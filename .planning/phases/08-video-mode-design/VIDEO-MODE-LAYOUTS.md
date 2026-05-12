# Phase 8 — Video Mode Layout Annotations

Source screenshots: `Docs/screenshots/v1.2-design/` (per CONTEXT D-02).
Device: iPhone 17 Pro Max (CONTEXT D-04). Presets: Classic + Dracula
(CONTEXT D-03; CLAUDE.md §8.12).

Per Plan-doc §Core rule: Small PiP = control-aware; Large PiP = board-aware.
Compromise order (plan-doc §Compromise order): board > critical info > picker
> settings/secondary > time > board shrink/scroll.

## Deviation note — Plan 08-01 shipped 17 PiP-overlaid screenshots, not 10 naked ones

The 08-01 plan called for 10 plain in-progress screenshots. Gabe captured **17
screenshots with the real PiP overlay already applied** (PiP-large + PiP-small,
multiple positions). The deviation is accepted and locked — see
`Docs/screenshots/v1.2-design/README.md` for the full file table.

What this means for this layout doc:

- The 6 PiP zones from REQUIREMENTS VIDEO-02 (Large top, Large bottom, Small TL,
  Small TR, Small BL, Small BR) are STILL the canonical vocabulary. Every game
  section below annotates all 6 zones.
- Several zones have **real** evidence on disk — those annotations cite the
  actual screenshot rather than synthesizing the overlay on a clean board.
- Zones without a game-and-preset specific shot are noted as "synthesized
  overlay" and cite the **canonical 4-corner Hard Dracula set** as supporting
  evidence for the placement rule:
  - Small TL → `mines-hard-dracula-pip-small-tl.png`
  - Small TR → `mines-hard-dracula-pip-small-tr.png`
  - Small BL → `mines-hard-dracula-pip-small-bl.png`
  - Small BR → `mines-hard-dracula-pip-small-br.png`
  Plus `home-classic-pip-large-bottom.png` for Large bottom and
  `home-dracula-pip-small-bottom.png` for Small bottom corroboration.

The companion sketch files under
`.planning/sketches/08-video-mode-design/layout-*.html` outline all 6 zones
overlaid on the best-available screenshot for each game.

## Six PiP zones (REQUIREMENTS VIDEO-02)

1. Large top
2. Large bottom
3. Small TL (top-left)
4. Small TR (top-right)
5. Small BL (bottom-left)
6. Small BR (bottom-right)

## Screenshot inventory used by this doc

Full 17-file inventory — every shot below is referenced at least once in the
per-game sections that follow. (Source: `Docs/screenshots/v1.2-design/README.md`.)

| File | Used as |
|------|---------|
| `home-classic-pip-large-top.png` | Large top — Home preset baseline (referenced for Large-top discussion across games) |
| `home-classic-pip-large-bottom.png` | Large bottom — real evidence (Home Classic) |
| `home-dracula-pip-small-bottom.png` | Small bottom — real evidence (Home Dracula, supports BL/BR rule) |
| `mines-easy-classic-pip-large.png` | Mines Easy Large top — real |
| `mines-easy-dracula-pip-large.png` | Mines Easy Large top — real (Dracula audit) |
| `mines-medium-classic-pip-large.png` | Mines Medium Large top — real |
| `mines-medium-dracula-pip-large.png` | Mines Medium Large top — real (Dracula audit) |
| `mines-hard-classic-pip-large.png` | Mines Hard Large top — real (baseline squeeze) |
| `mines-hard-dracula-pip-large.png` | Mines Hard Large top — real (baseline squeeze, Dracula audit) |
| `mines-hard-dracula-pip-small-tl.png` | Small TL canonical evidence |
| `mines-hard-dracula-pip-small-tr.png` | Small TR canonical evidence |
| `mines-hard-dracula-pip-small-bl.png` | Small BL canonical evidence |
| `mines-hard-dracula-pip-small-br.png` | Small BR canonical evidence |
| `merge-classic-pip-large.png` | Merge Large top — real |
| `merge-dracula-pip-large.png` | Merge Large top — real (Dracula audit) |
| `nonogram-classic-pip-large.png` | Nonogram Large top — real |
| `nonogram-dracula-pip-large.png` | Nonogram Large top — real (Dracula audit) |

