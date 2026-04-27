---
phase: 06-cloudkit-siwa
plan: 01
subsystem: auth-keychain-tdd
tags: [keychain, tdd, wave-0, auth, sc2-lock]
requirements:
  completed: [PERSIST-04]
dependency_graph:
  requires:
    - "Phase 4 — InMemoryStatsContainer test-helper pattern (P4 D-31 analog)"
    - "Phase 4 — @testable import gamekit precedent (multiple suites)"
    - "Phase 5 — Swift Testing @Suite + per-test-isolation idiom (SettingsStoreFlagsTests)"
  provides:
    - "protocol KeychainBackend (Sendable seam for Plan 06-04 AuthStore DI)"
    - "@MainActor final class SystemKeychainBackend (production Keychain wrapper, SC2 verbatim)"
    - "enum KeychainError (writeFailed/deleteFailed OSStatus carriers)"
    - "InMemoryKeychainBackend (test-target-only dict stub)"
    - "AuthStoreTests RED skeleton (locks 7-test API surface for Plan 06-04)"
  affects:
    - "Plan 06-04 (AuthStore): tests already written + locked API surface"
    - "Plan 06-04 commit gate: feat(06-04) MUST flip 8× 'cannot find AuthStore' errors GREEN"
tech_stack:
  added:
    - Security framework (kSecClass, SecItemAdd/CopyMatching/Delete)
    - AuthenticationServices (test-only, for revocation Notification.Name + CredentialState type)
  patterns:
    - "Protocol seam D-16 (production + test-stub pair) — directly mirrors P4 InMemoryStatsContainer"
    - "Idempotent delete-before-add write — T-06-09 DoS mitigation"
    - "TDD RED-gate plan precedent — same shape as 04-02 (GameStats), 04-03 (StatsExporter), 05-01/05-03/05-06"
key_files:
  created:
    - gamekit/gamekit/Core/KeychainBackend.swift
    - gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift
    - gamekit/gamekitTests/Core/AuthStoreTests.swift
  modified: []
decisions:
  - "TDD RED gate uses ONE atomic commit (test(06-01)) per plan §verification + CLAUDE.md §8.10 — the 3 files form one coherent RED-gate batch (P4 04-02 RED-precedent)"
  - "SystemKeychainBackend is @MainActor final class (RESEARCH §Pattern 3 + PATTERNS §4) — consistent with Core/SFXPlayer + Core/SettingsStore main-actor isolation"
  - "Idempotent write via try? delete BEFORE SecItemAdd (RESEARCH lines 421-423) — T-06-09 errSecDuplicateItem mitigation as a structural property, not a try/catch fallback"
  - "delete(account:) treats errSecSuccess AND errSecItemNotFound as non-throwing — AuthStore revocation handler requires non-fatal delete for D-13 contract"
  - "Doc-comments in KeychainBackend.swift refer to the test stub indirectly (no literal InMemoryKeychainBackend symbol) — preserves T-06-W-test-leak negative grep gate"
  - "Test file's first compile error references CredentialStateProvider (line 57) before AuthStore (line 78) — both symbols are part of the locked Plan 06-04 API surface; the broader plan acceptance pattern matches 'Cannot find type AuthStore' which fires 8× in subsequent errors"
metrics:
  duration_minutes: 5
  completed_date: 2026-04-27
  tasks_completed: 3
  files_created: 3
  files_modified: 0
  commit_hash: a18a186
---

# Phase 06 Plan 01: Keychain Backend RED-Gate Summary

**One-liner:** TDD RED-gate Wave-0 deliverable — `KeychainBackend` protocol seam + verbatim-SC2 `SystemKeychainBackend` + in-memory test stub + 7-test `AuthStoreTests` skeleton compile-failing with `cannot find 'AuthStore' in scope` until Plan 06-04 ships AuthStore.swift.

## Outcome

3 new Swift files committed atomically as `test(06-01): RED-gate Keychain backend + AuthStoreTests skeleton` (commit `a18a186`). Production target builds clean. Test target fails-to-compile with the intended TDD gate error message (8× `cannot find 'AuthStore' in scope` + 1× `cannot find type 'CredentialStateProvider' in scope`). Plan 06-04's `feat(06-04)` commit will flip all 9 errors GREEN.

## Files Shipped

| File | Lines | Cap | Target | Role |
|------|-------|-----|--------|------|
| `gamekit/gamekit/Core/KeychainBackend.swift` | 126 | ≤130 | production | protocol + KeychainError + @MainActor SystemKeychainBackend |
| `gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift` | 30 | ≤35 | tests only | in-memory dict stub mirroring InMemoryStatsContainer (P4 D-31) |
| `gamekit/gamekitTests/Core/AuthStoreTests.swift` | 190 | ≤200 | tests only | @Suite("AuthStore") + 7 @Test methods + StubCredentialStateProvider |

