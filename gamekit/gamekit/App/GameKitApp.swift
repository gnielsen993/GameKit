//
//  GameKitApp.swift
//  gamekit
//
//  The single @main scene for GameKit.
//  Owns ThemeManager (single source of truth for theming, P1 invariant).
//  Owns app-wide stores and the startup controller. The controller prepares
//  the single shared SwiftData ModelContainer after the branded first frame,
//  then injects it at the destination root.
//
//  Phase 4 invariants (per D-07, D-08, D-09, D-29):
//    - Single shared ModelContainer (D-07) — constructed once per startup
//      attempt and injected app-wide at RootTabView
//    - cloudKitDatabase reads SettingsStore.cloudSyncEnabled at startup
//      (D-08); flag default is false in P4 (relaunch required to flip;
//      live reconfigure is a P6 concern per ROADMAP)
//    - CloudKit container ID is iCloud.com.lauterstar.gamekit (D-09 lock,
//      mirrored in PROJECT.md and Plan 04-01's smoke test)
//    - ModelContainer construction failures surface a retry experience;
//      existing game data is never deleted automatically
//    - Existing themeManager @StateObject seam PRESERVED — additive only
//      per 04-PATTERNS.md line 9 critical correction
//
//  Cold-start invariant: App.init performs no persistence or network work.
//

import SwiftUI
import DesignKit

@main
struct GameKitApp: App {
    @StateObject private var themeManager: ThemeManager
    @State private var settingsStore: SettingsStore
    @State private var videoModeStore: VideoModeStore
    @State private var sfxPlayer: SFXPlayer
    @State private var authStore: AuthStore
    @State private var cloudSyncStatusObserver: CloudSyncStatusObserver
    @State private var startupController: AppStartupController

    init() {
        // Register GameDrawer's "Classic" identity (Chrome Diner) into the
        // DesignKit configuration seam. MUST run before ThemeManager() — a
        // stored `.classicMuted` preference resolves through the registered
        // preset's anchors. See Core/GameKitClassic.swift.
        DesignKit.configure(classicPreset: GameKitClassic.chromeDiner)
        _themeManager = StateObject(wrappedValue: ThemeManager())

        // SettingsStore must be constructed BEFORE the container so
        // cloudSyncEnabled is available for ModelConfiguration (D-08).
        let store = SettingsStore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--fresh-launch") {
            store.hasSeenIntro = false
        } else if ProcessInfo.processInfo.arguments.contains("--returning-launch") {
            store.hasSeenIntro = true
        }
        #endif
        _settingsStore = State(initialValue: store)

        // P9 (D-05): VideoModeStore constructed right after SettingsStore so
        // user-preference stores are adjacent in construction order, matching
        // their adjacency in the property declaration block. Constructor has
        // no dependencies (UserDefaults.standard default) so placement is
        // flexible; this placement is canonical per 09-PATTERNS.md §6.
        let videoMode = VideoModeStore()
        _videoModeStore = State(initialValue: videoMode)

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

        _startupController = State(
            initialValue: AppStartupController(
                cloudSyncEnabled: store.cloudSyncEnabled
            )
        )

    }

    var body: some Scene {
        WindowGroup {
            AppEntryRootView(startupController: startupController)
                .environmentObject(themeManager)
                .environment(\.settingsStore, settingsStore)
                .environment(\.videoModeStore, videoModeStore)
                .environment(\.sfxPlayer, sfxPlayer)
                .environment(\.authStore, authStore)
                .environment(\.cloudSyncStatusObserver, cloudSyncStatusObserver)
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
