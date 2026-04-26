---
phase: 04-stats-persistence
plan: 03
subsystem: codec
tags: [swift, swiftdata, json, filedocument, swift-testing, tdd]

# Dependency graph
requires:
  - phase: 04-stats-persistence
    plan: 01
    provides: "@Model GameRecord / @Model BestTime / GameKind / Outcome / InMemoryStatsContainer.make() factory — all consumed by export/import field mapping and the test suite"
  - phase: 02-mines-engines
    provides: "MinesweeperDifficulty.rawValue (easy/medium/hard) — canonical key surfaced as `difficultyRaw` in the JSON envelope (D-05/D-18 round-trip)"
provides:
  - "StatsExportEnvelope — Codable+Sendable+Equatable JSON envelope (D-17, D-18) — single source of truth for export and import; consumed by Plan 05/06 SettingsView wiring"
  - "StatsImportError — LocalizedError+Equatable enum with schemaVersionMismatch / decodeFailed / fileReadFailed cases (D-21); errorDescription via String(localized:) for xcstrings auto-extraction"
  - "StatsExportDocument — FileDocument bridge for SwiftUI `.fileExporter`; UTType.json content types"
  - "StatsExporter — @MainActor enum with export(modelContext:) + importing(_:modelContext:) + defaultExportFilename(now:) (D-16, D-19, D-20); replace-on-import semantics in single transaction; decode-validate-transaction order (RESEARCH Pitfall 6)"
  - "StatsExporterTests — 7 @Test funcs proving SC4 round-trip + RESEARCH Pitfall 6 negative path + RESEARCH Pitfall 7 encoder determinism + D-18 JSON keys + D-19 filename pattern"
affects: [04-04-app-wiring, 04-05-stats-view, 04-06-settings-view]

# Tech tracking
tech-stack:
  added: ["UniformTypeIdentifiers (system framework — first usage in GameKit; UTType.json for FileDocument content types)"]
  patterns:
    - "@MainActor enum codec namespace (no ivar state; matches P2 engine namespace pattern: BoardGenerator/RevealEngine/WinDetector) — locked as standard for stateless write-side services"
    - "Encoder configuration locked: `[.prettyPrinted, .sortedKeys] + .iso8601` — non-negotiable for SC4 byte-for-byte determinism (RESEARCH Pitfall 7)"
    - "Decode-then-validate-then-transaction-then-save order — schemaVersion guard sits BEFORE the destructive `delete(model:)` calls; future-schema files cannot destroy existing data (RESEARCH Pitfall 6)"
    - "UUID + per-row schemaVersion preserved across round-trip via post-init assignment (`rec.id = r.id`; `rec.schemaVersion = r.schemaVersion`) — default `id: UUID = UUID()` would emit fresh UUIDs and break SC4 byte-for-byte equality"
    - "Codec layer Foundation-only — envelope + error files do NOT import the persistence framework; only the StatsExporter (which fetches/inserts) does. SwiftUI imports limited to FileDocument bridge alone."
    - "Plan-level TDD RED -> GREEN gate: failing test commit lands first ('Cannot find type StatsExporter in scope'); production type follows in next commit. Identical pattern to Plan 04-02."

key-files:
  created:
    - "gamekit/gamekit/Core/StatsExportEnvelope.swift (62 lines)"
    - "gamekit/gamekit/Core/StatsImportError.swift (39 lines)"
    - "gamekit/gamekit/Core/StatsExportDocument.swift (48 lines)"
    - "gamekit/gamekit/Core/StatsExporter.swift (178 lines)"
    - "gamekit/gamekitTests/Core/StatsExporterTests.swift (309 lines)"
  modified: []

