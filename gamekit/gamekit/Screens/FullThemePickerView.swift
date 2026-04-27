//
//  FullThemePickerView.swift
//  gamekit
//
//  P5 (D-14, SHELL-02, THEME-03): NavigationLink destination from Settings APPEARANCE.
//  Renders the full DKThemePicker(catalog: .all) including DesignKit's built-in
//  custom-color editor — the user surface for ThemeManager.overrides per D-25.
//  Pushed onto Settings' NavigationStack — does NOT own its own stack.
//

import SwiftUI
import DesignKit

struct FullThemePickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                DKThemePicker(
                    themeManager: themeManager,
                    theme: theme,
                    scheme: colorScheme,
                    catalog: PresetCatalog.all,
                    maxGridHeight: nil,
                    grouped: true
                )
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "More themes"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
