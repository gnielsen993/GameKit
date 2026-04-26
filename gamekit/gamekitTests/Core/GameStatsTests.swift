//
//  GameStatsTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 04-02 write-side boundary
//  (GameStats). Verifies D-11 (single firewall), D-12 (insert-then-
//  evaluate-BestTime; insert-or-mutate; faster-only), D-13 (resetAll
//  atomic via transaction), and SC1's literal mandate — explicit
//  `try modelContext.save()` is wired (not autosave).
//
//  Per D-30 (Swift Testing) and D-31 (in-memory container per test).
//
//  Why @MainActor struct (NOT P2's nonisolated struct):
//  SwiftData ModelContext is not Sendable per RESEARCH Pattern 6
//  [hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency].
//  Locked as the standard for ALL P4 Core tests in 04-01.
//

import Testing
import Foundation
import SwiftData
@testable import gamekit

@MainActor
@Suite("GameStats")
struct GameStatsTests {

    // Per D-31: fresh container per test. ~1ms init; avoids parallel-execution
    // row-bleed under Swift Testing's default concurrent execution.
    private func makeStats() throws -> (GameStats, ModelContext, ModelContainer) {
        let container = try InMemoryStatsContainer.make()
        let context = ModelContext(container)
        let stats = GameStats(modelContext: context)
        return (stats, context, container)
    }

    // MARK: - record(...) — D-12 step 1+2

    @Test("recordWin inserts both GameRecord and BestTime, then saves")
    func recordWin() throws {
        let (stats, ctx, _) = try makeStats()
        try stats.record(
            gameKind: .minesweeper,
            difficulty: "hard",
            outcome: .win,
            durationSeconds: 102.5
        )
        let records = try ctx.fetch(FetchDescriptor<GameRecord>())
        let bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(records.count == 1)
        #expect(records.first?.outcomeRaw == "win")
        #expect(records.first?.durationSeconds == 102.5)
        #expect(records.first?.difficultyRaw == "hard")
        #expect(records.first?.gameKindRaw == "minesweeper")
        #expect(bests.count == 1)
        #expect(bests.first?.seconds == 102.5)
        #expect(bests.first?.difficultyRaw == "hard")
        #expect(bests.first?.gameKindRaw == "minesweeper")
    }

    @Test("recordLoss inserts only GameRecord, no BestTime")
    func recordLoss() throws {
        let (stats, ctx, _) = try makeStats()
        try stats.record(
            gameKind: .minesweeper,
            difficulty: "easy",
            outcome: .loss,
            durationSeconds: 5.0
        )
        let records = try ctx.fetch(FetchDescriptor<GameRecord>())
        let bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(records.count == 1)
        #expect(records.first?.outcomeRaw == "loss")
        #expect(bests.count == 0)
    }

    // MARK: - BestTime semantics — D-12

