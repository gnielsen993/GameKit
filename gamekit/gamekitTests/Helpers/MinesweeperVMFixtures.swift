//
//  MinesweeperVMFixtures.swift
//  gamekitTests
//
//  Pre-built boards for MinesweeperViewModelTests state-transition coverage.
//  Boards are constructed deterministically — either via SeededGenerator
//  (for random-mine fixtures) or via direct hand-built [Cell] arrays
//  (for shape-locked fixtures like a fully-revealed-except-one-cell board).
//
//  Test target only — Foundation + @testable import gamekit.
//

import Foundation
@testable import gamekit

enum MinesweeperVMFixtures {

    /// Easy 9×9 board generated with seed=1, firstTap=(0,0). Has 10 mines
    /// placed everywhere EXCEPT (0,0) and its 3 bounds-clamped neighbors.
    /// Used as the "VM is in .playing state with a mine somewhere" base case.
    static func easyAfterFirstTap(seed: UInt64 = 1) -> MinesweeperBoard {
        var rng = SeededGenerator(seed: seed)
        return BoardGenerator.generate(
            difficulty: .easy,
            firstTap: MinesweeperIndex(row: 0, col: 0),
            rng: &rng
        )
    }

    /// Hard board generated with seed=1, firstTap=(8,15), then every
    /// non-mine cell set to .revealed EXCEPT one — used to assert that
    /// revealing the final safe cell flips gameState to .won.
    static func hardAlmostWonExceptOneCell(
        seed: UInt64 = 1
    ) -> (board: MinesweeperBoard, finalSafeCell: MinesweeperIndex) {
        var rng = SeededGenerator(seed: seed)
        let base = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: MinesweeperIndex(row: 8, col: 15),
            rng: &rng
        )
        // Find every non-mine index, reserve the last one as the "still hidden" cell.
        let nonMineIndices = base.allIndices().filter { !base.cell(at: $0).isMine }
        precondition(
            nonMineIndices.count == base.rows * base.cols - base.mineCount,
            "Non-mine count must equal cellCount - mineCount"
        )
        let finalSafe = nonMineIndices.last!
        // Build cell updates that reveal every non-mine cell EXCEPT finalSafe.
        let updates: [(MinesweeperIndex, MinesweeperCell)] = nonMineIndices
            .dropLast()
            .map { idx in
                let cell = base.cell(at: idx)
                return (idx, MinesweeperCell(
                    isMine: cell.isMine,
                    adjacentMineCount: cell.adjacentMineCount,
                    state: .revealed
                ))
            }
        return (base.replacingCells(updates), finalSafe)
    }

    /// Hard board with the first mine flipped to .mineHit.
    /// Drives WinDetector.isLost == true.
    static func hardLost(
        seed: UInt64 = 1
    ) -> (board: MinesweeperBoard, mineIdx: MinesweeperIndex) {
        var rng = SeededGenerator(seed: seed)
        let base = BoardGenerator.generate(
            difficulty: .hard,
            firstTap: MinesweeperIndex(row: 8, col: 15),
            rng: &rng
        )
        let firstMine = base.allIndices().first { base.cell(at: $0).isMine }!
        let mineCell = base.cell(at: firstMine)
        let lostBoard = base.replacingCell(
            at: firstMine,
            with: MinesweeperCell(
                isMine: mineCell.isMine,
                adjacentMineCount: mineCell.adjacentMineCount,
                state: .mineHit
            )
        )
        return (lostBoard, firstMine)
    }

    /// Easy board with 3 specified cells flagged (irrespective of whether they are mines).
    /// Used to test minesRemaining = mineCount - flaggedCount math.
    static func easyWith3Flagged(
        at indices: [MinesweeperIndex] = [
            MinesweeperIndex(row: 1, col: 1),
            MinesweeperIndex(row: 2, col: 2),
            MinesweeperIndex(row: 3, col: 3),
        ],
        seed: UInt64 = 1
    ) -> MinesweeperBoard {
        precondition(indices.count == 3)
        var rng = SeededGenerator(seed: seed)
        let base = BoardGenerator.generate(
            difficulty: .easy,
            firstTap: MinesweeperIndex(row: 0, col: 0),
            rng: &rng
        )
        let updates: [(MinesweeperIndex, MinesweeperCell)] = indices.map { idx in
            let cell = base.cell(at: idx)
            return (idx, MinesweeperCell(
                isMine: cell.isMine,
                adjacentMineCount: cell.adjacentMineCount,
                state: .flagged
            ))
        }
        return base.replacingCells(updates)
    }
}
