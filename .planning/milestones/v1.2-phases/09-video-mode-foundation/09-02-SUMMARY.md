---
phase: 09-video-mode-foundation
plan: 02
subsystem: core
tags: [video-mode, store, observable, environment-key, userdefaults, swift-6, main-actor, wave-1]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: 7 RED-state Swift Testing files locking the VideoModeStore + VideoModeLocation + EnvironmentValues.videoModeStore contract (from Plan 09-01)
provides:
  - VideoModeLocation enum (6 PiP zones, raw-string-stable, CaseIterable + Sendable, localizedLabel accessor)
  - VideoModeStore @Observable @MainActor final class (isEnabled + location stored properties, didSet UserDefaults writers, defensive corrupt-rawValue fallback)
  - EnvironmentValues.videoModeStore EnvironmentKey injection (deviation from plan — needed to unblock test-bundle compile; details below)
affects: [09-03-PLAN, 09-04-PLAN, 09-05-PLAN, 09-06-PLAN, 09-07-PLAN, 09-08-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable + @MainActor + final class — verbatim Phase 4 D-29 pattern from SettingsStore.swift:34-142"
    - "Stored property + didSet UserDefaults writer (NOT computed) — @Observable macro only tracks stored properties (09-RESEARCH Pitfall 1)"
    - "Defensive corrupt-rawValue fallback in init — VideoModeLocation(rawValue:) ?? .largeBottom handles hand-edited plist + future-version-added cases (RESEARCH Topic 3 invariant #4)"
    - "Per-property static UserDefaults key constants (Self.isEnabledKey / Self.locationKey) — locked rename = preference loss, mirrors SettingsStore convention"
    - "Custom EnvironmentKey for @Observable types — iOS-17-canonical seam (@EnvironmentObject is incompatible with @Observable per P4 RESEARCH Pitfall 1)"

key-files:
  created:
    - gamekit/gamekit/Core/VideoModeLocation.swift
    - gamekit/gamekit/Core/VideoModeStore.swift
  modified: []

key-decisions:
  - "EnvironmentKey extension shipped in 09-02 (not 09-03) — required to unblock test-bundle compile gate (VideoModeEnvironmentTests in same target references EnvironmentValues.videoModeStore); plan's split-to-09-03 design conflicted with hard success criterion 'VideoModeStoreTests tests all GREEN'. Smallest fix per CLAUDE.md §4. Plan 09-03 still ships the GameKitApp scene-root .environment(\\.videoModeStore, ...) injection and the GameKitAppTests GREEN flip."
  - "VideoModeLocation enum stays Foundation-only (no SwiftUI import) — keeps it reusable from engine layer, tests, and future snapshot rigs"
  - "Raw values locked as camelCase strings (largeTop, largeBottom, smallTopLeft, smallTopRight, smallBottomLeft, smallBottomRight) — D-07 vocabulary lock means rename = preference loss for existing installs"
  - "localizedLabel keys (videoMode.location.*) intentionally reference xcstrings entries that do not yet exist — Plan 09-04 ships the catalog entries. String(localized:) falls back to the key name in the gap (09-RESEARCH Pitfall 3 — accepted failure mode)"

patterns-established:
  - "Pattern: Phase 4 SettingsStore D-29 shape verbatim — copy header doc-block style, @Observable/@MainActor/final class triple-attribute, stored-property-with-didSet-writers, static-let UserDefaults-key constants, init(userDefaults:) signature. Future Phase 10/11 stores should follow this same shape."
  - "Pattern: Defensive enum-rawValue read in init — UserDefaults.string(forKey:) ?? \"\" + EnumType(rawValue:) ?? .defaultCase handles 3 failure modes (missing key / corrupt string / case added in newer app version then opened in older). Should be the default shape for any enum-typed UserDefaults preference."

requirements-completed: []
# Note: Plan 09-02 frontmatter declares requirements [VIDEO-01, VIDEO-02, VIDEO-03]
# but these are NOT marked complete here — the store foundation lands here but
# the user-visible deliverables (Settings card toggle, picker sub-screen, App-root
# injection wiring) ship in Plans 09-03 / 09-04 / 09-05. Requirement completion
# lands in those plans, not here.

# Metrics
duration: 6min
completed: 2026-05-13
---

# Phase 09 Plan 02: VideoModeStore + VideoModeLocation Summary

**VideoModeStore (@Observable @MainActor final class) + VideoModeLocation (6-case raw-string enum) ship as the foundation layer for Phase 9; all 6 Plan 09-01 VideoModeStoreTests + 1 VideoModeEnvironmentTests RED-state tests flip GREEN (bonus from deviation — see below).**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-05-13T00:49:49Z
- **Completed:** 2026-05-13T00:56:15Z
- **Tasks:** 2 / 2 completed
- **Files created:** 2
- **Files modified:** 0

## Accomplishments

- 2 new Core files at the exact paths declared in Plan 09-01's RED-gate contract: `gamekit/gamekit/Core/VideoModeLocation.swift` (55 lines) + `gamekit/gamekit/Core/VideoModeStore.swift` (113 lines including the EnvironmentKey extension)
- 6 VideoModeStoreTests tests flip RED → GREEN (`test_isEnabled_defaults_to_false`, `test_isEnabled_persists`, `test_location_default_is_largeBottom`, `test_location_persists_all_cases`, `test_location_enum_has_6_cases`, `test_corruptLocation_fallsBackToLargeBottom`)
- 1 VideoModeEnvironmentTests test flips RED → GREEN as a bonus from the EnvironmentKey deviation (`test_environmentKey_returns_injected`)
- Xcode 16 PBXFileSystemSynchronizedRootGroup auto-registered both new `Core/` files with zero `project.pbxproj` hand-patching (CLAUDE.md §8.8 validated empirically again)
- No `* 2.swift` Finder dupes; clean working tree apart from the pre-existing unrelated `Localizable.xcstrings` modification (left untouched)

## Task Commits

1. **Task 1: VideoModeLocation enum (D-07 vocabulary, 6 cases, localizedLabel accessor)** — `431b744` (feat)
2. **Task 2: VideoModeStore class + EnvironmentKey extension** — `8f7d42d` (feat)

**Plan metadata commit:** (pending — final commit lands after this SUMMARY.md + STATE.md + ROADMAP.md updates)

## Files Created/Modified

### Created (2 files)

- `gamekit/gamekit/Core/VideoModeLocation.swift` — 6-case raw-string enum (largeTop, largeBottom [D-03 default], smallTopLeft, smallTopRight, smallBottomLeft, smallBottomRight); `String + CaseIterable + Sendable` conformance; `localizedLabel: String` accessor sourcing `videoMode.location.*` keys (Plan 09-04 ships the catalog entries). Foundation-only — no SwiftUI import.
- `gamekit/gamekit/Core/VideoModeStore.swift` — `@Observable @MainActor final class VideoModeStore` with two stored properties (`isEnabled: Bool`, `location: VideoModeLocation`), both with `didSet` UserDefaults writers; static-let keys `isEnabledKey = "gamekit.videoModeEnabled"` + `locationKey = "gamekit.videoModeLocation"`; defensive init that handles missing/corrupt rawValue by falling back to `.largeBottom`. Includes EnvironmentKey extension (`VideoModeStoreKey: EnvironmentKey` + `extension EnvironmentValues { var videoModeStore }`) — see Deviations below.

### Static Constants Exported (downstream plans consume these)

| Constant | Value | Purpose |
| --- | --- | --- |
| `VideoModeStore.isEnabledKey` | `"gamekit.videoModeEnabled"` | UserDefaults key for the Off/On toggle (VIDEO-01) |
| `VideoModeStore.locationKey` | `"gamekit.videoModeLocation"` | UserDefaults key for the chosen PiP zone (VIDEO-02 / VIDEO-03) |

### Enum Cases (D-07 vocabulary lock — never rename)

| rawValue | localizedLabel key | Default? |
| --- | --- | --- |
| `largeTop` | `videoMode.location.largeTop` | |
| `largeBottom` | `videoMode.location.largeBottom` | yes (CONTEXT D-03) |
| `smallTopLeft` | `videoMode.location.smallTopLeft` | |
| `smallTopRight` | `videoMode.location.smallTopRight` | |
| `smallBottomLeft` | `videoMode.location.smallBottomLeft` | |
| `smallBottomRight` | `videoMode.location.smallBottomRight` | |

### Test-Suite Delta

| Test File | @Test func | Before 09-02 | After 09-02 |
| --- | --- | --- | --- |
| VideoModeStoreTests | test_isEnabled_persists | RED (compile fail) | **GREEN** |
| VideoModeStoreTests | test_isEnabled_defaults_to_false | RED (compile fail) | **GREEN** |
| VideoModeStoreTests | test_location_persists_all_cases | RED (compile fail) | **GREEN** |
| VideoModeStoreTests | test_location_default_is_largeBottom | RED (compile fail) | **GREEN** |
| VideoModeStoreTests | test_location_enum_has_6_cases | RED (compile fail) | **GREEN** |
| VideoModeStoreTests | test_corruptLocation_fallsBackToLargeBottom | RED (compile fail) | **GREEN** |
| VideoModeEnvironmentTests | test_environmentKey_returns_injected | RED (compile fail) | **GREEN** (bonus — deviation) |

Plan-declared expectation: 6/6 VideoModeStoreTests GREEN, VideoModeEnvironmentTests still RED (deferred to 09-03). Actual outcome: 7/7 GREEN because the EnvironmentKey deviation also flipped the env test.

Test verification command + result:
```
xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:gamekitTests/VideoModeStoreTests \
  -only-testing:gamekitTests/VideoModeEnvironmentTests
** TEST SUCCEEDED **
(7 test cases, all passed in <1 sec total)
```

## Decisions Made

- **Two stored properties with `didSet`, never computed** — locked by 09-RESEARCH Pitfall 1 / 09-PATTERNS Pitfall 1: `@Observable` macro only tracks stored properties; a computed `var location: VideoModeLocation { get { ... } set { ... } }` would persist writes correctly but SwiftUI views would not redraw on change. Mirrors `SettingsStore.swift:45-49` shape verbatim.
- **Defensive corrupt-rawValue fallback** — `VideoModeLocation(rawValue: userDefaults.string(forKey: Self.locationKey) ?? "") ?? .largeBottom` handles three failure modes: (1) missing UserDefaults key (fresh install), (2) value present but not matching any case (hand-edited plist, malicious tampering, value from a future app version that adds a 7th case), (3) any future serialization migration. Pattern should become the default shape for enum-typed UserDefaults reads (added to patterns-established).
- **No `register(defaults:)` call** — `UserDefaults.bool(forKey:)` returns `false` for unset keys per Apple docs, which is exactly the VIDEO-01 / ROADMAP SC1 default-Off contract. Adding `register(defaults:)` would be redundant code.
- **`localizedLabel` accessor accepts the silent-fallback gap** — `videoMode.location.*` xcstrings keys do not yet exist (Plan 09-04 ships them). In the gap, `String(localized:)` returns the key name itself (Apple-documented behavior). This is the 09-RESEARCH Pitfall 3 trade-off — accepted as the cost of decoupling enum shipping from catalog shipping.
- **EnvironmentKey shipped here, App-root injection deferred** — see Deviations below for rationale.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Shipped EnvironmentKey extension in 09-02 instead of deferring to 09-03**

- **Found during:** Task 2 verification (`xcodebuild test -only-testing:gamekitTests/VideoModeStoreTests` failed at build stage)
- **Issue:** Plan 09-02's `<action>` block (lines 313-318) explicitly says the `EnvironmentKey` extension ships in Plan 09-03 to keep injection-site review atomic. But Plan 09-01 shipped `VideoModeEnvironmentTests.swift` which references `EnvironmentValues.videoModeStore`. With the env test file present in the test target and that symbol absent, the entire test bundle fails to compile with `Value of type 'EnvironmentValues' has no member 'videoModeStore'` — meaning VideoModeStoreTests (and every other test in the target) cannot run. The plan's hard success criterion ("VideoModeStoreTests @Test funcs are all GREEN") is structurally unachievable as-written: GREEN requires the bundle to compile, the bundle requires the EnvironmentKey symbol, the symbol was deferred.
- **Fix:** Added the `EnvironmentKey` extension to the bottom of `VideoModeStore.swift` (lines 93-113), mirroring `SettingsStore.swift:144-155` shape verbatim. `private struct VideoModeStoreKey: EnvironmentKey { @MainActor static let defaultValue = VideoModeStore() }` + `extension EnvironmentValues { var videoModeStore: ... }`. The header doc-comment was updated to explain the change vs. plan.
- **Impact on 09-03:** Plan 09-03 is now scoped down to (a) wire `.environment(\\.videoModeStore, store)` at `GameKitApp` scene-root, (b) flip `GameKitAppTests/test_videoModeStore_injected_at_app_root` GREEN, (c) potentially own the shared store-instance lifecycle. The EnvironmentKey declaration itself is no longer 09-03's deliverable. Net 09-03 scope: smaller (good) — focused on injection-site wire-up.
- **Files modified:** `gamekit/gamekit/Core/VideoModeStore.swift` (added ~22 lines of extension + 8 lines of doc-comment update)
- **Commit:** `8f7d42d`

This deviation is also surfaced in 09-02-PLAN.md → 09-03-PLAN.md handoff (Plan 09-03 should grep `EnvironmentValues.videoModeStore` and confirm the symbol is already live).

## Issues Encountered

- Two `grep -q "Codable"` / `grep -q "nonisolated"` false positives during the in-line verify step — the plan's negative-grep checks matched substrings in the file's header doc-comment (e.g. "No `Codable` conformance" naturally contains "Codable"). Resolved by softening the doc-comment phrasing while preserving the meaning. No impact on the contract itself — the enum still has no `Codable` / `nonisolated` conformance.
- One pre-existing warning in `NonogramLibrary.swift:24` (`'nonisolated(unsafe)' is unnecessary`) surfaced in the build output. **Out of scope** for this plan per executor scope-boundary rules — logged as a deferred item for a future Nonogram-touching plan.

## TDD Gate Compliance

Plan 09-02 has `type: execute` at the plan level (not `tdd`) but its individual tasks carry `tdd="true"`. The RED gate is provided by Plan 09-01's seven test files (commits `74f6bb9` + `0b8f574`); this plan provides the GREEN production code that flips them. Gate sequence verified:

1. **RED gate present** (from Plan 09-01): `74f6bb9` (test) + `0b8f574` (test) — both already in `git log`.
2. **GREEN gate present** (this plan): `431b744` (feat, VideoModeLocation) + `8f7d42d` (feat, VideoModeStore + EnvironmentKey).
3. **Empirical GREEN verification:** `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests -only-testing:gamekitTests/VideoModeEnvironmentTests` → `** TEST SUCCEEDED **` (7/7 tests passed).
4. **REFACTOR gate:** not required — production code mirrors the Plan 09-01 contract verbatim with no cleanup needed.

## User Setup Required

None — no external service configuration required. UserDefaults backing is automatic via `UserDefaults.standard`.

## Next Phase Readiness

- **Plan 09-03 (Wave 2 — GameKitApp scene-root injection):** Can now wire `.environment(\\.videoModeStore, store)` at the App entry point. The EnvironmentKey symbol is already live (deviation note above), so 09-03 only owns the App-root `@State`/`@Bindable` lifecycle and the `GameKitAppTests` GREEN flip. Scope: smaller than originally planned.
- **Plan 09-04 (Wave 2 — Localizable.xcstrings videoMode.* keys):** Can author the 13 `videoMode.*` entries; the `localizedLabel` accessor on `VideoModeLocation` is wired to consume them. Until 09-04 lands, `String(localized:)` returns the key name itself (accepted Pitfall 3 gap).
- **Plan 09-05 (Wave 3 — Settings card UI):** Can author the VIDEO MODE Settings section, `Bindable(videoModeStore).isEnabled` for the Toggle, and the `NavigationLink` to the picker sub-screen.
- **Plan 09-06 (Wave 3 — VideoLocationPickerView):** Can author the 6-zone picker UI; `Bindable(videoModeStore).location` is the source-of-truth binding.
- **Plans 09-07 / 09-08:** Can build downstream consumers (compact row, SC5 regression) against the locked store contract.

**No blockers.** Foundation layer fully shipped.

---
*Phase: 09-video-mode-foundation*
*Completed: 2026-05-13*

## Self-Check: PASSED

- File `gamekit/gamekit/Core/VideoModeLocation.swift` — FOUND (55 lines)
- File `gamekit/gamekit/Core/VideoModeStore.swift` — FOUND (113 lines)
- Commit `431b744` (Task 1) — FOUND in `git log --oneline --all`
- Commit `8f7d42d` (Task 2) — FOUND in `git log --oneline --all`
- `xcodebuild test` for both VideoMode test suites — `** TEST SUCCEEDED **` (7/7 GREEN)
