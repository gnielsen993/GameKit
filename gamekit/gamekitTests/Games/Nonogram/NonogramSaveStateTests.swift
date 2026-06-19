//
//  NonogramSaveStateTests.swift
//  gamekitTests
//

import Foundation
import Testing
@testable import gamekit

@MainActor
struct NonogramSaveStateTests {

    @Test("stale terminal lives save is discarded instead of restored")
    func staleTerminalLivesSaveIsDiscarded() throws {
        let defaults = try makeDefaults()
        let key = NonogramSaveState.key(difficulty: .large, gameMode: .lives)
        let saved = NonogramSaveState(
            puzzleId: "stale-large",
            puzzleGrid: String(repeating: "0", count: 400),
            puzzleTitle: "Stale",
            cells: Array(repeating: .marked, count: 400),
            size: 20,
            difficulty: NonogramDifficulty.large.rawValue,
            gameMode: NonogramGameMode.lives.rawValue,
            livesRemaining: 0,
            lockedCellIndices: [],
            elapsedSeconds: 12,
            savedAt: Date.now
        )
        defaults.set(try JSONEncoder().encode(saved), forKey: key)

        let vm = NonogramViewModel(difficulty: .large, mode: .lives, userDefaults: defaults)
        vm.checkAndLoadOrRestoreState()

        #expect(vm.pendingSaveState == nil)
        #expect(defaults.data(forKey: key) == nil)
    }

    @Test("mismatched saved size is discarded instead of restored")
    func mismatchedSavedSizeIsDiscarded() throws {
        let defaults = try makeDefaults()
        let key = NonogramSaveState.key(difficulty: .large, gameMode: .free)
        let saved = NonogramSaveState(
            puzzleId: "bad-size",
            puzzleGrid: String(repeating: "0", count: 225),
            puzzleTitle: "Bad Size",
            cells: Array(repeating: .empty, count: 225),
            size: 15,
            difficulty: NonogramDifficulty.large.rawValue,
            gameMode: NonogramGameMode.free.rawValue,
            livesRemaining: NonogramGameMode.livesPerPuzzle,
            lockedCellIndices: [],
            elapsedSeconds: 9,
            savedAt: Date.now
        )
        defaults.set(try JSONEncoder().encode(saved), forKey: key)

        let vm = NonogramViewModel(difficulty: .large, mode: .free, userDefaults: defaults)
        vm.checkAndLoadOrRestoreState()

        #expect(vm.pendingSaveState == nil)
        #expect(defaults.data(forKey: key) == nil)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "NonogramSaveStateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
