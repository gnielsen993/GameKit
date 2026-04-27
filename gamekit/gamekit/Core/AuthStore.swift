//
//  AuthStore.swift
//  gamekit
//
//  P6 (D-13): Apple userID Keychain persistence + revocation/scene-active
//  lifecycle. Wraps `KeychainBackend` (Plan 06-01) for verbatim SC2 attribute
//  storage and registers `ASAuthorizationAppleIDProvider.credentialRevokedNotification`
//  observer in `init` so a revoked credential clears local sign-in state
//  silently — PERSIST-05 "never nag" verbatim.
//
//  P6 (D-16): Keychain wrapper isolation via `protocol KeychainBackend`
//  (Plan 06-01). AuthStore composes that protocol; tests inject
//  `InMemoryKeychainBackend` so no host-app entitlement is required.
//
//  P6 (D-14): scene-active validation via
//  `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)` wrapped
//  in `withCheckedContinuation`. Pitfall F: error path early-returns
//  `.notFound` BEFORE the success-path resume so the continuation is
//  resumed exactly once. Treats `.revoked` / `.notFound` / `.transferred`
//  as no-longer-authorized; `.authorized` is the no-op happy path.
//
//  Test seam (D-16, PATTERNS §6 line 384): a second protocol
//  `CredentialStateProvider: Sendable` mirrors KeychainBackend's protocol
//  shape, so `StubCredentialStateProvider` (test target) returns each of
//  the 4 `CredentialState` cases deterministically without hitting the
//  real Apple framework.
//
//  Threat-model mitigations (Plan 06-04 register):
//    - T-06-01 (Information Disclosure, userID storage path): AuthStore
//      reads/writes ONLY through KeychainBackend — never the user-defaults
//      store.
//    - T-06-02 (Information Disclosure, os.Logger): every `logger.*`
//      call uses outcome words only ("Signed in", "Cleared local sign-in
//      state: <reason>"). The userID NEVER appears in any log string.
//    - T-06-03 (Information Disclosure, token leak): AuthStore.signIn
//      takes ONLY the userID String. The full ASAuthorizationAppleIDCredential
//      (which carries the identity-bearing token field) does NOT cross into
//      AuthStore — Plan 06-07 / 06-08 extract `credential.user` at the
//      call site.
//    - T-06-08 (Loss of Availability, sign-out): `clearLocalSignInState`
//      deletes ONLY the Keychain userID entry; never imports SwiftData
//      and never touches the persistence container.
//    - T-06-PitfallF (Tampering, double-resume): error path early-return
//      ahead of the success-path resume in `SystemCredentialStateProvider`.
//
//  Logging note: `os.Logger(subsystem: "com.lauterstar.gamekit",
//  category: "auth")` — outcomes only, NEVER the userID. T-06-02 lock.
//

import Foundation
import AuthenticationServices
import SwiftUI
import os

// MARK: - Test seam (D-16; PATTERNS §6 line 384)

/// Test seam — abstracts `ASAuthorizationAppleIDProvider` so tests can stub
/// each `CredentialState` case (PATTERNS §6 line 384 + RESEARCH §Pattern 2).
/// Mirrors `KeychainBackend`'s protocol shape from Plan 06-01.
protocol CredentialStateProvider: Sendable {
    func getCredentialState(
        forUserID userID: String
    ) async -> ASAuthorizationAppleIDProvider.CredentialState
}

// MARK: - Production credential-state provider

/// Production conformer wrapping `ASAuthorizationAppleIDProvider`'s
/// callback API in `withCheckedContinuation` (RESEARCH §Pattern 2 +
/// Pitfall F — must resume exactly once).
@MainActor
struct SystemCredentialStateProvider: CredentialStateProvider {
    func getCredentialState(
        forUserID userID: String
    ) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                // Pitfall F: resume exactly once. Error path defensively
                // returns .notFound; otherwise pass state through.
                if error != nil {
                    continuation.resume(returning: .notFound)
                    return
                }
                continuation.resume(returning: state)
            }
        }
    }
}

// MARK: - AuthStore

@Observable
@MainActor
final class AuthStore {

    // MARK: - Constants

