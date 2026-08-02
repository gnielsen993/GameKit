import Testing
import Foundation
import SwiftData
@testable import gamekit

/// Regression coverage for the Merge "Best" number being session-local.
///
/// `bestScore` drives the header chip, the Video Mode chips, and the
/// "Best: N" line on the end-state card. It was only ever raised by
/// `handleSwipe`, so a fresh launch showed Best 0 and then presented the
/// current run as an all-time best — a number labelled "Best" that meant
/// "best since you opened the app."
@Suite("Merge best score")
@MainActor
struct MergeBestScoreTests {

    private static func isolatedDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    /// Plays a completed run worth `score` so GameStats stores a BestScore.
    private static func seedBestScore(_ stats: GameStats, mode: MergeMode, score: Int) throws {
        try stats.record(gameKind: .merge, mode: mode.rawValue, outcome: .loss, score: score)
    }

    @Test("a freshly attached VM shows the stored best, not zero")
    func attachSeedsStoredBest() throws {
        let (stats, _) = try Self.makeStats()
        try Self.seedBestScore(stats, mode: .winMode, score: 4096)

        let vm = MergeViewModel(
            mode: .winMode,
            userDefaults: Self.isolatedDefaults(),
            rng: SeededGenerator(seed: 1)
        )
        #expect(vm.bestScore == 0)   // nothing attached yet
        vm.attachGameStats(stats)
        #expect(vm.bestScore == 4096)
    }

    @Test("a VM given stats at init shows the stored best immediately")
    func initSeedsStoredBest() throws {
        let (stats, _) = try Self.makeStats()
        try Self.seedBestScore(stats, mode: .winMode, score: 1234)

        let vm = MergeViewModel(
            mode: .winMode,
            userDefaults: Self.isolatedDefaults(),
            rng: SeededGenerator(seed: 1),
            gameStats: stats
        )
        #expect(vm.bestScore == 1234)
    }

    @Test("best survives a restart")
    func bestSurvivesRestart() throws {
        let (stats, _) = try Self.makeStats()
        try Self.seedBestScore(stats, mode: .winMode, score: 900)

        let vm = MergeViewModel(
            mode: .winMode,
            userDefaults: Self.isolatedDefaults(),
            rng: SeededGenerator(seed: 1),
            gameStats: stats
        )
        vm.restart()
        #expect(vm.score == 0)
        #expect(vm.bestScore == 900)
    }

    @Test("switching mode re-reads the best for that mode")
    func modeSwitchRereadsBest() throws {
        let (stats, _) = try Self.makeStats()
        try Self.seedBestScore(stats, mode: .winMode, score: 500)
        try Self.seedBestScore(stats, mode: .infinite, score: 8000)

        let vm = MergeViewModel(
            mode: .winMode,
            userDefaults: Self.isolatedDefaults(),
            rng: SeededGenerator(seed: 1),
            gameStats: stats
        )
        #expect(vm.bestScore == 500)
        vm.setMode(.infinite)
        #expect(vm.bestScore == 8000)
        vm.setMode(.winMode)
        #expect(vm.bestScore == 500)
    }

    @Test("a live run never appears to lose ground to a lower stored best")
    func liveRunNeverRegresses() throws {
        let (stats, _) = try Self.makeStats()
        try Self.seedBestScore(stats, mode: .winMode, score: 10)

        let vm = MergeViewModel(
            mode: .winMode,
            userDefaults: Self.isolatedDefaults(),
            rng: SeededGenerator(seed: 7),
            gameStats: stats
        )
        // Drive the board until the run outscores the stored best.
        var guard_ = 0
        while vm.score <= 10 && guard_ < 200 {
            for direction in [SwipeDirection.left, .up, .right, .down] {
                vm.handleSwipe(direction)
            }
            guard_ += 1
        }
        #expect(vm.score > 10)
        #expect(vm.bestScore >= vm.score)
    }
}
