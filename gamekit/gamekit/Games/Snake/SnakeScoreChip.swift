//
//  SnakeScoreChip.swift
//  gamekit
//
//  Props-only score presentation for Snake. The full-size form follows Stack's
//  floating score hierarchy: typography alone, with no surrounding card. The
//  compact form retains the DESIGN.md §3.3 shell because Video Mode's compact
//  control row requires a bounded chip.
//
//  Token discipline: all colors via theme.colors.* only (CLAUDE.md §1, SNAKE-06).
//

import SwiftUI
import DesignKit

struct SnakeScoreChip: View {
    let theme: Theme
    let score: Int
    /// Compact variant for the Video Mode large-top compact row (§3.5 — all
    /// chips in the row use `compact: true` so they fit the `theme.spacing.xl`
    /// pill height). Mirrors StackScoreChip. Off-path always uses the full
    /// variant, rendered as floating type rather than a chip.
    var compact: Bool = false

    var body: some View {
        scoreContent
        .gameInfoReadout(theme: theme, compact: compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score)"))
    }

    private var scoreContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if compact {
                Text(String(localized: "Score").uppercased())
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            Text("\(score)")
                .font(compact
                      ? theme.typography.caption.monospacedDigit()
                      : theme.typography.title.monospacedDigit())
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText(value: Double(score)))
                .feedbackAnimation(theme.motion.ease, value: score)
        }
    }
}