## Per-game annotation

## Minesweeper — Easy (9x9 / 10 mines)

Screenshots: `Docs/screenshots/v1.2-design/mines-easy-classic-pip-large.png` ·
`mines-easy-dracula-pip-large.png`
Filename basis: `mines-easy-classic.png` / `mines-easy-dracula.png` (the 08-01
plan referenced these stems; the actual shots use the `-pip-large` suffix).
Sketch: `.planning/sketches/08-video-mode-design/layout-mines-easy.html`

Evidence map:

- **Large top** — real. `mines-easy-classic-pip-large.png` and
  `mines-easy-dracula-pip-large.png` show the actual top-banded PiP encroachment.
- **Large bottom** — synthesized overlay. Cite
  `home-classic-pip-large-bottom.png` for the canonical Large-bottom band
  placement; Easy's small 9x9 board fits comfortably below the top compact row.
- **Small TL / TR / BL / BR** — synthesized overlay. Cite the 4-corner Hard
  Dracula set (`mines-hard-dracula-pip-small-{tl,tr,bl,br}.png`) for canonical
  placement. Easy's board is well within the playable region for every corner.

| PiP zone | Where controls go | What happens to the board |
|---|---|---|
| Large top    | Compact row at bottom edge; slots `Back | Flags/mines | Reveal/Flag picker | Time | Settings` (per `08-COMPACT-ROW-TOKENS.md`). | Board fits between reserved top band and compact row. 9x9 fits with comfortable margin — visible in `mines-easy-classic-pip-large.png`. |
| Large bottom | Compact row at top edge; same slot order. | Board fits between top row and reserved bottom band. 9x9 fits comfortably (see `home-classic-pip-large-bottom.png` for the band geometry). |
| Small TL     | Move Back out of top-left into top-right or compact row. | Board unchanged — 9x9 sits well inside the playable region. (Canonical TL: `mines-hard-dracula-pip-small-tl.png`.) |
| Small TR     | Move Settings out of top-right into top-left or compact row. | Board unchanged. (Canonical TR: `mines-hard-dracula-pip-small-tr.png`.) |
| Small BL     | Move any bottom-left FAB/picker affordances to bottom-right. | Board unchanged. (Canonical BL: `mines-hard-dracula-pip-small-bl.png`.) |
| Small BR     | Move Reveal/Flag FAB (06.1-02) and bottom-right affordances to bottom-left. | Board unchanged. (Canonical BR: `mines-hard-dracula-pip-small-br.png`.) |

Compromise-order trigger: none expected on Easy. The board has surplus vertical
room even with Large top/bottom bands reserved.

## Minesweeper — Medium (16x16 / 40 mines)

Screenshots: `Docs/screenshots/v1.2-design/mines-medium-classic-pip-large.png` ·
`mines-medium-dracula-pip-large.png`
Filename basis: `mines-medium-classic.png` / `mines-medium-dracula.png`.
Sketch: `.planning/sketches/08-video-mode-design/layout-mines-medium.html`

Evidence map:

- **Large top** — real. `mines-medium-classic-pip-large.png` and
  `mines-medium-dracula-pip-large.png` show the actual top-banded encroachment;
  on Medium the band consumes roughly the existing header strip plus a slice of
  upper board rows.
- **Large bottom** — synthesized overlay. Cite `home-classic-pip-large-bottom.png`
  for band geometry. Medium board height starts to compete with the bottom band;
  Compromise order step 4 (collapse settings into menu) may kick in before
  rendering becomes uncomfortable.
- **Small TL / TR / BL / BR** — synthesized overlay. Cite the 4-corner Hard
  Dracula set for placement. Medium board fits inside the playable region with
  margin; the squeeze risk is at Large bands, not small corners.

