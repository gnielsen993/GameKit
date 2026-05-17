//
//  SudokuGameMode.swift
//  gamekit
//
//  Two-mode toggle for the Sudoku session:
//    - .free  → wrong placements highlight red but never lock the cell or
//               fail the session. Player can erase + retry freely.
//    - .lives → wrong placements increment mistakes (cap 3). Correct
//               placements lock the cell. 3 mistakes → .gameOver.
//
//  rawValue is the stable UserDefaults key for `sudoku.lastGameMode`.
//  Renaming = data break.
//

import Foundation

enum SudokuGameMode: String, Codable, Sendable, CaseIterable, Hashable {
    case free
    case lives

    static let livesPerPuzzle: Int = 3
}
