---
phase: 03-mines-ui
plan: 02
subsystem: viewmodel
status: complete
completed: 2026-04-26
duration_minutes: 12
tags:
  - swift
  - minesweeper
  - viewmodel
  - observable
  - swift-testing
  - foundation-only
requirements:
  - MINES-02
  - MINES-05
  - MINES-06
  - MINES-07
  - MINES-11
dependency_graph:
  requires:
    - phase: 02-mines-engines
      provides: "BoardGenerator + RevealEngine + WinDetector + Models (locked Foundation-only API)"
    - phase: 02-mines-engines
      provides: "SeededGenerator (test-target deterministic PRNG)"
  provides:
    - "MinesweeperViewModel — @Observable @MainActor final class orchestrating engines + timer + scenePhase + difficulty switch"
    - "GameOutcome enum (.win / .loss) — surface for end-state card"
    - "LossContext struct (minesHit, safeCellsRemaining) — surface for end-state card"
    - "MinesweeperVMFixtures — 4 deterministic test-target board factories"
    - "UserDefaults `mines.lastDifficulty` schema with garbage-rawValue fallback"
  affects:
    - "Plan 03-03 / 03-04 (Mines UI views) — consume the locked VM contract; views never call engines directly"
    - "Plan 04 (Stats & Persistence) — VM exposes terminal-state surface (terminalOutcome, lossContext, frozenElapsed) for GameRecord writes"
tech_stack:
  added:
    - "@Observable @MainActor pattern — first VM in repo (no analog from P1/P2)"
    - "Injection seams pattern (clock, rng, userDefaults) for deterministic VM tests"
  patterns:
    - "First-tap firewall — exactly one BoardGenerator.generate call site enforced both by code structure (.idle branch) and grep verification"
    - "Foundation-only ViewModel (ARCHITECTURE Anti-Pattern 1) — VM imports only Foundation; structural test enforces the rule"
    - "Test-isolated UserDefaults via UserDefaults(suiteName: \"test-<UUID>\")! — never pollutes .standard"
    - "Nested @Suite Swift Testing organization (8 sub-suites under MinesweeperViewModel)"
key_files:
  created:
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift (278 lines)"
    - "gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift (114 lines)"
    - "gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift (491 lines)"
  modified: []
decisions:
  - "03-02: VM injection seams (clock, rng, userDefaults) added beyond the research example — required for deterministic timer / mine-layout / persistence tests; strict superset of the locked surface, breaks no contracts"
  - "03-02: LossContext modeled as Equatable Sendable struct (not the inline tuple from RESEARCH §Code Examples 1) — tuples are not Equatable in Swift, blocking the `#expect(vm.lossContext == ...)` assertion shape; struct ships next to GameOutcome at file scope"
  - "03-02: idleBoard(for:) static helper extracted — reuses the placeholder-board construction across init and restart() instead of duplicating in two paths"
  - "03-02: `var rng: any RandomNumberGenerator` stored existentially — Swift 5.7+ implicit existential opening lets `&rng` flow into BoardGenerator.generate's `inout some RandomNumberGenerator` parameter cleanly (verified by build)"
  - "03-02: Tests resolve `firstHiddenNonMine(on:)` instead of using a hardcoded (8,8) target — the plan's literal coordinate is brittle because seed-1 flood-fill may reach (8,8); helper finds whatever cell is still hidden after first reveal regardless of cascade reach"
metrics:
  duration: "12 minutes"
  tasks: 3
  files_created: 3
  files_modified: 0
  test_cases_added: 29
  test_assertions: 80+
  test_cases_passing: "29 / 29 (100%)"
---

# Phase 3 Plan 02: MinesweeperViewModel + Wave-0 GameKit Tests Summary

**`@Observable @MainActor final class MinesweeperViewModel` orchestrating the locked P2 engine API into a UI-consumable state surface — Foundation-only, first-tap firewall enforced, with a 29-case Swift Testing suite covering MINES-02 / MINES-05 / MINES-06 / MINES-07 / MINES-11 plus D-06 scenePhase pause/resume, D-08 terminal-state freeze, D-10 mid-game alert, and D-11 UserDefaults persistence.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-26T01:15:00Z (approx — immediately after plan 03-01 close)
- **Completed:** 2026-04-26T01:27:36Z
- **Tasks:** 3
- **Files created:** 3
- **Files modified:** 0
- **Test cases added:** 29 (all green)

