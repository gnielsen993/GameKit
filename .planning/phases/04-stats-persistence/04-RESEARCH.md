# Phase 4: Stats & Persistence - Research

**Researched:** 2026-04-25
**Domain:** SwiftData (iOS 17+) with CloudKit-compatible schema, JSON Export/Import, single shared `ModelContainer`, @Observable settings store
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Schema (PERSIST-01)**
- **D-01:** Two `@Model` classes ship in `Core/`: `GameRecord` (per win/loss event) and `BestTime` (one row per `(gameKind, difficulty)`). Both **CloudKit-compatible from day 1**: every property optional or defaulted, no `@Attribute(.unique)`, every relationship optional (none in V1), `schemaVersion: Int = 1` on both.
- **D-02:** `GameRecord` shape: `id: UUID = UUID()`, `gameKindRaw: String = GameKind.minesweeper.rawValue`, `difficultyRaw: String = ""`, `outcomeRaw: String = ""`, `durationSeconds: Double = 0`, `playedAt: Date = .now`, `schemaVersion: Int = 1`. Computed `gameKind: GameKind` and `outcome: Outcome` accessors with safe fallbacks.
- **D-03:** `BestTime` shape: `id: UUID = UUID()`, `gameKindRaw: String`, `difficultyRaw: String = ""`, `seconds: Double = 0`, `achievedAt: Date = .now`, `schemaVersion: Int = 1`. **No `recordId` backreference** (kept minimal).
- **D-04:** `enum GameKind: String { case minesweeper }` and `enum Outcome: String { case win, loss }` ship in `Core/`. `Outcome.abandoned` deferred — additive when needed.
- **D-05:** `MinesweeperDifficulty.rawValue` (locked P2 D-02 = `"easy" | "medium" | "hard"`) is the **canonical serialization key** for `difficultyRaw`. Renaming = data break.
- **D-06:** No `@Attribute(.unique)`. Both models use `id: UUID = UUID()` for identity; CloudKit collision resolution is P6.

**ModelContainer + CloudKit feature flag (PERSIST-01, SC3)**
- **D-07:** Single shared `ModelContainer` constructed in `GameKitApp` with schema `[GameRecord.self, BestTime.self]` and a single `ModelConfiguration`. Injected app-wide via `.modelContainer(sharedContainer)`.
- **D-08:** `ModelConfiguration` reads `cloudSyncEnabled: Bool` from `SettingsStore` at startup; `cloudKitDatabase: cloudSyncEnabled ? .private("iCloud.com.lauterstar.gamekit") : .none`. P4 default `false`; `.private(...)` branch never executes in production yet.
- **D-09:** **CloudKit container ID locked: `iCloud.com.lauterstar.gamekit`** (matches PROJECT.md and bundle ID `com.lauterstar.gamekit`).
- **D-10:** SC3 smoke test constructs **both** configurations (`.none` and `.private("iCloud.com.lauterstar.gamekit")`) successfully. Catches schema constraint violations at PR time.

**GameStats wrapper (PERSIST-02 + SC1)**
- **D-11:** `Core/GameStats.swift` is the **single write-side boundary**. API: `init(modelContext: ModelContext)`, `record(gameKind:difficulty:outcome:durationSeconds:) throws`, `resetAll() throws`. Both methods call `try modelContext.save()` internally.
- **D-12:** `record(...)` insertion: insert `GameRecord`; if `outcome == .win`, look up `BestTime` by `(gameKindRaw, difficultyRaw)`; insert/update if better; `try modelContext.save()`. Loss → no `BestTime` write.
- **D-13:** `resetAll()` deletes both `GameRecord` and `BestTime` rows in a single `modelContext.transaction { ... }` block, then `save()`. Atomic.
- **D-14:** `GameStats` is **injected** into `MinesweeperViewModel` via init: `init(..., gameStats: GameStats? = nil)`. Tests pass `nil`; production passes live `GameStats`. **VM does NOT import SwiftData** — `GameStats` is the boundary.
- **D-15:** VM call site: a private `recordTerminalState()` helper invoked from terminal-state transitions. Wraps `try? gameStats?.record(...)`; failure logged via `os_log`; UI continues to render the terminal state.

**StatsExporter (PERSIST-03 + SC4)**
- **D-16:** Export/Import logic in `Core/StatsExporter.swift`. API: `static func export(modelContext:) throws -> Data`, `static func importing(_ data: Data, modelContext:) throws`. `enum`-namespace static methods.
- **D-17:** **Envelope shape:** single JSON object `{ schemaVersion, exportedAt, gameRecords[], bestTimes[] }`. `Codable` struct `StatsExportEnvelope` lives in `Core/StatsExportEnvelope.swift`.
- **D-18:** Arrays serialize raw fields directly (JSON keys = Swift property names). `Date` ISO8601, `UUID` lowercased canonical. Encoder uses `.iso8601` date strategy and `.prettyPrinted`.
- **D-19:** **Filename: `gamekit-stats-YYYY-MM-DD.json`**. UTI `public.json`; `fileExporter` `contentTypes: [.json]`.
- **D-20:** **Import collision = REPLACE.** Single `modelContext.transaction { ... }`: validate `schemaVersion == 1` (else throw `StatsImportError.schemaVersionMismatch`); delete all `GameRecord` + `BestTime`; decode + insert envelope rows; `save()`.
- **D-21:** Schema-mismatch alert: title `"Couldn't import stats"`, body `"This file was exported from a newer GameKit. Update the app and try again."`, single OK button. Existing data stays intact (transaction abort).

**Reset Stats UX**
- **D-22:** Settings → "Reset stats" → `.alert("Reset all stats?", role: .destructive)` with Cancel + Reset all stats buttons → `GameStats.resetAll()`.
- **D-23:** Alert body: `"This deletes all your Minesweeper games and best times. This can't be undone."` No "Export first?" nudge.

**Stats screen (SC2 + SHELL-03)**
- **D-24:** `StatsView` reads via `@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" }, sort: \.playedAt, order: .reverse)` and a sibling `@Query` for `BestTime`. View derives per-difficulty rows in pure-SwiftUI computed properties — no separate StatsViewModel.
- **D-25:** Per-difficulty layout: 4 columns — games · wins · win % · best time. One row per difficulty case **always rendered**. `"—"` em-dash for missing best time, `0` for counts.
- **D-26:** **Empty state:** when `minesRecords.isEmpty`, replace the table with `"No games played yet."` (matches SC2 verbatim).
- **D-27:** Win % display: integer percent no decimals (`Int(round(wins * 100.0 / games))`). Falls back to `"—"` when `games == 0`.

**SettingsStore (P4 surface)**
- **D-28:** `Core/SettingsStore.swift` ships as `@Observable final class` over `UserDefaults.standard`. P4 exposes one flag: `cloudSyncEnabled: Bool` (key `gamekit.cloudSyncEnabled`, default `false`). Future flags (haptics, SFX, hasSeenIntro) ship in P5.
- **D-29:** Constructed at app startup in `GameKitApp` and injected via `.environment(\.settingsStore, settingsStore)` (custom `EnvironmentKey`). `cloudSyncEnabled` read **once at container construction**; flipping later requires app relaunch.

**Test depth**
- **D-30:** Test framework = Swift Testing. New files: `gamekitTests/Core/GameStatsTests.swift` (~8 tests), `StatsExporterTests.swift` (~6 tests), `ModelContainerSmokeTests.swift` (~3 tests).
- **D-31:** Tests use **in-memory `ModelContainer`**: `ModelConfiguration(schema:, isStoredInMemoryOnly: true)`, helper at `Helpers/InMemoryStatsContainer.swift`. CloudKit smoke test combines `cloudKitDatabase: .private(...)` with `isStoredInMemoryOnly: true` so iCloud is never contacted in CI.

### Claude's Discretion

- **Exact `@Query` predicate syntax** — `#Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" }` per arch; planner may use `KeyPath`-based descriptors if SwiftData docs prefer.
- **StatsView visual layout** — DKCard with table grid vs `Grid` layout vs aligned `HStack` rows. UI-SPEC contract owns this (locked: SwiftUI `Grid`).
- **Whether `cloudSyncEnabled` is mutable in P4 Settings** — recommend NO surface in P4; the toggle UX requires the sign-in card; deferred to P6.
- **`Outcome.abandoned` reservation** — recommend ship `case win, loss` only; document in code comment.
- **`fileExporter` / `fileImporter` modal vs sheet UX** — both are standard iOS document pickers; recommend `fileExporter` from a Settings button tap with `defaultFilename: "gamekit-stats-\(ISO8601 date).json"`.
- **Loss + best-time interaction at write time** — recommend wrap BestTime write in `do/catch` inside `record(...)` so a flaky predicate doesn't block GameRecord persistence.
- **SchemaVersion bump policy** — P4 ships v1 only. Adding properties later (additive) doesn't require a bump. A bump is only needed when removing or renaming.
- **Where `GameStats` is constructed** — recommend lazy in `MinesweeperGameView` body using `@Environment(\.modelContext)`. Single place, no singleton.
- **Export timestamp timezone** — recommend ISO8601 in UTC (`Z` suffix) for cross-device portability.

### Deferred Ideas (OUT OF SCOPE)

