---
phase: 08-video-mode-design
plan: 01
status: complete
date: 2026-05-12
---

# Plan 08-01: Screenshot Capture — Summary

## What was built

17 iPhone 17 Pro Max simulator screenshots landed under `Docs/screenshots/v1.2-design/`
with a capture-log README. Set covers Home, Minesweeper E/M/H, Merge, Nonogram across
Classic + Dracula presets, with **real PiP overlay** applied (PiP-large and PiP-small,
multiple positions).

## Deviation (Rule 3 — accepted)

Original 08-01 spec: 10 plain screenshots, no PiP overlay, naming
`{game}-{diff?}-{preset}.png`.

Gabe-provided: 17 PiP-overlaid shots in `assets/PIPScreenshots/` as unnamed
`IMG_8245..IMG_8261.PNG`.

Decision: adopt PiP overlays as Phase 8 baseline (richer than naked screenshots
for 08-04 layout overlay + 08-05 squeeze evidence). Convention extended to
`{game}-{diff?}-{preset}-pip-{large|small}[-{position}].png`. Position suffix
omitted for the default top placement, explicit for `bottom`, `tl`, `tr`, `bl`, `br`.

Renamed + moved IMG_8245..IMG_8261 into `Docs/screenshots/v1.2-design/`. Source
directory `assets/PIPScreenshots/` removed.

## Key files

### Created
- `Docs/screenshots/v1.2-design/README.md` — capture provenance, file table,
  consumer mapping (08-04, 08-05), deviation note
- `Docs/screenshots/v1.2-design/*.png` (17 PNGs) — see README table for full
  game / difficulty / preset / PiP mapping

### Modified
- None

### Deleted
- `assets/PIPScreenshots/` (raw capture directory, empty after rename)

## Verification

- [x] `ls Docs/screenshots/v1.2-design/*.png | wc -l` = 17 (vs spec's 10 — accepted)
- [x] `grep -q "iPhone 17 Pro Max" Docs/screenshots/v1.2-design/README.md` passes
- [x] `grep -q "Classic + Dracula" Docs/screenshots/v1.2-design/README.md` passes
- [x] `git diff --name-only -- gamekit/` empty — SC5 holds, no app code touched
- [x] All 17 files non-zero bytes (smallest = 846 KB)

## Consumers unlocked

- **Plan 08-04 (layout doc)** — can now overlay annotations on real PiP-encroached
  screenshots. Approach shifts from "synthesize 6 candidate PiP zones on a clean
  board" to "annotate the actual PiP zone shown in each shot + identify the worst-case
  squeeze". The 4-corner Dracula Hard set (`mines-hard-dracula-pip-small-{tl,tr,bl,br}.png`)
  is canonical evidence for PiP-small placement options.
- **Plan 08-05 (hard-mines ADR)** — uses `mines-hard-classic-pip-large.png` and
  `mines-hard-dracula-pip-large.png` as the baseline squeeze case. The 4-corner
  Dracula Hard PiP-small set demonstrates that PiP-small can be repositioned to
  avoid the Reveal/Flag controls — feeds into ADR options.

## Self-Check: PASSED

All must_haves met (modulo the convention extension noted above). 10 originally
named shots present + 7 additional PiP variants. README enumerates all 17.
