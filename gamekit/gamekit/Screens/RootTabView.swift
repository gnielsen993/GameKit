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
            // flips true→false), turn the cloud-sync flag off. Container
            // reconfigures to .none on next cold-start; same-store-path
            // (D-08) preserves all local rows. Cloud rows remain on iCloud
            // server (Pitfall 4).
            if wasSignedIn && !isNowSignedIn {
                settingsStore.cloudSyncEnabled = false
            }
        }
        .alert(
            String(localized: "Quit and reopen to finish iCloud setup"),
            isPresented: Bindable(authStore).shouldShowRestartPrompt
        ) {
            // D-04 + D-05 (revised 2026-05-01): button labels updated for
            // honesty. The previous "Restart to enable iCloud sync" title +
            // "Quit GameKit" button promised an action that the dismiss-only
            // body never delivered, which read as "broken" to users. New
            // copy makes it explicit that the user is the one doing the
            // quitting. T-06-05 / D-05 LOCK preserved — both buttons remain
            // dismiss-only; no programmatic termination (App Store Review
            // red flag). App name interpolated from AppInfo.displayName so
            // future renames don't re-introduce the brand-drift bug.
            Button(String(localized: "Later"), role: .cancel) { }
            Button(String(localized: "OK")) { }
        } message: {
            Text(String(localized: "Your stats will sync to all devices signed in to this iCloud account. Swipe up in the app switcher to quit \(AppInfo.displayName), then reopen it to finish setup."))
        }
    }
}
