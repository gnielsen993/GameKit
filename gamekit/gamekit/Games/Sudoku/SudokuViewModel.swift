//
//  SudokuViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator for the Sudoku screen. Mirrors
//  NonogramViewModel discipline (Foundation-only, all state private(set),
//  GameStats firewall — no SwiftData import here, GameRecord writes
//  routed through GameStats.record(...)).
//
//  Lifecycle:
//    - init: load pool (lazy), pick next unplayed puzzle, .idle state.
//    - first commit (place value or note) → .playing, timer starts.
//    - on every successful value commit: check isSolved → .won.
//    - .lives mode: 3 mistakes → .gameOver.
//
//  Selection model:
//    - User taps a cell → that cell becomes `selected`.
//    - User taps a number-pad button (1...9) → in .value mode, commits
//      that digit to the selected cell; in .note mode, toggles that
//      digit in the cell's notes.
//    - Erase button → clears value or notes from the selected cell
//      (no-op on .given cells; no-op on locked correct cells in .lives).
//

import Foundation
import Observation

@Observable @MainActor
final class SudokuViewModel {

    // MARK: - State surface

    private(set) var difficulty: SudokuDifficulty
    private(set) var currentPuzzle: SudokuPuzzleEntry?
    private(set) var board: SudokuBoard?
    private(set) var state: SudokuGameState = .idle
    private(set) var gameMode: SudokuGameMode = .free
    private(set) var interactionMode: SudokuInteractionMode = .value

    /// Currently-selected cell, or nil if none. Selection persists across
    /// mutations.
    private(set) var selected: (row: Int, col: Int)?

    // Timer (mirrors NonogramViewModel's pattern)
    private(set) var timerAnchor: Date?
    private(set) var pausedElapsed: TimeInterval = 0
    private(set) var frozenElapsed: TimeInterval = 0

    // Lives-mode state
    private(set) var mistakes: Int = 0
    /// Flat indices of cells locked by a correct .lives placement (or by
    /// being given). Erase + re-place no-op on these.
    private(set) var lockedCells: Set<Int> = []

    // Sensory feedback counters
    private(set) var placeCount: Int = 0
    private(set) var winCount: Int = 0
    private(set) var wrongAttemptCount: Int = 0
    /// Flat index of the most-recent wrong placement, for the red-flash +
    /// shake animation in CellView. Auto-cleared ~600ms after being set.
    private(set) var lastWrongAttemptIdx: Int?

    // Single-step undo
    private(set) var undoSnapshot: SudokuUndoSnapshot?

    // MARK: - Injection seams

    private let pool: SudokuPuzzlePool
    private let userDefaults: UserDefaults
    private let clock: () -> Date
    private(set) var gameStats: GameStats?

    // MARK: - Derived

    /// Live elapsed seconds (matches NonogramViewModel pattern).
    var elapsedSeconds: TimeInterval {
        if state == .won || state == .gameOver { return frozenElapsed }
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + clock().timeIntervalSince(anchor)
    }

    /// Currently-selected cell, or nil if none selected.
    var selectedCell: SudokuCell? {
        guard let s = selected, let board else { return nil }
        return board.cell(row: s.row, col: s.col)
    }