| PiP zone | Where controls go | What happens to the board |
|---|---|---|
| Large top    | Compact row at bottom edge; full slot order. | Board fits between top band and bottom compact row. 16x16 visibly snug in `mines-medium-classic-pip-large.png` but legible — no Compromise order step beyond step 3 (mode/picker still reachable) needed. |
| Large bottom | Compact row at top edge; full slot order. | Board fits between top row and reserved bottom band. Compromise order step 4 (collapse settings into a menu) may kick in to free vertical room. |
| Small TL     | Move Back out of top-left into top-right or compact row. | Board unchanged. (Canonical TL: `mines-hard-dracula-pip-small-tl.png` — Medium is strictly smaller, so the same rule fits with extra margin.) |
| Small TR     | Move Settings out of top-right into top-left or compact row. | Board unchanged. (Canonical TR: `mines-hard-dracula-pip-small-tr.png`.) |
| Small BL     | Move bottom-left FAB/picker affordances to bottom-right. | Board unchanged. (Canonical BL: `mines-hard-dracula-pip-small-bl.png`; see also `home-dracula-pip-small-bottom.png` for general small-bottom geometry.) |
| Small BR     | Move Reveal/Flag FAB (06.1-02) and bottom-right affordances to bottom-left. | Board unchanged. (Canonical BR: `mines-hard-dracula-pip-small-br.png`.) |

Compromise-order trigger: Large bottom may push step 4 (collapse Settings into
overflow menu); Large top stays at step 3 in the current screenshots.

## Minesweeper — Hard (16x30 / 99 mines)

Screenshots: `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` ·
`mines-hard-dracula-pip-large.png`. Small-PiP corner evidence:
`mines-hard-dracula-pip-small-tl.png` · `mines-hard-dracula-pip-small-tr.png` ·
`mines-hard-dracula-pip-small-bl.png` · `mines-hard-dracula-pip-small-br.png`.
Filename basis: `mines-hard-classic.png` / `mines-hard-dracula.png`.
Sketch: `.planning/sketches/08-video-mode-design/layout-mines-hard.html`

Evidence map (Hard is the squeeze case — Hard has the richest real-screenshot
coverage of any game in the set):

- **Large top** — real. `mines-hard-classic-pip-large.png` and
  `mines-hard-dracula-pip-large.png` both show the squeeze: insufficient board
  height at the current fixed cell size to render 16x30 between the top PiP band
  and the compact row.
- **Large bottom** — synthesized overlay. Cite `home-classic-pip-large-bottom.png`
  for band geometry. Same squeeze symptom expected as Large top (the band size
  is identical; the encroachment direction is the only difference).
- **Small TL** — real. `mines-hard-dracula-pip-small-tl.png` is the canonical
  evidence for TL placement across the entire phase. Demonstrates that Hard's
  16x30 board still fits with normal cell size when PiP is small — the squeeze
  is a Large-PiP problem, not a Small-PiP problem.
- **Small TR** — real. `mines-hard-dracula-pip-small-tr.png` is the canonical TR
  evidence.
- **Small BL** — real. `mines-hard-dracula-pip-small-bl.png` is the canonical BL
  evidence. Cross-corroborated by `home-dracula-pip-small-bottom.png` for the
  general bottom-corner geometry.
- **Small BR** — real. `mines-hard-dracula-pip-small-br.png` is the canonical BR
  evidence. NOTE: the existing Reveal/Flag FAB (06.1-02) lives at bottom-right
  by default; Small BR forces relocation to bottom-left.

| PiP zone | Where controls go | What happens to the board |
|---|---|---|
| Large top    | Compact row at bottom edge; Compromise order steps 4–5 expected (collapse Settings into menu; reduce visible time/secondary stats). | Insufficient board height for the current fixed cell size to render 16x30 between top band and compact row. STRATEGY DEFERRED to `08-HARD-MINES-ADR.md` (Plan 08-05) per CONTEXT D-13. See `mines-hard-classic-pip-large.png` / `mines-hard-dracula-pip-large.png` for the baseline squeeze. |
| Large bottom | Compact row at top edge; Compromise order steps 4–5 expected. | Same squeeze symptom as Large top (band geometry identical; encroachment direction reversed). STRATEGY DEFERRED to `08-HARD-MINES-ADR.md`. |
| Small TL     | Move Back out of top-left into top-right or compact row. | Board unchanged — confirmed by `mines-hard-dracula-pip-small-tl.png`. Hard's 16x30 still fits at normal cell size with Small PiP. |
| Small TR     | Move Settings out of top-right into top-left or compact row. | Board unchanged — confirmed by `mines-hard-dracula-pip-small-tr.png`. |
| Small BL     | Move bottom-left affordances to bottom-right. | Board unchanged — confirmed by `mines-hard-dracula-pip-small-bl.png`. |
| Small BR     | Move Reveal/Flag FAB (06.1-02) from bottom-right to bottom-left. | Board unchanged — confirmed by `mines-hard-dracula-pip-small-br.png`. NOTE: this is the only zone that requires relocating the FAB anchor from its v1.0 home. |

