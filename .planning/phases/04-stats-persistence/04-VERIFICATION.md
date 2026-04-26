---
phase: 04-stats-persistence
status: passed
verified_by: user
verified_on: 2026-04-26
manual_sections:
  - sec1_force_quit_simulator
  - sec2_crash_simulator
  - sec3_device_reboot_physical
  - sec4_statsview_6_preset_matrix
  - sec5_settingsview_6_preset_matrix
  - sec6_alerts_copy
  - sec7_fileexporter_round_trip
  - sec8_voiceover_partial
goal_backward_status: passed
goal_backward_score: 5/5 success criteria verified
goal_backward_verified_on: 2026-04-26T11:15:00Z
---

# Phase 4 — Manual Verification Report

User-confirmed pass on 2026-04-26 ("verified") across all 8 manual verification sections specified in 04-06-PLAN Task 1.

## Sections

| # | Behavior | Requirement | Result |
|---|---|---|---|
| 1 | Force-quit survival on Simulator (write → terminate → relaunch → row present) | PERSIST-02 / SC1 / SC5 | ✅ user-verified |
| 2 | Crash-after-record-save survival on Simulator (temp toggle removed before phase end) | PERSIST-02 / SC5 | ✅ user-verified |
| 3 | Device-reboot survival on physical iPhone | PERSIST-02 / SC5 | ✅ user-verified |
| 4 | StatsView 6-preset matrix (forest/bubblegum/barbie/cream/dracula/voltage; empty + populated) | THEME-01 + CLAUDE.md §8.12 | ✅ user-verified |
| 5 | SettingsView DATA section 6-preset matrix | THEME-01 + CLAUDE.md §8.12 | ✅ user-verified |
| 6 | Reset alert + schema-mismatch import alert verbatim copy + transaction abort | D-21 / D-22 / D-23 / SC4 | ✅ user-verified |
| 7 | `fileExporter`/`fileImporter` round-trip on physical device (security-scoped URL bookends) | PERSIST-03 / SC4 | ✅ user-verified |
| 8 | VoiceOver StatsView combined-phrase row reading | A11Y-02 partial | ✅ user-verified |

## Notes

- Automated battery (Wave-0 + per-wave full suite) ran green in Plans 04-01..04-05 — see commit history `be5da5f..5dd8942`.
- Section 2's temporary `#if DEBUG ... fatalError("P4-06 verification") #endif` toggle was removed before phase close; clean-tree grep confirmed no stale `P4-06 verification` matches in `MinesweeperViewModel.swift`.
- This file closes the Plan 04-06 checkpoint gate; the goal-backward verifier will append automated artifact verification below.

---

# Phase 4 — Goal-Backward Verification (Automated)

**Verified:** 2026-04-26
**Goal:** Stats survive force-quit / crash / reboot, schema is CloudKit-compatible from day 1, and the Stats screen reads the persisted truth.
**Status:** passed (5/5 ROADMAP success criteria + 4/4 P4 requirements)

