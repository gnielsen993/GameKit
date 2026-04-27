//
//  AuthStoreTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 06-04 Core/AuthStore service.
//
//  TDD RED gate (Plan 06-01): this file deliberately compile-fails with
//  `cannot find 'AuthStore' in scope` until Plan 06-04 ships AuthStore.swift.
//  The failing build IS the gate — Plan 06-04's `feat(06-04)` commit flips
//  the suite GREEN. Same RED→GREEN sequence locked in P4 04-02 (GameStats),
//  P4 04-03 (StatsExporter), P5 05-01/05-03/05-06 (see git log).
//
//  What this proves (PERSIST-04 SC2):
//    - Keychain attribute set is round-trip correct via the protocol seam
//      (D-16) — `signIn` writes to `KeychainBackend`, `currentUserID` reads
//      back; #if DEBUG `clearForTesting()` clears state for isolation.
//    - `ASAuthorizationAppleIDProvider.credentialRevokedNotification`
//      observer wired in `init` clears state synchronously on the main
//      actor (no Task hop) — mirrors HapticsTests.swift:69-80 engine-state
//      seam pattern so tests can assert directly after a sync `post`.
//    - `validateOnSceneActive()` routes the 4 `CredentialState` cases per
//      D-14: `.authorized` preserves state, `.revoked`/`.notFound`/
//      `.transferred` all clear. The `.transferred` case treated as a
//      defensive default per D-14 (rare developer-account migration).
//    - Early-return when no userID stored (D-15 reinstall path):
//      `validateOnSceneActive()` skips the credential-state probe entirely;
//      `StubCredentialStateProvider.callCount == 0` proves it.
//
//  Why @MainActor struct: AuthStore is `@Observable @MainActor final class`
//  (per CONTEXT D-13/D-14), so all calls require main-actor isolation.
//  Mirrors SFXPlayerTests (gamekitTests/Core/SFXPlayerTests.swift:41-43)
//  and HapticsTests (gamekitTests/Core/HapticsTests.swift:34-36).
//
//  Not testable here:
//    - Real Sign in with Apple flow (requires entitlement + real Apple ID).
//    - Real `getCredentialState(forUserID:)` call (network + Apple-ID
//      system state) — abstracted via `CredentialStateProvider` protocol
//      seam per PATTERNS §6 line 384.
//    - Real Keychain access (host-app entitlement) — abstracted via
//      `KeychainBackend` protocol seam per CONTEXT D-16 + Plan 06-01.
//    - Real CloudKit container handshake (P4 SC3 smoke test owns that;
//      P6 SC3 manual 2-simulator promotion test in 06-VERIFICATION.md).
//

import Testing
import Foundation
import AuthenticationServices
@testable import gamekit

// MARK: - Test-only stub for AuthStore's CredentialStateProvider seam

/// AuthStore (Plan 06-04) defines `protocol CredentialStateProvider: Sendable`
/// per RESEARCH §Pattern 2 + PATTERNS §6 line 384. This stub returns a
/// configurable `CredentialState` and records call count so the
/// `sceneActiveValidation_noStoredID` test can prove the early-return path.
@MainActor
final class StubCredentialStateProvider: CredentialStateProvider {
    var stateToReturn: ASAuthorizationAppleIDProvider.CredentialState = .authorized
    private(set) var callCount: Int = 0

    func getCredentialState(forUserID userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        callCount += 1
        return stateToReturn
    }
}

// MARK: - Suite

@MainActor
@Suite("AuthStore")
struct AuthStoreTests {

    // MARK: - Test 1 — Keychain round-trip (PERSIST-04 SC2)

    @Test("backend.write → read → delete round-trip via AuthStore")
    func keychainRoundTrip() throws {
        let backend = InMemoryKeychainBackend()
        let store = AuthStore(backend: backend, credentialStateProvider: StubCredentialStateProvider())

        try store.signIn(userID: "fake.opaque.user.id.001")
        #expect(store.currentUserID == "fake.opaque.user.id.001")
        #expect(store.isSignedIn == true)

        // Re-construct AuthStore with same backend — Keychain persisted.
        let store2 = AuthStore(backend: backend, credentialStateProvider: StubCredentialStateProvider())
        #expect(store2.currentUserID == "fake.opaque.user.id.001")

        // #if DEBUG seam — clears Keychain + currentUserID for next test.
        store2.clearForTesting()
        #expect(store2.currentUserID == nil)
    }

