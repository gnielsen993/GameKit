---
phase: 08-video-mode-design
plan: 06
type: execute
wave: 4
depends_on: [08-01, 08-02, 08-03, 08-04, 08-05]
files_modified:
  - .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
autonomous: false
requirements: []
user_setup: []

must_haves:
  truths:
    - "08-DESIGN-LOCK.md exists with Gabe's explicit sign-off recorded"
    - "Doc enumerates all four design artifacts and confirms each exists"
    - "Doc confirms zero files under gamekit/ were modified during Phase 8 (SC5)"
    - "Doc names the unblock target: Phase 9 can begin"
  artifacts:
    - path: ".planning/phases/08-video-mode-design/08-DESIGN-LOCK.md"
      provides: "Phase 8 exit gate — design locked, Phase 9 unblocked"
      contains: "design locked"
  key_links:
    - from: ".planning/phases/08-video-mode-design/08-DESIGN-LOCK.md"
      to: ".planning/STATE.md"
      via: "STATE.md advances from Phase 8 to Phase 9 only after this file lands"
      pattern: "Phase 9"
---

<objective>
Close Phase 8 with the design-lock sign-off. Verify all four design artifacts
(VIDEO-MODE-LAYOUTS.md, 08-HARD-MINES-ADR.md, 08-COMPACT-ROW-TOKENS.md,
08-BANNER-PLACEMENT.md) exist and pass their content checks. Verify no `gamekit/`
file was touched during Phase 8 (SC5). Record Gabe's "design locked" signal.

Purpose: Phase 8 SC5 — "The phase exit is a 'design locked — Phase 9 can begin'
sign-off by Gabe." ROADMAP §Phase 8 says "Phase 9 cannot begin first."

Output: One markdown doc. Phase 9 is unblocked the moment it lands.
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
</context>

<tasks>

