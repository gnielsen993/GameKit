---
phase: 18-stats-design-specs-adr
plan: "04"
subsystem: verification
tags: [cold-start, instruments, arcade, lazy-init, structural-proof, baseline]

# Dependency graph
requires:
  - phase: 15-arcade-substrate-skeleton
    provides: "ArcadeLoopDriver substrate; 15-HUMAN-UAT.md pending Instruments item"
  - phase: 16-stack
    provides: "StackGameView, StackEngine — lazy-init targets inspected"
  - phase: 17-snake
    provides: "SnakeGameView, SnakeEngine — lazy-init targets inspected"
provides:
  - "Structural proof: no arcade engine or view state allocated at cold launch (all lazily constructed via HomeView navigationDestination)"
  - "18-COLD-START-BASELINE.md: structural proof complete + subjective ~200 ms timing baseline recorded honestly"
  - "15-HUMAN-UAT.md SC5 Instruments item retired with honest two-part closure note"
  - "ADR ARCADE-08 call-site alignment confirmed (D-12)"
affects:
  - 15-arcade-substrate-skeleton
  - phase-18-verification-close

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Structural lazy-init proof via navigationDestination closure inspection + App/ grep: no live-simulator required when SwiftUI guarantee is clear"
    - "Honesty-over-theater baseline recording: subjective estimate explicitly labeled as such; structural proof identified as load-bearing evidence"

key-files:
  created:
    - .planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md
  modified:
    - .planning/phases/15-arcade-substrate-skeleton/15-HUMAN-UAT.md

key-decisions:
  - "Structural inspection conclusive without DEBUG init-log: SwiftUI navigationDestination lazy-construction guarantee makes the allocation proof structural, not runtime (optional log step omitted)"
  - "ADR ARCADE-08 call-site comment in HomeView already matches 2026-07-02 amendment — no rewrite needed (D-12 confirmed)"
  - "D-09/D-10 honesty-over-theater: timing half closed via subjective ~200 ms developer estimate (not an Instruments trace); no device/iOS captured; baseline labeled explicitly as subjective estimate"
  - "Structural proof is load-bearing SC4 evidence; subjective timing is corroborating sanity-check only"
  - "Phase 15 SC5 UAT item retired honestly: retirement note states no formal Instruments session was performed"

patterns-established:
  - "Cold-start structural proof: grep App/ for engine/view names + inspect navigationDestination closure + cite line numbers in verification doc"
  - "Two-part SC4 closure: structural allocation proof (primary, structural guarantee) + subjective timing sanity-check (corroborating)"

requirements-completed: [ARCADE-08]

# Metrics
duration: continuation (Task 1 prior session ~5 min; Task 2 this session)
completed: 2026-07-06
---

# Phase 18 Plan 04: Cold-Start Baseline Summary

**SC4 closed via structural lazy-init proof (load-bearing) plus honest subjective ~200 ms estimate (corroborating); Phase 15 SC5 Instruments UAT item retired without false Instruments claim**

## Performance

- **Duration:** Task 1: ~5 min (2026-07-05); Task 2: continuation session (2026-07-06)
- **Started:** 2026-07-05T21:17:00Z (Task 1)
- **Completed:** 2026-07-06 (Task 2 resumption)
- **Tasks:** 2 of 2 complete
- **Files modified:** 2

## Accomplishments

- Inspected `HomeView.destination(for:)` lines 359-407: `StackGameView()` and `SnakeGameView()` constructed only inside `.navigationDestination(for: GameRoute.self)` closure (line 102) — SwiftUI lazy-construction guarantee means neither is allocated at scene build time.
- Grepped all 3 `App/` files (`GameKitApp.swift`, `AppInfo.swift`, `DummyDataSeeder.swift`) for `StackEngine|SnakeEngine|StackGameView|SnakeGameView` — ZERO hits.
- Filled in `18-COLD-START-BASELINE.md` Canonical Baseline section honestly: developer subjective self-estimate of ~200 ms, no device/iOS version captured, method explicitly labeled as NOT an Instruments trace; structural proof identified as load-bearing SC4 evidence.
- Retired `15-HUMAN-UAT.md` SC5 pending Instruments item with an honest retirement note documenting two-part closure and explicitly stating no formal Instruments session was performed.
- Confirmed `HomeView.destination(for:)` already contains the correct ARCADE-08 amendment comment (D-12 — no rewrite needed).

## Task Commits

1. **Task 1: Structural cold-start proof (lazy-init inspection)** — `1283da3` (docs) — prior session
2. **Task 2: Record canonical baseline + retire Phase 15 UAT item** — `89d9c55` (docs)

**Plan metadata:** (this commit)

## Files Created/Modified

- `.planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md` — Structural proof section (Task 1); Canonical Baseline and Phase 15 UAT Retirement sections completed (Task 2)
- `.planning/phases/15-arcade-substrate-skeleton/15-HUMAN-UAT.md` — SC5 item status changed from `pending` to `retired`; retirement note added with explicit statement that no Instruments session was performed; summary counts updated (pending: 0, retired: 1); file status changed to `retired`

## Decisions Made

- **Structural proof is load-bearing, timing is corroborating** — The allocation half of SC4 is closed by SwiftUI's structural `navigationDestination` lazy-construction guarantee, not by a runtime measurement. The ~200 ms subjective estimate validates the guarantee translates to a perceptibly fast launch, but it is not the primary evidence.
- **Honesty-over-theater (D-09/D-10)** — The developer did not run a formal Instruments session. The baseline records what actually happened: a subjective self-estimate. No device model, iOS version, or run count was captured. The method is labeled explicitly.
- **Phase 15 SC5 retired honestly** — The retirement note in `15-HUMAN-UAT.md` documents the actual closure mechanism rather than claiming a formal session that did not occur.
- **Future Instruments trace optional** — A future precise Instruments session may supersede the subjective estimate if a hard numeric regression anchor is later needed. This is noted in the baseline doc.

## Deviations from Plan

The plan's Task 2 acceptance criteria required a real-device Instruments session with "median ms, device model, and iOS version." The user provided a subjective self-estimate (~200 ms) instead, per the resume instructions (honesty-over-theater requirement).

Handling: the Canonical Baseline section explicitly labels the method as "developer subjective self-estimate," states it is NOT an Instruments trace, identifies the structural proof as load-bearing, and notes that a future Instruments session may supersede the estimate. The Phase 15 UAT retirement note is similarly honest.

This is a user-directed scope adjustment, not an auto-fix deviation. No deviation rules were triggered.

**Total deviations:** 1 (user-directed — timing half closed by subjective estimate rather than Instruments trace, per resume instructions)
**Impact on plan:** ARCADE-08 requirement satisfied. SC4 allocation half closed structurally (conclusive). SC4 timing half closed by corroborating subjective evidence with honest caveat.

## Issues Encountered

None — files updated cleanly, commit landed without hook failures.

## Known Stubs

None — this plan creates documentation artifacts, not product code.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary surfaces introduced.

## Next Phase Readiness

Phase 18 Plan 04 is the final plan in Phase 18 (stats-design-specs-adr). Phase 18 is complete. The v1.5 milestone (Endless Arcade Primitive — Phases 15–18) is complete.

---
*Phase: 18-stats-design-specs-adr*
*Completed: 2026-07-06*
