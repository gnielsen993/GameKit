# Phase 11: Minesweeper Adoption - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Minesweeper adopts the v1.2 Video Mode primitives shipped by Phases 9 + 10.

In scope:
- Wrap `MinesweeperGameView` outermost layer with `.videoModeAware(minBoardHeight: 480)` per Phase 10 D-14.
- Implement the Phase 8 ADR smaller-cells Hard strategy by gating
  `MinesweeperBoardView.Self.minCellSize` on `videoModeStore.isEnabled`.
- Render `VideoCompactControlRow` (P9 D-12) on Large PiP zones with the
  Mines-specific slot mapping (see D-05). Existing `MinesweeperHeaderBar` +
  `MinesweeperModePill` + nav-toolbar items hide on Large zones.
- On Small PiP zones, keep existing HeaderBar + ModePill + board layout;
  reposition individual nav-toolbar items via `VideoModeSlotRouter.anchors(for:)`.
- Extract `MinesRemainingChip` + `TimerChip` sibling subviews from
  `MinesweeperHeaderBar` so the HeaderBar (non-video / Small) and the compact
  row's stacked chip slot (Large) share one rendering.
- Easy + Medium fully playable across all 6 PiP zones; Hard 16×30
  legibility-validated per ADR screenshots on Classic + one Loud preset.
- Author `11-VIDEO-MANUAL-CHECK.md` matrix doc (18 rows = 3 difficulties × 6
  zones); SC1 lands Easy/Medium pass marks; SC3 lands Hard final-render parity
  refs.

Out of scope:
- End-state overlay redesign → Phase 13 (banner replacement).
- Merge + Nonogram adoption → Phase 12.
- Auto-detection of another app's PiP frame → permanently deferred
  (PROJECT.md v1.2 Out of Scope; no public iOS API).
- New gestures, MagnifyGesture changes, cell-level long-press changes
  (D-15 P10 untouched contract; ADR §How-it-composes).
- Banner copy string for Hard — Phase 8 ADR chose smaller-cells (not
  warning+compromise), so no banner copy ships in P11.

</domain>

<decisions>
## Implementation Decisions

### Layout architecture (Large vs Small zones)

- **D-01:** Large PiP zones (`.largeTop` / `.largeBottom`) swap to compact
  row layout. `MinesweeperHeaderBar`, `MinesweeperModePill`, and the
  existing nav-bar toolbar items hide. `VideoCompactControlRow` renders on
  the edge opposite the reserved band (compact row at bottom when band is
  top; row at top when band is bottom) per P10 SC2.

