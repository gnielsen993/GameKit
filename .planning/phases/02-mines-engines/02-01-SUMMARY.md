---
phase: 02-mines-engines
plan: 01
subsystem: minesweeper-models
tags: [swift, swift6, minesweeper, models, foundation-only, value-types]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: gamekit app target, Swift 6 strict concurrency, file-header convention, synchronized root group auto-registration of Games/ subfolder
provides:
  - MinesweeperDifficulty enum with locked easy/medium/hard cases + mechanical rows/cols/mineCount
  - MinesweeperIndex Hashable struct with bounds-clamped neighbors8(rows:cols:)
  - MinesweeperCell value type + State enum (hidden/revealed/flagged/mineHit) + precomputed adjacentMineCount
  - MinesweeperBoard immutable struct with flat [Cell] storage and pure replacingCell(at:with:) / replacingCells(_:) transforms
  - MinesweeperGameState lifecycle enum (idle/playing/won/lost(mineIdx:))
affects:
  - 02-02 (SeededGenerator helper — still independent, but Plan 03 consumes both)
  - 02-03 (BoardGenerator — directly consumes Difficulty + Index + Cell + Board)
  - 02-04 (RevealEngine — directly consumes Board + Cell + Index)
  - 02-05 (WinDetector — directly consumes Board + Cell)
  - 03-* (MinesweeperViewModel — consumes GameState, Board, Index, Cell)
  - 04-* (Stats persistence — Difficulty.rawValue is the locked stable serialization key per D-02)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-Foundation engine model layer (no SwiftUI/SwiftData/UIKit/GameplayKit/Observation/Combine)"
    - "Immutable value-type Board with copy-on-mutate semantics (D-10)"
    - "Set-based first-tap-safe exclusion via Hashable Index (D-09)"
    - "Single-enum Cell.State representation (CONTEXT.md Claude's Discretion recommendation)"
    - "Adjacency precomputed at generation, stored as let on Cell (read-many, compute-once)"

key-files:
  created:
    - gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperIndex.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperCell.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameState.swift
  modified: []

key-decisions:
  - "Difficulty raw values lowercase strings ('easy'/'medium'/'hard') — stable serialization key for P4 (D-02)"
  - "Difficulty has no displayName / String(localized:) / description — engine layer carries no localized names (D-03)"
  - "MinesweeperGameState.lost carries mineIdx: MinesweeperIndex so P3 renders mineHit without diffing"
  - "MinesweeperGameState NOT Codable — P4 persists outcome (GameRecord), not live state machine"
  - "Board uses flat [Cell] indexed row*cols+col (Swift-idiomatic, marginally faster, easier flood-fill)"
  - "Board has zero mutating funcs — engines compose replacingCell(at:with:) / replacingCells(_:) (D-10)"
  - "Cell.State is a single enum with hidden/revealed/flagged/mineHit; adjacency lives on Cell as let, not inside the enum case"
  - "Designated Board init asserts cells.count == rows*cols via precondition — fail-loud at construction"

patterns-established:
  - "Phase-2 file header convention: 1-paragraph purpose blurb + 'Phase 2 invariants (per D-XX...)' bullet list + 'Foundation-only — ROADMAP P2 SC5' callout"
  - "Default visibility (internal) for engine model types — @testable import gamekit reaches everything; no public needed"
  - "All conformances spelled out per type: Equatable, Hashable, Codable, Sendable on value types where they cost nothing"
  - "Board read accessors (cell/at, flatIndex, allIndices, contains) under one MARK; pure transforms (replacingCell, replacingCells) under a separate MARK with 'NEW Board — D-10' callout"

requirements-completed: [MINES-01]

# Metrics
duration: 3min
completed: 2026-04-25
---

# Phase 02 Plan 01: Minesweeper Model Layer Summary

**Pure-Foundation Minesweeper model layer (Difficulty / Index / Cell / Board / GameState) — five value types totaling 320 lines that lock the contract for Plans 03/04/05 engines and the Phase 3 ViewModel.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-25T21:45:51Z
- **Completed:** 2026-04-25T21:48:17Z
- **Tasks:** 2
- **Files created:** 5
- **Files modified:** 0

## Accomplishments

- Locked the engine contract surface: Plans 03/04/05 can compile against this layer with zero further changes.
- Established the pure-Foundation model layer pattern (no SwiftUI/SwiftData/UIKit/GameplayKit/Observation/Combine) — ROADMAP P2 SC5 verified by `grep -RE "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/` returning exit code 1.
- Implemented the bounds-clamped 8-neighbors helper that Plan 03 (BoardGenerator) needs to satisfy CLAUDE.md §8.11 first-tap safety — `MinesweeperIndex(0,0).neighbors8(rows:9, cols:9)` returns exactly 3 indices; interior taps return 8.
- Made `MinesweeperBoard` strictly immutable (D-10): all stored properties `let`, zero `mutating func` declarations, mutations only via the pure `replacingCell(at:with:)` / `replacingCells(_:)` transforms.
- Created the `Games/Minesweeper/` subfolder for the first time — synchronized root group (Xcode 16, `objectVersion = 77`) auto-registers it on next build per CLAUDE.md §8.8 (no `pbxproj` patching needed).

## Task Commits

Each task was committed atomically:

1. **Task 1: Difficulty + Index + GameState** — `74d7d75` (feat)
2. **Task 2: Cell + immutable Board** — `65bc952` (feat)

_Plan metadata commit will follow this SUMMARY._

## Files Created/Modified

### Created

