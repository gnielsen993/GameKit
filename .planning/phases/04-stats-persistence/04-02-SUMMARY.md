---
phase: 04-stats-persistence
plan: 02
subsystem: persistence-service
tags: [swift, swiftdata, service, swift-testing, main-actor, tdd]

# Dependency graph
requires:
  - phase: 04-stats-persistence
    plan: 01
    provides: "GameKind / Outcome / @Model GameRecord / @Model BestTime / InMemoryStatsContainer.make() factory — all consumed by record(...)/resetAll() bodies and the test suite"
  - phase: 02-mines-engines
    provides: "MinesweeperDifficulty.rawValue (easy/medium/hard) — canonical key passed by Plan 05 VM into record(difficulty:)"
provides:
  - "GameStats — @MainActor final class; single write-side boundary (D-11) consumed by Plan 04-04 (App scene wiring) + Plan 04-05/06 (VM injection + Settings reset)"
  - "Public record(gameKind:difficulty:outcome:durationSeconds:) throws — synchronous explicit save (PERSIST-02 / SC1 load-bearing call)"
  - "Public resetAll() throws — atomic via modelContext.transaction { delete(model:) × 2 } (D-13)"
  - "GameStatsTests — 8 @Test funcs; @MainActor @Suite struct; per-test InMemoryStatsContainer.make() factory; total runtime ≈ 1.0s wall-clock"
affects: [04-03-stats-exporter, 04-04-app-wiring, 04-05-stats-view, 04-06-settings-view]

# Tech tracking
tech-stack:
  added: ["os.Logger (system framework — first usage in GameKit; subsystem 'com.lauterstar.gamekit', category 'persistence' per RESEARCH Standard Stack)"]
  patterns:
    - "@MainActor final class service with private let modelContext: ModelContext + private let logger = Logger(...) — locked as the standard P4 service shape (consumed by future StatsExporter and any subsequent write-side service)"
    - "record(...) ordering: insert GameRecord FIRST, evaluate BestTime SECOND wrapped in do/catch, save THIRD — best-effort BestTime cannot block GameRecord persistence (Discretion lock from CONTEXT)"
    - "Capture-let pattern for #Predicate (RESEARCH §Pattern 4 footnote): `let kindRaw = gameKind.rawValue` before predicate closure — KeyPath cannot capture self"
    - "Strictly-less-than guard for BestTime mutation (`if seconds < current.seconds`) — equal-seconds is a no-op (calmer fewer writes; matches PROJECT.md tone)"
    - "modelContext.transaction { delete(model:) × 2 } — iOS 17.3+ atomic batch-delete for resetAll (D-13)"
    - "TDD plan-level cycle: test(...) RED commit landed BEFORE feat(...) GREEN commit (D-30 + Swift Testing × in-memory container)"

key-files:
  created:
    - "gamekit/gamekit/Core/GameStats.swift (155 lines)"
    - "gamekit/gamekitTests/Core/GameStatsTests.swift (193 lines)"
  modified: []

key-decisions:
  - "04-02: GameStats is @MainActor final class with single private let modelContext: ModelContext + os.Logger — NOT enum-namespace (carries state; VM injection requires instance reference per D-14)"
  - "04-02: record(...) wraps evaluateBestTime in do/catch; on failure, logger.error(...) emits via os.Logger and the outer try modelContext.save() still flushes the GameRecord (Discretion lock — best-effort BestTime, never best-effort GameRecord)"
  - "04-02: BestTime mutation uses strictly-less-than (`<`, not `<=`) — equal-seconds win is a no-op on both `seconds` and `achievedAt`. Documented in equalSecondsIsNoop test as a calmer-fewer-writes choice; Plan 05 StatsView display rationale: 'Best: 1:42' shows the seconds value; achievedAt is stored but not surfaced in P4, so equal-seconds churning achievedAt would be invisible to the user but cost a CloudKit sync token in P6"
  - "04-02: Capture-let predicate pattern locked (`let kindRaw = gameKind.rawValue` before #Predicate) — RESEARCH Pattern 4 footnote: KeyPath cannot capture self; future P4 service patterns inherit this idiom (StatsAggregation Plan 05, any future writer)"
  - "04-02: Logger interpolation uses `\\(error.localizedDescription, privacy: .public)` — failure messages are non-PII (game stats only; SwiftData fetch error names) and explicit privacy: .public is the safe-by-default annotation for OSLog under Swift 6 (avoids 'private' redaction in log inspection)"
  - "04-02: TDD gate sequence honored — test commit `ed5cce6` (RED, build fails: 'Cannot find type GameStats in scope') landed BEFORE feat commit `f3974bd` (GREEN, all 8 tests pass). Verifiable in `git log --oneline`"

