//
//  SnakeConfig.swift
//  gamekit
//
//  Play-test tuning constants for SnakeEngine. Values are MEDIUM confidence
//  baselines — calibrate on device (17-CONTEXT Claude's Discretion). No dt
//  clamp here; that lives in ArcadeLoopDriver only (ARCADE-02). Foundation only.
//  Grid dimensions and speed-ramp constants are MEDIUM-confidence device-calibration
//  baselines; verify on device before shipping.
//

import Foundation

/// Tuning constants for the Snake engine. All tick intervals are in seconds
/// (never frame counts) so behaviour is identical at 60 Hz and 120 Hz (SC2).
nonisolated struct SnakeConfig: Sendable {
    var cols: Int               // grid column count
    var rows: Int               // grid row count
    var wallMode: Bool          // true = wall-death; false = toroidal wrap (default)
    let startTickInterval: Double   // seconds between cell moves at score 0
    let minTickInterval: Double     // floor after ramp — CONTEXT "≥100ms tick" (HIGH: locked)
    let intervalDecrement: Double   // seconds faster per food eaten
    let startLength: Int        // initial snake body length in cells
    let fixedDt: Double         // fixed sim timestep for the VM accumulator (HIGH: research-locked)

    /// Default in-game preset — device-calibration baseline, not gospel.
    /// Plateau at (startTickInterval - minTickInterval) / intervalDecrement
    /// = (0.200 - 0.100) / 0.002 = 50 food eaten.
    nonisolated static let `default` = SnakeConfig(
        cols: 20,
        rows: 32,
        wallMode: false,            // wrap is default (SNAKE-02)
        startTickInterval: 0.200,   // 5 moves/sec — calm opening
        minTickInterval:   0.100,   // 10 moves/sec — plateau floor (CONTEXT locked ≥100ms)
        intervalDecrement: 0.002,   // per food eaten: 0.002s faster until plateau
        startLength: 3,
        fixedDt: 1.0 / 60.0
    )

    /// Stable config for unit tests — small 10×10 grid decoupled from default
    /// calibration changes so tests remain deterministic regardless of tuning.
    nonisolated static let testFixed = SnakeConfig(
        cols: 10,
        rows: 10,
        wallMode: false,
        startTickInterval: 0.200,
        minTickInterval:   0.100,
        intervalDecrement: 0.002,
        startLength: 3,
        fixedDt: 1.0 / 60.0
    )
}
