//
//  Outcome.swift
//  gamekit
//
//  Foundation-only raw-string enum capturing how a game ended. Cases
//  `.win` and `.loss` ship in P4 (D-04). Persistence-only — no SwiftUI,
//  no SwiftData.
//
//  Phase 4 invariants (per D-04):
//    - Raw values "win" / "loss" — stable serialization key for
//      GameRecord.outcomeRaw and the JSON export envelope (D-17).
//      Renaming = data break.
//    - `.abandoned` reserved for a future phase (chord-reveal v2 backlog
//      / Restart-as-abandoned tracking) — NOT shipped in P4. Adding the
//      case later is additive and schema-safe.
//

import Foundation

/// Terminal outcome of a recorded game. P4 ships `.win` and `.loss`
/// only — `.abandoned` is reserved (D-04, additive when added).
enum Outcome: String, Codable, Sendable, CaseIterable {
    case win
    case loss
    // case abandoned — RESERVED. Adding later is additive (schema-safe).
}
