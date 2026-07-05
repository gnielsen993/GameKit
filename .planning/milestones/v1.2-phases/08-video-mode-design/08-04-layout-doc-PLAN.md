---
phase: 08-video-mode-design
plan: 04
type: execute
wave: 2
depends_on: [08-01]
files_modified:
  - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
  - .planning/sketches/08-video-mode-design/layout-mines-easy.html
  - .planning/sketches/08-video-mode-design/layout-mines-medium.html
  - .planning/sketches/08-video-mode-design/layout-mines-hard.html
  - .planning/sketches/08-video-mode-design/layout-merge.html
  - .planning/sketches/08-video-mode-design/layout-nonogram.html
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "VIDEO-MODE-LAYOUTS.md exists and references all 10 screenshots from 08-01"
    - "Document covers Mines Easy, Mines Medium, Mines Hard, Merge, Nonogram — exactly five games/difficulties"
    - "Each of the 5 game sections has all 6 PiP zones annotated (Large top, Large bottom, Small TL, Small TR, Small BL, Small BR)"
    - "Per zone, a 'where controls go, what happens to the board' note is present"
    - "Both Classic and Dracula screenshot references are embedded for each game (CONTEXT D-03 + CLAUDE.md §8.12 legibility audit rule)"
    - "Mines Hard section explicitly defers the strategy choice to 08-HARD-MINES-ADR (Plan 08-05) — does NOT pre-decide"
    - "Five per-game HTML sketches under .planning/sketches/08-video-mode-design/ visualize the 6-zone overlay"
  artifacts:
    - path: ".planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md"
      provides: "Screenshot-annotated layout doc — Phase 8 SC1 anchor artifact"
      contains: "Small TL"
    - path: ".planning/sketches/08-video-mode-design/layout-mines-hard.html"
      provides: "Hard 16x30 baseline overlay sketch — feeds 08-05 ADR variant exploration"
  key_links:
    - from: ".planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md"
      to: "Docs/screenshots/v1.2-design/"
      via: "Layout doc embeds and annotates the 10 screenshots from 08-01"
      pattern: "Docs/screenshots/v1\\.2-design/.*\\.png"
    - from: ".planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md"
      to: ".planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md"
      via: "Mines Hard section defers strategy decision to 08-05 ADR"
      pattern: "08-HARD-MINES-ADR\\.md"
---

<objective>
Produce the screenshot-annotated layout doc that Phase 8 SC1 anchors on. For each
of 5 games (Mines E/M/H + Merge + Nonogram), embed both Classic + Dracula
screenshots from 08-01, overlay all 6 PiP zones, and write a per-zone control/board
movement note. Mines Hard intentionally defers the *strategy* choice to 08-05 — this
plan documents the baseline squeeze; 08-05 chooses the fix.

Purpose: Phase 8 SC1 — "VIDEO-MODE-LAYOUTS.md exists with Gabe's current screenshots
of Mines Easy, Mines Medium, Mines Hard, Merge, and Nonogram, each marked with all 6
PiP zones overlaid, plus a per-game / per-zone 'where the controls go, what happens
to the board' note." Phases 9–12 consume this doc by name.

Output: One markdown doc + five HTML sketches (one per game). No `gamekit/` code (SC5).
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
@Docs/screenshots/v1.2-design/README.md
</context>

<interfaces>
The six PiP locations from REQUIREMENTS VIDEO-02 (frozen vocabulary):
- Large top
- Large bottom
- Small TL (top-left)
- Small TR (top-right)
- Small BL (bottom-left)
- Small BR (bottom-right)

