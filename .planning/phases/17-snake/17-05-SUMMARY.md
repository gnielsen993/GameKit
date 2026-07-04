---
phase: 17-snake
plan: "05"
subsystem: snake-gameview
tags: [snake, gameview, chrome, dpad, gestures, haptics, banner, tdd]
dependency_graph:
  requires: ["17-03 (SnakeViewModel)", "17-04 (SnakeBoardCanvas)"]
  provides: ["SnakeGameView — fully assembled playable game screen"]
  affects: ["HomeView routing (snake → real game)", "Docs/releases/v1.4.md"]
tech_stack:
  added: []
  patterns:
    - "DragGesture(minimumDistance:10) + .defersSystemGestures(on: .all) for SC1"
    - "aspectRatio(cols/rows) constraint on board area so cellSize = width/cols produces correct canvas height"
    - "Bindable(vm).showingAbandonAlert for @Observable binding in .alert"
    - "Counter-trigger haptics: hapticsEnabled FIRST guard (eatCount, enqueueCount, highScoreCount)"
    - "D-08 head pulse: @State headPulse 1→0 over 150ms on eatCount, gated fxEnabled + !reduceMotion"
    - "TimelineView paused when idle/showBanner/!fxEnabled to avoid wasted GPU frames"
key_files:
  created:
    - gamekit/gamekit/Games/Snake/SnakeScoreChip.swift
    - gamekit/gamekit/Games/Snake/SnakeGameView.swift
    - gamekit/gamekit/Games/Snake/SnakeGameView+Chrome.swift
    - gamekit/gamekitTests/Games/Snake/SnakeGameViewTests.swift
  modified:
    - gamekit/gamekit/Screens/HomeView.swift
    - Docs/releases/v1.4.md
    - gamekit/gamekit/Games/Snake/SnakeEngine.swift
    - gamekit/gamekit/Games/Snake/SnakeViewModel.swift
    - gamekit/gamekitTests/Games/Snake/SnakeViewModelTests.swift
  deleted:
    - gamekit/gamekit/Games/Snake/SnakeHarnessView.swift
decisions:
  - "aspectRatio(20/32, contentMode: .fit) on boardArea ZStack ensures SnakeBoardCanvas always receives a canvas sized exactly cols × cellSize wide and rows × cellSize tall — prevents blank strip below row 31 when available height > cellSize×rows"
  - "SnakeConfig.default.cols / .rows used directly in view (not via VM computed props) since these values are compile-time invariants (wallMode only changes cfg.wallMode, not grid dimensions)"
  - "Bindable(vm).showingAbandonAlert — canonical Swift 6 @Observable binding pattern; no local @State mirror needed"
  - "Comment reworded from 'No .videoModeAware()' to 'HomeView routing carries no Video Mode modifier' to avoid tripping the token-discipline grep (same pattern as Plan 17-04 Rule 1 deviation)"
  - "SnakeFrame gained didMoveCell so the VM pops the direction queue per cell move, not per fixed step (checkpoint fix — queued turns survived only ~1 in 12 fixed steps at the 0.2s starting interval)"
  - "handleDirectionInput unifies swipe + D-pad entry: starts the run from idle (matching the 'Swipe or tap D-pad to start' copy) then enqueues; the idle card carries the swipe gesture since it overlays the board"
  - "start() clears directionQueue so idle-phase input cannot poison the capacity-2 queue"
  - "Score chip relocated from board overlay into the info row above the board (checkpoint feedback, DESIGN §5.2)"
metrics:
  duration_seconds: 5400
  completed_date: "2026-07-04"
  tasks_completed: 3
  files_changed: 10
---

# Phase 17 Plan 05: SnakeGameView Summary

**One-liner:** Fully assembled SnakeGameView with swipe + D-pad steering (defersSystemGestures SC1), three counter-trigger haptics, D-08 head pulse, 500ms game-over pre-roll, grayscale drain, VideoModeBanner, and wall-mode toolbar + abandon alert; Home route swapped to real game with SC3 Core substrate diff confirmed empty.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 TDD RED | SnakeGameViewTests — failing view-type contract tests | cf7b708 | gamekitTests/Games/Snake/SnakeGameViewTests.swift (new) |
| 1 TDD GREEN | SnakeScoreChip + SnakeGameView + chrome | 304933c | SnakeScoreChip.swift, SnakeGameView.swift, SnakeGameView+Chrome.swift (new) |
| 2 | HomeView routing swap, harness delete, SC3 gate, release log | ece35ad | HomeView.swift (+5 lines), SnakeHarnessView.swift (deleted), v1.4.md |
| 3 (fix) | Checkpoint fixes: start() clears queue | 3796260, 18fe4b4 | SnakeViewModel.swift, SnakeViewModelTests.swift |
| 3 (fix) | Checkpoint fix: score chip → info row | f363506 | SnakeGameView.swift, SnakeGameView+Chrome.swift |
| 3 (fix) | Checkpoint fix: pop queue per cell move + idle input starts run | 849ccf9 | SnakeEngine.swift, SnakeViewModel.swift, SnakeGameView.swift, SnakeViewModelTests.swift |
| 3 | Human-verify checkpoint — device test APPROVED 2026-07-04 | — | — |