- **D-02:** Small PiP zones (`.smallTopLeft` / `.smallTopRight` /
  `.smallBottomLeft` / `.smallBottomRight`) keep existing layout (HeaderBar
  + Board + ModePill VStack). Only the nav-bar toolbar items are
  repositioned per `VideoModeSlotRouter.anchors(for:)` — no compact-row
  swap. Mirrors `VIDEO-MODE-LAYOUTS.md` §Minesweeper rows for Small zones
  ("Move Back/Settings out of TL/TR into the opposite corner or compact
  row" — Mines chooses the opposite-corner branch on Small).

- **D-03:** Extract chip subviews from `MinesweeperHeaderBar`:
  `MinesRemainingChip.swift` and `TimerChip.swift` sibling files in
  `Games/Minesweeper/`. Both `MinesweeperHeaderBar` (non-video + Small
  zones) and the compact row's stacked slot (Large zones, see D-06)
  reference the same subviews. Single source of truth for chip rendering,
  theming, and token usage.

- **D-04:** Wrap site = `MinesweeperGameView()` outermost layer. Concrete
  placement: the NavigationLink destination in `HomeView.swift` applies
  `.videoModeAware(minBoardHeight: 480)` to the freshly constructed
  `MinesweeperGameView`. Keeps `MinesweeperGameView` itself agnostic of
  the wrap, and matches P10 D-15 "wraps Mines at the outermost layer."

### Compact row slot order (Large zones)

- **D-05:** Mines compact-row slot order is **revised** to:
  ```
  Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart
  ```
  Restart is rightmost (most-tapped action under stress). Settings is 4th
  (difficulty change menu only — see D-08). This **supersedes** the plan-doc
  + `08-COMPACT-ROW-TOKENS.md` Mines slot row, which previously specified
  `Back | Flags/mines | Reveal/Flag picker | Time | Settings`. Plan-task to
  update those docs accordingly.

- **D-06:** Slot 2 renders a **vertical stack** subview: `MinesRemainingChip`
  on top, `TimerChip` below. Both subviews are the D-03 extractions, sized
  to fit the compact row's `theme.spacing.xl` height anchor (P9 D-13). Keeps
  both chips visible without consuming two slots.

- **D-07:** `VideoCompactControlRow` component **contract preserved** at 5
  slots per P9 D-12 — slot 2 just renders a stacked sub-view in Mines; the
  component itself does not change. Merge + Nonogram (P12) consume the
  same component with their own slot 2 content (Merge: Score chip;
  Nonogram: Lives/size chip — both single chips, no stack). No P9 D-12
  contract change.

- **D-08:** Settings slot (slot 4) opens the difficulty-change menu using
  the current `MinesweeperToolbarMenu` shape (Easy / Medium / Hard radio
  list). No global app Settings link in this slot — global Settings stays
  reachable from HomeView only. Keeps the slot scoped to in-flight game
  control.

### Nav-bar handling under Video Mode

- **D-09:** Nav-bar title "Minesweeper" stays visible whenever Video Mode is
  On. Nav-bar toolbar items (Back chevron, Restart icon, MinesweeperToolbarMenu)
  are hidden via `.toolbar(.hidden, for: .navigationBar)` **only on Large
  zones** (their roles migrate into the compact row per D-05). On Small
  zones, nav-bar items stay visible but their leading/trailing anchors are
  repositioned per `VideoModeSlotRouter.anchors(for:)`. On Large-top
  specifically, the title bar sits above the reserved band (system chrome
  → band → board → compact row).

### Hard cell-size floor (ADR consumption)

- **D-10:** `MinesweeperBoardView.Self.minCellSize` becomes Video-Mode-aware.
  Implementation pattern (per Phase 8 ADR §How-it-composes): the existing
  static helper `cellSize(forWidth:cols:padding:spacing:)` keeps its
  signature; a sibling `minCellSize(videoModeOn:)` static returns the v1.0
  `18` constant when off, the lowered Video-Mode floor when on. Helper
  call sites in `MinesweeperBoardView.body` thread `videoModeStore.isEnabled`
  through. The `MagnifyGesture` + `.scaleEffect` + cell-level
  `LongPressGesture(0.25).exclusively(before: TapGesture())` chain stays
  byte-identical (D-17, P10 D-15 untouched contract).

- **D-11:** **Exact Video-Mode floor value deferred to plan task.** Plan
  step: render Hard 16×30 at candidate floors (10pt / 11pt / 12pt / 13pt)
  on **Dracula + Voltage** presets; measure mine icon + 1–8 SF Symbol
  legibility per CLAUDE.md §8.12; lock the value before SC2 close.
  Working number per ADR: ~12pt. Locked constant lives as
  `static let minCellSizeVideoMode: CGFloat = <measured>` on
  `MinesweeperBoardView`, doc-commented with the audit screenshot
  reference. Rollback condition: if mis-tap rate increases on iPhone 17
  Pro Max or §8.12 regression, ADR §Rollback condition fires (switch to
  warning-compromise as v1.3 fallback).

- **D-12:** Floor gate is purely `videoModeStore.isEnabled` — no
  `location.isLarge` condition, no `difficulty == .hard` condition. Per
  ADR §How-it-composes verbatim. Easy + Medium boards auto-scale above
  the lowered floor (their `(usable - spacing) / cols` computed value
  exceeds the floor at iPhone 17 Pro Max width); only Hard hits the new
  floor on Large zones. One gate, smallest test surface.

### Manual verification recipe doc

- **D-13:** Doc lives at
  `.planning/phases/11-mines-adoption/11-VIDEO-MANUAL-CHECK.md`. Co-located
  with phase artifacts; mirrors the `07-CHECKLIST.md` pattern from Phase 7.

- **D-14:** Single matrix doc. **18 rows = 3 difficulties × 6 zones.**
  Columns: `Difficulty | Zone | First-tap | Reveal | Long-press flag |
  Restart | Win/Loss completes | Pass/Fail`. Hard rows additionally cite
  ADR screenshot refs (`mines-hard-classic-pip-large.png`,
  `mines-hard-dracula-pip-large.png`, and the 4-corner Dracula Small set)
  in a trailing notes column.

- **D-15:** **Living doc** — SC1 lands the empty matrix and fills Easy +
  Medium pass marks for all 6 zones. SC3 fills the Hard rows with final-
  render parity confirmation against the ADR screenshots (Large-top,
  Large-bottom, and at least one Small zone per SC3 wording). The same
  doc serves SC1 quick-check + SC3 Hard validation evidence — verifier
  reads one file end-to-end.

### Cross-cutting / deconfliction

- **D-16:** **A2 NavigationStack height carry-forward (P10 VERIFICATION).**
  Plan-task: wrap real `MinesweeperGameView` inside its actual
  NavigationStack with Video Mode On + Large-top selected; measure
  available board height. If insufficient (P10 A2 hypothesis fires), add
  the documented `safeAreaInsets.top` adjustment per
  `10-RESEARCH.md` Assumption A2. Empirical check — do NOT
  preemptively widen the inset.

- **D-17:** **P10 D-15 untouched contract preserved verbatim.**
  `MinesweeperBoardView` `MagnifyGesture` + `.scaleEffect(zoomScale)` +
  `clampZoomScale(_:)` `[0.8, 2.0]` range + cell-level
  `LongPressGesture(0.25).exclusively(before: TapGesture())` composition
  are byte-identical. The ONLY board-level change is the `minCellSize`
  Video-Mode-aware lookup (D-10). Pinch-zoom stays as user's manual fit.

### Compactness reaction (P10 D-12/D-13 consumption)

- **D-18:** `\.videoModeCompactness` env reactions for Mines under D-05
  slot order:
  - `.normal` → render all 5 slots as D-05.
  - `.collapsedSettings` (plan-doc step 4) → Settings slot (4) folds into
    a ⋯ overflow attached to the Restart slot. User taps Restart for the
    common case; long-presses (or taps the overflow indicator) to surface
    Change-difficulty. Single visible slot, two affordances.
  - `.reducedTime` (plan-doc step 5) → drop the `TimerChip` half of slot
    2's stacked sub-view. Slot 2 becomes a single `MinesRemainingChip`
    centered in the slot's height. Time chip returns when compactness
    relaxes back.

### Claude's Discretion

- Names of the extracted chip subviews — `MinesRemainingChip` /
  `TimerChip` are working names.
- Name of the lowered-floor static helper or property —
  `minCellSizeVideoMode` working name; alternatives
  (`minCellSize(videoModeOn:)` overload) are equivalent.
- Exact `theme.spacing.*` token used for the stacked-chip vertical gap
  inside slot 2 — planner picks (`xs` / `s` likely candidates).
- Whether the `.collapsedSettings` overflow on Restart uses
  `contextMenu(_:)` or a `Menu` with primary-action — planner picks based
  on SwiftUI ergonomics + a11y trait coverage.
- Exact value of the localizable strings for any compact-row a11y labels
  (likely none net-new — existing Mines toolbar labels reused).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner) MUST read these before planning.**

