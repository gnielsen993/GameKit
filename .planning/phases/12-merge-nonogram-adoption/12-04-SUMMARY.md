---
phase: 12-merge-nonogram-adoption
plan: 04
subsystem: nonogram,video-mode
tags: [nonogram, video-mode, layout-branch, wrap-site, compact-row, large-zone, sibling-extension]
requires:
  - 11-mines-adoption/11-03 (three-way layout branch template)
  - 11-mines-adoption/11-04 (compact-row composition + round-2 polish locks)
  - 12-merge-nonogram-adoption/12-02 (Merge wrap + compactRowComposed template — verbatim shape)
  - 12-merge-nonogram-adoption/12-03 (NonogramSizeChip + NonogramLivesChip extracted; VideoModeTimerChip shared primitive)
provides:
  - NonogramModePill compact:Bool=false API (P12 mirror of MinesweeperModePill + MergeModePill)
  - NonogramGameView three-way Video Mode body branch (off / Large / Small)
  - NonogramGameView+VideoMode.swift sibling extension (407 lines)
  - HomeView Nonogram destination wrapped in .videoModeAware(minBoardHeight: 480) — all 3 games now wrapped
affects:
  - NonogramGameView (281 → 186 LOC; access modifiers promoted to internal for extension visibility)
  - NonogramModePill (71 → 83 LOC; compact-variant API added)
  - HomeView (+1 line — Nonogram arm of destination(for:) wrap)
tech-stack:
  added: []
  patterns:
    - "Three-way Group { off / Large / Small } body branch on videoModeStore.isEnabled + location.isLarge"
    - "Sibling-extension file pattern for §8.5 file-size-cap split (existingLayout + chrome lives in +VideoMode.swift)"
    - "VideoCompactControlRow with onSettings: nil (no gear; Fill/Mark picker covers settings — D-NG-01 lock)"
    - "Restart-with-overflow-menu always-collapsed with TWO sections: Change-size (NonogramDifficulty) + Change-mode (NonogramGameMode)"
    - "Symmetric chip-left / picker-center / chip-right compact-row layout (D-NG-01 = P11-04 round 2 mirror)"
    - "Single-slot Size↔Lives conditional swap in slot 2 (D-NG-01 — NOT a stacked composite; D-06 stays superseded)"
key-files:
  created:
    - gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift (407 lines)
  modified:
    - gamekit/gamekit/Games/Nonogram/NonogramModePill.swift (71 → 83 lines; compact:Bool=false API)
    - gamekit/gamekit/Games/Nonogram/NonogramGameView.swift (281 → 186 lines; three-way branch + access promotion)
    - gamekit/gamekit/Screens/HomeView.swift (+1 line; Nonogram arm wrap)