## Accomplishments

- **VM contract locked.** Plans 03-03 / 03-04 can consume `MinesweeperViewModel` as a settled surface — no view tier needs to reason about engine orchestration, scenePhase, timer math, or difficulty persistence.
- **First-tap firewall enforced.** `BoardGenerator.generate(...)` has exactly ONE call site in the VM (the `.idle` branch in `reveal(at:)`) — verified by grep + a structural test. CLAUDE.md §8.11 P0 invariant preserved end-to-end.
- **Foundation-only purity preserved.** VM imports only Foundation — verified by both the Task 1 verify-block grep AND a structural Swift Testing case (`vmSourceFile_importsOnlyFoundation`) that re-reads the source from disk and asserts no SwiftUI / Combine / SwiftData / UIKit / AppKit imports.
- **Wave-0 GameKit complete.** All 5 Wave-0 files now exist (DesignKit Wave-0 from plan 03-01 + GameKit Wave-0 from this plan): `ColorVisionSimulator.swift`, `ThemeGameNumberTests.swift`, `GameNumberPaletteWongTests.swift`, `MinesweeperVMFixtures.swift`, `MinesweeperViewModelTests.swift`.

## Task Commits

Each task committed atomically:

1. **Task 1: MinesweeperViewModel — @Observable @MainActor orchestrator** — `80746fd` (feat)
2. **Task 2: MinesweeperVMFixtures — pre-built boards for VM tests** — `a53ea96` (test)
3. **Task 3: MinesweeperViewModelTests — Swift Testing suite for VM contract** — `fd6f515` (test)

## Files Created/Modified

| File | Lines | Disposition |
|------|-------|-------------|
| `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` | 278 | NEW — `@Observable @MainActor final class` + `GameOutcome` + `LossContext` |
| `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` | 114 | NEW — 4 deterministic board factories (easy first-tap, hard almost-won, hard lost, easy with 3 flagged) |
| `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` | 491 | NEW — Swift Testing, 8 nested suites, 29 unique test cases |

All files <500 lines (CLAUDE.md §8.5 hard cap). The test file at 491 lines is intentional — single test file per VM is preferable for discoverability per the planner's note; if it crosses 500 in P3-03, split per-suite into siblings.

## Decision IDs implemented

- **D-05** — `timerAnchor: Date?` + `pausedElapsed: TimeInterval` accumulator owned by the VM; the future `MinesweeperHeaderBar` `TimelineView` will derive `displayed = pausedElapsed + (now - timerAnchor)` from these fields.
- **D-06** — `pause()` accumulates `clock() - timerAnchor` into `pausedElapsed` and nils the anchor; `resume()` sets a new anchor. Both no-op outside `.playing`. Verified by `pause_inPlaying_accumulatesElapsedAndNilsAnchor`, `resume_inPlaying_setsNewAnchor`, `pause_idleState_isNoOp`, `resume_idleState_isNoOp`.
- **D-07** — First reveal generates the board atomically with timer start: the `.idle` branch in `reveal(at:)` calls `BoardGenerator.generate(...)` then sets `timerAnchor = clock()`. Verified by `firstReveal_idleToPlaying_generatesFirstTapSafeBoard`.
- **D-08** — `freezeTimer()` accumulates final elapsed into `pausedElapsed` and nils the anchor on `.won` / `.lost` transition — same math as `pause()`. Verified by `terminalLoss_freezesTimer`.
- **D-10** — `requestDifficultyChange(_:)` from `.playing` stashes `pendingDifficultyChange` and flips `showingAbandonAlert = true`; from `.idle` / `.won` / `.lost` it applies immediately. `confirmDifficultyChange` / `cancelDifficultyChange` complete the state machine. Verified by 5 `DifficultyChangeAlert` tests.
- **D-11** — `setDifficulty(_:)` writes `MinesweeperDifficulty.rawValue` to UserDefaults key `mines.lastDifficulty`; init reads it back with garbage-rawValue fallback to `.easy`. Verified by 4 `DifficultyPersistence` tests.
- **D-12** — Default difficulty on first launch is `.easy` (proven by `init_emptyDefaults_fallsBackToEasy`).

## Requirement IDs satisfied (VM-side)

