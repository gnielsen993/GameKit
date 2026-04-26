---
phase: 04-stats-persistence
plan: 01
subsystem: database
tags: [swift, swiftdata, schema, cloudkit-compat, swift-testing, ios17]

# Dependency graph
requires:
  - phase: 02-mines-engines
    provides: "MinesweeperDifficulty.rawValue (easy/medium/hard) — canonical serialization key for difficultyRaw on GameRecord and BestTime per D-05"
  - phase: 01-foundation
    provides: "iOS 17 deployment target + Swift 6 strict concurrency + Xcode 16 PBXFileSystemSynchronizedRootGroup auto-registration"
provides:
  - "GameKind raw-string enum (sole case .minesweeper, additive future cases)"
  - "Outcome raw-string enum (.win, .loss; .abandoned reserved)"
  - "@Model GameRecord — CloudKit-compatible per-game record (D-02)"
  - "@Model BestTime — CloudKit-compatible per-(gameKind, difficulty) best time (D-03)"
  - "InMemoryStatsContainer test helper — @MainActor enum factory with optional cloudKitDatabase (D-31)"
  - "ModelContainerSmokeTests — SC3 dual-config + schema-lock smoke test"
  - "iCloud.com.lauterstar.gamekit container ID forcing-function lock (D-09 in test source)"
affects: [04-02-game-stats, 04-03-stats-exporter, 04-04-app-wiring, 04-05-stats-view, 04-06-settings-view, 06-cloudkit-siwa]

# Tech tracking
tech-stack:
  added: ["SwiftData (iOS 17+ system framework, no SPM resolution needed)"]
  patterns:
    - "CloudKit-compatible @Model schema: every property optional/defaulted, no SwiftData unique-attribute decorator, all relationships optional, schemaVersion: Int = 1"
    - "@Model + Date defaults: use Date() (NOT .now) — @Model macro substitution rejects .now shorthand"
    - "Swift Testing × in-memory ModelContainer × @MainActor — critical correction vs P2's nonisolated struct (ModelContext is not Sendable)"
    - "Test-only InMemoryStatsContainer factory pairs isStoredInMemoryOnly: true + .private(...) cloudKitDatabase to validate CloudKit constraints WITHOUT contacting iCloud (Assumption A2 confirmed green)"
    - "enum-namespace test helper (zero-state, factory-only) — matches P2 idiom (BoardGenerator/RevealEngine/WinDetector/MinesweeperVMFixtures)"

key-files:
  created:
    - "gamekit/gamekit/Core/GameKind.swift (26 lines)"
    - "gamekit/gamekit/Core/Outcome.swift (26 lines)"
    - "gamekit/gamekit/Core/GameRecord.swift (68 lines)"
    - "gamekit/gamekit/Core/BestTime.swift (57 lines)"
    - "gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift (48 lines)"
    - "gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift (68 lines)"
  modified: []

key-decisions:
  - "04-01: @Model Date default values use Date() (not .now) — @Model macro substitution rejects .now shorthand at expansion time; semantically identical because Date() == .now == Date.now"
  - "04-01: File-header invariant blocks reword 'no @Attribute(.unique)' as 'no SwiftData unique-attribute decorator' — keeps the literal token from leaking into source greps that ! grep -q for it"
  - "04-01: Wave-0 SC3 smoke test green from day 1 — both .none and .private('iCloud.com.lauterstar.gamekit') constructions pass with isStoredInMemoryOnly: true (Assumption A2 confirmed: CloudKit handshake is skipped when in-memory)"
  - "04-01: New gamekit/gamekit/Core/ + gamekit/gamekitTests/Core/ folders auto-registered by Xcode 16 PBXFileSystemSynchronizedRootGroup with zero project.pbxproj edits — CLAUDE.md §8.8 validated for Phase 4 (extends P1/P2 evidence)"
  - "04-01: Tests use @MainActor struct (NOT P2's nonisolated struct) — ModelContext is not Sendable per RESEARCH Pattern 6; locked as the standard for ALL P4 Core tests"

