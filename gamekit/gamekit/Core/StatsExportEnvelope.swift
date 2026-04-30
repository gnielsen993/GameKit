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
struct StatsExportEnvelope: Sendable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let gameRecords: [Record]
    let bestTimes: [Best]
    /// New in v2 (Merge phase). Decoders tolerate v1 envelopes lacking this
    /// key by defaulting to `[]` (custom `init(from:)` below). Encoders
    /// always emit the key — empty arrays serialize as `"bestScores": []`,
    /// which keeps v2 round-trips byte-deterministic under sortedKeys.
    let bestScores: [BestScoreEntry]

    init(
        schemaVersion: Int,
        exportedAt: Date,
        gameRecords: [Record],
        bestTimes: [Best],
        bestScores: [BestScoreEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.gameRecords = gameRecords
        self.bestTimes = bestTimes
        self.bestScores = bestScores
    }

    /// Codable mirror of `@Model GameRecord` — JSON keys = Swift property
    /// names (D-18). Field-for-field with GameRecord.swift; renaming any
    /// property here is a cross-version data break.
    ///
    /// `score` is new in v2 (Merge). Optional in the codec to keep v1 →
    /// v2 import compatible — old GameRecord rows decode as `score == nil`.
    struct Record: Codable, Sendable, Equatable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let outcomeRaw: String
        let durationSeconds: Double
        let playedAt: Date
        let schemaVersion: Int
        let score: Int?

        init(
            id: UUID,
            gameKindRaw: String,
            difficultyRaw: String,
            outcomeRaw: String,
            durationSeconds: Double,
            playedAt: Date,
            schemaVersion: Int,
            score: Int? = nil
        ) {
            self.id = id
            self.gameKindRaw = gameKindRaw
            self.difficultyRaw = difficultyRaw
            self.outcomeRaw = outcomeRaw
            self.durationSeconds = durationSeconds
            self.playedAt = playedAt
            self.schemaVersion = schemaVersion
            self.score = score
        }
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

    /// Codable mirror of `@Model BestScore` — JSON keys = Swift property
    /// names. New in v2.
    struct BestScoreEntry: Codable, Sendable, Equatable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let score: Int
        let achievedAt: Date
        let schemaVersion: Int
    }
}

// MARK: - Codable: tolerate v1 envelopes (no `bestScores` key)

extension StatsExportEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, gameRecords, bestTimes, bestScores
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        self.gameRecords = try c.decode([Record].self, forKey: .gameRecords)
        self.bestTimes = try c.decode([Best].self, forKey: .bestTimes)
        // Default to [] when key absent (v1 envelopes).
        self.bestScores = try c.decodeIfPresent(
            [BestScoreEntry].self, forKey: .bestScores
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(gameRecords, forKey: .gameRecords)
        try c.encode(bestTimes, forKey: .bestTimes)
        try c.encode(bestScores, forKey: .bestScores)
    }
}
