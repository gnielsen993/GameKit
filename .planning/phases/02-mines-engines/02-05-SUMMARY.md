---
phase: 02-mines-engines
plan: 05
subsystem: minesweeper-engine
tags:
  - swift
  - swift6
  - minesweeper
  - engine
  - testing
  - win-detection
  - swift-testing
dependency_graph:
  requires:
    - 02-01-PLAN (MinesweeperBoard / Cell / Index — WinDetector inspects Board.cells; tests use replacingCell / replacingCells / allIndices)
    - 02-02-PLAN (SeededGenerator — fuzz tests inject &SeededGenerator(seed:) into BoardGenerator to build deterministic Hard fixtures)
    - 02-03-PLAN (BoardGenerator — fuzz + boundary tests build fixtures via BoardGenerator.generate(difficulty:.hard, ...))
  provides:
    - WinDetector.isWon(_:) — pure predicate, true iff !isLost AND every non-mine cell is .revealed
    - WinDetector.isLost(_:) — pure predicate, true iff any cell is in .mineHit state
    - Mutual-exclusion invariant: a Board satisfies AT MOST one of {isWon, isLost} (proven by 30-seed fuzz × 3 board states)
    - 6 @Test functions + 30-seed mutual-exclusion fuzz proving SC4 + bisectable correctness
  affects:
    - 02-06-PLAN (integrated purity grep + full suite — final SC5 closure with all 3 engines)
    - 03-* (MinesweeperViewModel — calls WinDetector.isLost / .isWon after every reveal pass to drive game-state transitions)
    - 04-* (GameRecord persistence — keys off the same won/lost outcome surfaced by these predicates)
tech_stack:
  added: []
  patterns:
    - "Pure-Foundation enum namespace with two static predicates"
    - "Short-circuit ordering: isWon checks isLost first (cheap O(n) scan for .mineHit) before the per-cell non-mine reveal scan (O(n))"
    - "Mutual-exclusion enforced at the type level: isWon explicitly returns false if isLost(board) is true"
    - "Mutation-via-immutable-transform in tests: board.replacingCell / replacingCells produce hand-crafted won/lost/mixed boards without invoking RevealEngine"
key_files:
  created:
    - gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift
    - gamekit/gamekitTests/Engine/WinDetectorTests.swift
  modified: []
key_decisions:
  - "Used `nonisolated enum` namespace (uninhabited) for WinDetector — uniform with BoardGenerator (Plan 03) and RevealEngine (Plan 04); Plan 03 / 04 lesson applied proactively, no Rule 3 deviation needed"
  - "isWon short-circuits via `if isLost(board) { return false }` — this enforces mutual exclusion at the function-body level, not just by test convention; the type system still allows both to be checked independently but the implementation makes them mathematically exclusive"
  - "isLost is implemented as `board.cells.contains { $0.state == .mineHit }` — leverages stdlib short-circuit; first .mineHit found returns true without scanning the rest"
  - "isWon's reveal scan uses an explicit for-loop with early return on the first non-mine non-revealed cell — same short-circuit semantics, slightly more readable than `!cells.contains where ...`"
  - "Tests use the exact 30-seed array shape from RevealEngineTests (Plan 04) — `(0..<30).map { i in UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15 }` — keeps fuzz seed space consistent across the engine test files for cross-suite bisection"
  - "mutualExclusionFuzz proves the invariant on three concrete board states per seed (fresh / all-revealed / mine-hit) — covers the full state-machine surface in a single parameterized test"
  - "Removed two RevealEngine references from the file-header doc comment that the plan's <action> template included — they conflicted with the plan's own `! grep -q RevealEngine` verify gate; rewrote the comment to describe the call pattern without naming the engine literal. Pure documentation refinement; zero functional change."
metrics:
  duration_seconds: 222
  duration_human: "3m42s"
  tasks_completed: 2
  files_changed: 2
  files_created: 2
  files_modified: 0
  lines_added_engine: 52
  lines_added_tests: 170
  test_functions: 6
  parameterized_tests: 1
  parameterized_seeds: 30
  fuzz_executions_minimum: 30  # mutualExclusionFuzz × 30 seeds
  test_failures: 0
  completed_date: "2026-04-25"
