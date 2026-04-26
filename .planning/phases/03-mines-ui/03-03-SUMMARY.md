---
phase: 03-mines-ui
plan: 03
subsystem: minesweeper-leaf-views
status: complete
completed: 2026-04-26
duration_minutes: 6
tags:
  - swift
  - swiftui
  - minesweeper
  - leaf-views
  - theme-tokens
  - accessibility
  - gesture-composition
  - timeline-view
requirements:
  - MINES-02
  - MINES-05
  - MINES-07
  - MINES-11
  - THEME-02
  - A11Y-02
dependency_graph:
  requires:
    - "Plan 03-01 (DesignKit theme.gameNumber(_:) token + 6-preset palettes)"
    - "Plan 03-02 (MinesweeperViewModel — GameOutcome / LossContext types)"
    - "Phase 2 engine models (MinesweeperCell, MinesweeperIndex, MinesweeperGameState, MinesweeperDifficulty)"
    - "DesignKit DKCard + DKButton (consumed without local restyling)"
  provides:
    - "MinesweeperHeaderBar — props-only counter chip + TimelineView timer chip"
    - "MinesweeperCellView — props-only single tile (gesture + glyph + a11y)"
    - "MinesweeperToolbarMenu — props-only difficulty Menu (callback routing)"
    - "MinesweeperEndStateCard — props-only DKCard overlay (Restart + Change difficulty)"
  affects:
    - "Plan 03-04 (Mines UI composition) — composes these 4 leaf views into MinesweeperBoardView + MinesweeperGameView"
tech_stack:
  added:
    - "TimelineView(.periodic) timer pattern (first occurrence in repo)"
    - "LongPressGesture(0.25).exclusively(before: TapGesture()) cell-level gesture (first occurrence)"
    - "LocalizedStringKey-based accessibilityLabel pattern with 1-indexed row/col"
    - "Per-cell glyph switch over (state x isMine x isLost) for D-17 loss reveal"
  patterns:
    - "Props-only data-driven views (CLAUDE.md §8.2) — theme passed as let parameter, never @EnvironmentObject"
    - "DKCard / DKButton consumed without local restyling (UI-SPEC §Component Inventory)"
    - "Token-only color discipline (zero Color(...) literals across all 4 files)"
key_files:
  created:
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift (133 lines)"
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift (165 lines)"
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperToolbarMenu.swift (62 lines)"
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift (113 lines)"
  modified: []
decisions:
  - "03-03: HeaderBar timerAnchor fallback uses .distantPast (not .now) — when nil, TimelineView stops firing entirely; display math returns pausedElapsed regardless of context.date. Practically equivalent to .now but avoids wasted ticks (planner-noted choice)"
  - "03-03: CellView TileBackground inlined as private var tileBackground + private var backgroundFill: Color rather than the sibling struct shape from PATTERNS — equivalent semantics, fewer types to read at this size"
  - "03-03: CellView background switch covers all 4 Cell.State cases including .mineHit (which uses theme.colors.danger fill), even though .mineHit also has a bespoke glyph arm — keeps the switch exhaustive and lets P5 layer a phase-driven cross-fade if needed"
  - "03-03: ToolbarMenu trigger uses theme.typography.headline (17pt semibold) over .title (22pt) — fits Easy/Medium/Hard inside iPhone SE toolbar width without truncation; UI-SPEC mentioned .title; this is a documented planner deviation and the executor confirmed .headline"
  - "03-03: EndStateCard secondary button calls onChangeDifficulty closure which Plan 04 will wire to viewModel.restart() per refined D-03 (W-02) — sheet-presented difficulty picker deferred to P5"
  - "03-03: formatElapsed(_:) intentionally duplicated between HeaderBar and EndStateCard — 2 call sites in one game is below the DesignKit-promotion bar (CLAUDE.md §4); P5 may extract MinesweeperTimeFormat.swift if duplication grows"
  - "03-03: HeaderBar adds .monospacedDigit() modifier alongside theme.typography.monoNumber — belt + suspenders against any system font fallback that doesn't honor the .monospaced design hint"
metrics:
  duration: "~6 minutes"
  tasks: 4
  files_created: 4
  files_modified: 0
  total_lines: 473
---

# Phase 3 Plan 03: Minesweeper Leaf Views Summary

Four atomic, props-only SwiftUI leaf views land under `gamekit/gamekit/Games/Minesweeper/` — each receives `theme: Theme` plus its render data plus closure callbacks (no VM coupling), each consumes DesignKit components without local restyling, and the cell view encodes the load-bearing `LongPressGesture(0.25).exclusively(before: TapGesture())` SC1 contract plus the 1-indexed `accessibilityLabel`-baked-at-view-creation SC6 contract.

## Performance

