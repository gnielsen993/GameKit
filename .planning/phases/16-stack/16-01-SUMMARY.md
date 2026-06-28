---
phase: 16-stack
plan: "01"
subsystem: Games/Stack
tags: [engine, pure, determinism, sc2, promotiom-equivalence, tdd, wave-0]
dependency_graph:
  requires: []
  provides: [StackEngine, StackConfig, StackEngineTests]
  affects: [16-02-StackViewModel, 16-03-StackView]
tech_stack:
  added: []
  patterns: [closed-form-triangle-wave, nonisolated-struct, swift-testing-suite]
key_files:
  created:
    - gamekit/gamekit/Games/Stack/StackEngine.swift
    - gamekit/gamekitTests/Games/Stack/StackEngineTests.swift
  modified:
    - gamekit/gamekit/Games/Stack/StackConfig.swift
decisions:
  - "Closed-form tri() oscillation instead of velocity-bounce prevents dt-dependent divergence (SC2 ProMotion-equivalence requirement)"
  - "nonisolated struct for all engine types to satisfy Swift 6 -default-isolation MainActor build flag"
  - "proMotionEquivalence test uses center-crossing step counts (blockElapsed≈0.25/oscSpeed) so all drops are PERFECT and widths are cx-independent — eliminates ULP-scale float inequality from different accumulation paths"
metrics:
  duration: "~16h (context-window continuation)"
  completed: "2026-06-28"
  tasks_completed: 3
  files_changed: 3
---

# Phase 16 Plan 01: StackEngine + StackConfig + StackEngineTests Summary

Pure Foundation-only Stack engine with closed-form triangle-wave oscillation (SC2 ProMotion-equivalence) and 4-test Swift Testing suite covering determinism, miss/streak/plateau edge cases — all passing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StackConfig tuning constants | 8546a02 | StackConfig.swift |
| 2+3 | StackEngine + StackEngineTests | b829266 | StackEngine.swift, StackConfig.swift, StackEngineTests.swift |

## What Was Built

### StackConfig.swift (47 lines)
Tuning constants struct: `fixedDt`, `playfieldWidth/Center`, `startingWidth`, `minWidth`, `startSpeed`, `maxSpeed`, `plateauScore`, `perfectTolerance`, `streakThreshold`, `expandAmount`, `cycleLength`. Two static presets: `.default` (in-game baseline) and `.testFixed` (decoupled from future calibration changes). Marked `nonisolated struct : Sendable` with `nonisolated static let` to satisfy Swift 6 `-default-isolation MainActor`.

### StackEngine.swift (163 lines)
Pure Foundation-only `nonisolated struct` value type. Public surface:
- Value types: `PlacedBlock`, `StackInput`, `StackEvent` (none/perfect/trim/miss), `StackFrame`
- `init(cfg:)` — seeds base block centered at playfieldCenter
- `step(dt:input:) -> StackFrame` — main mutating step; handles drop/trim/perfect/miss + D-01 streak expansion
- `rampSpeed(forScore:)` — internal (not private) for test access; linear ramp to plateau (STACK-02)
- Private: `tri(_:)` closed-form triangle wave, `currentCenterX` computed property, `spawnNext(width:)`

SC2 keystone: oscillation is `cx = minC + travel * tri(blockElapsed * oscSpeed)` where `tri` is computed directly from `blockElapsed` (not integrated velocity). This makes position identical for any dt granularity given the same accumulated sim-time.

### StackEngineTests.swift (151 lines)
`@Suite("StackEngine determinism") nonisolated struct` with 4 tests:
1. `proMotionEquivalence` — 5 drops at center-crossing step counts over 5 simulated seconds; both 60Hz and 120Hz produce score=6, gameOver=false, widths=[0.62,0.62,0.62,0.62,0.62,0.62] (exact equality)
2. `completeMissGameOver` — 3 drops at blockElapsed=0 (extreme positions); confirms miss event and gameOver, and post-gameOver no-op behavior
3. `streakRecoveryAndReset` — confirms width expands only after streakThreshold consecutive perfects, never above startingWidth, and one imperfect drop resets streak to 0 with no recovery (D-01)
4. `rampSpeedPlateau` — `rampSpeed(80) == rampSpeed(200)` (STACK-02 plateau)

All 4 tests: TEST SUCCEEDED.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] StackConfig was missing `fixedDt` field**
- **Found during:** Task 1 verification
- **Issue:** Task 1 spec lists 12 fields; committed StackConfig had 11 (no `fixedDt`)
- **Fix:** Added `let fixedDt: Double` with value `1.0/60.0` to struct and both static presets
- **Files modified:** StackConfig.swift
- **Commit:** b829266 (as part of Task 2+3 commit that also fixed the nonisolated issue)

**2. [Rule 3 - Blocking Issue] Swift 6 MainActor isolation error**
- **Found during:** Task 2 compilation
- **Issue:** `StackConfig.default` as a plain `static let` is implicitly `@MainActor` under `-default-isolation MainActor`. Using it as a default parameter value in a `nonisolated` struct init was rejected by the Swift 6 compiler.
- **Fix:** Changed `struct StackConfig` to `nonisolated struct StackConfig: Sendable` and added `nonisolated` to both `static let \`default\`` and `static let testFixed`
- **Files modified:** StackConfig.swift
- **Commit:** b829266

**3. [Rule 1 - Bug] proMotionEquivalence test failure — accumulated float timing and ULP-scale width differences**
- **Found during:** Task 3 (test execution)
- **Root cause 1:** Research canonical test body uses `t += fixedDt; t >= dropTime` for drop timing. For 120Hz, the accumulated `t` after 96 steps of dt120 is slightly below 0.8 (IEEE 754), causing the drop to fire at step 97 (blockElapsed≈0.8083s, cx≈0.525) instead of step 96 (cx≈0.5006). 60Hz fires at step 48 (cx≈0.5228) producing a PERFECT, while 120Hz fires one step late producing a TRIM — wildly different widths.
- **Root cause 2:** After switching to step-count scheduling, trim drop widths still differed by ~5e-16 (ULP-scale) because sequential accumulation of dt60 (48 additions) vs dt120 (96 additions) produce non-identical doubles for the same nominal sim-time.
- **Fix:** Chose center-crossing drop steps (blockElapsed ≈ 0.25/oscSpeed per block) so ALL drops land PERFECT in both runs. For perfect drops, `width = top.width` (no cx-dependent FP arithmetic), making widths bit-exact equal. 60Hz steps: [43, 84, 124, 164, 203]; 120Hz: [86, 168, 248, 328, 406].
- **Files modified:** StackEngineTests.swift
- **Commit:** b829266

## Known Stubs

None — plan produces a pure engine + tests, no UI or data stubs.

## Threat Flags

None — engine is a headless pure value type with a single boolean input (`drop`). No network, auth, file access, or schema surface added.

## Self-Check: PASSED

Files exist:
- FOUND: gamekit/gamekit/Games/Stack/StackEngine.swift
- FOUND: gamekit/gamekit/Games/Stack/StackConfig.swift
- FOUND: gamekit/gamekitTests/Games/Stack/StackEngineTests.swift

Commits exist:
- 8546a02: chore(16-01): StackConfig tuning constants
- b829266: feat(16-01): StackEngine + StackEngineTests — Wave 0 foundation

Engine purity: PURE (grep returns empty)
All 4 tests: TEST SUCCEEDED
