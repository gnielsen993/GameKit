# Phase 6: CloudKit + Sign in with Apple - Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 13 (7 NEW + 6 MODIFIED)
**Analogs found:** 13 / 13

This map locks every P6 file to a concrete in-repo analog. For each NEW file we name the closest existing class/struct, the lines to copy, and the verbatim invariants (logger subsystem, EnvironmentKey shape, `@Observable @MainActor final class` skeleton, file-private row pattern, `@Suite` test layout). The planner is expected to copy these excerpts into per-plan action sections; researchers' synthetic snippets in 06-RESEARCH.md are SECONDARY to the in-repo analogs cited here.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Core/AuthStore.swift` | service (app-level singleton) | event-driven (revocation) + request-response (signIn) | `gamekit/gamekit/Core/SFXPlayer.swift` (lifecycle + EnvironmentKey) + `gamekit/gamekit/Core/Haptics.swift` (Apple-framework wrapper + non-fatal logging) | exact |
| `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` | service (app-level singleton) | event-driven (NotificationCenter) | `gamekit/gamekit/Core/SettingsStore.swift` (`@Observable @MainActor final class` shape + EnvironmentKey) | role-match (no NotificationCenter analog yet) |
| `gamekit/gamekit/Core/SyncStatus.swift` (or alongside observer) | model (pure value type) | n/a | `gamekit/gamekit/Core/Outcome.swift` / `gamekit/gamekit/Core/GameKind.swift` (small `Sendable` enum sibling files) | exact |
| `gamekit/gamekit/Core/KeychainBackend.swift` (protocol + `SystemKeychainBackend`) | service (Apple-framework wrapper) | request-response | `gamekit/gamekit/Core/Haptics.swift` (single-purpose Apple-framework wrapper with `os.Logger`) | role-match |
| `gamekit/gamekitTests/Core/AuthStoreTests.swift` | test (Swift Testing) | request-response | `gamekit/gamekitTests/Core/SFXPlayerTests.swift` + `gamekit/gamekitTests/Core/HapticsTests.swift` | exact |
| `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` | test (Swift Testing) | event-driven | `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` (per-test isolated state) + `HapticsTests.swift` | role-match |
| `gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift` | test helper (protocol stub) | request-response | `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` | exact |
| `gamekit/gamekit/App/GameKitApp.swift` (MOD) | app entry / DI root | construction-time wiring | self (current file — extend P4 D-29 + P5 D-12 pattern) | exact |
| `gamekit/gamekit/Screens/RootTabView.swift` (MOD) | screen shell | event-driven (scenePhase + alert) | self + `gamekit/gamekit/Screens/SettingsView.swift` lines 102-117 (existing `.alert` precedent) | exact |
| `gamekit/gamekit/Screens/SettingsView.swift` (MOD — new SYNC section) | screen | request-response | self §audioSection (lines 161-185) + §dataSection (lines 187-224) | exact |
| `gamekit/gamekit/Screens/IntroFlowView.swift` (MOD) | screen | request-response | self lines 124, 245-251 (replace no-op) + RESEARCH Code Example 4 | exact |
| `gamekit/gamekit/Resources/Localizable.xcstrings` (MOD) | resource | n/a | self (auto-extracted at build time) | n/a |
| `gamekit/gamekit/gamekit.entitlements` (MOD — verify only) | config | n/a | self (already shipped P5 D-21) | n/a |

---

## Pattern Assignments

### 1. `gamekit/gamekit/Core/AuthStore.swift` (NEW — service, event-driven + request-response)

**Primary analog:** `gamekit/gamekit/Core/SFXPlayer.swift` (skeleton, EnvironmentKey, logger).
**Secondary analog:** `gamekit/gamekit/Core/Haptics.swift` (Apple-framework wrapper + non-fatal logging).

#### Skeleton — copy from `SFXPlayer.swift`

**Header doc-comment shape (`SFXPlayer.swift` lines 1-44):** five-section `// MARK: -` layout — purpose / Phase invariants / threat model / `Foundation`+framework imports / `os.Logger`. Replicate verbatim with phase-6-specific bullets per CONTEXT D-13/D-14/D-16.

**Class declaration (`SFXPlayer.swift` lines 46-72):**

```swift
import Foundation
import AuthenticationServices
import Security
import os

@Observable
@MainActor
final class AuthStore {

    // MARK: - Backend (D-16 — protocol seam for testability)
    private let backend: KeychainBackend

    // MARK: - Apple framework
    private let provider = ASAuthorizationAppleIDProvider()

    // MARK: - Logger (mirror Haptics.swift:54-57 + GameStats.swift:47-50)
    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )

    // MARK: - Init
    init(backend: KeychainBackend = SystemKeychainBackend()) {
        self.backend = backend
        // D-13: register credentialRevokedNotification observer in init.
        // Mirror SFXPlayer.init layout — wire framework state, log non-fatal.
        registerRevocationObserver()
    }
}
```

> **Critical contrast vs. SFXPlayer:** SFXPlayer's `@Observable` is implicit by being injected via `EnvironmentKey`; SFXPlayer.swift line 60-61 reads `@MainActor final class` without `@Observable`. **AuthStore MUST add `@Observable`** because `currentUserID` flips on revocation and SettingsView's SYNC row reads it in a SwiftUI body. This matches `SettingsStore.swift` line 34-36 (`@Observable @MainActor final class SettingsStore`). Do not omit `@Observable`.

#### EnvironmentKey injection — verbatim copy from `SettingsStore.swift` lines 124-135

```swift
// MARK: - EnvironmentKey injection (mirror Core/SettingsStore.swift:124-135)

private struct AuthStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = AuthStore(backend: SystemKeychainBackend())
}

extension EnvironmentValues {
    var authStore: AuthStore {
        get { self[AuthStoreKey.self] }
        set { self[AuthStoreKey.self] = newValue }
    }
}
```

