---
phase: 18-stats-design-specs-adr
plan: 02
subsystem: ui
tags: [swiftui, dynamic-type, accessibility, stats, score-card, theme]

# Dependency graph
requires:
  - phase: 18-01
    provides: ScoreStatsCard shared layout component consumed by StackStatsCard and SnakeStatsCard
provides:
  - "§8.12 + D-04 audit result recorded in 18-STATS-AUDIT.md"
  - "Fix: metric value text no longer wraps mid-number at large Dynamic Type (ScoreStatsCard.metricRow)"
  - "Screenshots: Classic + Voltage + AccessibilityXXL + empty state confirmed in audit doc"
affects: [18-03, 18-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Metric value text: .lineLimit(1) + .minimumScaleFactor(0.7) on numeric values in Grid columns prevents mid-number line breaks at large Dynamic Type"

key-files:
  created:
    - ".planning/phases/18-stats-design-specs-adr/18-STATS-AUDIT.md"
    - ".planning/phases/18-stats-design-specs-adr/screenshots/03-classic-large-dt/03c-fixed-axxxl-stack.png"
  modified:
    - "gamekit/gamekit/Screens/ScoreStatsCard.swift"

key-decisions:
  - "Fix applied to metricRow value Text only — label text is allowed to wrap (it contains words, not numbers); only numeric values must stay on one line"
  - "minimumScaleFactor(0.7) chosen as a reasonable lower bound — allows the font to shrink up to 30% before SwiftUI would need to truncate, which is sufficient for 6-7 digit scores in the trailing Grid column"
  - "Hero numeral sizing left unchanged per reviewer instruction — inverted hierarchy at AXXXL is an observation, not a defect"

patterns-established:
  - "D-04 pattern: numeric value Text in Grid trailing columns uses .lineLimit(1) + .minimumScaleFactor(0.7); apply to any future score/count metric rows"

requirements-completed: [ARCADE-07]

# Metrics
duration: 35min
completed: 2026-07-05
---

# Phase 18 Plan 02: Stats Card Legibility Audit Summary

**§8.12 + D-04 audit passed for ScoreStatsCard (Classic + Voltage); one mid-number wrap defect found and fixed with `.lineLimit(1)` + `.minimumScaleFactor(0.7)` on metric value text**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-07-05 (continuation from Task 1 agent)
- **Completed:** 2026-07-05
- **Tasks:** 2 (Task 1 prior agent; Task 2 this agent)
- **Files modified:** 3

## Accomplishments

- §8.12 Loud preset check passed: Voltage preset renders all ScoreStatsCard elements legibly (hero numeral, caption, border rule, metric rows)
- D-04 hero numeral overflow: 7-digit score `1234567` does not clip or wrap (fixed `titleLarge` = 32pt)
- D-04 metric value wrap: fixed mid-number line break for 6-digit values at AccessibilityXXL DT
- Empty state "No runs yet." confirmed legible in textTertiary on Classic preset
- Audit result recorded in 18-STATS-AUDIT.md with pass/fail table and screenshot references

## Task Commits

1. **Task 1: Capture screenshots across presets and DT** — `b11e803` (chore) — prior agent
2. **Task 2: Fix D-04 metric value wrap + re-capture** — `8b805aa` (fix)

**Plan metadata:** _(this commit)_

## Files Created/Modified

- `gamekit/gamekit/Screens/ScoreStatsCard.swift` — Added `.lineLimit(1)` + `.minimumScaleFactor(0.7)` to metric value `Text` in `metricRow` (fix, 2 lines)
- `.planning/phases/18-stats-design-specs-adr/18-STATS-AUDIT.md` — Updated with full audit Result section (pass/fail table, fix description, re-capture reference)
- `.planning/phases/18-stats-design-specs-adr/screenshots/03-classic-large-dt/03c-fixed-axxxl-stack.png` — Re-capture: STACK card at AccessibilityXXL, Classic preset, showing fixed metric values on single lines

## Decisions Made

- Fix scoped to the value `Text` only — label text is words and may wrap normally; only numeric values must be single-line
- `minimumScaleFactor(0.7)` chosen as a practical lower bound for 6-7 digit scores in a trailing Grid column
- Hero numeral `titleLarge` (fixed 32pt) left unchanged per explicit reviewer instruction — inverted hierarchy at AXXXL is accepted as an observation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed metric value mid-number line wrap at AccessibilityXXL Dynamic Type**
- **Found during:** Task 2 human-verify checkpoint — reviewer reported defect in Capture 03a
- **Issue:** `770325` (Average Score for Stack) was rendering as `77032` on line 1 and `5` on line 2 at AXXXL DT, making it appear as two separate numbers
- **Fix:** Added `.lineLimit(1)` + `.minimumScaleFactor(0.7)` to the value `Text` in `ScoreStatsCard.metricRow`; numeric values now stay on one line and scale down proportionally before clipping
- **Files modified:** `gamekit/gamekit/Screens/ScoreStatsCard.swift`
- **Verification:** Re-captured Stats/STACK at AccessibilityXXL (Classic preset, seeded store); `770325` renders as a single value on the right side; `635493` (Snake Average Score) also confirmed single-line
- **Committed in:** `8b805aa`

---

**Total deviations:** 1 auto-fixed (Rule 1 bug)
**Impact on plan:** Bug fix was required for D-04 compliance; no scope creep.

## Issues Encountered

- Simulator shut down twice during the re-capture run (CoreSimulator silent shutdown, see memory `reference_sim_visual_verification.md` §6). Required re-boot and re-setting DT + theme between runs. The SwiftData seeded store persisted across reboots.

## Known Stubs

None — this plan produces an audit doc and a bug fix, not UI stubs.

## Threat Flags

None — no new network surfaces, auth paths, or schema changes.

## Next Phase Readiness

- ScoreStatsCard metric value rendering is now D-04 compliant across all DT sizes
- 18-STATS-AUDIT.md is complete and ready for reference by 18-03 and 18-04
- Phase 18 plan 04 (timing / cold-start verification) can proceed

---
*Phase: 18-stats-design-specs-adr*
*Completed: 2026-07-05*
