//
//  StackViewModel.swift
//  gamekit
//
//  @Observable @MainActor bridge between the arcade loop and the pure
//  StackEngine. Owns the fixed-timestep accumulator, latches tap input,
//  surfaces chrome state (score/streak/counters) as private(set), and
//  fires the single save-on-game-over persistence call.
//
//  SwiftData firewall: imports Foundation only. Holds GameStats? opaque
//  reference — never imports SwiftData (mirrors MergeViewModel.swift:16).
//

import Foundation

@Observable @MainActor
final class StackViewModel {

    // MARK: - State surface (private(set) per MergeViewModel discipline)

    private(set) var state: ArcadeGameState = .idle
    /// Latest engine snapshot — Canvas reads this each frame.
    private(set) var frame: StackFrame
    /// Counter-trigger for .impact(.medium) haptic on perfect drop (DESIGN §8.3).
    private(set) var perfectCount: Int = 0
    /// Counter-trigger for .impact(.light) haptic on trim drop (DESIGN §8.3).
    private(set) var dropCount: Int = 0
    /// SwiftData firewall: opaque GameStats reference (VM never imports SwiftData).
    private(set) var gameStats: GameStats?

    // MARK: - Tap input (writable from view; main-actor, no Sendable concern)

    /// Set to true by the view's .onTapGesture. Latched once per engine step,
    /// then cleared inside the accumulator loop so one tap = one engine step.
    var pendingDrop: Bool = false

    // MARK: - Private engine + accumulator

    private var engine: StackEngine
    private var accumulator: Double = 0
    private let fixedDt: Double          // sourced from StackConfig, not duplicated
    private var didAttachStats = false   // one-shot guard for attachGameStats

    // MARK: - Init

    init(cfg: StackConfig = .default) {
        self.engine = StackEngine(cfg: cfg)
        self.fixedDt = cfg.fixedDt
        // Initial frame mirrors the engine's seeded state (1 base block at centre).
        // Score = 1 because placed.count == 1 after StackEngine.init.
        self.frame = StackFrame(
            currentCenterX: cfg.playfieldCenter,
            currentWidth: cfg.startingWidth,
            score: 1,
            streak: 0,
            bestStreak: 0,
            gameOver: false,
            event: .none
        )
    }

    // MARK: - Lifecycle (mirrors StackHarnessVM.swift:54-70)

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

    // MARK: - Fixed-timestep tick
    // No dt clamp here — ArcadeLoopDriver already clamps raw dt upstream.

    func tick(dt: Double) {
        guard state == .running else { return }
        accumulator += dt
        while accumulator >= fixedDt {
            // Latch input then clear so exactly one engine step consumes the tap.
            let input = StackInput(drop: pendingDrop)
            pendingDrop = false
            let newFrame = engine.step(dt: fixedDt, input: input)
            accumulator -= fixedDt
            frame = newFrame

            // Counter-trigger haptics — view attaches .sensoryFeedback to these.
            // NOTE: no game-over counter — VideoModeBanner fires .error itself.
            switch newFrame.event {
            case .perfect:
                perfectCount += 1
            case .trim:
                dropCount += 1
            default:
                break
            }

            // Game-over transition: save exactly once, then exit (Pitfall 12).
            if newFrame.gameOver {
                state = .gameOver
                try? gameStats?.recordStackRun(
                    score: newFrame.score,
                    perfectStreak: newFrame.bestStreak
                )
                return   // halts the while loop; state != .running on next call
            }
        }
    }

    // MARK: - GameStats injection (lazy, one-shot; mirrors MergeViewModel.swift:79-83)

    func attachGameStats(_ stats: GameStats) {
        guard !didAttachStats else { return }
        didAttachStats = true
        gameStats = stats
    }

    // MARK: - Restart

    /// Resets engine, counters, and accumulator. Returns to .idle so the view
    /// shows the tap-to-start affordance (matches StackHarnessVM stop+start pattern).
    func restart() {
        engine = StackEngine(cfg: engine.cfg)
        accumulator = 0
        perfectCount = 0
        dropCount = 0
        pendingDrop = false
        frame = StackFrame(
            currentCenterX: engine.cfg.playfieldCenter,
            currentWidth: engine.cfg.startingWidth,
            score: 1,
            streak: 0,
            bestStreak: 0,
            gameOver: false,
            event: .none
        )
        state = .idle   // tap-to-start affordance re-shows after restart
    }
}
