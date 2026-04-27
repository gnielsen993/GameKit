---
phase: 06-cloudkit-siwa
type: verification
sc_count: 5
status: complete  # signed off via UAT.md 2026-04-27
signed_off_by: "User (UAT — see 06-UAT.md)"
signed_off_date: "2026-04-27"
fallback_used:    # set if 2-sim was used for SC3 (Pitfall C)
---

# Phase 6 — Manual SC1-SC5 Verification Checklist

> **Status note (added 2026-04-27 during P7 doc-drift cleanup per 07-01-PLAN):**
> This template was authored by Plan 06-09 Task 1. The actual SC1-SC5 sweep was
> performed against `06-UAT.md` (see that document for full evidence and 6/6 SC
> pass details) and signed off in `06-VALIDATION.md` on 2026-04-27. Rather than
> re-run the sweep against this template's evidence fields, the sign-off rows
> below have been marked PASS with a pointer to 06-UAT.md as the canonical
> evidence source. The unchecked checkboxes throughout the SC1-SC5 sections
> remain unchecked because the canonical evidence lives in 06-UAT.md, not here.

> Per CONTEXT D-18: Phase 6 ships against locked SC1-SC5 from ROADMAP.
> Wave 0 / Wave 1 / Wave 2 ship the production code; THIS document
> proves the production code satisfies SC1-SC5 against real iCloud +
> real Apple ID + real device-side measurements.

---

## Pre-flight (Plan 06-03 must be complete)

- [ ] Plan 06-03 Task 3 signed off — capabilities + schema deploy verified
- [ ] CloudKit Dashboard Development → `iCloud.com.lauterstar.gamekit` shows `CD_GameRecord` + `CD_BestTime` record types
- [ ] gamekit target Signing & Capabilities pane confirms 4 capabilities (SIWA + iCloud/CloudKit + container ID + Background Modes)
- [ ] Apple Developer Program membership active

**Test environment**:
- Real iCloud account confirmed accessible: ☐ yes / ☐ no — fallback: 2-sim with ≤60s lag (Pitfall C)
- 2 real devices on same iCloud account: ☐ yes / ☐ no — fallback: simulator pair
- iPhone test device(s) iOS version: _____________

---

## SC1 — Full-feature Mines parity signed-out

**What:** Every Mines gameplay path / stat / theme works identically signed-out vs signed-in. PERSIST-04 sign-in is OPTIONAL — never gates gameplay.

**Test instructions:**
1. Fresh install on Device A (delete app first if present).
2. On launch: dismiss the 3-step intro via "Skip" (do NOT sign in).
3. Verify SettingsView SYNC section row reads `"Not signed in"`.
4. Play full Easy game to win — confirm best-time + game count update in Stats.
5. Play full Medium game to loss — confirm loss recorded in Stats.
6. Play full Hard game to win — confirm best-time updated in Stats.
7. Switch theme via Settings APPEARANCE → 5 Classic swatches → swap to a Loud preset (Voltage / Dracula).
8. Repeat one Easy game on the Loud preset; confirm legibility (mines, numbers, flags all readable).
9. Restart app cold (force-quit + relaunch); confirm Stats persisted.
10. Visit SettingsView → Export stats → confirm fileExporter completes; Import stats → fileImporter completes.

**Expected:** All 10 steps pass without sign-in. SettingsView SYNC stays `"Not signed in"` throughout.

**Evidence:**
- [ ] Step 1-3 screenshot path: __________________
- [ ] Step 4-6 Stats screen screenshot path: __________________
- [ ] Step 7-8 themed Mines screenshot paths: __________________
- [ ] Step 9 cold-launch Stats screenshot: __________________
- [ ] Step 10 export+import screenshots: __________________
- [ ] Console log search: zero `error` log entries from `category: "auth"`: paste lldb session

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC2 — SIWA flow + Keychain + scene-active + revocation

**What:** Sign in via SIWA in Settings; Keychain entry written with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; scene-active validation runs on every `.active` transition; revocation handled silently (no alert).

**Test instructions:**
1. Continuing from SC1 Device A (signed-out).
2. Settings → SYNC → tap `Sign in with Apple` button → complete SIWA flow with Apple ID.
3. Confirm Restart prompt alert appears with VERBATIM copy:
   - Title: `"Restart to enable iCloud sync"`
   - Body: `"Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup."`
   - Buttons: `"Cancel"` (left) / `"Quit GameKit"` (right, default — NOT red/destructive)
4. Tap `"Quit GameKit"` — confirm alert dismisses but app does NOT terminate (D-05 lock).
5. Manually swipe up from app switcher to terminate.
6. Relaunch app cold.
7. Verify SettingsView SYNC section row 1 reads `"Signed in to iCloud"` (no Apple-ID suffix per Discretion).
8. **Keychain inspection** (requires Xcode Devices window or `security` CLI):
   - Open Xcode → Window → Devices and Simulators → select device → "View Device Logs" or use Console.app
   - Confirm Keychain entry visible: service `com.lauterstar.gamekit.auth`, account `appleUserID`, accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Pattern: `security find-generic-password -s com.lauterstar.gamekit.auth -a appleUserID` from a privileged shell (sim only).
