//
//  MinesweeperViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator that turns the locked P2 engine API
//  (BoardGenerator + RevealEngine + WinDetector) into a UI-consumable state
//  surface. Owns timer state, scenePhase pause/resume math (D-05/D-06),
//  first-tap board generation (D-07), terminal-state freeze (D-08), and
//  difficulty persistence via UserDefaults `mines.lastDifficulty` (D-11).
//
//  Phase 3 invariants (per ARCHITECTURE Anti-Pattern 1, RESEARCH §Pattern 2):
//    - Foundation-only — no SwiftUI, no Combine, no SwiftData (animation
//      and persistence are view-tier and P4 concerns)
//    - @MainActor — all state mutation is single-threaded; the engines are
//      Sendable so this is safe by construction
//    - First-tap-safety preserved end-to-end (CLAUDE.md §8.11): the .idle
//      branch in reveal(at:) is the ONLY path that calls BoardGenerator.generate
//
//  File layout (split 2026-05-01 to clear §8.1 split-smell zone, was 472 LOC):
//    - This file: stored properties, init, core game-state methods (reveal,
//      toggleFlag, restart, setDifficulty, requestDifficultyChange,
//      confirmDifficultyChange, cancelDifficultyChange, computeLossContext,
//      idleBoard)
//    - MinesweeperViewModel+Timer.swift — frozenElapsed, pause, resume,
//      freezeTimer
//    - MinesweeperViewModel+Persistence.swift — attachGameStats,
//      recordTerminalState, lastDifficultyKey
//    - MinesweeperViewModel+InteractionMode.swift — toggleInteractionMode,
//      setInteractionMode, handleTap, handleLongPress
//

import Foundation
// The Observation module ships with the Swift 5.9+ stdlib; @Observable
// does not require an explicit import. (RESEARCH §Code Examples 1)

/// Outcome surface used by Plan 03's MinesweeperEndStateCard view.
/// Distinct from MinesweeperGameState which carries the trip-mine index.
enum GameOutcome: Equatable, Sendable { case win, loss }

/// Loss-context surface consumed by Plan 03's MinesweeperEndStateCard (D-03).
/// Modeled as a struct (Sendable, Equatable) instead of an inline tuple —
/// tuples are not Equatable in Swift, which would make the test assertions
/// fragile.
struct LossContext: Equatable, Sendable {
    let minesHit: Int
    let safeCellsRemaining: Int
}

/// Interaction-mode toggle for Minesweeper (CONTEXT D-06 / D-11 — Phase 6.1).
///
/// `.reveal` = MINES-02 default (tap reveals, long-press flags).
/// `.flag`   = inverted (tap toggles flag, long-press reveals — long-press
///             always escapes the current mode regardless of which one).
///
/// `Codable` conformance is forward-looking — D-08 declined the UserDefaults
/// persistence option for v1.0.x, so the enum is never persisted today;
/// adding `Codable` has zero runtime cost and lets a future v1.0.x plan
/// flip on persistence without a source-level migration (RESEARCH §Pattern 5).
enum MinesweeperInteractionMode: String, Sendable, Equatable, Codable {
    case reveal
    case flag
}

@Observable @MainActor
final class MinesweeperViewModel {

    // MARK: - Read-only state surface (every var is private(set))

    private(set) var board: MinesweeperBoard
    private(set) var gameState: MinesweeperGameState = .idle
    private(set) var difficulty: MinesweeperDifficulty
    private(set) var flaggedCount: Int = 0
    /// Treated as read-only by external (view) callers; the Timer extension
    /// in the sibling file writes through internal access. Same applies to
    /// `pausedElapsed`, `gameStats`, `interactionMode`, `modeToggleCount`
    /// below — Swift `private(set)` does not cross file boundaries, so
    /// these intentionally drop to module-internal write access.
    var timerAnchor: Date?               // nil = paused/idle/terminal (D-05)
    var pausedElapsed: TimeInterval = 0  // accumulator (D-06)
    private(set) var lossContext: LossContext?

    /// Interaction-mode toggle (CONTEXT D-06 / D-11 — Phase 6.1).
    /// Defaults to `.reveal` and is reset to `.reveal` by every `restart()`
    /// (D-08 — no UserDefaults persistence). View-tier mode-routing logic
    /// lives in `handleTap(at:)` / `handleLongPress(at:)`; the cell view
    /// never branches on mode itself (CLAUDE.md §1 lightweight MVVM,
    /// ARCHITECTURE Anti-Pattern 1).
    var interactionMode: MinesweeperInteractionMode = .reveal

