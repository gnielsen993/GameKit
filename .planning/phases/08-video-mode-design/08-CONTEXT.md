# Phase 8: Video Mode Design - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Lock the v1.2 Video Mode design against real screenshots before any production
code ships. Produces four artifacts that Phases 9–13 consume by name:

1. Screenshot-annotated layout doc — all 6 PiP zones overlaid on Mines
   (Easy / Medium / Hard), Merge, and Nonogram.
2. Hard Minesweeper strategy ADR — smaller cells / scroll-pan / pinch-zoom /
   warning+compromise. Referenced by name in Phase 11.
3. Compact control row design tokens — pill sizing, hit targets, spacing
   anchors (no hardcoded values).
4. Non-board-covering win/loss banner placement sketch — per-PiP-zone rule
   + primary action affordance + a11y gating.

Design-only phase. No production app code in the `gamekit` target
(throwaway HTML / SwiftUI Preview sketches OK in `.planning/sketches/`).
Phase exits on Gabe's "design locked" sign-off; Phase 9 cannot begin first.

</domain>

<decisions>
## Implementation Decisions

### Design Medium & Screenshot Source
- **D-01:** Design medium for all Phase 8 sketches = **HTML throwaways via
  `/gsd-sketch`**. Multi-variant exploration baked in; lives under
  `.planning/sketches/`. Does NOT ship in `gamekit` target (Phase 8 SC5).
- **D-02:** Screenshots **captured fresh** in the simulator at start of
  the design phase. The existing `Docs/screenshots/asc/` set is App Store
  marketing material — partial coverage (has Hard / Merge / Mines win+loss,
  missing Easy / Medium / Nonogram and 6-corner annotations).
- **D-03:** Screenshot preset coverage = **Classic + Dracula (one Loud)**.
  Mirrors the CLAUDE.md §8.12 legibility-audit rule that every game-screen
  phase enforces. Catches banner / picker contrast bugs before Phase 9 code.
- **D-04:** Screenshot device coverage = **iPhone 17 Pro Max only** for
  v1.2 design lock. Pro Max represents the comfortable case; the Hard-Mines
  squeeze gradient is exposed by the difficulty itself, not the device size.
  (Smaller-device validation deferred to Phase 11 manual recipe.)

### Compact Control Row Tokens
- **D-05:** Picker pill corner radius = **`theme.radii.button`**. Matches the
  existing Reveal/Flag FAB (06.1-02), reads as primary in the row, distinct
  from info chips (which use `radii.chip`). Do NOT introduce a new `radii.pill`
  anchor — promote to DesignKit only when a second consumer appears
  (CLAUDE.md §2).
- **D-06:** Picker pill height token anchor = **`theme.spacing.xl`**.
  Sits between info-chip height (`spacing.l`) and full DKButton height —
  satisfies the plan-doc rule "smaller than the current full picker, slightly
  more prominent than info chips" without hardcoded points.
- **D-07:** Compact-row inter-item spacing = **`theme.spacing.s`**. Compact
  enough for Hard-board layouts (where the row competes with the board for
  vertical real estate) while staying above fat-finger risk on adjacent
  controls. Matches the existing `MinesweeperHeaderBar` gap.
- **D-08:** Per-game slot mapping = **plan-doc verbatim**, with each label
  read from existing game state (no new state plumbing in design phase):
    - Minesweeper: `Back | Flags/mines | Reveal/Flag picker | Time | Settings`
    - Merge:       `Back | Score | Mode picker | Best/time | Settings`
    - Nonogram:    `Back | Lives/size | Fill/Mark picker | Time | Settings`
  Sudoku slot mapping intentionally NOT spec'd — game not built (REQUIREMENTS
  §v1.2 Out of Scope).

### Win/Loss Banner Placement
- **D-09:** Banner anchor rule = **opposite-of-PiP**. Deterministic mapping:
    - Large top    → banner docks bottom edge
    - Large bottom → banner docks top edge
    - Small TL     → banner docks bottom-right
    - Small TR     → banner docks bottom-left
    - Small BL     → banner docks top-right
    - Small BR     → banner docks top-left
  One rule, six outcomes — easy to document, easy to verify by visual diff.
- **D-10:** Banner shape = **pill, full-width-minus-margins** along its anchor
  edge. Small vertical footprint keeps the board fully visible (the rule that
  defines Video Mode). Reads as chrome, not as a modal.
