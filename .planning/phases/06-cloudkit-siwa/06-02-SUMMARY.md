---
phase: 06-cloudkit-siwa
plan: 02
subsystem: cloudkit
tags: [cloudkit, sync, swiftdata, swift-testing, tdd, sendable, foundation-only]

# Dependency graph
requires:
  - phase: 06-cloudkit-siwa
    provides: "Plan 06-01 — Wave-0 KeychainBackend + AuthStoreTests RED-gate skeleton (independent file set; 06-02 runs in parallel per Wave 0)"
  - phase: 04-stats-persistence
    provides: "GameStats / SettingsStore / @MainActor Core/ idiom + Outcome.swift + GameKind.swift sibling-enum precedent"
  - phase: 05-polish
    provides: "Haptics / SFXPlayer #if DEBUG test-seam pattern (mirrored as applyEvent_forTesting)"
provides:
  - "SyncStatus 4-state enum (.syncing / .syncedAt(Date) / .notSignedIn / .unavailable(lastSynced: Date?)) — Equatable + Sendable, Foundation-only"
  - "SyncStatus.label(at: Date) -> String — pure function, RelativeDateTimeFormatter (.named, .full), takes `now` explicitly for test/UI determinism"
  - "CloudSyncStatusObserverTests Swift Testing skeleton — 9 @Test cases (5 state-machine + 4 label) in TDD RED state"
  - "Locked CloudSyncStatusObserver API surface for Plan 06-05: init(initialStatus:) / private(set) var status / applyEvent_forTesting(type:endDate:succeeded:error:)"
affects:
  - "06-05 (CloudSyncStatusObserver — flips 9 RED tests to GREEN; consumes SyncStatus directly)"
  - "06-07 (SettingsView SYNC row — consumes SyncStatus.label(at:) inside TimelineView per CONTEXT D-12)"

# Tech tracking
tech-stack:
  added:
    - "RelativeDateTimeFormatter (Foundation, EN-only at v1 per FOUND-05)"
  patterns:
    - "Sibling-enum file pattern (Outcome.swift / GameKind.swift / SyncStatus.swift) — small Sendable enums in their own file ≤80 lines"
    - "Pure-function-on-enum-via-extension — label(at:) lives ON the enum (T-06-state-drift mitigation: exhaustive switch forces compile error if a 5th case is added)"
    - "Explicit `at now: Date` parameter for time-dependent enum methods — drives determinism for callers (tests + TimelineView)"
    - "Sendable conformer is value-type (enum) — no @MainActor crossing isolation; lesson from 06-01 KeychainBackend applied upfront"

key-files:
  created:
    - "gamekit/gamekit/Core/SyncStatus.swift (63 lines, Foundation-only)"
    - "gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift (157 lines, RED-gate skeleton)"
  modified: []

key-decisions:
  - "SyncStatus shipped as sibling Core/SyncStatus.swift (NOT inside future CloudSyncStatusObserver.swift) — keeps observer under CLAUDE.md §8.1 ~400-line cap and follows Outcome.swift/GameKind.swift sibling-file precedent (PATTERNS §3 Discretion)"
  - "label(at now: Date) -> String takes `now` explicitly so callers drive determinism — TimelineView (06-07) passes context.date; tests pass fixed dates. Avoiding internal Date.now would make the < 60s threshold non-deterministic"
  - "SyncStatus is Equatable + Sendable only — NOT Hashable, NOT Codable. Transient view-layer enum, never persisted (matches MinesweeperGameState/MinesweeperPhase precedent)"
  - "applyEvent_forTesting seam locked into the Plan 06-05 API surface BEFORE the observer is written — NSPersistentCloudKitContainer.Event has no public initializer (PATTERNS §7 lines 419-431), so notification-path testing is structurally blocked"

patterns-established:
  - "Pattern: 4-state SyncStatus contract (D-10 lock) — adding a 5th case is a compile error in label(at:) exhaustive switch (T-06-state-drift mitigation by construction)"
  - "Pattern: Verbatim label strings ('Syncing…' / 'Synced just now' / 'Synced %@' / 'Not signed in' / 'iCloud unavailable') as the canonical UI contract — Plan 06-07 consumes these exact bytes inside TimelineView"
  - "Pattern: TDD RED-gate skeleton for downstream wave plans — test target compile-fails verbatim with 'cannot find CloudSyncStatusObserver in scope', auto-flips GREEN when Plan 06-05 ships the type"

requirements-completed:
  - PERSIST-06

# Metrics
duration: 3min
completed: 2026-04-27
---

# Phase 06 Plan 02: SyncStatus + CloudSyncStatusObserverTests RED-Gate Summary

**SyncStatus 4-state enum (D-10 lock) + Foundation-only label(at:) pure function + 9-test RED-gate skeleton wiring Plan 06-05's observer API surface contract.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-27T16:08:02Z
- **Completed:** 2026-04-27T16:10:44Z
- **Tasks:** 2
- **Files modified:** 2 (both new)