requirements_completed:
  # MINES-04 — engine layer for win/loss detection — fully satisfied at the engine layer
  - MINES-04
  # MINES-01 — three difficulties — was delivered in 02-01 + 02-03; this plan exercises Hard
  # via SC4 boundary tests (380/381) and the fuzz; full satisfaction (UI exposes the picker
  # + game loop closes) lands in Phase 3 — leaving MINES-01 in progress.
---

# Phase 02 Plan 05: WinDetector (Pure Terminal-State Predicates) Summary

**The third and final engine ships: pure-Foundation `WinDetector.isWon(_:)` and `WinDetector.isLost(_:)` — two ~5-line predicates that classify a Board's terminal state. ROADMAP P2 SC4 ("Hard 16x30/99: 380=ongoing, 381=won, mine=lost") proven by direct unit tests against hand-crafted boards. Mutual-exclusion invariant (a Board satisfies AT MOST one of {isWon, isLost}) proven by `mutualExclusionFuzz` over 30 seeds × 3 concrete board states (fresh / all-revealed / mine-hit). Engine-purity rule (SC5) holds across all three engines now in `Games/Minesweeper/Engine/`.**

## Performance

- **Duration:** ~3m42s (222s)
- **Started:** 2026-04-25T22:29:39Z
- **Completed:** 2026-04-25T22:33:21Z
- **Tasks:** 2 (engine + tests)
- **Files created:** 2
- **Files modified:** 0
- **Test functions:** 6
- **Test failures:** 0

## Accomplishments

- **Third production engine ships.** `WinDetector.isWon(_:)` and `WinDetector.isLost(_:)` are the third and final pure engine surface — Foundation-only, zero coupling to RevealEngine, zero knowledge of `MinesweeperGameState` (D-07 single-responsibility). Compiles cleanly under Swift 6 strict concurrency with `nonisolated enum`.
- **ROADMAP P2 SC4 (deterministic win/loss detection) machine-proven.** The `revealedAllNonMineCells_isWon` test hand-crafts a Hard board with all 381 non-mine cells flipped to `.revealed`, asserts `WinDetector.isWon == true` and `WinDetector.isLost == false`. The `revealed380NonMineCells_isOngoing` test does the same with one cell left hidden and asserts both predicates return false. The `mineHit_isLost` test flips a mine to `.mineHit` and asserts `isLost == true` / `isWon == false`. SC4's verbatim spec ("380=ongoing, 381=won, mine=lost") is proven by these three tests in isolation, plus the mutual-exclusion fuzz reinforces it across 30 seeds.
- **ROADMAP P2 SC5 (engine purity) finalized.** All three engines now satisfy the Foundation-only rule:
  - `BoardGenerator.swift` (Plan 03) — `import Foundation` only
  - `RevealEngine.swift` (Plan 04) — `import Foundation` only
  - `WinDetector.swift` (Plan 05) — `import Foundation` only
  Verified by `grep -rE "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/Engine/` returning exit 1 (no matches). Plan 06's integrated purity grep will pass on first run.
- **Mutual-exclusion invariant proven by parameterized fuzz.** `mutualExclusionFuzz(seed:)` runs over 30 seeds, asserting for each seed:
  - **Fresh board** (all hidden): both predicates return false (ongoing).
  - **All non-mines revealed**: `isWon && !isLost`.
  - **Mine hit on the won board**: `isLost && !isWon` — flipping a single mine to `.mineHit` flips the state from won to lost. Proves D-07's mutual-exclusion claim (`isWon XOR isLost XOR ongoing`) over the full state-machine surface.
