# Phase 4: Stats & Persistence - Context

**Gathered:** 2026-04-25
**Status:** Ready for research/planning

<domain>
## Phase Boundary

P4 delivers **stats persistence** for the playable Minesweeper loop shipped in P3. Two `@Model` classes, a single shared `ModelContainer` configured CloudKit-compatible from day 1 (with the actual sync OFF until P6), the StatsView reading via `@Query`, and a JSON Export/Import round-trip — all wired so terminal-state writes survive force-quit, crash, and device reboot.

**P4 ships:**
- `Core/GameRecord.swift` — `@Model final class GameRecord` (per-game record per win/loss).
- `Core/BestTime.swift` — `@Model final class BestTime` (one row per `(gameKind, difficulty)`; only-on-win-and-faster).
- `Core/GameKind.swift` — `enum GameKind: String { case minesweeper }`.
- `Core/Outcome.swift` — `enum Outcome: String { case win, loss }` (abandoned reserved for future).
- `Core/GameStats.swift` — single write-side wrapper. Public API: `record(gameKind:difficulty:outcome:durationSeconds:)` + `resetAll()`. Both call `try modelContext.save()` internally per SC1's explicit-save mandate.
- `Core/StatsExporter.swift` — sibling JSON Export/Import logic. Public API: `export(modelContext:) throws -> Data` + `importing(_ data: Data, modelContext:) throws`. Replace-on-import semantics.
- `Core/StatsExportEnvelope.swift` — shared `Codable` envelope schema used by both export and import.
- `Core/SettingsStore.swift` — `@Observable final class` over `UserDefaults` exposing `cloudSyncEnabled: Bool` (defaults to `false` in P4; flipped on in P6 PERSIST-04).
- `App/GameKitApp.swift` edit — construct shared `ModelContainer` with `cloudKitDatabase: cloudSyncEnabled ? .private("iCloud.com.lauterstar.gamekit") : .none`; inject into environment via `.modelContainer(...)`.
- `Games/Minesweeper/MinesweeperViewModel.swift` edit — accept injected optional `gameStats: GameStats?` via init; `recordTerminalState()` private helper called from terminal-state transition writes one `GameRecord`. VM **does not import SwiftData** — `GameStats` is the boundary per ARCHITECTURE.md.
- `Screens/StatsView.swift` edit — replace P1 stub with real per-difficulty rows; `@Query` filtered by `gameKindRaw == "minesweeper"`; empty state copy.
- `Screens/SettingsView.swift` edit — three rows: **Export stats** (`fileExporter`), **Import stats** (`fileImporter`), **Reset stats** (`.alert(role: .destructive)`).
- `Resources/Localizable.xcstrings` edit — empty-state copy, settings rows, alert text, error toasts.
- Tests: `gamekitTests/Core/GameStatsTests.swift`, `StatsExporterTests.swift`, `ModelContainerSmokeTests.swift` — Swift Testing, in-memory `ModelContainer`.

**Out of scope for P4** (owned by later phases):
- Sign in with Apple sign-in card on Settings + intro (PERSIST-05 → P6)
- Actual CloudKit sync turned on (PERSIST-04 → P6)
- Anonymous-to-signed-in data promotion (PERSIST-06 → P6)
- 3-step intro flow (SHELL-04 → P5)
- Animation pass / haptics on win-screen (MINES-08/09 → P5)
- Schema migration plan (only V1 ships in P4; lightweight migration via `SchemaMigrationPlan` is a future-phase concern)

**v1 ROADMAP P4 success criteria carried forward as locked specs (no re-asking):**
- SC1 — Hard win/loss writes `GameRecord` + updates `BestTime` synchronously via explicit `try modelContext.save()` in `GameStats`; force-quit-and-relaunch shows record present.
- SC2 — StatsView per-difficulty rows (games · wins · win % · best time); `@Query` filtered by `gameKindRaw == "minesweeper"`; explicit empty state ("No games played yet…").
- SC3 — `ModelContainer` constructs successfully under `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` even with sync OFF — smoke test catches schema constraint violations (no `@Attribute(.unique)`, all properties optional/defaulted, all relationships optional, `schemaVersion: Int = 1`) the moment they land.
- SC4 — Export 50-game stats set via `fileExporter`, reset, re-import via `fileImporter`; counts + best times byte-for-byte match. `schemaVersion` survives the round-trip.
- SC5 — Stats persist across force-quit / crash / device reboot — manual QA pass.

