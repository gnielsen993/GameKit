//
//  SudokuGameMode.swift
//  gamekit
//
//  Two-mode toggle for the Sudoku session:
//    - .free  → wrong placements render in the danger color (via
//               SudokuViewModel.incorrectCellIndices) but never lock the cell
//               or fail the session. Player can erase + retry freely.
//               NOTE: this comment described unbuilt behavior from the mode's
//               introduction until 2026-08-01 — the highlight did not exist
//               and a wrong digit produced no feedback at all.
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
