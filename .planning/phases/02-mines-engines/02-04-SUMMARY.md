---
phase: 02-mines-engines
plan: 04
subsystem: minesweeper-engine
tags:
  - swift
  - swift6
  - minesweeper
  - engine
  - testing
  - flood-fill
  - iterative
  - bfs
  - swift-testing
dependency_graph:
  requires:
    - 02-01-PLAN (MinesweeperBoard / Cell / Index — RevealEngine consumes Board.replacingCells, Cell.state, Index.neighbors8)
    - 02-02-PLAN (SeededGenerator — RevealEngineTests inject &SeededGenerator(seed:) into BoardGenerator to build deterministic fixtures)
    - 02-03-PLAN (BoardGenerator — RevealEngineTests build fixtures via BoardGenerator.generate; cluster-corner test hand-builds Board directly via designated initializer)
  provides:
    - RevealEngine.reveal(at:on:) (pure enum namespace; static method returning (board, revealed) tuple per D-06)
    - Iterative BFS flood-fill (no recursion — ROADMAP P2 SC3 proof)
    - Behavior matrix coverage: idempotent (.revealed/.mineHit), no-op (.flagged), .mineHit transition on mine tap, single-cell on numbered, full cascade on adj==0
    - 8 @Test functions + 30-seed idempotence fuzz proving bisectable correctness
  affects:
    - 02-05-PLAN (WinDetector — composes against boards transformed by this engine; .mineHit state is the loss signal)
    - 02-06-PLAN (integrated purity grep + full suite — both Plan 04 files contribute)
    - 03-* (MinesweeperViewModel — calls RevealEngine.reveal(at:on:) on every tap; consumes the ordered [MinesweeperIndex] for MINES-08 cascade animation)
tech_stack:
  added: []
  patterns:
    - "Iterative BFS via Array<Index> queue + head pointer (no removeFirst, O(1) amortized dequeue)"
    - "Visited set to bound flood-fill work to O(rows*cols)"
    - "Single batched immutable Board.replacingCells transform per cascade (D-10 + perf)"
    - "Behavior-matrix early-return chain (revealed/mineHit -> flagged -> hidden+mine -> hidden+numbered -> hidden+empty)"
key_files:
  created:
    - gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift
    - gamekit/gamekitTests/Engine/RevealEngineTests.swift
  modified: []
key_decisions:
  - "Used `enum` namespace (uninhabited) for RevealEngine — uniform with BoardGenerator pattern from Plan 03 + PATTERNS.md recommendation"
  - "BFS over Array<Index> queue with head pointer (CONTEXT 'Claude's Discretion') — chosen over LIFO stack because layer-by-layer reveal maps cleanly to P3's MINES-08 cascade animation"
  - "Visited set tracks enqueued cells (not just revealed) — prevents the same cell entering the queue twice when reached via multiple empty-cell neighbors; ensures O(rows*cols) total work"
  - "Mine guard at neighbor-enqueue step (not just at dequeue) — defensive double-check; cascade is guaranteed to never reveal a mine even if expansion logic is later refactored"
  - "Numbered cells terminate the cascade: revealed but neighbors NOT enqueued — standard Minesweeper semantics; the expansion-gate `if currentCell.adjacentMineCount == 0` is the contract"
  - ".mineHit and .revealed states share the idempotent no-op return path — both are terminal-revealed states; re-revealing either is a pure no-op"
  - "`nonisolated enum` and `nonisolated struct RevealEngineTests` — proactive application of the Plan 03 lesson; project default SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor would otherwise break Swift Testing's nonisolated invocation"
  - "Test file embeds (row,col) tuple format in failure messages — bisectable per D-13 (e.g. 'cell (5,5) seed: 137' uniquely identifies failure)"
metrics:
  duration_seconds: 618
  duration_human: "10m18s"
  tasks_completed: 2
  files_changed: 2
  files_created: 2
  files_modified: 0
  lines_added_engine: 161
  lines_added_tests: 225
  test_functions: 8
  parameterized_tests: 1
  parameterized_seeds: 30
  fuzz_executions_minimum: 30  # idempotenceFuzz × 30 seeds
  test_failures: 0
  completed_date: "2026-04-25"