### Phase 11 scope source
- `.planning/ROADMAP.md` §"Phase 11: Minesweeper Adoption" — SC1–SC5 verbatim
- `.planning/REQUIREMENTS.md` VIDEO-07, VIDEO-08
- `.planning/PROJECT.md` §"Current Milestone: v1.2 Video Mode" — milestone
  framing + out-of-scope list
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` — milestone master plan;
  §Minesweeper (the squeeze + four candidate strategies), §"Compact control
  row" (slot order), §"Compromise order" (the 6 steps Mines reacts to per D-18)

### Locked design from Phase 8 (mandatory)
- `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` — smaller-cells
  variant (Variant 1) locked; §How-it-composes is the D-10/D-12 contract;
  §Rollback condition is the D-11 fallback
- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` —
  §Minesweeper Easy / Medium / Hard per-zone behavior tables (D-01/D-02
  source); plan-task updates the Mines slot rows per D-05
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — token
  anchors (radii.button / spacing.xl / spacing.s) + slot mapping for Mines;
  plan-task updates Mines slot row per D-05
- `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` — Phase 13
  consumer; P11 does NOT touch this surface (end-state overlay stays)
- `.planning/phases/08-video-mode-design/08-DESIGN-LOCK.md` — design lock
  artifact; confirms P11 inputs are stable

