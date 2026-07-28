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
//  P5 (D-23, SHELL-04): routes directly to the 3-step IntroFlowView when
//  settingsStore.hasSeenIntro is false. IntroFlowView writes the flag on
//  Skip / Done, then the root crossfades to HomeView. Returning launches
//  construct HomeView directly, so neither path flashes the other.
//
//  P6 (D-13/D-14): observes scenePhase to call
//  AuthStore.validateOnSceneActive() on every .active transition (D-14
//  silent revocation catch). On authStore.isSignedIn transition from true
//  to false (revocation) flips settingsStore.cloudSyncEnabled = false and
//  reconfigures the container to .none in the same session; same-store-path
//  lock (D-08) preserves local data and cloud rows.
//
//  The root-level "quit and reopen" Restart prompt (D-03/D-04/D-05) was
//  removed 2026-07-27. It existed only because the container's sync mode was
//  fixed at launch; AppStartupController.reconfigure(cloudSyncEnabled:) now
//  swaps it live, so there is nothing left for the user to do by hand.
//

import SwiftUI
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.authStore) private var authStore
    @Environment(\.appStartupController) private var startupController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: Theme { themeManager.theme(using: colorScheme) }
    private var destinationAnimation: Animation? {
        settingsStore.animationsEnabled && !reduceMotion
            ? .easeOut(duration: theme.motion.normal)
            : nil
    }

    var body: some View {
        Group {
            if settingsStore.hasSeenIntro {
                HomeView()
                    .transition(.opacity)
            } else {
                IntroFlowView()
                    .transition(.opacity)
            }
        }
        .tint(theme.colors.accentPrimary)
        .animation(destinationAnimation, value: settingsStore.hasSeenIntro)
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
            // flips true→false), turn the cloud-sync flag off and drop the
            // container to .none in the same session. Same-store-path (D-08)
            // preserves all local rows. Cloud rows remain on iCloud server
            // (Pitfall 4).
            if wasSignedIn && !isNowSignedIn {
                settingsStore.cloudSyncEnabled = false
                Task { await startupController?.reconfigure(cloudSyncEnabled: false) }
            }
        }
    }
}
