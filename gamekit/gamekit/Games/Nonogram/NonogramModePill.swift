//
//  NonogramModePill.swift
//  gamekit
//
//  Two-segment pill flipping between place mode and mark mode. Same
//  silhouette as MinesweeperModePill so users feel cross-game consistency.
//
//  Reserved for play mode; the gallery render renders the pill but
//  swaps its colors to a quieter "preview" tone via `isInteractive`.
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
            segment(.place, glyph: "square.fill", label: "Place")
            segment(.mark, glyph: "xmark", label: "Mark")
        }
        .padding(theme.spacing.xs)
        .background(
            Capsule().fill(theme.colors.surface)
        )
        .overlay(
            Capsule().stroke(theme.colors.border, lineWidth: 1)
        )
    }

    private func segment(
        _ target: NonogramInteractionMode,
        glyph: String,
        label: String
    ) -> some View {
        let isActive = mode == target
        return Button {
            guard isInteractive else { return }
            onSelect(target)
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: glyph)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.xs)
            .foregroundStyle(isActive ? theme.colors.surface : theme.colors.textPrimary)
            .background(
                Capsule().fill(isActive ? theme.colors.accentPrimary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
