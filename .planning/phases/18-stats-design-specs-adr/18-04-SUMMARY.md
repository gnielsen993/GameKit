---
phase: 18-stats-design-specs-adr
plan: "04"
subsystem: verification
tags: [cold-start, instruments, arcade, lazy-init, structural-proof]

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
  - "18-COLD-START-BASELINE.md with structural section complete; canonical timing section pending Task 2 Instruments session"
  - "ADR ARCADE-08 call-site alignment confirmed (D-12)"
affects:
  - 15-arcade-substrate-skeleton
  - phase-18-verification-close

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Structural lazy-init proof via navigationDestination closure inspection + App/ grep: no live-simulator required when SwiftUI guarantee is clear"

key-files:
  created:
    - .planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md
  modified: []

key-decisions:
  - "Structural inspection conclusive without DEBUG init-log: SwiftUI navigationDestination lazy-construction guarantee makes the allocation proof structural, not runtime (optional log step omitted)"
  - "ADR ARCADE-08 call-site comment in HomeView already matches 2026-07-02 amendment — no rewrite needed (D-12 confirmed)"
  - "This session records the FIRST canonical cold-start baseline for GameDrawer — no v1.4 numeric anchor exists (D-10)"

patterns-established:
  - "Cold-start structural proof: grep App/ for engine/view names + inspect navigationDestination closure + cite line numbers in verification doc"

requirements-completed: [ARCADE-08]

# Metrics
duration: 5min
completed: 2026-07-05
---

# Phase 18 Plan 04: Cold-Start Structural Proof + Canonical Baseline Summary

**Allocation half of SC4 closed structurally: zero arcade/engine state allocated at launch (lazy navigationDestination); canonical timing baseline recorded pending user Instruments session (Task 2 blocking checkpoint)**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-05T21:17:00Z
- **Completed:** 2026-07-05T21:22:53Z (Task 1 only; Task 2 pending)
- **Tasks:** 1 of 2 complete (Task 2 = blocking human checkpoint)
- **Files created:** 1

## Accomplishments

- Inspected `HomeView.destination(for:)` lines 359-407: `StackGameView()` and `SnakeGameView()` constructed only inside `.navigationDestination(for: GameRoute.self)` closure (line 102) — SwiftUI lazy-construction guarantee means neither is allocated at scene build time.
- Grepped all 3 `App/` files (`GameKitApp.swift`, `AppInfo.swift`, `DummyDataSeeder.swift`) for `StackEngine|SnakeEngine|StackGameView|SnakeGameView` — ZERO hits.
- Confirmed `HomeView.destination(for:)` already contains the correct ARCADE-08 amendment comment (D-12 — no rewrite needed).
- Wrote `18-COLD-START-BASELINE.md` with the "Structural proof" section; "Canonical baseline" section left pending for Task 2.

## Task Commits

1. **Task 1: Structural cold-start proof** — `1283da3` (docs)
2. **Task 2: Instruments session** — PENDING (blocking human checkpoint)

**Plan metadata:** pending (will commit after Task 2 completes)

## Files Created/Modified

- `.planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md` — Structural proof + pending baseline template; structural section complete

## Decisions Made

- Skipped optional `#if DEBUG` init-log: the `navigationDestination` lazy-construction guarantee is structural — code inspection is conclusive without running the simulator.
- Confirmed D-12: ARCADE-08 call-site comment in `HomeView.destination(for:)` already matches the 2026-07-02 amendment. No changes to `HomeView.swift` or the ADR itself.

## Deviations from Plan

None — plan executed exactly as written. The optional DEBUG init-log (Task 1 action 3) was omitted because the structural inspection alone satisfies the acceptance criteria; this is explicitly permitted by the plan's "Optionally" wording.

## Issues Encountered

None.

## Known Stubs

None — this plan creates a documentation artifact, not product code.

## Threat Flags

None — no new network endpoints, auth paths, or trust-boundary surfaces introduced.

## Next Phase Readiness

- Task 2 is a **blocking human checkpoint** — requires a real-device Instruments App Launch session.
- Once the user provides median launch time (ms) + device model + iOS version:
  - `18-COLD-START-BASELINE.md` "Canonical baseline" section will be completed.
  - `15-HUMAN-UAT.md` pending SC5 item will be retired with a pointer to this doc.
  - Phase 18 Plan 04 will be fully closed.

---
*Phase: 18-stats-design-specs-adr*
*Completed: 2026-07-05 (Task 1 only; Task 2 blocking checkpoint pending)*
