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
import SudokuCore
import Observation

@Observable @MainActor
final class SudokuViewModel {

    // MARK: - State surface

    // NOTE: properties written cross-file by SudokuViewModel+SaveState.swift
    // and SudokuViewModel+CompletionFeedback.swift are declared plain `var`
    // (not private(set)) so those extensions can write them — same
    // convention as NonogramViewModel. They remain read-only to view callers
    // by discipline.

    private(set) var difficulty: SudokuDifficulty
    var currentPuzzle: SudokuPuzzleEntry?
    var board: SudokuBoard?
    var state: SudokuGameState = .idle
    private(set) var gameMode: SudokuGameMode = .free
    private(set) var interactionMode: SudokuInteractionMode = .value

    /// Currently-selected cell, or nil if none. Selection persists across
    /// mutations.
    private(set) var selected: (row: Int, col: Int)?

    // Timer (mirrors NonogramViewModel's pattern)
    var timerAnchor: Date?
    var pausedElapsed: TimeInterval = 0
    var frozenElapsed: TimeInterval = 0

    // Lives-mode state
    var mistakes: Int = 0
    /// Flat indices of cells locked by a correct .lives placement (or by
    /// being given). Erase + re-place no-op on these.
    var lockedCells: Set<Int> = []

    // Sensory feedback counters
    private(set) var placeCount: Int = 0
    private(set) var winCount: Int = 0
    private(set) var wrongAttemptCount: Int = 0
    /// Flat index of the most-recent wrong placement, for the red-flash +
    /// shake animation in CellView. Auto-cleared ~600ms after being set.
    private(set) var lastWrongAttemptIdx: Int?

    // Completion feedback
    /// Flat indices of cells belonging to a just-completed row, column, or box.
    /// Set on every correct placement that completes a group; auto-cleared after 800ms.
    var completionGlowIndices: Set<Int> = []
    /// Incremented each time completionGlowIndices is populated — drives the
    /// medium-impact haptic in the view.
    var completionGlowCount: Int = 0
    /// Incremented when all 9 instances of a digit have been placed.
    var numberCompleteCount: Int = 0
    /// The digit that just reached 0 remaining. Auto-cleared after 600ms.
    /// Used to pulse the corresponding button in SudokuNumberPad.
    var justCompletedDigit: Int?

    // Single-step undo
    private(set) var undoSnapshot: SudokuUndoSnapshot?

    // Save state — non-nil when a persisted in-progress game is waiting for
    // the player to choose Continue or New Puzzle. Cleared on restore,
    // discard, win, game-over, or restart.
    var pendingSaveState: SudokuSaveState?

    // MARK: - Injection seams
    //
    // `pool` / `userDefaults` / `clock` are internal (not private) so the
    // save-state extension can reach them.

    let pool: SudokuPuzzlePool
    let userDefaults: UserDefaults
    let clock: () -> Date
    private(set) var gameStats: GameStats?

    // MARK: - Derived

    /// Live elapsed seconds (matches NonogramViewModel pattern).
    var elapsedSeconds: TimeInterval {
        if state == .won || state == .gameOver || state == .practiceAfterLoss || state == .practiceComplete {
            return frozenElapsed
        }
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
        mode: SudokuGameMode? = nil,
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

        let resolvedMode = mode
            ?? SudokuGameMode(rawValue: userDefaults.string(forKey: Self.lastGameModeKey) ?? "")
            ?? .free
        self.gameMode = resolvedMode

        // Puzzle load is deferred to attachGameStats() so the first call
        // always has the full wonPuzzleIDs history from SwiftData.
        // Loading here (before stats injection) would always see an empty
        // played set and serve puzzle 0 on every cold start.
    }

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
        if board == nil {
            checkAndLoadOrRestoreState()
        }
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
        guard state == .idle || state == .playing || state == .practiceAfterLoss else { return }
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
        guard state == .idle || state == .playing || state == .practiceAfterLoss else { return }
        guard let s = selected, let board else { return }
        let idx = s.row * 9 + s.col
        let cell = board.cell(row: s.row, col: s.col)
        guard !cell.isGiven else { return }
        if gameMode == .lives && lockedCells.contains(idx) { return }

