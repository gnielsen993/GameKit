//
//  StackBoardFX.swift
//  gamekit
//
//  Value types for Stack's view-layer visual effects. Owned as @State by
//  StackGameView, spawned from engine events (counter-triggers), and drawn
//  by StackBoardCanvas as a pure function of `now - spawn`.
//
//  All FX are view-layer only — the pure StackEngine never sees them.
//  Spawning is gated by animationsEnabled && !reduceMotion in the view;
//  when gated off, these arrays stay empty and nothing draws (D-08/D-09).
//

import Foundation

/// A severed piece falling off the tower with gravity, drift, rotation,
/// and fade. Spawned on a `.trim` engine event (the overhang) and on game
/// over (the whole missed block, so it falls instead of vanishing).
///
/// Motion profile is deliberately gentle — gravity/spin tuned so the piece
/// detaches calmly rather than darting away, and opacity holds full for the
/// first 40% of the lifetime before fading (see StackBoardCanvas).
struct FallingTrimPiece: Identifiable, Equatable {
    let id = UUID()
    /// Normalized ground-plane center of the severed piece at the cut.
    let centerX: Double
    let centerZ: Double
    /// Normalized footprint of the severed piece.
    let width: Double
    let depth: Double
    /// Tower row the piece broke off (drives start Y and color).
    let rowIndex: Int
    /// Axis the piece drifts along as it falls (the trim axis).
    let axis: StackAxis
    /// True when the overhang was on the positive side of that axis.
    let fallsPositive: Bool
    let spawn: Date

    static let lifetime: TimeInterval = 0.8

    /// Opacity: hold full until this fraction of lifetime, then fade linearly.
    static let fadeStart: Double = 0.4

    func age(at now: Date) -> TimeInterval { now.timeIntervalSince(spawn) }
    func isExpired(at now: Date) -> Bool { age(at: now) >= Self.lifetime }
}

/// Perfect-drop settle: the placed block glides from its rendered drop
/// position to the engine's snapped center instead of teleporting — the
/// alignment correction stays legible without reading as a jump-cut.
struct SettleGlide: Equatable {
    /// Tower row of the just-placed block.
    let rowIndex: Int
    /// Rendered slider center at the moment of the drop (normalized).
    let fromCenterX: Double
    let fromCenterZ: Double
    let spawn: Date

    static let lifetime: TimeInterval = 0.14

    func age(at now: Date) -> TimeInterval { now.timeIntervalSince(spawn) }
    func isExpired(at now: Date) -> Bool { age(at: now) >= Self.lifetime }
}

/// Expanding outline ring celebrating a perfect drop.
struct PerfectPulse: Identifiable, Equatable {
    let id = UUID()
    /// Tower row of the perfectly placed block.
    let rowIndex: Int
    let spawn: Date

    static let lifetime: TimeInterval = 0.5

    func age(at now: Date) -> TimeInterval { now.timeIntervalSince(spawn) }
    func isExpired(at now: Date) -> Bool { age(at: now) >= Self.lifetime }
}

/// Brief brightness flash on the block that just landed — impact feedback
/// for every placement (perfect drops additionally get a PerfectPulse).
struct LandingFlash: Equatable {
    /// Tower row of the block that just landed.
    let rowIndex: Int
    let spawn: Date

    static let lifetime: TimeInterval = 0.25

    func age(at now: Date) -> TimeInterval { now.timeIntervalSince(spawn) }
    func isExpired(at now: Date) -> Bool { age(at: now) >= Self.lifetime }
}
