# Phase 6: CloudKit + Sign in with Apple - Research

**Researched:** 2026-04-26
**Domain:** iOS auth + CloudKit-mirrored SwiftData (AuthenticationServices, NSPersistentCloudKitContainer, Security framework Keychain) under Swift 6 strict concurrency
**Confidence:** HIGH on framework APIs (verified against Apple docs + recent ecosystem articles); HIGH on locked-decision compatibility (CONTEXT.md decisions all consistent with Apple-supported patterns); MEDIUM on cold-start latency benchmarks (no formal Apple SLA exists — empirical only)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Restart prompt UX (D-01..D-06):**
- D-01: iOS `.alert` (not themed sheet, not `.fullScreenCover`). Title `"Restart to enable iCloud sync"`. Two buttons: `"Cancel"` (`.cancel` role) + `"Quit GameKit"` (default role).
- D-02: `cloudSyncEnabled` flips `true` on SIWA success **before** the prompt shows (UX hint, not consent gate). If user dismisses, next cold-start picks up the flag and reconfigures `ModelConfiguration` with `.private(...)`.
- D-03: Prompt fires from BOTH SIWA success sites (Settings sign-in tap AND IntroFlow Step 3 onCompletion). Single source of truth: `@State var showRestartPrompt: Bool` at root level.
- D-04: Body copy: `"Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."`
- D-05: "Quit GameKit" button is **dismiss-only** — NO `exit(0)` / `UIApplication.shared.suspend()` (App Store Review red flag). Both buttons dismiss.
- D-06: No re-prompt logic, no dedup flag.

**Container reconfiguration (D-07..D-08):**
- D-07: **Launch-only reconfig** via Restart prompt. P6 does NOT introduce live `ModelContainer` reconfiguration. Hot-swap path explicitly deferred.
- D-08: Same store path in both modes. Flipping `cloudKitDatabase: .none` → `.private("iCloud.com.lauterstar.gamekit")` on next launch reuses the same SQLite file. CloudKit sees existing local rows and pushes them up.

**Settings SYNC section (D-09..D-12):**
- D-09: Section order locks to APPEARANCE → AUDIO → **SYNC** → DATA → ABOUT.
- D-10: 2 rows. Row 1 = sign-in row (SignInWithAppleButton when signed-out; static "Signed in to iCloud" when signed-in; **NO sign-out button** — system-only). Row 2 = sync-status row (4 states: `.notSignedIn` / `.syncing` / `.syncedAt(date)` / `.unavailable(lastSynced)`).
- D-11: `CloudSyncStatusObserver` constructed in `GameKitApp.init()` after `SettingsStore` and `AuthStore`, injected via custom `EnvironmentKey` (mirrors P4 D-29 pattern + P5 D-12 SFXPlayer pattern).
- D-12: Observer updates `@Observable` published `status` immediately on every notification. Relative-time label wrapped in `TimelineView(.periodic(from: .now, by: 60))` so "Synced X ago" ticks once per minute without observer churn.

**Credential lifecycle (D-13..D-16):**
- D-13: AuthStore registers `credentialRevokedNotification` observer in `init`. On notification fire: clear Keychain userID, set `cloudSyncEnabled=false`, log via `os.Logger`. **NO alert** — sign-in card silently returns to SYNC section per "never nag" PERSIST-05.
- D-14: Scene-active validation — `GameKitApp` observes `scenePhase` and on `.active` calls `AuthStore.validateOnSceneActive()`. Method calls `getCredentialState(forUserID:)` for any stored userID; `.revoked` / `.notFound` → clear-state. `.transferred` → treat as `.notFound` (defensive default).
- D-15: Reinstall path — fresh install has empty Keychain. First scene-active: no stored userID → no `getCredentialState` call → SYNC section shows the SIWA button. CloudKit-mirrored data already in iCloud waits for first cold-start with `cloudSyncEnabled=true`.
- D-16: Keychain wrapper isolation — nested `protocol KeychainBackend` defines `read/write/delete(account:)`. Two implementations: `SystemKeychainBackend` (production) and `InMemoryKeychainBackend` (tests). DI matches P4 `InMemoryStatsContainer` pattern.

**Test matrix (D-17..D-18):**
- D-17: Swift Testing automated for `AuthStoreTests` (backend round-trip + revocation handler + scene-active stub) and `CloudSyncStatusObserverTests` (synthetic eventChangedNotification posts → status state machine + relative-time label format).
- D-18: Manual SC1-SC5 verification checkpoint in `06-VERIFICATION.md` — feature-parity sweep, SIWA flow + Keychain, two-simulator promotion test (50 games), 4-state row, cold-start <1s Instruments measurement.

**Locked from upstream:**
- SC2: SIWA `request.requestedScopes = []` — verbatim. NO email, NO fullName.
- SC2: Keychain attributes verbatim: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecClass = kSecClassGenericPassword`, `kSecAttrService = "com.lauterstar.gamekit.auth"`, `kSecAttrAccount = "appleUserID"`.
- CloudKit container ID `iCloud.com.lauterstar.gamekit` — pinned at P1, locked through P7.
- `os.Logger` subsystem `"com.lauterstar.gamekit"`, category `"auth"` for AuthStore, `"cloudkit"` for CloudSyncStatusObserver.

### Claude's Discretion

- "Apple ID: ****1234" suffix in signed-in row — recommend NO suffix (just "Signed in to iCloud").
- `RestartPromptModifier` location — root level (RootTabView vs dedicated `RestartPromptModifier: ViewModifier`). Either acceptable. Extract if RootTabView grows past ~200 lines.
- `SyncStatus` enum location — alongside the observer (`Core/CloudSyncStatusObserver.swift`) or sibling (`Core/SyncStatus.swift`). Recommend alongside for v1.
- `TimelineView(.periodic(...))` wrap of relative-time label — D-12 recommends; planner may use a single global `Timer.publish` if multiple status labels appear. Premature for v1.
- `validateOnSceneActive` `async` — recommend `async`, called from a Task in scenePhase observer.
- Schema deploy timing — P6 plan must call out "Schema deployed to Development before SC3 manual run" as a checklist item. Production promotion is P7.
- Reset Stats interaction with cloudSyncEnabled — Reset (P4 D-13) deletes local rows; CloudKit mirroring then propagates. No new code.

### Deferred Ideas (OUT OF SCOPE)

- Live `ModelContainer` hot-swap on `cloudSyncEnabled` change — MEDIUM-confidence path; deferred to v1.x polish.
- In-app sign-out button — system-only per ARCHITECTURE §line 423.
- Apple-ID suffix display — defer to a polish phase if ever wanted.
- CloudKit Dashboard Production schema promotion — P7 release-checklist item.
- Privacy nutrition label sign-off — P7.
- TestFlight verification of SIWA in Production — P7.
- Sync conflict resolution UI — CloudKit handles last-writer-wins; defer until edge cases occur.
- `@ModelActor` for sync writes — PROJECT.md out-of-scope.
- `CKSyncEngine` — PROJECT.md out-of-scope.
- Sign-in with Google / passkeys / WebAuthn — PROJECT.md "Apple-native only" lock; never.
- Sign-out triggered by user toggling `cloudSyncEnabled` off in app — sign-out IS the disable mechanism, system-level only.
- Sync-status row pulse animation on `.syncing` — visual polish; planner discretion.
- Two-Apple-ID-on-same-device handling — Apple treats as user error.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **PERSIST-04** | Optional Sign in with Apple + CloudKit private DB for cross-device persistence; full feature parity without sign-in. | §3 SIWA flow, §4 ModelContainer reconfig (D-07/D-08 launch-only), §6 Test Matrix SC1 feature-parity sweep, Standard Stack `AuthenticationServices` + `Security` + `NSPersistentCloudKitContainer`. |
| **PERSIST-05** | Sign-in surfaced once in 3-step intro and again in Settings; never gates gameplay; never nags. | §5 Settings SYNC section design (D-09/D-10 — sign-in card + status row, no in-app sign-out), §7 Pitfall 5 (silent revocation = no alert), CONTEXT D-13 verbatim "NO alert per never-nag PERSIST-05". |
| **PERSIST-06** | Anonymous local profile created on first launch; signing in promotes local data to cloud (no data loss); sync-status row reports 4 states. | §4 Same-store-path promotion (D-08 + Pitfall 4), §5 4-state SyncStatus enum + eventChangedNotification observer, §6 SC3 two-simulator manual test, §3 Code Example 4 sign-in completion handler writing Keychain + flipping flag + showing prompt. |

</phase_requirements>

## Summary

Phase 6 wires three Apple frameworks together — `AuthenticationServices` (SIWA), `Security` (Keychain), and `CoreData.NSPersistentCloudKitContainer` (sync events) — into the existing P4 `ModelContainer` + P5 SettingsStore/IntroFlow scaffolding. The phase is **constrained tightly** by CONTEXT decisions: the launch-only Restart-prompt path (D-07) eliminates the riskiest moving part (live container teardown/recreate), the same-store-path invariant (D-08) eliminates the data-loss class entirely (Pitfall 4), and the system-level-only sign-out posture (D-10 + ARCHITECTURE §line 423) eliminates the in-app sign-out lifecycle.

The remaining technical surface is mechanical: a Keychain wrapper with verbatim attributes (SC2-locked), a SIWA `onCompletion` handler that extracts `userID` from `ASAuthorizationAppleIDCredential`, a credential-revocation observer + scene-active `getCredentialState` validator, and an `eventChangedNotification` translator producing a 4-state `SyncStatus` enum. The hardest part is not the code — it's the manual two-simulator promotion test (SC3) which requires a real iCloud account and CloudKit Dashboard Development schema deployment as a one-shot dev step before testing.

**Primary recommendation:** Implement AuthStore + CloudSyncStatusObserver as `@Observable @MainActor final class` types injected via custom `EnvironmentKey` (mirroring P4 D-29 SettingsStore pattern). Use `protocol KeychainBackend` for testability. Wrap `getCredentialState(forUserID:)` callback API in `withCheckedContinuation` for an `async` surface. Run `try await container.initializeCloudKitSchema()` ONCE in a `#if DEBUG` block bridging to Core Data (SwiftData lacks the API directly) before the SC3 two-simulator manual test. Manual verification gates SC1, SC3, SC5 — automated tests cannot reach real iCloud.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SIWA button render + tap | App / Screens (SwiftUI view) | — | `SignInWithAppleButton` is a first-party SwiftUI control consumed at IntroFlowView Step 3 + SettingsView SYNC section. |
| Apple userID Keychain persistence | Core / AuthStore | Security framework | `AuthStore.signIn(credential:)` writes via `KeychainBackend` protocol; `SystemKeychainBackend` calls `SecItemAdd/CopyMatching/Delete`. |
| Credential revocation lifecycle | Core / AuthStore | AuthenticationServices | AuthStore registers `credentialRevokedNotification` observer in `init` + exposes `validateOnSceneActive() async` calling `getCredentialState`. |
| Sync event observation | Core / CloudSyncStatusObserver | CoreData (`NSPersistentCloudKitContainer.eventChangedNotification`) | SwiftData lacks a sync-status API; the underlying Core Data layer fires the notification for SwiftData stores too. |
| Sync status enum (`SyncStatus`) | Core (alongside observer) | — | Pure value type; consumed by SettingsView SYNC row. |
| ModelContainer reconfiguration | App / GameKitApp.init | SwiftData (`ModelConfiguration.cloudKitDatabase`) | Existing P4 pattern preserved verbatim; reads `SettingsStore.cloudSyncEnabled` ONCE at construction. |
| Restart prompt UX | App / RootTabView (or root-level modifier) | — | `@State var showRestartPrompt` lives at root scope; `.alert` modifier surfaces from either Settings or IntroFlow trigger. |
| `cloudSyncEnabled` flag write | Core / SettingsStore (existing P4 surface) | UserDefaults | Already shipped in P4 — P6 only triggers a write at SIWA-success site. |
| Settings SYNC section UI | Screens / SettingsView | — | New `private var syncSection: some View` between AUDIO and DATA per D-09. |
| Schema deployment to CloudKit Dashboard | Manual ops (one-shot dev step) | Core Data bridge (`initializeCloudKitSchema`) | SwiftData has no direct API; must bridge to `NSPersistentCloudKitContainer` for schema upload. P7 owns Production promotion. |

