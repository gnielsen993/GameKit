//
//  MergeBestChip.swift
//  gamekit
//
//  Props-only best-score chip extracted from MergeHeaderBar (Plan 12-01 / D-12-CHIPS).
//  Sibling to MergeScoreChip — same shape, different label + data binding.
//  Consumed by:
//    - MergeHeaderBar (off-path / Small PiP zones) with compact: false
//    - MergeGameView Large-zone branch via VideoCompactControlRow slot 4
//      (Plan 12-02) with compact: true
//

import SwiftUI
import DesignKit

struct MergeBestChip: View {
    let theme: Theme
    let bestScore: Int
    /// Compact variant — see MergeScoreChip for shape rationale (P12 D-12-CHIPS).
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Best").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(bestScore)")
                .font(compact ? theme.typography.caption : theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText(value: Double(bestScore)))
                .feedbackAnimation(theme.motion.ease, value: bestScore)
        }
        .gameInfoReadout(theme: theme, compact: compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Best \(bestScore)"))
    }
}
