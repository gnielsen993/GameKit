---
phase: 18-stats-design-specs-adr
reviewed: 2026-07-06T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - gamekit/gamekit/Screens/ScoreStatsCard.swift
  - gamekit/gamekit/Screens/StackStatsCard.swift
  - gamekit/gamekit/Screens/SnakeStatsCard.swift
  - gamekit/gamekit/App/GameKitApp.swift
  - gamekit/gamekit/Core/ScreenshotSeeder.swift
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-07-06
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Five files reviewed: the shared `ScoreStatsCard` layout component, two thin wrapper cards (`StackStatsCard`, `SnakeStatsCard`), and the two files touched for screenshot-seeding infrastructure (`GameKitApp.swift`, `ScreenshotSeeder.swift`). Token discipline is clean — no hard-coded colors, radii, or spacing anywhere. The component hierarchy (shared layout + game-specific wrappers) is well-structured and clearly documented. No critical/data-loss issues found.

Four warnings were found: a SwiftUI identity anti-pattern in `ScoreStatsCard`, a fragile raw-string key in `SnakeStatsCard`, a silent encoding failure in `ScreenshotSeeder`, and a force-unwrap in the Sudoku cell helper that crashes at runtime if the hard-coded string is ever touched. Two info items cover minor code smell in the seeder.

---

## Warnings

### WR-01: `ForEach(metrics.indices, id: \.self)` uses integer index as view identity

**File:** `gamekit/gamekit/Screens/ScoreStatsCard.swift:99`

**Issue:** `ForEach(metrics.indices, id: \.self)` uses the integer offset as the SwiftUI stable identity for each metric row. SwiftUI's diffing engine cannot distinguish "row 0 in Stack card" from "row 0 in Snake card" — it sees the same integer `0`. In the current codebase the metric count is always fixed (3 for Stack, 2 for Snake) and `ScoreMetric` carries no internal `@State`, so no user-visible data is corrupted today. But the pattern is fragile: if metric count ever changes (e.g., a game adds a conditional extra row), SwiftUI may animate the wrong rows or silently reuse the wrong view state. It also prevents the compiler from warning about future conformance gaps on `ScoreMetric`.

**Fix:** Make `ScoreMetric` `Identifiable` — the `label` string is unique per card type and sufficient as a stable id — then drive `ForEach` directly off the array:

```swift
struct ScoreMetric: Identifiable {
    var id: String { label }       // label is unique within any given card
    let label: String
    let value: String
    let a11yLabel: String
}

// ScoreStatsCard.metricsContent:
ForEach(metrics) { metric in
    metricRow(label: metric.label, value: metric.value, a11yLabel: metric.a11yLabel)
}
```

---

### WR-02: `SnakeStatsCard` looks up the high-score key via a raw string literal with no constant protection

**File:** `gamekit/gamekit/Screens/SnakeStatsCard.swift:32`

**Issue:** `SnakeStatsCard.highScoreText` compares against the raw literal `"endless"`. The same literal appears unprotected in `SnakeViewModel.swift` (three times: lines 185, 202, 219), `ScreenshotSeeder.swift` (lines 163–168), and in test assertions — six total occurrences across four files, none gated by a constant. If the Snake write path ever changes its `difficultyRaw` key, all six sites must be updated by hand; the compiler gives no warning when one is missed, and `highScoreText` silently returns `"—"` with no error. By contrast, `StackStatsCard` uses `GameStats.stackEndlessMode` (defined in `GameStats.swift:315`), which provides compile-time safety.

The comment documents the deliberate omission of a constant ("NOT a GameStats constant — do not promote to one"), but that reasoning protects against accidental promotion — it does not justify leaving the literal unguarded across four files. A `private` or `internal` constant local to `GameStats` (analogous to `stackEndlessMode`) would satisfy the lock-in concern while making any future rename a one-file change.

**Fix:** Add a parallel constant to `GameStats.swift`:

```swift
// GameStats.swift (alongside stackEndlessMode / stackPerfectStreakMode)
static let snakeEndlessMode = "endless"   // PERMANENT KEY — D-12 data-break lock
```

Then replace all raw `"endless"` Snake-path literals:

```swift
// SnakeStatsCard.swift:32
$0.difficultyRaw == GameStats.snakeEndlessMode

// SnakeViewModel.swift:185, 202, 219
mode: GameStats.snakeEndlessMode

// ScreenshotSeeder.swift:164, 168
difficulty: GameStats.snakeEndlessMode
```

---

### WR-03: `ScreenshotSeeder.encode` silently discards encoding failures

