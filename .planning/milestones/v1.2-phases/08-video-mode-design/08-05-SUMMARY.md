---
phase: 08
plan: 05
subsystem: video-mode-design
tags: [adr, hard-minesweeper, video-mode, design-lock, deconfliction]
requires:
  - 08-01 (mines-hard-classic-pip-large.png · mines-hard-dracula-pip-large.png · 4-corner Dracula PiP-small set)
  - 08-04 (VIDEO-MODE-LAYOUTS.md §"Minesweeper — Hard" deferred-decision pointer)
  - 06.1-03 (A11Y-05 MagnifyGesture + auto-scale cellSize system — the deconfliction target)
provides:
  - 08-HARD-MINES-ADR.md (Hard 16x30 Video-Mode strategy = smaller-cells, Accepted 2026-05-12)
  - Phase 11 SC2 input — implements smaller-cells exactly; alternatives NOT re-debated
  - Phase 11 SC3 input — Hard validation re-uses the screenshots embedded in the ADR
  - ROADMAP §v1.2 Research Flags resolution — Phase 11 research-flag does NOT fire
affects:
  - .planning/ROADMAP.md (Phase 8 progress 4/6 -> 5/6; 08-05 [x])
  - .planning/STATE.md (Plan counter 5 of 6; CONTEXT D-13 resolved)
tech-stack:
  patterns:
    - "ADR-as-strategy-lock — Phase 11 SC2 reads ADR by name; alternatives NOT re-debated downstream"
    - "Smaller-cells via Video-Mode-aware Self.minCellSize lookup — 06.1-03 auto-scale infrastructure reused verbatim"
    - "Rollback target documented inline (warning-compromise / Variant 4) with existing 4-corner PiP-small evidence base"
key-files:
  modified:
    - .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md (256 -> 323 lines; Status / Decision / Rejected / Interaction / Rollback / Consumed-by all filled)
decisions:
  - "Hard 16x30 Video-Mode strategy = smaller-cells (Variant 1), Accepted 2026-05-12 (CONTEXT D-13 resolved)"
  - "ROADMAP §v1.2 Phase 11 research-flag does NOT fire — smaller-cells is one of two ROADMAP-named skip-research outcomes"
  - "Rollback target = warning-compromise (Variant 4) on Pro Max mis-tap regression OR §8.12 Dracula legibility regression in Phase 11 / TestFlight"
metrics:
  duration: continuation
  completed: 2026-05-12
---

# Phase 8 Plan 5: Hard-Mines ADR Summary

**One-liner:** Locked Hard 16x30 Video-Mode strategy as `smaller-cells` (Variant 1) in `08-HARD-MINES-ADR.md`, with explicit 06.1-03 deconfliction note (zero-gesture-change, only `Self.minCellSize` becomes Video-Mode-aware) and a warning-compromise rollback condition keyed on Pro Max mis-tap or Dracula §8.12 legibility regression.

## What shipped

