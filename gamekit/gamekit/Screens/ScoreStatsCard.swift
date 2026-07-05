//
//  ScoreStatsCard.swift
//  gamekit
//
//  Phase 18 (ARCADE-07, D-08): Shared score-based stats layout for arcade
//  games (Stack and Snake). Props-only — all derivation lives in per-game
//  wrappers. The hero High Score numeral above a border rule and a metric
//  grid makes this shape class visually distinct from turn-based win/loss
//  column-grid cards.
//
//  Token discipline: zero hard-coded color literals; all fonts / spacing from theme.
//  No queries here — callers own SwiftData queries and pass pre-fetched data.
//

import SwiftUI
import DesignKit

// MARK: - ScoreMetric

/// A single label | value row in the score stats grid.
/// The `a11yLabel` should read naturally (e.g. "Average score: 120").
struct ScoreMetric {
    let label: String
    let value: String
    let a11yLabel: String
}

// MARK: - ScoreStatsCard

/// Shared score-based stats layout component.
///
/// Renders a "HIGH SCORE" caption above a large hero numeral (D-01, D-02),
/// a 1pt border rule, and a two-column metric grid (Average Score · Runs
/// Played · any extras). When `isEmpty` is true, shows `emptyStateCopy`
/// instead (D-03, §8.3).
///
/// Props-only per CLAUDE.md §8.2 — no @Query, @Environment, or @State.
/// Consumed by `StackStatsCard` and `SnakeStatsCard` via delegation (D-08).
struct ScoreStatsCard: View {
    let theme: Theme
    /// High Score display string. Pass "—" when no score has been recorded.
    let heroValue: String
    /// Ordered metric rows (Average Score, Runs Played, and any game-extras).
    let metrics: [ScoreMetric]
    /// Pre-localized copy for the empty state (e.g. "No runs yet.").
    let emptyStateCopy: String
    /// True when no runs have been recorded; triggers the empty state view.
    let isEmpty: Bool

    // MARK: - Body

    var body: some View {
        if isEmpty {
            emptyState
        } else {
            metricsContent
        }
    }

    // MARK: - Empty state (§8.3 — explicit copy, no blank screen)

    @ViewBuilder
    private var emptyState: some View {
        Text(emptyStateCopy)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics content (hero + border rule + metric grid)

    @ViewBuilder
    private var metricsContent: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: theme.spacing.m,
            verticalSpacing: theme.spacing.s
        ) {
            // 1. Hero section — "HIGH SCORE" caption above large numeral,
            //    spanning both grid columns (D-01, D-02).
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "HIGH SCORE"))
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                Text(heroValue)
                    .font(theme.typography.titleLarge)
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .gridCellColumns(2)

            // 2. 1pt border rule separating hero from the metric grid.
            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .gridCellColumns(2)

            // 3. One GridRow per ScoreMetric (label | value).
            ForEach(metrics.indices, id: \.self) { index in
                metricRow(
                    label: metrics[index].label,
                    value: metrics[index].value,
                    a11yLabel: metrics[index].a11yLabel
                )
            }
        }
    }

    // MARK: - Metric row (label | value, 2-column)

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