patterns-established:
  - "Pattern 1: @MainActor final class P4 service with ModelContext ivar + os.Logger ivar + explicit `try modelContext.save()` on every write path (RESEARCH Pitfall 10) — template for StatsExporter and future writers"
  - "Pattern 2: insert-then-evaluate-then-save ordering with do/catch wrapping the secondary write — primary write always persists; secondary write is best-effort"
  - "Pattern 3: TDD plan-level RED/GREEN gate — test(...) commit lands first, fails to compile by design ('Cannot find type X in scope'), GREEN feat(...) commit follows; confirms P2's TDD pattern transfers cleanly to P4"
  - "Pattern 4: Per-test fresh in-memory ModelContainer factory in @MainActor @Suite struct — ~0–1ms per test, total suite runtime ≈ 1.0s wall-clock for 8 tests; no parallel-execution row-bleed under Swift Testing's default concurrent runner"

requirements-completed: [PERSIST-02]

# Metrics
duration: 8min
completed: 2026-04-26
---

# Phase 04 Plan 02: GameStats Write-Side Boundary Summary

**`@MainActor final class GameStats` lands as the single write-side boundary between gameplay and SwiftData (D-11). Synchronous `try modelContext.save()` on every write path satisfies PERSIST-02's force-quit survival mandate. 8 Swift Testing `@Test` funcs pass; TDD RED→GREEN gate sequence honored.**

## Performance

- **Duration:** 8 min (480 seconds wall-clock)
- **Started:** 2026-04-26T15:40:29Z
- **Completed:** 2026-04-26T15:48:29Z
- **Tasks:** 1/1
- **Files created:** 2 (1 production + 1 test file)
- **Test runtime:** GameStatsTests suite ≈ 1.0s wall-clock for 8 `@Test` funcs (per-test fresh in-memory container; ~0.125s/test on average including container init + ModelContext + ~5ms async sleep in `equalSecondsIsNoop`)

## Accomplishments

- `GameStats` write-side boundary lands at `gamekit/gamekit/Core/GameStats.swift` — `@MainActor final class` with `init(modelContext:)`, `record(gameKind:difficulty:outcome:durationSeconds:) throws`, and `resetAll() throws`. Foundation + SwiftData + os imports only — **no SwiftUI** (service layer; verified via `! grep -q "import SwiftUI"`).
- `record(...)` body order locked per D-12 + Discretion: `modelContext.insert(record)` → conditional `do/catch evaluateBestTime` → `try modelContext.save()`. Best-effort BestTime cannot block GameRecord persistence; the explicit synchronous save is the load-bearing PERSIST-02 / SC1 call.
- `resetAll()` body locked per D-13: `try modelContext.transaction { try modelContext.delete(model: GameRecord.self); try modelContext.delete(model: BestTime.self) }` then `try modelContext.save()`. Partial reset is impossible by construction.
- `evaluateBestTime` private helper uses the capture-let `#Predicate` pattern (RESEARCH §Pattern 4 footnote): `let kindRaw = gameKind.rawValue` captured before predicate closure (KeyPath cannot capture `self`). Strictly-less-than guard for BestTime mutation; equal-seconds is a no-op.
- `os.Logger(subsystem: "com.lauterstar.gamekit", category: "persistence")` is the failure logger — first `os.Logger` usage in GameKit; subsystem matches the bundle ID per RESEARCH §Standard Stack.
- **TDD gate sequence honored:** RED commit `ed5cce6` landed first (build fails: `Cannot find type 'GameStats' in scope`), GREEN commit `f3974bd` followed with the production class. Verifiable in `git log --oneline`.
- All 8 `@Test` funcs pass on first GREEN run — zero deviations during implementation.
- Full repo test suite remains green (no regression in P2 engines, P3 ViewModel, or P4-01 schema smoke tests).

## Task Commits

Each phase of the TDD cycle was committed atomically:

1. **Task 1 RED — failing test suite** — `ed5cce6` (test)
2. **Task 1 GREEN — production GameStats** — `f3974bd` (feat)

