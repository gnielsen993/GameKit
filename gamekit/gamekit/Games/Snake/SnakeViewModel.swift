//
//  SnakeViewModel.swift
//  gamekit
//
//  @Observable @MainActor bridge between ArcadeLoopDriver and SnakeEngine.
//  Owns the fixed-timestep accumulator (1/60s), the capacity-2 direction
//  queue with 180° reversal rejection (SNAKE-03 / SC4), event counters for
//  counter-trigger haptics, GameStats one-shot injection, and wall-mode
//  state. Persistence call (game-over record) and wall-mode toggle methods
//  live in SnakeViewModel+Persistence.swift (Plan 17-03 Task 2).
//
//  SwiftData firewall: imports Foundation only. Holds GameStats? opaque
//  reference — never imports SwiftData (mirrors StackViewModel.swift).
//
//  CLAUDE.md §4: pure MVVM — engine is Foundation-only, VM is the
//  @MainActor bridge, view reads published state without touching the engine.
//

import Foundation

@Observable @MainActor
final class SnakeViewModel {

    // MARK: - State surface (private(set) per MergeViewModel discipline)

    /// Current lifecycle phase — Canvas and chrome observe this.
    private(set) var state: ArcadeGameState = .idle
    /// Latest engine snapshot — Canvas reads this each frame for body, food,
    /// cellMoveAlpha (Gaffer alpha for smooth cell-to-cell interpolation).
    private(set) var frame: SnakeFrame
    /// Body snapshot BEFORE the most-recent cell move — Gaffer interpolation
    /// anchor for SnakeBoardCanvas. Updated alongside `frame` in tick().
    private(set) var prevBody: [SnakeCell]
    /// Counter-trigger for .impact(.light, intensity:0.7) haptic on food eat (D-08).
    private(set) var eatCount: Int = 0
    /// Counter-trigger for .selection haptic on accepted direction enqueue (D-07).
    private(set) var enqueueCount: Int = 0
    /// Counter-trigger for .impact(.medium, intensity:1.0) haptic on new high
    /// score mid-run (D-09). Fires at most once per run.
    private(set) var highScoreCount: Int = 0
    /// SwiftData firewall: opaque GameStats reference (VM never imports SwiftData).
    private(set) var gameStats: GameStats?

    // MARK: - Wall mode + abandon alert (methods wired in Task 2)

    /// Bound to `.alert(isPresented:)` in SnakeGameView. Mutable (not
    /// `private(set)`) so the alert binding can dismiss on user choice.
    var showingAbandonAlert: Bool = false
    /// true = wall-death mode; false = toroidal wrap (default, D-12).
    /// Persisted under "snake.wallMode" in UserDefaults.
    private(set) var wallMode: Bool

    // MARK: - Private engine + accumulator

    private var engine: SnakeEngine
    private var accumulator: Double = 0
    private let fixedDt: Double           // sourced from SnakeConfig (1/60s)
    private var directionQueue: [SnakeDirection] = []
    private let maxQueueDepth = 2         // capacity-2 per RESEARCH Pattern 3
    private var didAttachStats = false    // one-shot guard for attachGameStats
    /// Persisted best score at the start of this run — used to detect the
    /// once-per-run high-score crossing for the D-09 haptic.
    private var bestScoreAtStart: Int = 0
    /// Prevents highScoreCount from firing more than once per run.
    private var didCrossHighScore = false

    // MARK: - Init

    init() {
        let wm = UserDefaults.standard.bool(forKey: "snake.wallMode")
        self.wallMode = wm
        var cfg = SnakeConfig.default
        cfg.wallMode = wm
        let eng = SnakeEngine(cfg: cfg)
        self.engine = eng
        self.fixedDt = cfg.fixedDt
        // Build the idle-state initial frame — cellMoveAlpha = 0, no event.
        self.frame = SnakeFrame(
            body: eng.body,
            prevBody: eng.body,
            food: eng.food,
            currentDirection: eng.currentDirection,
            score: 0,
            cellMoveAlpha: 0,
            gameOver: false,
            event: .none
        )
        self.prevBody = eng.body
    }

    // MARK: - Lifecycle (mirrors StackViewModel.swift discipline)

    func start() {
        accumulator = 0   // clear carry so a (re)start never replays stale time
        state = .running
    }

    func pause() {
        if state == .running { state = .paused }
    }

    func resume() {
        if state == .paused { state = .running }
    }

    func stop() {
        state = .idle
        accumulator = 0
    }

    // MARK: - Direction queue (SNAKE-03 / SC4)
    //
    // effectiveCurrent = directionQueue.last ?? engine.currentDirection (Pitfall 5):
    //   When the queue already holds a pending turn, 180° is judged against
    //   THAT turn — not the engine's current direction. This prevents a
    //   right→left tap (180° of a queued .right) from sneaking through.
    //
    // enqueueCount += 1 is INSIDE the guard (Pitfall 6):
    //   Rejected inputs (180° reversal, full queue) never fire the .selection
    //   haptic. The counter-trigger in the view collapses to 0 when haptics
    //   are disabled, preventing spurious feedback regardless.

