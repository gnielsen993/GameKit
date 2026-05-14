//
//  NonogramLivesChip.swift
//  gamekit
//
//  Props-only lives chip extracted from NonogramHeaderBar (Plan 12-03 /
//  D-12-CHIPS). Renders the 3-heart-glyph chip with i<remaining filled
//  in danger color, others dimmed in textTertiary. Consumed by:
//    - NonogramHeaderBar in Lives mode (off-path / Small PiP zones) with compact: false
//    - NonogramGameView Large-zone branch via VideoCompactControlRow slot 2
//      (Plan 12-04) with compact: true — but only in Lives mode; Free mode
//      swaps to NonogramSizeChip per D-NG-01.
//

import SwiftUI
import DesignKit

struct NonogramLivesChip: View {
    let theme: Theme
    /// Remaining lives — clamped to `0...livesPerPuzzle` at the view layer;
    /// the iteration bound is sourced from the model enum's static constant.
    let remaining: Int
    /// Compact variant — see NonogramSizeChip for shape rationale (P12 D-12-CHIPS).
    var compact: Bool = false

    var body: some View {
        HStack(spacing: theme.spacing.xs / 2) {
            ForEach(0..<NonogramGameMode.livesPerPuzzle, id: \.self) { i in
                Image(systemName: i < remaining ? "heart.fill" : "heart")
                    .foregroundStyle(i < remaining
                                     ? theme.colors.danger
                                     : theme.colors.textTertiary)
                    .font(.system(size: compact ? 11 : 14, weight: .semibold))
            }
        }
        .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.s)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(remaining) of \(NonogramGameMode.livesPerPuzzle) lives remaining"))
    }
}
