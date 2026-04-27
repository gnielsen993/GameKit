//
//  RootTabView.swift
//  gamekit
//
//  3-tab TabView root per D-02 (TabView with three tabs — Home / Stats /
//  Settings; each tab owns its own NavigationStack inside its root view).
//  RootTabView itself is stateless — does not hold a NavigationStack
//  (ARCHITECTURE.md Anti-Pattern 3).
//
//  P5 (D-23, SHELL-04): drives the 3-step IntroFlowView via
//  .fullScreenCover gated on settingsStore.hasSeenIntro. The cover presents
//  ONLY when !hasSeenIntro at first appear; IntroFlowView writes
//  hasSeenIntro = true on Skip / Done dismissal so subsequent app launches
//  skip the cover entirely.
//

import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore

    @State private var selectedTab: Int = 0
    @State private var isIntroPresented: Bool = false

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
        .fullScreenCover(isPresented: $isIntroPresented) {
            IntroFlowView()
        }
        .onAppear {
            // Read-once on first appear; IntroFlowView writes hasSeenIntro = true
            // on dismiss, so subsequent app launches see hasSeenIntro = true and
            // the cover never re-presents (PATTERNS line 621 + CONTEXT D-23).
            if !settingsStore.hasSeenIntro {
                isIntroPresented = true
            }
        }
    }
}
