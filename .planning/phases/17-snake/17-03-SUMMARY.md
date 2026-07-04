---
phase: 17-snake
plan: "03"
subsystem: snake-viewmodel
tags: [snake, viewmodel, direction-queue, persistence, wall-mode, tdd]
dependency_graph:
  requires: [17-01, 17-02]
  provides: [SnakeViewModel, GameStats.bestScore-read-API, recordSnakeRunHigherOnly-test]
  affects: [17-04-SnakeBoardCanvas, 17-05-SnakeGameView]
tech_stack:
  added: []
  patterns:
    - "@Observable @MainActor class with fixedDt accumulator (StackViewModel analog)"
    - "capacity-2 direction queue with 180-degree rejection (effectiveCurrent = queue.last ?? engine.current)"
    - "counter-trigger haptic fields (eatCount, enqueueCount, highScoreCount)"
    - "GameStats one-shot injection via attachGameStats + bestScore read for D-09 threshold"
    - "wall-mode abandon-alert (MergeViewModel.requestModeChange analog)"
key_files:
  created:
    - gamekit/gamekit/Games/Snake/SnakeViewModel.swift
    - gamekit/gamekitTests/Games/Snake/SnakeViewModelTests.swift
  modified:
    - gamekit/gamekit/Core/GameStats.swift
    - gamekit/gamekitTests/Core/GameStatsTests.swift
decisions:
  - "Wall-mode toggle methods (requestWallModeToggle/confirm/cancel) included in Task 1 commit alongside stored properties — Swift cannot add stored properties via class extensions; functional split follows plan intent while respecting language constraints"
  - "GameStats.bestScore(gameKind:mode:) read method added as Rule 2 deviation — needed by SnakeViewModel to snapshot bestScoreAtStart for D-09 once-per-run high-score crossing; follows existing wonPuzzleIDs capture-let pattern"
  - "prevBody tracked as separate stored property (not a computed alias for frame.prevBody) to match StackViewModel's prevCenterX discipline; canvas plan (17-04) reads vm.prevBody directly"
  - "enqueueCount += 1 placed INSIDE both guard statements (Pitfall 6) — rejected inputs fire no haptic; verified by SnakeViewModelTests.rejects180DegreeReversal and effectiveCurrentUsesQueueTail"
metrics:
  duration_seconds: 1122
  completed_date: "2026-07-04"
  tasks_completed: 2
  files_changed: 4
---

# Phase 17 Plan 03: SnakeViewModel Summary

**One-liner:** @Observable @MainActor SnakeViewModel driving SnakeEngine via a 1/60s fixed-step accumulator with a capacity-2 direction queue, 180-degree reversal rejection, counter-trigger haptic fields, one-shot GameStats persistence, and a wall-mode abandon-alert toggle mirroring MergeViewModel.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 TDD RED | SnakeViewModelTests direction-queue failing tests | 642b015 | gamekitTests/Games/Snake/SnakeViewModelTests.swift (new) |
| 1 TDD GREEN | SnakeViewModel core — accumulator, direction queue, lifecycle, counters | c436dc5 | Games/Snake/SnakeViewModel.swift (new), Core/GameStats.swift (+bestScore read) |
| 2 TDD RED | recordSnakeRunHigherOnly persistence test | 3370785 | gamekitTests/Core/GameStatsTests.swift |
| 2 TDD GREEN | Persistence hookup + wall-mode abandon-alert | 6ea6859 | Games/Snake/SnakeViewModel.swift |

## What Was Built

**SnakeViewModel.swift** (249 lines) — @Observable @MainActor bridge that:
- Owns the 1/60s fixed-step accumulator (`while accumulator >= fixedDt`) driving `engine.step(dt:nextDirection:)` — ProMotion-equivalent since all timing is in seconds (SNAKE-03/SC4)
- Implements `tryEnqueueDirection(_ dir:) -> Bool` with capacity-2 direction queue; `effectiveCurrent = directionQueue.last ?? engine.currentDirection` (Pitfall 5 guard); `enqueueCount += 1` inside both reject guards (Pitfall 6 — no haptic on rejected input, D-07)
- Pops one direction per cell move (not per fixed step) matching the RESEARCH Pattern 3 contract
- Counter-trigger haptic fields: `eatCount` (D-08), `enqueueCount` (D-07), `highScoreCount` (D-09 — once-per-run via `bestScoreAtStart` snapshot)
- Wall-mode state (`wallMode` from `"snake.wallMode"` UserDefaults) with full abandon-alert flow: `requestWallModeToggle` / `confirmWallModeChange` / `cancelWallModeChange` / `applyWallModeToggle` mirroring MergeViewModel pattern
- Game-over persistence: `try? gameStats?.record(gameKind: .snake, mode: "endless", outcome: .loss, score: engine.score)` fires exactly once on the `.gameOver` transition then `return` halts the while loop (T-17-06 mitigated)
- `attachGameStats(_:)` one-shot injection; reads `bestScoreAtStart` via new `GameStats.bestScore(gameKind:mode:)` for D-09 threshold
- `restart()` rebuilds engine with current `wallMode`, resets all counters/queue, returns to `.idle`

