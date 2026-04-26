//
//  GameKind.swift
//  gamekit
//
//  Foundation-only raw-string enum identifying which game produced a stats
//  record. Sole case `.minesweeper` in P4 (D-04). The rawValue
//  ("minesweeper") is the canonical serialization key written to
//  GameRecord.gameKindRaw / BestTime.gameKindRaw and to the JSON export
//  envelope (D-17). Persistence-only — no SwiftUI, no SwiftData.
//
//  Phase 4 invariants (per D-04):
//    - Raw value "minesweeper" is the stable serialization key (mirrors P2
//      D-02 lockdown for MinesweeperDifficulty). Renaming = data break.
//    - Foundation-only — additive future cases (.sudoku, .nonogram, …)
//      ship in their respective game phases (D-04, schema-safe additive
//      change, no schemaVersion bump required under SwiftData lightweight
//      migration).
//

import Foundation

/// Identifier for the game that produced a stats record.
/// Raw value is the stable serialization key (D-04) — renaming = data break.
enum GameKind: String, Codable, Sendable, CaseIterable {
    case minesweeper
}
