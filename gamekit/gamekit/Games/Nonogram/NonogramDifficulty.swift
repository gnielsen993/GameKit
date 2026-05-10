//
//  NonogramDifficulty.swift
//  gamekit
//
//  Foundation-only raw-string enum for Nonogram board sizes. Mirrors
//  MinesweeperDifficulty discipline — rawValue is the stable serialization
//  key written to GameRecord.difficulty / BestTime.difficulty / JSON
//  export envelope. Renaming = data break.
//

import Foundation

enum NonogramDifficulty: String, Codable, Sendable, CaseIterable, Hashable {
    case tiny    // 5x5
    case small   // 10x10
    case medium  // 15x15
    case large   // 20x20

    /// Side length in cells.
    var size: Int {
        switch self {
        case .tiny:   return 5
        case .small:  return 10
        case .medium: return 15
        case .large:  return 20
        }
    }
}
