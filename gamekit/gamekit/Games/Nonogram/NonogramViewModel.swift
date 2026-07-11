//
//  NonogramViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator for the Nonogram screen. Mirrors
//  MinesweeperViewModel discipline (Foundation-only, all state
//  private(set), GameStats firewall — no SwiftData import here).
//
//  Lifecycle:
//    - init: instant-pick a puzzle (unseen curated or prefetched
//      procedural) — cheap, side-effect-free. When the curated pool is
//      exhausted and no prefetch exists, `currentPuzzle` stays nil and
//      `ensurePuzzleLoaded()` generates OFF the main thread
//      (`isGeneratingPuzzle` drives the view's loading state). Never
//      generate synchronously — 20×20 generation blocked the main
//      thread for 30s+ before the 2026-07-10 fix.
//    - first move → state = .playing, timer starts, puzzle marked seen
//      (NOT at pick time — see NonogramPicker header).
//    - on every successful mutation: re-check win → state = .won.
//    - restart() keeps the puzzle; newPuzzle() instant-picks + falls
//      back to async generation the same way init does.
//

import Foundation

@Observable @MainActor
final class NonogramViewModel {

    // MARK: - State surface
    //
    // Properties below marked `var` (not `private(set)`) are written by
    // NonogramViewModel+SaveState.swift. Treated as read-only by external
    // (view) callers — same pattern as MinesweeperViewModel's timer props.

    var difficulty: NonogramDifficulty
    var currentPuzzle: NonogramPuzzle?
    var board: NonogramBoard
    var state: NonogramGameState = .idle
    private(set) var interactionMode: NonogramInteractionMode = .place
    var gameMode: NonogramGameMode = .free

    // Timer
    var timerAnchor: Date?                       // nil = paused/idle/terminal
    var pausedElapsed: TimeInterval = 0
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
    // Plain `var` (not private(set)) — written by
    // NonogramViewModel+LineFeedback.swift. Read-only to view callers.
    var lineCompletionCount: Int = 0
    /// Tracks already-completed lines so we don't re-fire the haptic on
    /// every later mutation in an already-finished row/col. Strings are
    /// `"r<idx>"` / `"c<idx>"` so the same key can't collide between rows
    /// and columns.
    var completedLineKeys: Set<String> = []
    /// Row index of the most-recent line-completion event. Drives a
    /// 700ms accent-glow on every cell in that row so the player gets a
    /// visual "you nailed it" beat on top of the haptic. Auto-cleared.
    var flashRow: Int?
    /// Column index of the most-recent line-completion event.
    var flashCol: Int?
    /// Flat index (row * size + col) of the most-recent wrong-tap cell.
    /// Drives the red-flash + shake feedback in CellView. Auto-cleared
    /// ~0.6s after being set.
    private(set) var lastWrongAttemptIdx: Int?

    // Save state prompt
    var pendingSaveState: NonogramSaveState?

    /// True while a procedural puzzle is being generated off-main for
    /// the CURRENT slot (curated pool exhausted, no prefetch available).
    /// The view shows a lightweight loading state over the empty board.
    private(set) var isGeneratingPuzzle = false

    /// In-flight generation for the current puzzle slot. One at a time.
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    /// In-flight background prefetch of the NEXT procedural puzzle.
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?

    // Lives mode state
    var livesRemaining: Int = NonogramGameMode.livesPerPuzzle
    /// Flat indices (row * size + col) of cells the player has correctly
    /// filled in lives mode. Locked — taps on these are no-ops.
    var lockedCells: Set<Int> = []

    // MARK: - Injection seams

    let userDefaults: UserDefaults
    let clock: () -> Date
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
    /// Cached — recomputed only after a cell mutation, NOT on every view
    /// read. The placement-enumeration algorithm is too expensive to run
    /// for every SwiftUI render pass during a swipe (was the dominant
    /// cause of swipe lag on 20×20 boards).
    private(set) var rowsCrossOff: [[Bool]] = []

    /// Per-column, per-hint cross-off mask. Cached — see `rowsCrossOff`.
    private(set) var columnsCrossOff: [[Bool]] = []