- **`recordId: UUID?` backreference on BestTime** — defer until polish phase wants "Best: 1:42 (set 2026-04-25)".
- **Per-difficulty empty state copy** ("No Hard games yet") — defer; single global empty state is enough.
- **Reset alert "Export first?" nudge** — skipped for simpler 2-button alert.
- **`Outcome.abandoned`** — reserved enum case for future phase.
- **Sign in with Apple sign-in card** — P6 (PERSIST-04/05/06).
- **CloudKit sync turned ON by default** — P6.
- **Anonymous→signed-in data promotion** — P6.
- **Schema migration plan (`SchemaMigrationPlan`)** — P4 ships V1 only.
- **Streaming JSON Lines export format** — replace-on-import single envelope is simpler.
- **Import collision merge-by-id mode** — defer to P6 alongside CloudKit.
- **Error toast after successful Export** — defer to P5.
- **Reset Stats undo (5-second snackbar)** — defer; alert is sufficient.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **PERSIST-01** | Stats backed by SwiftData with CloudKit-compatible schema from day 1 (all properties optional or defaulted, no `@Attribute(.unique)`, all relationships optional, `schemaVersion: Int = 1`) | §SwiftData CloudKit constraint rules + SC3 smoke test pattern (Pattern 1, Pitfall 1, Code Examples 1+2) |
| **PERSIST-02** | Stats survive app force-quit, crash, and device reboot — explicit `try modelContext.save()` on terminal-state detection | §`GameStats.record(...)` synchronous-save pattern (Pattern 2, Code Examples 3) |
| **PERSIST-03** | Export/Import JSON of stats with `schemaVersion`; round-trips cleanly via `fileExporter`/`fileImporter` | §`fileExporter` + `FileDocument` pattern, `JSONEncoder` determinism (Pattern 3, Code Examples 4+5) |
| **SHELL-03** | Stats screen shows per-difficulty: games played · wins · win % · best time | §`@Query` + `#Predicate` pattern (Pattern 4, Code Examples 6) |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Directive | Source | P4 Application |
|-----------|--------|----------------|
| **Swift 6 + SwiftUI + SwiftData persistence** | §1 Stack | All P4 code lands in this stack |
| **iOS 17+** | §1 | `@Query`, `@Observable`, `.modelContainer(...)`, `fileExporter` are all iOS 17 APIs |
| **Offline-only — no backend, no cloud, no analytics** | §1 | P4 ships local-only; CloudKit-compat **schema** without active sync |
| **No hard-coded colors / radii / spacing** | §1 + §2 | P4 surfaces (StatsView/SettingsView) read DesignKit tokens only |
| **Lightweight MVVM** | §1 | StatsView reads `@Query` directly per CLAUDE.md §8.2 (no separate StatsViewModel); GameStats is a thin write-side wrapper |
| **Export/Import JSON with `schemaVersion`** | §1 Data safety | Required; `StatsExportEnvelope.schemaVersion: Int = 1` is the gate |
| **Schema changes additive when possible** | §1 Data safety | P4 ships V1 only; adding properties to V2 stays additive |
| **Never delete user data automatically** | §1 Data safety | `resetAll()` only fires from explicit `.alert(role: .destructive)` confirmation (D-22) |
| **Avoid bundle ID changes** | §1 + Pitfall 11 | Bundle locked `com.lauterstar.gamekit`; container ID `iCloud.com.lauterstar.gamekit` pinned in D-09 |
| **Tokens read via `theme.{spacing,colors,typography,radii}`** | §2 | All padding/colors/radii in StatsView/SettingsView edits |
| **Reuse existing patterns; smallest change** | §4 | Reuse `settingsSectionHeader`, `DKCard`, P3 `monoNumber + .monospacedDigit()` pattern |
| **Game engines pure / testable, no SwiftData imports** | §4 | `MinesweeperViewModel` does NOT `import SwiftData` (D-14); `GameStats` is the boundary |
| **Tests in same commit as new pure services** | §5 | GameStatsTests + StatsExporterTests + ModelContainerSmokeTests ship with their production files |
| **Verify Export/Import round-trip** | §5 | SC4 byte-for-byte round-trip is a Wave 0 test |
| **<400-line views; <500-line Swift files (hard cap)** | §8.1, §8.5 | StatsView <300, SettingsView <250, GameStats ~80, StatsExporter ~120 |
| **Reusable views are data-driven, not data-fetching** | §8.2 | StatsView owns the `@Query`; `MinesStatsCard` and `MinesDifficultyStatsRow` take props |
| **Every data-driven view ships with explicit empty state** | §8.3 | "No games played yet." (D-26) — copy-locked before card ships |
| **Theme tokens must exist before use** | §8.4 | All tokens consumed in P4 are pre-existing (verified in UI-SPEC) |
| **`.foregroundStyle` not `.foregroundColor` (iOS 17+)** | §8.6 | Already established in P1/P3; carries forward |
| **No Finder-dupe `X 2.swift` files; no manual pbxproj edits** | §8.7, §8.8 | New `Core/*.swift` files auto-register via Xcode 16 synchronized root group (P2/P3 already validated) |
| **Test-runner crash → uninstall stale sim before debugging** | §8.9 | P4 introduces V1 schema fresh; if crashes happen, uninstall first per CLAUDE.md ritual |
| **Atomic commits — one feature per commit** | §8.10 | P4 ships in plan-by-plan commits (schema → GameStats → StatsView → StatsExporter → SettingsView wiring) |
| **No `Color(...)` literals in `Games/` or `Screens/` (FOUND-07 hook)** | §1 | StatsView + SettingsView edits use `theme.colors.{...}` only |

## Summary

P4 is the **first SwiftData phase** of GameKit. The hard part is not the SwiftData APIs themselves — those are well-documented since iOS 17 and Apple-canonical — but the **CloudKit-compatibility constraints that ship in V1 even though sync is OFF** (D-08). Every constraint violation (`@Attribute(.unique)`, non-optional non-defaulted property, required relationship) compiles fine and only crashes the moment `cloudKitDatabase: .private(...)` runs against the schema. The SC3 smoke test (D-10) is the load-bearing protection: by constructing **both** configurations in CI from day 1, schema drift is caught at PR time, not in P6 when sync turns on.

Three subsystems land:

