//
//  NonogramViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator for the Nonogram screen. Mirrors
//  MinesweeperViewModel discipline (Foundation-only, all state
//  private(set), GameStats firewall — no SwiftData import here).
//
//  Lifecycle:
//    - init: pick a random puzzle for the chosen difficulty, board empty,
//      state = .idle, hints visible.
//    - first tap → state = .playing, timer starts.
//    - on every successful mutation: re-check win → state = .won.
//    - restart() picks a fresh random puzzle and resets the board + timer.
//

import Foundation

@Observable @MainActor
final class NonogramViewModel {

    // MARK: - State surface

    private(set) var difficulty: NonogramDifficulty
    private(set) var currentPuzzle: NonogramPuzzle?
    private(set) var board: NonogramBoard
    private(set) var state: NonogramGameState = .idle
    private(set) var interactionMode: NonogramInteractionMode = .place
    private(set) var gameMode: NonogramGameMode = .free

    // Timer
    private(set) var timerAnchor: Date?         // nil = paused/idle/terminal
    private(set) var pausedElapsed: TimeInterval = 0
    private(set) var frozenElapsed: TimeInterval = 0   // captured at win

    // Trigger counters for sensoryFeedback
    private(set) var placeCount: Int = 0
    private(set) var markCount: Int = 0
    private(set) var winCount: Int = 0
    /// Bumps every time the player attempts a wrong placement in lives mode.
    /// Used as a `.sensoryFeedback(.error)` trigger by the GameView.
    private(set) var wrongAttemptCount: Int = 0
    /// Bumps every time a row OR column transitions from "not fully
    /// crossed off" to "fully crossed off". Drives a heavier haptic so
    /// finishing a line feels distinct from individual cell taps.
    private(set) var lineCompletionCount: Int = 0
    /// Tracks already-completed lines so we don't re-fire the haptic on
    /// every later mutation in an already-finished row/col. Strings are
    /// `"r<idx>"` / `"c<idx>"` so the same key can't collide between rows
    /// and columns.
    private var completedLineKeys: Set<String> = []
    /// Flat index (row * size + col) of the most-recent wrong-tap cell.
    /// Drives the red-flash + shake feedback in CellView. Auto-cleared
    /// ~0.6s after being set.
    private(set) var lastWrongAttemptIdx: Int?

    // Lives mode state
    private(set) var livesRemaining: Int = NonogramGameMode.livesPerPuzzle
    /// Flat indices (row * size + col) of cells the player has correctly
    /// filled in lives mode. Locked — taps on these are no-ops.
    private(set) var lockedCells: Set<Int> = []

    // MARK: - Injection seams

    private let userDefaults: UserDefaults
    private let clock: () -> Date
    private var rng: any RandomNumberGenerator
    private(set) var gameStats: GameStats?

    // MARK: - Derived

    var rowHints: [[Int]] {
        guard let puzzle = currentPuzzle else { return [] }
        return NonogramHints.rows(for: puzzle, size: difficulty.size)
    }

    var columnHints: [[Int]] {
        guard let puzzle = currentPuzzle else { return [] }
        return NonogramHints.columns(for: puzzle, size: difficulty.size)
    }

    /// Per-row, per-hint cross-off mask. `mask[row][hintIdx] = true` when
    /// the player has placed a run that uniquely satisfies that hint number.
    var rowsCrossOff: [[Bool]] {
        NonogramHints.rowsCrossOff(board: board, hints: rowHints)
    }

    /// Per-column, per-hint cross-off mask.
    var columnsCrossOff: [[Bool]] {
        NonogramHints.columnsCrossOff(board: board, hints: columnHints)
    }

    /// Live elapsed seconds. While playing this advances with wall clock;
    /// at terminal states (win or game-over) it freezes to `frozenElapsed`.
    var elapsedSeconds: TimeInterval {
        if state == .won || state == .gameOver { return frozenElapsed }
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + clock().timeIntervalSince(anchor)
    }

    // MARK: - Init

    init(
        difficulty: NonogramDifficulty? = nil,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { Date.now },
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        gameStats: GameStats? = nil
    ) {
        self.userDefaults = userDefaults
        self.clock = clock
        self.rng = rng
        self.gameStats = gameStats

        let resolved = difficulty
            ?? NonogramDifficulty(rawValue: userDefaults.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .small
        self.difficulty = resolved

        let resolvedMode = NonogramGameMode(rawValue: userDefaults.string(forKey: Self.lastGameModeKey) ?? "")
            ?? .free
        self.gameMode = resolvedMode

        // Two-step init: empty board first so all stored properties are set
        // before we touch `&self.rng` for puzzle selection.
        self.board = .empty(size: resolved.size)
        self.currentPuzzle = nil
        self.board = .empty(size: resolved.size)
        self.currentPuzzle = pickPuzzle(for: resolved)
    }

    // MARK: - GameStats injection (lazy, one-shot)

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
    }

