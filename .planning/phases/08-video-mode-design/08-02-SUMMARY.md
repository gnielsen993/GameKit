---
phase: 08-video-mode-design
plan: 02
subsystem: design
tags: [designkit, tokens, compact-row, video-mode, sketch]

# Dependency graph
requires:
  - phase: 06.1-pre-release-polish
    provides: "Reveal/Flag FAB pattern using theme.radii.button (06.1-02) — pattern parent for D-05 picker pill radius"
  - phase: 02-mines-engines
    provides: "(indirect) MinesweeperHeaderBar slot-row reference — confirms theme.spacing.s gap (D-07)"
provides:
  - "08-COMPACT-ROW-TOKENS.md — token-level spec locking D-05..D-08 for Phase 9 VideoCompactControlRow"
  - "Per-game slot mappings (Minesweeper / Merge / Nonogram) consumed by Phase 11 + Phase 12"
  - "Compact-row HTML sketch with CSS variables mirroring DesignKit token names"
affects: [09-video-mode-foundation, 11-mines-video-mode-adoption, 12-merge-nonogram-video-mode-adoption]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Token-name-only design specs — markdown docs reference radii.button / spacing.xl / spacing.s by name, never px"
    - "HTML throwaway sketches in .planning/sketches/ with CSS variables 1:1 mirroring DesignKit tokens"

key-files:
  created:
    - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - .planning/sketches/08-video-mode-design/compact-row-tokens.html
  modified: []

key-decisions:
  - "D-05 locked into spec: picker pill = theme.radii.button (no new radii.pill anchor — CLAUDE.md §2 promotion rule)"
  - "D-06 locked: picker pill height = theme.spacing.xl (between info-chip and full DKButton)"
  - "D-07 locked: inter-item gap = theme.spacing.s (matches MinesweeperHeaderBar precedent)"
  - "D-08 locked: per-game slot mapping verbatim for Mines / Merge / Nonogram; Sudoku Out of Scope"

patterns-established:
  - "Design-token spec docs are token-name-only — zero pt/px values in 08-COMPACT-ROW-TOKENS.md; verified by grep gate in acceptance criteria"
  - "HTML sketch CSS variables mirror DesignKit token names 1:1 (--radii-button → theme.radii.button) so a future reader can map them by inspection"

requirements-completed: []

# Metrics
duration: 2min
completed: 2026-05-12
---

# Phase 8 Plan 02: Compact Control Row Tokens Summary

**DesignKit-token-level spec locking the v1.2 compact control row: picker pill = radii.button, height = spacing.xl, gap = spacing.s, with per-game slot mappings for Minesweeper / Merge / Nonogram and Sudoku held Out of Scope.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-12T21:42:36Z
- **Completed:** 2026-05-12T21:43:57Z
- **Tasks:** 2
- **Files modified:** 2 (both newly created)

## Accomplishments

- `08-COMPACT-ROW-TOKENS.md` authored — token anchors table covers picker pill, icon buttons, info chips; per-game slot mappings spec'd verbatim from D-08; Sudoku appears only under Out of Scope (2 occurrences total).
- HTML sketch renders all three slot orderings with CSS variables (`--radii-button`, `--spacing-xl`, `--spacing-s`, `--radii-chip`, `--spacing-l`) that mirror DesignKit token names 1:1.
- Legend table in the sketch maps every CSS variable back to its DesignKit token + source decision — Phase 9 can use the sketch as a visual diff against the implementation without ambiguity.
- Zero `gamekit/` files touched (Phase 8 SC5 satisfied for this plan).

## Task Commits

Each task was committed atomically:

1. **Task 1: Author 08-COMPACT-ROW-TOKENS.md spec** — `1089e0f` (docs)
2. **Task 2: Build compact-row HTML sketch** — `cade77c` (docs)

## Files Created/Modified

- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — 62-line spec; sections: Status, Slot Order, Token Anchors, Per-Game Slot Mapping (Mines / Merge / Nonogram), Out of Scope (Sudoku, radii.pill, per-game variants, portrait PiP), Source decisions, Consumed by.
- `.planning/sketches/08-video-mode-design/compact-row-tokens.html` — 169-line throwaway sketch; three rows (Mines / Merge / Nonogram) using CSS variables that mirror DesignKit token names, plus a legend table.

## Decisions Made

None new — this plan locks D-05..D-08 from the phase CONTEXT into a durable spec. All four decisions were already resolved in `08-CONTEXT.md` before execution began; the work was authoring the contract that Phase 9 reads, not making new design choices.

## Deviations from Plan

None — plan executed exactly as written.

- All hard rules respected: zero numeric pt/px values in the spec doc (verified by `grep -E "\b[0-9]+(pt|px)\b"` returning empty); picker references `radii.button` and `spacing.xl`; inter-item gap references `spacing.s`; Sudoku appears only under Out of Scope (count = 2).
- HTML sketch under 200 lines (169 lines).
- No file under `gamekit/` modified — Phase 8 SC5 holds for this plan.

## Issues Encountered

None.

## Verification

Acceptance criteria for both tasks were checked inline before each commit:

- `test -f` confirms both files exist.
- `grep -q "radii\.button"` / `grep -q "spacing\.xl"` / `grep -q "spacing\.s"` confirm token names present in the spec.
- `grep -q "Reveal/Flag picker"` / `grep -q "Mode picker"` / `grep -q "Fill/Mark picker"` confirm all three per-game pickers are spec'd.
- `grep -c "Sudoku"` returns 2 — both under Out of Scope (manually re-verified visually).
- `grep -E "\b[0-9]+(pt|px)\b" 08-COMPACT-ROW-TOKENS.md` returns empty — no hardcoded sizes in the spec.
- `wc -l compact-row-tokens.html` = 169 (≤ 200 cap).
- `git diff --name-only` across both task commits returns no files under `gamekit/`.

## Next Phase Readiness

- **Phase 9 SC4** can build `VideoCompactControlRow` directly against `08-COMPACT-ROW-TOKENS.md` — token anchors table is the literal contract.
- **Phase 11** Minesweeper adoption will use the Minesweeper slot mapping verbatim (no re-derivation needed).
- **Phase 12** Merge + Nonogram adoption will use their respective slot mappings.
- No blockers introduced. Plan 03 (banner placement) is the next plan in the Phase 8 sequence.

## Self-Check: PASSED

- FOUND: `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md`
- FOUND: `.planning/sketches/08-video-mode-design/compact-row-tokens.html`
- FOUND commit: `1089e0f` (Task 1 — docs: author compact-row tokens spec)
- FOUND commit: `cade77c` (Task 2 — docs: add compact-row HTML sketch)

---
*Phase: 08-video-mode-design*
*Completed: 2026-05-12*
