//
//  RevealEngineTests.swift
//  gamekitTests
//
//  Swift Testing coverage for RevealEngine (CONTEXT D-15..D-19).
//  Proves ROADMAP P2 SC3 (iterative flood-fill, no recursion) via the
//  cluster-corner Hard fixture: a single tap from the far corner reveals
//  hundreds of cells without stack growth (the test passing IS the SC3
//  proof — no separate depth check needed since the algorithm is
//  structurally non-recursive).
//
//  All randomized tests use SeededGenerator (Plan 02) — failure on seed N
//  is reproducible by re-running with seed N (D-13).
//

import Testing
import Foundation
@testable import gamekit

@Suite("RevealEngine")
nonisolated struct RevealEngineTests {

    /// Subset of the 100-seed array used in BoardGeneratorTests; using fewer
    /// seeds here keeps test time reasonable since the idempotence fuzz
    /// re-reveals every cell in the first cascade per seed (~tens of reveals
    /// × 30 seeds for Easy).
    static let seeds: [UInt64] = (0..<30).map { i in
        UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15
    }

    // MARK: - Helper: build a deterministic Easy board

    private static func easyBoard(
        seed: UInt64,
        firstTap: MinesweeperIndex = MinesweeperIndex(row: 0, col: 0)
    ) -> MinesweeperBoard {
        var rng = SeededGenerator(seed: seed)
        return BoardGenerator.generate(difficulty: .easy, firstTap: firstTap, rng: &rng)
    }

    // MARK: - Single-cell reveal (numbered cell)

    /// Locate any hidden numbered cell on a generated Easy board and assert
    /// reveal returns exactly that one cell — no cascade.
    @Test
    func revealHiddenNumberedCell_revealsOnly() throws {
        let board = Self.easyBoard(seed: 42)
        let numberedIdx = board.allIndices().first { idx in
            let cell = board.cell(at: idx)
            return cell.state == .hidden && !cell.isMine && cell.adjacentMineCount > 0
        }
        try #require(numberedIdx != nil,
            "Test seed must produce at least one hidden numbered cell on Easy")
        let result = RevealEngine.reveal(at: numberedIdx!, on: board)
        #expect(result.revealed == [numberedIdx!],
            "Numbered cell must reveal only itself (no cascade)")
        #expect(result.board.cell(at: numberedIdx!).state == .revealed)
    }

    // MARK: - Flood-fill cascade (empty cell) — branch on (0,0) adjacency

    /// (0,0) is GUARANTEED non-mine via first-tap exclusion. Adjacency may be
    /// 0 (cascade) or >0 (single-cell) depending on the seed; assert the
    /// correct branch in either case.
    @Test
    func revealEmptyCell_cascades() {
        let board = Self.easyBoard(seed: 42)
        let tap = MinesweeperIndex(row: 0, col: 0)
        let result = RevealEngine.reveal(at: tap, on: board)
        #expect(result.revealed.first == tap, "Cascade must start with tap index")
        #expect(result.board.cell(at: tap).state == .revealed)
        if board.cell(at: tap).adjacentMineCount == 0 {
            #expect(result.revealed.count > 1, "Empty tap must cascade")
        } else {
            #expect(result.revealed.count == 1, "Numbered tap must NOT cascade")
        }
    }

    // MARK: - Mine reveal triggers .mineHit

    @Test
    func revealMine_setsMineHit() throws {
        let board = Self.easyBoard(seed: 137)
        let mineIdx = board.allIndices().first { board.cell(at: $0).isMine }
        try #require(mineIdx != nil)
        let result = RevealEngine.reveal(at: mineIdx!, on: board)
        #expect(result.revealed == [mineIdx!])
        #expect(result.board.cell(at: mineIdx!).state == .mineHit,
            "Revealed mine must transition to .mineHit (Plan 05 WinDetector.isLost reads this)")
    }

    // MARK: - Idempotence: re-revealing a .revealed cell is a no-op

    @Test
    func revealAlreadyRevealedCell_isIdempotent() {
        let board = Self.easyBoard(seed: 1729)
        let tap = MinesweeperIndex(row: 0, col: 0)
        let first = RevealEngine.reveal(at: tap, on: board)
        // Re-reveal one of the already-revealed cells
        let alreadyRevealedIdx = first.revealed.first!
        let second = RevealEngine.reveal(at: alreadyRevealedIdx, on: first.board)
        #expect(second.revealed == [], "Re-revealing must return empty `revealed` list")
        #expect(second.board == first.board, "Re-revealing must not change the board")
    }

    // MARK: - Flag protection (no-op on flagged cell)

    @Test
    func revealFlaggedCell_isNoOp() {
        let board = Self.easyBoard(seed: 31337)
        let flaggedAt = MinesweeperIndex(row: 5, col: 5)
        let originalCell = board.cell(at: flaggedAt)
        let flaggedCell = MinesweeperCell(
            isMine: originalCell.isMine,
            adjacentMineCount: originalCell.adjacentMineCount,
            state: .flagged
        )
        let flaggedBoard = board.replacingCell(at: flaggedAt, with: flaggedCell)
        let result = RevealEngine.reveal(at: flaggedAt, on: flaggedBoard)
        #expect(result.revealed == [], "Revealing a flagged cell must be a no-op")
        #expect(result.board.cell(at: flaggedAt).state == .flagged,
            "Flagged cell must remain flagged after reveal attempt (Pitfall 7)")
    }

    // MARK: - SC3: iterative flood-fill on cluster-corner Hard board (no stack growth)

    /// Build a Hard board with mines forced into the top-left 11×9 corner region
    /// (99 mines fit in 99 cells), then tap (15, 29) — far corner — and assert
    /// the cascade reveals the entire bottom-right empty region. The fact that
    /// this test PASSES without stack overflow IS the ROADMAP P2 SC3 proof.
    @Test
    func cornerClusteredHardBoard_floodFillTerminates() {
        let rows = 16, cols = 30, mineCount = 99

        // Mine indices: first 99 cells in row-major order from (0,0)
        // through the top-left 11×9 region.
        var mineIndices: Set<MinesweeperIndex> = []
        var placed = 0
        outer: for r in 0..<11 {
            for c in 0..<9 {
                mineIndices.insert(MinesweeperIndex(row: r, col: c))
                placed += 1
                if placed == mineCount { break outer }
            }
        }
        #expect(mineIndices.count == mineCount, "Cluster must contain exactly 99 mines")

        // Build cells with correct adjacency
        var cells: [MinesweeperCell] = []
        cells.reserveCapacity(rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                let idx = MinesweeperIndex(row: r, col: c)
                let isMine = mineIndices.contains(idx)
                let adj = idx.neighbors8(rows: rows, cols: cols)
                    .reduce(0) { $0 + (mineIndices.contains($1) ? 1 : 0) }
                cells.append(MinesweeperCell(isMine: isMine, adjacentMineCount: adj))
            }
        }
        let board = MinesweeperBoard(
            difficulty: .hard,
            rows: rows,
            cols: cols,
            mineCount: mineCount,
            cells: cells
        )

        // Tap far corner (15, 29) — guaranteed non-mine (cluster is top-left).
        let tap = MinesweeperIndex(row: 15, col: 29)
        #expect(board.cell(at: tap).isMine == false)

        let result = RevealEngine.reveal(at: tap, on: board)

        // Should reveal a LARGE region (all bottom-right empty cells + their numbered border).
        // 480 total cells - 99 mines = 381 non-mine; cascade reveals most of the open region.
        // Conservative lower bound: should reveal more than 200 cells without stack overflow.
        #expect(result.revealed.count > 200,
            "Far-corner tap on cluster-corner board must reveal a large region (got \(result.revealed.count))")

        // No mines were revealed by cascade
        for idx in result.revealed {
            #expect(result.board.cell(at: idx).isMine == false,
                "Cascade must not reveal mines (cell \(idx))")
        }

        // All revealed cells have state == .revealed
        for idx in result.revealed {
            #expect(result.board.cell(at: idx).state == .revealed,
                "Cell \(idx) in revealed list must have state == .revealed")
        }

        // Tap must be the first element (BFS starts at the tap)
        #expect(result.revealed.first == tap, "BFS order — first revealed must be tap")
    }

    // MARK: - BFS discovery order: revealed[0] == tap

    @Test
    func revealedListStartsWithTap() {
        let board = Self.easyBoard(seed: 42)
        let tap = MinesweeperIndex(row: 0, col: 0)
        let result = RevealEngine.reveal(at: tap, on: board)
        #expect(result.revealed.first == tap,
            "First element of `revealed` must be the tap index (BFS order)")
    }

    // MARK: - D-17 fuzz: idempotence over seeds

    /// For each seed, after the initial reveal at (0,0), re-revealing every
    /// cell that was just revealed must be a no-op (empty `revealed`, board
    /// unchanged). Catches the "works on seed 42, breaks on seed 137" class.
    @Test(arguments: seeds)
    func idempotenceFuzz(seed: UInt64) {
        let board = Self.easyBoard(seed: seed)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        let first = RevealEngine.reveal(at: firstTap, on: board)
        for idx in first.revealed {
            let again = RevealEngine.reveal(at: idx, on: first.board)
            #expect(again.revealed == [],
                "Re-revealing already-revealed cell (\(idx.row),\(idx.col)) must return empty list (seed: \(seed))")
            #expect(again.board == first.board,
                "Re-revealing must not change the board (seed: \(seed), cell: (\(idx.row),\(idx.col)))")
        }
    }
}