key-decisions:
  - "04-03: StatsExporter is @MainActor enum (D-16) — no ivar state; matches P2 engine namespace pattern. ModelContext is not Sendable per RESEARCH Pattern 6, so @MainActor isolation is required even for the static surface."
  - "04-03: Codec layer split into 4 files instead of inlining (envelope + error + document + exporter) — each has a single responsibility (serialization mirror / LocalizedError / FileDocument bridge / fetch+encode+save pipeline). Inlining would push StatsExporter.swift toward 250 lines and mix three import lists; CLAUDE.md §8.1 + §8.5 favor splitting by concern."
  - "04-03: Documentation comment lines reworded to avoid leaking the literal `import SwiftData` token at the envelope/error layer — preserves the negative-grep verify gate (mirrors Plan 04-01's `@Attribute(.unique)` reword precedent)."
  - "04-03: roundTripFifty test asserts SEMANTIC byte-equality (gameRecords + bestTimes payloads encoded under the same deterministic encoder) rather than raw Data byte-equality between two export() calls. Rationale: `exportedAt` is generated fresh per export() call via `.now`, so wall-clock ms differences make raw two-export byte-equality structurally impossible; the SC4 / RESEARCH Pitfall 7 intent (records survive round-trip identically) is preserved by encoding the (gameRecords, bestTimes) tuple under `[.prettyPrinted, .sortedKeys] + .iso8601` and asserting Data-equality there. The encoderDeterministic test still proves Pitfall 7 directly on a fixed envelope."
  - "04-03: TDD plan-level RED -> GREEN gate sequence honored — test commit `453e6ee` (RED, build fails: 'Cannot find type StatsExporter in scope') landed BEFORE feat commit `a9384c8` (GREEN, all 7 tests pass). Verifiable in `git log --oneline`."
  - "04-03: UUID and per-row schemaVersion preservation locked as a post-init assignment pattern (`rec.id = r.id; rec.schemaVersion = r.schemaVersion`) — `init(...)` defaults can't be parameterized for these system-managed fields without breaking the GameStats.record(...) call site, so post-init assignment is the simplest path that keeps both call sites clean."
  - "04-03: `defaultExportFilename(now:)` uses `ISO8601DateFormatter().formatOptions = [.withFullDate]` (NOT `DateFormatter` with manual format string) — locale-independent by construction; RESEARCH Assumption A7 honors the same choice."

patterns-established:
  - "Pattern 1: @MainActor enum codec namespace with static methods for stateless services — matches P2 engine namespace; differentiates from @MainActor final class GameStats which carries state"
  - "Pattern 2: Decode -> validate -> transaction -> save ordering for any write path that runs after a parsed input (RESEARCH Pitfall 6) — schemaVersion guard ALWAYS precedes destructive operations"
  - "Pattern 3: Encoder/decoder configuration as a non-negotiable file-level invariant — `[.prettyPrinted, .sortedKeys] + .iso8601` is grepped in CI verify and tested by encoderDeterministic"
  - "Pattern 4: Semantic-payload byte-equality test for round-trip codecs that emit fresh timestamps — decode both ends, sort by stable id, re-encode the (records, bestTimes) tuple under the same encoder, assert Data-equality"
  - "Pattern 5: Plan-level TDD gate transfers to codec layers — RED test commit ('Cannot find type X in scope') lands first; GREEN feat commit follows. Same idiom as Plan 04-02."

requirements-completed: [PERSIST-03]

# Metrics
duration: 10min
completed: 2026-04-26
---

# Phase 04 Plan 03: StatsExporter Codec Summary

**JSON Export/Import surface lands. `@MainActor enum StatsExporter` ships with `export(modelContext:)` + `importing(_:modelContext:)` + `defaultExportFilename(now:)`. Encoder configuration `[.prettyPrinted, .sortedKeys] + .iso8601` enforced for SC4 byte-for-byte determinism. Decode-validate-transaction-save order protects existing data on schema-mismatch (RESEARCH Pitfall 6). 7 Swift Testing `@Test` funcs pass; TDD RED -> GREEN gate sequence honored.**

## Performance

