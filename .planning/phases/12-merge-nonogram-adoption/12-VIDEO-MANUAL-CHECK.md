---
phase: 12-merge-nonogram-adoption
type: video-manual-check
canonical: true
status: pending
signed_off_by: ""
signed_off_date: ""
---

# Phase 12 — Merge + Nonogram Video Mode Manual Verification

**Authored:** 2026-05-13 (Plan 12-06)
**Filled in by:** Plan 12-06 (SC1 + SC2 + SC3 + SC4 sweep)
**Mirrors:** `.planning/phases/11-mines-adoption/11-VIDEO-MANUAL-CHECK.md` per CONTEXT D-12-MATRIX

## Purpose

Single verifier-reads-end-to-end doc for Phase 12 SC1, SC2, SC3, SC4 per `.planning/ROADMAP.md` §"Phase 12: Merge + Nonogram Adoption":

- **SC1:** Merge plays across all 6 PiP zones — swipe-driven tile merging stays gesture-clean, score / mode-picker / best chips reflow per Phase 10 primitives, end-of-game flow remains reachable.
- **SC2:** Nonogram plays across all 6 PiP zones — playable grid stays usable, **row + column hints remain readable in Large-top AND Large-bottom** (the worst case per VIDEO-10).
- **SC3:** Legibility regression check passes on Classic + Loud preset for BOTH games × 6 zones.
- **SC4:** Video Mode Off restores both games' baseline layouts byte-identical (VIDEO-13 spot-check on each game).
- **SC5:** Compact control row consumed verbatim — Merge slots `Back | Score | Mode picker | Best | Restart-w-menu`, Nonogram slots `Back | Size↔Lives | Fill/Mark picker | Time | Restart-w-menu`. No per-game forking of `VideoCompactControlRow`. (Verified by code review at Plans 12-02 + 12-04 acceptance; doc-mention only here.)

Per CONTEXT D-12-MATRIX, the matrix has **24 rows = 2 games × 2 representative difficulties × 6 PiP zones**. Per the P11 precedent, only the worst-case rows (Merge row 2 + Nonogram row 20) are signed off during execution; the other 22 rows inherit by geometric interpolation and are DEFERRED to TestFlight.

Plan 12-05 locked the Video-Mode Nonogram cell-size floor at **12pt** (audit passed on Dracula + Voltage); each Hard row's render is validated against that floor.

## How to use

For each row:

1. Launch the app on iPhone 17 Pro Max simulator.
2. Settings → Video Mode → On.
3. Settings → Video location → select the row's `Zone`.
4. Home → tap the row's game tile.
5. For **Merge** rows: switch to the row's `Mode` via the compact-row's Restart-w-menu (slot 5 on Large zones) or nav-bar toolbar (Small zones). Run First-swipe / Restart / Mode-change / Win-or-GameOver columns.
6. For **Nonogram** rows: switch to the row's `Difficulty` via the compact-row's Restart-w-menu (slot 5) or nav-bar toolbar. Run First-tap / Slide-fill / Long-press-mark / Restart / Win columns.
7. Mark Pass/Fail per row. Add notes for any deviation from baseline.

For Nonogram Hard row 20 (`largeBottom`): additionally compare the rendered Hard board against the Plan 12-05 audit screenshots — final-render parity is the SC2 acceptance condition.

## Matrix

| # | Game | Difficulty/Mode | Zone | First action | Restart | Mode/Diff change | Win/Loss completes | Pass/Fail | Notes |
|---|------|-----------------|------|--------------|---------|------------------|--------------------|-----------|-------|
| 1 | Merge | winMode | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — TestFlight sweep — inherits compactRowComposed shape verified at row 2 (symmetric, compact row at top instead of bottom). |
| 2 | Merge | winMode | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | **VERIFY** — worst-case squeeze for Merge swipe gesture; SC1 acceptance row. Run on Classic + Dracula. |
| 3 | Merge | winMode | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones use existingLayout (P10 D-11 passthrough); only toolbar items reposition. |
| 4 | Merge | winMode | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 5 | Merge | winMode | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 6 | Merge | winMode | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 7 | Merge | infinite | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — inherits row 1 shape; mode differs in win semantics only. |
| 8 | Merge | infinite | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — inherits row 2 shape; mode differs in win semantics only. |
| 9 | Merge | infinite | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 10 | Merge | infinite | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 11 | Merge | infinite | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 12 | Merge | infinite | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 13 | Nonogram | Tiny 5×5 | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — 5×5 fits trivially at any floor; inherits row 14 shape. |
| 14 | Nonogram | Tiny 5×5 | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — 5×5 fits trivially at any floor. |
| 15 | Nonogram | Tiny 5×5 | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough (BoardView uses 14pt off-path floor). |
| 16 | Nonogram | Tiny 5×5 | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 17 | Nonogram | Tiny 5×5 | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 18 | Nonogram | Tiny 5×5 | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 19 | Nonogram | Medium 15×15 Hard | largeTop | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — mirrors row 20 shape (vertically); 12pt floor verified to fit on largeBottom in row 20. |
| 20 | Nonogram | Medium 15×15 Hard | largeBottom | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | **VERIFY (SC2 acceptance row)** — Plan 12-05 floor lock target at 12pt; compare against `Docs/screenshots/v1.2-phase-12/nonogram-hard-{classic,dracula,voltage}-largeBottom-locked.png`. Run on Classic + Dracula + Voltage. |
| 21 | Nonogram | Medium 15×15 Hard | smallTopLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough (BoardView uses 14pt off-path floor). |
| 22 | Nonogram | Medium 15×15 Hard | smallTopRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 23 | Nonogram | Medium 15×15 Hard | smallBottomLeft | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |
| 24 | Nonogram | Medium 15×15 Hard | smallBottomRight | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | DEFERRED — Small zones passthrough. |

## Sign-off

| Success criterion | Verifier | Date | Status |
|-------------------|----------|------|--------|
| SC1 — Merge plays across 6 zones | | | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC2 — Nonogram Hard hint legibility in Large zones | | | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC3 — Classic + Loud × both games × 6 zones legibility | | | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC4 — Off-restore byte-identity (Merge + Nonogram) | | | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| SC5 — Compact row consumed verbatim (no per-game forking) | | | ☐ PASS / ☐ FAIL / ☐ DEFERRED |
| **Top-level** | | | ☐ PASS / ☐ FAIL / ☐ PARTIAL |
