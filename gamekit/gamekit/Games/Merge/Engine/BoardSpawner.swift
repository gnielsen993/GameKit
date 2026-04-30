//
//  BoardSpawner.swift
//  gamekit
//
//  Pure tile-spawning logic. Deterministic given an injected RNG (mirrors
//  BoardGenerator at BoardGenerator.swift:23). Foundation-only.
//
//  Spawn rules (canonical 2048):
//    - Initial board: two random empty cells, each value 2 (90%) or 4 (10%).
//    - Per-turn spawn (after a non-empty slide): one random empty cell, same
//      90/10 distribution.
//    - Spawning into a full board returns nil — caller (VM) treats this as
//      a precondition violation since slide.didChange == true implies at
//      least one cell freed up.
//

import Foundation

nonisolated enum BoardSpawner {

    /// Probability of spawning a 4 (vs a 2). Canonical 2048 = 0.10.
    static let fourSpawnProbability: Double = 0.10

    /// Build the starting board: two tiles placed in two distinct random
    /// empty cells.
    static func initial(rng: inout some RandomNumberGenerator) -> MergeBoard {
        var board = MergeBoard.empty
        // Two spawns. Force-unwrap is safe — the empty board has 16 free cells.
        board = spawn(into: board, rng: &rng) ?? board
        board = spawn(into: board, rng: &rng) ?? board
        return board
    }

    /// Place one tile in a random empty cell. Returns nil iff the board is
    /// full. Tile value is 2 or 4 (90/10).
    static func spawn(
        into board: MergeBoard,
        rng: inout some RandomNumberGenerator
    ) -> MergeBoard? {
        let empties = board.emptyCoordinates()
        guard !empties.isEmpty else { return nil }

        // Pick a coordinate. `Int.random(in:using:)` is uniform.
        let pickIndex = Int.random(in: 0..<empties.count, using: &rng)
        let (r, c) = empties[pickIndex]

        // 90/10 value distribution.
        let value: Int = Double.random(in: 0..<1, using: &rng) < fourSpawnProbability ? 4 : 2
        let tile = MergeTile(value: value)
        return board.placing(tile, row: r, col: c)
    }
}
