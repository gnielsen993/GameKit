---
phase: 06-cloudkit-siwa
plan: 06
subsystem: app-wiring / scenephase / alert
tags:
  - app-wiring
  - alert
  - scenephase
  - wave-2
requires:
  - 06-04  # AuthStore (provides shouldShowRestartPrompt + validateOnSceneActive + isSignedIn)
  - 06-05  # CloudSyncStatusObserver (provides @Environment seam)
provides:
  - "GameKitApp constructs + injects \\.authStore + \\.cloudSyncStatusObserver into root scene Environment"
  - "RootTabView observes scenePhase → AuthStore.validateOnSceneActive() on .active (D-14)"
  - "RootTabView observes authStore.isSignedIn true→false → flips settingsStore.cloudSyncEnabled = false (T-06-08)"
  - "Root-level Restart prompt .alert bound to Bindable(authStore).shouldShowRestartPrompt (D-03 single source of truth)"
affects:
  - 06-07  # SettingsView SYNC section consumes \.authStore + \.cloudSyncStatusObserver and flips shouldShowRestartPrompt
  - 06-08  # IntroFlowView SIWA wire-up flips shouldShowRestartPrompt on success
tech-stack:
  added: []      # no new frameworks; all primitives from P5 + 06-04 + 06-05
  patterns:
    - "EnvironmentKey injection for @Observable (mirrors P4 D-29 / P5 D-12)"
    - "scenePhase observer + Task hop for @MainActor async lifecycle"
    - "Root-level .alert(isPresented: Bindable(authStore).shouldShowRestartPrompt)"
    - "xcstringstool sync (deterministic CLI catalog population — STATE.md 04-05 / 05-04 precedent)"
key-files:
  created: []
  modified:
    - gamekit/gamekit/App/GameKitApp.swift          # 92 → 129 lines (+37 incl. blank lines)
    - gamekit/gamekit/Screens/RootTabView.swift     # 57 → 107 lines (+50 incl. blank lines)
    - gamekit/gamekit/Resources/Localizable.xcstrings  # 741 → 765 lines (+24, additive only)
decisions:
  - "06-06: AuthStore + CloudSyncStatusObserver constructed in init() AFTER SettingsStore + SFXPlayer + BEFORE ModelContainer — preserves the P4 D-08 read of cloudSyncEnabled for the cloudKitDatabase ternary AND lets the observer's initialStatus read the same flag (single read, two consumers)."
  - "06-06: Restart prompt .alert lives on RootTabView body, not on WindowGroup — keeps RootTabView the single source of truth for view-tree-scoped lifecycle modifiers (PATTERNS §8 line 491). Bindable(authStore) is constructed in-place at the .alert call site (no @Bindable property needed because @Observable + Bindable inits cheaply)."
  - "06-06: Quit GameKit button is empty-body Button — no programmatic termination of any kind (App Store Review red flag T-06-05). Comment in source rewords the lock without naming the literal API tokens so the negative-grep gate stays clean (same self-imposed-grep-discipline pattern as the 'no-@Attribute(.unique)' comment in Plan 04-01)."
  - "06-06: Revocation→cloudSync flip lives in RootTabView .onChange(of: authStore.isSignedIn), not inside AuthStore. Keeps AuthStore single-responsibility (Q2 RESOLVED in 06-04 Summary — AuthStore does NOT inject SettingsStore). RootTabView is the natural composition site because it already injects both Environment values."
  - "06-06: xcstringstool sync picked up 4 SyncStatus labels (Plan 06-02 source) alongside the 4 Restart alert strings — both arrived in the same sync because the catalog hadn't been resynced since 06-02 shipped. The 4 SyncStatus strings (Syncing… / Synced just now / Synced %@ / iCloud unavailable / Not signed in) will be consumed by Plan 06-07 SettingsView SYNC row; carrying them now is forward-progress with zero downside (all empty-body { } entries resolve to the development-language source string at runtime — same shape as pre-existing 'Privacy', 'Reset all stats', etc.)."
metrics:
  duration_minutes: 6
  completed_date: "2026-04-27"
  task_count: 3
  file_count: 3
commit: 19f693b
---

# Phase 06 Plan 06: AuthStore + Observer + scenePhase + Restart alert at app root — Summary

Wave-2 integration #1 — wires AuthStore (06-04) + CloudSyncStatusObserver (06-05) into the app DI root + scene-phase lifecycle + the root-level Restart prompt alert (D-01..D-06). All three file edits ship in a single atomic commit per CLAUDE.md §8.10.

## What shipped

### Task 1 — `gamekit/gamekit/App/GameKitApp.swift` (+37 lines)

Additive only:

1. Two new `@State` properties: `authStore: AuthStore`, `cloudSyncStatusObserver: CloudSyncStatusObserver` (lines 41-42).
2. `init()` body inserts AuthStore + CloudSyncStatusObserver construction AFTER SFXPlayer and BEFORE the schema/ModelContainer block (lines 58-73). Observer initialStatus reads `store.cloudSyncEnabled ? .syncing : .notSignedIn` (CONTEXT Specifics line 204).
3. Body environment chain gains 2 modifiers: `.environment(\.authStore, authStore)` + `.environment(\.cloudSyncStatusObserver, cloudSyncStatusObserver)` (lines 99-100), inserted BEFORE `.preferredColorScheme(...)`.

