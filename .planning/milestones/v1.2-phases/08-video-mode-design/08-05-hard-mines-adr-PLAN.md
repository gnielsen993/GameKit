---
phase: 08-video-mode-design
plan: 05
type: execute
wave: 3
depends_on: [08-01, 08-04]
files_modified:
  - .planning/sketches/08-video-mode-design/hard-mines-smaller-cells.html
  - .planning/sketches/08-video-mode-design/hard-mines-scroll-pan.html
  - .planning/sketches/08-video-mode-design/hard-mines-pinch-zoom.html
  - .planning/sketches/08-video-mode-design/hard-mines-warning-compromise.html
  - .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
autonomous: false
requirements: []
user_setup: []

must_haves:
  truths:
    - "Four HTML sketch variants exist — one per candidate strategy (smaller cells / scroll-pan / pinch-zoom / warning+compromise)"
    - "08-HARD-MINES-ADR.md exists and names the four candidates"
    - "ADR contains a 'Decision' or 'Chosen' section identifying exactly ONE winning strategy"
    - "ADR contains screenshot evidence of the three rejected alternatives (the three sketch HTMLs not chosen, plus references back to Docs/screenshots/v1.2-design/mines-hard-*.png)"
    - "ADR contains a one-sentence rollback condition"
    - "ADR explicitly addresses the A11Y-05 / 06.1-03 MagnifyGesture + auto-scale deconfliction (CONTEXT D-13)"
    - "ADR is named in the doc body so Phase 11 SC2 can reference it ('Phase 08 Hard-Mines ADR' or '08-HARD-MINES-ADR.md')"
  artifacts:
    - path: ".planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md"
      provides: "The strategy lock for Hard 16x30 Video Mode — Phase 11 SC2 derives directly from it"
      contains: "06.1-03"
    - path: ".planning/sketches/08-video-mode-design/hard-mines-smaller-cells.html"
      provides: "Candidate variant 1: smaller cells"
    - path: ".planning/sketches/08-video-mode-design/hard-mines-scroll-pan.html"
      provides: "Candidate variant 2: scroll/pan"
    - path: ".planning/sketches/08-video-mode-design/hard-mines-pinch-zoom.html"
      provides: "Candidate variant 3: pinch-zoom"
    - path: ".planning/sketches/08-video-mode-design/hard-mines-warning-compromise.html"
      provides: "Candidate variant 4: warning + compromise"
  key_links:
    - from: ".planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md"
      to: ".planning/phases/11-minesweeper-adoption/ (future)"
      via: "Phase 11 SC2 references this ADR by name; alternatives must NOT be re-debated"
      pattern: "06\\.1-03|MagnifyGesture|A11Y-05"
---

<objective>
Resolve CONTEXT D-13 (the only intentionally open decision in Phase 8): pick ONE
Hard-Minesweeper Video-Mode strategy from {smaller cells / scroll-pan / pinch-zoom /
warning+compromise}, record the choice with rationale + rejected-alternative
screenshot evidence + a one-sentence rollback + an explicit deconfliction note for
the existing A11Y-05 / 06.1-03 MagnifyGesture + auto-scale system.

Purpose: Phase 8 SC2 — without this ADR, Phase 11 cannot ship the Hard adoption.
Phase 11 SC2 explicitly says "the rejected alternatives are NOT re-debated in this
phase" — the debate happens here, once, with screenshot evidence backing it.

Output: 4 candidate HTML sketches + 1 ADR markdown. Gabe picks the winner via the
checkpoint task. No `gamekit/` code (SC5).
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
@.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
@Docs/GameDrawer-v1.2-Video-Mode-Plan.md
@CLAUDE.md
@Docs/screenshots/v1.2-design/README.md

@.planning/phases/06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode/06.1-03-PLAN.md
</context>

<interfaces>
The four candidate strategies (plan-doc §Minesweeper "Possible directions to explore"):