patterns-established:
  - "Pattern 1: CloudKit-compatible @Model — optional/defaulted properties + no unique decorator + schemaVersion: Int = 1 + Date() (not .now) defaults"
  - "Pattern 2: In-memory ModelContainer test fixture — @MainActor enum factory with cloudKit: parameter; pair isStoredInMemoryOnly: true + .private(...) for CloudKit-constraint validation in CI"
  - "Pattern 3: Forcing-function string lock — load-bearing literal 'iCloud.com.lauterstar.gamekit' embedded in test source so any rename trips a deliberate test failure"
  - "Pattern 4: Wave-0 first — schema + smoke test land before any production wiring, so downstream plans (02-06) consume a green test fixture"

requirements-completed: [PERSIST-01]

# Metrics
duration: 4min
completed: 2026-04-26
---

# Phase 04 Plan 01: Schema Foundation Summary

**CloudKit-compatible SwiftData schema (GameKind, Outcome, GameRecord, BestTime) with `@MainActor` Swift Testing smoke test that validates BOTH `.none` and `.private("iCloud.com.lauterstar.gamekit")` configurations construct without throwing.**

## Performance

- **Duration:** 4 min (248 seconds wall-clock)
- **Started:** 2026-04-26T15:32:06Z
- **Completed:** 2026-04-26T15:36:14Z
- **Tasks:** 2/2
- **Files created:** 6 (4 production + 1 test helper + 1 test file)

## Accomplishments

- Schema foundation landed: `GameKind`, `Outcome`, `GameRecord`, `BestTime` ship in `gamekit/gamekit/Core/` (NEW directory; auto-registered by Xcode 16 with zero `project.pbxproj` edits — CLAUDE.md §8.8 validated for P4).
- All `@Model` types follow CloudKit-compat rules from day 1 (every property optional/defaulted, no SwiftData unique-attribute decorator, all relationships optional, `schemaVersion: Int = 1`) — even though sync stays OFF until P6.
- SC3 smoke test green: 3 `@Test` funcs pass under both `.none` and `.private("iCloud.com.lauterstar.gamekit")` configurations (D-10 dual-config check + D-23 schema-lock check). Total wall-clock <100ms; CloudKit handshake skipped via `isStoredInMemoryOnly: true` (Assumption A2 confirmed in practice).
- Container ID `iCloud.com.lauterstar.gamekit` now load-bearing in test source (D-09 forcing-function lock) — any rename in PROJECT.md, entitlements, or production code that doesn't update the smoke test trips the test on PR.
- Test infrastructure live for Plans 04-02 / 04-03 / 04-04 / 04-05 / 04-06: `try InMemoryStatsContainer.make()` is the canonical fresh-container fixture for the rest of P4.

## Task Commits

Each task was committed atomically:

1. **Task 1: Schema enums + `@Model` classes (Core/)** — `be5da5f` (feat)
2. **Task 2: InMemoryStatsContainer test helper + ModelContainerSmokeTests (SC3)** — `e753eca` (test)

_Plan metadata commit pending after this SUMMARY._

## Files Created/Modified

**Created:**
- `gamekit/gamekit/Core/GameKind.swift` — Foundation-only raw-string enum, sole case `.minesweeper` (D-04). 26 lines.
- `gamekit/gamekit/Core/Outcome.swift` — Foundation-only raw-string enum, cases `.win` and `.loss` (D-04); `.abandoned` reserved via comment. 26 lines.
- `gamekit/gamekit/Core/GameRecord.swift` — `@Model final class` per D-02; 7 fields all optional/defaulted; `schemaVersion: Int = 1`; computed `gameKind` / `outcome` accessors with safe fallbacks. 68 lines.
- `gamekit/gamekit/Core/BestTime.swift` — `@Model final class` per D-03; 6 fields all optional/defaulted; no `recordId` backreference. 57 lines.
- `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` — `@MainActor enum InMemoryStatsContainer.make(cloudKit:)` factory (D-31). 48 lines.
- `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` — Swift Testing `@MainActor @Suite` with 3 `@Test` funcs (D-10 dual-config + schema-lock). 68 lines.

**Modified:** None — pure additive plan.

## Decisions Made

