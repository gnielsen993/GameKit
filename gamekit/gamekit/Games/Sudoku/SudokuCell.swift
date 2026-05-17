//
//  SudokuCell.swift
//  gamekit
//
//  Single cell in the 9×9 Sudoku grid. Three populated states:
//    - .given: a clue from the puzzle (locked, cannot be erased or
//      modified by the player)
//    - .user(Int): a player-placed value 1...9
//    - .empty(notes: Set<Int>): no committed value, optional pencil
//      marks (1...9 set)
//
//  `notes` only meaningful in `.empty` — `.given` and `.user` ignore it.
//  Value cells (.given / .user) implicitly clear notes.
//

import Foundation

enum SudokuCell: Equatable, Hashable, Codable, Sendable {
    case given(Int)              // value 1...9, locked
    case user(Int)               // value 1...9, placed by player
    case empty(notes: Set<Int>)  // notes ⊆ {1...9}

    /// Currently-visible value, or nil if empty. Reads from .given or .user.
    var value: Int? {
        switch self {
        case .given(let v): return v
        case .user(let v):  return v
        case .empty:        return nil
        }
    }

    /// True for clue cells (.given). Player input + erase target this flag
    /// to no-op on locked cells.
    var isGiven: Bool {
        if case .given = self { return true }
        return false
    }

    /// True for cells the player can interact with (everything except .given).
    var isPlayerEditable: Bool { !isGiven }

    /// Currently-stored notes, or empty set if not in .empty state.
    var notes: Set<Int> {
        if case .empty(let n) = self { return n }
        return []
    }
}
