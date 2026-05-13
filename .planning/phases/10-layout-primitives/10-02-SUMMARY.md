---
phase: 10-layout-primitives
plan: 02
subsystem: video-mode
tags: [swift, swift-6, foundation-only, pure-helper, exhaustive-switch, video-mode, slot-router, sendable, equatable, green-flip, tdd]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: VideoModeLocation (6-case enum the slot-router switches over exhaustively)
  - phase: 08-video-mode-design
    provides: VIDEO-MODE-LAYOUTS.md per-zone "Where controls go" tables — the data source for the 24 anchor mappings
  - phase: 10-layout-primitives (Plan 10-01)
    provides: VideoModeSlotRouterTests.swift RED stub (7 @Test funcs / 25 #expect) that this plan flips GREEN
provides:
  - gamekit/gamekit/Core/VideoModeSlotRouter.swift (143 lines — SlotAnchor enum + SlotAnchorMap struct + VideoModeSlotRouter enum-namespace + anchors(for:) -> SlotAnchorMap)
  - SlotAnchor (6-case Sendable + Equatable enum: topLeading, topTrailing, bottomLeading, bottomTrailing, inCompactRow, hidden)
  - SlotAnchorMap (Equatable + Sendable struct with 4 named fields: back, settings, picker, fab)
  - VideoModeSlotRouter.anchors(for:) static — exhaustive 6-case switch returning the locked SlotAnchorMap per CONTEXT D-02 / D-08 / D-11
affects: [10-03 (modifier sibling — same file directory + same env-key seam), 10-04 (Wave 2 audit consumes the helper from #Preview), 11-mines-adoption, 12-merge-nonogram-adoption, 13-win-loss-banner]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Foundation-only pure helper consumable from any context (engine, tests, snapshot rigs) — no SwiftUI import"
    - "enum-as-namespace for static-function APIs (mirrors VideoModeLocation localizedLabel pattern; matches SettingsStore-style Sendable struct discipline)"
    - "Exhaustive switch over VideoModeLocation as project-wide compile-time safety net for v1.3+ enum extension"
    - "Named-fields SlotAnchorMap struct (vs [SlotID:SlotAnchor] dictionary) gives compiler exhaustiveness on slot identity per CONTEXT Claude's-Discretion lock"

key-files:
  created:
    - gamekit/gamekit/Core/VideoModeSlotRouter.swift
  modified: []

key-decisions:
  - "Adopted plan's verbatim file body — every @action header line, anchor literal, and switch arm written exactly as specified. Zero discretionary planner calls fell to executor."
  - "Verification path adapted: -only-testing flag cannot bypass test-target compilation, so verification used a temp-stash-and-restore (mv VideoModeAwareTests.swift to /tmp during xcodebuild test, restored immediately after) to prove all 7 @Test funcs pass on a real iPhone 17 Pro simulator. No git artifacts changed."
  - "A3 cross-check (per 10-RESEARCH.md Assumptions Log) confirmed: every one of the 6 switch arms aligns with the corresponding 'Where controls go' row in 08-VIDEO-MODE-LAYOUTS.md across Mines Easy/Medium/Hard, Merge, and Nonogram. No discrepancy surfaced."
  - "Plan 10-03 RED preserved as designed: VideoModeAwareTests.swift still references undefined VideoModeAware / VideoModeCompactness symbols. Six remaining xcodebuild errors all originate in VideoModeAwareTests.swift; zero remaining errors reference the slot-router symbols this plan shipped."

patterns-established:
  - "Wave 1 GREEN-flip pattern: ship the production type whose absence drove Wave 0 RED, then verify ONLY the corresponding test suite via xcodebuild -only-testing while temp-stashing sibling-RED test files that block whole-target compilation"
  - "Verification cross-check pattern: when a plan's switch table derives from a CONTEXT.md-canonical doc, verify each arm 1:1 against the source doc table BEFORE committing — surface as documented A3 gate, not as a deviation"
  - "Anchor-table contract pattern: 24 anchor literals in production source EXACTLY match the 24 #expect assertions in the RED test — Plan 10-01's test contract IS Plan 10-02's specification"

requirements-completed: [VIDEO-05]

# Metrics
duration: 4min
completed: 2026-05-13
---

# Phase 10 Plan 02: VideoModeSlotRouter Pure Helper Summary

**Foundation-only `VideoModeSlotRouter.anchors(for:)` ships with locked 24-anchor switch table — flips Plan 10-01 VideoModeSlotRouterTests RED → GREEN (7 @Test funcs / 25 #expect all passing on iPhone 17 Pro) and unlocks Phase 11/12 game-view adoption call sites.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-13T21:42:14Z
- **Completed:** 2026-05-13T21:46:01Z
- **Tasks:** 1 / 1
- **Files created:** 1 (`gamekit/gamekit/Core/VideoModeSlotRouter.swift`, 143 lines)
- **Files modified:** 0

## Accomplishments

- **VideoModeSlotRouter.swift shipped** at `gamekit/gamekit/Core/VideoModeSlotRouter.swift` (143 lines, well under CLAUDE.md §8.5 400-line soft cap and the plan-projected ~90-line target — the extra ~50 lines are doc-comment headers for the SlotAnchor / SlotAnchorMap / VideoModeSlotRouter / anchors(for:) public surface and Phase 13 forward-compat note). Foundation-only — no SwiftUI import; no main-actor isolation; reusable from engine layer, tests, and future snapshot rigs.
- **Three types declared at file scope**: `SlotAnchor` (Sendable + Equatable enum, 6 cases — topLeading, topTrailing, bottomLeading, bottomTrailing, inCompactRow, hidden), `SlotAnchorMap` (Equatable + Sendable struct, 4 named fields — back / settings / picker / fab), `VideoModeSlotRouter` (enum namespace) with `static func anchors(for:) -> SlotAnchorMap`.
- **Exhaustive switch over VideoModeLocation locked** — no `default:` case. A future 7th VideoModeLocation case in v1.3+ will produce a compile-time error here, exactly as the plan and CONTEXT D-02 + §code_context demand.
- **6 SlotAnchorMap shapes locked verbatim per CONTEXT D-02 / D-08 / D-11**:
  - `.largeTop` → all 4 → `.inCompactRow`
  - `.largeBottom` → all 4 → `.inCompactRow`
  - `.smallTopLeft` → back/settings → `.topTrailing`, picker/fab → `.bottomTrailing`
  - `.smallTopRight` → back/settings → `.topLeading`, picker/fab → `.bottomLeading`
  - `.smallBottomLeft` → back → `.topLeading`, settings → `.topTrailing`, picker/fab → `.bottomTrailing`
  - `.smallBottomRight` → back → `.topLeading`, settings → `.topTrailing`, picker/fab → `.bottomLeading`
- **Plan 10-01 GREEN-flip confirmed**: `xcodebuild test -only-testing:gamekitTests/VideoModeSlotRouterTests` reports `** TEST SUCCEEDED **` with all 7 @Test funcs passing (× 2 simulator clones = 14 passing test runs, all 25 #expect assertions green). VIDEO-05 contract LOCKED.
- **Plan 10-03 RED preserved as designed** (per plan success criteria): the 6 remaining test-target compile errors all live in `VideoModeAwareTests.swift` and reference `VideoModeCompactness` / `videoModeAware` / `\.videoModeStore` keypath ambiguity — zero errors reference any slot-router symbol.

## Task Commits

Single-task plan committed atomically:

1. **Task 1: Ship VideoModeSlotRouter.swift** — `c1c5830` (feat)

**Plan metadata commit:** added below in §"Final Commit" once SUMMARY + STATE + ROADMAP land together.

## Files Created/Modified

- `gamekit/gamekit/Core/VideoModeSlotRouter.swift` — 143 lines, Foundation-only pure helper with the 6-case exhaustive switch returning locked SlotAnchorMap per zone. Sibling to existing P9 `VideoModeStore.swift` / `VideoModeLocation.swift` / `VideoCompactControlRow.swift`. Auto-registered into the `gamekit` target by PBXFileSystemSynchronizedRootGroup (Xcode 16 `objectVersion = 77`) on first build — zero `project.pbxproj` edits required (CLAUDE.md §8.8).

## Decisions Made

None beyond what plan + CONTEXT pre-locked. All 24 anchor literals, three type declarations, header comments, and switch arms were written verbatim from the plan's `<action>` block. The plan's "Do NOT" list was honored line-by-line (no SwiftUI import, no anchor changes, no `default:` case, no banner field, no DesignKit promotion).

The only execution-time choice fell on verification mechanics (see Issues Encountered below) — the in-spec verification command was incompatible with the still-RED Plan 10-03 test file blocking whole-test-target compilation, so a temp-stash-and-restore approach proved the GREEN flip without modifying any tracked file.

## Deviations from Plan

None - plan executed exactly as written.

The verbatim file body from the plan `<action>` block landed at the specified path. No Rule 1 (bug fix) / Rule 2 (missing critical functionality) / Rule 3 (blocking issue) auto-fixes were applied to the production file. No Rule 4 (architectural decision) checkpoints surfaced.

## Issues Encountered

**1. Plan verification command can't run while sibling test file is RED — resolved with temp-stash-and-restore**

- **Found during:** Task 1 verify step
- **Issue:** The plan's verification command `xcodebuild test -scheme gamekit -destination ... -only-testing:gamekitTests/VideoModeSlotRouterTests` cannot complete because the test target's whole-bundle compilation fails on `VideoModeAwareTests.swift` (Plan 10-03's RED stub), which references undefined `VideoModeCompactness` / `\.videoModeAware` symbols. The `-only-testing` flag filters which tests RUN, not which sources COMPILE. The `-skip-testing` flag has the same limitation. This is a planning-time oversight: Plan 10-01 shipped two RED stubs in one wave but Plans 10-02 and 10-03 GREEN-flip them in separate plans, leaving an intermediate state where the slot-router's GREEN flip cannot be verified by the in-spec command.
- **Resolution (verification-only, no git artifact change):** Temporarily moved `VideoModeAwareTests.swift` to `/tmp/VideoModeAwareTests.swift.staged`, ran the plan's verification command — got `** TEST SUCCEEDED **` with all 7 @Test funcs passing on a real iPhone 17 Pro simulator (× 2 clones = 14 test runs, all 25 #expect green) — then restored the file. Verified `git status --short` post-restore: only the new `VideoModeSlotRouter.swift` is untracked; `VideoModeAwareTests.swift` is back in place untouched.
- **Why this is NOT a Rule-3 deviation against the plan:** The plan's `<verify>` block specifies the test invocation; the planner's stated success criterion ("VideoModeAwareTests still RED — Plan 10-03 produces those symbols") explicitly requires the modifier tests to remain failing. The verification mechanic (whole-target compile blocking the slot-router test run) is a tooling fact about `xcodebuild`, not a plan instruction to change. The temp-stash technique honored both the plan's verification intent and the success criterion of preserving Plan 10-03's RED state.
- **Future-proofing:** Plan 10-03 will GREEN-flip `VideoModeAwareTests.swift` and resolve this verification limitation permanently. Future Wave 0 RED-gate plans that span >1 GREEN-flip plans should consider either (a) splitting the RED test files into the same number of plans as the GREEN-flip plans, or (b) embedding the temp-stash technique into the GREEN-flip plan's `<verify>` block.

## User Setup Required

None — pure layout-helper code, no external services, no environment variables, no manual configuration.

## Verification Excerpts

### File structural checks (all OK)

```
OK: file exists
OK: imports Foundation
OK: no SwiftUI import
OK: SlotAnchor enum
OK: SlotAnchorMap struct
OK: VideoModeSlotRouter enum
OK: anchors(for:) sig
OK: no default case
Line count: 143
OK: under 400 lines
```

### A3 cross-check vs `08-VIDEO-MODE-LAYOUTS.md` (all 6 zones MATCH)

| PiP Zone        | 08-VIDEO-MODE-LAYOUTS.md "Where controls go" rule | Plan 10-02 switch arm                                                                       | Match |
|-----------------|---------------------------------------------------|---------------------------------------------------------------------------------------------|-------|
| Large top       | Compact row at bottom edge; full slot order in row | all 4 → `.inCompactRow`                                                                      | YES   |
| Large bottom    | Compact row at top edge; same slot order          | all 4 → `.inCompactRow`                                                                      | YES   |
| Small TL        | Move Back out of TL into TR/compact row           | back/settings → `.topTrailing`, picker/fab → `.bottomTrailing` (all toward trailing edge)    | YES   |
| Small TR        | Move Settings out of TR into TL/compact row       | back/settings → `.topLeading`, picker/fab → `.bottomLeading` (all toward leading edge)        | YES   |
| Small BL        | Move bottom-left affordances to bottom-right      | back→`.topLeading`, settings→`.topTrailing`, picker/fab→`.bottomTrailing`                    | YES   |
| Small BR        | Move BR FAB + bottom-right affordances to bottom-left | back→`.topLeading`, settings→`.topTrailing`, picker/fab→`.bottomLeading`                  | YES   |

### Plan 10-01 GREEN-flip confirmation (xcodebuild test)

```
Test suite 'VideoModeSlotRouterTests' started on 'Clone 1 of iPhone 17 Pro - gamekit'
Test case 'VideoModeSlotRouterTests/test_smallBottomLeft_anchors()' passed
Test case 'VideoModeSlotRouterTests/test_smallTopLeft_anchors()' passed
Test case 'VideoModeSlotRouterTests/test_smallTopRight_anchors()' passed
Test case 'VideoModeSlotRouterTests/test_largeTop_allInCompactRow()' passed
Test case 'VideoModeSlotRouterTests/test_smallBottomRight_anchors()' passed
Test case 'VideoModeSlotRouterTests/test_largeBottom_allInCompactRow()' passed
Test case 'VideoModeSlotRouterTests/test_all_cases_have_mappings()' passed
[× 2 simulator clones — 14 passing runs total]

** TEST SUCCEEDED **
```

7/7 tests passing — 25 #expect assertions all green (24 anchors + 1 exhaustiveness count).

### Plan 10-03 RED preserved (sanity check — modifier was NOT accidentally shipped)

`xcodebuild build-for-testing -scheme gamekit -destination ...` shows the only remaining test-target compile errors are in `VideoModeAwareTests.swift`:

```
gamekitTests/Core/VideoModeAwareTests.swift:76:10: error: cannot find type 'VideoModeCompactness' in scope
gamekitTests/Core/VideoModeAwareTests.swift:105:20: error: cannot find type 'VideoModeCompactness' in scope
gamekitTests/Core/VideoModeAwareTests.swift:80:14: error: no exact matches in call to initializer
gamekitTests/Core/VideoModeAwareTests.swift:80:26: error: cannot infer key path type from context
gamekitTests/Core/VideoModeAwareTests.swift:88:14: error: value of type 'StubProbe' has no member 'videoModeAware'
gamekitTests/Core/VideoModeAwareTests.swift:89:26: error: cannot infer key path type from context
```

Zero remaining errors reference `VideoModeSlotRouter`, `SlotAnchor`, or `SlotAnchorMap` — the slot-router file compiles clean against both the production target and the test target. Plan 10-03 RED preserved exactly as plan success criteria require.

### Git status (no unrelated artifacts touched)

```
$ git status --short
 M gamekit/gamekit/Resources/Localizable.xcstrings    (pre-existing, unrelated)
?? .claude/                                            (pre-existing, unrelated)
```

`project.pbxproj` was never touched. PBXFileSystemSynchronizedRootGroup (Xcode 16, `objectVersion = 77`) auto-registered the new file into the `gamekit` target, exactly as CLAUDE.md §8.8 promises.

## Self-Check: PASSED

- `gamekit/gamekit/Core/VideoModeSlotRouter.swift`: FOUND (143 lines)
- Commit `c1c5830`: FOUND (`feat(10-02): add VideoModeSlotRouter pure helper for VIDEO-05`)

## Next Phase Readiness

**Wave 1 half-complete; Plan 10-03 unblocked.** Plan 10-03 (`VideoModeAware`) will:

- Ship `gamekit/gamekit/Core/VideoModeAware.swift` with `struct VideoModeAware: ViewModifier`, `extension View { func videoModeAware(minBoardHeight: CGFloat = 320) -> some View }`, `enum VideoModeCompactness { case normal, collapsedSettings, reducedTime }`, and `EnvironmentValues.videoModeCompactness`.
- Implement the `if !store.isEnabled { return AnyView(content) }` hard short-circuit per CONTEXT D-05 / D-15.
- Reserve `geometry.size.height * 0.32` band on `.largeTop` / `.largeBottom` zones via `.safeAreaInset(edge:)` per D-08 / D-09 (0.32 fraction locked at the test level by Plan 10-01).
- Publish `.normal` / `.collapsedSettings` / `.reducedTime` per the D-14 0.85x threshold encoded in Plan 10-01's test math comments.
- GREEN-flip the 4 @Test funcs in `VideoModeAwareTests.swift` → completes VIDEO-06 + VIDEO-13.
- Restore the in-spec verification path (no temp-stash needed once 10-03 lands).

After Plan 10-03, Plan 10-04 (Wave 2 SC5 visual audit + 10-VERIFICATION.md sign-off + Docs/releases/v1.2.md Phase 10 entry) closes the phase.

No blockers. No outstanding questions surfaced during execution that affect Plans 10-03 / 10-04.

---
*Phase: 10-layout-primitives*
*Completed: 2026-05-13*
