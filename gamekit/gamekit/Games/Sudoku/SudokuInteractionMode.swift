//
//  SudokuInteractionMode.swift
//  gamekit
//
//  Pencil toggle for the number pad:
//    - .value → tapping a number-pad button commits the value to the
//               selected cell.
//    - .note  → tapping a number-pad button toggles that digit in the
//               selected cell's notes set.
//
//  Selecting the same number-pad digit twice in .note mode (with same
//  cell selected) clears it from the notes set.
//

import Foundation

enum SudokuInteractionMode: String, Codable, Sendable, CaseIterable, Hashable {
    case value
    case note
}