### Locked foundation from Phase 9 (mandatory)
- `.planning/phases/09-video-mode-foundation/09-CONTEXT.md` — D-05 store
  pattern, D-07 6-location enum, D-12 VideoCompactControlRow contract
  (P11 preserves), D-13 tokens (P11 consumes), D-14 component API
- `gamekit/gamekit/Core/VideoModeStore.swift` — `@Environment(\.videoModeStore)`
  read site; P11 reads `isEnabled` + `location`
- `gamekit/gamekit/Core/VideoModeLocation.swift` — 6-case enum; D-01/D-02
  branch on `.isLarge` (computed property if not present, added in plan)
- `gamekit/gamekit/Core/VideoCompactControlRow.swift` — P11 renders this
  on Large zones; slot 2 is the stacked-chip sub-view per D-06

### Locked primitives from Phase 10 (mandatory)
- `.planning/phases/10-layout-primitives/10-CONTEXT.md` — D-01 `.videoModeAware()`
  modifier (P11 call site), D-02 `VideoModeSlotRouter.anchors(for:)`
  (D-02 consumer), D-05 off-restore hard-short-circuit, D-12/D-13
  compactness env + 3 levels (D-18 consumer), D-14 `minBoardHeight: 480`
  (D-04 call), D-15 untouched contract (D-17 preserves)
- `.planning/phases/10-layout-primitives/10-VERIFICATION.md` — A2
  carry-forward (D-16 consumer), D-15 untouched contract restated,
  smaller-cells ADR reference
- `gamekit/gamekit/Core/VideoModeAware.swift` — modifier surface, off-path
  short-circuit, compactness env publication
- `gamekit/gamekit/Core/VideoModeSlotRouter.swift` — anchor table; D-02
  Small-zone consumer

### Hard validation screenshots (SC3)
- `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` —
  baseline squeeze, Classic
- `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png` —
  baseline squeeze, Dracula §8.12 audit
- `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-{tl,tr,bl,br}.png` —
  4-corner Dracula Small set (SC3 "at least one Small location")
- `Docs/screenshots/v1.2-design/home-classic-pip-large-{top,bottom}.png` —
  band geometry reference