    /// Recompute cross-off masks. Called after any board mutation.
    func refreshCrossOff() {
        guard currentPuzzle != nil else {
            rowsCrossOff = []
            columnsCrossOff = []
            return
        }
        rowsCrossOff = NonogramHints.rowsCrossOff(board: board, hints: rowHints)
        columnsCrossOff = NonogramHints.columnsCrossOff(board: board, hints: columnHints)
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
        mode: NonogramGameMode? = nil,
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

        let resolvedMode = mode
            ?? NonogramGameMode(rawValue: userDefaults.string(forKey: Self.lastGameModeKey) ?? "")
            ?? .free
        self.gameMode = resolvedMode

        // Two-step init: empty board first so all stored properties are set
        // before we touch `&self.rng` for puzzle selection. Instant-only —
        // nil when generation is needed; the view's `.task` →
        // attachGameStats → ensurePuzzleLoaded() handles that async, so
        // SwiftUI re-constructing the view struct never costs more than
        // a library lookup.
        self.board = .empty(size: resolved.size)
        self.currentPuzzle = nil
        self.currentPuzzle = pickInstantPuzzle(for: resolved)
        refreshCrossOff()
    }

    // MARK: - GameStats injection (lazy, one-shot)

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
        mergeSeenFromRecords()
        checkAndLoadOrRestoreState()
        refreshFrontierAfterMerge()
        if pendingSaveState == nil {
            ensurePuzzleLoaded()
        }
        prefetchNextPuzzleIfNeeded()
    }

    /// Rebuild the per-difficulty "seen" frontier from synced GameRecord
    /// wins. UserDefaults dies with an app delete; the SwiftData records
    /// survive via iCloud sync / stats import — without this merge a
    /// reinstall restarts the curated rotation and re-serves puzzles the
    /// player already solved.
    private func mergeSeenFromRecords() {
        guard let stats = gameStats else { return }
        for d in NonogramDifficulty.allCases {
            let won = stats.wonPuzzleIDs(gameKind: .nonogram, difficulty: d.rawValue)
            NonogramPicker.mergeSeen(ids: won, difficulty: d, userDefaults: userDefaults)
        }
    }

    /// After merging synced wins, the puzzle instant-picked at init may
    /// turn out to be one the player already solved (fresh install +
    /// iCloud restore). If the session hasn't started, swap it out.
    private func refreshFrontierAfterMerge() {
        guard state == .idle, pendingSaveState == nil,
              let p = currentPuzzle,
              NonogramPicker.isSeen(p.id, difficulty: difficulty, userDefaults: userDefaults)
        else { return }
        newPuzzle()
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
        currentPuzzle = preserved ?? pickInstantPuzzle(for: difficulty)
        refreshCrossOff()
        ensurePuzzleLoaded()
    }

    /// Pick a fresh random puzzle and reset the session. Used by the win-
    /// state "New puzzle" button + by setDifficulty (size changes always
    /// imply a new puzzle). Instant when the curated pool or prefetch
    /// cache can serve; otherwise generates off-main (loading state).
    func newPuzzle() {
        resetSessionState()
        currentPuzzle = pickInstantPuzzle(for: difficulty)
        refreshCrossOff()
        ensurePuzzleLoaded()
        prefetchNextPuzzleIfNeeded()
    }

    func resetSessionState() {
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
        flashRow = nil
        flashCol = nil
        interactionMode = .place
        livesRemaining = NonogramGameMode.livesPerPuzzle
        lockedCells = []
        pendingSaveState = nil
    }

    func setDifficulty(_ d: NonogramDifficulty) {
        guard d != difficulty else { return }
        clearSavedState()
        difficulty = d
        userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
        newPuzzle()
    }

    func setGameMode(_ mode: NonogramGameMode) {
        guard mode != gameMode else { return }
        clearSavedState()
        gameMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.lastGameModeKey)
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

    // MARK: - Puzzle loading

    /// Generate a puzzle for the current slot when nothing instant was
    /// available. Runs `NonogramGenerator` on a detached task — never on
    /// the main thread (20×20 generation cost froze the UI before the 2026-07-10 fix).
    /// Safe to call whenever; no-ops when a puzzle is present or a
    /// generation is already in flight.
    func ensurePuzzleLoaded() {
        guard currentPuzzle == nil, generationTask == nil else { return }
        isGeneratingPuzzle = true
        let d = difficulty
        let seed = UInt64.random(in: .min ... .max, using: &rng)
        generationTask = Task { [weak self] in
            let puzzle = await Self.generateDetached(difficulty: d, seed: seed)
            guard let self else { return }
            self.generationTask = nil
            self.isGeneratingPuzzle = false
            guard self.difficulty == d else {
                // Player switched sizes mid-generation — discard and
                // re-evaluate for the new difficulty.
                self.ensurePuzzleLoaded()
                return
            }
            // A save-state restore may have filled the slot meanwhile.
            guard self.currentPuzzle == nil else { return }
            self.currentPuzzle = puzzle
            self.refreshCrossOff()
            self.prefetchNextPuzzleIfNeeded()
        }
    }

    /// Background-generate the NEXT procedural puzzle once the curated
    /// pool for the current difficulty is exhausted and no prefetch is
    /// cached — so the player never waits on the generator again.
    func prefetchNextPuzzleIfNeeded() {
        guard prefetchTask == nil,
              NonogramPicker.needsGeneration(for: difficulty, userDefaults: userDefaults)
        else { return }
        let d = difficulty
        let seed = UInt64.random(in: .min ... .max, using: &rng)
        prefetchTask = Task(priority: .utility) { [weak self] in
            let puzzle = await Self.generateDetached(difficulty: d, seed: seed)
            guard let self else { return }
            NonogramPicker.storeCachedProcPuzzle(puzzle, for: d, userDefaults: self.userDefaults)
            self.prefetchTask = nil
        }
    }

    private nonisolated static func generateDetached(
        difficulty: NonogramDifficulty,
        seed: UInt64
    ) async -> NonogramPuzzle {
        await Task.detached(priority: .userInitiated) {
            NonogramGenerator.generate(difficulty: difficulty, seed: seed)
        }.value
    }

    // MARK: - Private

    /// idle → playing transition: start the timer and — the ONLY place
    /// this happens — mark the puzzle as seen. Marking on first move
    /// (not at pick time) keeps screen opens, save restores, and SwiftUI
    /// re-inits from draining the curated pool.
    private func beginPlayingIfNeeded() {
        guard state == .idle else { return }
        state = .playing
        timerAnchor = clock()
        pausedElapsed = 0
        if let id = currentPuzzle?.id {
            NonogramPicker.markSeen(puzzleId: id, difficulty: difficulty, userDefaults: userDefaults)
        }
        prefetchNextPuzzleIfNeeded()
    }

    private func applyMutation(at row: Int, col: Int, next: NonogramCellState) {
        guard currentPuzzle != nil else { return }  // still generating
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
                    beginPlayingIfNeeded()
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
                    beginPlayingIfNeeded()
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
                // Correct mark — commit AND lock. In Lives mode a verified
                // X is known truth, so the player can't un-mark it (matches
                // the locking rule for verified fills above).
                lockedCells.insert(idx)
            }
        }

        // First-action transition: idle → playing, start timer.
        beginPlayingIfNeeded()

        board = board.setting(next, atRow: row, col: col)

        switch next {
        case .filled: placeCount += 1
        case .marked: markCount += 1
        case .empty:
            if prev == .filled { placeCount += 1 } else { markCount += 1 }
        }

        // Refresh cross-off ONCE per mutation; both the line-completion
        // detector below and the view layer reuse the cached masks.
        refreshCrossOff()
        updateLineCompletions(touchedRow: row, touchedCol: col)

        if let puzzle = currentPuzzle, NonogramWinDetector.isWon(board: board, puzzle: puzzle) {
            recordWin()
        } else {
            saveCurrentState()
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
        clearSavedState()
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
        clearSavedState()
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

    /// Instant next puzzle for `difficulty` — unseen curated or cached
    /// prefetch, side-effect-free. Returns nil when procedural generation
    /// is required; callers follow up with `ensurePuzzleLoaded()`.
    private func pickInstantPuzzle(for difficulty: NonogramDifficulty) -> NonogramPuzzle? {
        var any: any RandomNumberGenerator = rng
        let p = NonogramPicker.nextInstant(
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