> **Note on `defaultValue`:** `SettingsStore.swift:127` and `SFXPlayer.swift:176` both construct a fresh instance for `defaultValue`. AuthStore MUST do the same (cannot use `nil` because `EnvironmentKey.Value` cannot be optional without redesign). The default value is replaced at the scene root by `.environment(\.authStore, authStore)`.

#### Non-fatal logging — copy from `Haptics.swift` lines 71-98 (per D-13)

```swift
// On revocation handler fire:
private func handleRevocation() {
    do {
        try backend.delete(account: "appleUserID")
    } catch {
        // Mirror Haptics.swift:91-97 + GameStats.swift:91-93 — log non-fatal.
        logger.error(
            "Keychain delete failed on revocation: \(error.localizedDescription, privacy: .public)"
        )
        // Continue — flag flip MUST proceed even if Keychain delete fails.
    }
    // Flag flip is the contract; Keychain delete is best-effort.
    // (SettingsStore is a separate dependency; planner injects via init.)
}
```

> **Privacy posture (RESEARCH Anti-Patterns line 693):** Apple userID MUST NEVER appear in `os.Logger` output even with `privacy: .private`. Log outcomes only ("revoked", "wrote keychain"), not the userID itself. Compare GameStats.swift:91-93 which logs error.localizedDescription with `privacy: .public` — this is safe because no PII is in the error string for our paths.

#### Test seam — adopt `SFXPlayer.swift` `#if DEBUG` pattern (lines 152-170)

If AuthStoreTests need direct visibility into a private cached state, mirror the SFXPlayer `#if DEBUG` test seam (`internal var lastInvocationAttempt`). Recommended seams:
- `internal var registeredObserverCount: Int` — proves observer wired exactly once (`HapticsTests.swift:69-80` pattern).
- `internal func resetForTesting()` — clears observer + Keychain for per-test isolation (`Haptics.swift:117-120`).

#### Async wrapper for `getCredentialState` — RESEARCH Pattern 2 + Discretion #6

The callback API is wrapped via `withCheckedContinuation`. No in-repo analog (project has no other callback→async bridges yet); use the synthetic snippet from RESEARCH Pattern 2 lines 358-377 verbatim. Place inside AuthStore as a `@MainActor private func getCredentialStateAsync(forUserID:) async -> ASAuthorizationAppleIDProvider.CredentialState`.

---

### 2. `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` (NEW — service, event-driven)

**Primary analog:** `gamekit/gamekit/Core/SettingsStore.swift` (`@Observable @MainActor final class` skeleton + EnvironmentKey).

#### Class declaration — copy `SettingsStore.swift` lines 31-50

```swift
import Foundation
import CoreData     // for NSPersistentCloudKitContainer.eventChangedNotification
import os

@Observable
@MainActor
final class CloudSyncStatusObserver {

    // MARK: - Published state (mirror SettingsStore line 38-49 didSet pattern,
    //         minus the UserDefaults write — observer doesn't persist anything)
    private(set) var status: SyncStatus

    // MARK: - Private state
    private var lastSyncDate: Date?

    // MARK: - Logger (mirror SFXPlayer.swift:69-72; category "cloudkit" per CONTEXT line 203)
    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "cloudkit"
    )

    init(initialStatus: SyncStatus = .notSignedIn) {
        self.status = initialStatus
        // RESEARCH Pattern 5 lines 572-577 — addObserver pattern.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }
}
```

> **Why `private(set)`:** SettingsStore's `cloudSyncEnabled` is `var` because the view binds via `Bindable(settingsStore).hapticsEnabled` (SettingsView.swift:172). The status row is READ-ONLY from the view — it should NEVER bind. Use `private(set) var status: SyncStatus` to enforce that the observer is the only writer.

#### EnvironmentKey injection — copy from `SettingsStore.swift` lines 124-135

```swift
private struct CloudSyncStatusObserverKey: EnvironmentKey {
    @MainActor static let defaultValue = CloudSyncStatusObserver()
}

extension EnvironmentValues {
    var cloudSyncStatusObserver: CloudSyncStatusObserver {
        get { self[CloudSyncStatusObserverKey.self] }
        set { self[CloudSyncStatusObserverKey.self] = newValue }
    }
}
```

#### Event handler — RESEARCH Pattern 5 lines 580-613 verbatim

The translator (`event.endDate == nil → .syncing`, `event.succeeded → .syncedAt`, error → `.unavailable`) has no in-repo analog. Use RESEARCH §Pattern 5 verbatim. The `@objc private func handleEvent(_ notification: Notification)` selector signature is correct because `NotificationCenter.addObserver(_:selector:name:object:)` predates async/await.

> **`@objc` + `@MainActor` collision:** A `@MainActor`-isolated `@objc func` IS allowed under Swift 6 if the selector is invoked on the main thread. `NotificationCenter` posts on whatever thread fires the notification; `NSPersistentCloudKitContainer.eventChangedNotification` is documented to fire on a background queue. **Mitigation:** wrap the handler body in `Task { @MainActor in ... }` or use `@objc nonisolated private func handleEvent(...)` that hops to main with `MainActor.assumeIsolated` / `Task { @MainActor in self.applyEvent(event) }`. Planner picks; recommend the inner-`Task { @MainActor in }` approach (cleaner under strict concurrency).

---

### 3. `gamekit/gamekit/Core/SyncStatus.swift` (NEW — pure value type)

**Primary analog:** `gamekit/gamekit/Core/Outcome.swift` and `gamekit/gamekit/Core/GameKind.swift` (small `Sendable` enums in their own files).

#### Skeleton (no in-repo analog read; pattern locked by precedent — small enum-only file ≤30 lines)

```swift
//
//  SyncStatus.swift
//  gamekit
//
//  P6 (D-10): 4-state enum read by Settings SYNC status row + driven by
//  CloudSyncStatusObserver. Pure value type — no SwiftUI / no SwiftData
//  imports. Lives alongside CloudSyncStatusObserver per CONTEXT Discretion;
//  promoted to a sibling file IFF a 2nd consumer (e.g. HomeView badge) appears.
//

import Foundation

enum SyncStatus: Equatable, Sendable {
    case syncing
    case syncedAt(Date)
    case notSignedIn
    case unavailable(lastSynced: Date?)
}
```

