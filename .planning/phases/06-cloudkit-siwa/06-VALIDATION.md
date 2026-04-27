---
phase: 6
slug: cloudkit-siwa
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
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
| **Quick run command** | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:gamekitTests/Core/AuthStoreTests` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16"` |
| **Estimated runtime** | Quick ~30s, full suite ~90s on M-series Mac |

---

## Sampling Rate

- **After every task commit:** Run targeted suite for the touched file (e.g., `-only-testing:gamekitTests/Core/AuthStoreTests` after `AuthStore.swift` edits)
- **After every plan wave:** Run full suite — `xcodebuild test -scheme gamekit -destination "platform=iOS Simulator,name=iPhone 16"`
- **Before `/gsd-verify-work`:** Full suite green AND manual SC1-SC5 checkpoint signed in `06-VERIFICATION.md`
- **Max feedback latency:** 30s (per-file), 90s (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 0 | PERSIST-04 | T-06-01 | Keychain round-trip with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | unit | `xcodebuild test -only-testing:gamekitTests/Core/AuthStoreTests/keychainRoundTrip` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 0 | PERSIST-04 | T-06-02 | `credentialRevokedNotification` clears AuthStore state | unit | `... AuthStoreTests/revocationClearsState` | ❌ W0 | ⬜ pending |
| 6-01-03 | 01 | 0 | PERSIST-04 | T-06-03 | All 4 `CredentialState` cases route correctly | unit (parameterized) | `... AuthStoreTests/sceneActiveValidation` | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 0 | PERSIST-06 | T-06-04 | `eventChangedNotification` userInfo → 4 SyncStatus cases | unit | `... CloudSyncStatusObserverTests/eventToStatusMapping` | ❌ W0 | ⬜ pending |
| 6-02-02 | 02 | 0 | PERSIST-06 | — | Relative-time label format (just-now / minutes / hours / days) | unit (pure fn) | `... CloudSyncStatusObserverTests/relativeTimeFormat` | ❌ W0 | ⬜ pending |
| 6-W-04 | — | 0 | PERSIST-04 | T-06-W4 | Entitlements include iCloud + CloudKit container + SIWA | manual | — | manual — Xcode Signing & Capabilities | ⬜ pending |
| 6-W-05 | — | 0 | PERSIST-06 | T-06-W5 | CloudKit Dashboard schema deployed (Development env) | manual | — | manual — `initializeCloudKitSchema()` once + Dashboard verify | ⬜ pending |
| 6-SC1 | — | 3 | PERSIST-04 | T-06-S1 | Full Mines feature parity signed-out | manual (SC1) | — | manual-only | ⬜ pending |
| 6-SC2 | — | 3 | PERSIST-04 | T-06-S2 | SIWA flow + Keychain write + scene-active validation + revocation | manual (SC2) | — | manual-only | ⬜ pending |
| 6-SC3 | — | 3 | PERSIST-06 | T-06-S3 | 50-game user signs in, restarts, all 50 mirror to second device | manual (SC3) | — | manual-only — real iCloud + 2 sims/devices | ⬜ pending |
| 6-SC4 | — | 3 | PERSIST-06 | T-06-S4 | Sync-status row reaches all 4 states | manual (SC4) | — | manual-only | ⬜ pending |
| 6-SC5 | — | 3 | PERSIST-04 | T-06-S5 | Cold-start <1s with cloudSyncEnabled=true | manual (SC5) | Instruments App Launch template | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekit/Core/AuthStore.swift` — production source (TDD: tests first per P4/P5 precedent)
- [ ] `gamekit/Core/CloudSyncStatusObserver.swift` — production source
- [ ] `gamekit/Core/SyncStatus.swift` (or alongside observer) — `enum SyncStatus`
- [ ] `gamekit/Core/KeychainBackend.swift` — `protocol KeychainBackend` + `SystemKeychainBackend`
- [ ] `gamekitTests/Core/AuthStoreTests.swift` — covers PERSIST-04 unit cases
- [ ] `gamekitTests/Core/CloudSyncStatusObserverTests.swift` — covers PERSIST-06 unit cases
- [ ] `gamekitTests/Helpers/InMemoryKeychainBackend.swift` — protocol stub for tests
- [ ] `06-VERIFICATION.md` — manual SC1-SC5 checkpoint template (planner authors)
- [ ] Wave-0 entitlements verification task — confirm iCloud + CloudKit container `iCloud.com.lauterstar.gamekit` + SIWA all registered in target
- [ ] Wave-0 schema deploy task — one-shot DEBUG-only call to `initializeCloudKitSchema()` to materialize record types in CloudKit Dashboard Development environment (BLOCKING for SC3)

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (AuthStore + Observer + Keychain backend + entitlements + schema deploy)
- [ ] No watch-mode flags
- [ ] Feedback latency <30s (per-file), <90s (full suite)
- [ ] `nyquist_compliant: true` set in frontmatter (after Wave 0 ships)

**Approval:** pending