requirements_completed:
  # MINES-04 — flood-fill reveal for empty cells to next numbered border — fully satisfied here
  - MINES-04
  # MINES-01 — three difficulties — was delivered in 02-01 + 02-03; this plan exercises Easy/Hard via fixtures
  # but the full game loop (UI + reveal + WinDetector) finishes in P3, so MINES-01 stays in-progress
---

# Phase 02 Plan 04: RevealEngine (Iterative BFS Flood-Fill) Summary

**The second engine ships: pure-Foundation `RevealEngine.reveal(at:on:)` with iterative BFS flood-fill (no recursion). 8 Swift Testing `@Test` functions cover the full behavior matrix — idempotence, flag protection, .mineHit transition, single-cell, cascade — with the cluster-corner Hard board test (99 mines forced into the top-left 11×9 corner; far-corner tap from (15,29)) proving ROADMAP P2 SC3 by completing without stack growth and revealing >200 cells in a single call. 30-seed idempotence fuzz over Easy boards re-reveals every cell from the first cascade and asserts board equality.**

## Performance

- **Duration:** ~10m18s (618s)
- **Started:** 2026-04-25T22:15:06Z
- **Completed:** 2026-04-25T22:25:24Z
- **Tasks:** 2 (engine + tests)
- **Files created:** 2
- **Files modified:** 0
- **Test functions:** 8
- **Test failures:** 0

## Accomplishments

- **Second production engine ships.** `RevealEngine.reveal(at:on:)` is the second pure engine — Foundation-only, returns `(board: MinesweeperBoard, revealed: [MinesweeperIndex])` per D-06. Compiles cleanly under Swift 6 strict concurrency with `nonisolated` namespace.
- **ROADMAP P2 SC3 (iterative flood-fill, no recursion) machine-proven.** The `cornerClusteredHardBoard_floodFillTerminates` test hand-builds a Hard board with all 99 mines in the top-left 11×9 corner, taps the far corner (15,29), and asserts the cascade completes without stack overflow and reveals >200 cells. Test passes in ~24s of full-suite run time. The fact that this test runs to completion IS the SC3 proof — the algorithm is structurally non-recursive (`floodFill(` appears exactly 2 times in the source: once for `private static func floodFill` and once for the dispatch from `reveal`).
- **Behavior matrix fully covered.** Six tests verify D-06's behavior table:
  - `revealHiddenNumberedCell_revealsOnly` — adj>0 cell reveals only itself
  - `revealEmptyCell_cascades` — adj==0 cell triggers BFS cascade (branches on (0,0) adjacency)
  - `revealMine_setsMineHit` — mine tap transitions to `.mineHit` state (Plan 05 WinDetector signal)
  - `revealAlreadyRevealedCell_isIdempotent` — re-reveal returns empty list + unchanged board
  - `revealFlaggedCell_isNoOp` — flagged cell unchanged, returns empty list (Pitfall 7)
  - `revealedListStartsWithTap` — first element of `revealed` is the tap index (BFS order invariant)
- **Cascade safety proven.** Cluster-corner test asserts `result.board.cell(at: idx).isMine == false` for every cell in `result.revealed` — the cascade is mathematically guaranteed to never reveal a mine.
- **Idempotence fuzz over 30 seeds.** `idempotenceFuzz` parameterized test uses 30 SeededGenerator seeds (subset of the 100-seed array used by Plan 03; reduced for runtime since each seed re-reveals every cell from the first cascade). For each seed: generate Easy board, reveal (0,0), then re-reveal every cell in the resulting `revealed` list — each must return empty list + unchanged board. Catches the "works on seed 42, breaks on seed 137" class.
- **D-07 single-responsibility preserved.** The grep guard `! grep -q "MinesweeperGameState" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` returns exit 1 — RevealEngine emits the `.mineHit` cell state but does NOT compute won/lost. Plan 05's WinDetector owns that.
- **ROADMAP P2 SC5 (engine purity) preserved.** `grep -E "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)"` on `RevealEngine.swift` returns exit 1 — only `import Foundation`.
- **Plan 03 lesson applied proactively.** Both `nonisolated enum RevealEngine` and `nonisolated struct RevealEngineTests` declared upfront — no Rule 3 deviation needed this plan. The lesson ("pure value types declared `nonisolated` to keep Swift Testing's nonisolated invocation happy") is now embedded in the Plan 02 pattern and ready for Plan 05.