- **Date defaults use `Date()` (not `.now`):** the `@Model` macro expands `defaultValue: .now` into `defaultValue` of inferred type `Any?` and emits `error: type 'Any?' has no member 'now'`. `Date()` is a fully-qualified expression that survives macro substitution. Semantically identical (`Date()` == `.now` == `Date.now`).
- **Comment text rewords "no `@Attribute(.unique)`" as "no SwiftData unique-attribute decorator":** the plan's verify uses `! grep -q "@Attribute(.unique)"` against the file. Documenting the prohibition with the literal token would defeat the negative grep. The reworded form preserves the documentation intent while keeping source greps clean.
- **`@MainActor struct` for the smoke test (NOT `nonisolated struct` from P2):** per RESEARCH Pattern 6 critical correction. `ModelContext` is not `Sendable`; locking this convention now means Plans 04-02 / 04-03 / 04-04 inherit the right scaffold automatically.
- **`Schema.entities.map { $0.name }.sorted() == ["BestTime", "GameRecord"]`** (rather than insertion-order check) — the schema ordering is a SwiftData implementation detail; sorted-name comparison is the stable, intent-preserving assertion. When Sudoku adds its own `@Model` in a future phase, the test fails deliberately and the assertion is updated by hand.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `@Model` macro rejects `Date = .now` default**

- **Found during:** Task 1 (initial `xcodebuild build` after writing the four `Core/` files)
- **Issue:** Build failed with `error: type 'Any?' has no member 'now'` originating in `@__swiftmacro_7gamekit10GameRecord5ModelfMm_.swift` and the matching macro for `BestTime`. The `@Model` macro substitutes the property declaration into a `Schema.PropertyMetadata(... defaultValue: .now ...)` call where the inferred type is `Any?`, and `.now` shorthand cannot resolve against `Any?`.
- **Fix:** Replaced `var playedAt: Date = .now` with `var playedAt: Date = Date()` in `GameRecord.swift` and the same edit for `var achievedAt: Date = .now` in `BestTime.swift`. `Date()` is fully qualified and survives macro substitution. Runtime semantics identical (both evaluate to "now at construction time").
- **Files modified:** `gamekit/gamekit/Core/GameRecord.swift`, `gamekit/gamekit/Core/BestTime.swift`
- **Verification:** `xcodebuild build` succeeded; subsequent `xcodebuild test -only-testing:gamekitTests/ModelContainerSmokeTests` passed all 3 tests (containers construct under both `.none` and `.private(...)`, confirming the `Date()` default is honored by the @Model macro and CloudKit constraint validation).
- **Committed in:** `be5da5f` (Task 1 commit)
- **Why this is a P4-wide constraint, not a one-off:** the `init(... playedAt: Date = .now)` parameter default is fine (regular Swift function default); only the stored-property default at the `@Model` class scope must be `Date()`. Documented in `GameRecord.swift` and `BestTime.swift` headers via the existing "Phase 4 invariants" block (the `Date()` choice is implicit in the source; Plans 04-02/03/04 should preserve it).

**2. [Rule 1 - Bug] Negative grep on `@Attribute(.unique)` was failing on documentation comments**