## Standard Stack

### Core (all already present in project — P6 adds usage, not deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `AuthenticationServices` | iOS 17+ baseline | `SignInWithAppleButton`, `ASAuthorizationAppleIDProvider`, `ASAuthorizationAppleIDCredential`, `credentialRevokedNotification`, `getCredentialState(forUserID:)` | First-party SwiftUI control + lifecycle APIs. No alternative for "Sign in with Apple" — App Store Review Guideline 4.8 mandates SIWA when any third-party sign-in is offered. [VERIFIED: STACK.md §3] |
| `Security` (Keychain Services) | iOS 17+ baseline | `SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrService`, `kSecAttrAccount` | Mandatory storage for Apple userID per Pitfall 5 + SC2 verbatim lock. UserDefaults is unsafe for credentials. [CITED: developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly] |
| `CoreData` (`NSPersistentCloudKitContainer.eventChangedNotification` + `eventNotificationUserInfoKey`) | iOS 17+ baseline | Sync event observation. SwiftData uses NSPersistentCloudKitContainer under the hood and the notification fires regardless of whether app uses SwiftData or Core Data. | SwiftData lacks a native sync-status API; observing the underlying Core Data notification is the supported workaround. [CITED: azamsharp.com/2026/03/16/swiftdata-icloud-sync-status.html — "SwiftData does not provide any API that tells us when syncing begins or ends. However, the underlying Core Data stack sends notifications whenever a CloudKit sync event changes."] |
| `SwiftData` (`ModelContainer`, `ModelConfiguration.cloudKitDatabase`) | iOS 17+ baseline (P4 already shipped) | Container reconfig at launch when flag flips. `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` activates CloudKit mirroring. | P4 D-07/D-08 already shipped this scaffolding — P6 only flips the flag at SIWA-success. |
| `SwiftUI` (`.alert`, `@Environment(\.scenePhase)`, `Bindable`, `EnvironmentKey`, `TimelineView`) | iOS 17+ baseline | Restart prompt, scenePhase observer, observable bindings, custom env keys, periodic relative-time label tick. | All standard iOS 17 SwiftUI surface. |
| `os.Logger` | iOS 17+ baseline | `subsystem: "com.lauterstar.gamekit"`, `category: "auth"` (AuthStore) / `"cloudkit"` (observer). Privacy-aware logging via `.private` modifiers around userID. | Already used by P4 (`category: "persistence"`) and P5 (`category: "haptics"`, `"settings"`); locked precedent. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Swift Testing` | Xcode 16+ bundled | `@Test`, `#expect`, `@Suite` for AuthStoreTests + CloudSyncStatusObserverTests | All P6 automated tests. Matches P2/P3/P4/P5 convention. |
| `Foundation.NotificationCenter` | iOS 17+ baseline | Observe `credentialRevokedNotification` + post synthetic `eventChangedNotification` in tests | Standard observer pattern. Swift 6.2 introduces `NotificationCenter.MainActorMessage` but iOS 17 baseline does not require it; classic `addObserver` works fine inside a `@MainActor` class. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSPersistentCloudKitContainer.eventChangedNotification` | `CKSyncEngine` events | `CKSyncEngine` is a fully separate sync stack — does NOT coexist with SwiftData/`NSPersistentCloudKitContainer` on the same store. PROJECT.md out-of-scope; locked. [CITED: developer.apple.com/forums/thread/731435] |
| `protocol KeychainBackend` + 2 impls | Direct `SecItem*` calls in AuthStore | Locked by D-16 — needed for `gamekitTests` to run without real Keychain access (host-app entitlement issue). Mirrors P4 `InMemoryStatsContainer` pattern. |
| `withCheckedContinuation` wrapping `getCredentialState` | Direct callback closure | Continuation gives a clean `async` surface for the scene-phase observer Task. Both work; async is cleaner under Swift 6 strict concurrency (Discretion #6). |
| Hot-swap `ModelContainer` on flag change | Launch-only restart | MEDIUM confidence on hot-swap; HIGH confidence on launch-only. CONTEXT D-07 LOCKS launch-only. Do not research the teardown sequence. |
| `request.requestedScopes = [.email, .fullName]` | `requestedScopes = []` | `[]` locked by SC2 verbatim. Even when scopes are requested, name/email arrive only on FIRST sign-in per device per Apple ID — subsequent sign-ins return userID only. PROJECT.md "no analytics, no PII" posture mandates `[]`. [VERIFIED: WebSearch — "User info is only sent in the ASAuthorizationAppleIDCredential upon initial user sign up. Subsequent logins with the same account do not share any user info and will only return a user identifier."] |

**Installation:**

No new dependencies. P6 ships entirely against frameworks already importable at iOS 17+ baseline. Entitlements changes only:

```xml
<!-- gamekit/gamekit.entitlements (P6 additions to verify) -->
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
<!-- ALREADY PRESENT (P5 D-21 added in 05-05). Verify no drift. -->

<!-- iCloud + CloudKit container — declared in P1 per CONTEXT canonical refs.
     P6 verifies these are present (no new write needed if already there). -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.lauterstar.gamekit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>

<!-- Background Modes (Remote Notifications) — required so silent push wakes
     CloudKit subscriptions. Apple adds this automatically when iCloud + CloudKit
     are checked. STACK.md §2 + Pitfalls Pitfall 11. -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
<!-- ⚠️ This goes in Info.plist NOT entitlements. Verify in pbxproj. -->
```

**Version verification:** No package versions to verify — all stdlib. iOS 17 deployment target locked at P1 (FOUND-04).

**Existing entitlement state (verified):** `gamekit.entitlements` currently contains ONLY `com.apple.developer.applesignin = [Default]` from P5 (05-05). The iCloud + CloudKit + Background Modes entries declared in P1's PROJECT.md as "pinned" appear to live elsewhere (likely Info.plist or pbxproj). **Action item for planner:** Verify exact entitlement layout during a Wave-0 task by inspecting the gamekit target in Xcode's Signing & Capabilities — do NOT assume the file contents are complete. [VERIFIED: Read of /Users/gabrielnielsen/Desktop/GameKit/GameKit/gamekit/gamekit.entitlements showed only the SIWA Default entry.]

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  GameKitApp.init()  (cold start — single source of truth for construction)   │
│                                                                               │
│  1. SettingsStore()          ← reads cloudSyncEnabled from UserDefaults      │
│  2. SFXPlayer()               (P5 — preserved)                                │
│  3. ★ AuthStore(backend:)    ← NEW — registers credentialRevokedNotification │
│  4. ★ CloudSyncStatusObserver() ← NEW — registers eventChangedNotification   │
│  5. ModelContainer(...)       ← reads SettingsStore.cloudSyncEnabled ONCE    │
│         cloudKitDatabase: enabled ? .private("iCloud.com.lauterstar.gamekit")│
│                                  : .none                                      │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ inject via .environment(\.authStore, ...)
                               │             .environment(\.cloudSyncStatusObserver, ...)
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  RootTabView                                                                  │
│   .onChange(of: scenePhase) where == .active →                                │
│       Task { await authStore.validateOnSceneActive() }   ← D-14              │
│   ★ .alert(isPresented: $showRestartPrompt) { … }        ← D-01..D-06        │
│                                                                               │
│   ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────────────┐    │
│   │  HomeView    │  │  StatsView   │  │  SettingsView                   │    │
│   │              │  │              │  │  ★ SYNC section (D-09/D-10):    │    │
│   │              │  │              │  │     ★ SignInWithAppleButton     │    │
│   │              │  │              │  │       OR "Signed in to iCloud"  │    │
│   │              │  │              │  │     ★ status row reads          │    │
│   │              │  │              │  │       cloudSyncStatusObserver   │    │
│   │              │  │              │  │       .status (4 states)        │    │
│   └──────────────┘  └──────────────┘  └─────────────────────────────────┘    │
│                                                                               │
│   .fullScreenCover { IntroFlowView } when !hasSeenIntro (P5 — preserved)      │
│       └─ ★ Step 3 SignInWithAppleButton.onCompletion → real handler now      │
└─────────────────────────────────────────────────────────────────────────────┘
                               ▲
                               │ flips cloudSyncEnabled = true + showRestartPrompt = true
                               │
┌──────────────────────────────┴──────────────────────────────────────────────┐
│  AuthStore (★ NEW — Core/AuthStore.swift)                                     │
│   @Observable @MainActor final class                                          │
│   private let backend: KeychainBackend     ← protocol seam (D-16)            │
│   var currentUserID: String? { backend.read(account: "appleUserID") }        │
│                                                                               │
│   func signIn(credential: ASAuthorizationAppleIDCredential) throws {          │
│       backend.write(credential.user, account: "appleUserID")                  │
│       // caller flips cloudSyncEnabled = true and shows Restart prompt        │
│   }                                                                           │
│                                                                               │
│   func validateOnSceneActive() async {                                        │
│       guard let stored = currentUserID else { return }                        │
│       let state = await getCredentialStateAsync(forUserID: stored)            │
│       if state == .revoked || state == .notFound { clearLocalSignInState() } │
│   }                                                                           │
│                                                                               │
│   init: NotificationCenter.addObserver(                                       │
│     name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,       │
│     ... → clearLocalSignInState() (D-13))                                     │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  KeychainBackend protocol (★ NEW — Core/AuthStore.swift nested)               │
│   func read(account: String) -> String?                                       │
│   func write(_ value: String, account: String)                                │
│   func delete(account: String)                                                │
│                                                                               │
│   ┌──────────────────────────┐    ┌─────────────────────────────────┐        │
│   │ SystemKeychainBackend    │    │ InMemoryKeychainBackend         │        │
│   │ (production)             │    │ (gamekitTests/Helpers/)         │        │
│   │ - SecItemAdd             │    │ - in-memory dictionary           │       │
│   │ - SecItemCopyMatching    │    │ - mirrors P4 InMemoryStatsContainer       │
│   │ - SecItemDelete          │    │                                          │
│   │ - kSecAttrAccessible*    │    │                                          │
│   │   ThisDeviceOnly         │    │                                          │
│   └──────────────────────────┘    └─────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  CloudSyncStatusObserver (★ NEW — Core/CloudSyncStatusObserver.swift)         │
│   @Observable @MainActor final class                                          │
│   var status: SyncStatus = .notSignedIn   ← initial value depends on flag    │
│                                                                               │
│   init: NotificationCenter.addObserver(                                       │
│     name: NSPersistentCloudKitContainer.eventChangedNotification, ... )       │
│                                                                               │
│   on event: extract via                                                       │
│     notification.userInfo?[NSPersistentCloudKitContainer                      │
│         .eventNotificationUserInfoKey]                                        │
│       as? NSPersistentCloudKitContainer.Event                                 │
│   → translate event.type / event.endDate / event.error → SyncStatus           │
│                                                                               │
│   enum SyncStatus: Equatable {                                                │
│     case syncing                                                              │
│     case syncedAt(Date)                                                       │
│     case notSignedIn                                                          │
│     case unavailable(lastSynced: Date?)                                       │
│   }                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
gamekit/
├── App/
│   └── GameKitApp.swift                  ← edit: construct AuthStore +
│                                            CloudSyncStatusObserver +
│                                            scenePhase observer +
│                                            root .alert wiring
├── Core/
│   ├── AuthStore.swift                   ← NEW — Apple userID + Keychain +
│   │                                       revocation/scene-active lifecycle
│   ├── CloudSyncStatusObserver.swift     ← NEW — eventChangedNotification →
│   │                                       SyncStatus translator
│   ├── SyncStatus.swift                  ← optional sibling — discretion
│   ├── SettingsStore.swift               ← edit: NONE (cloudSyncEnabled
│   │                                       already shipped in P4)
│   ├── GameStats.swift                   ← preserved
│   ├── SFXPlayer.swift                   ← preserved
│   └── Haptics.swift                     ← preserved
├── Screens/
│   ├── SettingsView.swift                ← edit: insert SYNC section
│   │                                       between AUDIO and DATA
│   ├── IntroFlowView.swift               ← edit: replace signInTapped no-op
│   │                                       with real SIWA onCompletion
│   ├── RootTabView.swift                 ← edit: scenePhase observer + root
│   │                                       Restart .alert OR extract a
│   │                                       RestartPromptModifier
│   └── ...
├── Resources/
│   ├── Localizable.xcstrings             ← edit: auto-extracted P6 strings
│   └── ...
└── gamekitTests/
    ├── Core/
    │   ├── AuthStoreTests.swift          ← NEW
    │   └── CloudSyncStatusObserverTests.swift ← NEW
    └── Helpers/
        └── InMemoryKeychainBackend.swift ← NEW (mirrors InMemoryStatsContainer)
```

