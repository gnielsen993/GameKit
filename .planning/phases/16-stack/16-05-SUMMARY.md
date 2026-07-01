---
phase: 16-stack
plan: "05"
subsystem: Games/Stack
tags: [swiftui, canvas, arcade-loop, video-mode-banner, reduce-motion, haptics, game-over, lifecycle, scene-phase]
dependency_graph:
  requires:
    - phase: 16-03
      provides: StackViewModel (state, tick, perfectCount, dropCount, restart, attachGameStats)
    - phase: 16-04
      provides: StackBoardCanvas (props-only Canvas render, Gaffer interpolation, RM gate)
  provides:
    - StackGameView (fully playable Stack game shell — chrome, loop, tap, banner, feedback)
    - StackHarnessView deleted (throwaway removed)
    - HomeView .stack destination wired to real game
  affects: [16-06-stats, 16-07-polish]
tech_stack:
  added: []
  patterns: [arcade-loop-lifecycle, scene-phase-dual-pause, counter-trigger-haptics-hapticsEnabled-first, video-mode-banner-centered, game-over-preroll-500ms, gaffer-prevCenterX-tracking, didInjectStats-one-shot, idle-explicit-empty-state]
key_files:
  created:
    - gamekit/gamekit/Games/Stack/StackGameView.swift
  modified:
    - gamekit/gamekit/Games/Stack/StackViewModel.swift
    - gamekit/gamekit/Screens/HomeView.swift
  deleted:
    - gamekit/gamekit/Games/Stack/StackHarnessView.swift
key_decisions:
  - "game-over pre-roll uses .grayscale(1.0) easeOut(0.5s) on StackBoardCanvas + 500ms Task.sleep before banner shows; RM/animations-off path sets showBanner immediately (no sleep)"
  - "showBanner state drives VideoModeBanner visibility; reset to false on restart (.idle) and re-computed on each .gameOver transition"
  - "prevCenterX tracked in StackGameView via .onChange(of: vm.frame.currentCenterX) { old, _ in prevCenterX = old } per 16-04 wiring note"
  - "accumulatorAlpha exposed via computed property on StackViewModel (accumulator/fixedDt clamped to 0...1)"
  - "placed array exposed via computed property on StackViewModel forwarding engine.placed"
  - "VideoModeLocation.largeBottom passed to VideoModeBanner (Stack is Video Mode exempt; location is not rendered by banner body)"
  - "Tap gesture checks vm.state == .running before setting pendingDrop — avoids accidental drop trigger from idle button area"
  - "No screen shake used at any point; no duplicate .error haptic (banner owns it)"
requirements-completed: [STACK-01, STACK-03, STACK-05, STACK-06]
duration: 29min
completed: "2026-06-29"
---

# Phase 16 Plan 05: StackGameView Summary

**Stack fully playable end-to-end: StackGameView shell wires arcade loop, tap-to-drop, VideoModeBanner game-over with 500ms color-drain pre-roll, gated perfect/normal haptics, and scenePhase dual-pause; throwaway harness deleted; Home routes to real game**

## Performance

- **Duration:** 29 min
- **Started:** 2026-06-29T21:05:18Z
- **Completed:** 2026-06-29T21:34:18Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 2 modified, 1 deleted)

## Accomplishments

- Created `StackGameView.swift` (224 lines < 250 cap) with full lifecycle: idle/running/game-over/restart, `.arcadeLoop`, scenePhase `.inactive` and `.background` both calling `vm.pause()`, and tap-to-drop wired to `vm.pendingDrop`
- Game-over path: 500ms `.grayscale` color-drain animation on the board (when `animationsEnabled && !reduceMotion`), then `VideoModeBanner(.loss)` centered with `.videoModeBannerTransition`; instant cut when RM or animations off
- Counter-trigger haptics with `hapticsEnabled` as FIRST guard: `.medium` on `perfectCount`, `.light` on `dropCount`; no duplicate `.error` (banner owns it)
- Visible combo/streak counter chip during running + game-over (D-04); explicit idle/tap-to-start screen (§8.3)
- Exposed `placed: [PlacedBlock]` and `accumulatorAlpha: Double` from `StackViewModel` for StackBoardCanvas wiring (plan 16-04 wiring notes fulfilled)
- Swapped `HomeView .stack` case from `StackHarnessView()` to `StackGameView()`; deleted `StackHarnessView.swift`; no `.videoModeAware` (ADR ARCADE-08)
- Build: BUILD SUCCEEDED on all passes

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StackGameView chrome, loop, tap, banner, haptics, slow-mo | 21d3e86 | StackGameView.swift (created), StackViewModel.swift (modified) |
| 2 | Swap Home destination; delete StackHarnessView | 6a1b3bb | HomeView.swift (modified), StackHarnessView.swift (deleted) |

