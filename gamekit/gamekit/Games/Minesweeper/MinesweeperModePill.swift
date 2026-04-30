//
//  MinesweeperModePill.swift
//  gamekit
//
//  Two-segment pill flipper for Reveal / Flag interaction mode.
//  Props-only (CLAUDE.md §8.2): receives current mode + onSelect closure.
//

import SwiftUI
import DesignKit

struct MinesweeperModePill: View {
    let theme: Theme
    let mode: MinesweeperInteractionMode
    let onSelect: (MinesweeperInteractionMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(.reveal,
                    glyph: "cursorarrow.click",
                    label: String(localized: "Reveal"))
            segment(.flag,
                    glyph: "flag.fill",
                    label: String(localized: "Flag"))
        }
        .padding(theme.spacing.xs)
        .background(
            Capsule().fill(theme.colors.surface)
        )
        .overlay(
            Capsule().stroke(theme.colors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segment(_ target: MinesweeperInteractionMode,
                         glyph: String,
                         label: String) -> some View {
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
            .foregroundStyle(isActive
                             ? theme.colors.background
                             : theme.colors.textPrimary)
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.s)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(
                    isActive
                    ? (target == .flag ? theme.colors.danger : theme.colors.accentPrimary)
                    : Color.clear
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
