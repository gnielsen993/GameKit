//
//  SudokuPuzzlePool.swift
//  gamekit
//
//  Actor that owns the bundled SudokuPuzzles.json pack. Lazy-loads on
//  first access (off main thread), caches parsed entries per difficulty,
//  and serves next-unplayed entries. "Played" is derived from
//  GameRecord rows (gameKindRaw == "sudoku" && outcomeRaw == "win" &&
//  puzzleIdRaw matches an entry id) — provided by the caller via the
//  `playedIDs(for:)` injection.
//
//  When a difficulty's pool is exhausted (every entry has a corresponding
//  played GameRecord), the pool silently recycles by emptying its in-
//  memory "played" set and returning the first entry. The persistent
//  GameRecord history is untouched, so a future "Solved Sudoku" gallery
//  still sees full history.
//
//  In-session cursor prevents consecutive `next(...)` calls within one
//  session from repeating before any GameRecord is written.
//

import Foundation

actor SudokuPuzzlePool {

    enum PoolError: Error, Equatable {
        case bundleResourceMissing
        case decodeFailed(String)
    }

    private let bundle: Bundle
    private let resourceName: String
    private let resourceExtension: String

    private var pack: SudokuPuzzlePack?
    private var cursor: [SudokuDifficulty: Int] = [:]   // session-local round-robin

    init(
        bundle: Bundle = .main,
        resourceName: String = "SudokuPuzzles",
        resourceExtension: String = "json"
    ) {
        self.bundle = bundle
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
    }

    /// Force a load; returns the loaded pack. Called implicitly by other
    /// methods on first access. Exposed for tests + warm-up.
    @discardableResult
    func load() throws -> SudokuPuzzlePack {
        if let pack { return pack }
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw PoolError.bundleResourceMissing
        }
        let data = try Data(contentsOf: url)
        let decoded = try Self.decode(data)
        self.pack = decoded
        return decoded
    }

    /// Nonisolated decode helper — decouples JSONDecoder (which picks up
    /// the actor's default isolation) from the actor context so Swift 6's
    /// InferIsolatedConformances doesn't flag SudokuPuzzlePack.Decodable.
    nonisolated private static func decode(_ data: Data) throws -> SudokuPuzzlePack {
        do {
            return try JSONDecoder().decode(SudokuPuzzlePack.self, from: data)
        } catch {
            throw PoolError.decodeFailed(String(describing: error))
        }
    }

    /// Total puzzles available for the given difficulty.
    func count(for difficulty: SudokuDifficulty) throws -> Int {
        let pack = try load()
        return pack.puzzles[difficulty.rawValue]?.count ?? 0
    }

    /// Return the next un-played puzzle for `difficulty`. `playedIDs` is
    /// the set of puzzle IDs already won (caller-supplied — typically
    /// queried from GameRecord). Silent recycle when exhausted.
    func next(
        difficulty: SudokuDifficulty,
        playedIDs: Set<String>
    ) throws -> SudokuPuzzleEntry {
        let pack = try load()
        guard let entries = pack.puzzles[difficulty.rawValue], !entries.isEmpty else {
            throw PoolError.decodeFailed("No entries for difficulty: \(difficulty.rawValue)")
        }

        // Combine caller's set with session-cursor-local exclusions to
        // avoid serving the same puzzle twice in one session before any
        // GameRecord is written.
        let cursorIdx = cursor[difficulty] ?? 0

        // Walk starting from cursor; pick first entry not in playedIDs.
        for i in 0..<entries.count {
            let idx = (cursorIdx + i) % entries.count
            let candidate = entries[idx]
            if !playedIDs.contains(candidate.id) {
                cursor[difficulty] = (idx + 1) % entries.count
                return candidate
            }
        }

        // All entries played — recycle. Reset cursor and serve [0].
        cursor[difficulty] = 1 % entries.count
        return entries[0]
    }
}
