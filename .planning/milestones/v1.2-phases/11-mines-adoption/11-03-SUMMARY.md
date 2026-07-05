---
phase: 11-mines-adoption
plan: 03
subsystem: ui
tags: [minesweeper, video-mode, layout-branch, wrap-site, swiftui]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: VideoModeStore env injection (@Environment(\.videoModeStore)) + 6-case VideoModeLocation enum
  - phase: 10-layout-primitives
    provides: .videoModeAware(minBoardHeight:) modifier (D-04 wrap site) + VideoModeSlotRouter.anchors(for:) (D-02 Small-zone consumer) + \.videoModeCompactness env (D-18 future-Plan-11-04 reads)
  - phase: 11-mines-adoption
    provides: 11-CONTEXT D-01/D-02/D-04/D-09/D-15/D-17 + 11-PATTERNS env-read templates + chip extractions (Plan 11-01) + Phase 8 doc supersession (Plan 11-02)
provides:
  - VideoModeLocation.isLarge — exhaustive-switch classifier; partitions the 6 PiP zones into Large vs Small (no catch-all, future 7th case fires compile error in every adopter)
  - HomeView Mines destination wrapped in .videoModeAware(minBoardHeight: 480) (D-04 outermost wrap site)
  - MinesweeperGameView three-way layout branch on (videoModeStore.isEnabled, location.isLarge) — off-path / Large-zone stub / Small-zone with repositioned toolbar
  - MinesweeperGameView+VideoMode.swift sibling file holding existingLayout / existingToolbarContent / smallZoneToolbarContent / backButton / restartButton / SlotAnchor→ToolbarItemPlacement mapping
  - TODO 11-04 marker on the Large-zone branch for Plan 11-04's VideoCompactControlRow composition
affects: [11-04, 11-05, 11-06, 11-07, 11-08]

# Tech tracking
tech-stack:
  added: []  # zero net-new dependencies — wraps existing primitives
  patterns:
    - "Three-way SwiftUI layout branch driven by @Observable env reads (videoModeStore.isEnabled × location.isLarge)"
    - "Sibling-file split (`+VideoMode.swift` suffix) to keep MinesweeperGameView under the CLAUDE.md §8.5 ≤500-line cap while owning the Video Mode layout chrome"
    - "SlotAnchor → ToolbarItemPlacement defensive mapping (exhaustive switch with defensive fallbacks for cases the router does not reach on Small zones today)"

key-files:
  created:
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift
  modified:
    - gamekit/gamekit/Core/VideoModeLocation.swift
    - gamekit/gamekit/Screens/HomeView.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift

key-decisions:
  - "Sibling-file split. MinesweeperGameView.swift at 401 lines was already at the CLAUDE.md §8.5 ≤400-line soft cap; the layout-branch refactor would push it past the 500-line hard cap. Extracted existingLayout + toolbar helpers into MinesweeperGameView+VideoMode.swift per 11-PATTERNS guidance. Result: GameView.swift = 304 lines, +VideoMode.swift = 245 lines."
  - "Dropped `private` from properties consumed by the extension. The extension lives in a separate file, so Swift's file-scoped `private` is not accessible to it. Affected: viewModel / dismiss / lossMinesRevealed / lossWrongFlagsPopped / endCardVisible / showConfetti / reduceMotion / settingsStore / videoModeStore / videoModeCompactness / theme / endStateOverlay / tripCellIndex. All stay internal to the module — no public API change. Tracked as Rule-3 deviation below."
  - "SlotAnchor → ToolbarItemPlacement mapping is defensive. VideoModeSlotRouter.anchors(for:) returns SlotAnchor (P10 D-02 enum: topLeading / topTrailing / bottomLeading / bottomTrailing / inCompactRow / hidden), not SwiftUI Alignment. The mapping switches on all 6 cases: topLeading→.topBarLeading, topTrailing→.topBarTrailing, bottomLeading/bottomTrailing→.bottomBar (for forward-compat with future Small-zone refinements), inCompactRow/hidden→.topBarLeading (defensive — router never emits these on Small zones per P10 D-02 switch, but mapping is exhaustive)."
  - "Large-zone branch ships as STUB per plan scope. Renders existingLayout with .toolbar(.hidden, for: .navigationBar) so the wrap site compiles + the env-read pipe works end-to-end. Plan 11-04 fills in the VideoCompactControlRow composition (D-05 slot order: Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart) + HeaderBar/ModePill hiding. TODO 11-04 marker emitted above the branch points the next executor at the correct line."

