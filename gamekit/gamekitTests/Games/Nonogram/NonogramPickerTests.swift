//
//  NonogramPickerTests.swift
//  gamekitTests
//
//  Picker contract after the 2026-07-10 freeze fix: picking is side-effect
//  free (seen is marked on first move by the VM), exhausted pools serve
//  the prefetch cache, and generation is never demanded synchronously.
//

import Foundation
import Testing
@testable import gamekit

@MainActor
struct NonogramPickerTests {

    @Test("nextInstant does not mutate the seen set")
    func nextInstantIsSideEffectFree() throws {
        let defaults = try makeDefaults()
        var rng: any RandomNumberGenerator = SeededRNG(seed: 1)

        let pick = NonogramPicker.nextInstant(difficulty: .tiny, userDefaults: defaults, rng: &rng)

        #expect(pick != nil)
        #expect(defaults.stringArray(forKey: NonogramPicker.seenKeyPrefix + "tiny") == nil)
    }

    @Test("nextInstant returns nil when curated pool exhausted and no cache")
    func exhaustedPoolWithoutCacheReturnsNil() throws {
        let defaults = try makeDefaults()
        markAllCuratedSeen(difficulty: .tiny, defaults: defaults)
        var rng: any RandomNumberGenerator = SeededRNG(seed: 1)

        let pick = NonogramPicker.nextInstant(difficulty: .tiny, userDefaults: defaults, rng: &rng)

        #expect(pick == nil)
        #expect(NonogramPicker.needsGeneration(for: .tiny, userDefaults: defaults))
    }

    @Test("exhausted pool serves the prefetched puzzle, repeatedly until marked seen")
    func exhaustedPoolServesCache() throws {
        let defaults = try makeDefaults()
        markAllCuratedSeen(difficulty: .tiny, defaults: defaults)
        let proc = NonogramGenerator.generate(difficulty: .tiny, seed: 7)
        NonogramPicker.storeCachedProcPuzzle(proc, for: .tiny, userDefaults: defaults)
        var rng: any RandomNumberGenerator = SeededRNG(seed: 1)

        let first = NonogramPicker.nextInstant(difficulty: .tiny, userDefaults: defaults, rng: &rng)
        let second = NonogramPicker.nextInstant(difficulty: .tiny, userDefaults: defaults, rng: &rng)

        #expect(first?.id == proc.id)
        #expect(second?.id == proc.id)  // unplayed → not consumed
        #expect(!NonogramPicker.needsGeneration(for: .tiny, userDefaults: defaults))
    }

    @Test("markSeen records the id and consumes a matching cache entry")
    func markSeenConsumesCache() throws {
        let defaults = try makeDefaults()
        let proc = NonogramGenerator.generate(difficulty: .tiny, seed: 7)
        NonogramPicker.storeCachedProcPuzzle(proc, for: .tiny, userDefaults: defaults)

        NonogramPicker.markSeen(puzzleId: proc.id, difficulty: .tiny, userDefaults: defaults)

        #expect(NonogramPicker.isSeen(proc.id, difficulty: .tiny, userDefaults: defaults))
        #expect(NonogramPicker.cachedProcPuzzle(for: .tiny, userDefaults: defaults) == nil)
    }

    @Test("markSeen keeps a non-matching cache entry")
    func markSeenKeepsUnrelatedCache() throws {
        let defaults = try makeDefaults()
        let proc = NonogramGenerator.generate(difficulty: .tiny, seed: 7)
        NonogramPicker.storeCachedProcPuzzle(proc, for: .tiny, userDefaults: defaults)

        NonogramPicker.markSeen(puzzleId: "tiny-001", difficulty: .tiny, userDefaults: defaults)

        #expect(NonogramPicker.cachedProcPuzzle(for: .tiny, userDefaults: defaults)?.id == proc.id)
    }

    @Test("mergeSeen unions synced ids into the frontier")
    func mergeSeenUnions() throws {
        let defaults = try makeDefaults()
        NonogramPicker.markSeen(puzzleId: "tiny-001", difficulty: .tiny, userDefaults: defaults)

        NonogramPicker.mergeSeen(
            ids: ["tiny-002", "tiny-003"], difficulty: .tiny, userDefaults: defaults
        )

        for id in ["tiny-001", "tiny-002", "tiny-003"] {
            #expect(NonogramPicker.isSeen(id, difficulty: .tiny, userDefaults: defaults))
        }
    }

    @Test("resetSeen clears both the frontier and the prefetch cache")
    func resetSeenClearsEverything() throws {
        let defaults = try makeDefaults()
        NonogramPicker.markSeen(puzzleId: "tiny-001", difficulty: .tiny, userDefaults: defaults)
        let proc = NonogramGenerator.generate(difficulty: .tiny, seed: 7)
        NonogramPicker.storeCachedProcPuzzle(proc, for: .tiny, userDefaults: defaults)

        NonogramPicker.resetSeen(userDefaults: defaults)

        #expect(!NonogramPicker.isSeen("tiny-001", difficulty: .tiny, userDefaults: defaults))
        #expect(NonogramPicker.cachedProcPuzzle(for: .tiny, userDefaults: defaults) == nil)
    }

    @Test("cache rejects a puzzle whose grid doesn't fit the difficulty")
    func cacheRejectsWrongSize() throws {
        let defaults = try makeDefaults()
        let wrongSize = NonogramGenerator.generate(difficulty: .small, seed: 7)

        NonogramPicker.storeCachedProcPuzzle(wrongSize, for: .tiny, userDefaults: defaults)

        #expect(NonogramPicker.cachedProcPuzzle(for: .tiny, userDefaults: defaults) == nil)
    }

    // MARK: - Helpers

    private func markAllCuratedSeen(difficulty: NonogramDifficulty, defaults: UserDefaults) {
        let ids = Set(NonogramLibrary.puzzles(for: difficulty).map(\.id))
        NonogramPicker.mergeSeen(ids: ids, difficulty: difficulty, userDefaults: defaults)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "NonogramPickerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