## What Was Built

**SnakeScoreChip.swift** (47 lines) — props-only §3.3 info chip with:
- `.contentTransition(.numericText(countsDown: false))` on score Text for D-08 rolling animation
- `.feedbackAnimation(.default, value: score)` reads env (animationsEnabled + reduceMotion) at mount site
- No compact variant — Video Mode exempt per 15-VIDEO-MODE-ADR.md

**SnakeGameView.swift** (229 lines) — game chrome wiring:
- Arcade loop: `.arcadeLoop(isRunning: vm.state == .running)` driving `vm.tick(dt:)`
- Scene phase: both `.inactive` AND `.background` call `vm.pause()` (Common Pitfall 2)
- Swipe gesture: `DragGesture(minimumDistance: 10)` dominant-axis mapping → `vm.tryEnqueueDirection`
- `.defersSystemGestures(on: .all)` on board (SC1 — system can't claim left-edge as nav-pop)
- D-08 head pulse: `@State private var headPulse: Double = 0`; onChange of vm.eatCount → animate 1→0 over 150ms when fxEnabled + !reduceMotion
- Game-over pre-roll: 500ms Task.sleep before `showBanner = true` when fxEnabled; instant cut otherwise (DESIGN §10.3)
- Grayscale drain: `Group { TimelineView(...) }.grayscale(vm.state == .gameOver ? 1.0 : 0.0).animation(fxEnabled ? .easeOut(0.5) : nil, ...)`
- Three counter-trigger haptics (hapticsEnabled FIRST): eatCount → .light(0.7), enqueueCount → .selection, highScoreCount → .medium(1.0)
- GameStats one-shot injection via `.task { guard !didInjectStats; ... vm.attachGameStats(stats) }`
- Abandon alert via `Bindable(vm).showingAbandonAlert` (Swift 6 @Observable binding)
- NO `@Environment(\.videoModeStore)`, NO Video Mode modifier (ADR exemption)
- Board area: `aspectRatio(20/32, contentMode: .fit)` + `layoutPriority(1)` so canvas is always correctly proportioned

**SnakeGameView+Chrome.swift** (165 lines) — chrome extension:
- `gameOverContent`: VideoModeBannerContent with a11y label "Game over. Score N. Restart"
- `idleContent`: VStack with "Snake" title + "Swipe or tap D-pad to start" + DKButton
- `backChevron`: topBarLeading, 44pt, chevron.backward, "Back to The Drawer" a11y
- `wallModeToolbar`: topBarTrailing, ellipsis.circle Menu, "Wall mode: On/Off" button text, calls `vm.requestWallModeToggle()`
- `SnakeDPad` struct: VStack/HStack cross layout, 44pt buttons, surface fill + 1pt border + chipShadow + .pressable, 4 directional a11y labels

**HomeView.swift** (edit) — `.snake` case swapped from `SnakeHarnessView()` to `SnakeGameView().disableInteractivePop()` with comment citing ADR.

**SnakeHarnessView.swift** (deleted) — Phase 15 throwaway removed.

**Docs/releases/v1.4.md** — added User-facing and Internal bullets for Snake.

## Verification Results

```
defersSystemGestures(on: .all) in SnakeGameView: FOUND
struct SnakeDPad in SnakeGameView+Chrome: FOUND
videoModeAware in SnakeGameView: NOT FOUND (0 occurrences)
Token violations (Color(red:)/Color(hex:)/.green/.blue): TOTAL 0 (TOKENS_OK)
.inactive + .background in scenePhase handler: FOUND
3 × sensoryFeedback with hapticsEnabled FIRST: CONFIRMED
SnakeGameView.swift: 229 lines (< 400 cap)
SnakeGameView+Chrome.swift: 165 lines (< 400 cap)
SnakeScoreChip.swift: 47 lines (< 400 cap)
xcodebuild build -scheme gamekit: BUILD SUCCEEDED
SnakeGameViewTests (3 tests): PASSED
SC3 gate (git log 17-commits -- ArcadeLoopDriver.swift ArcadeGameState.swift): EMPTY (zero changes)
HomeView .snake routes to SnakeGameView(): CONFIRMED
SnakeHarnessView.swift deleted: CONFIRMED
No project.pbxproj change: CONFIRMED
No ?? *2.swift dupes: CONFIRMED
Docs/releases/v1.4.md contains Snake bullet: CONFIRMED
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Comment reworded to avoid token-discipline grep false positive**
- **Found during:** Task 1 verification
- **Issue:** File header comment originally included the phrase "No .videoModeAware() in HomeView routing." The automated acceptance check `grep -Ec "videoModeAware" SnakeGameView.swift | grep -qx 0` requires zero occurrences, but the comment text tripped it (count = 1). Same pattern as Plan 17-04 deviation #2.
- **Fix:** Reworded to "HomeView routing carries no Video Mode modifier" — equivalent meaning, no false-positive pattern match.
- **Files modified:** `SnakeGameView.swift`
- **Commit:** 304933c

**2. [Rule 2 - Missing critical functionality] Board aspect ratio constraint**
- **Found during:** Task 1 implementation analysis
- **Issue:** SnakeBoardCanvas computes `cellSize = size.width / CGFloat(cols)`. Without an aspect ratio constraint on the board area, the canvas height could differ from `cellSize × rows`, causing either grid overflow (cell positions outside canvas) or a blank strip below row 31. On a typical iPhone 16 (width ≈ 350pt) with 500pt available height: cellSize = 350/20 = 17.5, required height = 17.5 × 32 = 560 > 500 → grid clips.
- **Fix:** Added `.aspectRatio(CGFloat(SnakeConfig.default.cols) / CGFloat(SnakeConfig.default.rows), contentMode: .fit)` to the boardArea ZStack. The board now constrains to a 20:32 canvas, ensuring cellSize × rows fits exactly.
- **Files modified:** `SnakeGameView.swift`
- **Commit:** 304933c

### Verification Command Note

The plan's multi-file token-discipline check uses `grep -Ec "..." file1 file2 file3 | grep -qx 0`. With multiple files, grep outputs per-file counts in `filename:count` format, not a bare `0`. The `grep -qx 0` step therefore always fails even when all counts are 0. Verified manually that the total across all three files is 0 (TOKENS_OK).

## TDD Gate Compliance

| Phase | Gate Commit | Description |
|-------|-------------|-------------|
| RED (Task 1) | cf7b708 | SnakeGameViewTests — TEST BUILD FAILED (3 types not found) |
| GREEN (Task 1) | 304933c | Three view files created — all 3 tests pass |

## Known Stubs

None. The view is fully wired:
- Swipe gesture and D-pad both call vm.tryEnqueueDirection
- score chip shows vm.frame.score (live)
- banner uses vm.frame.score for a11y label
- abandon alert binds to Bindable(vm).showingAbandonAlert
- GameStats injection fires via .task

## Task 3 — Human-Verify Checkpoint (APPROVED)

The first device test failed with "swipe and D-pad rarely work" and "score covers the board". Fix pass root causes:

1. **Per-fixed-step queue pop (dominant input bug):** `tick()` popped one queued direction on every 1/60s fixed step, but `SnakeEngine.step()` discards `nextDirection` on non-cell-move steps. At the 0.2s starting interval a cell move spans 12 fixed steps, so a queued turn survived only ~1 in 12 times. Fixed with `SnakeFrame.didMoveCell` + peek-then-pop in the VM (849ccf9).
2. **Idle input dead:** only the Start button called `start()` despite the "Swipe or tap D-pad to start" copy, and the idle card swallowed board-bound drags. Fixed with `handleDirectionInput` (starts from idle, then enqueues) and the swipe gesture attached to the idle card (849ccf9).
3. **Stale queue at start:** `start()` now flushes idle-phase input (18fe4b4).
4. **Score chip** moved from the board overlay to the info row (f363506).

Video Mode absence confirmed intentional (ADR ARCADE-08 — Snake remains exempt).

4 new input-regression tests added; full `gamekitTests` suite green (344 tests, `-parallel-testing-enabled NO` after simulator clone Mach -308 flakes). Human re-tested on device and **approved** (idle swipe-to-start, in-run responsiveness, SC1 no nav-pop, §8.12 legibility, Reduce Motion jump-cut).

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| (none) | — | — |

T-17-09 (dt burst after scenePhase resume): mitigated — both .inactive and .background call vm.pause(); ArcadeLoopDriver clamps dt to 0.1 on resume.
T-17-10 (substrate modification): mitigated — SC3 gate confirmed zero Core diff.
T-17-11 (left-edge swipe nav hijacking): mitigated in code — .defersSystemGestures(on: .all) + .disableInteractivePop(); SC1 device verification is Task 3.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `gamekit/gamekit/Games/Snake/SnakeScoreChip.swift` exists | FOUND |
| `gamekit/gamekit/Games/Snake/SnakeGameView.swift` exists | FOUND |
| `gamekit/gamekit/Games/Snake/SnakeGameView+Chrome.swift` exists | FOUND |
| `gamekit/gamekitTests/Games/Snake/SnakeGameViewTests.swift` exists | FOUND |
| `gamekit/gamekit/Games/Snake/SnakeHarnessView.swift` deleted | CONFIRMED |
| `.planning/phases/17-snake/17-05-SUMMARY.md` exists | FOUND |
| Commit cf7b708 (RED test) | FOUND |
| Commit 304933c (GREEN implementation) | FOUND |
| Commit ece35ad (routing + harness delete) | FOUND |
