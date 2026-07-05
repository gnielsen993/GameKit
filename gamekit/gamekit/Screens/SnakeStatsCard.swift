//
//  SnakeStatsCard.swift
//  gamekit
//
//  Phase 18 (ARCADE-07, D-08): Thin wrapper over ScoreStatsCard for the
//  Snake game. Derives High Score, Average Score, and Runs Played from
//  pre-queried props; delegates layout to ScoreStatsCard.
//
//  Snake omits the perfect-streak metric (D-07 — Stack-only).
//
//  Token discipline: zero hard-coded color literals; all fonts / spacing from theme.
//  No queries here — StatsView owns the existing snakeRecords / snakeBestScores queries.
//
//  Empty state: "No runs yet." (D-03 — replaces old per-game phrasing).
//

import SwiftUI
import DesignKit

struct SnakeStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    // MARK: - Derived values (18-PATTERNS.md field derivation)

    /// Returns the raw score string or "—" when no row exists.
    /// Key "endless" matches Plan 17 write path exactly (D-12: renaming = data break).
    /// NOT a GameStats constant — do not promote to one.
    private var highScoreText: String {
        guard let score = bestScores.first(where: {
            $0.difficultyRaw == "endless"
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
            ],
            emptyStateCopy: String(localized: "No runs yet."),
            isEmpty: records.isEmpty
        )
    }
}
