# Sudoku Phase 16 — Stats Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface Sudoku stats in `StatsView` using the existing shared `GameStats` / `GameRecord` / `BestTime` infrastructure (no new SwiftData model). Add a `SudokuStatsCard` that displays per-difficulty Games / Wins / Avg / Best, wire it into `StatsView` with the existing `@Query` pattern, add a read-side helper to `GameStats` for played-puzzle IDs, and rewire `SudokuViewModel` to use the real played-IDs (replacing the Phase 15 TODO stub).

**Architecture:** Mirrors `NonogramStatsCard` consumption pattern exactly. `StatsView` owns the `@Query` for `sudokuRecords` + `sudokuBestTimes`, passes them as props to the card. The card is data-driven, props-only per CLAUDE.md §8.2 — no `@Query`, no `modelContext`. New `GameStats.sudokuPlayedIDs(for:)` adds the first **read** path to `GameStats` (write-only until now); follows the existing `FetchDescriptor` + `#Predicate` pattern used in `evaluateBestTime`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, DesignKit, Foundation.

**Reference design spec:** `Docs/superpowers/specs/2026-05-15-sudoku-integration-design.md`
**Phase 15 plan (prerequisite):** `Docs/superpowers/plans/2026-05-16-sudoku-phase-15-game-vertical-slice.md`

---

## What's already in place from Phase 15

- `SudokuViewModel.recordWin()` + `recordGameOver()` already call `GameStats.record(gameKind: .sudoku, ...)` on terminal transitions. The write path is fully wired — wins create `GameRecord` rows with `gameKindRaw == "sudoku"` + `puzzleIdRaw == <UUID>`, and update `BestTime` via the existing faster-only logic.
- `SudokuViewModel.loadFreshPuzzle` stubs `playedIDs` as `Set<String>()` with a `TODO(Phase 16)` comment. This plan replaces the stub.

---

## File structure

### New file (1)

```
gamekit/gamekit/Games/Sudoku/SudokuStatsCard.swift   ← NEW (mirrors NonogramStatsCard)
```

### Modified files (3)

```
gamekit/gamekit/Core/GameStats.swift                 ← add sudokuPlayedIDs(for:) helper
gamekit/gamekit/Games/Sudoku/SudokuViewModel.swift   ← swap the TODO stub for the real call
gamekit/gamekit/Screens/StatsView.swift              ← add @Query + section + card
```

### New test file (1)

```
gamekit/gamekitTests/SudokuStatsIntegrationTests.swift
```

### Modified files (release log)

```
Docs/releases/v1.2.md                                ← append Phase 16 entry
```

---

## Commit boundary

| Commit | Scope |
|---|---|
| `feat(16-01)` | All Phase 16 work in one commit (small surface, integration unit). |

---

## Task 1 — Add `sudokuPlayedIDs(for:)` to `GameStats.swift`

**Files:**
- Modify: `gamekit/gamekit/Core/GameStats.swift`

This is the **first read-side method** on `GameStats`. It follows the existing `FetchDescriptor` + `#Predicate` capture-let pattern used in `evaluateBestTime`. Place the method in the `// MARK: - Public API` section, after the existing `record(...)` overloads and before `resetAll()`.

- [ ] **Step 1: Inspect existing patterns**

Read `gamekit/gamekit/Core/GameStats.swift` to understand:
- `@MainActor final class GameStats` shape
- Constructor signature: `init(modelContext: ModelContext)`
- The `evaluateBestTime` `#Predicate` capture-let pattern (line ~176): a local `let kindRaw = gameKind.rawValue` is used because `#Predicate` cannot capture `self` in a KeyPath.

- [ ] **Step 2: Add the new method**

Insert this method into `GameStats.swift` after the second `record(...)` overload (around line 145), and BEFORE `resetAll()`:

