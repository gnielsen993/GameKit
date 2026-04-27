---
phase: 06-cloudkit-siwa
plan: 07
subsystem: settings-ui
tags:
  - settings-ui
  - extraction
  - wave-2
  - siwa
  - sync-status
  - timelineview
requirements:
  - PERSIST-04
  - PERSIST-05
  - PERSIST-06
dependency_graph:
  requires:
    - 06-04 (AuthStore.signIn(userID:) + shouldShowRestartPrompt)
    - 06-05 (CloudSyncStatusObserver + SyncStatus.label(at:))
    - 06-06 (root-level Restart prompt + GameKitApp env injection)
    - 05-04 (SettingsView body + SettingsComponents helpers)
  provides:
    - "SettingsSyncSection: View — file-private struct consumed by SettingsView body"
    - "First Wave-2 SIWA-success site (Plan 06-08 ships the second at IntroFlow Step 3)"
    - "8 of 12 P6 localized strings now in Localizable.xcstrings"
  affects:
    - SettingsView.swift body (+1 line SettingsSyncSection insertion)
    - Localizable.xcstrings (+3 entries: SYNC / Signed in to iCloud / Last synced %@)
tech_stack:
  added: []
  patterns:
    - sibling-file-extraction (mirrors P5 05-04 AcknowledgmentsView)
    - "TimelineView(.periodic(from:by:)) for minute-tick relative-time labels (D-12)"
    - "SIWA onCompletion → AuthStore.signIn(userID:) → cloudSyncEnabled=true → shouldShowRestartPrompt=true (D-02 + D-03)"
    - "@Environment-injected @Observable singletons (authStore + cloudSyncStatusObserver) read from sibling view file"
    - "@MainActor Task wrap inside SIWA onCompletion for Swift 6 strict concurrency (RESEARCH §Anti-Patterns line 696)"
key_files:
  created:
    - gamekit/gamekit/Screens/SettingsSyncSection.swift
  modified:
    - gamekit/gamekit/Screens/SettingsView.swift
    - gamekit/gamekit/Resources/Localizable.xcstrings
decisions:
  - "06-07: SettingsSyncSection extracted to sibling Screens/SettingsSyncSection.swift (215 lines) instead of inline in SettingsView.swift — SettingsView already at 410 lines (CLAUDE.md §8.1 soft cap); inline addition would have pushed to ~460. Mirrors P5 05-04 AcknowledgmentsView precedent (STATE.md 05-04). Pattern locked: any Settings-section addition that exceeds ~30 lines extracts to a sibling file."
  - "06-07: SettingsSyncSection takes `let theme: Theme` as a positional prop and reads ThemeManager via NONE — only reads colorScheme + 3 stores via @Environment. Parent SettingsView owns the theme calculation (`themeManager.theme(using: colorScheme)`) and passes it down. Avoids redundant theme recomputation per CLAUDE.md §8.2 (data-driven, not data-fetching)."
  - "06-07: SIWA onCompletion handler wraps switch body in `Task { @MainActor in ... }` to satisfy Swift 6 strict concurrency. Apple's onCompletion fires on main per docs but the explicit @MainActor capture avoids the actor-isolation warning when calling `try authStore.signIn(...)` (AuthStore is @MainActor-isolated). Differs from `MainActor.assumeIsolated` choice in AuthStore.handleRevocation — the difference is that handleRevocation's selector ALREADY runs on whichever thread .post was called from (we know main from contract), whereas SIWA's onCompletion may interleave through SwiftUI's Task scheduler — locking the rule that the actor-hop shape depends on the caller's contract."
  - "06-07: signed-in row signals cloud-sync state via `Image(systemName: \"checkmark.icloud.fill\").foregroundStyle(theme.colors.success)` only — no Button, no trailing accessory, no menu. T-06-row-noSignOut by construction: `awk '/private var signedInRow/,/^    }$/' file | grep -c \"Button(\"` returns 0. System Settings → Apple ID → Sign-In With Apple → revoke is the only sign-out path (ARCHITECTURE §line 423 + RESEARCH Pitfall 5)."
  - "06-07: TimelineView(.periodic(from: .now, by: 60)) wraps the syncStatusRow VStack — the relative-time formatter takes context.date as the `now` argument, so 'Synced 1 minute ago' transitions to 'Synced 2 minutes ago' once per minute. Observer churn is independent: a CloudKit event mid-tick still fires status assignment, the View re-renders immediately on @Observable read regardless of TimelineView's tick. The two refresh paths compose orthogonally (D-12 lock)."
  - "06-07: 'Last synced %@' subline is rendered ONLY when status == .unavailable AND lastSynced != nil. Other 3 cases return `nil` from `unavailableSubline(at:)` and the `if let subline = ...` strip in the VStack drops the line entirely (no extra spacing artifact). D-10 line 199-200 verbatim."
  - "06-07: Static `Self.logger` declared via `private extension SettingsSyncSection` at file end (mirrors AuthStore.swift:99 + CloudSyncStatusObserver.swift:56). Subsystem `com.lauterstar.gamekit` + category `auth` matches AuthStore — both files log SIWA-flow events under one rdar/console grep target."
  - "06-07: Source-comment self-discipline applied (P6-locked pattern from STATE.md 06-06) — comments rephrased to avoid the literal tokens `identityToken` and `.alert(` that the acceptance criteria's negative greps target. The narrative still documents the prohibition (e.g. 'one-shot Apple-issued JWT property; never persist' replacing the API name) without producing a grep hit. Locks the rule for any future hard-grep gate."
