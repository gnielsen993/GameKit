//
//  BoardSpawnerTests.swift
//  gamekitTests
//
//  Swift Testing coverage for BoardSpawner. Deterministic via SeededGenerator
//  (Plan 02). Failure on seed N is bisectable by re-running with seed N.
//

import Testing
import Foundation
@testable import gamekit

@Suite("BoardSpawner")
nonisolated struct BoardSpawnerTests {

    static let seeds: [UInt64] = (0..<50).map { i in
        UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15
    }

    @Test(arguments: seeds)
    func initialBoard_hasExactlyTwoTiles(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let board = BoardSpawner.initial(rng: &rng)
        #expect(board.tileCount == 2,
            "Initial board must have exactly 2 tiles (seed: \(seed))")
        // Every tile must be 2 or 4.
        for tile in board.cells.compactMap({ $0 }) {
            #expect(tile.value == 2 || tile.value == 4,
                "Initial tile values must be 2 or 4 (got \(tile.value), seed: \(seed))")
        }
    }

    @Test(arguments: seeds)
    func spawn_intoEmptyBoard_addsOneTile(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let result = BoardSpawner.spawn(into: .empty, rng: &rng)
        let board = try? #require(result)
        #expect(board?.tileCount == 1)
    }

    @Test
    func spawn_intoFullBoard_returnsNil() {
        let cells: [MergeTile?] = (0..<16).map { _ in MergeTile(value: 2) }
        let full = MergeBoard(cells: cells)
        var rng = SeededGenerator(seed: 1)
        #expect(BoardSpawner.spawn(into: full, rng: &rng) == nil)
    }

    /// Statistical: over many spawns, ~10% of tiles should be 4s.
    /// Loose tolerance (5%–15%) keeps the test stable across seed sequences.
    @Test
    func spawn_distribution_isApproximately90_10() {
        var rng = SeededGenerator(seed: 0xDEADBEEF)
        var twoCount = 0
        var fourCount = 0
        let trials = 2000
        for _ in 0..<trials {
            if let board = BoardSpawner.spawn(into: .empty, rng: &rng),
               let tile = board.cells.compactMap({ $0 }).first {
                if tile.value == 2 { twoCount += 1 }
                if tile.value == 4 { fourCount += 1 }
            }
        }
        let fourRatio = Double(fourCount) / Double(trials)
        #expect(fourRatio > 0.05 && fourRatio < 0.15,
            "Expected ~10% fours over \(trials) trials, got \(fourRatio)")
        #expect(twoCount + fourCount == trials)
    }

    @Test
    func determinism_sameSeedSameBoard() {
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)
        let b1 = BoardSpawner.initial(rng: &rng1)
        let b2 = BoardSpawner.initial(rng: &rng2)
        // Compare by VALUE layout — tiles' UUIDs are random per construction
        // (intentional: SwiftUI uses them for animation matching). Determinism
        // here means "same seed → same value/position layout."
        let values1 = b1.cells.map { $0?.value }
        let values2 = b2.cells.map { $0?.value }
        #expect(values1 == values2)
    }
}
