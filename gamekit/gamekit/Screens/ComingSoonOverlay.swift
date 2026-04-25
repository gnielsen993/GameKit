//
//  ComingSoonOverlay.swift
//  gamekit
//
//  Floating capsule surfaced when a disabled game card is tapped.
//  Per D-06: discoverability over silence.
//  All styling via DesignKit tokens — radii.chip is the smallest existing token.
//

import SwiftUI
import DesignKit

struct ComingSoonOverlay: View {
    let title: String
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: "sparkles")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textPrimary)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .padding(.bottom, theme.spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
