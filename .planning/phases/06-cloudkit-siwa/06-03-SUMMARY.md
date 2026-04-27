---
phase: 06-cloudkit-siwa
plan: 03
subsystem: capabilities
tags:
  - capabilities
  - cloudkit-dashboard
  - blocking
  - wave-0
  - checkpoint-pending
status: checkpoint-awaiting-user-verification
requires:
  - PERSIST-04
  - PERSIST-06
provides:
  - "DEBUG-only CloudKitSchemaInitializer.deployDevelopmentSchema()"
  - "GameKitApp._runtimeDeployCloudKitSchema() lldb entry point"
  - "gamekit.entitlements 4-capability documentation block (T-06-09)"
affects:
  - gamekit/gamekit/gamekit.entitlements
  - gamekit/gamekit/Core/CloudKitSchemaInitializer.swift
  - gamekit/gamekit/App/GameKitApp.swift
tech-stack:
  added:
    - CoreData (NSPersistentCloudKitContainer / NSPersistentStoreDescription / NSManagedObjectModel)
  patterns:
    - "@MainActor enum static-namespace (matches P2/P4/P5 service pattern)"
    - "#if DEBUG full-file gate (T-06-schema-prod-leak)"
key-files:
  created:
    - gamekit/gamekit/Core/CloudKitSchemaInitializer.swift
  modified:
    - gamekit/gamekit/gamekit.entitlements
    - gamekit/gamekit/App/GameKitApp.swift
decisions:
  - "DEBUG-only schema deploy is a one-shot lldb invocation via GameKitApp._runtimeDeployCloudKitSchema(); no prod entry point, never auto-runs at app launch"
  - "Container literal iCloud.com.lauterstar.gamekit added as 4th canonical site (joining PROJECT.md:141 / GameKitApp.swift:60 / ModelContainerSmokeTests.swift)"
  - "Entitlements file documents 4 P6 capabilities via XML comment; capability registration itself remains in project.pbxproj managed by Xcode UI per CLAUDE.md §8.8"
  - "Release build confirmed green → #if DEBUG strip works; production binary contains zero schema-deploy symbols"
metrics:
  duration_seconds: 161
  duration_minutes: 3
  tasks_completed: 2
  tasks_pending: 1
  files_changed: 3
  completed_date: 2026-04-27
---

# Phase 6 Plan 03: Capabilities Verify + DEBUG Schema Deploy Preflight — Summary

Wave-0 BLOCKING prerequisite for Plan 06-09 SC3 (2-device promotion test): documented the four P6 capabilities the gamekit target must register (Sign in with Apple, iCloud + CloudKit + container iCloud.com.lauterstar.gamekit, iCloud CloudKit Documents, Background Modes → Remote notifications) and shipped a DEBUG-only schema initializer (`CloudKitSchemaInitializer`) plus an lldb entry point (`GameKitApp._runtimeDeployCloudKitSchema()`) so the user can materialize `CD_GameRecord` and `CD_BestTime` record types in the CloudKit Dashboard Development environment.

**Tasks 1+2 shipped autonomously and committed atomically. Task 3 is a `checkpoint:human-verify` and is pending user action — the plan is NOT yet fully complete.**

## Status

**Plan 06-03 status: CHECKPOINT REACHED (awaiting human verification)**

| Task | Type | Status | Commit |
|------|------|--------|--------|
| 1 | auto | complete | `b1f2956` |
| 2 | auto | complete | `b0b1ed0` |
| 3 | checkpoint:human-verify | **awaiting user verification** | — |

## What was shipped

### Task 1 — Entitlements documentation (commit `b1f2956`)
- `gamekit/gamekit/gamekit.entitlements` (29 lines, was 10): added an XML comment block immediately after `<plist version="1.0">` listing the 4 P6 capabilities the gamekit target must register, plus the runtime crash mode if any of #2/#3/#4 are missing (T-06-09).
- Original `com.apple.developer.applesignin = [Default]` entitlement preserved verbatim (P5 D-21).
- `plutil -lint` validates clean.

### Task 2 — DEBUG schema initializer (commit `b0b1ed0`)
- **NEW** `gamekit/gamekit/Core/CloudKitSchemaInitializer.swift` (82 lines, ENTIRE file gated by `#if DEBUG`):
  - `@MainActor enum CloudKitSchemaInitializer`
  - `static func deployDevelopmentSchema() throws` — bridges SwiftData @Model types (`GameRecord.self`, `BestTime.self`) to `NSPersistentCloudKitContainer` via `NSManagedObjectModel.makeManagedObjectModel(for:)`, calls `container.initializeCloudKitSchema()` once, removes the persistent store to release file locks.
  - Container literal `"iCloud.com.lauterstar.gamekit"` matches the 3 existing canonical sites (T-06-06).
- **MODIFIED** `gamekit/gamekit/App/GameKitApp.swift`: appended a DEBUG-only static helper `_runtimeDeployCloudKitSchema()` immediately after `private var preferredScheme`. **`init()` and `body` are byte-identical to pre-plan.**
- Build verified: Debug + Release both succeed on iPhone 16 Pro Max sim (iOS 18.5). Release success proves the `#if DEBUG` strip works — production binary contains zero schema-deploy symbols (T-06-schema-prod-leak mitigated).

## Acceptance criteria

