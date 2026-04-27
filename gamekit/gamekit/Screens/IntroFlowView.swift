//
//  IntroFlowView.swift
//  gamekit
//
//  P5 (D-18..D-24, SHELL-04, A11Y-01, A11Y-02): 3-step first-launch intro presented
//  via .fullScreenCover from RootTabView. TabView(.page) swipeable; Skip top-trailing
//  every step; Continue (steps 1+2) / Done (step 3) bottom-trailing. Both Skip and
//  Done write settingsStore.hasSeenIntro = true and dismiss the cover.
//
//  Layout per 05-CONTEXT D-18..D-24:
//    - Step 1 "Make it yours" — read-only DKThemePicker(catalog: .core) preview (D-19)
//    - Step 2 "Track your progress" — hand-coded sample stats card (D-20)
//    - Step 3 "Sync across devices" — SignInWithAppleButton + Skip in a DKCard (D-21)
//
//  Phase 5 invariants:
//    - No NavigationStack inside the cover (D-18) — Skip/Continue/Done overlays only
//    - .tabViewStyle(.page(indexDisplayMode: .always)) + .indexViewStyle(...) per D-18
//    - SignInWithAppleButton renders but onCompletion is a no-op in P5 — P6 PERSIST-04
//      wires the actual auth flow. The capability MUST be present in
//      gamekit.entitlements (com.apple.developer.applesignin = [Default]) for the
//      button to render at all and for the P6 wiring to not throw
//      ASAuthorizationErrorUnknown — added in this same plan
//    - Both Skip and Done call dismissIntro() which writes hasSeenIntro = true
//      then dismisses (single source of truth for the dismissal contract)
//    - Every step gates .dynamicTypeSize(...accessibility5) and uses
//      .accessibilityElement(children: .combine) (steps 1+2) or .contain (step 3)
//      per D-24 — SIWA owns its own a11y label so step 3 uses .contain
//

import SwiftUI
import DesignKit
import AuthenticationServices
import os

struct IntroFlowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 0

    private var theme: Theme { themeManager.theme(using: colorScheme) }
    private static let totalSteps = 3
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()
            TabView(selection: $currentStep) {
                IntroStep1ThemesView(theme: theme)
                    .tag(0)
                IntroStep2StatsView(theme: theme)
                    .tag(1)
                IntroStep3SignInView(
                    theme: theme,
                    colorScheme: colorScheme,
                    onSkip: dismissIntro,
                    onSignIn: signInTapped
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .tint(theme.colors.accentPrimary)
        }
        // Skip — top-trailing on every step (D-22).
        .overlay(alignment: .topTrailing) {
            DKButton(
                String(localized: "Skip"),
                style: .secondary,
                theme: theme,
                action: dismissIntro
            )
            .frame(width: 88)
            .padding(theme.spacing.l)
            .accessibilityLabel(String(localized: "Skip intro"))
        }
        // Continue / Done — bottom-trailing (D-22).
        .overlay(alignment: .bottomTrailing) {
            bottomActionButton
                .padding(theme.spacing.l)
        }
    }

    @ViewBuilder
    private var bottomActionButton: some View {
        if currentStep < Self.totalSteps - 1 {
            DKButton(
                String(localized: "Continue"),
                style: .primary,
                theme: theme,
                action: { withAnimation { currentStep += 1 } }
            )
            .frame(width: 140)
            .accessibilityLabel(String(localized: "Continue to next step"))
        } else {
            DKButton(
                String(localized: "Done"),
                style: .primary,
                theme: theme,
                action: dismissIntro
            )
            .frame(width: 140)
            .accessibilityLabel(String(localized: "Finish intro"))
        }
    }

    /// Single dismissal path used by Skip + Done (PATTERNS line 451 — single
    /// source of truth). Writes hasSeenIntro = true then dismisses; the
    /// SettingsStore.didSet persists synchronously to UserDefaults so a
    /// cold-relaunch never re-presents the cover (CONTEXT D-23).
    private func dismissIntro() {
        settingsStore.hasSeenIntro = true
        dismiss()
    }

    /// SIWA tap closure — P6 PERSIST-04 wires actual auth. Logs only in P5
    /// per CONTEXT D-21. The button visually responds (system handling) but
    /// no auth flow is initiated.
    private func signInTapped() {
        Self.logger.info("SIWA tapped during intro (P6 wires actual auth via PERSIST-04 — D-21)")
    }
}

