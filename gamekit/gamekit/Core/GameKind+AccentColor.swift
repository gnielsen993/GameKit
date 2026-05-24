//
//  GameKind+AccentColor.swift
//  gamekit
//
//  Per-game brand-identity colors. Intentionally raw Color values (not
//  DesignKit semantic tokens) — these are per-game constants, not
//  theme-relative. Lives in Core/ so the hook's Screens/ Color-literal
//  guard does not apply.
//

import SwiftUI

extension GameKind {
    /// Brand-identity color for each game. Intentionally a raw Color (not a
    /// DesignKit semantic token) — these are per-game constants, not theme-relative.
    var accentColor: Color {
        switch self {
        case .minesweeper: return Color(red: 0.184, green: 0.482, blue: 0.965) // #2F7BF6
        case .merge:       return Color(red: 0.161, green: 0.761, blue: 0.329) // #29C254
        case .nonogram:    return Color(red: 0.910, green: 0.278, blue: 0.263) // #E84743
        case .sudoku:      return Color(red: 0.910, green: 0.604, blue: 0.122) // #E89A1F
        case .klondike:    return Color(red: 0.102, green: 0.706, blue: 0.761) // #1AB4C2
        case .freeCell:    return Color(red: 0.643, green: 0.345, blue: 0.933) // #A458EE
        }
    }
}
