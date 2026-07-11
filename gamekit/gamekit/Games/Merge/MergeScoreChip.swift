//
//  MergeScoreChip.swift
//  gamekit
//
//  Props-only score chip extracted from MergeHeaderBar (Plan 12-01 / D-12-CHIPS).
//  Renders a floating readout at full size and a bounded chip only in
//  constrained Video Mode chrome; carries no state or environment reads.
//  Consumed by:
//    - MergeHeaderBar (off-path / Small PiP zones) with compact: false
//    - MergeGameView Large-zone branch via VideoCompactControlRow slot 2
//      (Plan 12-02) with compact: true
//  Single source of truth — token discipline, formatting, and a11y label
//  all live here. Mirrors MinesRemainingChip / Plan 11-01 + round 2 polish.
//

import SwiftUI
import DesignKit

struct MergeScoreChip: View {
    let theme: Theme
    let score: Int
    /// Compact variant for Video Mode slot 2 (P12 D-12-CHIPS mirror of
    /// P11-04 round 2 polish). When `true`, drops one Dynamic Type step,
    /// reduces horizontal + vertical padding to `theme.spacing.xs` so the
    /// chip fits inside `theme.spacing.xl` (the compact-row's pill-height
    /// anchor). Off-path callers leave it false for the floating hierarchy.
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Score").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(score)")
                .font(compact ? theme.typography.caption : theme.typography.title)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText(value: Double(score)))
                .feedbackAnimation(theme.motion.ease, value: score)
        }
        .gameInfoReadout(theme: theme, compact: compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score)"))
    }
}