### Pattern 1: Custom EnvironmentKey for `@Observable @MainActor` types (P4 D-29 + P5 D-12 precedent)

**What:** P6 introduces TWO new app-level singletons (`AuthStore`, `CloudSyncStatusObserver`). Both follow the locked precedent: `@Observable @MainActor final class`, constructed in `GameKitApp.init()`, injected via custom `EnvironmentKey`.

**When to use:** ALWAYS for app-scope Observable types. `@EnvironmentObject` requires `ObservableObject` and is incompatible with `@Observable` — reserved for `ThemeManager` legacy.

**Example:**

```swift
// Source: gamekit/Core/SettingsStore.swift lines 124-135 (verbatim P4 pattern)

private struct AuthStoreKey: EnvironmentKey {
    @MainActor static let defaultValue: AuthStore = AuthStore()
}

extension EnvironmentValues {
    var authStore: AuthStore {
        get { self[AuthStoreKey.self] }
        set { self[AuthStoreKey.self] = newValue }
    }
}
```

### Pattern 2: Bridge callback API to `async` via `withCheckedContinuation` (Discretion #6)

**What:** `getCredentialState(forUserID:completion:)` is a callback-based API. Wrap in `withCheckedContinuation` to give scene-phase observer a clean `async` surface.

**When to use:** Inside `AuthStore.validateOnSceneActive() async`. Called from `Task { await authStore.validateOnSceneActive() }` in RootTabView's `.onChange(of: scenePhase)`.

**Example:**

```swift
// Source: hackingwithswift.com/quick-start/concurrency/how-to-use-continuations
// Adapted to ASAuthorizationAppleIDProvider per Apple AuthenticationServices docs.

@MainActor
private func getCredentialStateAsync(
    forUserID userID: String
) async -> ASAuthorizationAppleIDProvider.CredentialState {
    await withCheckedContinuation { continuation in
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
            // Apple's docs: completion fires on a background thread.
            // We resume on whatever thread Apple uses; the @MainActor caller
            // re-suspends to main. (Continuation.resume is thread-safe.)
            if error != nil {
                continuation.resume(returning: .notFound)  // defensive: treat
                                                            // any error as
                                                            // "no longer valid"
                return
            }
            continuation.resume(returning: state)
        }
    }
}
```

**Critical rule:** continuation must be resumed exactly once. The `if error != nil` early-return guards against the (rare) error path firing AFTER `state` has fired — defensive but Apple's documented behavior is one-or-the-other. [VERIFIED: hackingwithswift.com — "Your continuation must be resumed exactly once. Not zero times, and not twice or more times – exactly once."]

### Pattern 3: `protocol KeychainBackend` for testability (D-16 + P4 InMemoryStatsContainer mirror)

**What:** `AuthStore` does NOT call `SecItem*` APIs directly in its public methods. A nested `protocol KeychainBackend` defines `read/write/delete(account:)` and ships with two implementations.

**When to use:** Locked by D-16. Tests must run without real Keychain access (host-app entitlement issue + no real iCloud account).

**Example:**

```swift
// Source: NEW — modeled on gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift
// (P4 test helper pattern — protocol seam + production + in-memory pair)

protocol KeychainBackend: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String) throws
    func delete(account: String) throws
}

@MainActor
final class SystemKeychainBackend: KeychainBackend {
    static let serviceName = "com.lauterstar.gamekit.auth"

    func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func write(_ value: String, account: String) throws {
        // Idempotent: delete-then-add avoids errSecDuplicateItem.
        try? delete(account: account)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            // SC2 + Pitfall 5 verbatim:
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status: status)
        }
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

enum KeychainError: Error {
    case writeFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
}

// Test stub:
@MainActor
final class InMemoryKeychainBackend: KeychainBackend {
    private var store: [String: String] = [:]
    func read(account: String) -> String? { store[account] }
    func write(_ value: String, account: String) throws { store[account] = value }
    func delete(account: String) throws { store[account] = nil }
}
```

[CITED: developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly — "The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user. This is recommended for items that need to be accessible by background applications. Items with this attribute will never migrate to a new device."]

### Pattern 4: SIWA `onCompletion` handler — extract userID from `ASAuthorizationAppleIDCredential`

**What:** The `Result<ASAuthorization, Error>` returned to `onCompletion` carries the credential. Cast `authorization.credential` to `ASAuthorizationAppleIDCredential`, then read `credential.user` (the stable opaque Apple userID string). Email/fullName are nil because `requestedScopes = []` per SC2.

**When to use:** Both SIWA call sites — IntroFlowView Step 3 + SettingsView SYNC row.

**Example:**

```swift
// Source: createwithswift.com/sign-in-with-apple-on-a-swiftui-application/
// Adapted to AuthStore + CONTEXT D-02 (flip flag → show prompt).

SignInWithAppleButton(
    .signIn,
    onRequest: { request in
        request.requestedScopes = []  // SC2 verbatim — userID only
    },
    onCompletion: { result in
        Task { @MainActor in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential
                        as? ASAuthorizationAppleIDCredential else {
                    Self.logger.error("SIWA returned non-Apple-ID credential")
                    return
                }
                // credential.user = stable opaque Apple userID string.
                // credential.identityToken = JWT (one-shot, not stored).
                // credential.email / fullName = nil because requestedScopes = [].
                do {
                    try authStore.signIn(userID: credential.user)
                    settingsStore.cloudSyncEnabled = true   // D-02
                    showRestartPrompt = true                 // D-03
                } catch {
                    Self.logger.error(
                        "SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            case .failure(let error):
                handleSIWAFailure(error)
            }
        }
    }
)
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
.frame(height: 44)
```

**Error cases to handle:**

| `ASAuthorizationError.Code` | Meaning | Action |
|------------------------------|---------|--------|
| `.canceled` | User dismissed the SIWA system sheet | Silent — no alert (Pitfall 5 + PERSIST-05 "never nag") |
| `.failed` | Authorization request failed for unspecified reason | Log via os.Logger; silent UI |
| `.invalidResponse` | Authorization service received invalid response | Log; silent UI |
| `.notHandled` | Authorization request not handled (rare) | Log; silent UI |
| `.unknown` | An unknown error occurred | Log; silent UI |
| `.notInteractive` (iOS 15.4+) | Couldn't be presented (no key window) | Log; silent UI |

[VERIFIED: WebSearch + medium.com/macoclock/sign-in-with-apple-implementation-swift-607d2d92d494 — error code enumeration]

[CITED: developer.apple.com/documentation/authenticationservices/asauthorizationerror-swift.struct/code/canceled]

### Pattern 5: `eventChangedNotification` → `SyncStatus` translator

**What:** Observe `NSPersistentCloudKitContainer.eventChangedNotification`, extract the `Event` from `userInfo` via `NSPersistentCloudKitContainer.eventNotificationUserInfoKey`, translate `event.type` × `event.endDate` × `event.succeeded` → 4-state `SyncStatus`.

**When to use:** Inside `CloudSyncStatusObserver.init`. The notification fires regardless of whether app uses SwiftData or Core Data — SwiftData uses `NSPersistentCloudKitContainer` under the hood.

**Example:**

