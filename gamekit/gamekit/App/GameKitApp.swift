//
//  GameKitApp.swift
//  gamekit
//
//  The single @main scene for GameKit.
//  Owns ThemeManager (single source of truth for theming, P1 invariant).
//  Owns the shared SwiftData ModelContainer (P4: GameRecord + BestTime,
//  CloudKit-compat schema per D-07/D-08, container ID iCloud.com.lauterstar.gamekit
//  per D-09). Owns SettingsStore for the cloudSyncEnabled flag (D-28/D-29).
//
//  Phase 4 invariants (per D-07, D-08, D-09, D-29):
//    - Single shared ModelContainer (D-07) — constructed ONCE in init(),
//      injected app-wide via .modelContainer(sharedContainer)
//    - cloudKitDatabase reads SettingsStore.cloudSyncEnabled at startup
//      (D-08); flag default is false in P4 (relaunch required to flip;
//      live reconfigure is a P6 concern per ROADMAP)
//    - CloudKit container ID is iCloud.com.lauterstar.gamekit (D-09 lock,
//      mirrored in PROJECT.md and Plan 04-01's smoke test)
//    - ModelContainer construction wraps a do/catch with fatalError
//      (RESEARCH §Code Examples 1) — schema constraint violations or
//      container ID drift fail at app launch, which Plan 04-01's smoke
//      test protects from at PR time
//    - Existing themeManager @StateObject seam PRESERVED — additive only
//      per 04-PATTERNS.md line 9 critical correction
//
//  Phase 1 invariants (preserved):
//    - No async work in App.init beyond the container init (cold-start
//      <1s target — ModelContainer init is sync; benchmark in Plan 06)
//    - No eager DesignKit work beyond ThemeManager()
//

import SwiftUI
import SwiftData
import DesignKit

@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()
    @State private var settingsStore: SettingsStore
    let sharedContainer: ModelContainer

    init() {
        // SettingsStore must be constructed BEFORE the container so
        // cloudSyncEnabled is available for ModelConfiguration (D-08).
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)

        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: store.cloudSyncEnabled
                ? .private("iCloud.com.lauterstar.gamekit")
                : .none
        )
        do {
            sharedContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema constraint violation OR CloudKit container ID drift.
            // Plan 04-01's ModelContainerSmokeTests catches this at PR time
            // before it can ship; reaching this fatalError in production
            // means a non-schema issue (e.g. disk write barrier).
            fatalError("Failed to construct shared ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .environment(\.settingsStore, settingsStore)
                .preferredColorScheme(preferredScheme)
                .modelContainer(sharedContainer)
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