## Files Created/Modified

- `gamekit/gamekit/Games/Stack/StackGameView.swift` — Chrome + lifecycle shell: arcadeLoop, scenePhase pause, tap-to-drop, idle screen, score/streak overlay, VideoModeBanner game-over, pre-roll, counter-trigger haptics, GameStats inject
- `gamekit/gamekit/Games/Stack/StackViewModel.swift` — Added `placed` and `accumulatorAlpha` computed properties for StackBoardCanvas wiring
- `gamekit/gamekit/Screens/HomeView.swift` — One-line swap: StackHarnessView() → StackGameView() in .stack case
- `gamekit/gamekit/Games/Stack/StackHarnessView.swift` — DELETED (throwaway Phase 15 harness per D-02)

## Decisions Made

- Game-over pre-roll: `.grayscale(1.0)` with `.easeOut(duration: 0.5)` on the Canvas view layer + `Task.sleep(for: .milliseconds(500))` before `showBanner = true`; RM/animations-off path skips sleep entirely (no artificial delay per DESIGN §10.3)
- `VideoModeLocation.largeBottom` passed as the `location` argument to `VideoModeBanner`; Stack is Video Mode exempt so any location works (banner body does not render the location)
- `onTapGesture` guards `vm.state == .running` so taps on the idle screen don't fire `pendingDrop` (idle Button handles its own tap via SwiftUI hit-testing order)
- `showBanner` resets to `false` both when state goes to `.idle` (restart) and at the start of any `.gameOver` transition (defense against stale state on rapid restart)

## Deviations from Plan

### Auto-added Missing Functionality (Rule 2)

**1. [Rule 2 - Missing Critical] Expose placed and accumulatorAlpha from StackViewModel**
- **Found during:** Task 1 (StackGameView creation)
- **Issue:** StackBoardCanvas requires `placed: [PlacedBlock]` and `accAlpha: Double` from outside (plan 16-04 wiring notes explicitly called this out). StackViewModel's `engine.placed` and `accumulator/fixedDt` were private.
- **Fix:** Added `var placed: [PlacedBlock] { engine.placed }` and `var accumulatorAlpha: Double { fixedDt > 0 ? min(accumulator / fixedDt, 1) : 0 }` as computed properties on StackViewModel. No behavior change to the VM — purely additive read-only surface.
- **Files modified:** `gamekit/gamekit/Games/Stack/StackViewModel.swift`
- **Committed in:** 21d3e86 (Task 1 commit)

---

**Total deviations:** 1 auto-added missing functionality (Rule 2)
**Impact on plan:** Essential for StackBoardCanvas wiring per 16-04 wiring notes. Purely additive.

## Known Stubs

None — StackGameView is a fully functional game shell. All data paths wired.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. All threat register items:
- **T-16-12** (loop running while backgrounded): mitigated — both `.inactive` and `.background` call `vm.pause()`; loop is off at game-over (grep confirms `arcadeLoop(isRunning: vm.state == .running)`).
- **T-16-13** (feedback not gated): mitigated — `hapticsEnabled ? vm.perfectCount : 0` and `hapticsEnabled ? vm.dropCount : 0` (first-guard pattern); `animationsEnabled && !reduceMotion` gates the pre-roll; no screen shake anywhere.
- **T-16-14** (harness causing duplicate-symbol / dead route): mitigated — StackHarnessView.swift deleted; zero StackHarness references in non-comment code.

## Issues Encountered

None — plan executed smoothly. Background build collisions (concurrent xcodebuild invocations) were resolved by waiting for prior build to complete before retrying.

## Next Phase Readiness

- Stack is fully playable end-to-end from Home
- Plan 16-06 (Stats screen integration) can now access the live game flow
- Plan 16-07 (polish/§8.12 theme audit) should audit Classic + Voltage/Dracula legibility on the StackBoardCanvas

## Self-Check: PASSED

- FOUND: gamekit/gamekit/Games/Stack/StackGameView.swift (224 lines)
- FOUND: gamekit/gamekit/Games/Stack/StackViewModel.swift (updated)
- FOUND: gamekit/gamekit/Screens/HomeView.swift (updated — StackGameView())
- DELETED (confirmed): gamekit/gamekit/Games/Stack/StackHarnessView.swift
- FOUND commit 21d3e86: feat(16-05): StackGameView chrome, loop, tap, banner, haptics, slow-mo
- FOUND commit 6a1b3bb: feat(16-05): swap Home destination to StackGameView; delete StackHarnessView
- Build: BUILD SUCCEEDED (exit code 0, confirmed by background task notification)
- No .videoModeAware in non-comment code
- arcadeLoop, hapticsEnabled haptic guards, VideoModeBanner: all verified
- Line count 224 < 250 cap
