# Sudoku Integration — Design Spec

**Date:** 2026-05-15
**Milestone:** v1.2 (Video Mode + Sudoku scope addition, 2026-05-14)
**Status:** Design — awaiting writing-plans handoff
**Author:** Brainstorm session 2026-05-15

---

## 1. Goal

Ship Sudoku as the 4th playable game in The Drawer, alongside Minesweeper, Merge, and Nonogram. Source the core engine from the sister repo `cxnielsen/sudokuplus` (user is a collaborator). The integration follows the project's "vendor what we need, leave the rest" policy: pull only the pure logic + a curated set of view patterns, rebuild the UI to match GameKit's existing game-folder shape, hook into DesignKit, route stats and settings through existing GameKit stores.

**Success criteria:**

- Sudoku appears as a drawer row on Home with 4 difficulty mode chips (Easy / Medium / Hard / Extreme).
- Game plays end-to-end: select cell → place number → win or lose (lives mode).
- Two modes (Free / Lives), mirroring Nonogram's pattern.
- 1500 puzzles per difficulty bundled (6000 total ≈ 1MB JSON resource).
- Stats persist (best time, average time, completion count) per difficulty via a new SwiftData model.
- All UI reads DesignKit semantic tokens — verified legible under Classic + at least one Loud/Moody preset (§8.12).
- No SQLite dependency, no network, no telemetry, no first-launch seeding dance.

**Non-goals for v1 (named to keep scope honest):**

- Hints / technique suggestions (their `BeginnerGameState.swift` logic) — v1.3+
- 4×4 Beginner board — v1.3+
- Daily Puzzle (deterministic date-seeded selection) — v1.3+
- Streaks / longest-streak stat — v1.3+
- iCloud sync for Sudoku records — piggybacks on existing v1.0 iCloud sync phase, no special work
- Onboarding flow — game launches straight to board, no tutorial
- Their Firebase event telemetry — GameKit has no telemetry SDK, ever

---

## 2. Architecture

### 2.1 Repo layout

```
gamekit/
  Packages/
    SudokuCore/                        ← NEW local Swift Package (vendored)
      Package.swift
      Sources/SudokuCore/
        Models.swift                   ← from cxnielsen/sudokuplus
        Protocols.swift                ← from cxnielsen/sudokuplus
        Errors.swift                   ← from cxnielsen/sudokuplus
        SudokuPuzzleGenerator.swift    ← from cxnielsen/sudokuplus
        SudokuSolver.swift             ← from cxnielsen/sudokuplus
        TechniqueRater.swift           ← from cxnielsen/sudokuplus
        UseCases.swift                 ← from cxnielsen/sudokuplus
        SHA256Hasher.swift             ← from cxnielsen/sudokuplus
        SudokuCore.swift               ← from cxnielsen/sudokuplus
        InMemoryPuzzleRepository.swift ← NEW (thin replacement for SQLite repo)
        — SKIPPED: SQLitePuzzleRepository.swift (drop SQLite3 dep)
      Tests/SudokuCoreTests/           ← lifted verbatim from cxnielsen
      README.md                        ← provenance + sync log + license note
  gamekit/                             ← existing app target
    Games/
      Sudoku/                          ← NEW folder, Nonogram-pattern shape
        Engine/                        ← thin wrappers / extensions only
        SudokuBoard.swift
        SudokuBoardView.swift
        SudokuCell.swift
        SudokuCellView.swift
        SudokuDifficulty.swift
        SudokuEndStateCard.swift
        SudokuGameMode.swift           ← .free / .lives
        SudokuGameState.swift
        SudokuGameView.swift
        SudokuGameView+VideoMode.swift
        SudokuHeaderBar.swift
        SudokuLivesChip.swift
        SudokuModePill.swift
        SudokuNumberPad.swift
        SudokuPuzzlePool.swift         ← loads JSON, serves next-unplayed
        SudokuStatsCard.swift
        SudokuToolbarMenu.swift
        SudokuViewModel.swift
    Resources/
      SudokuPuzzles.json               ← generated artifact (~1MB)
  Tools/
    GenerateSudokuPack/                ← NEW Swift CLI target
      Package.swift
      Sources/GenerateSudokuPack/main.swift
```

### 2.2 Wiring

- Main app target depends on local `SudokuCore` Swift Package.
- `Tools/GenerateSudokuPack` depends on `SudokuCore` only — zero UIKit/SwiftUI imports — runs as `swift run GenerateSudokuPack` from CLI.
- `SudokuPuzzles.json` committed to repo as a build resource (not gitignored).
- No new external Swift package dependencies. Pure Foundation across `SudokuCore`.