patterns-established:
  - "Plan 11-03 establishes the *structural* wrap site so every PiP zone selection routes through a deterministic branch. Plan 11-04 fills the Large-zone composition; Plan 11-05 lowers the Hard cell-size floor in BoardView; Plan 11-06 measures the NavigationStack-mounted board height (P10 A2 carry-forward)."
  - "Sibling-file extension pattern with non-private properties is now a precedent for future Mines/Merge/Nonogram Video-Mode adoptions. Bigger view structs split their chrome layer into `+VideoMode.swift` rather than inflating the primary file."

requirements-completed: [VIDEO-07]

# Metrics
duration: 8min
completed: 2026-05-13
---

# Phase 11 Plan 03: Minesweeper Video Mode Wrap Site Summary

**Three-way layout branch lands inside `MinesweeperGameView.body` and the NavigationLink destination in HomeView wraps Mines in `.videoModeAware(minBoardHeight: 480)`. Off-path stays byte-identical (SC5); Large-zone branch ships as a TODO-11-04 stub that hides the toolbar; Small-zone branch repositions the existing nav-bar items per `VideoModeSlotRouter.anchors(for:)`. `MinesweeperBoardView.swift` is byte-identical (D-17 untouched contract verified by git hash).**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-13T23:33:00Z
- **Completed:** 2026-05-13T23:41:12Z
- **Tasks:** 3
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- `VideoModeLocation.isLarge` — single exhaustive computed property partitions the 6 PiP zones into Large (`.largeTop` / `.largeBottom`) vs Small (`.smallTopLeft` / `.smallTopRight` / `.smallBottomLeft` / `.smallBottomRight`). No catch-all `default:` clause anywhere in the file — adding a 7th case to the enum later fires a compile error in every adopter. Doc-commented for the 11-PATTERNS "Exhaustive-switch" safety net.
- `HomeView.destination(for: .minesweeper)` arm chains `.videoModeAware(minBoardHeight: 480)` onto the freshly constructed `MinesweeperGameView`. Merge + Nonogram arms unchanged — they adopt in Phase 12 with their own `minBoardHeight` values. Off-path stays byte-identical via `VideoModeAware.body`'s `AnyView(content)` short-circuit when `store.isEnabled` is false (P10 D-05).
- `MinesweeperGameView` reads `@Environment(\.videoModeStore)` + `@Environment(\.videoModeCompactness)` and branches on `(videoModeStore.isEnabled, location.isLarge)`. The `body` is now a `Group { if/else if/else }` over three branches; persistent modifiers (`.navigationTitle` / `.navigationBarTitleDisplayMode` / `.navigationBarBackButtonHidden` / `.alert` / `.onChange(of: scenePhase)` / `.onChange(of: viewModel.phase)` / `.task`) apply to all three branches via the outer Group.
- `MinesweeperGameView+VideoMode.swift` (NEW · 245 lines) holds the layout chrome: `existingLayout` (the v1.0 ZStack body extracted verbatim), `existingToolbarContent` (off-path toolbar), `smallZoneToolbarContent` (Small-zone toolbar with re-anchored placements), `backButton` + `restartButton` shared subviews, and the static `toolbarPlacement(for:)` SlotAnchor → ToolbarItemPlacement mapping.
- D-17 untouched contract verified by `git hash-object`: `MinesweeperBoardView.swift` has hash `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` before AND after Plan 11-03. MagnifyGesture / .scaleEffect / clampZoomScale / cell-level LongPressGesture chain unmodified. The plan does not thread `videoModeStore` into BoardView — that's Plan 11-05's seam (D-10).
- D-09 verified: `.navigationTitle(String(localized: "Minesweeper"))` applies across all 3 branches (lives outside the branch on the outer Group). Title stays visible in every zone selection.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add `isLarge` computed property to VideoModeLocation** — `04e13d9` (feat)
2. **Task 2: Wrap Mines NavigationLink destination in `.videoModeAware(minBoardHeight: 480)`** — `1fb4d07` (feat)
3. **Task 3: Three-way layout branch in MinesweeperGameView + sibling file** — `9d30977` (feat)

