---
phase: 06-cloudkit-siwa
plan: 08
subsystem: intro-flow
tags:
  - intro-flow
  - siwa
  - wave-2
  - persist-04
requirements:
  - PERSIST-04
  - PERSIST-05
dependency_graph:
  requires:
    - 06-04 (AuthStore.signIn(userID:) + shouldShowRestartPrompt)
    - 06-06 (root-level Restart prompt + AuthStore env injection)
    - 06-07 (handler shape mirror — SettingsSyncSection.handleSIWACompletion)
    - 05-05 (IntroFlowView P5 — Step 3 SignInWithAppleButton + dismissIntro single source of truth)
  provides:
    - "Second of two SIWA-success sites — IntroFlowView Step 3 now flips the same shouldShowRestartPrompt as Settings SYNC (PERSIST-04 complete)"
    - "Three-caller dismissIntro() pattern: Skip + Done + SIWA-success all share the single source of truth"
  affects:
    - IntroFlowView.swift (handler additions; signInTapped no-op removed)
tech_stack:
  added: []
  patterns:
    - "SIWA onCompletion handler shape mirrored from Plan 06-07 (D-02 sequence: signIn → cloudSyncEnabled = true → shouldShowRestartPrompt = true → dismissIntro)"
    - "@Environment-injected @Observable singletons (authStore + settingsStore) read from a SwiftUI struct view"
    - "@MainActor Task wrap inside SIWA onCompletion for Swift 6 strict concurrency"
    - "Three-caller single-source-of-truth helper (dismissIntro extends from Skip/Done to also include SIWA-success)"
key_files:
  created: []
  modified:
    - gamekit/gamekit/Screens/IntroFlowView.swift
decisions:
  - "06-08: SIWA-success in intro is treated as Done — calls dismissIntro() so the .fullScreenCover dismisses (hasSeenIntro = true) and the user sees the Restart alert at the root level. This means the user does NOT remain trapped in the intro after a successful sign-in; the alert (via authStore.shouldShowRestartPrompt at root scope) surfaces over RootTabView once the cover dismisses. Aligns with the spirit of P5 D-21/D-22/D-23 — every Step 3 exit path writes hasSeenIntro = true."
  - "06-08: dismissIntro() body BYTE-IDENTICAL preserved (T-06-introdismiss lock proven by `diff` returning 0 lines between HEAD~ and HEAD). Doc-comment was tightened to mention the new third caller (SIWA-success), but the function body lines (`settingsStore.hasSeenIntro = true` + `dismiss()`) are byte-identical to P5. Lock locks the contract that future plans MUST NOT modify the body — only add or remove callers."
  - "06-08: signInTapped() removed (3 lines). Its purpose — log a tap event during intro — is subsumed by handleSIWARequest, which logs at the moment the SIWA request is initiated (one log line, fired once per attempt). Removing the no-op log produces a cleaner audit trail when correlating intro-flow logs with downstream Keychain writes."
  - "06-08: File-length budget (≤290 lines) required tightening doc-comments and the file header. The header was condensed from 28 lines (P5 — referencing all of D-18..D-24) to 14 lines retaining only load-bearing details. The dismissIntro and SIWA handler doc-comments were compressed to 1-3 lines each. No semantic loss: every removed line was already documented in the SUMMARY history (STATE.md 05-05 / 06-04 / 06-07) and the per-plan files. The cap was a hard acceptance gate."
  - "06-08: Mirrored handler shape from Plan 06-07 verbatim (Task { @MainActor in switch result { ... } } with credential.user extraction + try authStore.signIn). The two SIWA-success sites are now byte-similar at the call-site logic level — eases future maintenance (e.g., adding rate-limiting, telemetry, retry — would update both sites identically)."
  - "06-08: Plan introduced ZERO new user-facing strings. All new code paths use Self.logger.info/error which are not extracted by SWIFT_EMIT_LOC_STRINGS. The Restart alert strings (4) and SyncStatus labels (5) and SYNC section strings (3) — total 12 P6 strings — were already shipped via Plans 06-06 + 06-07; this plan inherits them by reference. xcstringstool sync was not run (no .stringsdata changes for IntroFlowView between commits)."
  - "06-08: handleSIWARequest extracts the request-shaping role from P5's signInTapped no-op. SC2 verbatim `request.requestedScopes = []` is set inside handleSIWARequest (single source of scope policy in IntroFlowView) — adversarial negative-grep `! grep -E '\\.email|\\.fullName' IntroFlowView.swift` returns empty (T-06-04 lock). The intro-side scope policy is now identical to the Settings-side (Plan 06-07 line 80) — both sites show the same SIWA consent screen with no PII fields."
metrics:
  duration_minutes: 13
  tasks_completed: 2
  files_changed: 1
  commits: 1
  completed_date: "2026-04-27"