<task type="auto">
  <name>Task 1: Pre-flight artifact audit</name>
  <read_first>
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md (08-04 output)
    - .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md (08-05 output)
    - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md (08-02 output)
    - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md (08-03 output)
    - Docs/screenshots/v1.2-design/README.md (08-01 output)
  </read_first>
  <action>
    Run a single-shot audit script (inline bash) that confirms:

    1. All four artifact files exist.
    2. The 10 expected screenshots are present in `Docs/screenshots/v1.2-design/`.
    3. The four key spec strings are present:
       - VIDEO-MODE-LAYOUTS.md contains `08-HARD-MINES-ADR.md` (Hard defers to ADR)
       - 08-HARD-MINES-ADR.md contains `06.1-03` (deconfliction note)
       - 08-COMPACT-ROW-TOKENS.md contains `radii.button` and `spacing.xl` and `spacing.s`
       - 08-BANNER-PLACEMENT.md contains `opposite-of-PiP` and `DKButton` and `accessibilityReduceMotion`
    4. No file under `gamekit/` has been modified during Phase 8. Run:
       `git diff --name-only main -- gamekit/ 2>/dev/null` (or against the Phase 8 start ref if Phase 8 was branched). Expected: empty output.

       Fallback for solo-dev workflow on `main`: list any working-tree mods under `gamekit/`:
       `git status --porcelain -- gamekit/ | head`
       Expected: empty (no staged or unstaged Phase-8-related changes).

    If any check fails, abort the plan and emit a structured failure note listing
    which artifact / string / file is missing. Do NOT proceed to the sign-off task
    in that case.
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - test -f .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - test -f .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - test -f .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - test "$(ls Docs/screenshots/v1.2-design/*.png 2>/dev/null | wc -l | tr -d ' ')" = "10"
    - grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - grep -q "06.1-03" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -q "radii.button" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - grep -q "opposite-of-PiP" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - test -z "$(git status --porcelain -- gamekit/ 2>/dev/null)"  (no working-tree changes under gamekit/)
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md && test -f .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && test -f .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && test -f .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && test "$(ls Docs/screenshots/v1.2-design/*.png 2>/dev/null | wc -l | tr -d ' ')" = "10" && grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md && grep -q "06.1-03" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -q "radii.button" .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md && grep -q "opposite-of-PiP" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md</automated>
  </verify>
  <done>All four artifacts exist; all required strings present; no app-code drift.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Design-lock sign-off</name>
  <read_first>
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md
    - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - .planning/sketches/08-video-mode-design/*.html (the throwaway sketch corpus)
  </read_first>
  <what-built>
    Phase 8 produced four design artifacts that Phases 9–13 consume by name:
    - VIDEO-MODE-LAYOUTS.md (SC1) — 5 games x 6 PiP zones annotated, Classic + Dracula screenshots referenced per game.
    - 08-HARD-MINES-ADR.md (SC2) — one chosen Hard strategy + rejected-alternatives evidence + rollback + 06.1-03 deconfliction.
    - 08-COMPACT-ROW-TOKENS.md (SC3) — picker pill `radii.button`, height `spacing.xl`, gap `spacing.s`, per-game slot mappings for Mines/Merge/Nonogram (Sudoku Out of Scope).
    - 08-BANNER-PLACEMENT.md (SC4) — 6-row opposite-of-PiP anchor table, DKButton primary action, dampen-to-identity Reduce-Motion, haptics/SFX gating restated.

    Plus a sketch corpus under `.planning/sketches/08-video-mode-design/` documenting
    the design exploration (compact-row tokens, banner placement, 5 per-game layout
    overlays, 4 Hard-Mines candidate variants).

    No file under `gamekit/` was modified (SC5).
  </what-built>
  <how-to-verify>
    Gabe's review checklist:

    1. Open each of the four artifact files. Confirm each tells a complete story
       for its concern. Specifically:
       - VIDEO-MODE-LAYOUTS.md: walk the 5 game sections, confirm each lists all
         6 PiP zones with a "controls / board" note for each.
       - 08-HARD-MINES-ADR.md: confirm the §Decision section names the variant
         you actually picked in Plan 08-05's checkpoint, the §Rollback condition
         is something you'd actually trigger on, and the §Interaction section
         mentions `06.1-03` and `MagnifyGesture`.
       - 08-COMPACT-ROW-TOKENS.md: confirm token names match what you expect
         (radii.button / spacing.xl / spacing.s) and the three slot mappings read
         correctly.
       - 08-BANNER-PLACEMENT.md: confirm the 6-row anchor table maps PiP zones
         to banner positions the way you expect ("opposite-of-PiP").

    2. (Optional) Open each `.planning/sketches/08-video-mode-design/*.html` in a
       browser to sanity-check the visual representations.

    3. Confirm no `gamekit/` file changed during Phase 8 (`git status -- gamekit/`
       should be clean).

    4. Reply with one of:
       - `design locked` — Phase 9 unblocked, Claude writes 08-DESIGN-LOCK.md.
       - Specific revisions (e.g. "ADR §Decision rationale needs to mention X" or
         "VIDEO-MODE-LAYOUTS.md Merge section is missing the Small BR note") —
         Claude updates the affected artifact and re-prompts.

    Do NOT type `design locked` if any artifact still feels incomplete; the cost
    of unlocking Phase 9 prematurely is downstream phases re-deriving design.
  </how-to-verify>
  <action>
    Claude actions before checkpoint: list the four artifacts and the sketch
    directory contents to the chat, then wait.

    Claude actions after Gabe types `design locked`: proceed to Task 3.

    Claude actions after Gabe requests revisions: scope the revision to the
    smallest possible diff (one artifact at a time), apply, re-run that
    artifact's grep checks from its parent plan's acceptance_criteria, then
    re-prompt this checkpoint.
  </action>
  <verify>
    <automated>echo "Awaiting Gabe's 'design locked' signal — checkpoint task, no automated gate."</automated>
  </verify>
  <done>Gabe replies `design locked`.</done>
  <resume-signal>Gabe types `design locked` or lists specific revisions.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Write 08-DESIGN-LOCK.md</name>
  <read_first>
    - The four artifact files (re-read to embed accurate references)
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (CONTEXT D-01..D-13 — list which decisions landed in which artifact)
    - .planning/ROADMAP.md §Phase 8 SC1–SC5 (the exit-gate contract)
  </read_first>
  <action>
    Create `.planning/phases/08-video-mode-design/08-DESIGN-LOCK.md` with this structure:

    ```
    # Phase 8 — Design Lock

    **Signed off:** {YYYY-MM-DD}  (today's date — use `date +%Y-%m-%d`)
    **Status:** design locked — Phase 9 unblocked.

    ## Artifacts shipped

    | Artifact | SC | Locks decisions |
    |---|---|---|
    | `VIDEO-MODE-LAYOUTS.md` | SC1 | CONTEXT D-02, D-03, D-04 (screenshot source / preset / device); REQUIREMENTS VIDEO-02 (6 zones). |
    | `08-HARD-MINES-ADR.md` | SC2 | CONTEXT D-13 (Hard strategy) + the ADR's own decision. |
    | `08-COMPACT-ROW-TOKENS.md` | SC3 | CONTEXT D-05, D-06, D-07, D-08 (picker pill tokens + slot mappings). |
    | `08-BANNER-PLACEMENT.md` | SC4 | CONTEXT D-09, D-10, D-11, D-12 (anchor / shape / action / Reduce-Motion). |

    ## SC5 — no app-code drift

    `git status --porcelain -- gamekit/` returns empty at sign-off time. Phase 8 wrote
    zero files under the `gamekit/` Xcode target. All sketches are under
    `.planning/sketches/08-video-mode-design/` and are explicitly throwaway per
    CONTEXT D-01.

    ## Sketch corpus (provenance)

    All HTML throwaways live under `.planning/sketches/08-video-mode-design/`:
    - `compact-row-tokens.html` (08-02)
    - `banner-placement.html` (08-03)
    - `layout-mines-easy.html` / `layout-mines-medium.html` / `layout-mines-hard.html` / `layout-merge.html` / `layout-nonogram.html` (08-04)
    - `hard-mines-smaller-cells.html` / `hard-mines-scroll-pan.html` / `hard-mines-pinch-zoom.html` / `hard-mines-warning-compromise.html` (08-05)

    Sketches are NOT promoted to `gamekit/`. They exist as design-trace only.

    ## Unblocked

    Phase 9 (Video Mode Foundation) can now begin. Phase 9 consumes:
    - `08-COMPACT-ROW-TOKENS.md` directly when building `VideoCompactControlRow` (Phase 9 SC4).
    - `VIDEO-MODE-LAYOCKS.md` for Settings-copy framing of the 6-zone vocabulary (Phase 9 SC3).

    Phase 11 (Minesweeper Adoption) is conditionally blocked on Phase 10 + on this
    ADR — see `08-HARD-MINES-ADR.md` §Consumed by for whether the chosen variant
    triggers the Phase 11 research-phase per ROADMAP §v1.2 Research Flags.

    Phase 13 (Win/Loss Banner) consumes `08-BANNER-PLACEMENT.md` for SC1–SC5.

    ## Sign-off

    Gabe Nielsen — {YYYY-MM-DD} — "design locked".
    ```

    (Fix the typo placeholder `VIDEO-MODE-LAYOCKS.md` to `VIDEO-MODE-LAYOUTS.md`
    when writing.)

    Replace `{YYYY-MM-DD}` with today's date in two places.
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "design locked" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "Phase 9 unblocked" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "VIDEO-MODE-LAYOUTS.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "08-COMPACT-ROW-TOKENS.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "08-BANNER-PLACEMENT.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - grep -q "no app-code drift\|SC5" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md
    - ! grep -q "VIDEO-MODE-LAYOCKS" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md  (typo guarded)
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && grep -q "design locked" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && grep -q "VIDEO-MODE-LAYOUTS.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && grep -q "08-HARD-MINES-ADR.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && grep -q "08-COMPACT-ROW-TOKENS.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && grep -q "08-BANNER-PLACEMENT.md" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md && ! grep -q "VIDEO-MODE-LAYOCKS" .planning/phases/08-video-mode-design/08-DESIGN-LOCK.md</automated>
  </verify>
  <done>Sign-off doc exists; lists every artifact and SC; asserts SC5 (no app-code drift); declares Phase 9 unblocked.</done>
</task>

</tasks>

<verification>
- All four upstream artifacts pass their grep checks.
- 08-DESIGN-LOCK.md records sign-off date + zero-drift assertion + Phase 9 unblock.
- No file under `gamekit/` modified (SC5).
</verification>

<success_criteria>
- 08-DESIGN-LOCK.md exists with all required strings.
- All four upstream artifacts referenced by name.
- `git status --porcelain -- gamekit/` returns empty.
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-06-SUMMARY.md`.
</output>
