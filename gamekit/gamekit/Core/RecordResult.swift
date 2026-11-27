//
//  RecordResult.swift
//  gamekit
//
//  What a recorded win says about personal bests, decided by the same code
//  that writes the best time (`GameStats.recordReportingBest`). Callers that
//  want to show a "personal best" never re-derive the rule (assisted wins,
//  practice completions and non-wins never set one; v1.6 ruling).
//

import Foundation

/// Outcome of the best-time evaluation for one recorded result.
nonisolated struct RecordResult: Equatable, Sendable {

    /// True only when this result wrote a new or faster `BestTime`. The first
    /// unassisted win at a difficulty counts (previousBest is nil).
    let setBestTime: Bool

    /// The best time that stood before this result. Nil when there was none,
    /// and always nil for `.noRecord`.
    let previousBest: Double?

    /// Result for anything that never competes for a record: a loss, an
    /// assisted win, a practice completion, or a failed evaluation.
    static let noRecord = RecordResult(setBestTime: false, previousBest: nil)
}

extension GameStats {

    /// Record one terminal-state outcome; see `recordReportingBest` for the
    /// full contract. Kept as a Void-returning forwarder so the existing
    /// `try? gameStats?.record(...)` call sites in other games compile
    /// without an unused-result warning.
    func record(
        gameKind: GameKind,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double,
        puzzleId: String? = nil,
        assistCount: Int? = nil,
        countsTowardRecords: Bool = true
    ) throws {
        try recordReportingBest(
            gameKind: gameKind,
            difficulty: difficulty,
            outcome: outcome,
            durationSeconds: durationSeconds,
            puzzleId: puzzleId,
            assistCount: assistCount,
            countsTowardRecords: countsTowardRecords
        )
    }
}