- **Duration:** 10 min (625 seconds wall-clock)
- **Started:** 2026-04-26T15:52:58Z
- **Completed:** 2026-04-26T16:03:23Z
- **Tasks:** 2/2
- **Files created:** 5 (4 production + 1 test file)
- **Test runtime:** StatsExporterTests suite ~6s wall-clock for 7 `@Test` funcs (per-test fresh in-memory container; the 50-row roundTripFifty + dual encode/decode dominates the runtime)

## Accomplishments

- Codec contract surface lands at `gamekit/gamekit/Core/{StatsExportEnvelope,StatsImportError,StatsExportDocument}.swift` — three small, single-purpose files (62/39/48 lines) replacing what could have been a monolithic 250-line `StatsExporter.swift`. CLAUDE.md §8.5 split-by-concern honored.
- `StatsExportEnvelope` declares `Codable + Sendable + Equatable` mirror of `@Model GameRecord` and `@Model BestTime` — JSON keys equal Swift property names per D-18 (`schemaVersion`, `exportedAt`, `gameRecords`, `bestTimes` at top level; `id`, `gameKindRaw`, `difficultyRaw`, `outcomeRaw`, `durationSeconds`, `playedAt`, `schemaVersion` per record; `seconds`, `achievedAt` for BestTime). Renaming any property = data break.
- `StatsImportError` declares `LocalizedError + Equatable` enum with three cases (`schemaVersionMismatch(found:expected:)`, `decodeFailed`, `fileReadFailed`); `errorDescription` uses `String(localized:)` for xcstrings auto-extraction (FOUND-05). Plan 05 SettingsView alert body re-references the same xcstrings keys — single source of truth.
- `StatsExportDocument` declares `FileDocument` with `[.json]` content types and throws `CocoaError(.fileReadCorruptFile)` on missing/empty file blobs. Plan 05 will bind it to `.fileExporter(...)`.
- `StatsExporter.export(modelContext:)` body locked: `fetch GameRecord` → `fetch BestTime` → build envelope (map `@Model` → Codable struct field-by-field) → encoder configured `[.prettyPrinted, .sortedKeys] + .iso8601` → `try encoder.encode(envelope)`. The `.sortedKeys` setting is non-negotiable per RESEARCH Pitfall 7 — without it, key-order randomness across runs would silently fail SC4 in production with no test-side warning.
- `StatsExporter.importing(_:modelContext:)` body locked per D-20 + RESEARCH Pitfall 6: `decode → validate schemaVersion == 1 → transaction { delete(model:) × 2; insert envelope rows } → save()`. The schemaVersion guard sits BEFORE the destructive transaction, so a future-schema envelope CANNOT destroy existing data — proven by `schemaVersionMismatchThrows`.
- UUID + per-row `schemaVersion` preserved across round-trip via post-init assignment (`rec.id = r.id; rec.schemaVersion = r.schemaVersion`) — without this, the default `id: UUID = UUID()` would emit fresh UUIDs and the byte-for-byte SC4 check would fail.
- `defaultExportFilename(now:)` uses `ISO8601DateFormatter().formatOptions = [.withFullDate]` — locale-independent by construction; produces `gamekit-stats-2026-04-25.json` deterministically regardless of user locale (RESEARCH Assumption A7 honored).
- **TDD gate sequence honored:** RED commit `453e6ee` landed first (build fails: `Cannot find type 'StatsExporter' in scope`), GREEN commit `a9384c8` followed with the production type. Verifiable in `git log --oneline`.
- All 7 `@Test` funcs pass on the GREEN gate. Full repo test suite remains green (no regression in P2 engines, P3 ViewModel, P4-01 schema smoke, P4-02 GameStats).

## Task Commits

Each phase of the work was committed atomically (one TDD pair plus the contract-types prelude):

1. **Task 1 — codec contract types (envelope + error + document)** — `30fab72` (feat)
2. **Task 2 RED — failing StatsExporter test suite** — `453e6ee` (test)
3. **Task 2 GREEN — production StatsExporter** — `a9384c8` (feat)

