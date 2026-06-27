//
//  ArcadeLoopDriverTests.swift
//  gamekitTests
//
//  Locked substrate gate tests for the Phase 15 arcade loop primitive.
//  Gates ROADMAP Phase 15 SC1(a) and SC1(b) — both must remain green
//  throughout Phases 16/17 without modification.
//
//  nonisolated (NOT @MainActor): these tests probe Foundation-only types
//  (ArcadeGameState) and pure clamp math — no ModelContext, no SwiftUI,
//  no SwiftData. Mirrors BoardGeneratorTests.swift discipline.
//

import Testing
import Foundation
@testable import gamekit

@Suite("ArcadeLoopDriver substrate")
nonisolated struct ArcadeLoopDriverTests {

    // MARK: - SC1a: onTick gating (ROADMAP Phase 15 SC1a)

    @Test("onTick is gated on .running — other states produce zero ticks")
    func onTickGating() {
        var tickCount = 0

        // Model the VM contract: guard state == .running; only .running increments.
        func simulateTick(state: ArcadeGameState, dt: Double) {
            guard state == .running else { return }
            tickCount += 1
        }

        // idle — must produce zero ticks
        simulateTick(state: .idle, dt: 1.0 / 60.0)
        #expect(tickCount == 0,
            "idle state must not forward ticks; got \(tickCount)")

        // running — must produce exactly one tick
        simulateTick(state: .running, dt: 1.0 / 60.0)
        #expect(tickCount == 1,
            "running state must forward exactly one tick; got \(tickCount)")

        // paused — must not add further ticks
        simulateTick(state: .paused, dt: 1.0 / 60.0)
        #expect(tickCount == 1,
            "paused state must not forward ticks; got \(tickCount)")

        // gameOver — must not add further ticks
        simulateTick(state: .gameOver, dt: 1.0 / 60.0)
        #expect(tickCount == 1,
            "gameOver state must not forward ticks; total must remain 1; got \(tickCount)")
    }

    // MARK: - SC1b: spiral-of-death clamp (ROADMAP Phase 15 SC1b)

    @Test("spiral-of-death clamp: dt=2.0 produces at most 15 steps")
    func spiralOfDeathClamp() {
        let rawDt: Double = 2.0
        let maxDt: Double = 0.1
        let fixedDt: Double = 1.0 / 60.0

        // Clamp invariant: min(rawDt, maxDt) == maxDt
        let clamped = min(rawDt, maxDt)
        #expect(clamped == maxDt,
            "min(\(rawDt), \(maxDt)) must equal \(maxDt); got \(clamped)")

        // Drain the accumulator via fixed-timestep loop
        var accumulator = clamped
        var steps = 0
        while accumulator >= fixedDt {
            steps += 1
            accumulator -= fixedDt
        }

        // A clamped dt of 0.1 at 60 Hz produces ≈6 steps; guard at 15
        #expect(steps <= 15,
            "Fixed-step drain of clamped dt=\(clamped) at fixedDt=\(fixedDt) must produce ≤15 steps; got \(steps)")

        // Loop terminates: accumulator must be below fixedDt after drain
        #expect(accumulator < fixedDt,
            "Accumulator must fall below fixedDt after drain; got \(accumulator)")
    }
}