    // MARK: - Public API

    func handleTap(at row: Int, col: Int) {
        guard state == .idle || state == .playing else { return }
        // Note: .won and .gameOver short-circuit above.
        let cell = board.cell(row: row, col: col)
        let next: NonogramCellState
        switch (interactionMode, cell) {
        case (.place, .filled):    next = .empty
        case (.place, .empty), (.place, .marked): next = .filled
        case (.mark, .marked):     next = .empty
        case (.mark, .empty), (.mark, .filled):   next = .marked
        }
        applyMutation(at: row, col: col, next: next)
    }

    /// Direct cell setter used by the slide-drag gesture. Caller passes the
    /// final state explicitly (no mode-routing) so the drag's start-cell
    /// intent fully determines the smear behavior.
    /// Returns `true` if the mutation went through cleanly. Returns
    /// `false` when a Lives-mode wrong attempt fired — the BoardView uses
    /// the false return to ABORT the drag so a single careless swipe
    /// can't burn all 3 lives.
    @discardableResult
    func setCell(at row: Int, col: Int, to next: NonogramCellState) -> Bool {
        guard state == .idle || state == .playing else { return false }
        let wrongBefore = wrongAttemptCount
        applyMutation(at: row, col: col, next: next)
        return wrongAttemptCount == wrongBefore
    }

    func handleLongPress(at row: Int, col: Int) {
        guard state == .idle || state == .playing else { return }
        // Note: .won and .gameOver short-circuit above.
        let cell = board.cell(row: row, col: col)
        // Long-press always invokes the OPPOSITE mode's behavior.
        let next: NonogramCellState
        switch (interactionMode, cell) {
        case (.place, .marked):    next = .empty
        case (.place, .empty), (.place, .filled): next = .marked
        case (.mark, .filled):     next = .empty
        case (.mark, .empty), (.mark, .marked):   next = .filled
        }
        applyMutation(at: row, col: col, next: next)
    }

    func setInteractionMode(_ mode: NonogramInteractionMode) {
        interactionMode = mode
    }

    /// Reset the session, KEEPING the current puzzle. Used by the toolbar
    /// restart button + game-over "Try again" — both are "I want another
    /// crack at THIS puzzle." For a fresh puzzle, call `newPuzzle()`.
    func restart() {
        let preserved = currentPuzzle
        resetSessionState()
        currentPuzzle = preserved ?? pickPuzzle(for: difficulty)
    }

    /// Pick a fresh random puzzle and reset the session. Used by the win-
    /// state "New puzzle" button + by setDifficulty (size changes always
    /// imply a new puzzle).
    func newPuzzle() {
        resetSessionState()
        currentPuzzle = pickPuzzle(for: difficulty)
    }

    /// Backwards-compat alias for code that still calls `tryAgain()`.
    func tryAgain() { restart() }

    private func resetSessionState() {
        board = .empty(size: difficulty.size)
        state = .idle
        timerAnchor = nil
        pausedElapsed = 0
        frozenElapsed = 0
        placeCount = 0
        markCount = 0
        wrongAttemptCount = 0
        lastWrongAttemptIdx = nil
        lineCompletionCount = 0
        completedLineKeys = []
        interactionMode = .place
        livesRemaining = NonogramGameMode.livesPerPuzzle
        lockedCells = []
    }

    func setDifficulty(_ d: NonogramDifficulty) {
        guard d != difficulty else { return }
        difficulty = d
        userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
        // Difficulty change implies new puzzle — the size is different.
        newPuzzle()
    }

    func setGameMode(_ mode: NonogramGameMode) {
        guard mode != gameMode else { return }
        gameMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.lastGameModeKey)
        // Mode change pulls a new puzzle so locked-cell state from a
        // previous lives session can't leak into the new mode.
        newPuzzle()
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

