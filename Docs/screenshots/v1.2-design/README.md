# Phase 8 Design Screenshots

Captured: 2026-05-12
Device: iPhone 17 Pro Max simulator (per CONTEXT D-04)
App build: GameDrawer main @ 0d1f9a8 (Merge + Nonogram graduated)
Presets: Classic + Dracula (per CONTEXT D-03, mirrors CLAUDE.md §8.12)

## Deviation from 08-01 spec

The 08-01 plan asked for 10 plain in-progress game screenshots named
`{game}-{difficulty?}-{preset}.png`. Gabe captured 17 screenshots **with the
real PiP overlay applied** (both `large` and `small` PiP sizes, multiple
positions) — richer evidence for downstream layout work than naked shots.

Decision (2026-05-12): adopt PiP-overlaid screenshots as the Phase 8 baseline.
Convention extended to `{game}-{difficulty?}-{preset}-pip-{large|small}[-{position}].png`
where `{position}` is omitted for the default top placement and explicit when
non-default (`bottom`, `tl`, `tr`, `bl`, `br`).

All boards are pre-first-tap (empty). Per CLAUDE.md §8.11 first-tap safety,
empty boards are valid layout-evidence — they show the playable region without
biasing the layout doc to a particular game state.

## Files (17)

| Game | Difficulty | Preset | PiP | Filename |
|------|------------|--------|-----|----------|
| Home | — | Classic | large, top | home-classic-pip-large-top.png |
| Home | — | Classic | large, bottom | home-classic-pip-large-bottom.png |
| Home | — | Dracula | small, bottom | home-dracula-pip-small-bottom.png |
| Minesweeper | Easy (9x9) | Classic | large, top | mines-easy-classic-pip-large.png |
| Minesweeper | Easy (9x9) | Dracula | large, top | mines-easy-dracula-pip-large.png |
| Minesweeper | Medium (16x16) | Classic | large, top | mines-medium-classic-pip-large.png |
| Minesweeper | Medium (16x16) | Dracula | large, top | mines-medium-dracula-pip-large.png |
| Minesweeper | Hard (16x30) | Classic | large, top | mines-hard-classic-pip-large.png |
| Minesweeper | Hard (16x30) | Dracula | large, top | mines-hard-dracula-pip-large.png |
| Minesweeper | Hard (16x30) | Dracula | small, top-left | mines-hard-dracula-pip-small-tl.png |
| Minesweeper | Hard (16x30) | Dracula | small, top-right | mines-hard-dracula-pip-small-tr.png |
| Minesweeper | Hard (16x30) | Dracula | small, bottom-left | mines-hard-dracula-pip-small-bl.png |
| Minesweeper | Hard (16x30) | Dracula | small, bottom-right | mines-hard-dracula-pip-small-br.png |
| Merge | — | Classic | large, top | merge-classic-pip-large.png |
| Merge | — | Dracula | large, top | merge-dracula-pip-large.png |
| Nonogram | 10x10 | Classic | large, top | nonogram-classic-pip-large.png |
| Nonogram | 10x10 | Dracula | large, top | nonogram-dracula-pip-large.png |

## Consumers

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` (Plan 08-04) —
  ingests these screenshots. Because PiP is already overlaid, 08-04 annotates
  the **actual** PiP zone covering each layout rather than synthesizing 6
  candidate zones on a clean board. The 4 `mines-hard-dracula-pip-small-{tl,tr,bl,br}.png`
  corner set is the canonical evidence for PiP-small placement options.
- `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` (Plan 08-05) —
  uses `mines-hard-classic-pip-large.png` and `mines-hard-dracula-pip-large.png`
  as the baseline squeeze case. The 4-corner Dracula set demonstrates that
  PiP-small can be repositioned to avoid the Reveal/Flag controls.

## Provenance

These are **not** the ASC marketing screenshots in `Docs/screenshots/asc/` —
those have partial coverage (missing Easy / Medium / Nonogram, no 6-corner
overlays, no PiP overlay). Per CONTEXT D-02, Phase 8 captures fresh.

The original raw capture set lived briefly under `assets/PIPScreenshots/` as
unnamed `IMG_8245..IMG_8261.PNG` before being moved + renamed into this directory.