REFACTOR commit not needed — the production code already matches the plan's verbatim shape with no duplication; mandated file-header invariant blocks are load-bearing.

_Plan metadata commit pending after this SUMMARY._

## Files Created/Modified

**Created:**
- `gamekit/gamekit/Core/StatsExportEnvelope.swift` (62 lines) — `Codable + Sendable + Equatable` envelope. 4 top-level fields (`schemaVersion`, `exportedAt`, `gameRecords`, `bestTimes`); 2 nested structs (`Record` with 7 fields per D-18; `Best` with 6 fields per D-18). Foundation-only.
- `gamekit/gamekit/Core/StatsImportError.swift` (39 lines) — `LocalizedError + Equatable` enum; 3 cases; `errorDescription` via `String(localized:)`. Foundation-only.
- `gamekit/gamekit/Core/StatsExportDocument.swift` (48 lines) — `FileDocument`; `[.json]` content types; `CocoaError(.fileReadCorruptFile)` on missing blob. SwiftUI + UniformTypeIdentifiers imports.
- `gamekit/gamekit/Core/StatsExporter.swift` (178 lines) — `@MainActor enum` with three static funcs; encoder pinned `[.prettyPrinted, .sortedKeys] + .iso8601`; decode-validate-transaction-save order. Foundation + SwiftData + os imports — no SwiftUI.
- `gamekit/gamekitTests/Core/StatsExporterTests.swift` (309 lines) — `@MainActor @Suite struct` with 7 `@Test` funcs; per-test `try InMemoryStatsContainer.make()` factory.

**Modified:** None — pure additive plan.

## Test Coverage Map

| `@Test` func | Behavior asserted | Decision / Pitfall ref | T-04-* mitigated |
|---|---|---|---|
| `roundTripFifty` | seed 50 GameRecords + 3 BestTimes → export → wipe → import → re-export → semantic payload byte-equal AND counts match | D-20 + RESEARCH Pitfall 7 | T-04-11 (encoder determinism baseline) |
| `schemaVersionMismatchThrows` | hand-craft `schemaVersion: 99` envelope → `importing(...)` throws `.schemaVersionMismatch(found: 99, expected: 1)` AND existing 1-row store is intact | D-20 + RESEARCH Pitfall 6 | **T-04-10** (forcing function for "schema-mismatch destroys data on wrong order") |
| `replaceOnImport` | seed 5 records + 1 best time → import envelope with 3 different records + 1 best time → final state = exactly 3 records + 1 best time; original "easy" rows wiped | D-20 (replace semantics) | T-04-12 partial (replace correctness) |
| `encoderDeterministic` | encode same envelope twice → byte-equal Data | RESEARCH Pitfall 7 | **T-04-11** (forcing function for "encoder non-determinism breaks SC4") |
| `envelopeKeysMatchSwiftProperties` | encoded JSON contains literal keys `schemaVersion`, `exportedAt`, `gameRecords`, `bestTimes`, `id`, `gameKindRaw`, `difficultyRaw`, `outcomeRaw`, `durationSeconds`, `playedAt` | D-18 | — (cross-version compat regression gate) |
| `decodeFailedThrows` | `Data("not valid json".utf8)` → `importing(...)` throws `.decodeFailed` AND existing rows untouched | D-20 + RESEARCH Pitfall 6 | T-04-10 partial (decode-failure path also leaves data intact) |
| `defaultExportFilenameMatchesPattern` | filename = `gamekit-stats-` + 10-char date + `.json` | D-19 + RESEARCH A7 | — (locale-independence regression gate) |

**Coverage of `04-VALIDATION.md` Per-Requirement Verification Map:** all required StatsExporter tests are covered (round-trip 50, schema-mismatch, replace-on-import, encoder determinism, JSON-keys, decode-failed, defaultExportFilename = 7 vs the planned 5–7).

## Decisions Made

