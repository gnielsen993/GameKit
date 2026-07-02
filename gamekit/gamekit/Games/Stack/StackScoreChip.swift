//
//  StackScoreChip.swift
//  gamekit
//
//  Props-only score chip for Stack's Video Mode surfaces. Renders the
//  DESIGN.md §3.3 generic-info-chip shell; carries no @State, no
//  @Environment reads. Consumed by StackGameView's Large-zone compact row
//  (slot 2, compact: true). Off-path Stack keeps its bare-text score
//  overlay — this chip exists only where the compact row demands the §3.5
//  chip shape. Mirrors MergeScoreChip.
//

import SwiftUI
import DesignKit

struct StackScoreChip: View {
    let theme: Theme
    let score: Int
    /// Compact variant for the Video Mode compact row (§3.5 — all chips in
    /// the row use `compact: true` so they fit the `theme.spacing.xl` pill
    /// height). Full variant retained per the §3.3 chip contract.
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Score").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(score)")
                .font(compact ? theme.typography.caption : theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
        }
        .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.m)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score)"))
    }
}
