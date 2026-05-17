//
//  SudokuDifficulty.swift
//  gamekit
//
//  Raw-string enum identifying Sudoku difficulty tier. The raw value is the
//  stable serialization key written to GameRecord.difficultyRaw and to the
//  pack JSON's `puzzles.<key>` lookup. Renaming = data break + pack
//  mismatch.
//
//  Mirrors NonogramDifficulty's shape: raw String, CaseIterable, Codable,
//  Sendable, Hashable. Order in `allCases` = render order in the drawer
//  mode-chip row + StatsView.
//

import Foundation

enum SudokuDifficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case easy
    case medium
    case hard
    case extreme

    /// Human-readable label for chips, headers, end-state banners.
    var displayName: String {
        switch self {
        case .easy:    return "Easy"
        case .medium:  return "Medium"
        case .hard:    return "Hard"
        case .extreme: return "Extreme"
        }
    }
}