    private func applyMutation(at row: Int, col: Int, next: NonogramCellState) {
        let prev = board.cell(row: row, col: col)
        guard prev != next else { return }

        let idx = row * difficulty.size + col

        // Lives-mode gate. Marks (player aid) stay free in both modes;
        // fills are validated against the solution.
        if gameMode == .lives {
            // Locked correct fills can't be erased or remarked.
            if lockedCells.contains(idx) { return }

            if next == .filled {
                guard let puzzle = currentPuzzle else { return }
                let solutionBit = puzzle.solution[idx]
                if !solutionBit {
                    // Wrong fill — auto-mark with X, lock, lose a life,
                    // record the wrong-attempt for the visual flash.
                    if state == .idle {
                        state = .playing
                        timerAnchor = clock()
                        pausedElapsed = 0
                    }
                    board = board.setting(.marked, atRow: row, col: col)
                    lockedCells.insert(idx)
                    recordWrongAttempt(at: idx)
                    return
                }
                // Correct — fall through to commit + lock the cell below.
                lockedCells.insert(idx)
            } else if next == .empty && prev == .filled {
                // Erasing a previously-correct fill is blocked; locked
                // cells already returned above. Defensive belt:
                return
            } else if next == .marked {
                guard let puzzle = currentPuzzle else { return }
                let solutionBit = puzzle.solution[idx]
                if solutionBit {
                    // Player marked an actually-filled cell. Wrong call —
                    // auto-fill it correctly + lock + life lost.
                    if state == .idle {
                        state = .playing
                        timerAnchor = clock()
                        pausedElapsed = 0
                    }
                    board = board.setting(.filled, atRow: row, col: col)
                    lockedCells.insert(idx)
                    recordWrongAttempt(at: idx)
                    if state != .gameOver,
                       let puzzle = currentPuzzle,
                       NonogramWinDetector.isWon(board: board, puzzle: puzzle) {
                        recordWin()
                    }
                    return
                }
                // Correct mark — fall through to commit (don't lock; player
                // may want to un-mark later for free).
            }
        }

        // First-action transition: idle → playing, start timer.
        if state == .idle {
            state = .playing
            timerAnchor = clock()
            pausedElapsed = 0
        }

        board = board.setting(next, atRow: row, col: col)

        switch next {
        case .filled: placeCount += 1
        case .marked: markCount += 1
        case .empty:
            if prev == .filled { placeCount += 1 } else { markCount += 1 }
        }

        // Detect any row/col that just became fully satisfied. Bump the
        // completion counter once per newly-completed line so the haptic
        // fires exactly when the player snaps a hint set into place.
        updateLineCompletions(touchedRow: row, touchedCol: col)

        if let puzzle = currentPuzzle, NonogramWinDetector.isWon(board: board, puzzle: puzzle) {
            recordWin()
        }
    }

    /// Recompute the completion state for the touched row + column only —
    /// no other lines could have changed in this single-cell mutation.
    /// Bumps `lineCompletionCount` for each line that newly transitioned
    /// to fully-crossed-off; un-completing a previously-finished line
    /// drops it from the tracked set without firing a haptic.
    private func updateLineCompletions(touchedRow: Int, touchedCol: Int) {
        let rowMask = NonogramHints.rowsCrossOff(board: board, hints: rowHints)
        let colMask = NonogramHints.columnsCrossOff(board: board, hints: columnHints)

        let rowKey = "r\(touchedRow)"
        let rowComplete = touchedRow >= 0 && touchedRow < rowMask.count
            && rowMask[touchedRow].allSatisfy { $0 }
        if rowComplete && !completedLineKeys.contains(rowKey) {
            completedLineKeys.insert(rowKey)
            lineCompletionCount += 1
        } else if !rowComplete {
            completedLineKeys.remove(rowKey)
        }

        let colKey = "c\(touchedCol)"
        let colComplete = touchedCol >= 0 && touchedCol < colMask.count
            && colMask[touchedCol].allSatisfy { $0 }
        if colComplete && !completedLineKeys.contains(colKey) {
            completedLineKeys.insert(colKey)
            lineCompletionCount += 1
        } else if !colComplete {
            completedLineKeys.remove(colKey)
        }
    }

    /// Record a wrong-tap event: bump the counter (drives sensoryFeedback),
    /// pin the cell index for visual flash, decrement lives, transition
    /// to game-over if exhausted. The flash auto-clears after 600ms.
    private func recordWrongAttempt(at idx: Int) {
        wrongAttemptCount += 1
        lastWrongAttemptIdx = idx
        livesRemaining -= 1
        if livesRemaining <= 0 {
            recordGameOver()
        }
        // Auto-clear the flash so the cell returns to its committed look.
        // If a newer wrong tap landed in the meantime, it'll have updated
        // lastWrongAttemptIdx, so guard before clearing.
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
            gameKind: .nonogram,
            difficulty: difficulty.rawValue,
            outcome: .loss,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    private func recordWin() {
        // Freeze the timer at win and stop wall-clock advancement.
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .won
        winCount += 1
        try? gameStats?.record(
            gameKind: .nonogram,
            difficulty: difficulty.rawValue,
            outcome: .win,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    /// Next puzzle for `difficulty`. Delegates to `NonogramPicker` so the
    /// curated-unseen-first → procedural fallback rule lives in one place.
    /// Always returns a valid puzzle (procedural Unlimited tier never
    /// runs out).
    private func pickPuzzle(for difficulty: NonogramDifficulty) -> NonogramPuzzle? {
        var any: any RandomNumberGenerator = rng
        let p = NonogramPicker.next(
            difficulty: difficulty,
            userDefaults: userDefaults,
            rng: &any
        )
        rng = any
        return p
    }

    // MARK: - Constants

    /// UserDefaults key for the last-played difficulty. Renaming = data break.
    static let lastDifficultyKey = "nonogram.lastDifficulty"
    /// UserDefaults key for the last-played game mode (free / lives).
    static let lastGameModeKey = "nonogram.lastGameMode"
}