## Observable Truths (Goal-Backward from ROADMAP P4 Success Criteria)

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|---|---|---|
| SC1 | Hard win/loss writes `GameRecord` and updates `BestTime` synchronously via explicit `try modelContext.save()` on terminal-state detection; force-quit immediately after game-over preserves the record. | ✓ VERIFIED | `GameStats.swift:101` calls `try modelContext.save()` after every `record(...)`; `GameStats.swift:114` does the same in `resetAll()`. `MinesweeperViewModel.swift:271-278` invokes `recordTerminalState(...)` from both `.lost` and `.won` transitions (lines 162, 166), wired via the optional `gameStats: GameStats?` injection seam (line 104, attached one-shot at `MinesweeperGameView.swift:127-135` `.task`). `GameStatsTests/recordWin`, `recordLoss`, `bestTimeOnlyOnFaster`, `equalSecondsIsNoop` all pass. Manual force-quit pass in §1. |
| SC2 | Stats screen shows per-difficulty rows (games / wins / win % / best time) populated from `@Query` filtered by `gameKindRaw == "minesweeper"`; explicit empty state copy. | ✓ VERIFIED | `StatsView.swift:44-49` uses `@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" }, sort: \.playedAt, order: .reverse)`; `StatsView.swift:51-52` queries `BestTime` with the same predicate. Empty state at `StatsView.swift:99` renders the literal `"No games played yet."` (verbatim with the SC). 3 always-rendered difficulty rows iterated via `ForEach(MinesweeperDifficulty.allCases)` at line 130, satisfying D-25 ("3 always-rendered rows"). Catalog entry confirmed at `Localizable.xcstrings`. |
| SC3 | `ModelContainer` constructs successfully when configured with `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")`; smoke test catches schema constraint violations (no `@Attribute(.unique)`, all properties optional/defaulted, all relationships optional, `schemaVersion: Int = 1`). | ✓ VERIFIED | `ModelContainerSmokeTests.swift` runs both `.none` (line 43) and `.private("iCloud.com.lauterstar.gamekit")` (line 52) constructions plus a schema-lock assertion (line 64). All three cases passed in the live `xcodebuild test` run (see Behavioral Spot-Check below). `GameRecord.swift:38-67` and `BestTime.swift:34-57` both confirm: every property defaulted, no `@Attribute(.unique)` decorator anywhere in `Core/`, zero relationships, and `schemaVersion: Int = 1` on both models. |
| SC4 | Export to JSON via `fileExporter` and re-import via `fileImporter` produces a byte-for-byte round-trip including `schemaVersion`. | ✓ VERIFIED | `StatsExporter.swift:91-94` configures `JSONEncoder` with `.iso8601 + [.prettyPrinted, .sortedKeys]` (RESEARCH Pitfall 7). Decode-validate-transaction order at lines 108-166: schemaVersion mismatch (line 126) throws BEFORE the destructive `transaction { delete; insert }` block (line 134). UUID + per-row schemaVersion preserved across round-trip (lines 146-147, 157-158). `StatsExporterTests/roundTripFifty` proves byte-equality with 50 records sorted by id; `schemaVersionMismatchThrows` proves existing data UNTOUCHED on a future-schema envelope. Both pass. Manual §6 + §7 confirm physical-device behavior. |
| SC5 | Stats persist across app force-quit, crash, and device reboot. | ✓ VERIFIED | All three scenarios passed in manual verification §1 (force-quit, simulator), §2 (crash via temporary `fatalError`, simulator; toggle removed before close), §3 (device reboot, physical iPhone). The synchronous `try modelContext.save()` in both `GameStats.record(...)` (line 101) and `StatsExporter.importing(...)` (line 165) guarantees pre-termination flush. |

**Score:** 5/5 ROADMAP P4 success criteria verified.

## Required Artifacts (Three-Level Check)