**File:** `gamekit/gamekit/Core/ScreenshotSeeder.swift:255–258`

**Issue:** The private `encode` helper uses `try?` and silently drops the failure when `JSONEncoder.encode` throws:

```swift
private static func encode<T: Encodable>(_ value: T, to key: String, ...) {
    if let data = try? encoder.encode(value) {
        defaults.set(data, forKey: key)
    }
    // failure: no log, no indication anything was skipped
}
```

In a screenshot session, a silent failure here means a save-state never gets written to `UserDefaults`, so the screenshot shows an incorrect (empty or stale) in-progress game state with no diagnostic output. The symptom looks identical to "the seeder ran but the game hasn't loaded yet," making it hard to distinguish from a timing race.

**Fix:** Log the failure so it surfaces in the console during screenshot sessions:

```swift
private static func encode<T: Encodable>(_ value: T, to key: String, defaults: UserDefaults, encoder: JSONEncoder) {
    do {
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
    } catch {
        print("❌ ScreenshotSeeder: failed to encode \(T.self) for key '\(key)': \(error)")
    }
}
```

---

### WR-04: Force-unwrap in `makeSudokuCells` crashes if the solution string is ever modified

**File:** `gamekit/gamekit/Core/ScreenshotSeeder.swift:245`

**Issue:** `makeSudokuCells` force-unwraps the `Int` conversion of each character in the `solution` string:

```swift
let s = solution.map { Int(String($0))! }
```

The solution string is currently a hard-coded 81-digit constant defined 10 lines above. However, if someone editing the seeder accidentally inserts a space, letter, or newline — even during a merge conflict resolution — this crashes in the `#if DEBUG` path during a screenshot session, aborting the entire seed run with no SwiftData records written (the `save()` at line 47 has already been called for SwiftData, but this runs in `seedSaveStates()` after the save, so partial seeding state is left in the container).

`givens` has the same pattern (`Int(String($0))!`) but is slightly less risky because the non-digit branch is handled first (`$0 == "0" ? 0 : Int(String($0))!`).

**Fix:** Replace force-unwraps with guarded conversions and a diagnostic print:

```swift
let s = solution.compactMap { Int(String($0)) }
guard s.count == 81 else {
    print("❌ ScreenshotSeeder: invalid solution string (count \(s.count)); Sudoku save state skipped.")
    return
}
```

---

## Info

### IN-01: `isActive` and `isArcadeActive` re-parse `CommandLine.arguments` on every access

**File:** `gamekit/gamekit/Core/ScreenshotSeeder.swift:29–37` / `gamekit/gamekit/App/GameKitApp.swift:138–141`

**Issue:** Both `isActive` and `isArcadeActive` are `static var` computed properties that call `CommandLine.arguments.contains(...)` each time they are read. `GameKitApp.init()` reads them three times in total (line 138 reads each once; line 141 reads `isArcadeActive` again). `CommandLine.arguments` is immutable after process launch, so the repeated parsing is redundant.

**Fix:** Change to `static let` to evaluate once:

```swift
static let isActive: Bool = CommandLine.arguments.contains("--screenshots")
static let isArcadeActive: Bool = CommandLine.arguments.contains("--screenshots-arcade")
```

---

### IN-02: `isEmpty` check driven by `records` while high-score hero reads from `bestScores`

**File:** `gamekit/gamekit/Screens/StackStatsCard.swift:77` / `gamekit/gamekit/Screens/SnakeStatsCard.swift:66`

**Issue:** Both wrappers pass `isEmpty: records.isEmpty`, but `heroValue` (`highScoreText`) reads from `bestScores`. In steady state this is consistent — a game that has been played always writes both a `GameRecord` and a `BestScore`. However, during a CloudKit sync where `BestScore` rows arrive before `GameRecord` rows (delivery order is not guaranteed), the card shows "No runs yet." even though a high score is already present. The reverse scenario (records arrive before best scores) shows the metrics grid with `"—"` as the hero, which is acceptable.

The current behavior is reasonable and matches the documented spec (D-03: empty state = no runs), but it is worth calling out so future sync edge-case investigations know where to look.

**Fix (optional):** To make the empty gate data-source-consistent with the hero, drive it from `bestScores` instead:

```swift
isEmpty: bestScores.first(where: { $0.difficultyRaw == GameStats.stackEndlessMode }) == nil
```

Only adopt this if CloudKit sync ordering becomes a user-reported issue; the current approach is defensible for v1.

---

_Reviewed: 2026-07-06_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