</domain>

<decisions>
## Implementation Decisions

### Schema (PERSIST-01)
- **D-01:** Two `@Model` classes ship in `Core/`: `GameRecord` (per win/loss event) and `BestTime` (one row per `(gameKind, difficulty)`). Both **CloudKit-compatible from day 1** per ARCHITECTURE.md: every property is optional or defaulted, no `@Attribute(.unique)`, every relationship optional (none in V1), `schemaVersion: Int = 1` on both.
- **D-02:** `GameRecord` shape:
  ```swift
  @Model final class GameRecord {
      var id: UUID = UUID()
      var gameKindRaw: String = GameKind.minesweeper.rawValue
      var difficultyRaw: String = ""             // matches MinesweeperDifficulty.rawValue: "easy"|"medium"|"hard" (P2 D-02)
      var outcomeRaw: String = ""                // "win" | "loss"
      var durationSeconds: Double = 0
      var playedAt: Date = .now
      var schemaVersion: Int = 1
  }
  ```
  Computed accessors `var gameKind: GameKind` and `var outcome: Outcome` defaulted to safe fallbacks.
- **D-03:** `BestTime` shape **(per W-confirmed: one row per (gameKind, difficulty); only-on-win-and-faster; no recordId backreference):**
  ```swift
  @Model final class BestTime {
      var id: UUID = UUID()
      var gameKindRaw: String = GameKind.minesweeper.rawValue
      var difficultyRaw: String = ""
      var seconds: Double = 0
      var achievedAt: Date = .now
      var schemaVersion: Int = 1
  }
  ```
  No `recordId: UUID?` backreference — kept minimal. StatsView shows "Best: 1:42" (no "set [date]" affordance in P4; can be derived from `achievedAt` later if a Polish phase wants it).
- **D-04:** `GameKind: String { case minesweeper }` and `Outcome: String { case win, loss }` ship in `Core/`. `Outcome.abandoned` is **deferred** — P3 doesn't record abandoned games today (Restart resets state without writing), so P4 ships only `win` and `loss`. Adding `.abandoned` later is additive, schema-safe.
- **D-05:** `MinesweeperDifficulty.rawValue` (locked P2 D-02 as `"easy" | "medium" | "hard"`) is the **canonical serialization key** for `difficultyRaw` on both `GameRecord` and `BestTime`. Renaming a case = data break — locked since P2.
- **D-06:** No `@Attribute(.unique)` on any property. Both models rely on `id: UUID = UUID()` for identity. CloudKit syncs duplicates if multi-device writes collide; resolution is a P6 concern.

### ModelContainer + CloudKit feature flag (PERSIST-01, SC3)
- **D-07:** Single shared `ModelContainer` constructed in `GameKitApp` with schema `[GameRecord.self, BestTime.self]` and a single `ModelConfiguration`. Injected app-wide via `.modelContainer(sharedContainer)` on the root scene.
- **D-08:** `ModelConfiguration` reads `cloudSyncEnabled: Bool` from `SettingsStore` at startup:
  ```swift
  ModelConfiguration(
      schema: schema,
      cloudKitDatabase: settingsStore.cloudSyncEnabled
          ? .private("iCloud.com.lauterstar.gamekit")
          : .none
  )
  ```
  In P4 the flag defaults to `false`; the `.private(...)` branch never executes in production yet. P6 flips the default once Sign in with Apple lands.
- **D-09:** **CloudKit container ID is locked: `iCloud.com.lauterstar.gamekit`** (matches PROJECT.md and bundle ID `com.lauterstar.gamekit`). Pinned in `PROJECT.md` and the smoke test (D-23) so any later rename causes a deliberate test failure, not silent breakage.
- **D-10:** SC3 smoke test (`ModelContainerSmokeTests.swift`) constructs **both** configurations (`.none` and `.private("iCloud.com.lauterstar.gamekit")`) successfully — even though sync is OFF in production. Catches schema constraint violations (e.g., somebody adding `@Attribute(.unique)`) at PR time.