## SC2 Verbatim Lock — Keychain Attribute Set Shipped

The Keychain attribute set in `SystemKeychainBackend.write(_:account:)` is verbatim per CONTEXT line 202 + Pitfall 5 + SC2:

```swift
let attrs: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: Self.serviceName,                  // "com.lauterstar.gamekit.auth"
    kSecAttrAccount as String: account,                           // AuthStore passes "appleUserID"
    kSecValueData as String: Data(value.utf8),
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
]
```

**T-06-01 mitigation proof:** `grep -q "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly" gamekit/gamekit/Core/KeychainBackend.swift` returns hit. No alternate accessibility class anywhere in the file (no `kSecAttrAccessibleAlways`, no `kSecAttrAccessibleAfterFirstUnlock` without the `ThisDeviceOnly` suffix).

**T-06-06 mitigation proof:** `static let serviceName = "com.lauterstar.gamekit.auth"` is a single source-of-truth — typo trips lookup but cannot corrupt user data. Plan 06-04 round-trip suite will smoke-test it.

**T-06-09 mitigation proof:** `try? delete(account:)` is the first statement inside `write(_:account:)`. `errSecDuplicateItem` failure class is structurally avoided — never reaches the SecItemAdd guard.

**T-06-W-test-leak mitigation proof:** `grep -r "InMemoryKeychainBackend" gamekit/gamekit/ 2>/dev/null` returns ZERO hits. The doc-comments in `KeychainBackend.swift` refer to the test stub via wording ("an in-memory test stub (test target only)") rather than the literal symbol name to keep the negative grep audit clean.

## TDD RED-Gate Compile Error (verbatim from xcodebuild)

```
gamekitTests/Core/AuthStoreTests.swift:57:42: error: cannot find type 'CredentialStateProvider' in scope
gamekitTests/Core/AuthStoreTests.swift:78:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:85:22: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:98:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:121:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:136:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:151:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:166:21: error: cannot find 'AuthStore' in scope
gamekitTests/Core/AuthStoreTests.swift:180:21: error: cannot find 'AuthStore' in scope
** TEST FAILED **
```

This is the intended RED state. Plan 06-04 ships:
1. `protocol CredentialStateProvider: Sendable` (closes the line-57 error)
2. `final class AuthStore` with `init(backend:credentialStateProvider:)` (closes the 8× line-{78,85,98,121,136,151,166,180} errors)
3. `func signIn(userID:) throws`, `var currentUserID: String?`, `var isSignedIn: Bool`, `func validateOnSceneActive() async`, `clearForTesting()` #if DEBUG seam — all already exercised in the tests above
4. NotificationCenter `credentialRevokedNotification` observer in `init` clearing state synchronously on the main actor

After Plan 06-04: `xcodebuild test -only-testing:gamekitTests/AuthStoreTests` runs all 7 tests GREEN.

## Locked AuthStore API Surface (consumed by AuthStoreTests, Plan 06-04 must ship)

```swift
@Observable @MainActor
final class AuthStore {
    init(backend: KeychainBackend = SystemKeychainBackend(),
         credentialStateProvider: CredentialStateProvider = ...)
    var isSignedIn: Bool { get }              // computed via backend
    var currentUserID: String? { get }        // computed via backend
    func signIn(userID: String) throws        // writes Keychain
    func validateOnSceneActive() async        // calls credentialStateProvider; clears on revoked/notFound/transferred
    var shouldShowRestartPrompt: Bool { get set }   // settable per RESEARCH lines 678-683 + PATTERNS §9
    #if DEBUG
    func clearForTesting()                    // test isolation seam
    #endif
}

protocol CredentialStateProvider: Sendable {
    func getCredentialState(forUserID: String) async -> ASAuthorizationAppleIDProvider.CredentialState
}
```

The 7 `@Test` methods enumerated in AuthStoreTests.swift cover:
- T1 `keychainRoundTrip` — `signIn` writes, `currentUserID` reads back, re-instantiation persists, `clearForTesting()` clears (D-16 protocol-seam round-trip)
- T2 `revocationClearsState` — synchronous post of `credentialRevokedNotification` clears state immediately (D-13)
- T3 `sceneActiveValidation_authorized` — `.authorized` preserves state (D-14 no-op path)
- T4 `sceneActiveValidation_revoked` — `.revoked` clears state (D-14)
- T5 `sceneActiveValidation_notFound` — `.notFound` clears state (D-14)
- T6 `sceneActiveValidation_transferred` — `.transferred` clears state (D-14 defensive default)
- T7 `sceneActiveValidation_noStoredID` — early-return when Keychain empty; `stub.callCount == 0` (D-15 reinstall path)