- **MINES-02** — `reveal(at:)` and `toggleFlag(at:)` state transitions; flag-on-revealed is no-op (engine D-07 + view D-15 sympathy). Verified by 4 `RevealAndFlag` tests.
- **MINES-05 timer** — pause / resume / freeze covered by 6 `TimerState` tests including `frozenElapsed_inIdleIsZero`.
- **MINES-05 counter** — `minesRemaining = mineCount - flaggedCount`; updates synchronously on toggleFlag; goes negative on over-flagging (informational counter, not gating). Verified by 3 `MineCounter` tests.
- **MINES-06** — `restart()` resets to `.idle` board at the same difficulty; flagged count, timer, lossContext all clear. Verified by 2 `Restart` tests.
- **MINES-07** — `revealMine_transitionsToLost`, `revealAllSafeCells_transitionsToWon`. `terminalOutcome` exposed for the future end-state card.
- **MINES-11** — `lossContext` populated on `.lost`: `minesHit ≥ 1`, `safeCellsRemaining` matches the post-loss board scan. Verified by `LossContext` tests. View-side wrong-flag rendering remains a Plan 03-03/03-04 view-tier concern; the VM lossContext shape is what the view will read.

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` → BUILD SUCCEEDED (no errors, only pre-existing warnings)
- `xcodebuild test -only-testing:gamekitTests/MinesweeperViewModelTests` → ** TEST SUCCEEDED **; 29 unique test cases across 8 nested suites
- `xcodebuild test -only-testing:gamekitTests` (full gamekit test target) → all P2 engine tests still green; new VM tests added cleanly without regression
- `grep -E "^import (SwiftUI|SwiftData|UIKit|AppKit|Combine|GameplayKit)" MinesweeperViewModel.swift` → exit 1 (Foundation-only verified)
- `grep -c '^\s*board = BoardGenerator.generate' MinesweeperViewModel.swift` → 1 (first-tap firewall verified — exactly one call site in production code)
- VM file: 278 lines (well under 500 hard cap)
- Test file: 491 lines (under 500 hard cap; intentional single-file shape per planner note)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug prevention] toggleFlag tests retargeted via `firstHiddenNonMine(on:)` helper instead of hardcoded (8,8)**
- **Found during:** Task 3 test authorship (analysis of seed-1 cascade reach)
- **Issue:** The plan's RevealAndFlag tests hardcoded `MinesweeperIndex(row: 8, col: 8)` as the toggleFlag target after a `(0,0)` first reveal. With seed=1 on Easy 9×9, the flood-fill cascade from `(0,0)` may reach `(8,8)` (depends on the empty-cell path), in which case `(8,8)` would already be `.revealed` and toggleFlag would no-op — the test would silently fail to test the hidden→flagged transition. The plan even commented "far from first tap" but the cascade reaches farther than expected at this density.
- **Fix:** Added `static func firstHiddenNonMine(on:)` helper to the outer suite and use it in `toggleFlag_hiddenToFlagged_incrementsFlaggedCount`, `toggleFlag_flaggedToHidden_decrementsFlaggedCount`, and `minesRemaining_decrementsOnFlag`. The helper picks the FIRST hidden non-mine cell after the cascade, guaranteeing the test exercises the actual toggleFlag transition regardless of seed-1 cascade reach.
- **Files modified:** `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` only — VM unchanged.
- **Verification:** All 4 `RevealAndFlag` tests + the affected `MineCounter` test pass.
- **Committed in:** `fd6f515` (Task 3 commit)

**2. [Rule 2 — Missing critical functionality] Added one test the plan omitted: `frozenElapsed_inIdleIsZero`**
- **Found during:** Task 3 — reviewing the `frozenElapsed` accessor's defensive math
- **Issue:** The VM's `frozenElapsed` returns `pausedElapsed` when `timerAnchor == nil`, which means an `.idle` VM with `pausedElapsed == 0` returns `0`. The plan's TimerStateTests covered pause/resume but never verified that `.idle` produces `0` — meaning a future contributor accidentally seeding `pausedElapsed` non-zero in `init` would not be caught.
- **Fix:** Added `frozenElapsed_inIdleIsZero` test to `TimerStateTests`. One-line `#expect(vm.frozenElapsed == 0)` after `makeVM`.
- **Files modified:** `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` only.
- **Verification:** Test passes.
- **Committed in:** `fd6f515` (Task 3 commit)

### Other planned deviations from RESEARCH §Code Examples 1 (called out by the planner; reproduced here for the record)

The planner explicitly listed three deviations from the RESEARCH canonical example. All three were applied as planned:

1. **Injection seams added** (`clock`, `rng`, `userDefaults` parameters with production defaults). Strict superset of the research example; required for the deterministic timer-math + mine-layout + persistence tests in Task 3.
2. **`LossContext` struct replaces inline tuple.** Tuples are not Equatable in Swift; the struct is `Equatable, Sendable` so `#expect(vm.lossContext == ...)` shape works.
3. **`idleBoard(for:)` static helper added.** The placeholder-board construction is reused across `init` and `restart()` — extracting avoided two divergent code paths.

These are listed in this section because the SUMMARY contract from the planner asks the executor to enumerate them explicitly.

### Authentication gates

None — pure Swift code, no external services, no auth.

---

**Total deviations:** 2 auto-fixed (1 bug-prevention, 1 missing-coverage) + 3 planned-deviation reaffirmations.
**Impact on plan:** Both auto-fixes harden test coverage. No scope creep. VM contract unchanged from the locked surface.

## Wave 0 status (per `03-VALIDATION.md`)

**5 / 5 Wave-0 files complete:**

- ✅ `DesignKit/Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift` (Plan 03-01)
- ✅ `DesignKit/Tests/DesignKitTests/ThemeGameNumberTests.swift` (Plan 03-01)
- ✅ `DesignKit/Tests/DesignKitTests/GameNumberPaletteWongTests.swift` (Plan 03-01)
- ✅ `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` (this plan)
- ✅ `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` (this plan)

Plans 03-03 and 03-04 (the view tier) can now author against:
- A token contract proven CVD-safe under the resolver path (Plan 03-01).
- A VM contract proven by 29 deterministic state-transition tests (this plan).

## Issues Encountered

None — all three tasks executed cleanly. Build was green from the first compile of MinesweeperViewModel.swift; tests were green from the first run.

## TDD Gate Compliance

The plan declared `tdd="true"` on each task. The execution shape was test-after-production-per-task:
- Task 1: production VM file + verify build (no test commit because the test fixtures don't exist yet by design — Task 2 ships them)
- Task 2: fixtures (test-target file)
- Task 3: full test suite — first run all green

No RED gate was attempted before writing the production VM because the plan's task ordering (production VM → fixtures → tests) was explicit and intentional: the VM had to compile before fixtures could `@testable import` it, and fixtures had to exist before the test suite could compile. This is "TDD-style" rather than strict RED→GREEN; the plan's `tdd` attribute documents the discipline of test-tight coupling rather than literal red-green-refactor cycles per task. All three commits ship in proper conventional shape (`feat`, `test`, `test`).

## User Setup Required

None — pure Swift code, no external services, no environment configuration.

## Next Plan Readiness

Plan 03-03 (or whatever the next view-tier plan is) can immediately:
- Wire `@State private var viewModel: MinesweeperViewModel` in `MinesweeperGameView`
- Bind `.alert(isPresented: $viewModel.showingAbandonAlert)` for the D-10 mid-game switch
- Bind `TimelineView(.periodic(from: viewModel.timerAnchor ?? .now, by: 1))` to the timer chip
- Read `viewModel.terminalOutcome` / `viewModel.lossContext` / `viewModel.frozenElapsed` for the end-state card
- Call `viewModel.reveal(at:)` / `viewModel.toggleFlag(at:)` / `viewModel.requestDifficultyChange(_:)` from cell gestures + toolbar Menu

The VM is the firewall between view code and engine code. Views never `import` the engine modules directly.

## Self-Check: PASSED

- ✅ `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` exists (NEW, 278 lines)
- ✅ `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` exists (NEW, 114 lines)
- ✅ `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` exists (NEW, 491 lines)
- ✅ Commit `80746fd` exists in repo (Task 1 — feat: VM)
- ✅ Commit `a53ea96` exists in repo (Task 2 — test: fixtures)
- ✅ Commit `fd6f515` exists in repo (Task 3 — test: VM tests)
- ✅ `xcodebuild test -only-testing:gamekitTests/MinesweeperViewModelTests` reports TEST SUCCEEDED, 29 unique cases all green
- ✅ Foundation-only purity grep returns exit 1 (no SwiftUI / Combine / SwiftData / UIKit / AppKit)
- ✅ First-tap firewall: exactly one `BoardGenerator.generate(...)` production call site

---

*Phase: 03-mines-ui*
*Completed: 2026-04-26*
