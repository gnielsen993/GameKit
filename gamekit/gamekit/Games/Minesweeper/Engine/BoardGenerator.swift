//
//  BoardGenerator.swift
//  gamekit
//
//  Pure board generation. Deterministic given an injected RNG (D-11).
//  First-tap-safe via single-rule placement (PITFALLS Pitfall 1):
//  mines are sampled WITHOUT REPLACEMENT from allCells - {tapped} - tapped.neighbors8.
//  No re-roll loop. No "regenerate until tap is empty." Single shot.
//
//  Phase 2 invariants (per D-08, D-10, D-11):
//    - Foundation-only — no SwiftUI, no SwiftData, no GameplayKit (ROADMAP P2 SC5)
//    - Returns NEW immutable Board (D-10 — never mutates an input)
//    - Generic over RandomNumberGenerator (D-11 — production: SystemRNG, tests: SeededGenerator)
//
//  CLAUDE.md §8.11: first-tap safety is P0. A first-tap loss is a bug.
//

import Foundation

/// Pure-function namespace producing a populated MinesweeperBoard from
/// `(difficulty, firstTap, rng)`. Stateless; uninhabited (`enum`).
/// Foundation-only — ROADMAP P2 SC5.
nonisolated enum BoardGenerator {

    /// Generate a populated board with mines placed everywhere EXCEPT
    /// `firstTap` and its bounds-clamped 8-neighbors. Adjacency precomputed.
    ///
    /// - Parameters:
    ///   - difficulty: Locked difficulty (rows/cols/mineCount, see D-05).
    ///   - firstTap: The cell the player tapped first. Mines are excluded from this
    ///               cell + its bounds-clamped neighbors (3 / 5 / 8 depending on position).
    ///   - rng: Inout RandomNumberGenerator. Tests pass `&SeededGenerator(seed: N)`,
    ///         production passes `&SystemRandomNumberGenerator()` (D-11).
    /// - Returns: A populated MinesweeperBoard with all cells `.hidden`.
    ///
    /// Pre: `firstTap` MUST be on the board (`firstTap.row in 0..<rows`,
    ///      `firstTap.col in 0..<cols`). Engine traps via precondition.
    /// Pre: `difficulty.cellCount > difficulty.mineCount + safeZoneSize` for ALL
    ///      difficulties — verified arithmetically: Easy 81 > 10+4 ✓,
    ///      Medium 256 > 40+9 ✓, Hard 480 > 99+9 ✓.
    static func generate(
        difficulty: MinesweeperDifficulty,
        firstTap: MinesweeperIndex,
        rng: inout some RandomNumberGenerator
    ) -> MinesweeperBoard {
        let rows = difficulty.rows
        let cols = difficulty.cols
        precondition(firstTap.row >= 0 && firstTap.row < rows &&
                     firstTap.col >= 0 && firstTap.col < cols,
            "firstTap (\(firstTap.row),\(firstTap.col)) must be on board (\(rows)x\(cols))")

        // 1. Build the safe-zone exclusion set: {tapped} ∪ tapped.neighbors8
        //    (bounds-clamped — Pitfall 1).
        var safeZone: Set<MinesweeperIndex> = [firstTap]
        safeZone.formUnion(firstTap.neighbors8(rows: rows, cols: cols))

        // 2. Build the candidate pool = allCells - safeZone.
        //    (Iterating row-major; 81 / 256 / 480 cells max — fast.)
        var minePool: [MinesweeperIndex] = []
        minePool.reserveCapacity(rows * cols - safeZone.count)
        for r in 0..<rows {
            for c in 0..<cols {
                let idx = MinesweeperIndex(row: r, col: c)
                if !safeZone.contains(idx) {
                    minePool.append(idx)
                }
            }
        }

        // 3. Sample WITHOUT REPLACEMENT, single shot. No re-roll loop (PITFALLS Pitfall 1).
        //    `Array.shuffled(using:)` uses Fisher-Yates internally — O(n) and uniform
        //    given a uniform RNG. Take the first `mineCount` indices.
        let shuffled = minePool.shuffled(using: &rng)
        let mineIndices = Set(shuffled.prefix(difficulty.mineCount))

        // 4. Precompute adjacency for every cell. Build a flat [MinesweeperCell]
        //    in row-major order so it matches MinesweeperBoard's `cells` storage layout.
        var cells: [MinesweeperCell] = []
        cells.reserveCapacity(rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                let idx = MinesweeperIndex(row: r, col: c)
                let isMine = mineIndices.contains(idx)
                let adjacent = idx.neighbors8(rows: rows, cols: cols)
                    .reduce(0) { $0 + (mineIndices.contains($1) ? 1 : 0) }
                cells.append(MinesweeperCell(
                    isMine: isMine,
                    adjacentMineCount: adjacent,
                    state: .hidden
                ))
            }
        }

        // 5. Build the immutable Board (D-10).
        return MinesweeperBoard(difficulty: difficulty, cells: cells)
    }
}
