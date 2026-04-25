# Phase 2: Mines Engines - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 02-mines-engines
**Areas discussed:** Difficulty representation, Reveal output shape, RNG / seed strategy, Test depth

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Difficulty representation | Enum vs struct vs hybrid for Difficulty model. Leaks into P3 UI + P4 stats discriminator. | ✓ |
| Reveal output shape | Just new Board, vs (Board, [revealedCells]) tuple. P3 cascade animation needs the cell list. | ✓ |
| RNG / seed strategy | `inout some RandomNumberGenerator` vs `seed: UInt64?`. Affects test reproducibility. | ✓ |
| Test depth beyond ROADMAP criteria | Bare-min tests vs targeted invariants vs full fuzz battery. | ✓ |

**User's choice:** All four areas selected for discussion.

---

## Difficulty representation

### Q1: How should `Difficulty` be modeled?

| Option | Description | Selected |
|--------|-------------|----------|
| Enum + computed props (Recommended) | `enum Difficulty: String, CaseIterable { case easy, medium, hard }` with computed rows/cols/mineCount. Idiomatic, exhaustive switch, raw value = stable key. | ✓ |
| Struct + static configs | `struct Difficulty { let rows, cols, mineCount: Int; static let easy = ... }`. Flexible but loses exhaustive switch. | |
| Enum wrapping a Config struct | Enum cases hold associated `BoardConfig` value. Hybrid, slight indirection cost. | |

**User's choice:** Enum + computed properties.

### Q2: How should `Difficulty` serialize for P4 stats / JSON export?

| Option | Description | Selected |
|--------|-------------|----------|
| Lowercase string raw value (Recommended) | `"easy"`, `"medium"`, `"hard"`. Stable across renames, JSON-friendly, human-readable in export file. | ✓ |
| Int raw value | 0/1/2. Compact but reorder/insertion breaks downstream stats. | |
| Codable default (no raw) | Swift synthesizes string keys. Couples export schema to enum case-name spelling. | |

**User's choice:** Lowercase string raw value.

### Q3: Should `Difficulty` carry its own localized display name in the engine layer?

| Option | Description | Selected |
|--------|-------------|----------|
| No — UI owns display strings (Recommended) | Engine stays Foundation-only. P3/P5 view layer maps `.easy → String(localized: "Easy")`. | ✓ |
| Yes — enum exposes `displayName` | `var displayName: String { String(localized: ...) }`. Pulls localization concern into engine. | |

**User's choice:** No — UI owns display strings.

### Q4: Carve out an extension hook now for MINES-V2-04 (custom board sizes), or strictly v1?

| Option | Description | Selected |
|--------|-------------|----------|
| Strictly v1 — 3 cases only (Recommended) | Don't pre-design for v2. CLAUDE.md §4 minimum-change rule. | ✓ |
| Add `case custom(rows, cols, mineCount)` now | Future-proof but complicates exhaustive UI switches and stats discriminator key. | |

**User's choice:** Strictly v1.

---

## Reveal output shape

### Q1: What should `RevealEngine.reveal(at:on:)` return?

| Option | Description | Selected |
|--------|-------------|----------|
| (Board, [Index]) tuple (Recommended) | Return new Board + ordered list of newly-revealed cell indices in flood-fill order. P3 cascade animation needs this list. | ✓ |
| Just new Board | Caller diffs old vs new. Pushes order reconstruction to VM (lossy via set diff). | |
| Result struct | `struct RevealResult { ... }`. Same info as tuple but named. | |

**User's choice:** (Board, [Index]) tuple.

### Q2: Should reveal-result include terminal-state detection (won/lost), or stays separate via `WinDetector`?

| Option | Description | Selected |
|--------|-------------|----------|
| Separate WinDetector (Recommended) | Per ARCHITECTURE.md: WinDetector.isWon/isLost. Engines stay single-responsibility. | ✓ |
| RevealEngine returns Outcome enum | Fewer VM calls, but reveal does two jobs and WinDetector becomes dead code. | |

**User's choice:** Separate WinDetector.

### Q3: Where does first-tap mine placement live — inside `RevealEngine.reveal` or as a separate `BoardGenerator` call from VM?

| Option | Description | Selected |
|--------|-------------|----------|
| VM orchestrates: BoardGenerator on first tap, then RevealEngine (Recommended) | Per ARCHITECTURE: BoardGenerator + RevealEngine separate. VM gates on first reveal. | ✓ |
| RevealEngine.reveal handles empty-board case internally | Hides the seam from VM but couples generator to reveal engine. | |

**User's choice:** VM orchestrates.

### Q4: How is a cell location represented across the engine API?

| Option | Description | Selected |
|--------|-------------|----------|
| `Index` struct { row, col } (Recommended) | Self-documenting, compiler-checked, easy to debug, Hashable for Set-based exclusions. | ✓ |
| Flat `Int` (row*cols + col) | Compact but `(idx / cols, idx % cols)` math at every read site. | |
| Tuple `(Int, Int)` | No new type but tuples aren't Hashable in Swift. | |

