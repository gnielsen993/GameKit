//
//  StackStatsCard.swift
//  gamekit
//
//  Phase 18 (ARCADE-07, D-08): Thin wrapper over ScoreStatsCard for the
//  Stack game. Derives High Score, Average Score, Runs Played, and Best
//  Streak from pre-queried props; delegates layout to ScoreStatsCard.
//
//  Token discipline: zero hard-coded color literals; all fonts / spacing from theme.
//  No queries here — StatsView owns the existing stackRecords / stackBestScores queries.
//
//  Empty state: "No runs yet." (D-03 — replaces old per-game phrasing).
//

import SwiftUI
import DesignKit

struct StackStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    // MARK: - Derived values (18-PATTERNS.md field derivation)

    /// Returns the raw score string for the "endless" mode row, or "—".
    private var highScoreText: String {
        guard let score = bestScores.first(where: {
            $0.difficultyRaw == GameStats.stackEndlessMode
        })?.score else { return "—" }
        return "\(score)"
    }

    /// Integer average of per-run scores (derivation only — no schema change, D-06).
    /// Guards nil scores and the empty denominator (T-18-03 mitigation).
    private var averageScoreText: String {
        let scores = records.compactMap { $0.score }.filter { $0 > 0 }
        guard !scores.isEmpty else { return "—" }
        let avg = scores.reduce(0, +) / scores.count
        return "\(avg)"
    }

    private var runsPlayed: Int { records.count }

    /// Best perfect-streak score (Stack-only, D-07). Keyed on "perfectStreak"
    /// BestScore row — do NOT rename; it is a stable CloudKit serialization key.
    private var bestStreakText: String {
        guard let streak = bestScores.first(where: {
            $0.difficultyRaw == GameStats.stackPerfectStreakMode
        })?.score else { return "—" }
        return "\(streak)"
    }

    // MARK: - Body

    var body: some View {
        ScoreStatsCard(
            theme: theme,
            heroValue: highScoreText,
            metrics: [
                ScoreMetric(
                    label: String(localized: "Average Score"),
                    value: averageScoreText,
                    a11yLabel: String(localized: "Average score: \(averageScoreText)")
                ),
                ScoreMetric(
                    label: String(localized: "Runs Played"),
                    value: "\(runsPlayed)",
                    a11yLabel: String(localized: "Runs played: \(runsPlayed)")
                ),
                ScoreMetric(
                    label: String(localized: "Best Streak"),
                    value: bestStreakText,
                    a11yLabel: String(localized: "Best perfect streak: \(bestStreakText)")
                ),
            ],
            emptyStateCopy: String(localized: "No runs yet."),
            isEmpty: records.isEmpty
        )
    }
}