### GameStats wrapper (PERSIST-02 + SC1)
- **D-11:** `Core/GameStats.swift` is the **single write-side boundary** between gameplay and SwiftData. Public API (per W-confirmed):
  ```swift
  final class GameStats {
      init(modelContext: ModelContext)
      func record(gameKind: GameKind, difficulty: String,
                  outcome: Outcome, durationSeconds: Double) throws
      func resetAll() throws
  }
  ```
  Both methods call `try modelContext.save()` internally — explicit save satisfies SC1's literal mandate.
- **D-12:** `record(...)` insertion logic:
  1. `modelContext.insert(GameRecord(...))`.
  2. **If `outcome == .win`:** look up existing `BestTime` by `(gameKindRaw, difficultyRaw)` predicate; if none OR `durationSeconds < existing.seconds`, write/update (`modelContext.insert(BestTime(...))` for new, mutate `seconds` + `achievedAt` for existing).
  3. `try modelContext.save()`.
  4. Loss → no `BestTime` write.
- **D-13:** `resetAll()` deletes **both** `GameRecord` and `BestTime` rows in a single `modelContext.transaction { ... }` block, then calls `try modelContext.save()`. Atomic — partial reset is impossible.
- **D-14:** `GameStats` is **injected** into `MinesweeperViewModel` via init: `init(..., gameStats: GameStats? = nil)`. Tests pass `nil`; production passes the live `GameStats` resolved from environment in `MinesweeperGameView`. The VM **does NOT import SwiftData** — `GameStats` is the boundary per ARCHITECTURE.md.
- **D-15:** VM call site: a private `recordTerminalState()` helper invoked from inside the existing `.playing → .won` and `.playing → .lost` transitions in `reveal(at:)`. Wraps `try? gameStats?.record(...)` — failure is logged via `os_log` and the user-facing UI continues to render the terminal state (gameplay is never blocked by a persistence failure).

### StatsExporter (PERSIST-03 + SC4)
- **D-16:** Export/Import logic ships in **`Core/StatsExporter.swift`** (sibling to `GameStats`, per W-confirmed). Single responsibility per class — `GameStats` writes gameplay records, `StatsExporter` handles file I/O. Public API:
  ```swift
  enum StatsExporter {
      static func export(modelContext: ModelContext) throws -> Data
      static func importing(_ data: Data, modelContext: ModelContext) throws
  }
  ```
  Static / `enum`-namespace because there is no ivar state; matches the pattern P2 used for engine namespaces.
- **D-17:** **Envelope shape** (per W-confirmed: single JSON object, replace-on-import):
  ```json
  {
    "schemaVersion": 1,
    "exportedAt": "2026-04-25T19:30:00Z",
    "gameRecords": [ /* GameRecord-shaped objects */ ],
    "bestTimes":   [ /* BestTime-shaped objects */ ]
  }
  ```
  `Codable` struct `StatsExportEnvelope` lives in `Core/StatsExportEnvelope.swift` next to the exporter so both sides reference the same source-of-truth.
- **D-18:** `gameRecords` and `bestTimes` arrays serialize the `@Model` raw fields directly: `id`, `gameKindRaw`, `difficultyRaw`, `outcomeRaw`/`seconds`, `durationSeconds`/`achievedAt`, `playedAt`, `schemaVersion`. JSON keys = Swift property names. `Date` encoded ISO8601, `UUID` lowercased canonical form. Encoder uses `.iso8601` date strategy and `.prettyPrinted` for human-readable exports.
- **D-19:** **Filename pattern: `gamekit-stats-YYYY-MM-DD.json`** generated at export time from `Date.now`. UTI = `public.json`. `fileExporter` document `contentTypes: [.json]`.
- **D-20:** **Import collision policy = REPLACE.** `StatsExporter.importing(_:modelContext:)` runs in a single `modelContext.transaction { ... }`:
  1. **Validate `schemaVersion == 1`** — if mismatch, throw `StatsImportError.schemaVersionMismatch(found: Int, expected: 1)` and abort the transaction.
  2. Delete all existing `GameRecord` and `BestTime` rows.
  3. Decode and `insert` all envelope rows.
  4. `try modelContext.save()`.
  Replace-on-import is the simplest semantic that satisfies SC4's "byte-for-byte" round-trip guarantee.
- **D-21:** Settings UI presents the schema-mismatch error as `.alert("Couldn't import stats", role: .destructive)` with body `"This file was exported from a newer GameKit. Update the app and try again."` and a single "OK" button. Existing data stays intact (transaction abort).