---

# Phase 06 Plan 08: IntroFlowView Step 3 SIWA Wiring Summary

Wave-2 integration #3 (final integration plan) — replaces the P5 D-21 no-op SIWA `onCompletion` in IntroFlowView Step 3 with a real PERSIST-04 handler. With this commit landed, **PERSIST-04 is end-to-end complete**: both SIWA-success sites (SettingsView SYNC section from Plan 06-07 + IntroFlowView Step 3 from this plan) flip the same `authStore.shouldShowRestartPrompt` flag, which surfaces the root-level Restart alert (Plan 06-06).

## Diff stats

| File | Lines added | Lines removed | Net |
|------|-------------|---------------|-----|
| `gamekit/gamekit/Screens/IntroFlowView.swift` | 51 | 36 | +15 |

Final file length: **289 lines** (within ≤290 budget).

## What landed

### Edit A — `@Environment(\.authStore)` injection

Added at line 39 (immediately after `@Environment(\.settingsStore) private var settingsStore`). Mirrors Plan 06-07's SettingsSyncSection injection.

### Edit B — Two new handler methods + signInTapped removed

```swift
private func handleSIWARequest(_ request: ASAuthorizationAppleIDRequest) {
    request.requestedScopes = []   // SC2 verbatim — userID only
    Self.logger.info("SIWA request initiated from intro Step 3")
}

private func handleSIWACompletion(_ result: Result<ASAuthorization, Error>) {
    Task { @MainActor in
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential else {
                Self.logger.error("SIWA returned non-Apple-ID credential")
                return
            }
            // T-06-03: extract ONLY credential.user; never the one-shot JWT.
            do {
                try authStore.signIn(userID: credential.user)
                settingsStore.cloudSyncEnabled = true        // D-02
                authStore.shouldShowRestartPrompt = true     // D-03
                dismissIntro()                                // STATE 05-05 SoT
            } catch {
                Self.logger.error("SIWA Keychain write failed: ...")
            }
        case .failure(let error):
            Self.logger.error("SIWA failed: ...")
        }
    }
}
```

P5 `signInTapped()` removed — subsumed by `handleSIWARequest`.

### Edit C — IntroStep3SignInView signature update

```swift
// Before (P5):
let onSignIn: () -> Void

// After (P6 06-08):
let onSIWARequest: (ASAuthorizationAppleIDRequest) -> Void
let onSIWACompletion: (Result<ASAuthorization, Error>) -> Void
```

### Edit D — SignInWithAppleButton wiring

```swift
SignInWithAppleButton(
    .signIn,
    onRequest: { request in onSIWARequest(request) },
    onCompletion: { result in onSIWACompletion(result) }
)
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
.frame(height: 44)
```

Styling modifiers (`signInWithAppleButtonStyle` + `frame(height: 44)`) BYTE-IDENTICAL preserved (P5 UI-SPEC line 253 lock).

### Edit E — Call site update

```swift
IntroStep3SignInView(
    theme: theme,
    colorScheme: colorScheme,
    onSkip: dismissIntro,
    onSIWARequest: handleSIWARequest,
    onSIWACompletion: handleSIWACompletion
)
```

## dismissIntro() byte-identical preservation

```bash
$ git show HEAD~:gamekit/gamekit/Screens/IntroFlowView.swift | sed -n '/private func dismissIntro/,/^    }$/p' > /tmp/p5.txt
$ sed -n '/private func dismissIntro/,/^    }$/p' gamekit/gamekit/Screens/IntroFlowView.swift > /tmp/p6.txt
$ diff /tmp/p5.txt /tmp/p6.txt | wc -l
0
```

The function body (`settingsStore.hasSeenIntro = true` + `dismiss()`) is byte-identical between `HEAD~` (P5 + 06-07) and `HEAD` (this plan). Doc-comment was updated to mention the new third caller (SIWA-success), but the body — the load-bearing contract — is unchanged. T-06-introdismiss lock proven.

## Threat-model acceptance proofs

| Threat ID | Mitigation | Acceptance command | Result |
|-----------|------------|---------------------|--------|
| T-06-04 (requestedScopes drift) | `request.requestedScopes = []` LITERAL in handleSIWARequest | `grep -q 'request.requestedScopes = \[\]' …` | PASS |
| T-06-04 (no .email / .fullName) | Negative grep | `! grep -E '\.email\|\.fullName' …` | PASS (zero matches) |
| T-06-03 (one-shot JWT never persisted) | Handler extracts ONLY `credential.user` | `! grep -q 'identityToken' …` | PASS (zero matches) |
| T-06-PERSIST05 (silent failure) | No `.alert(` in IntroFlowView | `grep -c '\.alert(' …` returns 0 | PASS |
| T-06-introdismiss | `dismissIntro()` body byte-identical | `diff /tmp/p5.txt /tmp/p6.txt \| wc -l` | PASS (0) |