1. **Schema layer** (`Core/GameRecord.swift`, `BestTime.swift`, `GameKind.swift`, `Outcome.swift`) — all-optional/defaulted CloudKit-safe `@Model` classes; `MinesweeperDifficulty.rawValue` is the canonical serialization key.
2. **Write boundary** (`Core/GameStats.swift`) — `MinesweeperViewModel` injection target. Synchronous `try modelContext.save()` per terminal state (SC1's literal mandate). VM stays Foundation-only — `GameStats` is the firewall.
3. **Export/Import** (`Core/StatsExporter.swift` + `StatsExportEnvelope.swift`) — single JSON envelope with `schemaVersion` gate; `fileExporter`/`fileImporter` system pickers; replace-on-import via `modelContext.transaction { ... }`.

Plus surface wiring: `GameKitApp` constructs the shared `ModelContainer` and `SettingsStore`; `StatsView` adopts dual `@Query`s and renders the per-difficulty grid; `SettingsView` adds a "DATA" section with Export/Import/Reset rows and three modal flows.

**Primary recommendation:** Ship Wave 0 (in-memory test container helper + 3 test files) FIRST, then implement schema, then `GameStats`, then `StatsExporter`, then UI wiring. SC3's smoke test is a Wave-0 file because it must catch schema regressions on the first commit that adds `@Model` classes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `GameRecord` + `BestTime` `@Model` definition | **Persistence (Core/)** | — | Pure schema; Foundation + SwiftData only; never imported by Games/ |
| `ModelContainer` construction | **App (App/GameKitApp.swift)** | — | Single seam per ARCHITECTURE.md (§Pattern 5); read once at startup |
| `SettingsStore` (UserDefaults + cloudSyncEnabled flag) | **Persistence (Core/)** | — | UserDefaults shape per CLAUDE.md §1 — tiny key-value, no SwiftData |
| Terminal-state stats write | **ViewModel → GameStats (Core/)** | — | VM detects terminal state; GameStats owns the SwiftData write. VM does not `import SwiftData`. |
| `BestTime` only-on-win-and-faster lookup | **GameStats (Core/)** | — | One-place rule; `record(...)` is the single decision point |
| StatsView read path | **View (Screens/) via `@Query`** | — | Per ARCHITECTURE Anti-Pattern 4 — view owns query, child cards take props |
| Export JSON encoding | **Persistence (Core/StatsExporter.swift)** | — | Encoder pinned (`.iso8601` + `.prettyPrinted`); deterministic for byte-for-byte round-trip (SC4) |
| Import JSON decoding + replace | **Persistence (Core/StatsExporter.swift)** | View (Screens/SettingsView.swift) for picker chrome only | Transaction-bounded replace; settings owns the file picker presentation |
| `fileExporter` / `fileImporter` modal presentation | **View (Screens/SettingsView.swift)** | — | iOS-native chrome; `.json` UTType; `defaultFilename: "gamekit-stats-YYYY-MM-DD.json"` |
| Reset confirmation alert | **View (Screens/SettingsView.swift)** | GameStats (Core/) for the actual `resetAll()` call | View owns the consent gate; GameStats owns the atomic delete transaction |
| Schema-version gate on import | **Persistence (Core/StatsExporter.swift)** | View for surfacing the error alert | `schemaVersion != 1` throws `StatsImportError.schemaVersionMismatch`; View renders the alert |
| Wong-safe color audit (THEME-01) | (P3 already shipped; P4 inherits) | — | StatsView surfaces are non-game; `gameNumber` palette unused — only `surface/textPrimary/danger` consumed |
| `os_log` non-fatal failure logging | **GameStats / StatsExporter** | — | iOS 17 idiomatic `Logger` from `os` module; subsystem `com.lauterstar.gamekit`, category `persistence` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 17+ (bundled) | `@Model`, `@Query`, `ModelContainer`, `ModelContext` | `[CITED: developer.apple.com/documentation/swiftdata]` — Apple-canonical; CloudKit-compat path is built-in via `ModelConfiguration.cloudKitDatabase` |
| Foundation | bundled | `UUID`, `Date`, `JSONEncoder`/`JSONDecoder`, `UserDefaults`, `os.Logger` | `[VERIFIED: codebase already imports]` |
| SwiftUI | iOS 17+ | `@Query`, `.modelContainer(...)`, `fileExporter`, `fileImporter`, `.alert(role:)`, `Grid` | `[CITED: developer.apple.com/documentation/swiftui/view/fileexporter]` — declarative file pickers iOS 17+ |
| Observation | Swift 5.9+ stdlib | `@Observable` macro for `SettingsStore` | `[VERIFIED: P3 MinesweeperViewModel already uses without explicit import]` — no `import Observation` needed |
| UniformTypeIdentifiers | bundled | `UTType.json` for `fileExporter` `contentTypes:` | `[CITED: developer.apple.com/documentation/uniformtypeidentifiers]` — ships with Foundation; `import UniformTypeIdentifiers` required for `UTType` symbol |
| Swift Testing | bundled with Xcode 16+ | `@Test` / `#expect` / `@Suite` / `arguments:` for the 3 new test files | `[VERIFIED: P2 + P3 conventions, gamekitTests already on Swift Testing]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `os.Logger` | iOS 14+ | Non-fatal persistence-failure logging (D-15) | Inside `GameStats.record(...)` and `StatsExporter` catch blocks; never log raw `id` UUIDs (privacy: log shape, not values) |
| `UserDefaults.standard` | bundled | `SettingsStore` backing store (D-28) | Tiny key-value flags only — `cloudSyncEnabled: Bool`, future `hapticsEnabled` etc. NEVER stats. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `JSONEncoder` with `.iso8601` strategy | `.iso8601withFractionalSeconds` | Adds milliseconds to every Date — unnecessary precision for played-at timestamps; `.iso8601` already produces deterministic Z-suffix UTC strings. **Reject.** |
| `JSONEncoder.outputFormatting = .prettyPrinted` only | `[.prettyPrinted, .sortedKeys]` | `[VERIFIED: Apple JSONEncoder docs]` — `.sortedKeys` enforces deterministic key order across encoder runs. **Recommend** for SC4 byte-for-byte round-trip even though Swift dictionaries already encode in declaration order today. Belt-and-suspenders against future encoder changes. |
| `FileDocument` wrapper for export | Plain `Data` returned to a `Transferable`-style API | iOS 17 `fileExporter` has TWO overloads: one takes `document: FileDocument` (canonical), one takes `document: Data` directly via the `(isPresented:document:contentType:defaultFilename:onCompletion:)` signature. **Recommend `FileDocument` wrapper** (`StatsExportDocument: FileDocument`) — explicit type-safety, integrates cleanly with Transferable for future Share Sheet support. ~20 extra lines. |
| `modelContext.delete(model: GameRecord.self)` (batch API) | Iterate `@Query` results and `delete(_:)` per-row | `[VERIFIED: 2025 SwiftData batch delete API]` — `delete(model:)` operates on the persistent store directly, **bypassing object instantiation**. For `resetAll()` (D-13) and the import-replace path (D-20), `delete(model:)` is correct: O(1) ish vs O(n) per-row. Requires `try modelContext.save()` after to commit. **Recommend.** |
| `@Attribute(.unique)` on `BestTime.gameKindRaw + difficultyRaw` composite | Application-level "look up by predicate, insert/update" logic in `GameStats.record(...)` | CloudKit-incompat (D-06). Application-level uniqueness is the only viable path. |
| `SchemaMigrationPlan` upfront | Lightweight migration only (additive properties) | P4 ships V1; lightweight migration handles future additive changes. `SchemaMigrationPlan` lands when V2 is actually drafted (deferred). **Reject upfront.** |
| Custom `ModelActor` for writes | Main-actor `ModelContext` from container's `mainContext` | Mines stats writes are <10ms and main-actor-bound (per STACK.md §1 explicit guidance). `ModelActor` is premature. **Reject for MVP.** |
| `presentedItemURL` security-scoped resource handling for imported files | Read directly from URL passed by `.fileImporter` | `[CITED: developer.apple.com/documentation/swiftui/view/fileimporter]` — iOS `fileImporter` returns a security-scoped URL; you MUST call `url.startAccessingSecurityScopedResource()` before reading and `stopAccessingSecurityScopedResource()` after. **Required**, not optional. |

**Installation:**

```swift
// All system frameworks — no new SPM dependencies needed
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os
// (Foundation auto-imported)
```

**Version verification:** All APIs cited (`@Model`, `@Query`, `#Predicate`, `ModelContainer`, `ModelConfiguration.cloudKitDatabase`, `fileExporter`, `fileImporter`, `delete(model:)`, `Logger`) are iOS 17+ system frameworks bundled with the OS. No SPM resolution needed; verified against Apple developer documentation `[CITED: developer.apple.com/documentation/swiftdata]` and existing codebase usage in P1–P3 (already on iOS 17 deployment target per FOUND-04).

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│              App / GameKitApp.swift  (entry point)                  │
│   @main · @StateObject ThemeManager · SettingsStore                 │
│   reads cloudSyncEnabled at init →                                  │
│     constructs sharedContainer = try ModelContainer(                │
│       for: [GameRecord.self, BestTime.self],                        │
│       configurations: ModelConfiguration(                           │
│         schema: schema,                                             │
│         cloudKitDatabase: cloudSyncEnabled                          │
│           ? .private("iCloud.com.lauterstar.gamekit")               │
│           : .none                                                   │
│       )                                                             │
│     )                                                               │
│   .modelContainer(sharedContainer) on RootTabView                   │
└──────────────┬──────────────────────────────────────────────────────┘
               │ environment injection
               ▼
   ┌─────────────────────────────────────────────────────────┐
   │   Screens/RootTabView                                   │
   │      tab: HomeView      tab: StatsView    tab: Settings │
   └──┬─────────────────┬───────────────┬──────────────────┬─┘
      │                 │               │                  │
      │ NavigationLink  │               │                  │
      ▼                 ▼               ▼                  ▼
 ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
 │ Mines        │ │ HomeView     │ │ StatsView    │ │ SettingsView │
 │ GameView     │ │ (Mines card) │ │              │ │              │
 │              │ │              │ │ @Query GR    │ │ @State flags │
 │ @Environment │ └──────────────┘ │ @Query BT    │ │ for 4 modals │
 │   modelCtx → │                  │              │ │              │
 │ GameStats(.) │                  │ derives      │ │ Export →     │
 │     ↓        │                  │ per-diff     │ │   .file      │
 │   inject →   │                  │ stats in     │ │   Exporter   │
 │ MinesweeperVM│                  │ pure SwiftUI │ │              │
 └──────┬───────┘                  └──────────────┘ │ Import →     │
        │                                           │   .file      │
        │ on terminal state                         │   Importer   │
        │ (.won / .lost):                           │              │
        │   try? gameStats?.record(...)             │ Reset →      │
        │   ↓ (failure → os_log; UI continues)      │   .alert     │
        │                                           │   destructive│
        ▼                                           └──────┬───────┘
┌──────────────────────────────────────────────────────────┼──────────┐
│         Core/  (cross-game write boundary)               ▼          │
│  ┌─────────────────────────────┐  ┌──────────────────────────────┐  │
│  │ GameStats                   │  │ StatsExporter (enum ns)     │  │
│  │  init(modelContext:)        │  │  static export(modelCtx:)    │  │
│  │  record(...) throws         │  │     → encode to JSON Data    │  │
│  │  resetAll() throws          │  │  static importing(_:modelCtx:)│ │
│  │                             │  │     → validate schemaVersion │  │
│  │  internal                   │  │     → transaction { delete   │  │
│  │   try modelContext          │  │       all; decode; insert;   │  │
│  │     .transaction { ... }    │  │       save }                 │  │
│  │   try modelContext.save()   │  │                              │  │
│  └──────────────┬──────────────┘  └──────────────┬───────────────┘  │
│                 │                                │                  │
│                 ▼                                ▼                  │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │   sharedContainer.mainContext (ModelContext, @MainActor)   │   │
│   │     ↕ insert / delete / save / @Query auto-refresh         │   │
│   └────────────────────────────────────────────────────────────┘   │
│                                  │                                  │
│                                  ▼                                  │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │   SwiftData ModelContainer (single, shared)                │   │
│   │   Schema: [GameRecord, BestTime]                           │   │
│   │   Configuration:                                           │   │
│   │     cloudKitDatabase: cloudSyncEnabled                     │   │
│   │       ? .private("iCloud.com.lauterstar.gamekit")          │   │
│   │       : .none      ←  P4 default                           │   │
│   └──────────────────────────────┬─────────────────────────────┘   │
│                                  ↕  (CloudKit mirroring,           │
│                                      OFF in P4, ON in P6)          │
│                          ┌─────────────────┐                       │
│                          │ iCloud Private  │                       │
│                          │ Database        │                       │
│                          │ (P6 territory)  │                       │
│                          └─────────────────┘                       │
└──────────────────────────────────────────────────────────────────────┘

         ┌─────────────────────────────────────────────┐
         │  SettingsStore  (Observable @MainActor)     │
         │   over UserDefaults.standard                │
         │   key: gamekit.cloudSyncEnabled (Bool=false)│
         │   read ONCE at GameKitApp.init for D-08     │
         └─────────────────────────────────────────────┘
```

**Trace the primary use case (PERSIST-02 — Hard win, force-quit, relaunch shows record present):**

1. User wins Hard board → VM `gameState = .won` → calls `freezeTimer()` then `try? gameStats?.record(.minesweeper, "hard", .win, 158.4)`.
2. `GameStats.record(...)` inserts `GameRecord`; `Outcome == .win` → look up `BestTime` by `(gameKindRaw == "minesweeper" && difficultyRaw == "hard")`; if first-ever or faster, insert/update `BestTime`.
3. `try modelContext.save()` — explicit, synchronous, before any animation. SQLite WAL is fsync'd before the call returns.
4. User force-quits. iOS terminates the process. The on-disk SQLite file already has the row.
5. User relaunches. `GameKitApp.init` reconstructs the same `ModelContainer` against the same store URL. `StatsView`'s `@Query` re-fetches; new GameRecord + BestTime appear.

### Recommended Project Structure

```
gamekit/gamekit/
├── App/
│   └── GameKitApp.swift             ← edited: construct sharedContainer + SettingsStore;
│                                       inject .modelContainer + .environment(\.settingsStore)
├── Core/                             ← NEW folder (does not yet exist; auto-registers per CLAUDE.md §8.8)
│   ├── GameKind.swift                ← enum GameKind: String { case minesweeper }
│   ├── Outcome.swift                 ← enum Outcome: String { case win, loss }
│   ├── GameRecord.swift              ← @Model final class GameRecord
│   ├── BestTime.swift                ← @Model final class BestTime
│   ├── GameStats.swift               ← write boundary
│   ├── StatsExportEnvelope.swift     ← Codable struct (Codable mirror of @Model fields)
│   ├── StatsExporter.swift           ← enum namespace; static export/importing
│   ├── StatsImportError.swift        ← Error enum; .schemaVersionMismatch case
│   └── SettingsStore.swift           ← @Observable; UserDefaults wrapper
├── Games/Minesweeper/
│   └── MinesweeperViewModel.swift    ← edited: add gameStats: GameStats? injection point
│                                       + private recordTerminalState() helper
│   └── MinesweeperGameView.swift     ← edited: lazy GameStats from @Environment(\.modelContext)
├── Screens/
│   ├── StatsView.swift               ← rewritten: @Query × 2; Grid layout; empty state
│   ├── SettingsView.swift            ← extended: add DATA section (Export/Import/Reset);
│   │                                   .fileExporter / .fileImporter / 2 alerts
│   └── SettingsComponents.swift      ← unchanged (settingsSectionHeader reused)
└── Resources/
    └── Localizable.xcstrings         ← edited: new strings auto-extracted at compile time

gamekit/gamekitTests/
├── Core/                              ← NEW subfolder (auto-registers)
│   ├── GameStatsTests.swift           ← ~8 tests
│   ├── StatsExporterTests.swift       ← ~6 tests
│   └── ModelContainerSmokeTests.swift ← ~3 tests
└── Helpers/                           ← NEW subfolder
    └── InMemoryStatsContainer.swift   ← test-only helper; isStoredInMemoryOnly: true
```

### Pattern 1: CloudKit-Compatible `@Model` Schema (PERSIST-01)

**What:** Every property optional or defaulted. No `@Attribute(.unique)`. No required relationships. `schemaVersion: Int = 1` field on every `@Model` class.

**When to use:** Any `@Model` that is, or might ever be, mirrored to CloudKit. Since GameKit ships with `cloudKitDatabase` as a feature flag (D-08), every `@Model` from V1 follows the rules — even though P4 default-flips sync OFF.

**Example:**

```swift
// Source: D-02 + ARCHITECTURE.md Pattern 2 + iOS 17 SwiftData docs
// [CITED: developer.apple.com/documentation/swiftdata]
import Foundation
import SwiftData

@Model
final class GameRecord {
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.minesweeper.rawValue
    var difficultyRaw: String = ""           // "easy" | "medium" | "hard" — locked P2 D-02
    var outcomeRaw: String = ""              // "win" | "loss"
    var durationSeconds: Double = 0
    var playedAt: Date = .now
    var schemaVersion: Int = 1

    // Computed accessors — safe fallbacks per D-02
    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .minesweeper }
    var outcome: Outcome { Outcome(rawValue: outcomeRaw) ?? .loss }

    init(
        gameKind: GameKind = .minesweeper,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double,
        playedAt: Date = .now
    ) {
        self.gameKindRaw = gameKind.rawValue
        self.difficultyRaw = difficulty
        self.outcomeRaw = outcome.rawValue
        self.durationSeconds = durationSeconds
        self.playedAt = playedAt
    }
}
```

**Note on `schemaVersion: Int = 1`:** `[ASSUMED]` — userland convention, not a SwiftData reserved word. SwiftData's actual schema versioning lives in `VersionedSchema` + `SchemaMigrationPlan`. The field exists for the JSON envelope (D-17) and for human-readable forward-compat checks. Keeping it on every `@Model` mirrors what's shipped to JSON; harmless overhead.

### Pattern 2: `GameStats` as Write Boundary (PERSIST-02 + SC1)

**What:** A single class that owns `ModelContext` and exposes only domain-meaningful methods. The ViewModel injection target. Failure modes are contained — VM can pass `nil` in tests, and `try? gameStats?.record(...)` makes persistence failures non-fatal to gameplay.

**When to use:** Always. This is the boundary that lets `MinesweeperViewModel` stay Foundation-only (no `import SwiftData` per D-14).

**Example:**

```swift
// Source: D-11 + D-12 + ARCHITECTURE.md Pattern 4 + Code Examples 1
import Foundation
import SwiftData
import os

