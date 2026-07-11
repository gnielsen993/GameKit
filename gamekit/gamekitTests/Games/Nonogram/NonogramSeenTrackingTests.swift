//
//  NonogramSeenTrackingTests.swift
//  gamekitTests
//
//  VM-level contract for the 2026-07-10 seen-tracking rework: opening the
//  screen burns nothing, the first move marks the puzzle seen, and
//  attaching GameStats rebuilds the frontier from synced wins so a
//  reinstall doesn't re-serve solved puzzles.
//

import Foundation
import SwiftData
import Testing
@testable import gamekit

@MainActor
struct NonogramSeenTrackingTests {

    @Test("init does not mark the picked puzzle seen; the first move does")
    func firstMoveMarksSeen() throws {
        let defaults = try makeDefaults()
        let vm = NonogramViewModel(difficulty: .tiny, mode: .free, userDefaults: defaults)
        let picked = try #require(vm.currentPuzzle)

        #expect(!NonogramPicker.isSeen(picked.id, difficulty: .tiny, userDefaults: defaults))

        vm.handleTap(at: 0, col: 0)

        #expect(vm.state == .playing)
        #expect(NonogramPicker.isSeen(picked.id, difficulty: .tiny, userDefaults: defaults))
    }

    @Test("attachGameStats merges synced wins into the seen frontier")
    func attachMergesWonRecords() throws {
        let defaults = try makeDefaults()
        let (stats, container) = try makeStats()
        _ = container  // keep the in-memory store alive for the test body
        try stats.record(
            gameKind: .nonogram,
            difficulty: NonogramDifficulty.tiny.rawValue,
            outcome: .win,
            durationSeconds: 60,
            puzzleId: "tiny-777"
        )
        // A loss and a foreign-game win must NOT merge.
        try stats.record(
            gameKind: .nonogram,
            difficulty: NonogramDifficulty.tiny.rawValue,
            outcome: .loss,
            durationSeconds: 60,
            puzzleId: "tiny-888"
        )
        try stats.record(
            gameKind: .sudoku,
            difficulty: "easy",
            outcome: .win,
            durationSeconds: 60,
            puzzleId: "sudoku-1"
        )

        let vm = NonogramViewModel(difficulty: .tiny, mode: .free, userDefaults: defaults)
        vm.attachGameStats(stats)

        #expect(NonogramPicker.isSeen("tiny-777", difficulty: .tiny, userDefaults: defaults))
        #expect(!NonogramPicker.isSeen("tiny-888", difficulty: .tiny, userDefaults: defaults))
        #expect(!NonogramPicker.isSeen("sudoku-1", difficulty: .tiny, userDefaults: defaults))
    }

    @Test("already-won init pick is swapped out after the merge")
    func mergedWinRefreshesFrontier() throws {
        let defaults = try makeDefaults()
        // Leave exactly one curated tiny puzzle unseen so init must pick it.
        let pool = NonogramLibrary.puzzles(for: .tiny)
        let lastUnseen = try #require(pool.last)
        NonogramPicker.mergeSeen(
            ids: Set(pool.dropLast().map(\.id)),
            difficulty: .tiny,
            userDefaults: defaults
        )

        let vm = NonogramViewModel(difficulty: .tiny, mode: .free, userDefaults: defaults)
        #expect(vm.currentPuzzle?.id == lastUnseen.id)

        // Synced history says the player already solved that puzzle.
        let (stats, container) = try makeStats()
        _ = container  // keep the in-memory store alive for the test body
        try stats.record(
            gameKind: .nonogram,
            difficulty: NonogramDifficulty.tiny.rawValue,
            outcome: .win,
            durationSeconds: 60,
            puzzleId: lastUnseen.id
        )
        vm.attachGameStats(stats)

        // Pool is now fully seen → the stale pick is dropped and async
        // procedural generation takes over (loading state, never a
        // synchronous main-thread generate).
        #expect(vm.currentPuzzle?.id != lastUnseen.id)
        if vm.currentPuzzle == nil {
            #expect(vm.isGeneratingPuzzle)
        }
    }

    @Test("restoring a save keeps the resumed puzzle marked seen")
    func restoreMarksSeen() throws {
        let defaults = try makeDefaults()
        let vm = NonogramViewModel(difficulty: .tiny, mode: .free, userDefaults: defaults)
        let puzzle = try #require(vm.currentPuzzle)
        let saved = NonogramSaveState(
            puzzleId: puzzle.id,
            puzzleGrid: puzzle.grid,
            puzzleTitle: puzzle.title,
            cells: Array(repeating: .empty, count: 25),
            size: 5,
            difficulty: NonogramDifficulty.tiny.rawValue,
            gameMode: NonogramGameMode.free.rawValue,
            livesRemaining: NonogramGameMode.livesPerPuzzle,
            lockedCellIndices: [],
            elapsedSeconds: 3,
            savedAt: Date.now
        )

        vm.restoreState(saved)

        #expect(vm.state == .playing)
        #expect(NonogramPicker.isSeen(puzzle.id, difficulty: .tiny, userDefaults: defaults))
    }

    // MARK: - Helpers

    private func makeStats() throws -> (GameStats, ModelContainer) {
        let schema = Schema([GameRecord.self, BestTime.self, BestScore.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (GameStats(modelContext: container.mainContext), container)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "NonogramSeenTrackingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