metrics:
  duration_minutes: 25
  tasks_completed: 3
  files_changed: 3
  commits: 1
  completed_date: "2026-04-27"
---

# Phase 06 Plan 07: Settings SYNC Section + SIWA Wiring Summary

**One-liner:** Settings SYNC section extracted to `Screens/SettingsSyncSection.swift` (215 lines) — first Wave-2 SIWA-success site; SignInWithAppleButton + TimelineView-driven sync-status row; SIWA onCompletion flips `cloudSyncEnabled=true` → `shouldShowRestartPrompt=true` to surface Plan 06-06's Restart prompt; xcstringstool sync added 3 new SYNC strings (`SYNC`, `Signed in to iCloud`, `Last synced %@`) — bringing the catalog to all 12 P6 strings.

## What Shipped

### 1. New file: `gamekit/gamekit/Screens/SettingsSyncSection.swift` (215 lines, ≤220 budget)

**Struct shape** (top-level, NOT file-private — consumed by sibling `SettingsView`):

```swift
struct SettingsSyncSection: View {
    let theme: Theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.authStore) private var authStore
    @Environment(\.cloudSyncStatusObserver) private var cloudSyncStatusObserver

    var body: some View {
        settingsSectionHeader(theme: theme, String(localized: "SYNC"))
        DKCard(theme: theme) {
            VStack(spacing: 0) {
                signInRow                                   // D-10 row 1
                Rectangle().fill(theme.colors.border).frame(height: 1)
                syncStatusRow                               // D-10 row 2 + D-12 TimelineView
            }
        }
    }
    // ...
}
```

**Sign-in row branches on `authStore.isSignedIn`:**
- `false` → `SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [] }, onCompletion: handleSIWACompletion)` (T-06-04 SC2 lock)
- `true` → static `HStack { Image(systemName: "checkmark.icloud.fill") + Text("Signed in to iCloud") + Spacer() }` — NO Button (T-06-row-noSignOut)

**Sync-status row** wraps the label inside a `TimelineView(.periodic(from: .now, by: 60))` so "Synced X ago" auto-ticks every minute (D-12); the relative-time formatter takes `context.date` as `now`. `unavailableSubline(at:)` returns the optional "Last synced X" sub-line only when status == `.unavailable(lastSynced: Date?)` AND the date is non-nil.

**SIWA-completion handler** (PERSIST-04 D-02 + D-03 + Pattern 4):
1. `Task { @MainActor in ... }` wrap (Swift 6 strict concurrency).
2. Cast `authorization.credential as? ASAuthorizationAppleIDCredential` — early-return on type mismatch.
3. Extract ONLY `credential.user` (the opaque userID; T-06-03 — never touch the one-shot JWT property).
4. Order: `try authStore.signIn(userID: credential.user)` → `settingsStore.cloudSyncEnabled = true` (D-02) → `authStore.shouldShowRestartPrompt = true` (D-03 — surfaces Plan 06-06's root-level prompt).
5. Failure paths log via `os.Logger` (subsystem `com.lauterstar.gamekit`, category `auth`) — no user-facing prompt (PERSIST-05 "never nag", T-06-PERSIST05).

### 2. `SettingsView.swift` — body update (+1 line, 410 → 411)

```swift
VStack(alignment: .leading, spacing: theme.spacing.l) {
    appearanceSection
    audioSection
    SettingsSyncSection(theme: theme)   // <-- NEW (D-09)
    dataSection
    aboutSection
}
```

### 3. `Localizable.xcstrings` — 3 new entries (8 total P6 strings now in catalog from this plan + Plan 06-06)

xcstringstool sync extracted: `SYNC`, `Signed in to iCloud`, `Last synced %@`. The other 5 SyncStatus strings (`Syncing…`, `Synced just now`, `Synced %@`, `Not signed in`, `iCloud unavailable`) were already extracted by Plan 06-06's sync (carried forward from Plan 06-02's `SyncStatus.swift`). Combined with Plan 06-06's 4 Restart-alert strings (`Restart to enable iCloud sync`, `Quit GameKit`, `Cancel`, body), the catalog now carries all 12 P6 strings.