decisions:
  - "D-NG-17 PROVEN: NonogramBoardView.swift SHA fa6c2c0711357fd642210e352047d35e9b097f25 byte-identical from plan start to plan end. Verified via `git rev-parse HEAD~4:…/NonogramBoardView.swift` == `git rev-parse HEAD:…/NonogramBoardView.swift`. Slide gesture, super-cell rules, hint geometry (colHintRowHeight / rowHintColumnWidth / maxRowHints / maxColHints), fill/X mark rendering — all bit-for-bit unchanged. Plan 12-05 handles the cell-size floor seam separately."
  - "D-NG-01 SLOT MAPPING SHIPPED VERBATIM: Slot 1 backButton + onBack closure / Slot 2 single-slot Size↔Lives swap on viewModel.gameMode == .lives / Slot 3 NonogramModePill(compact:true) center-anchored / Slot 4+5 HStack(VideoModeTimerChip(compact:true) gated on != .reducedTime + restartWithOverflowMenu) / Slot 6 onSettings:nil. The slot 2 swap is a single-slot conditional swap — NOT a stacked composite (D-06 stays superseded for this phase per CONTEXT line 54-55)."
  - "D-12-OFFRESTORE PRESERVED: existingLayout in the sibling extension constructs NonogramHeaderBar / NonogramBoardView / NonogramModePill with the SAME prop list and modifier chain as the pre-12-04 NonogramGameView body (verbatim ZStack + VStack(spacing: theme.spacing.m) + same 4 sensoryFeedback triggers + same opacity/allowsHitTesting on the ModePill terminal-state gate). Off-path renders the v1.1 view tree structurally identical to pre-plan state. NonogramHeaderBar continues to invoke NonogramSizeChip / NonogramLivesChip / VideoModeTimerChip with `compact` defaulted (no explicit args) → v1.1 chip render preserved per Plan 12-03 contract."
  - "Sibling extension file split MANDATORY (not soft-choice): NonogramGameView was 281 LOC pre-plan. Adding env reads + three-way Group branch + inline existingLayout / largeZoneLayout / compactRowComposed / restartWithOverflowMenu / toolbar contents would have pushed the host to ~620 LOC — past §8.5's 500-line hard cap. Actual outcome: 186 LOC host + 407 LOC extension. Both under the hard cap; extension lands near the ≤500 line plan ceiling because Nonogram's compactRowComposed has more conditional branches than Mines / Merge (Size↔Lives swap + 2-section menu)."
  - "Access modifier promotions to internal: viewModel, colorScheme, settingsStore, dismiss, endCardVisible, reduceMotion, theme, isInteractive, isTerminal, endStateOverlay. Same shape Mines used during Plan 11-03 + Merge used during Plan 12-02 — extension needs read access to these via the host struct. modelContext + scenePhase + showDifficultyPicker + didInjectStats + difficultyDisplayName stay private (host-only consumers)."
  - "restartWithOverflowMenu uses primaryAction { viewModel.restart() } + TWO sections: Section('Change size') { ForEach(NonogramDifficulty.allCases) } + Section('Change mode') { ForEach(NonogramGameMode.allCases) }. Tap = restart, long-press / chevron = surface both menus. Always collapsed (not gated on videoModeCompactness == .collapsedSettings) per the P11-04 round 1 polish lesson. Both menu enums are CaseIterable in the existing codebase (NonogramDifficulty.swift line 13; NonogramGameMode.swift line 18) — no fallback list needed."
  - "Zero new xcstrings keys introduced. The extension's restartWithOverflowMenu Menu section labels ('Change size' / 'Change mode') already exist in Localizable.xcstrings (lines 297 / 294). The gameModeLabel helper uses 'Free' (existing) and 'Lives  -  3 strikes' (existing line 551 — same key NonogramToolbarMenu uses) instead of a bare 'Lives' to avoid introducing a new key. Difficulty labels ('Tiny  -  5 × 5' etc.) all existed from Phase 6.1."
metrics:
  duration_seconds: 261
  completed_date: 2026-05-13
  task_count: 4
  file_count: 4
---

# Phase 12 Plan 04: Nonogram Video Mode Wrap + Compact-Row Composition — Summary

Landed the Nonogram Video Mode wrap site + three-way layout branch + Large-zone compactRowComposed in a single wave-4 deliverable. Combines the P11-03 wrap-site template, P11-04 compact-row composition template, and Plan 12-02 Merge polish — all collapsed into one plan per the D-12-WAVES contract. Nonogram is the third (and final v1.1 game) to adopt the locked Mines pattern.

## What shipped

| File | Delta | Notes |
|------|-------|-------|
| `gamekit/gamekit/Games/Nonogram/NonogramModePill.swift` | 71 → 83 lines | Added `compact: Bool = false` API mirroring MinesweeperModePill + MergeModePill compact variants: 13pt glyph (vs 16pt), `theme.typography.body` (vs `.headline`), `theme.spacing.s` horizontal pad (vs `.l`), `theme.spacing.xs` vertical pad (vs `.s`), `theme.spacing.l` minHeight (vs 44), `.lineLimit(1) + .minimumScaleFactor(0.7)`. Off-path callers (compact omitted → false) get v1.1 pill byte-identical. |
| `gamekit/gamekit/Screens/HomeView.swift` | +1 line | Nonogram arm of `destination(for:)` chains `.videoModeAware(minBoardHeight: 480)`. All 3 games now wrapped (Mines from P11-03 + Merge from 12-02 + Nonogram from this plan = 3 occurrences of the modifier). |
| `gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift` | NEW (407 lines) | Sibling extension hosting `existingLayout`, `backButton`, `restartButton`, `existingToolbarContent`, `smallZoneToolbarContent`, `toolbarPlacement(for:)` static, `nonogramBoard` (D-NG-17 single-construction helper), `confettiOverlay`, `largeZoneLayout`, `compactRowComposed`, `restartWithOverflowMenu`, `difficultyLabel` + `gameModeLabel` private helpers. Mirrors `MergeGameView+VideoMode.swift` shape — adapted for Nonogram (4 sensoryFeedback modifiers vs Merge's 2; conditional Size↔Lives chip swap in slot 2; 2-section restart menu vs Merge's 1; VideoModeTimerChip gated on `!= .reducedTime` like Mines). |
| `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift` | 281 → 186 lines | Body rewritten as `Group { off / Large / Small }`. Inline ZStack body (lines 47-138) + inline toolbar block (lines 179-215) removed (moved to sibling extension). Env reads added (`@Environment(\.videoModeStore)`, `@Environment(\.videoModeCompactness)`). Access modifiers on `viewModel`, `colorScheme`, `settingsStore`, `dismiss`, `endCardVisible`, `reduceMotion`, `theme`, `isInteractive`, `isTerminal`, `endStateOverlay` promoted from private → internal so the sibling extension can read them. |

