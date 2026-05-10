//
//  NonogramGameMode.swift
//  gamekit
//
//  Two-mode toggle for the Nonogram session:
//    - .free   → tap-anything sandbox. Wrong placements aren't punished;
//                player can erase / re-place freely.
//    - .lives  → strict mode. Tapping a cell auto-validates against the
//                solution. Correct fills lock (cannot erase). Wrong fills
//                cost a life and aren't committed. 3 wrong = game over.
//
//  rawValue is the stable persistence key for `nonogram.lastGameMode`
//  (UserDefaults). Renaming = data break.
//

import Foundation

enum NonogramGameMode: String, Codable, Sendable, CaseIterable, Hashable {
    case free
    case lives

    /// Lives granted at the start of a `.lives` session.
    static let livesPerPuzzle: Int = 3
}
