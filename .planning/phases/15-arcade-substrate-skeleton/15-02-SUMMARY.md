---
phase: 15-arcade-substrate-skeleton
plan: "02"
subsystem: games
tags: [swift6, swiftui, arcade, game-loop, harness, throwaway]

requires:
  - "15-01: ArcadeLoopDriver ViewModifier + ArcadeGameState enum"
provides:
  - "StackHarnessView: throwaway live-substrate harness driving .arcadeLoop, pauses on .inactive + .background"
  - "SnakeHarnessView: same harness shape with vertical oscillation, structurally identical to StackHarnessView"
affects:
  - "15-03 (HomeView destination + routing wires to StackHarnessView / SnakeHarnessView)"
  - "16-stack-game (StackGameView replaces StackHarnessView)"
  - "17-snake-game (SnakeGameView replaces SnakeHarnessView)"

tech-stack:
  added: []
  patterns:
    - "Throwaway harness file contains both VM + View (one file, two types, both under 100 lines)"
    - "StackHarnessVM / SnakeHarnessVM: @Observable @MainActor, ArcadeGameState, tickCount counter-trigger, fixed-timestep accumulator"
    - "scenePhase handler pauses on BOTH .inactive AND .background — critical distinction from turn-based Minesweeper (which omits .inactive)"
    - "PBXFileSystemSynchronizedRootGroup auto-registers new Games/Stack/ and Games/Snake/ subfolders — no pbxproj edits needed"

key-files:
  created:
    - gamekit/gamekit/Games/Stack/StackHarnessView.swift
    - gamekit/gamekit/Games/Snake/SnakeHarnessView.swift
  modified: []

key-decisions:
  - "Harness visual: Stack uses horizontal sine-wave oscillation, Snake uses vertical — distinguishes the two harnesses visually while both remain token-only"
  - "VM methods pause()/resume() guard on current state to avoid accidental transitions (pause from .idle is a no-op, resume from .idle is a no-op)"
  - "Both harnesses use .navigationBarBackButtonHidden(true) + custom chevron.backward toolbar button — consistent with MergeGameView and MinesweeperGameView patterns"

patterns-established:
  - "Arcade harness template: @Observable @MainActor VM with ArcadeGameState + tickCount + fixed-timestep accumulator; View drives .arcadeLoop + scenePhase dual-pause"

requirements-completed: [ARCADE-04, ARCADE-06]

duration: 7min
completed: "2026-06-27"
---

# Phase 15 Plan 02: Live-Substrate Harness Views Summary

**Two throwaway harness views (StackHarnessView + SnakeHarnessView) driving the real .arcadeLoop modifier with fixed-timestep accumulators, pausing on BOTH .inactive and .background scenePhase transitions**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-27T02:32:02Z
- **Completed:** 2026-06-27T02:39:20Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- StackHarnessView + StackHarnessVM in `Games/Stack/` — drives real `.arcadeLoop(isRunning: vm.state == .running)`, horizontally-oscillating Circle, scenePhase pauses on `.inactive` AND `.background` (ARCADE-04), counter-trigger tickCount (ARCADE-06)
- SnakeHarnessView + SnakeHarnessVM in `Games/Snake/` — structurally identical to Stack harness with vertically-oscillating dot to distinguish visually; same dual-phase pause handler
- Both files auto-registered by PBXFileSystemSynchronizedRootGroup — no pbxproj hand-edits (CLAUDE.md §8.8 validated again for new top-level Game subfolders)
- Full test suite green after both additions (ArcadeLoopDriverTests SC1a/SC1b still pass)
- Zero strict-concurrency warnings in both files

## Task Commits

Each task was committed atomically:

1. **Task 1: StackHarnessView + StackHarnessVM** - `c49d521` (feat)
2. **Task 2: SnakeHarnessView + SnakeHarnessVM** - `4902d56` (feat)

## Files Created/Modified

- `gamekit/gamekit/Games/Stack/StackHarnessView.swift` - Throwaway harness: StackHarnessVM (@Observable @MainActor, ArcadeGameState, tickCount, accumulator) + StackHarnessView (arcadeLoop, scenePhase dual-pause, token-only colors, back chevron)
- `gamekit/gamekit/Games/Snake/SnakeHarnessView.swift` - Same structure as Stack harness; vertically-oscillating dot; SnakeHarnessVM + SnakeHarnessView

## Decisions Made

- Harness visual: Stack horizontal sine oscillation, Snake vertical — distinguishes the two while both remain token-only and pause-respecting
- VM state guards: `pause()` only from `.running`, `resume()` only from `.paused` — no accidental transitions from `.idle`
- Back chevron matches MergeGameView pattern exactly (chevron.backward, 18pt semibold, textPrimary, 44×44 frame, `.plain` button style)

## Deviations from Plan

None — plan executed exactly as written. Both new Games/ subfolders auto-registered without pbxproj edits as expected (CLAUDE.md §8.8 / RESEARCH A3 fallback not needed).

## Known Stubs

Both harness views are intentionally throwaway stubs — they exist solely to verify the arcade substrate end-to-end. They are deleted and replaced by StackGameView / SnakeGameView in Phases 16/17 respectively. The stubs do not prevent any plan goals (they ARE the plan goal: a live exercise of the substrate).

## Threat Flags

None — no new network/auth/persistence surface introduced. scenePhase → vm.pause() dual-handler satisfies T-15-02 (denial-of-service via banner: loop stops on .inactive, zero CPU consumed).

## Self-Check: PASSED

- `gamekit/gamekit/Games/Stack/StackHarnessView.swift` exists: FOUND
- `gamekit/gamekit/Games/Snake/SnakeHarnessView.swift` exists: FOUND
- commit c49d521: FOUND
- commit 4902d56: FOUND
- Both files contain `case .inactive, .background:`: CONFIRMED
- Both files contain `.arcadeLoop(isRunning:`: CONFIRMED
- Both files contain `guard state == .running else { return }`: CONFIRMED (count >= 1)
- No `Color.` literals in either file: CONFIRMED (count = 0)
- Full test suite: PASSED (TEST SUCCEEDED)
- Build succeeded with zero strict-concurrency warnings: CONFIRMED

---
*Phase: 15-arcade-substrate-skeleton*
*Completed: 2026-06-27*