**User's choice:** `Index { row, col }` struct.

---

## RNG / seed strategy

### Q1: How does `BoardGenerator` accept randomness?

| Option | Description | Selected |
|--------|-------------|----------|
| `inout some RandomNumberGenerator` (Recommended) | Idiomatic Swift. Production: `&SystemRandomNumberGenerator()`. Tests: `&SeededGenerator(seed: 42)`. | ✓ |
| `seed: UInt64?` parameter | Generator wraps seed internally. Couples engine to one seedable algorithm. | |
| Two overloads | `generate(...)` + `generate(..., seed:)`. Doubles surface area. | |

**User's choice:** `inout some RandomNumberGenerator`.

### Q2: Which seedable PRNG implementation for tests?

| Option | Description | Selected |
|--------|-------------|----------|
| Custom SplitMix64 in test target (Recommended) | ~15 lines. Pure-Swift, deterministic, uniform, fast. Test-target only. | ✓ |
| `GKMersenneTwisterRandomSource` (GameplayKit) | Apple-shipped seedable PRNG. Adds GameplayKit dep for ~15 lines of work. | |
| LinearCongruentialGenerator | Simpler than SplitMix64. Lower statistical quality. | |

**User's choice:** Custom SplitMix64 in test target.

### Q3: How are seeds chosen in tests?

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded seeds per test (Recommended) | Each test names a seed for reproducibility. Bisectable. | ✓ |
| Random seed printed on failure | `Date()`-based seed, print on assert. Catches more edge cases but flaky-test risk. | |
| Both: most tests hardcoded, one fuzz suite uses random+print | Hardcoded for named scenarios + a small fuzz harness. Overlaps with Test-depth area. | |

**User's choice:** Hardcoded seeds per test.

### Q4: Does production also accept a seed (e.g. for daily-challenge MINES-V2-DAILY)?

| Option | Description | Selected |
|--------|-------------|----------|
| No — v1 uses system RNG only (Recommended) | Strictly v1. The `inout some RandomNumberGenerator` API doesn't preclude future daily-seed work. | ✓ |
| Yes — expose optional seed in VM now | Future-proof but introduces v2 surface area into v1 VM. | |

**User's choice:** No — v1 uses system RNG only.

---

## Test depth

### Q1: How deep should the Phase 2 test suite go beyond ROADMAP's 5 success criteria?

| Option | Description | Selected |
|--------|-------------|----------|
| Targeted + invariants (Recommended) | All 5 SC + 1 invariant-fuzz suite per engine. ~15 tests total. | ✓ |
| Bare ROADMAP success criteria only | Exactly the 5 enumerated SC. ~8 tests. Lowest defense-in-depth. | |
| Full property/fuzz battery | ~50+ tests. Strongest, but Phase 2 turns into a test-engineering phase. | |

**User's choice:** Targeted + invariants.

### Q2: Add a performance test for Hard-board generation (16×30/99) latency?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — single XCTMetric/measure block (Recommended) | One measure block asserting <50ms. Cheap insurance against O(n²) regressions. | ✓ |
| No | Defer perf concerns until felt. Hard board has 480 cells, single-pass sample is O(n). | |

**User's choice:** Yes — single perf measure block.

### Q3: How should test files be organized?

| Option | Description | Selected |
|--------|-------------|----------|
| One file per engine + one suite per concern (Recommended) | BoardGeneratorTests, RevealEngineTests, WinDetectorTests. Mirrors engine structure 1:1. | ✓ |
| Single MinesweeperEngineTests.swift | All tests in one file. Easier to grep but bumps the 500-line cap. | |
| By scenario, not engine | FirstTapSafetyTests, FloodFillTests, etc. Smears one engine across files. | |

**User's choice:** One file per engine.

### Q4: Confirm Swift Testing (not XCTest)?

| Option | Description | Selected |
|--------|-------------|----------|
| Swift Testing — `@Test` / `#expect` (Recommended) | Required by ROADMAP P2 SC1. Modern, parameterized via `arguments:`, better diagnostics. | ✓ |
| XCTest | Conflicts with ROADMAP success criterion 1. | |

**User's choice:** Swift Testing.

---

## Claude's Discretion

Items the user did not lock — planner / executor has flexibility:

- Cell / Board internal layout (flat `[Cell]` vs nested `[[Cell]]`)
- Flag/unflag location (instance method on `Board` vs static on `RevealEngine` vs VM-only)
- Iterative flood-fill data structure (FIFO queue vs LIFO stack)
- `MinesweeperGameState` exact case set
- `Cell.state` enum-vs-flags representation

## Deferred Ideas

- `case custom(rows, cols, mineCount)` for MINES-V2-04 — v2
- Production seedable RNG / daily challenge hook (DAILY-V2-01) — v2
- Full property/fuzz test battery — only if regression bites
- `MinesweeperPhase` animation orchestration — P3/P5
- `MinesweeperViewModel` — P3
- Mid-game state persistence — later phase, no engine change required