### Reset Stats UX (PERSIST-02 supporting)
- **D-22:** Settings → "Reset stats" row → single `.alert("Reset all stats?", role: .destructive)` with **Cancel** + **Reset all stats** buttons (per W-confirmed). Tap Reset → `GameStats.resetAll()` (D-13) — wipes both `GameRecord` and `BestTime` in one transaction. Per CLAUDE.md §1 "never delete user data automatically": the alert is the explicit consent gate.
- **D-23:** Alert body copy: `"This deletes all your Minesweeper games and best times. This can't be undone."` — direct, non-scolding. No "Export first?" nudge in the alert (per W-confirmed simpler path); user can Export from the same Settings screen if they want a backup before resetting.

### Stats screen (SC2 + SHELL-03)
- **D-24:** `StatsView` reads via `@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" }, sort: \.playedAt, order: .reverse) private var minesRecords: [GameRecord]` and `@Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "minesweeper" }) private var minesBestTimes: [BestTime]`. View derives per-difficulty rows in pure-SwiftUI computed properties — no imperative aggregation, no separate ViewModel for stats yet (StatsView stays small per CLAUDE.md §8.2 "data-driven, not data-fetching").
- **D-25:** Per-difficulty row layout: 4 columns — **games · wins · win % · best time**. One row per `MinesweeperDifficulty` case (Easy / Medium / Hard) **always rendered**, even when zero records — per-difficulty empty cell shows `"—"` for missing best time and `0` for counts. The 3 rows live inside a `DKCard` with a section header "Minesweeper".
- **D-26:** **Empty state copy:** when `minesRecords.isEmpty` the card replaces the table with a single line `"No games played yet."` (matches SC2 literal). Per-difficulty empty rows ("No Hard games yet") deferred — single global empty state is calmer.
- **D-27:** Win % display: integer percent with no decimals (`Int(round(wins * 100.0 / games))`), trailing `%`. Falls back to `"—"` when `games == 0`. Calmer than 1-decimal precision; matches the "premium minimal" PROJECT.md tone.

### SettingsStore (P4 surface)
- **D-28:** `Core/SettingsStore.swift` ships as an `@Observable final class` over `UserDefaults.standard`. P4 exposes one flag: `cloudSyncEnabled: Bool` (key `gamekit.cloudSyncEnabled`, defaults to `false`). Future flags (`hapticsEnabled`, `sfxEnabled`, `hasSeenIntro`) ship in P5.
- **D-29:** `SettingsStore` is **constructed at app startup** in `GameKitApp` and injected via `.environment(\.settingsStore, settingsStore)` (custom `EnvironmentKey`). The store's `cloudSyncEnabled` is read **once at container construction** for D-08 — flipping it later requires app relaunch (acceptable for v1; no live migration needed).

### Test depth
- **D-30:** Test framework = Swift Testing, matching P2/P3 convention. New test files:
  - `gamekitTests/Core/GameStatsTests.swift` — record/resetAll happy paths + BestTime only-on-win-and-faster + transaction atomicity (~8 tests).
  - `gamekitTests/Core/StatsExporterTests.swift` — round-trip 50-record envelope (SC4) + schemaVersion mismatch error (SC4 negative path) + replace-on-import wipes existing rows + envelope JSON encoding/decoding determinism (~6 tests).
  - `gamekitTests/Core/ModelContainerSmokeTests.swift` — both `.none` and `.private("iCloud.com.lauterstar.gamekit")` configurations construct without throwing (SC3 — even though sync OFF) (~3 tests).
- **D-31:** Tests use **in-memory `ModelContainer`**: `ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))` per `Helpers/InMemoryStatsContainer.swift`. No simulator state pollution between runs. CloudKit smoke test uses `cloudKitDatabase: .private(...)` configuration but `isStoredInMemoryOnly: true` so iCloud is never actually contacted in CI.

### Claude's Discretion
The user did not lock the following — planner has flexibility but should align with research / CLAUDE.md / ARCHITECTURE.md:

