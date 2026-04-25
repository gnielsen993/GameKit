//
//  SettingsComponents.swift
//  gamekit
//
//  Local helpers for SettingsView (and StatsView) — section headers + nav rows.
//  Free @ViewBuilder functions, not promoted to DesignKit (CLAUDE.md §2:
//  promote only when used in 2+ games — these aren't game-specific anyway).
//

import SwiftUI
import DesignKit

@ViewBuilder
func settingsSectionHeader(theme: Theme, _ title: String) -> some View {
    Text(title)
        .font(theme.typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.textTertiary)
        .tracking(1.2)
        .padding(.leading, theme.spacing.xs)
}

@ViewBuilder
func settingsNavRow(theme: Theme, title: String) -> some View {
    HStack {
        Text(title)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(theme.colors.textTertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
}
