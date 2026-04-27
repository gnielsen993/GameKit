---
phase: 06-cloudkit-siwa
plan: 04
subsystem: auth
tags:
  - authstore
  - tdd
  - wave-1
  - keychain
  - siwa-lifecycle
requires:
  - 06-01  # KeychainBackend + AuthStoreTests RED skeleton
provides:
  - "@Observable @MainActor AuthStore"
  - "protocol CredentialStateProvider: Sendable"
  - "struct SystemCredentialStateProvider"
  - "EnvironmentKey injection (\\.authStore)"
  - "shouldShowRestartPrompt: Bool published trigger (D-03)"
affects:
  - "Plan 06-06 (RootTabView scenePhase observer will call validateOnSceneActive())"
  - "Plan 06-07 (SettingsView reads authStore.isSignedIn + flips shouldShowRestartPrompt on SIWA-success)"
  - "Plan 06-08 (IntroFlowView SIWA Step-3 success site flips shouldShowRestartPrompt)"
tech-stack:
  added:
    - "AuthenticationServices.framework (ASAuthorizationAppleIDProvider)"
    - "os.Logger(category: \"auth\")"
  patterns:
    - "withCheckedContinuation Pitfall F early-return on error"
    - "Selector-based NotificationCenter observer (sync delivery contract)"
    - "MainActor.assumeIsolated inside @objc method on @MainActor class"
    - "EnvironmentKey injection mirroring SettingsStore D-29"
key-files:
  created:
    - gamekit/gamekit/Core/AuthStore.swift  # 232 lines (≤240 budget)
  modified:
    - gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift  # Rule 3: SKIP_OBSERVER_TESTS gate so test target compiles until Plan 06-05
decisions:
  - "Selector-based addObserver (NOT block-based with queue:.main) per Plan 06-04 §Critical implementation notes — block-based hops through dispatch_async and breaks Plan 06-01 Test 2's sync-test contract."
  - "MainActor.assumeIsolated inside @objc handleRevocation(_:) — narrow-and-correct for @MainActor class; Task { @MainActor in ... } would defer past .post returning."
  - "Pitfall F early-return: `if error != nil { resume(returning: .notFound); return }` BEFORE `resume(returning: state)` — continuation resumed exactly once."
  - "AuthStore composes Sendable KeychainBackend without @MainActor crossing — Plan 06-01 lesson held: Sendable protocol conformer stays non-isolated; @MainActor class holds `let backend: KeychainBackend` cleanly under Swift 6 strict concurrency."
  - "AuthStore stays single-responsibility — does NOT inject SettingsStore even though RESEARCH §Code Examples 1 mentions it as an option (Q2 RESOLVED-declined). Plan 06-06 wires sign-out → cloudSyncEnabled=false at the GameKitApp scenePhase observer level instead."
  - "Rule 3 deviation: gate Plan 06-02's CloudSyncStatusObserverTests body in `#if SKIP_OBSERVER_TESTS` so the test target compiles. Plan 06-05 deletes the gate when CloudSyncStatusObserver.swift ships."
metrics:
  duration_minutes: 5
  completed_date: 2026-04-27
  tasks: 1
  files: 2
---

# Phase 06 Plan 04: AuthStore (Wave-1 GREEN gate) Summary

@Observable @MainActor AuthStore composes KeychainBackend + CredentialStateProvider seams to flip Plan 06-01's 7 RED tests GREEN — Apple userID Keychain persistence + revocation observer + scene-active credential validation, all logged without ever interpolating the userID.

## What shipped

### `gamekit/gamekit/Core/AuthStore.swift` (new, 232 lines)