| Artifact | Expected | Exists | Substantive | Wired | Status |
|----------|----------|--------|-------------|-------|--------|
| `Core/GameKind.swift` | `enum GameKind: String { case minesweeper }` Foundation-only | ✓ | ✓ (26 lines, locked rawValue per D-04) | ✓ (consumed by GameRecord/BestTime/StatsExportEnvelope/GameStats) | ✓ VERIFIED |
| `Core/Outcome.swift` | `enum Outcome: String { case win, loss }` Foundation-only | ✓ | ✓ (26 lines) | ✓ (consumed by GameRecord/StatsExportEnvelope/GameStats) | ✓ VERIFIED |
| `Core/GameRecord.swift` | `@Model final class` with all defaulted properties + `schemaVersion: Int = 1` | ✓ | ✓ (68 lines, every property defaulted, no `@Attribute(.unique)`) | ✓ (queried in StatsView.swift:44-49; written in GameStats.swift:71-78; mirrored in StatsExportEnvelope.Record) | ✓ VERIFIED |
| `Core/BestTime.swift` | `@Model final class` with all defaulted properties + `schemaVersion: Int = 1` | ✓ | ✓ (57 lines, faster-only enforced via GameStats logic, not a unique decorator) | ✓ (queried in StatsView.swift:51-52; written in GameStats.swift:146-152; mirrored in StatsExportEnvelope.Best) | ✓ VERIFIED |
| `Core/GameStats.swift` | Public `record(...)` + `resetAll()`, both with sync save, @MainActor | ✓ | ✓ (155 lines, sync save at lines 101 + 114, `evaluateBestTime` faster-only with strict `<` at line 141) | ✓ (constructed in MinesweeperGameView.swift `.task`; injected via `attachGameStats(...)` one-shot; also constructed in SettingsView.swift:91 for resetAll, line 197 for importing path) | ✓ VERIFIED |
| `Core/StatsExportEnvelope.swift` | `Codable + Sendable + Equatable` envelope mirroring both @Model types | ✓ | ✓ (62 lines, JSON keys = Swift property names per D-18) | ✓ (encoded in StatsExporter.export, decoded in StatsExporter.importing) | ✓ VERIFIED |
| `Core/StatsImportError.swift` | `LocalizedError + Equatable` with localized strings | ✓ | ✓ (39 lines, schemaVersionMismatch + decodeFailed + fileReadFailed) | ✓ (thrown by StatsExporter.importing; consumed by SettingsView.swift:199-202) | ✓ VERIFIED |
| `Core/StatsExportDocument.swift` | `FileDocument` wrapping JSON Data for `.fileExporter` | ✓ | ✓ (48 lines) | ✓ (constructed in SettingsView.swift:181, bound to `.fileExporter` at line 70) | ✓ VERIFIED |
| `Core/StatsExporter.swift` | `enum` namespace with `export(modelContext:)` + `importing(_:modelContext:)` + filename helper | ✓ | ✓ (178 lines, decode→validate→transaction order, sortedKeys+iso8601+prettyPrinted, sync save) | ✓ (called from SettingsView.swift:180 export, :197 import, :72 filename) | ✓ VERIFIED |
| `Core/SettingsStore.swift` | `@Observable @MainActor` UserDefaults wrapper exposing `cloudSyncEnabled` + EnvironmentKey | ✓ | ✓ (78 lines, custom `EnvironmentKey` per RESEARCH §Pattern 5) | ✓ (constructed in GameKitApp.init; injected via `.environment(\.settingsStore, …)` at line 70; read at line 51 to drive `cloudKitDatabase` ternary) | ✓ VERIFIED |
| `App/GameKitApp.swift` (edit) | Shared `ModelContainer` constructed once with `cloudKitDatabase` ternary; `.modelContainer(...)` injection | ✓ | ✓ (83 lines, single shared container, do/catch with fatalError per RESEARCH §Code Examples 1) | ✓ (`.modelContainer(sharedContainer)` at line 72; ThemeManager + SettingsStore environment seams preserved) | ✓ VERIFIED |
| `Screens/StatsView.swift` (rewrite) | @Query rows + empty state + 3 always-rendered difficulty rows | ✓ | ✓ (234 lines, GridRow + DKCard + theme tokens only) | ✓ (rendered from RootTabView; `@Query` reads container injected by App scene) | ✓ VERIFIED |
| `Screens/SettingsView.swift` (edit) | DATA section: 3 rows + 3 alerts + `.fileExporter`/`.fileImporter` with security-scoped URL bookends | ✓ | ✓ (239 lines, `startAccessingSecurityScopedResource()` + `defer stopAccessing` at lines 193-194 per RESEARCH Pitfall 5) | ✓ (rendered from RootTabView; modelContext from environment) | ✓ VERIFIED |
| `Games/Minesweeper/MinesweeperViewModel.swift` (edit) | 5th injection seam `gameStats: GameStats? = nil`; `recordTerminalState()` private helper called from terminal transitions | ✓ | ✓ (5th init param at line 104; one-shot `attachGameStats` at lines 125-128; `recordTerminalState` calls at lines 162 + 166; helper at lines 271-278; **VM imports only Foundation** at line 20 — no SwiftData) | ✓ (attached at MinesweeperGameView.swift:127-135 `.task`) | ✓ VERIFIED |
| `Games/Minesweeper/MinesweeperGameView.swift` (edit) | `.task { GameStats(modelContext:); attachGameStats(...) }` one-shot per scene | ✓ | ✓ (lines 127-135, guarded by `didInjectStats` flag) | ✓ (RESEARCH Pitfall 8 — no per-render allocation) | ✓ VERIFIED |
| `Resources/Localizable.xcstrings` | All P4 user-facing strings auto-extracted | ✓ | ✓ (catalog contains "No games played yet.", "DATA", "Export stats", "Import stats", "Reset stats", "Reset all stats?", "Reset all stats", "Couldn't import stats", "This deletes all your Minesweeper games and best times. This can't be undone.", "This file was exported from a newer GameKit. Update the app and try again.", "The file couldn't be read. Check that it's a GameKit stats export and try again.") | ✓ (FOUND-05 / SWIFT_EMIT_LOC_STRINGS=YES — auto-extracted) | ✓ VERIFIED |
| `gamekitTests/Helpers/InMemoryStatsContainer.swift` | Test-only factory with `isStoredInMemoryOnly: true` + optional cloudKit param | ✓ | ✓ (48 lines, @MainActor enum) | ✓ (consumed by ModelContainerSmokeTests + GameStatsTests + StatsExporterTests) | ✓ VERIFIED |
| `gamekitTests/Core/ModelContainerSmokeTests.swift` | Dual-config construction + schema lock | ✓ | ✓ (3 cases) | ✓ (all 3 PASS in live test run) | ✓ VERIFIED |
| `gamekitTests/Core/GameStatsTests.swift` | record/resetAll/BestTime-only-on-faster coverage | ✓ | ✓ (8 cases) | ✓ (all 8 PASS in live test run) | ✓ VERIFIED |
| `gamekitTests/Core/StatsExporterTests.swift` | Round-trip-50 byte-equal + schema-mismatch + replace-on-import + encoder-determinism + filename | ✓ | ✓ (7 cases) | ✓ (all 7 PASS in live test run) | ✓ VERIFIED |