## Files Created/Modified

| File | Status | Before | After | Delta | Purpose |
|------|--------|--------|-------|-------|---------|
| `gamekit/gamekit/Core/VideoModeLocation.swift` | MODIFIED | 55 | 75 | +20 | `isLarge` extension added per 11-PATTERNS template |
| `gamekit/gamekit/Screens/HomeView.swift` | MODIFIED | 250 | 251 | +1 | `.videoModeAware(minBoardHeight: 480)` chained on Mines destination (D-04 wrap site) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` | MODIFIED | 401 | 304 | -97 | Body refactored to three-way branch; layout chrome moved to sibling file; `private` dropped from properties consumed by extension; new `videoModeStore` + `videoModeCompactness` env reads |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` | NEW | 0 | 245 | +245 | Owns `existingLayout`, `existingToolbarContent`, `smallZoneToolbarContent`, `backButton`, `restartButton`, `toolbarPlacement(for:)` |

Net code delta: +169 lines across 4 files (most of the growth is doc-comments + the sibling-file struct boilerplate; logic is ~50 lines of branch + toolbar wiring).

## D-17 Untouched Contract — Byte-Identity Verification

`MinesweeperBoardView.swift` was NOT modified by this plan.

| Check | Before P11-03 | After P11-03 |
|-------|---------------|--------------|
| `git hash-object gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` | `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` | `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` |
| `diff <(git show HEAD~1:…/MinesweeperBoardView.swift) …/MinesweeperBoardView.swift` (run after Task 3 commit against pre-P11-03 HEAD) | — | EMPTY (zero output) |