9. **Scene-active validation:** background app (Home button) → wait 5s → foreground app → check Console.app filtered to `category:auth`: confirm `"Signed in (userID hidden)"` (initial sign) AND a subsequent line implying validateOnSceneActive ran (no error → silent; or revocation cleared logs).
10. **Revocation lifecycle:**
    - System Settings → tap your name (Apple ID) → Password & Security → Sign in with Apple → GameKit → Stop using Apple ID → confirm
    - Foreground GameKit app
    - Verify SettingsView SYNC section returns to signed-out state SILENTLY — NO alert appears (PERSIST-05 + D-13 lock)
    - Verify Console.app shows: `"Cleared local sign-in state: scene-active state=revoked"` OR `"Cleared local sign-in state: credentialRevokedNotification"` (one of the two paths fires depending on whether revocation arrives via notification or via scene-active poll)

**Expected:** All 10 steps complete without ANY alert except the Restart prompt at step 3. Keychain attrs verified verbatim. Revocation flips SYNC card to signed-out silently.

**Evidence:**
- [ ] Step 3 Restart alert screenshot (verbatim title/body/buttons): __________
- [ ] Step 7 signed-in row screenshot: __________
- [ ] Step 8 Keychain attrs CLI/Console output paste: __________
- [ ] Step 9 Console.app `category:auth` log paste: __________
- [ ] Step 10 silent-revocation Console.app log paste + signed-out screenshot: __________
- [ ] Step 10 negative — NO alert observed during revocation: paste video timestamp or "no alert seen" affirmation

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC3 — 2-device anonymous→signed-in promotion (50 games)

**What:** A user with 50 local games signs in, dismisses Restart prompt or quits, relaunches; on relaunch all 50 games are present and begin mirroring to CloudKit; second device on same iCloud account sees the rows.

**Test setup (Pitfall C lookbacks):**
- **Preferred:** 2 real devices on same iCloud account.
- **Fallback (acceptable):** 2 simulators on same iCloud account; expect ≤60s lag; mark `fallback_used: 2-sim` in frontmatter.

**Test instructions:**
1. Fresh install on Device A; sign-out state.
2. Play 50 Hard-difficulty games (any mix of wins/losses; quickest path: tap-mine on first reveal repeatedly to log losses fast). Confirm Stats screen shows 50 hard games played.
3. Settings → SYNC → Sign in with Apple → complete SIWA flow → Restart prompt appears.
4. Tap `"Quit GameKit"` (dismiss only) → swipe up from app switcher to terminate.
5. Relaunch Device A cold. Confirm:
   - All 50 games still in Stats (D-08 same-store-path lock — local data preserved).
   - SettingsView SYNC row 2 shows `"Syncing…"` then transitions to `"Synced just now"` within ~10-60 seconds (CloudKit setup + initial export).
6. Fresh install on Device B (DIFFERENT device or simulator on SAME iCloud account; if Device B is the same physical device as A, delete + reinstall so Keychain is empty per D-15).
7. Sign in on Device B via Settings → SIWA flow → tap Quit → relaunch.
8. Wait up to 60s for CloudKit import.
9. On Device B: open Stats screen. Confirm all 50 hard games present (counts + best time match Device A within last-writer-wins margin).
10. Verify on both devices that gameplay continues to sync: play a new game on Device A → wait 30s → verify it appears on Device B's Stats.

**Expected:** Local data on Device A preserved across the sign-in event (Pitfall 4 mitigation). Cloud rows from Device A appear on Device B within 60s.

**Evidence:**
- [ ] Device A Stats screenshot showing 50 games (pre-sign-in): __________
- [ ] Device A Restart prompt screenshot: __________
- [ ] Device A post-relaunch Stats screenshot (50 games preserved + Synced status): __________
- [ ] Device B Stats screenshot post-sync (50 games visible): __________
- [ ] Step 10 cross-device-sync proof (timestamp matched on both Stats): __________
- [ ] If 2-sim fallback used, document observed lag in seconds: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC4 — Sync-status row 4 states observable

**What:** SettingsView SYNC row 2 reaches all 4 states: `"Not signed in"`, `"Syncing…"`, `"Synced just now"` / `"Synced X ago"`, `"iCloud unavailable"`.

**Test instructions:**
1. **State `"Not signed in"`:** Fresh install / signed-out → SYNC row 2 reads `"Not signed in"` immediately.
2. **State `"Syncing…"`:** From SC3 step 5 — observe row 2 reading `"Syncing…"` during CloudKit setup. Capture screenshot within the few-seconds window.
3. **State `"Synced just now"`:** Wait for sync to settle → row 2 reads `"Synced just now"`. Wait 65 seconds → row 2 reads `"Synced 1 minute ago"` (proves TimelineView relative-time tick — D-12 + Plan 06-07 wiring).
4. **State `"iCloud unavailable"`:** With cloudSyncEnabled=true, toggle Airplane Mode ON. Trigger a sync event by playing a game (creates a write that needs to push). Within ~20 seconds, row 2 reads `"iCloud unavailable"` with sub-line `"Last synced [relative]"`. Toggle Airplane Mode OFF → wait → row 2 returns to `"Synced just now"`.