### 2.3 Integration approach

**Approach C — Hybrid (locked during brainstorm).** Mirror Nonogram's file shape and view-model architecture as the outer skeleton, but lift the proven rendering math (cell-size grid, box-border thickening, selection highlight) from `cxnielsen`'s `BoardView.swift` as the inside of `SudokuBoardView`. Same call as any sister-repo port: coherent architecture, no reinventing solved geometry.

Their views serve as reference only — none are imported directly. Their `Theme/` is discarded entirely (DesignKit is the only theme system).

---

## 3. Engine Layer — SudokuCore Vendoring

### 3.1 Sync workflow

- Initial vendor: `git archive` of `cxnielsen/sudokuplus@<sha>` → extract `SudokuCore/Sources/SudokuCore/*` and `SudokuCore/Tests/SudokuCoreTests/*` into `Packages/SudokuCore/`.
- Record SHA in `Packages/SudokuCore/README.md`:
  ```
  Synced-from: cxnielsen/sudokuplus@<full-sha> on YYYY-MM-DD
  Synced-by:   <commit author>
  ```
- Re-sync: re-run archive, diff against existing files, manually re-apply non-conflicting upstream changes. No automated upstream pull, no submodule. Manual review every time so we never accidentally regress local edits.

### 3.2 Files dropped during vendor

- `SQLitePuzzleRepository.swift` + every reference to `import SQLite3`. We do not need persistent puzzle storage; runtime serves from a bundled JSON pack.
- Any iCloud / Firebase / telemetry stub that lives in `SudokuCore` (audit during vendor; expected: none).

### 3.3 New file added during vendor

`InMemoryPuzzleRepository.swift` — a ~20-line `actor` conforming to their `PuzzleRepository` protocol, backed by a `[String: Puzzle]` dict keyed by hash. Used by `GenerateSudokuPack` CLI for dedup; not used by the app at runtime (app loads JSON directly via `SudokuPuzzlePool`).

### 3.4 Tests

- `Packages/SudokuCore/Tests/SudokuCoreTests/` lifted verbatim.
- CI gate: `cd Packages/SudokuCore && swift test` green before the vendoring commit is allowed to land.

### 3.5 License / attribution

`Packages/SudokuCore/README.md`:

```
SudokuCore is vendored from cxnielsen/sudokuplus with permission of the
author (Gabriel Nielsen is a collaborator on that repository).

Sync history:
- 2026-05-XX — initial vendor at <sha>
```

No third-party license requirements — repo is private, single-author. The note is courtesy + provenance, not legal mandate.

---

## 4. Puzzle Pack Pipeline