> **Discretion call:** CONTEXT line 96-97 says either "alongside the observer" or "sibling `Core/SyncStatus.swift`" is acceptable. Recommend **sibling file** because: (a) it keeps `CloudSyncStatusObserver.swift` under the CLAUDE.md §8.1 ~400-line soft cap, (b) the relative-time label formatter (Specifics line 199-200) naturally belongs as a `var label: String` extension on the enum and an extension lives cleaner in its own file, (c) pure enums in their own file are a project precedent (`Outcome.swift`, `GameKind.swift`).

---

### 4. `gamekit/gamekit/Core/KeychainBackend.swift` (NEW — protocol + `SystemKeychainBackend`)

**Primary analog:** `gamekit/gamekit/Core/Haptics.swift` (single-purpose Apple-framework wrapper with `os.Logger` non-fatal failure).

#### Protocol — RESEARCH Pattern 3 lines 393-397 verbatim

```swift
protocol KeychainBackend: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String) throws
    func delete(account: String) throws
}
```

#### `SystemKeychainBackend` — RESEARCH Pattern 3 lines 399-449 verbatim

> **Verbatim attributes from CONTEXT Specifics line 202 — non-negotiable:**
> ```swift
> kSecClass as String:        kSecClassGenericPassword,
> kSecAttrService as String:  "com.lauterstar.gamekit.auth",
> kSecAttrAccount as String:  account,        // "appleUserID" passed in
> kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
> ```
> Any deviation breaks SC2 verbatim lock.

#### `KeychainError` enum — RESEARCH Pattern 3 lines 451-454

```swift
enum KeychainError: Error {
    case writeFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
}
```

> **Idempotent write pattern (RESEARCH lines 421-423):** `try? delete(account:)` BEFORE `SecItemAdd` to avoid `errSecDuplicateItem`. This matches the spirit of `GameStats.evaluateBestTime` (Core/GameStats.swift:139-153) which is insert-or-mutate-or-noop — same "make it work whatever the prior state" posture.

