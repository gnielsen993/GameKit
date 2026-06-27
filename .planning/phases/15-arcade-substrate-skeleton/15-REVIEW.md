---
phase: 15-arcade-substrate-skeleton
reviewed: 2026-06-26T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - gamekit/gamekit/Core/ArcadeGameState.swift
  - gamekit/gamekit/Core/ArcadeLoopDriver.swift
  - gamekit/gamekit/Core/GameKind.swift
  - gamekit/gamekit/Core/GameKind+AccentColor.swift
  - gamekit/gamekit/Core/GameRoute.swift
  - gamekit/gamekit/Core/GameDescriptor.swift
  - gamekit/gamekit/Games/Stack/StackHarnessView.swift
  - gamekit/gamekit/Games/Snake/SnakeHarnessView.swift
  - gamekit/gamekit/Screens/GameIconView.swift
  - gamekit/gamekit/Screens/StatsView.swift
  - gamekit/gamekit/Screens/HomeView.swift
  - gamekit/gamekitTests/Core/ArcadeLoopDriverTests.swift
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-06-26
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 15 introduced the ArcadeLoopDriver/ArcadeGameState substrate, Stack and Snake harness views, GameKind/GameRoute/GameDescriptor additive extensions, brand accent colors, Canvas icons, StatsView placeholders, and the modeless-tile direct-navigation fix. The Core additions are well-designed: the spiral-of-death clamp placement, scenePhase dual-pause (`.inactive` AND `.background`), and Swift 6 concurrency usage are all correct. No security vulnerabilities, data-loss paths, or crashes were identified.

The four warnings are: one Phase-15-specific preemptive risk (StatsView at 496 lines, 4 below the hard cap) and three pre-existing token-discipline violations in reviewed files that Phase 15 did not introduce but also did not repair (hardcoded spacing/font in HomeView tile builders, hardcoded `.white` in three GameIconView draw functions). The four info items cover dead code in the throwaway harnesses, unused-but-declared @Query properties, and a minor contract gap in ArcadeLoopDriver.

---

## Warnings

### WR-01: StatsView at 496 lines — one Phase 16/17 addition will breach the §8.5 hard cap

**File:** `gamekit/gamekit/Screens/StatsView.swift:1`
**Issue:** The file currently stands at 496 lines, 4 lines below the 500-line hard cap from CLAUDE.md §8.5. Phase 15 added approximately 20 lines (Stack/Snake `@Query` declarations plus two placeholder `DKCard` sections). Each of the two upcoming game phases (16 Stack, 17 Snake) will need to replace those placeholder sections with a real stats card — which, following the existing file-private pattern (`MinesStatsCard`, `MergeStatsCard`, `MergeModeStatsRow`, etc.), would add 50–80 lines each. The first such replacement pushes the file over 500 lines and triggers a mandatory split mid-phase.
**Fix:** Before Phase 16 begins, extract the file-private stats card structs (`MinesStatsCard`, `MinesDifficultyStatsRow`, `MergeStatsCard`, `MergeModeStatsRow`, and any future per-game cards) into a sibling file `StatsCards.swift` inside `Screens/`. The `StatsView.swift` body retains only the `@Query` declarations, the `shows()` guard, and the structural `VStack`. This is additive work, safe to do before or at the start of Phase 16 — do not defer it into Phase 17.

---

### WR-02: HomeView tile builders contain hardcoded spacing and font literals

**File:** `gamekit/gamekit/Screens/HomeView.swift:128,174,191,210,221,245,262`
**Issue:** Three distinct hardcoded values appear in the tile-builder code (pre-existing, not introduced by Phase 15):

- `LazyVGrid(columns: columns, spacing: 26)` at line 128 — should be a DesignKit spacing token.
- `VStack(spacing: 8)` at lines 174, 210, 245 — should be a DesignKit spacing token (likely `theme.spacing.xs` or `theme.spacing.s`).
- `.font(.system(size: 13, weight: .semibold))` at lines 191, 221, 262 — should be a DesignKit typography token (likely `theme.typography.caption.weight(.semibold)`).

These violate CLAUDE.md §1 ("No hard-coded colors / radii / spacing in UI. All styling reads DesignKit semantic tokens.") and DESIGN.md §1.3. They would render incorrectly if a future DesignKit spacing scale change is applied.
**Fix:**
```swift
// line 128
LazyVGrid(columns: columns, spacing: theme.spacing.l) {   // 26pt ≈ theme.spacing.l

// lines 174, 210, 245
VStack(spacing: theme.spacing.xs) {                        // 8pt ≈ theme.spacing.xs

// lines 191, 221, 262
.font(theme.typography.caption.weight(.semibold))
```
Verify the rendered sizes match the existing layout before landing.

---

### WR-03: GameIconView hardcodes `.white` in three pre-existing draw functions

**File:** `gamekit/gamekit/Screens/GameIconView.swift:149,203,226`
**Issue:** Three pre-existing draw functions use literal `.white`:

- `drawSolitaire` line 149: `c.fill(h, with: .color(.white.opacity(0.92)))` — heart pip on the front card.
- `drawFiveLetter` line 203: `.foregroundStyle(.white.opacity(0.95))` — letter labels on tile cells.
- `drawWordGrid` line 226: `ctx.stroke(path, with: .color(.white.opacity(0.95)), ...)` — word-path stroke.

