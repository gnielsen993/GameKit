import Testing
import Foundation
import SwiftData
@testable import gamekit

/// Coverage for the arcade game-over run summary.
///
/// The v1.5 spec asked for a run summary with a personal-best indicator; both
/// banners shipped with `subtitle: nil`, and Stack had no best-score awareness
/// at all. Dying told you nothing about what you were chasing or whether you
/// had just beaten it.
///
/// The load-bearing detail is that `bestScoreAtStart` must hold the *pre-run*
/// value. The game-over write updates the stored best before the banner
/// renders, so a view re-reading GameStats at that moment would always see a
/// tie and could never say "new best".
@Suite("Arcade run summary")
@MainActor
struct ArcadeRunSummaryTests {

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    // MARK: - Stack

    @Test("Stack seeds the stored best when stats attach")
    func stackSeedsBestOnAttach() throws {
        let (stats, _) = try Self.makeStats()
        try stats.recordStackRun(score: 42, perfectStreak: 3)

        let vm = StackViewModel()
        #expect(vm.bestScoreAtStart == 0)
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 42)
    }

    @Test("Stack reports no new best before the run passes it")
    func stackNotNewBestBelowThreshold() throws {
        let (stats, _) = try Self.makeStats()
        try stats.recordStackRun(score: 42, perfectStreak: 3)

        let vm = StackViewModel()
        vm.attachGameStats(stats)
        // A fresh run starts at score 0, well under the stored 42.
        #expect(vm.isNewBest == false)
    }

    @Test("a first-ever Stack run never claims a new best")
    func stackFirstRunNoFalseBest() throws {
        let (stats, _) = try Self.makeStats()
        let vm = StackViewModel()
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 0)
        // Stack's score floor is 1 — the base block is already placed — so a
        // naive `score > best` would fire on an empty history. With nothing
        // stored there is no record to break.
        #expect(vm.frame.score >= 1)
        #expect(vm.isNewBest == false)
    }

    @Test("a first-ever Snake run never claims a new best")
    func snakeFirstRunNoFalseBest() throws {
        let (stats, _) = try Self.makeStats()
        let vm = SnakeViewModel()
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 0)
        #expect(vm.isNewBest == false)
    }

    @Test("Stack re-reads the stored best on restart")
    func stackRestartRereadsBest() throws {
        let (stats, _) = try Self.makeStats()
        let vm = StackViewModel()
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 0)

        // A run lands in the store while this VM is alive.
        try stats.recordStackRun(score: 99, perfectStreak: 5)
        vm.restart()
        #expect(vm.bestScoreAtStart == 99)
    }

    // MARK: - Snake

    @Test("Snake seeds the stored best when stats attach")
    func snakeSeedsBestOnAttach() throws {
        let (stats, _) = try Self.makeStats()
        try stats.record(
            gameKind: .snake,
            mode: GameStats.snakeEndlessMode,
            outcome: .loss,
            score: 17
        )

        let vm = SnakeViewModel()
        #expect(vm.bestScoreAtStart == 0)
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 17)
    }

    @Test("Snake reports no new best before the run passes it")
    func snakeNotNewBestBelowThreshold() throws {
        let (stats, _) = try Self.makeStats()
        try stats.record(
            gameKind: .snake,
            mode: GameStats.snakeEndlessMode,
            outcome: .loss,
            score: 17
        )

        let vm = SnakeViewModel()
        vm.attachGameStats(stats)
        #expect(vm.isNewBest == false)
    }

    @Test("Snake re-reads the stored best on restart")
    func snakeRestartRereadsBest() throws {
        let (stats, _) = try Self.makeStats()
        let vm = SnakeViewModel()
        vm.attachGameStats(stats)
        #expect(vm.bestScoreAtStart == 0)

        try stats.record(
            gameKind: .snake,
            mode: GameStats.snakeEndlessMode,
            outcome: .loss,
            score: 31
        )
        vm.restart()
        #expect(vm.bestScoreAtStart == 31)
    }

    @Test("attach is one-shot and does not re-seed on a second call")
    func snakeAttachIsOneShot() throws {
        let (stats, _) = try Self.makeStats()
        let vm = SnakeViewModel()
        vm.attachGameStats(stats)

        try stats.record(
            gameKind: .snake,
            mode: GameStats.snakeEndlessMode,
            outcome: .loss,
            score: 55
        )
        vm.attachGameStats(stats)   // guarded no-op
        #expect(vm.bestScoreAtStart == 0)
    }
}