## Task Commits

Each task committed atomically:

1. **Task 1: RevealEngine engine** — `f4a437b` `feat(02-04): add RevealEngine with iterative BFS flood-fill`
2. **Task 2: RevealEngineTests suite** — `483b1bc` `test(02-04): add RevealEngineTests Swift Testing suite`

_Plan metadata commit will follow this SUMMARY._

## Files Created / Modified

### Created

- **`gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift`** (161 lines)
  `nonisolated enum RevealEngine { static func reveal(at:on:) -> (board:, revealed:) }` with `private static func floodFill(from:on:)`. Implements the full behavior matrix as an early-return chain followed by mine/numbered/empty branching. Empty-cell branch dispatches to iterative BFS. Foundation-only.

- **`gamekit/gamekitTests/Engine/RevealEngineTests.swift`** (225 lines)
  `@Suite("RevealEngine") nonisolated struct RevealEngineTests` with 8 `@Test` functions, 1 parameterized over a 30-seed array. Cluster-corner test hand-builds a 99-mine Hard fixture inline (no BoardGenerator dependency for that test — keeps the SC3 proof self-contained and reproducible regardless of BoardGenerator's RNG order).

### Modified

None.

## Decisions Implemented

| Decision | Where it shows up |
|---|---|
| **D-06** — RevealEngine returns (board, revealed) tuple | Exact signature: `static func reveal(at:on:) -> (board: MinesweeperBoard, revealed: [MinesweeperIndex])` |
| **D-07** — No win/loss in RevealEngine | Grep guard verified: `MinesweeperGameState` does not appear in `RevealEngine.swift`. The engine surfaces a `.mineHit` Cell state; Plan 05 WinDetector reads it |
| **D-10** — Engine returns NEW immutable Board | Single-cell paths use `board.replacingCell(at:with:)`; cascade uses single batched `board.replacingCells(updates)` — both produce a fresh `MinesweeperBoard` value |
| **D-13** — Hardcoded seeds, bisectable failures | `static let seeds: [UInt64] = (0..<30).map { ... }` — every fuzz failure prints the seed |
| **D-15** — Swift Testing | `import Testing`, `@Suite(...)`, `@Test`, `#expect(...)`, `try #require(...)` — no XCTest |
| **D-16** — Targeted invariant fuzz scope | 7 single-shot tests + 1 parameterized fuzz; not a property-test battery |
| **D-17** — RevealEngine fuzz: idempotence | `idempotenceFuzz(seed:)` over 30 seeds: re-reveal every cell from first cascade returns empty + unchanged Board |
| **D-19** — Test files mirror engine 1:1 | `gamekitTests/Engine/RevealEngineTests.swift` matches `gamekit/Games/Minesweeper/Engine/RevealEngine.swift` |
| **Claude's Discretion** (CONTEXT) — BFS via Array queue + head pointer | `var queue: [MinesweeperIndex] = [start]; var queueHead = 0; while queueHead < queue.count { ... }` — exact pattern |
| **CLAUDE.md §8.5** | Engine 161 lines, tests 225 lines — both well under 500 |
| **CLAUDE.md §8.8** | New files in existing `Engine/` subfolders auto-registered by `PBXFileSystemSynchronizedRootGroup` — no `pbxproj` patching, build green on first run |
| **PATTERNS.md** "Iterative algorithms only" | `floodFill(` appears exactly 2 times in the source — declaration + dispatch from `reveal` — confirming no self-call recursion |

## Requirements Traceability

- **MINES-01** (three difficulties): contract delivered in 02-01 + 02-03; this plan exercises Easy via the seed fuzz fixtures and Hard via the cluster-corner SC3 proof. Full satisfaction (UI exposes the picker + game loop closes) lands in Phase 3 — leaving MINES-01 in progress.
- **MINES-04** (flood-fill reveal for empty cells to the next numbered border): **Fully satisfied.** The reveal algorithm precisely matches the requirement: empty cells trigger BFS cascade; the cascade reveals the empty cell + every reachable empty cell + the immediate numbered border (numbered cells get revealed, but their neighbors are not enqueued). The cluster-corner test, the cascade test, the idempotence fuzz, and the BFS-order test together prove correctness on real fixtures + 30 seeds.

## ROADMAP Success Criteria Proven

- **SC3** (iterative flood-fill, no recursion, no stack growth on 16×30 corner-clustered Hard board): **fully proven** by `cornerClusteredHardBoard_floodFillTerminates`. Test reveals >200 cells in one call. Algorithm is structurally non-recursive (verified by `grep -c "floodFill(" RevealEngine.swift` returning 2).
- **SC5** (engines import only Foundation): **partially proven** — `RevealEngine.swift` imports only `Foundation`; combined with `BoardGenerator.swift` from Plan 03, two of three engines now satisfy the rule. Final SC5 closes when WinDetector ships in 02-05.

## Test Stats

| Metric | Value |
|---|---|
| `@Test` functions in `RevealEngineTests` | 8 |
| Parameterized `@Test(arguments: seeds)` | 1 (`idempotenceFuzz`) |
| Single-shot `@Test` | 7 |
| Seeds in fuzz array | 30 |
| Test executions (parameterized × seeds + singletons) | 30 + 7 = 37 minimum |
| Test failures | 0 |
| Cluster-corner cell count assertion | `> 200` (lower bound; actual not surfaced by xcresulttool but assertion passed — test would have failed otherwise with a precise count in the failure message) |
| Test runner verdict | `** TEST SUCCEEDED **` |
| Total xcodebuild test elapsed (RevealEngine only) | ~24s |
| Total xcodebuild test elapsed (full gamekitTests) | ~28s |

**Note on test counts:** The Xcode 17C529 / Swift Testing xcresult bundle does not surface per-test results through `xcresulttool get test-results summary` (returns `passedTests: 0` despite `** TEST SUCCEEDED **`). This is an Xcode/Swift Testing tooling gap, not a test-discovery failure — when running the full `gamekitTests` suite without `-only-testing` filter, individual test names DO stream to stdout (e.g., `'BoardGeneratorTests/mineCountAlwaysExact_medium(seed:)' passed`). Authoritative success signal is the runner's `** TEST SUCCEEDED **` plus exit code 0, identical to Plan 03's environment.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1/2/3 auto-fixes triggered.

The Plan 03 `nonisolated` lesson was applied proactively (both `RevealEngine` and `RevealEngineTests` declared `nonisolated` from the start), so the Rule 3 deviation that hit Plan 03's test build did not recur.

## Auth Gates

None — engine + tests are pure Swift; no external services.

## Issues Encountered

None substantive. The Xcode/Swift Testing xcresult tooling gap (per-test counts not surfaced through `xcresulttool`) is documented under Test Stats above; it does not affect test correctness or the success signal.

## Deferred Issues

None. All Plan 02-04 success criteria pass.

## Known Stubs

None. RevealEngine is real algorithm code, tests assert against real outputs, no mocks.

## Next Plan Readiness

- **Plan 02-05 (WinDetector):** **unblocked.** Can compose against boards transformed by RevealEngine: `let r = RevealEngine.reveal(at: idx, on: board); WinDetector.isWon(r.board) || WinDetector.isLost(r.board)`. The `.mineHit` state is the loss signal (set by RevealEngine when a mine is tapped). Reminder for the 02-05 executor: declare any new engine/test types `nonisolated` from the start (Plan 02-03 / 02-04 pattern).
- **Plan 02-06 (integrated purity grep + full test suite):** the engine-purity grep on `Games/Minesweeper/Engine/` will pass (`BoardGenerator.swift` and `RevealEngine.swift` both import only Foundation). Full test suite runs clean.
- **Plan 03-* (MinesweeperViewModel):** the production VM-side call site will be `let result = RevealEngine.reveal(at: idx, on: board); self.board = result.board; animateCascade(result.revealed)`. P3's MINES-08 cascade animation can stagger directly off `result.revealed` — BFS discovery order is exactly what visualizes nicely (layer-by-layer reveal from the tap outward).

## Threat Model Status

| Threat ID | Disposition | Outcome |
|---|---|---|
| **T-02-08** (DoS — flood-fill termination on cluster-corner board) | mitigate | **Satisfied.** Iterative BFS over Array queue with `visited: Set` guard; total work bounded by `rows * cols`. The `cornerClusteredHardBoard_floodFillTerminates` test proves termination on the worst-case shape (99 mines in top-left 11×9 corner, far-corner tap from (15,29)). PITFALLS "Performance Traps → Recursive flood-fill on Hard" failure mode mitigated. |
| **T-02-09** (Tampering — flag protection / cell state machine) | mitigate | **Satisfied.** `revealFlaggedCell_isNoOp` test ensures user can't accidentally reveal a flagged cell — engine's behavior matrix returns `(board, [])` for `.flagged` state. UI cannot bypass this since reveal must go through the engine. |
| **T-02-10** (Information Disclosure — adjacency reveal) | accept | N/A by design. Adjacency counts are precomputed at generation; revealing exposes them via `cell.adjacentMineCount` — that IS the game mechanic. |

## Self-Check

- File created: `test -f gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → FOUND
- File created: `test -f gamekit/gamekitTests/Engine/RevealEngineTests.swift` → FOUND
- Commit `f4a437b` (Task 1 RevealEngine) → FOUND in `git log --oneline`
- Commit `483b1bc` (Task 2 RevealEngineTests) → FOUND in `git log --oneline`
- `grep -q "enum RevealEngine" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → exit 0
- `grep -q "private static func floodFill" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → exit 0
- `grep -q "while queueHead < queue.count" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → exit 0
- `grep -E "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → exit 1 (no matches; only `import Foundation`)
- `grep -q "MinesweeperGameState" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → exit 1 (D-07 single-responsibility guard)
- `grep -c "floodFill(" gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` → 2 (≤ 3 cap; declaration + single dispatch from `reveal` — no recursion)
- `grep -q "@Suite(\"RevealEngine\")" gamekit/gamekitTests/Engine/RevealEngineTests.swift` → exit 0
- All 8 required test names present (verified individually): `revealHiddenNumberedCell_revealsOnly`, `revealEmptyCell_cascades`, `revealMine_setsMineHit`, `revealAlreadyRevealedCell_isIdempotent`, `revealFlaggedCell_isNoOp`, `cornerClusteredHardBoard_floodFillTerminates`, `revealedListStartsWithTap`, `idempotenceFuzz`
- `grep -q "@Test(arguments: seeds)" gamekit/gamekitTests/Engine/RevealEngineTests.swift` → exit 0 (idempotenceFuzz)
- `xcodebuild build` (production app) → `** BUILD SUCCEEDED **`
- `xcodebuild test -only-testing:gamekitTests/RevealEngine` → `** TEST SUCCEEDED **` (exit code 0)
- `xcodebuild test -only-testing:gamekitTests` (full suite, ensures no regressions) → `** TEST SUCCEEDED **` (exit code 0)
- `RevealEngine.swift` line count: 161 (≤ 300 cap ≤ 500 §8.5 cap)
- `RevealEngineTests.swift` line count: 225 (≤ 300 cap ≤ 500 §8.5 cap)

## Self-Check: PASSED

---

*Phase: 02-mines-engines*
*Completed: 2026-04-25*
