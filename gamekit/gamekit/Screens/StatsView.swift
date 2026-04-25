//
//  StatsView.swift
//  gamekit
//
//  Phase 1: themed scaffold stub.
//  Real per-difficulty stats (with @Query) arrive at Phase 4 (SHELL-03)
//  per D-04 / D-11. Empty state ("No games played yet.") lands then.
//

import SwiftUI
import DesignKit

struct StatsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    settingsSectionHeader(theme: theme, String(localized: "HISTORY"))
                    DKCard(theme: theme) {
                        Text(String(localized: "Your stats will appear here."))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    settingsSectionHeader(theme: theme, String(localized: "BEST TIMES"))
                    DKCard(theme: theme) {
                        Text(String(localized: "Your best times will appear here."))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Stats"))
        }
    }
}