    // MARK: - P5 animation orchestration (CONTEXT D-05/D-06)
    //
    // Animation orchestration state — drives BoardView/CellView/GameView
    // animation modifiers. VM owns NO `Animation` types and NO
    // `withAnimation` calls (D-05 invariant). Transitions are set
    // ATOMICALLY alongside `gameState` mutations in reveal / toggleFlag /
    // restart so the view tier observes a single coherent (gameState,
    // phase) tuple change per `.onChange(of: vm.phase)` cycle.
    //
    // Foundation-only — `MinesweeperPhase` is itself Foundation-only per
    // Plan 05-01 SUMMARY; extending the VM with these properties does not
    // introduce SwiftUI/Combine/SwiftData (verified by P3
    // `vmSourceFile_importsOnlyFoundation` structural test).

    /// Animation phase published to the view tier (CONTEXT D-05/D-06).
    /// View consumers: `MinesweeperBoardView` (`.transition` cascade),
    /// `MinesweeperGameView` (`.phaseAnimator` win wash + `.keyframeAnimator`
    /// loss shake + `.onChange(of: vm.phase)` Haptics/SFX orchestration).
    private(set) var phase: MinesweeperPhase = .idle

    /// Trigger counter for `.sensoryFeedback(.selection)` on cell reveal
    /// (CONTEXT D-07). Bumped after each successful reveal that mutates the
    /// board (RevealEngine returns at least one revealed cell). Idempotent
    /// reveal of an already-revealed cell does NOT bump — gating is on the
    /// meaningful state transition, not the call (Plan 05-06 Test 6).
    private(set) var revealCount: Int = 0

    /// Trigger counter for `.sensoryFeedback(.impact(.light))` on flag
    /// toggle (CONTEXT D-07) AND `.symbolEffect(.bounce, value:)` flag
    /// spring (CONTEXT D-04). Bumped on every successful flag state
    /// transition (`.hidden ↔ .flagged`). Toggle attempts on `.revealed`
    /// or `.mineHit` cells are no-ops and do NOT bump (P3 D-19 preserved).
    private(set) var flagToggleCount: Int = 0

    /// Trigger counter for `.sensoryFeedback(.impact(.light))` on the
    /// mode-toggle FAB (CONTEXT D-09 — Phase 6.1). Bumped on every
    /// `toggleInteractionMode()` call. Reset on `restart()` for symmetry
    /// with `revealCount` and `flagToggleCount` (RESEARCH open question #3 —
    /// `.sensoryFeedback` is value-change-driven, so resetting to 0 still
    /// fires the haptic on the first post-restart toggle when the value
    /// flips 0 → 1). Treated as read-only by external callers; the
    /// InteractionMode extension writes through internal access.
    var modeToggleCount: Int = 0

    // MARK: - Difficulty-switch confirmation flow (D-10, RESEARCH Pitfall 4)

    /// Bound to `.alert(isPresented:)` in MinesweeperGameView.
    /// Mutable (not `private(set)`) so the alert binding can dismiss on user choice.
    var showingAbandonAlert: Bool = false
    private(set) var pendingDifficultyChange: MinesweeperDifficulty?

    // MARK: - Injection seams (test-friendly defaults)

    /// Module-internal access (was `private`) so the Timer / Persistence /
    /// InteractionMode extensions in sibling files can read these injection
    /// seams. External callers should not touch them.
    let userDefaults: UserDefaults
    let clock: () -> Date          // injectable for deterministic tests of timer math
    var rng: any RandomNumberGenerator

    /// Persistence boundary — VM does NOT import SwiftData. GameStats is
    /// forward-resolved within the gamekit module (RESEARCH §Code Examples 4
    /// line 1131; ARCHITECTURE Anti-Pattern 1). Constructed in
    /// MinesweeperGameView.body via .task using @Environment(\.modelContext);
    /// attached via attachGameStats(_:) one-shot per scene (RESEARCH Pitfall 8).
    /// Treated as read-only by external callers; Persistence extension writes.
    var gameStats: GameStats?

    // MARK: - Derived presentations (no caching — recomputed per access)

    var minesRemaining: Int {
        board.mineCount - flaggedCount
    }