D-17 contract: `MagnifyGesture` + `.scaleEffect(zoomScale, anchor: .center)` + `clampZoomScale(_:)` `[0.8, 2.0]` + cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())` chain preserved verbatim. Plan 11-05 owns the only board-level change (the `minCellSize` Video-Mode-aware lookup, D-10).

## Off-path Byte-Identity Verification

The off-path branch (`if !videoModeStore.isEnabled`) renders `existingLayout.toolbar { existingToolbarContent }`. Both `existingLayout` and `existingToolbarContent` are extracted **verbatim** from the v1.0 body — same ZStack content, same VStack composition, same `.keyframeAnimator` / `.phaseAnimator` / `.opacity` / `.allowsHitTesting` / `.sensoryFeedback` modifier chain, same nav-bar items at the same placements (`.topBarLeading` for Back + Restart, `.topBarTrailing` for `MinesweeperToolbarMenu`).

View-tree shape preserved because the outer `Group` is a SwiftUI no-op container — it does not introduce intermediate layout (Apple's SwiftUI builds Group as a transparent passthrough). The persistent modifiers (`.navigationTitle` / `.navigationBarBackButtonHidden` / `.alert` / `.onChange` / `.task`) apply to the Group's contents, which on the off-path is `existingLayout.toolbar(…)` — semantically equivalent to the v1.0 chained-on-ZStack shape.

SC5 byte-identity end-to-end manual confirmation is deferred to Plan 11-08's full SC1/SC4/SC5 sweep per `<verification>`.

## Mapping from SlotAnchor → ToolbarItemPlacement

The `VideoModeSlotRouter` `SlotAnchor` enum has 6 cases. The defensive mapping in `MinesweeperGameView+VideoMode.swift` covers all of them:

| SlotAnchor case | ToolbarItemPlacement | Reachable on Small zones today? |
|-----------------|----------------------|---------------------------------|
| `.topLeading` | `.topBarLeading` | Yes — smallTopRight / smallBottomLeft `back` slot; smallBottomLeft `back`; smallBottomRight `back` |
| `.topTrailing` | `.topBarTrailing` | Yes — smallTopLeft `back`+`settings`; smallBottomLeft `settings`; smallBottomRight `settings` |
| `.bottomLeading` | `.bottomBar` (defensive) | No — router never emits this for Small-zone `back`/`settings`. Mapped for forward-compat with future Small-zone router refinements. |
| `.bottomTrailing` | `.bottomBar` (defensive) | No — same |
| `.inCompactRow` | `.topBarLeading` (defensive) | No — only emitted on Large zones; Large branch hides the toolbar entirely so the mapping is unreachable |
| `.hidden` | `.topBarLeading` (defensive) | No — currently unused by the router |

The mapping is intentionally exhaustive (no `default:` clause inside `toolbarPlacement(for:)`) so a future `SlotAnchor` case added to the enum fires a compile error here — matching the same safety-net pattern as `VideoModeLocation.isLarge`.

## Small-Zone Toolbar Behavior (D-02)

`smallZoneToolbarContent` reads `let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)` once at the top, then emits three `ToolbarItem`s:

- `ToolbarItem(placement: toolbarPlacement(for: anchors.back)) { backButton }`
- `ToolbarItem(placement: toolbarPlacement(for: anchors.back)) { restartButton }` (paired with Back per Mines spec — both share the `back` anchor)
- `ToolbarItem(placement: toolbarPlacement(for: anchors.settings)) { MinesweeperToolbarMenu(...) }`

Per-zone resolution (from VideoModeSlotRouter.swift):
- `smallTopLeft` → Back/Restart at `.topBarTrailing`, Menu at `.topBarTrailing`
- `smallTopRight` → Back/Restart at `.topBarLeading`, Menu at `.topBarLeading`
- `smallBottomLeft` → Back/Restart at `.topBarLeading`, Menu at `.topBarTrailing`
- `smallBottomRight` → Back/Restart at `.topBarLeading`, Menu at `.topBarTrailing`

HeaderBar + ModePill stay rendered on all Small zones per D-02 ("keep existing layout + Board + ModePill VStack").

## File-Split Decision

`MinesweeperGameView.swift` was 401 lines pre-P11-03 (already at CLAUDE.md §8.5 ≤400-line soft cap). The three-way branch refactor + toolbar helpers + Anchor mapping would have pushed it past the 500-line hard cap. Per 11-PATTERNS guidance:

> "the D-01/D-02 layout branch is the boundary where it splits if it tips over. Plan-task watches for split."

Split applied. Result:
- `MinesweeperGameView.swift`: **304 lines** (-97 net; the body itself shrunk significantly and the toolbar/layout chrome moved out)
- `MinesweeperGameView+VideoMode.swift`: **245 lines** (NEW)
- Combined: **549 lines** — both files individually ≤500.

The sibling file uses Swift extension syntax + drops `private` from cross-referenced properties; no API change since everything stays internal to the module.

## Decisions Made

- **Sibling-file split with internal-property access.** Chosen over an in-file split because the §8.5 cap is per-file, and Swift extensions in separate files cannot see `private` members of the host struct. Trade-off: the host struct's @State / @Environment properties are now internal-default rather than file-scoped. Net assessment: low risk — nothing outside the Minesweeper module imports `MinesweeperGameView`, and the properties were never part of any public API.
- **Defensive 6-case SlotAnchor mapping** rather than 2-case + default. Exhaustive switch fires a compile error if `SlotAnchor` grows a 7th case in v1.3+, mirroring the same safety-net we applied to `VideoModeLocation.isLarge`. Two defensive returns (`.bottomBar` for bottom anchors, `.topBarLeading` for `.inCompactRow`/`.hidden`) keep the mapping total.
- **Large-zone branch ships as STUB**, not as the compact-row composition. Plan 11-03's `<objective>` block locks this scope: "the Large-zone branch ships as a stub that renders the existing layout AND emits a clearly-marked TODO marker for Plan 11-04". The `.toolbar(.hidden, for: .navigationBar)` modifier IS applied so the next plan can rely on a clean nav bar to render the compact row.
- **Outer Group container** chosen over `@ViewBuilder` ternary expansion for the branch site. Group is a no-op SwiftUI container — it does not introduce a layout intermediate — which means all the persistent modifiers (`navigationTitle`, `alert`, `onChange`, `task`) attach to the chosen branch's view tree naturally. This keeps the off-path view tree shape byte-identical to v1.0.
- **`.bottomBar` for the defensive bottom-anchor mapping.** SwiftUI's `ToolbarItemPlacement` does not have `.bottomBarLeading` / `.bottomBarTrailing`; the only standard bottom-bar slot is `.bottomBar`. Forward-compat note for future Small-zone router refinements that might want fine-grained bottom-bar positioning: they'd need to evolve the mapping then.

## Deviations from Plan

### Rule 3 — Auto-fix blocking issue

**1. [Rule 3 - Blocking] Dropped `private` modifier from MinesweeperGameView properties consumed by the sibling-file extension.**

- **Found during:** Task 3, when refactoring `MinesweeperGameView.swift` into a sibling-file split per the plan's `<action>` step 6 ("extract to MinesweeperGameView+VideoMode.swift if you cross ~500 lines").
- **Issue:** Plan's `<acceptance_criteria>` for Task 3 included `grep -c "@Environment(\\\\.videoModeStore) private var videoModeStore"` returning `1` — i.e., the env read was prescribed with `private`. But Swift's `private` is scoped to the **file** containing the declaration. When the layout helpers live in a sibling file (`MinesweeperGameView+VideoMode.swift`), they cannot see `private` members of the host struct. Compile errors would fire on every reference.
- **Fix:** Dropped the `private` modifier from properties the extension consumes:
  - `viewModel` (`@State var`)
  - `dismiss` (`@Environment(\.dismiss) var`)
  - `lossMinesRevealed`, `lossWrongFlagsPopped`, `endCardVisible`, `showConfetti` (`@State var`)
  - `reduceMotion`, `settingsStore` (`@Environment var`)
  - `videoModeStore`, `videoModeCompactness` (new `@Environment var`)
  - `theme` (computed `var`)
  - `endStateOverlay(outcome:)` (`func`)
  - `tripCellIndex` (computed `var`)
  All become internal-default within the gamekit module. No public API change (no module exports `MinesweeperGameView`).
- **Files modified:** `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (Task 3 commit).
- **Commit:** `9d30977`.
- **Why this is Rule 3 and not Rule 4:** the change is a Swift-language access-modifier necessity, not an architectural decision. The plan's `<action>` template wrote `private var ...` from the env-read pattern doc but didn't anticipate the sibling-file split's access requirements. Swift literally rejects the alternative.

