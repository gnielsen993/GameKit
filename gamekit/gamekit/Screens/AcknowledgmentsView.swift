//
//  AcknowledgmentsView.swift
//  gamekit
//
//  P5 (D-17, SHELL-02): NavigationLink destination from Settings ABOUT row.
//  Three credit lines per UI-SPEC §Copywriting (T-05-13 mitigation: SF Symbols
//  Apple attribution required for App Store review).
//
//  Extracted to a sibling file (vs. file-private inside SettingsView.swift) per
//  CLAUDE.md §8.1 — keeps SettingsView.swift under the ~400-line soft cap.
//  Pushed onto Settings' NavigationStack — does NOT own its own stack.
//

import SwiftUI
import DesignKit

struct AcknowledgmentsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                Text(String(localized: "DesignKit · own work"))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(localized: "SF Symbols · Apple Inc."))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(localized: "GameKit is built with care, by hand, with no telemetry, no ads, and no third-party dependencies beyond the above."))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Acknowledgments"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
