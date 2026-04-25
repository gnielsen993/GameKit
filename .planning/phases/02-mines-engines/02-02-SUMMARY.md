---
phase: 02-mines-engines
plan: 02
subsystem: testing
tags:
  - swift
  - testing
  - rng
  - test-helper
  - splitmix64
dependency_graph:
  requires:
    - 02-01-PLAN (Minesweeper model layer — though SeededGenerator itself does not import any model types)
  provides:
    - SeededGenerator (deterministic test PRNG conforming to RandomNumberGenerator)
  affects:
    - 02-03-PLAN (BoardGenerator tests will consume SeededGenerator(seed: N))
    - 02-04-PLAN (RevealEngine tests will consume SeededGenerator(seed: N))
    - 02-05-PLAN (WinDetector tests will consume SeededGenerator(seed: N))
tech_stack:
  added:
    - SplitMix64 PRNG (Steele-Lea-Flood, 2014) — pure Swift, ~15-line body
  patterns:
    - test-only helper isolated to gamekitTests target via folder placement (no @testable reverse-import seam)
    - inout some RandomNumberGenerator engine API enables zero-coupling RNG injection (D-11)
key_files:
  created:
    - gamekit/gamekitTests/Helpers/SeededGenerator.swift
  modified: []
decisions:
  - Used SplitMix64 (not GameplayKit.GKMersenneTwisterRandomSource) per CONTEXT D-12 — preserves Foundation-only engine purity (ROADMAP P2 SC5)
  - File placed in gamekit/gamekitTests/Helpers/ (test target only) — production target NEVER ships a seedable RNG (D-12 enforces this physically; production VMs will use SystemRandomNumberGenerator per D-11)
  - Default internal visibility (no public, no @frozen) — file lives in test target so visibility is moot, but kept minimal per CLAUDE.md §4 "smallest change"
  - Did NOT add a self-test for SeededGenerator — Plan 03's determinismSameSeedSameBoard test will exercise it transitively (avoids YAGNI test-of-the-test)
  - Did NOT add @testable import gamekit to the file — SeededGenerator is independent of any production type; only the test files (Plans 03/04/05) need that import
metrics:
  duration_seconds: 144
  duration_human: "2.4 min"
  tasks_completed: 1
  files_changed: 1
  lines_added: 39
  lines_body: 15
  completed_date: "2026-04-25"
---

# Phase 02 Plan 02: SeededGenerator (SplitMix64 Test PRNG) Summary

Deterministic ~15-line SplitMix64 PRNG conforming to `RandomNumberGenerator`, shipped to the test target only — unlocks Plans 03/04/05 deterministic engine tests per CONTEXT D-11/D-12/D-13.

## What Shipped

**One file, test target only:**

```
gamekit/gamekitTests/Helpers/SeededGenerator.swift   (39 lines total, ~15 line body)
```

The struct exposes a single public-ish initializer and one method, satisfying stdlib `RandomNumberGenerator`:

```swift
struct SeededGenerator: RandomNumberGenerator {
    init(seed: UInt64)
    mutating func next() -> UInt64
}
```

Default-providing protocol extensions handle `next(upperBound:)` (which `Array.shuffled(using:)` actually invokes) — no extra surface needed.

## API Contract for Plans 03/04/05

```swift
// In any test file under gamekitTests/Engine/:
var rng = SeededGenerator(seed: 42)
let board = BoardGenerator.generate(
    difficulty: .hard,
    firstTap: MinesweeperIndex(row: 8, col: 15),
    rng: &rng                                          // inout some RandomNumberGenerator
)
```

Same `seed: 42` produces the same `UInt64` sequence forever → same mine placement → same flood-fill ordering → bisectable test failures (D-13).

Production call sites (P3 ViewModel, future) substitute `var rng = SystemRandomNumberGenerator()` — engine signature is unchanged.

## Decisions Implemented

| Decision | Implementation |
|----------|----------------|
| **D-11** — engine accepts `inout some RandomNumberGenerator` | SeededGenerator conforms to that protocol; ready to be passed via `&rng` |
| **D-12** — custom SplitMix64, no GameplayKit, test-target-only | File lives in `gamekitTests/Helpers/`, never under `gamekit/gamekit/` — verified by acceptance-criteria greps |
| **D-13** — hardcoded seeds, bisectable failures | Same seed → same `UInt64` sequence forever (algorithm invariant) |
| **D-14** — v1 production uses system RNG | SeededGenerator NOT in production target; future MINES-V2 / DAILY-V2-01 lands without engine API change |
| **CLAUDE.md §8.5** — ≤500-line cap | 39 lines total, well under cap |
| **CLAUDE.md §8.8** — synchronized root group auto-registers | Confirmed: see "PBXFileSystemSynchronizedRootGroup verdict" below |