- **Exact `@Query` predicate syntax** — `#Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" }` per arch; planner may use `KeyPath`-based descriptors if SwiftData 2.0 docs prefer.
- **StatsView visual layout** — DKCard with table grid vs `Grid` layout vs aligned `HStack` rows. UI-SPEC contract owns this.
- **Whether `cloudSyncEnabled` is mutable in P4 Settings** — recommend NO surface in P4 (the row exists in P6 next to Sign in with Apple). The flag is read at construction (D-29) and the toggle UX requires the sign-in card; deferring to P6 is cleaner.
- **`Outcome.abandoned` reservation** — recommend ship `case win, loss` only; document in code comment that abandoned is reserved for a future phase (chord-reveal v2 backlog item) so adding it later is additive.
- **`fileExporter` / `fileImporter` modal vs sheet UX** — both are standard iOS document pickers; either works. Recommend `fileExporter` from a Settings button tap with `defaultFilename: "gamekit-stats-\(ISO8601 date).json"`.
- **Loss + best-time interaction at write time** — `record(...)` writes the GameRecord first, then evaluates BestTime; if BestTime lookup throws, GameRecord still persists (best-effort BestTime). Recommend: wrap BestTime write in `do/catch` inside `record(...)` so a flaky predicate doesn't block GameRecord persistence.
- **SchemaVersion bump policy** — P4 ships v1 only. Adding properties later (additive) doesn't require a bump under SwiftData lightweight migration. A bump is only needed when removing or renaming. Document in `04-NOTES.md` that bumps are deliberate.
- **Where `GameStats` is constructed** — recommend lazy in `MinesweeperGameView` body using the `@Environment(\.modelContext)` accessor: `let gameStats = GameStats(modelContext: modelContext); MinesweeperViewModel(..., gameStats: gameStats)` inside `@State private var viewModel: MinesweeperViewModel = ...`. Single place. No singleton.
- **Export timestamp timezone** — recommend ISO8601 in UTC (`Z` suffix) for cross-device portability when CloudKit lands. Local-time display is a presentation concern in StatsView, not a serialization one.

### Folded Todos
None — STATE.md `Pending Todos` is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules + invariants
- `CLAUDE.md` — Project constitution (§1 stack/data-safety/no-Color, §2 DesignKit conventions, §4 promote-when-proven, §5 tests-in-same-commit, §8.5 file caps, §8.10 atomic commits)
- `AGENTS.md` — Mirror of CLAUDE.md
- `.planning/PROJECT.md` — Vision + non-negotiables (calm/ad-free/offline-first; CloudKit container ID `iCloud.com.lauterstar.gamekit`)
- `.planning/REQUIREMENTS.md` — PERSIST-01/02/03 + SHELL-03 full text
- `.planning/ROADMAP.md` — Phase 4 entry: goal, SC1–SC5, dependency on Phase 3

### Architecture + research
- `.planning/research/ARCHITECTURE.md` — Schema spec (`@Model GameRecord`, `BestTime`, `cloudKitDatabase` feature-flag), Component Responsibilities table (GameStats / SettingsStore boundaries), Component diagram showing the SwiftData+CloudKit row
- `.planning/research/PITFALLS.md` — Known traps (CloudKit constraint violations; SwiftData migration brittleness)
- `.planning/research/STACK.md` — SwiftUI + SwiftData + iOS 17+ stack constraints

### Engine API + prior decisions (consumed, do not modify)
- `.planning/phases/02-mines-engines/02-CONTEXT.md` — Locked engine API (D-02 `MinesweeperDifficulty.rawValue` strings — canonical serialization key for P4 `difficultyRaw` per D-05)
- `.planning/phases/02-mines-engines/02-VERIFICATION.md` — Engine guarantees consumed by VM
- `.planning/phases/03-mines-ui/03-CONTEXT.md` — VM contract (D-11 UserDefaults key precedent for `mines.lastDifficulty`); P3 VM is the call site for `recordTerminalState()` per D-15
- `.planning/phases/03-mines-ui/03-VERIFICATION.md` — VM API surface verified