**SnakeViewModelTests.swift** (64 lines) — 4 Swift Testing cases:
- `rejects180DegreeReversal`: .left from initial .right → false, enqueueCount == 0
- `acceptsValidTurn`: .up from initial .right → true, enqueueCount == 1
- `effectiveCurrentUsesQueueTail`: queue=[.up], then .down (opposite of .up) → false (Pitfall 5)
- `capsQueueAtTwo`: queue=[.up,.left], third valid direction → false (capacity, not 180°)

**GameStats.swift** (Rule 2 addition) — `bestScore(gameKind:mode:) -> Int` read method for the D-09 high-score crossing detection.

**GameStatsTests.swift** — `recordSnakeRunHigherOnly`: score 15 then 8 → BestScore stays at 15, exactly 2 GameRecords.

## Verification Results

```
TEST SUCCEEDED: gamekitTests/SnakeViewModelTests (4 tests)
TEST SUCCEEDED: gamekitTests/GameStatsTests (10 tests, including recordSnakeRunHigherOnly)
BUILD SUCCEEDED: full app target
wc -l SnakeViewModel.swift: 249 (< 400 cap)
No Finder-dupe files (git status)
No project.pbxproj change
```

## Deviations from Plan

### Auto-fixed Issues (Rule 2)

**1. [Rule 2 - Missing critical functionality] GameStats.bestScore read method**
- **Found during:** Task 1 (attachGameStats needs to snapshot bestScoreAtStart for D-09)
- **Issue:** SnakeViewModel imports Foundation only (SwiftData firewall). To detect the once-per-run high-score crossing, the VM needs the persisted best score at game start. GameStats had no read path for this.
- **Fix:** Added `bestScore(gameKind:mode:) -> Int` to GameStats (public read, no write, no schema change). Mirrors the capture-let pattern from `wonPuzzleIDs`. Returns 0 on any fetch error.
- **Files modified:** `gamekit/gamekit/Core/GameStats.swift`
- **Commit:** c436dc5

**2. [Rule 3 - Task split] Wall-mode stored properties included in Task 1**
- **Found during:** Task 1 (planning the Task 1/2 split)
- **Issue:** Swift does not allow stored properties in class extensions. Plan says Task 2 "extends SnakeViewModel with var showingAbandonAlert, private(set) var wallMode." Stored properties must be in the class body (Task 1's file), not a later extension.
- **Fix:** Declared `showingAbandonAlert` and `wallMode` in Task 1's SnakeViewModel.swift. The wall-mode toggle METHODS (requestWallModeToggle / confirmWallModeChange / cancelWallModeChange / applyWallModeToggle) were also included in Task 1's commit since they require the stored properties. Task 2's GREEN commit added only the persistence call in tick().
- **Files modified:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift`
- **Impact:** Zero functional change — all behavior matches plan spec exactly; only commit grouping differs.

## Known Stubs

None. SnakeViewModel is a complete implementation. The persistence call fires on every game-over. The direction queue enforces all specified constraints. Wall-mode toggle with abandon-alert is fully wired.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| (none) | — | — |

T-17-04 (UserDefaults snake.wallMode tampering) — accepted per plan threat register (Bool with known-good default, no gameplay-security implication).
T-17-05 (stale SwiftData store) — accepted per plan threat register (no new @Model added).
T-17-06 (duplicate score writes) — mitigated: record() called once on the .gameOver transition, then `return` halts the while loop, ensuring single write per run.

## TDD Gate Compliance

| Phase | Gate Commit | Description |
|-------|-------------|-------------|
| RED (Task 1) | 642b015 | SnakeViewModelTests — compile error (SnakeViewModel not found) |
| GREEN (Task 1) | c436dc5 | SnakeViewModel created — all 4 tests pass |
| RED (Task 2) | 3370785 | recordSnakeRunHigherOnly test added to GameStatsTests |
| GREEN (Task 2) | 6ea6859 | Persistence call wired in tick() — all tests pass |

## Self-Check: PASSED

- [x] `gamekit/gamekit/Games/Snake/SnakeViewModel.swift` exists (249 lines)
- [x] `gamekit/gamekitTests/Games/Snake/SnakeViewModelTests.swift` exists (64 lines)
- [x] `gamekit/gamekit/Core/GameStats.swift` contains `bestScore(gameKind:mode:)`
- [x] `gamekit/gamekitTests/Core/GameStatsTests.swift` contains `recordSnakeRunHigherOnly`
- [x] Commit 642b015 (RED test) — FOUND
- [x] Commit c436dc5 (GREEN SnakeViewModel) — FOUND
- [x] Commit 3370785 (persistence test) — FOUND
- [x] Commit 6ea6859 (persistence wiring) — FOUND
- [x] `xcodebuild test -only-testing:gamekitTests/GameStatsTests` → TEST SUCCEEDED
- [x] `xcodebuild build` → BUILD SUCCEEDED
