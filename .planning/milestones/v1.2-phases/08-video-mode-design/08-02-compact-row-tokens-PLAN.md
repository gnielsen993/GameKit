---
phase: 08-video-mode-design
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
  - .planning/sketches/08-video-mode-design/compact-row-tokens.html
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "08-COMPACT-ROW-TOKENS.md exists with picker pill = radii.button (D-05), height = spacing.xl (D-06), inter-item gap = spacing.s (D-07)"
    - "Per-game slot mappings for Minesweeper, Merge, Nonogram are spec'd verbatim from D-08 plan-doc"
    - "Sudoku is explicitly listed as Out of Scope (REQUIREMENTS §v1.2 Out of Scope)"
    - "Document contains zero hardcoded point values (no '8pt', '44pt', '0.5', etc — all sizing reads token names)"
    - "An HTML sketch under .planning/sketches/08-video-mode-design/ renders the three slot-orderings using CSS variables that mirror the named tokens"
  artifacts:
    - path: ".planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md"
      provides: "Compact-control-row token spec — Phase 9 reads this directly when building VideoCompactControlRow"
      contains: "radii.button"
    - path: ".planning/sketches/08-video-mode-design/compact-row-tokens.html"
      provides: "Throwaway HTML sketch — visual proof the three slot-orderings fit at the spec'd spacing"
  key_links:
    - from: ".planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md"
      to: ".planning/phases/09-video-mode-foundation/ (future)"
      via: "Phase 9 SC4 references this doc by name to build VideoCompactControlRow"
      pattern: "radii\\.button|spacing\\.xl|spacing\\.s"
---

<objective>
Spec the compact control row visual language at the DesignKit-token level —
no hardcoded sizes. Lock the four decisions from CONTEXT D-05..D-08 into a
durable doc that Phase 9 SC4 consumes directly when building the shared
`VideoCompactControlRow` component.

Purpose: Phase 8 SC3 — the compact-row tokens must be sketched at the token
level with concrete DesignKit anchors named. Sudoku is intentionally absent
(REQUIREMENTS §v1.2 Out of Scope, CONTEXT D-08).

Output: One markdown spec + one throwaway HTML sketch. Both live in
`.planning/`. No file under `gamekit/` touched (SC5).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/08-video-mode-design/08-CONTEXT.md
@Docs/GameDrawer-v1.2-Video-Mode-Plan.md
@CLAUDE.md

<!-- Pattern parents — pre-read so the spec uses the same token vocabulary the rest of the codebase already uses -->
@gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift
<!-- Reveal/Flag FAB consumer of radii.button (CONTEXT §code_context); use as the precedent for D-05 -->
</context>

<interfaces>
<!-- The four DesignKit token anchors this spec uses. -->
<!-- DO NOT invent new tokens. These are the ONLY radii/spacing names valid in v1.2 design. -->

DesignKit tokens (canonical, from `../DesignKit/Sources/DesignKit/Layout/*.swift`):
- Radii: `radii.card`, `radii.button`, `radii.chip`, `radii.sheet`
- Spacing: `spacing.xs`, `spacing.s`, `spacing.m`, `spacing.l`, `spacing.xl`, `spacing.xxl`

D-05 lock: picker pill MUST use `radii.button` (mirrors Reveal/Flag FAB from 06.1-02).
D-06 lock: picker pill height MUST anchor to `spacing.xl`.
D-07 lock: inter-item gap MUST be `spacing.s`.
D-08 lock: slot orderings come verbatim from plan-doc §Compact control row.
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Author 08-COMPACT-ROW-TOKENS.md spec</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-05, D-06, D-07, D-08 verbatim)
    - Docs/GameDrawer-v1.2-Video-Mode-Plan.md (§Compact control row — verbatim source of slot order)
    - CLAUDE.md §1 (DesignKit token discipline — no hardcoded values)
    - CLAUDE.md §2 (promotion rule — no new radii.pill token; reuse radii.button)
    - gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift (slot-row precedent — confirm spacing.s gap reading)
  </read_first>
  <action>
    Create `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` with these EXACT sections in order:

    1. `# Phase 8 — Compact Control Row Tokens` (h1)
    2. `## Status` paragraph: "Design lock for Phase 9 SC4. Tokens here are the contract VideoCompactControlRow must read. Per CLAUDE.md §1, no hardcoded radii / spacing / colors. Per CLAUDE.md §2, no new DesignKit anchor is added; v1.2 reuses existing tokens (D-05 rejects a speculative `radii.pill`)."
    3. `## Slot Order` — quote the plan-doc verbatim: "Back | primary info | picker | secondary info | settings"
    4. `## Token Anchors` table:
       | Element | Token | Source decision |
       |---|---|---|
       | Picker pill corner radius | `radii.button` | D-05 |
       | Picker pill height | `spacing.xl` | D-06 |
       | Inter-item gap | `spacing.s` | D-07 |
       | Back / Settings icon button radius | `radii.button` | D-05 (consistency) |
       | Info chip corner radius | `radii.chip` | existing — chips already use this anchor |
       | Info chip height | `spacing.l` | inherited from `MinesweeperHeaderBar` precedent |
    5. `## Per-Game Slot Mapping` — three subsections, exact strings from D-08:
       - `### Minesweeper`: `Back | Flags/mines | Reveal/Flag picker | Time | Settings`
       - `### Merge`: `Back | Score | Mode picker | Best/time | Settings`
       - `### Nonogram`: `Back | Lives/size | Fill/Mark picker | Time | Settings`
    6. `## Out of Scope` — bulleted:
       - Sudoku slot mapping (game not built — REQUIREMENTS §v1.2 Out of Scope, CONTEXT D-08).
       - `radii.pill` DesignKit token (CLAUDE.md §2 promotion rule — needs 2+ consumers, v1.2 has 1).
       - Per-game compact-picker variants (REQUIREMENTS VIDEO-04 locks "shared compact control row component").
    7. `## Source decisions` bulleted list referencing D-05, D-06, D-07, D-08 by ID.
    8. `## Consumed by` bulleted list:
       - Phase 9 SC4 — `VideoCompactControlRow` component.
       - Phase 11 — Minesweeper adoption uses the Minesweeper slot mapping.
       - Phase 12 — Merge + Nonogram adoption use their respective slot mappings.

    HARD RULES:
    - No numeric values for sizes (no "8", "44", "0.5", "12pt"). All sizing reads `theme.{radii,spacing}.<name>`.
    - "picker" elements MUST reference `radii.button` and `spacing.xl`.
    - "Inter-item" or "gap" MUST reference `spacing.s`.
    - Sudoku MUST appear under "Out of Scope" — never under slot mappings.
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "radii\.button" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "spacing\.xl" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "spacing\.s" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "Reveal/Flag picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "Mode picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "Fill/Mark picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -E "Sudoku.*Out of Scope|Out of Scope.*Sudoku" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md (Sudoku is OOS, not a fourth mapping)
    - grep -cE "Sudoku" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md — Sudoku appears at most twice (under "Out of Scope" only)
    - grep -E "\b[0-9]+(pt|px)\b" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md returns NO matches (no hardcoded sizes)
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "radii\.button" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "spacing\.xl" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "spacing\.s" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "Reveal/Flag picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "Mode picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "Fill/Mark picker" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && ! grep -qE "\b[0-9]+(pt|px)\b" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md</automated>
  </verify>
  <done>Markdown spec locks D-05..D-08 with valid DesignKit token names only; Sudoku appears only under Out of Scope.</done>