    // MARK: - Test 2 — Revocation observer (PERSIST-04 SC2 / D-13)

    @Test("credentialRevokedNotification clears Keychain + currentUserID")
    func revocationClearsState() throws {
        let backend = InMemoryKeychainBackend()
        let store = AuthStore(backend: backend, credentialStateProvider: StubCredentialStateProvider())
        try store.signIn(userID: "fake.user.id.002")
        #expect(store.currentUserID != nil)

        NotificationCenter.default.post(
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )

        // AuthStore's revocation handler MUST run synchronously on the
        // main actor (no Task hop) per PATTERNS §6 line 376 to allow
        // direct seam read.
        #expect(store.currentUserID == nil)
        #expect(store.isSignedIn == false)
    }

    // MARK: - Tests 3-7 — validateOnSceneActive() routing (D-14)

    @Test(".authorized preserves state — validateOnSceneActive no-op")
    func sceneActiveValidation_authorized() async throws {
        let backend = InMemoryKeychainBackend()
        let stub = StubCredentialStateProvider()
        stub.stateToReturn = .authorized
        let store = AuthStore(backend: backend, credentialStateProvider: stub)
        try store.signIn(userID: "fake.user.id.003")

        await store.validateOnSceneActive()

        #expect(store.currentUserID == "fake.user.id.003")
        #expect(store.isSignedIn == true)
        #expect(stub.callCount == 1)
    }

    @Test(".revoked clears Keychain + currentUserID")
    func sceneActiveValidation_revoked() async throws {
        let backend = InMemoryKeychainBackend()
        let stub = StubCredentialStateProvider()
        stub.stateToReturn = .revoked
        let store = AuthStore(backend: backend, credentialStateProvider: stub)
        try store.signIn(userID: "fake.user.id.004")

        await store.validateOnSceneActive()

        #expect(store.currentUserID == nil)
        #expect(store.isSignedIn == false)
        #expect(stub.callCount == 1)
    }

    @Test(".notFound clears Keychain + currentUserID")
    func sceneActiveValidation_notFound() async throws {
        let backend = InMemoryKeychainBackend()
        let stub = StubCredentialStateProvider()
        stub.stateToReturn = .notFound
        let store = AuthStore(backend: backend, credentialStateProvider: stub)
        try store.signIn(userID: "fake.user.id.005")

        await store.validateOnSceneActive()

        #expect(store.currentUserID == nil)
        #expect(store.isSignedIn == false)
        #expect(stub.callCount == 1)
    }

    @Test(".transferred clears Keychain + currentUserID — D-14 defensive default")
    func sceneActiveValidation_transferred() async throws {
        let backend = InMemoryKeychainBackend()
        let stub = StubCredentialStateProvider()
        stub.stateToReturn = .transferred
        let store = AuthStore(backend: backend, credentialStateProvider: stub)
        try store.signIn(userID: "fake.user.id.006")

        await store.validateOnSceneActive()

        #expect(store.currentUserID == nil)
        #expect(store.isSignedIn == false)
        #expect(stub.callCount == 1)
    }

    @Test("No stored userID — validateOnSceneActive early-returns; provider never called")
    func sceneActiveValidation_noStoredID() async {
        let backend = InMemoryKeychainBackend()
        let stub = StubCredentialStateProvider()
        let store = AuthStore(backend: backend, credentialStateProvider: stub)
        // No signIn — Keychain is empty per D-15 reinstall path.

        await store.validateOnSceneActive()

        #expect(store.currentUserID == nil)
        #expect(store.isSignedIn == false)
        // D-15: zero `getCredentialState` calls when nothing is stored.
        #expect(stub.callCount == 0)
    }
}