## Localizable.xcstrings — unchanged

This plan introduced **zero** new user-facing strings:
- All new code paths use `Self.logger.info/error` (not extracted by `SWIFT_EMIT_LOC_STRINGS`)
- `Restart to enable iCloud sync` / `Quit GameKit` / `Cancel` / body — already shipped Plan 06-06
- `SYNC` / `Signed in to iCloud` / `Last synced %@` — already shipped Plan 06-07
- `Syncing…` / `Synced just now` / `Synced %@` / `Not signed in` / `iCloud unavailable` — already shipped Plan 06-06 (extracted from SyncStatus.swift)
- `Sync across devices` / `Skip` / `Sign in with Apple to sync your stats…` — P5 strings preserved

All 12 P6 strings + all P5 intro strings verified present:

```bash
$ for s in "SYNC" "Signed in to iCloud" "Syncing" "Synced just now" \
           "Not signed in" "iCloud unavailable" \
           "Restart to enable iCloud sync" "Quit GameKit" \
           "Sync across devices" "Skip"; do
    grep -q "\"$s" gamekit/gamekit/Resources/Localizable.xcstrings && echo "PASS: $s"
  done
PASS: SYNC
PASS: Signed in to iCloud
PASS: Syncing
PASS: Synced just now
PASS: Not signed in
PASS: iCloud unavailable
PASS: Restart to enable iCloud sync
PASS: Quit GameKit
PASS: Sync across devices
PASS: Skip
```

JSON valid: `python3 -c "import json; json.load(...)"` exits 0.

## Verification gate proofs

| # | Acceptance | Result |
|---|------------|--------|
| A | `@Environment(\.authStore)` added | PASS |
| B | `handleSIWARequest` + `requestedScopes = []` literal | PASS |
| C | `handleSIWACompletion` + `signIn(userID: credential.user)` + `cloudSyncEnabled = true` + `shouldShowRestartPrompt = true` + `dismissIntro()` | PASS |
| D | `IntroStep3SignInView` signature: 2 closure props added, `onSignIn` removed | PASS |
| E | `signInTapped()` removed | PASS |
| F | T-06-04 negative grep — no `.email` / `.fullName` | PASS |
| G | T-06-03 negative grep — no `identityToken` | PASS |
| H | T-06-PERSIST05 — `.alert(` count = 0 | PASS |
| I | T-06-introdismiss — `dismissIntro()` body byte-identical (diff = 0 lines) | PASS |
| J | SIWA HIG style: `.signInWithAppleButtonStyle` + `.frame(height: 44)` preserved | PASS |
| K | CLAUDE.md §8.6 — no `.foregroundColor(` | PASS |
| L | File length ≤290 lines | PASS (289) |

## Build + test gate

```
xcodebuild build -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"
** BUILD SUCCEEDED **

xcodebuild test -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"
** TEST SUCCEEDED **
```

AuthStoreTests 7/7 + CloudSyncStatusObserverTests 9/9 + all P2-P5 suites green. No regression.

## Wave 2 status

With this commit, **Wave 2 is complete**:
- Plan 06-06: AuthStore + observer + scenePhase + Restart alert at app root (19f693b)
- Plan 06-07: Settings SYNC section + SettingsSyncSection extraction + xcstrings sync (9974f92)
- Plan 06-08: IntroFlow Step 3 SIWA wiring (a5bcfd9) **← this plan**

PERSIST-04 (anonymous → signed-in promotion via SIWA) is end-to-end functional. Both SIWA-success sites flip the same `authStore.shouldShowRestartPrompt` flag; the root-level alert (Plan 06-06) surfaces the Restart copy regardless of which site triggered.

## What's next (Wave 3)

- **Plan 06-03 Task 3 (checkpoint:human-verify)** — still pending; user must verify Xcode capabilities + run lldb schema-deploy + confirm CloudKit Dashboard Development env. Blocking for Plan 06-09 SC3 (real-CloudKit promotion test).
- **Plan 06-09** — manual SC1-SC5 verification per `06-VERIFICATION.md`. Includes 50-game promotion via 2-simulator iCloud test, sync-status 4-state observability, and cold-start <1s regression.

## Self-Check: PASSED

**Files:**
- FOUND: `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/Screens/IntroFlowView.swift` (289 lines)
- FOUND: `/Users/gabrielnielsen/Desktop/GameKit/.planning/phases/06-cloudkit-siwa/06-08-SUMMARY.md` (this file)

**Commit:**
- FOUND: `a5bcfd9 feat(06-08): wire IntroFlowView Step 3 SIWA onCompletion (replaces P5 D-21 no-op)`
