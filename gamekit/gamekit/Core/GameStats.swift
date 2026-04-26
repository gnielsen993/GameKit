//
//  GameStats.swift
//  gamekit
//
//  Single write-side boundary between gameplay and SwiftData (D-11).
//  Public API: `record(...)` + `resetAll()`. Both methods call
//  `try modelContext.save()` internally — explicit save satisfies
//  SC1's literal mandate (RESEARCH Pitfall 10 forbids autosave reliance:
//  on a force-quit immediately after a win the autosave debounce window
//  has not yet fired, so the GameRecord is lost). PERSIST-02's force-
//  quit survival rests on the synchronous save call returning before
//  the user can swipe-up.
//
//  Phase 4 invariants (per D-11 / D-12 / D-13 / D-14; RESEARCH Pitfalls 3+9+10):
//    - @MainActor — `ModelContext` is not Sendable (RESEARCH Pattern 6);
//      same actor-isolation pattern as `MinesweeperViewModel`. Locked
//      as the standard for ALL P4 services.
//    - `record(...)` order: insert `GameRecord` FIRST, evaluate
//      `BestTime` SECOND, save THIRD. The win-path BestTime evaluation
//      is wrapped in do/catch (Discretion lock from CONTEXT) so a flaky
//      predicate cannot block GameRecord persistence — the worst case
//      is a missed BestTime update, never a missed game record.
//    - `resetAll()` uses `try modelContext.transaction { delete(model:) × 2 }`
//      (iOS 17.3+ batch-delete API per D-13) — atomic; partial reset
//      is impossible.
//    - This file is the firewall (D-14): the Minesweeper VM holds an
//      optional `GameStats?` reference, never imports SwiftData
//      directly. Plan 05 wires the injection from
//      `@Environment(\.modelContext)` at the App scene root.
//    - Strictly-less-than guard on BestTime mutation — equal-seconds is
//      a no-op (avoids unnecessary writes; matches PROJECT.md "calm,
//      fewer writes" tone).
//

import Foundation
import SwiftData
import os

/// `GameStats` — single write-side boundary between gameplay and
/// SwiftData (D-11). Owns the `record(...)` and `resetAll()` API.
/// All write paths explicitly call `try modelContext.save()` per
/// RESEARCH Pitfall 10 (autosave reliance is unsafe under force-quit).
@MainActor
final class GameStats {

    private let modelContext: ModelContext
    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "persistence"
    )

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Record one terminal-state outcome. Inserts a `GameRecord`
    /// unconditionally; if `outcome == .win`, evaluates `BestTime`
    /// (insert-or-mutate, faster-only). Calls `try modelContext.save()`
    /// synchronously before returning (PERSIST-02 / SC1).
    func record(
        gameKind: GameKind,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double
    ) throws {
        // 1. Insert GameRecord unconditionally (D-12 step 1).
        //    Done BEFORE BestTime evaluation so a flaky predicate cannot
        //    block GameRecord persistence (Discretion lock from CONTEXT).
        let record = GameRecord(
            gameKind: gameKind,
            difficulty: difficulty,
            outcome: outcome,
            durationSeconds: durationSeconds,
            playedAt: .now
        )
        modelContext.insert(record)

        // 2. Win path: evaluate BestTime (insert-or-mutate, faster-only).
        //    Wrap in do/catch — best-effort. The outer save() still flushes
        //    the GameRecord even if this throws.
        if outcome == .win {
            do {
                try evaluateBestTime(
                    gameKind: gameKind,
                    difficulty: difficulty,
                    seconds: durationSeconds
                )
            } catch {
                logger.error(
                    "BestTime evaluation failed: \(error.localizedDescription, privacy: .public)"
                )
                // GameRecord still persists via the explicit save below.
            }
        }

        // 3. Synchronous save — RESEARCH Pitfall 10 forbids autosave reliance.
        //    PERSIST-02 force-quit survival rests on this call returning
        //    before the user can swipe-up.
        try modelContext.save()
    }

    /// Atomic reset of all stats — deletes every `GameRecord` and every
    /// `BestTime` inside one `modelContext.transaction { ... }` block
    /// (D-13). Partial reset is impossible by construction. Calls
    /// `try modelContext.save()` after the transaction.
    func resetAll() throws {
        // D-13: atomic via transaction. iOS 17.3+ batch-delete API.
        try modelContext.transaction {
            try modelContext.delete(model: GameRecord.self)
            try modelContext.delete(model: BestTime.self)
        }
        try modelContext.save()
    }

    // MARK: - Private

    /// BestTime insert-or-mutate (faster-only). Strictly-less-than guard:
    /// equal-seconds is a no-op (no `seconds` rewrite, no `achievedAt`
    /// churn) — matches PROJECT.md "calmer, fewer writes" tone.
    ///
    /// Capture-let pattern (RESEARCH §Pattern 4 footnote): `#Predicate`
    /// cannot capture `self` in a KeyPath, so `gameKind.rawValue` is
    /// captured into a local `let kindRaw` before the predicate closure.
    private func evaluateBestTime(
        gameKind: GameKind,
        difficulty: String,
        seconds: Double
    ) throws {
        let kindRaw = gameKind.rawValue
        let descriptor = FetchDescriptor<BestTime>(
            predicate: #Predicate {
                $0.gameKindRaw == kindRaw && $0.difficultyRaw == difficulty
            }
        )

        let existing = try modelContext.fetch(descriptor)
        if let current = existing.first {
            // Faster-only — equal-seconds is a no-op.
            if seconds < current.seconds {
                current.seconds = seconds
                current.achievedAt = .now
            }
        } else {
            let best = BestTime(
                gameKind: gameKind,
                difficulty: difficulty,
                seconds: seconds,
                achievedAt: .now
            )
            modelContext.insert(best)
        }
    }
}
