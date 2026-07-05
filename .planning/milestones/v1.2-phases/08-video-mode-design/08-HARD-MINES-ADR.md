# Phase 08 Hard-Mines ADR — Video Mode Strategy for Hard 16x30

## Status

**Accepted 2026-05-12.**

This ADR resolves CONTEXT D-13 — the only intentionally open decision in Phase 8.
This document **locks the Hard Minesweeper Video Mode strategy**. Phase 11 SC2
references this ADR by name and **MUST NOT re-debate** the rejected
alternatives.

Sister phases that consume this ADR:

- Phase 11 (Minesweeper Adoption) SC2 — implements the chosen variant exactly.
- Phase 11 (Minesweeper Adoption) SC3 — Hard validation re-uses the screenshots
  embedded below.
- ROADMAP §v1.2 Research Flags §Phase 11 — research is CONDITIONAL on the
  chosen variant (scroll-pan / pinch-zoom = research-flag fires; smaller-cells /
  warning+compromise = skip research, direct to planning).

## Context

The v1.2 Video Mode design must accommodate every game across all six PiP zones
from REQUIREMENTS VIDEO-02 (Large top, Large bottom, Small TL, Small TR, Small
BL, Small BR). Mines Easy (9x9) and Mines Medium (16x16) fit acceptably under
every zone with the Compromise order applied (see `VIDEO-MODE-LAYOUTS.md` Easy /
Medium sections).

**Mines Hard (16x30) does not.** With the v1.0 18pt cell-size floor (Plan
06.1-03 / A11Y-05) and a Large-top or Large-bottom PiP overlay applied, the
board cannot render fully between the reserved PiP band and the compact control
row on iPhone 17 Pro Max (the comfortable case per CONTEXT D-04). Evidence:

- `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` — Classic
  preset, Large-top PiP, baseline squeeze visible.
- `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png` — Dracula
  preset (CLAUDE.md §8.12 legibility audit), same squeeze.

The Small-PiP corners (TL / TR / BL / BR) on Hard are **not** affected — the
canonical 4-corner Dracula set proves Hard's 16x30 fits at current cell size
when PiP is small:

- `mines-hard-dracula-pip-small-tl.png`
- `mines-hard-dracula-pip-small-tr.png`
- `mines-hard-dracula-pip-small-bl.png`
- `mines-hard-dracula-pip-small-br.png`

The squeeze problem is therefore a **Large-PiP problem on Hard**, not a general
Hard problem. See `VIDEO-MODE-LAYOUTS.md` §"Minesweeper — Hard (16x30 / 99
mines)" for the per-zone behavior table and the explicit "Strategy decision
deferred" subsection pointing here.

Four candidate strategies were sketched (Plan 08-05 Task 1). This ADR records
all four with their pros/cons and screenshot evidence, then locks one.

## Candidates considered

### Candidate 1 — Smaller cells

- **Sketch:** [`hard-mines-smaller-cells.html`](../../sketches/08-video-mode-design/hard-mines-smaller-cells.html)
- **Screenshot baseline:** `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png` (Dracula §8.12 audit)

When Video Mode is on, the Hard board renders at a smaller cell size (e.g. 18pt
floor → 12pt floor) so the full 16x30 grid fits between the reserved PiP band
and the compact row. The existing auto-scale `cellSize` formula from Plan
06.1-03 re-runs against the lowered floor. No new gesture; pinch-zoom remains
available as the user-driven escape hatch.

**A11Y-05 / 06.1-03 interaction:** preserves the existing `MagnifyGesture` +
auto-scale `cellSize` system. The only change is one constant
(`minCellSize`) — gated on `videoModeStore.isOn` — feeding the existing pure
`cellSize(forWidth:cols:padding:spacing:)` static helper. Cell-level
`LongPressGesture(0.25).exclusively(before: TapGesture())` composition is
untouched.

**Pros**

- Full board visible — no new gesture for the user to learn.
- Auto-scale infrastructure from 06.1-03 already exists; this variant tweaks one constant.
- Lowest user-facing surface change — Hard plays identically, just smaller.
- Does NOT trigger Phase 11 research-flag per ROADMAP §v1.2 Research Flags.

**Cons**

- Cell taps approach a fat-finger floor (~12–13pt). Misfire risk on Hard's already-dense board.
- Legibility of cell numbers (1–8 SF Symbol) on Dracula at 12pt needs explicit audit (CLAUDE.md §8.12).
- Mines/flag icons may need a smaller SF Symbol variant or risk visual collision with adjacent cells.
- Tap-target accessibility tradeoff — pinch-zoom is the answer, but discoverability is still the user's burden.