</task>

<task type="auto">
  <name>Task 2: Build compact-row HTML sketch</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md (the spec just written — sketch must mirror it)
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-01 locks design medium = HTML throwaways via /gsd-sketch)
  </read_first>
  <action>
    `mkdir -p .planning/sketches/08-video-mode-design/`

    Create `.planning/sketches/08-video-mode-design/compact-row-tokens.html` — a single-file
    HTML throwaway that renders the three slot orderings (Mines / Merge / Nonogram) at
    the spec'd token sizes. Use CSS custom properties with names that mirror the DesignKit
    tokens so a future reader can map them 1:1 to the spec.

    Required structure:
    - `:root { --radii-button: 12px; --spacing-s: 8px; --spacing-xl: 40px; }` (these are
      illustrative pixel APPROXIMATIONS for the sketch only — the spec doc remains
      token-name-only). Add a top-of-page note: "Sketch uses illustrative px values for
      browser rendering; spec doc 08-COMPACT-ROW-TOKENS.md is the contract."
    - Three rows (Minesweeper / Merge / Nonogram), each laying out:
      `[Back] [primary-info-chip] [picker-pill] [secondary-info-chip] [Settings]`
      with `gap: var(--spacing-s)` and picker pill using `border-radius: var(--radii-button); height: var(--spacing-xl);`.
    - Labels match D-08 exactly (e.g. Minesweeper picker pill reads "Reveal/Flag").
    - At the bottom of the page, a short legend mapping CSS variables → DesignKit tokens.

    Keep total file under 200 lines. No external assets — inline everything.
  </action>
  <acceptance_criteria>
    - test -f .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "radii-button" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "spacing-xl" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "spacing-s" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "Reveal/Flag" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "Mode picker\|Mode" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - grep -q "Fill/Mark\|Fill" .planning/sketches/08-video-mode-design/compact-row-tokens.html
    - wc -l .planning/sketches/08-video-mode-design/compact-row-tokens.html — line count <= 200
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/sketches/08-video-mode-design/compact-row-tokens.html && grep -q "radii-button" .planning/sketches/08-video-mode-design/compact-row-tokens.html && grep -q "spacing-xl" .planning/sketches/08-video-mode-design/compact-row-tokens.html && grep -q "spacing-s" .planning/sketches/08-video-mode-design/compact-row-tokens.html && grep -q "Reveal/Flag" .planning/sketches/08-video-mode-design/compact-row-tokens.html</automated>
  </verify>
  <done>HTML sketch renders all three slot orderings using CSS variables mirroring the DesignKit token vocabulary.</done>
</task>

</tasks>

<verification>
- Spec doc and HTML sketch both exist.
- Spec doc references the three D-05..D-07 tokens by name and never hardcodes a pt/px value.
- Sudoku appears only under "Out of Scope" (never as a fourth slot mapping).
- No file under `gamekit/` modified (SC5).
</verification>

<success_criteria>
- 08-COMPACT-ROW-TOKENS.md contains radii.button, spacing.xl, spacing.s, all three game slot mappings, and Sudoku Out-of-Scope note.
- `.planning/sketches/08-video-mode-design/compact-row-tokens.html` renders the three orderings.
- `git diff --name-only -- gamekit/` returns empty.
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-02-SUMMARY.md`.
</output>
