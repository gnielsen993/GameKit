//
//  SettingsView.swift
//  gamekit
//
//  Phase 1: themed scaffold stub.
//  Real Settings spine (theme picker, haptics, SFX, reset stats, about)
//  arrives at Phase 5 (SHELL-02) per D-04.
//  Real empty state copy lands then; for now use placeholder copy
//  (CLAUDE.md §8.3: never blank cards).
//

import SwiftUI
import DesignKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
                    DKCard(theme: theme) {
                        Text(String(localized: "Theme controls coming in a future update."))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    settingsSectionHeader(theme: theme, String(localized: "ABOUT"))
                    DKCard(theme: theme) {
                        Text(String(localized: "GameKit · v1.0"))
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Settings"))
        }
    }
}
