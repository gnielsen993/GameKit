---
phase: 17-snake
verified: 2026-07-04T20:00:00Z
status: passed
score: 19/19
overrides_applied: 0
re_verification: false
---

# Phase 17: Snake — Verification Report

**Phase Goal:** Snake is fully playable — swipe or D-pad turns, grow on food, self-collision ends the run — confirming genuine substrate reuse with zero Core/ changes.
**Verified:** 2026-07-04
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All three roadmap success criteria verified, plus plan-level must-haves verified across all six plans.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 (SC1) | User can play Snake: swipe/D-pad changes direction, eating grows snake, self/wall collision ends run with game-over banner | VERIFIED | `DragGesture` + `SnakeDPad` call `vm.handleDirectionInput`; engine grow/slide/collision logic confirmed; `VideoModeBanner` shown on game-over; device-approved 2026-07-04 |
| 2 (SC1) | Left-edge board swipe does NOT trigger nav pop | VERIFIED | `.defersSystemGestures(on: .all)` on board area in `SnakeGameView.swift:216`; `.disableInteractivePop()` in HomeView route; device-approved 2026-07-04 |
| 3 (SC2) | Same pinned seed produces identical food-spawn sequences, grow events, and collision outcomes across two runs | VERIFIED | `seedDeterminism` test in `SnakeEngineTests.swift:27`; uses `Int.random(in:using:&rng)` with `SeededGenerator(seed:)` injection |
| 4 (SC2) | `dt=1/60` and `dt=1/120` over 5 simulated seconds produce same cell-move count and collision state | VERIFIED | `proMotionEquivalence` test in `SnakeEngineTests.swift:60`; full gamekitTests suite green (344 tests) |
| 5 (SC3) | `git diff` on `Core/ArcadeLoopDriver.swift` + `Core/ArcadeGameState.swift` is empty for all Phase 17 commits | VERIFIED | `git log --follow -- Core/ArcadeLoopDriver.swift` shows last commit `6f67d1c` (Phase 15 hardening); `git log --follow -- Core/ArcadeGameState.swift` shows last commit `7d1687e` (Phase 15 creation); zero Phase 17 commits to either file |
| 6 | Snake advances one cell per tickInterval, grows on food, dies on self-collision | VERIFIED | `SnakeEngine.step()` accumulates `cellAccumulator += dt`; grows via `body.insert(newHead, at:0)` (no tail removal on eat); self-collision via `body.dropLast().contains(newHead)` |
| 7 | Wrap mode re-enters opposite edge; wall mode ends run on edge contact | VERIFIED | Toroidal wrap `(newHead.col + cfg.cols) % cfg.cols` at engine line 142; wall gate `gameOver = true` at line 137; `toroidalWrap` and `wallCollision` tests confirm |
| 8 | tickInterval ramps down with score, floors at minTickInterval (>= 100ms) | VERIFIED | `max(cfg.minTickInterval, cfg.startTickInterval - Double(score) * cfg.intervalDecrement)` at `SnakeEngine.swift:113`; `minTickInterval = 0.100` in `SnakeConfig.default` |
| 9 | ArcadePalette.layer(forIndex:theme:) produces accent-derived color ramp from DesignKit chart tokens only | VERIFIED | Ramp uses `theme.charts.chart1...chart6`; zero `Color(red:)`/`Color(hex:)` matches; `StackPalette` is a 3-line `typealias StackPalette = ArcadePalette` shim |
| 10 | Capacity-2 direction queue preserves rapid turns; 180-degree reversal rejected with no haptic | VERIFIED | `maxQueueDepth = 2`; `effectiveCurrent = directionQueue.last ?? engine.currentDirection` (Pitfall 5 guard); `enqueueCount += 1` placed AFTER both guard statements (Pitfall 6); `rejects180DegreeReversal`, `effectiveCurrentUsesQueueTail`, `capsQueueAtTwo` tests green |
| 11 | VM fixed-step accumulator drives engine at 1/60s, pops one direction per cell move | VERIFIED | `while accumulator >= fixedDt` loop in `SnakeViewModel.tick()`; direction popped only when `newFrame.didMoveCell`; `midIntervalInputSurvives` test confirms |
| 12 | On game-over, score persists exactly once via `GameStats.record(gameKind:.snake, mode:"endless", outcome:.loss)` | VERIFIED | `SnakeViewModel.swift:183-189`; `return` after record call halts the while loop; `recordSnakeRunHigherOnly` test confirms higher-only semantics and exact 2 records |
| 13 | Wall mode toggle with score>0 raises abandon alert; score==0 applies immediately; persists under "snake.wallMode" | VERIFIED | `requestWallModeToggle()` gates on `engine.score > 0`; `UserDefaults.standard.set(wallMode, forKey: "snake.wallMode")` in `applyWallModeToggle()`; read at `init()` |
| 14 | Snake renders as continuous rounded path with head eye-dots and ArcadePalette head-to-tail gradient, food as token circle, board as flat border-tinted well | VERIFIED | `SnakeBoardCanvas.swift`: body path via `ArcadePalette.layer(forIndex: i, theme:)`; `drawEyes()` with `theme.colors.background`; food with `theme.colors.success`; board `RoundedRectangle` stroked with `theme.colors.border`; zero token violations |
| 15 | Gaffer interpolation between cell moves; Reduce Motion renders jump-cut to CURRENT position (not prevBody) | VERIFIED | `let alpha = reduceMotion ? 1.0 : cellMoveAlpha` at `SnakeBoardCanvas.swift:82` (CR-01 fix); `segPos()` lerps `prevBody[i] → snakeBody[i]` at alpha; device-approved 2026-07-04 |
| 16 | Wrap-boundary segments do not streak across the board | VERIFIED | `colJump <= cols / 2 && rowJump <= rows / 2` guard at `SnakeBoardCanvas.swift:114`; `continue` skips the connecting stroke on wrap |
| 17 | Home Snake tile opens SnakeGameView (not harness); harness deleted | VERIFIED | `HomeView.swift:404`: `SnakeGameView().disableInteractivePop()` with ADR comment; `SnakeHarnessView.swift` does not exist |
| 18 | Stats screen shows Snake high score and runs played, with explicit empty state | VERIFIED | `SnakeStatsCard` reads `bestScores.first(where: { $0.difficultyRaw == "endless" })`; empty state "No Snake games played yet." present; `StatsView.swift:231` mounts card with existing `snakeRecords`/`snakeBestScores` @Query pairs |
| 19 | Eating food rolls score chip; high-score pulses once mid-run; game-over drains board then shows banner after 500ms | VERIFIED | `SnakeScoreChip` with `.contentTransition(.numericText(countsDown: false))`; `highScoreCount` increments at most once per run via `didCrossHighScore` flag; `Task.sleep(for: .milliseconds(500))` pre-roll gated by `fxEnabled`; `.grayscale(vm.state == .gameOver ? 1.0 : 0.0)` drain |