    private static let appleUserIDAccount = "appleUserID"
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )

    // MARK: - Dependencies (D-16 protocol seams)

    private let backend: KeychainBackend
    private let credentialStateProvider: CredentialStateProvider

    // MARK: - Observed state

    /// D-03 root-level alert trigger. Both SIWA-success sites
    /// (SettingsView Plan 06-07 + IntroFlowView Plan 06-08) flip this
    /// to true; RootTabView's `.alert(isPresented:)` reads via Bindable.
    var shouldShowRestartPrompt: Bool = false

    // MARK: - Computed (read-through to backend)

    var isSignedIn: Bool { backend.read(account: Self.appleUserIDAccount) != nil }
    var currentUserID: String? { backend.read(account: Self.appleUserIDAccount) }

    // MARK: - Init

    init(
        backend: KeychainBackend = SystemKeychainBackend(),
        credentialStateProvider: CredentialStateProvider = SystemCredentialStateProvider()
    ) {
        self.backend = backend
        self.credentialStateProvider = credentialStateProvider
        registerRevocationObserver()
    }

    // MARK: - Sign-in (D-02 caller flips cloudSyncEnabled BEFORE prompt)

    /// Writes the opaque Apple userID to Keychain. Throws `KeychainError`
    /// on write failure; caller (Plan 06-07/06-08) treats as silent log
    /// per PERSIST-05 "never nag".
    func signIn(userID: String) throws {
        try backend.write(userID, account: Self.appleUserIDAccount)
        // T-06-02 lock: NEVER interpolate userID into log output.
        Self.logger.info("Signed in (userID hidden)")
    }

    // MARK: - Lifecycle (D-14)

    /// Called from RootTabView's scenePhase observer on `.active`
    /// (Plan 06-06). `async` because `getCredentialState` is callback-based;
    /// safe to call when not signed in (early-return — Pitfall G mitigation).
    func validateOnSceneActive() async {
        guard let stored = currentUserID else { return }
        let state = await credentialStateProvider.getCredentialState(forUserID: stored)
        switch state {
        case .authorized:
            return  // happy path
        case .revoked, .notFound, .transferred:
            // D-14 + defensive: .transferred treated like .notFound
            // (rare developer-account migration; Apple docs suggest treat
            // as no-longer-authorized).
            clearLocalSignInState(reason: "scene-active state=\(state)")
        @unknown default:
            clearLocalSignInState(reason: "scene-active unknown state")
        }
    }

    // MARK: - Private

    private func registerRevocationObserver() {
        // D-13: silent — no alert (PERSIST-05 "never nag" verbatim).
        // Selector-based registration (no queue arg) delivers the callback
        // SYNCHRONOUSLY on the same thread that called .post — required for
        // PATTERNS §6 line 376 + Plan 06-01 Test 2 (state must be cleared
        // BEFORE NotificationCenter.post returns). Block-based addObserver
        // with queue:.main hops through a dispatch_async; that breaks the
        // sync-test contract. Selector-based + @objc + @MainActor-isolated
        // method is Swift-6-strict-concurrency-clean.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRevocation(_:)),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )
    }

    @objc private func handleRevocation(_ notification: Notification) {
        // @objc selector reaches here on whatever thread .post was called
        // from. Tests post from main; the production AuthenticationServices
        // framework also posts from main (Apple docs). MainActor.assumeIsolated
        // is the narrow-and-correct shape here vs. wrapping in
        // Task { @MainActor in ... } which would defer past .post returning.
        MainActor.assumeIsolated {
            clearLocalSignInState(reason: "credentialRevokedNotification")
        }
    }

    private func clearLocalSignInState(reason: String) {
        do {
            try backend.delete(account: Self.appleUserIDAccount)
            Self.logger.info(
                "Cleared local sign-in state: \(reason, privacy: .public)"
            )
        } catch {
            Self.logger.error(
                "Failed to clear sign-in state: \(error.localizedDescription, privacy: .public)"
            )
            // Continue: caller-observable surface is `currentUserID == nil`
            // on next backend.read(); even if delete fails, the next sign-in
            // overwrites idempotently (KeychainBackend.write delete-then-add).
        }
    }

    // MARK: - DEBUG test seams (PATTERNS §S5 — internal #if DEBUG)
    #if DEBUG
    internal func clearForTesting() {
        try? backend.delete(account: Self.appleUserIDAccount)
    }
    #endif
}

// MARK: - EnvironmentKey injection (PATTERNS §S1; mirrors SettingsStore.swift:124-135)

private struct AuthStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = AuthStore(
        backend: SystemKeychainBackend(),
        credentialStateProvider: SystemCredentialStateProvider()
    )
}

extension EnvironmentValues {
    var authStore: AuthStore {
        get { self[AuthStoreKey.self] }
        set { self[AuthStoreKey.self] = newValue }
    }
}
