---
phase: 09-video-mode-foundation
plan: 01
subsystem: testing
tags: [swift-testing, red-gate, tdd, wave-0, video-mode, userdefaults, xcstrings]

# Dependency graph
requires:
  - phase: 08-video-mode-design
    provides: 6-zone location vocabulary (D-07), default location largeBottom (D-03), VIDEO MODE Settings card placement (D-01), D-09 a11y label vocabulary
provides:
  - 7 RED-state Swift Testing files locking the Wave 1+ production contract
  - 14 @Test funcs covering 15 of 15 validation rows (compile-only 09-06-01 + manual 09-06-02 require no @Test)
  - Compile-time RED gate proving VideoModeStore / VideoModeLocation / EnvironmentValues.videoModeStore / videoMode.* xcstrings keys do not yet exist
  - Isolated-UserDefaults helper pattern propagated to 7 new test files (per-file declaration, NOT shared)
affects: [09-02-PLAN, 09-03-PLAN, 09-04-PLAN, 09-05-PLAN, 09-06-PLAN, 09-07-PLAN, 09-08-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Swift Testing @MainActor @Suite + makeIsolatedDefaults() static helper — copied verbatim from SettingsStoreFlagsTests.swift:36-39 across all 7 new test files"
    - "RED-gate-by-undefined-symbol — tests reference types Wave 1+ ships; compile failure IS the gate"
    - "xcstrings catalog tested via JSONSerialization parse with source-tree fallback resolved from #filePath (RED-safe before catalog is recompiled)"
    - "Bindable round-trip pattern as Toggle binding stand-in for SwiftUI view tests (Bindable(store).property pattern from SettingsView.swift:197)"

key-files:
  created:
    - gamekit/gamekitTests/Core/VideoModeStoreTests.swift
    - gamekit/gamekitTests/Core/VideoModeEnvironmentTests.swift
    - gamekit/gamekitTests/App/GameKitAppTests.swift
    - gamekit/gamekitTests/Screens/SettingsViewTests.swift
    - gamekit/gamekitTests/Screens/VideoLocationPickerViewTests.swift
    - gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift
    - gamekit/gamekitTests/Regression/SC5RegressionTests.swift
  modified: []

key-decisions:
  - "Per-file (not shared) makeIsolatedDefaults() static helper — Swift Testing's parallel execution makes shared cross-file helpers risky"
  - "LocalizableCatalogTests resolves Localizable.xcstrings via Bundle.main first, then #filePath source-tree fallback — keeps test runnable in RED state before catalog is recompiled"
  - "SwiftUI view tests use Bindable round-trip as stand-in until ViewInspector / snapshot rig lands in P10/P11 (per CONTEXT D-15 + 09-PATTERNS.md §8)"
  - "GameKitAppTests body uses the EnvironmentValues default-value path — SwiftUI App scene-tree injection is not inspectable from unit tests; TODO(09-03) marker tracks the real assertion swap"
  - "SC5RegressionTests is a placeholder per CONTEXT D-15 — Phase 9 game views don't yet read videoModeStore.isOn so off-state baseline is preserved by construction"

patterns-established:
  - "Pattern: RED-gate test author-once — each Wave 0 test ships with test-name verbatim from VALIDATION row + TODO comment naming the plan that swaps the placeholder for the real assertion"
  - "Pattern: xcstrings key existence assertion via JSONSerialization parse — usable for future L10N work"
  - "Pattern: per-file static makeIsolatedDefaults() declaration in every Swift Testing suite that touches UserDefaults (5 of 7 new files include it; LocalizableCatalogTests + SC5RegressionTests carry it for pattern uniformity)"

requirements-completed: []
# Note: Plan 09-01 frontmatter declares requirements [VIDEO-01, VIDEO-02, VIDEO-03, VIDEO-04, VIDEO-14]
# but these are NOT marked complete here — Wave 0 RED tests do not satisfy the requirements;
# Waves 1-3 (plans 09-02 through 09-05) produce the production code that flips the tests to GREEN.
# Requirement completion lands in those plans, not here.

# Metrics
duration: 17min
completed: 2026-05-12
---

# Phase 09 Plan 01: Wave 0 RED Test Gates Summary

**7 RED-state Swift Testing files locking the VideoModeStore + VideoModeLocation + EnvironmentValues.videoModeStore + videoMode.* xcstrings contract that Waves 1-3 must satisfy; 14 @Test funcs covering 15 validation rows.**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-05-12T18:30Z (approximate — plan execution kickoff)
- **Completed:** 2026-05-12T18:47Z
- **Tasks:** 2 / 2 completed
- **Files created:** 7
- **Files modified:** 0

## Accomplishments

- 7 new Swift Testing files at the exact paths declared in 09-VALIDATION.md Wave 0 requirements
- 14 @Test funcs total, named verbatim per VALIDATION rows (planner-validation handler greps for these exact strings)
- Compile-time RED state confirmed via `xcodebuild build-for-testing` — `cannot find 'VideoModeStore' in scope` + `cannot find 'VideoModeLocation' in scope` errors land exactly where expected
- Xcode 16 PBXFileSystemSynchronizedRootGroup auto-registered the 4 new test subdirectories (`App/`, `Screens/`, `Resources/`, `Regression/`) with zero `project.pbxproj` hand-patching (CLAUDE.md §8.8 once again validated empirically)
- Pattern propagation: all 7 files mirror SettingsStoreFlagsTests.swift:36-39 isolated-UserDefaults helper verbatim — no drift

## Task Commits

Each task was committed atomically (Swift Testing — no separate RED/GREEN split per task; the RED commits together ARE the gate):

1. **Task 1: VideoModeStoreTests + VideoModeEnvironmentTests (6 + 1 = 7 @Test funcs)** — `74f6bb9` (test)
2. **Task 2: App-root, Settings, Picker, xcstrings catalog, SC5 regression stubs (1 + 2 + 2 + 1 + 1 = 7 @Test funcs)** — `0b8f574` (test)

**Plan metadata commit:** (pending — final commit lands after this SUMMARY.md + STATE.md + ROADMAP.md updates)

## Files Created/Modified

### Created (7 files)

**Task 1 — Wave 1 contract (VIDEO-01 / VIDEO-02 / VIDEO-03):**
- `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` — 6 @Test funcs covering VIDEO-01/02/03 default + round-trip + 6-case enum exhaustiveness + corrupt-rawValue defense (RESEARCH Topic 3 invariant #4)
- `gamekit/gamekitTests/Core/VideoModeEnvironmentTests.swift` — 1 @Test func covering EnvironmentKey identity (`===`) round-trip

**Task 2 — Waves 2 & 3 contract (VIDEO-03 / VIDEO-01 / VIDEO-02 / VIDEO-14 / SC5):**
- `gamekit/gamekitTests/App/GameKitAppTests.swift` — 1 @Test func, app-root injection (placeholder body, TODO marker for 09-03)
- `gamekit/gamekitTests/Screens/SettingsViewTests.swift` — 2 @Test funcs, Toggle binding + conditional row visibility (Bindable round-trip stand-in)
- `gamekit/gamekitTests/Screens/VideoLocationPickerViewTests.swift` — 2 @Test funcs, zone tap + a11y label coverage (per-case `localizedLabel` non-empty assertion)
- `gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift` — 1 @Test func, asserts 13 `videoMode.*` keys present with non-empty `en` stringUnit values; parses Localizable.xcstrings via JSONSerialization with `#filePath` source-tree fallback (RED-safe)
- `gamekit/gamekitTests/Regression/SC5RegressionTests.swift` — 1 @Test func placeholder per CONTEXT D-15 (Phase 9 doesn't yet branch on `videoModeStore.isOn`)

### Test-to-Validation Row Mapping

| Test File | @Test func | VALIDATION row | Requirement |
| --- | --- | --- | --- |
| VideoModeStoreTests | test_isEnabled_persists | 09-01-01 | VIDEO-01 |
| VideoModeStoreTests | test_isEnabled_defaults_to_false | 09-01-02 | VIDEO-01 |
| VideoModeStoreTests | test_location_persists_all_cases | 09-01-03 | VIDEO-02 / VIDEO-03 |
| VideoModeStoreTests | test_location_default_is_largeBottom | 09-01-04 | VIDEO-02 / D-03 |
| VideoModeStoreTests | test_location_enum_has_6_cases | 09-01-05 | VIDEO-02 / D-07 |
| VideoModeStoreTests | test_corruptLocation_fallsBackToLargeBottom | (RESEARCH inv #4) | (defensive) |
| VideoModeEnvironmentTests | test_environmentKey_returns_injected | 09-02-01 | VIDEO-03 |
| GameKitAppTests | test_videoModeStore_injected_at_app_root | 09-02-02 | VIDEO-03 |
| SettingsViewTests | test_videoMode_toggle_binds_to_store | 09-03-01 | VIDEO-01 |
| SettingsViewTests | test_locationRow_visibility_follows_isEnabled | 09-03-02 | VIDEO-01 / D-01 |
| VideoLocationPickerViewTests | test_zone_tap_updates_location | 09-04-01 | VIDEO-02 |
| VideoLocationPickerViewTests | test_zone_a11y_labels | 09-04-02 | VIDEO-02 / D-09 |
| LocalizableCatalogTests | test_videoMode_copy_keys_exist | 09-05-01 | VIDEO-14 |
| SC5RegressionTests | test_off_state_byte_identical | 09-07-01 | SC5 |

(Rows 09-06-01 [compile-only smoke via `xcodebuild build`] and 09-06-02 [manual `#Preview` canvas sign-off] require no @Test.)

## Decisions Made

- **Per-file static `makeIsolatedDefaults()` helper** (5 of 7 files) — per 09-PATTERNS.md §8 + Task 2's `<action>` note, Swift Testing's default-parallel execution makes a shared/cross-file helper risky. Each file ships its own copy of the 4-line helper. LocalizableCatalogTests and SC5RegressionTests carry the helper for pattern uniformity even though their tests don't use it.
- **`LocalizableCatalogTests` source-tree fallback** — loadCatalogJSON() tries `Bundle.main.url(forResource:)` first, then resolves `#filePath` → `gamekit/Resources/Localizable.xcstrings`. This keeps the test runnable in RED state before Wave 2 plan 09-03 has recompiled the catalog with `videoMode.*` keys; without the fallback, the test would fail with a confusing "bundle resource missing" error rather than the intended "key X not found" assertion.
- **SwiftUI view tests use Bindable round-trip as stand-in** — SettingsViewTests / VideoLocationPickerViewTests do NOT walk SwiftUI's view tree (no ViewInspector dependency added). Each `@Test` body exercises the same Bindable / closure / accessor code path the real view will consume, plus a `TODO(09-04|09-05)` marker for when the real view-tree assertion can land. This honors CLAUDE.md §4 "smallest change that satisfies the requirement" — Wave 0 only needs to declare the contract; real interaction assertions belong to the production-code plan that ships the view.
- **GameKitAppTests placeholder body** — SwiftUI App scene-tree injection is not directly inspectable from a unit test. The test body asserts the EnvironmentValues default-value path is reachable (the RED gate IS the reference to `EnvironmentValues.videoModeStore`); the real injection assertion swap is tracked via `TODO(09-03)` marker.
- **SC5RegressionTests is a single `#expect(true)` line** — per CONTEXT D-15 + 09-PATTERNS.md §8 last paragraph, Phase 9 game views do not yet read `videoModeStore.isEnabled`, so off-state baseline is preserved by construction. Real snapshot infrastructure is a Phase 10/11 deliverable; trying to scaffold it here would be speculate-building.

## Deviations from Plan

None — plan executed exactly as written.

The plan explicitly authored 7 placeholder-bodied tests because Wave 1+ production code does not yet exist (TDD plan-level RED gate). Every "placeholder body" decision noted above is in the plan's `<action>` blocks verbatim.

## Issues Encountered

None.

## TDD Gate Compliance

This plan is `type: tdd` at the plan-level. Gate sequence verified in git log:

1. **RED gate present:** Both commits are `test(...)` — `74f6bb9` (Task 1) and `0b8f574` (Task 2).
2. **GREEN gate intentionally deferred:** GREEN does NOT land in this plan. Plan 09-02 (Wave 1 — VideoModeStore + VideoModeLocation production code) ships the `feat(...)` commit that flips Task 1's tests to GREEN. Plans 09-03 / 09-04 / 09-05 flip Task 2's tests as their respective production code lands.
3. **Fail-fast verification:** Confirmed via `xcodebuild build-for-testing -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`:

   ```
   /Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekitTests/Core/VideoModeStoreTests.swift:54:21:
     error: cannot find 'VideoModeStore' in scope
   /Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekitTests/Core/VideoModeStoreTests.swift:87:20:
     error: cannot find 'VideoModeLocation' in scope
   ** TEST BUILD FAILED **
   ```

   These errors are the RED gate exactly as the plan declared. NOT a regression.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Plan 09-02 (Wave 1)** can now author `VideoModeStore` + `VideoModeLocation` + `EnvironmentValues.videoModeStore` extension against the locked contract:
  - `VideoModeStore.isEnabledKey: String` (UserDefaults key constant)
  - `VideoModeStore.locationKey: String` (UserDefaults key constant)
  - `VideoModeStore(userDefaults:)` initializer
  - `var isEnabled: Bool` (default false, didSet writes through)
  - `var location: VideoModeLocation` (default .largeBottom, raw-string didSet, corrupt-fallback to .largeBottom)
  - `enum VideoModeLocation: String, CaseIterable, Sendable` with locked 6 raw values: `largeTop / largeBottom / smallTopLeft / smallTopRight / smallBottomLeft / smallBottomRight`
  - `VideoModeLocation.localizedLabel: String` accessor
  - `EnvironmentValues.videoModeStore: VideoModeStore` getter/setter
- **Plans 09-03 / 09-04 / 09-05** can author against the picker + Settings card + xcstrings keys with test names locked.
- **Phase 11/12** snapshot infrastructure work can swap the `SC5RegressionTests` `#expect(true)` placeholder for real off-state snapshot diff once `videoModeStore.isEnabled` flows into game views.

**No blockers.** RED-state is healthy and expected.

---
*Phase: 09-video-mode-foundation*
*Completed: 2026-05-12*

## Self-Check: PASSED

All 7 test files + SUMMARY.md exist on disk. Both task commits (`74f6bb9`, `0b8f574`) verified present in `git log --oneline --all`.