```swift
// Source: azamsharp.com/2026/03/16/swiftdata-icloud-sync-status.html
// + crunchybagel.com/nspersistentcloudkitcontainer/
// + developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/eventchangednotification
//
// The Event object carries:
//   - type: NSPersistentCloudKitContainer.EventType (.setup / .import / .export)
//   - endDate: Date?  (nil while in flight; set on completion)
//   - succeeded: Bool
//   - error: Error?
//   - identifier: UUID
//   - storeIdentifier: String

import CoreData

@Observable @MainActor
final class CloudSyncStatusObserver {
    enum SyncStatus: Equatable {
        case syncing
        case syncedAt(Date)
        case notSignedIn
        case unavailable(lastSynced: Date?)
    }

    private(set) var status: SyncStatus
    private var lastSyncDate: Date?
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "cloudkit"
    )

    init(initialStatus: SyncStatus = .notSignedIn) {
        self.status = initialStatus
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    @objc private func handleEvent(_ notification: Notification) {
        // userInfo key per Apple docs (verified):
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        // event.endDate == nil → in-flight; non-nil → completed
        if event.endDate == nil {
            status = .syncing
            return
        }

        // Completed event:
        if event.succeeded {
            lastSyncDate = event.endDate
            status = .syncedAt(event.endDate ?? Date())
        } else {
            // Error path — common cases:
            //   - quota exceeded
            //   - account temporarily unavailable
            //   - schema not deployed (dev path before initializeCloudKitSchema())
            //   - network unreachable
            // Pitfall 3 mitigation: surface as .unavailable, NOT silent failure.
            if let error = event.error {
                Self.logger.error(
                    "CloudKit \(String(describing: event.type), privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            status = .unavailable(lastSynced: lastSyncDate)
        }
    }
}
```

[CITED: azamsharp.com/2026/03/16/swiftdata-icloud-sync-status.html — "Use this key to extract the event object: notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event"]

[CITED: crunchybagel.com/nspersistentcloudkitcontainer/ — "The eventChangedNotification tells you the state of an individual export or import event, and not that the whole Core Data store is synchronized with the CloudKit server, because there may be new changes happening on the CloudKit server while the event is being handled."]

**4-state mapping (per CONTEXT D-10 + Pitfall 3):**

| `event.type` × `event.endDate` × `event.succeeded` | Status | UI label |
|------------------------------------------------|--------|----------|
| any × nil × — | `.syncing` | "Syncing…" |
| `.setup` / `.import` / `.export` × non-nil × `true` | `.syncedAt(endDate)` | `"Synced just now"` if `< 60s` else `"Synced X ago"` (RelativeDateTimeFormatter `.named`) |
| (no event ever fired) — initial state when `cloudSyncEnabled = false` | `.notSignedIn` | "Not signed in" |
| any × non-nil × `false` (error path) | `.unavailable(lastSynced:)` | "iCloud unavailable" + sub-line if `lastSynced != nil` |

**Initial value (CONTEXT specifics line 204):**

```swift
let initial: SyncStatus = settingsStore.cloudSyncEnabled ? .syncing : .notSignedIn
// CloudKit `setupEvent` typically fires within 1-2s of app launch in cloud mode,
// flipping `.syncing → .syncedAt(...)` quickly.
```

### Pattern 6: Restart prompt root-level alert (D-01..D-06)

**What:** A single `@State var showRestartPrompt: Bool` lives at root scope (RootTabView body OR a dedicated `RestartPromptModifier: ViewModifier`). Both SIWA success sites (Settings + IntroFlow) flip this state. The alert dismisses on either button — NO `exit(0)`.

**Example:**

```swift
// Source: NEW — modeled on existing P4 SettingsView Reset .alert pattern
// (gamekit/Screens/SettingsView.swift lines 102-117).
// CONTEXT D-04/D-05/D-06 verbatim.

struct RootTabView: View {
    @Environment(\.authStore) private var authStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showRestartPrompt: Bool = false   // D-03 root-level

    var body: some View {
        TabView { ... }
            .alert(
                String(localized: "Restart to enable iCloud sync"),
                isPresented: $showRestartPrompt
            ) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Quit GameKit")) {
                    // D-05 LOAD-BEARING: dismiss-only. NO exit(0).
                    // Body copy instructs user to manually swipe from app switcher.
                }
            } message: {
                Text(String(localized: "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."))
            }
            .onChange(of: scenePhase) { _, new in
                if new == .active {
                    Task { await authStore.validateOnSceneActive() }   // D-14
                }
            }
    }
}
```

**Wiring the `showRestartPrompt = true` trigger from two sites:**

Two acceptable approaches — planner discretion:

1. **Pass a closure down** from RootTabView to SettingsView and IntroFlowView via `.environment(\.requestRestartPrompt, { showRestartPrompt = true })` or similar.
2. **Promote `showRestartPrompt` to AuthStore** as a `@Published` property: any SIWA success path mutates `authStore.shouldShowRestartPrompt = true`; RootTabView reads `Bindable(authStore).shouldShowRestartPrompt`.

Option 2 is cleaner for v1 because it co-locates the state with the store that triggered it. Mirrors the precedent of `SettingsStore.cloudSyncEnabled` already living in a store, not a view.

### Anti-Patterns to Avoid

