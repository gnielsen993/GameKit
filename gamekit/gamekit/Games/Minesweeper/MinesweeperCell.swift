//
//  MinesweeperCell.swift
//  gamekit
//
//  A single Minesweeper cell. Value type. Engines (BoardGenerator,
//  RevealEngine) transform cells by emitting a NEW Cell inside a NEW
//  Board (D-10 immutable Board) — Cell instances are replaced wholesale,
//  never mutated through a reference.
//
//  Phase 2 invariants (per D-09 + PATTERNS.md "Cell.state single-enum"):
//    - `isMine` and `adjacentMineCount` are `let` — set at board generation
//      (Plan 03) and never change after; reads are O(1) and free of
//      derived computation per CONTEXT.md "Adjacency counts precomputed
//      at board-generation time"
//    - `state` is `var` — but Cell instances live inside the Board's
//      immutable `cells` array; engines copy that array, mutate the
//      copy, and build a NEW Board from it (D-10)
//    - State is a single enum — hidden / revealed / flagged / mineHit —
//      best self-documents in tests (CONTEXT.md "Claude's Discretion")
//    - Equatable so SwiftUI diffing in P3 can short-circuit unchanged
//      cells (PITFALLS.md Pitfall 6)
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

/// A single cell on a Minesweeper board. Value type; engines mutate
/// by returning a new Board carrying a new [Cell] (D-10 immutable Board).
/// Foundation-only — ROADMAP P2 SC5.
struct MinesweeperCell: Equatable, Hashable, Codable, Sendable {
    /// Whether this cell holds a mine. Set at board generation (Plan 03), never changes after.
    let isMine: Bool

    /// Count of mines in the 8-neighborhood. Precomputed at generation
    /// per CONTEXT.md "Adjacency counts precomputed at board-generation time"
    /// (read 100s of times per game, computed once). 0...8.
    let adjacentMineCount: Int

    /// Mutable lifecycle state. Engines transform by emitting a new Cell
    /// inside a new Board (Board is immutable; Cell instances are replaced wholesale).
    var state: State

    enum State: Equatable, Hashable, Codable, Sendable {
        /// Default. Not yet revealed, not flagged.
        case hidden
        /// Player or flood-fill revealed this cell. Adjacent count is read from `adjacentMineCount`.
        case revealed
        /// Player long-pressed to flag. Cannot be revealed without first un-flagging.
        case flagged
        /// Terminal: this is the mine the player tripped (loss-triggering cell only).
        case mineHit
    }

    init(isMine: Bool, adjacentMineCount: Int, state: State = .hidden) {
        self.isMine = isMine
        self.adjacentMineCount = adjacentMineCount
        self.state = state
    }
}