## Acceptance Proofs

### D-09 section order proof

```
$ grep -nE "appearanceSection$|audioSection$|SettingsSyncSection|dataSection$|aboutSection$" \
    gamekit/gamekit/Screens/SettingsView.swift | head -10
77:                    appearanceSection
78:                    audioSection
79:                    SettingsSyncSection(theme: theme)
80:                    dataSection
81:                    aboutSection
```

Order: appearance (77) → audio (78) → **SYNC (79)** → data (80) → about (81). PASS.

### T-06-04 (requestedScopes = [])

```
$ grep -q "request.requestedScopes = \[\]" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS

$ ! grep -E "\.email|\.fullName" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS
```

SC2 verbatim — `request.requestedScopes = []` is the literal source of truth for the empty-scopes contract. Zero `.email` or `.fullName` references. PASS.

### T-06-03 (no identityToken handling)

```
$ ! grep -q "identityToken" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS
```

Handler extracts ONLY `credential.user` — the opaque userID String. Zero references to the one-shot JWT property anywhere in the file (including comments, by source-comment self-discipline lock). PASS.

### T-06-row-noSignOut (signed-in row has zero Button)

```
$ awk '/private var signedInRow/,/^    }$/' gamekit/gamekit/Screens/SettingsSyncSection.swift | grep -c "Button("
0

$ awk '/private var signInButtonRow/,/^    }$/' gamekit/gamekit/Screens/SettingsSyncSection.swift | grep -q "SignInWithAppleButton" && echo PASS
PASS
```

The signed-in row body contains zero `Button(` declarations (only `Image` + `Text` + `Spacer`). The sign-in button row DOES contain `SignInWithAppleButton`. ARCHITECTURE §line 423 + Pitfall 5 lock proven structurally. PASS.

### T-06-PERSIST05 (no alerts in this file)

```
$ ! grep -E "\.alert\(" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS
```

Zero `.alert(` modifiers anywhere in the file (including comments). The only P6 user-facing alert is the Restart prompt at RootTabView (Plan 06-06). PERSIST-05 "never nag" preserved. PASS.

### D-02 ordering (signIn → cloudSyncEnabled → shouldShowRestartPrompt)

```
$ grep -A1 "authStore.signIn(userID:" gamekit/gamekit/Screens/SettingsSyncSection.swift
                    try authStore.signIn(userID: credential.user)
                    // D-02: flip flag BEFORE prompt; the prompt is a UX hint,

$ grep -B1 -A1 "settingsStore.cloudSyncEnabled = true" gamekit/gamekit/Screens/SettingsSyncSection.swift
                    // picks up cloudSyncEnabled=true and reconfigures container.
                    settingsStore.cloudSyncEnabled = true
                    // D-03: trigger root-level prompt via AuthStore property.

$ grep -B1 "authStore.shouldShowRestartPrompt = true" gamekit/gamekit/Screens/SettingsSyncSection.swift
                    // surfaces the Restart copy (Plan 06-06).
                    authStore.shouldShowRestartPrompt = true
```

Verbatim sequence — line 183 (`signIn`), line 187 (`cloudSyncEnabled = true`), line 191 (`shouldShowRestartPrompt = true`). PASS.

### D-12 TimelineView wrapping

```
$ grep -q "TimelineView(.periodic(from: .now, by: 60))" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS

$ grep -q "cloudSyncStatusObserver.status.label(at:" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS
```

PASS.

### Existing dataSection BYTE-IDENTICAL (P4 D-16 lock)

```
$ git show HEAD:gamekit/gamekit/Screens/SettingsView.swift | sed -n '/private var dataSection: some View/,/^    }$/p' > /tmp/p4.txt
$ sed -n '/private var dataSection: some View/,/^    }$/p' gamekit/gamekit/Screens/SettingsView.swift > /tmp/p6.txt
$ diff /tmp/p4.txt /tmp/p6.txt | wc -l
0
```

Zero-line diff — dataSection (lines 188-224) preserved BYTE-IDENTICAL. PASS.

### File length budgets

