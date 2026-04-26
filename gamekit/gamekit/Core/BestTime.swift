//
//  BestTime.swift
//  gamekit
//
//  SwiftData @Model storing the best win duration for a single
//  (gameKind, difficulty) pair. One row per pair — uniqueness enforced
//  by GameStats.record(...) write-path logic (Plan 04-02), NOT by a
//  SwiftData unique-attribute decorator. Persistence-only — no SwiftUI.
//
//  Phase 4 invariants (per D-01, D-03, D-06; RESEARCH Pitfalls 1+2):
//    - Every property optional or defaulted (RESEARCH Pitfall 1) —
//      CloudKit private DB rejects required properties at container init.
//    - No SwiftData unique-attribute decorator (RESEARCH Pitfall 2) —
//      CloudKit private DB rejects unique constraints at container init.
//      Identity comes from `id: UUID = UUID()`.
//    - All relationships optional (P4 has zero relationships → automatic).
//    - `schemaVersion: Int = 1` is the userland forward-compat gate;
//      bumps are deliberate (rename or remove only).
//    - One row per (gameKind, difficulty) is enforced by GameStats
//      write-path logic (Plan 04-02 D-12), NOT by a unique decorator.
//    - No `recordId: UUID?` backreference per D-03 — minimal schema.
//      StatsView shows "Best: 1:42" only (no "set [date]" affordance in
//      P4); a future polish phase may add the backreference and an
//      `achievedAt` display.
//

import Foundation
import SwiftData

/// Best win duration for a single (gameKind, difficulty). Updated
/// by GameStats.record(...) only when a faster win arrives; loss
/// records never touch BestTime (D-12).
@Model
final class BestTime {
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.minesweeper.rawValue
    var difficultyRaw: String = ""
    var seconds: Double = 0
    var achievedAt: Date = Date()
    var schemaVersion: Int = 1

    /// Safe-fallback accessor — unknown raw → `.minesweeper`.
    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .minesweeper }

    init(
        gameKind: GameKind = .minesweeper,
        difficulty: String,
        seconds: Double,
        achievedAt: Date = .now
    ) {
        self.gameKindRaw = gameKind.rawValue
        self.difficultyRaw = difficulty
        self.seconds = seconds
        self.achievedAt = achievedAt
        // id, schemaVersion default-initialized
    }
}
