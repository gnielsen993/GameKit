//
//  BoardGeneratorTests.swift
//  gamekitTests
//
//  Swift Testing coverage for BoardGenerator (CONTEXT D-15, D-16, D-17, D-18, D-19).
//  Proves ROADMAP P2 SC1 (exact mine counts) and SC2 (first-tap safety).
//
//  All randomized tests use SeededGenerator (Plan 02) — failure on seed N
//  is reproducible by re-running with seed N (D-13).
//

import Testing
import Foundation
@testable import gamekit

@Suite("BoardGenerator")
nonisolated struct BoardGeneratorTests {

    /// 100 fixed seeds (D-17). Mixing constants (golden ratio) gives a
    /// well-distributed seed array without relying on system entropy.
    /// Indexed in failure messages: "seed[42] = 0xC0F4...".
    static let seeds: [UInt64] = (0..<100).map { i in
        UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15
    }

    // MARK: - SC1: exact mine count for every difficulty

    @Test(arguments: seeds)
    func mineCountAlwaysExact_easy(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let board = BoardGenerator.generate(
            difficulty: .easy,
            firstTap: MinesweeperIndex(row: 0, col: 0),
            rng: &rng
        )
        #expect(board.cells.count(where: \.isMine) == 10,
            "Easy must place exactly 10 mines (seed: \(seed))")
        #expect(board.cells.count == 81)
    }

    @Test(arguments: seeds)
    func mineCountAlwaysExact_medium(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let board = BoardGenerator.generate(
            difficulty: .medium,
            firstTap: MinesweeperIndex(row: 0, col: 0),
            rng: &rng
        )
        #expect(board.cells.count(where: \.isMine) == 40,
            "Medium must place exactly 40 mines (seed: \(seed))")
        #expect(board.cells.count == 256)
    }

    @Test(arguments: seeds)
    func mineCountAlwaysExact_hard(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let board = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: MinesweeperIndex(row: 0, col: 0),
            rng: &rng
        )
        #expect(board.cells.count(where: \.isMine) == 99,
            "Hard must place exactly 99 mines (seed: \(seed))")
        #expect(board.cells.count == 480)
    }

    // MARK: - SC2: first-tap safety at corner / interior / far-corner

    /// Easy corner (0,0): exclusion zone = self + 3 neighbors = 4 cells
    @Test(arguments: seeds)
    func firstTapSafeAtCorner_Easy(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        let board = BoardGenerator.generate(
            difficulty: .easy,
            firstTap: firstTap,
            rng: &rng
        )
        // Bounds-clamped neighbors at (0,0) = (0,1), (1,0), (1,1) = 3 cells
        let safeZone = [firstTap] + firstTap.neighbors8(rows: 9, cols: 9)
        #expect(safeZone.count == 4, "Easy (0,0) safe zone must be 4 cells")
        for idx in safeZone {
            #expect(board.cell(at: idx).isMine == false,
                "Cell \(idx) in first-tap safe zone must NOT be a mine (seed: \(seed))")
        }
    }

    /// Hard corner (0,0): exclusion zone = self + 3 neighbors = 4 cells
    @Test(arguments: seeds)
    func firstTapSafeAtCorner_Hard(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        let board = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: firstTap,
            rng: &rng
        )
        let safeZone = [firstTap] + firstTap.neighbors8(rows: 16, cols: 30)
        #expect(safeZone.count == 4)
        for idx in safeZone {
            #expect(board.cell(at: idx).isMine == false,
                "Hard (0,0) safe-zone cell \(idx) must NOT be a mine (seed: \(seed))")
        }
    }

    /// Hard interior (8,15): exclusion zone = self + 8 neighbors = 9 cells
    /// Per ROADMAP SC2: "Hard center tap (8,15) ... 9-cell exclusion"
    @Test(arguments: seeds)
    func firstTapSafeAtInterior_Hard(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let firstTap = MinesweeperIndex(row: 8, col: 15)
        let board = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: firstTap,
            rng: &rng
        )
        let safeZone = [firstTap] + firstTap.neighbors8(rows: 16, cols: 30)
        #expect(safeZone.count == 9, "Hard (8,15) interior safe zone must be 9 cells")
        for idx in safeZone {
            #expect(board.cell(at: idx).isMine == false,
                "Hard (8,15) safe-zone cell \(idx) must NOT be a mine (seed: \(seed))")
        }
    }

    /// Hard far-corner (15,29): exclusion zone = self + 3 neighbors = 4 cells
    @Test(arguments: seeds)
    func firstTapSafeAtFarCorner_Hard(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let firstTap = MinesweeperIndex(row: 15, col: 29)
        let board = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: firstTap,
            rng: &rng
        )
        let safeZone = [firstTap] + firstTap.neighbors8(rows: 16, cols: 30)
        #expect(safeZone.count == 4)
        for idx in safeZone {
            #expect(board.cell(at: idx).isMine == false,
                "Hard far-corner safe-zone cell \(idx) must NOT be a mine (seed: \(seed))")
        }
    }

    // MARK: - Adjacency correctness (every cell's count matches reference)

    @Test(arguments: seeds)
    func adjacencyMatchesReference(seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        let board = BoardGenerator.generate(
            difficulty: .medium,
            firstTap: MinesweeperIndex(row: 8, col: 8),
            rng: &rng
        )
        // Build a Set of mine indices from the actual board (ground truth)
        var mineSet: Set<MinesweeperIndex> = []
        for idx in board.allIndices() where board.cell(at: idx).isMine {
            mineSet.insert(idx)
        }
        // For every cell, recompute adjacency from scratch and compare
        for idx in board.allIndices() {
            let expected = idx.neighbors8(rows: board.rows, cols: board.cols)
                .reduce(0) { $0 + (mineSet.contains($1) ? 1 : 0) }
            #expect(board.cell(at: idx).adjacentMineCount == expected,
                "Adjacency mismatch at \(idx): got \(board.cell(at: idx).adjacentMineCount), expected \(expected) (seed: \(seed))")
        }
    }

    // MARK: - Determinism (same seed → same board)

    @Test
    func determinismSameSeedSameBoard() {
        for difficulty in MinesweeperDifficulty.allCases {
            var rng1 = SeededGenerator(seed: 42)
            var rng2 = SeededGenerator(seed: 42)
            let firstTap = MinesweeperIndex(row: 0, col: 0)
            let b1 = BoardGenerator.generate(difficulty: difficulty, firstTap: firstTap, rng: &rng1)
            let b2 = BoardGenerator.generate(difficulty: difficulty, firstTap: firstTap, rng: &rng2)
            #expect(b1 == b2, "Same seed must produce identical boards for \(difficulty)")
        }
    }

    // MARK: - D-18: Performance bench (Hard < 50ms median over 20 runs)

    /// IMPORTANT: This bench uses Duration-native comparison
    /// (`#expect(median < .milliseconds(50))`) to avoid brittle manual
    /// sub-second-component arithmetic — a mistyped 1e18 / 1e15
    /// conversion can silently produce wrong values and let the
    /// assertion pass with bogus measurements.
    @Test
    func hardBoardGenerationUnder50ms() {
        let runs = 20
        var samples: [Duration] = []
        samples.reserveCapacity(runs)
        for i in 0..<runs {
            var rng = SeededGenerator(seed: UInt64(i &+ 1))
            let start = ContinuousClock.now
            _ = BoardGenerator.generate(
                difficulty: .hard,
                firstTap: MinesweeperIndex(row: 8, col: 15),
                rng: &rng
            )
            samples.append(ContinuousClock.now - start)
        }
        samples.sort()
        let median = samples[runs / 2]
        // Duration-native comparison — no manual unit conversion required.
        // Swift Testing prints `Duration` values in a human-readable form
        // (e.g. "0.012s") in the failure message.
        #expect(median < .milliseconds(50),
            "Hard board generation median \(median) must be < 50ms (D-18)")
    }
}