    /// Remaining count of each digit 1...9 (9 minus number of cells
    /// committed to that digit). Used by SudokuNumberPad badges.
    var remainingPerDigit: [Int: Int] {
        guard let board else {
            return Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 9) })
        }
        var counts: [Int: Int] = [:]
        for d in 1...9 { counts[d] = 9 }
        for cell in board.cells {
            if let v = cell.value, counts[v] != nil {
                counts[v]! -= 1
            }
        }
        return counts
    }

    // MARK: - Init

    init(
        difficulty: SudokuDifficulty? = nil,
        pool: SudokuPuzzlePool = SudokuPuzzlePool(),
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { Date.now },
        gameStats: GameStats? = nil
    ) {
        self.pool = pool
        self.userDefaults = userDefaults
        self.clock = clock
        self.gameStats = gameStats

        let resolved = difficulty
            ?? SudokuDifficulty(rawValue: userDefaults.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy
        self.difficulty = resolved

        let resolvedMode = SudokuGameMode(rawValue: userDefaults.string(forKey: Self.lastGameModeKey) ?? "")
            ?? .free
        self.gameMode = resolvedMode

        // Load the first puzzle lazily.
        Task { @MainActor in
            await self.loadFreshPuzzle()
        }
    }

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
    }

    // MARK: - Public API

    /// Select a cell. Does NOT mutate the board or start the timer.
    func select(row: Int, col: Int) {
        guard (0..<9).contains(row), (0..<9).contains(col) else { return }
        selected = (row, col)
    }

    /// Place a value 1...9 into the selected cell. Honors the current
    /// interactionMode: in .value commits the digit, in .note toggles it
    /// in the notes set.
    func place(value: Int) {
        guard (1...9).contains(value),
              let s = selected,
              let board else { return }
        let idx = s.row * 9 + s.col
        let cell = board.cell(row: s.row, col: s.col)

        // Givens are immutable.
        guard !cell.isGiven else { return }

        // .lives: locked correct cells are immutable.
        if gameMode == .lives && lockedCells.contains(idx) { return }

        switch interactionMode {
        case .value:
            commitValue(value, atRow: s.row, col: s.col)
        case .note:
            toggleNote(value, atRow: s.row, col: s.col)
        }
    }

    /// Erase the selected cell's value/notes. No-op on givens and on
    /// locked correct cells in .lives.
    func erase() {
        guard let s = selected, let board else { return }
        let idx = s.row * 9 + s.col
        let cell = board.cell(row: s.row, col: s.col)
        guard !cell.isGiven else { return }
        if gameMode == .lives && lockedCells.contains(idx) { return }

        switch cell {
        case .user:
            captureUndo(at: s.row, col: s.col, previousCell: cell)
            self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
        case .empty(let notes) where !notes.isEmpty:
            captureUndo(at: s.row, col: s.col, previousCell: cell)
            self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
        default:
            break  // .given handled above; .empty(notes: []) is a no-op
        }
    }

    /// Restore the last mutation. Consumes the snapshot.
    func undo() {
        guard let snap = undoSnapshot, let board else { return }
        self.board = board.setting(snap.previousCell, atRow: snap.row, col: snap.col)
        self.mistakes = snap.previousMistakes
        undoSnapshot = nil
    }

    func setInteractionMode(_ mode: SudokuInteractionMode) {
        interactionMode = mode
    }

    func setDifficulty(_ d: SudokuDifficulty) {
        guard d != difficulty else { return }
        difficulty = d
        userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
        Task { @MainActor in await loadFreshPuzzle() }
    }

    func setGameMode(_ mode: SudokuGameMode) {
        guard mode != gameMode else { return }
        gameMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.lastGameModeKey)
        Task { @MainActor in await loadFreshPuzzle() }
    }

    /// Restart the current puzzle (same givens, fresh state).
    func restart() {
        guard let puzzle = currentPuzzle else { return }
        resetSessionState()
        board = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution)
        // Re-lock given cells.
        var locked = Set<Int>()
        if let b = board {
            for i in 0..<81 where b.cells[i].isGiven { locked.insert(i) }
        }
        lockedCells = locked
    }

    /// Load a new (unplayed) puzzle for the current difficulty.
    func newPuzzle() {
        Task { @MainActor in await loadFreshPuzzle() }
    }

    func pause() {
        guard let anchor = timerAnchor else { return }
        pausedElapsed += clock().timeIntervalSince(anchor)
        timerAnchor = nil
    }

    func resume() {
        guard state == .playing, timerAnchor == nil else { return }
        timerAnchor = clock()
    }

    // MARK: - Private

    private func loadFreshPuzzle() async {
        resetSessionState()
        do {
            // TODO(Phase 16): swap to gameStats?.sudokuPlayedIDs(for: difficulty)
            // once GameStats gains a SwiftData read path. For now, pass an empty
            // set so the pool falls back to its session-cursor round-robin.
            let playedIDs = Set<String>()
            let entry = try await pool.next(difficulty: difficulty, playedIDs: playedIDs)
            currentPuzzle = entry
            board = SudokuBoard(givens: entry.givens, solution: entry.solution)
            // Lock all given cells so erase() no-ops on them.
            var locked = Set<Int>()
            if let b = board {
                for i in 0..<81 where b.cells[i].isGiven { locked.insert(i) }
            }
            lockedCells = locked
        } catch {
            currentPuzzle = nil
            board = nil
        }
    }

    private func resetSessionState() {
        state = .idle
        timerAnchor = nil
        pausedElapsed = 0
        frozenElapsed = 0
        mistakes = 0
        placeCount = 0
        wrongAttemptCount = 0
        lastWrongAttemptIdx = nil
        undoSnapshot = nil
        selected = nil
        lockedCells = []
        interactionMode = .value
    }

    private func commitValue(_ value: Int, atRow row: Int, col: Int) {
        guard var board else { return }
        let idx = row * 9 + col
        let prevCell = board.cell(row: row, col: col)
        let correct = board.solutionDigit(atRow: row, col: col) == value

        if gameMode == .lives {
            if !correct {
                // Wrong placement — increment mistakes, NO commit, record
                // the wrong-attempt for visual flash + haptic.
                if state == .idle { startTimer() }
                recordWrongAttempt(at: idx)
                return
            }
            // Correct — commit + lock + auto-clear peer notes.
            captureUndo(at: row, col: col, previousCell: prevCell)
            board = board.setting(.user(value), atRow: row, col: col)
            board = board.clearingPeerNotes(of: value, fromRow: row, col: col)
            self.board = board
            lockedCells.insert(idx)
            placeCount += 1
            if state == .idle { startTimer() }
            if board.isSolved { recordWin(); return }
            return
        }

        // .free mode — commit unconditionally. Wrong placements show red
        // via the CellView's solution-mismatch overlay, but no failure
        // state.
        captureUndo(at: row, col: col, previousCell: prevCell)
        board = board.setting(.user(value), atRow: row, col: col)
        board = board.clearingPeerNotes(of: value, fromRow: row, col: col)
        self.board = board
        placeCount += 1
        if state == .idle { startTimer() }
        if board.isSolved { recordWin() }
    }

    private func toggleNote(_ value: Int, atRow row: Int, col: Int) {
        guard let board else { return }
        let cell = board.cell(row: row, col: col)
        // Notes can only be added to .empty cells. Committing a value
        // clears notes implicitly.
        guard case .empty(var notes) = cell else { return }
        if notes.contains(value) {
            notes.remove(value)
        } else {
            notes.insert(value)
        }
        captureUndo(at: row, col: col, previousCell: cell)
        self.board = board.setting(.empty(notes: notes), atRow: row, col: col)
        if state == .idle { startTimer() }
    }

    private func startTimer() {
        state = .playing
        timerAnchor = clock()
        pausedElapsed = 0
    }

    private func captureUndo(at row: Int, col: Int, previousCell: SudokuCell) {
        undoSnapshot = SudokuUndoSnapshot(
            row: row,
            col: col,
            previousCell: previousCell,
            previousMistakes: mistakes
        )
    }

    private func recordWrongAttempt(at idx: Int) {
        wrongAttemptCount += 1
        lastWrongAttemptIdx = idx
        mistakes += 1
        if mistakes >= SudokuGameMode.livesPerPuzzle {
            recordGameOver()
        }
        // Auto-clear flash after 600ms (mirrors Nonogram).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if self.lastWrongAttemptIdx == idx {
                self.lastWrongAttemptIdx = nil
            }
        }
    }

    private func recordGameOver() {
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .gameOver
        try? gameStats?.record(
            gameKind: .sudoku,
            difficulty: difficulty.rawValue,
            outcome: .loss,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    private func recordWin() {
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .won
        winCount += 1
        try? gameStats?.record(
            gameKind: .sudoku,
            difficulty: difficulty.rawValue,
            outcome: .win,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    // MARK: - Constants

    static let lastDifficultyKey = "sudoku.lastDifficulty"
    static let lastGameModeKey   = "sudoku.lastGameMode"
}

// MARK: - Test injection seam (#if DEBUG)

#if DEBUG
extension SudokuViewModel {
    /// Test-only entry point that bypasses the async pool load.
    @MainActor
    func injectTestBoardForUnitTests(puzzle: SudokuPuzzleEntry) {
        self.currentPuzzle = puzzle
        self.board = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution)
        var locked = Set<Int>()
        if let b = self.board {
            for i in 0..<81 where b.cells[i].isGiven {
                locked.insert(i)
            }
        }
        self.lockedCells = locked
    }
}
#endif