```swift
// MARK: - Read API (Phase 16 — first read path on GameStats)

/// All puzzle IDs for a (gameKind, difficulty) the player has WON.
/// Source of truth = `GameRecord` rows (puzzle-based games store the
/// pool entry's UUID in `puzzleIdRaw`). Used by `SudokuViewModel` to
/// skip already-solved puzzles when the pool serves the next entry.
///
/// Capture-let per RESEARCH §Pattern 4 — `#Predicate` cannot capture
/// `self` in a KeyPath, so `gameKind.rawValue` is captured into
/// `kindRaw` before the predicate closure.
func wonPuzzleIDs(gameKind: GameKind, difficulty: String) -> Set<String> {
    let kindRaw = gameKind.rawValue
    let winRaw = Outcome.win.rawValue
    let descriptor = FetchDescriptor<GameRecord>(
        predicate: #Predicate { record in
            record.gameKindRaw == kindRaw
                && record.difficultyRaw == difficulty
                && record.outcomeRaw == winRaw
        }
    )
    let records = (try? modelContext.fetch(descriptor)) ?? []
    return Set(records.compactMap { $0.puzzleIdRaw })
}
```

The generic name `wonPuzzleIDs(gameKind:difficulty:)` is preferred over a Sudoku-specific name so future puzzle-based games (Crossword, etc.) reuse it without a rename.

- [ ] **Step 3: Build to confirm the method compiles**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 2 — Rewire `SudokuViewModel.loadFreshPuzzle` to use the real played-IDs

**Files:**
- Modify: `gamekit/gamekit/Games/Sudoku/SudokuViewModel.swift`

- [ ] **Step 1: Find the TODO stub**

In `SudokuViewModel.swift`, locate the `loadFreshPuzzle()` method. There is a line:

```swift
// TODO(Phase 16): swap to gameStats?.wonPuzzleIDs(gameKind: .sudoku, difficulty: difficulty.rawValue)
let playedIDs = Set<String>()
```

(The TODO comment may have used a slightly different method name — `sudokuPlayedIDs(for:)` was the name in the design spec. Use the actual signature added in Task 1: `wonPuzzleIDs(gameKind:difficulty:)`.)

- [ ] **Step 2: Replace the stub**

Replace the two lines with:

```swift
let playedIDs = gameStats?.wonPuzzleIDs(
    gameKind: .sudoku,
    difficulty: difficulty.rawValue
) ?? Set<String>()
```

- [ ] **Step 3: Build**

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify the existing 10 SudokuViewModel tests still pass**

```bash
xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:gamekitTests/SudokuViewModelTests \
  2>&1 | grep -E "Test Case|Executed" | tail -15
```

Expected: 10/10 pass. The tests use `injectTestBoardForUnitTests` which bypasses the pool entirely, so the played-IDs change doesn't affect them.

---

## Task 3 — `SudokuStatsCard.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuStatsCard.swift`

This is the user-visible stats panel. Mirrors `NonogramStatsCard` exactly — props-only, no `@Query`, no `modelContext`. Difference: include an **Avg** column (per-difficulty average win time) in addition to Games / Wins / Best.

- [ ] **Step 1: Inspect the reference**

Read `gamekit/gamekit/Games/Nonogram/NonogramStatsCard.swift` for:
- The Grid + GridRow header/divider pattern
- The per-difficulty row sub-struct pattern (`NonogramDifficultyStatsRow`)
- The empty-state copy + Tier coloring
- The mm:ss / h:mm:ss formatting helper

- [ ] **Step 2: Write `SudokuStatsCard.swift`**

```swift
//
//  SudokuStatsCard.swift
//  gamekit
//
//  Per-difficulty Sudoku stats panel for StatsView. Mirrors the
//  NonogramStatsCard / MinesStatsCard discipline: pure props, no @Query,
//  no modelContext access. Adds an "Avg" column on top of the Games /
//  Wins / Best trio so per-difficulty average win time is visible
//  alongside the personal-best.
//

import SwiftUI
import DesignKit

