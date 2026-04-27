# Phase 6: CloudKit + Sign in with Apple - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 06-cloudkit-siwa
**Areas discussed:** First-sign-in Restart prompt
**Areas locked from roadmap defaults (not interactively discussed):** Container reconfiguration strategy, Settings sync UI + status row, Credential lifecycle UX, Test matrix scope

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Container reconfig strategy | Launch-only Restart vs always-on .private(...) vs hot-swap | |
| Settings sync UI + status row | Section placement, 4-state status row, observer location | |
| Credential lifecycle UX | Revocation alert vs silent, scene-active checks, reinstall path | |
| First-sign-in Restart prompt | Surface, flag-flip timing, fire sites, copy | ✓ |

**User's choice:** Single area selected — Restart prompt. The other three areas were left to roadmap defaults (HIGH-confidence research recommendations + verbatim SC2 lock).

---

## First-sign-in Restart prompt

### Q1: What surface for the post-SIWA Restart prompt?

| Option | Description | Selected |
|--------|-------------|----------|
| iOS alert | `.alert` with Cancel + 'Quit GameKit'. Matches Apple Notes/Reminders idiom. | ✓ |
| Themed sheet (DKCard) | `.sheet` with full-page DKCard — premium feel, more code, unusual for relaunch instruction | |
| Full-screen cover | `.fullScreenCover` blocking everything — heavy for non-destructive instruction | |

**User's choice:** iOS alert (Recommended).
**Notes:** Matches Apple's lightest-touch idiom for relaunch-required toggles.

---

### Q2: When does cloudSyncEnabled flip true?

| Option | Description | Selected |
|--------|-------------|----------|
| On SIWA success, before prompt | Flag flips on SIWA completion; prompt is UX hint not consent gate. If user taps Cancel, next cold-start reconfigures anyway. | ✓ |
| Only on user confirming Quit | Half-state: Keychain has userID, sync still off until user taps Quit | |
| On SIWA, with rollback on Cancel | Flip true on SIWA, rollback if Cancel — most consistent UX, most code | |

**User's choice:** On SIWA success, before prompt (Recommended).
**Notes:** Sticky decision — matches Pitfall 4 "same store path; mirroring just turns on." No half-state.

---

### Q3: Where does the prompt fire?

| Option | Description | Selected |
|--------|-------------|----------|
| Both Settings AND IntroFlow Step 3 | Single `showRestartPrompt` state; either trigger sets it. Honors SC5 "once in intro and once in Settings." | ✓ |
| Settings only | IntroFlow silently flips flag; user discovers sync after relaunch | |
| Settings always; IntroFlow conditional | Intro shows prompt only if user has existing local games | |

**User's choice:** Both Settings AND IntroFlow Step 3 (Recommended).

---

### Q4: Restart prompt copy?

| Option | Description | Selected |
|--------|-------------|----------|
| Apple-style minimal | Title 'Restart to enable iCloud sync' + body explaining Quit & reopen + Cancel/'Quit GameKit' | ✓ |
| GameKit calm tone | Title 'One more step' + warmer tone + Later/'Quit GameKit' | |
| Plain transactional | Title 'Sign-in complete' + shortest body + Cancel/'Quit' | |

**User's choice:** Apple-style minimal (Recommended).

---

## Follow-up: Skip remaining gray areas

| Option | Description | Selected |
|--------|-------------|----------|
| More questions on Prompt | Lock Quit-button mechanic, re-prompt cadence, dedup logic | |
| Skip the other gray areas | Roadmap defaults locked for Container reconfig / Settings sync UI / Credential lifecycle | ✓ |
| Discuss other gray areas first | Open Container reconfig / Settings sync UI / Credential lifecycle interactively | |

**User's choice:** Skip the other gray areas.
**Implication:** Claude locked HIGH-confidence roadmap defaults + SC2 verbatim requirements as decisions. Captured Quit-button mechanic, re-prompt non-logic, and scope details under Claude's Discretion in CONTEXT.md (notably D-05 no-`exit(0)` lock for App Review safety).

---

## Claude's Discretion (locked in CONTEXT.md without user re-prompt)

- Container reconfiguration = launch-only via Restart prompt (ROADMAP HIGH-conf)
- Settings SYNC section between AUDIO and DATA, 2 rows (sign-in + status)
- `CloudSyncStatusObserver` constructed in `GameKitApp.init`, EnvironmentKey-injected
- Credential revocation = silent state-clear + sign-in card returns (no alert, "never nag" PERSIST-05)
- Scene-active validation via `getCredentialState` per SC2 verbatim
- Keychain wrapper isolation via `protocol KeychainBackend` for testability
- Quit GameKit button = dismiss-only, NO `exit(0)` call (App Review safety)
- No re-prompt logic, no `hasShownRestartPrompt` flag (cold-start naturally reconfigures)
- Test matrix split: Swift Testing for AuthStore + Observer; manual SC1-SC5 for iCloud-dependent paths
- Schema deploy to Development environment is a P6 prerequisite for SC3; Production deploy is P7

## Deferred Ideas

See CONTEXT.md `<deferred>` section. Highlights:
- Live ModelContainer hot-swap (MEDIUM-conf path) — deferred to v1.x polish if Restart prompt feels friction-y
- In-app sign-out button — never (system-level only)
- Apple-ID suffix display in signed-in row — defer
- CloudKit Production schema promotion — P7
- Privacy nutrition label — P7
- TestFlight Production-env SIWA verification — P7
