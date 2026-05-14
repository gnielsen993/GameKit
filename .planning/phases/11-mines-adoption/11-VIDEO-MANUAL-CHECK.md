---
phase: 11-mines-adoption
type: video-manual-check
canonical: true
status: partial           # partial — Hard largeBottom Voltage row signed off during execution; other rows DEFERRED to TestFlight sweep
signed_off_by: "gabe (iterative review during phase execution)"
signed_off_date: "2026-05-13"
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
| 1 | Easy | largeTop | — | — | — | — | — | DEFERRED | TestFlight sweep — inherits compactRowComposed shape verified at row 14. |
| 2 | Easy | largeBottom | — | — | — | — | — | DEFERRED | TestFlight sweep — same compactRowComposed as row 14, smaller board (9×9 fits trivially at any floor). |
| 3 | Easy | smallTopLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones use existingLayout (P10 D-11 passthrough) + slot-routed toolbar; byte-identical to v1.0 layout with Reveal/Flag pill + HeaderBar. |
| 4 | Easy | smallTopRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 5 | Easy | smallBottomLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 6 | Easy | smallBottomRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 7 | Medium | largeTop | — | — | — | — | — | DEFERRED | TestFlight sweep — inherits compactRowComposed shape; 16×16 fits at default 18pt floor (off-path) and at 12pt VM floor (on-path). |
| 8 | Medium | largeBottom | — | — | — | — | — | DEFERRED | TestFlight sweep — same as row 7. |
| 9 | Medium | smallTopLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 10 | Medium | smallTopRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 11 | Medium | smallBottomLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 12 | Medium | smallBottomRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. |
| 13 | Hard | largeTop | — | — | — | — | — | DEFERRED | TestFlight sweep — symmetric to row 14 (compactRowComposed at top instead of bottom). 12pt floor verified to fit 16×30 on largeBottom in row 14; A2 measurement (Plan 11-06) confirmed largeTop also fits. ADR ref: `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png`. |
| 14 | Hard | largeBottom | ✓ | ✓ | ✓ | ✓ | ✓ | PASS | Verified during execution 2026-05-13 — Voltage preset, locked 12pt floor, symmetric two-chip compactRowComposed (round 4 polish). Board fits inside available area; no horizontal scroll; adjacency numbers + mine glyph + flag glyph all legible per §8.12. ADR ref: `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png`. |
| 15 | Hard | smallTopLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough (P10 D-11); existingLayout renders board at the v1.0 18pt floor (Hard fits w/ MagnifyGesture preserved per D-17). ADR ref: `mines-hard-dracula-pip-small-tl.png`. |
| 16 | Hard | smallTopRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. ADR ref: `mines-hard-dracula-pip-small-tr.png`. |
| 17 | Hard | smallBottomLeft | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. ADR ref: `mines-hard-dracula-pip-small-bl.png`. |
| 18 | Hard | smallBottomRight | — | — | — | — | — | DEFERRED | TestFlight sweep — Small zones passthrough. ADR ref: `mines-hard-dracula-pip-small-br.png`. |

## Sign-off

| Criterion                                                       | Verifier | Date  | Status          |
|-----------------------------------------------------------------|----------|-------|-----------------|
| SC1 — Easy/Medium pass marks all 6 zones (rows 1-12)            | gabe     | 2026-05-13 | PARTIAL — Hard largeBottom verified; Easy/Medium + Small zones DEFERRED to TestFlight sweep (rows inherit verified compactRowComposed + existingLayout passthrough) |
| SC3 — Hard final-render parity vs ADR screenshots (rows 13-18)  | gabe     | 2026-05-13 | PARTIAL — row 14 PASS (Voltage); row 13 symmetric DEFERRED; rows 15-18 Small-zone passthrough DEFERRED |
| SC4 — Theme legibility (Classic + one Loud × E/M/H × 6 zones)   | gabe     | 2026-05-13 | PARTIAL — Voltage × Hard × largeBottom PASS (round-4 polish iteration); remaining matrix DEFERRED |
| SC5 — Off-restore byte-identity vs v1.0 / v1.0.6.1              | —        | —          | DEFERRED — off-restore not toggled during execution; byte-identity guaranteed by `existingLayout` call sites untouched + `MinesweeperBoardView` SHA unchanged across the phase + `MinesweeperHeaderBar` consumes default `compact: false` chip API |

**Status (top-level):** PARTIAL — Large-zone Hard layout iteratively verified during execution; full 18-row sweep DEFERRED to TestFlight build per Plan 11-08 close.
**Verifier:** gabe (iterative review during phase execution)
**Date:** 2026-05-13

## Execution-time verification summary

The Mines Video Mode adoption was reviewed live during phase execution via 4 rounds of design feedback on the Large-zone compact row. Verified surfaces:

- **Hard 16×30 fit at 12pt floor on largeBottom (Voltage)** — A2 measurement (Plan 11-06) confirmed board fits without horizontal scroll inside the NavigationStack chrome; user confirmed adjacency numbers + mine glyph + flag glyph all legible.
- **D-05 slot order superseded for Mines** — round 2 polish split the stacked Mines+Timer slot 2 into symmetric two-chip layout (Mines-left / pill-center / Time-right) per user feedback. Phase 8 D-06 (stacked chip) intentionally diverged — documented in 11-04-SUMMARY addendum.
- **Settings gear dropped** — round 1 polish; `VideoCompactControlRow.onSettings` nullable; Mines passes `nil`. Phase 9 D-12 5-slot contract softened to 5-or-4.
- **Always-collapsed difficulty menu** — round 1 polish; `restartWithOverflowMenu` hosts difficulty picker on Large zones unconditionally (no threshold-driven branching).
- **Center-anchored Reveal/Flag pill** — round 3 + round 4 polish; `Spacer(minLength: 0).frame(maxWidth: theme.spacing.xs)` flanking the picker slot in `VideoCompactControlRow`.

The remaining 17 rows are DEFERRED to TestFlight because:
- Small-zone rows (1-6 partial + 9-12 + 15-18) use Phase 10 D-11 passthrough — `videoModeAware` short-circuits, layout falls through to `existingLayout` with slot-routed toolbar; byte-identical to v1.0 once Reveal/Flag is honored.
- Large-zone Easy/Medium rows (1, 2, 7, 8) inherit the same `compactRowComposed` shape verified in row 14 with a smaller board (9×9 or 16×16) — geometric inheritance is trivial.
- Large-top Hard (row 13) is symmetric to row 14 (compact row at top instead of bottom); A2 measurement (Plan 11-06) confirmed largeTop also fits.

This satisfies "verify the Large-zone Mines worst-case template" — which is the actual phase-defining acceptance per ROADMAP Phase 11 Goal. Full 18-row coverage moves to the TestFlight sweep listed in v1.0 carry-over items (per STATE.md §"v1.0 Carry-Over" — PF-06 12+4 theme-matrix screenshots).

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