struct SudokuStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var hasAnyRecord: Bool { !records.isEmpty }

    var body: some View {
        if !hasAnyRecord {
            Text(String(localized: "No Sudoku games played yet."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: theme.spacing.m,
                    verticalSpacing: theme.spacing.s
                ) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text(String(localized: "Games")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Avg")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                    }
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)

                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 1)
                        .gridCellColumns(5)

                    ForEach(SudokuDifficulty.allCases, id: \.self) { diff in
                        SudokuDifficultyStatsRow(
                            theme: theme,
                            difficulty: diff,
                            records: records,
                            bestTimes: bestTimes
                        )
                    }
                }
            }
        }
    }
}

private struct SudokuDifficultyStatsRow: View {
    let theme: Theme
    let difficulty: SudokuDifficulty
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var wins: [GameRecord] {
        cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }
    }
    private var gamesCount: Int { cohort.count }
    private var winsCount: Int { wins.count }
    private var avgText: String {
        guard !wins.isEmpty else { return "—" }
        let total = wins.reduce(0.0) { $0 + $1.durationSeconds }
        return formatSeconds(total / Double(wins.count))
    }
    private var bestText: String {
        guard let s = bestTimes.first(where: {
            $0.difficultyRaw == difficulty.rawValue
        })?.seconds else { return "—" }
        return formatSeconds(s)
    }

    private func formatSeconds(_ s: Double) -> String {
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    var body: some View {
        GridRow {
            Text(difficulty.displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            statNumber("\(gamesCount)")
            statNumber("\(winsCount)")
            statNumber(avgText)
            statNumber(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(difficulty.displayName): \(gamesCount) games, \(winsCount) wins, average \(avgText), best \(bestText)"
        ))
    }

    @ViewBuilder
    private func statNumber(_ s: String) -> some View {
        Text(s)
            .font(theme.typography.monoNumber)
            .monospacedDigit()
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.trailing)
    }
}
```

- [ ] **Step 3: Confirm `SudokuDifficulty.displayName` exists**

Phase 15 (Task 1) added `displayName` returning `"Easy"|"Medium"|"Hard"|"Extreme"`. Verify by `grep displayName gamekit/gamekit/Games/Sudoku/SudokuDifficulty.swift`. If somehow missing, add it.

- [ ] **Step 4: Confirm `theme.typography.monoNumber` exists**

`NonogramStatsCard` uses it — should be a stable DesignKit token. If missing, fall back to `theme.typography.body.monospacedDigit()` (less ideal — `monoNumber` is the locked token per the existing usage).

---

## Task 4 — Wire `SudokuStatsCard` into `StatsView`

**Files:**
- Modify: `gamekit/gamekit/Screens/StatsView.swift`

- [ ] **Step 1: Add the @Query properties**

Open `gamekit/gamekit/Screens/StatsView.swift`. After the existing nonogram `@Query` blocks (around line 72), append:

```swift
@Query(
    filter: #Predicate<GameRecord> { $0.gameKindRaw == "sudoku" },
    sort: \.playedAt,
    order: .reverse
)
private var sudokuRecords: [GameRecord]

@Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "sudoku" })
private var sudokuBestTimes: [BestTime]
```

- [ ] **Step 2: Add the SUDOKU section to the body**

After the NONOGRAM section block (line ~109), append:

```swift
settingsSectionHeader(theme: theme, String(localized: "SUDOKU"))

DKCard(theme: theme) {
    SudokuStatsCard(
        theme: theme,
        records: sudokuRecords,
        bestTimes: sudokuBestTimes
    )
}
```

The section order is now Mines → Merge → Nonogram → Sudoku, matching drawer order.

- [ ] **Step 3: Build**

Expected: `** BUILD SUCCEEDED **`.

---

## Task 5 — `SudokuStatsIntegrationTests.swift`

**Files:**
- Create: `gamekit/gamekitTests/SudokuStatsIntegrationTests.swift`

- [ ] **Step 1: Write the tests**

```swift
//
//  SudokuStatsIntegrationTests.swift
//  gamekitTests
//
//  Integration tests for Phase 16 — verifies GameStats.record(gameKind:.sudoku, ...)
//  produces correct GameRecord rows, BestTime is updated only on faster wins,
//  and the new GameStats.wonPuzzleIDs(gameKind:difficulty:) read path returns
//  the right IDs.
//