    /// Returns true if the direction was accepted into the queue.
    /// A false return means the input was silently rejected (no haptic — D-07).
    @discardableResult
    func tryEnqueueDirection(_ dir: SnakeDirection) -> Bool {
        let effectiveCurrent = directionQueue.last ?? engine.currentDirection
        guard dir != effectiveCurrent.opposite else { return false }   // 180° reject
        guard directionQueue.count < maxQueueDepth else { return false } // capacity cap
        directionQueue.append(dir)
        enqueueCount += 1   // fires .selection haptic counter-trigger in view
        return true
    }

    // MARK: - Fixed-timestep tick
    // No dt clamp — ArcadeLoopDriver already clamps min(rawDt, 0.1) (ARCADE-02).
    // Pops one direction from the queue per cell move (not per fixed step).

    func tick(dt: Double) {
        guard state == .running else { return }
        accumulator += dt
        while accumulator >= fixedDt {
            // Pop one queued direction per cell move.
            let nextDir = directionQueue.isEmpty ? nil : directionQueue.removeFirst()
            let newFrame = engine.step(dt: fixedDt, nextDirection: nextDir)
            accumulator -= fixedDt
            // Gaffer anchor: update prevBody to the body BEFORE this cell move.
            prevBody = newFrame.prevBody
            frame = newFrame

            switch newFrame.event {
            case .ate:
                eatCount += 1
                // D-09: high-score crossing fires at most once per run.
                if newFrame.score > bestScoreAtStart && !didCrossHighScore {
                    highScoreCount += 1
                    didCrossHighScore = true
                }
            case .died, .none:
                break
            }

            // Game-over transition: persist score exactly once, then halt loop.
            // "endless" and "snake" are PERMANENT serialization keys — renaming = data break (D-12).
            if newFrame.gameOver {
                state = .gameOver
                try? gameStats?.record(
                    gameKind: .snake,
                    mode: "endless",    // PERMANENT KEY — D-12 data-break lock
                    outcome: .loss,     // snake runs always end in loss (no win state)
                    score: engine.score // food eaten count (SNAKE-05)
                )
                return   // halts the while loop; state != .running on next call
            }
        }
    }

    // MARK: - GameStats injection (lazy, one-shot; mirrors StackViewModel.swift)

    /// Called from SnakeGameView.task exactly once. Reads the persisted best
    /// score to seed the D-09 high-score crossing threshold for this run.
    func attachGameStats(_ stats: GameStats) {
        guard !didAttachStats else { return }
        didAttachStats = true
        gameStats = stats
        bestScoreAtStart = stats.bestScore(gameKind: .snake, mode: "endless")
    }

    // MARK: - Restart

    /// Resets engine, counters, and accumulator. Returns to .idle so the view
    /// shows the swipe-to-start affordance.
    func restart() {
        var cfg = SnakeConfig.default
        cfg.wallMode = wallMode
        engine = SnakeEngine(cfg: cfg, rng: SystemRandomNumberGenerator())
        accumulator = 0
        eatCount = 0
        enqueueCount = 0
        highScoreCount = 0
        directionQueue = []
        didCrossHighScore = false
        bestScoreAtStart = gameStats?.bestScore(gameKind: .snake, mode: "endless") ?? 0
        prevBody = engine.body
        frame = SnakeFrame(
            body: engine.body,
            prevBody: engine.body,
            food: engine.food,
            currentDirection: engine.currentDirection,
            score: 0,
            cellMoveAlpha: 0,
            gameOver: false,
            event: .none
        )
        state = .idle
    }

    // MARK: - Wall mode toggle methods (D-11 / D-12 — Task 2)

    /// Entry point for the toolbar "Wall mode" menu button.
    /// If a run is in progress (score > 0), surfaces the abandon alert.
    /// If no progress has been made, applies the toggle immediately.
    func requestWallModeToggle() {
        if engine.score > 0 {
            showingAbandonAlert = true
        } else {
            applyWallModeToggle()
        }
    }

    /// User confirmed Abandon — apply the wall-mode flip.
    func confirmWallModeChange() {
        showingAbandonAlert = false
        applyWallModeToggle()
    }

    /// User tapped Cancel — dismiss alert, keep in-progress game.
    func cancelWallModeChange() {
        showingAbandonAlert = false
    }

    /// Flips wallMode, persists to UserDefaults, and calls restart().
    /// "snake.wallMode" is a PERMANENT serialization key — renaming = data break (D-12).
    private func applyWallModeToggle() {
        wallMode.toggle()
        UserDefaults.standard.set(wallMode, forKey: "snake.wallMode")
        restart()
    }
}
