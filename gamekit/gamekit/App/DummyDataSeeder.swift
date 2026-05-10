//
//  DummyDataSeeder.swift
//  gamekit
//
//  DEBUG-only one-shot seeder that pre-populates the shared SwiftData
//  container with realistic dummy stats so screenshot sessions show
//  populated cards (best times, score history, recent games) instead
//  of empty-state copy. Mirrors the gating pattern used by the
//  CloudKit schema auto-deploy block in GameKitApp.init() — runs once
//  per device install, gated by a UserDefaults flag, stripped from
//  Release builds.
//
//  Hard rule: NEVER seed when iCloud sync is enabled. Seeding into a
//  CloudKit-backed container pushes 30+ fake records to the user's
//  real iCloud account. The check below makes this impossible to
//  trigger by accident.
//
//  To reseed (e.g. after wiping the simulator stats via Settings →
//  Reset Stats but wanting fresh dummy data again):
//
//    xcrun simctl spawn booted defaults delete com.lauterstar.gamekit \
//      gamekit.debug.didSeedDummyStats.v1
//
//  …then relaunch. The block stays #if DEBUG so production builds
//  cannot reach this code at all.
//

import Foundation
import SwiftData

#if DEBUG
@MainActor
enum DummyDataSeeder {
    static let seedKey = "gamekit.debug.didSeedDummyStats.v1"

    static func seedIfNeeded(container: ModelContainer, cloudSyncEnabled: Bool) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seedKey) else { return }
        guard !cloudSyncEnabled else {
            print("⚠️ Skipping dummy stats seed: cloudSyncEnabled = true. Toggle iCloud sync OFF in Settings, relaunch, then the seeder will populate. (Refusing to push 30+ fake records to your iCloud account.)")
            return
        }

        let context = container.mainContext

        let now = Date()
        func daysAgo(_ days: Double) -> Date {
            now.addingTimeInterval(-days * 86_400)
        }

        // BestTime per Minesweeper difficulty.
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "easy",   seconds: 23,  achievedAt: daysAgo(2)))
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "medium", seconds: 105, achievedAt: daysAgo(5)))
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "hard",   seconds: 332, achievedAt: daysAgo(11)))

        // BestScore per Merge mode.
        context.insert(BestScore(gameKind: .merge, difficulty: "win",      score: 18432, achievedAt: daysAgo(3)))
        context.insert(BestScore(gameKind: .merge, difficulty: "infinite", score: 4096,  achievedAt: daysAgo(7)))

        // Minesweeper Easy — 8W / 2L.
        let easyRecords: [(Outcome, Double, Double)] = [
            (.win, 23, 2), (.win, 31, 6), (.win, 28, 9), (.win, 35, 12),
            (.win, 41, 15), (.win, 26, 18), (.win, 38, 22), (.win, 45, 28),
            (.loss, 12, 4), (.loss, 18, 21),
        ]
        for (outcome, seconds, daysAgoVal) in easyRecords {
            context.insert(GameRecord(
                gameKind: .minesweeper, difficulty: "easy",
                outcome: outcome, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal)
            ))
        }

        // Minesweeper Medium — 5W / 4L.
        let mediumRecords: [(Outcome, Double, Double)] = [
            (.win, 105, 5), (.win, 134, 8), (.win, 156, 13), (.win, 142, 19), (.win, 178, 25),
            (.loss, 89, 3), (.loss, 67, 10), (.loss, 112, 16), (.loss, 95, 22),
        ]
        for (outcome, seconds, daysAgoVal) in mediumRecords {
            context.insert(GameRecord(
                gameKind: .minesweeper, difficulty: "medium",
                outcome: outcome, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal)
            ))
        }

        // Minesweeper Hard — 2W / 6L (genre-realistic; Hard is brutal).
        let hardRecords: [(Outcome, Double, Double)] = [
            (.win, 332, 11), (.win, 421, 24),
            (.loss, 187, 1), (.loss, 245, 6), (.loss, 198, 14),
            (.loss, 276, 17), (.loss, 312, 20), (.loss, 156, 27),
        ]
        for (outcome, seconds, daysAgoVal) in hardRecords {
            context.insert(GameRecord(
                gameKind: .minesweeper, difficulty: "hard",
                outcome: outcome, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal)
            ))
        }

        // Merge winMode — 2W / 2L (winMode "win" rawValue).
        let mergeWinRecords: [(Outcome, Double, Int, Double)] = [
            (.win,  612, 18432, 3),
            (.win,  489, 12856, 7),
            (.loss, 287,  4096, 14),
            (.loss, 156,  2048, 19),
        ]
        for (outcome, seconds, score, daysAgoVal) in mergeWinRecords {
            context.insert(GameRecord(
                gameKind: .merge, difficulty: "win",
                outcome: outcome, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal), score: score
            ))
        }

        // Merge infinite — endless variant; outcome is .loss when board locks.
        let mergeInfiniteRecords: [(Outcome, Double, Int, Double)] = [
            (.loss, 423, 4096, 7),
            (.loss, 198, 1024, 21),
        ]
        for (outcome, seconds, score, daysAgoVal) in mergeInfiniteRecords {
            context.insert(GameRecord(
                gameKind: .merge, difficulty: "infinite",
                outcome: outcome, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal), score: score
            ))
        }

        // Nonogram — winning records carry puzzleId so the Solved gallery
        // has thumbnails to render. Best times wired per difficulty.
        context.insert(BestTime(gameKind: .nonogram, difficulty: "tiny",   seconds: 14,  achievedAt: daysAgo(1)))
        context.insert(BestTime(gameKind: .nonogram, difficulty: "small",  seconds: 78,  achievedAt: daysAgo(4)))
        context.insert(BestTime(gameKind: .nonogram, difficulty: "medium", seconds: 312, achievedAt: daysAgo(9)))

        let nonogramTinyWins: [(String, Double, Double)] = [
            ("tiny-001", 14, 1), ("tiny-002", 22, 2),
            ("tiny-003", 19, 5), ("tiny-004", 31, 8),
        ]
        for (pid, seconds, daysAgoVal) in nonogramTinyWins {
            context.insert(GameRecord(
                gameKind: .nonogram, difficulty: "tiny",
                outcome: .win, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal), puzzleId: pid
            ))
        }
        let nonogramSmallWins: [(String, Double, Double)] = [
            ("small-001", 78, 4), ("small-002", 124, 11),
        ]
        for (pid, seconds, daysAgoVal) in nonogramSmallWins {
            context.insert(GameRecord(
                gameKind: .nonogram, difficulty: "small",
                outcome: .win, durationSeconds: seconds,
                playedAt: daysAgo(daysAgoVal), puzzleId: pid
            ))
        }
        // One medium win + one loss for the row to show non-100% win rate.
        context.insert(GameRecord(
            gameKind: .nonogram, difficulty: "medium",
            outcome: .win, durationSeconds: 312,
            playedAt: daysAgo(9), puzzleId: "medium-001"
        ))
        context.insert(GameRecord(
            gameKind: .nonogram, difficulty: "medium",
            outcome: .loss, durationSeconds: 188,
            playedAt: daysAgo(13)
        ))

        do {
            try context.save()
            defaults.set(true, forKey: seedKey)
            print("✅ Seeded dummy stats: 6 best times + 2 best scores + 41 game records. Reset: xcrun simctl spawn booted defaults delete com.lauterstar.gamekit \(seedKey) then relaunch.")
        } catch {
            print("❌ Dummy stats seed failed: \(error)")
        }
    }
}
#endif
