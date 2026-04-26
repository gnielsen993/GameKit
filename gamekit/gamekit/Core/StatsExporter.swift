//
//  StatsExporter.swift
//  gamekit
//
//  JSON Export/Import sibling to `GameStats` (D-16). Public API:
//  `export(modelContext:) throws -> Data` + `importing(_:modelContext:) throws`.
//  Replace-on-import semantics per D-20 — simplest semantic that satisfies
//  SC4's byte-for-byte round-trip guarantee. `enum`-namespace because there
//  is no ivar state (matches the P2 engine namespace pattern).
//
//  Phase 4 invariants (per D-16/D-17/D-18/D-19/D-20/D-21; RESEARCH Pitfalls 6+7+10):
//    - @MainActor — `ModelContext` is not Sendable (RESEARCH Pattern 6);
//      same actor-isolation as `GameStats`.
//    - Decode-then-validate-then-transaction order (RESEARCH Pitfall 6) —
//      `schemaVersion` check BEFORE opening the destructive delete
//      transaction. Wrong order destroys data on schema-mismatch when a
//      future-schema file lands. The negative path is exercised by
//      `schemaVersionMismatchThrows` in StatsExporterTests.
//    - Encoder configuration `.sortedKeys + .iso8601 + .prettyPrinted` is
//      non-negotiable for SC4 byte-for-byte determinism (RESEARCH Pitfall 7).
//      `encoderDeterministic` test is the regression gate.
//    - Synchronous `try modelContext.save()` after the transaction commits —
//      same RESEARCH Pitfall 10 enforcement as GameStats. Force-quit
//      immediately after import must persist the imported set.
//    - Schema version pinned at `1` (D-04 envelope-level). Future bumps are
//      deliberate; bumping = forward-incompat (`schemaVersionMismatch` throws
//      to the user).
//    - UUID + per-row schemaVersion preserved across round-trip — re-inserted
//      GameRecord/BestTime have their `id`/`schemaVersion` overwritten from
//      the envelope so round-trip equality holds. Default `id: UUID = UUID()`
//      would otherwise emit fresh UUIDs and the byte-for-byte SC4 check fails.
//    - Loss-vs-best-time interaction: `importing` does NOT re-evaluate
//      BestTime via `GameStats.evaluateBestTime` — it inserts the envelope's
//      BestTime rows verbatim. Replace-on-import semantics per D-20.
//

import Foundation
import SwiftData
import os

/// `StatsExporter` — codec layer for the user's only data export path
/// (D-16). Pure static surface; no ivar state. All write paths explicitly
/// call `try modelContext.save()` per RESEARCH Pitfall 10 (autosave reliance
/// is unsafe under force-quit).
@MainActor
enum StatsExporter {

    /// Pinned at 1 in P4; bumping requires a deliberate, additive migration plan.
    static let envelopeSchemaVersion: Int = 1

    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "persistence"
    )

    // MARK: - Export

    /// Encode the current store as a `StatsExportEnvelope` JSON `Data`.
    /// Encoder configuration is `.sortedKeys + .iso8601 + .prettyPrinted` —
    /// load-bearing for SC4 byte-for-byte determinism (RESEARCH Pitfall 7).
    static func export(modelContext: ModelContext) throws -> Data {
        let records = try modelContext.fetch(FetchDescriptor<GameRecord>())
        let bests = try modelContext.fetch(FetchDescriptor<BestTime>())

        let envelope = StatsExportEnvelope(
            schemaVersion: envelopeSchemaVersion,
            exportedAt: .now,
            gameRecords: records.map { rec in
                StatsExportEnvelope.Record(
                    id: rec.id,
                    gameKindRaw: rec.gameKindRaw,
                    difficultyRaw: rec.difficultyRaw,
                    outcomeRaw: rec.outcomeRaw,
                    durationSeconds: rec.durationSeconds,
                    playedAt: rec.playedAt,
                    schemaVersion: rec.schemaVersion
                )
            },
            bestTimes: bests.map { best in
                StatsExportEnvelope.Best(
                    id: best.id,
                    gameKindRaw: best.gameKindRaw,
                    difficultyRaw: best.difficultyRaw,
                    seconds: best.seconds,
                    achievedAt: best.achievedAt,
                    schemaVersion: best.schemaVersion
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601                    // UTC, "Z" suffix
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // SC4 byte-for-byte
        return try encoder.encode(envelope)
    }

    // MARK: - Import (decode → validate → transaction → save)

    /// Replace-on-import (D-20). Decodes the envelope FIRST, validates
    /// `schemaVersion == 1` SECOND (BEFORE any destructive transaction —
    /// RESEARCH Pitfall 6), THEN opens a single transaction that deletes
    /// existing rows and inserts the envelope's rows, finally calling
    /// `try modelContext.save()` synchronously.
    ///
    /// Throws `StatsImportError.decodeFailed` on malformed JSON,
    /// `StatsImportError.schemaVersionMismatch(found:expected:)` on a
    /// future-schema envelope. Both throw paths leave existing data intact.
    static func importing(_ data: Data, modelContext: ModelContext) throws {
        // Step 1: Decode FIRST. If the JSON is malformed, throw before
        //         touching SwiftData. RESEARCH Pitfall 6.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: StatsExportEnvelope
        do {
            envelope = try decoder.decode(StatsExportEnvelope.self, from: data)
        } catch {
            logger.error(
                "Import decode failed: \(error.localizedDescription, privacy: .public)"
            )
            throw StatsImportError.decodeFailed
        }

        // Step 2: Validate schemaVersion. If mismatch, throw — existing
        //         data UNTOUCHED (no transaction opened yet). RESEARCH Pitfall 6.
        guard envelope.schemaVersion == envelopeSchemaVersion else {
            throw StatsImportError.schemaVersionMismatch(
                found: envelope.schemaVersion,
                expected: envelopeSchemaVersion
            )
        }

        // Step 3: Open replace-on-import transaction (D-20). Atomic.
        try modelContext.transaction {
            try modelContext.delete(model: GameRecord.self)
            try modelContext.delete(model: BestTime.self)

            for r in envelope.gameRecords {
                let rec = GameRecord(
                    gameKind: GameKind(rawValue: r.gameKindRaw) ?? .minesweeper,
                    difficulty: r.difficultyRaw,
                    outcome: Outcome(rawValue: r.outcomeRaw) ?? .loss,
                    durationSeconds: r.durationSeconds,
                    playedAt: r.playedAt
                )
                rec.id = r.id                          // preserve UUID for round-trip equality
                rec.schemaVersion = r.schemaVersion
                modelContext.insert(rec)
            }
            for b in envelope.bestTimes {
                let best = BestTime(
                    gameKind: GameKind(rawValue: b.gameKindRaw) ?? .minesweeper,
                    difficulty: b.difficultyRaw,
                    seconds: b.seconds,
                    achievedAt: b.achievedAt
                )
                best.id = b.id
                best.schemaVersion = b.schemaVersion
                modelContext.insert(best)
            }
        }

        // Step 4: Synchronous save (RESEARCH Pitfall 10). Force-quit-after-import
        //         must immediately persist the imported set.
        try modelContext.save()
    }

    // MARK: - Filename helper (D-19)

    /// Produces "gamekit-stats-YYYY-MM-DD.json" — locale-independent ISO
    /// date per RESEARCH Assumption A7. Plan 05 SettingsView passes this
    /// to `.fileExporter(defaultFilename:)`.
    static func defaultExportFilename(now: Date = .now) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]   // YYYY-MM-DD
        return "gamekit-stats-\(formatter.string(from: now)).json"
    }
}