### Acceptance-criteria grep adjustment

**2. [Rule 3 - Blocking] Plan acceptance criterion `grep -cE "MinesweeperBoardView\(\s*theme:"` returned `0` despite the constructor call being present.**

- **Found during:** Task 3 verification.
- **Issue:** The `MinesweeperBoardView(` opens on its own line, with `theme:` on the next line. `grep -E` with `\s*` does not span newlines, so the count returned `0`.
- **Fix:** Verified the same intent via `perl -0777` multiline regex (`MinesweeperBoardView\(\s*theme:` matched once). The constructor call IS byte-identical to v1.0 (same props in same order: theme, board, gameState, phase, hapticsEnabled, reduceMotion, revealCount, flagToggleCount, lossMinesRevealed, lossWrongFlagsPopped, lossTripIdx, onTap, onLongPress).
- **Files modified:** none — this is a verification-tooling deviation, not a code change.
- **Commit:** n/a.

### Plan-text leniency

**3. [Spec adjustment] The plan's `<action>` step 3 referenced `Alignment`-shaped anchors; the actual `SlotAnchor` enum has 6 string-named cases.**

- **Found during:** Task 3 implementation, when reading `gamekit/gamekit/Core/VideoModeSlotRouter.swift` per the `<read_first>` step.
- **Issue:** The plan template assumed `SlotAnchorMap` exposed `Alignment` values (`.topLeading` / `.topTrailing`), but it actually exposes a dedicated `SlotAnchor` enum (`topLeading` / `topTrailing` / `bottomLeading` / `bottomTrailing` / `inCompactRow` / `hidden`). The plan explicitly accounted for this contingency: "If the actual `SlotAnchorMap` API exposes a different anchor type than `Alignment`, mirror its shape (read `VideoModeSlotRouter.swift` directly before authoring this helper)."
- **Fix:** Wrote `static func toolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement` with a 6-case exhaustive switch (per the §SlotAnchor table above). Pattern is the same; the type was just `SlotAnchor` rather than `Alignment`.
- **Files modified:** `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` (Task 3 commit).
- **Commit:** `9d30977`.