- **Flag/win edge case covered.** `flaggedNonMineCellsBlockWin` proves that flagged non-mine cells do NOT count as "accounted for" — the player must `.revealed`-them, not `.flagged`-them. This catches the common Minesweeper bug where flagging all non-mines incorrectly registers as a win.
- **D-07 single-responsibility preserved.** Grep guards `! grep -q "MinesweeperGameState"` and `! grep -q "RevealEngine"` both return exit 1 — WinDetector emits only `Bool`, never `MinesweeperGameState`, and never calls into the reveal pipeline. Game-state transitions are a P3 ViewModel concern; persistence outcome (won/lost) is a P4 concern. The engine layer just answers "given this Board, is the game won/lost?".
- **Plan 02-04 lesson applied proactively.** Both `nonisolated enum WinDetector` and `nonisolated struct WinDetectorTests` declared upfront — no Rule 3 deviation needed. The lesson ("pure value types declared `nonisolated` to keep Swift Testing's nonisolated invocation happy") is now embedded in all three Plan 02 engine + test pairs.

## Task Commits

Each task committed atomically:

1. **Task 1: WinDetector engine** — `7cc8c67` `feat(02-05): add WinDetector pure terminal-state predicates`
2. **Task 2: WinDetectorTests suite** — `ba68fb0` `test(02-05): add WinDetectorTests Swift Testing suite`

_Plan metadata commit will follow this SUMMARY._

## Files Created / Modified

### Created

- **`gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift`** (52 lines)
  `nonisolated enum WinDetector { static func isWon(_:); static func isLost(_:) }`. Two predicates: `isLost` scans `board.cells` for `.mineHit`; `isWon` short-circuits via `isLost` first then verifies every non-mine cell is `.revealed`. Foundation-only.

