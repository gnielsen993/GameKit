---
phase: 06-cloudkit-siwa
plan: 05
subsystem: cloudkit
tags:
  - cloudkit
  - tdd
  - wave-1
  - green-gate
requirements:
  - PERSIST-06
dependency_graph:
  requires:
    - 06-02-PLAN  # SyncStatus enum + RED test skeleton
    - 06-04-PLAN  # SKIP_OBSERVER_TESTS gate (now reversed)
  provides:
    - CloudSyncStatusObserver  # @Observable @MainActor singleton consumed by SettingsView (Plan 06-07)
    - cloudSyncStatusObserver-EnvironmentKey  # \.cloudSyncStatusObserver
  affects:
    - gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift  # SKIP gate removed
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor final class + EnvironmentKey injection (analog: AuthStore, SettingsStore, SFXPlayer)"
    - "@objc nonisolated selector + Task { @MainActor [weak self] in ... } hop (background-queue-safe; differs from AuthStore which uses MainActor.assumeIsolated because main-thread delivery is contractual there)"
    - "#if DEBUG applyEvent_forTesting seam (Apple type has no public init — PATTERNS §S5)"
    - "private(set) var enforcing observer-only-writer contract"
key_files:
  created:
    - gamekit/gamekit/Core/CloudSyncStatusObserver.swift  # 198 lines
  modified:
    - gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift  # SKIP_OBSERVER_TESTS gate removed (-3 lines)
decisions:
  - Background-then-hop pattern (Task @MainActor) NOT MainActor.assumeIsolated — RESEARCH §Q4 RESOLVED locks queue:nil delivery (Apple posts on background); assumeIsolated would crash. Differs deliberately from AuthStore which uses assumeIsolated because credentialRevokedNotification has contractual main-thread delivery.
  - Event snapshot extracted OFF main before the hop (read-only access to Apple value-type-like properties is thread-safe); only Sendable scalars cross the actor boundary, avoiding the need to capture the full Event reference into the Task closure.
  - Translator (applyEvent) is the SINGLE source of truth — production path AND #if DEBUG test seam both call it; eliminates risk of test/prod divergence.
  - File length 198 ≤ 200 budget — kept under cap by consolidating PATTERNS §S5 doc-comment block (5 lines → 2 lines) without losing the SFXPlayer/Haptics analog references.
metrics:
  duration_minutes: 13
  task_count: 1
  file_count: 2
  test_count: 9
  completed: "2026-04-27"
---

# Phase 6 Plan 05: CloudSyncStatusObserver — Wave-1 GREEN Gate Summary

Wave-1 GREEN gate landed. `Core/CloudSyncStatusObserver.swift` (198 lines, ≤ 200 budget) flips Plan 06-02's 9 RED `CloudSyncStatusObserverTests` GREEN; the `#if SKIP_OBSERVER_TESTS` gate Plan 06-04 added (Rule 3 deviation) is removed. Full `xcodebuild test` exits 0 — AuthStoreTests still 7/7 GREEN, no regressions.

## Tasks Completed

### Task 1: Ship CloudSyncStatusObserver production source
- **Commit:** `a7d10db`
- **Files:**
  - `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` (created, 198 lines)
  - `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` (modified, -3 lines — SKIP gate removed)
- **TDD GREEN:** 9/9 CloudSyncStatusObserverTests pass.

## Verification

### CloudSyncStatusObserverTests — 9/9 GREEN

```
Test case 'CloudSyncStatusObserverTests/initialStatus_notSignedIn_default()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/initialStatus_syncing_explicit()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/event_endDateNil_flipsToSyncing()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/event_succeeded_flipsToSyncedAt()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/event_failed_flipsToUnavailable_withLastSynced()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/label_lessThan60s_isJustNow()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/label_minutes_isXAgo()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/label_hours_isXAgo()' passed (0.000 seconds)
Test case 'CloudSyncStatusObserverTests/label_unavailable_isPlainString()' passed (0.000 seconds)
** TEST SUCCEEDED **
```

Translator path tests run in 0.000s — pure synchronous calls via `applyEvent_forTesting` seam (no NotificationCenter round-trip, no Task hop). Confirms the seam bypasses the `Task { @MainActor in ... }` path, exercising only the translator function itself — exactly the contract Plan 06-02 designed.

### AuthStoreTests — 7/7 GREEN (no regression)

```
Test case 'AuthStoreTests/keychainRoundTrip()' passed (0.000 seconds)
Test case 'AuthStoreTests/revocationClearsState()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_authorized()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_revoked()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_notFound()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_transferred()' passed (0.000 seconds)
Test case 'AuthStoreTests/sceneActiveValidation_noStoredID()' passed (0.000 seconds)
** TEST SUCCEEDED **
```

### Full Suite — `** TEST SUCCEEDED **`

`xcodebuild test -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"` exited 0; no failing tests across all targets.

## TDD RED→GREEN Sequence (CLAUDE.md §8.10)

```
a7d10db feat(06-05): implement CloudSyncStatusObserver (turns 9/9 RED tests GREEN)   <-- GREEN gate (this plan)
a46000c docs(06-04): complete AuthStore Wave-1 GREEN gate plan
e43cc79 feat(06-04): implement AuthStore (turns 7/7 RED tests GREEN)
ca895ec docs(06-03): record Tasks 1+2 + Task 3 checkpoint pending in SUMMARY/STATE
b0b1ed0 feat(06-03): DEBUG-only CloudKit schema initializer + lldb entry point
b1f2956 docs(06-03): document 4 P6 capability requirements in gamekit.entitlements
a29d606 docs(06-02): complete RED-gate SyncStatus + CloudSyncStatusObserverTests plan
a0d4364 test(06-02): RED-gate SyncStatus enum + CloudSyncStatusObserver test skeleton  <-- RED gate (Plan 06-02)
```