No Rule 1 (bug fix) or Rule 4 (architectural change) deviations triggered. No auth gates.

## Issues Encountered

- **Pre-existing xcstrings drift carried forward (out of scope).** `gamekit/gamekit/Resources/Localizable.xcstrings` still shows the unstaged modification carried over from before Plan 11-01 (the 3 key stubs `"2048 · Classic"`, `"Drawer open. Tap a mode to play, or tap again to close."`, `"Infinite · Endless"`). Logged in `.planning/phases/11-mines-adoption/deferred-items.md` per executor scope-boundary rules. Left unstaged in all 3 Plan 11-03 commits.
- **Pre-existing Nonogram warning (out of scope).** `xcodebuild build` emits one warning from `gamekit/gamekit/Games/Nonogram/Engine/NonogramLibrary.swift:24:5` ("'nonisolated(unsafe)' is unnecessary for a constant with 'Sendable' type 'NSLock'"). Not introduced by Plan 11-03; touching Nonogram is out of phase scope per `11-CONTEXT.md` §domain ("Merge + Nonogram adoption → Phase 12"). Not logged separately — it's a Nonogram-engine concern that Phase 12 or a separate cleanup will address.

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — **BUILD SUCCEEDED** after Task 1, Task 2, AND Task 3.
- `xcodebuild test -only-testing:gamekitTests/MinesweeperViewModelTests` — **TEST SUCCEEDED** (all VM cases passed; no behavior change in VM).
- `grep -c "var isLarge: Bool" gamekit/gamekit/Core/VideoModeLocation.swift` → `1` ✓
- `grep -c "case .largeTop, .largeBottom:" gamekit/gamekit/Core/VideoModeLocation.swift` → `1` ✓
- `grep -c "case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:" gamekit/gamekit/Core/VideoModeLocation.swift` → `1` ✓
- `grep -c "default:" gamekit/gamekit/Core/VideoModeLocation.swift` → `0` ✓ (after doc-comment rewording — original draft had "no `default:`" in the comment text; reworded to "no catch-all fallback" so the count is true)
- `grep -cE "case largeTop$|case largeBottom" gamekit/gamekit/Core/VideoModeLocation.swift` → `2` ✓ (raw enum cases preserved)
- `grep -c "MinesweeperGameView(initialDifficulty: difficulty)" gamekit/gamekit/Screens/HomeView.swift` → `1` ✓
- `grep -c "\\.videoModeAware(minBoardHeight: 480)" gamekit/gamekit/Screens/HomeView.swift` → `1` ✓
- `grep -c "MergeGameView(initialMode: mode)" gamekit/gamekit/Screens/HomeView.swift` → `1` ✓
- `grep -c "NonogramGameView(initialDifficulty: difficulty)" gamekit/gamekit/Screens/HomeView.swift` → `1` ✓
- `awk '/case .merge/,/case .nonogram/' gamekit/gamekit/Screens/HomeView.swift | grep -c "videoModeAware"` → `0` ✓
- `grep -c "@Environment(\\\\.videoModeStore) var videoModeStore" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓ (literal `private` dropped per Rule 3 deviation #1)
- `grep -c "@Environment(\\\\.videoModeCompactness) var videoModeCompactness" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓
- `grep -c "if !videoModeStore.isEnabled" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓ (off-path branch)
- `grep -c "videoModeStore.location.isLarge" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓ (Large branch)
- `grep -c "VideoModeSlotRouter.anchors(for: videoModeStore.location)" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` → `2` ✓ (Small-zone toolbar + doc comment)
- `grep -c "TODO 11-04" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓ (placeholder for Plan 11-04)
- `grep -c ".navigationTitle(String(localized: \"Minesweeper\"))" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓ (D-09)
- `grep -c ".navigationBarBackButtonHidden(true)" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `1` ✓
- `wc -l gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `304` ✓ (≤500)
- `wc -l gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` → `245` ✓ (≤500)
- `find gamekit/gamekit/Games/Minesweeper -name "* 2.swift"` → empty ✓ (no Finder dupes)
- **D-17 byte-identity:** `git hash-object gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` ✓ (unchanged before AND after Plan 11-03)