**Score:** 19/19 truths verified

---

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `Games/Snake/SnakeEngine.swift` | VERIFIED | 193 lines; pure Foundation-only; `nonisolated struct SnakeEngine`; `struct SnakeFrame`, `enum SnakeDirection`, `enum SnakeEvent`, `struct SnakeCell` all exported; zero SwiftUI/UIKit/CGFloat/CGPoint imports |
| `Games/Snake/SnakeConfig.swift` | VERIFIED | 52 lines; `nonisolated struct SnakeConfig: Sendable`; `default` and `testFixed` statics; `minTickInterval = 0.100`; Foundation-only |
| `gamekitTests/Games/Snake/SnakeEngineTests.swift` | VERIFIED | 6 `@Test` functions: `seedDeterminism`, `proMotionEquivalence`, `wallCollision`, `toroidalWrap`, `selfCollision`, `postGameOverNoOp`; `SeededGenerator(seed:)` injection |
| `Core/ArcadePalette.swift` | VERIFIED | 89 lines; `enum ArcadePalette` with `layer(forIndex:theme:)->Layer`; `segmentsPerStop` + `blocksPerStop` alias; chart1–6 ramp only |
| `Games/Stack/StackPalette.swift` | VERIFIED | 3-line shim: `typealias StackPalette = ArcadePalette`; no implementation body |
| `Games/Snake/SnakeViewModel.swift` | VERIFIED | 265 lines; `@Observable @MainActor final class SnakeViewModel`; accumulator loop, capacity-2 queue, wall-mode abandon-alert, one-shot persistence |
| `gamekitTests/Games/Snake/SnakeViewModelTests.swift` | VERIFIED | 8 `@Test` functions including direction-queue contract and `midIntervalInputSurvives` |
| `gamekitTests/Core/GameStatsTests.swift` (extended) | VERIFIED | `recordSnakeRunHigherOnly` test present at line 226; score-15-then-8 leaves BestScore at 15 |
| `Core/GameStats.swift` (extended) | VERIFIED | `bestScore(gameKind:mode:) -> Int` read method at line 177; Rule 2 documented deviation |
| `Games/Snake/SnakeBoardCanvas.swift` | VERIFIED | 211 lines; props-only `Canvas`; ArcadePalette ramp; Gaffer lerp; wrap-boundary guard; head pulse prop; CR-01 fix applied (alpha=1.0 under RM) |
| `Games/Snake/SnakeGameView.swift` | VERIFIED | 244 lines; `.defersSystemGestures(on: .all)`; `.arcadeLoop`; both `.inactive` and `.background` pause; 3 counter-trigger haptics; no `.videoModeAware` |
| `Games/Snake/SnakeGameView+Chrome.swift` | VERIFIED | 165 lines; `SnakeDPad` struct; wall-mode toolbar; abandon alert; idle content; back chevron |
| `Games/Snake/SnakeScoreChip.swift` | VERIFIED | 47 lines; props-only; `.contentTransition(.numericText(countsDown: false))`; token-only |
| `Screens/HomeView.swift` (edited) | VERIFIED | `.snake` case at line 404: `SnakeGameView().disableInteractivePop()` with ADR comment; no `.videoModeAware` |
| `Games/Snake/SnakeHarnessView.swift` (deleted) | VERIFIED | File does not exist |
| `Screens/SnakeStatsCard.swift` | VERIFIED | 100 lines; props-only; reads `difficultyRaw == "endless"`; "No Snake games played yet." empty state; zero token violations |
| `Screens/StatsView.swift` (edited) | VERIFIED | Line 231: `SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)`; old "No Snake games yet." placeholder removed (0 occurrences) |