## Acceptance Criteria — All Pass

### Task 1 (KeychainBackend.swift)
- [x] File exists
- [x] Contains `protocol KeychainBackend: Sendable`
- [x] Contains `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- [x] Contains `kSecClassGenericPassword`
- [x] Contains `com.lauterstar.gamekit.auth`
- [x] Contains `@MainActor` AND `final class SystemKeychainBackend`
- [x] Contains `case writeFailed(status: OSStatus)`
- [x] Contains `try? delete` (idempotent-write pattern)
- [x] File length 126 ≤ 130 lines
- [x] Production target builds clean (`** BUILD SUCCEEDED **`)

### Task 2 (InMemoryKeychainBackend.swift)
- [x] File exists
- [x] Contains `@testable import gamekit`
- [x] Contains `final class InMemoryKeychainBackend: KeychainBackend`
- [x] Contains `private var store: [String: String] = [:]`
- [x] Test-target-only placement: `grep -r "InMemoryKeychainBackend" gamekit/gamekit/` returns ZERO hits
- [x] File length 30 ≤ 35 lines

### Task 3 (AuthStoreTests.swift)
- [x] File exists
- [x] Contains `@Suite("AuthStore")`
- [x] Contains `@testable import gamekit`
- [x] Contains `import AuthenticationServices`
- [x] Contains all 7 `@Test func` names (verified via shell loop)
- [x] Contains `ASAuthorizationAppleIDProvider.credentialRevokedNotification`
- [x] Contains `StubCredentialStateProvider`
- [x] Contains `InMemoryKeychainBackend`
- [x] **TDD RED gate**: `xcodebuild test` fails with `cannot find 'AuthStore' in scope` (8× hits)
- [x] File length 190 ≤ 200 lines

## Plan-Level Verification

- [x] Production target builds clean — `xcodebuild build -scheme gamekit ...` returns `** BUILD SUCCEEDED **`
- [x] AuthStoreTests fails to build with `Cannot find type 'AuthStore' in scope` — TDD RED gate confirmed
- [x] All three files committed in single atomic commit `test(06-01): RED-gate Keychain backend + AuthStoreTests skeleton` (`a18a186`) per CLAUDE.md §8.10
- [x] Plan 06-04 will reverse the build error in its `feat(06-04)` commit

## Deviations from Plan

**One micro-deviation tracked:** Initial draft of `KeychainBackend.swift` referred to `InMemoryKeychainBackend` by literal symbol name in three doc-comment locations (file-level prose + invariant bullet + protocol doc-string). The Task 2 acceptance criterion runs a strict negative grep (`! grep -r "InMemoryKeychainBackend" gamekit/gamekit/`) which would have failed. **Rule 1 fix applied inline:** rewrote the three comments to refer to "an in-memory test stub (test target only)" / "the in-memory test stub" — substantively identical documentation, satisfies the T-06-W-test-leak grep audit. No behavior change. No new commit (fix landed before the staging step). Tracked here for traceability.

Otherwise: **plan executed exactly as written.** Tasks 1-3 followed the verbatim Swift snippets from RESEARCH §Pattern 3 + PATTERNS §4-§6 with no scope drift. Single atomic commit per plan §verification (NOT per-task commits) is the planner-specified strategy and matches CLAUDE.md §8.10 grouped-batch interpretation.

## TDD Gate Compliance

This plan ships a TDD RED-gate atomic commit (`test(06-01): ...`). The corresponding GREEN commit (`feat(06-04): ...`) lands in Plan 06-04 and turns the 9 compile errors GREEN. The plan-level frontmatter `type: execute` (not `type: tdd`), but each task is `tdd="true"`; the plan-level RED→GREEN gate sequence pairs with Plan 06-04's GREEN commit per CONTEXT D-13/D-14/D-16 contract.

Verifiable in git log after Plan 06-04 ships:
```
git log --oneline | grep -E "06-01|06-04"
# expected:
# <hash> feat(06-04): implement AuthStore  ← GREEN gate
# a18a186 test(06-01): RED-gate Keychain backend + AuthStoreTests skeleton  ← THIS commit
```

## Self-Check: PASSED

- [x] `gamekit/gamekit/Core/KeychainBackend.swift` exists (126 lines)
- [x] `gamekit/gamekitTests/Helpers/InMemoryKeychainBackend.swift` exists (30 lines)
- [x] `gamekit/gamekitTests/Core/AuthStoreTests.swift` exists (190 lines)
- [x] Commit `a18a186` reachable in `git log --oneline`
- [x] Production build SUCCEEDED
- [x] TDD RED gate fires expected error 9× (1 CredentialStateProvider + 8 AuthStore)
- [x] Zero `InMemoryKeychainBackend` hits in production sources