### Candidate 2 — Scroll/pan

- **Sketch:** [`hard-mines-scroll-pan.html`](../../sketches/08-video-mode-design/hard-mines-scroll-pan.html)
- **Screenshot baseline:** `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png`

When Video Mode is on, the Hard board keeps its current 18pt cell size. The
board is wider/taller than the viewport; the user pans with a single-finger
drag past a movement threshold (e.g. 8pt) to see different regions. Below the
threshold, single-finger gestures reach the cell as today.

**A11Y-05 / 06.1-03 interaction:** highest deconfliction risk. The existing
`MagnifyGesture` is two-finger and composes cleanly with a new
single-finger pan via `.simultaneousGesture(...)`. The HIGH risk is that
cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())` is also
single-finger — drag-vs-tap classification by movement threshold is a vector
for regressing ROADMAP P3 SC1's 50-tap zero-misfire requirement.

**Pros**

- Cell size preserved — touch targets identical to v1.0 Hard play.
- Mines/flag icons render at the same size users already know.
- No legibility regression on any preset (CLAUDE.md §8.12 stays trivial).

**Cons**

- Highest deconfliction risk with the cell-level `.exclusively(before:)` chain.
- Adds a new gesture surface; **triggers Phase 11 research-flag** per ROADMAP §v1.2 Research Flags.
- User can lose track of where they are on a 16x30 board mid-game.
- Pan overshoot/decay may interfere with the cell-reveal cascade animation from Phase 5.

### Candidate 3 — Pinch-zoom (reuse A11Y-05)

- **Sketch:** [`hard-mines-pinch-zoom.html`](../../sketches/08-video-mode-design/hard-mines-pinch-zoom.html)
- **Screenshot baseline:** `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png`

When Video Mode is on (and Hard is the current difficulty), trigger a one-shot
animation: `withAnimation { zoomScale = clampZoomScale(fitScale) }` where
`fitScale` is computed from the available height below the PiP band. After the
auto-fit, the user manages zoom with the existing pinch-zoom system from Plan
06.1-03. Reduce Motion: auto-fit collapses to `.identity` (instant snap).

**A11Y-05 / 06.1-03 interaction:** lowest code surface — reuses the existing
`MagnifyGesture` + `clampZoomScale` + `.scaleEffect` layer verbatim. The only
new behavior is one `withAnimation` call on Video Mode entry. Cell-level
`.exclusively(before:)` is byte-identical.

**Pros**

- Lowest code surface — only an auto-fit trigger on Video Mode entry.
- Zero new gesture surface; reuses A11Y-05 verbatim.
- User already knows how to use pinch from non-Video-Mode play.

**Cons**

- Discoverability: without auto-fit, Hard + Large PiP renders unplayable at first glance.
- `fitScale` may need to clamp below the existing 0.8 floor — if so, the ScrollView fallback engages and the user sees a partial board until they pinch/scroll.
- Auto-fit animation on entry may collide with the cell reveal-cascade animation if the user re-enters Video Mode mid-game.
- **Triggers Phase 11 research-flag** per ROADMAP §v1.2 Research Flags (composition with cell gestures during the auto-fit animation needs a spike to verify).

### Candidate 4 — Warning + compromise

- **Sketch:** [`hard-mines-warning-compromise.html`](../../sketches/08-video-mode-design/hard-mines-warning-compromise.html)
- **Screenshot baseline (the warning surface):**
  `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png`
- **Screenshot evidence (the compromise target — PiP-small):**
  `mines-hard-dracula-pip-small-{tl,tr,bl,br}.png` (4-corner canonical set)

When Video Mode is on, Hard, and PiP is Large, the app shows a one-time pill
banner "Video Mode works best with small PiP on Hard." The compact row applies
the Compromise order steps 4–5 from the plan-doc (collapse Settings into
overflow ⋯ menu; hide time chip). The board keeps its current cell size; the
squeeze persists but is honestly acknowledged. The user is directed toward
PiP-small (which the 4-corner Dracula set proves is fully playable).

**A11Y-05 / 06.1-03 interaction:** zero deconfliction risk. The existing
`MagnifyGesture` + auto-scale `cellSize` system is untouched. Pinch remains
available as a user-driven escape hatch if the user keeps PiP-large. No new
gesture; no layout-engine change. Only one banner view + one Compromise-order
branch.

**Pros**

- Zero gesture or layout-engine changes — lowest engineering risk.
- Cell size + touch targets identical to v1.0 Hard play — zero legibility regression.
- Existing A11Y-05 still available as escape hatch.
- Ships in a single Phase 11 plan with no research-flag spike. Does NOT trigger Phase 11 research-flag per ROADMAP §v1.2 Research Flags.

**Cons**

- Concedes that Hard + Large PiP isn't a great experience — relies on user heeding the banner.
- Adds one localized copy string; copy review needed.
- If user ignores the banner AND doesn't pinch, the bottom-row squeeze persists for the whole game.
- Banner display rules need precise wording (once per session vs forever vs every Hard+Large entry) — Phase 11 locks this.

## Decision

**Chosen: smaller-cells (Variant 1).**

Smaller-cells preserves the full 16x30 board without introducing a new gesture,
deconflicts cleanly with A11Y-05 / 06.1-03 (the existing `MagnifyGesture` stays
untouched — pinch still works as the user's manual fit), and does NOT trigger
the Phase 11 research-flag per ROADMAP §v1.2 Research Flags. The variant reuses
the auto-scale infrastructure shipped in 06.1-03: only a single `minCellSize`
constant changes (gated on `videoModeStore.isOn`), feeding the existing pure
`cellSize(forWidth:cols:padding:spacing:)` static helper. Trade-off accepted:
cell-size reduction approaches the fat-finger floor (~12pt) on Hard's already-
dense board — mitigated by keeping A11Y-05 pinch-zoom as the user-controlled
escape hatch and by the §8.12 Dracula legibility audit that Phase 11 SC4 will
run on the produced cell size. Phase 11 implements EXACTLY this variant and
does NOT re-debate the rejected alternatives.

## Rejected alternatives

Each rejected variant retains its full Pros/Cons inline above (§Candidates
considered). The screenshot evidence for each is `mines-hard-classic-pip-large.png`
and `mines-hard-dracula-pip-large.png` (the baseline squeeze the rejected
variant attempted to solve); the §8.12 Dracula screenshot is the load-bearing
piece per CONTEXT D-13 that the chosen approach must survive.

### Rejected: scroll-pan (Variant 2)

- **Sketch:** [`hard-mines-scroll-pan.html`](../../sketches/08-video-mode-design/hard-mines-scroll-pan.html)
- **Screenshot evidence:** `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png` (baseline squeeze)

**Rejected because:** highest deconfliction risk with the cell-level
`LongPressGesture(0.25).exclusively(before: TapGesture())` chain locked in
ROADMAP P3 SC1 — a single-finger pan introduces a drag-vs-tap classification
problem that puts the 50-tap zero-misfire requirement at risk. It also
**triggers the Phase 11 research-flag** per ROADMAP §v1.2 Research Flags
(extra spike before code), while smaller-cells avoids that gate entirely.

### Rejected: pinch-zoom (Variant 3)

- **Sketch:** [`hard-mines-pinch-zoom.html`](../../sketches/08-video-mode-design/hard-mines-pinch-zoom.html)
- **Screenshot evidence:** `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png` (baseline squeeze)

**Rejected because:** discoverability failure mode is severe — without
auto-fit, Hard + Large PiP renders unplayable at first glance and the user
must guess that pinch is the answer. The auto-fit `withAnimation` trigger
may also collide with the in-flight cell reveal-cascade from Phase 5
(MINES-08), and it **triggers the Phase 11 research-flag** for that exact
composition risk. Smaller-cells preserves the same A11Y-05 pinch surface as
a manual escape hatch without making auto-fit the load-bearing path.

### Rejected: warning-compromise (Variant 4)

- **Sketch:** [`hard-mines-warning-compromise.html`](../../sketches/08-video-mode-design/hard-mines-warning-compromise.html)
- **Screenshot evidence (the warning surface):**
  `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
  `mines-hard-dracula-pip-large.png`