REFACTOR commit not needed — code already matches the plan's verbatim shape with no duplication; mandated file-header comments are load-bearing.

_Plan metadata commit pending after this SUMMARY._

## Files Created/Modified

**Created:**
- `gamekit/gamekit/Core/GameStats.swift` (155 lines) — `@MainActor final class GameStats`. Header block documents the firewall purpose (D-11) and Phase 4 invariants (D-12 / D-13 / D-14 / Pitfalls 3+9+10). One public init, two public throwing methods (`record`, `resetAll`), one private throwing helper (`evaluateBestTime`).
- `gamekit/gamekitTests/Core/GameStatsTests.swift` (193 lines) — `@MainActor @Suite struct GameStatsTests` with 8 `@Test` funcs. Per-test `try InMemoryStatsContainer.make()` factory (D-31).

**Modified:** None — pure additive plan.

## Test Coverage Map

| `@Test` func | Behavior asserted | D-12 / D-13 ref | T-04-* mitigated |
|---|---|---|---|
| `recordWin` | win → 1 GameRecord (`outcomeRaw == "win"`) + 1 BestTime (`seconds == 102.5`) | D-12 step 1+2 | T-04-05 (BestTime correctness baseline) |
| `recordLoss` | loss → 1 GameRecord (`outcomeRaw == "loss"`) + 0 BestTime | D-12 step 2 negative path | — |
| `bestTimeOnlyOnFaster` | seed 100s → slower 150s no-op → faster 80s mutates in place; total 1 BestTime row, 3 GameRecord rows | D-12 insert-or-mutate + faster-only | T-04-05 (Tampering — slower win cannot replace) |
| `bestTimeIsolatedPerDifficulty` | easy + hard tracked independently; mutating easy leaves hard untouched | D-12 predicate isolation | T-04-05 (per-cohort isolation) |
| `bestTimeIsolatedPerGameKind` | hand-built `gameKindRaw == "future-game"` BestTime preserved when minesweeper/easy win lands; predicate filters by `gameKindRaw` | D-12 predicate isolation | T-04-05 (cross-game pollution prevented; future-game wiring proven) |
| `resetAllAtomic` | 3 records + 1 BestTime → resetAll → both arrays empty | D-13 atomic transaction | T-04-06 (atomicity) |
| `resetAllEmptyIsNoop` | empty store → resetAll does not throw; store remains queryable | D-13 transaction edge case | T-04-06 (no-op safety) |
| `equalSecondsIsNoop` *(async)* | 60s win → 5ms sleep → second 60s win → BestTime count still 1 AND `achievedAt` unchanged | strictly-less-than guard | calmer-writes choice |

**Coverage of `04-VALIDATION.md` Per-Requirement Verification Map:** all 5 GameStats tests required by VALIDATION are covered (recordWin, recordLoss, bestTimeOnlyOnFaster, resetAllAtomic, plus the predicate-isolation and equal-seconds extras).

## Decisions Made

- **`final class` (not `enum`-namespace):** `GameStats` carries state (`modelContext`, `logger`) and the VM injection point per D-14 needs an instance reference. The `enum` shape works for `StatsExporter` (Plan 03 — no state) but not here.
- **`@MainActor` annotation:** `ModelContext` is not `Sendable` per RESEARCH Pattern 6. Locked as standard for ALL P4 services (matches `MinesweeperViewModel` actor isolation; smoke test scaffold in 04-01 already established this for the test layer).
- **insert-then-evaluate-then-save ordering with do/catch wrapping `evaluateBestTime`:** if the BestTime predicate or insert/mutate throws, the GameRecord is already pending and the outer `try modelContext.save()` still flushes it. Best-effort BestTime; gameplay record always persists. The `logger.error(...)` call emits non-PII fetch-error names through `os.Logger` for post-hoc inspection.
- **Strictly-less-than guard for BestTime mutation (`<`, not `<=`):** equal-seconds is a no-op on both `seconds` and `achievedAt`. RESEARCH does not mandate this; it matches PROJECT.md "calm, fewer writes" tone and avoids unnecessary CloudKit sync-token consumption when sync flips on in P6. **Note for Plan 05 StatsView display rationale:** `BestTime.seconds` is what gets displayed ("Best: 1:42"); `achievedAt` is stored but not surfaced in P4. Churning `achievedAt` on equal-seconds wins would be invisible to the user but expensive in P6's CloudKit pipeline.
- **`Logger` interpolation uses `privacy: .public`:** failure messages are non-PII (SwiftData fetch error names like "fetchDescriptor compilation failed"). Without explicit `privacy: .public`, OSLog redacts string interpolations as `<private>` — the developer's intent for diagnostic logs is `.public`. ASVS L1 N/A here; CLAUDE.md "no analytics, no phone-home" satisfied because `os.Logger` is local-only (`com.lauterstar.gamekit` subsystem; user-installable Console.app inspection is not telemetry).
- **TDD plan-level RED→GREEN sequence locked:** committed the failing test suite first (`ed5cce6`), then the production class (`f3974bd`). The build error in the RED commit (`Cannot find type 'GameStats' in scope`) is the load-bearing proof that the test was wired correctly before the impl existed.

