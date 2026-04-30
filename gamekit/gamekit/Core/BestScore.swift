//
//  BestScore.swift
//  gamekit
//
//  SwiftData @Model storing the best (highest) score for a single
//  (gameKind, difficulty) pair. Mirrors `BestTime` (Core/BestTime.swift)
//  byte-for-byte at the structural level, with `seconds: Double` swapped
//  for `score: Int` and "lower is better" semantics inverted to "higher
//  is better." One row per (gameKind, difficulty) is enforced by
//  GameStats.record(...) write-path logic, NOT by a SwiftData
//  unique-attribute decorator (CloudKit-compat per BestTime invariants).
//
//  Phase: Merge stats (additive schema bump — JSON envelope -> v2; SwiftData
//  lightweight migration handles model-level addition).
//

import Foundation
import SwiftData

/// Best (highest) score for a single (gameKind, difficulty). Updated by
/// GameStats.record(gameKind:mode:outcome:score:) only when a higher
/// score arrives; loss records may still update best score (a loss can
/// be a high score in score-chase games).
@Model
final class BestScore {
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.merge.rawValue
    var difficultyRaw: String = ""           // stores MergeMode.rawValue ("win" | "infinite")
    var score: Int = 0
    var achievedAt: Date = Date()
    var schemaVersion: Int = 1

    /// Safe-fallback accessor — unknown raw → `.merge`.
    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .merge }

    init(
        gameKind: GameKind = .merge,
        difficulty: String,
        score: Int,
        achievedAt: Date = .now
    ) {
        self.gameKindRaw = gameKind.rawValue
        self.difficultyRaw = difficulty
        self.score = score
        self.achievedAt = achievedAt
        // id, schemaVersion default-initialized
    }
}
