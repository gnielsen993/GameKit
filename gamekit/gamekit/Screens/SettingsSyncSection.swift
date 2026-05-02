//
//  SettingsSyncSection.swift
//  gamekit
//
//  P6 (D-09 / D-10 / D-12 / PERSIST-04 + PERSIST-06): SYNC section in
//  SettingsView between AUDIO and DATA.
//
//  Extracted from SettingsView.swift (currently 410 lines, already at
//  CLAUDE.md §8.1 soft cap) — mirrors AcknowledgmentsView.swift
//  extraction precedent from P5 05-04 (STATE.md "05-04: extracted to
//  sibling Screens/AcknowledgmentsView.swift instead of file-private
//  inside SettingsView.swift").
//
//  Rows (D-10 + P7.1):
//    1. Sign-in row — SignInWithAppleButton when signed-out; "Signed
//       in to iCloud" label when signed-in.
//    2. Sync-status row — reads CloudSyncStatusObserver.status; wrapped
//       in TimelineView(.periodic(from: .now, by: 60)) so "Synced X ago"
//       ticks once per minute without observer churn (D-12).
//    3. Sign-out row (P7.1; signed-in only) — clears local Keychain;
//       SwiftData stats stay (offline-first §1).
//    4. Delete-account row (P7.1; signed-in only) — App Store Guideline
//       5.1.1(v). Confirm alert → AuthStore.deleteAccount wipes the
//       CloudKit private zone + Keychain. Failure path shows a follow-up
//       alert directing the user to System Settings to finish revocation.
//
//  P7.1 supersedes the original T-06-row-noSignOut lock ("System Settings
//  is the only sign-out path"): App Store Review rejects SIWA apps that
//  don't expose in-app sign-out + delete account from the same surface
//  as account creation.
//
//  SIWA-completion handler (PERSIST-04 D-02 + D-03 + Pattern 4):
//    success -> AuthStore.signIn(userID:) -> SettingsStore.cloudSyncEnabled = true
//              -> AuthStore.shouldShowRestartPrompt = true
//              (RootTabView root-level prompt surfaces the Restart copy — Plan 06-06)
//    failure -> silent os.Logger only (PERSIST-05 "never nag" — T-06-PERSIST05).
//
//  Threat mitigations:
//    T-06-04 (requestedScopes drift): request.requestedScopes = [] (SC2 verbatim)
//    T-06-03 (one-shot Apple-issued JWT): handler extracts ONLY credential.user String
//

import SwiftUI
import SwiftData
import AuthenticationServices
import DesignKit
import os