---

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `SnakeEngine.step` | `SnakeFrame.cellMoveAlpha` | `min(cellAccumulator / tickInterval, 1.0)` | WIRED |
| `SnakeEngine.spawnFood` | seeded RNG | `Int.random(in: 0..<candidates.count, using: &rng)` | WIRED |
| `ArcadePalette.layer` | `theme.charts.chart1...chart6` | ramp array of 6 chart tokens | WIRED |
| `SnakeViewModel.tick` | `engine.step(dt:nextDirection:)` | `while accumulator >= fixedDt`; peek queue; pop on `didMoveCell` | WIRED |
| `SnakeViewModel` game-over | `GameStats.record` | `mode: "endless"`, `outcome: .loss`, `score: engine.score` — once then `return` | WIRED |
| `SnakeViewModel.applyWallModeToggle` | `UserDefaults snake.wallMode` | `UserDefaults.standard.set(wallMode, forKey: "snake.wallMode")` | WIRED |
| `SnakeBoardCanvas` | `ArcadePalette.layer(forIndex:theme:)` | per-segment stroke color at `SnakeBoardCanvas.swift:123` | WIRED |
| `SnakeBoardCanvas.segPos` | `cellMoveAlpha` | `reduceMotion ? 1.0 : cellMoveAlpha` (CR-01 fix) | WIRED |
| `SnakeGameView board` | `vm.tryEnqueueDirection` | `DragGesture.onEnded` + `SnakeDPad onDirection` both call `vm.handleDirectionInput` | WIRED |
| `SnakeGameView board` | system nav gesture arbitration | `.defersSystemGestures(on: .all)` | WIRED |
| `HomeView .snake route` | `SnakeGameView` | `SnakeGameView().disableInteractivePop()` (no `.videoModeAware`) | WIRED |
| `SnakeStatsCard` | `BestScore endless row` | `bestScores.first(where: { $0.difficultyRaw == "endless" })` | WIRED |
| `StatsView .snake section` | `SnakeStatsCard` | `SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)` via existing `@Query` pairs | WIRED |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `SnakeBoardCanvas` | `snakeBody`, `food`, `cellMoveAlpha` | `vm.frame` from `SnakeEngine.step()` via `ArcadeLoopDriver.arcadeLoop` | Yes — engine computes real grid state each tick | FLOWING |
| `SnakeStatsCard` | `bestScores` (highScoreText), `records` (runsPlayed) | `@Query` pairs `snakeBestScores` / `snakeRecords` in `StatsView` populated by `GameStats.record()` on game-over | Yes — SwiftData real queries; empty state shown when no runs played | FLOWING |
| `SnakeScoreChip` | `score` | `vm.frame.score` (engine food-eat counter) | Yes — engine increments `score` on each eat | FLOWING |