- `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift` (53 lines) — locked easy/medium/hard cases with mechanical rows/cols/mineCount/cellCount. Codable + Sendable + CaseIterable. Per D-01..D-05.
- `gamekit/gamekit/Games/Minesweeper/MinesweeperIndex.swift` (49 lines) — Hashable + Codable + Sendable struct with `neighbors8(rows:cols:)` returning 3/5/8 bounds-clamped neighbors. Per D-09 + PITFALLS Pitfall 1.
- `gamekit/gamekit/Games/Minesweeper/MinesweeperCell.swift` (59 lines) — value type with `let isMine`, `let adjacentMineCount`, `var state: State`. State enum: hidden / revealed / flagged / mineHit. Equatable for SwiftUI diffing in P3.
- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` (124 lines) — immutable struct with flat `[MinesweeperCell]` storage indexed `row*cols+col`. Read accessors `cell(at:)`, `flatIndex(_:)`, `allIndices()`, `contains(_:)`. Pure transforms `replacingCell(at:with:)` and `replacingCells(_:)`. Designated init `precondition`-asserts `cells.count == rows*cols`. Zero `mutating func`s.
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameState.swift` (35 lines) — lifecycle enum: `.idle / .playing / .won / .lost(mineIdx: MinesweeperIndex)`. Equatable + Hashable + Sendable. Intentionally NOT Codable.

### Modified

None.

## Decisions Made

All decisions traced to CONTEXT.md (D-01..D-05, D-09, D-10) or PATTERNS.md guidance — no new decisions invented at execution time. The two notable executor-discretion calls:

- **Picked `lost(mineIdx: MinesweeperIndex)` over a bare `lost` case** (CONTEXT.md "Claude's Discretion") — the trip cell is a load-bearing input to the P3 mineHit overlay, and reconstructing it from a board diff is lossy. The cost is one associated value; the savings is a guaranteed-correct overlay surface.
- **Picked single-enum `Cell.State` (hidden/revealed/flagged/mineHit) over `revealed(adjacent: Int)` associated value** (CONTEXT.md "Claude's Discretion" + PATTERNS.md recommendation) — adjacency is precomputed at generation and lives as `let adjacentMineCount` on Cell. Keeping the enum case trivial means tests can read adjacency uniformly whether the cell is hidden or revealed.

## Deviations from Plan

None — plan executed exactly as written. All five files match the canonical shape specified in the plan's `<action>` blocks; all acceptance criteria pass; no auto-fix rules triggered.

## Contract Surface for Plans 03/04/05

This is the locked surface downstream plans will consume:

```swift
// Plan 03 — BoardGenerator
enum BoardGenerator {
    static func generate(
        difficulty: MinesweeperDifficulty,
        firstTap: MinesweeperIndex,
        rng: inout some RandomNumberGenerator
    ) -> MinesweeperBoard
}

// Plan 04 — RevealEngine
enum RevealEngine {
    static func reveal(at index: MinesweeperIndex, on board: MinesweeperBoard)
        -> (board: MinesweeperBoard, revealed: [MinesweeperIndex])
}

// Plan 05 — WinDetector
enum WinDetector {
    static func isWon(_ board: MinesweeperBoard) -> Bool
    static func isLost(_ board: MinesweeperBoard) -> Bool
}
```

Key invariants downstream plans rely on:

- `MinesweeperIndex.neighbors8(rows:cols:)` is bounds-clamped — Plan 03's first-tap-safe exclusion `Set(allCells) - {tapped} - tapped.neighbors8(rows:cols:)` is correct at corners (3 exclusions = 4 total) and edges (5 = 6 total).
- `MinesweeperBoard` is immutable; all mutations route through `replacingCell(at:with:)` or `replacingCells(_:)` — engines emit a NEW Board, never mutate.
- `MinesweeperCell.adjacentMineCount` is a `let`, computed once at generation; reveal-time reads are O(1).
- `MinesweeperDifficulty.rawValue` ∈ {"easy", "medium", "hard"} is a frozen serialization key — renaming is a P4 data break.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 02-02 (SeededGenerator SplitMix64 test helper) is independent and can proceed in parallel with Wave 2 — it does not consume this plan's types directly, but `gamekitTests/` will eventually `@testable import gamekit` to exercise these types via the engines from 02-03 onward.
- Plan 02-03 (BoardGenerator) is unblocked: the contract this plan locks (Difficulty, Index.neighbors8, Cell with adjacency field, Board with flat storage + replacingCell) is exactly what 02-03's `<action>` block expects.
- Plans 02-04 (RevealEngine) and 02-05 (WinDetector) are also unblocked at the model-contract level; they will depend on 02-03's Board population for fixtures.
- No build verification performed in this plan — Plan 02-06 runs the integrated `xcodebuild` purity grep and full test suite per CONTEXT.md / ROADMAP.md SC5.

## Self-Check: PASSED

Verified post-write:

- `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift` — FOUND
- `gamekit/gamekit/Games/Minesweeper/MinesweeperIndex.swift` — FOUND
- `gamekit/gamekit/Games/Minesweeper/MinesweeperCell.swift` — FOUND
- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` — FOUND
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameState.swift` — FOUND
- Commit `74d7d75` (Task 1: Difficulty + Index + GameState) — FOUND in `git log --oneline`
- Commit `65bc952` (Task 2: Cell + Board) — FOUND in `git log --oneline`
- `grep -RE "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/` — exit code 1 (no matches)
- `grep -RE "^\s*mutating func" gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` — exit code 1 (no matches)
- All five files contain only `import Foundation` (verified file-by-file)

---

*Phase: 02-mines-engines*
*Completed: 2026-04-25*