### 4.1 JSON schema (`Resources/SudokuPuzzles.json`)

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-15T00:00:00Z",
  "generatorSourceSha": "<sudokuplus sha at vendor time>",
  "puzzles": {
    "easy":    [ { "id": "<uuid>", "givens": "5300...", "solution": "5347...", "givenCount": 36 }, ... ],
    "medium":  [ ... ],
    "hard":    [ ... ],
    "extreme": [ ... ]
  }
}
```

- `givens` / `solution` = 81-char strings, `0` = empty cell.
- Target 1500 entries per difficulty × 4 difficulties = **6000 puzzles ≈ ~1.1MB JSON**.
- If bundle size becomes an issue later, gzip → ship as `.json.gz` → decompress on load. v1 ships uncompressed.
- `schemaVersion: 1` allows future field additions without bricking older app versions that might restore from backup.

### 4.2 CLI tool — `swift run GenerateSudokuPack`

**Flags:**

- `--per-difficulty <N>` — target count per difficulty (default 1500).
- `--difficulties <csv>` — restrict to subset (e.g., `--difficulties hard,extreme`). Default = all four.
- `--output <path>` — output JSON path (default `gamekit/gamekit/Resources/SudokuPuzzles.json`).
- `--append` — read existing JSON, fill missing slots only. **Default off**: a no-flag run starts fresh.
- `--time-budget <minutes>` — soft cap; writes progress, exits cleanly when budget exhausted.

**Behavior:**

- Resumable: with `--append`, dedup by hash, fill until each difficulty reaches `--per-difficulty`.
- Atomic write: serialize to `<output>.tmp`, then rename to `<output>` on success. Crash mid-write leaves the previous good file intact.
- Logs progress every 60s:
  ```
  easy:    423/1500 (28%)
  medium:    0/1500 (0%)
  hard:      0/1500 (0%)
  extreme:   0/1500 (0%)
  elapsed: 18m22s  budget: 20m
  ```
- Dedup uses `SHA256Hasher` (existing class). Two identical boards never enter the pool.

**20-minute batch workflow:**

```
swift run GenerateSudokuPack --append --time-budget 20
git add gamekit/gamekit/Resources/SudokuPuzzles.json
git commit -m "chore(sudoku): grow pack — easy +XXX, medium +XXX, ..."
```

Repeat across sessions until each difficulty reaches 1500.

### 4.3 Runtime loader — `SudokuPuzzlePool` (actor)

- Decodes `SudokuPuzzles.json` from app bundle on first call (`Bundle.main.url(forResource:withExtension:)`). Off main thread.
- Caches parsed `[Difficulty: [PuzzleEntry]]` in memory.
- Played-puzzle set is **derived from `[GameRecord]` query** at pool init: `GameRecord` rows where `gameKindRaw == "sudoku"` and `outcomeRaw == "win"` and `puzzleIdRaw != nil` → the `puzzleIdRaw` values form the played set per difficulty. **No separate UserDefaults persistence** — single source of truth, naturally piggybacks on iCloud sync (when v1.0 phase lands), no extra schema.
- `next(difficulty:) async -> PuzzleEntry`:
  1. Pick first entry whose `id` is not in the played set.
  2. If pool exhausted → empty the in-memory played set (silent recycle; `GameRecord` rows stay untouched so a future "Solved Sudoku" gallery still sees full history).
  3. Return entry. ViewModel writes `GameRecord` with `puzzleId: entry.id` on `.won` — that write is what marks "played" for next session.
- In-session reseed avoidance: pool keeps its own in-memory cursor so consecutive `next(difficulty:)` calls within one session never repeat before any `GameRecord` is written.
- Cold-start parse cost benchmark target: <100ms on iPhone 12. If slower, switch to per-difficulty lazy decode (4 sub-files instead of one).

---

## 5. Game Layer

### 5.1 Type shape (mirrors `NonogramViewModel` / `NonogramGameState`)

**`SudokuGameState`** — pure model, Codable for session restore.

```
- board: [[SudokuCell]]              // 9×9, each cell knows .given/.solution/.user/.notes
- selected: (row: Int, col: Int)?
- mode: SudokuGameMode               // .free | .lives
- difficulty: SudokuDifficulty
- elapsedSeconds: Int
- mistakes: Int                       // 0–3 in .lives, always 0 in .free
- status: SudokuStatus                // .playing | .won | .lost
- undo: UndoSnapshot?                 // single-step
```

**`SudokuViewModel`** — `@Observable` orchestrator. Owns one `SudokuGameState`. Methods:

- `place(value: Int)` — commits or rejects per mode rules.
- `toggleNote(value: Int)` — toggle pencil mark in selected cell.
- `erase()` — clear user value + notes from selected cell (no-op on given cells; no-op on locked correct cells in `.lives`).
- `undo()` — restore last `UndoSnapshot`. One step only.
- `select(row:col:)` — change selection.
- `tick()` — bump `elapsedSeconds` by 1; called by a 1s Timer publisher.
- `restart()` — reset state, keep same puzzle.
- `loadNew(difficulty:)` — fetch next puzzle from `SudokuPuzzlePool`, reset state.

Pulls puzzles from `SudokuPuzzlePool`. Routes haptics/SFX through existing `SettingsStore` (no new toggles).

### 5.2 Modes (`SudokuGameMode`)

```swift
enum SudokuGameMode: String, Codable, Sendable, CaseIterable, Hashable {
    case free
    case lives

