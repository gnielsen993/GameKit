---
phase: 17-snake
plan: 01
subsystem: testing
tags: [snake, game-engine, pure-foundation, seeded-rng, determinism, promtion]

# Dependency graph
requires: []
provides:
  - SnakeEngine pure Foundation-only value-type grid engine (step/spawnFood/frame contract)
  - SnakeConfig tuning struct with default + testFixed statics
  - SnakeEngineTests suite (seedDeterminism, proMotionEquivalence, wallCollision, toroidalWrap, selfCollision, postGameOverNoOp)
  - SnakeCell / SnakeDirection / SnakeEvent / SnakeFrame exported types for Plans 02/03/04
affects: [17-02-plan, 17-03-plan, 17-04-plan, 17-05-plan, 17-06-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "nonisolated struct engine with private var rng: any RandomNumberGenerator seam (seeded test injection)"
    - "Gaffer alpha pattern: cellMoveAlpha = min(cellAccumulator / tickInterval, 1.0)"
    - "startLength: 5 required for clockwise self-collision test (3-cell body geometrically cannot self-collide)"

key-files:
  created:
    - gamekit/gamekit/Games/Snake/SnakeEngine.swift
    - gamekit/gamekit/Games/Snake/SnakeConfig.swift
    - gamekit/gamekitTests/Games/Snake/SnakeEngineTests.swift
  modified: []

key-decisions:
  - "17-01: SnakeEngine stores rng as 'private var rng: any RandomNumberGenerator' existential — Swift 5.7+ implicit opening lets SeededGenerator (test) and SystemRandomNumberGenerator (prod) inject cleanly through the 'some RandomNumberGenerator' init parameter"
  - "17-01: Self-collision check uses body.dropLast() (tail-exclusion) so a sliding move never falsely collides on the vacating tail cell"
  - "17-01: prevBody snapshotted at the start of each cell move (Gaffer anchor) so the view can lerp between cell positions"
  - "17-01: tickInterval ramp computed after each cell move: max(cfg.minTickInterval, cfg.startTickInterval - Double(score) * cfg.intervalDecrement) — floors at 100ms per CONTEXT locked constraint"
  - "17-01: startLength=5 required in selfCollision test — 3-cell body in a 2×2 clockwise loop can never self-collide because the tail vacates the entering cell on every non-eating move; 5-cell body exceeds the 4-cell loop perimeter and collides on the 4th cell move"

patterns-established:
  - "Engine purity: nonisolated struct, Foundation-only, no CGFloat/CGPoint/Date.now/modelContext"
  - "Config split: SnakeConfig.default for device-calibration baseline, SnakeConfig.testFixed for unit-test stability"
  - "Self-collision test: use startLength=5 (not testFixed.startLength=3) to guarantee loop collision"

requirements-completed: [SNAKE-01, SNAKE-02, SNAKE-04]

# Metrics
duration: 236min (includes prior executor run + quota-limit interruption; continuation executor ~15min)
completed: 2026-07-03
---

# Phase 17 Plan 01: SnakeEngine + Config + Tests Summary

**Pure Foundation-only SnakeEngine with seeded RNG injection, toroidal-wrap and wall-mode collision, Gaffer alpha interpolation, and a 6-test determinism/ProMotion/collision suite (SC2 gate green)**

## Performance

- **Duration:** 236 min (prior executor + quota interruption + continuation)
- **Started:** 2026-07-03T15:56:10Z
- **Completed:** 2026-07-03T19:52:44Z (continuation)
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- SnakeConfig delivers `default` (20×32, wrap, 200ms→100ms ramp) and `testFixed` (10×10, stable for deterministic tests) statics
- SnakeEngine implements the full RESEARCH §Pattern 1 step contract: accumulator-based cell moves, toroidal wrap vs wall death, body.dropLast() self-collision, food eating (grow/slide), score-driven speed ramp, Gaffer alpha for view interpolation
- All 6 SnakeEngineTests pass: SC2 seedDeterminism + proMotionEquivalence gate is green; wallCollision, toroidalWrap, selfCollision, postGameOverNoOp cover the full collision surface

## Task Commits

1. **Task 1: SnakeConfig tuning struct** - `fed3ba1` (feat)
2. **Task 2: SnakeEngine value types + step logic** - `de3a461` (feat)
3. **Task 3: SnakeEngineTests** - `4e3bcf5` (test)

## Files Created/Modified

- `gamekit/gamekit/Games/Snake/SnakeConfig.swift` — Sendable tuning struct: default + testFixed statics, wallMode var, tick-interval constants
- `gamekit/gamekit/Games/Snake/SnakeEngine.swift` — Pure engine: SnakeCell/SnakeDirection/SnakeEvent/SnakeFrame types + step/spawnFood/frame; 188 lines
- `gamekit/gamekitTests/Games/Snake/SnakeEngineTests.swift` — @Suite nonisolated struct, 6 @Test functions, SeededGenerator injection

## Decisions Made

- Engine stores `rng: any RandomNumberGenerator` existential — SeededGenerator (tests) and SystemRandomNumberGenerator (prod) both inject through the `some RandomNumberGenerator` init parameter via implicit existential opening (Swift 5.7+)
- `prevBody` snapshotted at the top of each cell-move branch (Gaffer anchor) — view lerps between prevBody and body using cellMoveAlpha
- `tickInterval` recomputed after every cell move using `max(minTickInterval, startTickInterval - Double(score) * intervalDecrement)` — floors at 100ms per CONTEXT locked constraint (SNAKE-04)
- `self-collision` check uses `body.dropLast()` — tail cell vacates on a non-eating move, excluding it prevents false positives during a pure slide

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] selfCollision test: 3-cell body geometrically cannot self-collide in a 2×2 clockwise loop**
- **Found during:** Task 3 (SnakeEngineTests)
- **Issue:** The original test used `SnakeConfig.testFixed` (startLength=3). A 3-cell snake in a 2×2 clockwise loop (right→down→left→up) never self-collides because on every non-eating move the tail vacates the cell the head is about to enter. After 3000 steps the engine never triggered `gameOver`, so `Issue.record` fired and the test failed.
- **Root cause:** The geometric invariant is: for a body of length N to self-collide in a loop of perimeter P, N must be > P. The 2×2 clockwise loop has perimeter 4; startLength=3 means body < perimeter, so collision is impossible.
- **Fix:** Replaced the inline `cfg.wallMode = false` mutation with a full memberwise `SnakeConfig(cols:10, rows:10, wallMode:false, startTickInterval:0.200, minTickInterval:0.100, intervalDecrement:0.002, startLength:5, fixedDt:1.0/60.0)` so the body (length 5) exceeds the loop perimeter (4). The 5-cell body self-collides on the 4th cell move (~48 steps at 60 Hz).
- **Files modified:** `gamekit/gamekitTests/Games/Snake/SnakeEngineTests.swift`
- **Verification:** `xcodebuild test ... -only-testing:gamekitTests/SnakeEngineTests` — all 6 tests pass, TEST SUCCEEDED
- **Committed in:** `4e3bcf5` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — test setup bug)
**Impact on plan:** Engine correctness unaffected. Test now verifies the actual behavior it claims to test. No scope creep.

## Issues Encountered

None beyond the selfCollision deviation above.

## Known Stubs

None — SnakeEngine is a complete engine implementation. No placeholder values or TODO markers in the shipped files.

## Threat Surface Scan

No new security-relevant surfaces introduced. Engine is offline, single-player, Foundation-only. Trust boundary (gesture/VM → engine) covered by T-17-01 mitigation (direction 180° double-guard in step()). T-17-02 frame-rate divergence mitigated by SC2 gate (proMotionEquivalence passes).

## Next Phase Readiness

- SnakeCell / SnakeDirection / SnakeEvent / SnakeFrame types are exported and locked — Plans 02/03/04 can import directly
- SnakeEngine.step(dt:nextDirection:) contract is proven by tests — VM (Plan 02) wires the ArcadeLoopDriver accumulator to this seam
- SC2 gate is green — ProMotion equivalence verified before any view code exists

---
*Phase: 17-snake*
*Completed: 2026-07-03*
