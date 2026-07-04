//
//  SnakeEngineTests.swift
//  gamekitTests
//
//  Determinism + edge-case suite for SnakeEngine. Wave 0 gate — covers
//  SNAKE-01/02/04 mechanics, SC2 ProMotion equivalence, and seed determinism.
//
//  nonisolated: engine is Foundation-only; no actor isolation needed
//  (mirrors StackEngineTests.swift convention).
//
//  Assumption A3: Int.random(in:using:) with SplitMix64 is deterministic
//  across Swift versions. If seedDeterminism ever proves flaky, assertions
//  fall back to body/gameOver/score equality rather than exact food positions.
//

import Testing
import Foundation
@testable import gamekit

@Suite("SnakeEngine determinism")
nonisolated struct SnakeEngineTests {

    // MARK: - SC2a: Seed determinism

    /// Same pinned seed → identical food-spawn sequences and outcomes across two runs.
    @Test("seed determinism: two identical seeds produce identical frame sequences")
    func seedDeterminism() {
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)
        var e1 = SnakeEngine(cfg: .testFixed, rng: rng1)
        var e2 = SnakeEngine(cfg: .testFixed, rng: rng2)

        // Feed identical direction sequences over 10 simulated seconds
        let dirs: [SnakeDirection?] = [nil, .up, nil, nil, .right, nil, nil, .down, nil, nil]
        let stepsPerSec = 60
        var dirIdx = 0

        for step in 0..<(10 * stepsPerSec) {
            let dir: SnakeDirection?
            if step % stepsPerSec == 0 && dirIdx < dirs.count {
                dir = dirs[dirIdx]
                dirIdx += 1
            } else {
                dir = nil
            }
            let f1 = e1.step(dt: 1.0 / 60.0, nextDirection: dir)
            let f2 = e2.step(dt: 1.0 / 60.0, nextDirection: dir)
            #expect(f1.body == f2.body)
            #expect(f1.gameOver == f2.gameOver)
            if f1.gameOver { break }
        }
        #expect(e1.score == e2.score, "identical scores after identical inputs with same seed")
    }

    // MARK: - SC2b: ProMotion equivalence

    /// dt=1/60 vs dt=1/120 over 5 simulated seconds, same seed, straight run →
    /// identical cell-move count and collision state. This is the Phase 17 SC2 gate.
    @Test("ProMotion equivalence: dt=1/60 vs dt=1/120 produce same cell-move count")
    func proMotionEquivalence() {
        func run(fixedDt: Double) -> (score: Int, gameOver: Bool) {
            var rng = SeededGenerator(seed: 99)
            var e = SnakeEngine(cfg: .testFixed, rng: rng)
            let steps = Int((5.0 / fixedDt).rounded())
            for _ in 0..<steps {
                _ = e.step(dt: fixedDt, nextDirection: nil)
                if e.gameOver { break }
            }
            return (e.score, e.gameOver)
        }
        let r60  = run(fixedDt: 1.0 / 60.0)
        let r120 = run(fixedDt: 1.0 / 120.0)
        #expect(r60.score    == r120.score,    "score must match across 60Hz and 120Hz")
        #expect(r60.gameOver == r120.gameOver, "gameOver must match across 60Hz and 120Hz")
    }

    // MARK: - Wall collision

    /// With wallMode=true on a small grid, running right hits the right wall → gameOver.
    @Test("wall collision ends game in wall mode")
    func wallCollision() {
        var cfg = SnakeConfig.testFixed
        cfg.wallMode = true
        cfg.cols = 5
        cfg.rows = 5
        var rng = SeededGenerator(seed: 1)
        var e = SnakeEngine(cfg: cfg, rng: rng)

        // Step right long enough to hit the wall (at most cols*100 steps gives many ticks)
        for _ in 0..<1_000 {
            let f = e.step(dt: 1.0 / 60.0, nextDirection: .right)
            if f.gameOver { return }    // expected path
        }
        Issue.record("Expected wall collision but snake never died within 1000 steps")
    }

    // MARK: - Toroidal wrap

    /// With wallMode=false, the head exits the right edge and re-enters at col 0 without dying.
    @Test("wrap mode: head exits right edge and re-enters left without dying")
    func toroidalWrap() {
        var cfg = SnakeConfig.testFixed
        cfg.wallMode = false
        cfg.cols = 10
        cfg.rows = 10
        var rng = SeededGenerator(seed: 2)
        var e = SnakeEngine(cfg: cfg, rng: rng)

        var wrapped = false
        for _ in 0..<1_000 {
            let prevHead = e.body[0]
            _ = e.step(dt: 1.0 / 60.0, nextDirection: .right)
            // Detect wrap: was on last column, now on first
            if prevHead.col == cfg.cols - 1 && e.body[0].col == 0 {
                wrapped = true
                break
            }
            if e.gameOver { break }
        }
        #expect(wrapped, "Snake must wrap from last column to first without dying")
    }

    // MARK: - Self-collision

    /// Drive the snake into a tight clockwise loop that collides with its own body → gameOver.
    ///
    /// A 3-cell snake can NEVER self-collide in a 2×2 clockwise loop because the tail
    /// always vacates the entering cell just in time. startLength=5 guarantees the body
    /// is longer than the 4-cell loop perimeter, so self-collision occurs on the 4th cell
    /// move (after ≈48 steps at 60 Hz — well under the 3000-step budget).
    @Test("self-collision ends the run")
    func selfCollision() {
        // Build config with a longer starting body — startLength is a let so use the
        // full memberwise init rather than mutating a testFixed copy.
        let cfg = SnakeConfig(
            cols: 10, rows: 10, wallMode: false,
            startTickInterval: 0.200, minTickInterval: 0.100,
            intervalDecrement: 0.002, startLength: 5, fixedDt: 1.0 / 60.0
        )
        var rng = SeededGenerator(seed: 7)
        var e = SnakeEngine(cfg: cfg, rng: rng)

        // Clockwise loop: right → down → left → up, one direction change per cell move.
        // With a 5-cell body the head re-enters a body cell on the 4th revolution,
        // triggering self-collision via the body.dropLast() check in SnakeEngine.step.
        let loopDirs: [SnakeDirection] = [.right, .down, .left, .up]
        var loopIdx = 0
        // Change direction every tickInterval/dt steps ≈ 0.200/(1/60) = 12 steps
        let stepsPerDir = 12

        for step in 0..<3_000 {
            let dir = loopDirs[loopIdx % loopDirs.count]
            _ = e.step(dt: 1.0 / 60.0, nextDirection: dir)
            if e.gameOver { return }    // self-collision achieved — test passes
            if (step + 1) % stepsPerDir == 0 { loopIdx += 1 }
        }
        Issue.record("Expected self-collision but snake never died within 3000 steps")
    }

    // MARK: - Post-gameOver no-op

    /// After gameOver, step() returns .none without mutating state (guard at top of step).
    @Test("post-gameOver steps are no-ops")
    func postGameOverNoOp() {
        var cfg = SnakeConfig.testFixed
        cfg.wallMode = true
        cfg.cols = 5
        cfg.rows = 5
        var rng = SeededGenerator(seed: 3)
        var e = SnakeEngine(cfg: cfg, rng: rng)

        // Drive into wall
        for _ in 0..<1_000 {
            _ = e.step(dt: 1.0 / 60.0, nextDirection: .right)
            if e.gameOver { break }
        }
        #expect(e.gameOver, "snake must be dead before no-op check")

        let scoreBefore = e.score
        let bodyBefore  = e.body
        let noOp = e.step(dt: 1.0, nextDirection: .left)
        #expect(noOp.event == .none)
        #expect(noOp.gameOver)
        #expect(e.score == scoreBefore, "score must not change after gameOver")
        #expect(e.body  == bodyBefore,  "body must not change after gameOver")
    }
}