**Byte-identical preservations (verified via `git diff` showing 0 deletions):**
- `let store = SettingsStore()` / `_settingsStore = State(initialValue: store)` (P4 D-29)
- `let sfx = SFXPlayer()` / `_sfxPlayer = State(initialValue: sfx)` (P5 D-12)
- `let schema = Schema([GameRecord.self, BestTime.self])` (P4 D-07)
- `cloudKitDatabase: store.cloudSyncEnabled ? .private("iCloud.com.lauterstar.gamekit") : .none` (P4 D-08 + T-06-06 container ID lock)
- do/catch + `fatalError("Failed to construct shared ModelContainer: \(error)")` (P4 RESEARCH §Code Examples 1)
- `.environmentObject(themeManager)` / `.environment(\.settingsStore, settingsStore)` / `.environment(\.sfxPlayer, sfxPlayer)` / `.preferredColorScheme(preferredScheme)` / `.modelContainer(sharedContainer)`
- `#if DEBUG static func _runtimeDeployCloudKitSchema()` (P6 03 Pitfall D mitigation)

### Task 2 — `gamekit/gamekit/Screens/RootTabView.swift` (+50 lines)

Six additive changes:

1. **Header doc comment** — appended P6 paragraph documenting D-03/D-13/D-14 (lines 16-23).
2. **Two new `@Environment` properties** after `@Environment(\.settingsStore)`: `\.scenePhase`, `\.authStore` (lines 33-34). Note: `\.cloudSyncStatusObserver` is consumed by SettingsView only (Plan 06-07), not RootTabView.
3. **`.onChange(of: scenePhase)`** — on transition to `.active`, fires `Task { await authStore.validateOnSceneActive() }` (D-14 silent revocation catch; AuthStore early-returns when not signed in — Pitfall G).
4. **`.onChange(of: authStore.isSignedIn)`** — on `true→false` transition (revocation), sets `settingsStore.cloudSyncEnabled = false` (T-06-08; container reconfigs to `.none` on next cold start; same-store-path D-08 preserves local rows; cloud rows preserved server-side per Pitfall 4).
5. **Root `.alert(...)`** bound to `Bindable(authStore).shouldShowRestartPrompt` with verbatim D-04 copy.
6. The existing `selectedTab`, `isIntroPresented`, `.fullScreenCover`, `.onAppear { hasSeenIntro check }` chain stays BYTE-IDENTICAL.

### Task 3 — `gamekit/gamekit/Resources/Localizable.xcstrings` (+24 lines, additive only)

`xcrun xcstringstool sync` invoked against 46 .stringsdata files; result: 8 new keys appended (no orphans removed, no existing entries modified).

## Verbatim grep proofs

### D-04 Restart alert copy (exact strings present in source)

```
$ grep -c '"Restart to enable iCloud sync"'    gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c '"Quit GameKit"'                      gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c '"Cancel"'                            gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c "Your stats will sync to all devices signed in to this iCloud account. Quit GameKit and reopen to finish setup." gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c 'role: .cancel'                       gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c 'Bindable(authStore).shouldShowRestartPrompt' gamekit/gamekit/Screens/RootTabView.swift  # 1
```

### scenePhase observer + revocation flip (D-14 + T-06-08)

```
$ grep -c '\.onChange(of: scenePhase)'             gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c 'newPhase == .active'                    gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c 'await authStore.validateOnSceneActive()' gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c '\.onChange(of: authStore.isSignedIn)'   gamekit/gamekit/Screens/RootTabView.swift  # 1
$ grep -c 'settingsStore.cloudSyncEnabled = false' gamekit/gamekit/Screens/RootTabView.swift  # 2  (one in source, one in comment)
```

### T-06-05 / D-05 LOCK — programmatic termination ABSENT

```
$ grep -E "exit\(0\)|UIApplication\.shared\.suspend|abort\(\)" gamekit/gamekit/Screens/RootTabView.swift
[no matches]
$ echo $?
1   # grep exit 1 = "no matches" = PASS

$ grep -E "exit\(0\)|UIApplication\.shared\.suspend|abort\(\)" gamekit/gamekit/App/GameKitApp.swift
[no matches]
$ echo $?
1   # PASS

$ grep -E "exit\(|abort\(|UIApplication.*suspend" gamekit/gamekit/Screens/RootTabView.swift
[no matches]
$ echo $?
1   # PASS — broader gate from success_criteria also clean
```

### T-06-06 container ID lock preserved

```
$ grep -c '\.private("iCloud.com.lauterstar.gamekit")' gamekit/gamekit/App/GameKitApp.swift
1
```

Container ID literal is at line 79 of the post-edit file; cloudKitDatabase ternary unchanged.

### Construction-order proof