## Deviations from Plan

### Auto-fixed Issues

**None.** All 8 tests passed on the first GREEN run. The verbatim class shape mandated in the plan's `<action>` block compiled and ran without modification.

### Plan-acceptance-criterion-vs-reality minor variance

**1. [Documentation only] `GameStats.swift` line count: 155 vs plan-stated ≤150**

- **Plan acceptance criterion:** `Files: GameStats.swift ≤ 150 lines`.
- **Actual:** 155 lines (33-line header + 12 blank lines + ~110 lines of code+inline comments).
- **Why over:** the plan's `<action>` block mandated a verbose file header naming D-11, D-12, D-13, D-14, RESEARCH Pitfalls 3+9+10, the ModelContext non-Sendable rationale, and the Discretion lock. Removing any of these would drop documentation the plan explicitly required.
- **Resolution:** accept the 5-line overshoot. CLAUDE.md §8.5's actual hard cap is 500 lines; the plan's 150-line acceptance criterion was a planner estimate, not a CLAUDE.md constraint. No action taken — documenting here for traceability.
- **Files affected:** `gamekit/gamekit/Core/GameStats.swift`
- **Commit:** `f3974bd` (GREEN feat commit)

---

**Total deviations:** 0 auto-fixed bugs; 1 documentation-only line-count variance (155 vs 150, well under the 500-line CLAUDE.md hard cap). No CONTEXT decisions violated. No scope creep.

## Issues Encountered

None.

## Wave-0 Status Update

Wave-0 of Phase 04 carries 5 required artifacts (per `04-VALIDATION.md`):

| Artifact | Owner | Status |
|---|---|---|
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | Plan 04-01 | ✅ Complete (2026-04-26) |
| `gamekitTests/Core/ModelContainerSmokeTests.swift` | Plan 04-01 | ✅ Complete (2026-04-26) |
| `gamekitTests/Core/GameStatsTests.swift` | **Plan 04-02 (this plan)** | **✅ Complete (2026-04-26)** |
| `gamekitTests/Core/StatsExporterTests.swift` | Plan 04-03 | ⬜ Pending |
| `gamekitTests/Core/StatsAggregationTests.swift` (optional) | Plan 04-05 | ⬜ Pending |

**Plan 04-02 share: 1/1 owned artifact complete. Phase Wave-0 share: 3/4 required + 0/1 optional.** StatsExporterTests is the last required Wave-0 artifact; ships in Plan 04-03.

## TDD Gate Compliance

Plan-level TDD gate sequence verified per `<tdd_execution>` Plan-Level TDD Gate Enforcement:

| Gate | Commit | Verification |
|---|---|---|
| RED | `ed5cce6` (test) | Build error confirmed: `Cannot find type 'GameStats' in scope` — test suite fails to compile by design |
| GREEN | `f3974bd` (feat) | All 8 `@Test` funcs pass on first run; full repo suite green (no regression) |
| REFACTOR | — | Not needed — code already matches plan's verbatim shape; no duplication; comments are load-bearing per file-header mandate |

`git log --oneline` confirms RED commit precedes GREEN commit by one position. Both are authored by this plan execution.

## Threat Flags

None — plan introduces zero new trust boundaries beyond the typed-input service layer that the threat model already enumerates (T-04-05 / T-04-06 mitigated by `bestTimeOnlyOnFaster`, `bestTimeIsolatedPerDifficulty`, `bestTimeIsolatedPerGameKind`, `resetAllAtomic`; T-04-07/08/09 accepted disposition unchanged).

