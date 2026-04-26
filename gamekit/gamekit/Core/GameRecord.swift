//
//  GameRecord.swift
//  gamekit
//
//  SwiftData @Model representing a single completed game (one win or one
//  loss). Stored in the shared ModelContainer constructed in GameKitApp
//  (Plan 04-04). Read by StatsView via @Query (Plan 04-05); written
//  exclusively through GameStats.record(...) at the .playing → terminal
//  transition (Plan 04-02 / 04-04). Persistence-only — no SwiftUI.
//
//  Phase 4 invariants (per D-01, D-02, D-05, D-06; RESEARCH Pitfalls 1+2):
//    - Every property optional or defaulted (RESEARCH Pitfall 1) —
//      CloudKit private DB rejects required properties at container init.
//      Compile-fine, throw-on-init failure mode.
//    - No SwiftData unique-attribute decorator (RESEARCH Pitfall 2) —
//      CloudKit private DB rejects unique constraints at container init.
//      Identity comes from `id: UUID = UUID()`.
//    - All relationships optional (P4 has zero relationships → automatic).
//    - `schemaVersion: Int = 1` is the userland forward-compat gate —
//      survives the JSON envelope round-trip (D-17). Future bumps are
//      deliberate (additive changes alone do NOT require a bump under
//      SwiftData lightweight migration; rename or remove DOES require
//      a bump).
//    - `difficultyRaw` accepts raw `MinesweeperDifficulty.rawValue`
//      (D-05) — locked at "easy" / "medium" / "hard" since P2 D-02.
//      Renaming = data break.
//    - The model layer is intentionally string-keyed at the field
//      boundary so non-Mines games (Sudoku, Nonogram, …) can write the
//      same model with their own difficulty enum.
//

import Foundation
import SwiftData

/// One completed game (win or loss). Written by GameStats.record(...);
/// read by StatsView via @Query; round-tripped by StatsExporter.
@Model
final class GameRecord {
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.minesweeper.rawValue
    var difficultyRaw: String = ""           // matches MinesweeperDifficulty.rawValue per D-05
    var outcomeRaw: String = ""              // "win" | "loss"
    var durationSeconds: Double = 0
    var playedAt: Date = Date()
    var schemaVersion: Int = 1

    /// Safe-fallback accessor (D-02) — unknown raw → `.minesweeper`.
    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .minesweeper }

    /// Safe-fallback accessor (D-02) — unknown raw → `.loss` (the
    /// conservative choice: an unparseable record never inflates wins).
    var outcome: Outcome { Outcome(rawValue: outcomeRaw) ?? .loss }

    init(
        gameKind: GameKind = .minesweeper,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double,
        playedAt: Date = .now
    ) {
        self.gameKindRaw = gameKind.rawValue
        self.difficultyRaw = difficulty
        self.outcomeRaw = outcome.rawValue
        self.durationSeconds = durationSeconds
        self.playedAt = playedAt
        // id, schemaVersion default-initialized
    }
}
