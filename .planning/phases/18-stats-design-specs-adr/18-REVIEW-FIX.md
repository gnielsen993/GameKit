---
phase: 18-stats-design-specs-adr
fixed_at: 2026-07-06T20:31:00Z
review_path: .planning/phases/18-stats-design-specs-adr/18-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Fixed at:** 2026-07-06
**Source review:** `.planning/phases/18-stats-design-specs-adr/18-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01 through WR-04; IN-01 and IN-02 excluded per fix_scope: critical_warning)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: `ForEach(metrics.indices, id: \.self)` uses integer index as view identity

**Files modified:** `gamekit/gamekit/Screens/ScoreStatsCard.swift`
**Commit:** 453d53b
**Applied fix:** Added `Identifiable` conformance to `ScoreMetric` with `var id: String { label }` (label is unique within any card). Changed `ForEach(metrics.indices, id: \.self) { index in metrics[index] }` to `ForEach(metrics) { metric in }` so SwiftUI diffing uses the stable string identity rather than the integer offset.

---

### WR-02: `SnakeStatsCard` looks up the high-score key via a raw string literal with no constant protection

**Files modified:**
- `gamekit/gamekit/Core/GameStats.swift`
- `gamekit/gamekit/Screens/SnakeStatsCard.swift`
- `gamekit/gamekit/Games/Snake/SnakeViewModel.swift`
- `gamekit/gamekit/Core/ScreenshotSeeder.swift`
- `gamekit/gamekitTests/Core/GameStatsTests.swift`

**Commit:** 1fac58a
**Applied fix:** Added `static let snakeEndlessMode = "endless"` to the existing permanent-key block in `GameStats.swift` (alongside `stackEndlessMode`). Replaced all six raw `"endless"` Snake-path literals:
- `SnakeStatsCard.swift:32` — the `bestScores.first(where:)` comparison
- `SnakeViewModel.swift:185, 202, 219` — all three `bestScore(gameKind:mode:)` / `record(gameKind:mode:)` call sites
- `ScreenshotSeeder.swift:164, 168` — both `BestScore` and `GameRecord` inserts in `seedArcadeStats`
- `GameStatsTests.swift` — the two `mode:` arguments and both `#Predicate` comparisons (captured via local `let snakeKey = GameStats.snakeEndlessMode` for SwiftData predicate compatibility)

Comments referencing "NOT a GameStats constant — do not promote to one" were updated to reflect the new constant.

---

### WR-03: `ScreenshotSeeder.encode` silently discards encoding failures

**Files modified:** `gamekit/gamekit/Core/ScreenshotSeeder.swift`
**Commit:** 81f48d1
**Applied fix:** Replaced `if let data = try? encoder.encode(value)` with a `do/catch` block that prints `"❌ ScreenshotSeeder: failed to encode \(T.self) for key '\(key)': \(error)"` on failure. Encoding failures now surface in the console during screenshot sessions instead of silently producing empty/stale UI state.

---

### WR-04: Force-unwrap in `makeSudokuCells` crashes if the solution string is ever modified

**Files modified:** `gamekit/gamekit/Core/ScreenshotSeeder.swift`
**Commit:** a77f45f
**Applied fix:** Replaced `solution.map { Int(String($0))! }` with `solution.compactMap { Int(String($0)) }` followed by a `guard s.count == 81` check that prints a diagnostic and returns `[]` early. The `givens` line retains its original form (the non-digit branch is handled first by the ternary and the reviewer rated it lower risk; the minimal-change principle favoured leaving it untouched).

---

_Fixed: 2026-07-06_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
