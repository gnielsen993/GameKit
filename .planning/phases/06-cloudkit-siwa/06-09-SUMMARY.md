---
phase: 06-cloudkit-siwa
plan: 09
subsystem: verification
tags:
  - verification
  - manual
  - sc-checkpoint
  - wave-3
  - checkpoint-pending
status: checkpoint-awaiting-user-verification
requirements:
  - PERSIST-04
  - PERSIST-05
  - PERSIST-06
dependency_graph:
  requires:
    - 06-03 (capabilities + DEBUG schema deploy — Task 3 still pending; required by SC3)
    - 06-06 (AuthStore + Restart prompt + scenePhase observer)
    - 06-07 (SettingsView SYNC section)
    - 06-08 (IntroFlowView Step 3 SIWA wiring)
  provides:
    - "06-VERIFICATION.md template — manual SC1-SC5 sweep checklist + sign-off table + gap log"
  affects:
    - .planning/phases/06-cloudkit-siwa/06-VERIFICATION.md
tech_stack:
  added: []
  patterns:
    - "Manual verification template with verbatim copy locks (Restart alert, Keychain attrs, 4 SyncStatus labels)"
    - "Sign-off table mapping each SC to PERSIST requirement IDs"
    - "Gap log severity scale (Critical/Major/Minor) routed to /gsd-plan-phase --gaps"
key_files:
  created:
    - .planning/phases/06-cloudkit-siwa/06-VERIFICATION.md
  modified: []
decisions:
  - "06-09 Task 1 (autonomous) shipped as planned — 237-line template within ≤350 budget"
  - "Plan 09 is NOT marked fully complete; Task 2 is BLOCKING manual sweep — execution paused awaiting user resume signal"
  - "SC3 dependency on Plan 06-03 Task 3 (capabilities + schema deploy) explicitly flagged — schema must be in CloudKit Dashboard Development before SC3 can pass"
  - "Per CLAUDE.md §8.10, atomic commit shipped (7f24223) — SUMMARY + STATE updates will land in a separate commit after sign-off"
metrics:
  duration_seconds: 90
  duration_minutes: 2
  tasks_completed: 1
  tasks_pending: 1
  files_changed: 1
  completed_date: "2026-04-27"
---

# Phase 6 Plan 09: Manual SC1-SC5 Verification Checkpoint — Summary (PARTIAL)

Wave-3 closing plan that proves the production code from Waves 0-2 satisfies the locked SC1-SC5 success criteria for Phase 6. Two tasks: Task 1 ships the `06-VERIFICATION.md` template (autonomous); Task 2 is the BLOCKING manual sweep where the user runs all 5 SC tests on a real device (or 2-sim fallback per Pitfall C) and signs off.

**Plan 06-09 status: CHECKPOINT REACHED (awaiting human verification).** Task 1 shipped + committed atomically; Task 2 cannot be executed by the agent — it requires real iCloud, real Apple ID flows, manual revocation through system Settings, and Instruments App Launch traces on a real device.

## Status

| Task | Type | Status | Commit |
|------|------|--------|--------|
| 1 | auto | complete | `7f24223` |
| 2 | checkpoint:human-verify | **awaiting user verification** | — |

## What was shipped (Task 1)

`.planning/phases/06-cloudkit-siwa/06-VERIFICATION.md` — 237-line manual verification template:

- **Frontmatter:** phase, status (`pending` → flips to `complete` after sign-off), `signed_off_by`, `signed_off_date`, `fallback_used` (set to `2-sim` if SC3 uses simulator pair).
- **Pre-flight checklist:** gates Plan 06-03 Task 3 (capabilities + schema deploy) + Apple Developer Program membership + test environment confirmation.
- **5 SC sections** — each with: test description / 8-10 step instructions / expected outcome / 5-6 evidence-recording fields (screenshot paths, Console.app log paste, Instruments trace path) / pass/fail/defer status flag / observed-gaps free-text field.
  - **SC1** — 10-step sign-out parity sweep (intro Skip path, Stats updates, theme switch to Loud preset, cold-restart persistence, Export/Import round-trip).
  - **SC2** — 10-step SIWA flow with verbatim Restart alert copy lock (`"Restart to enable iCloud sync"` / `"Your stats will sync to all devices..."` / `"Cancel"` + `"Quit GameKit"` non-destructive), verbatim Keychain attrs (`com.lauterstar.gamekit.auth` / `appleUserID` / `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), scene-active validation, and SILENT revocation lifecycle (Pitfall 5 — no alert).
  - **SC3** — 10-step 2-device 50-game promotion test with Pitfall C 2-sim fallback documented (`fallback_used: 2-sim` frontmatter signal). Validates D-08 same-store-path lock + Pitfall 4 mitigation.
  - **SC4** — 4-state sync-status row exercise: `"Not signed in"` / `"Syncing…"` / `"Synced just now"` (+ TimelineView relative-time tick verification) / `"iCloud unavailable"` (Airplane Mode toggle).
  - **SC5** — Instruments App Launch trace measuring cold-start ≤1000 ms with `cloudSyncEnabled=true` (FOUND-01 P0 latency budget). Real-device required; sim cold-start is not meaningful.
- **Gap log table** — Critical / Major / Minor severity scale; gaps route to `/gsd-plan-phase 06 --gaps`.
- **Sign-off table** — 5 rows mapped to PERSIST-04, PERSIST-05, PERSIST-06.
- **Phase-close updates** — explicit ROADMAP.md + STATE.md + atomic commit recipe per CLAUDE.md §8.10.

## Acceptance criteria (Task 1)

| Criterion | Status |
|-----------|--------|
| File exists at `.planning/phases/06-cloudkit-siwa/06-VERIFICATION.md` | PASS |
| All 5 SC sections present with `## SC1`...`## SC5` headings | PASS |
| Pre-flight checklist references Plan 06-03 | PASS |
| Verbatim Restart prompt copy embedded in SC2 | PASS |
| Verbatim Keychain attrs embedded in SC2 | PASS |
| All 4 SyncStatus labels embedded in SC4 | PASS |
| Pitfall C 2-sim fallback documented + `fallback_used` field | PASS |
| Gap log table + Severity scale present | PASS |
| Sign-off table maps to PERSIST-04/05/06 (≥5 references) | PASS (8 refs) |
| Phase-close update list (ROADMAP + STATE) present | PASS |
| Line count ≤ 350 | PASS (237) |

All Task 1 acceptance gates green.

## Deviations from Plan

None — Task 1 executed exactly as written. Template structure matches the verbatim block in 06-09-PLAN.md §action.

## CHECKPOINT — Task 2 (awaiting human verification)

**Type:** `checkpoint:human-verify` (BLOCKING for Phase 6 close)

The user must run all 5 SC sweeps and sign off in `06-VERIFICATION.md`. See the file's per-SC instructions for step-by-step procedures. **Do NOT mark Plan 06-09 complete in STATE.md until the user reports a resume signal.**

### Critical dependency to flag before SC3

**SC3 cannot succeed unless Plan 06-03 Task 3 has shipped first.** Per `06-03-SUMMARY.md`:

> Task 3 is a `checkpoint:human-verify` and is pending user action — the plan is NOT yet fully complete.

If the user has NOT yet:
- Verified the gamekit target's 4 capabilities in Xcode → Signing & Capabilities (SIWA + iCloud + container `iCloud.com.lauterstar.gamekit` + Background Modes/Remote notifications), AND
- Run `expr try? GameKitApp._runtimeDeployCloudKitSchema()` from lldb in a Debug build, AND
- Confirmed `CD_GameRecord` + `CD_BestTime` are visible in CloudKit Dashboard Development...

...then SC3 will fail with a "schema not found" error from CloudKit. Plan 06-03 Task 3 must be cleared FIRST.

### Estimated time budget for Task 2

- SC1: ~20 min (3 difficulty playthroughs + theme switch + Export/Import).
- SC2: ~15 min (SIWA flow + Keychain inspection + revocation lifecycle).
- SC3: ~30 min (50 games + 2-device sync + cross-sync verification).
- SC4: ~15 min (4 states + 65s relative-time wait + Airplane Mode toggle).
- SC5: ~15-20 min (Instruments App Launch trace).
- **Total: ~95-100 min focused testing.**

### Resume signal — type one of:

- `approved — all 5 SCs PASS; 06-VERIFICATION.md signed off; ROADMAP + STATE updated; Phase 6 complete`
- `approved with deferrals — SC[N] DEFERRED-WITH-REASON [reason]; remaining SCs PASS; ROADMAP + STATE updated`
- `gaps surfaced — [N] gaps in gap log; invoking /gsd-plan-phase 06 --gaps to schedule closure plan(s)`
- `blocked: [SC-N] FAILED — [observation]; gap created; need [direction]`
- `blocked: SC3 cannot run until Plan 06-03 Task 3 cleared (capabilities + schema deploy)`

After the user reports back, the orchestrator will resolve the checkpoint and re-spawn an executor (or the verifier) to mark plan 06-09 fully complete in STATE.md and flip Phase 6 to `Complete` in ROADMAP.md.

## Self-Check

- [x] `.planning/phases/06-cloudkit-siwa/06-VERIFICATION.md` — created, 237 lines, all 10 acceptance criteria green.
- [x] Commit `7f24223` (Task 1) verified in `git log`.
- [x] No code touched (planning artifact only) — no Swift build needed.
- [x] STATE.md NOT updated (Plan 09 marked checkpoint-pending only after user resume).

## Self-Check: PASSED (Task 1)

Task 2 is a `checkpoint:human-verify` — execution paused until user resume signal. Plan 06-09 is NOT marked fully complete in STATE.md; current-plan counter remains at 09 with status `checkpoint reached, awaiting human verification`.