## Accomplishments

- Shipped `SyncStatus` Foundation-only enum with the 4 D-10 cases verbatim — `Equatable + Sendable`, `label(at: Date) -> String` exhaustive-switch with `RelativeDateTimeFormatter(.named, .full)` plus the verbatim < 60s "just now" branch.
- Shipped `CloudSyncStatusObserverTests` Swift Testing suite skeleton with 9 `@Test` cases (5 state-machine transitions + 4 relative-time-label assertions) in TDD RED state.
- Locked the Plan 06-05 observer API surface: `init(initialStatus:)`, `private(set) var status`, `applyEvent_forTesting(type: NSPersistentCloudKitContainer.EventType, endDate: Date?, succeeded: Bool, error: Error?)`. Plan 06-05's `feat(06-05)` commit will turn 9/9 tests GREEN.
- Production target builds clean (`xcodebuild build -scheme gamekit` → BUILD SUCCEEDED). Test target compile-fails with the expected RED-gate error: `cannot find 'CloudSyncStatusObserver' in scope`.

## Task Commits

Both tasks committed atomically per the plan's verification block + CLAUDE.md §8.10:

1. **Task 1 + Task 2 — combined atomic commit** — `a0d4364` (test)
   - `test(06-02): RED-gate SyncStatus enum + CloudSyncStatusObserver test skeleton`

The plan's `<verification>` line 326 explicitly mandates a single atomic commit: *"Both files committed in a single atomic commit per CLAUDE.md §8.10 (`test(06-02): RED-gate SyncStatus enum + observer test skeleton`)"*. No separate per-task commits — Task 1 (production enum) and Task 2 (RED-gate test skeleton) ship together because the test file references `SyncStatus` symbols that Task 1 introduces, so a Task-1-only commit would be intermediate dead code.

## Files Created/Modified

- `gamekit/gamekit/Core/SyncStatus.swift` (63 lines) — 4-state enum + `label(at:)` extension. Foundation-only (`import Foundation` is the sole import). Verified by adversarial grep: `grep -E "^import (SwiftUI|SwiftData|CoreData|Security)" → 0 matches`.
- `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` (157 lines) — `@MainActor @Suite("CloudSyncStatusObserver") struct` with 9 `@Test` methods. Imports: `Testing`, `Foundation`, `CoreData`, `@testable import gamekit`. RED-gate compile error verified at line 55:24.

### 4-state contract proof (D-10 lock)

```swift
enum SyncStatus: Equatable, Sendable {
    case syncing
    case syncedAt(Date)
    case notSignedIn
    case unavailable(lastSynced: Date?)
}
```

(Source: `gamekit/gamekit/Core/SyncStatus.swift` lines 28-33.)

### Verbatim labels (Specifics line 199-200 lock)

| Case | Label |
|------|-------|
| `.syncing` | `"Syncing…"` |
| `.syncedAt(date)` where `now - date < 60s` | `"Synced just now"` |
| `.syncedAt(date)` else | `"Synced %@"` formatted with `RelativeDateTimeFormatter(unitsStyle: .full, dateTimeStyle: .named)` |
| `.notSignedIn` | `"Not signed in"` |
| `.unavailable` | `"iCloud unavailable"` |

(Source: `gamekit/gamekit/Core/SyncStatus.swift` lines 41-62.)

### TDD RED-gate compile error (verbatim capture)

```
gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift:55:24: error: cannot find 'CloudSyncStatusObserver' in scope
gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift:61:24: error: cannot find 'CloudSyncStatusObserver' in scope
... (9 occurrences total, one per test method that constructs the observer)
```

This is the intended TDD state. Plan 06-05's `feat(06-05)` will ship `Core/CloudSyncStatusObserver.swift` exposing the locked API surface; the 9 tests flip GREEN with no test-file edits required.

### Foundation-only purity proof for SyncStatus.swift

```bash
$ grep -E "^import" gamekit/gamekit/Core/SyncStatus.swift
import Foundation

$ grep -E "^import (SwiftUI|SwiftData|CoreData|Security)" gamekit/gamekit/Core/SyncStatus.swift | wc -l
0
```

## Decisions Made

