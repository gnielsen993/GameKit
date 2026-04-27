---
phase: 6
slug: cloudkit-siwa
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-27
audited: 2026-04-27
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `06-RESEARCH.md` §Validation Architecture

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (Xcode 16+ bundled) — matches P2-P5 convention |
| **Config file** | None — Swift Testing requires no config beyond test target build settings |
| **Quick run command** | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:gamekitTests/AuthStore` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16"` |
| **Estimated runtime** | Quick ~30s, full suite ~90s on M-series Mac |

---

## Sampling Rate

- **After every task commit:** Run targeted suite for the touched file (e.g., `-only-testing:gamekitTests/AuthStore` after `AuthStore.swift` edits)
- **After every plan wave:** Run full suite — `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16"`
- **Before `/gsd-verify-work`:** Full suite green AND manual SC1-SC5 checkpoint signed in `06-VERIFICATION.md`
- **Max feedback latency:** 30s (per-file), 90s (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 0 | PERSIST-04 | T-06-01 | Keychain round-trip with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | unit | `xcodebuild test -only-testing:gamekitTests/AuthStore/keychainRoundTrip()` | ✅ | ✅ green |
| 6-01-02 | 01 | 0 | PERSIST-04 | T-06-02 | `credentialRevokedNotification` clears AuthStore state | unit | `xcodebuild test -only-testing:gamekitTests/AuthStore/revocationClearsState()` | ✅ | ✅ green |
| 6-01-03 | 01 | 0 | PERSIST-04 | T-06-03 | All 4 `CredentialState` cases route correctly + no-stored-ID early-return | unit (5 funcs) | `xcodebuild test -only-testing:gamekitTests/AuthStore` (5 sceneActiveValidation_* funcs) | ✅ | ✅ green |
| 6-02-01 | 02 | 0 | PERSIST-06 | T-06-04 | `eventChangedNotification` userInfo → 4 SyncStatus cases (state-machine) | unit (5 funcs) | `xcodebuild test -only-testing:gamekitTests/CloudSyncStatusObserver` (initialStatus_* + event_* funcs) | ✅ | ✅ green |
| 6-02-02 | 02 | 0 | PERSIST-06 | — | Relative-time label format (just-now / minutes / hours / unavailable) | unit (4 funcs) | `xcodebuild test -only-testing:gamekitTests/CloudSyncStatusObserver` (label_* funcs) | ✅ | ✅ green |
| 6-W-04 | — | 0 | PERSIST-04 | T-06-W4 | Entitlements include iCloud + CloudKit container + SIWA | manual | — | manual — Xcode Signing & Capabilities | ✅ green |
| 6-W-05 | — | 0 | PERSIST-06 | T-06-W5 | CloudKit Dashboard schema deployed (Development env) | manual | — | manual — `initializeCloudKitSchema()` once + Dashboard verify | ✅ green |
| 6-SC1 | — | 3 | PERSIST-04 | T-06-S1 | Full Mines feature parity signed-out | manual (SC1) | — | manual-only | ✅ green |
| 6-SC2 | — | 3 | PERSIST-04 | T-06-S2 | SIWA flow + Keychain write + scene-active validation + revocation | manual (SC2) | — | manual-only | ✅ green |
| 6-SC3 | — | 3 | PERSIST-06 | T-06-S3 | 50-game user signs in, restarts, all 50 mirror to second device | manual (SC3) | — | manual-only — real iCloud + 2 sims/devices | ✅ green |
| 6-SC4 | — | 3 | PERSIST-06 | T-06-S4 | Sync-status row reaches all 4 states | manual (SC4) | — | manual-only | ✅ green |
| 6-SC5 | — | 3 | PERSIST-04 | T-06-S5 | Cold-start <1s with cloudSyncEnabled=true | manual (SC5) | Instruments App Launch template | manual-only | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `gamekit/Core/AuthStore.swift` — production source (TDD: tests first per P4/P5 precedent)
- [x] `gamekit/Core/CloudSyncStatusObserver.swift` — production source
- [x] `gamekit/Core/SyncStatus.swift` (or alongside observer) — `enum SyncStatus`
- [x] `gamekit/Core/KeychainBackend.swift` — `protocol KeychainBackend` + `SystemKeychainBackend`
- [x] `gamekitTests/Core/AuthStoreTests.swift` — covers PERSIST-04 unit cases (7 funcs)
- [x] `gamekitTests/Core/CloudSyncStatusObserverTests.swift` — covers PERSIST-06 unit cases (9 funcs)
- [x] `gamekitTests/Helpers/InMemoryKeychainBackend.swift` — protocol stub for tests
- [x] `06-VERIFICATION.md` — manual SC1-SC5 checkpoint template (planner authors)
- [x] Wave-0 entitlements verification task — confirm iCloud + CloudKit container `iCloud.com.lauterstar.gamekit` + SIWA all registered in target
- [x] Wave-0 schema deploy task — one-shot DEBUG-only call to `initializeCloudKitSchema()` to materialize record types in CloudKit Dashboard Development environment (BLOCKING for SC3)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full Mines feature parity signed-out | PERSIST-04 SC1 | End-to-end UX cannot be unit-tested | Open app fresh, do not sign in, play full Easy/Medium/Hard games incl. win + loss, verify Stats screen + Settings + theme switching |
| Real SIWA round-trip (Keychain write) | PERSIST-04 SC2 | Real Apple ID + Keychain entitlement required | Settings → SYNC → Sign in → complete SIWA → verify userID in Keychain via Xcode → background+foreground app → confirm `validateOnSceneActive` fires (log) |
| Credential revocation lifecycle | PERSIST-04 SC2 | Requires manipulating Apple ID system Settings | After sign-in: Settings → Apple ID → Password & Security → Sign in with Apple → GameKit → Stop using Apple ID; foreground app; verify SYNC section returns to signed-out silently (no alert) |
| 2-device CloudKit promotion | PERSIST-06 SC3 | Requires real iCloud account + 2 devices/sims | Sim A (or Device A): play 50 Hard games signed-out, sign in, tap Quit GameKit, kill+relaunch. Sim B (or Device B, same iCloud, fresh install, signs in): open Stats → 50 games appear within 60s. **Note:** iOS Simulator 2-sim CloudKit sync is unreliable per Apple sample-cloudkit-sync-engine — fall back to 2 real devices if sim test flakes. |
| Sync-status 4 states observable | PERSIST-06 SC4 | Requires triggering real CloudKit events | (a) Default `Not signed in` (b) Sign in then trigger 50-record write → observe `Syncing…` (c) Wait for settle → `Synced just now` (d) Toggle Airplane Mode + force a sync → observe `iCloud unavailable — last synced [date]` |
| Cold-start <1s with sync ON | PERSIST-04 SC5 (FOUND-01) | Real timing requires real device | Instruments App Launch template, target device cold-start, verify `RootTabView idle <1s` from launch tap with `cloudSyncEnabled=true` |
| Reinstall path | PERSIST-04 SC2 | Requires deletion + reinstall | Sign in → play games → delete app → reinstall → SYNC section shows SIWA button (Keychain wiped) → re-sign in → verify CloudKit data downloads back |
| Settings SYNC section legibility | THEME-01 carry-over (Mines theme matrix not regressed) | Visual verification | Switch through Classic + 1 from each category (Sweet/Bright/Soft/Moody/Loud); verify SYNC rows + status text legible; pulse animation on .syncing reads against bg |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (AuthStore + Observer + Keychain backend + entitlements + schema deploy)
- [x] No watch-mode flags
- [x] Feedback latency <30s (per-file), <90s (full suite)
- [x] `nyquist_compliant: true` set in frontmatter (Wave 0 shipped)

**Approval:** signed-off 2026-04-27 (user-confirmed real-device SC1-SC5 sweep + Wave-0 manual checks)

---

## Validation Audit 2026-04-27

| Metric | Count |
|--------|-------|
| Gaps found | 0 (no missing tests) |
| Resolved | 5 doc-state refresh: frontmatter (3 fields), File Exists ❌→✅, Status ⬜→✅ green, stale test method names corrected (3 rows), Wave 0 checkboxes |
| Escalated | 0 |

**Audit findings:**
- 16 unit tests across 2 suites (`AuthStoreTests` 7 funcs / `CloudSyncStatusObserverTests` 9 funcs) — all GREEN per Plan 06-05 SUMMARY metric `test_count: 9` + Plan 06-04 SUMMARY decision "AuthStoreTests still 7/7 GREEN".
- All 4 Wave-0 production sources exist on disk (`AuthStore.swift`, `CloudSyncStatusObserver.swift`, `SyncStatus.swift`, `KeychainBackend.swift`) plus 1 test helper (`InMemoryKeychainBackend.swift`).
- Stale "Automated Command" entries referenced non-existent test methods (`sceneActiveValidation`, `eventToStatusMapping`, `relativeTimeFormat` were category labels, not Swift Testing func names) — corrected to suite-level filters with func-name notes.
- Manual rows (Wave-0 entitlements + schema deploy + SC1-SC5) signed off after user-confirmed real-device sweep.