- **`@MainActor enum` (not `final class`):** `StatsExporter` carries no ivar state — the only shared symbol is the static `envelopeSchemaVersion` constant and a `Logger`. `enum` is the correct shape for a pure namespace. `@MainActor` annotation is still required because `ModelContext` is not `Sendable` (RESEARCH Pattern 6) and the static methods accept it as a parameter.
- **4-file split for the codec layer:** envelope (serialization mirror) + error (LocalizedError) + document (SwiftUI FileDocument bridge) + exporter (fetch + encode + save pipeline) each have a single responsibility. Inlining would push `StatsExporter.swift` over 250 lines and force a `SwiftUI` import for the FileDocument; CLAUDE.md §8.5 split-by-concern keeps the codec namespace Foundation/SwiftData-only.
- **Comment reword to preserve negative-grep gate:** the plan's verify uses `! grep -q "import SwiftData"` against the envelope and error files. My initial header comments contained the literal phrase "NO `import SwiftData`" / "the @Model types are the SwiftData side". Rewrote to "the codec layer stays Foundation-only" / "the persistence side" — preserves the documentation intent without leaking the literal token. Same precedent as Plan 04-01's `@Attribute(.unique)` reword.
- **Semantic-payload byte-equality for `roundTripFifty`:** the plan as drafted asserted `exported == reExported` where both are raw `Data` from separate `export()` calls. `exportedAt = .now` makes raw byte-equality structurally impossible across two `export()` invocations (wall-clock ms differs). The SC4 / RESEARCH Pitfall 7 intent ("byte-for-byte round-trip") is properly captured by:
  1. `encoderDeterministic` — proves encoder produces identical bytes for identical envelopes (the actual Pitfall 7 contract)
  2. `roundTripFifty` payload check — decode both exports, sort by id, re-encode the `(gameRecords, bestTimes)` payload tuple under the same deterministic encoder, assert `Data` equality. This proves all record fields survive the round-trip identically.
- **UUID + per-row schemaVersion preservation as post-init assignment:** the `GameRecord.init(...)` and `BestTime.init(...)` parameter lists don't include `id` or `schemaVersion` (those are system-managed defaults: `id: UUID = UUID()`, `schemaVersion: Int = 1`). Adding them as init params would clutter the GameStats.record(...) call site. Post-init assignment (`rec.id = r.id; rec.schemaVersion = r.schemaVersion`) is the simplest path; the `@Model` macro permits direct property writes since they are `var`.
- **`Logger.error(...)` interpolation uses `privacy: .public`:** decode-failure messages are non-PII (JSONDecoder error names like "dataCorrupted at gameRecords[3].playedAt"). Without explicit `privacy: .public`, OSLog redacts string interpolations as `<private>`. Same standard locked in Plan 04-02 GameStats.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `import SwiftData` literal in StatsExportEnvelope/StatsImportError comments defeated the negative-grep verify gate**

- **Found during:** Task 1 verify (after writing the three contract type files).
- **Issue:** The plan's verify uses `! grep -q "import SwiftData" gamekit/gamekit/Core/StatsExportEnvelope.swift` (and same for the error file). My initial file-header comment blocks contained the literal phrases `NO 'import SwiftData'` and `Foundation-only — NO SwiftUI / SwiftData imports at the error layer`. The literal `import SwiftData` token in those comments tripped the negative grep even though no actual `import SwiftData` directive existed in the source.
- **Fix:** Rewrote the comments to "codec layer stays Foundation-only" / "the persistence side" / "no persistence-framework imports at the error layer" — preserves the documentation intent without leaking the literal token.
- **Files modified:** `gamekit/gamekit/Core/StatsExportEnvelope.swift`, `gamekit/gamekit/Core/StatsImportError.swift`
- **Verification:** `! grep -q "import SwiftData"` against both files now returns success; full Task 1 verify chain passes.
- **Committed in:** `30fab72` (Task 1 commit — folded with the original write-out).
- **Why this is a P4-wide pattern (now twice-validated):** Plan 04-01 hit the same issue with `! grep -q "@Attribute(.unique)"` and resolved it identically. Documentation comments must not leak the literal token of any negative-grep verify gate. Future P4 plans should pre-emptively apply this when introducing new files.

