---
phase: 08-video-mode-design
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
  - .planning/sketches/08-video-mode-design/banner-placement.html
autonomous: true
requirements: []
user_setup: []

must_haves:
  truths:
    - "08-BANNER-PLACEMENT.md exists with the 6-row opposite-of-PiP anchor table (D-09)"
    - "Banner shape locked as pill, full-width-minus-margins (D-10)"
    - "Primary action surface locked as DKButton inside the banner (D-11) — never tap-banner-to-reveal"
    - "Reduce-Motion handling is dampen-to-identity (D-12) — mirrors v1.0 05-06 D-04"
    - "Haptics/SFX/animation gating restated for the banner: hapticsEnabled / sfxEnabled / accessibilityReduceMotion are first guards"
    - "An HTML sketch renders the 6 PiP-location/banner-anchor pairings"
  artifacts:
    - path: ".planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md"
      provides: "Banner placement spec — Phase 13 consumes by name"
      contains: "opposite-of-PiP"
    - path: ".planning/sketches/08-video-mode-design/banner-placement.html"
      provides: "Throwaway HTML sketch — 6 PiP/banner pairings visualized"
  key_links:
    - from: ".planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md"
      to: ".planning/phases/13-win-loss-banner/ (future)"
      via: "Phase 13 SC1..SC5 derive directly from this spec"
      pattern: "DKButton|accessibilityReduceMotion|hapticsEnabled|sfxEnabled"
---

<objective>
Lock the non-board-covering win/loss banner design at the placement, shape, action,
and a11y-gating levels. CONTEXT D-09..D-12 are already resolved — this plan converts
those four decisions into the durable spec Phase 13 consumes by name.

Purpose: Phase 8 SC4 — every one of the 6 PiP zones must have a "banner goes here,
primary action goes here, board stays visible" annotation + restated gating policy.

Output: One markdown spec + one HTML sketch. No `gamekit/` code touched (SC5).
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

@.planning/phases/05-polish/05-03-PLAN.md
@.planning/phases/05-polish/05-06-PLAN.md
</context>

<interfaces>
Pattern parent contracts the banner spec must restate.

From v1.0 `Core/Haptics.swift` (05-03 D-10):
- `Haptics.fire(_:)` guards on `settingsStore.hapticsEnabled` FIRST inside the firing surface.
- New banner haptic surfaces MUST replicate this — the toggle is the first line of the function body, not an external wrapper.

From v1.0 `Core/SFXPlayer.swift` (05-03 D-10):
- `SFXPlayer.play(_:)` guards on `settingsStore.sfxEnabled` FIRST.
- Configured with `AVAudioSession.ambient` (does NOT duck user music).
- Default `sfxEnabled == false` (matches MINES-10).

From v1.0 05-06 D-04 (animation pass):
- `.transition(.opacity)` collapses to `.transition(.identity)` when `accessibilityReduceMotion == true`.
- `.symbolEffect(.bounce, value: trigger)` collapses to `value: 0` when Reduce Motion is on.
- `.keyframeAnimator(initialValue:, trigger:)` collapses to `trigger: false` when Reduce Motion is on.

