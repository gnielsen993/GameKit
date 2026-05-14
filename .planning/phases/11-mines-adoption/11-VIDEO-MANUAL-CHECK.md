---
phase: 11-mines-adoption
type: video-manual-check
canonical: true
status: pending           # pending | in_progress | complete | blocked
signed_off_by: ""
signed_off_date: ""
---

# Phase 11 — Minesweeper Video Mode Manual Verification

**Authored:** 2026-05-13 (Plan 11-07)
**Filled in by:** Plan 11-08 (SC1 + SC3 sweep)
**Mirrors:** `.planning/phases/07-release/07-CHECKLIST.md` per CONTEXT D-13

## Purpose

This is the single verifier-reads-end-to-end doc for Phase 11 SC1 and SC3
per `.planning/ROADMAP.md` §"Phase 11: Minesweeper Adoption":

- **SC1:** Easy (9×9/10) + Medium (16×16/40) playable across all 6 PiP
  locations — first-tap, reveal, long-press flag, restart, win, loss all
  complete; manual recipe doc per-location quick-check.
- **SC3:** Hard (16×30/99) validated against ADR screenshots — final
  render parity for Large-top, Large-bottom, and at least one Small
  location.

Per CONTEXT D-14, the matrix has 18 rows = 3 difficulties × 6 PiP zones.
Per CONTEXT D-15, this is a living doc: SC1 fills Easy + Medium rows;
SC3 fills Hard rows with final-render parity confirmations against the
ADR screenshot pair. Plan 11-08 closes both SC1 and SC3 by completing
the matrix.

## How to use

For each row:

1. Launch the app on iPhone 17 Pro Max simulator.
2. Settings → Video Mode → On.
3. Settings → Video location → select the row's `Zone`.
4. Home → Minesweeper → switch to the row's `Difficulty` via the
   in-game Settings menu (compact row's slot 4 on Large zones; nav-bar
   toolbar on Small zones).
5. Run each gesture column:
   - **First-tap** — tap any cell; confirm the cell reveals + the timer
     starts; confirm no first-tap mine loss (Phase 2 MINES-03 invariant
     preserved).
   - **Reveal** — tap an unrevealed non-flagged cell; confirm reveal
     cascade animates (or static end state if Reduce Motion is on).
   - **Long-press flag** — long-press an unrevealed cell for 0.25s;
     confirm a flag appears + the mines-remaining chip decrements.
   - **Restart** — tap Restart (compact-row slot 5 on Large, toolbar
     icon on Small); confirm a fresh board appears.
   - **Win/Loss completes** — play to terminal state OR force a loss
     by tapping a known mine (or use the DEBUG seed if available);
     confirm the end-state overlay appears.
6. Mark Pass/Fail per row. Add notes for any deviation from baseline.

For Hard rows (13-18), additionally compare the rendered Hard board
against the Phase 8 ADR screenshot listed in the Notes column —
final-render parity is the SC3 acceptance condition. Plan 11-05 locked
the Video-Mode cell-size floor at **12pt** (audit passed on Dracula +
Voltage); each Hard row's render is validated against that floor.

## Matrix

| # | Difficulty | Zone | First-tap | Reveal | Long-press flag | Restart | Win/Loss completes | Pass/Fail | Notes |
|---|------------|------|-----------|--------|-----------------|---------|--------------------|-----------|-------|
| 1 | Easy | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 2 | Easy | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 3 | Easy | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 4 | Easy | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 5 | Easy | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 6 | Easy | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 7 | Medium | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 8 | Medium | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 9 | Medium | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 10 | Medium | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 11 | Medium | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 12 | Medium | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 13 | Hard | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05, audit passed 2026-05-13 on Dracula + Voltage). ADR ref: `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png`, `mines-hard-dracula-pip-large.png`. |
| 14 | Hard | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05 audit). ADR ref: same as row 13 (Large-top + Large-bottom share the Phase 8 squeeze pair). |
| 15 | Hard | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05 audit). ADR ref: `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-tl.png`. |
| 16 | Hard | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05 audit). ADR ref: `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-tr.png`. |
| 17 | Hard | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05 audit). ADR ref: `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-bl.png`. |
| 18 | Hard | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | Locked floor: 12pt (Plan 11-05 audit). ADR ref: `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-br.png`. |

## Sign-off

| Criterion                                                       | Verifier | Date  | Status          |
|-----------------------------------------------------------------|----------|-------|-----------------|
| SC1 — Easy/Medium pass marks all 6 zones (rows 1-12)            | _____    | _____ | ☐ PASS / ☐ FAIL |
| SC3 — Hard final-render parity vs ADR screenshots (rows 13-18)  | _____    | _____ | ☐ PASS / ☐ FAIL |

**Status (top-level):** ☐ PASS / ☐ FAIL / ☐ DEFERRED
**Verifier:** _______________
**Date:** ___________

## References

### Locked design (mandatory upstream reads)

- `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` — smaller-cells variant (Variant 1), Accepted 2026-05-12. §How-it-composes is the D-10 contract Plan 11-05 implements.
- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — §Minesweeper Easy / Medium / Hard per-zone behavior tables.
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — Mines slot row (revised 2026-05-13 per 11-CONTEXT D-05).
- `.planning/phases/11-mines-adoption/11-CONTEXT.md` — D-01 through D-18 source decisions for this phase.
- `.planning/phases/11-mines-adoption/11-05-SUMMARY.md` — locked `minCellSizeVideoMode = 12pt` (audit 2026-05-13 on Dracula + Voltage, ADR §Rollback did NOT fire). Hard rows 13-18 validate against this floor.

### Screenshot evidence

- `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` — baseline squeeze, Classic.
- `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png` — baseline squeeze, Dracula §8.12 audit.
- `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-small-{tl,tr,bl,br}.png` — 4-corner Dracula Small set.

### Cross-cutting

- `CLAUDE.md` §8.12 — theme legibility audit (Classic + one Loud preset).
- `.planning/ROADMAP.md` §"Phase 11: Minesweeper Adoption" — SC1 + SC3 source.