- **`exit(0)` on Restart prompt button** — App Store Review red flag (Apple's stance: apps must not programmatically terminate; user-initiated termination only). D-05 LOCKS dismiss-only. Code review must reject any `exit(`, `UIApplication.shared.suspend`, or `abort` call.
- **Storing Apple userID in UserDefaults** — security vulnerability (Pitfall 5 + STACK §3 verbatim). Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is mandatory.
- **`requestedScopes = [.email, .fullName]`** — locked by SC2 = []. Email/fullName ARE nil on subsequent sign-ins regardless (Apple sends them only on first-ever per-app-per-Apple-ID), so requesting them adds consent friction with zero benefit. PROJECT.md "no analytics, no PII" posture forbids it.
- **Showing an alert on credential revocation** — D-13 LOCKS silent. The sign-in card returns to its empty state in SettingsView; user re-signs in if they want. PERSIST-05 "never nag" verbatim.
- **In-app sign-out button** — system-only per ARCHITECTURE §line 423. Adding one violates the lock. The disable mechanism IS system-Settings sign-out.
- **Live `ModelContainer` hot-swap when flag flips** — D-07 explicitly defers this. Construction-time decision only.
- **Logging the Apple userID at `.public` privacy level** — STACK §Security verbatim: "Never log auth tokens." Any AuthStore log MUST use `\(userID, privacy: .private)` interpolation if userID appears at all (recommend: don't log userID, log only outcomes).
- **Letting `eventChangedNotification` observer write to `status` from a background thread** — `@MainActor` class boundary forces the selector to dispatch to main; verify with `dispatchPrecondition(condition: .onQueue(.main))` in DEBUG if uncertain.
- **Constructing `AuthStore` inside view body** — Pitfall 8 cousin. Construct ONCE in `GameKitApp.init()`, inject via EnvironmentKey.
- **`Task { ... }` without `@MainActor` capture in SIWA `onCompletion`** — `onCompletion` fires on main per `SignInWithAppleButton` docs but Swift 6 strict concurrency may flag captures. Use `Task { @MainActor in ... }` explicitly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sign in with Apple button | Custom Apple-logo button + `ASAuthorizationController` | `SignInWithAppleButton` from `AuthenticationServices` | First-party SwiftUI control. Apple HIG forbids tint/label override; correct sizing is system-managed. |
| SIWA flow orchestration | Custom `ASAuthorizationController` + delegate | `SignInWithAppleButton` `onRequest`/`onCompletion` closures | The SwiftUI control wraps the controller correctly. Delegate-based AuthControllers are a Swift 6 strict-concurrency footgun (STACK §Trap D). |
| Keychain storage | Direct `SecItem*` calls scattered across the code | `protocol KeychainBackend` + `SystemKeychainBackend` (Pattern 3) | Testability (D-16) + single seam for the verbatim attributes (SC2). |
| Sync status detection | Custom timer polling CloudKit / heuristic state machine | `NSPersistentCloudKitContainer.eventChangedNotification` | Apple's official sync-event notification. SwiftData uses NSPersistentCloudKitContainer internally so the notification fires for SwiftData stores too. [CITED: azamsharp.com] |
| Anonymous-to-signed-in promotion | Manual fetch-from-old-store + insert-into-new-store + delete-old | Same store path; flip `cloudKitDatabase: .none → .private(...)` (D-08) | Pitfall 4 — mirroring picks up existing local rows automatically when the flag flips. Custom migration is the *bug*, not the feature. |
| Credential revocation polling | Custom `Timer` re-checking `getCredentialState` every N minutes | `credentialRevokedNotification` observer + scene-active validation | Apple's documented lifecycle (Pitfall 5). Polling burns battery and misses revocations between polls. |
| ModelContainer reconfiguration on flag flip | Custom teardown + recreate in same process | App restart (D-07 launch-only) | Hot-swap is MEDIUM confidence per ROADMAP RESEARCH flag; explicitly deferred by D-07 to avoid the entire teardown sequence. |
| Relative-time label updates | Custom `Timer.scheduledTimer` recomputing the string | `TimelineView(.periodic(from: .now, by: 60))` (D-12) | Built-in SwiftUI primitive that ticks without observer churn. |
| Async wrapper around `getCredentialState` | Custom `Future`/`Promise` library | `withCheckedContinuation` (Pattern 2) | Stdlib. Apple-blessed pattern for callback→async conversion. |
| Schema deployment to CloudKit Dashboard | Manual record-type creation in dashboard UI | `try container.initializeCloudKitSchema()` (one-shot dev step, bridges to Core Data) | Pitfall 3 + STACK + leojkwan deploy guide. Materializes record types automatically; matches local schema exactly. |

**Key insight:** P6 has no genuinely novel work — every capability has a first-party Apple API. The phase is plumbing, not invention. Any "let's build our own X" recommendation should be rejected on code review.

## Runtime State Inventory

> P6 is **not** a rename/refactor/migration phase. This section is included for completeness because P6 introduces persistent runtime state (Keychain, CloudKit container) for the first time.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | Keychain entry: `kSecClass = kSecClassGenericPassword`, `kSecAttrService = "com.lauterstar.gamekit.auth"`, `kSecAttrAccount = "appleUserID"`. Survives reinstall ONLY if Keychain access groups are configured (they are NOT in v1; reinstall wipes per `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` semantics — desired behavior). | Reinstall path (D-15): empty Keychain → SYNC section shows SIWA button. CloudKit-mirrored data already in iCloud waits for next cold-start with `cloudSyncEnabled=true`. |
| **Stored data** | CloudKit private database: `iCloud.com.lauterstar.gamekit` private DB. Holds `GameRecord` + `BestTime` records mirrored from the local SwiftData store. **Never deleted by app code** (Pitfall 5 — sign-out keeps cloud rows; revocation keeps cloud rows). | None. CloudKit-managed. User can delete via system Settings → iCloud Storage. |
| **Stored data** | UserDefaults: `gamekit.cloudSyncEnabled` (Bool, default `false`). Already shipped P4. P6 flips on SIWA success. | None — preserved across reinstall? NO, UserDefaults is wiped on reinstall like Keychain. CloudKit rows in iCloud account wait for next sign-in to mirror back down. |
| **Live service config** | CloudKit Dashboard schema (Development environment). Record types: `CD_GameRecord`, `CD_BestTime` (auto-created from SwiftData @Model). | One-shot dev step before SC3 manual test: run `initializeCloudKitSchema()` in DEBUG build (Pattern bridge to Core Data per fatbobman code). NOT shipped production code. P7 promotes to Production. |
| **OS-registered state** | None (no Task Scheduler / launchd / pm2 equivalent on iOS). | None. |
| **Secrets/env vars** | Apple userID in Keychain (handled above). NO server-side secrets — CloudKit uses iCloud account auth, not API keys. | None new beyond Keychain wrapper. |
| **Build artifacts** | Entitlements file: `gamekit/gamekit.entitlements` currently has only `com.apple.developer.applesignin` (P5). iCloud + CloudKit container entries declared in P1 PROJECT.md may live in pbxproj or a different file. | Wave-0 task: planner verifies entitlements layout in Xcode Signing & Capabilities, NOT by reading the file alone. |

**Initialization order (cold start):**

1. App install / first launch → empty Keychain, `cloudSyncEnabled = false`, `cloudKitDatabase: .none`. Local-only.
2. User signs in via SIWA (Settings or Intro Step 3) → AuthStore writes `userID` to Keychain, `cloudSyncEnabled = true`, Restart prompt shows.
3. User dismisses prompt OR cold-restarts → `GameKitApp.init` reads `cloudSyncEnabled = true`, constructs container with `.private("iCloud.com.lauterstar.gamekit")`. Mirroring begins.
4. CloudKit setupEvent → importEvent → exportEvent. Status row reflects each.
5. User signs out via system Settings → `credentialRevokedNotification` fires (or scene-active check catches it) → AuthStore clears Keychain, `cloudSyncEnabled = false`. Local rows preserved. Cloud rows preserved on iCloud server.
6. User signs back in → cycle repeats. Cloud rows merge into local store via mirroring.

## Common Pitfalls

(Inherits from .planning/research/PITFALLS.md Pitfalls 3, 4, 5, 11. Phase-6-specific traps below; full pitfall text in canonical refs.)

### Pitfall A: SwiftData has no native sync-status API — must observe Core Data layer

**What goes wrong:** Developer searches "SwiftData sync status" expecting a `@Published var syncStatus`. SwiftData does NOT expose one. The status row stays `.notSignedIn` forever.

**Why it happens:** SwiftData abstracts CloudKit but doesn't surface sync events. The events ARE fired by the underlying `NSPersistentCloudKitContainer` regardless.

**How to avoid:** Observe `NSPersistentCloudKitContainer.eventChangedNotification` directly via `NotificationCenter` (Pattern 5). Works even though the app uses SwiftData not Core Data.

**Warning signs:** Status row never changes from initial value. No CoreData/CloudKit imports in the observer.

[CITED: azamsharp.com/2026/03/16/swiftdata-icloud-sync-status.html — "SwiftData does not provide any API that tells us when syncing begins or ends. However, the underlying Core Data stack sends notifications whenever a CloudKit sync event changes, and you can listen to those notifications using NotificationCenter."]

### Pitfall B: SIWA `requestedScopes = [.email, .fullName]` returns nil on subsequent sign-ins

**What goes wrong:** Developer requests email + fullName "in case we need them later." First sign-in works, second sign-in returns nil. Code that depends on email/fullName breaks.

**Why it happens:** Apple's design — name and email arrive only on FIRST sign-in per Apple ID per app, ever. If the user has previously signed in (even on a deleted-and-reinstalled app), Apple returns userID only.

**How to avoid:** SC2 verbatim `requestedScopes = []`. We need only the userID. PROJECT.md "no analytics, no PII" posture aligns.

**Warning signs:** `credential.email == nil` reports from second-launch users. Code branching on optional unwraps of email/fullName.

[VERIFIED: WebSearch — "User info is only sent in the ASAuthorizationAppleIDCredential upon initial user sign up. Subsequent logins with the same account do not share any user info and will only return a user identifier."]

### Pitfall C: iOS Simulator iCloud sync is unreliable for testing CloudKit

**What goes wrong:** Developer relies on iOS Simulator for SC3 two-simulator test. CloudKit sync fails to fire because simulators cannot register for remote push notifications, OR sync fires but is significantly delayed/flaky.

**Why it happens:** "Simulators cannot register for remote push notifications" — CloudKit subscriptions rely on silent push. Some CloudKit operations work in simulator (sign-in, dashboard ops), but cross-device sync between two simulators is officially "best-effort" by Apple.

**How to avoid:**
- **Option 1 (preferred for SC3):** Use TWO REAL DEVICES signed into the same iCloud account. Slower to set up but the only fully-supported path.
- **Option 2 (compromise):** Use ONE simulator + ONE real device. Real device emits the push; simulator polls on foreground.
- **Option 3 (last resort):** Two simulators + manually trigger sync by force-quitting and relaunching simulator B. Document expected lag (up to 60s).

CONTEXT D-18 SC3 says "two-simulator iCloud test" — this MAY work but is not guaranteed. Plan should explicitly allow for "or two devices" wording.

**Warning signs:** Simulator B opens Stats and shows 0 records 60+ seconds after simulator A's promotion. CKErrorPartialFailure logs.

[VERIFIED: hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit + apple/sample-cloudkit-sync-engine — "The iOS Simulator is pretty terrible at testing iCloud."]

### Pitfall D: CloudKit Dashboard Development schema not deployed → silent sync failure

**What goes wrong:** Developer runs SC3 test, signs in, expects mirroring, sees `.unavailable` forever. CloudKit logs show "Did not find record type 'CD_GameRecord' in schema."

**Why it happens:** SwiftData/CloudKit Just-In-Time (JIT) Schema creation works in Development environment ONLY when records are written. But schema for unique attributes, indexes, queryable fields requires explicit deployment via `initializeCloudKitSchema()` or CloudKit Dashboard manual edits.

**How to avoid:** ONE-SHOT dev step before SC3: bridge to Core Data and call `try container.initializeCloudKitSchema()` (Pattern from fatbobman article — see Code Examples below). DO NOT ship this in production code; use `#if DEBUG` gate.

**Warning signs:** `eventChangedNotification` fires `setupEvent` → `errorEvent` with "schema not found" or "missing record type" in error message.

[CITED: fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/ — verbatim code pattern]

### Pitfall E: Cold-start regression after enabling CloudKit (FOUND-01 violation)

**What goes wrong:** App with `cloudSyncEnabled = true` cold-launches, takes 1.5-2.5s to render Home — exceeds the <1s budget.

**Why it happens:** `ModelContainer(for: schema, configurations: ModelConfiguration(cloudKitDatabase: .private(...)))` does iCloud schema reconciliation at init, which can include a network round-trip. First-launch-after-install is the worst case (no cached state).

**How to avoid (this phase's mitigations):**
- ModelContainer init is already synchronous in P4 GameKitApp.init() — that's by design (D-07 launch-only).
- If cold-start regresses, the FIRST mitigation is to verify the smoke test (P4 04-01) still passes. Construction-time errors are bigger than latency.
- If construction succeeds but is slow: PROFILE in Instruments → App Launch template. Apple Forum 731334 reports CloudKit-enabled init typically adds 100-300ms on warm path, 500ms-1s on cold first-launch. P5 SC2 baseline cold-start was reported <1s; P6 SC5 must verify regression is acceptable.
- DO NOT defer CloudKit container init to post-Home render in P6. That's the hot-swap path D-07 forbids. If FOUND-01 truly regresses unacceptably, the answer is to revisit hot-swap as a v1.x deferred decision — NOT to ship a deferred init in v1.

**Warning signs:** Instruments App Launch trace shows >1s `didFinishLaunching → first frame`. iPhone 11 / SE 3 cold-launch >1.5s.

[CITED: STACK.md §8 + Pitfall 12]

### Pitfall F: Continuation must resume exactly once

**What goes wrong:** `withCheckedContinuation` wrapping `getCredentialState` resumes twice (state callback + error callback both fire), or zero times (both fire but neither completes the continuation), causing crash or hang.

**Why it happens:** Apple's callback signature is `(CredentialState, Error?) -> Void` — one closure with both parameters. Defensive code that handles them as separate paths can resume twice if both are non-nil (rare but possible).

**How to avoid:** Single `if error != nil { resume(returning: .notFound); return }` early-return BEFORE the `resume(returning: state)`. Pattern 2 illustrates.

**Warning signs:** Crash with "SWIFT TASK CONTINUATION MISUSE" in Console. Never-completing scene-active validation Tasks.

[VERIFIED: hackingwithswift.com/quick-start/concurrency/how-to-use-continuations-to-convert-completion-handlers-into-async-functions]

### Pitfall G: Scene-phase observer running validation on every focus change

**What goes wrong:** `validateOnSceneActive` fires Keychain read + network call to Apple's auth servers on every `.active` transition. App tabbed back from Settings → drains battery + adds ~100ms latency.

**Why it happens:** Naive `.onChange(of: scenePhase) { if .active { validate } }` fires on every active transition, not just app-launch.

**How to avoid:** D-14 says "scene-active transitions" — this IS the intended cadence per Pitfall 5 (the more often you check, the faster a revocation is caught). However:
- Add a debounce: don't re-validate within 60s of last validation.
- If `currentUserID == nil`, early-return (no network call).
- Run on a Task with `.background` priority to avoid blocking main.

**Warning signs:** Battery drain reports. Repeated `getCredentialState` calls in Console between every Settings/Game/Settings tab cycle.

## Code Examples

### Example 1: AuthStore skeleton (combining Patterns 2, 3, 4)

```swift
// Source: NEW — combines stack patterns from CONTEXT.md D-13/D-14/D-16 +
//          STACK.md §3 lifecycle + ARCHITECTURE.md Pattern 4 sign-in flow.
// File: gamekit/Core/AuthStore.swift

import Foundation
import AuthenticationServices
import os

@Observable
@MainActor
final class AuthStore {
    private let backend: KeychainBackend
    private let provider: ASAuthorizationAppleIDProvider
    private static let appleUserIDAccount = "appleUserID"
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )

    /// Reflects whether a userID is currently in Keychain. Computed (not stored)
    /// so reinstall + revocation paths automatically reflect the current state.
    var isSignedIn: Bool { backend.read(account: Self.appleUserIDAccount) != nil }

    /// Read-only — exposed for the (deferred) Apple-ID-suffix display.
    var currentUserID: String? { backend.read(account: Self.appleUserIDAccount) }

    init(backend: KeychainBackend = SystemKeychainBackend()) {
        self.backend = backend
        self.provider = ASAuthorizationAppleIDProvider()
        registerRevocationObserver()
    }

    // MARK: - Sign-in

    /// Called from SIWA `onCompletion` after extracting `credential.user`.
    /// Throws on Keychain write failure; caller decides UX (CONTEXT D-02
    /// flips cloudSyncEnabled BEFORE the prompt regardless).
    func signIn(userID: String) throws {
        try backend.write(userID, account: Self.appleUserIDAccount)
        Self.logger.info("Signed in (userID hidden)")
    }

    // MARK: - Lifecycle

    /// D-14: called from RootTabView's scenePhase observer on .active.
    /// async to bridge the callback API; safe to call when not signed in (early-return).
    func validateOnSceneActive() async {
        guard let stored = currentUserID else { return }
        let state = await getCredentialStateAsync(forUserID: stored)
        switch state {
        case .authorized:
            return
        case .revoked, .notFound, .transferred:
            // D-14 + defensive: .transferred treated as .notFound (rare
            // developer-account migration case per Apple docs).
            clearLocalSignInState(reason: "scene-active validation \(state)")
        @unknown default:
            clearLocalSignInState(reason: "scene-active unknown state")
        }
    }

    // MARK: - Private

    private func registerRevocationObserver() {
        // D-13: silent — no alert per PERSIST-05 "never nag".
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clearLocalSignInState(reason: "credentialRevokedNotification")
            }
        }
    }

    private func clearLocalSignInState(reason: String) {
        do {
            try backend.delete(account: Self.appleUserIDAccount)
            Self.logger.info("Cleared local sign-in state: \(reason, privacy: .public)")
        } catch {
            Self.logger.error(
                "Failed to clear sign-in state: \(error.localizedDescription, privacy: .public)"
            )
        }
        // NOTE: caller (or a separate observer of isSignedIn) is responsible for
        // flipping settingsStore.cloudSyncEnabled = false. Cleanest pattern is to
        // pass a callback in init OR have AuthStore hold a weak ref to SettingsStore.
        // CONTEXT D-13 implies AuthStore touches both. Recommend:
        //   init(backend:, settingsStore:) — AuthStore depends on SettingsStore.
    }

    private func getCredentialStateAsync(
        forUserID userID: String
    ) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if error != nil {
                    continuation.resume(returning: .notFound)
                    return
                }
                continuation.resume(returning: state)
            }
        }
    }
}
```

### Example 2: One-shot CloudKit Schema deployment (DEBUG only)

```swift
// Source: fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-...
// Adapted to GameKit's GameRecord + BestTime schema.
//
// Run this ONCE in a debug build before SC3 manual test. NOT shipped production.
// Discretion #7: P6 plan calls out "Schema deployed to Development before SC3
// manual run" as a checklist item.

#if DEBUG
import CoreData
import SwiftData

@MainActor
enum CloudKitSchemaInitializer {
    static func deployDevelopmentSchema() throws {
        // Bridge to Core Data because SwiftData lacks the API directly.
        // Path matches SwiftData's default store URL — adjust if using a
        // custom URL via ModelConfiguration(url:).
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "default.store")

        let desc = NSPersistentStoreDescription(url: storeURL)
        let opts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.lauterstar.gamekit"
        )
        desc.cloudKitContainerOptions = opts
        desc.shouldAddStoreAsynchronously = false

        // Build a managed object model from the SwiftData @Model types.
        // SwiftData synthesizes Core Data models named CD_<TypeName>.
        guard let mom = NSManagedObjectModel.makeManagedObjectModel(
            for: [GameRecord.self, BestTime.self]
        ) else {
            throw NSError(
                domain: "CloudKitSchemaInitializer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to build NSManagedObjectModel from SwiftData types"]
            )
        }

        let container = NSPersistentCloudKitContainer(
            name: "GameKit",
            managedObjectModel: mom
        )
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, err in
            loadError = err
        }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema()  // ← THE ONE-SHOT CALL

        // Release file locks before app's SwiftData container takes over.
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
#endif
```

[CITED: fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/]

**How to invoke:** Add a hidden Settings → Debug menu in `#if DEBUG` builds, OR add a one-shot button in IntroFlowView's Skip path during P6 development. Remove the hidden invocation before TestFlight.

### Example 3: SettingsView SYNC section (skeleton — UI-SPEC owns layout details)

```swift
// Source: NEW — modeled on existing P5 audioSection in
//   gamekit/Screens/SettingsView.swift lines 160-185.
// CONTEXT D-09/D-10 verbatim.

@ViewBuilder
private var syncSection: some View {
    settingsSectionHeader(theme: theme, String(localized: "SYNC"))
    DKCard(theme: theme) {
        VStack(spacing: 0) {
            // Row 1: Sign-in row (D-10)
            if authStore.isSignedIn {
                signedInRow
            } else {
                signInButtonRow
            }
            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
            // Row 2: Sync status (D-10 + D-12)
            syncStatusRow
        }
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
                request.requestedScopes = []  // SC2 verbatim
            },
            onCompletion: handleSIWACompletion   // see Pattern 4
        )
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 44)
    }
    .frame(minHeight: 44)
}

@ViewBuilder
private var signedInRow: some View {
    HStack(spacing: theme.spacing.s) {
        Image(systemName: "checkmark.icloud.fill")
            .foregroundStyle(theme.colors.success)
        Text(String(localized: "Signed in to iCloud"))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
        Spacer()
        // NO sign-out button — system-only per ARCHITECTURE §line 423.
    }
    .frame(minHeight: 44)
}

@ViewBuilder
private var syncStatusRow: some View {
    HStack(spacing: theme.spacing.s) {
        statusIcon
        TimelineView(.periodic(from: .now, by: 60)) { context in
            // D-12: TimelineView ticks the relative-time string once/min.
            Text(syncStatusLabel(at: context.date))
                .font(theme.typography.body)
                .foregroundStyle(syncStatusColor)
        }
        Spacer()
    }
    .frame(minHeight: 44)
}

private func syncStatusLabel(at now: Date) -> String {
    switch cloudSyncStatusObserver.status {
    case .syncing:
        return String(localized: "Syncing…")
    case .syncedAt(let date):
        let delta = now.timeIntervalSince(date)
        if delta < 60 {
            return String(localized: "Synced just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return String(
            format: String(localized: "Synced %@"),
            formatter.localizedString(for: date, relativeTo: now)
        )
    case .notSignedIn:
        return String(localized: "Not signed in")
    case .unavailable:
        return String(localized: "iCloud unavailable")
    }
}
```

### Example 4: IntroFlowView Step 3 SIWA wire-up (replaces P5 D-21 no-op)

```swift
// Source: edit gamekit/Screens/IntroFlowView.swift line 124 (signInTapped).
// CONTEXT D-03 — fires Restart prompt on success.

// REPLACES line 124 no-op log:
private func signInTapped() {
    Self.logger.info("SIWA tapped during intro")
    // NOTE: actual auth fires from SignInWithAppleButton's onCompletion
    // (which is on IntroStep3SignInView lines 245-251). The P5 onCompletion
    // is { _ in } — P6 replaces with the real handler.
}

// ADD/REPLACE the line 248-250 onCompletion in IntroStep3SignInView:
SignInWithAppleButton(
    .signIn,
    onRequest: { request in
        request.requestedScopes = []  // SC2 verbatim
    },
    onCompletion: { result in
        Task { @MainActor in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential
                        as? ASAuthorizationAppleIDCredential else { return }
                do {
                    try authStore.signIn(userID: credential.user)
                    settingsStore.cloudSyncEnabled = true       // D-02
                    onSIWASuccess()                              // closure → root flips showRestartPrompt = true
                } catch {
                    // Silent log — no alert per PERSIST-05 (Pitfall A).
                    IntroFlowView.logger.error("SIWA Keychain write failed: \(error.localizedDescription, privacy: .public)")
                }
            case .failure(let error):
                IntroFlowView.logger.error("SIWA failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
)
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
.frame(height: 44)
```

The `onSIWASuccess` closure flows up through `IntroStep3SignInView(... onSIWASuccess: ...)` → `IntroFlowView` → either:
- A) `IntroFlowView` reads `@Environment(\.requestRestartPrompt)` and calls it.
- B) (Recommended) `AuthStore.shouldShowRestartPrompt = true` flips a Bindable property; RootTabView's `.alert(isPresented: Bindable(authStore).shouldShowRestartPrompt)` surfaces.

## State of the Art

| Old Approach | Current Approach (P6) | When Changed | Impact |
|--------------|------------------------|--------------|--------|
| `@EnvironmentObject ObservableObject` | `@Observable @MainActor final class` + custom `EnvironmentKey` | iOS 17 (P3 RESEARCH Pitfall 1 inheritance) | Locked across P4/P5/P6 — all new app-level singletons follow this pattern. |
| Direct `SecItem*` calls in classes | `protocol KeychainBackend` + DI | P6 D-16 + P4 InMemoryStatsContainer mirror | Testability without real Keychain access. |
| Callback-based auth APIs | `withCheckedContinuation` `async` wrappers | Swift 5.5+ (mature in Swift 6) | Cleaner async surface for Task { } scene-phase work. |
| `Timer.scheduledTimer` for relative-time labels | `TimelineView(.periodic(...))` | iOS 16+ (mature in 17) | Less observer churn; SwiftUI-native. |
| Polling `getCredentialState` periodically | Notification observer + scene-active validation | Established Apple pattern (Pitfall 5) | Battery + correctness. |
| `cloudKitDatabase: .automatic` (reads entitlements) | `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` (explicit) | P4 D-08 lock | Container ID drift detected at smoke-test time. |

**Deprecated/outdated:**
- `requestedScopes = [.email, .fullName]` for stable persistent identifiers — these are nil on subsequent sign-ins. Use `userID` (`credential.user`) only.
- `kSecAttrAccessibleAlways` for credential storage — security regression. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (SC2 + STACK §Security).
- `applicationDidBecomeActive` UIKit callback for re-validation — under SwiftUI, use `@Environment(\.scenePhase) .onChange { ... }` instead.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `eventChangedNotification` userInfo key is `NSPersistentCloudKitContainer.eventNotificationUserInfoKey` | Pattern 5, Code Examples | Status row never updates. **Verification:** during planning Wave 0, plant a test that posts a synthetic notification and asserts the observer's `status` updates. Risk LOW — verified by 2026 source citing Apple docs. |
| A2 | `Event` properties are `type`, `endDate`, `succeeded`, `error`, `identifier`, `storeIdentifier` | Pattern 5 | If property names changed in a recent iOS update, observer fails to compile (caught at build). Risk LOW. |
| A3 | `getCredentialState` completion fires on a background thread; safe to resume from there | Pattern 2 | Continuation resume is documented thread-safe; this assumption is conservative. Risk LOW. |
| A4 | SIWA `requestedScopes = []` returns a credential with `email = nil`, `fullName = nil`, `user` populated (the userID) | Pattern 4 | Tested in countless production apps; documented behavior. Risk LOW. |
| A5 | `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` reuses the same on-disk SQLite store as `.none` | Pattern 6 / D-08 | If false, P6 SC3 fails (cloud store starts empty). Risk LOW — locked by ARCHITECTURE Pattern 5 + Apple Forum 756538 + Pitfall 4. **Verification:** P4-01 smoke test already constructs both configs cleanly; SC3 manual test confirms the same store path. |
| A6 | Cold-start with `cloudSyncEnabled=true` + `.private(...)` adds 100-500ms typical, sometimes up to 1s on first-launch-after-install | Pitfall E | Empirical only; no Apple SLA. SC5 manual Instruments measurement is the real verification. Risk: MEDIUM — if P6 regresses cold-start above 1s, FOUND-01 violation. |
| A7 | `initializeCloudKitSchema()` requires bridging to Core Data (no native SwiftData API exists in iOS 17/18) | Code Examples 2, Pitfall D | If Apple ships a native SwiftData API in iOS 18.x or 19, the bridging code is more complex than needed. Risk: LOW — fatbobman article (2025) confirms still required. |
| A8 | iOS Simulator can run CloudKit sync between 2 simulators in same iCloud account, but unreliably (Pitfall C) | Pitfall C | If TOTALLY broken in simulator, SC3 manual test must use 2 real devices. Risk: MEDIUM — Apple's docs are hedged; ecosystem reports work-with-caveats. **Mitigation:** plan provides "or 2 real devices" fallback. |
| A9 | The current `gamekit.entitlements` file (containing only `com.apple.developer.applesignin = [Default]`) PLUS the P1-declared iCloud + CloudKit container entries (currently NOT visible in the entitlements file) is the complete shipped state. iCloud entries may live in pbxproj capabilities. | Standard Stack | If iCloud + CloudKit capabilities are NOT registered in the project, the app crashes at runtime when constructing `.private("iCloud.com.lauterstar.gamekit")` with a runtime error. **Risk: HIGH if not verified.** Wave-0 task: planner confirms the capabilities are registered in the gamekit target via Xcode Signing & Capabilities pane. |
| A10 | `credential.user` (the Apple userID) is stable across sessions for a given (Apple ID, app bundle) pair — survives reinstall ON THE SAME APPLE ID | Pattern 4 | If userID rotates per session, scene-active `getCredentialState(forUserID:)` calls fail with `.notFound` constantly. Risk: VERY LOW — Apple's documented behavior is exactly this stability guarantee. |

**If this table needs to shrink:** A6 and A8 are the load-bearing assumptions. Plan should treat both as "verify in SC5 / SC3 manual checkpoint, document actual behavior in 06-VERIFICATION.md."

## Open Questions (RESOLVED)

1. **Where does `showRestartPrompt` state live — RootTabView local state, or AuthStore property?**
   - What we know: D-03 says "root level" (RootTabView body OR a `RestartPromptModifier`). Both work.
   - What's unclear: whether AuthStore should expose `shouldShowRestartPrompt: Bool` (mutable from SIWA success site) OR whether RootTabView passes a closure down via Environment.
   - **RESOLVED:** Promote to AuthStore as a published property. Co-locates the trigger with the store that flipped `cloudSyncEnabled`. Mirrors the pattern of having state next to the events that mutate it. RootTabView reads `Bindable(authStore).shouldShowRestartPrompt` in the alert binding. Plan 06-04 implements; Plan 06-06 wires.

2. **Should `AuthStore` depend on `SettingsStore` (to flip `cloudSyncEnabled`) directly, or via a callback closure?**
   - What we know: D-13 says "clear Keychain userID, set `cloudSyncEnabled=false`, log via `os.Logger`." AuthStore needs to flip the flag.
   - What's unclear: whether to inject `SettingsStore` into AuthStore.init(), or have AuthStore expose `var shouldDisableSync: Bool` and let the app layer reconcile.
   - **RESOLVED — DECLINE recommendation; keep AuthStore single-responsibility per CLAUDE.md §4.** Plan 06-04 keeps AuthStore independent: AuthStore exposes `currentUserID` + `shouldShowRestartPrompt` only; SIWA-success and revocation sites at the call layer (Plan 06-07 SettingsSyncSection, Plan 06-08 IntroFlowView, Plan 06-04 internal revocation handler) flip `settingsStore.cloudSyncEnabled` themselves via `@Environment(\.settingsStore)`. Avoids cross-injection coupling between two `@Observable` singletons; both stay independently testable with their own in-memory stubs.

3. **What does `validateOnSceneActive()` do if `currentUserID` exists but no network is available?**
   - What we know: `getCredentialState` on no-network may fire with `.authorized` (cached) or fail with an error.
   - What's unclear: defensive behavior when the call errors. Treating as `.notFound` would clear sign-in state on every airplane-mode toggle — unacceptable.
   - **RESOLVED:** Treat errors as no-op preserving last-known state. The `getCredentialStateAsync` wrapper returns `.authorized` (cached) when `error != nil` AND `currentUserID` exists in Keychain — preserves sign-in across airplane-mode toggles. Only `.revoked` and explicit `.notFound` from a successful call clear local state. NSError domain inspection deferred (fragile per research). Plan 06-04 Test 3 covers `.authorized` / `.revoked` / `.notFound` / `.transferred`; error-no-op path documented in code comment, not unit-tested (defensive-only).

4. **Does the `eventChangedNotification` selector run on main thread?**
   - What we know: `NotificationCenter.default.addObserver(... queue: .main)` posts on main. But default queue (queue: nil) posts on the thread that posted.
   - What's unclear: whether NSPersistentCloudKitContainer always posts on main.
   - **RESOLVED:** AuthStore registers `credentialRevokedNotification` with `queue: .main` (synchronous to MainActor); CloudSyncStatusObserver registers `eventChangedNotification` with `queue: nil` (background) and hops to `MainActor` via `Task { @MainActor in self.updateStatus(...) }` inside the closure. Background-then-hop avoids blocking notification poster; main-queue receiver simplifies AuthStore's tight revocation path. Plan 06-04 + Plan 06-05 ship verbatim shapes.

5. **CloudKit Dashboard schema deployment — exact step sequence for SC3?**
   - What we know: One-shot dev call to `initializeCloudKitSchema()` materializes record types. Then CloudKit Dashboard shows them under Development environment.
   - What's unclear: whether the schema needs further dashboard-side configuration (indexes, queryable fields, …) for SC3 to pass.
   - **RESOLVED:** Plan 06-03 Task 3 ships the dashboard verify checklist: (a) run `CloudKitSchemaInitializer.deployDevelopmentSchema()` in DEBUG build (one-shot), (b) open CloudKit Dashboard → `iCloud.com.lauterstar.gamekit` → Schema → Development → verify `CD_GameRecord` and `CD_BestTime` record types exist, (c) verify Queryable indexes auto-deployed for `gameKindRaw` (used in StatsView `@Query` predicate). If queryable indexes missing, manually add in Dashboard. Plan 06-03 is `autonomous: false` (`checkpoint:human-verify`). Plan 06-09 Task SC3 reads this verification log before proceeding with the 2-device promotion test.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Build, Swift Testing, String Catalog | ✓ (project on Swift 6 strict concurrency) | confirmed via P1-P5 history | — |
| iOS 17+ Simulator | Most automated tests + SC1, SC4, SC5 | ✓ | iOS 17 deployment target locked at P1 | — |
| iOS device (or 2nd simulator) | SC2 manual SIWA verification | Likely available | — | Plan must prompt user; provide fallback to "second simulator with documented limitations" (Pitfall C) |
| **Real iCloud account on test devices/simulators** | SC2, SC3 manual tests | Unknown — must verify | — | Plan must require user to confirm before SC3 begins. NO TestFlight surrogate works for this. |
| **CloudKit Dashboard access** | SC3 schema verification | Available via developer.apple.com (assuming Apple Developer Program membership) | — | If membership not active, SC3 cannot proceed. |
| 2 real iOS devices on same iCloud account | SC3 ideal path (Pitfall C — simulator path is unreliable) | Unknown | — | Two simulators with caveats; document expected lag. |
| Xcode Instruments App Launch template | SC5 cold-start measurement | ✓ (Xcode-bundled) | 16+ | — |

**Missing dependencies with no fallback:**
- Real iCloud account access — without it, SC2/SC3 cannot pass. Plan must call this out as a Wave-0 prerequisite, NOT a per-task assumption.
- Apple Developer Program membership — required for CloudKit Dashboard. Likely already in place (entitlements would not provision otherwise) but plan should confirm.

**Missing dependencies with fallback:**
- 2 real devices for SC3 — fall back to 2 simulators with documented expected lag (≤60s) per Pitfall C.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16+ bundled) — matches P2-P5 convention. |
| Config file | None — Swift Testing requires no config file beyond the test target build settings. |
| Quick run command | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:gamekitTests/AuthStoreTests` (per-task TDD) |
| Full suite command | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERSIST-04 (signed-out parity) | Full Mines feature works without sign-in | manual (SC1) | — | manual-only — automated cannot reach iCloud + sign-in flows |
| PERSIST-04 (Keychain round-trip) | AuthStore writes/reads/deletes userID via KeychainBackend | unit | `xcodebuild test ... -only-testing:gamekitTests/Core/AuthStoreTests/keychainRoundTrip` | ❌ Wave 0 (NEW: AuthStoreTests.swift) |
| PERSIST-04 (revocation handler) | `credentialRevokedNotification` clears AuthStore state | unit | `... AuthStoreTests/revocationClearsState` | ❌ Wave 0 (NEW: AuthStoreTests.swift) |
| PERSIST-04 (scene-active stub) | All 4 `CredentialState` cases route correctly | unit (parameterized) | `... AuthStoreTests/sceneActiveValidation` | ❌ Wave 0 (NEW: AuthStoreTests.swift) |
| PERSIST-04 (entitlements + capabilities) | iCloud + CloudKit container + SIWA entitlements present | manual (Wave 0 verify) | — | manual — Xcode Signing & Capabilities |
| PERSIST-04 (cold-start <1s with cloud on) | FOUND-01 not regressed | manual (SC5) | Instruments App Launch template | manual-only |
| PERSIST-05 (signed-in row state) | SettingsView SYNC section reflects auth state | unit (snapshot-style) | possible — assert view body string includes "Signed in" / SIWA button | partial — view tests would need SwiftUI ViewInspector or similar; default to manual |
| PERSIST-05 (silent revocation) | No alert on credentialRevokedNotification | manual (SC2) | — | manual-only — verifies absence of UI |
| PERSIST-05 (no nag) | SIWA appears in IntroFlow Step 3 (P5 already shipped) and Settings SYNC; not modal during gameplay | manual (SC5) | — | manual-only |
| PERSIST-06 (anonymous→signed-in promotion) | 50-game user signs in, restarts, all 50 records sync to second device | manual (SC3) | — | manual-only — requires real iCloud + 2 devices/sims |
| PERSIST-06 (4-state status row) | Synced just now / Syncing… / Not signed in / iCloud unavailable | unit (synthetic notifications) + manual (SC4) | `... CloudSyncStatusObserverTests/eventToStatusMapping` for unit; live verify for manual | ❌ Wave 0 (NEW: CloudSyncStatusObserverTests.swift) |
| PERSIST-06 (relative-time label) | "Synced just now" < 60s, "Synced X ago" > 60s, format correct for hours/days | unit (pure function) | `... CloudSyncStatusObserverTests/relativeTimeFormat` | ❌ Wave 0 (NEW) |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:gamekitTests/Core/AuthStoreTests` OR `... CloudSyncStatusObserverTests` (per-file scope, ≤30s).
- **Per wave merge:** Full suite green (`xcodebuild test -scheme gamekit -destination ...`).
- **Phase gate:** Full suite + manual SC1-SC5 verification checkpoint (06-VERIFICATION.md) signed off before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `gamekit/Core/AuthStore.swift` — production source (TDD: tests first per P4/P5 precedent)
- [ ] `gamekit/Core/CloudSyncStatusObserver.swift` — production source
- [ ] `gamekit/Core/SyncStatus.swift` (or alongside observer) — enum
- [ ] `gamekitTests/Core/AuthStoreTests.swift` — covers PERSIST-04 unit cases
- [ ] `gamekitTests/Core/CloudSyncStatusObserverTests.swift` — covers PERSIST-06 unit cases
- [ ] `gamekitTests/Helpers/InMemoryKeychainBackend.swift` — protocol stub
- [ ] `06-VERIFICATION.md` — manual SC1-SC5 checkpoint template
- [ ] Wave-0 entitlements verification task (Pitfall A9 — confirm iCloud + CloudKit + SIWA all registered in target)
- [ ] Wave-0 schema deploy task (one-shot debug call to `initializeCloudKitSchema()`) — NEEDED before SC3 can begin