---

### Behavioral Spot-Checks

Step 7b skipped — SnakeEngine is a pure value-type struct with no runnable entry point separate from the iOS app. Behavioral verification is covered by the unit test suite (344 tests, green) and the device approval on 2026-07-04.

---

### Probe Execution

Step 7c skipped — no probe scripts declared for Phase 17. The SC2 gate (engine determinism + ProMotion equivalence) is implemented as Swift Testing unit tests and confirmed green.

---

### Requirements Coverage

| Requirement | Plans | Description | Status | Evidence |
|-------------|-------|-------------|--------|----------|
| SNAKE-01 | 01, 05 | Swipe or tap-to-turn changes direction; eating food grows the snake | SATISFIED | `DragGesture` + `SnakeDPad` → `handleDirectionInput`; engine grow logic confirmed; device-approved |
| SNAKE-02 | 01, 03 | Default wrap (toroidal); wall-death mode selectable via toggle | SATISFIED | Toroidal wrap default in `SnakeConfig.default.wallMode = false`; `requestWallModeToggle()` / abandon alert / UserDefaults persistence |
| SNAKE-03 | 03, 05 | On-screen D-pad alongside swipe; both feed direction queue so rapid turns not dropped | SATISFIED | `SnakeDPad` always visible below board; capacity-2 queue; `midIntervalInputSurvives` test; device-approved input responsiveness |
| SNAKE-04 | 01 | Speed ramps with length then plateaus; self-collision (and wall collision in wall mode) ends run | SATISFIED | `max(cfg.minTickInterval, ...)` floor at 100ms; `body.dropLast().contains(newHead)` self-collision; `wallCollision` test |
| SNAKE-05 | 03, 06 | Score is food eaten; high score persisted; Stats screen shows high score and runs played | SATISFIED | `GameStats.record(gameKind:.snake, mode:"endless", outcome:.loss, score:engine.score)` once on game-over; `SnakeStatsCard` reads "endless" `BestScore` row |
| SNAKE-06 | 02, 04 | Renders with DesignKit tokens only; legible under Classic + one Loud/Moody preset | SATISFIED | Zero `Color(red:)`/`Color(hex:)`/`.green`/`.blue` in all Snake view files; ArcadePalette chart tokens only; device §8.12 audit approved (Classic + Loud preset) |
| SNAKE-07 | 04, 05 | Reduce Motion path: jump-cut between cells, gameplay unchanged | SATISFIED | `reduceMotion ? 1.0 : cellMoveAlpha` (CR-01 fix) renders current cell position under RM; gameplay (engine, scoring, collision) unchanged; device-approved |