## Plan-spec Confirmations (per `<output>` block)

- **3 files modified + 1 created + line-count deltas:** see Files Created/Modified table above. ✓
- **MinesweeperBoardView.swift unmodified (D-17 untouched contract):** git hash unchanged — `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` before and after. ✓
- **Off-path branch structurally byte-identical (view tree shape preserved):** `existingLayout` extracted verbatim from the v1.0 ZStack body; same VStack composition; same `.keyframeAnimator` / `.phaseAnimator` modifier chain; outer `Group` is a no-op SwiftUI container. End-to-end manual SC5 confirmation deferred to Plan 11-08 per `<verification>`. ✓
- **Exact SlotAnchorMap anchor → ToolbarItemPlacement mapping documented:** see Mapping table above. 6-case exhaustive switch, defensive fallbacks for bottom anchors + `.inCompactRow` / `.hidden`. ✓
- **File-split decision documented:** sibling file `MinesweeperGameView+VideoMode.swift` created; 304 + 245 = 549 total lines, both ≤500. ✓

## Next Phase Readiness

- **Plan 11-04 ready.** The Large-zone branch is a stub with a `TODO 11-04` marker that locates the exact insertion point for the `VideoCompactControlRow` composition. The compact-row composition will:
  - Hide `MinesweeperHeaderBar` + `MinesweeperModePill` per D-01.
  - Render `VideoCompactControlRow` per D-05 slot order: `Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart`.
  - Slot 2 = vertical-stack subview (`MinesRemainingChip` on top, `TimerChip` below — both already extracted in Plan 11-01).
  - Slot 3 = `MinesweeperModePill`.
  - Slot 4 = `MinesweeperToolbarMenu` (D-08 — difficulty change menu only).
  - Slot 5 = Restart action.
  - React to `videoModeCompactness` per D-18 (`.collapsedSettings` → fold Settings into Restart overflow; `.reducedTime` → drop the TimerChip half of slot 2).
- **Plan 11-05 ready.** This plan did NOT touch `MinesweeperBoardView.swift` per D-17. Plan 11-05 will add the `minCellSize` Video-Mode-aware lookup (D-10/D-11) inside BoardView, reading `@Environment(\.videoModeStore)` directly per D-12 (purely env-gated, no `location.isLarge` / `difficulty == .hard` conditioning).
- **Plan 11-06 ready.** This plan did NOT pre-add the `safeAreaInsets.top` adjustment (D-16). Plan 11-06 will measure the NavigationStack-mounted board height empirically and decide whether the adjustment is needed.
- **No release-log entry appended this commit.** Per CLAUDE.md §8.10 + §0.3 and the Plan 11-01 / 11-02 precedent, internal structural refactors with no shipped user-facing change are grouped with the Phase 11 wrap-up commit (likely Plan 11-08). The Phase 11 release-log line in 11-PATTERNS will be appended once Phase 11 ships a user-facing surface (Plan 11-04 onward).

## Self-Check: PASSED

- `gamekit/gamekit/Core/VideoModeLocation.swift`: FOUND (75 lines, modified).
- `gamekit/gamekit/Screens/HomeView.swift`: FOUND (251 lines, modified).
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift`: FOUND (304 lines, modified).
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift`: FOUND (245 lines, new).
- Commit `04e13d9`: FOUND (Task 1 — isLarge classifier).
- Commit `1fb4d07`: FOUND (Task 2 — HomeView wrap).
- Commit `9d30977`: FOUND (Task 3 — three-way branch + sibling file).
- Build: green.
- Tests: green (MinesweeperViewModelTests, all cases pass).
- D-17 contract: BoardView byte-identical (hash `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` unchanged).
- No Finder dupes.
- No deletions in any commit.

---
*Phase: 11-mines-adoption*
*Completed: 2026-05-13*