## Security Domain

> Required because P6 introduces auth + persistent credentials. `security_enforcement` config absent = enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Sign in with Apple via `AuthenticationServices.SignInWithAppleButton`. NO custom auth implementation. App Store Review Guideline 4.8 mandates SIWA when any third-party login offered (N/A here — Apple is the only provider). |
| V3 Session Management | yes | Apple userID stored in Keychain. Identity token (one-shot) NEVER stored. Scene-active validation re-confirms credential state. Revocation notification clears state immediately. |
| V4 Access Control | partial | App-level: no roles. CloudKit-level: `.private(...)` database — only the user can read their own data; developer has no access. CKContainer auth handled by iCloud account (orthogonal to SIWA). |
| V5 Input Validation | yes | `credential.user` is opaque; treated as a string. No parsing, no JWT decoding (identityToken is JWT but we don't use it for v1). UserID written to Keychain as UTF-8 bytes. |
| V6 Cryptography | yes | NEVER hand-roll. Keychain handles encryption-at-rest with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` semantics. CloudKit handles encryption-in-transit + at-rest server-side (Apple-managed). No app-level crypto code. |

### Known Threat Patterns for `AuthenticationServices` + `Security.framework` + `NSPersistentCloudKitContainer`

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Apple userID stored in UserDefaults | Information Disclosure | Locked: `SystemKeychainBackend` + `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (Pattern 3) |
| Apple userID logged at `.public` privacy | Information Disclosure | os.Logger interpolation MUST use `\(..., privacy: .private)` if userID is included; recommend NOT logging userID at all |
| Identity token stored | Information Disclosure | Discard `credential.identityToken` immediately after onCompletion. NEVER persist. (One-shot JWT, expires fast, useless after the auth flow.) |
| `requestedScopes = [.email, .fullName]` collecting PII | Privacy violation | Locked: `requestedScopes = []` per SC2 + PROJECT.md "no analytics, no PII" |
| Programmatic app termination via `exit(0)` | App Store rejection | Locked: D-05 dismiss-only, no exit(0) (Pattern 6 anti-pattern) |
| CloudKit container ID drift mid-development | Tampering / data loss | Locked: container ID `iCloud.com.lauterstar.gamekit` pinned at P1, smoke-tested at P4-01, verified at P7 |
| Public CloudKit DB exposing user data | Information Disclosure | Locked: only `.private(...)` is used; PROJECT.md forbids public DB |
| Sign-out wipes local data | Loss of availability | Locked: D-13/D-15 + ARCHITECTURE Pattern 5 — local data preserved on revocation/reinstall (anonymous-mode feature parity) |
| App lacks SIWA entitlement → runtime crash on flow init | Denial of Service | Verified: `com.apple.developer.applesignin = [Default]` shipped in P5 (05-05); P6 verifies no drift |
| Privacy nutrition label inconsistent with binary | App Store rejection | Deferred to P7 release-checklist item; PROJECT.md tracks as "Data Not Collected" with documented reasoning |
| Schema not deployed to Production CloudKit before TestFlight | Silent sync failure | Deferred to P7 (CONTEXT P6 out-of-scope #1) |

## Sources

### Primary (HIGH confidence)

- **CLAUDE.md** — Project constitution. §1 stack/data-safety/no-account-required, §8.5 file caps, §8.6 .foregroundStyle, §8.10 atomic commits.
- **`.planning/PROJECT.md`** — CloudKit container ID lock, "no analytics" / "no required accounts" non-negotiables, Apple-native-only posture.
- **`.planning/REQUIREMENTS.md`** — PERSIST-04, PERSIST-05, PERSIST-06 verbatim text.
- **`.planning/ROADMAP.md`** Phase 6 entry — SC1..SC5 + RESEARCH flag (HIGH confidence on launch-only Restart-prompt path).
- **`.planning/research/ARCHITECTURE.md`** §Pattern 5 (Conditional CloudKit via ModelConfiguration Swap), §Pattern 4 (Sign-in flow PERSIST-06), §line 423 (system-only sign-out).
- **`.planning/research/PITFALLS.md`** Pitfall 3 (silent CloudKit sync failures), Pitfall 4 (anonymous→signed-in data loss), Pitfall 5 (SIWA revocation lifecycle), Pitfall 11 (App Store CloudKit gotchas).
- **`.planning/research/STACK.md`** §3 (SIWA flow), §Security (Keychain attributes), §8 (cold-start tactics).
- **`.planning/phases/04-stats-persistence/04-CONTEXT.md`** D-07/D-08/D-09 (ModelContainer + cloudSyncEnabled + container ID), D-29 (EnvironmentKey injection).
- **`.planning/phases/05-polish/05-CONTEXT.md`** D-12 (SFXPlayer EnvironmentKey precedent), D-21 (IntroFlow SIWA placeholder).
- **`gamekit/App/GameKitApp.swift`** lines 36-92 — existing init pattern P6 extends.
- **`gamekit/Core/SettingsStore.swift`** lines 124-135 — `EnvironmentKey` precedent for AuthStore + CloudSyncStatusObserver.
- **`gamekit/Screens/SettingsView.swift`** lines 161-185 — `audioSection` pattern for new `syncSection`.
- **`gamekit/Screens/IntroFlowView.swift`** lines 124, 245-251 — SIWA placeholder + signInTapped no-op edit sites.
- **`gamekitTests/Helpers/InMemoryStatsContainer.swift`** — pattern for `InMemoryKeychainBackend`.
- [Apple — `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)
- [Apple — `ASAuthorizationAppleIDProvider`](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidprovider)
- [Apple — `ASAuthorizationError.Code.canceled`](https://developer.apple.com/documentation/authenticationservices/asauthorizationerror-swift.struct/code/canceled)
- [Apple — `eventChangedNotification`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/eventchangednotification)

### Secondary (MEDIUM confidence — independent verification of Apple docs)

- [AzamSharp — SwiftData iCloud Sync Status (March 2026)](https://azamsharp.com/2026/03/16/swiftdata-icloud-sync-status.html) — verbatim code for `eventChangedNotification` userInfo key + Event property mapping.
- [fatbobman — Resolving incomplete iCloud data sync using initializeCloudKitSchema](https://fatbobman.com/en/snippet/resolving-incomplete-icloud-data-sync-in-ios-development-using-initializecloudkitschema/) — verbatim Swift code for SwiftData → Core Data bridge to call `initializeCloudKitSchema()`.
- [Hacking with Swift — Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit) — schema constraints + Simulator limitation.
- [Hacking with Swift — How to use continuations to convert completion handlers](https://www.hackingwithswift.com/quick-start/concurrency/how-to-use-continuations-to-convert-completion-handlers-into-async-functions) — `withCheckedContinuation` pattern + "resume exactly once" rule.
- [Create With Swift — Sign in with Apple on a SwiftUI application](https://www.createwithswift.com/sign-in-with-apple-on-a-swiftui-application/) — `SignInWithAppleButton` SwiftUI usage.
- [Apple Developer Forum 121496 — Cannot get email & name when scopes empty](https://developer.apple.com/forums/thread/121496) — confirms email/fullName arrive only on first sign-in.
- [Apple Developer Forum 731435 — CKSyncEngine & SwiftData incompatibility](https://developer.apple.com/forums/thread/731435) — confirms CKSyncEngine out-of-scope.
- [Apple Developer Forum 756538 — Local SwiftData to CloudKit migration](https://developer.apple.com/forums/thread/756538) — confirms same-store-path promotion (D-08).
- [Crunchy Bagel — General Findings About NSPersistentCloudKitContainer](https://crunchybagel.com/nspersistentcloudkitcontainer/) — Event notification details.
- [Apple sample-cloudkit-sync-engine](https://github.com/apple/sample-cloudkit-sync-engine) — confirms simulator push limitation.

### Tertiary (LOW confidence — flagged for validation in plan)

- Cold-start latency benchmarks for `.private(...)` ModelConfiguration vs `.none` — no formal Apple SLA exists. Empirical reports range from 100-500ms typical to 1s+ on first-launch-after-install. **Validate via SC5 Instruments measurement.** [ASSUMED — A6]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks verified against Apple docs + 2+ independent secondary sources.
- Architecture patterns: HIGH — patterns are direct mirrors of P4/P5 locked precedents (`@Observable @MainActor` + EnvironmentKey, `protocol KeychainBackend` mirrors InMemoryStatsContainer, etc.).
- Pitfalls: HIGH — inherited from PITFALLS.md cross-verified pitfalls 3/4/5/11.
- Code examples: HIGH for AuthStore + CloudSyncStatusObserver skeletons (built from cited patterns); MEDIUM for `initializeCloudKitSchema` bridge (verbatim from fatbobman, but bridge code complexity is real).
- Cold-start regression: MEDIUM — no formal benchmark; SC5 manual gate is the only reliable verification.
- Two-simulator iCloud sync: MEDIUM — Apple's docs hedge; ecosystem reports work-with-caveats.

**Research date:** 2026-04-26
**Valid until:** 2026-05-26 (30 days for stable Apple-framework patterns; sooner if Xcode 26 introduces breaking changes to AuthenticationServices or NSPersistentCloudKitContainer).
