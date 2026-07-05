---
phase: 10-layout-primitives
plan: 01
subsystem: testing
tags: [swift-testing, swiftui, view-modifier, tdd-red, video-mode, slot-router, environment-key]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: VideoModeStore, VideoModeLocation, VideoCompactControlRow, EnvironmentValues.videoModeStore (env-key seam), makeIsolatedDefaults() test pattern
  - phase: 08-video-mode-design
    provides: VIDEO-MODE-LAYOUTS.md slot-anchor data, 08-HARD-MINES-ADR.md untouched contract, screenshot-derived band fraction
provides:
  - gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift (RED stub — 7 @Test funcs / 25 #expect locking VIDEO-05 slot-anchor contract)
  - gamekit/gamekitTests/Core/VideoModeAwareTests.swift (RED stub — 4 @Test funcs locking VIDEO-13 off-state byte-identical + VIDEO-06 3-level compactness contract)
  - renderAndCapture probe helper pattern (UIHostingController + Color.clear.onAppear capture box; no ViewInspector dep)
  - 0.32 band fraction lock (D-09/D-10) and 0.85x compactness threshold lock (D-14) committed as test-source literals
affects: [10-02, 10-03, 10-04, 11-mines-adoption, 12-merge-nonogram-adoption, 13-win-loss-banner]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RED-gate via @testable test file compile failure on undefined production symbols (P9 P01 pattern continues into P10)"
    - "renderAndCapture(store:minBoardHeight:forcedHeight:) probe helper for env-value capture without ViewInspector"
    - "CompactnessCaptureBox @MainActor reference type for closure-based test capture"
    - "Threshold literals (0.32 band fraction, 0.85 floor scale) embedded in test source as the locked contract"

key-files:
  created:
    - gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift
    - gamekit/gamekitTests/Core/VideoModeAwareTests.swift
  modified: []

key-decisions:
  - "Test contract locks SlotAnchorMap shape with named fields (back/settings/picker/fab) before Plan 10-02 ships the type — compile-time exhaustiveness over [SlotID:Anchor] dictionary"
  - "renderAndCapture probe uses UIHostingController + 0.05s RunLoop pass + reference-type capture box; no 3rd-party ViewInspector dep (RESEARCH §Example 1 recommendation 1)"
  - "0.85x compactness floor scale locked at test level — Plan 10-03 MUST implement `available >= floor ? .normal : (available >= floor*0.85 ? .collapsedSettings : .reducedTime)` exactly"
  - "0.32 band fraction locked at test level — Plan 10-03 must reserve geometry.size.height * 0.32 on .largeTop / .largeBottom zones"
  - "Off-state test uses intentionally TIGHT forcedHeight (200pt) to prove the short-circuit — if modifier were running it would publish .reducedTime; .normal coming back proves D-05"

patterns-established:
  - "Pattern 1: Wave 0 RED gate emits 2 test files referencing 5+ unshipped symbols (VideoModeSlotRouter, SlotAnchorMap, SlotAnchor, VideoModeAware, VideoModeCompactness) — xcodebuild build-for-testing failure IS the gate"
  - "Pattern 2: 24 anchor assertions × 1 exhaustiveness loop = 25 #expect in slot-router test, splitting by-case to surface failures per zone (RESEARCH §Pattern 2)"
  - "Pattern 3: probe-child env capture for ViewModifier env-key contracts — replicable for any future @Environment(\\.foo) publication test"

requirements-completed: []  # Plan ships TESTS only. Production wiring lands in Plans 10-02 (VideoModeSlotRouter → VIDEO-05) + 10-03 (VideoModeAware → VIDEO-06, VIDEO-13). Requirements stay open until GREEN.

# Metrics
duration: 4 min
completed: 2026-05-13
---

# Phase 10 Plan 01: Layout Primitive Wave 0 RED Gate Summary

**Two Swift Testing files commit the VIDEO-05 / VIDEO-06 / VIDEO-13 acceptance contract before VideoModeSlotRouter and VideoModeAware exist — xcodebuild build-for-testing fails on undefined-symbol errors exactly as designed.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-13T16:11Z
- **Completed:** 2026-05-13T16:15Z
- **Tasks:** 2 / 2
- **Files created:** 2 (both new test files)
- **Files modified:** 0

## Accomplishments

- **VideoModeSlotRouterTests.swift** — 7 @Test funcs covering 6 PiP zones × 4 slots = 24 anchor assertions + 1 exhaustiveness count (25 #expect total). The 6 SlotAnchorMap shapes from CONTEXT D-02 / D-08 / D-11 are now contract-locked at the test level: `.largeTop` / `.largeBottom` → 4×`.inCompactRow`; `.smallTopLeft` → trailing edge; `.smallTopRight` → leading edge; `.smallBottomLeft` → topLeading + topTrailing + 2×bottomTrailing; `.smallBottomRight` → topLeading + topTrailing + 2×bottomLeading. Plan 10-02 must produce these exact mappings to flip GREEN.
- **VideoModeAwareTests.swift** — 4 @Test funcs locking the SC3 off-state byte-identical contract (`isEnabled == false` → descendant env reads `.normal` default) + the 3-level VIDEO-06 compactness contract (`available >= floor` → `.normal`; `0.85*floor <= available < floor` → `.collapsedSettings`; `available < 0.85*floor` → `.reducedTime`). The 0.32 band fraction and 0.85 threshold values are embedded as test-source literals.
- **renderAndCapture helper** ships a reusable env-capture pattern: `UIHostingController` + `Color.clear.onAppear` writes through a `@MainActor` `CompactnessCaptureBox` reference type, no ViewInspector SPM dep needed (RESEARCH §Example 1 recommendation 1).
- **RED gate confirmed** via `xcodebuild build-for-testing` on `iPhone 17 Pro / iOS 17`. The build fails with the exact undefined-symbol errors plans 10-02 / 10-03 will resolve (see Verification Excerpts below).

## Task Commits

1. **Task 1: Create VideoModeSlotRouterTests.swift RED stub** — `fcdbafd` (test)
2. **Task 2: Create VideoModeAwareTests.swift RED stub** — `7e97b7e` (test)

## Files Created/Modified

- `gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift` — 95 lines, 7 @Test funcs, 25 #expect — locks VIDEO-05 slot-anchor map for Plan 10-02.
- `gamekit/gamekitTests/Core/VideoModeAwareTests.swift` — 168 lines, 4 @Test funcs + renderAndCapture helper + CompactnessCaptureBox — locks VIDEO-06 + VIDEO-13 for Plan 10-03.

## Verification: RED-Gate Excerpts

**xcodebuild build-for-testing -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'** — exit `** TEST BUILD FAILED **`, target errors below.

### VideoModeSlotRouterTests.swift undefined-symbol errors (first 3 of many)

```
gamekitTests/Core/VideoModeSlotRouterTests.swift:36:19: error: cannot find 'VideoModeSlotRouter' in scope
gamekitTests/Core/VideoModeSlotRouterTests.swift:45:19: error: cannot find 'VideoModeSlotRouter' in scope
gamekitTests/Core/VideoModeSlotRouterTests.swift:54:19: error: cannot find 'VideoModeSlotRouter' in scope
```

Plus cascading `cannot infer contextual base in reference to member 'topLeading'` / `'bottomLeading'` / `'bottomTrailing'` errors — these surface because `SlotAnchor` is undefined, so the `.topLeading` shorthand cannot resolve. Plan 10-02 shipping `enum SlotAnchor { case topLeading, topTrailing, bottomLeading, bottomTrailing, inCompactRow, hidden }` resolves all of these in one stroke.

### VideoModeAwareTests.swift undefined-symbol errors (first 5)

```
gamekitTests/Core/VideoModeAwareTests.swift:76:10: error: cannot find type 'VideoModeCompactness' in scope
gamekitTests/Core/VideoModeAwareTests.swift:105:20: error: cannot find type 'VideoModeCompactness' in scope
gamekitTests/Core/VideoModeAwareTests.swift:80:14: error: no exact matches in call to initializer
  @Environment(\.videoModeCompactness) private var compactness
gamekitTests/Core/VideoModeAwareTests.swift:88:14: error: value of type 'StubProbe' has no member 'videoModeAware'
  .videoModeAware(minBoardHeight: minBoardHeight)
gamekitTests/Core/VideoModeAwareTests.swift:89:26: error: cannot infer key path type from context
  .environment(\.videoModeStore, store)
```

Plan 10-03 ships `enum VideoModeCompactness`, `EnvironmentValues.videoModeCompactness`, `struct VideoModeAware: ViewModifier`, and `extension View { func videoModeAware(minBoardHeight:) -> some View }` — all 5 error categories above resolve.

## Verification: No project.pbxproj Edit

```
$ git status --short
 M .planning/STATE.md                                  (pre-existing, unrelated)
 M gamekit/gamekit/Resources/Localizable.xcstrings     (pre-existing, unrelated)
?? .claude/                                            (pre-existing, unrelated)
?? gamekit/gamekitTests/Core/VideoModeAwareTests.swift (before commit)
?? gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift (before commit)
```

`project.pbxproj` was never touched. PBXFileSystemSynchronizedRootGroup (Xcode 16, `objectVersion = 77`) auto-registered both new files into the `gamekitTests` target on first build attempt, exactly as CLAUDE.md §8.8 promises.

## Decisions Made

None beyond what plan + CONTEXT pre-locked. All assertion values, helper shapes, and threshold literals were written verbatim from the plan `<action>` blocks. No discretionary planner calls fell to executor.

## Deviations from Plan

None — plan executed exactly as written.

Both files match the verbatim source blocks in 10-01-PLAN.md `<action>`. Verification commands match plan `<verify>` block. No Rule 1 / 2 / 3 fixes applied; no Rule 4 architectural decisions surfaced.

## Issues Encountered

None. Build failed exactly where expected, on the symbols the next two plans will ship.

## User Setup Required

None — pure test code, no external services.

## Self-Check: PASSED

- `gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift`: FOUND
- `gamekit/gamekitTests/Core/VideoModeAwareTests.swift`: FOUND
- Commit `fcdbafd`: FOUND (`test(10-01): add VideoModeSlotRouterTests RED stub`)
- Commit `7e97b7e`: FOUND (`test(10-01): add VideoModeAwareTests RED stub`)

## Next Phase Readiness

**Wave 1 unblocked.** Plan 10-02 (`VideoModeSlotRouter`) and Plan 10-03 (`VideoModeAware`) now have a precise, pre-committed acceptance surface:

- Plan 10-02 ships `gamekit/gamekit/Core/VideoModeSlotRouter.swift` containing `enum SlotAnchor`, `struct SlotAnchorMap` (Equatable / Sendable with `back`, `settings`, `picker`, `fab` fields), and `enum VideoModeSlotRouter` with `static func anchors(for: VideoModeLocation) -> SlotAnchorMap` returning the 6 SlotAnchorMaps locked in this test file. Flipping the slot-router test suite GREEN ≡ VIDEO-05 complete.
- Plan 10-03 ships `gamekit/gamekit/Core/VideoModeAware.swift` containing `struct VideoModeAware: ViewModifier` (with `private static let largeBandFraction: CGFloat = 0.32`), `extension View { func videoModeAware(minBoardHeight: CGFloat = 320) -> some View }`, `enum VideoModeCompactness { case normal, collapsedSettings, reducedTime }`, and `EnvironmentValues.videoModeCompactness`. The modifier MUST short-circuit with `if !store.isEnabled { return AnyView(content) }` and MUST publish `.normal` / `.collapsedSettings` / `.reducedTime` per the D-14 0.85x threshold encoded in the test math comments. Flipping the modifier test suite GREEN ≡ VIDEO-06 + VIDEO-13 complete.

No blockers. No outstanding questions surfaced during execution that affect Plans 10-02 / 10-03 / 10-04.

---
*Phase: 10-layout-primitives*
*Completed: 2026-05-13*
