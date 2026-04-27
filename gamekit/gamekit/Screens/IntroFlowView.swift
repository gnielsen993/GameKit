//
//  IntroFlowView.swift
//  gamekit
//
//  P5 (D-18..D-24, SHELL-04, A11Y-01, A11Y-02): 3-step first-launch intro
//  presented via .fullScreenCover from RootTabView. TabView(.page) swipeable;
//  Skip top-trailing every step; Continue (steps 1+2) / Done (step 3)
//  bottom-trailing. Skip + Done + P6 SIWA-success all call dismissIntro()
//  which writes hasSeenIntro = true and dismisses (single source of truth).
//
//  Steps: 1 "Make it yours" (D-19) → 2 "Track your progress" (D-20) →
//  3 "Sync across devices" (D-21).
//
//  P6 (PERSIST-04): Step 3 SIWA onCompletion wires real auth — Plan 06-08
//  replaces the P5 D-21 no-op. Mirrors SettingsSyncSection handler shape.
//

import SwiftUI
import DesignKit
import AuthenticationServices
import os

struct IntroFlowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.authStore) private var authStore
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
                    onSIWARequest: handleSIWARequest,
                    onSIWACompletion: handleSIWACompletion
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

    /// Single dismissal path used by Skip + Done + P6 SIWA-success
    /// (PATTERNS line 451 — single source of truth). SettingsStore.didSet
    /// persists synchronously so a cold-relaunch never re-presents (D-23).
    private func dismissIntro() {
        settingsStore.hasSeenIntro = true
        dismiss()
    }

    // MARK: - SIWA handlers (P6 PERSIST-04 — replaces P5 D-21 no-op)

    /// T-06-04 lock: requestedScopes = [] LITERAL (SC2 verbatim).
    private func handleSIWARequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = []   // SC2 verbatim — userID only
        Self.logger.info("SIWA request initiated from intro Step 3")
    }

    /// Plan 06-07 mirror. Success: Keychain → flip cloudSyncEnabled (D-02) →
    /// flip Restart-prompt flag (D-03) → dismiss. Failure: silent log only.
    private func handleSIWACompletion(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential
                        as? ASAuthorizationAppleIDCredential else {
                    Self.logger.error("SIWA returned non-Apple-ID credential")
                    return
                }
                // T-06-03: extract ONLY credential.user; never the one-shot JWT.
                do {
                    try authStore.signIn(userID: credential.user)
                    settingsStore.cloudSyncEnabled = true        // D-02
                    authStore.shouldShowRestartPrompt = true     // D-03
                    dismissIntro()                                // STATE 05-05 SoT
                } catch {
                    Self.logger.error("SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)")
                }
            case .failure(let error):
                Self.logger.error("SIWA failed: \(error.localizedDescription, privacy: .public)")
            }
        }
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
    let onSIWARequest: (ASAuthorizationAppleIDRequest) -> Void
    let onSIWACompletion: (Result<ASAuthorization, Error>) -> Void

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
                        onRequest: { request in onSIWARequest(request) },
                        onCompletion: { result in onSIWACompletion(result) }
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
