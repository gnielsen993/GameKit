//
//  MergeTile.swift
//  gamekit
//
//  Immutable value type for a single Merge tile. Each tile carries a stable
//  `id: UUID` so SwiftUI can match-animate slides and merges across board
//  diffs. Engines transform tiles by emitting NEW tiles — there are no
//  mutating methods (mirrors MinesweeperBoard discipline).
//
//  Foundation-only. No SwiftUI / SwiftData imports.
//
//  Invariants:
//    - `value` is always a power of two ≥ 2 (engines never produce other values).
//    - `id` is stable across slides: a tile that survives a merge keeps its id;
//       the absorbed tile's id is dropped from the next board.
//    - `mergedThisTurn` prevents double-merges in a single swipe (canonical
//       2048 rule — `[2,2,4]` swiped left becomes `[4,4]`, NOT `[8]`).
//

import Foundation

nonisolated struct MergeTile: Equatable, Hashable, Codable, Sendable, Identifiable {
    let id: UUID
    let value: Int
    /// Set true by the engine when this tile was just produced by a merge
    /// during the current turn. Reset to false at the start of the next slide.
    let mergedThisTurn: Bool

    init(id: UUID = UUID(), value: Int, mergedThisTurn: Bool = false) {
        precondition(value >= 2 && (value & (value - 1)) == 0,
            "MergeTile.value must be a power of two ≥ 2 (got \(value))")
        self.id = id
        self.value = value
        self.mergedThisTurn = mergedThisTurn
    }
}