**2. [Rule 1 - Bug] `roundTripFifty` raw-Data byte-equality assertion was structurally impossible**

- **Found during:** Task 2 GREEN gate (full StatsExporterTests run after writing production StatsExporter).
- **Issue:** Initial GREEN run reported 6/7 tests passing; `roundTripFifty` failed on the final `#expect(exported == reExported)` assertion. The test's intent (proving SC4's "byte-for-byte" round-trip) cannot be expressed as raw-`Data` equality across two separate `export()` calls because `StatsExportEnvelope.exportedAt` is generated fresh from `.now` per export — wall-clock millisecond differences between the two `export()` calls produce different ISO8601 strings → different bytes. Running the test in isolation passed by coincidence (both calls landed in the same ms); running with sibling tests (which add overhead between the two calls) failed.
- **Fix:** Replaced the raw-Data comparison with a semantic-payload comparison: decode both envelopes, sort their `gameRecords` + `bestTimes` arrays by stable UUID id, re-encode the `(gameRecords, bestTimes)` tuple under the same `[.prettyPrinted, .sortedKeys] + .iso8601` encoder, and assert that `Data` is byte-equal. This proves all record/best-time field values survive the round-trip identically — the actual SC4 intent. The `encoderDeterministic` test (which DID pass) already proves RESEARCH Pitfall 7 (the encoder is deterministic for a fixed envelope).
- **Files modified:** `gamekit/gamekitTests/Core/StatsExporterTests.swift` (replaced 1-line comparison with a 30-line semantic-payload comparison block).
- **Verification:** all 7 tests pass on the GREEN gate; full repo test suite remains green.
- **Committed in:** `a9384c8` (Task 2 GREEN feat commit — folded with the production StatsExporter so the test suite ships green together).
- **Plan compliance note:** the plan's behavior spec for `roundTripFifty` (line 361 of `04-03-PLAN.md`) literally asserts `data == data2` (byte-for-byte). The plan is structurally incorrect — `data2` here is the **second** export's Data, which can never equal the first export's Data due to `exportedAt`. The intent ("byte-for-byte round-trip including schemaVersion") is fully preserved by my fix and is, in fact, more rigorous: comparing all record field values byte-for-byte is what SC4 actually wants. This is a Rule 1 fix, not a deviation from intent.

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs — both verify-time issues directly caused by this plan's changes; one was a planning artifact in the test spec itself, the other a comment-text leakage).
**Impact on plan:** Both fixes were required for verify gates to pass; both are scoped to files this plan introduces; neither violates any CONTEXT decision (D-16/17/18/19/20/21 are all honored). No scope creep.

## Issues Encountered

None beyond the two deviations above. No fix-attempt-limit thresholds approached (each deviation took one fix to resolve).

## Wave-0 Status Update

Wave-0 of Phase 04 carries 5 required artifacts (per `04-VALIDATION.md`):

| Artifact | Owner | Status |
|---|---|---|
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | Plan 04-01 | Complete (2026-04-26) |
| `gamekitTests/Core/ModelContainerSmokeTests.swift` | Plan 04-01 | Complete (2026-04-26) |
| `gamekitTests/Core/GameStatsTests.swift` | Plan 04-02 | Complete (2026-04-26) |
| `gamekitTests/Core/StatsExporterTests.swift` | **Plan 04-03 (this plan)** | **Complete (2026-04-26)** |
| `gamekitTests/Core/StatsAggregationTests.swift` (optional) | Plan 04-05 | Pending |

**Plan 04-03 share: 1/1 owned artifact complete. Phase Wave-0 share: 4/4 required + 0/1 optional.**

**Wave-0 of Phase 04 is now COMPLETE.** All required test artifacts ship before any production wiring (App scene + StatsView + SettingsView) lands in Plans 04-04 / 04-05 / 04-06. The codec layer, write-side boundary, and schema foundation all have green test coverage; downstream plans can author against the locked APIs without risk of cascading fixes back into Wave-0 files.

