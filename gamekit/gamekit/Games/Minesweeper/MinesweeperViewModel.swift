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

@Observable @MainActor
final class MinesweeperViewModel {

    // MARK: - Read-only state surface (every var is private(set))

    private(set) var board: MinesweeperBoard
    private(set) var gameState: MinesweeperGameState = .idle
    private(set) var difficulty: MinesweeperDifficulty
    private(set) var flaggedCount: Int = 0
    private(set) var timerAnchor: Date?               // nil = paused/idle/terminal (D-05)
    private(set) var pausedElapsed: TimeInterval = 0  // accumulator (D-06)
    private(set) var lossContext: LossContext?

    // MARK: - Difficulty-switch confirmation flow (D-10, RESEARCH Pitfall 4)

    /// Bound to `.alert(isPresented:)` in MinesweeperGameView.
    /// Mutable (not `private(set)`) so the alert binding can dismiss on user choice.
    var showingAbandonAlert: Bool = false
    private(set) var pendingDifficultyChange: MinesweeperDifficulty?

    // MARK: - Injection seams (test-friendly defaults)

    private let userDefaults: UserDefaults
    private let clock: () -> Date          // injectable for deterministic tests of timer math
    private var rng: any RandomNumberGenerator

    // MARK: - Derived presentations (no caching — recomputed per access)

    var minesRemaining: Int {
        board.mineCount - flaggedCount
    }

    /// Wall-clock elapsed at the moment of access. Used by the end-state
    /// card after the timer freezes (D-08). System-clock-rollback safe:
    /// negative deltas clamp to 0 (RESEARCH §Pattern 2).
    var frozenElapsed: TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, clock().timeIntervalSince(anchor))
    }

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
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.userDefaults = userDefaults
        self.clock = clock
        self.rng = rng

        let resolved: MinesweeperDifficulty = difficulty
            ?? MinesweeperDifficulty(rawValue: userDefaults.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy
        self.difficulty = resolved
        self.board = Self.idleBoard(for: resolved)
    }

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

        // Engines are mutually exclusive (P2 verified — WinDetector.swift:42).
        if WinDetector.isLost(board) {
            if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
                gameState = .lost(mineIdx: mineIdx)
                lossContext = computeLossContext()
            }
            freezeTimer()
        } else if WinDetector.isWon(board) {
            gameState = .won
            freezeTimer()
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
        case .revealed, .mineHit:
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

    /// scenePhase .background path (D-06). No-op outside .playing.
    func pause() {
        guard case .playing = gameState, let anchor = timerAnchor else { return }
        pausedElapsed += max(0, clock().timeIntervalSince(anchor))
        timerAnchor = nil
    }

    /// scenePhase .active path (D-06). No-op outside .playing.
    /// Idempotent — calling twice without a pause in between is a no-op.
    func resume() {
        guard case .playing = gameState, timerAnchor == nil else { return }
        timerAnchor = clock()
    }

    // MARK: - Private helpers

    private func freezeTimer() {
        if let anchor = timerAnchor {
            pausedElapsed += max(0, clock().timeIntervalSince(anchor))
        }
        timerAnchor = nil
    }

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

    // MARK: - Constants

    /// UserDefaults key per D-11 — locked at "mines.lastDifficulty".
    /// Renaming = data break for any user who already played a game.
    static let lastDifficultyKey = "mines.lastDifficulty"
}
