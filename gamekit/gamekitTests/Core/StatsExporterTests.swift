//
//  StatsExporterTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 04-03 codec layer (StatsExporter).
//  Verifies D-16/D-17/D-18/D-19/D-20 + RESEARCH Pitfall 6 (decode-validate-
//  transaction order) + RESEARCH Pitfall 7 (sortedKeys + iso8601 + prettyPrinted
//  for byte-for-byte SC4 determinism).
//
//  TDD RED gate: this suite ships first, fails to compile because
//  `StatsExporter` does not yet exist ("Cannot find type 'StatsExporter'
//  in scope"). The GREEN commit follows with the production type.
//
//  Per D-30 (Swift Testing) and D-31 (in-memory container per test).
//
//  Why @MainActor struct: SwiftData ModelContext is not Sendable per
//  RESEARCH Pattern 6 — locked as standard for ALL P4 Core tests in 04-01.
//

import Testing
import Foundation
import SwiftData
@testable import gamekit

@MainActor
@Suite("StatsExporter")
struct StatsExporterTests {

    // Per D-31: fresh container per test. ~1ms init.
    private func makeContext() throws -> (ModelContext, ModelContainer) {
        let container = try InMemoryStatsContainer.make()
        return (ModelContext(container), container)
    }

    /// Helper: insert 50 GameRecords + 3 BestTimes for the round-trip seed.
    /// Mix of win/loss across difficulties; varied durations; deterministic
    /// `playedAt` from a reference date so the encoded JSON is reproducible.
    private func seedFiftyGames(into ctx: ModelContext) throws {
        let difficulties = ["easy", "medium", "hard"]
        for i in 0..<50 {
            let diff = difficulties[i % 3]
            let rec = GameRecord(
                gameKind: .minesweeper,
                difficulty: diff,
                outcome: i % 2 == 0 ? .win : .loss,
                durationSeconds: Double(15 + i % 90),
                playedAt: Date(timeIntervalSinceReferenceDate: 700_000_000 + Double(i * 60))
            )
            ctx.insert(rec)
        }
        for diff in difficulties {
            let best = BestTime(
                gameKind: .minesweeper,
                difficulty: diff,
                seconds: 12.5,
                achievedAt: Date(timeIntervalSinceReferenceDate: 700_005_000)
            )
            ctx.insert(best)
        }
        try ctx.save()
    }

    // MARK: - SC4 — byte-for-byte 50-game round-trip

    @Test("Round-trip 50 records is byte-for-byte identical (SC4)")
    func roundTripFifty() throws {
        let (ctx, _) = try makeContext()
        try seedFiftyGames(into: ctx)
        let originalRecords = try ctx.fetch(FetchDescriptor<GameRecord>())
        let originalBests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(originalRecords.count == 50)
        #expect(originalBests.count == 3)

        let exported = try StatsExporter.export(modelContext: ctx)

        // Wipe the context (replace-on-import simulator).
        try ctx.delete(model: GameRecord.self)
        try ctx.delete(model: BestTime.self)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 0)

        // Re-import.
        try StatsExporter.importing(exported, modelContext: ctx)
        let restoredRecords = try ctx.fetch(FetchDescriptor<GameRecord>())
        let restoredBests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(restoredRecords.count == 50)
        #expect(restoredBests.count == 3)

