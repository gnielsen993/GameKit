//
//  MinesweeperGameState.swift
//  gamekit
//
//  The lifecycle of a Minesweeper session, owned by the P3 ViewModel.
//  Engines never read or write this state — they transform Boards;
//  the VM derives the next GameState from the resulting Board via
//  WinDetector predicates (Plan 05).
//
//  Phase 2 invariants (per CONTEXT.md "Claude's Discretion" — recommended shape):
//    - Four cases: idle / playing / won / lost(mineIdx:)
//    - `lost` carries the triggering MinesweeperIndex so P3 can render the
//      mineHit overlay without reconstructing the trip cell from a diff
//    - No Codable — P4 persists the *outcome* (GameRecord), not the live
//      state machine
//    - MinesweeperPhase (animation orchestration enum) is a P3/P5 view-layer
//      concern (CONTEXT.md deferred — not shipped here)
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

/// Lifecycle of a Minesweeper session, owned by the P3 ViewModel.
/// Foundation-only — ROADMAP P2 SC5. Engine ships this; P3/P5
/// MinesweeperPhase (animation orchestration) is a view-layer concern (CONTEXT.md deferred).
enum MinesweeperGameState: Equatable, Hashable, Sendable {
    /// Pre-first-tap. Board is unpopulated.
    case idle
    /// First tap fired; mines placed; reveals in flight.
    case playing
    /// All non-mine cells revealed.
    case won
    /// A mine was revealed; carries the triggering index so P3 can render mineHit state.
    case lost(mineIdx: MinesweeperIndex)
}