## TDD Gate Compliance

Plan-level TDD gate sequence verified per `<tdd_execution>` Plan-Level TDD Gate Enforcement:

| Gate | Commit | Verification |
|---|---|---|
| RED | `453e6ee` (test) | Build error confirmed: `Cannot find type 'StatsExporter' in scope` (7 occurrences) — test suite fails to compile by design |
| GREEN | `a9384c8` (feat) | All 7 `@Test` funcs pass on the GREEN gate; full repo suite green (no regression) |
| REFACTOR | — | Not needed — code matches the plan's verbatim shape; no duplication; comments are load-bearing per file-header mandate |

`git log --oneline` confirms RED commit precedes GREEN commit. Both are authored by this plan execution.

Note: the contract-types commit `30fab72` (envelope + error + document) precedes both RED and GREEN. This is the canonical pattern for plan-level TDD when production scaffolding (types referenced by the test suite) must exist for the test suite to compile against THE NEW TYPE under test (`StatsExporter`). The contract types alone don't trip the RED gate because the failing test references `StatsExporter`, not `StatsExportEnvelope`. Same pattern as Plan 04-02's GameStats: `GameRecord` / `BestTime` already existed when the GameStatsTests RED commit landed.

## Threat Flags

None — plan introduces zero new trust boundaries beyond the codec layer that the threat model already enumerates. The plan's `<threat_model>` mitigations are honored end-to-end:

- **T-04-10 (Tampering — schema-mismatch destroys data on wrong order):** mitigated by `schemaVersionMismatchThrows` (proves the schemaVersion guard sits BEFORE the destructive transaction; existing data UNTOUCHED on a future-schema envelope) and by `decodeFailedThrows` (proves decode failures also leave existing data intact). The decode→validate→transaction→save order is a structural property of the implementation (visible in `StatsExporter.importing` body).
- **T-04-11 (Tampering — encoder non-determinism breaks SC4 byte-equality):** mitigated by `encoderDeterministic` (two encodes of the same envelope → byte-equal Data) and by the `.sortedKeys` literal grep gate. Absence of `.sortedKeys` would silently fail SC4 in production.
- **T-04-12, T-04-13, T-04-14, T-04-15:** accepted dispositions unchanged (informational stats; user-initiated; in-memory decode is correct for v1; logger emits non-PII error names only). No new mitigations required.

## CLAUDE.md compliance check

- **§1 Stack:** Swift 6 + SwiftData (iOS 17+) ✅; offline-only ✅; no ads/coins/accounts ✅; `os.Logger` is local-only.
- **§4 Smallest change:** zero refactoring of existing files; pure additive plan ✅. Reuses the `@MainActor` + namespace-enum pattern already established by P2 engines (BoardGenerator/RevealEngine/WinDetector) and the `Foundation + SwiftData + os` import set established by GameStats.
- **§5 Tests-in-same-commit (or same-plan for TDD):** RED test commit `453e6ee` and GREEN feat commit `a9384c8` ship in the same plan execution. Test-first sequence honored.
- **§8.5 File caps:** envelope 62, error 39, document 48, exporter 178, tests 309 — all well under 500-line hard cap; all under their planned per-file caps (90/50/60/200/350).
- **§8.6 SwiftUI correctness:** `StatsExportDocument` uses `FileDocument` correctly; `readableContentTypes`/`writableContentTypes` static surface matches Apple's idiomatic shape. No `.foregroundColor` / `.foregroundStyle` decisions in this plan (no view layer).
- **§8.7 No `X 2.swift` dupes:** `git status` clean throughout ✅.
- **§8.8 PBXFileSystemSynchronizedRootGroup:** new files dropped into existing `gamekit/gamekit/Core/` and `gamekit/gamekitTests/Core/` directories — auto-registered by Xcode 16. Zero `project.pbxproj` edits ✅; build green confirms.
- **§8.10 Atomic commits:** 3 atomic commits (Task 1 contract types `30fab72`; Task 2 RED `453e6ee`; Task 2 GREEN `a9384c8`) — no bundling of unrelated work ✅.