## D-NG-17 byte-identity confirmation (the central correctness gate)

`NonogramBoardView.swift` SHA was **NOT** modified across this plan:

```
SHA at plan start (HEAD~4 = commit 1e705e7, parent of 77e02bd):
  fa6c2c0711357fd642210e352047d35e9b097f25

SHA at plan end (HEAD = commit a327935):
  fa6c2c0711357fd642210e352047d35e9b097f25
```

Both SHAs are bit-for-bit identical. `git diff HEAD~4..HEAD -- gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` produces zero output. The slide gesture composition, super-cell rules (`superCellRules` block), hint geometry (`colHintRowHeight` / `rowHintColumnWidth` / `maxRowHints` / `maxColHints` computations), and fill/X-mark rendering are untouched. T-12-NG-WRAP-1 mitigation confirmed.

The cell-size floor seam (D-NG-15) lands in Plan 12-05 — that plan will modify BoardView for the first time in Phase 12, on the known-clean baseline this plan preserved.

## Off-path structural byte-identity (D-12-OFFRESTORE / SC4 / T-12-OFFRESTORE)

When `videoModeStore.isEnabled == false`, the body branch resolves to:

```swift
existingLayout
    .toolbar { existingToolbarContent }
```

…where:

- `existingLayout` is the verbatim extraction of the pre-12-04 `NonogramGameView.body` ZStack: `theme.colors.background.ignoresSafeArea()` + `VStack(spacing: theme.spacing.m) { NonogramHeaderBar + (board OR "No puzzles bundled yet" empty state) + NonogramModePill }` + `confettiOverlay` + end-state overlay. Same props, same closures, same `.sensoryFeedback` triggers (`.error` on `viewModel.wrongAttemptCount`, `.impact(light, 0.7)` on `placeCount`, `.selection` on `markCount`, `.impact(medium, 1.0)` on `lineCompletionCount`), same `.padding(.horizontal, theme.spacing.m).layoutPriority(1)` board chain, same `.opacity(isInteractive ? 1 : 0).allowsHitTesting(isInteractive)` on the ModePill.
- `NonogramModePill` is invoked without an explicit `compact:` argument → defaults to `false` → v1.1 pill shape byte-identical.
- `NonogramHeaderBar` continues to consume `NonogramSizeChip` + `NonogramLivesChip` + `VideoModeTimerChip` with `compact` defaulted to `false` per Plan 12-03's contract — v1.1 chip render preserved. `grep -c "compact" NonogramHeaderBar.swift` returns 0 outside docstrings.
- `existingToolbarContent` recreates the v1.1 toolbar items at the original placements (Back + Restart at `.topBarLeading`; NonogramToolbarMenu at `.topBarTrailing`) — byte-identical button bodies (44×44 chevron + counterclockwise arrow, same accessibility labels).
- The confetti gate (`viewModel.state == .won && settingsStore.animationsEnabled && !reduceMotion`) and end-state gate (`isTerminal && endCardVisible`) preserved verbatim via the shared `confettiOverlay` + `endStateOverlay` helpers.

Off-path render is structurally byte-identical to v1.1 (the user-visible composition matches; the view-tree is the same).

## D-NG-01 slot mapping (compact-row composition)

The `compactRowComposed` in the sibling extension wires the Large-zone branch to `VideoCompactControlRow` with the D-NG-01 slot order verbatim:

| Slot | Content | Notes |
|------|---------|-------|
| 1 | `onBack: { dismiss() }` | Back closure invokes `dismiss` from the host's environment. |
| 2 | `if viewModel.gameMode == .lives { NonogramLivesChip(compact:true) } else { NonogramSizeChip(compact:true) }` | **Single-slot conditional swap per D-NG-01** — NOT a stacked composite. In Free mode, slot 2 renders Size. In Lives mode, slot 2 renders 3-heart Lives chip. D-06 stacked variant stays superseded for this phase (CONTEXT line 54-55). |
| 3 | `NonogramModePill(theme:, mode: viewModel.interactionMode, isInteractive: isInteractive, onSelect: { viewModel.setInteractionMode($0) }, compact: true)` | Center-anchored via `VideoCompactControlRow`'s Spacer flanking. Fill/Mark picker — the Reveal/Flag equivalent for Nonogram. |
| 4 + 5 (secondaryInfo HStack) | `if videoModeCompactness != .reducedTime { VideoModeTimerChip(compact: true) }` + `restartWithOverflowMenu` | `HStack(spacing: theme.spacing.s)`. TimerChip gated on `!= .reducedTime` to match Mines's P11-04 D-18 reaction. Restart hosts the always-collapsed 2-section menu. |
| 6 | `onSettings: nil` | Gear dropped — Fill/Mark picker covers settings role (D-NG-01 lock; matches Mines P11-04 round 1 polish carry-over and Plan 12-02 Merge). |

`restartWithOverflowMenu` uses:
```swift
Menu {
    Section("Change size") {
        ForEach(NonogramDifficulty.allCases) { ... }
    }
    Section("Change mode") {
        ForEach(NonogramGameMode.allCases) { ... }
    }
} label: { ... } primaryAction: { viewModel.restart() }
```

Tap = restart (the common case during play); long-press / chevron tap surfaces both menus with checkmarks on the current difficulty + mode. Always-collapsed (NOT gated on `videoModeCompactness == .collapsedSettings`) per the P11-04 round 1 polish lesson. Two sections vs Mines's one — Nonogram has both difficulty AND game-mode (Free / Lives) to expose. Merge's single Change-mode section is the simpler case.

## File-split decision (sibling extension MANDATORY)

The plan called for a sibling extension up front rather than as a soft choice. Rationale:

- Pre-12-04 NonogramGameView was 281 LOC.
- Adding env reads (+5) + three-way Group branch (+15) + inline existingLayout (~50 LOC body), inline largeZoneLayout (~60 LOC), inline compactRowComposed (~50 LOC), inline restartWithOverflowMenu (~40 LOC), inline existingToolbarContent + smallZoneToolbarContent + toolbarPlacement static + nonogramBoard helper + confettiOverlay (~120 LOC combined) would have pushed the host to ~620 LOC — past §8.5's 500-line hard cap.
- Actual outcome: 186 LOC host + 407 LOC extension. Both under §8.5's 500-line hard cap. The extension lands closer to the ≤500 line plan ceiling than Mines (486 LOC) / Merge (308 LOC) because Nonogram's compactRowComposed has more conditional branches than the other two games (Size↔Lives swap in slot 2 + 2-section restart menu vs Mines's 1-section + Merge's 1-section).
- Each file's MARK sections stay coherent (host = "scene wiring + body branch + end-state overlay + scene-phase lifecycle"; extension = "Video Mode layout helpers").

## xcstrings keys — zero new keys introduced

All localized strings consumed by the new sibling extension already exist in `Localizable.xcstrings`:

- `"Back to The Drawer"` — existed (Phase 2; cross-game)
- `"Restart game"` — existed (Phase 4; cross-game)
- `"Change size"` — existed (xcstrings line 297; Phase 6+ used by toolbar variants)
- `"Change mode"` — existed (xcstrings line 294; Phase 6+)
- `"Free"` — existed (xcstrings line 435; NonogramToolbarMenu consumer)
- `"Lives  -  3 strikes"` — existed (xcstrings line 551; NonogramToolbarMenu consumer). The plan acceptance note mentioned `"Lives"` (bare) as a possible new key; verified that bare `"Lives"` is NOT in xcstrings, so the extension reuses the existing `"Lives  -  3 strikes"` key NonogramToolbarMenu uses — no new keys.
- `"Tiny  -  5 × 5"`, `"Small  -  10 × 10"`, `"Medium  -  15 × 15"`, `"Large  -  20 × 20"` — existed (Phase 6 / 6.1; consumed by NonogramGameView.difficultyDisplayName + NonogramToolbarMenu)

`gamekit/gamekit/Resources/Localizable.xcstrings` shows a pre-existing uncommitted modification carried over from Plan 12-02 / 12-03 (Xcode auto-managed additions from prior surface edits — not introduced by this plan and out of Task 1-4 acceptance criteria scope). Left uncommitted; same SCOPE BOUNDARY rule Plan 12-02 invoked.