- **Duration:** ~6 minutes
- **Tasks:** 4 (all green on first build)
- **Files created:** 4 (133 + 165 + 62 + 113 = 473 lines total)
- **Files modified:** 0 — wholly additive plan; existing P1/P2 files untouched
- **Builds:** 4 clean `xcodebuild build` runs (one per task), all `BUILD SUCCEEDED`

## Task Commits

Each task committed atomically with a `feat(03-03)` prefix:

1. **Task 1 — MinesweeperHeaderBar (TimelineView timer chip):** `28f4337`
2. **Task 2 — MinesweeperCellView (gesture composition + glyph + a11y):** `efe32de`
3. **Task 3 — MinesweeperToolbarMenu (Easy/Medium/Hard Menu):** `ea4a1c3`
4. **Task 4 — MinesweeperEndStateCard (DKCard overlay + 2 DKButtons):** `271764f`

## Files Created

| File | Lines | Disposition | Per-file budget (UI-SPEC) |
|------|-------|-------------|---------------------------|
| `MinesweeperHeaderBar.swift` | 133 | NEW — counter chip + TimelineView timer chip | <150 — within budget |
| `MinesweeperCellView.swift` | 165 | NEW — single tile, gesture, glyph switch, a11y | <250 — within budget |
| `MinesweeperToolbarMenu.swift` | 62 | NEW — toolbar Menu over difficulties | <100 — within budget |
| `MinesweeperEndStateCard.swift` | 113 | NEW — DKCard outcome overlay | <200 — within budget |

All four files comfortably under the 400-line view cap and the 500-line CLAUDE.md §8.5 hard cap. Total LoC under 500 across the four leaf views — Plan 04's composition layer has plenty of room to add `MinesweeperBoardView` + `MinesweeperGameView` without straining file-size budgets.

## Decision IDs implemented

- **D-01..D-04** (end-state card shape) — `MinesweeperEndStateCard.swift` composes `DKCard` with the four content elements (outcome title, elapsed, loss-context line, two-button stack). DKCard supplies `radii.card` / `spacing.l` / `surface` / `border`; this view never redeclares them. Win title tinted `theme.colors.success`, loss title tinted `theme.colors.danger`; body text stays `theme.colors.textPrimary` for cross-preset calmness (D-04).
- **D-05** (TimelineView timer) — `MinesweeperHeaderBar.swift` renders the timer via `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))`. Zero `Timer.publish`, zero Combine, zero `Task { while … sleep }`. When `timerAnchor` is nil the chip displays `pausedElapsed` and TimelineView stops firing (because `.distantPast` is not in the future).
- **D-09** (toolbar Menu shape) — `MinesweeperToolbarMenu.swift` renders a SwiftUI `Menu` with three `Button`s from `MinesweeperDifficulty.allCases`. Trigger glyph is `slider.horizontal.3` per UI-SPEC.
- **D-13** (consumption of `theme.gameNumber(_:)`) — `MinesweeperCellView.swift` adjacency-number arm reads `theme.gameNumber(cell.adjacentMineCount)` for the `.foregroundStyle()`. Plan 01 supplied the token; this plan is the first consumer.
- **D-17** (loss-state glyph switch) — `MinesweeperCellView.swift` `glyph` body switches on `(cell.state, cell.isMine, isLost)` with the three loss-state arms ordered per RESEARCH §Pattern 5: trip mine → hidden mine on loss → wrongly-flagged cell with X overlay → normal flag → revealed numbered → revealed empty.
- **D-18** (no animation in P3) — Loss reveal flips instantly. The switch arms are structured so Plan 5 can later layer `phase: MinesweeperPhase` cross-fades without touching V/VM contracts.
- **D-19** (a11y baked at view creation, 1-indexed) — `MinesweeperCellView.swift` `accessibilityLabelKey` is a `LocalizedStringKey` computed property called inside `body`'s `.accessibilityLabel(_:)`. Row/col are interpolated as `index.row + 1` and `index.col + 1` — 1-indexed in the spoken label per ROADMAP exemplar.
- **D-20** (button + overlay a11y at view creation) — Both `MinesweeperEndStateCard` (overlay-level `accessibilityLabel` via `children: .combine`) and the chips in `MinesweeperHeaderBar` ship `accessibilityLabel` / `accessibilityValue` directly inside `body`, never via `.onAppear` retrofit.

## Requirement IDs satisfied (view-side)

