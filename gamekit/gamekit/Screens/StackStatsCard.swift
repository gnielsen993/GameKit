//
//  StackStatsCard.swift
//  gamekit
//
//  Phase 16 (STACK-04): props-only Stack stats card for StatsView.
//  Three metrics only (D-10, minimal): high score · runs played · best
//  perfect streak. Full ARCADE-07 score-breakdown shape deferred to Phase 18.
//
//  Token discipline: zero Color(...) literals; all fonts / spacing from theme.
//  No queries here — StatsView owns the existing stackRecords / stackBestScores queries.
//
//  Empty state first (CLAUDE.md §8.3): "No Stack games played yet."
//

import SwiftUI
import DesignKit

struct StackStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    // MARK: - Derived values (16-PATTERNS.md field derivation)

    /// Returns the raw score string or "—" when no row exists.
    private var highScoreText: String {
        guard let score = bestScores.first(where: {
            $0.difficultyRaw == GameStats.stackEndlessMode
        })?.score else { return "—" }
        return "\(score)"
    }

    private var runsPlayed: Int { records.count }

    private var bestStreakText: String {
        guard let streak = bestScores.first(where: {
            $0.difficultyRaw == GameStats.stackPerfectStreakMode
        })?.score else { return "—" }
        return "\(streak)"
    }

    // MARK: - Body

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            metricsGrid
        }
    }

    // MARK: - Empty state (§8.3 — explicit copy, no blank screen)

    @ViewBuilder
    private var emptyState: some View {
        Text(String(localized: "No Stack games played yet."))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics grid (2-column: label | value)

    @ViewBuilder
    private var metricsGrid: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: theme.spacing.m,
            verticalSpacing: theme.spacing.s
        ) {
            metricRow(
                label: String(localized: "High Score"),
                value: highScoreText,
                a11yLabel: String(localized: "High score: \(highScoreText)")
            )

            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .gridCellColumns(2)

            metricRow(
                label: String(localized: "Runs Played"),
                value: "\(runsPlayed)",
                a11yLabel: String(localized: "Runs played: \(runsPlayed)")
            )

            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .gridCellColumns(2)

            metricRow(
                label: String(localized: "Best Streak"),
                value: bestStreakText,
                a11yLabel: String(localized: "Best perfect streak: \(bestStreakText)")
            )
        }
    }

    @ViewBuilder
    private func metricRow(label: String, value: String, a11yLabel: String) -> some View {
        GridRow {
            Text(label)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .gridColumnAlignment(.leading)
            Text(value)
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
                .gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(a11yLabel))
    }
}