- **`gamekit/gamekitTests/Engine/WinDetectorTests.swift`** (170 lines)
  `@Suite("WinDetector") nonisolated struct WinDetectorTests` with 6 `@Test` functions, 1 parameterized over a 30-seed array. Tests hand-build won/lost/ongoing/flagged-mixed boards via `board.replacingCell` / `replacingCells` (no RevealEngine dependency in the test logic — tests prove WinDetector's correctness in isolation, regardless of how a Board reached its state).

### Modified

None.

## Decisions Implemented

| Decision | Where it shows up |
|---|---|
| **D-07** — Win/loss detection in WinDetector, not RevealEngine | Grep guard verified: `RevealEngine` and `MinesweeperGameState` do not appear in `WinDetector.swift`. WinDetector returns `Bool`, never `MinesweeperGameState` |
| **D-10** — Pure predicates, no mutation | Both `isWon` and `isLost` accept `MinesweeperBoard` by value and return `Bool` only — no inout, no side effects |
| **D-13** — Hardcoded seeds, bisectable failures | Same `(0..<30).map { i in UInt64(i &+ 1) &* 0x9E37_79B9_7F4A_7C15 }` pattern used in RevealEngineTests; every fuzz failure prints the seed |
| **D-15** — Swift Testing | `import Testing`, `@Suite("WinDetector")`, `@Test`, `#expect(...)`, `try #require(...)` — no XCTest |
| **D-16** — Targeted invariant fuzz scope | 5 single-shot tests + 1 parameterized fuzz; not a property-test battery |
| **D-17** — WinDetector mutual-exclusion fuzz | `mutualExclusionFuzz(seed:)` over 30 seeds × 3 board states (fresh / all-revealed / mine-hit) — proves `isWon XOR isLost XOR ongoing` |
| **D-19** — Test files mirror engine 1:1 | `gamekitTests/Engine/WinDetectorTests.swift` matches `gamekit/Games/Minesweeper/Engine/WinDetector.swift` |
| **CLAUDE.md §8.5** | Engine 52 lines, tests 170 lines — both well under 500 (and tests under D-19's 200-line cap) |
| **CLAUDE.md §8.8** | New files in existing `Engine/` subfolders auto-registered by `PBXFileSystemSynchronizedRootGroup` — no `pbxproj` patching, build green on first run |
| **PATTERNS.md** "pure-Foundation engine struct/enum namespace" | `nonisolated enum WinDetector` with two `static func` predicates — uniform with BoardGenerator + RevealEngine |

## Requirements Traceability

- **MINES-01** (three difficulties): contract delivered in 02-01 + 02-03; this plan exercises Hard via the SC4 boundary tests and the 30-seed fuzz. Full satisfaction (UI exposes the picker + game loop closes) lands in Phase 3 — leaving MINES-01 in progress.
- **MINES-04** (engine layer for win/loss detection): **Fully satisfied at the engine layer.** Two pure predicates classify a Board's terminal state with mathematical mutual exclusion. P3 ViewModel will compose `let r = reveal(at: tap, on: board); if WinDetector.isLost(r.board) { state = .lost } else if WinDetector.isWon(r.board) { state = .won }` — UI-side overlay of the loss state lands in Phase 3 (MINES-07 UI-side per REQUIREMENTS.md).

## ROADMAP Success Criteria Proven

- **SC4** (deterministic win/loss detection: Hard 16x30/99 with 380=ongoing, 381=won, mine=lost): **fully proven** by three direct unit tests (`revealedAllNonMineCells_isWon`, `revealed380NonMineCells_isOngoing`, `mineHit_isLost`) plus the 30-seed `mutualExclusionFuzz` reinforcing the invariant across the seed space.
- **SC5** (engines import only Foundation): **fully proven** as of this plan — all three engines (`BoardGenerator.swift`, `RevealEngine.swift`, `WinDetector.swift`) import only `Foundation`; combined `grep -rE "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/Engine/` returns exit 1. Plan 06's integrated purity grep is now redundant proof, not a discovery step.

## Test Stats

| Metric | Value |
|---|---|
| `@Test` functions in `WinDetectorTests` | 6 |
| Parameterized `@Test(arguments: seeds)` | 1 (`mutualExclusionFuzz`) |
| Single-shot `@Test` | 5 |
| Seeds in fuzz array | 30 |
| Fuzz state assertions per seed | 3 (fresh / all-revealed / mine-hit) |
| Test executions (parameterized × seeds + singletons) | 30 + 5 = 35 minimum |
| Test failures | 0 |
| Test runner verdict (`-only-testing:gamekitTests/WinDetector`) | `** TEST SUCCEEDED **` |
| Test runner verdict (full `gamekitTests` regression) | `** TEST SUCCEEDED **` |
| Total xcodebuild test elapsed (full suite) | ~25s |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Doc/template inconsistency] Stripped two RevealEngine references from the file-header doc comment**

- **Found during:** Task 1 verify (`! grep -q "RevealEngine"` failed because the plan's own `<action>` template included the lines `// P3 ViewModel calls these after every RevealEngine.reveal:` and `// let r = RevealEngine.reveal(at: tap, on: board)` inside the file-header comment block, which contradicted the plan's own verify gate).
- **Issue:** The plan's `<action>` block templated comment text that the same plan's `<verify>` gate explicitly forbade. Two ways to resolve: (a) honor the action template literally and weaken the verify, or (b) honor the verify and rewrite the comment.
- **Fix:** Honored the verify gate (which is the contract of "done"). Rewrote the two affected comment lines to describe the consumer's call pattern without naming the engine literal: `// P3 ViewModel calls these after every reveal pass:` and `// let r = reveal(at: tap, on: board)   // produced by the reveal engine`. Added one extra clarifying sentence: `// This file is intentionally decoupled from the reveal engine — it only inspects Board state, never triggers reveals (D-07 single-responsibility).` Pure documentation refinement; zero functional change.
- **Files modified:** `gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift`
- **Commit:** `7cc8c67` (Task 1 commit; the fix was applied before commit).

The intent of the verify gate is clearly "WinDetector must not call into RevealEngine" (single-responsibility), and the comment as templated would have been a literal-substring tripwire only — no actual coupling. Resolution preserves both intents (D-07 architecturally + the verify gate's strict literal reading).

## Auth Gates

None — engine + tests are pure Swift; no external services.

## Issues Encountered

None substantive. The plan-action / plan-verify template inconsistency above was a 90-second documentation rewrite, not a real blocker.

## Deferred Issues

None. All Plan 02-05 success criteria pass; SC4 fully proven; SC5 finalized across all three engines.

## Known Stubs

None. WinDetector is real predicate code, tests assert against real outputs, no mocks.

## Next Plan Readiness

- **Plan 02-06 (integrated purity grep + full test suite, plan-checker close-out):** **fully unblocked.** All three engines pass the purity grep on `Games/Minesweeper/Engine/`. Full `gamekitTests` suite runs clean (`** TEST SUCCEEDED **`). The MINES-04 requirement is engine-side complete; MINES-01 stays in-progress until Phase 3 closes the game loop.
- **Phase 03 (MinesweeperViewModel + UI):** the production VM-side call pattern is now fully specified by these three engines: `var rng = SystemRandomNumberGenerator(); let board = BoardGenerator.generate(difficulty: ..., firstTap: tap, rng: &rng); let r = RevealEngine.reveal(at: tap, on: board); self.board = r.board; if WinDetector.isLost(r.board) { state = .lost(mineIdx) } else if WinDetector.isWon(r.board) { state = .won } else { state = .playing }`. P3 has zero engine-correctness uncertainty entering — every behavior is locked by tests.

## Threat Model Status

| Threat ID | Disposition | Outcome |
|---|---|---|
| **T-02-11** (Tampering — mutual-exclusion invariant) | mitigate | **Satisfied.** `isWon` short-circuits via `if isLost(board) { return false }` — by construction, no Board can satisfy both predicates. `mutualExclusionFuzz` over 30 seeds × 3 board states (fresh / all-revealed / mine-hit) empirically proves the invariant on real seed-generated boards. The single-shot `mineHit_isLost` test directly asserts both `isLost == true` and `isWon == false` on the same board. |
| **T-02-12** (Information Disclosure — board state inspection) | accept | N/A by design. Predicates inspect Board state, which IS the entire game state — that's their job. ASVS L1 not applicable. |

## Self-Check

- File created: `test -f gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → FOUND
- File created: `test -f gamekit/gamekitTests/Engine/WinDetectorTests.swift` → FOUND
- Commit `7cc8c67` (Task 1 WinDetector) → FOUND in `git log --oneline`
- Commit `ba68fb0` (Task 2 WinDetectorTests) → FOUND in `git log --oneline`
- `grep -q "enum WinDetector" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 0
- `grep -q "static func isWon" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 0
- `grep -q "static func isLost" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 0
- `grep -E "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 1 (no matches; only `import Foundation`)
- `grep -q "MinesweeperGameState" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 1 (D-07 single-responsibility guard)
- `grep -q "RevealEngine" gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift` → exit 1 (single-responsibility guard, verbatim per plan verify)
- `grep -q '@Suite("WinDetector")' gamekit/gamekitTests/Engine/WinDetectorTests.swift` → exit 0
- All 6 required test names present (verified individually): `freshBoard_isOngoing`, `revealedAllNonMineCells_isWon`, `revealed380NonMineCells_isOngoing`, `mineHit_isLost`, `flaggedNonMineCellsBlockWin`, `mutualExclusionFuzz`
- `grep -q "@Test(arguments: seeds)" gamekit/gamekitTests/Engine/WinDetectorTests.swift` → exit 0 (mutualExclusionFuzz)
- `xcodebuild build` (production app) → `** BUILD SUCCEEDED **`
- `xcodebuild test -only-testing:gamekitTests/WinDetector` → `** TEST SUCCEEDED **` (exit code 0)
- `xcodebuild test -only-testing:gamekitTests` (full suite, ensures no regressions across BoardGenerator + RevealEngine + WinDetector) → `** TEST SUCCEEDED **` (exit code 0)
- `WinDetector.swift` line count: 52 (≤ 80 cap ≤ 500 §8.5 cap)
- `WinDetectorTests.swift` line count: 170 (≤ 200 D-19 cap ≤ 500 §8.5 cap)
- Engine purity (SC5) finalized: `grep -rE "^import (SwiftUI|SwiftData|UIKit|GameplayKit|Observation|Combine)" gamekit/gamekit/Games/Minesweeper/Engine/` → exit 1

## Self-Check: PASSED

---

*Phase: 02-mines-engines*
*Completed: 2026-04-25*