1. **Smaller cells** — Hard board renders at a smaller cell size in Video Mode so the full 16x30 grid plus reserved PiP band + compact control row all fit on iPhone 17 Pro Max without scrolling.
2. **Scroll/pan** — Hard board keeps its current cell size; a scroll/pan gesture lets the user move the viewport. May conflict with MagnifyGesture from 06.1-03.
3. **Pinch-zoom** — User pinch-zooms to fit. ALREADY EXISTS as A11Y-05 (06.1-03). Question is whether Video Mode triggers an automatic-zoom-out on entry or relies on the user.
4. **Warning + compromise** — Hard + Large PiP shows a one-time warning ("Video Mode works best with small PiP on Hard") and applies the Compromise order (collapse settings/secondary into a menu, hide time chip) without resizing cells.

Existing A11Y-05 / 06.1-03 interaction surface (the deconfliction target):
- `MagnifyGesture` lets the user pinch the Mines board.
- Auto-scale `cellSize` fits the board to width on entry (the v1.0 06.1-03 GREEN).
- A scroll/pan addition (candidate 2) would need to compose with the existing pinch
  without gesture collision. A "smaller cells in Video Mode" addition (candidate 1)
  would need to re-run auto-scale with a smaller min-cell constant when Video Mode is
  on.
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Build 4 candidate-strategy HTML sketches</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-13 — the decision belongs in this plan)
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md (Hard section + sketch baseline)
    - .planning/phases/06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode/06.1-03-PLAN.md (MagnifyGesture + auto-scale surface)
    - Docs/GameDrawer-v1.2-Video-Mode-Plan.md (§Minesweeper "Possible directions to explore")
    - Docs/screenshots/v1.2-design/README.md (locate mines-hard-classic.png + mines-hard-dracula.png paths)
  </read_first>
  <action>
    `mkdir -p .planning/sketches/08-video-mode-design/`

    Create four HTML files — each a single-file throwaway under 250 lines, inline
    CSS only. Each one renders the SAME baseline screenshot
    (`../../../Docs/screenshots/v1.2-design/mines-hard-classic.png`) with the
    Large-top PiP overlay (the worst case from VIDEO-MODE-LAYOUTS.md) applied,
    THEN demonstrates that variant's approach:

    1. `.planning/sketches/08-video-mode-design/hard-mines-smaller-cells.html`:
       - Top of page: "Variant 1: Smaller cells in Video Mode"
       - Mock the 16x30 grid at a SMALLER cell size so it fits below the Large-top band + above the compact row.
       - Annotate: "min cell size constant reduced when Video Mode is on; auto-scale re-runs."
       - Note A11Y-05 / 06.1-03 interaction: "MagnifyGesture preserved; pinch still works to expand."

    2. `.planning/sketches/08-video-mode-design/hard-mines-scroll-pan.html`:
       - Top of page: "Variant 2: Scroll/pan in Video Mode"
       - Mock the 16x30 grid at NORMAL cell size, clipped to a viewport with scroll indicators.
       - Annotate: "Cell size unchanged; user pans horizontally and/or vertically."
       - Note A11Y-05 / 06.1-03 interaction: "Gesture composition with existing MagnifyGesture: scroll/pan = single-finger drag, pinch = two-finger; specify simultaneous vs exclusive in ADR."

    3. `.planning/sketches/08-video-mode-design/hard-mines-pinch-zoom.html`:
       - Top of page: "Variant 3: Pinch-zoom in Video Mode"
       - Mock the same 16x30 with a "zoom out to fit" callout — user invokes existing A11Y-05.
       - Annotate: "On Video Mode entry, optionally auto-fit (single-shot animation), then user manages with existing pinch."
       - Note A11Y-05 / 06.1-03 interaction: "This variant REUSES the existing system — no new gesture; only a one-time auto-fit on Video Mode entry."

    4. `.planning/sketches/08-video-mode-design/hard-mines-warning-compromise.html`:
       - Top of page: "Variant 4: Warning + compromise"
       - Mock the same 16x30 at NORMAL cell size, but with the Compromise order applied: time chip hidden, settings collapsed into menu, secondary info hidden.
       - Add a small banner overlay text: "Video Mode works best with small PiP on Hard."
       - Annotate: "No cell resize, no scroll, no new gesture. Existing A11Y-05 pinch still available as escape hatch."
       - Note A11Y-05 / 06.1-03 interaction: "Zero change to existing pinch/auto-scale system. Lowest deconfliction risk."

    All four files must include a footer back-link to
    `../../phases/08-video-mode-design/08-HARD-MINES-ADR.md` and a "candidate
    variant N of 4" header so they can be browsed side-by-side.
  </action>
  <acceptance_criteria>
    - test -f .planning/sketches/08-video-mode-design/hard-mines-smaller-cells.html
    - test -f .planning/sketches/08-video-mode-design/hard-mines-scroll-pan.html
    - test -f .planning/sketches/08-video-mode-design/hard-mines-pinch-zoom.html
    - test -f .planning/sketches/08-video-mode-design/hard-mines-warning-compromise.html
    - For each: grep -q "06.1-03\|MagnifyGesture\|A11Y-05" (deconfliction note present)
    - For each: grep -q "08-HARD-MINES-ADR.md" (back-link present)
    - Each file <= 250 lines.
  </acceptance_criteria>
  <verify>
    <automated>for f in hard-mines-smaller-cells.html hard-mines-scroll-pan.html hard-mines-pinch-zoom.html hard-mines-warning-compromise.html; do test -f ".planning/sketches/08-video-mode-design/$f" || exit 1; grep -qE "06\.1-03|MagnifyGesture|A11Y-05" ".planning/sketches/08-video-mode-design/$f" || exit 1; grep -q "08-HARD-MINES-ADR.md" ".planning/sketches/08-video-mode-design/$f" || exit 1; done</automated>
  </verify>
  <done>Four candidate sketches exist; each names the existing pinch/auto-scale system; each links back to the ADR file.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 2: Decision — Gabe picks the winning Hard-Mines strategy</name>
  <read_first>
    - The four sketches from Task 1 (all under .planning/sketches/08-video-mode-design/hard-mines-*.html)
    - Docs/screenshots/v1.2-design/mines-hard-classic.png + mines-hard-dracula.png (baseline squeeze)
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md (Hard section)
    - .planning/phases/06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode/06.1-03-PLAN.md (existing pinch surface)
  </read_first>
  <decision>Which Hard-Minesweeper Video-Mode strategy does v1.2 ship?</decision>
  <context>
    CONTEXT D-13 intentionally deferred this decision to design execution. The four
    candidate variants are now sketched. Gabe reviews the sketches against the real
    Hard screenshots and picks one. The pick locks the ADR — Phase 11 implements
    exactly the chosen approach and does NOT re-debate alternatives.

    Key trade-off axes per variant (from §interfaces above):

    | Variant | Deconfliction risk vs 06.1-03 | New gesture? | New code surface area |
    |---|---|---|---|
    | Smaller cells | Low — auto-scale re-runs with smaller min | No | Small (one constant + Video-Mode-aware path) |
    | Scroll/pan | High — gesture composition with pinch | Yes | Medium (new gesture + viewport state) |
    | Pinch-zoom | None — reuses existing system | No | Tiny (optional one-shot auto-fit on entry) |
    | Warning + compromise | None — no gesture or layout change | No | Small (one banner + Compromise-order branch) |
  </context>
  <options>
    <option id="smaller-cells">
      <name>Smaller cells (Variant 1)</name>
      <pros>Full board visible in Video Mode without any new gesture or warning copy. Auto-scale infrastructure (06.1-03) already exists.</pros>
      <cons>Cells may approach a fat-finger floor on Hard 16x30 at Large-top/bottom; legibility on Dracula preset needs verification. Mines/flags icons may need a smaller variant.</cons>
    </option>
    <option id="scroll-pan">
      <name>Scroll/pan (Variant 2)</name>
      <pros>Cell size unchanged — touch targets stay identical to non-Video-Mode play.</pros>
      <cons>Highest deconfliction risk with existing MagnifyGesture from 06.1-03. Adds a new gesture (single-finger drag for scroll). Phase 11 Conditional Research flag triggers if this variant wins.</cons>
    </option>
    <option id="pinch-zoom">
      <name>Pinch-zoom — reuse A11Y-05 (Variant 3)</name>
      <pros>Lowest code surface — reuses the existing system. Optional one-shot auto-fit on Video Mode entry is the only new behavior.</pros>
      <cons>Discoverability: user must know pinch works. Without auto-fit, Hard + Large PiP may render unplayable at first glance and frustrate the user before they pinch.</cons>
    </option>
    <option id="warning-compromise">
      <name>Warning + compromise (Variant 4)</name>
      <pros>Zero gesture or layout-engine changes. Existing A11Y-05 still available as user-driven escape hatch. Lowest engineering risk and ships in a single Phase 11 plan.</pros>
      <cons>Concedes that Hard + Large PiP isn't a great experience — relies on user heeding the warning and either changing PiP or living with cramped layout. Adds one localized copy string.</cons>
    </option>
  </options>
  <action>
    Claude actions: present the four sketches + their trade-off rows to Gabe, wait for the resume-signal, then capture the selected variant ID into a session variable that Task 3 reads as "the decision". Do not write the ADR in this task — Task 3 owns that. If Gabe replies with a variant ID plus rationale, preserve the rationale verbatim for Task 3 to embed in §Decision. If Gabe replies with the variant ID only, Task 3 generates a default rationale tied to the trade-off axes above.
  </action>
  <resume-signal>Reply with one of: `smaller-cells`, `scroll-pan`, `pinch-zoom`, `warning-compromise`. Optionally add rationale; if omitted, Claude writes a default rationale tied to the trade-off axes above.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Write 08-HARD-MINES-ADR.md</name>
  <read_first>
    - The decision from Task 2 (one of: smaller-cells / scroll-pan / pinch-zoom / warning-compromise)
    - The four sketches from Task 1
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-13 — ADR content requirements)
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md (cross-reference Hard section)
    - .planning/phases/06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode/06.1-03-PLAN.md (pinch + auto-scale surface)
    - .planning/ROADMAP.md §Phase 11 SC2 (consumer rule — alternatives NOT re-debated)
  </read_first>
  <action>
    Create `.planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md` with EXACTLY these sections in order:

    1. `# Phase 08 Hard-Mines ADR — Video Mode Strategy for Hard 16x30`
    2. `## Status` paragraph: "Decided 2026-05-{date}. Locks the Hard Minesweeper Video Mode strategy. Phase 11 SC2 references this ADR by name and MUST NOT re-debate the rejected alternatives."
    3. `## Context` paragraph: restate the Hard squeeze problem (16x30 fixed grid + Large-top/bottom PiP = insufficient screen space at current cell size on iPhone 17 Pro Max). Reference `Docs/screenshots/v1.2-design/mines-hard-classic.png` and `mines-hard-dracula.png` as evidence. Reference `VIDEO-MODE-LAYOUTS.md` Hard section.
    4. `## Candidates considered` — four h3 subsections, ONE per variant. Each includes:
       - Variant name (matching Task 1 file names)
       - Link to the variant sketch (relative path)
       - One-paragraph behavior description
       - Pros bullet list (3-4 items)
       - Cons bullet list (3-4 items)
    5. `## Decision` — `**Chosen:** <variant-name>`. One-paragraph rationale tying the choice to the Pros/Cons in the prior section.
    6. `## Rejected alternatives` — bulleted list of the three NOT-chosen variants, each with a one-sentence "rejected because…" reason. Include the link to each rejected variant's sketch as the "screenshot evidence" required by CONTEXT D-13.
    7. `## Interaction with A11Y-05 / 06.1-03 MagnifyGesture + auto-scale system` — REQUIRED section per CONTEXT D-13. State explicitly:
       - What the existing system does (pinch + auto-fit-to-width on entry).
       - How the chosen variant composes with it (preserves / replaces / extends).
       - If the chosen variant adds a new gesture, the composition rule (e.g. "scroll = single-finger drag, pinch = two-finger; both gestures simultaneous via `.simultaneousGesture(...)`").
    8. `## Rollback condition` — ONE sentence. Format: "If <observable failure mode> appears during Phase 11 verification or TestFlight feedback, revert this ADR and pick <next-best variant from §Decision>."
    9. `## Consumed by`:
       - Phase 11 SC2 (Minesweeper adoption — implements chosen variant exactly).
       - Phase 11 SC3 (Hard validation against same screenshots used in this ADR).
       - v1.2 Research Flags §Phase 11 — research is CONDITIONAL on the variant; clarify whether the chosen variant triggers it (scroll-pan / pinch-zoom = yes; smaller-cells / warning-compromise = no).
    10. `## Source decisions`: CONTEXT D-13 + this ADR's own decision.

    HARD RULES:
    - The phrase `06.1-03` MUST appear in the §Interaction section.
    - The phrase `MagnifyGesture` MUST appear in the §Interaction section.
    - All four candidate names MUST appear (smaller cells, scroll-pan, pinch-zoom, warning+compromise — exact spelling).
    - The phrase `rollback` MUST appear (in §Rollback condition).
    - The phrase `Chosen` or `chosen` MUST appear in §Decision.
    - The doc title MUST start with `# Phase 08 Hard-Mines ADR` so Phase 11 SC2 can grep for the canonical name.

    Phase 11 research-flag note (from ROADMAP §v1.2 Research Flags):
    - If `scroll-pan` or `pinch-zoom` is chosen, the §Consumed by entry MUST say
      "triggers Phase 11 research-phase per ROADMAP §v1.2 Research Flags".
    - If `smaller-cells` or `warning-compromise` is chosen, §Consumed by MUST say
      "does NOT trigger Phase 11 research-phase per ROADMAP §v1.2 Research Flags;
      Phase 11 proceeds direct to planning".
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -q "^# Phase 08 Hard-Mines ADR" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -q "06.1-03" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -q "MagnifyGesture" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qiE "smaller.cells" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qiE "scroll.pan|scroll/pan" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qiE "pinch.zoom" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qiE "warning.compromise|warning \+ compromise" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qi "rollback" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -qi "chosen" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
    - grep -q "Phase 11" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -q "^# Phase 08 Hard-Mines ADR" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -q "06.1-03" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -q "MagnifyGesture" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qiE "smaller.cells" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qiE "scroll.pan|scroll/pan" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qiE "pinch.zoom" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qiE "warning.compromise|warning \+ compromise" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qi "rollback" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md && grep -qi "chosen" .planning/phases/08-video-mode-design/08-HARD-MINES-ADR.md</automated>
  </verify>
  <done>ADR exists, names all four candidates, identifies exactly one chosen, includes rollback + 06.1-03 deconfliction note + Phase 11 research-flag mapping.</done>
</task>

</tasks>

<verification>
- All four candidate HTML sketches exist.
- ADR exists and passes every grep check.
- ADR is consumable by Phase 11 SC2 (alternatives NOT re-debated downstream).
- A11Y-05 / 06.1-03 interaction explicitly addressed (CONTEXT D-13).
- No `gamekit/` files touched (SC5).
</verification>

<success_criteria>
- 4 sketch HTMLs + 1 ADR markdown all exist.
- ADR's §Decision identifies exactly one variant.
- ADR's §Interaction names `06.1-03` and `MagnifyGesture`.
- ADR's §Rollback contains a single rollback-condition sentence.
- `git diff --name-only -- gamekit/` returns empty.
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-05-SUMMARY.md`.
</output>
