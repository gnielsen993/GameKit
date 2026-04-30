//
//  RootTabView.swift
//  gamekit
//
//  Root scene wrapper. Tab bar removed — Home is the sole root surface;
//  Settings/Stats/Account reach through a profile button on HomeView's
//  toolbar (sheet routing). RootTabView retains the IntroFlow + scenePhase
//  + AuthStore alert wiring so those side effects keep firing exactly once
//  at the scene root.
//
//  P5 (D-23, SHELL-04): drives the 3-step IntroFlowView via
//  .fullScreenCover gated on settingsStore.hasSeenIntro. The cover presents
//  ONLY when !hasSeenIntro at first appear; IntroFlowView writes
//  hasSeenIntro = true on Skip / Done dismissal so subsequent app launches
//  skip the cover entirely.
//
//  P6 (D-03/D-13/D-14): observes scenePhase to call
//  AuthStore.validateOnSceneActive() on every .active transition (D-14
//  silent revocation catch). Hosts the root-level Restart prompt .alert
//  bound to AuthStore.shouldShowRestartPrompt (D-03 single-source-of-truth
//  for both SIWA-success sites — Settings Plan 06-07 + IntroFlow Plan
//  06-08). On authStore.isSignedIn transition from true to false (revocation)
//  flips settingsStore.cloudSyncEnabled = false; same-store-path lock (D-08)
//  preserves local data and cloud rows.
//

import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.authStore) private var authStore

    @State private var isIntroPresented: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        HomeView()
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
        .onChange(of: scenePhase) { _, newPhase in
            // D-14: validate stored Apple credential on every .active transition.
            // AuthStore.validateOnSceneActive early-returns when not signed in
            // (Pitfall G mitigation — no network call without stored userID).
            if newPhase == .active {
                Task {
                    await authStore.validateOnSceneActive()
                }
            }
        }
        .onChange(of: authStore.isSignedIn) { wasSignedIn, isNowSignedIn in
            // T-06-08 + D-13: when revocation clears the Keychain (isSignedIn
            // flips true→false), turn the cloud-sync flag off. Container
            // reconfigures to .none on next cold-start; same-store-path
            // (D-08) preserves all local rows. Cloud rows remain on iCloud
            // server (Pitfall 4).
            if wasSignedIn && !isNowSignedIn {
                settingsStore.cloudSyncEnabled = false
            }
        }
        .alert(
            String(localized: "Restart to enable iCloud sync"),
            isPresented: Bindable(authStore).shouldShowRestartPrompt
        ) {
            // D-04 + D-05 verbatim. Cancel uses .cancel role; Quit GameKit
            // uses default role (NOT .destructive — quitting is non-destructive,
            // data is safe; PATTERNS §S7 line 1002).
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Quit GameKit")) {
                // T-06-05 / D-05 LOCK: dismiss-only — no programmatic
                // termination of any kind (App Store Review red flag).
                // The body copy instructs the user to manually swipe
                // up from the app switcher and reopen; that
                // user-initiated action is the only Review-compliant
                // termination path.
            }
        } message: {
            Text(String(localized: "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."))
        }
    }
}