### Existing source files (read-only context — edited or wrapped, not duplicated)
- `gamekit/gamekit/App/GameKitApp.swift` — Where the shared `ModelContainer` lands (D-07), `SettingsStore` constructed (D-29)
- `gamekit/gamekit/Screens/StatsView.swift` — Phase 1 stub; P4 replaces with real `@Query` rows (D-24..D-27)
- `gamekit/gamekit/Screens/SettingsView.swift` — Phase 1 themed-scaffold stub; P4 adds Export / Import / Reset rows (D-22..D-23)
- `gamekit/gamekit/Screens/SettingsComponents.swift` — Existing row-component patterns to reuse for new Settings rows
- `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` — Where the `gameStats: GameStats?` injection point lands (D-14, D-15)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` — Where `GameStats` is constructed and passed to the VM (Discretion)
- `gamekit/gamekit/Resources/Localizable.xcstrings` — Empty-state + alert + error copy (auto-extracted from `String(localized:)`)

### DesignKit (sibling SPM — read but do not duplicate)
- `../DesignKit/Sources/DesignKit/Components/DKCard.swift` — Wraps the StatsView per-difficulty card (D-25)
- `../DesignKit/Sources/DesignKit/Components/DKBadge.swift` — Possible win % chip styling (Discretion)
- `../DesignKit/Sources/DesignKit/Theme/Tokens.swift` — Verify token surface for new Settings rows + StatsView typography
- `../DesignKit/Sources/DesignKit/Components/DKSectionHeader.swift` — Stats card section header

</canonical_refs>

<specifics>
## Specific Ideas

- Settings row labels: **"Export stats"**, **"Import stats"**, **"Reset stats"** (verb-first; consistent with existing Settings convention).
- Reset alert: title `"Reset all stats?"`; body `"This deletes all your Minesweeper games and best times. This can't be undone."`; buttons `"Cancel"` + `"Reset all stats"` (destructive).
- Schema-mismatch import alert: title `"Couldn't import stats"`; body `"This file was exported from a newer GameKit. Update the app and try again."`; single `"OK"` button.
- Empty state: `"No games played yet."` (matches SC2 verbatim).
- StatsView row format: `"Easy   12   8   67%   1:42"` (4 columns aligned with monospaced numerals via `theme.typography.monoNumber` to prevent jitter when stats update).
- Best time format: `mm:ss` for elapsed < 60min; `h:mm:ss` if > 60min (matches P3 timer display format).
- Export JSON pretty-printed (human-readable; user might inspect the file).
- Export filename: `gamekit-stats-YYYY-MM-DD.json` from `Date.now` formatted ISO8601-date in user's locale.
- StatsExportEnvelope `exportedAt` field is ISO8601 UTC with `Z` suffix (Discretion lock for cross-device CloudKit portability).
- `GameKind: String { case minesweeper }` ships solo in P4 — `case sudoku, nonogram, …` are added in their respective game phases (additive, schema-safe).

</specifics>

<deferred>
## Deferred Ideas

- **`recordId: UUID?` backreference on BestTime** — would let StatsView show "Best: 1:42 (set 2026-04-25)". Defer until a polish phase explicitly wants the affordance; minimal schema today is calmer.
- **Per-difficulty empty state copy** ("No Hard games yet") — defer to a polish phase; single global empty state is enough for v1.
- **Reset alert "Export first?" nudge** — adds a calm UX moment but introduces a 3-button alert. Skipped for simpler-path-by-default; user can Export from the same Settings screen one row above.
- **`Outcome.abandoned`** — reserved enum case for a future phase if Restart/abandon is to be tracked. Not added in P4 (additive change is schema-safe).
- **Sign in with Apple sign-in card on Settings + intro** — P6 (PERSIST-04/05/06).
- **CloudKit sync turned ON by default** — P6.
- **Anonymous→signed-in data promotion** — P6.
- **Schema migration plan (`SchemaMigrationPlan`)** — P4 ships V1 only. Lightweight migration handles additive changes; a versioned migration plan is added when V2 is actually drafted.
- **Streaming JSON Lines export format** — would be useful at huge histories (>10k games), unrealistic for v1; the single-envelope replace-on-import semantic is simpler and matches SC4 byte-for-byte goal.
- **Import collision merge-by-id mode** — defer to P6 once CloudKit cross-device merge edge cases surface; replace-on-import covers the v1 single-device case.
- **Error toast after successful Export** ("Saved to Files") — minor polish; defer to P5.
- **Reset Stats undo (5-second snackbar)** — would soften the destructive action but adds state machine complexity; the alert is sufficient for v1.

</deferred>

---

*Phase: 04-stats-persistence*
*Context gathered: 2026-04-25*
