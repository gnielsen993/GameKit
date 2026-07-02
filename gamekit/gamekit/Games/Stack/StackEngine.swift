//
//  StackEngine.swift
//  gamekit
//
//  Pure value-type engine for the Stack game. Foundation-only — no view-layer
//  or persistence imports. Oscillation uses a closed-form triangle wave on
//  accumulated per-block sim-time, making dt=1/60 and dt=1/120 produce
//  identical results (SC2 / ProMotion-equivalence requirement).
//
//  3D footprint model: blocks live on a normalized X×Z ground plane and the
//  slide axis alternates per placement (X, Z, X, …). A drop trims only the
//  axis the block was travelling along; the other extent is inherited from
//  the tower top, so a sloppy run shrinks the footprint in both dimensions
//  over time. Height stays one block-unit — the tower rhythm is unchanged.
//
//  CLAUDE.md §4: pure / testable, no external framework dependencies.
//

import Foundation

// MARK: - Value Types

/// Ground-plane axis a sliding block travels along. Alternates per placement.
nonisolated enum StackAxis: Equatable, Sendable {
    case x, z
    var other: StackAxis { self == .x ? .z : .x }
}

nonisolated struct PlacedBlock: Equatable, Sendable {
    var centerX: Double
    var centerZ: Double
    var width: Double     // extent along X
    var depth: Double     // extent along Z
}

nonisolated struct StackInput: Equatable, Sendable {
    var drop: Bool = false
}

nonisolated enum StackEvent: Equatable, Sendable {
    case none
    case perfect(index: Int)
    /// Overhang severed on the axis the block was travelling along.
    case trim(overhangWidth: Double, axis: StackAxis)
    case miss
}

nonisolated struct StackFrame: Equatable, Sendable {
    var currentCenterX: Double
    var currentCenterZ: Double
    var currentWidth: Double
    var currentDepth: Double
    /// Axis the slider is currently travelling along.
    var axis: StackAxis
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
    private var currentDepth: Double
    private var axis: StackAxis = .x              // slide axis of the current block
    private var blockElapsed: Double = 0          // sim-time since current block spawned
    private var oscSpeed: Double                  // sweeps/sec, fixed at spawn from score
    private var startSide: Double = 0             // phase offset for the triangle wave
    private(set) var streak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var gameOver = false

    var score: Int { placed.count }

    init(cfg: StackConfig = .default) {
        self.cfg = cfg
        // First placed block is the base: centered, full starting footprint
        self.placed = [PlacedBlock(centerX: cfg.playfieldCenter,
                                   centerZ: cfg.playfieldCenter,
                                   width: cfg.startingWidth,
                                   depth: cfg.startingDepth)]
        self.currentWidth = cfg.startingWidth
        self.currentDepth = cfg.startingDepth
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

    /// Slider extent along the active axis.
    private var activeExtent: Double { axis == .x ? currentWidth : currentDepth }

    /// Slider center coordinate along the active axis. The inactive-axis
    /// coordinate is locked to the tower top (see `frame(event:)`).
    private var currentSlideCenter: Double {
        let travel = cfg.playfieldWidth - activeExtent
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

        let top = placed[placed.count - 1]
        let c = currentSlideCenter
        let ext = activeExtent
        let topC = axis == .x ? top.centerX : top.centerZ
        let topExt = axis == .x ? top.width : top.depth
        let overlapL = max(c - ext / 2, topC - topExt / 2)
        let overlapR = min(c + ext / 2, topC + topExt / 2)
        let overlapW = overlapR - overlapL

        if overlapW <= cfg.minWidth {
            // Complete miss — no overlap left, run ends
            gameOver = true
            bestStreak = max(bestStreak, streak)
            return frame(event: .miss)
        }

        if abs(c - topC) <= cfg.perfectTolerance {
            // Perfect drop — preserve footprint; regrow BOTH axes only after
            // N consecutive perfects (D-01): the streak reward restores the
            // whole footprint, capped at the starting extents.
            streak += 1
            bestStreak = max(bestStreak, streak)
            var newWidth = top.width
            var newDepth = top.depth
            if streak >= cfg.streakThreshold {
                newWidth = min(newWidth + cfg.expandAmount, cfg.startingWidth)
                newDepth = min(newDepth + cfg.expandAmount, cfg.startingDepth)
            }
            placed.append(PlacedBlock(centerX: top.centerX, centerZ: top.centerZ,
                                      width: newWidth, depth: newDepth))
            spawnNext(width: newWidth, depth: newDepth)
            return frame(event: .perfect(index: placed.count - 1))
        } else {
            // Imperfect — trim overhang on the slide axis only, reset streak
            // (D-01: no recovery on break). The inactive extent carries over.
            streak = 0
            let trimmedAxis = axis
            let newCenter = (overlapL + overlapR) / 2
            let overhang = ext - overlapW
            var block = PlacedBlock(centerX: top.centerX, centerZ: top.centerZ,
                                    width: top.width, depth: top.depth)
            if axis == .x {
                block.centerX = newCenter
                block.width = overlapW
            } else {
                block.centerZ = newCenter
                block.depth = overlapW
            }
            placed.append(block)
            spawnNext(width: block.width, depth: block.depth)
            return frame(event: .trim(overhangWidth: overhang, axis: trimmedAxis))
        }
    }

    // MARK: - Helpers

    private mutating func spawnNext(width: Double, depth: Double) {
        currentWidth = width
        currentDepth = depth
        blockElapsed = 0
        oscSpeed = rampSpeed(forScore: score)
        startSide = startSide == 0 ? 0.5 : 0     // alternate start side each block
        axis = axis.other                        // alternate slide axis each block
    }

    private func frame(event: StackEvent) -> StackFrame {
        let top = placed[placed.count - 1]
        let c = currentSlideCenter
        return StackFrame(
            currentCenterX: axis == .x ? c : top.centerX,
            currentCenterZ: axis == .z ? c : top.centerZ,
            currentWidth: currentWidth,
            currentDepth: currentDepth,
            axis: axis,
            score: score,
            streak: streak,
            bestStreak: bestStreak,
            gameOver: gameOver,
            event: event
        )
    }
}