## Critical Path Notes for Plan 05

Plan 05 (StatsView + SettingsView Export/Import wiring) consumes:

- **`StatsExporter.export(modelContext:)` and `StatsExporter.importing(_:modelContext:)`:** call sites must wrap in `do/catch StatsImportError` to surface the schema-mismatch / decodeFailed alert flows per UI-SPEC §Copywriting Contract. The error's `errorDescription` already pulls the localized alert body via `String(localized:)` — no manual string mapping required at the call site.
- **`StatsExporter.defaultExportFilename(now: .now)`:** pass to `.fileExporter(defaultFilename:)` — locale-independent ISO8601 date.
- **`StatsExportDocument(data: encoded)`:** the SwiftUI `.fileExporter(...)` modifier expects this `FileDocument` — bind via `isPresented:document:contentType:defaultFilename:onCompletion:`.
- **Reset Stats alert flow** (Plan 04-06): wires `try gameStats.resetAll()` (already shipped in 04-02) inside the `.alert(role: .destructive)` confirmation. No StatsExporter coupling.

## Next Phase Readiness

Plans 04-04 / 04-05 / 04-06 can now consume the full P4 codec + write-side stack:

- **`GameStats` instance (production)** — Plan 04-04 will construct `GameStats(modelContext:)` from `@Environment(\.modelContext)` at the App scene root.
- **`try gameStats.record(...)` write path** — Plan 04-05 will call this from `MinesweeperViewModel.recordTerminalState(outcome:)`.
- **`try gameStats.resetAll()`** — Plan 04-06 will call this from a `.alert(role: .destructive)` confirmation.
- **`StatsExporter.export(modelContext:)` and `StatsExporter.importing(_:modelContext:)`** — Plan 04-06 will wire to `.fileExporter(...)` and `.fileImporter(...)` SettingsView rows; do/catch on `StatsImportError` for alert flows.
- **`StatsExporter.defaultExportFilename(now:)`** — Plan 04-06 will pass to `.fileExporter(defaultFilename:)`.
- **`StatsExportDocument`** — Plan 04-06 will instantiate as `StatsExportDocument(data: try StatsExporter.export(modelContext: ctx))` and bind to the fileExporter modifier.

No blockers. Plan 04-04 (App scene wiring — shared `ModelContainer` + `SettingsStore` + `GameStats` injection) can start immediately.

## Self-Check: PASSED

Verified via Bash:
- `gamekit/gamekit/Core/StatsExportEnvelope.swift` — FOUND (62 lines)
- `gamekit/gamekit/Core/StatsImportError.swift` — FOUND (39 lines)
- `gamekit/gamekit/Core/StatsExportDocument.swift` — FOUND (48 lines)
- `gamekit/gamekit/Core/StatsExporter.swift` — FOUND (178 lines)
- `gamekit/gamekitTests/Core/StatsExporterTests.swift` — FOUND (309 lines)
- Commit `30fab72` (feat 04-03 contract types) — FOUND in `git log --oneline`
- Commit `453e6ee` (test 04-03 RED) — FOUND in `git log --oneline`
- Commit `a9384c8` (feat 04-03 GREEN) — FOUND in `git log --oneline`
- Plan automated verify chain — all 14 grep/test gates pass
- `xcodebuild test -only-testing:gamekitTests/StatsExporterTests` — `** TEST SUCCEEDED **` (7/7 passed)
- Full repo suite `xcodebuild test` — `** TEST SUCCEEDED **` (no regression in any prior test target)
- TDD gate sequence: RED `453e6ee` precedes GREEN `a9384c8` in `git log --oneline` ✅

---
*Phase: 04-stats-persistence*
*Completed: 2026-04-26*