### Minesweeper consumer files
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` — wrap site
  for the modifier (D-04); Large-zone branch hides HeaderBar + ModePill +
  toolbar; Small-zone branch keeps existing layout (D-01/D-02)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` —
  `Self.minCellSize` Video-Mode-aware seam (D-10); `MagnifyGesture`
  untouched (D-17)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` — chip
  extraction source (D-03)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperModePill.swift` — compact
  row picker-slot consumer (D-05 slot 3)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperToolbarMenu.swift` —
  Settings-slot consumer; D-08 reuses verbatim
- `gamekit/gamekit/Screens/HomeView.swift` — wrap call site for the
  modifier; `.videoModeAware(minBoardHeight: 480)` on the Mines
  NavigationLink destination (D-04)

### Cross-cutting rules
- `CLAUDE.md` §1 (Lightweight MVVM; SwiftData firewall preserved),
  §2 (DesignKit token discipline; no new tokens speculatively introduced),
  §8.4 (verify tokens exist), §8.5 (file-size cap — chip extractions help),
  §8.7 (Finder-dupe vigilance — new files in `Games/Minesweeper/`),
  §8.8 (synchronized root group auto-registration),
  §8.10 (commit discipline — chip extraction lands separately from
  Video-Mode wrap; floor change separate from layout swap),
  §8.12 (theme audit Classic + 1 Loud preset → SC4 mandate),
  §8.13 (status table updates if any user-facing fact changes),
  §8.14 (`Docs/releases/v1.2.md` appended with each significant change)

### Localization
- `gamekit/gamekit/Resources/Localizable.xcstrings` — likely zero net-new
  keys; existing Mines toolbar / chip labels reused. Plan-task confirms
  before closing SC1.

### Release log
- `Docs/releases/v1.2.md` (created when `MARKETING_VERSION` bumped to 1.2.x)
  — append Minesweeper-adoption entries per §8.14 / §0.3

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- **`VideoModeStore` env-injected** (Core/VideoModeStore.swift) — P11 reads
  `isEnabled` + `location` via `@Environment(\.videoModeStore)`; matches
  P9 D-05 / P10 D-04 pattern.
- **`VideoCompactControlRow`** (Core/VideoCompactControlRow.swift) — 5-slot
  component P9 shipped; D-07 preserves the contract, Mines fills slot 2
  with a stacked sub-view.
- **`VideoModeSlotRouter.anchors(for:)`** (Core/VideoModeSlotRouter.swift)
  — D-02 Small-zone consumer; exhaustive switch over `VideoModeLocation`.
- **`.videoModeAware(minBoardHeight:)`** (Core/VideoModeAware.swift) —
  D-04 wrap site; default `320pt` per P10 D-14, Mines passes `480pt`.
- **`MinesweeperToolbarMenu`** (Games/Minesweeper/MinesweeperToolbarMenu.swift)
  — D-08 Settings-slot consumer; reused verbatim, just relocated.
- **`MinesweeperModePill`** (Games/Minesweeper/MinesweeperModePill.swift)
  — D-05 Picker-slot consumer; reused verbatim in slot 3.
- **A11Y-05 / 06.1-03 `MagnifyGesture` + auto-scale `cellSize` helper** —
  D-17 untouched; only the floor parameter (D-10) becomes Video-Mode-aware.
- **`Localizable.xcstrings`** — Mines labels already cover the new slot
  positions; D-08/D-09 do not introduce net-new keys per plan-task review.

### Established patterns
- **`@Environment(\.videoModeStore)`** for store reads — every P9/P10
  surface uses this; D-01/D-02 follow.
- **Exhaustive switch over `VideoModeLocation`** — `.isLarge` boolean
  branch (computed prop if absent, added in plan) keeps Large/Small split
  compile-time-checked.
- **Static-helper `minCellSize` pattern** — A11Y-05 / 06.1-03 already
  threads a `CGFloat` floor through the auto-scale helper; D-10 just adds
  a Video-Mode-aware lookup at the call site.
- **Custom EnvironmentKey injection** at `GameKitApp.init()` — already
  done for `VideoModeStore` in P9; P11 reads only, no new injection.
- **File-size cap discipline (CLAUDE.md §8.5)** — `MinesweeperGameView.swift`
  is 401 lines; the D-01/D-02 layout branch is the boundary where it
  splits if it tips over. Plan-task watches for split.

### Integration points
- **Wrap call site (D-04)** — `Screens/HomeView.swift` Mines
  NavigationLink destination applies `.videoModeAware(minBoardHeight: 480)`.
- **Game view branch site (D-01/D-02)** — `MinesweeperGameView.body`
  reads `@Environment(\.videoModeStore)`; branches:
  ```
  if !store.isEnabled               → existing v1.0 layout
  else if store.location.isLarge    → compact-row layout (D-05/D-06/D-07)
  else                              → existing layout + repositioned toolbar (D-02)
  ```
- **Compact-row consumer site (D-05/D-06)** — Large-zone branch renders
  `VideoCompactControlRow { ... }` with slot 2 = stacked chip sub-view
  (D-03 extractions), slot 3 = `MinesweeperModePill`, slot 4 =
  `MinesweeperToolbarMenu`, slot 5 = Restart button.
- **Compactness consumer (D-18)** — Large-zone branch reads
  `@Environment(\.videoModeCompactness)` and adjusts: `.collapsedSettings`
  folds slot 4 into slot 5's overflow; `.reducedTime` drops the Time
  chip from slot 2's stack.
- **Hard cell-size seam (D-10)** — `MinesweeperBoardView.body` threads
  `store.isEnabled` to the `minCellSize` lookup; no other view touches
  this surface.
- **Slot-router consumer (D-02)** — Small-zone branch reads
  `VideoModeSlotRouter.anchors(for: store.location)` to position nav-bar
  Back/Restart/Menu items on the anti-PiP corner.
- **A2 NavigationStack inset (D-16)** — empirical plan-task; site is the
  `.videoModeAware()` modifier's `.safeAreaInset(.top)` call; only changes
  if measurement shows insufficient board height.

</code_context>

<specifics>
## Specific Ideas

- **Stacked chip in slot 2** is the resolution that lets Restart join the
  compact row without breaking the 5-slot contract — Mines on top, Time
  below, both subviews extracted from HeaderBar (D-03/D-06). The
  alternative (extending VideoCompactControlRow to 6 slots) would pull
  Merge + Nonogram into a contract change they don't need in P12.
- **Restart rightmost** matches the rest-state-of-hand for the most-tapped
  in-flight action; Back stays leftmost (cross-game convention); Picker
  stays center (thumb reach on iPhone 17 Pro Max).
- **`.reducedTime` drops the Time half of slot 2's stack** (not the whole
  slot) — keeps Mines remaining visible at the smallest compactness level;
  Mines remaining is more load-bearing than elapsed time during play.
- **D-11 cell-size audit pairs Dracula + Voltage** — Dracula is the §8.12
  canonical Loud preset; Voltage is the lightness contrast. Two Loud
  presets at the legibility floor catches more regressions than Dracula
  alone, at marginal extra cost (one extra preset toggle per candidate
  floor).
- **D-16 A2 check is empirical** — do NOT pre-add the `safeAreaInsets.top`
  adjustment speculatively. P10 VERIFICATION explicitly defers; P11
  measures first, adjusts only if needed.

</specifics>

<deferred>
## Deferred Ideas

- **End-state overlay redesign** → Phase 13. P11 ships existing
  full-screen overlay untouched (covers board including PiP zone). P13
  closes the milestone with a non-board-covering banner/pill.
- **Banner copy for Hard Video Mode** — ADR chose smaller-cells (not
  warning+compromise). No banner copy ships in P11. Held in reserve as
  the v1.3 fallback per ADR §Rollback condition.
- **Merge + Nonogram compact-row Restart** — Mines-specific in P11.
  Merge has no in-flight restart (relies on end-state card); Nonogram
  may want a Restart but that's a P12 decision against the same 5-slot
  contract.
- **Promote `MinesRemainingChip` + `TimerChip` to DesignKit** — CLAUDE.md
  §2 requires 2+ consumers; today they're Mines-only. Revisit if Nonogram
  reuses the chip shape in P12.
- **Promote stacked-chip-in-slot-2 pattern to VideoCompactControlRow API**
  — currently a Mines-specific ad-hoc sub-view. Revisit if Nonogram or
  future games adopt the same stack.
- **Auto-detection of another app's PiP frame** — PROJECT.md v1.2 Out of
  Scope; no public iOS API; permanently deferred.
- **Vertical / portrait PiP layouts and large-left / large-right zones** —
  PROJECT.md v1.2 Out of Scope; v1.3+ candidate.

</deferred>

---

*Phase: 11-mines-adoption*
*Context gathered: 2026-05-13*
