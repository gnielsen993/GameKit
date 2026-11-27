//
//  SudokuNearWinFixture.swift
//  gamekit
//
//  DEBUG-only. Picks the three cells a near-win Sudoku fixture leaves empty,
//  so the win moment can be reached in three taps (by Gabe, and by UI tests)
//  without playing a puzzle. The three cells all take the same solution
//  digit: the number pad then shows exactly one enabled key with 3 left, a UI
//  test can finish without knowing the solution, and the last placement
//  completes a row, a column, a box and the digit at once.
//
//  Pure and Foundation-only. Applying it to a view model lives in
//  SudokuViewModel+DebugFixture.swift. Never compiled into Release.
//

#if DEBUG

import Foundation

nonisolated enum SudokuNearWinFixture {

    /// Launch argument that starts a Sudoku game three taps from a win.
    static let launchArgument = "--sudoku-near-win"

    /// Suffix appended to the puzzle id so persistence and stats paths can
    /// recognise a fixture game and leave the player's real data alone.
    static let puzzleIDSuffix = "-debug-near-win"

    /// A believable clock for the win sheet: 4:11.
    static let previewElapsedSeconds: TimeInterval = 251

    /// Flat indices (row-major) of the three cells to leave empty: the first
    /// three non-given cells of the smallest digit that has at least three.
    /// Empty when no digit qualifies or either string is malformed.
    static func emptyIndices(givens: String, solution: String) -> [Int] {
        let given = Array(givens)
        let solved = Array(solution)
        guard given.count == 81, solved.count == 81 else { return [] }

        var byDigit: [Character: [Int]] = [:]
        for idx in 0..<81 where given[idx] == "0" || given[idx] == "." {
            byDigit[solved[idx], default: []].append(idx)
        }
        for digit in "123456789" {
            if let indices = byDigit[digit], indices.count >= 3 {
                return Array(indices.prefix(3))
            }
        }
        return []
    }

    /// True only for puzzle ids this fixture produced.
    static func isFixture(puzzleID: String?) -> Bool {
        guard let puzzleID else { return false }
        return puzzleID.hasSuffix(puzzleIDSuffix)
    }
}

#endif