Layout behavior rules (plan-doc §Layout behavior — restate verbatim per section):
- Small PiP: avoid the covered corner; move controls; keep board in normal layout.
- Large PiP: reserve top or bottom band; fit board between band and control row;
  controls collapse before board becomes unplayable (§Compromise order).
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Author VIDEO-MODE-LAYOUTS.md</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-02, D-03, D-04, D-13 — Hard strategy defers to 08-05)
    - Docs/GameDrawer-v1.2-Video-Mode-Plan.md (§Layout behavior, §Game-specific notes, §Compromise order)
    - Docs/screenshots/v1.2-design/README.md (confirm 10 screenshots landed from 08-01)
    - .planning/ROADMAP.md §Phase 8 SC1 (verbatim — every PiP zone overlaid, per-game/per-zone notes)
    - .planning/REQUIREMENTS.md (VIDEO-02 — the 6 location vocabulary)
  </read_first>
  <action>
    Create `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` with this structure:

    ```
    # Phase 8 — Video Mode Layout Annotations

    Source screenshots: Docs/screenshots/v1.2-design/ (per CONTEXT D-02).
    Device: iPhone 17 Pro Max (CONTEXT D-04). Presets: Classic + Dracula (CONTEXT D-03; CLAUDE.md §8.12).

    Per Plan-doc §Core rule: Small PiP = control-aware; Large PiP = board-aware.
    Compromise order (plan-doc §Compromise order): board > critical info > picker > settings/secondary > time > board shrink/scroll.

    ## Six PiP zones (REQUIREMENTS VIDEO-02)

    1. Large top
    2. Large bottom
    3. Small TL
    4. Small TR
    5. Small BL
    6. Small BR

    ## Per-game annotation
    ```

    Then five h2 sections, one per game, each with this EXACT shape:

    ```
    ## Minesweeper — Easy (9x9 / 10 mines)

    Screenshots: `Docs/screenshots/v1.2-design/mines-easy-classic.png` · `mines-easy-dracula.png`
    Sketch: `.planning/sketches/08-video-mode-design/layout-mines-easy.html`

    | PiP zone | Where controls go | What happens to the board |
    |---|---|---|
    | Large top    | Compact row at bottom edge; back/info/picker/time/settings consolidated.        | Board fits between reserved top band and compact row. Easy fits comfortably. |
    | Large bottom | Compact row at top edge; same slot order.                                       | Board fits between top row and reserved bottom band. Easy fits comfortably. |
    | Small TL     | Move back/icon-buttons out of top-left into top-right or compact row.           | Board unchanged. |
    | Small TR     | Move settings out of top-right into top-left or compact row.                    | Board unchanged. |
    | Small BL     | Move any bottom-left FAB/picker affordances to bottom-right.                    | Board unchanged. |
    | Small BR     | Move Reveal/Flag FAB (06.1-02) and bottom-right affordances to bottom-left.     | Board unchanged. |
    ```

    Repeat the shape for:
    - `## Minesweeper — Medium (16x16 / 40 mines)` — screenshots `mines-medium-classic.png` / `mines-medium-dracula.png`; sketch `layout-mines-medium.html`.
      Notes: Large top/bottom may start to feel tight; Compromise order step 4 (collapse settings into menu) may kick in. Small zones still keep board unchanged.
    - `## Minesweeper — Hard (16x30 / 99 mines)` — screenshots `mines-hard-classic.png` / `mines-hard-dracula.png`; sketch `layout-mines-hard.html`.
      Notes for each row MUST state the squeeze symptom (e.g. "Large top: insufficient board height for current fixed cell size; STRATEGY DEFERRED to `08-HARD-MINES-ADR.md` per CONTEXT D-13").
      Add an explicit subsection at the END of this game's section:
      ```
      ### Strategy decision deferred

      Per CONTEXT D-13, the Hard-Minesweeper strategy (smaller cells / scroll-pan /
      pinch-zoom / warning+compromise) is NOT pre-decided in this document. The
      decision lives in `08-HARD-MINES-ADR.md` (Plan 08-05), which uses the same
      screenshots and the `layout-mines-hard.html` baseline as inputs.

      The ADR MUST deconflict with the existing A11Y-05 / 06.1-03 MagnifyGesture +
      auto-scale system (CONTEXT D-13).
      ```
    - `## Merge` — screenshots `merge-classic.png` / `merge-dracula.png`; sketch `layout-merge.html`.
      Notes: Square board easier to fit; large PiP may only require vertical compression of compact row.
    - `## Nonogram` — screenshots `nonogram-classic.png` / `nonogram-dracula.png`; sketch `layout-nonogram.html`.
      Notes: Hints + board need careful space management; Large top/bottom is the worst case (matches plan-doc §Game-specific notes — Nonogram).

    After the 5 game sections, add:

    ```
    ## Cross-game summary

    | Game / difficulty | Hardest PiP cases |
    |---|---|
    | Mines Easy     | none (all 6 zones fit). |
    | Mines Medium   | Large top / Large bottom (Compromise order kicks in). |
    | Mines Hard     | Large top / Large bottom (squeeze case — see 08-HARD-MINES-ADR.md). |
    | Merge          | Large top / Large bottom (vertical compression). |
    | Nonogram       | Large top / Large bottom (hint legibility at risk). |

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
    ```

    HARD RULES:
    - Exactly 5 game h2 sections — Mines Easy, Mines Medium, Mines Hard, Merge, Nonogram.
    - Each section's table MUST have exactly 6 rows (one per PiP zone).
    - Mines Hard section MUST contain the phrase "STRATEGY DEFERRED" or "Strategy decision deferred" and reference `08-HARD-MINES-ADR.md`.
    - Both Classic + Dracula screenshot filenames MUST be referenced for every game.
    - Sudoku MUST NOT appear (REQUIREMENTS §v1.2 Out of Scope).
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - grep -c "^## Minesweeper — Easy\|^## Minesweeper — Medium\|^## Minesweeper — Hard\|^## Merge\|^## Nonogram" returns 5
    - grep -c "mines-easy-classic.png\|mines-easy-dracula.png\|mines-medium-classic.png\|mines-medium-dracula.png\|mines-hard-classic.png\|mines-hard-dracula.png\|merge-classic.png\|merge-dracula.png\|nonogram-classic.png\|nonogram-dracula.png" returns 10
    - grep -ciE "Large top|Large bottom|Small TL|Small TR|Small BL|Small BR" returns >= 30 (6 zones x 5 games minimum)
    - grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - grep -qiE "deferred|defer" Mines-Hard section (the phrase appears at least once)
    - grep -i "Sudoku" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md returns NO matches
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md && test "$(grep -cE '^## Minesweeper — Easy|^## Minesweeper — Medium|^## Minesweeper — Hard|^## Merge|^## Nonogram' .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md)" = "5" && test "$(grep -ciE 'Large top|Large bottom|Small TL|Small TR|Small BL|Small BR' .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md)" -ge 30 && grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md && ! grep -qi "Sudoku" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md</automated>
  </verify>
  <done>5 game sections, 6 zones each, both presets referenced per game, Hard defers to ADR, no Sudoku.</done>