    // `frozenElapsed` lives in MinesweeperViewModel+Timer.swift.

    var terminalOutcome: GameOutcome? {
        switch gameState {
        case .won:   return .win
        case .lost:  return .loss
        default:     return nil
        }
    }

    // MARK: - Init

    /// - Parameters:
    ///   - difficulty: explicit override; if nil, reads from `userDefaults` (D-11) or falls back to .easy.
    ///   - userDefaults: injection seam — tests pass an isolated suite; production passes `.standard`.
    ///   - clock: injection seam — tests pin time, production uses `Date.now`.
    ///   - rng: injection seam — tests pass `SeededGenerator(seed:)` for determinism, production passes `SystemRandomNumberGenerator()`.
    init(
        difficulty: MinesweeperDifficulty? = nil,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { Date.now },
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        gameStats: GameStats? = nil                  // NEW (D-14, RESEARCH §Code Examples 4)
    ) {
        self.userDefaults = userDefaults
        self.clock = clock
        self.rng = rng
        self.gameStats = gameStats

        let resolved: MinesweeperDifficulty = difficulty
            ?? MinesweeperDifficulty(rawValue: userDefaults.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy
        self.difficulty = resolved
        self.board = Self.idleBoard(for: resolved)
    }

    // `attachGameStats(_:)` lives in MinesweeperViewModel+Persistence.swift.

    // MARK: - Public API consumed by views

    /// First reveal generates the populated board (first-tap-safe per CLAUDE.md §8.11)
    /// and starts the timer atomically (D-07). Subsequent reveals delegate to
    /// RevealEngine. Terminal-state detection runs after every reveal pass.
    func reveal(at index: MinesweeperIndex) {
        // First-tap branch — the ONLY path that calls BoardGenerator.generate.
        // Per CLAUDE.md §8.11 first-tap safety is P0; if a future contributor
        // adds another generate() call site outside this branch, the engine
        // contract is broken — this is the firewall.
        if case .idle = gameState {
            board = BoardGenerator.generate(
                difficulty: difficulty,
                firstTap: index,
                rng: &rng
            )
            gameState = .playing
            timerAnchor = clock()
            pausedElapsed = 0
        }
        guard case .playing = gameState else { return }

        let result = RevealEngine.reveal(at: index, on: board)
        board = result.board

        // P5 D-05/D-06: publish the engine-ordered reveal list as the
        // animation phase. Idempotent reveal (engine returns []) does not
        // bump the trigger counter — gating is on meaningful transitions
        // per Plan 05-06 Test 6.
        if !result.revealed.isEmpty {
            phase = .revealing(cells: result.revealed)
            revealCount += 1
        }

        // Engines are mutually exclusive (P2 verified — WinDetector.swift:42).
        // Ordering lock: gameState → phase → freezeTimer → recordTerminalState.
        // The phase set lives BETWEEN gameState and freezeTimer so SwiftData
        // failure logging in recordTerminalState cannot intercept the phase
        // change (Plan 05-06 PATTERNS line 106).
        if WinDetector.isLost(board) {
            if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
                gameState = .lost(mineIdx: mineIdx)
                lossContext = computeLossContext()
                phase = .lossShake(mineIdx: mineIdx)     // P5 D-06
            }
            freezeTimer()
            recordTerminalState(outcome: .loss)         // NEW (D-15)
        } else if WinDetector.isWon(board) {
            gameState = .won
            phase = .winSweep                            // P5 D-06
            freezeTimer()
            recordTerminalState(outcome: .win)          // NEW (D-15)
        }
    }

    /// Toggle a flag at `index`. No-op outside `.playing` and on already-revealed
    /// or `.mineHit` cells (per CONTEXT D-15 — "flags are intentional commitments").
    func toggleFlag(at index: MinesweeperIndex) {
        guard case .playing = gameState else { return }
        let cell = board.cell(at: index)
        switch cell.state {
        case .hidden:
            board = board.replacingCell(
                at: index,
                with: MinesweeperCell(
                    isMine: cell.isMine,
                    adjacentMineCount: cell.adjacentMineCount,
                    state: .flagged
                )
            )
            flaggedCount += 1
            // P5 D-06: publish flag spring phase + bump trigger counter.
            // Both directions (.hidden→.flagged AND .flagged→.hidden) bump
            // because the .symbolEffect(.bounce) flag spring fires on every
            // user-initiated flag commitment per CONTEXT D-07.
            phase = .flagging(idx: index)
            flagToggleCount += 1
        case .flagged:
            board = board.replacingCell(
                at: index,
                with: MinesweeperCell(
                    isMine: cell.isMine,
                    adjacentMineCount: cell.adjacentMineCount,
                    state: .hidden
                )
            )
            flaggedCount -= 1
            phase = .flagging(idx: index)                // P5 D-06
            flagToggleCount += 1                         // P5 D-07
        case .revealed, .mineHit:
            // P3 D-19 preserved — rejected toggle does NOT mutate phase or
            // bump flagToggleCount (Plan 05-06 Test "toggleFlag_onRevealedCell").
            return
        }
    }

