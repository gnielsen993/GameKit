//
//  MergeViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator wiring the pure Merge engine
//  (MergeEngine + BoardSpawner + GameOverDetector) into a UI surface.
//  Mirrors MinesweeperViewModel discipline at MinesweeperViewModel.swift:52:
//    - Foundation-only (no SwiftUI / SwiftData / Combine)
//    - All public state `private(set)`
//    - GameStats is the SwiftData firewall — VM holds an optional reference
//      and never imports SwiftData directly.
//
//  Mode persistence: `merge.lastMode` in UserDefaults.
//

import Foundation

@Observable @MainActor
final class MergeViewModel {

    // MARK: - Read-only state surface

    private(set) var board: MergeBoard
    private(set) var score: Int = 0
    private(set) var bestScore: Int = 0
    private(set) var mode: MergeMode
    private(set) var state: MergeGameState = .idle
    /// True once the user has dismissed the win banner via `continuePastWin()`.
    /// Suppresses re-firing the win banner for every subsequent merge above 2048.
    private(set) var hasContinuedPastWin: Bool = false
    /// Trigger counter for `.sensoryFeedback(.impact(.light))` on each merge.
    /// Bumped once per slide that produced any merges (not per individual merge —
    /// a single swipe with two merges fires one haptic per the canonical
    /// `.sensoryFeedback` value-change semantic).
    private(set) var mergeCount: Int = 0
    /// Trigger counter for the optional .winSweep / .gameOver effects.
    private(set) var terminalCount: Int = 0
    /// Highest tile value on the board, surfaced for the header bar.
    var maxTile: Int { board.maxValue }

    // MARK: - Injection seams

    private let userDefaults: UserDefaults
    private var rng: any RandomNumberGenerator
    private(set) var gameStats: GameStats?

    // MARK: - Init

    init(
        mode: MergeMode? = nil,
        userDefaults: UserDefaults = .standard,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        gameStats: GameStats? = nil
    ) {
        self.userDefaults = userDefaults
        self.rng = rng
        self.gameStats = gameStats

        let resolved: MergeMode = mode
            ?? MergeMode(rawValue: userDefaults.string(forKey: Self.lastModeKey) ?? "")
            ?? .winMode
        self.mode = resolved
        self.board = .empty
    }

    // MARK: - GameStats injection (lazy, one-shot)

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
    }

    // MARK: - Public API

    /// Lazy first-spawn — the initial board is built on the first user
    /// gesture (mirrors Minesweeper's first-tap-safe pattern). No score or
    /// state mutation happens at .idle except the spawn + transition.
    func handleSwipe(_ direction: SwipeDirection) {
        if case .idle = state {
            board = BoardSpawner.initial(rng: &rng)
            state = .playing
            // First swipe IS a real swipe — fall through and apply slide
            // against the freshly spawned board.
        }

        // Block input on terminal states. `.won` is non-terminal in winMode
        // when the player has continued past it (`hasContinuedPastWin == true`).
        switch state {
        case .gameOver:
            return
        case .won where !hasContinuedPastWin:
            return
        default:
            break
        }

        let result = MergeEngine.slide(board, direction: direction)
        guard result.didChange else { return }

        // Spawn a new tile after the slide. Spawner.spawn returns nil only
        // if the board is full; slide.didChange == true implies at least
        // one cell was empty after compression, so this never returns nil
        // in practice — fall back to the slid board if it does.
        let spawned = BoardSpawner.spawn(into: result.board, rng: &rng) ?? result.board
        board = spawned

        score += result.scoreDelta
        if score > bestScore { bestScore = score }
        if !result.merges.isEmpty { mergeCount += 1 }

        // Win check (winMode only; suppress after continuePastWin).
        if mode == .winMode,
           !hasContinuedPastWin,
           GameOverDetector.hasReached2048(board) {
            state = .won
            terminalCount += 1
            recordTerminal(outcome: .win)
            return
        }

        // Game-over check applies in both modes.
        if GameOverDetector.isGameOver(board) {
            state = .gameOver
            terminalCount += 1
            recordTerminal(outcome: .loss)
        }
    }

    /// Dismiss the win banner and continue past 2048 (winMode only).
    /// No-op outside `.won`. After this, the win banner cannot re-fire
    /// in this session (re-set on `restart()`).
    func continuePastWin() {
        guard case .won = state else { return }
        hasContinuedPastWin = true
        state = .playing
    }

    /// Same mode, fresh board. Score / state / continuation flag reset.
    /// Best-score is session-local on the VM; persistence is via GameStats.
    func restart() {
        board = .empty
        score = 0
        state = .idle
        hasContinuedPastWin = false
        mergeCount = 0
        terminalCount = 0
    }

    /// Mode setter. Persists the new mode to UserDefaults and restarts the
    /// session — mid-session mode swaps would conflate score-board lineage.
    func setMode(_ newMode: MergeMode) {
        guard newMode != mode else { return }
        mode = newMode
        userDefaults.set(newMode.rawValue, forKey: Self.lastModeKey)
        restart()
    }

    // MARK: - Private

    /// Writes a GameRecord (with `score`) at terminal state. Best-effort —
    /// failure logs inside GameStats and gameplay UI continues to render.
    private func recordTerminal(outcome: Outcome) {
        try? gameStats?.record(
            gameKind: .merge,
            mode: mode.rawValue,
            outcome: outcome,
            score: score
        )
    }

    // MARK: - Constants

    /// UserDefaults key for the last-played mode. Renaming = data break.
    static let lastModeKey = "merge.lastMode"

    // MARK: - Test seam (#if DEBUG — do NOT call from production)

    #if DEBUG
    /// Test-only: shove a known board into the VM so tests can drive
    /// deterministic merge / win / game-over scenarios without scripting
    /// every spawn. Visible only via `@testable import gamekit`.
    func testHook_setBoard(_ board: MergeBoard) {
        self.board = board
    }
    #endif
}