        switch cell {
        case .user:
            captureUndo(at: s.row, col: s.col, previousCell: cell)
            self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
            saveCurrentState()
        case .empty(let notes) where !notes.isEmpty:
            captureUndo(at: s.row, col: s.col, previousCell: cell)
            self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
            saveCurrentState()
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
        clearSavedState()
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

    func keepSolving() {
        guard state == .gameOver else { return }
        state = .practiceAfterLoss
        saveCurrentState()
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

    /// Internal (not private) — invoked from SudokuViewModel+SaveState.swift.
    func loadFreshPuzzle() async {
        resetSessionState()
        do {
            let playedIDs = gameStats?.wonPuzzleIDs(
                gameKind: .sudoku,
                difficulty: difficulty.rawValue
            ) ?? Set<String>()
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
        completionGlowIndices = []
        completionGlowCount = 0
        numberCompleteCount = 0
        justCompletedDigit = nil
        pendingSaveState = nil
        undoSnapshot = nil
        selected = nil
        lockedCells = []
        interactionMode = .value
        assistsUsed = 0
        activeHint = nil
        hintUnavailable = nil
        isHintCardVisible = false
    }

    /// Indices of user-placed digits that disagree with the solution.
    ///
    /// Free mode only, and that is the whole point: `.lives` never commits a
    /// wrong value, so only `.free` can hold one. Free mode's contract has
    /// always said wrong placements show red — it simply was not built, so a
    /// player could enter a wrong digit, get no signal of any kind, and grind
    /// for the rest of the session on a board that could never be solved.
    ///
    /// The tradeoff is real and accepted: a player can now brute-force by
    /// trying digits until nothing is red. Free mode already has no lives, no
    /// failure state, and unlimited erase — someone who chose it over Lives
    /// mode opted out of stakes, and silently letting them waste an hour is
    /// the worse failure.
    var incorrectCellIndices: Set<Int> {
        guard gameMode == .free, let board else { return [] }
        var result: Set<Int> = []
        for row in 0..<9 {
            for col in 0..<9 {
                if case .user(let value) = board.cell(row: row, col: col),
                   board.solutionDigit(atRow: row, col: col) != value {
                    result.insert(row * 9 + col)
                }
            }
        }
        return result
    }

    // MARK: - Talkthrough (assist)

    /// Assists asked for on this puzzle. Persisted with the save so closing
    /// the app cannot launder an assisted solve into a clean one.
    var assistsUsed: Int = 0

    /// How far the player has asked the current hint to go.
    ///
    /// Graduated on purpose: naming the technique and region is usually
    /// enough to unstick someone, and stopping there leaves them the
    /// satisfaction of placing the digit. Only a second ask reveals it.
    enum HintStage: Equatable { case explanation, reveal }

    struct ActiveHint: Equatable {
        let step: SudokuHintEngine.Step
        var stage: HintStage
    }

    private(set) var activeHint: ActiveHint?

    /// The explanation can be closed without discarding its ring and support
    /// shading. Those remain until the named digit is placed.
    private(set) var isHintCardVisible = false

    /// Set when a request could not produce a step. Singles are the only
    /// techniques this engine proves, so Hard and Extreme puzzles will reach
    /// this — the copy has to own that rather than pretend.
    private(set) var hintUnavailable: HintUnavailable?

    enum HintUnavailable: Equatable {
        /// Something already placed contradicts the solution (free mode only).
        case boardHasAMistake
        /// Beyond naked and hidden singles.
        case beyondSingles
    }

    /// Ask for the next step, or push the current one further.
    ///
    /// Charges exactly one assist per puzzle-step, not per tap: escalating
    /// from explanation to reveal is the same hint, so it does not cost twice.
    func requestHint() {
        guard state == .idle || state == .playing || state == .practiceAfterLoss else { return }
        hintUnavailable = nil

        // Reopening a dismissed explanation is not another ask. A second tap
        // while it is already visible still escalates the same step.
        if var hint = activeHint {
            if !isHintCardVisible {
                isHintCardVisible = true
                return
            }
            hint.stage = .reveal
            activeHint = hint
            return
        }

        // A wrong digit already on the board makes any further advice
        // meaningless — the engine would reason from a false premise.
        if !incorrectCellIndices.isEmpty {
            hintUnavailable = .boardHasAMistake
            isHintCardVisible = true
            return
        }

        guard let board else { return }
        let engine = SudokuHintEngine()
        guard let step = engine.nextStep(board: Self.flatValues(of: board)) else {
            hintUnavailable = .beyondSingles
            isHintCardVisible = true
            return
        }

        activeHint = ActiveHint(step: step, stage: .explanation)
        isHintCardVisible = true
        assistsUsed += 1
        saveCurrentState()
    }

    /// The square the hint names, so the board can ring it.
    var hintTargetIndex: Int? { activeHint?.step.index }

    /// The squares carrying the argument — the containing row, column, or box
    /// for a hidden single, the peers that do the eliminating for a naked one.
    /// Shaded so the explanation has something to point at.
    var hintSupportingIndices: Set<Int> {
        guard let hint = activeHint else { return [] }
        switch hint.step.technique {
        case .hiddenSingle:
            return Set(hint.step.supportingIndices)
        case .nakedSingle:
            // All 20 peers at once is noise. The row and column through the
            // square carry the argument legibly; the box is implied by the
            // ring on the square itself.
            let row = hint.step.row, col = hint.step.column
            return Set((0..<9).map { row * 9 + $0 } + (0..<9).map { $0 * 9 + col })
        }
    }

    func dismissHint() {
        isHintCardVisible = false
        if activeHint == nil { hintUnavailable = nil }
    }

    /// Places the digit the current hint names, if the player asks for it.
    func applyHint() {
        guard let hint = activeHint else { return }
        select(row: hint.step.row, col: hint.step.column)
        place(value: hint.step.value)
        activeHint = nil
        isHintCardVisible = false
    }

    /// Honest fallback when the singles engine cannot narrate a short step.
    /// Reveals exactly one empty cell and charges one assist.
    func applyFallbackHint() {
        guard hintUnavailable == .beyondSingles, let board else { return }
        guard let index = (0..<81).first(where: {
            if case .empty = board.cells[$0] { return true }
            return false
        }) else { return }
        assistsUsed += 1
        select(row: index / 9, col: index % 9)
        place(value: board.solutionDigit(atRow: index / 9, col: index % 9))
        hintUnavailable = nil
        isHintCardVisible = false
    }

    /// The board as SudokuCore sees it: row-major, 0 for empty.
    static func flatValues(of board: SudokuBoard) -> [Int] {
        (0..<81).map { index in
            switch board.cell(row: index / 9, col: index % 9) {
            case .given(let v): return v
            case .user(let v):  return v
            case .empty:        return 0
            }
        }
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
            consumeHintIfMatched(index: idx, value: value)
            if state == .idle { startTimer() }
            fireCompletionEffects(row: row, col: col, value: value, board: board)
            saveCurrentState()
            if board.isSolved { completeBoard(); return }
            return
        }

        // .free mode — commit unconditionally. Wrong placements render in the
        // danger color via `incorrectCellIndices` (fed to SudokuCellView by
        // SudokuBoardView), but there is no failure state and nothing locks.
        captureUndo(at: row, col: col, previousCell: prevCell)
        board = board.setting(.user(value), atRow: row, col: col)
        board = board.clearingPeerNotes(of: value, fromRow: row, col: col)
        self.board = board
        placeCount += 1
        consumeHintIfMatched(index: idx, value: value)
        if state == .idle { startTimer() }
        fireCompletionEffects(row: row, col: col, value: value, board: board)
        saveCurrentState()
        if board.isSolved { completeBoard() }
    }

    /// A hint is consumed only by entering the digit it named. Other valid
    /// placements leave its board guidance intact.
    private func consumeHintIfMatched(index: Int, value: Int) {
        guard activeHint?.step.index == index,
              activeHint?.step.value == value else { return }
        activeHint = nil
        isHintCardVisible = false
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
        saveCurrentState()
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
        if state == .practiceAfterLoss {
            scheduleWrongFlashClear(for: idx)
            return
        }
        mistakes += 1
        if mistakes >= SudokuGameMode.livesPerPuzzle {
            recordGameOver()
        }
        scheduleWrongFlashClear(for: idx)
    }

    private func scheduleWrongFlashClear(for idx: Int) {
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
            puzzleId: currentPuzzle?.id,
            assistCount: assistsUsed
        )
        saveCurrentState()
    }

    private func completeBoard() {
        if state == .practiceAfterLoss {
            clearSavedState()
            state = .practiceComplete
        } else {
            recordWin()
        }
    }

    private func recordWin() {
        clearSavedState()
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
            puzzleId: currentPuzzle?.id,
            assistCount: assistsUsed
        )
    }

    // MARK: - Save state + completion feedback
    //
    // Persistence I/O lives in SudokuViewModel+SaveState.swift; the
    // group-completion glow/pulse lives in
    // SudokuViewModel+CompletionFeedback.swift.

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
