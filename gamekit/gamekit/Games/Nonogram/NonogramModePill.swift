//
//  NonogramModePill.swift
//  gamekit
//
//  Two-segment pill for place / mark interaction mode. Mirrors
//  MinesweeperModePill exactly (typography, padding, min-height, capsule
//  fill semantics) so the bottom picker reads the same across games.
//

import SwiftUI
import DesignKit

struct NonogramModePill: View {
    let theme: Theme
    let mode: NonogramInteractionMode
    let isInteractive: Bool
    let onSelect: (NonogramInteractionMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(.place,
                    glyph: "square.fill",
                    label: String(localized: "Place"))
            segment(.mark,
                    glyph: "xmark",
                    label: String(localized: "Mark"))
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
    private func segment(_ target: NonogramInteractionMode,
                         glyph: String,
                         label: String) -> some View {
        let isActive = mode == target
        Button {
            guard isInteractive else { return }
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
                    ? (target == .mark ? theme.colors.danger : theme.colors.accentPrimary)
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
