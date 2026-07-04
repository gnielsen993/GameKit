//
//  SnakeStatsCard.swift
//  gamekit
//
//  Phase 17 (SNAKE-05): props-only Snake stats card for StatsView.
//  Two metrics only (Phase 17 scope, minimal): high score · runs played.
//  Full shape deferred to Phase 18.
//
//  Token discipline: zero Color(...) literals; all fonts / spacing from theme.
//  No queries here — StatsView owns the existing snakeRecords / snakeBestScores queries.
//
//  Empty state first (CLAUDE.md §8.3): "No Snake games played yet."
//

import SwiftUI
import DesignKit

struct SnakeStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    // MARK: - Derived values (17-PATTERNS.md field derivation)

    /// Returns the raw score string or "—" when no row exists.
    /// Key "endless" matches Plan 03 write path exactly (D-12: renaming = data break).
    private var highScoreText: String {
        guard let score = bestScores.first(where: {
            $0.difficultyRaw == "endless"
        })?.score else { return "—" }
        return "\(score)"
    }

    private var runsPlayed: Int { records.count }

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
        Text(String(localized: "No Snake games played yet."))
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