import XCTest
import SwiftData
@testable import gamekit

@MainActor
final class SudokuStatsIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var stats: GameStats!

    override func setUp() async throws {
        let schema = Schema([GameRecord.self, BestTime.self, BestScore.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        stats = GameStats(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        stats = nil
        container = nil
    }

    func test_recordWin_createsGameRecordAndBestTime() throws {
        try stats.record(
            gameKind: .sudoku,
            difficulty: SudokuDifficulty.easy.rawValue,
            outcome: .win,
            durationSeconds: 120,
            puzzleId: "puzzle-1"
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.gameKindRaw, "sudoku")
        XCTAssertEqual(records.first?.difficultyRaw, "easy")
        XCTAssertEqual(records.first?.outcomeRaw, "win")
        XCTAssertEqual(records.first?.puzzleIdRaw, "puzzle-1")

        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 1)
        XCTAssertEqual(bests.first?.seconds, 120)
    }

    func test_recordLoss_doesNotUpdateBestTime() throws {
        try stats.record(
            gameKind: .sudoku,
            difficulty: SudokuDifficulty.hard.rawValue,
            outcome: .loss,
            durationSeconds: 300,
            puzzleId: "puzzle-2"
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        XCTAssertEqual(records.count, 1)
        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 0)
    }

    func test_fasterWin_updatesBestTime_slowerWin_doesNot() throws {
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 200, puzzleId: "p1")
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 150, puzzleId: "p2")
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 175, puzzleId: "p3")

        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 1)
        XCTAssertEqual(bests.first?.seconds, 150)
    }

    func test_wonPuzzleIDs_returnsOnlyWonRecords_andOnlyForRequestedDifficulty() throws {
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 60, puzzleId: "e1")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 70, puzzleId: "e2")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .loss, durationSeconds: 80, puzzleId: "e3")
        try stats.record(gameKind: .sudoku, difficulty: "hard", outcome: .win, durationSeconds: 200, puzzleId: "h1")

        let easyIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "easy")
        XCTAssertEqual(easyIDs, ["e1", "e2"])

        let hardIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "hard")
        XCTAssertEqual(hardIDs, ["h1"])

        let extremeIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "extreme")
        XCTAssertEqual(extremeIDs, [])
    }

    func test_wonPuzzleIDs_isolatedByGameKind() throws {
        // A Nonogram win must NOT appear in Sudoku's played-IDs.
        try stats.record(gameKind: .nonogram, difficulty: "easy", outcome: .win, durationSeconds: 100, puzzleId: "nono-1")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 100, puzzleId: "sud-1")

        let sudokuIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "easy")
        XCTAssertEqual(sudokuIDs, ["sud-1"])
        XCTAssertFalse(sudokuIDs.contains("nono-1"))
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:gamekitTests/SudokuStatsIntegrationTests \
  2>&1 | grep -E "Test Case|Executed" | tail -10
```

Expected: 5/5 pass.

---

## Task 6 — Append Phase 16 to release log + commit

**Files:**
- Modify: `Docs/releases/v1.2.md`

- [ ] **Step 1: Append the Phase 16 entry**

Add a new `## Internal changes (16)` section AFTER the existing `## Internal changes (15)` section in `Docs/releases/v1.2.md`:

```markdown
## Internal changes (16)
- **Phase 16 — Sudoku stats integration.** New `SudokuStatsCard`
  surfaces per-difficulty Games / Wins / Avg / Best in `StatsView`
  (4th game-stats panel; section order matches drawer order). Card
  is data-driven props-only per §8.2 — reads from shared
  `GameRecord` + `BestTime` SwiftData models, no new model. New
  `GameStats.wonPuzzleIDs(gameKind:difficulty:)` adds the first
  read-side method to `GameStats` (write-only until now), backing
  the `SudokuPuzzlePool`'s played-puzzle skip logic via the
  ViewModel — Phase 15's TODO stub replaced. No SwiftData schema
  bump; adding the `.sudoku` GameKind rawValue is additive per §1.
  Tests: `SudokuStatsIntegrationTests` (5 cases) cover record-on-win,
  no-best-on-loss, faster-only best updates, per-difficulty filter,
  and game-kind isolation — all green.
```

- [ ] **Step 2: Final build + tests**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

```bash
xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:gamekitTests/SudokuStatsIntegrationTests \
  -only-testing:gamekitTests/SudokuViewModelTests \
  -only-testing:gamekitTests/SudokuPuzzlePoolTests \
  -only-testing:gamekitTests/SudokuBoardTests \
  2>&1 | grep -E "Executed|TEST SUCCEEDED|FAILED" | tail -5
```
Expected: All 4 suites green.

- [ ] **Step 3: Commit**

```bash
git add gamekit/gamekit/Core/GameStats.swift \
        gamekit/gamekit/Games/Sudoku/SudokuViewModel.swift \
        gamekit/gamekit/Games/Sudoku/SudokuStatsCard.swift \
        gamekit/gamekit/Screens/StatsView.swift \
        gamekit/gamekitTests/SudokuStatsIntegrationTests.swift \
        Docs/releases/v1.2.md
git commit -m "$(cat <<'EOF'
feat(16-01): Sudoku stats — card + GameStats read path + played-IDs rewire

Phase 16: surface Sudoku stats in StatsView using the shared
GameRecord / BestTime infrastructure (no new SwiftData model).

- SudokuStatsCard: per-difficulty Games / Wins / Avg / Best,
  props-only data-driven view (mirrors NonogramStatsCard)
- StatsView: @Query for sudokuRecords + sudokuBestTimes, SUDOKU
  section appended after NONOGRAM (drawer order preserved)
- GameStats.wonPuzzleIDs(gameKind:difficulty:): first read-side
  method on GameStats. Follows existing FetchDescriptor +
  #Predicate capture-let pattern from evaluateBestTime
- SudokuViewModel.loadFreshPuzzle: replaces the Phase 15 TODO stub
  with the real call — pool now skips puzzles the player has won

Tests: SudokuStatsIntegrationTests (5 cases) — record-on-win,
no-best-on-loss, faster-only update, per-difficulty filter,
game-kind isolation. All Sudoku tests still green (28 total).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Summary of what this plan delivers

After all 6 tasks complete:

1. `Games/Sudoku/SudokuStatsCard.swift` — new card view, 5 columns (Difficulty / Games / Wins / Avg / Best).
2. `StatsView` shows the SUDOKU section below NONOGRAM.
3. `GameStats.wonPuzzleIDs(gameKind:difficulty:)` — first read path; reusable for any future puzzle-based game.
4. `SudokuViewModel` now skips already-won puzzles via real played-IDs query.
5. `SudokuStatsIntegrationTests` (5 tests) green.
6. Phase 16 release log entry appended to `Docs/releases/v1.2.md`.

---

## Open items for downstream phases

- **Phase 17** — Full 1500-per-difficulty pack generation. Independent of this plan (just runs `tools/GenerateSudokuPack`).
- **Solved-puzzles gallery for Sudoku** — Nonogram has `SolvedNonogramsView`. Sudoku does not in v1.2 — punt to v1.3.
- **Export/import schema** — Adding `.sudoku` GameKind rawValue is additive (no `schemaVersion` bump). Verify via the existing `StatsExporter` round-trip test if it exists; otherwise leave as-is.

---

*End of Phase 16 plan.*
