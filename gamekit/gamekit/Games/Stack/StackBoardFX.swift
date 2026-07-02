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

/// A trimmed overhang piece falling off the tower with gravity, drift,
/// rotation, and fade. Spawned on a `.trim` engine event.
struct FallingTrimPiece: Identifiable, Equatable {
    let id = UUID()
    /// Normalized center X of the severed piece at the moment of the cut.
    let centerX: Double
    /// Normalized width of the severed piece.
    let width: Double
    /// Tower row the piece broke off (drives start Y and color).
    let rowIndex: Int
    /// True when the overhang was on the right side of the tower.
    let fallsRight: Bool
    let spawn: Date

    static let lifetime: TimeInterval = 0.8

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
