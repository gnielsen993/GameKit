//
//  StatsExportEnvelope.swift
//  gamekit
//
//  Codable mirror of GameRecord + BestTime for JSON export/import (D-17, D-18).
//  Single source of truth referenced by both `StatsExporter.export` and
//  `StatsExporter.importing`. JSON keys = Swift property names per D-18;
//  renaming a field = data break (round-trip + cross-version compat).
//
//  Phase 4 invariants:
//    - schemaVersion lives at envelope level (NOT per-row only) for top-level
//      forward-compat gating; nested `Record`/`Best` structs duplicate it for
//      self-describing rows. The envelope-level value is the version checked
//      by `StatsExporter.importing` BEFORE any destructive transaction runs
//      (D-20 + RESEARCH Pitfall 6).
//    - Date encoding is ISO8601 UTC (`Z` suffix) per Discretion lock +
//      RESEARCH §Standard Stack — locale-independent, CloudKit-portable.
//    - Foundation-only — pure value-type serialization side; the @Model
//      types are the persistence side. The codec layer does NOT depend on
//      the persistence framework.
//    - `Equatable` synthesized so test suites can use `#expect(env1 == env2)`
//      directly without spelling out per-field comparisons.
//    - `Sendable` so the envelope is safe to hand off across actors if a
//      future plan moves serialization off the main actor.
//

import Foundation

/// JSON envelope for stats export/import (D-17). Mirrors @Model GameRecord
/// and @Model BestTime as plain value types so the codec layer stays
/// Foundation-only. Property names ARE the JSON keys (D-18) — locked since P4.
struct StatsExportEnvelope: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let gameRecords: [Record]
    let bestTimes: [Best]

    /// Codable mirror of `@Model GameRecord` — JSON keys = Swift property
    /// names (D-18). Field-for-field with GameRecord.swift; renaming any
    /// property here is a cross-version data break.
    struct Record: Codable, Sendable, Equatable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let outcomeRaw: String
        let durationSeconds: Double
        let playedAt: Date
        let schemaVersion: Int
    }

    /// Codable mirror of `@Model BestTime` — JSON keys = Swift property
    /// names (D-18). Field-for-field with BestTime.swift; renaming any
    /// property here is a cross-version data break.
    struct Best: Codable, Sendable, Equatable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let seconds: Double
        let achievedAt: Date
        let schemaVersion: Int
    }
}
