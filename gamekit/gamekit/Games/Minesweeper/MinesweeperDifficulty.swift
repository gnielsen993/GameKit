//
//  MinesweeperDifficulty.swift
//  gamekit
//
//  The three locked Minesweeper difficulties (Easy / Medium / Hard) and
//  the mechanical board dimensions each one specifies.
//
//  Phase 2 invariants (per D-01, D-02, D-04, D-05):
//    - Three cases only — no `case custom(...)` (D-04)
//    - Raw values are the stable serialization key for P4 stats and JSON
//      export (D-02) — renaming any case = data break
//    - Engine layer carries no localized display names (D-03); the P3/P5
//      view layer owns String(localized:) mapping
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

/// Three locked difficulties for v1 (D-04). Raw values are the stable
/// serialization key for P4 stats and JSON export (D-02) — renaming = data break.
/// Foundation-only — ROADMAP P2 SC5.
nonisolated enum MinesweeperDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard

    var rows: Int {
        switch self {
        case .easy:   9
        case .medium: 16
        case .hard:   24
        }
    }

    var cols: Int {
        switch self {
        case .easy:   9
        case .medium: 16
        case .hard:   16
        }
    }

    var mineCount: Int {
        switch self {
        case .easy:   10
        case .medium: 40
        case .hard:   80
        }
    }

    /// Total cells on the board for this difficulty (rows * cols).
    var cellCount: Int { rows * cols }
}