```
$ grep -n "let store = SettingsStore()\|let sfx = SFXPlayer()\|let auth = AuthStore()\|CloudSyncStatusObserver(\|let schema = Schema" gamekit/gamekit/App/GameKitApp.swift
48:        let store = SettingsStore()
55:        let sfx = SFXPlayer()
62:        let auth = AuthStore()
70:        let observer = CloudSyncStatusObserver(
75:        let schema = Schema([GameRecord.self, BestTime.self])
```

Order: SettingsStore → SFXPlayer → AuthStore → CloudSyncStatusObserver → schema → ModelContainer. Matches plan §interfaces line 47-65 exactly.

## xcstringstool sync invocation

```
cd /Users/gabrielnielsen/Desktop/GameKit/gamekit
ARGS=()
while IFS= read -r f; do
  ARGS+=(--stringsdata "$f")
done < <(find /tmp/gamekit-derived/...arm64 -name "*.stringsdata" -type f)
# 46 files → 92 ARGS entries

xcrun xcstringstool sync gamekit/Resources/Localizable.xcstrings "${ARGS[@]}"
# (no output = clean sync; xcstringstool only prints on warning/error)
```

Catalog diff stat:

```
$ git diff --stat HEAD~ -- gamekit/gamekit/Resources/Localizable.xcstrings
 gamekit/gamekit/Resources/Localizable.xcstrings | 24 ++++++++++++++++++++++++
 1 file changed, 24 insertions(+)
```

8 new keys (4 Restart-alert + 4 SyncStatus labels carrying forward from Plan 06-02), zero deletions, zero pre-existing entries modified. JSON validity: `python3 -c "import json; json.load(open('...'))"` exits 0.

## Build + test results

- `xcodebuild build -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"` → `** BUILD SUCCEEDED **`, zero `Localizable` warnings.
- `xcodebuild test -scheme gamekit -destination "id=A55E88EB-1176-47C0-84D8-F1A781AA5F48"` → `** TEST SUCCEEDED **`. All previously-green suites still green:
  - 9/9 CloudSyncStatusObserverTests
  - 7/7 AuthStoreTests
  - SettingsStoreFlagsTests, MinesweeperPhaseTransitionTests, MinesweeperViewModelTests (multiple suites), GameStatsTests, etc.
  - gamekitUITestsLaunchTests + gamekitUITests.testExample / testLaunchPerformance.

## File line counts

| File | Before | After | Budget | Result |
|------|--------|-------|--------|--------|
| gamekit/gamekit/App/GameKitApp.swift | 92 | 129 | ≤ 130 | PASS |
| gamekit/gamekit/Screens/RootTabView.swift | 57 | 107 | ≤ 110 | PASS |
| gamekit/gamekit/Resources/Localizable.xcstrings | 741 | 765 | n/a (catalog) | additive only |

## Deviations from Plan

None — plan executed exactly as written.

One micro-touch worth noting: the inline comment on the Quit GameKit button was reworded once during Task 2 to remove the literal substrings `exit(0)`, `UIApplication.shared.suspend`, and `abort()` from comment text. The original comment quoted those API names as part of the documentation lock; the regex acceptance criterion `! grep -E "exit\(0\)|UIApplication\.shared\.suspend|abort\(\)"` matches regardless of code-vs-comment context. Final comment reads:

```swift
Button(String(localized: "Quit GameKit")) {
    // T-06-05 / D-05 LOCK: dismiss-only — no programmatic
    // termination of any kind (App Store Review red flag).
    // The body copy instructs the user to manually swipe
    // up from the app switcher and reopen; that
    // user-initiated action is the only Review-compliant
    // termination path.
}
```

This preserves the documentation intent (future readers see the "no programmatic termination" lock with full context) while keeping the negative-grep gate clean. Same discipline as the P4 04-01 "no SwiftData unique-attribute decorator" comment rewording.

## Self-Check: PASSED

```
$ [ -f gamekit/gamekit/App/GameKitApp.swift ]; echo $?           # 0 FOUND
$ [ -f gamekit/gamekit/Screens/RootTabView.swift ]; echo $?       # 0 FOUND
$ [ -f gamekit/gamekit/Resources/Localizable.xcstrings ]; echo $? # 0 FOUND
$ git log --oneline --all | grep -q "19f693b" && echo FOUND       # FOUND
```

Commit hash `19f693b` present in history; all 3 modified files exist on disk.

## Threat Flags

None — Plan 06-06 does not introduce any new network endpoint, auth path, file access pattern, or schema change. The trust boundaries it crosses (App boot ↔ construction order, Alert button ↔ programmatic termination) are already enumerated in the plan's `<threat_model>` register and mitigated as documented (T-06-05 / T-06-06 / T-06-08).

## Forward dependencies unblocked

Plans 06-07 (SettingsView SYNC section) and 06-08 (IntroFlowView SIWA wire-up) can now consume `@Environment(\.authStore)` + `@Environment(\.cloudSyncStatusObserver)` directly and flip `authStore.shouldShowRestartPrompt = true` on SIWA-success to surface the root alert.
