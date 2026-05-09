//
//  NonogramWinDetector.swift
//  gamekit
//
//  Pure win predicate. The player has won iff every cell in their board
//  whose state is `.filled` corresponds to a `1` bit in the puzzle's
//  solution grid AND every `1` bit in the solution has been filled.
//
//  `marked` and `empty` cell states are treated identically — they don't
//  affect the win condition (marks are a player aid, not a commitment).
//
//  Foundation-only. Engines do not import SwiftUI / SwiftData / Combine
//  per CLAUDE §4.
//

import Foundation

enum NonogramWinDetector {
    static func isWon(board: NonogramBoard, puzzle: NonogramPuzzle) -> Bool {
        let solution = puzzle.solution
        guard solution.count == board.cells.count else { return false }
        for (idx, bit) in solution.enumerated() {
            let isFilled = board.cells[idx] == .filled
            if bit && !isFilled { return false }
            if !bit && isFilled { return false }
        }
        return true
    }
}