- **D-11:** Primary action surface = **explicit DKButton inside the banner**
  ("Play Again" / "Continue"). Visible affordance, VoiceOver-friendly,
  one-tap reachable from the moment the banner appears. NEVER a tap-banner-
  to-reveal-action pattern (VIDEO-11 SC2 forbids it).
- **D-12:** Reduce-Motion handling for banner motion = **dampen to identity**.
  Mirrors v1.0 05-06 D-04 surface-level lock — `.identity` transition,
  `.symbolEffect` value=0, `.keyframeAnimator` trigger=false when
  `accessibilityReduceMotion == true`. Static banner appears; no confetti,
  no sweep, no spring. Stronger than "reduce intensity"; matches plan-doc
  phrase "dampened to near-zero".

### Open — Resolved During Design Execution
- **D-13:** **Hard Minesweeper strategy is NOT pre-decided here**. The user
  intentionally declined to choose from {smaller cells / scroll-pan / pinch-
  zoom / warning+compromise} during discussion. Decision lands during sketch
  work (D-01 HTML throwaways), is recorded in `08-HARD-MINES-ADR.md` at
  phase exit, and is referenced by name from Phase 11 Success Criteria. The
  ADR MUST include: chosen approach, rejected-alternatives screenshot
  evidence, one-sentence rollback condition, interaction note with the
  existing A11Y-05 pinch-zoom + auto-scale system (06.1-03 SUMMARY).

### Claude's Discretion
- Sketch HTML structure / styling within `.planning/sketches/` is unconstrained
  beyond the rule that final tokens must be valid DesignKit anchors.
- Number of sketch variants per artifact — explore as many as needed to
  earn the design lock; expect 2–4 variants for Hard Mines specifically.
- Filename convention inside `.planning/sketches/08-video-mode-design/`.