    /// Same difficulty, fresh idle board. Timer / pausedElapsed / lossContext reset.
    func restart() {
        board = Self.idleBoard(for: difficulty)
        gameState = .idle
        flaggedCount = 0
        timerAnchor = nil
        pausedElapsed = 0
        lossContext = nil
        // P5 D-06 — animation orchestration reset alongside game-state reset.
        // Triggers (revealCount / flagToggleCount) reset to 0 so the next
        // session's .sensoryFeedback / .symbolEffect counters start clean.
        phase = .idle
        revealCount = 0
        flagToggleCount = 0
        // CONTEXT D-08 — Phase 6.1: mode resets to .reveal on every restart.
        // No UserDefaults persistence (D-08 declined the persistence option);
        // modeToggleCount resets for symmetry with the other trigger counters.
        interactionMode = .reveal
        modeToggleCount = 0
    }

    /// Direct setter — internal callers (confirmDifficultyChange, init paths) use this.
    /// Plan 03 view callers should use `requestDifficultyChange(_:)` so the alert flow runs.
    func setDifficulty(_ d: MinesweeperDifficulty) {
        difficulty = d
        userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
        restart()
    }

    /// View callers go through here so the mid-game alert (D-10) can interpose
    /// on `.playing` state. From idle / won / lost the change applies immediately.
    func requestDifficultyChange(_ d: MinesweeperDifficulty) {
        guard d != difficulty else { return }
        switch gameState {
        case .playing:
            pendingDifficultyChange = d
            showingAbandonAlert = true
        case .idle, .won, .lost:
            setDifficulty(d)
        }
    }

    /// User confirmed Abandon in the alert — apply the pending change.
    func confirmDifficultyChange() {
        guard let d = pendingDifficultyChange else {
            showingAbandonAlert = false
            return
        }
        pendingDifficultyChange = nil
        showingAbandonAlert = false
        setDifficulty(d)
    }

    /// User tapped Cancel in the alert — keep the in-progress game.
    func cancelDifficultyChange() {
        pendingDifficultyChange = nil
        showingAbandonAlert = false
    }

    // `pause()` and `resume()` live in MinesweeperViewModel+Timer.swift.

    // Phase 6.1 (MINES-12) interaction-mode toggle + tap routing
    // (toggleInteractionMode, setInteractionMode, handleTap, handleLongPress)
    // lives in MinesweeperViewModel+InteractionMode.swift.

    // MARK: - Private helpers

    // `recordTerminalState(outcome:)` lives in MinesweeperViewModel+Persistence.swift.
    // `freezeTimer()` lives in MinesweeperViewModel+Timer.swift.

    private func computeLossContext() -> LossContext {
        var minesHit = 0
        var safeCellsRemaining = 0
        for cell in board.cells {
            if cell.state == .mineHit { minesHit += 1 }
            if !cell.isMine && cell.state != .revealed { safeCellsRemaining += 1 }
        }
        return LossContext(minesHit: minesHit, safeCellsRemaining: safeCellsRemaining)
    }

    private static func idleBoard(for d: MinesweeperDifficulty) -> MinesweeperBoard {
        // Pre-first-tap: empty cells. BoardGenerator.generate is called on the
        // first reveal; this initial board is replaced wholesale at that point.
        // Using a placeholder (all isMine: false, adjacency: 0) is fine because
        // no logic reads from it before the first tap (.idle state is checked first).
        MinesweeperBoard(
            difficulty: d,
            cells: Array(
                repeating: MinesweeperCell(isMine: false, adjacentMineCount: 0),
                count: d.cellCount
            )
        )
    }

    // `lastDifficultyKey` lives in MinesweeperViewModel+Persistence.swift.
}