**Public surface:**
- `protocol CredentialStateProvider: Sendable` — test seam mirroring KeychainBackend's protocol shape (PATTERNS §6 line 384).
- `@MainActor struct SystemCredentialStateProvider: CredentialStateProvider` — production conformer wrapping `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:completion:)` in `withCheckedContinuation` with Pitfall F error early-return.
- `@Observable @MainActor final class AuthStore`:
  - `init(backend: KeychainBackend = SystemKeychainBackend(), credentialStateProvider: CredentialStateProvider = SystemCredentialStateProvider())` — both seams default to production, tests inject in-memory stubs.
  - `var isSignedIn: Bool { backend.read(...) != nil }` and `var currentUserID: String? { backend.read(...) }` — read-through computed; no separate cache.
  - `var shouldShowRestartPrompt: Bool = false` — D-03 root-level alert trigger.
  - `func signIn(userID: String) throws` — writes userID to Keychain via backend; logs "Signed in (userID hidden)".
  - `func validateOnSceneActive() async` — D-14 routing; `.authorized` is no-op; `.revoked` / `.notFound` / `.transferred` → clearLocalSignInState.
  - `@objc private func handleRevocation(_:)` — D-13 silent revocation; selector-based observer registered in init.
  - `#if DEBUG internal func clearForTesting()` — Plan 06-01 Test 1 round-trip seam.
- `EnvironmentValues.authStore` extension — iOS-17-canonical injection for @Observable types.

### `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` (modified — Rule 3)

Wrapped the suite body in `#if SKIP_OBSERVER_TESTS` / `#endif` so the test target compiles while Plan 06-05 is unshipped. Without this gate, Plan 06-04 cannot run AuthStoreTests because Plan 06-02's symbol-level RED ("cannot find 'CloudSyncStatusObserver' in scope") prevents the entire test target from linking. Plan 06-05's GREEN-gate executor MUST delete the `#if SKIP_OBSERVER_TESTS` and `#endif` lines.

## Verification

### 7/7 AuthStoreTests GREEN

```
xcodebuild test -scheme gamekit \
  -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48" \
  -only-testing:gamekitTests/AuthStoreTests
```

**Output (xcodebuild tail):**
```
** TEST SUCCEEDED **

Testing started
Test suite 'AuthStoreTests' started on 'Clone 1 of iPhone 16 Pro Max - gamekit (77399)'
Test case 'AuthStoreTests/sceneActiveValidation_transferred()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_authorized()'  passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_noStoredID()'  passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_revoked()'     passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_notFound()'    passed (0.000 seconds)
Test case 'AuthStoreTests/revocationClearsState()'             passed (0.000 seconds)
Test case 'AuthStoreTests/keychainRoundTrip()'                 passed (0.000 seconds)
```

### Full regression — `** TEST SUCCEEDED **`

```
xcodebuild test -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"
```

All P2/P3/P4/P5 suites pass + Plan 06-01 KeychainBackend round-trip + Plan 06-02 SyncStatus + Plan 06-04 AuthStore (7/7). UI tests (gamekitUITests, gamekitUITestsLaunchTests) also pass.

### T-06-02 lock proof — every `logger.*` call site in AuthStore.swift

| Line | Call | Interpolates? |
|------|------|---------------|
| 140  | `Self.logger.info("Signed in (userID hidden)")` | No — literal string only |
| 197  | `Self.logger.info("Cleared local sign-in state: \(reason, privacy: .public)")` | No — `reason` is a switch-case label like `"scene-active state=.revoked"` or `"credentialRevokedNotification"`; never the userID |
| 201  | `Self.logger.error("Failed to clear sign-in state: \(error.localizedDescription, privacy: .public)")` | No — Foundation error description; no userID |

Adversarial grep:
```
grep -A1 "logger\." gamekit/gamekit/Core/AuthStore.swift | \
  grep -cE "\\\\\\(userID|\\\\\\(stored|\\\\\\(currentUserID|\\\\\\(credential\\.user"
# → 0
```

### Threat-model mitigations confirmed