// MARK: - Step 1: Themes preview (D-19)

private struct IntroStep1ThemesView: View {
    let theme: Theme
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            Text(String(localized: "Make it yours"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Pick a theme that fits your mood. Five Classic palettes here, dozens more in Settings."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: theme.spacing.xxl)
            // Read-only swatches preview — taps are no-op (D-19).
            DKThemePicker(
                themeManager: themeManager,
                theme: theme,
                scheme: colorScheme,
                catalog: PresetCatalog.core,
                maxGridHeight: nil,
                grouped: false
            )
            .allowsHitTesting(false)            // read-only per D-19
            Spacer(minLength: theme.spacing.xxl)
        }
        .padding(theme.spacing.l)
        .padding(.top, theme.spacing.xxl)
        .frame(maxWidth: 480, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "Step 1 of 3. Make it yours. Pick a theme that fits your mood. Five Classic palettes here, dozens more in Settings.")))
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}

// MARK: - Step 2: Stats preview (D-20)

private struct IntroStep2StatsView: View {
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            Text(String(localized: "Track your progress"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Best times and win streaks save automatically. No accounts. No leaderboards. Just your numbers."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: theme.spacing.xxl)
            // Hand-coded sample stats — NOT @Query (CLAUDE.md §8.3 + UI-SPEC line 148).
            // Onboarding never shows the empty state; the sample numbers convey what
            // StatsView will surface once the user plays.
            DKCard(theme: theme) {
                VStack(spacing: theme.spacing.s) {
                    sampleRow(difficulty: String(localized: "Easy"),   plays: "12", winPct: "67%", best: "1:42")
                    sampleRow(difficulty: String(localized: "Medium"), plays: "5",  winPct: "40%", best: "4:15")
                    sampleRow(difficulty: String(localized: "Hard"),   plays: "—",  winPct: "—",   best: "—")
                }
            }
            Spacer(minLength: theme.spacing.xxl)
        }
        .padding(theme.spacing.l)
        .padding(.top, theme.spacing.xxl)
        .frame(maxWidth: 480, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "Step 2 of 3. Track your progress. Best times and win streaks save automatically. No accounts. No leaderboards. Just your numbers.")))
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }

    @ViewBuilder
    private func sampleRow(difficulty: String, plays: String, winPct: String, best: String) -> some View {
        HStack {
            Text(difficulty)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Text(plays)
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
            Text(winPct)
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
            Text(best)
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
        }
    }
}

// MARK: - Step 3: Sign-in card with Skip (D-21)

private struct IntroStep3SignInView: View {
    let theme: Theme
    let colorScheme: ColorScheme
    let onSkip: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            Text(String(localized: "Sync across devices"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text(String(localized: "Sign in with Apple to sync your stats across iPhone, iPad, and Mac. Optional — the app works fully without it."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: theme.spacing.xxl)
            DKCard(theme: theme) {
                VStack(spacing: theme.spacing.s) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { _ in onSignIn() },
                        onCompletion: { _ in
                            // P6 PERSIST-04 wires this — no-op in P5 (D-21).
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 44)
                    // Apple HIG forbids tint override; system rounds to ~50pt — accept (UI-SPEC line 253).
                    DKButton(
                        String(localized: "Skip"),
                        style: .secondary,
                        theme: theme,
                        action: onSkip
                    )
                }
            }
            Spacer(minLength: theme.spacing.xxl)
        }
        .padding(theme.spacing.l)
        .padding(.top, theme.spacing.xxl)
        .frame(maxWidth: 480, alignment: .center)
        // .contain (not .combine) — SIWA owns its own a11y label (Apple HIG); we let
        // VoiceOver navigate the SIWA button as its own element while still reading
        // the title/body in order (UI-SPEC line 159).
        .accessibilityElement(children: .contain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}