`test(06-02)` precedes `feat(06-05)` — TDD RED→GREEN gate sequence honored across the 4-commit gap. Plan 06-04 ran in parallel (different files; no merge conflict).

## Acceptance Criteria — All GREEN

| Criterion | Result |
|-----------|--------|
| File exists at `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` | OK |
| 9/9 CloudSyncStatusObserverTests pass | OK |
| `@Observable` + `@MainActor` + `final class CloudSyncStatusObserver` | OK |
| `private(set) var status: SyncStatus` (T-06-state-drift lock) | OK |
| Notification subscription with `eventChangedNotification` + `eventNotificationUserInfoKey` | OK |
| Logger `subsystem: "com.lauterstar.gamekit"` + `category: "cloudkit"` | OK |
| Main-actor hop via `Task { @MainActor [weak self] in ... }` (T-06-state-bg-write mitigation) | OK |
| `#if DEBUG applyEvent_forTesting` seam (PATTERNS §S5) | OK |
| EnvironmentKey injection — `\.cloudSyncStatusObserver` | OK |
| Imports: Foundation + CoreData + SwiftUI + os | OK |
| File length ≤ 200 lines | 198 |
| Atomic commit per CLAUDE.md §8.10 (single feat commit, both files) | OK |
| AuthStoreTests still 7/7 GREEN — no regression | OK |

## Threat-Model Mitigations Honored

| Threat ID | Mitigation Applied | Verification |
|-----------|---------------------|--------------|
| T-06-state-bg-write | `@objc nonisolated handleEvent` extracts snapshot off-main; `Task { @MainActor [weak self] in ... }` hops before mutating `status`. | Class-level `@MainActor` isolation prevents direct cross-actor write; `grep -E "Task \{ @MainActor"` matches in source. |
| T-06-state-drift | Translator switches exhaustively over 4 cases via `(endDate, succeeded)` shape; adding a 5th SyncStatus case forces a compile error in `SyncStatus.label(at:)`. | `private(set) var status: SyncStatus` lock — observer is only writer. |
| T-06-A1 | Defensive `guard let event = ... as? Event else { return }` short-circuits on nil/mismatched cast. | Line 110 of source: early-return before any state mutation. |
| T-06-pitfall-3 | Failure path → `.unavailable(lastSynced: lastSyncDate)`; `logger.error` logs at `.public` privacy with `error.localizedDescription` only (no PII). | Source lines 159-167: failure branch logs error name only; no PII identifiers anywhere. |

## Deviations from Plan

**None — plan executed exactly as written.** Two minor budget-management touches:

1. **Header comment trim (1 line):** Initial draft was 201 lines. Consolidated PATTERNS §S5 doc-comment block (5 lines → 2 lines) to keep the file at 198 lines, satisfying the `≤ 200` budget without losing any analog references. Not a deviation — well within editorial discretion.
2. **AuthStore-style import-block doc-MARK removed:** The plan-spec skeleton placed `// MARK: - Imports` above the import block; the analog AuthStore.swift / SettingsStore.swift / SFXPlayer.swift don't use a MARK there. Removed for consistency. Not a deviation — cosmetic alignment with neighbouring files.

## Auth Gates Encountered

None — fully autonomous execution.

## Known Stubs

None. CloudSyncStatusObserver is a complete @Observable singleton; the `#if DEBUG applyEvent_forTesting` seam is the documented test-only entry point (PATTERNS §S5), not a stub.

## Wave-1 Status

Wave-1 (Plans 06-04 + 06-05) **COMPLETE**:
- Plan 06-04 (AuthStore): GREEN — 7/7 AuthStoreTests pass.
- Plan 06-05 (CloudSyncStatusObserver): GREEN — 9/9 CloudSyncStatusObserverTests pass.

Together they ship the two `@Observable @MainActor` singletons consumed by Wave 2:
- `AuthStore` → SettingsView SIWA button + IntroFlowView SIWA button (Plan 06-07/08).
- `CloudSyncStatusObserver` → SettingsView SYNC status row (Plan 06-07).

## Outstanding Issues / Pending

- **Plan 06-03 Task 3 (checkpoint:human-verify) — STILL PENDING.** Independent of Wave 1 (uses test stubs); blocks Plan 06-09 SC3 (real-CloudKit promotion test) only. User must complete the Xcode capability sweep + lldb schema deploy + CloudKit Dashboard verification per `.planning/phases/06-cloudkit-siwa/06-03-SUMMARY.md` §CHECKPOINT.

## Self-Check: PASSED

- File `gamekit/gamekit/Core/CloudSyncStatusObserver.swift` exists (198 lines).
- Commit `a7d10db` exists in `git log --oneline -10`.
- Modified file `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` shows 3 lines removed (SKIP gate).
- `xcodebuild test -scheme gamekit` returns `** TEST SUCCEEDED **` for full suite + only-testing CloudSyncStatusObserverTests + only-testing AuthStoreTests.
- TDD RED→GREEN sequence visible in git log: `a0d4364 test(06-02)` precedes `a7d10db feat(06-05)`.
