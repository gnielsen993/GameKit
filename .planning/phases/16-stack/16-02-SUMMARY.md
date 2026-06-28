---
phase: 16-stack
plan: "02"
subsystem: core-persistence
tags: [swiftdata, gamestats, stack, persistence, cloudkit-safe]
dependency_graph:
  requires: [16-01]
  provides: [recordStackRun, stackEndlessMode, stackPerfectStreakMode]
  affects: [GameStats.swift, GameStatsTests.swift]
tech_stack:
  added: []
  patterns: [evaluateBestScore-reuse, best-effort-do-catch, single-save, same-file-extension]
key_files:
  created: []
  modified:
    - gamekit/gamekit/Core/GameStats.swift
    - gamekit/gamekitTests/Core/GameStatsTests.swift
decisions:
  - "recordStackRun added as same-file extension to reach private evaluateBestScore"
  - "Two permanent serialization keys (endless/perfectStreak) locked with data-break comment"
  - "resetAll() confirmed to clear Stack data for free (deletes all BestScore rows)"
  - "Stack persists nothing in UserDefaults this phase — no resetAll addition needed"
metrics:
  duration: 10
  completed_date: "2026-06-28"
  tasks_completed: 2
  files_modified: 2
---

# Phase 16 Plan 02: recordStackRun + Persistence Test Summary

## One-liner

`GameStats.recordStackRun(score:perfectStreak:)` implemented as a same-file extension reusing higher-only `evaluateBestScore` for two `BestScore` rows, with a green persistence test proving CloudKit-safe D-11 streak tracking without any schema change.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | recordStackRun + permanent mode-key constants in GameStats | dae7d0c | GameStats.swift |
| 2 | recordStackRunWritesStreakWithoutSchemaChange persistence test | dae7d0c | GameStatsTests.swift |

Both tasks committed together per CLAUDE.md §5 (new pure services ship with tests in the same commit).

## What Was Built

### GameStats.swift (359 lines, under 400 cap)

Added a `// MARK: - Stack write path (Phase 16, STACK-04)` extension at the bottom of the file with:

- `static let stackEndlessMode = "endless"` — permanent serialization key (renaming = data break, commented as such)
- `static let stackPerfectStreakMode = "perfectStreak"` — permanent serialization key
- `func recordStackRun(score: Int, perfectStreak: Int) throws` — single write path for Stack game-over

The method body follows the existing score-record path ordering (insert FIRST → evaluate SECOND (best-effort) → save THIRD):
1. Inserts exactly ONE `GameRecord` (`gameKind: .stack`, `difficulty: "endless"`, `outcome: .loss`)
2. Evaluates `BestScore` for `"endless"` (high score) in best-effort `do/catch` if `score > 0`
3. Evaluates `BestScore` for `"perfectStreak"` in best-effort `do/catch` if `perfectStreak > 0`
4. Calls `try modelContext.save()` exactly once (force-quit survival)

Same-file extension used so the method can reach `private evaluateBestScore` (Swift allows private access from same-file extensions). The `logger` is also private but accessible for the same reason.

### GameStatsTests.swift

Added `recordStackRunWritesStreakWithoutSchemaChange` to the existing `@MainActor @Suite struct GameStatsTests`. Test asserts:

- Exactly 1 `GameRecord` after `recordStackRun(score: 42, perfectStreak: 7)` (runs-played stays honest)
- Exactly 2 `BestScore` rows (`"endless"` + `"perfectStreak"`)
- `"endless"` score == 42, `"perfectStreak"` score == 7
- Higher-only behavior: after `recordStackRun(score: 10, perfectStreak: 3)`, the `"perfectStreak"` row remains 7

## Verification

- `xcodebuild test -only-testing:gamekitTests/GameStatsTests`: **TEST SUCCEEDED**
- `recordStackRunWritesStreakWithoutSchemaChange` passed on iPhone 16 (iOS 18.5)
- `grep -q 'func recordStackRun' GameStats.swift && grep -q 'stackPerfectStreakMode' GameStats.swift` → OK
- `wc -l GameStats.swift` → 359 (< 400 cap)
- `grep -c "@Model" GameStats.swift` → 1 (comment only; no new `@Model` introduced, baseline unchanged)
- `grep -c "schemaVersion" GameStats.swift` → 0 in new code (no schema bump)
- Single `modelContext.save()` in `recordStackRun` body (line 357)

## resetAll() confirmation

`resetAll()` at line 175–195 already calls `try modelContext.delete(model: BestScore.self)` inside an atomic transaction. This deletes ALL `BestScore` rows regardless of game kind — Stack's two rows (`"endless"` and `"perfectStreak"`) clear for free. Stack persists nothing in `UserDefaults` this phase, so no addition to the `resetAll` per-game clear list is needed.

## Deviations from Plan

None — plan executed exactly as written. The same-file extension approach (specified in the plan) gave access to `private evaluateBestScore` without any structural change.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. The two new `BestScore` rows use the existing CloudKit-synced `@Model` with no new fields. The `"endless"` / `"perfectStreak"` raw string keys flowing through the persisted `difficultyRaw` column are matched by existing safe-fallback accessors (T-16-03 from the plan's threat register — mitigated by existing infrastructure).

## Self-Check: PASSED

- GameStats.swift: FOUND
- GameStatsTests.swift: FOUND
- 16-02-SUMMARY.md: FOUND
- commit dae7d0c: FOUND