- **MINES-02** (cell view gesture composition) — `MinesweeperCellView.swift` ships the literal `LongPressGesture(minimumDuration: 0.25).exclusively(before: TapGesture())` source pattern. SC1 50-tap manual test on iPhone SE remains a Plan 04 verification gate (the gesture cannot be exercised standalone — it needs a parent that wires the closures into a VM).
- **MINES-05** (header bar counter + timer) — `MinesweeperHeaderBar.swift` ships counter chip (mines remaining, 3-digit zero-pad, negative-tolerant) + TimelineView-driven timer chip with `monoNumber` font + `.monospacedDigit()` to prevent jitter. SC2 pause/resume math is in the VM (Plan 02); this view consumes `timerAnchor` + `pausedElapsed` correctly to render the frozen / live timer.
- **MINES-07** (end-state card outcome rendering) — `MinesweeperEndStateCard.swift` renders win as "You won!" + elapsed; loss as "Bad luck" + elapsed + context line. SC4 outcome tinting (`success` for win, `danger` for loss) verified via grep.
- **MINES-11** (cell view loss-state mine reveal + wrong-flag X) — `MinesweeperCellView.swift` glyph switch arms 1, 2, 3 implement D-17 verbatim: the trip mine background fills `theme.colors.danger`, every other hidden mine flips to a visible mine glyph on loss, and wrongly-flagged cells render the flag with an X overlay (both in `theme.colors.danger`).
- **THEME-02** (token-only color consumption) — All 4 files: zero `Color(...)` literals (FOUND-07 hook regex returns no matches). The pre-commit hook would have caught any `Color(red:|hex:|white:)` or `Color.<colorname>` literal in `Games/Minesweeper/`. Adjacency colors specifically read `theme.gameNumber(n)` per D-13.
- **A11Y-02** (cell + button + overlay a11y baked in, partial — full audit lives in P5) — `MinesweeperCellView.accessibilityLabel` is a 1-indexed `LocalizedStringKey` switched on `cell.state`; `MinesweeperHeaderBar` chips ship `accessibilityLabel` + `accessibilityValue`; `MinesweeperToolbarMenu` ships `accessibilityLabel("Difficulty")` + `accessibilityValue(displayName)`; `MinesweeperEndStateCard` ships an overlay-level `accessibilityLabel` via `children: .combine`. All baked at view creation (no `.onAppear` retrofits).

## SC1 contract reaffirmation (load-bearing for Plan 04 verification)

The literal source patterns required by SC1 are present in `MinesweeperCellView.swift` exactly as ROADMAP locks them:

```
$ grep -n "LongPressGesture(minimumDuration: 0.25)\|exclusively(before: TapGesture" gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift
9://       (LongPressGesture(0.25).exclusively(before: TapGesture()))
45:                LongPressGesture(minimumDuration: 0.25)
46:                    .exclusively(before: TapGesture())
```

`.exclusively(before:)` (line 46) is NOT `.simultaneously(with:)` — RESEARCH Pitfall 7 (which would fire both gestures) is structurally avoided. The 50-tap iPhone SE manual misfire test scheduled in Plan 04's verification can now exercise this contract end-to-end.

## Verification

