---
status: complete
phase: 06-cloudkit-siwa
source:
  - 06-01-SUMMARY.md
  - 06-02-SUMMARY.md
  - 06-03-SUMMARY.md
  - 06-04-SUMMARY.md
  - 06-05-SUMMARY.md
  - 06-06-SUMMARY.md
  - 06-07-SUMMARY.md
  - 06-08-SUMMARY.md
  - 06-09-SUMMARY.md
started: 2026-04-27T18:35:00Z
updated: 2026-04-27T19:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Pre-flight — 06-03 capabilities + schema deploy
expected: |
  Xcode Signing & Capabilities pane shows SIWA + iCloud/CloudKit + container `iCloud.com.lauterstar.gamekit`
  + Background Modes (Remote notifications). `expr try? GameKitApp._runtimeDeployCloudKitSchema()`
  run from lldb. CloudKit Dashboard Development shows `CD_GameRecord` and `CD_BestTime` record types.
result: pass

### 2. SC1 — Sign-out parity (Mines fully playable, no SIWA gate)
expected: |
  Fresh install, dismiss intro via Skip (do NOT sign in). SettingsView SYNC row reads
  "Not signed in". Play full Easy/Medium/Hard games — wins, losses, best-times all recorded
  in Stats. Theme swap to a Loud preset (Voltage / Dracula) keeps mines / numbers / flags
  legible. Cold restart preserves Stats. Export/Import JSON round-trips. Zero
  `category:auth` error log entries.
result: pass

### 3. SC2 — SIWA + Keychain + scene-active + silent revocation
expected: |
  From signed-out state: tap Sign in with Apple in Settings → SYNC → complete SIWA →
  Restart prompt appears with VERBATIM copy: title "Restart to enable iCloud sync",
  body "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit
  and reopen to finish setup.", buttons "Cancel" (left) / "Quit GameKit" (right, NOT red).
  Tap "Quit GameKit" — alert dismisses, app does NOT terminate (D-05). Manually swipe-kill.
  Cold relaunch → SYNC row 1 reads "Signed in to iCloud". Keychain entry: service
  `com.lauterstar.gamekit.auth`, account `appleUserID`, accessibility
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Background → wait 5s → foreground:
  Console.app `category:auth` shows scene-active validation ran. Revoke via System
  Settings → Apple ID → Password & Security → Sign in with Apple → GameKit → Stop using
  Apple ID. Foreground app: SYNC row flips to signed-out SILENTLY (NO alert — D-13 lock).
  Console.app shows "Cleared local sign-in state: …".
result: pass

### 4. SC3 — 2-device anonymous→signed-in promotion (50 games preserved + cross-sync)
expected: |
  Device A signed-out: play 50 Hard games (any mix). Stats shows 50 hard games.
  Sign in via Settings → SYNC → SIWA → Restart prompt → tap Quit GameKit → swipe-kill.
  Cold relaunch Device A: all 50 games still in Stats (D-08 same-store-path lock).
  SYNC row 2 reads "Syncing…" then "Synced just now" within 10-60s. Fresh-install
  Device B (real device or simulator on SAME iCloud — empty Keychain per D-15). Sign in
  on B → Quit → relaunch → wait ≤60s. Device B Stats: all 50 hard games visible
  (counts + best time match A within last-writer-wins margin). Play a new game on A,
  wait 30s, B Stats reflects it.
result: pass

### 5. SC4 — 4-state SyncStatus row observable
expected: |
  State 1 "Not signed in": fresh signed-out install — SYNC row 2 reads "Not signed in".
  State 2 "Syncing…": during SC3 step 5, capture screenshot of row 2 mid-sync.
  State 3 "Synced just now" → "Synced 1 minute ago": after sync settles, row 2 reads
  "Synced just now"; wait 65s, row 2 reads "Synced 1 minute ago" (TimelineView relative-time
  tick — D-12 + 06-07). State 4 "iCloud unavailable": with cloudSyncEnabled=true, Airplane
  Mode ON → play a game (forces a write) → within ~20s row 2 reads "iCloud unavailable"
  with sub-line "Last synced [relative]". Airplane Mode OFF → row 2 returns to "Synced just now".
result: pass

### 6. SC5 — Cold-start ≤1000ms with cloudSyncEnabled=true (FOUND-01)
expected: |
  Real device required (Instruments cannot meaningfully trace Simulator cold-start).
  Device A in cloudSyncEnabled=true state. Force-quit + wait 30s. Xcode → Product → Profile
  → "App Launch" template → record. Tap gamekit on home screen. Stop after Home tab visible.
  Instruments App Launch trace: read "Time to Initial Frame" (or equivalent). Measured value
  ≤ 1000 ms. First-launch-after-install can be worst case (≤1500ms) — document which.
  If no real device: mark DEFERRED-WITH-REASON (acceptable per VERIFICATION.md).
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
