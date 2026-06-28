//
//  StackConfig.swift
//  gamekit
//
//  Play-test tuning constants for StackEngine. Values are MEDIUM confidence
//  baselines — calibrate on device (16-CONTEXT D-03). No dt clamp here;
//  that lives in ArcadeLoopDriver only (ARCADE-02). Foundation only.
//

import Foundation

/// Tuning constants for the Stack engine. All speeds are in sweeps/sec (time-
/// units, not frames). Coordinates are normalized: playfieldWidth = 1.0.
struct StackConfig {
    let playfieldWidth: Double     // normalized width of the playfield
    let playfieldCenter: Double    // center X in normalized coords
    let startingWidth: Double      // initial block width (HIGH: generous landing zone)
    let minWidth: Double           // overlap below this = complete miss
    let startSpeed: Double         // sweep speed at score 0 (sweeps/sec)
    let maxSpeed: Double           // sweep speed after plateau (sweeps/sec)
    let plateauScore: Int          // score at which speed stops ramping (HIGH: ≤80)
    let perfectTolerance: Double   // half-width band for a "perfect" drop
    let streakThreshold: Int       // consecutive perfects before width expands (D-01)
    let expandAmount: Double       // width added per expansion tick, capped at startingWidth
    let cycleLength: Int           // chart-color cycle length (matches theme.charts count)

    /// Default in-game preset — play-test baseline, not gospel.
    static let `default` = StackConfig(
        playfieldWidth: 1.0, playfieldCenter: 0.5,
        startingWidth: 0.62, minWidth: 0.015,
        startSpeed: 0.35, maxSpeed: 0.90, plateauScore: 80,
        perfectTolerance: 0.025, streakThreshold: 5, expandAmount: 0.04,
        cycleLength: 6
    )

    /// Stable config for unit tests — decoupled from future default calibration.
    static let testFixed = StackConfig(
        playfieldWidth: 1.0, playfieldCenter: 0.5,
        startingWidth: 0.62, minWidth: 0.015,
        startSpeed: 0.35, maxSpeed: 0.90, plateauScore: 80,
        perfectTolerance: 0.025, streakThreshold: 5, expandAmount: 0.04,
        cycleLength: 6
    )
}