struct SettingsSyncSection: View {
    let theme: Theme

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.authStore) private var authStore
    @Environment(\.cloudSyncStatusObserver) private var cloudSyncStatusObserver

    // P7.1 alert state — destructive delete confirm + cloud-wipe-failed
    // follow-up. Both default false; alert(isPresented:) toggles back on
    // dismiss so the rows stay tappable.
    @State private var isDeleteConfirmPresented: Bool = false
    @State private var isDeleteCloudFailedAlertPresented: Bool = false

    var body: some View {
        settingsSectionHeader(theme: theme, String(localized: "SYNC"))
        DKCard(theme: theme) {
            VStack(spacing: 0) {
                signInRow
                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                syncStatusRow
                if authStore.isSignedIn {
                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 1)
                    signOutRow
                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 1)
                    deleteAccountRow
                }
            }
        }
        .alert(
            String(localized: "Delete account?"),
            isPresented: $isDeleteConfirmPresented
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete account"), role: .destructive) {
                Task { await performDeleteAccount() }
            }
        } message: {
            Text(String(localized: "This wipes your iCloud-synced stats AND your local stats on this device, and signs you out of \(AppInfo.displayName). To finish revoking Sign in with Apple, open Settings → Apple ID → Sign in with Apple → \(AppInfo.displayName)."))
        }
        .alert(
            String(localized: "Couldn't reach iCloud"),
            isPresented: $isDeleteCloudFailedAlertPresented
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "You're signed out on this device, but we couldn't wipe the iCloud copy of your stats right now. Reconnect to the internet and sign in again to retry, or open Settings → Apple ID → Sign in with Apple → \(AppInfo.displayName) to revoke access."))
        }
    }

    // MARK: - Row 1: Sign-in (D-10)

    @ViewBuilder
    private var signInRow: some View {
        if authStore.isSignedIn {
            signedInRow
        } else {
            signInButtonRow
        }
    }

    @ViewBuilder
    private var signInButtonRow: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: "icloud")
                .foregroundStyle(theme.colors.textTertiary)
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    // SC2 verbatim — userID only, no PII (T-06-04 lock).
                    request.requestedScopes = []
                },
                onCompletion: handleSIWACompletion
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, theme.spacing.s)
    }

    @ViewBuilder
    private var signedInRow: some View {
        // P7.1: status-only label — sign-out and delete-account live in
        // dedicated rows below (App Store 5.1.1(v) requires both surfaces).
        HStack(spacing: theme.spacing.s) {
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(theme.colors.success)
            Text(String(localized: "Signed in to iCloud"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, theme.spacing.s)
    }

    // MARK: - P7.1 sign-out + delete-account rows

    @ViewBuilder
    private var signOutRow: some View {
        Button {
            authStore.signOut()
            // D-08 same-store-path: keep cloudSyncEnabled mirrored to
            // signed-in state. Cloud rows on iCloud server stay intact;
            // re-signing-in restores sync (Pitfall 4).
            settingsStore.cloudSyncEnabled = false
        } label: {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(localized: "Sign out"))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .padding(.horizontal, theme.spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Sign out of iCloud"))
    }

    @ViewBuilder
    private var deleteAccountRow: some View {
        Button {
            isDeleteConfirmPresented = true
        } label: {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: "trash")
                    .foregroundStyle(theme.colors.danger)
                Text(String(localized: "Delete account"))
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .padding(.horizontal, theme.spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Delete account and iCloud data"))
        .accessibilityHint(String(localized: "Wipes your iCloud-synced stats and signs out"))
    }

    private func performDeleteAccount() async {
        let outcome = await authStore.deleteAccount()
        // D-08 mirror: clear the flag locally; container reconfigures to
        // .none on next cold-start (same-store-path preserves the file).
        settingsStore.cloudSyncEnabled = false
        // P7.1 user-feedback: "delete account" must also wipe local
        // stats — leaving GameRecord/BestTime/BestScore rows behind
        // contradicts the user's stated intent. Mirrors the Reset stats
        // path in DATA section. Failure logged silently per
        // PERSIST-05 "never nag".
        do {
            try GameStats(modelContext: modelContext).resetAll()
        } catch {
            Self.logger.error(
                "Local stats wipe failed during deleteAccount: \(error.localizedDescription, privacy: .public)"
            )
        }
        if !outcome.cloudWipeSucceeded {
            isDeleteCloudFailedAlertPresented = true
        }
    }

    // MARK: - Row 2: Sync status (D-10 + D-12 TimelineView)

    @ViewBuilder
    private var syncStatusRow: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: statusGlyph)
                .foregroundStyle(statusForegroundColor)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cloudSyncStatusObserver.status.label(at: context.date))
                        .font(theme.typography.body)
                        .foregroundStyle(statusForegroundColor)
                    if let subline = unavailableSubline(at: context.date) {
                        Text(subline)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                }
            }
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, theme.spacing.s)
    }

    private var statusGlyph: String {
        switch cloudSyncStatusObserver.status {
        case .syncing:        return "arrow.triangle.2.circlepath"
        case .syncedAt:       return "checkmark.circle"
        case .notSignedIn:    return "icloud.slash"
        case .unavailable:    return "exclamationmark.icloud"
        }
    }

    private var statusForegroundColor: Color {
        switch cloudSyncStatusObserver.status {
        case .syncing:        return theme.colors.accentPrimary
        case .syncedAt:       return theme.colors.textSecondary
        case .notSignedIn:    return theme.colors.textSecondary
        case .unavailable:    return theme.colors.danger
        }
    }

    /// Sub-line "Last synced X" only when .unavailable carries a lastSynced
    /// date (D-10 verbatim). Other states return nil — VStack drops the line.
    private func unavailableSubline(at now: Date) -> String? {
        if case .unavailable(let lastSynced) = cloudSyncStatusObserver.status,
           let lastSynced {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.dateTimeStyle = .named
            return String(
                format: String(localized: "Last synced %@"),
                formatter.localizedString(for: lastSynced, relativeTo: now)
            )
        }
        return nil
    }

    // MARK: - SIWA completion handler (PATTERN 4 + D-02 + D-03 + T-06-03)

    private func handleSIWACompletion(_ result: Result<ASAuthorization, Error>) {
        // Wrap in @MainActor Task to satisfy Swift 6 strict concurrency
        // (RESEARCH §Anti-Patterns line 696). SIWA onCompletion fires on
        // main per Apple docs but explicit @MainActor capture avoids warnings.
        Task { @MainActor in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential
                        as? ASAuthorizationAppleIDCredential else {
                    Self.logger.error("SIWA returned non-Apple-ID credential")
                    return
                }
                // T-06-03: extract ONLY credential.user (the opaque userID).
                // DO NOT touch credential. one-shot JWT property; never persist.
                do {
                    try authStore.signIn(userID: credential.user)
                    // D-02: flip flag BEFORE prompt; the prompt is a UX hint,
                    // not a consent gate. If user cancels, next cold-start
                    // picks up cloudSyncEnabled=true and reconfigures container.
                    settingsStore.cloudSyncEnabled = true
                    // D-03: trigger root-level prompt via AuthStore property.
                    // RootTabView root-level prompt (Bindable(authStore).shouldShowRestartPrompt)
                    // surfaces the Restart copy (Plan 06-06).
                    authStore.shouldShowRestartPrompt = true
                } catch {
                    // T-06-PERSIST05: silent log; no user-facing prompt (PERSIST-05 "never nag").
                    Self.logger.error(
                        "SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            case .failure(let error):
                // Silent — Pitfall 5 + PERSIST-05 verbatim.
                Self.logger.error(
                    "SIWA failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

// MARK: - Logger (subsystem + auth category — mirrors AuthStore.swift:99)

private extension SettingsSyncSection {
    static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )
}
