//
//  GameInfoReadoutStyle.swift
//  gamekit
//
//  Shared presentation for passive game information. Full-size readouts
//  float directly over the game scene; compact Video Mode readouts retain a
//  bounded surface where constrained chrome needs separation and contrast.
//

import SwiftUI
import DesignKit

private struct GameInfoReadoutModifier: ViewModifier {
    let theme: Theme
    let compact: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if compact {
            content
                .padding(.horizontal, theme.spacing.xs)
                .padding(.vertical, theme.spacing.xs)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .chipShadow()
        } else {
            content
                .padding(.horizontal, theme.spacing.xs)
                .padding(.vertical, theme.spacing.xs)
        }
    }
}

extension View {
    /// Passive information floats in normal game layouts. Use `compact` only
    /// inside constrained Video Mode chrome where a surface aids separation.
    func gameInfoReadout(theme: Theme, compact: Bool = false) -> some View {
        modifier(GameInfoReadoutModifier(theme: theme, compact: compact))
    }
}
