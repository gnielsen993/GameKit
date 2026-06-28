//
//  StackEngine.swift
//  gamekit
//
//  Pure value-type engine for the Stack game. Foundation-only — no view-layer
//  or persistence imports. Oscillation uses a closed-form triangle wave on
//  accumulated per-block sim-time, making dt=1/60 and dt=1/120 produce
//  identical results (SC2 / ProMotion-equivalence requirement).
//
//  CLAUDE.md §4: pure / testable, no external framework dependencies.
//

import Foundation

// MARK: - Value Types

nonisolated struct PlacedBlock: Equatable, Sendable {
    var centerX: Double
    var width: Double
}

nonisolated struct StackInput: Equatable, Sendable {
    var drop: Bool = false
}

nonisolated enum StackEvent: Equatable, Sendable {
    case none
    case perfect(index: Int)
    case trim(overhangWidth: Double)
    case miss
}

nonisolated struct StackFrame: Equatable, Sendable {
    var currentCenterX: Double
    var currentWidth: Double
    var score: Int
    var streak: Int
    var bestStreak: Int
    var gameOver: Bool
    var event: StackEvent
}

// MARK: - Engine

nonisolated struct StackEngine {

    // --- config ---
    let cfg: StackConfig

    // --- state (pure value semantics) ---
    private(set) var placed: [PlacedBlock]
    private var currentWidth: Double
    private var blockElapsed: Double = 0          // sim-time since current block spawned
    private var oscSpeed: Double                  // sweeps/sec, fixed at spawn from score
    private var startSide: Double = 0             // phase offset for the triangle wave
    private(set) var streak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var gameOver = false

    var score: Int { placed.count }

    init(cfg: StackConfig = .default) {
        self.cfg = cfg
        // First placed block is the base: centered, full startingWidth
        self.placed = [PlacedBlock(centerX: cfg.playfieldCenter, width: cfg.startingWidth)]
        self.currentWidth = cfg.startingWidth
        self.oscSpeed = cfg.startSpeed
    }

    // MARK: - Oscillation (closed-form, SC2 keystone)

    /// Triangle wave in [0, 1]. Closed-form on blockElapsed — identical output at any
    /// dt granularity as long as the same accumulated sim-time is used (SC2).
    private func tri(_ t: Double) -> Double {
        let p = (t + startSide).truncatingRemainder(dividingBy: 1.0)
        let q = p < 0 ? p + 1 : p
        return q < 0.5 ? q * 2 : 2 - q * 2
    }

    private var currentCenterX: Double {
        let travel = cfg.playfieldWidth - currentWidth
        let minC = cfg.playfieldCenter - travel / 2
        return minC + travel * tri(blockElapsed * oscSpeed)
    }

    // MARK: - Speed Ramp (STACK-02)

    /// Linear ramp from startSpeed to maxSpeed across 0…plateauScore blocks, then constant.
    /// Speed in sweeps/sec (time-unit based, never frames — avoids ProMotion divergence).
    /// Exposed as internal so StackEngineTests can verify the plateau invariant.
    func rampSpeed(forScore s: Int) -> Double {
        let f = min(Double(s) / Double(cfg.plateauScore), 1.0)
        return cfg.startSpeed + (cfg.maxSpeed - cfg.startSpeed) * f
    }

    // MARK: - Main Step

    mutating func step(dt: Double, input: StackInput) -> StackFrame {
        guard !gameOver else { return frame(event: .none) }
        blockElapsed += dt
        guard input.drop else { return frame(event: .none) }

        let cx = currentCenterX
        let top = placed[placed.count - 1]
        let curL = cx - currentWidth / 2
        let curR = cx + currentWidth / 2
        let topL = top.centerX - top.width / 2
        let topR = top.centerX + top.width / 2
        let overlapL = max(curL, topL)
        let overlapR = min(curR, topR)
        let overlapW = overlapR - overlapL

        if overlapW <= cfg.minWidth {
            // Complete miss — no overlap left, run ends
            gameOver = true
            bestStreak = max(bestStreak, streak)
            return frame(event: .miss)
        }

        let offset = abs(cx - top.centerX)
        if offset <= cfg.perfectTolerance {
            // Perfect drop — preserve width; expand only after N consecutive (D-01)
            streak += 1
            bestStreak = max(bestStreak, streak)
            var newWidth = top.width
            if streak >= cfg.streakThreshold {
                newWidth = min(newWidth + cfg.expandAmount, cfg.startingWidth)
            }
            placed.append(PlacedBlock(centerX: top.centerX, width: newWidth))
            spawnNext(width: newWidth)
            return frame(event: .perfect(index: placed.count - 1))
        } else {
            // Imperfect — trim overhang, reset streak (D-01: no recovery on break)
            streak = 0
            let newCenter = (overlapL + overlapR) / 2
            let overhang = currentWidth - overlapW
            placed.append(PlacedBlock(centerX: newCenter, width: overlapW))
            spawnNext(width: overlapW)
            return frame(event: .trim(overhangWidth: overhang))
        }
    }

    // MARK: - Helpers

    private mutating func spawnNext(width: Double) {
        currentWidth = width
        blockElapsed = 0
        oscSpeed = rampSpeed(forScore: score)
        startSide = startSide == 0 ? 0.5 : 0     // alternate start side each block
    }

    private func frame(event: StackEvent) -> StackFrame {
        StackFrame(
            currentCenterX: currentCenterX,
            currentWidth: currentWidth,
            score: score,
            streak: streak,
            bestStreak: bestStreak,
            gameOver: gameOver,
            event: event
        )
    }
}
