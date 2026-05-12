# Phase 8 — Compact Control Row Tokens

## Status

Design lock for Phase 9 SC4. Tokens here are the contract `VideoCompactControlRow` must read. Per CLAUDE.md §1, no hardcoded radii / spacing / colors. Per CLAUDE.md §2, no new DesignKit anchor is added; v1.2 reuses existing tokens (D-05 rejects a speculative `radii.pill`).

## Slot Order

Plan-doc verbatim (`Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Compact control row):

> Back | primary info | picker | secondary info | settings

## Token Anchors

| Element                              | Token          | Source decision                          |
| ------------------------------------ | -------------- | ---------------------------------------- |
| Picker pill corner radius            | `radii.button` | D-05                                     |
| Picker pill height                   | `spacing.xl`   | D-06                                     |
| Inter-item gap                       | `spacing.s`    | D-07                                     |
| Back / Settings icon button radius   | `radii.button` | D-05 (consistency)                       |
| Info chip corner radius              | `radii.chip`   | existing — chips already use this anchor |
| Info chip height                     | `spacing.l`    | inherited from `MinesweeperHeaderBar` precedent |

Picker pill uses `radii.button` because that anchor already reads as "primary action surface" in v1.0 (Reveal/Flag FAB, 06.1-02). Info chips use `radii.chip` because that anchor already reads as "passive info readout" in v1.0 (`MinesweeperHeaderBar`). The compact row therefore inherits the existing radius vocabulary without inventing new anchors.

## Per-Game Slot Mapping

Labels read verbatim from CONTEXT D-08. Each label maps to existing game state — no new state plumbing in the design phase.

### Minesweeper

`Back | Flags/mines | Reveal/Flag picker | Time | Settings`

### Merge

`Back | Score | Mode picker | Best/time | Settings`

### Nonogram

`Back | Lives/size | Fill/Mark picker | Time | Settings`

## Out of Scope

- Sudoku slot mapping — game not built (REQUIREMENTS §v1.2 Out of Scope, CONTEXT D-08). Re-evaluated when Sudoku enters the roadmap.
- `radii.pill` DesignKit token — CLAUDE.md §2 promotion rule requires 2+ consumers; v1.2 has 1 (the compact-row picker pill). Reuses `radii.button`.
- Per-game compact-picker variants — REQUIREMENTS VIDEO-04 locks "shared compact control row component". Per-game pickers are forbidden; the picker pill is the same surface across all three games.
- Vertical / portrait-PiP slot orderings — explicit Out of Scope per REQUIREMENTS §v1.2.

## Source decisions

- **D-05** — picker pill corner radius = `radii.button` (no new `radii.pill` anchor).
- **D-06** — picker pill height = `spacing.xl`.
- **D-07** — inter-item gap = `spacing.s`.
- **D-08** — per-game slot mapping verbatim, Sudoku excluded.

Full text in `.planning/phases/08-video-mode-design/08-CONTEXT.md` §Compact Control Row Tokens.

## Consumed by

- Phase 9 SC4 — `VideoCompactControlRow` component. The view reads `theme.radii.button` / `theme.spacing.xl` / `theme.spacing.s` / `theme.radii.chip` / `theme.spacing.l` directly; no derived constants, no hardcoded points.
- Phase 11 — Minesweeper adoption uses the Minesweeper slot mapping (Back | Flags/mines | Reveal/Flag picker | Time | Settings).
- Phase 12 — Merge + Nonogram adoption use their respective slot mappings from §Per-Game Slot Mapping.
