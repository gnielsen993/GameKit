//
//  MinesRemainingChip.swift
//  gamekit
//
//  Props-only mine-counter chip extracted from MinesweeperHeaderBar
//  (Plan 11-01 / D-03). Renders the chip surface; carries no @State,
//  no @Environment reads. Consumed by:
//    - MinesweeperHeaderBar (non-Video / Small PiP zones)
//    - MinesweeperGameView Large-zone branch via VideoCompactControlRow
//      slot 2's stacked sub-view (Plan 11-04 / D-06)
//  Single source of truth — token discipline, formatting, and a11y
//  label all live here.
//

import SwiftUI
import DesignKit

struct MinesRemainingChip: View {
    let theme: Theme
    let minesRemaining: Int

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "flag.fill")
                .foregroundStyle(theme.colors.danger)
            Text(formatCounter(minesRemaining))
                .font(theme.typography.monoNumber)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(minesRemaining) mines remaining"))
    }

    /// Counter format: 3-digit zero-pad for positive values; bare integer
    /// with leading minus for negative (over-flagging produces a negative
    /// counter — informational per Plan 02 VM behavior). Examples: 042 / -3 / 099.
    private func formatCounter(_ n: Int) -> String {
        if n >= 0 { return String(format: "%03d", n) }
        return "\(n)"
    }
}
