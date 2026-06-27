---
phase: 15-arcade-substrate-skeleton
plan: "03"
subsystem: type-system / presentation
tags: [gamekind, accent-colors, canvas-icons, stats-view, swiftdata, cloudkit-safe]
dependency_graph:
  requires: [15-01, 15-02]
  provides: [GameKind.stack, GameKind.snake, accentColor, drawStack, drawSnake, StatsView placeholders]
  affects: [GameIconView.swift, StatsView.swift, GameKind.swift, GameKind+AccentColor.swift]
tech_stack:
  added: []
  patterns: [additive-enum-case, exhaustive-switch-extension, BestScore-query-pair, empty-state-placeholder]
key_files:
  created: []
  modified:
    - gamekit/gamekit/Core/GameKind.swift
    - gamekit/gamekit/Core/GameKind+AccentColor.swift
    - gamekit/gamekit/Screens/GameIconView.swift
    - gamekit/gamekit/Screens/StatsView.swift
decisions:
  - "D-07 accent colors locked: Stack=orange(0.961,0.498,0.122), Snake=green(0.176,0.741,0.490)"
  - "drawStack/drawSnake take color param only; no literal Color in draw functions"
  - "StatsView placeholders use BestScore (not BestTime) per score-based game shape"
  - "shows() function needed no modification — already works for any GameKind"
metrics:
  duration_minutes: 6
  completed_date: "2026-06-27"
  tasks_completed: 3
  files_modified: 4
---

# Phase 15 Plan 03: Type System Registration (GameKind + Icons + StatsView) Summary

**One-liner:** Registered Stack and Snake into the GameKit type system: additive enum cases with locked D-07 brand accent colors, distinct Canvas tile icons, and StatsView placeholder sections with explicit empty states — ROADMAP SC4 proven via ModelContainerSmokeTests.

## What Was Built

### Task 1: GameKind cases + D-07 accent colors (commit c6748ff)

Added `case stack` (raw: "stack") and `case snake` (raw: "snake") to `GameKind` after `wordGrid`. These raw values are permanent CloudKit-safe serialization keys — additive extension, no schema-version bump, no migration required.

Added two cases to `GameKind+AccentColor.swift` (the sole sanctioned literal-color file in Core/):
- Stack: `Color(red: 0.961, green: 0.498, blue: 0.122)` — vivid orange
- Snake: `Color(red: 0.176, green: 0.741, blue: 0.490)` — calm green

`ModelContainerSmokeTests` (all 3 cases) passed, proving ROADMAP SC4.

### Task 2: GameIconView Canvas draws (commit 7692390)

Extended the exhaustive `switch kind` in `GameIconView` with `case .stack:` and `case .snake:` (no default — compiler-enforced exhaustiveness that blocked the build until both cases were present).

`drawStack`: three offset rounded-rect blocks at varying opacities (0.35 / 0.65 / 1.00) suggesting a growing tower; a dim landing shadow line at y=32. Uses only the `color` param.

`drawSnake`: 7 square cells in an L-shaped path, opacity ramps from tail (0.25) to head (1.00), conveying directionality. Uses only the `color` param.

File stays at 275 lines (soft cap 400, hard cap 500). No literal `Color(` or `Color.` in either draw function. Clean build, zero strict-concurrency warnings.

### Task 3: StatsView @Query pairs + placeholder sections (commit d8c3f2f)

Added four `@Query` declarations (mirroring the merge/wordGrid BestScore pattern):
- `stackRecords` (GameRecord, filter `gameKindRaw == "stack"`, sort playedAt reverse)
- `stackBestScores` (BestScore, filter `gameKindRaw == "stack"`)
- `snakeRecords` / `snakeBestScores` equivalents

Added `shows(.stack)` and `shows(.snake)` sections in the ScrollView body after wordGrid. Each section contains a `settingsSectionHeader` (gated on `focusedKind == nil`) and a `DKCard` with explicit empty-state copy:
- "No Stack games yet." — `theme.colors.textSecondary`, `theme.spacing.m` padding
- "No Snake games yet." — same token usage

Placeholder sections are marked for replacement by StackStatsCard/SnakeStatsCard in Phases 16/17. The `shows()` function needed no modification — it already handles any `GameKind`. All strings use `String(localized:)`. Clean build, zero strict-concurrency warnings.

## Deviations from Plan

None — plan executed exactly as written.

The plan objective noted that `GameIconView` MUST be updated in the same PR as `GameKind` (exhaustive switch with no default would block the build). Task 2 was completed before Task 1's smoke-test verification ran, but both were committed separately as planned (Task 1 commit c6748ff preceded Task 2 commit 7692390 in the log).

## Success Criteria Met

- [x] `GameKind` has additive `.stack` and `.snake` cases with stable lowercase raw strings
- [x] Adding `.stack`/`.snake` passes `ModelContainerSmokeTests` with no migration and no schema-version bump (ROADMAP SC4)
- [x] Stack and Snake render distinct tile icons via `GameIconView` Canvas draws
- [x] `StatsView` shows Stack and Snake sections with explicit empty-state copy
- [x] All `GameKind` exhaustive switches stay green (AccentColor + GameIconView)
- [x] Clean build, zero strict-concurrency warnings

## Threat Surface Scan

No new trust boundaries introduced. Only additive enum cases, brand colors, Canvas drawing, and read-only `@Query` declarations. Threat T-15-03 (data integrity — additive raw-string schema extension) accepted per plan, with `ModelContainerSmokeTests` as the enforcement gate.

## Known Stubs

StatsView Stack and Snake sections are intentional Phase 15 placeholders — they display "No X games yet." because no gameplay exists until Phases 16/17. These are documented stubs, not accidental omissions. The placeholder sections will be wired with real `StackStatsCard`/`SnakeStatsCard` in their respective game phases.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| gamekit/gamekit/Core/GameKind.swift | FOUND |
| gamekit/gamekit/Core/GameKind+AccentColor.swift | FOUND |
| gamekit/gamekit/Screens/GameIconView.swift | FOUND |
| gamekit/gamekit/Screens/StatsView.swift | FOUND |
| 15-03-SUMMARY.md | FOUND |
| commit c6748ff (Task 1) | VERIFIED |
| commit 7692390 (Task 2) | VERIFIED |
| commit d8c3f2f (Task 3) | VERIFIED |
