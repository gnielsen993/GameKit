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
    /// Trigger counter for milestone-strength feedback on each merge.
    /// Bumped once per slide that produced any merges (not per individual merge —
    /// a single swipe with two merges fires one haptic per the canonical
    /// `.sensoryFeedback` value-change semantic).
    private(set) var mergeCount: Int = 0
    /// Trigger counter for valid slides that do not merge. Kept separate from
    /// `mergeCount` so one swipe produces exactly one feedback class.
    private(set) var slideCount: Int = 0
    /// Trigger counter for the optional .winSweep / .gameOver effects.
    private(set) var terminalCount: Int = 0
    /// Highest tile value on the board, surfaced for the header bar.
    var maxTile: Int { board.maxValue }

    // MARK: - Injection seams

    private let userDefaults: UserDefaults
    private var rng: any RandomNumberGenerator
    private(set) var gameStats: GameStats?
    private(set) var pendingSaveState: MergeSaveState?

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
        // Auto-populate the initial board so the user lands on something to
        // play, not an empty grid. The original "first-swipe spawns the
        // board" pattern read as broken — a swipe against an empty board
        // doesn't communicate that it both *creates* and *moves* tiles.
        //
        // Two-step init to satisfy Swift's "self fully initialized before
        // inout self.rng" rule: assign `.empty` first, then re-assign with
        // the spawned board.
        self.board = .empty
        self.board = BoardSpawner.initial(rng: &self.rng)
        self.state = .playing
    }

    // MARK: - GameStats injection (lazy, one-shot)

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
        checkAndLoadOrRestoreState()
    }

    // MARK: - Public API

    /// Apply a swipe. The initial board is now spawned at VM init / restart
    /// so the user always lands on a populated grid; the historical
    /// `.idle` first-swipe-spawns-the-board branch was removed.
    func handleSwipe(_ direction: SwipeDirection) {
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
        if result.merges.isEmpty {
            slideCount += 1
        } else {
            mergeCount += 1
        }

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
        } else {
            saveCurrentState()
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
    /// Re-spawns the initial 2-tile board (matches VM init) so the player
    /// can act immediately without an extra swipe.
    func restart() {
        clearSavedState()
        board = BoardSpawner.initial(rng: &rng)
        score = 0
        state = .playing
        hasContinuedPastWin = false
        mergeCount = 0
        slideCount = 0
        terminalCount = 0
    }

    /// Direct mode setter — used by `confirmModeChange()` after the user
    /// approves abandoning their in-progress board. View callers should
    /// route through `requestModeChange(_:)` so the abandon alert fires
    /// when there's actual progress to lose.
    func setMode(_ newMode: MergeMode) {
        guard newMode != mode else { return }
        mode = newMode
        userDefaults.set(newMode.rawValue, forKey: Self.lastModeKey)
        restart()
    }

    // MARK: - Mode-change confirmation flow (mirrors Minesweeper's
    // difficulty-change abandon alert)

    /// Bound to `.alert(isPresented:)` in MergeGameView. Mutable (not
    /// `private(set)`) so the alert binding can dismiss on user choice.
    var showingAbandonAlert: Bool = false
    private(set) var pendingModeChange: MergeMode?

    /// View callers go through here so a mid-game mode swap pops the
    /// abandon alert instead of immediately blowing away the score.
    /// "Mid-game" = the player has scored at least one merge. Score 0
    /// means they haven't made meaningful progress, so apply immediately.
    func requestModeChange(_ newMode: MergeMode) {
        guard newMode != mode else { return }
        if score > 0 {
            pendingModeChange = newMode
            showingAbandonAlert = true
        } else {
            setMode(newMode)
        }
    }

    /// User confirmed Abandon in the alert — apply the pending change.
    func confirmModeChange() {
        guard let target = pendingModeChange else {
            showingAbandonAlert = false
            return
        }
        pendingModeChange = nil
        showingAbandonAlert = false
        setMode(target)
    }

    /// User tapped Cancel — keep the in-progress game.
    func cancelModeChange() {
        pendingModeChange = nil
        showingAbandonAlert = false
    }

    // MARK: - Private

    /// Writes a GameRecord (with `score`) at terminal state. Best-effort —
    /// failure logs inside GameStats and gameplay UI continues to render.
    private func recordTerminal(outcome: Outcome) {
        clearSavedState()
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

    // MARK: - Save state

    func checkAndLoadOrRestoreState() {
        let key = MergeSaveState.key(mode: mode)
        if let data = userDefaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(MergeSaveState.self, from: data) {
            pendingSaveState = saved
        }
    }

    func restoreState(_ saved: MergeSaveState) {
        guard let m = MergeMode(rawValue: saved.mode) else { discardSaveAndLoadNew(); return }
        board = saved.board
        score = saved.score
        mode = m
        hasContinuedPastWin = saved.hasContinuedPastWin
        state = .playing
        pendingSaveState = nil
    }

    func discardSaveAndLoadNew() {
        clearSavedState()
    }

    func saveCurrentState() {
        guard state == .playing || (state == .won && hasContinuedPastWin) else { return }
        let snapshot = MergeSaveState(
            board: board,
            score: score,
            mode: mode.rawValue,
            hasContinuedPastWin: hasContinuedPastWin,
            savedAt: Date.now
        )
        let key = MergeSaveState.key(mode: mode)
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: key)
        }
    }

    func clearSavedState() {
        userDefaults.removeObject(forKey: MergeSaveState.key(mode: mode))
        pendingSaveState = nil
    }

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