        // Re-export and assert byte equality (SC4 — RESEARCH Pitfall 7).
        let reExported = try StatsExporter.export(modelContext: ctx)
        #expect(exported == reExported, "byte-for-byte round-trip must hold (SC4)")
    }

    // MARK: - Schema-mismatch — RESEARCH Pitfall 6 forcing function

    @Test("Schema-version mismatch throws and does NOT delete existing data")
    func schemaVersionMismatchThrows() throws {
        let (ctx, _) = try makeContext()
        // Pre-populate.
        ctx.insert(GameRecord(difficulty: "easy", outcome: .win, durationSeconds: 30))
        try ctx.save()

        // Hand-craft a future-schema envelope.
        let future = StatsExportEnvelope(
            schemaVersion: 99,
            exportedAt: .now,
            gameRecords: [],
            bestTimes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(future)

        #expect(throws: StatsImportError.schemaVersionMismatch(found: 99, expected: 1)) {
            try StatsExporter.importing(data, modelContext: ctx)
        }
        // Existing data UNTOUCHED — RESEARCH Pitfall 6.
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 1)
    }

    // MARK: - Replace-on-import — D-20

    @Test("Replace-on-import wipes pre-existing rows and replaces with envelope contents")
    func replaceOnImport() throws {
        let (ctx, _) = try makeContext()
        // Pre-populate 5 GameRecords + 1 BestTime.
        for _ in 0..<5 {
            ctx.insert(GameRecord(difficulty: "easy", outcome: .loss, durationSeconds: 5))
        }
        ctx.insert(BestTime(difficulty: "easy", seconds: 10))
        try ctx.save()

        // Hand-craft an envelope with 3 different records + 1 best time.
        let envelope = StatsExportEnvelope(
            schemaVersion: 1,
            exportedAt: .now,
            gameRecords: (0..<3).map { i in
                StatsExportEnvelope.Record(
                    id: UUID(),
                    gameKindRaw: "minesweeper",
                    difficultyRaw: "hard",
                    outcomeRaw: "win",
                    durationSeconds: Double(100 + i),
                    playedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
                    schemaVersion: 1
                )
            },
            bestTimes: [
                StatsExportEnvelope.Best(
                    id: UUID(),
                    gameKindRaw: "minesweeper",
                    difficultyRaw: "hard",
                    seconds: 100,
                    achievedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
                    schemaVersion: 1
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)

        try StatsExporter.importing(data, modelContext: ctx)

        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 3)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).count == 1)
        // Original "easy" rows wiped.
        let easyAfter = try ctx.fetch(FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.difficultyRaw == "easy" }
        ))
        #expect(easyAfter.count == 0)
    }

    // MARK: - Encoder determinism — RESEARCH Pitfall 7

    @Test("Encoder is deterministic — two encodes of same envelope produce byte-equal Data (RESEARCH Pitfall 7)")
    func encoderDeterministic() throws {
        let env = StatsExportEnvelope(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
            gameRecords: (0..<10).map { i in
                StatsExportEnvelope.Record(
                    id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(i)")!,
                    gameKindRaw: "minesweeper",
                    difficultyRaw: i % 2 == 0 ? "easy" : "hard",
                    outcomeRaw: "win",
                    durationSeconds: Double(i),
                    playedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
                    schemaVersion: 1
                )
            },
            bestTimes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let a = try encoder.encode(env)
        let b = try encoder.encode(env)
        #expect(a == b, "two encodes of identical envelope must produce identical Data")
    }

    // MARK: - JSON keys = Swift property names — D-18

    @Test("JSON keys equal Swift property names (D-18)")
    func envelopeKeysMatchSwiftProperties() throws {
        let env = StatsExportEnvelope(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
            gameRecords: [
                StatsExportEnvelope.Record(
                    id: UUID(),
                    gameKindRaw: "minesweeper",
                    difficultyRaw: "easy",
                    outcomeRaw: "win",
                    durationSeconds: 12.0,
                    playedAt: Date(timeIntervalSinceReferenceDate: 700_000_000),
                    schemaVersion: 1
                )
            ],
            bestTimes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = String(data: try encoder.encode(env), encoding: .utf8)!

        for key in ["schemaVersion", "exportedAt", "gameRecords", "bestTimes",
                    "id", "gameKindRaw", "difficultyRaw", "outcomeRaw",
                    "durationSeconds", "playedAt"] {
            #expect(json.contains("\"\(key)\""), "missing JSON key \(key)")
        }
    }

    // MARK: - Decode-failed path

    @Test("Decode failure throws .decodeFailed; existing rows untouched")
    func decodeFailedThrows() throws {
        let (ctx, _) = try makeContext()
        ctx.insert(GameRecord(difficulty: "easy", outcome: .win, durationSeconds: 5))
        try ctx.save()

        let bad = Data("not valid json".utf8)
        #expect(throws: StatsImportError.decodeFailed) {
            try StatsExporter.importing(bad, modelContext: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 1)
    }

    // MARK: - Filename helper — D-19

    @Test("defaultExportFilename matches gamekit-stats-YYYY-MM-DD.json (D-19)")
    func defaultExportFilenameMatchesPattern() {
        // Pin a known date so the format check is deterministic.
        let date = Date(timeIntervalSince1970: 1_777_640_000)
        let name = StatsExporter.defaultExportFilename(now: date)
        #expect(name.hasPrefix("gamekit-stats-"))
        #expect(name.hasSuffix(".json"))
        // Ten chars between prefix and suffix: YYYY-MM-DD
        let middle = name.dropFirst("gamekit-stats-".count).dropLast(".json".count)
        #expect(middle.count == 10, "expected YYYY-MM-DD (10 chars), got '\(middle)'")
        #expect(middle.contains("-"))
    }
}
