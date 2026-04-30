//
//  MergeHeaderBar.swift
//  gamekit
//
//  Score chip + best-score chip for the Merge game scene. Props-only.
//  Mirrors MinesweeperHeaderBar discipline at MinesweeperHeaderBar.swift:23.
//

import SwiftUI
import DesignKit

struct MergeHeaderBar: View {
    let theme: Theme
    let score: Int
    let bestScore: Int
    let mode: MergeMode

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            chip(label: String(localized: "Score"), value: score)
            Spacer()
            chip(label: String(localized: "Best"), value: bestScore)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    @ViewBuilder
    private func chip(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(value)")
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
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
        .accessibilityLabel(Text("\(label) \(value)"))
    }
}