**File-size cap (CLAUDE.md §8.5 / §8.1):** every P4 file ≤239 lines. No file exceeds the 400-line soft cap or 500-line hard cap.

## Key Link Verification (Wiring)

| From | To | Via | Status | Detail |
|------|----|-----|--------|--------|
| `MinesweeperGameView.body.task` | `MinesweeperViewModel.attachGameStats(_:)` | one-shot construction `GameStats(modelContext: modelContext)` | ✓ WIRED | `MinesweeperGameView.swift:127-135` — `didInjectStats` flag prevents re-fire (RESEARCH Pitfall 8). |
| `MinesweeperViewModel.reveal(at:)` terminal branches | `recordTerminalState(outcome:)` | private helper invoked after `freezeTimer()` | ✓ WIRED | Lines 162 (loss) + 166 (win); helper at 271-278 wraps `try? gameStats?.record(...)` so a persistence failure cannot block the win/loss overlay. |
| `GameStats.record(...)` | `try modelContext.save()` | synchronous save | ✓ WIRED | `GameStats.swift:101` — order: insert GameRecord → evaluate BestTime in do/catch → save. RESEARCH Pitfall 10 satisfied. |
| `GameStats.resetAll()` | `try modelContext.transaction { delete × 2 }` + `try save()` | iOS 17.3+ batch delete inside transaction | ✓ WIRED | Lines 110-114, atomic. |
| `StatsExporter.export(modelContext:)` | `JSONEncoder([.prettyPrinted, .sortedKeys] + .iso8601)` | encoder configured at lines 91-94 | ✓ WIRED | RESEARCH Pitfall 7 — byte-for-byte determinism gate. |
| `StatsExporter.importing(_:modelContext:)` | decode → validate (`schemaVersion == 1`) → transaction → save | order at lines 108-166 | ✓ WIRED | Validation at line 126 throws BEFORE the destructive transaction at line 134 (RESEARCH Pitfall 6). Existing data untouched on mismatch (proven by `schemaVersionMismatchThrows`). |
| `SettingsView.fileImporter` callback | security-scoped URL bookends | `startAccessingSecurityScopedResource()` + `defer { stopAccessingSecurityScopedResource() }` | ✓ WIRED | Lines 193-194 (RESEARCH Pitfall 5 — load-bearing for real-device imports). |
| `SettingsView` Reset row | `.alert(role: .destructive)` → `GameStats.resetAll()` | `isResetAlertPresented` state | ✓ WIRED | Lines 84-99; modelContext resolved lazily inside button closure (Pitfall 8). |
| `SettingsView` Import alert | `StatsImportError.errorDescription` | LocalizedError + xcstrings | ✓ WIRED | Lines 199-201 surface the error string; xcstrings catalog contains both case-specific bodies. |
| `GameKitApp.init` | shared `ModelContainer` with `cloudKitDatabase: store.cloudSyncEnabled ? .private(...) : .none` | ternary at lines 51-54 | ✓ WIRED | `.modelContainer(sharedContainer)` at line 72 — single shared container injected app-wide. |
| `StatsView` `@Query` | `GameRecord` / `BestTime` filtered by `gameKindRaw == "minesweeper"` | `#Predicate` | ✓ WIRED | Lines 44-52 — game-2 isolation proven by `bestTimeIsolatedPerGameKind` test. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `StatsView` | `minesRecords: [GameRecord]` | `@Query` over shared `ModelContainer` constructed in `GameKitApp.init` and persisted at the SwiftData store path | ✓ Yes — populated by `GameStats.record(...)` from `MinesweeperViewModel.recordTerminalState`; manual §1/§4 confirm a real Hard win surfaces a row | ✓ FLOWING |
| `StatsView` | `minesBestTimes: [BestTime]` | `@Query` over same container | ✓ Yes — populated by `GameStats.evaluateBestTime` on win-and-faster | ✓ FLOWING |
| `SettingsView` Export | encoded `Data` | `StatsExporter.export(modelContext:)` runs real `FetchDescriptor<GameRecord>` + `FetchDescriptor<BestTime>` against the live container | ✓ Yes — proven by `roundTripFifty` (50-row count survives) and manual §7 (real-device round-trip) | ✓ FLOWING |
| `SettingsView` Import | decoded `StatsExportEnvelope` | `Data(contentsOf: url)` from `.fileImporter` callback, then `StatsExporter.importing(...)` runs real delete + insert in a transaction | ✓ Yes — proven by `replaceOnImport` and manual §7 | ✓ FLOWING |
| `MinesweeperViewModel.recordTerminalState` | `frozenElapsed` Double | computed inside the VM from `clock()` injection (production: `Date.now`); passed verbatim to `GameStats.record(...)` | ✓ Yes — `MinesweeperViewModelTests/terminalLoss_freezesTimer` confirms freeze ordering | ✓ FLOWING |