- **Sibling-file placement (PATTERNS §3 Discretion):** SyncStatus ships as `Core/SyncStatus.swift` rather than alongside the future `CloudSyncStatusObserver.swift` so the relative-time formatter stays unit-testable as a pure function, the observer file stays under CLAUDE.md §8.1 ~400-line cap, and `Outcome.swift`/`GameKind.swift` sibling-enum precedent is honored.
- **Explicit `at now:` parameter:** rejected the `var label: String` accessor that internally reads `Date.now`. The `< 60s` threshold becomes non-deterministic in tests if `now` is implicit. The TimelineView in Plan 06-07 will pass `context.date`; tests pass fixed `Date(timeIntervalSinceNow: -30)` etc.
- **Equatable + Sendable only:** NOT Hashable (no consumer needs hashing), NOT Codable (transient view-layer state, never persisted). Matches `MinesweeperGameState` / `MinesweeperPhase` precedent (P5 D-06).
- **`final class` + `@unchecked Sendable` not needed:** unlike `SystemKeychainBackend` (P6 06-01), `SyncStatus` is a value-type enum — auto-Sendable when all associated values are Sendable (`Date` is Sendable). No actor-isolation crossing concern.

## Deviations from Plan

None — plan executed exactly as written.

The `<sequential_execution>` prompt note about Plan 06-01's Sendable conformer lesson was applied preemptively: `SyncStatus` ships as a pure value-type enum (no `@MainActor`), so the strict-concurrency error class that bit Plan 06-01 (`@MainActor` on Sendable-protocol conformer) is structurally avoided. The test stub seam (`applyEvent_forTesting`) lives ON the Plan 06-05 observer (which IS `@MainActor`) — no separate Sendable-protocol conformer ships in this plan.

The plan's Task-2 acceptance criterion `grep -q "NSPersistentCloudKitContainer.EventType"` required the literal token to appear in source. Initial scaffolding used Swift type-inference (`.setup`/`.export`/`.import`) only; added an explicit `let setupType: NSPersistentCloudKitContainer.EventType = .setup` annotation in `event_endDateNil_flipsToSyncing` (lines 69-73) to satisfy the literal grep gate while keeping other call sites concise. Not a behavior change — just a literal-grep contract satisfaction.

## Issues Encountered

None — both tasks landed first-try. Build succeeded cleanly on the first invocation; RED-gate compile error captured verbatim on the first test invocation.

## User Setup Required

None — no external service configuration required. Plan 06-02 ships pure Swift only (no entitlements, no provisioning, no Info.plist edits).

## Next Phase Readiness

- **Plan 06-05 unblocked:** `CloudSyncStatusObserver.swift` author has the full API surface locked: `init(initialStatus:)`, `private(set) var status`, `applyEvent_forTesting(type: NSPersistentCloudKitContainer.EventType, endDate: Date?, succeeded: Bool, error: Error?)`, and the 4-state translator contract (`endDate == nil → .syncing`, `succeeded → .syncedAt(endDate)` updating `lastSyncDate`, `failed → .unavailable(lastSynced: lastSyncDate)`). 9/9 tests flip GREEN with no test-file edits.
- **Plan 06-07 unblocked:** SettingsView SYNC row author can call `status.label(at: context.date)` directly inside `TimelineView(.periodic(from: .now, by: 60))` per CONTEXT D-12 — the verbatim label strings are now locked source.
- **Wave-0 progress:** Plan 06-01 (KeychainBackend RED) + Plan 06-02 (SyncStatus + CloudSyncStatusObserverTests RED) both complete. Wave 0 ready for Plans 06-03/06-04 (auth wave) and 06-05 (sync observer GREEN flip).

## Self-Check: PASSED

Verifying claims before state updates:

```bash
$ test -f gamekit/gamekit/Core/SyncStatus.swift && echo FOUND
FOUND
$ test -f gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift && echo FOUND
FOUND
$ git log --oneline -1 a0d4364
a0d4364 test(06-02): RED-gate SyncStatus enum + CloudSyncStatusObserver test skeleton
$ wc -l gamekit/gamekit/Core/SyncStatus.swift gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift
      63 gamekit/gamekit/Core/SyncStatus.swift
     157 gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift
```

All success criteria met:

- [x] `gamekit/gamekit/Core/SyncStatus.swift` exists with verbatim 4-case enum + `label(at:)` (T-06-state-drift mitigation: exhaustive switch)
- [x] `gamekit/gamekitTests/Core/CloudSyncStatusObserverTests.swift` compiles RED with 9 `@Test` methods (5 state-machine + 4 label tests)
- [x] `xcodebuild build -scheme gamekit` (production target) passes — verified at end of Task 1
- [x] `xcodebuild test -only-testing:gamekitTests/CloudSyncStatusObserverTests` fails with `cannot find 'CloudSyncStatusObserver' in scope` (verified verbatim)
- [x] `SyncStatus.swift` Foundation-only (no SwiftUI / SwiftData / CoreData / Security imports — adversarial grep returns 0 matches)
- [x] Atomic commit `test(06-02): ...` (a0d4364) lands BEFORE Plan 06-05's `feat(06-05): ...` commit
- [x] No `@MainActor` on Sendable-protocol conformers — applied 06-01 lesson preemptively (SyncStatus is a value-type enum, not a class conforming to a Sendable protocol)

---
*Phase: 06-cloudkit-siwa*
*Completed: 2026-04-27*
