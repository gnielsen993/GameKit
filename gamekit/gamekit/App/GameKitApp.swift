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
    @State private var sfxPlayer: SFXPlayer
    @State private var authStore: AuthStore
    @State private var cloudSyncStatusObserver: CloudSyncStatusObserver
    let sharedContainer: ModelContainer

    init() {
        // SettingsStore must be constructed BEFORE the container so
        // cloudSyncEnabled is available for ModelConfiguration (D-08).
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)

        // P5 (D-12): SFXPlayer constructed AFTER SettingsStore so a
        // future cross-flag dependency could be added without re-ordering.
        // Init is non-throwing — missing CAF files fall through to a
        // no-op `play(...)` per Core/SFXPlayer.swift D-11 invariant.
        let sfx = SFXPlayer()
        _sfxPlayer = State(initialValue: sfx)

        // P6 (D-13): AuthStore constructed AFTER SettingsStore + SFXPlayer.
        // Registers credentialRevokedNotification observer in init.
        // Default seams (SystemKeychainBackend + SystemCredentialStateProvider)
        // are correct for production; tests inject in-memory stubs (Plan 06-01).
        let auth = AuthStore()
        _authStore = State(initialValue: auth)

        // P6 (D-11): CloudSyncStatusObserver constructed AFTER AuthStore.
        // Initial status: .syncing if cloudSyncEnabled (CloudKit setupEvent
        // typically fires within 1-2s of launch; .syncing dampens the
        // first-paint-of-status-row → it's already correct when SC4 ticks);
        // .notSignedIn otherwise (CONTEXT Specifics line 204).
        let observer = CloudSyncStatusObserver(
            initialStatus: store.cloudSyncEnabled ? .syncing : .notSignedIn
        )
        _cloudSyncStatusObserver = State(initialValue: observer)

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
                .environment(\.sfxPlayer, sfxPlayer)
                .environment(\.authStore, authStore)
                .environment(\.cloudSyncStatusObserver, cloudSyncStatusObserver)
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

    // MARK: - DEBUG schema deploy entry point (Plan 06-03 Task 2 — Pitfall D mitigation)
    //
    // BLOCKING for Plan 06-09 SC3. Run ONCE in a debug build:
    //   1. Launch app in Xcode debug
    //   2. Pause execution; in lldb console:
    //        expr try? GameKitApp._runtimeDeployCloudKitSchema()
    //   3. Verify in CloudKit Dashboard → Development → record types CD_GameRecord + CD_BestTime exist
    //   4. Remove invocation before TestFlight.
    //
    #if DEBUG
    @MainActor
    static func _runtimeDeployCloudKitSchema() throws {
        try CloudKitSchemaInitializer.deployDevelopmentSchema()
    }
    #endif
}
