---
phase: 15-arcade-substrate-skeleton
plan: "01"
subsystem: core
tags: [swift6, swiftui, timelineview, arcade, game-loop, unit-tests]

requires: []
provides:
  - "ArcadeGameState: Foundation-only nonisolated enum (idle/running/paused/gameOver)"
  - "ArcadeLoopDriver: SwiftUI ViewModifier with TimelineView(.animation) and min(rawDt, 0.1) clamp"
  - "Two locked substrate gate tests: onTickGating (SC1a) + spiralOfDeathClamp (SC1b)"
affects:
  - "15-02 (harness views consume .arcadeLoop modifier and ArcadeGameState)"
  - "16-stack-game (StackGameView replaces harness, StackVM adopts ArcadeGameState)"
  - "17-snake-game (SnakeGameView replaces harness, SnakeVM adopts ArcadeGameState)"

tech-stack:
  added: []
  patterns:
    - "ArcadeLoopDriver ViewModifier: content.background { if isRunning { TimelineView(.animation) ... } } — declarative pause, no CADisplayLink"
    - "min(rawDt, 0.1) clamp in the driver only — per-game VMs never add a second clamp"
    - "lastDate = nil on isRunning → false — prevents stale anchor from causing a dt spike on resume"
    - "nonisolated struct test suite for Foundation-only types (mirrors BoardGeneratorTests pattern)"

key-files:
  created:
    - gamekit/gamekit/Core/ArcadeGameState.swift
    - gamekit/gamekit/Core/ArcadeLoopDriver.swift
    - gamekit/gamekitTests/Core/ArcadeLoopDriverTests.swift
  modified: []

key-decisions:
  - "Fixed-timestep accumulator lives in per-game VM, NOT in ArcadeLoopDriver — driver is stateless beyond lastDate anchor"
  - "ArcadeLoopDriver uses no AnyView branching — the if-isRunning guard is inside .background, not at the top-level return"
  - "onTick closure is plain ((_ dt: Double) -> Void) — Swift 6 concurrency clean because ViewModifier.body is MainActor-isolated"

patterns-established:
  - "ArcadeGameState.idle/running/paused/gameOver is the canonical lifecycle for all arcade games"
  - "view.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) } is the sole call-site shape"

requirements-completed: [ARCADE-01, ARCADE-02, ARCADE-03]

duration: 4min
completed: "2026-06-27"
---

# Phase 15 Plan 01: Arcade Substrate Summary

**Foundation-only ArcadeGameState enum + SwiftUI ArcadeLoopDriver ViewModifier with min(rawDt, 0.1) spiral-of-death clamp, gated by two locked unit tests (SC1a onTick gating + SC1b clamp math)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-27T02:14:27Z
- **Completed:** 2026-06-27T02:18:29Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- ArcadeGameState Foundation-only nonisolated enum with idle/running/paused/gameOver — the shared lifecycle for all endless arcade games
- ArcadeLoopDriver ViewModifier using TimelineView(.animation) with min(rawDt, 0.1) clamp as the sole spiral-of-death guard; lastDate resets to nil on pause for zero drift
- Two locked substrate gate tests pass: onTickGating (SC1a) and spiralOfDeathClamp (SC1b) — ROADMAP Phase 15 SC1 satisfied

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ArcadeGameState enum + ArcadeLoopDriver ViewModifier** - `7d1687e` (feat)
2. **Task 2: Write the two locked substrate gate tests** - `39c3484` (test)

## Files Created/Modified

- `gamekit/gamekit/Core/ArcadeGameState.swift` - Foundation-only nonisolated enum with 4 cases for the arcade session lifecycle
- `gamekit/gamekit/Core/ArcadeLoopDriver.swift` - SwiftUI ViewModifier wrapping TimelineView(.animation); the arcadeLoop(isRunning:onTick:) View extension
- `gamekit/gamekitTests/Core/ArcadeLoopDriverTests.swift` - Two locked substrate gate tests: onTickGating and spiralOfDeathClamp

## Decisions Made

- Fixed-timestep accumulator placed in per-game VM, not in the driver — driver is stateless beyond the `lastDate` anchor; engine receives pre-clamped dt values
- `ArcadeLoopDriver.body` uses no AnyView/top-level branching — the `if isRunning` guard is inside `.background {}`, keeping the return type opaque
- `onTick` is a plain closure (`(_ dt: Double) -> Void`) — no `@MainActor` annotation needed because ViewModifier.body is inferred as @MainActor in Swift 6

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ArcadeGameState and ArcadeLoopDriver ready for Plan 02 harness views to consume
- Both gate tests green; substrate is locked and cannot regress without a test failure
- Plan 02 will wire .arcadeLoop into StackHarnessView / SnakeHarnessView and add GameKind/GameRoute/GameDescriptor/HomeView entries

## Self-Check: PASSED

- `gamekit/gamekit/Core/ArcadeGameState.swift` exists: FOUND
- `gamekit/gamekit/Core/ArcadeLoopDriver.swift` exists: FOUND
- `gamekit/gamekitTests/Core/ArcadeLoopDriverTests.swift` exists: FOUND
- commit 7d1687e: FOUND
- commit 39c3484: FOUND
- Both tests green: CONFIRMED (xcodebuild test succeeded)
- Build succeeded with zero strict-concurrency warnings: CONFIRMED

---
*Phase: 15-arcade-substrate-skeleton*
*Completed: 2026-06-27*
