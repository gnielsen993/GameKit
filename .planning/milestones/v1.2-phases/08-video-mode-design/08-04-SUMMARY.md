---
phase: 08-video-mode-design
plan: 04
subsystem: video-mode-design
tags: [design, layout, video-mode, screenshots, pip-zones]
requires:
  - .planning/phases/08-video-mode-design/08-01-SUMMARY.md
  - Docs/screenshots/v1.2-design/README.md
  - .planning/phases/08-video-mode-design/08-CONTEXT.md
  - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
  - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
  - Docs/GameDrawer-v1.2-Video-Mode-Plan.md
provides:
  - VIDEO-MODE-LAYOUTS.md (5 games x 6 PiP zones, anchor artifact for Phase 8 SC1)
  - 5 HTML overlay sketches under .planning/sketches/08-video-mode-design/
  - Baseline squeeze evidence pointer for Plan 08-05 ADR
affects:
  - Phase 9 Foundation (VideoModeStore reads zone vocabulary from layout doc)
  - Phase 10 Layout Primitives (stub behavior derives from per-zone notes)
  - Phase 11 Minesweeper Adoption (consumes layout doc + ADR)
  - Phase 12 Merge + Nonogram Adoption
  - Phase 13 Win/Loss Banner (cross-references 08-BANNER-PLACEMENT.md)
tech-stack:
  added: []
  patterns:
    - HTML throwaway sketches (CONTEXT D-01)
    - 6-zone PiP vocabulary (REQUIREMENTS VIDEO-02)
    - Compromise order from plan-doc §Compromise order
key-files:
  created:
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - .planning/sketches/08-video-mode-design/layout-mines-easy.html
    - .planning/sketches/08-video-mode-design/layout-mines-medium.html
    - .planning/sketches/08-video-mode-design/layout-mines-hard.html
    - .planning/sketches/08-video-mode-design/layout-merge.html
    - .planning/sketches/08-video-mode-design/layout-nonogram.html
  modified: []
decisions:
  - "Layout doc references all 17 PiP-overlaid screenshots from 08-01 (not 10 — extended per Rule-3 deviation)"
  - "Mines Hard strategy deferred to 08-HARD-MINES-ADR.md (Plan 08-05) per CONTEXT D-13 — NO pre-decision"
  - "Canonical 4-corner Hard Dracula set chosen as evidence anchor for Small-PiP placement across all games"
metrics:
  duration_minutes: 8
  completed_date: 2026-05-12
  tasks_completed: 2
  files_created: 6
status: complete
---

# Phase 8 Plan 04: Layout Doc — Summary

## One-liner

Screenshot-annotated `VIDEO-MODE-LAYOUTS.md` (5 games × 6 PiP zones) plus 5 HTML
overlay sketches; Hard-Mines strategy explicitly deferred to Plan 08-05.

## What was built

- **`.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md`** — the Phase 8
  SC1 anchor artifact. Five game H2 sections (Mines Easy, Mines Medium, Mines
  Hard, Merge, Nonogram). Each section:
  - Cites both Classic + Dracula screenshots (CLAUDE.md §8.12 legibility audit).
  - Has a 6-row PiP-zone table with "where controls go / what happens to the
    board" notes for every zone.
  - Maps each zone annotation to a real-or-synthesized screenshot, with
    canonical 4-corner Hard Dracula citations where synthesis was used.
  - Records the Compromise-order trigger (steps 3, 4, or 5 from plan-doc
    §Compromise order) where applicable.
- **Mines Hard "Strategy decision deferred" subsection** — explicit pointer to
  `08-HARD-MINES-ADR.md` (Plan 08-05) with the CONTEXT D-13 deconfliction note
  for A11Y-05 / 06.1-03 MagnifyGesture + auto-scale.
- **Five HTML overlay sketches** under `.planning/sketches/08-video-mode-design/`
  (`layout-mines-easy.html`, `layout-mines-medium.html`, `layout-mines-hard.html`,
  `layout-merge.html`, `layout-nonogram.html`). Each shows the source screenshot
  as a device-frame background with 6 toggleable PiP-zone overlays (radio
  buttons) and a per-zone behavior table. All inline CSS, under 250 lines each.
- **`layout-mines-hard.html`** additionally embeds the canonical 4-corner Dracula
  evidence grid as four real screenshots side-by-side, and carries a top-of-page
  red strategy-deferred note pointing at the 08-05 ADR.
- **Banner-placement pairing table** copied into the doc so downstream agents
  read one table for both PiP zones and banner anchors (sourced from
  `08-BANNER-PLACEMENT.md` D-09).

## Files