final class GameStats {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.lauterstar.gamekit", category: "persistence")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(
        gameKind: GameKind,
        difficulty: String,
        outcome: Outcome,
        durationSeconds: Double
    ) throws {
        // Insert GameRecord first — never blocked by BestTime evaluation
        let record = GameRecord(
            gameKind: gameKind,
            difficulty: difficulty,
            outcome: outcome,
            durationSeconds: durationSeconds
        )
        modelContext.insert(record)

        // BestTime evaluation only on win — wrapped in do/catch so a flaky predicate
        // doesn't block GameRecord persistence (Discretion lock)
        if outcome == .win {
            do {
                try evaluateBestTime(
                    gameKind: gameKind,
                    difficulty: difficulty,
                    seconds: durationSeconds
                )
            } catch {
                logger.error("BestTime evaluation failed: \(error.localizedDescription)")
                // GameRecord still persists; BestTime miss is non-fatal
            }
        }

        try modelContext.save()
    }

    private func evaluateBestTime(
        gameKind: GameKind,
        difficulty: String,
        seconds: Double
    ) throws {
        let kindRaw = gameKind.rawValue
        let descriptor = FetchDescriptor<BestTime>(
            predicate: #Predicate { $0.gameKindRaw == kindRaw && $0.difficultyRaw == difficulty }
        )
        let existing = try modelContext.fetch(descriptor)

        if let existing = existing.first {
            if seconds < existing.seconds {
                existing.seconds = seconds
                existing.achievedAt = .now
            }
        } else {
            let new = BestTime(
                gameKind: gameKind,
                difficulty: difficulty,
                seconds: seconds
            )
            modelContext.insert(new)
        }
    }

    func resetAll() throws {
        try modelContext.transaction {
            try modelContext.delete(model: GameRecord.self)
            try modelContext.delete(model: BestTime.self)
        }
        try modelContext.save()
    }
}
```

**Key choices:**
- `final class` (not `enum` namespace) because it carries state (`modelContext`, `logger`) and the VM needs an injectable instance per D-14.
- `try modelContext.save()` is **synchronous and explicit** — non-negotiable per Pitfall 10 (autosave delay drops records on force-quit; PERSIST-02 demands force-quit survival).
- `try modelContext.transaction { ... }` for `resetAll()` makes the two `delete(model:)` calls atomic; partial reset is impossible.

### Pattern 3: JSON Export/Import via `FileDocument` + Envelope

**What:** A typed `FileDocument` wrapper (`StatsExportDocument`) carries a `Data` payload to `fileExporter`. The payload is the encoded `StatsExportEnvelope`, a `Codable` struct that mirrors the `@Model` fields.

**When to use:** Always — this is the only path that crosses the app boundary. `fileImporter` returns a security-scoped URL that needs explicit `startAccessingSecurityScopedResource()` / `stop...` bookends.

**Example:**

```swift
// Source: D-17 + D-18 + D-19 + D-20 + UI-SPEC interaction contract
// [CITED: developer.apple.com/documentation/swiftui/view/fileexporter]
// [CITED: useyourloaf.com/blog/swiftui-importing-and-exporting-files/]
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// Codable mirror — JSON keys match Swift property names per D-18
struct StatsExportEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let gameRecords: [Record]
    let bestTimes: [Best]

    struct Record: Codable, Sendable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let outcomeRaw: String
        let durationSeconds: Double
        let playedAt: Date
        let schemaVersion: Int
    }

    struct Best: Codable, Sendable {
        let id: UUID
        let gameKindRaw: String
        let difficultyRaw: String
        let seconds: Double
        let achievedAt: Date
        let schemaVersion: Int
    }
}

enum StatsImportError: LocalizedError {
    case schemaVersionMismatch(found: Int, expected: Int)
    case decodeFailed
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .schemaVersionMismatch:
            return String(localized: "This file was exported from a newer GameKit. Update the app and try again.")
        case .decodeFailed, .fileReadFailed:
            return String(localized: "The file couldn't be read. Check that it's a GameKit stats export and try again.")
        }
    }
}

enum StatsExporter {
    private static let envelopeSchemaVersion = 1