## PBXFileSystemSynchronizedRootGroup Verdict (the key learning for future test-target additions)

**No `pbxproj` hand-patching was required.** Xcode 16 (`objectVersion = 77`) `PBXFileSystemSynchronizedRootGroup` auto-registered both the new `gamekitTests/Helpers/` subfolder AND the new `SeededGenerator.swift` file inside it — the file compiled into the test target on the very first build.

**Evidence:**

1. `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E' build-for-testing` → `** TEST BUILD SUCCEEDED **`
2. Compiled artifact landed at `DerivedData/.../gamekit.build/Debug-iphonesimulator/gamekitTests.build/Objects-normal/arm64/SeededGenerator.o` (under `gamekitTests.build/`, not `gamekit.build/` — confirms test-target-only placement)

**Implication for Plans 03/04/05:** Creating the next subfolder `gamekit/gamekitTests/Engine/` and dropping `BoardGeneratorTests.swift` / `RevealEngineTests.swift` / `WinDetectorTests.swift` into it will Just Work — no `pbxproj` edits, no Xcode-UI ceremony. CLAUDE.md §8.8 is empirically validated for nested-folder creation, not just same-folder file additions.

## Acceptance Criteria — All Satisfied

- [x] File `gamekit/gamekitTests/Helpers/SeededGenerator.swift` exists
- [x] Contains `struct SeededGenerator: RandomNumberGenerator` (literal substring)
- [x] Contains `mutating func next() -> UInt64` (literal substring — required protocol method)
- [x] Contains all three SplitMix64 magic constants (`0x9E37_79B9_7F4A_7C15`, `0xBF58_476D_1CE4_E5B9`, `0x94D0_49BB_1331_11EB`)
- [x] Imports only `Foundation` — `grep -E "^import (SwiftUI|SwiftData|UIKit|GameplayKit)"` returns exit 1 (no match)
- [x] Does NOT exist anywhere under `gamekit/gamekit/` (production target) — verified `gamekit/gamekit/Games/Minesweeper/SeededGenerator.swift` and `gamekit/gamekit/SeededGenerator.swift` both absent
- [x] `xcodebuild build-for-testing` succeeds with `** TEST BUILD SUCCEEDED **`
- [x] File body is 15 lines (struct definition itself), 39 total with header — well under D-12's "~15 line body" guidance and CLAUDE.md §8.5's 500-line cap

## Threat Model Status

| Threat ID | Disposition | Mitigation Outcome |
|-----------|-------------|--------------------|
| **T-02-03** (Tampering — file ends up in production target) | mitigate | **Satisfied.** File path is `gamekit/gamekitTests/Helpers/SeededGenerator.swift` (test target). Compiled artifact lands under `gamekitTests.build/`, not `gamekit.build/`. Plan 06's purity grep on `Games/Minesweeper/Engine/` will continue to pass. |
| **T-02-04** (Information Disclosure) | accept | N/A — test-only, no PII, deterministic algorithm with no secrets. |

## Requirements Traceability

The plan frontmatter tags `MINES-04` (iterative flood-fill reveal). **This plan does NOT satisfy MINES-04 on its own** — SeededGenerator merely *enables deterministic testing* of the RevealEngine that will land in Plan 04. Marking MINES-04 complete now would be premature.

**Decision:** Defer MINES-04 completion to Plan 04 (RevealEngine implementation + tests). This SUMMARY records the dependency: Plan 04's MINES-04 satisfaction is built on top of this plan's RNG infrastructure.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1/2/3 auto-fixes triggered.

## Auth Gates

None.

## Deferred Issues

None.

## Known Stubs

None. SeededGenerator has zero stub data — it's pure algorithm.

## Self-Check

- File created: `test -f gamekit/gamekitTests/Helpers/SeededGenerator.swift` → FOUND
- Commit hash recorded: `76383dd` → `git log --oneline | grep 76383dd` → FOUND (`test(02-02): add SeededGenerator SplitMix64 PRNG (test target only)`)
- xcodebuild verdict: `** TEST BUILD SUCCEEDED **` → confirmed
- File NOT in production target: `gamekit/gamekit/**/SeededGenerator.swift` → ABSENT (correct)

## Self-Check: PASSED