- ADR Status flipped Proposed → **Accepted 2026-05-12**.
- §Decision names `smaller-cells (Variant 1)` with rationale tied to: full-board preservation, no new gesture, reuse of 06.1-03 auto-scale infrastructure, Phase 11 research-flag avoidance, fat-finger-floor trade-off accepted with pinch-zoom escape hatch.
- §Rejected alternatives populated for all three NOT-chosen variants (scroll-pan, pinch-zoom, warning-compromise) — each with sketch path, baseline screenshot evidence, and a 2-3 sentence "rejected because…" tied to the Pros/Cons axes from the candidate sections.
- §Interaction with A11Y-05 / 06.1-03 explicit deconfliction contract: `MagnifyGesture`, cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())`, `.scaleEffect(zoomScale, anchor: .center)`, `zoomScale`/`baseZoomScale` dual-state, and `clampZoomScale(_:)` range all byte-identical; only `Self.minCellSize` lookup becomes Video-Mode-aware (gated on `videoModeStore.isOn`).
- §Rollback condition (one sentence): if Phase 11 ships smaller-cells and a measurable mis-tap rate increase appears on iPhone 17 Pro Max OR a §8.12 Dracula legibility regression appears during Phase 11 verification or TestFlight feedback, rollback to warning-compromise (Variant 4) as the v1.3 fallback.
- §Consumed by: Phase 11 SC2 implements smaller-cells exactly; Phase 11 SC3 re-uses embedded screenshots; ROADMAP §v1.2 research-flag explicitly does NOT fire.

## Decision: smaller-cells (Variant 1)

**Gabe's note (verbatim):** "I want to try to get it first try so smaller-cells and if not then whatever we change it."

**Rationale (refined to match his intent):**

- Preserves the full 16x30 board without introducing a new gesture (zero risk to the ROADMAP P3 SC1 50-tap zero-misfire requirement).
- Deconflicts cleanly with A11Y-05 / 06.1-03 — `MagnifyGesture` stays untouched; pinch remains the user's manual fit.
- Does NOT trigger the Phase 11 research-flag per ROADMAP §v1.2 Research Flags (one of the two ROADMAP-named "skip research, proceed direct to planning" outcomes).
- Reuses the auto-scale infrastructure shipped in 06.1-03: only a single `minCellSize` constant becomes Video-Mode-aware, feeding the existing pure `cellSize(forWidth:cols:padding:spacing:)` static helper.

**Trade-off accepted:** cell-size reduction approaches the fat-finger floor (~12pt) — mitigated by:

1. A11Y-05 pinch-zoom remains as the user-controlled escape hatch.
2. Phase 11 SC4 §8.12 Dracula legibility audit gates the exact `minCellSize` value before code ships.
3. Rollback target (warning-compromise / Variant 4) is pre-documented for v1.3 if dogfooding reveals the trade-off was wrong.

## Deconfliction contract (06.1-03 / A11Y-05)

The ADR §Interaction section nails the byte-identical surface area:

| 06.1-03 surface | Smaller-cells change |
|---|---|
| `MagnifyGesture` via `.simultaneousGesture(...)` | UNCHANGED — byte-identical |
| Cell `LongPressGesture(0.25).exclusively(before: TapGesture())` | UNCHANGED — no `MinesweeperCellView` modifications |
| `.scaleEffect(zoomScale, anchor: .center)` on `LazyVGrid` | UNCHANGED |
| `zoomScale` / `baseZoomScale` dual-state + `clampZoomScale(_:)` `[0.8, 2.0]` | UNCHANGED |
| `scrollAxis(for:)` horizontal-ScrollView fallback | UNCHANGED — still engages on sub-floor cases |
| `cellSize(forWidth:cols:padding:spacing:)` static helper signature | UNCHANGED |
| `Self.minCellSize` constant lookup | **CHANGED** — becomes Video-Mode-aware (e.g. `Self.minCellSize(videoModeOn:)`); returns v1.0 `18` verbatim when `videoModeStore.isOn == false` |

Phase 11 SC5 (VIDEO-13 byte-identical off-path) is satisfied trivially by the off-path-returns-`18` rule.

## Rollback condition

> If Phase 11 ships smaller-cells and the reduced cell-size triggers a measurable mis-tap rate increase on iPhone 17 Pro Max or a §8.12 Dracula legibility regression during Phase 11 verification or TestFlight feedback, **rollback** this ADR and switch to warning-compromise (Variant 4) as the v1.3 fallback — that variant requires no gesture or layout change and the 4-corner Dracula PiP-small set is already documented as its evidence base.

## Deviations from Plan

None — plan executed exactly as written. The plan-doc explicitly named Task 3 as a checkpoint:decision; Gabe's reply (`smaller-cells`) plus rationale was captured verbatim into §Decision, and the rollback condition was synthesized from his note ("if not then whatever we change it") into a specific failure-mode-triggered switch to warning-compromise.

## Authentication gates

None.

## Commits

- `ce3c9bd` — `docs(08-05): add 4 Hard-Mines Video Mode candidate sketches` (Task 1, prior agent).
- `8a6042d` — `docs(08-05): scaffold 08-HARD-MINES-ADR.md draft (Decision empty)` (Task 2, prior agent).
- `894ff5c` — `docs(08-05): lock Hard-Minesweeper Video-Mode strategy as smaller-cells` (Task 3, this agent).

## Files

- `.planning/sketches/08-video-mode-design/hard-mines-smaller-cells.html` (Variant 1; the chosen approach)
- `.planning/sketches/08-video-mode-design/hard-mines-scroll-pan.html` (Variant 2; rejected)
- `.planning/sketches/08-video-mode-design/hard-mines-pinch-zoom.html` (Variant 3; rejected)
- `.planning/sketches/08-video-mode-design/hard-mines-warning-compromise.html` (Variant 4; rejected, held as v1.3 rollback target)
- `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` (323 lines; Status / Decision / Rejected / Interaction / Rollback / Consumed-by all populated)

## Phase 8 progress (after this plan)

- 08-01 screenshot-capture ✅
- 08-02 compact-row-tokens ✅
- 08-03 banner-placement ✅
- 08-04 layout-doc ✅
- **08-05 hard-mines-adr ✅** ← this plan
- 08-06 design-lock — unblocked; can now author `08-DESIGN-LOCK.md` and request Gabe's sign-off.

## Self-Check: PASSED

- ADR exists: FOUND `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md`
- All four candidate names appear: smaller-cells / scroll-pan / pinch-zoom / warning-compromise — VERIFIED via grep
- `rollback`, `chosen`, `06.1-03`, `MagnifyGesture`, `Phase 11` all present — VERIFIED via grep
- Commit `894ff5c` recorded — FOUND in git log
- No `gamekit/` files touched (Phase 8 SC5) — VERIFIED via git status / git diff