**Expected:** All 4 states observable. Sub-line on `.unavailable(lastSynced:)` shows relative time.

**Evidence:**
- [ ] State 1 screenshot: __________
- [ ] State 2 screenshot (Syncing…): __________
- [ ] State 3a screenshot (Synced just now) + State 3b screenshot 65s later (Synced X ago): __________
- [ ] State 4 screenshot (iCloud unavailable + Last synced sub-line): __________
- [ ] Console.app logs filtered to `category:cloudkit` showing event transitions: __________

**Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED-WITH-REASON

**Observed gaps:** _______________________________________________

---

## SC5 — Cold-start <1s with cloudSyncEnabled=true (FOUND-01 not regressed)

**What:** Cold-start time on a real device with `cloudSyncEnabled=true` (i.e. the `.private("iCloud.com.lauterstar.gamekit")` ModelConfiguration path) remains under 1 second. FOUND-01 is the project's hard P0 latency budget.

**Test instructions:**
1. Real device required (Instruments cannot trace Simulator cold-start meaningfully). If a real device is unavailable, mark SC5 as DEFERRED-WITH-REASON and surface as a P7 release-checklist item.
2. Use the Device A from SC3 — it should be in `cloudSyncEnabled=true` state.
3. Force-quit the app + wait 30 seconds (allows OS to fully release process state).
4. Open Xcode → Product → Profile → select "App Launch" template → Choose Device → Record.
5. From Instruments, tap the gamekit app on the device's home screen to launch.
6. Stop recording after the app shows the Home tab with games visible.
7. In Instruments App Launch trace, find the metric `Time to RootTabView idle` (or equivalent — likely "Time to Initial Frame" minus baseline; refer to Apple's App Launch documentation).
8. Record measured value in milliseconds.

**Expected:** Measured cold-start ≤ 1000 ms. Pitfall E notes: 100-500ms typical, 1s+ on first-launch-after-install acceptable; document actual.

**Evidence:**
- [ ] Instruments trace file path (`.trace`): __________
- [ ] Measured cold-start in ms: __________
- [ ] Comparison vs P5 SC2 baseline (if known): __________
- [ ] Was this first-launch-after-install (worst case) or warm cold-start: __________

**Status:** ☐ PASS (≤1000ms) / ☐ FAIL (>1000ms) / ☐ DEFERRED-WITH-REASON (no real device available)

**Observed gaps:** _______________________________________________

---

## Gap Log

Record any failures here. Each gap = a candidate plan for `/gsd-plan-phase 06 --gaps`.

| Gap ID | SC | Severity | Description | Remediation | Status |
|--------|----|----------|-------------|-------------|--------|
| (blank — no gaps yet) |    |          |             |             |        |

Severity scale:
- **Critical** (P0): blocks ROADMAP P6 close. Examples: SC2 alert appears on revocation; SC3 data loss on sign-in.
- **Major** (P1): functional regression. Examples: SC4 state never reaches `"Synced just now"`; SC5 cold-start regresses to 1.5s+.
- **Minor** (P2): cosmetic / polish. Examples: status row glyph misaligned; relative-time string flickers.

---

## Sign-off

| Criterion | Verifier | Date | Status |
|-----------|----------|------|--------|
| SC1 — Sign-out parity (PERSIST-04) | User (UAT) | 2026-04-27 | ✓ PASS (per 06-UAT.md) |
| SC2 — SIWA + Keychain + revocation (PERSIST-04 + PERSIST-05) | User (UAT) | 2026-04-27 | ✓ PASS (per 06-UAT.md) |
| SC3 — 2-device promotion (PERSIST-06) | User (UAT) | 2026-04-27 | ✓ PASS (per 06-UAT.md) |
| SC4 — 4-state sync-status (PERSIST-06) | User (UAT) | 2026-04-27 | ✓ PASS (per 06-UAT.md) |
| SC5 — Cold-start <1s (PERSIST-04 SC5 + FOUND-01) | User (UAT) | 2026-04-27 | ✓ PASS (per 06-UAT.md) |

Phase 6 close criteria:
- [x] All 5 SCs PASS or DEFERRED-WITH-REASON-DOCUMENTED
- [x] No Critical gaps open
- [x] Major gaps converted to a P6 gap-closure plan via `/gsd-plan-phase 06 --gaps` OR explicitly accepted as P7 release-checklist items

---

## Phase-Close Updates (after sign-off)

After ALL SCs PASS or DEFERRED:

- [x] Update `.planning/ROADMAP.md` — Phase 6 row: status `In progress` → `Complete`; date filled
- [x] Update `.planning/STATE.md` — `current_position` advances to Phase 7; `progress.completed_phases` increments to 6
- [ ] Atomic commit `docs(06-09): SC1-SC5 verification checkpoint signed off — Phase 6 complete` per CLAUDE.md §8.10
- [x] Optional: update `.planning/REQUIREMENTS.md` traceability — flip PERSIST-04, PERSIST-05, PERSIST-06 from "Pending" → "Complete (06)"