    @Test("BestTime updates only when faster; slower win is a no-op on BestTime")
    func bestTimeOnlyOnFaster() throws {
        let (stats, ctx, _) = try makeStats()
        // Seed an initial best of 100s on hard.
        try stats.record(gameKind: .minesweeper, difficulty: "hard",
                         outcome: .win, durationSeconds: 100.0)
        // Slower win: 150s — must NOT replace.
        try stats.record(gameKind: .minesweeper, difficulty: "hard",
                         outcome: .win, durationSeconds: 150.0)
        var bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(bests.count == 1, "must NOT insert a second BestTime row")
        #expect(bests.first?.seconds == 100.0, "slower win must NOT replace existing best")
        // Faster win: 80s — must mutate in place (no new row).
        try stats.record(gameKind: .minesweeper, difficulty: "hard",
                         outcome: .win, durationSeconds: 80.0)
        bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(bests.count == 1, "faster win must mutate in place, not insert")
        #expect(bests.first?.seconds == 80.0)
        // GameRecord rows still accumulate every call.
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 3)
    }

    @Test("BestTime is per-difficulty — easy and hard tracked independently")
    func bestTimeIsolatedPerDifficulty() throws {
        let (stats, ctx, _) = try makeStats()
        try stats.record(gameKind: .minesweeper, difficulty: "easy",
                         outcome: .win, durationSeconds: 12.0)
        try stats.record(gameKind: .minesweeper, difficulty: "hard",
                         outcome: .win, durationSeconds: 200.0)
        let bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(bests.count == 2)
        // Mutate easy; hard untouched.
        try stats.record(gameKind: .minesweeper, difficulty: "easy",
                         outcome: .win, durationSeconds: 8.0)
        let again = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(again.count == 2)
        #expect(again.first(where: { $0.difficultyRaw == "easy" })?.seconds == 8.0)
        #expect(again.first(where: { $0.difficultyRaw == "hard" })?.seconds == 200.0)
    }

    @Test("BestTime predicate filters by gameKindRaw — game-2 isolation wired")
    func bestTimeIsolatedPerGameKind() throws {
        // Plan 04 ships only .minesweeper, so this test simulates a future
        // game-2 row by inserting a hand-built BestTime with a different
        // gameKindRaw and asserting the predicate ignores it. When a second
        // game ships its GameKind case, this fixture changes to that game's
        // actual rawValue (additive — no test rewrite required).
        let (stats, ctx, _) = try makeStats()
        let foreign = BestTime(gameKind: .minesweeper, difficulty: "easy", seconds: 30.0)
        foreign.gameKindRaw = "future-game"   // simulate a different game
        ctx.insert(foreign)
        try ctx.save()
        // Now record a Mines easy win at 50s — slower than the foreign 30s
        // but they're different gameKindRaw values, so foreign must stay
        // and a NEW BestTime row must be inserted for minesweeper/easy.
        try stats.record(gameKind: .minesweeper, difficulty: "easy",
                         outcome: .win, durationSeconds: 50.0)
        let bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(bests.count == 2, "predicate must isolate per-gameKindRaw")
        let foreignAfter = bests.first(where: { $0.gameKindRaw == "future-game" })
        #expect(foreignAfter?.seconds == 30.0, "foreign-game BestTime must be untouched")
        let mineAfter = bests.first(where: {
            $0.gameKindRaw == "minesweeper" && $0.difficultyRaw == "easy"
        })
        #expect(mineAfter?.seconds == 50.0, "minesweeper/easy BestTime must be inserted fresh")
    }

    // MARK: - resetAll — D-13

    @Test("resetAll deletes both GameRecord and BestTime atomically")
    func resetAllAtomic() throws {
        let (stats, ctx, _) = try makeStats()
        // Pre-populate with 3 wins on easy (each faster than the last so
        // BestTime mutates in place — final state: 3 GameRecord + 1 BestTime).
        for i in 0..<3 {
            try stats.record(gameKind: .minesweeper, difficulty: "easy",
                             outcome: .win, durationSeconds: Double(20 - i * 5))
        }
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 3)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).count == 1)
        try stats.resetAll()
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 0)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).count == 0)
    }

    @Test("resetAll on empty store is a no-op (does not throw)")
    func resetAllEmptyIsNoop() throws {
        let (stats, ctx, _) = try makeStats()
        try stats.resetAll()
        // Confirm the store is still queryable (transaction left it healthy).
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 0)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).count == 0)
    }

    // MARK: - Equal-seconds no-op (calmer fewer-writes choice)

    @Test("equal-seconds win does not mutate existing BestTime (calmer no-op)")
    func equalSecondsIsNoop() async throws {
        let (stats, ctx, _) = try makeStats()
        try stats.record(gameKind: .minesweeper, difficulty: "medium",
                         outcome: .win, durationSeconds: 60.0)
        let firstAchievedAt = try ctx.fetch(FetchDescriptor<BestTime>()).first?.achievedAt
        // Wait a tick so achievedAt would clearly differ if the impl mutated.
        try await Task.sleep(nanoseconds: 5_000_000)   // 5ms
        try stats.record(gameKind: .minesweeper, difficulty: "medium",
                         outcome: .win, durationSeconds: 60.0)
        let bests = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(bests.count == 1, "equal-seconds win must not insert a second BestTime")
        #expect(bests.first?.seconds == 60.0)
        #expect(bests.first?.achievedAt == firstAchievedAt,
                "equal-seconds win must NOT mutate achievedAt — strictly-faster only")
        #expect(try ctx.fetch(FetchDescriptor<GameRecord>()).count == 2,
                "GameRecord still appends every call")
    }
}
