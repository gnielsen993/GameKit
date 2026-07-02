//
//  StackEngineTests.swift
//  gamekitTests
//
//  Determinism + edge-case suite for StackEngine. Locked Wave 0 gate — covers
//  STACK-01/02/03 mechanics, SC2 ProMotion equivalence, and the 3D footprint
//  model (alternating slide axes, per-axis trims).
//
//  nonisolated: engine is Foundation-only; no actor isolation needed
//  (mirrors MergeEngineTests.swift convention, 02-04 nonisolated lesson).
//

import Testing
import Foundation
@testable import gamekit

@Suite("StackEngine determinism")
nonisolated struct StackEngineTests {

    // MARK: - Helpers

    /// Advance engine in 1 ms steps until the sliding block is within half the
    /// perfect-tolerance of the top block's center on the ACTIVE axis, then
    /// drop (dt=0 to hold position). Uses inout so the caller's engine is mutated.
    private func landPerfect(engine: inout StackEngine, cfg: StackConfig) -> StackFrame {
        let top = engine.placed.last!
        func offset(_ f: StackFrame) -> Double {
            f.axis == .x ? abs(f.currentCenterX - top.centerX)
                         : abs(f.currentCenterZ - top.centerZ)
        }
        var f = engine.step(dt: 0.001, input: StackInput(drop: false))
        var attempts = 0
        while offset(f) > cfg.perfectTolerance * 0.5 && attempts < 10_000 {
            f = engine.step(dt: 0.001, input: StackInput(drop: false))
            attempts += 1
        }
        return engine.step(dt: 0, input: StackInput(drop: true))
    }

    // MARK: - SC2: ProMotion equivalence

    /// SC2: same fixed config, drops at center-crossing step counts, dt=1/60 vs dt=1/120
    /// over 5 simulated seconds ⇒ identical score / gameOver / tower footprints.
    ///
    /// Design: all 5 drops are scheduled at center-crossing steps — blockElapsed ≈
    /// 0.25/oscSpeed at each block's speed — so the active-axis center falls at the
    /// exact oscillation midpoint (offset ≈ 0.0006–0.002, all << perfectTolerance=0.025).
    /// For PERFECT drops, the footprint is inherited (no center-dependent FP
    /// arithmetic), so extents are bit-exact equal regardless of the ULP-scale
    /// difference in accumulated blockElapsed between runs.
    ///
    /// Keystone: a velocity-bounce model would shift the oscillation phase at each reflection
    /// point by a dt-dependent error, producing different centers and thus different drop
    /// types (perfect vs trim) between 60 Hz and 120 Hz. Closed-form tri() prevents this.
    @Test("ProMotion equivalence: 60 Hz step stream ≡ 120 Hz step stream")
    func proMotionEquivalence() {
        // 60-Hz cumulative drop steps targeting center crossings per block.
        // Derivation: step = round(0.25/oscSpeed_N * 60) where oscSpeed_N = rampSpeed(N).
        //   Block 1: oscSpeed=0.35,        step≈43  (cumulative 43)
        //   Block 2: oscSpeed=0.36375,     step≈41  (cumulative 84)
        //   Block 3: oscSpeed=0.370625,    step≈40  (cumulative 124)
        //   Block 4: oscSpeed=0.3775,      step≈40  (cumulative 164)
        //   Block 5: oscSpeed=0.384375,    step≈39  (cumulative 203)
        // 120-Hz: multiply each by 2 ([86, 168, 248, 328, 406]).
        let dropStepsAt60: [Int] = [43, 84, 124, 164, 203]

        func run(fixedDt: Double) -> StackEngine {
            var e = StackEngine(cfg: .testFixed)
            let ratio = fixedDt == 1.0 / 60.0 ? 1 : 2
            let dropSteps = Set(dropStepsAt60.map { $0 * ratio })
            let totalSteps = Int((5.0 / fixedDt).rounded())
            for step in 1...totalSteps {
                _ = e.step(dt: fixedDt, input: StackInput(drop: dropSteps.contains(step)))
            }
            return e
        }

        let a = run(fixedDt: 1.0 / 60.0)
        let b = run(fixedDt: 1.0 / 120.0)
        #expect(a.score == b.score)
        #expect(a.gameOver == b.gameOver)
        #expect(a.placed.map(\.width) == b.placed.map(\.width))
        #expect(a.placed.map(\.depth) == b.placed.map(\.depth))
    }

    // MARK: - 3D footprint: axis alternation + per-axis trims

    /// Slide axis alternates X → Z → X per placement, and an imperfect drop
    /// trims ONLY the axis the block was travelling along — the other extent
    /// carries over unchanged.
    @Test("axes alternate per placement; a trim only cuts the active axis")
    func axisAlternationAndPerAxisTrim() {
        let cfg = StackConfig.testFixed
        var engine = StackEngine(cfg: cfg)

        // Block 1 slides on X. Drop at blockElapsed=0 (extreme edge) → X trim.
        let f1 = engine.step(dt: 0, input: StackInput(drop: true))
        #expect(f1.event == .trim(overhangWidth: engine.cfg.startingWidth
                                    - engine.placed.last!.width, axis: .x))
        #expect(engine.placed.last!.width < cfg.startingWidth, "X trim narrows width")
        #expect(engine.placed.last!.depth == cfg.startingDepth, "Z extent untouched by an X trim")
        #expect(f1.axis == .z, "next slider travels along Z")

        // Block 2 slides on Z. Extreme drop → Z trim; width carries over.
        let widthAfterX = engine.placed.last!.width
        let f2 = engine.step(dt: 0, input: StackInput(drop: true))
        if case .trim(_, let axis) = f2.event {
            #expect(axis == .z)
        } else {
            Issue.record("expected a Z-axis trim, got \(f2.event)")
        }
        #expect(engine.placed.last!.depth < cfg.startingDepth, "Z trim narrows depth")
        #expect(engine.placed.last!.width == widthAfterX, "X extent untouched by a Z trim")
        #expect(f2.axis == .x, "axis alternates back to X")
    }

    // MARK: - STACK-01: complete miss ends the run

    /// Drive drops at blockElapsed=0 (extreme edge positions) to narrow the
    /// footprint until a complete miss (overlap ≤ minWidth). With alternating
    /// axes each extreme drop trims one dimension, so the run must still end
    /// within a bounded number of drops.
    @Test("complete miss (no overlap) ends the run")
    func completeMissGameOver() {
        var engine = StackEngine(cfg: .testFixed)

        var missFrame: StackFrame?
        for _ in 0..<20 {
            let f = engine.step(dt: 0, input: StackInput(drop: true))
            if f.event == .miss { missFrame = f; break }
        }
        #expect(missFrame != nil, "extreme drops must reach a complete miss within 20 drops")
        #expect(engine.gameOver)

        // Both dimensions were narrowed on the way down.
        let top = engine.placed.last!
        #expect(top.width < engine.cfg.startingWidth)
        #expect(top.depth < engine.cfg.startingDepth)

        // Post-gameOver steps are no-ops (gameOver guard returns .none)
        let noOp = engine.step(dt: 1.0, input: StackInput(drop: true))
        #expect(noOp.event == .none)
        #expect(noOp.gameOver)
    }

    // MARK: - STACK-03 / D-01: streak-based footprint recovery

    /// N consecutive perfects regrow the footprint only after reaching
    /// streakThreshold. One imperfect resets streak to 0 with no recovery.
    @Test("N consecutive perfects expand the footprint; one imperfect resets streak")
    func streakRecoveryAndReset() {
        let cfg = StackConfig.testFixed
        var engine = StackEngine(cfg: cfg)

        // Phase A: one trim drop at blockElapsed=0 to bring width below startingWidth
        _ = engine.step(dt: 0, input: StackInput(drop: true))
        let narrowedWidth = engine.placed.last!.width
        #expect(narrowedWidth < cfg.startingWidth, "trim must narrow below startingWidth")
        #expect(engine.streak == 0)

        // Phase B: (streakThreshold - 1) perfect drops — footprint must NOT expand yet
        for _ in 0..<(cfg.streakThreshold - 1) {
            _ = landPerfect(engine: &engine, cfg: cfg)
        }
        #expect(engine.streak == cfg.streakThreshold - 1)
        #expect(engine.placed.last!.width == narrowedWidth,
                "width must stay unchanged before streak threshold is reached")

        // Phase C: Nth perfect — footprint MUST expand (D-01 streak threshold)
        _ = landPerfect(engine: &engine, cfg: cfg)
        let expandedWidth = engine.placed.last!.width
        #expect(expandedWidth > narrowedWidth, "width expands after N consecutive perfects")
        #expect(expandedWidth <= cfg.startingWidth, "width never exceeds startingWidth cap")
        #expect(engine.placed.last!.depth <= cfg.startingDepth, "depth never exceeds startingDepth cap")
        #expect(engine.streak == cfg.streakThreshold)

        // Phase D: one imperfect (drop at blockElapsed=0 → extreme, imperfect position)
        _ = engine.step(dt: 0, input: StackInput(drop: true))
        #expect(engine.streak == 0, "broken streak resets to 0 with no recovery (D-01)")
    }

    // MARK: - STACK-02: speed plateau

    /// Speed plateaus at plateauScore — rampSpeed(80) == rampSpeed(200).
    @Test("speed plateaus after plateauScore")
    func rampSpeedPlateau() {
        let engine = StackEngine(cfg: .testFixed)
        #expect(engine.rampSpeed(forScore: 80) == engine.rampSpeed(forScore: 200))
    }
}