No HOLLOW / DISCONNECTED / STATIC props found. Every render path is fed by a real DB query or a real upstream computation.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full xcodebuild test suite green on iOS 17 simulator (P4 + P2 + P3 regression) | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` | 79 test cases passed, 0 failed (exit 0). Includes all P4 cases: `ModelContainerSmokeTests` ×3, `GameStatsTests` ×8, `StatsExporterTests` ×7, `MinesweeperViewModelTests/vmSourceFile_importsOnlyFoundation` (firewall) ×1. | ✓ PASS |
| CloudKit container ID triple-lock enforced | `grep -rn "iCloud.com.lauterstar.gamekit"` | Locked in 3 places (forcing function): `.planning/PROJECT.md:141` + `gamekit/App/GameKitApp.swift:52` + `gamekitTests/Core/ModelContainerSmokeTests.swift:52`. Renaming any one fails the smoke test on PR (D-09 forcing function). | ✓ PASS |
| VM Foundation-only firewall (D-14) | `grep -nE "import "` against `MinesweeperViewModel.swift` | Imports `Foundation` ONLY — no `SwiftData`, no `SwiftUI`, no `ModelContext`. Asserted at runtime by `vmSourceFile_importsOnlyFoundation` test which passed. | ✓ PASS |
| Schema constraint check (no `@Attribute(.unique)`, all properties defaulted) | `grep -rn "@Attribute(.unique)" Core/` | Zero matches. Both `@Model` classes (`GameRecord`, `BestTime`) have every property defaulted; identity is `id: UUID = UUID()`. CloudKit-compat invariant from RESEARCH Pitfalls 1+2 satisfied. | ✓ PASS |
| Crash-toggle cleanup (Section 2 fatalError harness) | `grep "P4-06 verification\|fatalError(\"P4"` against `MinesweeperViewModel.swift` | Zero matches — temporary toggle removed before phase close. | ✓ PASS |
| Finder-dupe sweep (CLAUDE.md §8.7) | `find gamekit -name "* 2.swift"` | Zero matches. | ✓ PASS |
| File-size cap (CLAUDE.md §8.5/§8.1) | `wc -l Core/*.swift Screens/StatsView.swift Screens/SettingsView.swift` | All P4 files ≤239 lines (largest: SettingsView 239, StatsView 234, StatsExporter 178, GameStats 155). 400-line soft cap and 500-line hard cap both respected. | ✓ PASS |

## Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| PERSIST-01 | 04-01, 04-04 | SwiftData stats with CloudKit-compat schema (all defaulted, no `@Attribute(.unique)`, optional relationships, `schemaVersion: Int = 1`) | ✓ SATISFIED | `GameRecord.swift` + `BestTime.swift` conform; `ModelContainerSmokeTests` proves dual-config construction. |
| PERSIST-02 | 04-02, 04-05, 04-06 | Stats survive force-quit / crash / reboot via explicit sync save | ✓ SATISFIED | `GameStats.swift:101` sync save; manual §1+§2+§3 all green. |
| PERSIST-03 | 04-03, 04-05, 04-06 | Export/Import JSON with `schemaVersion`; round-trips cleanly | ✓ SATISFIED | `StatsExporter` + `StatsExportEnvelope` + `StatsExportDocument`; `roundTripFifty` test passes; manual §7 (real-device) green. |
| SHELL-03 | (none — orphan in plan frontmatter) | Stats screen shows per-difficulty: games · wins · win % · best time | ✓ SATISFIED (orphan) | `StatsView.swift:113-119` headers + `MinesDifficultyStatsRow` (lines 143-234) renders all four columns; manual §4 (6-preset matrix) confirms visual. ⚠ This requirement maps to Phase 4 in REQUIREMENTS.md but no P4 plan declared `SHELL-03` in its `requirements:` frontmatter. The implementation covers it anyway. |

**Doc-drift note (informational, not a blocker):** Top-list checkboxes at `REQUIREMENTS.md:32, 58, 60, 62` correctly mark SHELL-03 / PERSIST-01 / PERSIST-02 / PERSIST-03 as `[x]`, but the bottom mapping table at lines 170, 184, 185 still shows `Pending` for SHELL-03 / PERSIST-02 / PERSIST-03. Mechanical sweep at phase open of Phase 5 would resolve.

## Anti-Patterns Found

None blocking. Scan covered:

- `grep -rn -E "TODO|FIXME|XXX|HACK"` against `Core/`, `StatsView.swift`, `SettingsView.swift` → zero matches
- `grep -rn "@Attribute(.unique)"` against `Core/` → zero matches (CloudKit-compat invariant)
- `grep "placeholder|coming soon|not yet implemented"` → matches only in P1-stub comments inside `appearanceSection` (line 115 — "P1 stub — UNCHANGED. SHELL-02 polish at P5") and `aboutSection` (line 165 — "P1 stub — UNCHANGED") of `SettingsView.swift`. ℹ️ Info, not a P4 blocker — `SHELL-02` is a Phase 5 requirement; P4 explicitly preserved these stubs by design (Plan 04-05 frontmatter scope: DATA section only).
- Hardcoded `Color(...)` literals or numeric `cornerRadius:` / `padding(<int>)` in `Games/`/`Screens/` → none in P4 surface (pre-commit hook from FOUND-07 enforces this on every commit).

## Human Verification

All human-verifiable items were completed in the manual-pass sections above (force-quit, crash, reboot, 6-preset theme matrix, alert copy, real-device file picker round-trip, VoiceOver). No additional human verification required for the goal-backward layer.

## Gaps Summary

No gaps. The phase goal — "Stats survive force-quit / crash / reboot, schema is CloudKit-compatible from day 1, and the Stats screen reads the persisted truth" — is achieved end-to-end:

- **Persistence path is real:** `MinesweeperViewModel.recordTerminalState` → `GameStats.record(...)` → `try modelContext.save()` synchronously, every win or loss.
- **CloudKit-compat schema is real:** dual-config smoke test passes; no unique attributes; all properties defaulted; container ID triple-locked.
- **Stats screen reads persisted truth:** `@Query` filtered by `gameKindRaw == "minesweeper"`, with empty state and 3 always-rendered difficulty rows; data flows from a real upstream `GameStats.record(...)` writer.
- **Export/Import works:** decode → validate → transaction → save order; sortedKeys+iso8601+prettyPrinted determinism; security-scoped URL bookends for real-device safety.
- **Manual survival pass:** force-quit + crash + reboot all confirmed.

Phase 5 (Polish) is unblocked.

---

_Goal-backward verification: 2026-04-26_
_Verifier: Claude (gsd-verifier)_
