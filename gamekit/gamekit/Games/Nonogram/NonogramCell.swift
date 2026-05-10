//
//  NonogramCell.swift
//  gamekit
//
//  Cell state for a Nonogram board cell.
//
//  - .empty   = no input (default)
//  - .filled  = the player marked this cell as part of the picture
//  - .marked  = the player annotated this cell as definitely-NOT part of
//               the picture (the "X" mode in the UI). A purely cosmetic
//               aid for the solver — does not affect win detection.
//
//  Win = every cell whose solution-grid bit is 1 has state == .filled,
//  and every cell whose solution-grid bit is 0 has state != .filled.
//  `marked` and `empty` are treated identically for win detection.
//

import Foundation

enum NonogramCellState: String, Codable, Sendable, Hashable {
    case empty
    case filled
    case marked
}
