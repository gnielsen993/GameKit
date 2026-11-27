import Testing
import Foundation
import SwiftData
@testable import gamekit

/// `GameStats.recordReportingBest` tells the caller whether a win set a
/// personal best and what the previous best was. The rule itself (assisted,
/// practice and non-win results never set a best) is unchanged; this suite
/// pins that the reported answer always matches what was written.
@Suite("RecordResult")
@MainActor
struct RecordResultTests {

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

    private static func win(
        _ stats: GameStats,
        seconds: Double,
        assistCount: Int? = nil,
        countsTowardRecords: Bool = true,
        outcome: Outcome = .win
    ) throws -> RecordResult {
        try stats.recordReportingBest(
            gameKind: .sudoku, difficulty: "easy",
            outcome: outcome, durationSeconds: seconds,
            assistCount: assistCount,
            countsTowardRecords: countsTowardRecords
        )
    }

    @Test("first unassisted win on an empty store sets a best with no previous")
    func firstWinSetsBest() throws {
        let (stats, ctx) = try Self.makeStats()
        let result = try Self.win(stats, seconds: 300)
        #expect(result == RecordResult(setBestTime: true, previousBest: nil))
        #expect(try Self.bestTimes(ctx).count == 1)
        #expect(try Self.bestTimes(ctx).first?.seconds == 300)
    }

    @Test("a faster win sets a best and reports the old one")
    func fasterWinSetsBest() throws {
        let (stats, ctx) = try Self.makeStats()
        _ = try Self.win(stats, seconds: 300)
        let result = try Self.win(stats, seconds: 250)
        #expect(result == RecordResult(setBestTime: true, previousBest: 300))
        #expect(try Self.bestTimes(ctx).count == 1)
        #expect(try Self.bestTimes(ctx).first?.seconds == 250)
    }

    @Test("a slower win sets no best and reports the standing one")
    func slowerWinSetsNoBest() throws {
        let (stats, ctx) = try Self.makeStats()
        _ = try Self.win(stats, seconds: 300)
        let result = try Self.win(stats, seconds: 400)
        #expect(result == RecordResult(setBestTime: false, previousBest: 300))
        #expect(try Self.bestTimes(ctx).first?.seconds == 300)
    }

    @Test("an equal time sets no best and does not rewrite the row")
    func equalTimeSetsNoBest() throws {
        let (stats, ctx) = try Self.makeStats()
        _ = try Self.win(stats, seconds: 300)
        let achievedAt = try #require(try Self.bestTimes(ctx).first?.achievedAt)
        let result = try Self.win(stats, seconds: 300)
        #expect(result == RecordResult(setBestTime: false, previousBest: 300))
        #expect(try Self.bestTimes(ctx).first?.achievedAt == achievedAt)
    }

    @Test("an assisted win is recorded but reports no record")
    func assistedWinReportsNoRecord() throws {
        let (stats, ctx) = try Self.makeStats()
        let result = try Self.win(stats, seconds: 30, assistCount: 1)
        #expect(result == .noRecord)
        #expect(try Self.bestTimes(ctx).isEmpty)
        #expect(try Self.records(ctx).count == 1)
    }

    @Test("a practice completion (countsTowardRecords false) reports no record")
    func practiceReportsNoRecord() throws {
        let (stats, ctx) = try Self.makeStats()
        let result = try Self.win(stats, seconds: 30, countsTowardRecords: false)
        #expect(result == .noRecord)
        #expect(try Self.bestTimes(ctx).isEmpty)
        #expect(try Self.records(ctx).count == 1)
    }

    @Test("a loss reports no record")
    func lossReportsNoRecord() throws {
        let (stats, ctx) = try Self.makeStats()
        let result = try Self.win(stats, seconds: 30, outcome: .loss)
        #expect(result == .noRecord)
        #expect(try Self.bestTimes(ctx).isEmpty)
        #expect(try Self.records(ctx).count == 1)
    }

    @Test("an assisted win cannot report a record over a stored best")
    func assistedWinOverStoredBest() throws {
        let (stats, ctx) = try Self.makeStats()
        _ = try Self.win(stats, seconds: 300)
        let result = try Self.win(stats, seconds: 100, assistCount: 2)
        #expect(result == .noRecord)
        #expect(try Self.bestTimes(ctx).first?.seconds == 300)
    }

    @Test("the Void record(...) forwarder still inserts the record and the best")
    func voidForwarderUnchanged() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .sudoku, difficulty: "easy",
            outcome: .win, durationSeconds: 200
        )
        #expect(try Self.records(ctx).count == 1)
        #expect(try Self.bestTimes(ctx).first?.seconds == 200)
    }

    @Test("best times are tracked per difficulty")
    func perDifficultyPreviousBest() throws {
        let (stats, _) = try Self.makeStats()
        _ = try Self.win(stats, seconds: 300)
        let hard = try stats.recordReportingBest(
            gameKind: .sudoku, difficulty: "hard",
            outcome: .win, durationSeconds: 900
        )
        #expect(hard == RecordResult(setBestTime: true, previousBest: nil))
    }
}
