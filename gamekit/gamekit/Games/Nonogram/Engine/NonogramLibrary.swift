//
//  NonogramLibrary.swift
//  gamekit
//
//  Bundle-loader for shipped puzzles. Reads
//  Resources/nonograms/<difficulty>.json once at first access and caches
//  the decoded array per-difficulty for the app lifetime. Foundation-only.
//
//  JSON shape (per file):
//    [
//      { "id": "tiny-001", "title": "Cat", "grid": "01100..." },
//      ...
//    ]
//
//  Files that fail to decode log to console and contribute zero puzzles —
//  the library degrades gracefully so a single typo'd entry doesn't
//  crash the game shell.
//

import Foundation

enum NonogramLibrary {
    nonisolated(unsafe) private static var cache: [NonogramDifficulty: [NonogramPuzzle]] = [:]
    private static let cacheLock = NSLock()

    /// All shipped puzzles for the given difficulty, in bundle order.
    /// Filtered to those that pass `isValid(for:)` so a malformed entry
    /// can't crash the renderer.
    static func puzzles(for difficulty: NonogramDifficulty) -> [NonogramPuzzle] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[difficulty] {
            return cached
        }
        let loaded = load(difficulty: difficulty)
        cache[difficulty] = loaded
        return loaded
    }

    /// Test seam: drop the cached puzzles so a unit test can swap the
    /// bundle source between cases.
    static func _resetCacheForTesting() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    private static func load(difficulty: NonogramDifficulty) -> [NonogramPuzzle] {
        // Xcode's processed-resource pipeline flattens Resources/nonograms/
        // into the bundle root, so look up by name only — no subdirectory.
        // Try the subdirectory path first anyway in case a future blue-
        // folder reference preserves the structure.
        let url = Bundle.main.url(
            forResource: difficulty.rawValue,
            withExtension: "json",
            subdirectory: "nonograms"
        ) ?? Bundle.main.url(
            forResource: difficulty.rawValue,
            withExtension: "json"
        )
        guard let url else {
            #if DEBUG
            print("ℹ️ NonogramLibrary: no bundle file for \(difficulty.rawValue)")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([NonogramPuzzle].self, from: data)
            let valid = decoded.filter { $0.isValid(for: difficulty.size) }
            #if DEBUG
            if valid.count != decoded.count {
                print("⚠️ NonogramLibrary: dropped \(decoded.count - valid.count) invalid \(difficulty.rawValue) entries")
            }
            #endif
            return valid
        } catch {
            #if DEBUG
            print("❌ NonogramLibrary: decode failed for \(difficulty.rawValue): \(error)")
            #endif
            return []
        }
    }
}