### Strategy decision deferred

Per CONTEXT D-13, the Hard-Minesweeper strategy (smaller cells / scroll-pan /
pinch-zoom / warning+compromise) is NOT pre-decided in this document. The
decision lives in `08-HARD-MINES-ADR.md` (Plan 08-05), which uses the same
screenshots and the `layout-mines-hard.html` baseline as inputs.

The ADR MUST deconflict with the existing A11Y-05 / 06.1-03 MagnifyGesture +
auto-scale system (CONTEXT D-13).

## Merge

Screenshots: `Docs/screenshots/v1.2-design/merge-classic-pip-large.png` ·
`merge-dracula-pip-large.png`.
Filename basis: `merge-classic.png` / `merge-dracula.png`.
Sketch: `.planning/sketches/08-video-mode-design/layout-merge.html`

Evidence map:

- **Large top** — real. `merge-classic-pip-large.png` and
  `merge-dracula-pip-large.png` show the actual top-banded encroachment. Merge's
  square board compresses gracefully — vertical compression of the compact row
  is the main lever.
- **Large bottom** — synthesized overlay. Cite `home-classic-pip-large-bottom.png`.
  Square board absorbs vertical squeeze better than rectangular Mines.
- **Small TL / TR / BL / BR** — synthesized overlay on Merge backgrounds; cite
  the 4-corner Hard Dracula canonical set for placement geometry. Merge square
  board has comfortable corner margin.

| PiP zone | Where controls go | What happens to the board |
|---|---|---|
| Large top    | Compact row at bottom edge; slots `Back | Score | Mode picker | Best/time | Settings` (per `08-COMPACT-ROW-TOKENS.md`). | Square board scales down vertically; visible compression in `merge-classic-pip-large.png`. Compromise order rarely advances past step 3. |
| Large bottom | Compact row at top edge; same slot order. | Square board absorbs the squeeze; vertical compression of the compact row is the main lever. (`home-classic-pip-large-bottom.png` for band geometry.) |
| Small TL     | Move Back out of top-left into top-right or compact row. | Board unchanged. (Canonical TL: `mines-hard-dracula-pip-small-tl.png`.) |
| Small TR     | Move Settings out of top-right into top-left or compact row. | Board unchanged. (Canonical TR: `mines-hard-dracula-pip-small-tr.png`.) |
| Small BL     | Move bottom-left affordances to bottom-right. | Board unchanged. (Canonical BL: `mines-hard-dracula-pip-small-bl.png`.) |
| Small BR     | Move bottom-right affordances to bottom-left. | Board unchanged. (Canonical BR: `mines-hard-dracula-pip-small-br.png`.) |

Compromise-order trigger: rarely past step 3. Square board geometry is friendly
to Video Mode (plan-doc §Game-specific notes — Merge: "likely straightforward").

## Nonogram

Screenshots: `Docs/screenshots/v1.2-design/nonogram-classic-pip-large.png` ·
`nonogram-dracula-pip-large.png`.
Filename basis: `nonogram-classic.png` / `nonogram-dracula.png`.
Sketch: `.planning/sketches/08-video-mode-design/layout-nonogram.html`

Evidence map:

- **Large top** — real. `nonogram-classic-pip-large.png` and
  `nonogram-dracula-pip-large.png` show the actual top-banded encroachment.
  Hints + board both need vertical room; Large top is the worst case for
  Nonogram (matches plan-doc §Game-specific notes — Nonogram: "Large sizes may
  behave more like Minesweeper").
- **Large bottom** — synthesized overlay. Cite `home-classic-pip-large-bottom.png`.
  Same risk as Large top — hint legibility at risk.
- **Small TL / TR / BL / BR** — synthesized overlay on Nonogram backgrounds;
  cite the 4-corner Hard Dracula canonical set for placement. Nonogram corners
  fit at normal cell size for default 10x10 difficulty.

| PiP zone | Where controls go | What happens to the board |
|---|---|---|
| Large top    | Compact row at bottom edge; slots `Back | Lives/size | Fill/Mark picker | Time | Settings` (per `08-COMPACT-ROW-TOKENS.md`). | Hints + board contest the remaining vertical band; hint legibility is the failure mode (matches plan-doc — "Large sizes may behave more like Minesweeper"). Compromise order step 5 (reduce visible time/secondary stats) may kick in early. |
| Large bottom | Compact row at top edge; same slot order. | Hint legibility at risk — same failure mode as Large top. (Band geometry: `home-classic-pip-large-bottom.png`.) |
| Small TL     | Move Back out of top-left into top-right or compact row. | Board unchanged at default 10x10. (Canonical TL: `mines-hard-dracula-pip-small-tl.png`.) |
| Small TR     | Move Settings out of top-right into top-left or compact row. | Board unchanged. (Canonical TR: `mines-hard-dracula-pip-small-tr.png`.) |
| Small BL     | Move bottom-left affordances to bottom-right. | Board unchanged. (Canonical BL: `mines-hard-dracula-pip-small-bl.png`.) |
| Small BR     | Move bottom-right affordances to bottom-left. | Board unchanged. (Canonical BR: `mines-hard-dracula-pip-small-br.png`.) |

Compromise-order trigger: Large top / Large bottom can advance to step 5 (reduce
visible time/secondary stats) to preserve hint legibility. Larger Nonogram sizes
(15x15) are not yet captured at design time — Phase 12 manual recipe will
re-audit if 15x15 ships.

## Cross-game summary

| Game / difficulty | Hardest PiP cases |
|---|---|
| Mines Easy     | none (all 6 zones fit). |
| Mines Medium   | Large top / Large bottom (Compromise order step 4 kicks in). |
| Mines Hard     | Large top / Large bottom (squeeze case — see `08-HARD-MINES-ADR.md`). |
| Merge          | Large top / Large bottom (vertical compression of compact row). |
| Nonogram       | Large top / Large bottom (hint legibility at risk). |

The Small TL/TR/BL/BR rows are uniformly "controls move, board unchanged" across
all five games at the screenshotted difficulties — proven by the canonical
4-corner Hard Dracula set. The squeeze problem in v1.2 is a Large-PiP problem,
not a Small-PiP problem.

## Pair with banner placement (08-BANNER-PLACEMENT.md)

`08-BANNER-PLACEMENT.md` D-09 defines the opposite-of-PiP anchor rule. Every PiP
zone in this doc pairs with a banner zone via that table — for completeness:

| PiP zone | Banner docks |
|---|---|
| Large top    | bottom edge |
| Large bottom | top edge |
| Small TL     | bottom-right |
| Small TR     | bottom-left |
| Small BL     | top-right |
| Small BR     | top-left |

Phase 13 win/loss banner reads from this paired table — do not re-derive the
banner anchor inside game code.

## Consumed by

- Phase 9 Foundation — Settings copy + VideoModeStore reads zone vocabulary from here.
- Phase 10 Layout Primitives — stub game-screen behavior derives from these per-zone notes.
- Phase 11 Minesweeper Adoption — consumes both this doc AND `08-HARD-MINES-ADR.md`.
- Phase 12 Merge + Nonogram Adoption — consumes the Merge + Nonogram sections.
- Phase 13 Win/Loss Banner — cross-references `08-BANNER-PLACEMENT.md` per zone.

## Source decisions

- CONTEXT D-02, D-03, D-04 — screenshot source / preset / device.
- CONTEXT D-13 — Hard-Mines strategy deferred to 08-05 ADR.
- REQUIREMENTS VIDEO-02 — six-zone vocabulary.
- Plan 08-01 Rule-3 deviation — 17 PiP-overlaid shots adopted as Phase 8
  baseline (see `Docs/screenshots/v1.2-design/README.md` and
  `08-01-SUMMARY.md`).
