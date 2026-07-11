//
//  NonogramPicker.swift
//  gamekit
//
//  Selects the next puzzle for the Nonogram VM. Curated puzzles cycle
//  first (each shown once before any repeat); after the entire curated
//  pool for a difficulty is exhausted, procedural puzzles take over
//  (Unlimited tier) via a prefetched cache — generation itself is the
//  VM's job (off the main thread) because it can take seconds at 20×20.
//
//  Picking has NO side effects. A puzzle counts as "seen" only when the
//  VM calls `markSeen` on the player's first move — opening the screen,
//  restoring a save, or SwiftUI re-constructing the view must not burn
//  entries from the curated pool (pick-time marking (pre-2026-07-10),
//  which drained pools several entries per visit without play).
//
//  "Seen" tracking is per-difficulty in UserDefaults. It is rebuilt from
//  synced GameRecord wins on stats attach (see NonogramViewModel) so an
//  app reinstall with iCloud sync / stats import doesn't restart the
//  curated rotation. Resets when stats reset.
//
//  Foundation-only · no SwiftUI / SwiftData (CLAUDE §4 engine purity).
//

import Foundation

enum NonogramPicker {

    /// UserDefaults key for the per-difficulty seen-puzzle-id sets.
    /// Renaming = data break (player loses their "all seen" frontier
    /// and curated cycle restarts).
    static let seenKeyPrefix = "nonogram.seenPuzzleIds."

    /// UserDefaults key for the per-difficulty prefetched procedural
    /// puzzle (JSON-encoded NonogramPuzzle). Renaming = one lost
    /// prefetch, regenerated on next play — not a data break.
    static let cacheKeyPrefix = "nonogram.nextProcPuzzle."

    /// Pick the next puzzle for `difficulty` WITHOUT side effects.
    /// Order: unseen curated → prefetched procedural cache → nil.
    /// nil means the caller must generate procedurally (expensive —
    /// run it off the main thread).
    static func nextInstant(
        difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard,
        rng: inout any RandomNumberGenerator
    ) -> NonogramPuzzle? {
        #if DEBUG
        // STRESS-TEST OVERRIDE — checkerboard puzzle generates the
        // worst-case hint count per row + per column. Used to inspect
        // hint-header layout under maximum density. REVERT before ship.
        if Self.stressMode {
            return checkerboard(for: difficulty)
        }
        #endif
        let pool = NonogramLibrary.puzzles(for: difficulty)
        let seen = seenIds(for: difficulty, userDefaults: userDefaults)

        // 1) Unseen curated puzzle.
        let unseen = pool.filter { !seen.contains($0.id) }
        if let pick = unseen.randomElement(using: &rng) {
            return pick
        }

        // 2) Prefetched procedural puzzle. Served repeatedly until the
        //    player actually starts it (markSeen clears the cache).
        return cachedProcPuzzle(for: difficulty, userDefaults: userDefaults)
    }

    /// Record that the player actually started `puzzleId` (first move).
    /// Clears the prefetch cache when it held this puzzle so the next
    /// pick generates or serves a fresh one.
    static func markSeen(
        puzzleId: String,
        difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) {
        var seen = seenIds(for: difficulty, userDefaults: userDefaults)
        seen.insert(puzzleId)
        userDefaults.set(Array(seen), forKey: seenKeyPrefix + difficulty.rawValue)
        if cachedProcPuzzle(for: difficulty, userDefaults: userDefaults)?.id == puzzleId {
            userDefaults.removeObject(forKey: cacheKeyPrefix + difficulty.rawValue)
        }
    }

    /// Union `ids` into the seen set. Used to rebuild the curated
    /// frontier from synced GameRecord wins after reinstall / import.
    static func mergeSeen(
        ids: Set<String>,
        difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) {
        guard !ids.isEmpty else { return }
        let seen = seenIds(for: difficulty, userDefaults: userDefaults)
        let merged = seen.union(ids)
        guard merged.count > seen.count else { return }
        userDefaults.set(Array(merged), forKey: seenKeyPrefix + difficulty.rawValue)
    }

    static func isSeen(
        _ puzzleId: String,
        difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        seenIds(for: difficulty, userDefaults: userDefaults).contains(puzzleId)
    }

    /// True when the next pick for `difficulty` would find neither an
    /// unseen curated puzzle nor a cached procedural one — i.e. the VM
    /// should generate (or prefetch) in the background.
    static func needsGeneration(
        for difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        let seen = seenIds(for: difficulty, userDefaults: userDefaults)
        let pool = NonogramLibrary.puzzles(for: difficulty)
        guard pool.allSatisfy({ seen.contains($0.id) }) else { return false }
        return cachedProcPuzzle(for: difficulty, userDefaults: userDefaults) == nil
    }

    /// The prefetched procedural puzzle for `difficulty`, if any.
    /// Invalid payloads (size mismatch, bad grid) are dropped.
    static func cachedProcPuzzle(
        for difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) -> NonogramPuzzle? {
        let key = cacheKeyPrefix + difficulty.rawValue
        guard let data = userDefaults.data(forKey: key),
              let puzzle = try? JSONDecoder().decode(NonogramPuzzle.self, from: data) else {
            return nil
        }
        guard puzzle.isValid(for: difficulty.size) else {
            userDefaults.removeObject(forKey: key)
            return nil
        }
        return puzzle
    }

    /// Store a background-generated puzzle for instant serving later.
    static func storeCachedProcPuzzle(
        _ puzzle: NonogramPuzzle,
        for difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard
    ) {
        guard puzzle.isValid(for: difficulty.size),
              let data = try? JSONEncoder().encode(puzzle) else { return }
        userDefaults.set(data, forKey: cacheKeyPrefix + difficulty.rawValue)
    }

    /// Forget every "seen" id and prefetched puzzle for every difficulty.
    /// Wired to SettingsStore reset-stats so a clean account starts
    /// curated rotation from scratch.
    static func resetSeen(userDefaults: UserDefaults = .standard) {
        for d in NonogramDifficulty.allCases {
            userDefaults.removeObject(forKey: seenKeyPrefix + d.rawValue)
            userDefaults.removeObject(forKey: cacheKeyPrefix + d.rawValue)
        }
    }

    // MARK: - Private

    private static func seenIds(
        for difficulty: NonogramDifficulty,
        userDefaults: UserDefaults
    ) -> Set<String> {
        Set(userDefaults.stringArray(forKey: seenKeyPrefix + difficulty.rawValue) ?? [])
    }

    #if DEBUG
    /// Flip to `true` to force every puzzle pick to a checkerboard with
    /// max-density hints (every row + every col is `[1, 1, 1, …]`).
    /// REVERT to `false` before merging to ship.
    static let stressMode: Bool = false

    /// Synthetic checkerboard puzzle for hint-header stress testing.
    /// 5×5 → 3 hints per row/col, 10×10 → 5, 15×15 → 8, 20×20 → 10.
    private static func checkerboard(for difficulty: NonogramDifficulty) -> NonogramPuzzle {
        let n = difficulty.size
        var bits = ""
        for r in 0..<n {
            for c in 0..<n {
                bits.append((r + c) % 2 == 0 ? "1" : "0")
            }
        }
        return NonogramPuzzle(
            id: "stress-\(difficulty.rawValue)",
            title: "Stress (debug)",
            grid: bits
        )
    }
    #endif
}
