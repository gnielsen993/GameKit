//
//  NonogramPicker.swift
//  gamekit
//
//  Selects the next puzzle for the Nonogram VM. Curated puzzles cycle
//  first (each shown once before any repeat); after the entire curated
//  pool for a difficulty is exhausted, falls through to procedural
//  generation (Unlimited tier).
//
//  "Seen" tracking is per-difficulty in UserDefaults — local-only;
//  we deliberately don't sync this via SwiftData/iCloud for v1.1
//  (smaller state surface, no schema bump). Resets when stats reset.
//
//  Foundation-only · no SwiftUI / SwiftData (CLAUDE §4 engine purity).
//

import Foundation

enum NonogramPicker {

    /// UserDefaults key for the per-difficulty seen-puzzle-id sets.
    /// Renaming = data break (player loses their "all seen" frontier
    /// and curated cycle restarts).
    static let seenKeyPrefix = "nonogram.seenPuzzleIds."

    /// Pick the next puzzle for `difficulty`. Prefers an unseen curated
    /// entry; falls back to procedural when all curated have been seen.
    /// Marks the chosen id as seen as a side-effect.
    static func next(
        difficulty: NonogramDifficulty,
        userDefaults: UserDefaults = .standard,
        rng: inout any RandomNumberGenerator
    ) -> NonogramPuzzle {
        let pool = NonogramLibrary.puzzles(for: difficulty)
        let seenKey = seenKeyPrefix + difficulty.rawValue
        var seen = Set(userDefaults.stringArray(forKey: seenKey) ?? [])

        // 1) Try an unseen curated puzzle.
        let unseen = pool.filter { !seen.contains($0.id) }
        if let pick = unseen.randomElement(using: &rng) {
            seen.insert(pick.id)
            userDefaults.set(Array(seen), forKey: seenKey)
            return pick
        }

        // 2) Curated pool empty (no bundled puzzles for this size) OR
        //    fully seen → procedural fallback.
        let proc = NonogramGenerator.generate(difficulty: difficulty, rng: &rng)
        seen.insert(proc.id)
        userDefaults.set(Array(seen), forKey: seenKey)
        return proc
    }

    /// Forget every "seen" id for every difficulty. Wired to
    /// SettingsStore reset-stats so a clean account starts curated
    /// rotation from scratch.
    static func resetSeen(userDefaults: UserDefaults = .standard) {
        for d in NonogramDifficulty.allCases {
            userDefaults.removeObject(forKey: seenKeyPrefix + d.rawValue)
        }
    }
}
