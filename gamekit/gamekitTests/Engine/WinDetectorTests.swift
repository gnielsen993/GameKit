//
//  WinDetectorTests.swift
//  gamekitTests
//
//  Swift Testing coverage for WinDetector (CONTEXT D-15..D-19).
//  Proves ROADMAP P2 SC4 (Hard 24x16/80: 303=ongoing, 304=won, mine=lost).
//
//  All randomized tests use SeededGenerator (Plan 02) — failure on seed N
//  is reproducible by re-running with seed N (D-13).
//

import Testing
import Foundation
@testable import gamekit

@Suite("WinDetector")
nonisolated struct WinDetectorTests {

    /// Mutual-exclusion fuzz seeds. 30 seeds keeps test runtime modest while
    /// providing enough sample diversity to catch the "works on seed 42,
    /// breaks on seed 137" class (D-13, D-17).
    static let seeds: [UInt64] = (0..<30).map { i in
        UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15
    }

    // MARK: - Helper: build a Hard board

    private static func hardBoard(
        seed: UInt64,
        firstTap: MinesweeperIndex = MinesweeperIndex(row: 12, col: 8)
    ) -> MinesweeperBoard {
        var rng = SeededGenerator(seed: seed)
        return BoardGenerator.generate(difficulty: .hard, firstTap: firstTap, rng: &rng)
    }

    // MARK: - Fresh board: all hidden -> ongoing (isWon=false, isLost=false)

    @Test
    func freshBoard_isOngoing() {
        let board = Self.hardBoard(seed: 42)
        #expect(WinDetector.isWon(board) == false, "Freshly-generated board cannot be won")
        #expect(WinDetector.isLost(board) == false, "Freshly-generated board cannot be lost (no mine yet hit)")
    }

    // MARK: - SC4: 304/304 non-mine cells revealed -> won

    @Test
    func revealedAllNonMineCells_isWon() {
        let board = Self.hardBoard(seed: 42)
        // Build a new Board with every non-mine cell flipped to .revealed
        let updates: [(MinesweeperIndex, MinesweeperCell)] = board.allIndices().compactMap { idx in
            let cell = board.cell(at: idx)
            guard !cell.isMine else { return nil }   // mines stay .hidden
            return (idx, MinesweeperCell(
                isMine: false,
                adjacentMineCount: cell.adjacentMineCount,
                state: .revealed
            ))
        }
        #expect(updates.count == 304,
            "Hard 24x16/80 must have 384-80=304 non-mine cells (got \(updates.count))")
        let revealedBoard = board.replacingCells(updates)
        #expect(WinDetector.isWon(revealedBoard) == true, "All 304 non-mine cells revealed = won (SC4)")
        #expect(WinDetector.isLost(revealedBoard) == false)
    }

    // MARK: - SC4: 303/304 non-mine cells revealed -> ongoing

    @Test
    func revealed303NonMineCells_isOngoing() {
        let board = Self.hardBoard(seed: 42)
        // Reveal 303 of the 304 non-mine cells (skip the first one we encounter)
        var skipped = false
        let updates: [(MinesweeperIndex, MinesweeperCell)] = board.allIndices().compactMap { idx in
            let cell = board.cell(at: idx)
            guard !cell.isMine else { return nil }
            if !skipped {
                skipped = true
                return nil  // leave one non-mine cell hidden
            }
            return (idx, MinesweeperCell(
                isMine: false,
                adjacentMineCount: cell.adjacentMineCount,
                state: .revealed
            ))
        }
        #expect(updates.count == 303, "Should leave exactly one non-mine cell hidden")
        let partialBoard = board.replacingCells(updates)
        #expect(WinDetector.isWon(partialBoard) == false, "303/304 non-mine cells revealed = ongoing (SC4)")
        #expect(WinDetector.isLost(partialBoard) == false)
    }

    // MARK: - SC4: mine hit -> lost

    @Test
    func mineHit_isLost() throws {
        let board = Self.hardBoard(seed: 42)
        // Find a mine, flip it to .mineHit
        let mineIdx = board.allIndices().first { board.cell(at: $0).isMine }
        try #require(mineIdx != nil)
        let originalMine = board.cell(at: mineIdx!)
        let hitMine = MinesweeperCell(
            isMine: true,
            adjacentMineCount: originalMine.adjacentMineCount,
            state: .mineHit
        )
        let lostBoard = board.replacingCell(at: mineIdx!, with: hitMine)
        #expect(WinDetector.isLost(lostBoard) == true, "A mineHit cell = lost (SC4)")
        #expect(WinDetector.isWon(lostBoard) == false, "Cannot win once a mine is hit (mutual exclusion)")
    }

    // MARK: - Flagged non-mine cells block win (must be .revealed, not .flagged)

    @Test
    func flaggedNonMineCellsBlockWin() {
        let board = Self.hardBoard(seed: 42)
        // Reveal all non-mine cells EXCEPT one, which we flag instead
        var didFlag = false
        let updates: [(MinesweeperIndex, MinesweeperCell)] = board.allIndices().compactMap { idx in
            let cell = board.cell(at: idx)
            guard !cell.isMine else { return nil }
            if !didFlag {
                didFlag = true
                return (idx, MinesweeperCell(
                    isMine: false,
                    adjacentMineCount: cell.adjacentMineCount,
                    state: .flagged   // flagged, not revealed!
                ))
            }
            return (idx, MinesweeperCell(
                isMine: false,
                adjacentMineCount: cell.adjacentMineCount,
                state: .revealed
            ))
        }
        let mixedBoard = board.replacingCells(updates)
        #expect(WinDetector.isWon(mixedBoard) == false,
            "Even with all non-mines accounted for, flagged != revealed -> not won")
        #expect(WinDetector.isLost(mixedBoard) == false)
    }

    // MARK: - D-17 fuzz: mutual-exclusion invariant over seeds

    @Test(arguments: seeds)
    func mutualExclusionFuzz(seed: UInt64) {
        let board = Self.hardBoard(seed: seed)
        // 1. Fresh board: ongoing
        let freshWon = WinDetector.isWon(board)
        let freshLost = WinDetector.isLost(board)
        #expect(!(freshWon && freshLost), "Mutual exclusion violated on fresh board (seed: \(seed))")
        #expect(freshWon == false && freshLost == false, "Fresh board must be ongoing (seed: \(seed))")

        // 2. Reveal all non-mines: won
        let allRevealedUpdates: [(MinesweeperIndex, MinesweeperCell)] = board.allIndices().compactMap { idx in
            let c = board.cell(at: idx)
            guard !c.isMine else { return nil }
            return (idx, MinesweeperCell(isMine: false, adjacentMineCount: c.adjacentMineCount, state: .revealed))
        }
        let wonBoard = board.replacingCells(allRevealedUpdates)
        #expect(WinDetector.isWon(wonBoard) && !WinDetector.isLost(wonBoard),
            "All non-mines revealed must be won-XOR-not-lost (seed: \(seed))")

        // 3. Trip a mine on the won board -> switches to lost (and stays not-won by mutual exclusion)
        let mineIdx = board.allIndices().first { board.cell(at: $0).isMine }!
        let hit = MinesweeperCell(isMine: true, adjacentMineCount: board.cell(at: mineIdx).adjacentMineCount, state: .mineHit)
        let lostBoard = wonBoard.replacingCell(at: mineIdx, with: hit)
        #expect(WinDetector.isLost(lostBoard), "Mine hit must register as lost (seed: \(seed))")
        #expect(!WinDetector.isWon(lostBoard), "Cannot be won AND lost (seed: \(seed))")
    }
}