### Folded Todos
None — `gsd-sdk query todo.match-phase 8` returned zero matches.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 source-of-truth
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` — full v1.2 product/UX plan;
  Phase 8 SC1–SC5 derive directly from §Design phase required, §Core rule,
  §Compact control row, §Compromise order, §Win/loss screens.
- `.planning/ROADMAP.md` §Phase 8 — phase definition, SC1–SC5 verbatim,
  dependency on v1.0 Phase 6.1.
- `.planning/REQUIREMENTS.md` §v1.2 Requirements — VIDEO-01..14 + §Out of
  Scope (Phase 8 itself has no VIDEO-* mapping; it is the design gate).
- `.planning/PROJECT.md` §Key Decisions — manual-selection-only,
  control-aware-vs-board-aware split, shared compact row, banner replaces
  full-screen end overlays.

### Cross-cutting invariants
- `CLAUDE.md` §1 — DesignKit token discipline (no hardcoded colors / radii /
  spacing). Applies to every token referenced in D-05..D-08.
- `CLAUDE.md` §0.1 — Chrome Diner restomod policy: Classic preset is the
  default baseline; per-context overrides deferred until first felt-table
  game (does not apply to v1.2).
- `CLAUDE.md` §8.12 — game-screen change verified on Classic + one Loud
  preset (Dracula / Voltage). D-03 follows this rule for design artifacts.
- `CLAUDE.md` §2 — DesignKit promotion rule: don't add a new token anchor
  until a second consumer appears. Applies to D-05 (no new `radii.pill`).

### Pattern parents (reuse, don't re-derive)
- `.planning/phases/05-polish/05-CONTEXT.md` + plans 05-03 / 05-06 — the
  haptics/SFX/Reduce-Motion gating pattern the banner inherits in D-12
  (and that Phase 13 will consume). v1.0 05-03 D-10 contract:
  `settingsStore.hapticsEnabled` is the FIRST guard inside any
  haptic-firing surface.
- `.planning/phases/06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode/06.1-CONTEXT.md`
  + 06.1-02 + 06.1-03 — Reveal/Flag FAB (radii.button anchor referenced
  by D-05) and the auto-scale cellSize + MagnifyGesture system that
  the Hard-Mines strategy ADR (D-13) MUST deconflict with.

### Sister-phase context (read before Phase 9 planning)
- `.planning/phases/04-stats-persistence/04-CONTEXT.md` + 04-04 — the
  SettingsStore @Observable + EnvironmentKey pattern Phase 9's
  `VideoModeStore` mirrors (per ROADMAP §Phase 9 SC2).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **DKButton** (DesignKit) — banner primary-action surface (D-11) uses this
  directly; do NOT roll a new button for the banner.
- **`MinesweeperHeaderBar`** (`Games/Minesweeper/`) — slot-ordering reference
  for D-08 Mines mapping; row spacing `theme.spacing.s` matches D-07.
- **Reveal/Flag FAB** (06.1-02 PLAN) — `theme.radii.button` consumer; D-05
  picker pill matches this anchor for consistency.
- **`MinesweeperPhase` + `.phaseAnimator` / `.keyframeAnimator` pattern**
  (05-06 PLAN) — banner motion in D-12 reuses the exact gating pattern
  (`.identity` transition / `.symbolEffect` value=0 / trigger=false on
  Reduce Motion).
- **`Haptics.swift` + `SFXPlayer.swift`** (`Core/`, 05-03 PLAN) — banner
  haptics/SFX in Phase 13 fire through these surfaces; `hapticsEnabled` /
  `sfxEnabled` are the first guards inside each.
- **Auto-scale cellSize + `MagnifyGesture`** (06.1-03 PLAN) — interaction
  surface the Phase 11 Hard-Mines ADR (D-13) MUST deconflict with.

### Established Patterns
- **@Observable store + custom EnvironmentKey** (04-04 SettingsStore,
  06-04 AuthStore, 06-05 CloudSyncStatusObserver) — Phase 9 `VideoModeStore`
  inherits this shape. Phase 8 only needs to confirm the design implies it;
  Phase 9 builds it.
- **Slot-ordered header row** (`MinesweeperHeaderBar` v1.0, Merge + Nonogram
  v1.1) — compact-control-row in Video Mode is a stricter variant of this
  pattern (compact pill picker + chip info + Back/Settings anchors).
- **Surface-level animation gating** (05-06 D-04) — every motion surface
  carries its own `accessibilityReduceMotion` guard at the `.transition` /
  `.symbolEffect` / `.keyframeAnimator` level. Banner in D-12 follows.

### Integration Points
- Phase 8 outputs feed Phase 9 (VideoModeStore + Settings UI + shared
  compact row component) and Phase 13 (banner implementation). Phase 11
  references the Hard-Mines ADR (D-13) directly.
- No app-code integration in Phase 8 itself — design artifacts live in
  `.planning/phases/08-video-mode-design/` and `.planning/sketches/`.

</code_context>

<specifics>
## Specific Ideas

- Banner anchor rule (D-09) is a finite 6-row table. Spec the table itself
  in the layout doc; downstream agents read the table, not derived logic.
- Hard-Mines ADR (D-13) MUST include screenshot evidence of the rejected
  alternatives — not just prose. The screenshots ARE the rationale.
- Sketch variants for Hard Mines should test on Pro Max + manually verify
  against the smallest iPhone width during the design pass (even though
  D-04 caps screenshot capture to Pro Max only — manual verification is
  cheap and the Hard squeeze is real).

</specifics>

<deferred>
## Deferred Ideas

These came up in research / plan-doc but are intentionally NOT in Phase 8:

- **PiP-location persistence: global vs per-game** — Plan doc §Open
  questions calls this out. REQUIREMENTS VIDEO-03 implies global ("shared
  store, observable by every game screen"). Phase 9 plan will lock this;
  Phase 8 design phase does not need it.
- **Small-PiP corner-aware vs simpler top/bottom-only mode** — Plan doc
  §Open questions. v1.2 ships corner-aware per VIDEO-02 (6 zones); the
  "simpler mode" alternative is a v1.3+ option only if real usage shows
  the corner zones confuse users.
- **Vertical / portrait PiP tracking** — Explicit Out of Scope per
  REQUIREMENTS §v1.2 + ROADMAP §v1.2 Out-of-Scope Reminder.
- **Sudoku Video Mode slot mapping** — Game not built; deferred.
- **Per-game compact-picker variants** — REQUIREMENTS VIDEO-04 locks
  "shared compact control row component". Per-game variants forbidden.
- **`radii.pill` DesignKit token** — Don't add until 2+ consumers (CLAUDE.md
  §2). v1.2 uses `radii.button` (D-05).
- **Auto-detect of another app's PiP frame** — No public iOS API; permanent
  defer per PROJECT.md Key Decisions + ROADMAP §v1.2 Out-of-Scope.

### Reviewed Todos (not folded)
None — zero matches from `gsd-sdk query todo.match-phase 8`.

</deferred>

---

*Phase: 08-video-mode-design*
*Context gathered: 2026-05-12*