- **Screenshot evidence (the compromise target — PiP-small):**
  `mines-hard-dracula-pip-small-{tl,tr,bl,br}.png` (4-corner canonical set)

**Rejected because:** concedes that Hard + Large PiP isn't a great
experience — the variant ships a "this is hard, please change PiP" pill
rather than a working Hard + Large PiP layout. Held in reserve as the v1.3
rollback target (see §Rollback condition) because its evidence base (the
4-corner Dracula PiP-small set) is already documented and it requires zero
gesture or layout-engine change to ship.

## Interaction with A11Y-05 / 06.1-03 MagnifyGesture + auto-scale system

This section is **required** per CONTEXT D-13 and is the deconfliction contract
that Phase 11 implements against.

**What the existing system does (Plan 06.1-03 / A11Y-05):**

- An auto-scale `cellSize` static helper (`MinesweeperBoardView.cellSize(forWidth:cols:padding:spacing:)`) computes per-cell side length from container width, clamped to an `18pt` floor (`Self.minCellSize`).
- A `MagnifyGesture` (NOT the deprecated `MagnificationGesture`) is applied to the ScrollView via `.simultaneousGesture(...)`. It composes with cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())` without competing — single-finger gestures hit the child by default child-priority; two-finger pinch hits the parent simultaneously.
- A dual-state pattern (`zoomScale` + `baseZoomScale`) is committed via `clampZoomScale(_:)` clamped to `[0.8, 2.0]`. State persists across `vm.restart()` within a session; resets on cold launch.
- A `.scaleEffect(zoomScale, anchor: .center)` is applied to the `LazyVGrid` (not the ScrollView) so the ScrollView's clipping frame stays stable during zoom.
- A horizontal ScrollView fallback (via `scrollAxis(for:)` helper) engages on sub-floor cases (e.g. iPhone SE 320pt on Hard).

**How the chosen variant composes with it:**

Smaller-cells **adds NO new gesture**. The cell-level
`LongPressGesture(0.25).exclusively(before: TapGesture())` composition in
`MinesweeperCellView` remains byte-identical. The board-level `MagnifyGesture`
applied via `.simultaneousGesture(...)` on the ScrollView in `MinesweeperBoardView`
remains byte-identical. The `.scaleEffect(zoomScale, anchor: .center)` layer
on the `LazyVGrid` remains byte-identical, as does the `zoomScale` /
`baseZoomScale` dual-state pattern and the `[0.8, 2.0]` `clampZoomScale(_:)`
range.

The ONLY change to the 06.1-03 system: when `videoModeStore.isOn == true`,
the auto-scale `cellSize(forWidth:cols:padding:spacing:)` static helper is
re-invoked with a lower `minCellSize` floor (the v1.0 constant of `18` becomes
a smaller Video-Mode-aware constant — exact value locked by Phase 11 SC2
after the §8.12 Dracula legibility audit; the working number is ~12pt). The
helper signature is unchanged; the existing helper call site in
`MinesweeperBoardView.body` is unchanged; only the `Self.minCellSize`
reference becomes a Video-Mode-aware lookup (e.g. a
`Self.minCellSize(videoModeOn:)` overload or an environment-conditional
constant). Pinch-zoom remains the user-controlled escape hatch when the
reduced cell size still feels too dense, and the existing fallback to
horizontal ScrollView (`scrollAxis(for:)`) still engages on sub-floor cases
on smaller devices.

No `MinesweeperCellView` modifications. No new gesture surface. No
`.exclusively(before:)` chain modifications. Phase 11 SC5 (VIDEO-13 byte-
identical off-path check) is satisfied trivially because the Video-Mode-aware
`minCellSize` lookup returns the v1.0 `18` constant verbatim when
`videoModeStore.isOn == false`.

## Rollback condition

If Phase 11 ships smaller-cells and the reduced cell-size triggers a measurable
mis-tap rate increase on iPhone 17 Pro Max or a §8.12 Dracula legibility
regression during Phase 11 verification or TestFlight feedback, **rollback**
this ADR and switch to warning-compromise (Variant 4) as the v1.3 fallback —
that variant requires no gesture or layout change and the 4-corner Dracula
PiP-small set is already documented as its evidence base.

## Consumed by

- **Phase 11 SC2 (Minesweeper Adoption)** — implements chosen variant exactly. Alternatives are NOT re-debated.
- **Phase 11 SC3 (Hard validation)** — re-uses the screenshots embedded above (`mines-hard-classic-pip-large.png`, `mines-hard-dracula-pip-large.png`, plus the 4-corner Dracula set if PiP-small testing applies).
- **ROADMAP §v1.2 Research Flags §Phase 11** — **does NOT trigger Phase 11 research-phase per ROADMAP §v1.2 Research Flags; Phase 11 proceeds direct to planning.** The chosen variant (smaller-cells) is one of the two ROADMAP-named "skip research" outcomes; the research-flag explicitly does NOT fire for this ADR.

Phase 11 SC2 implements smaller-cells per this ADR; alternatives are NOT re-debated.

## Source decisions

- **CONTEXT D-13** — Hard Minesweeper strategy intentionally deferred to design execution; ADR is the resolution surface.
- **This ADR's own decision** — locks the chosen variant; downstream phases reference by name.
- Plan 06.1-03 / A11Y-05 — defines the existing `MagnifyGesture` + auto-scale `cellSize` system that the chosen variant must compose with.
- `VIDEO-MODE-LAYOUTS.md` §"Minesweeper — Hard" — the per-zone behavior table that points here.
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Minesweeper "Possible directions to explore" — the source list of the four candidate strategies.
