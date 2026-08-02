import Testing
import Foundation
import SwiftData
@testable import gamekit

/// The v1.6 record ruling, enforced at the one place that can honour it.
///
/// An assisted win is a win: it is inserted, it counts toward games played,
/// win rate, and streaks. It does not write a `BestTime`. A record is a claim
/// about unaided play, so it stops being worth keeping the moment it stops
/// being that — but nothing else about the win is diminished.
@Suite("Assist record semantics")
@MainActor
struct AssistRecordSemanticsTests {

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    private static func bestTimes(_ ctx: ModelContext) throws -> [BestTime] {
        try ctx.fetch(FetchDescriptor<BestTime>())
    }

    private static func records(_ ctx: ModelContext) throws -> [GameRecord] {
        try ctx.fetch(FetchDescriptor<GameRecord>())
    }

    @Test("an unaided win still writes a best time")
    func unaidedWinSetsBestTime() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 90
        )
        #expect(try Self.bestTimes(ctx).count == 1)
    }

    @Test("an assisted win is recorded but sets no best time")
    func assistedWinSetsNoBestTime() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 30, assistCount: 1
        )
        // The win itself counts — this is the half that must not regress.
        let records = try Self.records(ctx)
        #expect(records.count == 1)
        #expect(records.first?.outcomeRaw == Outcome.win.rawValue)
        #expect(records.first?.wasAssisted == true)
        // The record does not.
        #expect(try Self.bestTimes(ctx).isEmpty)
    }

    @Test("a fast assisted win cannot displace a slower unaided best")
    func assistedWinCannotBeatStoredBest() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 120
        )
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 5, assistCount: 3
        )
        let best = try Self.bestTimes(ctx)
        #expect(best.count == 1)
        #expect(best.first?.seconds == 120)   // the honest time survives
        #expect(try Self.records(ctx).count == 2)
    }

    @Test("assistCount zero is unaided, not assisted")
    func zeroAssistsCountsAsUnaided() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 60, assistCount: 0
        )
        #expect(try Self.bestTimes(ctx).count == 1)
        #expect(try Self.records(ctx).first?.wasAssisted == false)
    }

    @Test("a record predating assists reads as unaided")
    func legacyRecordIsUnaided() {
        let record = GameRecord(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .win, durationSeconds: 60
        )
        #expect(record.assistCount == nil)
        #expect(record.wasAssisted == false)
    }

    @Test("an assisted loss is recorded like any other loss")
    func assistedLossIsRecorded() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .nonogram, difficulty: "10x10",
            outcome: .loss, durationSeconds: 45, assistCount: 2
        )
        #expect(try Self.records(ctx).count == 1)
        #expect(try Self.bestTimes(ctx).isEmpty)
    }

    @Test("assists default to on so help is offered, not hidden")
    func assistsDefaultOn() {
        let suite = UserDefaults(suiteName: "AssistRecordSemanticsTests.\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }
        let store = SettingsStore(userDefaults: suite)
        #expect(store.assistsEnabled)
    }

    @Test("turning assists off persists")
    func assistsTogglePersists() {
        let name = "AssistRecordSemanticsTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { suite.removePersistentDomain(forName: name) }

        let store = SettingsStore(userDefaults: suite)
        store.assistsEnabled = false
        // A fresh store must read the stored false rather than the default.
        let reloaded = SettingsStore(userDefaults: suite)
        #expect(reloaded.assistsEnabled == false)
    }
}
