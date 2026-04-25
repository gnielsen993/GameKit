# Phase 2: Mines Engines - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

P2 delivers the **pure-Swift Minesweeper engine layer** that proves the hardest correctness requirement (first-tap safety) before any UI exists. Three deterministic, Foundation-only structs/enums in `Games/Minesweeper/Engine/`:

- `BoardGenerator` — produces a populated `MinesweeperBoard` for `(difficulty, firstTap, rng)`, with mines placed excluding tapped cell + bounds-clamped 8-neighbors and adjacency precomputed.
- `RevealEngine` — single-cell reveal + iterative flood-fill (no recursion).
- `WinDetector` — `isWon(board)` / `isLost(board)` predicates.

Plus the supporting models: `Difficulty`, `Index`, `Cell`, `MinesweeperBoard`, `MinesweeperGameState`. All pure value types; only `Foundation` import allowed.

**Out of scope for P2** (owned by later phases):
- Any SwiftUI view, gesture, timer, overlay (P3)
- ViewModel orchestration class — `MinesweeperViewModel` is built in P3 against this engine
- SwiftData / `ModelContainer` / stats persistence (P4)
- Animation cascade rendering (P5) — engine merely surfaces the ordered cell list P5 will animate against
- Haptics / SFX / accessibility labels (P3 bakes-in / P5 polishes)
- CloudKit (P6)

</domain>

<decisions>
## Implementation Decisions

### Difficulty representation
- **D-01:** `Difficulty` is `enum Difficulty: String, CaseIterable, Codable { case easy, medium, hard }` with computed `rows`, `cols`, `mineCount` properties. Idiomatic Swift; exhaustive switch downstream; Codable for JSON export.
- **D-02:** Raw values are lowercase strings (`"easy"`, `"medium"`, `"hard"`). These become the **stable serialization key** for P4 stats (`BestTime.difficultyRaw: String`, `GameRecord.difficultyRaw: String`) and the JSON export (PERSIST-03). Renaming a case = data break — locked.
- **D-03:** Engine layer carries **no localized display names**. `Difficulty` exposes only mechanical properties; `String(localized:)` mapping happens in the P3/P5 view layer. Keeps engine target Foundation-only.
- **D-04:** **Strictly 3 cases for v1.** No `case custom(rows, cols, mineCount)` extension hook. MINES-V2-04 (custom board sizes) earns its own redesign when v2 lands. Matches CLAUDE.md §4: "smallest change that satisfies the requirement."
- **D-05:** Board sizes per ROADMAP P2 SC1: Easy 9×9 / 10 mines, Medium 16×16 / 40 mines, Hard 16×30 / 99 mines. Locked.

### Reveal API shape
- **D-06:** `RevealEngine.reveal(at:on:) -> (board: Board, revealed: [Index])` returns the new immutable Board **and** an ordered `[Index]` list of newly-revealed cells in flood-fill discovery order. P3/P5 reveal cascade animation (MINES-08) staggers off this list — engine surfacing the order means P3 doesn't reconstruct it via set diff (lossy).
- **D-07:** Win/loss detection stays in `WinDetector`, not bundled into `RevealEngine`'s return. VM call pattern: `let r = RevealEngine.reveal(...); board = r.board; if WinDetector.isLost(board) { ... } else if WinDetector.isWon(board) { ... }`. Single-responsibility per engine.
- **D-08:** First-tap mine placement is **VM-orchestrated**: VM's first `reveal` calls `BoardGenerator.generate(difficulty:, firstTap:, rng:&)` to produce a populated board, then `RevealEngine.reveal(at:on:)`. Two pure structs, single responsibility each. Engine has no "pre-populated vs not" branch.
- **D-09:** Cell location is `struct Index: Hashable { let row, col: Int }` across the entire engine API. Hashable enables Set-based first-tap-safe exclusion (`Set(allCells) - {tapped} - tapped.neighbors8`). Compiler-checked at call sites; debug-prints are self-documenting.
- **D-10:** `Board` is an immutable value-type struct; engine functions **return new Board**, never mutate. Per ARCHITECTURE.md "always return new board." `inout` mutation rejected — breaks SwiftUI `@Observable` snapshotting and complicates undo if added later.

