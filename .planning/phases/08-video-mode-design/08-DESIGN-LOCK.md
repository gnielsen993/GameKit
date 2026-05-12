# Phase 8 — Design Lock

**Signed off:** 2026-05-12
**Signed off by:** Gabe Nielsen — verbatim signal: `design locked`
**Status:** design locked — Phase 9 unblocked.

## Artifacts locked

| Artifact | SC | Path | Locks decisions |
|---|---|---|---|
| `VIDEO-MODE-LAYOUTS.md` | SC1 | `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` (302L) | CONTEXT D-02, D-03, D-04 (screenshot source / preset / device); REQUIREMENTS VIDEO-02 (6 zones). |
| `08-HARD-MINES-ADR.md` | SC2 | `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` (323L) | CONTEXT D-13 (Hard strategy) — chosen: **smaller-cells (Variant 1)**; rejected: scroll-pan / pinch-zoom / warning-compromise. |
| `08-COMPACT-ROW-TOKENS.md` | SC3 | `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` (62L) | CONTEXT D-05, D-06, D-07, D-08 (picker pill `radii.button` + height `spacing.xl` + gap `spacing.s` + per-game slot mappings for Mines / Merge / Nonogram). |
| `08-BANNER-PLACEMENT.md` | SC4 | `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` (70L) | CONTEXT D-09, D-10, D-11, D-12 (6-row opposite-of-PiP anchor table + pill shape + `DKButton` primary action + Reduce-Motion dampen-to-identity). |

## SC5 — no app-code drift

`git status --porcelain -- gamekit/` returns empty at sign-off time. **Zero files under `gamekit/` were modified during Phase 8 — verified via git status.** Phase 8 wrote zero files into the `gamekit` Xcode target. All sketches are under `.planning/sketches/08-video-mode-design/` and are explicitly throwaway per CONTEXT D-01 — they ship as design provenance only and are never compiled into the app binary.

## 08-01 deviation impact

Plan 08-01 (screenshot capture) shipped **17 PiP-overlaid screenshots** instead of the plan-doc's original 10 plain screenshots — see `08-01-SUMMARY.md` for the Rule-3 deviation acceptance. The PiP-overlaid set is richer than naked captures because it directly evidences the small-PiP-corner-avoidance and large-PiP-squeeze cases that Plans 08-04 (layout doc) and 08-05 (Hard-Mines ADR) reason about.

Consequences locked into Phase 8 outputs:

- The 17-shot set becomes the **new baseline** for downstream phases. Phases 11 / 12 / 13 validate against the same 17 PNGs under `Docs/screenshots/v1.2-design/`.
- Plan 08-06's pre-flight artifact-audit PNG-count check was relaxed from `== 10` to `>= 10` (actual count 17) per the executor's Rule-1 deviation-handling rules. The original audit script's strict `== 10` would have spuriously failed despite the deviation being accepted upstream; the relaxed predicate preserves the audit's intent (screenshots exist) without re-opening the closed 08-01 deviation.
- Naming convention extended to `{game}-{diff?}-{preset}-pip-{large|small}[-{position}].png`. Position suffix omitted for the default top placement; explicit for `bottom`, `tl`, `tr`, `bl`, `br`.

## 08-04 strategy-deferral note

The "Minesweeper — Hard" section of `VIDEO-MODE-LAYOUTS.md` **explicitly defers** Hard 16×30 Video-Mode strategy to `08-HARD-MINES-ADR.md` per CONTEXT D-13. The layout doc carries a "Strategy decision deferred" subsection pointing at the ADR with a 06.1-03 / A11Y-05 `MagnifyGesture` deconfliction note — it does NOT pre-decide the strategy.

Plan 08-05 resolved the deferral. The ADR Status flipped Proposed → **Accepted 2026-05-12** with **smaller-cells (Variant 1)** as the chosen strategy. Rationale: full-board preservation, zero new gesture, reuse of 06.1-03 auto-scale infrastructure (only `Self.minCellSize` becomes Video-Mode-aware, gated on `videoModeStore.isOn`), no Phase 11 research-flag fired per ROADMAP §v1.2 Research Flags. Rollback target documented inline as warning-compromise (Variant 4) keyed on Pro Max mis-tap regression OR §8.12 Dracula legibility regression during Phase 11 / TestFlight.

## Sketch corpus (provenance)

All HTML throwaways live under `.planning/sketches/08-video-mode-design/`:

- `compact-row-tokens.html` (08-02)
- `banner-placement.html` (08-03)
- `layout-mines-easy.html` / `layout-mines-medium.html` / `layout-mines-hard.html` / `layout-merge.html` / `layout-nonogram.html` (08-04)
- `hard-mines-smaller-cells.html` (08-05; chosen) / `hard-mines-scroll-pan.html` (08-05; rejected) / `hard-mines-pinch-zoom.html` (08-05; rejected) / `hard-mines-warning-compromise.html` (08-05; rejected, held as v1.3 rollback target)

Sketches are NOT promoted to `gamekit/`. They exist as design-trace only.

## Unblock target

**Phase 9 (Video Mode Foundation) can begin.** Phase 9 consumes:

- `08-COMPACT-ROW-TOKENS.md` directly when building `VideoCompactControlRow` (Phase 9 SC4).
- `VIDEO-MODE-LAYOUTS.md` for the 6-zone vocabulary that drives Settings copy framing (Phase 9 SC3).

Phase 11 (Minesweeper Adoption) consumes `08-HARD-MINES-ADR.md` — Phase 11 SC2 implements smaller-cells exactly; alternatives are NOT re-debated downstream. ROADMAP §v1.2 Phase 11 research-flag does NOT fire (smaller-cells is one of the two ROADMAP-named skip-research outcomes).

Phase 12 (Merge + Nonogram Adoption) consumes the Merge + Nonogram sections of `VIDEO-MODE-LAYOUTS.md` plus the slot mappings in `08-COMPACT-ROW-TOKENS.md`.

Phase 13 (Win/Loss Banner) consumes `08-BANNER-PLACEMENT.md` for SC1–SC5.

## Sign-off

Gabe Nielsen — 2026-05-12 — "design locked".