- **Found during:** Task 1 (running the plan's `<verify>` checklist after Task 1 commit)
- **Issue:** The plan's verify uses `! grep -q "@Attribute(.unique)"` against `GameRecord.swift` and `BestTime.swift`. Both file-header invariant blocks documented "No `@Attribute(.unique)` (RESEARCH Pitfall 2) — …" — the literal token in the comment defeated the negative grep, even though the actual `@Model` class body had no such decorator.
- **Fix:** Rewrote the comment lines as "No SwiftData unique-attribute decorator (RESEARCH Pitfall 2) — …" — preserves the documentation intent (and its citation to Pitfall 2) without leaking the literal token.
- **Files modified:** `gamekit/gamekit/Core/GameRecord.swift`, `gamekit/gamekit/Core/BestTime.swift`
- **Verification:** `! grep -q "@Attribute(.unique)" gamekit/gamekit/Core/GameRecord.swift` and the same for `BestTime.swift` both return success. The full Task 1 verify chain now passes.
- **Committed in:** `be5da5f` (Task 1 commit — folded with the `Date()` fix)

---

**Total deviations:** 2 auto-fixed (2 × Rule 1 bug — both compile/verify-time issues directly caused by this plan's changes).
**Impact on plan:** Both fixes were required for Task 1 to land; both are scoped to files this plan introduces; neither violates any CONTEXT decision. No scope creep.

## Issues Encountered

None beyond the two deviations above.

## Wave-0 Status

Wave-0 of Phase 04 carried 5 required artifacts (per `04-VALIDATION.md`):

| Artifact | Owner | Status |
|---|---|---|
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | Plan 04-01 (this plan) | ✅ Complete |
| `gamekitTests/Core/ModelContainerSmokeTests.swift` | Plan 04-01 (this plan) | ✅ Complete |
| `gamekitTests/Core/GameStatsTests.swift` | Plan 04-02 | ⬜ Pending |
| `gamekitTests/Core/StatsExporterTests.swift` | Plan 04-03 | ⬜ Pending |
| `gamekitTests/Core/StatsAggregationTests.swift` (optional) | Plan 04-05 | ⬜ Pending |

**Plan 04-01 share: 2/2 owned artifacts complete. Phase Wave-0 share: 2/4 required + 0/1 optional.**

## Threat Flags

None — plan introduces zero new trust boundaries beyond the schema declaration itself, which is mitigated by the SC3 smoke test (T-04-01) and the literal-string container-ID lock (T-04-02). No new network surface, no new auth path, no new file I/O, no schema additions at trust boundaries.

## CLAUDE.md compliance check

- **§1 Stack:** Swift 6 + SwiftData (iOS 17+) ✅; offline-only ✅; no ads/coins/accounts ✅.
- **§4 Smallest change:** zero refactoring of existing files; pure additive plan ✅.
- **§5 Tests-in-same-commit:** the SC3 smoke test ships in Task 2's commit (`e753eca`) immediately after the schema lands in Task 1 (`be5da5f`) ✅. (Per the plan structure, schema and tests are in two atomic commits; both ship together as part of one plan execution.)
- **§8.5 File caps:** all 6 new files < 80 lines (largest = `GameRecord.swift` at 68 lines) ✅; well under 500-line hard cap.
- **§8.6 SwiftUI correctness:** N/A — Core models import only `Foundation` + `SwiftData`; no SwiftUI surface.
- **§8.7 No `X 2.swift` dupes:** `git status` clean throughout ✅.
- **§8.8 PBXFileSystemSynchronizedRootGroup:** new `gamekit/gamekit/Core/` and `gamekit/gamekitTests/Core/` folders auto-registered without `project.pbxproj` edits ✅; build green confirms.
- **§8.10 Atomic commits:** 2 atomic commits (`be5da5f` schema; `e753eca` tests) — no bundling of unrelated work ✅.

## Next Phase Readiness

Plans 04-02 / 04-03 / 04-04 / 04-05 / 04-06 can now consume:

- `GameRecord`, `BestTime`, `GameKind`, `Outcome` — production schema types from `Core/`.
- `try InMemoryStatsContainer.make()` — fresh in-memory container fixture for per-test isolation (D-31).
- `try InMemoryStatsContainer.make(cloudKit: .private("iCloud.com.lauterstar.gamekit"))` — CloudKit-compat constraint validation path (any plan touching schema can copy this for a regression check).

No blockers. Plan 04-02 (GameStats wrapper) can start immediately.

## Self-Check: PASSED

Verified via Bash:
- `gamekit/gamekit/Core/GameKind.swift` — FOUND (26 lines)
- `gamekit/gamekit/Core/Outcome.swift` — FOUND (26 lines)
- `gamekit/gamekit/Core/GameRecord.swift` — FOUND (68 lines)
- `gamekit/gamekit/Core/BestTime.swift` — FOUND (57 lines)
- `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` — FOUND (48 lines)
- `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` — FOUND (68 lines)
- Commit `be5da5f` (feat 04-01 schema) — FOUND in `git log`
- Commit `e753eca` (test 04-01 smoke) — FOUND in `git log`
- `xcodebuild build` — green
- `xcodebuild test -only-testing:gamekitTests/ModelContainerSmokeTests` — `** TEST SUCCEEDED **` (3/3 passed)

---
*Phase: 04-stats-persistence*
*Completed: 2026-04-26*