These violate CLAUDE.md §1. On a white or near-white background these elements vanish. Phase 15 draw functions (`drawStack`, `drawSnake`) correctly avoid this pattern — they use only `color.opacity(...)`. The pre-existing functions should follow the same discipline.
**Fix:** Each hardcoded `.white` should be replaced by the passed `color` parameter, or by a second parameter (e.g., `onColor: Color = .white`) if a distinct foreground-on-background contrast is intentional. For the tile context (icon drawn on a colored rounded rect), `color` already provides the correct tint, and the pip/label should use a contrasting value relative to that. A pragmatic short-term fix:
```swift
// drawSolitaire: pass color through, let caller supply contrast color
c.fill(h, with: .color(color.opacity(0.92)))

// drawFiveLetter: same
.foregroundStyle(color.opacity(0.95))

// drawWordGrid: same
ctx.stroke(path, with: .color(color.opacity(0.95)), ...)
```

---

### WR-04: ArcadeLoopDriver `lastDate = nil` reset not guaranteed on rapid pause/resume

**File:** `gamekit/gamekit/Core/ArcadeLoopDriver.swift:47-49`
**Issue:** The `ArcadeLoopDriver` documents the invariant "lastDate resets to nil on isRunning → false — no stale anchor on resume; first tick after resume delivers dt=0." This holds in the common case. However, if `isRunning` transitions `false → true` within a single SwiftUI render cycle (e.g., `vm.pause()` and `vm.resume()` called synchronously before any re-render), SwiftUI may elide the intermediate `false` state in `.onChange(of: isRunning)`, meaning `lastDate = nil` never fires. The stale `lastDate` would then cause the first post-resume tick to compute `rawDt = newDate.timeIntervalSince(lastDate)` — potentially seconds — before the `min(rawDt, 0.1)` clamp caps it at 0.1 s. The spiral-of-death guard bounds the damage (≤6 fixed steps at 60 Hz), but the documented zero-dt-on-resume contract is not ironclad.

The practical trigger is unlikely from the scenePhase handler (OS phase transitions don't coalesce), but Phase 16/17 VMs may call `pause()`/`resume()` programmatically (e.g., in-game pause overlays) and could hit this path.
**Fix:** Reset `lastDate` on the `isRunning → true` transition as well, ensuring a clean start regardless of whether the prior `false` onChange fired:
```swift
.onChange(of: isRunning) { _, running in
    // Reset on both transitions: nil on pause (prevents stale anchor),
    // and also nil on resume (guarantees dt=0 on first tick regardless
    // of whether the false→true transition was coalesced).
    lastDate = nil
}
```
A `lastDate = nil` at resume is harmless — the TimelineView immediately fires a new date, and the `?? 0` fallback delivers dt=0 exactly as documented.

---

## Info

### IN-01: `stop()` method in both harness VMs is dead code

**File:** `gamekit/gamekit/Games/Stack/StackHarnessView.swift:66-69`, `gamekit/gamekit/Games/Snake/SnakeHarnessView.swift:66-69`
**Issue:** `StackHarnessVM.stop()` and `SnakeHarnessVM.stop()` are defined but never called. The views call only `vm.start()`, `vm.pause()`, and `vm.resume()`. View teardown (back navigation) destroys the VM naturally without needing `stop()`.
**Fix:** Since the harnesses are throwaway (deleted at Phase 16/17 start), either remove `stop()` now to keep the type surface minimal, or leave it as scaffolding — no functional impact either way.

---

### IN-02: `stackBestScores` and `snakeBestScores` @Query declarations are unused in the current view body

**File:** `gamekit/gamekit/Screens/StatsView.swift:134-145`
**Issue:** Both `@Query` properties are declared and backed by SwiftData but the placeholder section bodies (`DKCard { Text("No Stack games yet.") }`) do not reference them. SwiftData still evaluates the predicates on every update. Since no `GameRecord` with `gameKindRaw == "stack"` or `"snake"` exists yet, the overhead is trivial — but they add two live fetch descriptors with no current consumer.
**Fix:** No immediate action required; they exist as scaffolding for StackStatsCard/SnakeStatsCard in Phases 16/17. Document explicitly in the relevant PLAN.md that these @Query properties are pre-wired and ready.

---

### IN-03: SC1a test name and scope mismatch in ArcadeLoopDriverTests

**File:** `gamekit/gamekitTests/Core/ArcadeLoopDriverTests.swift:23-51`
**Issue:** The test is named "ArcadeLoopDriver substrate" / "onTick is gated on .running", but it tests a _simulated_ version of the VM guard pattern (`func simulateTick(state:dt:)` defined inline), not the actual `ArcadeLoopDriver` ViewModifier. The driver's `.onChange(of: context.date)` callback is untested by this suite (it requires SwiftUI context, which is excluded by design). The test correctly validates the VM contract invariant, but the suite name implies it covers the driver runtime behavior — which it does not.
**Fix:** Add a one-line comment above `onTickGating()` clarifying scope:
```swift
// Tests the VM-side guard contract (guard state == .running).
// ArcadeLoopDriver's TimelineView path requires SwiftUI context and
// is validated by the manual D-04 device test (15-05-SUMMARY.md).
```

---

### IN-04: `start()` does not clear the accumulator — risky pattern to copy to real VMs

**File:** `gamekit/gamekit/Games/Stack/StackHarnessView.swift:54-56`, `gamekit/gamekit/Games/Snake/SnakeHarnessView.swift:54-56`
**Issue:** `StackHarnessVM.start()` sets `state = .running` but does not reset `accumulator`. This is safe for the harness because the only path to `.idle` that Phase 15 provides is the initial construction (where `accumulator = 0`). However, when Phases 16/17 implement real VMs copying this harness as the template, a `restart()` scenario (game-over → new game) that calls `start()` without resetting the accumulator would carry forward a partial fixed step, causing the first game tick to be shorter than expected.
**Fix:** Add `accumulator = 0` to `start()` as a safe default — it costs nothing and prevents the pattern from silently becoming a bug when promoted:
```swift
func start() {
    accumulator = 0
    state = .running
}
```

---

_Reviewed: 2026-06-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
