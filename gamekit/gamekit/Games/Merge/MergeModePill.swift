//
//  MergeModePill.swift
//  gamekit
//
//  Two-segment pill flipper for winMode / infinite. Props-only. Mirrors
//  MinesweeperModePill at MinesweeperModePill.swift:12 in structure.
//

import SwiftUI
import DesignKit

struct MergeModePill: View {
    let theme: Theme
    let mode: MergeMode
    let onSelect: (MergeMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(.winMode,
                    glyph: "trophy.fill",
                    label: String(localized: "Win"))
            segment(.infinite,
                    glyph: "infinity",
                    label: String(localized: "Infinite"))
        }
        .padding(theme.spacing.xs)
        .background(Capsule().fill(theme.colors.surface))
        .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func segment(_ target: MergeMode, glyph: String, label: String) -> some View {
        let isActive = mode == target
        Button {
            onSelect(target)
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: glyph)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(isActive ? theme.colors.background : theme.colors.textPrimary)
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.s)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isActive ? theme.colors.accentPrimary : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
