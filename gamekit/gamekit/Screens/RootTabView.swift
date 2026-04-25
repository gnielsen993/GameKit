//
//  RootTabView.swift
//  gamekit
//
//  3-tab TabView root per D-02 (TabView with three tabs — Home / Stats /
//  Settings; each tab owns its own NavigationStack inside its root view).
//  RootTabView itself is stateless — does not hold a NavigationStack
//  (ARCHITECTURE.md Anti-Pattern 3).
//

import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: Int = 0

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(String(localized: "Home"), systemImage: "house") }
                .tag(0)

            StatsView()
                .tabItem { Label(String(localized: "Stats"), systemImage: "chart.bar") }
                .tag(1)

            SettingsView()
                .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape") }
                .tag(2)
        }
        .tint(theme.colors.accentPrimary)
    }
}