### RNG / seed strategy
- **D-11:** `BoardGenerator.generate(difficulty:firstTap:rng:)` accepts `inout some RandomNumberGenerator`. Idiomatic Swift. Production passes `&SystemRandomNumberGenerator()` from the VM. Tests pass `&SeededGenerator(seed: N)`. Zero coupling between engine and any specific seed type.
- **D-12:** Test seedable PRNG = **custom SplitMix64** (~15 lines) in `gamekitTests/Helpers/SeededGenerator.swift`. Production engine target does NOT ship the seedable generator — it's a test-only helper. Pure-Swift, deterministic, uniform, fast. No GameplayKit dependency.
- **D-13:** Test seeds are **hardcoded per test** (e.g. `seed: 42`). Failure is bisectable: same seed always fails the same way. Random-and-print rejected for v1 (flaky-test risk + harder bisection). One `arguments:` parameterized fuzz test per engine (D-18) supplies a fixed array of seeds — still deterministic.
- **D-14:** **v1 production uses system RNG only.** No optional `seed: UInt64?` exposed on the VM yet. Future MINES-V2 / DAILY-V2-01 (daily challenge) lands by passing a seeded `RandomNumberGenerator` to `BoardGenerator.generate` from a future VM hook — the engine API doesn't change. CLAUDE.md §4 minimum-change.

### Test depth
- **D-15:** Test framework = **Swift Testing** (`@Test` / `#expect`, parameterized via `arguments:`). Required by ROADMAP P2 SC1 ("Swift Testing suite passes"). Replace existing `gamekit/gamekitTests/gamekitTests.swift` template scaffold.
- **D-16:** Test scope = **ROADMAP success criteria + targeted invariant fuzz**. ~15 tests total across the engine surface. Bare-SC-only rejected (lowest defense-in-depth); full property/fuzz battery rejected (Phase 2 turns into a test-engineering phase). Targeted middle ground catches the "works on seed 42, breaks on seed 137" class.
- **D-17:** Per-engine invariant fuzz suites (parameterized over a fixed array of ≥100 seeds — see D-13):
  - **BoardGenerator:** for each `Difficulty` × `firstTap ∈ {(0,0), (0, cols-1), (rows-1, 0), (rows-1, cols-1), (rows/2, cols/2)}` × seed array, assert (a) exact `mineCount` mines placed, (b) tapped cell + bounds-clamped neighbors all mine-free, (c) adjacency counts match a recomputed reference.
  - **RevealEngine:** for each seed, after revealing every non-mine cell sequentially: (a) flood-fill terminates, (b) `revealed` list is contiguous (every cell in the list is reachable from the tap cell via non-mine neighbors), (c) repeating reveal on already-revealed cell is idempotent (returns identical board, empty `revealed` list).
  - **WinDetector:** for each seed-generated board, board state always satisfies exactly one of `isWon XOR isLost XOR ongoing` (mutual-exclusion invariant); revealing all non-mine cells flips to `isWon`; revealing any single mine flips to `isLost`.