From DesignKit:
- `DKButton` is the primary-action surface used everywhere in v1.0.
- No new button component is rolled for the banner (CLAUDE.md §2 promotion rule).
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Author 08-BANNER-PLACEMENT.md spec</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-09, D-10, D-11, D-12 verbatim)
    - Docs/GameDrawer-v1.2-Video-Mode-Plan.md (§Win/loss screens — hybrid minimal banner)
    - .planning/phases/05-polish/05-03-PLAN.md (haptics/SFX first-guard pattern parent)
    - .planning/phases/05-polish/05-06-PLAN.md (Reduce-Motion surface-level gating pattern parent)
    - CLAUDE.md §1 (any haptics/SFX/animation respects user settings + a11y)
  </read_first>
  <action>
    Create `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` with these EXACT sections in order:

    1. `# Phase 8 — Win/Loss Banner Placement` (h1)
    2. `## Status` paragraph: "Design lock for Phase 13. Replaces the v1.0 full-screen win/loss overlays with a non-board-covering banner per plan-doc §Win/loss screens. Board stays visible behind the banner in all 6 PiP locations."
    3. `## Anchor table (D-09 opposite-of-PiP rule)` with a markdown table — six rows:
       | PiP location | Banner docks |
       Row 1: Large top    -> bottom edge
       Row 2: Large bottom -> top edge
       Row 3: Small TL     -> bottom-right
       Row 4: Small TR     -> bottom-left
       Row 5: Small BL     -> top-right
       Row 6: Small BR     -> top-left
       Add caption: "One rule, six outcomes. Downstream agents read the table — do not re-derive."
    4. `## Shape (D-10)`:
       - Pill, full-width-minus-margins along its anchor edge.
       - Small vertical footprint — board remains fully visible behind it (the rule that defines Video Mode).
       - Reads as chrome, not as a modal.
       - Corner radius: `radii.button` (consistency with the picker pill anchor from 08-COMPACT-ROW-TOKENS.md D-05).
       - Horizontal margin: `spacing.m` from screen edge.
    5. `## Primary action (D-11)`:
       - Explicit `DKButton` embedded inside the banner ("Play Again" / "Continue").
       - Visible affordance — one-tap reachable from the moment the banner appears.
       - VoiceOver-friendly (standard DKButton accessibility traits).
       - FORBIDDEN: any tap-banner-to-reveal-action pattern (REQUIREMENTS VIDEO-11 SC2).
    6. `## Reduce-Motion handling (D-12)`:
       - Banner motion dampens to identity when `accessibilityReduceMotion == true`.
       - Concrete surface-level rules (mirrors 05-06 D-04):
         - `.transition(.opacity)` collapses to `.transition(.identity)` when Reduce Motion is on.
         - Confetti / sweep / spring collapse to no-op (`trigger: false` / `value: 0`).
         - Static banner appears immediately, no animated entrance.
       - Reference: "see v1.0 05-06 D-04 for the surface-level lock pattern".
    7. `## Haptics & SFX gating (restated for the banner)`:
       - Win-banner haptic — guarded by `settingsStore.hapticsEnabled` FIRST, inside the firing surface (v1.0 05-03 D-10 contract).
       - Loss-banner haptic — same guard.
       - Win/loss banner SFX — guarded by `settingsStore.sfxEnabled` FIRST. Plays on `AVAudioSession.ambient` (does NOT duck user music). Default OFF per MINES-10.
       - Optional confetti — gated by Reduce Motion AND any future `animationsEnabled` toggle.
    8. `## Out of scope`:
       - Auto-dismiss timer behavior (Phase 13 decides).
       - Banner stack handling for back-to-back wins (Phase 13 decides).
       - Per-game banner copy variations (Phase 13 decides — design phase only locks placement/shape/action/a11y).
    9. `## Source decisions` bulleted list: D-09, D-10, D-11, D-12.
    10. `## Consumed by` bulleted list:
        - Phase 13 SC1 — non-board-covering banner in all 3 games across all 6 PiP locations.
        - Phase 13 SC2 — primary action one-tap reachable (D-11 lock).
        - Phase 13 SC3 — haptics gating.
        - Phase 13 SC4 — SFX gating.
        - Phase 13 SC5 — animation + Reduce Motion gating.

    HARD RULES:
    - Anchor table MUST have exactly six location/dock rows.
    - The phrase "opposite-of-PiP" MUST appear.
    - The phrase "DKButton" MUST appear.
    - The phrase "accessibilityReduceMotion" MUST appear.
    - The phrases "hapticsEnabled" AND "sfxEnabled" MUST both appear.
    - Forbidden pattern: any phrasing suggesting tap-banner-to-reveal-action.
  </action>
  <acceptance_criteria>
    - test -f .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -q "opposite-of-PiP" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -q "DKButton" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -q "accessibilityReduceMotion" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -q "hapticsEnabled" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -q "sfxEnabled" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -cE "Large top|Large bottom|Small TL|Small TR|Small BL|Small BR" returns >= 6
    - grep -q "dampen" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - grep -iE "tap.*banner.*reveal|tap.*to.*expand.*card" must return NO matches
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && grep -q "opposite-of-PiP" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && grep -q "DKButton" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && grep -q "accessibilityReduceMotion" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && grep -q "hapticsEnabled" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && grep -q "sfxEnabled" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md && ! grep -qiE "tap.*banner.*reveal" .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md</automated>
  </verify>
  <done>6-row anchor table + DKButton + Reduce-Motion + haptics/SFX gating all present; no tap-banner-to-reveal phrasing.</done>
</task>

<task type="auto">
  <name>Task 2: Build banner-placement HTML sketch</name>
  <read_first>
    - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md (the spec just written)
    - .planning/phases/08-video-mode-design/08-CONTEXT.md (D-01 design medium = HTML throwaway)
  </read_first>
  <action>
    `mkdir -p .planning/sketches/08-video-mode-design/`

    Create `.planning/sketches/08-video-mode-design/banner-placement.html` — a single-file
    HTML throwaway that lays out 6 device-frame thumbnails (2 columns x 3 rows or 3 cols x 2
    rows), each labeled with its PiP location and showing:
    - A grey "PiP" rectangle at the labeled location (Large top/bottom = wide band; Small
      TL/TR/BL/BR = small square in the labeled corner).
    - A blue pill labeled "Play Again" at the opposite anchor per the D-09 table.
    - A faint "board" rectangle filling the remaining area so the "board stays visible"
      property is obvious at a glance.

    Add a footer note linking to `../../phases/08-video-mode-design/08-BANNER-PLACEMENT.md`
    as the source of truth.

    Keep total file under 250 lines. No external assets — inline CSS only.
  </action>
  <acceptance_criteria>
    - test -f .planning/sketches/08-video-mode-design/banner-placement.html
    - grep -ciE "Large top|Large bottom|Small TL|Small TR|Small BL|Small BR" returns >= 6
    - grep -q "Play Again" .planning/sketches/08-video-mode-design/banner-placement.html
    - grep -q "08-BANNER-PLACEMENT.md" .planning/sketches/08-video-mode-design/banner-placement.html
    - wc -l line count <= 250
  </acceptance_criteria>
  <verify>
    <automated>test -f .planning/sketches/08-video-mode-design/banner-placement.html && test "$(grep -ciE 'Large top|Large bottom|Small TL|Small TR|Small BL|Small BR' .planning/sketches/08-video-mode-design/banner-placement.html)" -ge 6 && grep -q "Play Again" .planning/sketches/08-video-mode-design/banner-placement.html</automated>
  </verify>
  <done>HTML sketch renders 6 PiP/banner pairings; back-link to spec present.</done>
</task>

</tasks>

<verification>
- Spec doc and HTML sketch both exist.
- Spec doc contains the 6-row anchor table, DKButton, accessibilityReduceMotion, hapticsEnabled, sfxEnabled.
- No file under `gamekit/` modified (SC5).
</verification>

<success_criteria>
- 08-BANNER-PLACEMENT.md contains all required strings (see acceptance_criteria).
- `.planning/sketches/08-video-mode-design/banner-placement.html` renders 6 PiP/banner pairings.
- `git diff --name-only -- gamekit/` returns empty.
</success_criteria>

<output>
After completion, create `.planning/phases/08-video-mode-design/08-03-SUMMARY.md`.
</output>
