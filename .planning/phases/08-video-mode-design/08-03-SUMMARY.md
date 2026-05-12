---
phase: 08-video-mode-design
plan: 03
subsystem: ui
tags: [design-spec, video-mode, banner, win-loss, accessibility, dkbutton, reduce-motion]

# Dependency graph
requires:
  - phase: 05-polish
    provides: "Haptics/SFX first-guard contract (05-03 D-10) and Reduce-Motion surface-level lock (05-06 D-04) — banner inherits both"
  - phase: 06.1-pre-release-polish-home-cards-2-per-row-grid-mines-flag-mode
    provides: "Reveal/Flag FAB `radii.button` consumer (06.1-02) — banner pill radius matches"
  - phase: 08-video-mode-design
    provides: "08-CONTEXT.md D-09..D-12 decisions resolved before this plan"
provides:
  - "08-BANNER-PLACEMENT.md — 6-row opposite-of-PiP anchor table + shape/action/a11y spec"
  - "Phase 13 consumes this spec by name for SC1–SC5"
  - "HTML sketch visualising the 6 PiP/banner pairings"
affects: [phase-13-win-loss-banner, phase-09-video-mode-store, phase-04-layout-doc]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Design spec doc-only output, no gamekit/ code (Phase 8 SC5)"
    - "Single-rule lookup table (6 rows) instead of derived logic — easier verify-by-diff"
    - "Throwaway HTML sketch under .planning/sketches/ (D-01 medium)"

key-files:
  created:
    - .planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md
    - .planning/sketches/08-video-mode-design/banner-placement.html
  modified: []

key-decisions:
  - "Banner anchor = opposite-of-PiP (D-09) — 6-row deterministic mapping, downstream agents read the table"
  - "Banner shape = pill, full-width-minus-margins, radii.button + spacing.m margin (D-10)"
  - "Primary action = explicit DKButton inside banner; never tap-banner-to-trigger (D-11, VIDEO-11 SC2)"
  - "Reduce-Motion = dampen to identity (D-12, mirrors v1.0 05-06 D-04)"
  - "Banner haptics/SFX guarded by hapticsEnabled/sfxEnabled FIRST inside firing surfaces (v1.0 05-03 D-10 contract)"

patterns-established:
  - "Opposite-of-PiP rule table: 6 PiP locations → 6 banner anchors, no derivation"
  - "Primary-action lives on DKButton, not on container surface (avoids tap-anywhere antipattern)"
  - "Banner motion gating mirrors existing v1.0 surface-level Reduce-Motion lock"

requirements-completed: []

# Metrics
duration: 2min
completed: 2026-05-12
---

# Phase 8 Plan 03: Banner Placement Summary

**Win/loss banner design locked: 6-row opposite-of-PiP anchor table + pill shape (`radii.button`) + embedded `DKButton` action + dampen-to-identity Reduce-Motion + first-guard haptics/SFX gating — ready for Phase 13 consumption by name.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-12T21:42:36Z
- **Completed:** 2026-05-12T21:44:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Authored `08-BANNER-PLACEMENT.md` — the durable design lock Phase 13 SC1–SC5 derive from.
- Built `banner-placement.html` throwaway sketch — 6 device-frame thumbnails showing each PiP location paired with its opposite-edge banner anchor and an embedded `DKButton` pill.
- Re-stated v1.0 05-03 D-10 (haptics/SFX first-guard) and v1.0 05-06 D-04 (Reduce-Motion surface lock) inside the banner spec so Phase 13 implementers do not re-derive the pattern.
- Locked out the tap-anywhere-on-banner antipattern forbidden by REQUIREMENTS VIDEO-11 SC2.
- Zero `gamekit/` files touched — Phase 8 SC5 holds.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author 08-BANNER-PLACEMENT.md spec** — `15d32d6` (docs)
2. **Task 2: Build banner-placement HTML sketch** — `2fae9d4` (docs)

**Plan metadata commit:** to follow (SUMMARY + STATE/ROADMAP update).