- **D-18:** Add **one performance test** for Hard-board generation latency: `@Test func hardBoardGenerationUnder50ms()` using `XCTMetric.wallClockTime` (or Swift Testing's measure equivalent), asserting <50ms median. Cheap insurance against accidental O(n²) regressions in mine placement (Pitfall 1 warned about brute-force re-rolling).
- **D-19:** Test files mirror engine structure 1:1:
  - `gamekitTests/Engine/BoardGeneratorTests.swift` — mine counts, first-tap-safe, determinism, perf bench (D-18)
  - `gamekitTests/Engine/RevealEngineTests.swift` — single-reveal, flood-fill (no-recursion verified by depth check), idempotence
  - `gamekitTests/Engine/WinDetectorTests.swift` — won, lost, ongoing, mutual-exclusion fuzz
  - `gamekitTests/Helpers/SeededGenerator.swift` — SplitMix64 (D-12)
  Each file <200 lines; well under the 500-line cap (CLAUDE.md §8.5).

### Claude's Discretion
The user did not lock the following — planner has flexibility, but should align with research / CLAUDE.md / AGENTS.md / ARCHITECTURE.md:

- **`Cell` / `Board` internal layout** — flat `[Cell]` indexed by `row * cols + col` vs nested `[[Cell]]`. Either is correct. Flat is marginally faster + Swift-idiomatic for fixed-size grids; pick based on flood-fill code clarity.
- **Flag/unflag location** — engine instance method on `Board` (e.g. `board.flagged(at: idx) -> Board`) vs static on `RevealEngine` vs entirely in VM (since flags don't affect mine placement). Recommend: instance method on `Board` — flags are a pure Cell.state transform, not "reveal logic," so naming it `RevealEngine.flag` is misleading. VM-only also acceptable since flags never feed back into `BoardGenerator`/`RevealEngine`.
- **Iterative flood-fill data structure** — explicit FIFO queue (`Deque<Index>` or `Array` with index pointer) vs explicit LIFO stack. ROADMAP SC3 only requires "iterative — no recursion." Either passes; queue gives BFS order (visually nicer cascade), stack gives DFS (also fine).
- **`MinesweeperGameState` enum shape** — likely `.idle / .playing / .won / .lost(mineIdx: Index)`. Planner picks exact case set.
- **`MinesweeperPhase` enum** — animation-orchestration enum referenced in ARCHITECTURE.md is a **P3** concern, not P2. Engine ships `MinesweeperGameState` only.
- **`Cell.state` representation** — single enum with cases (`.hidden`, `.revealed(adjacent: Int)`, `.flagged`, `.mineHit`) vs flag bits / parallel arrays. Recommend single enum — best self-documents in tests.

### Folded Todos
None — STATE.md `Pending Todos` is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/PROJECT.md` — Vision, constraints, key decisions, out-of-scope list
- `.planning/REQUIREMENTS.md` §Minesweeper — MINES-01, MINES-03, MINES-04 (the requirements P2 must satisfy)
- `.planning/ROADMAP.md` §"Phase 2: Mines Engines" — goal, the 5 success criteria, dependency on P1
- `.planning/STATE.md` — current position, accumulated decisions
- `.planning/phases/01-foundation/01-CONTEXT.md` — Prior-phase decisions still in force (TabView shell, DesignKit linking, no SwiftData yet, file caps)

### Architecture & pitfalls research
- `.planning/research/ARCHITECTURE.md` §"Component Responsibilities" — `BoardGenerator`, `RevealEngine`, `WinDetector` contracts; `Games/Minesweeper/Engine/` subfolder rule; pure-engine + Observable VM + dumb View pattern
- `.planning/research/ARCHITECTURE.md` §"Validating the Folder Layout" — exact file placement under `gamekit/gamekit/Games/Minesweeper/Engine/`
- `.planning/research/PITFALLS.md` §"Pitfall 1: First-tap loss…" — single-rule mine placement (`allCells - {tapped} - tapped.neighbors8`), bounds-clamped neighbors, no re-roll loop, exact P2 unit-test list
- `.planning/research/STACK.md` — Swift 6 strict concurrency, Foundation-only purity rule for engines
- `.planning/research/SUMMARY.md` — Research convergence summary

### Working rules
- `CLAUDE.md` §1 (absolute constraints — Swift 6, iOS 17+), §4 (rules for AI changes — pure/testable engines, no SwiftUI/modelContext, smallest change), §5 (testing expectations — engine determinism, happy + empty + edge), §8.5 (≤500-line Swift cap), §8.7 (no Finder dupes), §8.8 (synchronized root group auto-registration), §8.11 (first-tap safety is P0)
- `AGENTS.md` — Mirror of CLAUDE.md for non-Claude tools

### Sibling references (read-only)
- `../DesignKit/Sources/DesignKit/` — Confirm DesignKit is NOT imported by any engine file (purity check)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`gamekit.xcodeproj`** (Xcode 16, `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup`) — synchronized root group auto-registers new `.swift` files in folders. Drop new engine files into `gamekit/gamekit/Games/Minesweeper/Engine/` and the test files into `gamekit/gamekitTests/Engine/` and they auto-register. **No `pbxproj` hand-patching required for new files** (CLAUDE.md §8.8). New top-level folders (`Games/Minesweeper/`, `Games/Minesweeper/Engine/`, `gamekitTests/Engine/`, `gamekitTests/Helpers/`) — verify whether these need a one-time `pbxproj` group registration or whether the synchronized root group covers nested-folder creation too. Likely covered, but plan a build-and-confirm step.
- **`gamekit/gamekitTests/gamekitTests.swift`** — Default Swift Testing target template. Will be replaced/augmented by the new engine tests under `gamekitTests/Engine/`. Test target already exists (P1 verified) — no target-membership changes needed.
- **No prior Mines code** — `Games/` folder does not yet exist; P2 is the first time `Games/Minesweeper/` is created.

### Established Patterns
- **DesignKit token discipline** does NOT apply to engines — engines have zero UI. The pre-commit hook (FOUND-07, P1-02) restricts checks to `Games/` and `Screens/`, but engines under `Games/Minesweeper/Engine/` should never trigger the hook because they import only `Foundation` (no `Color(...)`, no `cornerRadius:`, no `padding(`). If the hook fires on an engine file, that's a bug — engine has accidentally imported SwiftUI.
- **File size cap** (CLAUDE.md §8.1, §8.5) — ≤500-line hard cap. Engines are likely small (BoardGenerator ~80 lines, RevealEngine ~120 lines incl. flood-fill, WinDetector ~30 lines). If RevealEngine bloats past ~200 lines, split flood-fill into a sibling file.
- **Foundation-only purity rule** — verified at build target level (ARCHITECTURE.md). Add `import Foundation` only; no `import SwiftUI`, `import SwiftData`, `import GameplayKit`. Anyone tempted to use `GKMersenneTwisterRandomSource` for the seedable PRNG: explicitly rejected in D-12.

### Integration Points
- **No integration with P1 shell** — engines are pure value types with no consumers in P2. P3's `MinesweeperViewModel` will be the first consumer.
- **Test target reuse** — `gamekitTests` target already exists from P1; just add new files under it. New `Engine/` and `Helpers/` subfolders auto-register.

### Cross-Cutting Invariants Active in P2
Per ROADMAP.md "Cross-Cutting Invariants" (active P1 → P7): file-size cap, no Finder dupes, project hygiene. **DesignKit token discipline** is structurally non-applicable to engines (no UI). **CloudKit-compatible schema** is non-applicable (no SwiftData). **Bundle ID stability** is project-level (no engine touches `pbxproj`).

</code_context>

<specifics>
## Specific Ideas

- **Engine target purity is the headline.** If any engine `.swift` file imports SwiftUI / SwiftData / UIKit / GameplayKit, that's a planning bug, not an implementation choice. ROADMAP P2 SC5 ("Engines import only `Foundation`") is the load-bearing test of this phase.
- **First-tap-safe placement is non-negotiable** (CLAUDE.md §8.11) and is implemented by single-shot `sample(without_replacement, from: allCells - {tapped} - tapped.neighbors8, count: difficulty.mineCount)`. **No re-roll loop allowed** — Pitfall 1 explicitly warns against it (Hard density makes brute-force re-roll a hang).
- **Bounds-clamped neighbors** for corner/edge taps: `(0,0)` excludes 4 cells (self + 3 neighbors), edge cells exclude 6 (self + 5), interior cells exclude 9 (self + 8). Test list in PITFALLS.md is the spec.
- **Adjacency counts precomputed at board-generation time**, not on-demand at reveal. Per ARCHITECTURE.md and standard performance practice — adjacency is read 100s of times per game, computed once.
- **Iterative flood-fill, no recursion** (ROADMAP SC3) — explicit queue or stack. Stack growth on a 16×30 mine-clustered board is the failure mode this guards against.
- **Test reproducibility ethos** — every test failure should be reproducible by re-running with the same seed. Hardcoded seeds + SplitMix64 (D-12, D-13) deliver this.

</specifics>

<deferred>
## Deferred Ideas

### Surfaced during discussion but pushed to other phases or v2
- **`case custom(rows, cols, mineCount)` on `Difficulty`** — D-04 keeps to 3 cases. MINES-V2-04 (custom board sizes) earns its own enum redesign when v2 lands.
- **Production seedable RNG / daily challenge hook** — D-14 keeps v1 to system RNG. DAILY-V2-01 (daily seed) re-enters via the existing `inout some RandomNumberGenerator` API — no engine surface change needed at that time.
- **Full property/fuzz test battery** — D-16 keeps targeted scope. If a future regression bites, the test file structure (D-19) cleanly accepts more `@Test` functions without restructuring.
- **`MinesweeperPhase` animation-orchestration enum** — referenced in ARCHITECTURE.md but it's a P3/P5 view-layer concern, not engine.
- **`MinesweeperViewModel`** — P3 builds against this engine.
- **Mid-game state persistence (resume after force-quit)** — Pitfall 10 mentions snapshot-on-background as a future hardening. Engine `Board` is `Codable`-trivial (composed of `Codable` value types), so adding mid-game persistence in a later phase requires no engine change.

### Reviewed Todos (not folded)
None — STATE.md `Pending Todos` was empty.

</deferred>

---

*Phase: 02-mines-engines*
*Context gathered: 2026-04-25*