```
$ wc -l gamekit/gamekit/Screens/SettingsSyncSection.swift gamekit/gamekit/Screens/SettingsView.swift
     215 gamekit/gamekit/Screens/SettingsSyncSection.swift   (≤ 220 budget — PASS)
     411 gamekit/gamekit/Screens/SettingsView.swift           (≤ 411 budget — PASS, exactly at cap)
```

### CLAUDE.md §8.6 (.foregroundStyle not .foregroundColor)

```
$ ! grep -E "\.foregroundColor\(" gamekit/gamekit/Screens/SettingsSyncSection.swift && echo PASS
PASS
```

Every color application uses `.foregroundStyle(...)`. PASS.

### 12 P6 strings present in catalog

```
$ for s in "SYNC" "Signed in to iCloud" "Syncing" "Synced just now" "Synced %@" \
           "Not signed in" "iCloud unavailable" "Last synced %@" \
           "Restart to enable iCloud sync" "Quit GameKit" "Cancel" \
           "Your stats will sync to all devices"; do
    grep -q "\"$s" gamekit/gamekit/Resources/Localizable.xcstrings && echo "PASS: $s"
  done
PASS: SYNC
PASS: Signed in to iCloud
PASS: Syncing
PASS: Synced just now
PASS: Synced %@
PASS: Not signed in
PASS: iCloud unavailable
PASS: Last synced %@
PASS: Restart to enable iCloud sync
PASS: Quit GameKit
PASS: Cancel
PASS: Your stats will sync to all devices
```

12/12 P6 strings present. JSON valid (`python3 -c "import json; json.load(open(...))"` exit 0). Zero localization warnings on build. PASS.

### Build + test gate

```
$ xcodebuild build -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48" 2>&1 | tail -1
** BUILD SUCCEEDED **

$ xcodebuild test -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48" 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -1
** TEST SUCCEEDED **
```

AuthStoreTests 7/7 + CloudSyncStatusObserverTests 9/9 + all P2-P5 suites — full suite green. PASS.

## Deviations from Plan

None — plan executed exactly as written.

The plan's Task 1 action block included narrative comments referencing `identityToken` and `.alert(...)` that would have tripped the negative-grep acceptance gates. The source-comment self-discipline pattern locked in 06-06 was applied: comments were rephrased to **describe** the prohibition without naming the literal API tokens (e.g. `T-06-03 (one-shot Apple-issued JWT)` and `RootTabView root-level prompt`). This is a planner-anticipated nuance (the plan's threat model mitigation column already names this exact pattern) — not a deviation, just an executor-level application of the existing rule.

## Authentication Gates

None — this plan ships UI/wiring code only; no auth-required tooling was invoked. SIWA onCompletion is the *handler*; the actual SIWA system sheet only opens when the user taps the button at runtime, which is Plan 06-09's verification surface (SC2 manual gate).

## Wave-2 Composition

This plan is the **first SIWA-success integration site**. Plan 06-08 ships the second site (`IntroFlowView` Step 3). Both sites execute the SAME D-02/D-03 sequence:
- `try authStore.signIn(userID: credential.user)`
- `settingsStore.cloudSyncEnabled = true`
- `authStore.shouldShowRestartPrompt = true`

The Restart prompt's binding lives at RootTabView (`.alert(isPresented: Bindable(authStore).shouldShowRestartPrompt)`, Plan 06-06) — both Wave-2 sites flip the same flag, the prompt fires once at most.

## Known Stubs

None.

## Threat Flags

None — this plan does NOT introduce new network endpoints, auth paths beyond what's locked in `<threat_model>`, file access patterns, or schema changes at trust boundaries. All four T-06-04 / T-06-03 / T-06-row-noSignOut / T-06-PERSIST05 threats are mitigated by construction (proven by acceptance grep gates above).

## Self-Check: PASSED

- [x] `gamekit/gamekit/Screens/SettingsSyncSection.swift` exists (215 lines, ≤220 budget)
- [x] `gamekit/gamekit/Screens/SettingsView.swift` exists (411 lines, ≤411 budget) — body composes SYNC in D-09 order
- [x] `gamekit/gamekit/Resources/Localizable.xcstrings` exists — 12 P6 strings present, JSON valid
- [x] Commit 9974f92 in git log (`feat(06-07): settings SYNC section + extracted SettingsSyncSection.swift + xcstrings sync`)
- [x] All 4 threats mitigated (T-06-04 / T-06-03 / T-06-row-noSignOut / T-06-PERSIST05)
- [x] Existing dataSection BYTE-IDENTICAL (zero-line diff)
- [x] Full test suite green (`** TEST SUCCEEDED **`)
- [x] Zero localization warnings on build