All 7 SNAKE requirements satisfied. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `SnakeBoardCanvas.swift` | 39, 49, 57, 165 | Stale doc comments say "alpha 0.0" after CR-01 fix changed code to 1.0 | WARNING (advisory) | Comments are misleading but code behavior at line 82 is correct; already flagged in 17-REVIEW.md (CR-01 follow-up) |
| `SnakeGameView.swift` | 126–140 | 500ms pre-roll `Task` not cancelled on state leaving `.gameOver` — can re-show banner over fresh idle screen (WR-01) | WARNING (advisory) | Narrow timing window; tracked in 17-REVIEW.md WR-01 for Phase 18 follow-up |
| `SnakeBoardCanvas.swift` | 143–144 | Head eye-dot center computed with plain lerp — streaks across board during wrap frames (WR-02) | WARNING (advisory) | Visual artifact on wrap frames only; tracked in 17-REVIEW.md WR-02 for Phase 18 follow-up |
| `SnakeViewModel.swift` | 130 | `handleDirectionInput` doesn't guard on `.gameOver`/`.paused` — fires `.selection` haptic on dead game (WR-03) | WARNING (advisory) | Haptic misinformation only; no gameplay effect; tracked in 17-REVIEW.md WR-03 |
| Multiple | Various | `"endless"` serialization key duplicated as raw string literals in 4 locations (WR-04) | WARNING (advisory) | Risk of typo producing silent stats bug; `GameStats.stackEndlessMode` precedent not followed; tracked in 17-REVIEW.md WR-04 |
| `SnakeEngine.swift` | 94 | Comment: "Placeholder food — will be replaced by spawnFood()" | INFO | NOT a stub — `food` initialized at line 95 and immediately replaced by `spawnFood()` at line 96; explanatory comment only |

No TBD/FIXME/XXX markers found. No empty return stubs. All files under 400-line cap (max: SnakeViewModel.swift at 265 lines). No Finder-dupe `* 2.swift` files.

**Debt marker gate:** CLEAN — zero unresolved TBD/FIXME/XXX markers.

---

### Human Verification (Pre-Approved)

All device-only items were verified and APPROVED on 2026-07-04 via the Plan 17-05 Task 3 checkpoint. No remaining human verification items.

| Test | Expected | Result |
|------|----------|--------|
| SC1 (device): left-edge board swipe does not pop NavigationStack | Snake turns; no nav pop | APPROVED 2026-07-04 |
| SC4: rapid turn sequence (up then right) registers both; opposite-heading swipe is silent no-op | Both turns applied in order; no haptic / no death on reversal | APPROVED 2026-07-04 |
| §8.12 Classic preset legibility | Body gradient, eye dots, food, board well all legible | APPROVED 2026-07-04 |
| §8.12 Loud/Moody preset legibility | Same legibility on Voltage or Dracula preset | APPROVED 2026-07-04 |
| SNAKE-07 Reduce Motion (device/simulator): snake teleports cell-to-cell, no interpolation, gameplay unchanged | Jump-cut movement; grow/collision/scoring identical | APPROVED 2026-07-04 (CR-01 fix applied) |
| §12.5 new-game checklist | All DESIGN.md §12.5 items pass for Snake | APPROVED 2026-07-04 |

---

### SC3 Gate Detail

The context note specifies SC3 targets `ArcadeLoopDriver.swift` and `ArcadeGameState.swift` only. The two planned deviations are explicitly outside the gate:

- `Core/ArcadePalette.swift` (Plan 17-02): new file promoted from Stack — NOT a substrate file
- `Core/GameStats.swift` (Plan 17-03): `bestScore(gameKind:mode:)` read-only method added as a documented Rule 2 deviation — NOT a substrate file

`git log --follow -- Core/ArcadeLoopDriver.swift` last commit: `6f67d1c` (Phase 15 substrate hardening, pre-Phase 17).
`git log --follow -- Core/ArcadeGameState.swift` last commit: `7d1687e` (Phase 15 creation).
Zero Phase 17 commits to either substrate file. SC3 gate: CLEAN.

---

### Gaps Summary

No gaps. All 19 must-have truths verified. All 7 requirements (SNAKE-01..07) satisfied. All key links wired. Data flows from real sources (engine step, SwiftData queries). SC3 confirmed empty. Full gamekitTests suite green (344 tests). All human items device-approved 2026-07-04.

Five advisory warnings from the code review (WR-01 through WR-05) are documented and tracked for Phase 18 follow-up. None block the phase goal.

---

_Verified: 2026-07-04_
_Verifier: Claude (gsd-verifier)_
