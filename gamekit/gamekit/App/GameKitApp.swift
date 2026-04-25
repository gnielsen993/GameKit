//
//  GameKitApp.swift
//  gamekit
//
//  The single @main scene for GameKit.
//  Owns ThemeManager (single source of truth for theming).
//  Injects via .environmentObject so every screen consumes DesignKit tokens.
//
//  Phase 1 invariants (per D-11, D-12):
//    - No SwiftData (ModelContainer arrives in P4)
//    - No async work in App.init (cold-start <1s — keep surface trivial)
//    - No eager DesignKit work beyond ThemeManager()
//

import SwiftUI
import DesignKit

@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch themeManager.mode {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
