//
//  NonogramSizeChip.swift
//  gamekit
//
//  Props-only puzzle-size chip extracted from NonogramHeaderBar (Plan 12-03
//  / D-12-CHIPS). Renders the "□ 10 × 10"-style chip surface; carries no
//  @State, no @Environment reads. Consumed by:
//    - NonogramHeaderBar (off-path / Small PiP zones) with compact: false
//    - NonogramGameView Large-zone branch via VideoCompactControlRow slot 2
//      (Plan 12-04) with compact: true — but only in Free mode; Lives mode
//      swaps to NonogramLivesChip in slot 2 per D-NG-01.
//  Single source of truth — token discipline, formatting, and a11y label
//  all live here. Mirrors MinesRemainingChip / MergeScoreChip pattern.
//

import SwiftUI
import DesignKit

struct NonogramSizeChip: View {
    let theme: Theme
    /// Pre-formatted size label like "10 × 10". The view supplies the
    /// formatted string so the chip stays a pure renderer; NonogramHeaderBar
    /// continues to forward whatever sizeLabel the GameView formats.
    let sizeLabel: String
    /// Compact variant for Video Mode slot 2 (P12 D-12-CHIPS). When `true`,
    /// drops one Dynamic Type step (caption instead of headline), reduces
    /// padding to `theme.spacing.xs` so the chip fits inside `theme.spacing.xl`
    /// (the compact-row's pill-height anchor). Off-path callers (HeaderBar)
    /// leave defaulted to `false` and get the v1.1 chip byte-identical
    /// (D-12-OFFRESTORE).
    var compact: Bool = false

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "square.grid.3x3.square")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(sizeLabel)
                .font(compact ? theme.typography.caption : theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .gameInfoReadout(theme: theme, compact: compact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Puzzle size \(sizeLabel)"))
    }
}