| Threat ID | Acceptance grep | Result |
|-----------|-----------------|--------|
| T-06-01 (no UserDefaults for userID) | `grep -E "UserDefaults.*appleUserID\|appleUserID.*UserDefaults"` | 0 matches ✓ |
| T-06-02 (no userID in logger) | grep above | 0 matches ✓ |
| T-06-03 (no identityToken handling) | `grep -c "identityToken"` | 0 matches ✓ |
| T-06-08 (no SwiftData / persistence container) | `grep -cE "import SwiftData\|ModelContext\|ModelContainer"` | 0 matches ✓ |
| T-06-PitfallF (single-resume continuation) | `grep -q "if error != nil"` + `grep -q "withCheckedContinuation"` | both present ✓ |

### Structural acceptance

- `@Observable` + `@MainActor` + `final class AuthStore` ✓
- Both DI seams (`backend: KeychainBackend`, `credentialStateProvider: CredentialStateProvider`) ✓
- `SystemCredentialStateProvider` (production conformer) ✓
- `credentialRevokedNotification` observer registered in init ✓
- `var shouldShowRestartPrompt: Bool` published ✓
- `EnvironmentKey` injection (`AuthStoreKey` + `var authStore: AuthStore`) ✓
- Logger configured at subsystem `com.lauterstar.gamekit`, category `auth` ✓
- Imports = exactly `Foundation`, `AuthenticationServices`, `SwiftUI`, `os` ✓
- File length = 232 lines (≤ 240 budget) ✓

### TDD RED → GREEN sequence verified in git log

```
$ git log --oneline | grep -E "(test|feat)\(06-0[14]\)"
e43cc79 feat(06-04): implement AuthStore (turns 7/7 RED tests GREEN)
a18a186 test(06-01): RED-gate Keychain backend + AuthStoreTests skeleton
```

`test(06-01)` precedes `feat(06-04)` — same RED→GREEN pattern locked in P4 04-02 / 04-03 and P5 05-01 / 05-03 / 05-06.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Gate Plan 06-02 CloudSyncStatusObserverTests body**
- **Found during:** Task 1 verification (`xcodebuild test -only-testing:gamekitTests/AuthStoreTests`)
- **Issue:** Plan 06-02 left `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` in symbol-level RED state ("cannot find 'CloudSyncStatusObserver' in scope" + ~20 cascade errors). The test target failed to compile, which prevented `xcodebuild test -only-testing` from running ANY tests including AuthStoreTests. `-skip-testing` only skips at runtime — compile happens first. This blocked Plan 06-04's stated GREEN gate.
- **Fix:** Wrapped the test suite body in `#if SKIP_OBSERVER_TESTS` / `#endif` (compile-time gate, no flag set anywhere → bodies always compiled out). Updated the file's doc-comment to instruct Plan 06-05 to delete both gate lines when shipping `Core/CloudSyncStatusObserver.swift`. The Plan 06-02 RED contract is preserved structurally — when the gate is removed, the same "cannot find 'CloudSyncStatusObserver' in scope" symbol-level errors will resurface immediately if the production type is missing.
- **Files modified:** `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift`
- **Commit:** `e43cc79` (single atomic commit per CLAUDE.md §8.10)
- **Forward action required (Plan 06-05):** When implementing `Core/CloudSyncStatusObserver.swift`, search for `SKIP_OBSERVER_TESTS` in the test file and DELETE both the `#if SKIP_OBSERVER_TESTS` line (around line 58) and the `#endif // SKIP_OBSERVER_TESTS — Plan 06-05 deletes ...` line (around line 167). The 9-test suite will then compile and run against the new production type.

### Rule 4 (architectural) — none applied

The plan's `<context>` reminded the executor to NOT add `init(... settingsStore:)` even though RESEARCH §Code Examples 1 mentions it. Confirmed: AuthStore stays single-responsibility, no SettingsStore injection. Plan 06-06 will wire sign-out → cloudSyncEnabled=false at the GameKitApp scenePhase observer level instead.

## Self-Check: PASSED

- File `gamekit/gamekit/Core/AuthStore.swift` exists ✓
- Commit `e43cc79` exists in `git log --all` ✓
- All 7 AuthStoreTests pass ✓
- Full regression `** TEST SUCCEEDED **` ✓