The plan's `<threat_model>` mitigations are honored end-to-end:
- **T-04-05 (Tampering — BestTime "only-on-faster" rule):** mitigated by `bestTimeOnlyOnFaster` (slower win cannot replace; faster win mutates in place — single row), `bestTimeIsolatedPerDifficulty` (per-cohort), `bestTimeIsolatedPerGameKind` (predicate filters by `gameKindRaw`), and `equalSecondsIsNoop` (no `achievedAt` churn).
- **T-04-06 (Tampering — resetAll atomicity):** mitigated by `resetAllAtomic` (post-reset both arrays count == 0); the `try modelContext.transaction { ... }` block is the structural guarantee.

## CLAUDE.md compliance check

- **§1 Stack:** Swift 6 + SwiftData (iOS 17+) ✅; offline-only ✅; no ads/coins/accounts ✅; `os.Logger` is local-only (not telemetry).
- **§4 Smallest change:** zero refactoring of existing files; pure additive plan ✅. No invented architecture; reuses the `@MainActor` + `final class` + injected dependency pattern already established by `MinesweeperViewModel`.
- **§5 Tests-in-same-commit (or same-plan for TDD):** RED test commit (`ed5cce6`) and GREEN feat commit (`f3974bd`) ship in the same plan execution. Test-first sequence honored.
- **§8.5 File caps:** GameStats.swift = 155 lines, GameStatsTests.swift = 193 lines — both well under 500-line hard cap. (155 vs plan's ≤150 is a 5-line documentation variance; see Deviations.)
- **§8.6 SwiftUI correctness:** N/A — `GameStats.swift` imports only Foundation + SwiftData + os; no SwiftUI surface (verified via `! grep -q "import SwiftUI"`).
- **§8.7 No `X 2.swift` dupes:** `git status` clean throughout ✅.
- **§8.8 PBXFileSystemSynchronizedRootGroup:** new files dropped into existing `gamekit/gamekit/Core/` and `gamekit/gamekitTests/Core/` directories — auto-registered by Xcode 16 (objectVersion = 77). Zero `project.pbxproj` edits ✅; build green confirms.
- **§8.10 Atomic commits:** 2 atomic commits (RED `ed5cce6`; GREEN `f3974bd`) — no bundling of unrelated work ✅.

## Next Phase Readiness

Plans 04-03 / 04-04 / 04-05 / 04-06 can now consume:

- **`GameStats` instance (production):** Plan 04-04 will construct `GameStats(modelContext:)` from `@Environment(\.modelContext)` at the App scene root. Plan 04-05 (VM edit) will inject the optional `GameStats?` reference into `MinesweeperViewModel` per D-14 (the VM never imports SwiftData — the firewall holds).
- **`try gameStats.record(...)` write path:** Plan 04-05 will call this from `MinesweeperViewModel.recordTerminalState(outcome:)` — the synchronous save returns before user can swipe-up, so PERSIST-02 force-quit survival is wired by construction.
- **`try gameStats.resetAll()`:** Plan 04-06 will call this from a `.alert(role: .destructive)` confirmation in `SettingsView` — single button, no input parameters; atomic transaction guarantees no partial reset state.
- **TDD scaffold for Plan 04-03 (StatsExporter):** the `@MainActor @Suite struct` + per-test `try InMemoryStatsContainer.make()` factory pattern is now twice-validated (smoke + GameStats); StatsExporterTests should mirror it directly.

No blockers. Plan 04-03 (StatsExporter — JSON envelope + Codable round-trip) can start immediately.

## Self-Check: PASSED

Verified via Bash:
- `gamekit/gamekit/Core/GameStats.swift` — FOUND (155 lines)
- `gamekit/gamekitTests/Core/GameStatsTests.swift` — FOUND (193 lines)
- Commit `ed5cce6` (test 04-02 RED) — FOUND in `git log --oneline`
- Commit `f3974bd` (feat 04-02 GREEN) — FOUND in `git log --oneline`
- Plan automated verify chain — all 12 grep/test gates pass
- `xcodebuild test -only-testing:gamekitTests/GameStatsTests` — `** TEST SUCCEEDED **` (8/8 passed)
- Full repo suite `xcodebuild test` — `** TEST SUCCEEDED **` (no regression)
- TDD gate sequence: RED `ed5cce6` precedes GREEN `f3974bd` in `git log --oneline` ✅

---
*Phase: 04-stats-persistence*
*Completed: 2026-04-26*