> **Annotation:** RESEARCH Pattern 3 marks `SystemKeychainBackend` as `@MainActor final class`. Re-evaluate: SecItem APIs are thread-safe; `@MainActor` is restrictive but consistent with the rest of Core/ (SFXPlayer, GameStats, SettingsStore all `@MainActor`). Keep `@MainActor` for consistency unless tests require off-main calls (they shouldn't — `InMemoryKeychainBackend` runs in `@MainActor` test methods).

---

### 5. `gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift` (NEW — test helper)

**Primary analog:** `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` (verbatim — protocol/factory test seam, P4 D-31 pattern, `@testable import gamekit`).

#### Header — copy `InMemoryStatsContainer.swift` lines 1-25 layout

```swift
//
//  InMemoryKeychainBackend.swift
//  gamekitTests
//
//  Test-only KeychainBackend stub (D-16). In-memory dictionary; no SecItem
//  calls; no host-app entitlement needed.
//
//  Critical placement: TEST TARGET ONLY. If this file ends up in the
//  production app target, the AuthStore default-value EnvironmentKey
//  would silently swap to the in-memory backend in release builds.
//
//  Why @MainActor: AuthStore is @MainActor; KeychainBackend conformers
//  must align. Mirrors InMemoryStatsContainer.swift:35-36.
//
//  Why class-with-dictionary: matches RESEARCH Pattern 3 lines 458-463
//  test-stub idiom; in-memory state means tests are deterministic without
//  a tearDown step.
//

import Foundation
@testable import gamekit
```

#### Body — RESEARCH Pattern 3 lines 458-463 verbatim

```swift
@MainActor
final class InMemoryKeychainBackend: KeychainBackend {
    private var store: [String: String] = [:]

    func read(account: String) -> String? { store[account] }
    func write(_ value: String, account: String) throws { store[account] = value }
    func delete(account: String) throws { store[account] = nil }
}
```

> **Sendable conformance:** `KeychainBackend: Sendable` (RESEARCH line 393) but `InMemoryKeychainBackend` has mutable state. The `@MainActor` isolation makes it main-actor-`Sendable` automatically (Swift 6 main-actor types are `Sendable` by construction).

---

### 6. `gamekit/gamekitTests/Core/AuthStoreTests.swift` (NEW — Swift Testing)

**Primary analog:** `gamekit/gamekitTests/Core/SFXPlayerTests.swift` (gating-at-source pattern via `#if DEBUG` test seam) + `gamekit/gamekitTests/Core/HapticsTests.swift` (Apple-framework wrapper test layout).

#### Header — copy `SFXPlayerTests.swift` lines 1-34

Key invariants to mirror in the file header:
- "What this proves" bulleted list (SFXPlayerTests.swift:8-25)
- "Why @MainActor struct" justification (SFXPlayerTests.swift:26-29)
- Note about which paths are NOT testable (SFXPlayerTests.swift:30-33 — for AuthStore the un-testable surface is real `getCredentialState` / real Apple ID — must be stubbed)

#### Imports + suite — verbatim from `HapticsTests.swift` lines 29-36

```swift
import Testing
import Foundation
import AuthenticationServices
@testable import gamekit

@MainActor
@Suite("AuthStore")
struct AuthStoreTests {
    // ...
}
```

#### Round-trip test — pattern from `SettingsStoreFlagsTests.swift` lines 60-69

```swift
@Test("backend.write → read → delete round-trip")
func backend_roundTrip() throws {
    let backend = InMemoryKeychainBackend()
    let store = AuthStore(backend: backend)

    try store.signIn(userID: "fake.opaque.user.id.001")
    #expect(store.currentUserID == "fake.opaque.user.id.001")

    store.signOutLocally()  // or whatever revocation handler is named
    #expect(store.currentUserID == nil)
}
```

#### Revocation test — mirror `HapticsTests.swift` lines 69-80 (engine-state seam)

```swift
@Test("credentialRevokedNotification clears Keychain + currentUserID")
func revocationNotification_clearsState() throws {
    let backend = InMemoryKeychainBackend()
    let store = AuthStore(backend: backend)
    try store.signIn(userID: "fake.user.id.002")
    #expect(store.currentUserID != nil)

    NotificationCenter.default.post(
        name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
        object: nil
    )
    // Allow main-actor-hop if the handler dispatches to a Task.
    // Mirror SFXPlayerTests gating contract — direct seam read after sync.
    #expect(store.currentUserID == nil)
}
```

> **Why no `await` after `post`:** if the revocation handler dispatches via `Task { @MainActor in ... }` the test must `await` somehow. Pattern: define a `#if DEBUG var revocationHandlerCompleted: AsyncStream<Void>` seam OR assert eventually via `#expect(eventually:)`-style polling. `HapticsTests.swift:69-80` solves the analogous problem by reading `Haptics.hasInitializedEngineForTesting` directly after a synchronous call — AuthStore's revocation handler should complete synchronously on the main actor (no Task hop) to allow the same test pattern.

#### `validateOnSceneActive` test — INJECT a stub provider

`ASAuthorizationAppleIDProvider` is not mockable directly. Recommend a second protocol seam:

```swift
// In AuthStore.swift:
protocol CredentialStateProvider: Sendable {
    func getCredentialState(forUserID: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}
```

Tests inject a stub that returns `.revoked` / `.notFound` / `.authorized` per scenario. Same pattern shape as `KeychainBackend`. Mirror `InMemoryStatsContainer.swift` factory style.

---

### 7. `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` (NEW — Swift Testing)

**Primary analog:** `HapticsTests.swift` for synthetic-event-then-assert pattern + `SettingsStoreFlagsTests.swift` for per-test isolation.

#### Suite layout — `HapticsTests.swift` lines 34-94 layout

```swift
import Testing
import Foundation
import CoreData
@testable import gamekit

@MainActor
@Suite("CloudSyncStatusObserver")
struct CloudSyncStatusObserverTests {

    @Test("Initial status is .notSignedIn when cloudSyncEnabled = false")
    func initialStatus_notSignedIn() {
        let observer = CloudSyncStatusObserver(initialStatus: .notSignedIn)
        #expect(observer.status == .notSignedIn)
    }

    @Test("eventChangedNotification with endDate=nil flips status to .syncing")
    func event_endDateNil_flipsToSyncing() {
        let observer = CloudSyncStatusObserver(initialStatus: .notSignedIn)

        // Synthetic notification — Event must be constructed.
        // NSPersistentCloudKitContainer.Event has no public initializer;
        // tests likely need a #if DEBUG seam exposing applyEvent(type:endDate:succeeded:error:)
        // directly. Mirror SFXPlayer.swift:154-170 #if DEBUG seam shape.
        observer.applyEvent_forTesting(type: .setup, endDate: nil, succeeded: false, error: nil)
        #expect(observer.status == .syncing)
    }

    // ... 4-state cases following the same shape ...
}
```

> **Critical — `NSPersistentCloudKitContainer.Event` has no public init:** tests cannot fabricate a real `Event` payload to post via `NotificationCenter`. The cleanest path is a `#if DEBUG internal func applyEvent_forTesting(...)` seam on the observer that bypasses the notification path and tests the translator function directly. This matches SFXPlayer's `#if DEBUG internal var lastInvocationAttempt` (SFXPlayer.swift:158) and Haptics' `#if DEBUG internal static func resetForTesting()` (Haptics.swift:117-120).

#### Relative-time label test — `SettingsStoreFlagsTests.swift` round-trip pattern

```swift
@Test("Synced just now — < 60s")
func relativeLabel_lessThan60s() {
    let date = Date(timeIntervalSinceNow: -30)
    let label = SyncStatus.syncedAt(date).label  // pure function
    #expect(label.contains("just now"))
}
```

> **Pure-function locality:** put the `var label: String` on `SyncStatus` (in `SyncStatus.swift`) NOT on the observer. Pure functions are unit-testable without observer state. Mirrors `Outcome.swift` and `GameKind.swift` keeping their `rawValue` mappings on the enum itself.

---

### 8. `gamekit/gamekit/App/GameKitApp.swift` (MODIFIED — DI root)

**Primary analog:** SELF (current file — extending P4 D-29 + P5 D-12 pattern).

#### Existing `init` lines 43-72 — extend in same shape

Existing pattern (lines 43-54):
```swift
init() {
    let store = SettingsStore()
    _settingsStore = State(initialValue: store)

    let sfx = SFXPlayer()
    _sfxPlayer = State(initialValue: sfx)
    // ...
}
```

P6 ADD between SFXPlayer construction (line 54) and the schema/container construction (line 56):

```swift
// P6 (D-13): AuthStore constructed AFTER SettingsStore + SFXPlayer.
// Registers credentialRevokedNotification observer in init.
let auth = AuthStore(backend: SystemKeychainBackend())
_authStore = State(initialValue: auth)

// P6 (D-11): CloudSyncStatusObserver constructed AFTER AuthStore.
// Initial status reads SettingsStore.cloudSyncEnabled per Specifics line 204.
let observer = CloudSyncStatusObserver(
    initialStatus: store.cloudSyncEnabled ? .syncing : .notSignedIn
)
_cloudSyncStatusObserver = State(initialValue: observer)
```

#### Existing scene body lines 74-83 — add two `.environment(...)` chains and root `.alert` + `scenePhase` observer

The current body chains `.environment(\.settingsStore, ...)` + `.environment(\.sfxPlayer, ...)` (lines 78-79). Add:

```swift
.environment(\.authStore, authStore)
.environment(\.cloudSyncStatusObserver, cloudSyncStatusObserver)
```

> **Where the alert + scenePhase observer lives — D-03 + Discretion #2:** The `.alert(isPresented: $showRestartPrompt)` + `.onChange(of: scenePhase)` belong on `RootTabView` (because `RootTabView` already owns scene-active state via `.onAppear` line 48-55) NOT on `GameKitApp.body` directly. **Match analog:** `SettingsView.swift:102-117` shows the project's existing `.alert` precedent — copy that shape into RootTabView. See section 9 below.

---

### 9. `gamekit/gamekit/Screens/RootTabView.swift` (MODIFIED — add `.alert` + scenePhase observer)

**Primary analog:** SELF (lines 30-56) + `SettingsView.swift` lines 102-117 (existing `.alert` precedent).

#### Existing scenePhase pattern — current file has none; add via `@Environment(\.scenePhase)`

The current `RootTabView` has `.onAppear` (line 48-55) for the intro fullScreenCover gate but NO scenePhase observer. P6 introduces the pattern. Closest analog is the `.onAppear` shape — replace conceptually with `.onChange(of: scenePhase)`:

```swift
@Environment(\.scenePhase) private var scenePhase
@Environment(\.authStore) private var authStore
@State private var showRestartPrompt: Bool = false   // D-03 root-level

var body: some View {
    TabView(...)
        // ... existing modifiers ...
        .onChange(of: scenePhase) { _, new in
            // D-14: validate stored credential when app becomes active.
            if new == .active {
                Task { await authStore.validateOnSceneActive() }
            }
        }
        .alert(
            String(localized: "Restart to enable iCloud sync"),
            isPresented: $showRestartPrompt
        ) {
            // D-04 + D-05 verbatim. Cancel + Quit, both dismiss-only.
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Quit GameKit")) {
                // D-05: NO exit(0). Body copy directs user.
            }
        } message: {
            Text(String(localized: "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."))
        }
}
```

#### `.alert` shape — VERBATIM from `SettingsView.swift` lines 102-117

```swift
// SettingsView.swift:102-117 — existing in-repo alert precedent.
// Copy the .alert + Button + role: .cancel + message: pattern verbatim.
.alert(
    String(localized: "Reset all stats?"),
    isPresented: $isResetAlertPresented
) {
    Button(String(localized: "Cancel"), role: .cancel) {}
    Button(String(localized: "Reset all stats"), role: .destructive) {
        // ... action ...
    }
} message: {
    Text(String(localized: "..."))
}
```

> **Difference vs. Reset alert:** the Reset alert uses `role: .destructive` (red Quit button); the Restart alert uses **default role** for "Quit GameKit" per D-01 + D-05. Quitting is non-destructive (data is safe), so default role is correct.

#### Trigger wiring — Discretion #1 (RESEARCH lines 678-683)

Two acceptable approaches per RESEARCH lines 678-683:
1. Pass closure down via `.environment(\.requestRestartPrompt, { showRestartPrompt = true })`.
2. Promote `showRestartPrompt` to `AuthStore` as a `@Observable` property.

**Recommend approach 2** (RESEARCH line 683). Add `var shouldShowRestartPrompt: Bool = false` to `AuthStore`. RootTabView binds: `.alert(..., isPresented: Bindable(authStore).shouldShowRestartPrompt)`. SIWA success sites (Settings + Intro) flip `authStore.shouldShowRestartPrompt = true`. This co-locates the trigger with the store that caused it, mirroring `SettingsStore.cloudSyncEnabled` pattern (the flag lives in the store, not in the view).

> **Soft-cap nudge (CLAUDE.md §8.5 + Discretion #2):** RootTabView is currently 57 lines. After P6 it grows by ~30 lines (`@Environment(\.scenePhase)` + `@Environment(\.authStore)` + `@State` + `.onChange` + `.alert`). Stays well under 200 — no extraction needed. Discretion #2 says "extract if RootTabView grows past ~200 lines"; we don't.

---

### 10. `gamekit/gamekit/Screens/SettingsView.swift` (MODIFIED — new SYNC section)

**Primary analog:** SELF §audioSection (lines 161-185) for section structure + §dataSection (lines 187-224) for multi-row layout + file-private rows at lines 348-407.

#### Section header + DKCard wrapper — copy `audioSection` lines 165-185 layout verbatim

```swift
@ViewBuilder
private var syncSection: some View {
    // P6 (D-09): SYNC section between AUDIO and DATA.
    // Section order locks to APPEARANCE → AUDIO → SYNC → DATA → ABOUT.
    settingsSectionHeader(theme: theme, String(localized: "SYNC"))
    DKCard(theme: theme) {
        VStack(spacing: 0) {
            // Row 1: SignInWithAppleButton OR static "Signed in" row (D-10)
            signInRow

            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)

            // Row 2: sync-status row reading observer.status (D-10)
            syncStatusRow
        }
    }
}
```

> **Verbatim section discipline:** matches `audioSection` (lines 167-184) — `DKCard { VStack(spacing: 0) { row + 1pt Rectangle border + row } }`. The 1pt theme.colors.border divider is the project's row-separator idiom (see also `dataSection` lines 200-201, `aboutSection` lines 247-249).

#### Section insertion — `body` line 78-79

```swift
// Existing in body (SettingsView.swift:75-81):
appearanceSection
audioSection
// P6 — INSERT here:
syncSection
// Existing:
dataSection
aboutSection
```

#### Row 1 (sign-in row) — file-private `SettingsAuthRow` modeled on `SettingsToggleRow` (lines 386-407)

```swift
@ViewBuilder
private var signInRow: some View {
    if authStore.currentUserID == nil {
        // SignInWithAppleButton inline. RESEARCH Code Example 4.
        // Mirror IntroFlowView lines 245-251 styling (.signIn, .frame(height: 44),
        // signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)).
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                request.requestedScopes = []  // SC2 verbatim
            },
            onCompletion: { result in
                handleSIWACompletion(result)  // see section 11 below for verbatim
            }
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 44)
        .padding(.horizontal, theme.spacing.s)
    } else {
        // Static "Signed in" row — mirror Version row layout
        // (SettingsView.swift:235-245).
        HStack(spacing: theme.spacing.s) {
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(String(localized: "Signed in to iCloud"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
        }
        .frame(minHeight: 44)
    }
}
```

> **No file-private `SettingsAuthRow` struct needed** — the conditional is short enough to inline as a `@ViewBuilder`. If the row grows (future polish: Apple-ID suffix, etc.), promote per CLAUDE.md §8.1.

#### Row 2 (sync-status row) — file-private layout modeled on `aboutSection` Version row (lines 235-245)

```swift
@ViewBuilder
private var syncStatusRow: some View {
    HStack(spacing: theme.spacing.s) {
        Image(systemName: "arrow.triangle.2.circlepath")
            .foregroundStyle(theme.colors.textTertiary)
        // TimelineView wrap per CONTEXT D-12 + Specifics line 206
        // so the relative-time string ticks once per minute without
        // observer churn.
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Text(cloudSyncStatusObserver.status.label)
                .font(theme.typography.body)
                .foregroundStyle(textColor(for: cloudSyncStatusObserver.status))
        }
        Spacer()
    }
    .frame(minHeight: 44)
}

// Color helper — secondary for inactive states, accentPrimary for syncing,
// danger token for unavailable (mirror "Reset stats" glyphTint
// SettingsView.swift:218 — theme.colors.danger).
private func textColor(for status: SyncStatus) -> Color {
    switch status {
    case .syncing:           return theme.colors.accentPrimary
    case .syncedAt:          return theme.colors.textSecondary
    case .notSignedIn:       return theme.colors.textSecondary
    case .unavailable:       return theme.colors.danger
    }
}
```

> **`@Environment` injection — add to `SettingsView` near line 64:**
> ```swift
> @Environment(\.authStore) private var authStore
> @Environment(\.cloudSyncStatusObserver) private var cloudSyncStatusObserver
> ```
> Mirrors existing `@Environment(\.settingsStore)` line 64.

> **CLAUDE.md §8.1 cap:** SettingsView.swift is currently 411 lines (over the soft cap). P6 adds ~50 lines (`syncSection` + `signInRow` + `syncStatusRow` + `handleSIWACompletion` + `textColor`). Planner SHOULD extract — recommend moving the SYNC section into `Screens/SettingsSyncSection.swift` as a file-private `struct SyncSection: View` (params: theme, authStore, observer, onSignInSuccess closure). Mirrors `AcknowledgmentsView.swift` extraction precedent (SettingsView.swift:409-410 comment).

---

### 11. `gamekit/gamekit/Screens/IntroFlowView.swift` (MODIFIED — replace no-op)

**Primary analog:** SELF (line 124 — `signInTapped` no-op) + RESEARCH Code Example 4 lines 480-511.

#### Existing `signInTapped` line 124-126 — REPLACE the body

Before:
```swift
private func signInTapped() {
    Self.logger.info("SIWA tapped during intro (P6 wires actual auth via PERSIST-04 — D-21)")
}
```

After (no-op preserved as the ONREQUEST closure body — onTap pre-flight; the actual handler moves to `onCompletion`):

```swift
// onRequest hook — set scopes per SC2.
private func handleSIWARequest(_ request: ASAuthorizationAppleIDRequest) {
    request.requestedScopes = []   // SC2 verbatim
    Self.logger.info("SIWA request initiated from intro Step 3")
}

// onCompletion hook — RESEARCH Code Example 4 lines 484-511.
private func handleSIWACompletion(_ result: Result<ASAuthorization, Error>) {
    Task { @MainActor in
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential else {
                Self.logger.error("SIWA returned non-Apple-ID credential")
                return
            }
            do {
                try authStore.signIn(userID: credential.user)
                settingsStore.cloudSyncEnabled = true       // D-02
                authStore.shouldShowRestartPrompt = true    // D-03
                dismissIntro()                              // existing helper line 116
            } catch {
                Self.logger.error(
                    "SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        case .failure(let error):
            // Pitfall 5 + PERSIST-05 "never nag": silent UI on every error code.
            // Log via os.Logger only.
            Self.logger.error(
                "SIWA failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
```

> **Add `@Environment(\.authStore)` to `IntroFlowView`** (currently has only settingsStore on line 38). Mirror line 38 layout.

#### Existing `SignInWithAppleButton` lines 245-251 — REWIRE `onRequest` and `onCompletion`

Before:
```swift
SignInWithAppleButton(
    .signIn,
    onRequest: { _ in onSignIn() },
    onCompletion: { _ in
        // P6 PERSIST-04 wires this — no-op in P5 (D-21).
    }
)
```

After (new closures passed down via `IntroStep3SignInView`):
```swift
SignInWithAppleButton(
    .signIn,
    onRequest: onSIWARequest,           // closure prop
    onCompletion: onSIWACompletion       // closure prop
)
```

`IntroStep3SignInView` gains two new closure properties replacing `onSignIn`. The view's signature becomes:
```swift
private struct IntroStep3SignInView: View {
    let theme: Theme
    let colorScheme: ColorScheme
    let onSkip: () -> Void
    let onSIWARequest: (ASAuthorizationAppleIDRequest) -> Void   // NEW
    let onSIWACompletion: (Result<ASAuthorization, Error>) -> Void  // NEW
    // ...
}
```

`IntroFlowView.body` (line 53-65) updates the call site to pass `handleSIWARequest` and `handleSIWACompletion`.

> **Style preservation (line 252):** keep `.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)` and `.frame(height: 44)` verbatim — these are HIG-locked per UI-SPEC line 253.

---

### 12. `gamekit/gamekit/Resources/Localizable.xcstrings` (MODIFIED — auto-extracted)

**Primary analog:** SELF (Xcode auto-extracts `String(localized: "...")` literals at build time).

P6 adds these strings via `String(localized: ...)` call sites:
- `"Restart to enable iCloud sync"` (alert title — D-04)
- `"Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."` (alert body — D-04)
- `"Cancel"` (alert cancel — already exists, used in SettingsView.swift:106)
- `"Quit GameKit"` (alert default — D-04)
- `"SYNC"` (section header — D-09)
- `"Signed in to iCloud"` (signed-in row — Specifics line 200)
- `"Not signed in"` (status — D-10)
- `"Syncing…"` (status — D-10)
- `"Synced just now"` (status — D-10)
- `"Synced \(relative)"` (status — D-10) — String interpolation; xcstrings handles via `%@` placeholder
- `"iCloud unavailable"` (status — D-10)
- `"Last synced \(relative)"` (status sub-line — D-10)

> **No manual edits required.** Xcode 16's String Catalog auto-discovery scans on build. Verify by running a clean build and checking the catalog UI. Plan should include "verify all 12 P6 strings appear in Localizable.xcstrings post-build" as a checklist item.

---

### 13. `gamekit/gamekit/gamekit.entitlements` (MODIFIED — verify only)

**Current state (verified):**
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

**P6 verification (per RESEARCH lines 142-177):**

The SIWA entitlement is already present from P5 D-21. The iCloud + CloudKit container + remote-notification background mode entries declared as "pinned at P1" are NOT in this file — they likely live in `project.pbxproj` or are toggled via Xcode's Signing & Capabilities pane.

**Action items for the planner (Wave-0 verification task):**
1. Open the `gamekit` target → Signing & Capabilities pane.
2. Verify "iCloud" capability is checked with "CloudKit" service + container `iCloud.com.lauterstar.gamekit`.
3. Verify "Background Modes" is checked with "Remote notifications" subitem.
4. Verify "Sign in with Apple" capability is present.
5. **Do NOT hand-edit `project.pbxproj`** (CLAUDE.md §8.8) — toggle in Xcode UI; Xcode writes the file correctly.

If any of items 2–4 are missing, this becomes a real edit to `gamekit.entitlements` AND `project.pbxproj` toggled via Xcode. Surface as a P6 Wave-0 BLOCKER if missing.

---

## Shared Patterns

### S1. EnvironmentKey injection for `@Observable @MainActor` types

**Source:** `gamekit/gamekit/Core/SettingsStore.swift` lines 124-135 (P4 D-29 origin)
**Apply to:** `AuthStore`, `CloudSyncStatusObserver` (and any future Core/ singleton)

```swift
// VERBATIM template — replace TYPE/keyName per file:
private struct TYPEKey: EnvironmentKey {
    @MainActor static let defaultValue = TYPE()
}

extension EnvironmentValues {
    var keyName: TYPE {
        get { self[TYPEKey.self] }
        set { self[TYPEKey.self] = newValue }
    }
}
```

> **Why this not `@EnvironmentObject`:** `@EnvironmentObject` requires `ObservableObject` (legacy Combine protocol) and is INCOMPATIBLE with `@Observable` (iOS 17 macro). `@EnvironmentObject` is reserved for `ThemeManager` (DesignKit legacy). All P4+ project state goes through custom `EnvironmentKey`. See SettingsStore.swift comments lines 18-21 for the project rationale.

### S2. `os.Logger` non-fatal failure logging

**Source:** `gamekit/gamekit/Core/Haptics.swift` lines 71-98 + `gamekit/gamekit/Core/GameStats.swift` lines 47-50, 91-93
**Apply to:** `AuthStore` (category: `"auth"`), `CloudSyncStatusObserver` (category: `"cloudkit"`), all SIWA error paths in IntroFlowView + SettingsView

```swift
// CONSTRUCTION (mirror Haptics.swift:54-57 / SFXPlayer.swift:69-72):
private let logger = Logger(
    subsystem: "com.lauterstar.gamekit",
    category: "auth"   // or "cloudkit" — PER FILE; see CONTEXT line 203
)

// USAGE (mirror Haptics.swift:91-97 / GameStats.swift:91-93):
logger.error(
    "SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)"
)
```

> **Privacy posture (RESEARCH Anti-Patterns lines 693-694):** Apple userID NEVER appears in logs. `error.localizedDescription` from `KeychainError.writeFailed(status:)` is safe (only contains an OSStatus code). Apple userID would be in user code only — explicit guard: never `logger.info("signed in as \(userID)")` even with `.private` interpolation. Log outcomes only.

### S3. `@Suite("Name") struct` with `@MainActor` for Swift Testing

**Source:** `gamekit/gamekitTests/Core/HapticsTests.swift` lines 34-36 + `SFXPlayerTests.swift` lines 41-43 + `SettingsStoreFlagsTests.swift` lines 27-29
**Apply to:** `AuthStoreTests`, `CloudSyncStatusObserverTests`

```swift
import Testing
@testable import gamekit

@MainActor
@Suite("AuthStore")        // or "CloudSyncStatusObserver"
struct AuthStoreTests {

    @Test("description that names what it proves")
    func methodName_describesAssertion() {
        // Arrange — fresh dependencies (per-test isolation, mirror
        // SettingsStoreFlagsTests:36-39 makeIsolatedDefaults pattern).
        let backend = InMemoryKeychainBackend()
        let store = AuthStore(backend: backend)

        // Act
        try? store.signIn(userID: "fake.id")

        // Assert
        #expect(store.currentUserID == "fake.id")
    }
}
```

### S4. Per-test isolation via dependency-injected fresh state

**Source:** `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` lines 36-39 + `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` (entire file)
**Apply to:** `AuthStoreTests` (fresh `InMemoryKeychainBackend()` per `@Test`), `CloudSyncStatusObserverTests` (fresh observer per `@Test`)

```swift
// Pattern (SettingsStoreFlagsTests.swift:36-39 verbatim):
static func makeIsolatedBackend() -> InMemoryKeychainBackend {
    return InMemoryKeychainBackend()
}

@Test("...")
func ...() {
    let backend = Self.makeIsolatedBackend()
    let store = AuthStore(backend: backend)
    // Each @Test gets a new backend — no shared state. Swift Testing
    // runs @Tests in parallel by default; this is mandatory for correctness.
}
```

### S5. `#if DEBUG` test seam for visibility into private state

**Source:** `gamekit/gamekit/Core/SFXPlayer.swift` lines 152-170 + `gamekit/gamekit/Core/Haptics.swift` lines 113-126
**Apply to:** `AuthStore` (revocation observer count seam) + `CloudSyncStatusObserver` (`applyEvent_forTesting` seam)

```swift
// Pattern (SFXPlayer.swift:154-169 verbatim shape):
#if DEBUG
internal func resetForTesting() {
    // clear observer/state for per-test isolation
}

internal var hasRegisteredObserverForTesting: Bool {
    // expose private state to @testable import gamekit
}

internal func applyEvent_forTesting(
    type: NSPersistentCloudKitContainer.EventType,
    endDate: Date?,
    succeeded: Bool,
    error: Error?
) {
    // direct translator entry — bypass NotificationCenter because
    // NSPersistentCloudKitContainer.Event has no public initializer.
}
#endif
```

> **Critical placement:** `#if DEBUG` ONLY. Production code calling `resetForTesting` would silently break the gating contract. Visibility is `internal` (not `private`) so `@testable import gamekit` reaches it; production code in the app target sees nothing because `#if DEBUG` excludes the symbols from release builds.

### S6. File-private row components (Settings rows)

**Source:** `gamekit/gamekit/Screens/SettingsView.swift` lines 348-407 (`SettingsActionRow` + `SettingsToggleRow`)
**Apply to:** Any new SYNC row variants that emerge during P6 implementation. For now, the SYNC section uses inline `@ViewBuilder var signInRow` + `@ViewBuilder var syncStatusRow` (no file-private struct needed).

```swift
// IF a 3rd row variant emerges, mirror SettingsView.swift:348-370 layout:
private struct SettingsAuthRow: View {
    let theme: Theme
    let glyph: String
    let label: String
    // ... no `let action: () -> Void` because the SIWA button owns its own tap

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            Image(systemName: glyph)
                .foregroundStyle(theme.colors.textPrimary)
            Text(label)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
        }
        .frame(minHeight: 44)               // HIG min target — UI-SPEC §Spacing
        .contentShape(Rectangle())
    }
}
```

### S7. Alert at root scope with `.cancel` + default Button shape

**Source:** `gamekit/gamekit/Screens/SettingsView.swift` lines 102-117 (Reset alert) + lines 118-125 (Import error alert)
**Apply to:** Restart prompt alert in `RootTabView` (D-01..D-06)

```swift
// VERBATIM shape — copy SettingsView.swift:102-117 layout:
.alert(
    String(localized: "TITLE"),
    isPresented: $boolFlag
) {
    Button(String(localized: "Cancel"), role: .cancel) {}
    Button(String(localized: "PRIMARY")) {
        // action — for P6 Restart prompt: NO action body (D-05 dismiss-only)
    }
} message: {
    Text(String(localized: "BODY"))
}
```

> **Difference for P6:** Reset uses `role: .destructive` (red); Restart uses **default role** (blue) per D-01 + D-05. Quitting is non-destructive — default role is the correct semantic.

### S8. Single dismissal helper for multi-trigger flows

**Source:** `gamekit/gamekit/Screens/IntroFlowView.swift` lines 116-119 (`dismissIntro()` — single source of truth used by Skip + Done)
**Apply to:** Any future P6 helper for shared "SIWA success" code path between Settings + Intro Step 3

```swift
// IntroFlowView.swift:116-119 — single source of truth precedent.
// P6 Settings + Intro Step 3 SIWA-success path is the same shape — both
// call AuthStore.signIn → flip cloudSyncEnabled → flip shouldShowRestartPrompt.
// Recommend extracting to AuthStore.handleSIWASuccess(credential:settingsStore:)
// for a single source of truth. Both call sites then become 1-liner closures.
```

---

## No Analog Found

Files with no close in-repo match (planner falls back to RESEARCH.md synthetic snippets):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Core/AuthStore.swift` async wrapper around `getCredentialState` (RESEARCH Pattern 2) | service helper | request-response | No callback→async bridge exists in the repo yet. Use RESEARCH §Pattern 2 lines 358-377 verbatim — `withCheckedContinuation` is the Apple-blessed pattern. |
| `Core/CloudSyncStatusObserver.swift` event translator (RESEARCH Pattern 5) | service | event-driven | No NotificationCenter observer exists in the repo yet. Use RESEARCH §Pattern 5 lines 540-613 verbatim. |
| `Core/AuthStore.swift` `CredentialStateProvider` test stub | test seam | request-response | No abstraction over `ASAuthorizationAppleIDProvider` exists yet. Mirror `KeychainBackend` protocol shape (RESEARCH §Pattern 3) — same `protocol + Sendable + Stub` idiom. |

For these three surfaces, the planner cites `06-RESEARCH.md` directly. The remaining 10 files (above) all have strong in-repo analogs.

---

## Metadata

**Analog search scope:**
- `gamekit/gamekit/Core/` (12 files — services, models, exporters)
- `gamekit/gamekit/Screens/` (9 files — views, shells)
- `gamekit/gamekit/App/` (1 file — entry)
- `gamekit/gamekitTests/Core/` (6 files — Swift Testing suites)
- `gamekit/gamekitTests/Helpers/` (3 files — test factories)
- `gamekit/gamekit/gamekit.entitlements` (1 file — verified state)

**Files scanned:** 32 (via `Read` + directory listings)
**Strong matches found:** 13 / 13 (100%)
**Pattern extraction date:** 2026-04-26