</task>

<task type="auto">
  <name>Task 2: Build 5 per-game overlay HTML sketches</name>
  <read_first>
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md (the doc just written)
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-01 — HTML throwaway medium)
    - Docs/screenshots/v1.2-design/README.md (filename list)
  </read_first>
  <action>
    `mkdir -p .planning/sketches/08-video-mode-design/`

    Create five HTML files. Each renders a single device-frame thumbnail of the
    target game/difficulty with all 6 PiP zone overlays toggleable (radio buttons
    or 6 stacked thumbnails work — pick whichever is simpler).

    Files:
    - `.planning/sketches/08-video-mode-design/layout-mines-easy.html` (references mines-easy-classic.png as bg)
    - `.planning/sketches/08-video-mode-design/layout-mines-medium.html`
    - `.planning/sketches/08-video-mode-design/layout-mines-hard.html` (CRITICAL — baseline for 08-05)
    - `.planning/sketches/08-video-mode-design/layout-merge.html`
    - `.planning/sketches/08-video-mode-design/layout-nonogram.html`

    Each file must:
    - Reference its source screenshot via a relative path like `../../../Docs/screenshots/v1.2-design/mines-easy-classic.png` (use `background-image` or `<img>`).
    - Label all 6 PiP zones (Large top, Large bottom, Small TL, Small TR, Small BL, Small BR) — either as 6 mini-frames or as a single frame with togglable overlays.
    - Footer back-link to `../../phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md`.
    - Stay under 250 lines each. Inline CSS only.

    The `layout-mines-hard.html` file MUST additionally contain a top-of-page note:
    "Strategy decision deferred to 08-HARD-MINES-ADR.md (Plan 08-05). This sketch
    shows only the baseline squeeze."
  </action>
  <acceptance_criteria>
    - test -f .planning/sketches/08-video-mode-design/layout-mines-easy.html
    - test -f .planning/sketches/08-video-mode-design/layout-mines-medium.html
    - test -f .planning/sketches/08-video-mode-design/layout-mines-hard.html
    - test -f .planning/sketches/08-video-mode-design/layout-merge.html
    - test -f .planning/sketches/08-video-mode-design/layout-nonogram.html
    - For every file: grep -ciE "Large top|Large bottom|Small TL|Small TR|Small BL|Small BR" returns >= 6
    - grep -q "08-HARD-MINES-ADR.md" .planning/sketches/08-video-mode-design/layout-mines-hard.html
    - Each file is <= 250 lines.
  </acceptance_criteria>
  <verify>
    <automated>for f in layout-mines-easy.html layout-mines-medium.html layout-mines-hard.html layout-merge.html layout-nonogram.html; do test -f ".planning/sketches/08-video-mode-design/$f" || exit 1; test "$(grep -ciE 'Large top|Large bottom|Small TL|Small TR|Small BL|Small BR' ".planning/sketches/08-video-mode-design/$f")" -ge 6 || exit 1; done && grep -q "08-HARD-MINES-ADR.md" .planning/sketches/08-video-mode-design/layout-mines-hard.html</automated>
  </verify>
  <done>Five per-game HTML sketches exist; each labels all 6 PiP zones; Hard sketch defers strategy.</done>
</task>

</tasks>

<verification>
- Layout doc + 5 sketches all exist.
- Every game/difficulty has all 6 PiP zones annotated.
- Hard section defers strategy to 08-05 ADR — does NOT pre-decide.
- Sudoku absent from all artifacts.
- No `gamekit/` files touched (SC5).
</verification>

<success_criteria>
- VIDEO-MODE-LAYOUTS.md passes all acceptance grep checks.
- 5 sketch files exist, each with 6 PiP-zone labels.
- Hard sketch + Hard section in doc both reference 08-HARD-MINES-ADR.md.
- `git diff --name-only -- gamekit/` returns empty.
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-04-SUMMARY.md`.
</output>