| Criterion | Status |
|-----------|--------|
| Entitlements: `plutil -lint` exits 0 | PASS |
| Entitlements: SIWA entitlement preserved with `Default` value | PASS |
| Entitlements: 4-capability comment block present (Sign in with Apple / iCloud.com.lauterstar.gamekit / Remote notifications / T-06-09) | PASS |
| Entitlements: file ≤ 35 lines (actual: 29) | PASS |
| `Core/CloudKitSchemaInitializer.swift` exists | PASS |
| Single `^#if DEBUG` and single `^#endif` (full-file gate) | PASS |
| Container literal `iCloud.com.lauterstar.gamekit` present | PASS |
| `container.initializeCloudKitSchema()` call present | PASS |
| Both `GameRecord.self` and `BestTime.self` referenced | PASS |
| `GameKitApp._runtimeDeployCloudKitSchema` helper present | PASS |
| `GameKitApp.init()` body unchanged (diff count for `init()` / `sharedContainer = try ModelContainer` lines: 0) | PASS |
| Debug build succeeds | PASS |
| Release build succeeds (proves #if DEBUG strip) | PASS |
| `Core/CloudKitSchemaInitializer.swift` ≤ 90 lines (actual: 82) | PASS |

## Deviations from Plan

None — Tasks 1 + 2 executed exactly as written.

## CHECKPOINT — Task 3 (awaiting human verification)

**Type:** `checkpoint:human-verify` (BLOCKING for Plan 06-09 SC3)

Two steps; both required to clear this checkpoint.

### Step A — Capability verification (T-06-09 mitigation)

1. Open `gamekit/gamekit.xcodeproj` in Xcode.
2. Select the `gamekit` target → **Signing & Capabilities** tab.
3. Confirm ALL FOUR capabilities are present:
   - [ ] **Sign in with Apple** (already shipped P5 D-21)
   - [ ] **iCloud** with CloudKit checked AND container `iCloud.com.lauterstar.gamekit` listed
   - [ ] **iCloud → CloudKit Documents** subitem checked (auto with iCloud + CloudKit)
   - [ ] **Background Modes** with `Remote notifications` checked
4. If any capability is missing, ADD via the `+ Capability` button in Xcode (do NOT hand-edit `project.pbxproj` per CLAUDE.md §8.8). Re-build. Mention which capabilities you added in your resume signal.
5. Confirm Apple Developer Program membership is active at https://developer.apple.com/account (membership lapse → entitlements stop provisioning).

### Step B — Schema deploy (Pitfall D mitigation)

1. Set the active scheme to **Debug**. Build + Run on a real iOS device or the iPhone 16 Pro Max simulator (simulator is OK for schema deploy; only SC3 sync-between-devices needs real iCloud per Pitfall C).
2. Once the app launches, pause execution in Xcode (⌘+Y or the pause button in the debug bar).
3. In the lldb console at the bottom of Xcode, run exactly:

   ```
   expr try? GameKitApp._runtimeDeployCloudKitSchema()
   ```

   Expected output: `(()?) $R0 = 0 values` (success — function returned without throwing) **OR** a thrown error printed to console. Some success runs print `(()?)` with no value; both are GREEN as long as no error appears.
4. Watch the Xcode Console for output. A successful run prints lines including "CloudKit … Initializing schema" and finishes within ~30 seconds. An error run prints a thrown NSError with a message — copy that error verbatim into the resume signal.
5. Open https://icloud.developer.apple.com/dashboard/ → select container `iCloud.com.lauterstar.gamekit` → switch environment to **Development** → **Schema** → **Record Types** panel.
6. Confirm BOTH record types appear: `CD_GameRecord` and `CD_BestTime`. (`CD_` prefix is auto-added by SwiftData/CoreData.)
7. While in the Schema panel, also note whether `gameKindRaw` appears as a queryable index on `CD_GameRecord` (P4 GameStats predicate captures it; required for SC3).
8. If only one or zero record types appear: schema deploy is incomplete. Re-run Step B.3 once more. If still incomplete, surface as a Plan 06-03 BLOCKER.

### What this gates

Plan 06-09 SC3 (the 2-device 50-game promotion test). Without record types in CloudKit Dashboard, sync fires `setupEvent → errorEvent` with "schema not found" forever and the SC3 test cannot succeed.

### Resume signal — type one of:

- `approved — capabilities all present + schema deployed; CD_GameRecord + CD_BestTime visible in CloudKit Dashboard Development; gameKindRaw queryable index present`
- `approved with note — added [capability name(s)]; schema deployed cleanly; CD_GameRecord + CD_BestTime visible`
- `blocked: capability [name] missing and cannot be added — Apple Developer Program / Team Identifier issue`
- `blocked: schema deploy threw [error verbatim from lldb / Xcode Console]`
- `blocked: CloudKit Dashboard shows [N record types vs expected 2] — [observation]`

The orchestrator will resolve the checkpoint after the user reports back, then re-spawn an executor (or the verifier) to mark plan 06-03 fully complete in STATE.md.

## Self-Check

- [x] `gamekit/gamekit/gamekit.entitlements` — modified, validated as plist, contains 4-capability lock comment.
- [x] `gamekit/gamekit/Core/CloudKitSchemaInitializer.swift` — created, DEBUG-gated, 82 lines.
- [x] `gamekit/gamekit/App/GameKitApp.swift` — modified additively (helper at tail of struct only).
- [x] Commit `b1f2956` (Task 1) verified in `git log`.
- [x] Commit `b0b1ed0` (Task 2) verified in `git log`.
- [x] Debug build PASS.
- [x] Release build PASS.

## Self-Check: PASSED (Tasks 1+2)

Task 3 is a human-verify checkpoint — execution paused until user resume signal. Plan 06-03 is NOT marked fully complete in STATE.md; current-plan counter remains at 03 with status `checkpoint reached`.