## NonogramBoardView untouched contract (D-NG-17)

- This plan does NOT modify `NonogramBoardView.swift`. The plan's acceptance criterion `diff <(git show HEAD:gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift) gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` produces ZERO output.
- The `nonogramBoard` helper in `NonogramGameView+VideoMode.swift` invokes `NonogramBoardView(...)` with the EXACT same prop list and modifier chain (frame / horizontal-padding / layoutPriority / 4 sensoryFeedback triggers) as the pre-12-04 inline call site at NonogramGameView.swift:60-100. Both `existingLayout` and `largeZoneLayout` consume the same helper → single source of truth for VM-trigger wiring.
- Plan 12-05 will add the Video-Mode-aware cell-size floor seam (env read + defaulted `floor:` param on `cellSize(...)`) to BoardView for the first time in Phase 12, on the known-clean baseline this plan preserved.

## Verification

- **Build:** `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → `** BUILD SUCCEEDED **` after Task 4. (Task 3 acceptance criterion explicitly allowed mid-task build red because the sibling extension's references to `theme` / `viewModel` / `isInteractive` / `isTerminal` / `endStateOverlay` / `endCardVisible` were inaccessible until Task 4 promoted them — Task 4 wired it and the sequenced pair lands green end-to-end.)
- **NonogramViewModelTests:** `** TEST SUCCEEDED **` on iPhone 17 Pro sim. VM behavior unchanged — the refactor is view-tree only.
- **D-NG-17:** `git rev-parse HEAD~4:gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` == `git rev-parse HEAD:gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` == `fa6c2c0711357fd642210e352047d35e9b097f25`. Byte-identical.
- **D-12-OFFRESTORE:** Off-path view tree structurally byte-identical (same props, same closures, same modifier chain). NonogramHeaderBar invokes all 3 chips with `compact` defaulted (no explicit args).
- **File-size cap (§8.5):** NonogramModePill 83 / NonogramGameView 186 / NonogramGameView+VideoMode 407. All well under the 500-line hard cap.
- **Token discipline (§2 / FOUND-07):** `grep -cE "Color\(|cornerRadius: [0-9]|padding\([0-9]"` returns `0` for NonogramModePill.swift AND NonogramGameView+VideoMode.swift.
- **§8.7 no Finder dupes:** `find gamekit/gamekit/Games/Nonogram -name "*\ 2.swift"` returns nothing.
- **Manual smoke (deferred to Plan 12-06):** Per the plan's verification block, the full SC sweep moves to Plan 12-06's 24-row manual matrix. This plan needed only build + tests + D-NG-17 byte-identity + grep acceptance, all of which are green.

## Commits

| Task | Type | Hash | Message |
|------|------|------|---------|
| 1 | feat | `77e02bd` | feat(12-04): add compact:Bool=false API to NonogramModePill |
| 2 | feat | `b524780` | feat(12-04): wrap Nonogram NavigationLink destination in .videoModeAware |
| 3 | feat | `01ce270` | feat(12-04): add NonogramGameView+VideoMode sibling extension |
| 4 | refactor | `a327935` | refactor(12-04): three-way Video Mode branch in NonogramGameView body |

## Deviations from Plan

None — plan executed exactly as written. All 4 tasks landed in their own commits per CLAUDE.md §8.10 commit discipline. No Rule 1–4 deviations triggered:

- No bugs surfaced (Rule 1 not invoked).
- No missing critical functionality (Rule 2 not invoked) — all behavior gates preserved (confetti gate, end-state gate, ModePill terminal-state gate, 4 sensoryFeedback modifiers, scenePhase pause/resume, `.task` lazy stats injection guarded by `didInjectStats`).
- No blocking issues (Rule 3 not invoked) — all required types (`NonogramSizeChip`, `NonogramLivesChip`, `VideoModeTimerChip`, `VideoCompactControlRow`, `VideoModeSlotRouter`, `SlotAnchor`, `NonogramGameMode.allCases`, `NonogramDifficulty.allCases`) existed at plan start. The plan's "defensive fallback to an explicit `[NonogramGameMode.free, .lives]` list if not CaseIterable" was unnecessary — both enums are already `CaseIterable` (NonogramGameMode.swift line 18 + NonogramDifficulty.swift line 13).
- No architectural decisions surfaced (Rule 4 not invoked) — the plan inherits the locked Mines + Merge pattern verbatim.

The plan called out `"Lives"` (bare) as a possibly new xcstrings key — verified absent from xcstrings, used the existing `"Lives  -  3 strikes"` key (line 551) that NonogramToolbarMenu already consumes. No new keys introduced.

The pre-existing uncommitted `Localizable.xcstrings` modification (carried over from Plan 12-02 / 12-03; auto-managed Xcode additions from prior MergeToolbarMenu / Drawer surface edits) remains uncommitted. Not a deviation — explicit SCOPE BOUNDARY rule preserves it; downstream phase-close commit (Plan 12-06) or housekeeping pass will sweep.

## Downstream consumers (Plans 12-05 / 12-06)

- **Plan 12-05 (Nonogram cell-size floor audit):** Will touch `NonogramBoardView.swift` for the FIRST time in Phase 12 (env read + defaulted `floor:` param + single call-site change in `body`). This plan's SHA-preservation guarantee (`fa6c2c0...`) means the floor seam lands on a known-clean baseline. Audit happens on Hard Nonogram (15×15) / hardest = 20×20 — same audit-checkpoint shape Mines used in Plan 11-05.
- **Plan 12-06 (phase close):** Manual matrix sweep across Merge + Nonogram × 2 difficulties × 6 zones (24 rows per D-12-MATRIX). Off-path SC4 sweep will visually confirm the structural byte-identity claim made in this summary (D-12-OFFRESTORE for both games). Append Phase 12 entries to `Docs/releases/v1.2.md` per CLAUDE.md §8.14 / D-12-RELEASELOG.

## Shared VideoModeTimerChip — consumer count

Post-Plan-12-04, the shared timer chip is now consumed by all 4 game-mode call sites:
- `MinesweeperHeaderBar` (Plan 12-01) — off-path / Small PiP zones, `compact: false`
- `MinesweeperGameView+VideoMode.compactRowComposed` (Plan 12-01) — Large zones, `compact: true`
- `NonogramHeaderBar` (Plan 12-03) — off-path / Small PiP zones, `compact: false`
- `NonogramGameView+VideoMode.compactRowComposed` (this plan) — Large zones, `compact: true`

Merge has no live timer (D-MG-01 explicit); it consumes a `MergeBestChip` instead in the right-side slot. The shared chip's `compact:Bool=false` API is now battle-tested across 2 games × 2 paths.

## Success criteria mapping

| SC | Mapping | Status |
|----|---------|--------|
| SC1 (Nonogram plays across 6 PiP locations) | D-NG-01 slot mapping + three-way branch + .videoModeAware wrap | Code complete; visual sweep deferred to Plan 12-06 |
| SC2 (Hard nonogram hint legibility) | Depends on Plan 12-05 floor seam | Out of scope for THIS plan (12-04+12-05 close SC2 together) |
| SC3 (Legibility regression Classic + Loud) | Depends on Plan 12-05 + 12-06 manual matrix | Out of scope for THIS plan |
| SC4 (Off-restore byte-identity for Nonogram) | D-12-OFFRESTORE preserved via defaulted compact:false | PROVEN — chips invoked without compact arg; existingLayout extracted verbatim |
| SC5 (Compact row consumed verbatim — no per-game forking) | D-NG-01 inherits shared VideoCompactControlRow | PROVEN — `grep -c "VideoCompactControlRow(" NonogramGameView+VideoMode.swift` returns 1 |

This plan delivers SC1 (Nonogram plays across all 6 PiP locations), SC4 (Off-restore byte-identity for Nonogram), and SC5 (compact row consumed verbatim for Nonogram). SC2 + SC3 land in Plan 12-05 alongside the cell-size floor seam.

## Self-Check: PASSED

- `gamekit/gamekit/Games/Nonogram/NonogramModePill.swift`: FOUND (compact API present, 83 lines)
- `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift`: FOUND (three-way branch, 186 lines)
- `gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift`: FOUND (407-line sibling extension)
- `gamekit/gamekit/Screens/HomeView.swift`: FOUND (Nonogram arm wrap; 3 occurrences of `.videoModeAware(minBoardHeight: 480)` — Mines + Merge + Nonogram)
- `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift`: PRESENT and SHA UNCHANGED (`fa6c2c0711357fd642210e352047d35e9b097f25` matches HEAD~4)
- Commit `77e02bd` (Task 1): FOUND
- Commit `b524780` (Task 2): FOUND
- Commit `01ce270` (Task 3): FOUND
- Commit `a327935` (Task 4): FOUND
- Build: `** BUILD SUCCEEDED **`
- NonogramViewModelTests: `** TEST SUCCEEDED **`