## Files Created/Modified

- `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` — Banner placement spec (anchor table, shape, action, Reduce-Motion, haptics/SFX gating, source decisions, consumed-by). 70 lines.
- `.planning/sketches/08-video-mode-design/banner-placement.html` — 6-thumbnail HTML sketch, inline CSS only, 233 lines, back-link to spec.

## Decisions Made

All four decisions consumed (not made) — they were pre-resolved in `08-CONTEXT.md`:

- **D-09** opposite-of-PiP — converted to a 6-row markdown table in the spec; mirrored visually in the HTML sketch.
- **D-10** pill, full-width-minus-margins — added concrete token anchors (`radii.button`, `spacing.m`) so Phase 13 has zero ambiguity.
- **D-11** DKButton inside banner — accompanied by an explicit FORBIDDEN line ruling out tap-anywhere-on-banner-to-trigger, satisfying VIDEO-11 SC2.
- **D-12** dampen to identity — surface-level rules enumerated (`.transition(.identity)`, `value: 0`, `trigger: false`) with explicit "see v1.0 05-06 D-04" pointer.

One small wording adjustment was made during execution (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Reworded D-11 Source-decisions line to satisfy forbidden-pattern check**

- **Found during:** Task 1 acceptance verification
- **Issue:** The plan's task body and CONTEXT D-11 both use the phrase "tap-banner-to-reveal" as the name of the forbidden pattern. But the same plan's acceptance criterion is `grep -iE "tap.*banner.*reveal" must return NO matches`. Including the literal phrase anywhere in the spec — even when defining what is forbidden — would fail acceptance.
- **Fix:** Kept the FORBIDDEN block in the Primary action section but phrased the prohibition as "tap-anywhere-on-banner-to-trigger-action pattern". Reworded the Source decisions D-11 bullet to "the action surface is the button, not the whole banner." Semantics preserved; literal regex hit avoided.
- **Files modified:** `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md`
- **Verification:** All 9 acceptance greps pass; `tap.*banner.*reveal` returns zero matches.
- **Committed in:** `15d32d6` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 plan-self-contradiction smoothed)
**Impact on plan:** Cosmetic only — the meaning of D-11 (no tap-anywhere-on-banner action) is fully preserved and explicitly forbidden in the spec. No scope creep.

## Issues Encountered

- `.planning/STATE.md` was already in the working tree with uncommitted edits at plan start (parallel plan 08-02 is running). Left STATE.md untouched during task work and will update it after committing my own files, per the parallel-write protocol in the spawn objective.

## User Setup Required

None — design-only artifacts.

## Next Phase Readiness

- **For Plan 08-04 (layout doc):** can cite `08-BANNER-PLACEMENT.md` by name and pull the 6-row anchor table directly into the layout-doc annotations.
- **For Phase 13:** SC1 (non-board-covering), SC2 (one-tap reachable action), SC3 (haptics), SC4 (SFX), SC5 (animation+Reduce-Motion) all map onto explicit sections in the spec. No prose-mining required.
- **No blockers.**

## Self-Check: PASSED

Files exist:

- FOUND: `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md`
- FOUND: `.planning/sketches/08-video-mode-design/banner-placement.html`
- FOUND: `.planning/phases/08-video-mode-design/08-03-SUMMARY.md` (this file)

Commits exist:

- FOUND: `15d32d6` (Task 1)
- FOUND: `2fae9d4` (Task 2)

Spec greps:

- "opposite-of-PiP": yes
- "DKButton": yes
- "accessibilityReduceMotion": yes
- "hapticsEnabled": yes
- "sfxEnabled": yes
- 6 PiP-location-label matches: yes
- "dampen": yes
- forbidden `tap.*banner.*reveal`: zero matches

SC5 (no gamekit/ code):

- `git diff --name-only` since plan start, scoped to `gamekit/`: empty

---

*Phase: 08-video-mode-design*
*Completed: 2026-05-12*