    static let livesPerPuzzle: Int = 3
}
```

- **`.free`** — wrong placement highlights cell in red; doesn't lock; user can erase + retry; no fail state; win when board complete.
- **`.lives`** — wrong placement increments `mistakes` (cap 3), placement rejected (not committed). 3 mistakes = `.lost`. Correct placements lock cell (cannot erase). Mirrors `NonogramGameMode` semantics exactly.
- Persisted in `UserDefaults` key `sudoku.lastGameMode` (`rawValue` string). Renaming the case = data break.
- Mode picked via in-game `SudokuModePill` (top of board). Drawer mode chips select difficulty only.

### 5.3 Board features

- **Notes / candidates.** Long-press number pad button = notes mode toggle, OR dedicated "pencil" toggle button in the header bar (final UX call deferred to phase 15; both UX patterns are common in mainstream Sudoku apps). When a value is committed to a cell, that value is auto-removed from notes in the same row, column, and 3×3 box. Auto-clear is on by default; a future settings toggle may expose it (out of v1 scope).
- **Timer.** Stopwatch in `SudokuHeaderBar`. Driven by `SudokuViewModel.tick()` on a 1s SwiftUI `TimelineView` or `Timer.publish`. Pauses on `ScenePhase.inactive`. Pauses while end-state banner shown.
- **Mistake counter.** Shown in `HeaderBar` as `SudokuLivesChip` (3 dots, dim as mistakes accumulate) only in `.lives` mode. Hidden in `.free`.
- **Undo.** Single-step. `SudokuViewModel` keeps `lastUndoSnapshot: UndoSnapshot?` of `(row, col, prevValue, prevNotes)`. After undo, snapshot is consumed (no redo, no multi-step history).
- **Number pad.** 1–9 grid, bottom of board. Each button shows a small remaining-count badge (e.g., "5: 3 left"). Greys out when 9 already placed. References cxnielsen's `NumberPadView.swift` for layout.

### 5.4 Drawer integration

Add to `GameDescriptor.all` in `Core/GameDescriptor.swift` after Nonogram:

```swift
GameDescriptor(
    kind: .sudoku,
    titleKey: "Sudoku",
    captionKey: "Tap to play",
    symbol: "square.grid.3x3.fill",
    accent: .slot4,
    route: .sudoku(nil),
    modes: [
        GameModeChip(id: "easy",    labelKey: "Easy",    detailKey: "9×9", route: .sudoku(.easy)),
        GameModeChip(id: "medium",  labelKey: "Medium",  detailKey: "9×9", route: .sudoku(.medium)),
        GameModeChip(id: "hard",    labelKey: "Hard",    detailKey: "9×9", route: .sudoku(.hard)),
        GameModeChip(id: "extreme", labelKey: "Extreme", detailKey: "9×9", route: .sudoku(.extreme))
    ]
)
```

Plus:

- `GameKind.sudoku` case added to `enum GameKind` in `Core/GameKind.swift` (confirmed location during spec review).
- `GameRoute.sudoku(SudokuDifficulty?)` case in `Core/GameRoute.swift`.
- Switch arm in `HomeView.destination(for:)`:
  ```swift
  case .sudoku(let difficulty):
      SudokuGameView(initialDifficulty: difficulty)
          .videoModeAware(minBoardHeight: 480)
  ```
- `AccentSlot.slot4` palette slot is **already wired** in `Core/GameDescriptor.swift` (`.slot4 → catalogueColor(3)`) and DesignKit's `CataloguePalette.swift` already exposes a 6-slot palette per preset. No DesignKit changes required.

**Icon.** SF Symbol `"square.grid.3x3.fill"` — solid 9-cell mini-grid. Reads as Sudoku at 22pt. Consistent with sibling drawer cards (each uses a single SF Symbol on the icon plate). No custom asset until v1.3 polish pass.

---

## 6. Stats Integration

**Spec review finding (2026-05-15):** Existing GameKit stats infrastructure (`Core/GameStats.swift`, `Core/GameRecord.swift`, `Core/BestTime.swift`) already supports per-game-kind stats keyed by `(gameKind, difficulty)`. `GameRecord` even includes `puzzleIdRaw` for puzzle-based games (Nonogram already uses it). **No new SwiftData model is needed for Sudoku — reuse the existing shared infrastructure.** This was the original brainstorm's "hybrid stats" intent (best + avg + count), correctly mapped to existing primitives.

### 6.1 Write path

`SudokuViewModel` calls `GameStats.record(gameKind:difficulty:outcome:durationSeconds:puzzleId:...)` on terminal transition (`.playing` → `.won` or `.lost`), same write-path as Nonogram:

- `gameKind: .sudoku` (new `GameKind` case)
- `difficulty: SudokuDifficulty.rawValue` (`"easy"|"medium"|"hard"|"extreme"`)
- `outcome: .win | .loss` — losses only emit in `.lives` mode (3 mistakes). In `.free` mode there is no loss state, so a session either reaches `.won` or is abandoned (no record written).
- `durationSeconds: Double`
- `puzzleId: entry.id.uuidString` — links the record back to the bundle entry so a future "Solved Sudoku" gallery is trivial

`GameStats.record(...)` internally:
- appends a `GameRecord` row
- updates the matching `BestTime` row (one per `(gameKind, difficulty)`) only when the new duration is faster than the current best

### 6.2 Read path

`StatsView` injects `[GameRecord]` + `[BestTime]` via `@Query` (already in place for sibling games). New `SudokuStatsCard` (lives in `Games/Sudoku/`) is a **data-driven, props-only view** per §8.2:

```swift
struct SudokuStatsCard: View {
    let theme: Theme
    let records: [GameRecord]    // pre-filtered to gameKind == .sudoku
    let bestTimes: [BestTime]    // pre-filtered to gameKind == .sudoku
    // ... per-difficulty rows: Best (from bestTimes) · Avg (computed from records) · Played (records.count)
}
```

`StatsView` invokes it after the existing Nonogram card (mirror the existing `NonogramStatsCard` consumption site):

```swift
SudokuStatsCard(
    theme: theme,
    records: records.filter { $0.gameKind == .sudoku },
    bestTimes: bestTimes.filter { $0.gameKind == .sudoku }
)
```

Card layout — one row per difficulty:
- `Easy · Best 4:32 · Avg 6:18 · Played 12`
- Empty state copy when `records.isEmpty`: "No Sudoku puzzles solved yet."

### 6.3 Export / import

Existing `StatsExporter` round-trips `GameRecord` + `BestTime` by `gameKindRaw` — adding `.sudoku` as a `GameKind` case is the only change. **No JSON envelope `schemaVersion` bump required** (additive `GameKind` rawValue is forward-compat by design per §1 "additive when possible"; old app version reading a newer envelope safely ignores unknown `gameKindRaw` values via the safe-fallback accessor pattern documented in `GameRecord.swift`).

### 6.4 Test additions

- `SudokuStatsIntegrationTests` — `GameStats.record(gameKind: .sudoku, ...)` writes a `GameRecord` with correct `puzzleIdRaw`; second faster win updates `BestTime`; slower win does not.
- `SudokuStatsCardTests` — empty-records → empty-state copy; mixed records → correct per-difficulty Best/Avg/Played counts.

---

## 7. Settings · Theme · Haptics · Video Mode

### 7.1 DesignKit tokens

All color, spacing, radii, motion reads from `theme.*` — zero hardcoded values per §1.

- Cell text (user-placed): `theme.colors.textPrimary`
- Given (locked) cells: `theme.colors.textSecondary` + bold weight
- Cell background (normal): `theme.colors.surface`
- Cell selected: `theme.colors.accent.opacity(0.15)` background
- Row/column/box peer highlight: `theme.colors.accent.opacity(0.06)`
- Same-number peer highlight: `theme.colors.accent.opacity(0.10)`
- Wrong-placement red: `theme.colors.danger`
- Box borders (3×3 group dividers): thicker stroke using `theme.colors.border`

**Theme audit gate per §8.12:** Verify legibility under Classic + at least one Loud/Moody preset (Voltage or Dracula) before phase 15 can be called done. Cell numbers, peer highlights, and wrong-placement red must all stay distinguishable. If any token fails, fix the token usage — do not carve a Sudoku-specific exception.

### 7.2 Haptics

Routed through existing `SettingsStore.hapticsEnabled`:

- Light tap on cell select
- Medium tap on value commit
- Success haptic on `.won`
- Error haptic on wrong placement (`.lives` mode only)

### 7.3 SFX

Routed through `SettingsStore.sfxEnabled`. Reuse Nonogram's win/lose chimes if pitched similarly; otherwise no new audio asset for v1.

### 7.4 Animations

All animations gated through `SettingsStore.animationsEnabled` AND `accessibilityReduceMotion`. Cell-fill animation, win-banner reveal, mistakes-chip dim — all respect the toggles.

### 7.5 Video Mode

Hook into existing `videoModeAware(minBoardHeight:)` modifier. Add `SudokuGameView+VideoMode.swift` mirroring `NonogramGameView+VideoMode.swift`. Banner = shared `VideoModeBanner` primitive shipped in Phase 13. No new Video Mode work specific to Sudoku.

---

## 8. Testing

Per §5 of `CLAUDE.md`, new pure services ship with tests in the same commit.

### 8.1 SudokuCoreTests (vendored)

Lifted verbatim from `cxnielsen/sudokuplus`. Green gate before any vendoring commit lands. Coverage includes generator, solver, rater, models.

### 8.2 SudokuPuzzlePoolTests (new)

- Loads a fixture JSON (50-puzzle subset bundled in test resources).
- Asserts: `next(difficulty:)` cycles through unplayed entries, exhaustion resets played set, decode rejects malformed input (empty string, non-81-char givens, missing required field).

### 8.3 SudokuViewModelTests (new)

- Happy path: place all correct values → `status == .won` → record updated.
- `.lives` mode: wrong placement increments mistakes, rejects commit, 3rd wrong = `.lost`.
- Locked given cell: `place()` and `erase()` are no-ops.
- Locked correct cell (`.lives` mode): `erase()` is a no-op.
- Undo: restores `(prevValue, prevNotes)`, consumes snapshot.
- Notes auto-clear: commit a value in cell → notes in row/col/box for that value are cleared.

### 8.4 Sudoku stats integration tests (new)

Covered in §6.4 — `SudokuStatsIntegrationTests` + `SudokuStatsCardTests`. No standalone "SudokuRecord" tests because there is no new SwiftData model — existing `GameStats` / `GameRecord` / `BestTime` tests already exercise the storage primitives generically across `GameKind` values.

### 8.5 UI tests

None for v1. Per `CLAUDE.md` §5, UI tests minimal unless requested.

---

## 9. Phase Plan (rough cut)

Writing-plans will refine. Numbering picks up after Phase 13 (last shipped in v1.2).

### Phase 14 — Vendor SudokuCore + CLI tool

- Land `Packages/SudokuCore/` (vendored sources + tests).
- Land `Tools/GenerateSudokuPack/` (CLI target).
- Land placeholder `Resources/SudokuPuzzles.json` (4 difficulties × 10 puzzles = 40 puzzles) so app target compiles + tests pass.
- Tests green: `swift test` on SudokuCore + main app target builds.

### Phase 15 — Game vertical slice

- `SudokuPuzzlePool` + `SudokuGameState` + `SudokuViewModel` + `SudokuBoardView` + `SudokuNumberPad` + `SudokuHeaderBar` + `SudokuModePill` + `SudokuLivesChip` + `SudokuEndStateCard`.
- Drawer wiring: `GameDescriptor.all` entry + `GameKind.sudoku` + `GameRoute.sudoku` + `HomeView.destination(for:)` arm.
- Both modes (.free + .lives) functional. Notes + timer + undo working.
- **Theme audit gate** under Classic + 2 Loud/Moody presets per §8.12 before phase callable done.

### Phase 16 — Stats integration

- `SudokuViewModel` calls `GameStats.record(gameKind: .sudoku, ...)` on terminal transition (no new SwiftData model).
- New `SudokuStatsCard` view in `Games/Sudoku/` consumed by `StatsView`.
- `StatsView` filters `[GameRecord]` + `[BestTime]` by `gameKind == .sudoku` and passes them in.
- Integration tests per §6.4.
- No JSON envelope `schemaVersion` bump (adding a `GameKind` rawValue is additive per §1).

### Phase 17 — Pack generation

- Run `swift run GenerateSudokuPack --append --time-budget 20` in 20-min sessions across multiple sittings.
- Each batch commits the grown JSON.
- Phase done when all 4 difficulties = 1500 entries.
- Can overlap chronologically with Phase 14–16 since the pack file is independent of the app code path.

### Verification

End of all 4 phases:

- Drawer shows 4 games.
- Sudoku plays end-to-end on real device.
- Tested under at least one Classic + one Loud preset.
- Stats persist across launch.
- Export/import round-trips.
- `MARKETING_VERSION` bumped, `Docs/releases/v<X>.md` updated per §0.3.

---

## 10. Open questions (for writing-plans phase)

- **Notes-mode UX gesture.** Long-press number-pad button vs dedicated pencil toggle in header. Decide in phase 15 after building both stubs and comparing on-device feel.
- **Auto-clear notes toggle.** Default ON in v1; whether to expose as a setting is a v1.3+ call.
- **End-state banner copy.** Reuse Nonogram's "You solved it!" / "Game over — 3 mistakes" pattern, but final wording during phase 15 polish.
- **`SudokuCore` vendor SHA.** Pick a stable commit on `cxnielsen/sudokuplus@main` at phase 14 kickoff. Record in `Packages/SudokuCore/README.md`.

---

*End of design spec.*
