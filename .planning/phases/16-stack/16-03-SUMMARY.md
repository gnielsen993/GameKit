---
phase: 16-stack
plan: "03"
subsystem: Games/Stack
tags: [viewmodel, observable, mainactor, fixed-timestep, foundation-only, swiftdata-firewall, counter-trigger-haptics]
dependency_graph:
  requires: [16-01-StackEngine, 16-02-recordStackRun]
  provides: [StackViewModel]
  affects: [16-04-StackGameView, 16-05-StackBoardCanvas]
tech_stack:
  added: []
  patterns: [observable-mainactor-class, fixed-timestep-accumulator, single-tap-latch, swiftdata-firewall, counter-trigger-haptics, one-shot-stats-attach, arcade-game-state-lifecycle]
key_files:
  created:
    - gamekit/gamekit/Games/Stack/StackViewModel.swift
  modified: []
decisions:
  - "restart() sets state = .idle (not .running) so tap-to-start affordance re-shows — matches StackHarnessVM stop+start pattern"
  - "fixedDt sourced from StackConfig.fixedDt (not duplicated as a literal) — single source of truth for the sim timestep"
  - "Initial StackFrame constructed manually (score: 1 matching engine's placed.count after init) — engine.frame(event:) is private so no shortcut available"
metrics:
  duration: 291
  completed: "2026-06-28"
  tasks_completed: 2
  files_changed: 1
---

# Phase 16 Plan 03: StackViewModel Summary

`@Observable @MainActor StackViewModel` bridging the arcade loop to the pure `StackEngine` via a `while accumulator >= fixedDt` fixed-timestep loop, with single-tap latching, perfectCount/dropCount counter-trigger haptics, one-shot GameStats attachment, and a single `recordStackRun` call on the `.running` → `.gameOver` transition.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1+2 | VM skeleton + counters + save-on-game-over | e6d6cdb | StackViewModel.swift |

Tasks 1 and 2 both write to the same file (`StackViewModel.swift`) and the skeleton from Task 1 is only correct in conjunction with the counter/persistence wiring from Task 2; they were implemented and committed together as a single atomic unit.

## What Was Built

### StackViewModel.swift (148 lines)

`@Observable @MainActor final class StackViewModel` — Foundation-only (no SwiftUI/SwiftData imports, SwiftData firewall enforced).

**State surface (all `private(set)`):**
- `state: ArcadeGameState = .idle` — lifecycle state (idle/running/paused/gameOver)
- `frame: StackFrame` — latest engine snapshot; Canvas reads this each draw
- `perfectCount: Int` — counter-trigger for `.impact(.medium)` haptic
- `dropCount: Int` — counter-trigger for `.impact(.light)` haptic
- `gameStats: GameStats?` — opaque reference, never imports SwiftData

**Tap input:** `var pendingDrop: Bool = false` — fully writable from view (no `private(set)`); main-actor, no Sendable concern.

**Lifecycle:** `start()` / `pause()` / `resume()` / `stop()` — verbatim shape from `StackHarnessVM` (StackHarnessView.swift:54-70). `start()` clears the accumulator to prevent stale-time replay.

**Fixed-timestep tick:**
```swift
func tick(dt: Double) {
    guard state == .running else { return }
    accumulator += dt
    while accumulator >= fixedDt {
        let input = StackInput(drop: pendingDrop)
        pendingDrop = false          // latch consumed; one tap = one step
        let newFrame = engine.step(dt: fixedDt, input: input)
        accumulator -= fixedDt
        frame = newFrame
        // bump perfectCount / dropCount
        // game-over transition: save once, return
    }
}
```
No second dt clamp (ArcadeLoopDriver clamps upstream). `pendingDrop` cleared inside the while loop — exactly one engine step per tap.

**Game-over:** On `newFrame.gameOver` (the single `.running` → `.gameOver` transition): set `state = .gameOver`, call `try? gameStats?.recordStackRun(score:perfectStreak:)` exactly once, `return`. One call site enforced — `grep -c "recordStackRun" StackViewModel.swift` == 1.

**Counter-trigger haptics:** `perfectCount` bumps on `.perfect(_)` event, `dropCount` on `.trim(_)` event. No game-over counter — `VideoModeBanner` owns `.error` haptic.

**GameStats attach:** `func attachGameStats(_ stats: GameStats)` with `didAttachStats: Bool` one-shot guard (mirrors MergeViewModel.swift:79-83).

**Restart:** Resets `engine`, `accumulator`, `perfectCount`, `dropCount`, `pendingDrop`, `frame`, and `state = .idle`. Tap-to-start affordance re-shows after restart.

## Verification

**Task 1 acceptance:**
- `@Observable @MainActor final class StackViewModel`: present
- Foundation-only: `grep -rn 'import SwiftData|import SwiftUI' StackViewModel.swift` — empty
- `while accumulator >= fixedDt` loop: present
- No dt clamp: `grep -c "0.1)" StackViewModel.swift` == 0
- All externally-read state is `private(set)`: confirmed

**Task 2 acceptance:**
- `perfectCount` / `dropCount` increment on `.perfect` / `.trim`: confirmed
- No game-over haptic counter: `grep -c "gameOverCount|terminalCount|errorCount" StackViewModel.swift` == 0
- Single `recordStackRun` call site: `grep -c "recordStackRun" StackViewModel.swift` == 1
- `attachGameStats(_:)` one-shot guard: confirmed (`didAttachStats` guard)
- `restart()` resets engine + counters + accumulator: confirmed
- Foundation-only import: confirmed
- `wc -l` == 148 (< 200)

**Build:** `xcodebuild build -project gamekit.xcodeproj -scheme gamekit` → **BUILD SUCCEEDED**

## Deviations from Plan

None — plan executed exactly as written.

The only implementation choice exercised via "Claude's Discretion" was `restart()` setting `state = .idle` (documented in decisions). This matches the StackHarnessVM pattern where `stop()` sets idle and a new `start()` call is required from the tap affordance.

## Known Stubs

None — StackViewModel is a logic/bridge class with no UI stubs.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The SwiftData firewall is maintained (Foundation-only import). T-16-06 (per-frame disk write DoS) mitigated: `recordStackRun` call confirmed at exactly one call site, on the gameOver transition only. T-16-07 (SwiftData architecture drift) mitigated: Foundation-only import grep gate passes.

## Self-Check: PASSED

- FOUND: gamekit/gamekit/Games/Stack/StackViewModel.swift
- FOUND commit e6d6cdb
- Build: BUILD SUCCEEDED