    static func export(modelContext: ModelContext) throws -> Data {
        let records = try modelContext.fetch(FetchDescriptor<GameRecord>())
        let bests = try modelContext.fetch(FetchDescriptor<BestTime>())

        let envelope = StatsExportEnvelope(
            schemaVersion: envelopeSchemaVersion,
            exportedAt: .now,
            gameRecords: records.map { r in
                .init(
                    id: r.id, gameKindRaw: r.gameKindRaw,
                    difficultyRaw: r.difficultyRaw, outcomeRaw: r.outcomeRaw,
                    durationSeconds: r.durationSeconds, playedAt: r.playedAt,
                    schemaVersion: r.schemaVersion
                )
            },
            bestTimes: bests.map { b in
                .init(
                    id: b.id, gameKindRaw: b.gameKindRaw,
                    difficultyRaw: b.difficultyRaw, seconds: b.seconds,
                    achievedAt: b.achievedAt, schemaVersion: b.schemaVersion
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys] // SC4 byte-for-byte determinism
        return try encoder.encode(envelope)
    }

    static func importing(_ data: Data, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: StatsExportEnvelope
        do {
            envelope = try decoder.decode(StatsExportEnvelope.self, from: data)
        } catch {
            throw StatsImportError.decodeFailed
        }

        guard envelope.schemaVersion == envelopeSchemaVersion else {
            throw StatsImportError.schemaVersionMismatch(
                found: envelope.schemaVersion,
                expected: envelopeSchemaVersion
            )
        }

        try modelContext.transaction {
            // Replace-on-import per D-20
            try modelContext.delete(model: GameRecord.self)
            try modelContext.delete(model: BestTime.self)

            for r in envelope.gameRecords {
                let record = GameRecord(
                    gameKind: GameKind(rawValue: r.gameKindRaw) ?? .minesweeper,
                    difficulty: r.difficultyRaw,
                    outcome: Outcome(rawValue: r.outcomeRaw) ?? .loss,
                    durationSeconds: r.durationSeconds,
                    playedAt: r.playedAt
                )
                record.id = r.id  // preserve identity from envelope
                modelContext.insert(record)
            }
            for b in envelope.bestTimes {
                let best = BestTime(
                    gameKind: GameKind(rawValue: b.gameKindRaw) ?? .minesweeper,
                    difficulty: b.difficultyRaw,
                    seconds: b.seconds,
                    achievedAt: b.achievedAt
                )
                best.id = b.id
                modelContext.insert(best)
            }
        }
        try modelContext.save()
    }
}

// FileDocument wrapper for fileExporter
struct StatsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let blob = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = blob
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
```

### Pattern 4: `@Query` + `#Predicate` for StatsView (SHELL-03)

**What:** StatsView declares `@Query` with `#Predicate` and `KeyPath`-based sort. View derives per-difficulty rows in pure-SwiftUI computed properties — no separate StatsViewModel (CLAUDE.md §8.2).

**Example:**

```swift
// Source: D-24 + ARCHITECTURE.md Pattern 4 + UI-SPEC layout contract
// [CITED: developer.apple.com/documentation/swiftdata/query]
import SwiftUI
import SwiftData
import DesignKit

struct StatsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    // Two queries — view owns fetch (CLAUDE.md §8.2)
    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" },
        sort: \.playedAt,
        order: .reverse
    )
    private var minesRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "minesweeper" })
    private var minesBestTimes: [BestTime]

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    settingsSectionHeader(theme: theme, String(localized: "MINESWEEPER"))
                    DKCard(theme: theme) {
                        if minesRecords.isEmpty {
                            Text(String(localized: "No games played yet."))
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textTertiary)
                                .frame(maxWidth: .infinity)
                        } else {
                            statsGrid
                        }
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Stats"))
        }
    }

    private var statsGrid: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: theme.spacing.m,
            verticalSpacing: theme.spacing.s
        ) {
            // Column header strip
            GridRow {
                Text("").gridColumnAlignment(.leading)
                Text(String(localized: "Games"))
                    .gridColumnAlignment(.trailing)
                Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                Text(String(localized: "Win %")).gridColumnAlignment(.trailing)
                Text(String(localized: "Best")).gridColumnAlignment(.trailing)
            }
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.textSecondary)

            // 1pt rule between header and data rows
            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .gridCellColumns(5)

            ForEach(MinesweeperDifficulty.allCases, id: \.self) { diff in
                let cohort = minesRecords.filter { $0.difficultyRaw == diff.rawValue }
                let wins = cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count
                let games = cohort.count
                let winPct: String = games == 0
                    ? "—"
                    : "\(Int((Double(wins) * 100.0 / Double(games)).rounded()))%"
                let best = minesBestTimes.first { $0.difficultyRaw == diff.rawValue }

                GridRow {
                    Text(displayName(diff))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("\(games)")
                        .font(theme.typography.monoNumber)
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                        .gridColumnAlignment(.trailing)
                    Text("\(wins)")
                        .font(theme.typography.monoNumber)
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                        .gridColumnAlignment(.trailing)
                    Text(winPct)
                        .font(theme.typography.monoNumber)
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                        .gridColumnAlignment(.trailing)
                    Text(formatBestTime(best?.seconds))
                        .font(theme.typography.monoNumber)
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }
    // displayName + formatBestTime are file-private helpers
}
```

**`#Predicate` constraint note:** `[CITED: hackingwithswift.com/quick-start/swiftdata]` — `#Predicate` blocks support `==` on `String` properties cleanly. Capturing local variables into the predicate (as in `evaluateBestTime` above) requires the variables to be `let`-bound and captured before the `#Predicate { ... }` block — direct keypath comparison to a literal string also works for the simpler `gameKindRaw == "minesweeper"` case.

### Pattern 5: Shared `ModelContainer` Construction in `GameKitApp`

**What:** Single `ModelContainer` constructed once at app init. Two configurations are explicitly possible (production = `.none`; SC3 smoke test exercises `.private(...)` in CI). The container is injected app-wide via `.modelContainer(...)`.

**Example:**

```swift
// Source: D-07 + D-08 + D-29 + ARCHITECTURE.md Pattern 5
import SwiftUI
import SwiftData
import DesignKit

@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()
    @State private var settingsStore = SettingsStore()
    let sharedContainer: ModelContainer

    init() {
        let store = SettingsStore()
        _settingsStore = State(initialValue: store)

        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: store.cloudSyncEnabled
                ? .private("iCloud.com.lauterstar.gamekit")
                : .none
        )
        do {
            sharedContainer = try ModelContainer(
                for: schema, configurations: [config]
            )
        } catch {
            // Fatal at launch — schema constraint violation.
            // SC3 smoke test guards against this in CI.
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .environment(\.settingsStore, settingsStore)
                .preferredColorScheme(preferredScheme)
                .modelContainer(sharedContainer)
        }
    }

    private var preferredScheme: ColorScheme? { /* unchanged from P1 */ }
}

// SettingsStore EnvironmentKey
private struct SettingsStoreKey: EnvironmentKey {
    static let defaultValue: SettingsStore = SettingsStore()
}
extension EnvironmentValues {
    var settingsStore: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
```

**Two notes:**

1. **`@State private var settingsStore = SettingsStore()` initialized in `init()` then re-read** — this awkward double-construct is because `cloudSyncEnabled` must be read **before** the `ModelContainer` exists. The `_settingsStore = State(initialValue: store)` rebinding pattern is iOS-17-canonical.
2. **CloudKit container ID lookup:** `[CITED: Apple Developer Documentation — ModelConfiguration.CloudKitDatabase]` — when `cloudKitDatabase` is `.automatic`, SwiftData reads the **first** iCloud container ID from `Entitlements.plist`. When passing `.private("iCloud.com.lauterstar.gamekit")` explicitly (D-08), the entitlements file MUST list `iCloud.com.lauterstar.gamekit` as a CloudKit container — otherwise `ModelContainer.init(...)` throws at runtime with a "container not configured" error. **For P4 sync-OFF default, the entitlements file does NOT need the iCloud capability** — `.none` skips the CloudKit lookup. The SC3 smoke test passes `isStoredInMemoryOnly: true` AND `cloudKitDatabase: .private(...)`; SwiftData still validates the schema constraints but **does not contact iCloud** because the in-memory store has no real CloudKit pairing. **Confidence: HIGH** that the smoke test works without iCloud capability provisioning; the actual P6 sync-on path WILL require capability provisioning at that time.

### Pattern 6: In-Memory `ModelContainer` for Tests

**What:** Per-test fresh container with `isStoredInMemoryOnly: true` so simulator state does not leak between tests. The CloudKit smoke test combines `cloudKitDatabase: .private(...)` with `isStoredInMemoryOnly: true` — schema constraints are validated, no iCloud round-trip.

**Example:**

```swift
// Source: D-31 + [CITED: hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code]
import SwiftData
@testable import gamekit

@MainActor
enum InMemoryStatsContainer {
    static func make(cloudKit: ModelConfiguration.CloudKitDatabase = .none) throws -> ModelContainer {
        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: cloudKit
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// Usage in a test:
@MainActor
@Suite("GameStats")
struct GameStatsTests {
    @Test("record(.win) inserts GameRecord and BestTime") func recordWin() throws {
        let container = try InMemoryStatsContainer.make()
        let stats = GameStats(modelContext: container.mainContext)

        try stats.record(
            gameKind: .minesweeper,
            difficulty: "hard",
            outcome: .win,
            durationSeconds: 158.4
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        #expect(records.count == 1)
        #expect(bests.count == 1)
        #expect(bests.first?.seconds == 158.4)
    }
}
```

**`@MainActor` requirement:** `[CITED: hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency]` — `ModelContext` is NOT Sendable. Tests that use `mainContext` MUST be annotated `@MainActor` (suite or per-test). Swift Testing's `@Suite` accepts `@MainActor`. Per-test `@MainActor` annotations also work for Swift Testing parameterized tests.

### Anti-Patterns to Avoid

- **VM imports SwiftData.** Already locked OUT by D-14. If anyone adds `import SwiftData` to `MinesweeperViewModel.swift`, the architectural firewall is breached. Engine purity rule (CLAUDE.md §4) is the same firewall, one tier deeper.
- **Stats writes inside the win/loss animation onAppear.** Pitfall 10 explicitly: "User wins, animation starts, user force-quits. Result: win never counted." Write **synchronously before animation triggers**.
- **`@Attribute(.unique)` on any field.** Compiles fine; crashes when CloudKit is enabled in P6. SC3 smoke test catches this at PR time.
- **Required (non-optional, non-defaulted) properties on `@Model`.** Same failure mode as `@Attribute(.unique)`.
- **`ModelContainer` reconstruction at runtime.** STACK.md MEDIUM-confidence note: hot-swapping container config is "touchy." For P4, container is built once at app init; toggling `cloudSyncEnabled` requires app relaunch (D-29). P6 lands the actual sign-in flow.
- **`@Query` inside reusable cards.** CLAUDE.md §8.2; `MinesStatsCard` and `MinesDifficultyStatsRow` take props.
- **`Color(...)` literal anywhere in `Screens/StatsView.swift` or `Screens/SettingsView.swift`.** Pre-commit hook FOUND-07 rejects these; UI-SPEC enforces it.
- **`autosave` reliance.** Pitfall 10 again: explicit `try modelContext.save()` is mandatory; SwiftData's autosave delay can drop a record on force-quit.
- **JSON without `.sortedKeys`.** SC4's "byte-for-byte" round-trip would silently break the day Apple changes the default key ordering. `.sortedKeys` is cheap belt-and-suspenders.
- **`Data`-based `fileExporter` overload without a `FileDocument` wrapper.** The bare-Data overload exists but a `FileDocument` wrapper is canonical, more type-safe, and straight-up cheaper to extend (Transferable, Share Sheet) later.
- **Forgetting `startAccessingSecurityScopedResource()` on imported URLs.** `[CITED: developer.apple.com/documentation/swiftui/view/fileimporter]` — imported URLs from `fileImporter` are security-scoped; reading without bookend calls fails silently in release builds. Wrap with `defer { url.stopAccessingSecurityScopedResource() }`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stats persistence over app force-quit | Hand-rolled JSON-to-disk on every state change | `SwiftData @Model` + `try modelContext.save()` | SwiftData WAL fsync + on-disk SQLite gives crash-safety for free |
| Object-relational mapping for two tables | Custom Codable-to-SQLite layer | `@Model` macro + `ModelContainer` | iOS-canonical; CloudKit-mirror-ready in V1 even though sync OFF |
| Reactive view-model fetch wiring | `@Published` + manual `fetch()` calls | `@Query` macro | Auto-refreshes on container saves; iOS 17 idiomatic; less code |
| Settings persistence | Custom `Codable` struct + `JSONEncoder` to a Settings.json file | `UserDefaults.standard` + `@Observable` wrapper | Tiny key-value shape per CLAUDE.md §1; UserDefaults is the right tool |
| File picker UI (Export) | Custom UIDocumentPickerViewController integration | SwiftUI `.fileExporter(...)` modifier | Native; handles UTType, defaultFilename, cancel/error paths |
| File picker UI (Import) | Custom UIDocumentPickerViewController integration | SwiftUI `.fileImporter(...)` modifier | Native; security-scoped URLs; same chrome as system |
| Confirmation dialog for destructive action | Custom modal sheet | SwiftUI `.alert(role: .destructive)` | iOS-native; system tints destructive button; A11y handled |
| Logging non-fatal failures | `print(...)` | `os.Logger` | iOS canonical; structured; respects privacy modifiers; doesn't ship to release console |
| Batch delete for `resetAll()` | `try modelContext.fetch(...).forEach { delete($0) }` | `try modelContext.delete(model: GameRecord.self)` | iOS 17 batch API operates on store directly; bypasses object instantiation; correct for SwiftData |
| Atomic two-table delete | Two separate `save()` calls | `modelContext.transaction { ... }` | One commit; partial reset is impossible |
| ISO8601 date encoding | Custom `DateFormatter` | `JSONEncoder.dateEncodingStrategy = .iso8601` | Foundation-canonical; UTC `Z` suffix; cross-device portable |
| Schema-version envelope wrapper for JSON | Custom version field handling | `Codable struct StatsExportEnvelope { var schemaVersion: Int; ... }` | Single source of truth; encode + decode are symmetric |
| Combine-based settings change observation | `Combine.Publisher` | `@Observable` macro on `SettingsStore` | iOS 17 idiomatic; views automatically re-render; less boilerplate |

**Key insight:** iOS 17 + SwiftData ships canonical solutions for every persistence problem in P4. The trap is reaching for older patterns (`Combine`, `NSPersistentContainer`, `NSCoder`, `Timer.publish`) that pre-date the modern stack. Every time you're tempted to import `Combine` for stats, the answer is `@Query` + `@Observable` + `try modelContext.save()`.

## Common Pitfalls

### Pitfall 1: `@Attribute(.unique)` slips into a `@Model` and crashes the day CloudKit turns on

**What goes wrong:** Devs reach for `@Attribute(.unique) var id: UUID` out of habit. Local-only mode tolerates it; the moment `cloudKitDatabase: .private(...)` is configured, `ModelContainer.init(...)` throws.

**Why it happens:** No compile-time warning. Local-only tests pass. Shipped silently.

**How to avoid:**
- SC3 smoke test (D-10) constructs the container with **both** `.none` and `.private(...)` configurations every test run. The constraint violation surfaces at PR time.
- Code review checklist item: any `@Attribute(.unique)` in `Core/*.swift` is a P0 reject.
- Identity is enforced via `id: UUID = UUID()` + application-level dedup in `evaluateBestTime` (Pattern 2).

**Warning signs:** `@Attribute(.unique)` appears in any `Core/` file. Schema validation throws in the smoke test.

### Pitfall 2: Required (non-optional, non-defaulted) `@Model` property crashes container init

**What goes wrong:** `var difficulty: MinesweeperDifficulty` (no default, not optional) compiles fine; CloudKit container init throws with `"property must be optional or have a default value"`.

**Why it happens:** Forgetting CloudKit's eventual-consistency rule (a record may arrive without every field).

**How to avoid:** D-02 + D-03 give every property a default. SC3 smoke test catches violations.

**Warning signs:** Any `var X: Type` without `= default` or `?` in `Core/GameRecord.swift` or `BestTime.swift`.

### Pitfall 3: Game-result write happens after the win-sweep animation onAppear

**What goes wrong:** User wins → animation starts (1s sweep) → user force-quits → save never fired → win uncounted. PERSIST-02 fails.

**Why it happens:** UX-first thinking — "save when the success screen is shown" — is wrong.

**How to avoid:** D-15: `recordTerminalState()` fires from inside the VM's terminal-state transition (`gameState = .won`), **before** any view-tier observation. The VM mutating `gameState` synchronously triggers `try? gameStats?.record(...)` inline. Animation runs after the SQLite WAL fsync.

**Warning signs:** `gameStats.record(...)` called from `.onAppear`, `.task`, `.onChange(of: gameState)`, or any view-tier callback. Manual force-quit test doesn't show the row in StatsView.

### Pitfall 4: Timer drift undercount on Hard wins (already fixed in P3 — preserved here)

**What goes wrong:** User pauses for a phone call; elapsed undercount.

**Why it happens:** Naive `Timer.publish` accumulator pauses with the app.

**How to avoid:** P3 D-05/D-06 already shipped wall-clock + scenePhase pause/resume math. P4 inherits — `viewModel.frozenElapsed` is canonical at terminal-state transitions, and that's the value passed to `gameStats.record(...)`.

**Warning signs:** Any `gameStats.record(... durationSeconds: Date.now.timeIntervalSince(...))` call site — should always be `viewModel.frozenElapsed`.

### Pitfall 5: `.fileImporter` URL not security-scope-acquired before reading

**What goes wrong:** Import works in the simulator (no security scope enforcement); fails silently in release on device — `Data(contentsOf: url)` returns empty bytes or throws "permission denied."

**Why it happens:** `fileImporter` returns a security-scoped URL by default. Reading requires explicit `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()` bookends.

**How to avoid:**

```swift
.fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.json]) { result in
    switch result {
    case .success(let url):
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try StatsExporter.importing(data, modelContext: modelContext)
        } catch let StatsImportError.schemaVersionMismatch {
            isImportSchemaErrorAlertPresented = true
        } catch {
            isImportGenericErrorAlertPresented = true
        }
    case .failure:
        // user cancelled — silent
        break
    }
}
```

**Warning signs:** Import works in dev, fails on TestFlight. `Data(contentsOf:)` returns 0 bytes from imported URLs.

### Pitfall 6: Schema-version mismatch alert wipes existing stats

**What goes wrong:** Devs initially write the import path as: "delete all → decode → if decode fails, throw." The delete already ran. Existing data is gone.

**Why it happens:** Wrong order in the transaction.

**How to avoid:** D-20 explicit order:
1. **Decode first** (cheap; pre-validation)
2. **Validate `schemaVersion`** (throws *before* any delete)
3. THEN open transaction → delete → insert → save

The `try modelContext.transaction { ... }` block also rolls back on throw, so even if delete-then-decode happened (it shouldn't), the rollback restores. But "decode + validate before opening the transaction" is structurally cleaner.

**Warning signs:** A test simulating malformed JSON shows fewer rows after the import attempt than before.

### Pitfall 7: `JSONEncoder` non-deterministic key ordering breaks SC4 byte-for-byte round-trip

**What goes wrong:** Export → reset → import gives logically equivalent data, but the bytes differ because JSON object key order is non-deterministic across Swift runtime versions.

**Why it happens:** Swift's `Dictionary` and `JSONEncoder` don't guarantee key order without `.sortedKeys`.

**How to avoid:** `encoder.outputFormatting = [.prettyPrinted, .sortedKeys]`. Already in Pattern 3. Adds 0 runtime cost; protects against silent SC4 regression.

**Warning signs:** SC4 test fails with "data length matches but bytes differ at offset N."

### Pitfall 8: `MinesweeperGameView` recomputes `GameStats` per body invocation

**What goes wrong:** `let gameStats = GameStats(modelContext: modelContext)` inside `body` constructs a new instance every render. State-free per se, but creates GC churn and (worse) a new `os.Logger` every render.

**Why it happens:** Naive translation of "construct lazily."

**How to avoid:** Construct once via `@Environment(\.modelContext)` accessor inside `init` or via a `@State` lazy:

```swift
struct MinesweeperGameView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MinesweeperViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                // ... render with vm
            } else {
                Color.clear.onAppear {
                    let stats = GameStats(modelContext: modelContext)
                    viewModel = MinesweeperViewModel(gameStats: stats)
                }
            }
        }
    }
}
```

**Better recommendation:** keep current P3 `init()` shape but add an `init(modelContext:)` overload that constructs `GameStats` once and threads it into the VM. The `@Environment(\.modelContext)` value is stable across body re-renders, but the `let` rebinding inside `body` is what causes churn.

**Warning signs:** `Logger` instances printed multiply for the same game; instruments shows `GameStats.init` in the SwiftUI body hot path.

### Pitfall 9: `BestTime` uniqueness is application-level, not enforced — concurrent writes could create duplicates

**What goes wrong:** Two rapid wins (impossible in single-player MVP, but theoretically) could both pass the "no existing BestTime" check and create two `BestTime` rows for the same `(gameKind, difficulty)`.

**Why it happens:** No `@Attribute(.unique)` (CloudKit-incompat); application-level lookup-then-insert is racy in principle.

**How to avoid:** P4 is single-player, single-device, main-actor only. The race window doesn't exist in practice. **For P6 multi-device CloudKit:** add a "merge duplicates" pass on launch that picks the lowest-`seconds` row per `(gameKind, difficulty)`. Already deferred per CONTEXT.

**Warning signs:** Multiple `BestTime` rows for the same `(gameKindRaw, difficultyRaw)` pair after a P6 multi-device session.

### Pitfall 10: `ModelContext.save()` failure is non-fatal but invisible

**What goes wrong:** `gameStats?.record(...)` throws (disk full, sandbox permission, schema corruption). VM uses `try?` per D-15 — failure is silent. User keeps playing; their stats aren't recording.

**Why it happens:** UX gates the persistence layer. If a save fails repeatedly, the user has zero feedback.

**How to avoid:** D-15 routes failure through `os_log` so a sysdiagnose can recover the trail. **For P5 polish:** consider a Settings "Diagnostics" row showing the last save failure time + reason. Out of scope for P4.

**Warning signs:** Stats screen never updates despite playing games. Console shows `os_log` errors with `category: persistence`.

## Code Examples

### Common Operation 1: Construct shared `ModelContainer` with feature-flagged CloudKit

See **Pattern 5** above.

### Common Operation 2: `@Model` class with CloudKit-compat constraints

See **Pattern 1** above.

### Common Operation 3: Synchronous stats record with explicit save

See **Pattern 2** above (full `GameStats.record(...)` listing).

### Common Operation 4: VM injection without SwiftData import

```swift
// Source: D-14 + D-15 + existing P3 MinesweeperViewModel.swift signature
import Foundation
// NOTE: NO `import SwiftData` — VM is the engine-purity boundary

@Observable @MainActor
final class MinesweeperViewModel {
    // ... existing P3 state ...

    private let gameStats: GameStats?  // injected; nil in tests; concrete in production

    init(
        difficulty: MinesweeperDifficulty? = nil,
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { Date.now },
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        gameStats: GameStats? = nil  // NEW in P4
    ) {
        // ... existing init ...
        self.gameStats = gameStats
    }

    private func recordTerminalState(outcome: GameOutcome) {
        // try? — failure is non-fatal per D-15
        try? gameStats?.record(
            gameKind: .minesweeper,
            difficulty: difficulty.rawValue,
            outcome: outcome == .win ? .win : .loss,
            durationSeconds: frozenElapsed
        )
    }
    // call recordTerminalState(outcome: .win) immediately after gameState = .won
    // call recordTerminalState(outcome: .loss) immediately after gameState = .lost(mineIdx:)
}
```

`GameStats` as a forward-declared opaque type works because the VM only stores it as `GameStats?` and calls one method. The test target imports `gamekit` (which re-exports SwiftData transitively if needed), but VM tests just pass `nil` and assert state transitions — no SwiftData container needed for VM tests.

### Common Operation 5: SC3 smoke test (CloudKit + in-memory)

```swift
// Source: D-10 + D-31
@MainActor
@Suite("ModelContainer smoke")
struct ModelContainerSmokeTests {
    @Test("constructs with .none cloudKitDatabase")
    func constructLocalOnly() throws {
        _ = try InMemoryStatsContainer.make(cloudKit: .none)
    }

    @Test("constructs with .private(\"iCloud.com.lauterstar.gamekit\") cloudKitDatabase")
    func constructCloudKitCompat() throws {
        // Even with sync OFF in production, construction MUST succeed —
        // proves no @Attribute(.unique), all properties optional/defaulted.
        _ = try InMemoryStatsContainer.make(
            cloudKit: .private("iCloud.com.lauterstar.gamekit")
        )
    }

    @Test("schema is exactly [GameRecord, BestTime]")
    func schemaIsLocked() throws {
        let container = try InMemoryStatsContainer.make()
        let entityNames = container.schema.entities.map(\.name).sorted()
        #expect(entityNames == ["BestTime", "GameRecord"])
    }
}
```

### Common Operation 6: `fileExporter` integration in SettingsView

```swift
// Source: D-19 + UI-SPEC interaction contract + Pattern 3
@Environment(\.modelContext) private var modelContext
@State private var isExporterPresented = false
@State private var exportDocument: StatsExportDocument?

// trigger row:
SettingsActionRow(
    theme: theme,
    glyph: "square.and.arrow.up",
    label: String(localized: "Export stats"),
    glyphTint: theme.colors.textPrimary
) {
    do {
        let data = try StatsExporter.export(modelContext: modelContext)
        exportDocument = StatsExportDocument(data: data)
        isExporterPresented = true
    } catch {
        // Export failed pre-picker — log, no toast in P4 per CONTEXT
        Logger(subsystem: "com.lauterstar.gamekit", category: "persistence")
            .error("Export pre-picker failed: \(error.localizedDescription)")
    }
}

// modifier on the surrounding view:
.fileExporter(
    isPresented: $isExporterPresented,
    document: exportDocument,
    contentType: .json,
    defaultFilename: defaultExportFilename()
) { result in
    if case .failure(let error) = result {
        Logger(subsystem: "com.lauterstar.gamekit", category: "persistence")
            .error("Export failed: \(error.localizedDescription)")
    }
}

private func defaultExportFilename() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return "gamekit-stats-\(formatter.string(from: .now)).json"
}
```

## Runtime State Inventory

> Skipped — P4 is greenfield (first SwiftData phase). No existing runtime state to migrate. The first time `try ModelContainer(...)` runs creates a fresh SQLite store under `Application Support/default.store`. No data exists to rename, migrate, or invalidate.

## State of the Art

Typical 2026-04 SwiftData + CloudKit patterns vs older approaches that should be avoided:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSPersistentCloudKitContainer` (Core Data) | `ModelConfiguration(cloudKitDatabase: .private(...))` | iOS 17 (2023) | SwiftData wraps Core Data; same CloudKit mirror under the hood; cleaner declarative API |
| `@StateObject` for view models | `@State` + `@Observable` | iOS 17 (2023) | `@Observable` macro replaces `ObservableObject`; granular property observation; less boilerplate |
| `@ObservedObject` injection | Plain `let` properties on `@Observable` types passed as init params | iOS 17 (2023) | `@Observable` propagates re-render to consumers; no wrapper needed |
| `Combine.Publisher` for settings observation | `@Observable` over `UserDefaults` | iOS 17 (2023) | `@Observable` is the modern way; no `Combine` import needed |
| `try? ModelContainer(...)` without configurations | `try ModelContainer(for: schema, configurations: [config])` with explicit `ModelConfiguration` | iOS 17 (2023) | Explicit `cloudKitDatabase` and `isStoredInMemoryOnly` flags require ModelConfiguration |
| Recursive object iteration to delete all | `try modelContext.delete(model: T.self)` | iOS 17.3 (2024-ish) | Batch delete operates on the persistent store; bypasses object instantiation; significantly faster |
| `XCTAssertEqual` + XCTest | `#expect(...)` + Swift Testing | Xcode 16 (2024) | Better diagnostics, parallel execution, parameterized tests; XCTest stays for UI tests |
| `Color(hex:)` literals | `theme.colors.{role}` semantic tokens | DesignKit P1 (2026-04) | Pre-commit hook FOUND-07 enforces; no exceptions |
| `Timer.publish(every: 1)` for elapsed | Wall-clock `Date` + scenePhase pause/resume | P3 D-05 (2026-04) | Survives backgrounding; no Combine dep |
| `@Attribute(.transformable)` | Codable enums + `String` raw values | iOS 17 (2023) | CloudKit-incompat with custom transformers; raw String is portable + cross-platform safe |

**Deprecated / outdated:**
- `NSCoding` for stats persistence: replaced by `Codable` + `JSONEncoder` (Foundation has supported this for years; SwiftData inherits it via `@Model`).
- `UIDocumentPickerViewController` direct integration: SwiftUI's `.fileExporter` / `.fileImporter` modifiers are the canonical iOS 17+ path.
- `XCTAssertNoThrow(try ModelContainer(...))`: replaced by Swift Testing's `#expect(throws: Never.self) { try ModelContainer(...) }` or simply `_ = try ...` inside a `@Test func` body (Swift Testing surfaces the throw automatically).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `schemaVersion: Int = 1` on `@Model` is a userland convention, not a SwiftData reserved word. | Pattern 1 | LOW — if SwiftData reserves the symbol, the field on the `@Model` would conflict and compile-error immediately. We'd rename to `appSchemaVersion`. Caught at first compile. |
| A2 | Combining `cloudKitDatabase: .private("iCloud....")` + `isStoredInMemoryOnly: true` validates schema constraints WITHOUT contacting iCloud. | Pattern 6 + SC3 | MEDIUM — if SwiftData attempts a real CloudKit handshake during `ModelContainer.init`, the smoke test would fail in CI without an iCloud account. Mitigation: D-31 specifies in-memory + CloudKit config; if it fails in practice, fall back to two separate tests (`.none` validates schema; `.private(...)` requires CI iCloud account or skip in CI). |
| A3 | `.private("iCloud.com.lauterstar.gamekit")` does NOT require the iCloud capability in `Entitlements.plist` for the `cloudKitDatabase: .none` production path. | Pattern 5 | LOW — by definition `.none` skips CloudKit lookup. The smoke test path exercises `.private(...)` only via `isStoredInMemoryOnly: true`. P6 will add the capability. |
| A4 | Apple's `JSONEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]` is deterministic across Swift runtime versions. | Pattern 3 + Pitfall 7 | LOW — `.sortedKeys` is documented to enforce alphabetical key ordering; Apple has not signaled deprecation. |
| A5 | Preserving `id: UUID` from the import envelope (`record.id = r.id`) is safe — `@Model`'s `id` is a normal property when no `@Attribute(.unique)` is set, so explicit assignment overrides the default `UUID()` generator. | Pattern 3 (importing) | LOW — if SwiftData ignores assignments to `id`, the imported records get fresh UUIDs and round-trip identity is lost (but data fidelity is preserved). Tests catch this immediately. Mitigation: if it fails, drop `id` from the envelope serialization (relax SC4 byte-for-byte to "logically equivalent"). |
| A6 | `try modelContext.delete(model: T.self)` followed by `try modelContext.save()` inside a `transaction { }` block is the correct atomic-batch-delete pattern. | Pattern 2 (`resetAll`) | LOW — confirmed by `[CITED: fatbobman.com/en/snippet/how-to-batch-delete-data-in-swiftdata/]`; iOS 17.3+ supports batch delete inside transactions. |
| A7 | `ISO8601DateFormatter` with `[.withFullDate]` produces `YYYY-MM-DD` formatted dates regardless of user locale. | Code Examples 6 (filename) | LOW — Apple-canonical behavior; locale-independent ISO format. |
| A8 | `UserDefaults.standard` writes for `cloudSyncEnabled` are durable across force-quit (no explicit `synchronize()` needed on iOS 17+). | Pattern 5 | LOW — `synchronize()` was deprecated in iOS 12; `UserDefaults` writes are durable on next runloop tick. |

**If `[ASSUMED]` claims fail in practice:** A2 is the highest-risk item. If the SC3 smoke test cannot run `.private(...)` without iCloud account, fall back to running it locally on dev machines only and skipping in CI — still catches schema violations at PR review time.

## Open Questions

1. **VM injection ergonomics: `init(gameStats:)` vs `setGameStats(_:)`.**
   - What we know: D-14 specifies init injection. `MinesweeperGameView` constructs `GameStats` from `@Environment(\.modelContext)`.
   - What's unclear: whether the VM's `init` should accept `GameStats` (forces `MinesweeperGameView` to construct VM after env is resolved — awkward with `@State`) or expose a `setGameStats(_:)` method called from `.task` after first appearance.
   - **Recommendation:** Keep init injection per D-14. `MinesweeperGameView` already uses `_viewModel = State(initialValue: MinesweeperViewModel())` in `init()`; adapt to construct `GameStats` from the environment in `.onAppear` and call a small VM mutator (`viewModel.setGameStats(stats)`). Slightly relaxes D-14's pure-init injection but is iOS-17-canonical given `@State` ownership constraint. Planner picks final shape.

2. **`StatsExportEnvelope` field ordering for SC4.**
   - What we know: `.sortedKeys` enforces alphabetical order in encoded JSON.
   - What's unclear: whether the `Codable` struct's property declaration order influences anything beyond `.sortedKeys`-disabled encoding.
   - **Recommendation:** Property declaration order is irrelevant when `.sortedKeys` is set. Document property order in source for human-readability but don't depend on it.

3. **Lazy-construction pattern for `GameStats` in `MinesweeperGameView`.**
   - What we know: `@Environment(\.modelContext)` is stable across body re-renders.
   - What's unclear: whether constructing `let gameStats = GameStats(modelContext: modelContext)` inside `body` (every render) is acceptable or must be hoisted.
   - **Recommendation:** Hoist via `@State private var gameStats: GameStats?` initialized in `.onAppear` once. Avoids GC churn (Pitfall 8) and keeps a single `os.Logger` instance. Planner picks final shape.

4. **`os_log` vs `Logger` for D-15 non-fatal failure logging.**
   - What we know: D-15 says "logged via `os_log`."
   - What's unclear: literal `os_log(...)` C function vs the swiftier `Logger` from `os` module.
   - **Recommendation:** Use `Logger(subsystem:category:)` — iOS 14+ canonical, structured, supports privacy modifiers (`.public`/`.private`). The `os_log` reference in D-15 is colloquial.

5. **Per-test fresh container vs shared.**
   - What we know: `isStoredInMemoryOnly: true` gives a clean store per `ModelContainer` instance.
   - What's unclear: whether Swift Testing's parallel execution causes container-instance contention for shared schemas.
   - **Recommendation:** Per-test fresh container (build a new one in each `@Test` function). In-memory containers are cheap (~1ms init); the simplicity of fresh-per-test outweighs any performance gain. If a perf issue surfaces, switch to `@Suite.serialized` with one shared container.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Swift Testing, `@Observable`, SwiftData iOS 17 APIs | ✓ (P1+P2+P3 already on Xcode 16) | objectVersion=77 | — |
| iOS 17.0 deployment target | All P4 APIs | ✓ (FOUND-04 locked) | 17.0 | — |
| Swift 6.0 strict concurrency | `@MainActor` + Sendable enforcement | ✓ (FOUND-04 + P1 verified) | 6.0 | — |
| DesignKit (local SPM at `../DesignKit`) | StatsView + SettingsView token consumption | ✓ (P1 wired, P3 extended) | local path | — |
| iOS Simulator (UDID `51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E`) | `xcodebuild test -destination` | ✓ (P3 already runs against this) | iOS 17+ | swap simulator UDID |
| iCloud account on test machine | NOT required for P4 (smoke test uses `isStoredInMemoryOnly: true`) | n/a | — | — |
| iCloud capability provisioning (entitlements) | NOT required for P4 sync-OFF default; required at P6 | n/a in P4 | — | P6 adds capability |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

> Required (`workflow.nyquist_validation: true` confirmed in `.planning/config.json`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` / `#expect`), bundled with Xcode 16 — for `gamekitTests`. (XCTest stays available for UI / perf only — none in P4.) |
| Config file | None separate — `gamekitTests` target already exists (validated P1+P2+P3). |
| Quick run command | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E' -only-testing:gamekitTests/Core` |
| Full suite command | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` |
| Estimated runtime | ~4s quick (Core suite alone), ~35s full (gamekit + DesignKitTests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERSIST-01 / SC3 | `ModelContainer(.none)` + `ModelContainer(.private("iCloud..."))` both construct | unit (smoke) | `… -only-testing:gamekitTests/Core/ModelContainerSmokeTests` | ❌ Wave 0 |
| PERSIST-01 / SC3 | Schema is exactly `[GameRecord, BestTime]` | unit | `… -only-testing:gamekitTests/Core/ModelContainerSmokeTests/schemaIsLocked` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `record(.win)` inserts GameRecord + BestTime; calls save() | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/recordWin` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `record(.loss)` inserts GameRecord only — no BestTime | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/recordLoss` | ❌ Wave 0 |
| PERSIST-02 / SC1 | Faster win replaces existing BestTime; slower win does not | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/bestTimeOnlyOnFaster` | ❌ Wave 0 |
| PERSIST-02 / SC1 | `resetAll()` deletes both tables atomically (transaction) | unit | `… -only-testing:gamekitTests/Core/GameStatsTests/resetAllAtomic` | ❌ Wave 0 |
| PERSIST-02 | `MinesweeperViewModel` does NOT `import SwiftData` | structural | grep on production source — pre-commit ritual | ✅ existing (P3 same pattern) |
| PERSIST-03 / SC4 | 50-game export → reset → import gives byte-for-byte identical envelope | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/roundTripFifty` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Schema-version mismatch throws `StatsImportError.schemaVersionMismatch` | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/schemaVersionMismatchThrows` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Replace-on-import wipes pre-existing rows | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/replaceOnImport` | ❌ Wave 0 |
| PERSIST-03 / SC4 | Encoder is deterministic — `.sortedKeys + .iso8601 + .prettyPrinted` | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/encoderDeterministic` | ❌ Wave 0 |
| PERSIST-03 | `JSON keys` exactly match Swift property names per D-18 | unit | `… -only-testing:gamekitTests/Core/StatsExporterTests/envelopeKeysMatchSwiftProperties` | ❌ Wave 0 |
| SHELL-03 | StatsView `@Query` filter for `gameKindRaw == "minesweeper"` returns expected cohort | unit (snapshot of computed properties) | `… -only-testing:gamekitTests/Core/StatsViewModelTests/perDifficultyAggregation` (optional — UI integration is manual) | manual |
| SHELL-03 | Win % formula matches D-27 (no decimals) | unit | inline assertion in StatsView preview / `… -only-testing:gamekitTests/Core/StatsAggregationTests/winPctRounding` | optional |
| SHELL-03 | Empty state copy renders when `minesRecords.isEmpty` | manual (preview) | UI verify in 6-preset audit | manual |
| FOUND-07 | Zero `Color(...)` literals in `Screens/StatsView.swift` and `Screens/SettingsView.swift` | smoke (CI shell + `.githooks/pre-commit`) | `git diff --cached` + grep | ✅ existing |

### Sampling Rate

- **Per task commit:** `xcodebuild test … -only-testing:gamekitTests/Core` (~4s; Core test bundle).
- **Per wave merge:** Full suite (~35s; gamekit + DesignKitTests).
- **Phase gate:** Full suite green AND
  - manual force-quit-and-relaunch test (PERSIST-02 / SC5)
  - manual crash-and-relaunch test (PERSIST-02 / SC5)
  - manual device-reboot test (PERSIST-02 / SC5)
  - 6-preset theme audit screenshots in `04-VERIFICATION.md` (StatsView empty + populated; SettingsView DATA section; Reset alert active)

### Wave 0 Gaps

- [ ] `gamekit/gamekitTests/Helpers/InMemoryStatsContainer.swift` — `@MainActor enum` helper exposing `make(cloudKit:)` for test container construction
- [ ] `gamekit/gamekitTests/Core/GameStatsTests.swift` — covers PERSIST-01 + PERSIST-02 (~8 tests)
- [ ] `gamekit/gamekitTests/Core/StatsExporterTests.swift` — covers PERSIST-03 + SC4 round-trip + schemaVersion mismatch (~6 tests)
- [ ] `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` — SC3 dual-config construction (~3 tests)
- [ ] (Optional) `gamekit/gamekitTests/Core/StatsAggregationTests.swift` — pure-Swift functions extracted from StatsView for win% / best-time formatting (~3 tests; only if planner chooses to extract pure helpers)

*(Framework install: not needed — Swift Testing bundled with Xcode 16; gamekitTests target already validated P1+P2+P3.)*

### Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Force-quit survival (between games) | PERSIST-02 / SC5 | Real iOS process termination differs from simulator quit | Win a Hard game → force-quit (swipe-up + swipe-up app card) → relaunch → verify `StatsView` row shows the win |
| Crash survival | PERSIST-02 / SC5 | Real crash differs from controlled exit | Add a temporary crash-after-win debug toggle; trigger; relaunch; verify record present. Remove toggle before phase-end. |
| Device-reboot survival | PERSIST-02 / SC5 | OS-level state flush after reboot is not simulator-equivalent | Win a Hard game → reboot device → relaunch → verify record present |
| 6-preset legibility (StatsView populated) | THEME-01 / CLAUDE.md §8.12 | Visual judgment across Forest / Bubblegum / Barbie / Cream / Dracula / Voltage | Capture screenshot per preset; attach to `04-VERIFICATION.md` |
| 6-preset legibility (SettingsView DATA section) | THEME-01 / CLAUDE.md §8.12 | Same | Same |
| Reset alert reads cleanly under all 6 presets | UI-SPEC §Color | System alert chrome but row that triggers it must be unambiguous | Attach screenshot of Reset alert active per preset |
| `fileExporter` round-trip on real device | PERSIST-03 / SC4 | `.fileImporter` security-scoped resource handling differs simulator vs device | Export to Files → Reset → Import same file → verify counts + best times match (do this on a physical iPhone, not just simulator) |
| Schema-mismatch import alert appears with correct copy | D-21 | Manual JSON edit + import path | Hand-edit a known-good export to set `schemaVersion: 2`; import; verify alert matches D-21 copy |

## Security Domain

> Skipped — `security_enforcement` is not set in `.planning/config.json`, and P4 introduces no auth, no network, no secrets. PERSIST-02's "data safety" requirements are operational (force-quit survival), not security (no privilege boundaries crossed). Security domain re-enters at P6 with Sign in with Apple + CloudKit account handling.

That said, two security-adjacent notes carried forward from PITFALLS.md (verified relevant to P4):

- **Export/Import file destination:** uses user-chosen path via `fileExporter` / `fileImporter`. Never writes to a shared cache directory. Tracked under "Security Mistakes" in PITFALLS.md (already locked behavior, no action needed).
- **Privacy nutrition label:** `Data Not Collected` posture preserved — P4 adds no analytics, no telemetry, no cloud writes (`.none` default). Locked in PROJECT.md.

## Sources

### Primary (HIGH confidence)

- `[CITED: developer.apple.com/documentation/swiftdata]` — `@Model`, `@Query`, `#Predicate`, `ModelContainer`, `ModelConfiguration`, `cloudKitDatabase`
- `[CITED: developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct]` — `.private(_:)` and `.none` API surface
- `[CITED: developer.apple.com/documentation/swiftdata/modelconfiguration/isstoredinmemoryonly]` — in-memory test container pattern
- `[CITED: developer.apple.com/documentation/swiftui/view/fileexporter]` — `fileExporter` modifier signatures (FileDocument and Data overloads)
- `[CITED: developer.apple.com/documentation/swiftui/view/fileimporter]` — `fileImporter` security-scoped URL handling
- `[CITED: developer.apple.com/documentation/uniformtypeidentifiers]` — `UTType.json`
- `[CITED: developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app]` — `delete(model:)` batch API + transaction semantics
- `[VERIFIED: gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift]` — existing `@Observable @MainActor` shape, `GameOutcome`, `LossContext`, `frozenElapsed` accessor
- `[VERIFIED: gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift]` — locked `"easy"|"medium"|"hard"` raw values
- `[VERIFIED: .planning/research/ARCHITECTURE.md]` — Pattern 5 (Conditional CloudKit via ModelConfiguration swap), Pattern 2 (Game-agnostic SwiftData schema), Anti-Patterns 1+4
- `[VERIFIED: .planning/research/PITFALLS.md]` — Pitfalls 2, 3, 4, 10 (CloudKit constraints, sync silent failures, force-quit survival)
- `[VERIFIED: .planning/research/STACK.md]` — §2 SwiftData CloudKit constraints; §1 Swift 6 strict concurrency rules; §6 testing decision
- `[VERIFIED: .planning/phases/04-stats-persistence/04-CONTEXT.md]` — D-01 through D-31 locked decisions
- `[VERIFIED: .planning/phases/04-stats-persistence/04-UI-SPEC.md]` — 6/6 PASS layout contract (Grid, monoNumber, DKCard, three-row Settings card)

### Secondary (MEDIUM-HIGH confidence)

- [`hackingwithswift.com/quick-start/swiftdata` — multiple SwiftData chapters](https://www.hackingwithswift.com/quick-start/swiftdata) — verified against Apple docs for predicate syntax + iCloud sync constraints
- [`useyourloaf.com/blog/swiftui-importing-and-exporting-files`](https://useyourloaf.com/blog/swiftui-importing-and-exporting-files/) — FileDocument vs Data overload tradeoffs; current as of 2024
- [`fatbobman.com/en/snippet/how-to-batch-delete-data-in-swiftdata/`](https://fatbobman.com/en/snippet/how-to-batch-delete-data-in-swiftdata/) — `delete(model:)` batch API verified against Apple docs
- [`hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency`](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency) — `ModelContext` non-Sendable, `@MainActor` test pattern
- [`hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code`](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code) — in-memory test container pattern
- [Apple Developer Forums #731334 — SwiftData Configurations for Private and Public CloudKit](https://developer.apple.com/forums/thread/731334) — explicit `.private(containerID)` vs `.automatic` semantics
- [Apple Developer Forums #756538 — Local SwiftData to CloudKit migration](https://developer.apple.com/forums/thread/756538) — same-store path for `.none ↔ .private(...)` flips

### Tertiary (LOW confidence — flagged for validation if used)

- None — all CloudKit-compat constraints verified against multiple authoritative sources; `os.Logger` API is iOS 14+ canonical.

## Metadata

**Confidence breakdown:**

- **Schema design (CloudKit-compat constraints):** HIGH — multiply confirmed via Apple Developer Forums, Hacking With Swift, and existing PITFALLS.md research; SC3 smoke test catches violations at PR time.
- **Standard stack (`@Model`, `@Query`, `ModelContainer`, `fileExporter`):** HIGH — Apple-canonical iOS 17+; widely documented; matches existing P1–P3 conventions.
- **`GameStats` write boundary pattern:** HIGH — directly transplanted from ARCHITECTURE.md Pattern 4 + decisions D-11..D-15.
- **`StatsExporter` JSON envelope round-trip:** HIGH — `Codable` + `JSONEncoder([.prettyPrinted, .sortedKeys])` is well-trodden; Pitfall 7 + A4 captures the determinism risk.
- **`fileImporter` security-scoped resource handling:** HIGH — documented Apple behavior; Pitfall 5 captures the dev-vs-release simulator gap.
- **In-memory test container with CloudKit config:** MEDIUM — A2 captures the risk that `cloudKitDatabase: .private(...)` + `isStoredInMemoryOnly: true` may attempt a real handshake. Mitigation path is to split the test if it surfaces.
- **VM injection without SwiftData import:** HIGH — D-14 + existing P3 VM signature already supports the optional injection point.
- **Common pitfalls:** HIGH — synthesized from PITFALLS.md (already verified) + 2026-04 SwiftData community knowledge.

**Research date:** 2026-04-25
**Valid until:** 2026-05-25 (30 days; SwiftData is a stable iOS 17 API surface; iOS 18/26 may add features but won't remove iOS 17 compatibility).