- `xcodebuild build -project gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` → `** BUILD SUCCEEDED **` (clean across all 4 task commits)
- `grep -E '^\s*Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' gamekit/gamekit/Games/Minesweeper/Minesweeper{HeaderBar,CellView,ToolbarMenu,EndStateCard}.swift` → exit 1 (zero matches; FOUND-07 hook would not have rejected any of the 4 commits)
- `grep -E "^[^/]*Timer\.publish|^[^/]*Timer\.scheduledTimer|^import Combine" MinesweeperHeaderBar.swift` → exit 1 (no actual `Timer.publish` / `Timer.scheduledTimer` / `import Combine` in code; the only matches were inside the file's documentation header explicitly forbidding these patterns)
- All 4 files inside per-file UI-SPEC budgets and well under the CLAUDE.md §8.5 hard cap

## Deviations from Plan

### Auto-fixed Issues

None. Plan 03-03 executed exactly as written. The four leaf views compiled cleanly on first build; no Rule 1 / 2 / 3 fixes were needed.

### Planned deviations from PATTERNS.md (called out by the planner; reproduced here for the record)

These are not surprises — the planner explicitly listed these in the plan; reproducing for traceability:

1. **`MinesweeperCellView` TileBackground inlined.** PATTERNS sketched a sibling `private struct TileBackground` view; the executor used the inlined `private var tileBackground: some View` ViewBuilder + `private var backgroundFill: Color` switch instead. Equivalent semantics, fewer types to read at 165 lines. Planner explicitly OK'd either form ("planner recommends the inlined form for clarity at this size").
2. **`MinesweeperToolbarMenu` trigger uses `.headline` not `.title`.** UI-SPEC mentioned `.title` (22pt semibold) for the trigger label; the planner pre-emptively flagged this as a documented deviation and recommended `.headline` (17pt semibold) so "Medium" / "Hard" fit inside the iPhone SE toolbar width. Executor confirmed `.headline`. Iterating to `.title` after iPhone SE manual fit-verification in Plan 04 remains an option.
3. **`MinesweeperHeaderBar` timer fallback uses `.distantPast` not `.now`.** Plan said either was acceptable when `timerAnchor` is nil, with a planner note that `.distantPast` is more efficient (TimelineView stops firing entirely). Executor took the planner's recommendation.
4. **`formatElapsed(_:)` duplicated between HeaderBar and EndStateCard.** Planner explicitly accepted this as below the CLAUDE.md §4 promotion bar (2 call sites in one game; promote when used in 2+ games). P5 may extract a shared formatter if the duplication grows.

### Authentication gates

None — pure SwiftUI code, no external services, no auth.

## Per-file size summary (UI-SPEC budgets vs actuals)

| File | UI-SPEC budget | Actual | Status |
|------|---------------|--------|--------|
| `MinesweeperHeaderBar.swift` | <150 | 133 | within budget |
| `MinesweeperCellView.swift` | <250 (planner allowed up to 300 because the switch is exhaustive) | 165 | well within budget |
| `MinesweeperToolbarMenu.swift` | <100 | 62 | well within budget |
| `MinesweeperEndStateCard.swift` | <200 | 113 | well within budget |

No file grew larger than its budget; nothing required splitting.

## Wave 2 status

Plan 03-03 closes the **leaf-view** half of Wave 2. Plan 03-04 (the composer plan: `MinesweeperBoardView` + `MinesweeperGameView` + `HomeView` `.navigationDestination` rewire + `Localizable.xcstrings` extraction + SC1 50-tap manual gate) can now compose these 4 settled props-only views into the playable game scene. None of the leaf views imports the VM directly — Plan 04 is the only place where `@State private var viewModel: MinesweeperViewModel` lives, and it threads `theme: Theme` + render data + closure callbacks down into each leaf view per RESEARCH §Anti-Pattern "Re-fetching theme tokens inside cell views."

## Issues Encountered

None. Tasks 1–4 each produced a single clean commit on a green build.

## TDD Gate Compliance

The plan declared `tdd="false"` on each task — these are SwiftUI leaf views with no business logic to test in isolation. Their behavior is exercised end-to-end in Plan 04 (the manual 50-tap iPhone SE gesture test for SC1; manual visual verification under 4+ presets per CLAUDE.md §8.12). No RED/GREEN/REFACTOR gates apply at this layer.

## User Setup Required

None — pure Swift code, no external services, no environment configuration.

## Next Plan Readiness

Plan 03-04 (Mines UI composition) can immediately:
- Import these 4 leaf views by file proximity (synchronized root group auto-registers per CLAUDE.md §8.8; already validated empirically across all of P2 + P3-02)
- Hoist `theme: Theme` from `themeManager.theme(using: colorScheme)` once at the top of `MinesweeperGameView` and pass as a `let` into each leaf
- Wire `MinesweeperHeaderBar(theme:, minesRemaining: vm.minesRemaining, timerAnchor: vm.timerAnchor, pausedElapsed: vm.pausedElapsed)`
- Wire `MinesweeperBoardView(theme:, board: vm.board, gameState: vm.gameState, onTap: vm.reveal, onLongPress: vm.toggleFlag)` instantiating `MinesweeperCellView` per cell inside a `LazyVGrid`
- Wire `.toolbar { ToolbarItem(placement: .topBarTrailing) { MinesweeperToolbarMenu(theme:, currentDifficulty: vm.difficulty, onSelect: vm.requestDifficultyChange) } }`
- Wire `MinesweeperEndStateCard(theme:, outcome: outcome, elapsed: vm.frozenElapsed, lossContext: vm.lossContext, onRestart: vm.restart, onChangeDifficulty: vm.restart)` per refined D-03 W-02

The leaf-view contracts are settled; the composer plan is purely a wiring exercise plus the SC1 manual gate.

## Self-Check: PASSED

- `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` exists (133 lines) — verified
- `gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift` exists (165 lines) — verified
- `gamekit/gamekit/Games/Minesweeper/MinesweeperToolbarMenu.swift` exists (62 lines) — verified
- `gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift` exists (113 lines) — verified
- Commit `28f4337` (Task 1) exists in repo — verified
- Commit `efe32de` (Task 2) exists in repo — verified
- Commit `ea4a1c3` (Task 3) exists in repo — verified
- Commit `271764f` (Task 4) exists in repo — verified
- `xcodebuild build` clean across all 4 task commits — verified
- Zero `Color(...)` literals across all 4 files — verified by FOUND-07-style strict regex (exit 1)
- SC1 contract source pattern present in `MinesweeperCellView.swift` (lines 45–46) — verified

---

*Phase: 03-mines-ui*
*Completed: 2026-04-26*
