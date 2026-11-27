//
//  SudokuViewModel+TestSeam.swift
//  gamekit
//
//  DEBUG-only test entry point, moved out of SudokuViewModel.swift to keep
//  the host file shrinking toward the section 8.5 line cap.
//

import Foundation

// MARK: - Test injection seam (#if DEBUG)

#if DEBUG
extension SudokuViewModel {
    /// Test-only entry point that bypasses the async pool load.
    @MainActor
    func injectTestBoardForUnitTests(puzzle: SudokuPuzzleEntry) {
        self.currentPuzzle = puzzle
        self.board = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution)
        var locked = Set<Int>()
        if let b = self.board {
            for i in 0..<81 where b.cells[i].isGiven {
                locked.insert(i)
            }
        }
        self.lockedCells = locked
    }
}
#endif