### Created

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — 302 lines
- `.planning/sketches/08-video-mode-design/layout-mines-easy.html` — 99 lines
- `.planning/sketches/08-video-mode-design/layout-mines-medium.html` — 98 lines
- `.planning/sketches/08-video-mode-design/layout-mines-hard.html` — 134 lines
- `.planning/sketches/08-video-mode-design/layout-merge.html` — 98 lines
- `.planning/sketches/08-video-mode-design/layout-nonogram.html` — 99 lines

### Modified

None.

### Deleted

None.

## Commits

- `f2e4beb` — docs(08-04): author VIDEO-MODE-LAYOUTS.md (5 games x 6 PiP zones)
- `4546438` — docs(08-04): add 5 per-game PiP-zone overlay sketches

## Deviations from Plan

### How the 08-01 deviation reshaped 08-04 (no new deviation, but materially different approach)

The plan-doc must_haves said "all 10 screenshots from 08-01". Plan 08-01 actually
shipped 17 PiP-overlaid screenshots (see `08-01-SUMMARY.md` — Rule-3 deviation
accepted). The brief in the executor prompt called this out:

> Treat "all relevant screenshots from 08-01" as the operative requirement; the
> doc must reference every available shot at least once.

This was followed: the "Screenshot inventory used by this doc" table inside
`VIDEO-MODE-LAYOUTS.md` enumerates all 17 files and the per-game sections cite
each as either real evidence or canonical-set support. No additional deviation
was needed at this plan's level — the brief was implemented directly.

### Synthesized-vs-real evidence mapping (added beyond plan-doc spec)

The original plan-doc §Layout behavior treated each zone as a self-contained
annotation. Because of the 08-01 deviation, the layout doc now explicitly tags
each zone in each game section as **real** (game-and-preset-specific screenshot
exists) or **synthesized** (canonical 4-corner Hard Dracula set + Home Classic
Large-bottom + Home Dracula Small-bottom cited as evidence). This is a stricter
contract than the plan required but is the right behavior given the asymmetric
screenshot coverage. Not flagged as a separate deviation — it sits inside the
must_haves' "annotate every game section with all 6 zones" intent.

### Auto-fixed Issues

None — both tasks ran clean, no Rule-1/2/3 fixes were needed.

## Verification

- [x] `test -f .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` passes
- [x] 5 game H2 sections present (`grep -cE '^## Minesweeper — Easy|…' = 5`)
- [x] 6-zone label total = 96 across the doc (vs. plan's minimum of 30)
- [x] `08-HARD-MINES-ADR.md` referenced (5 occurrences in doc, 1 in Hard sketch)
- [x] No "Sudoku" in any artifact (REQUIREMENTS §v1.2 Out of Scope)
- [x] All 5 sketch files exist, each with >=6 PiP-zone labels (18–23 actual)
- [x] All sketch files <= 250 lines (max 134, min 98)
- [x] Both Classic + Dracula screenshot filenames referenced for every game
- [x] `git diff --name-only -- gamekit/` empty across both commits (SC5 holds)
- [x] No unintended file deletions across either commit
- [x] Plan automated verify commands for both tasks pass (run inline at end of each task)

## Auth gates

None.

## Threat Flags

None — design-doc only, no security-relevant surface introduced.

## Known Stubs

None — every zone annotation is backed by a real screenshot reference or a
canonical-set citation. No `TODO` / `placeholder` / "coming soon" text in any
artifact.

## Consumers unlocked

- **Plan 08-05 (Hard-Mines ADR)** — `layout-mines-hard.html` baseline + the
  Hard section's "Strategy decision deferred" subsection are the explicit hand-off
  points. The ADR can compare strategy variants against the same 4-corner Dracula
  evidence grid embedded in the sketch.
- **Plan 08-06 (Design lock)** — the layout doc is one of the four artifacts the
  design-lock checklist verifies.
- **Phase 9 Foundation** — `VideoModeStore` zone vocabulary reads from this doc.
- **Phase 10 Layout Primitives** — stub behaviors derive from the per-zone
  control/board notes in each game section.
- **Phase 11 Minesweeper Adoption** — consumes layout doc + ADR.
- **Phase 12 Merge + Nonogram Adoption** — consumes the Merge + Nonogram sections.
- **Phase 13 Win/Loss Banner** — uses the banner-anchor pairing table.

## Self-Check: PASSED

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — FOUND
- `.planning/sketches/08-video-mode-design/layout-mines-easy.html` — FOUND
- `.planning/sketches/08-video-mode-design/layout-mines-medium.html` — FOUND
- `.planning/sketches/08-video-mode-design/layout-mines-hard.html` — FOUND
- `.planning/sketches/08-video-mode-design/layout-merge.html` — FOUND
- `.planning/sketches/08-video-mode-design/layout-nonogram.html` — FOUND
- Commit `f2e4beb` (Task 1) — FOUND in `git log`
- Commit `4546438` (Task 2) — FOUND in `git log`
