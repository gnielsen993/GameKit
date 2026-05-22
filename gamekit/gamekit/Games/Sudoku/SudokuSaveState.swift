//
//  SudokuSaveState.swift
//  gamekit
//
//  Codable snapshot of an in-progress Sudoku session. One slot per
//  difficulty+gameMode combination stored in UserDefaults under the key
//  returned by `key(difficulty:gameMode:)`.
//
//  SudokuCell is already Codable so the full cells array encodes directly —
//  no custom cell schema needed. On restore the board is reconstructed from
//  givens+solution (clean givens) then non-default cells are overlaid via
//  SudokuBoard.setting(_:atRow:col:).
//

import Foundation

struct SudokuSaveState: Codable {
    let puzzleId: String
    let givens: String
    let solution: String
    let givenCount: Int
    let cells: [SudokuCell]         // 81 cells, row-major, full current state
    let elapsedSeconds: TimeInterval
    let mistakes: Int
    let lockedCellIndices: [Int]    // flat indices of lives-mode locked cells
    let gameMode: String            // SudokuGameMode.rawValue
    let savedAt: Date

    /// UserDefaults key for the given difficulty + game mode pair.
    static func key(difficulty: SudokuDifficulty, gameMode: SudokuGameMode) -> String {
        "sudoku.saveState.\(difficulty.rawValue).\(gameMode.rawValue)"
    }

    /// Remove all save-state slots from UserDefaults. Called from
    /// GameStats.resetAll() so a full stats reset also clears in-progress games.
    static func clearAll(userDefaults: UserDefaults = .standard) {
        for difficulty in SudokuDifficulty.allCases {
            for mode in SudokuGameMode.allCases {
                userDefaults.removeObject(forKey: key(difficulty: difficulty, gameMode: mode))
            }
        }
    }
}
