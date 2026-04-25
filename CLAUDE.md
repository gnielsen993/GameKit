# CLAUDE.md
## GameKit — Claude Code working rules

Claude Code reads this file at the start of every session. Treat it as
the project constitution. Mirrored in [`AGENTS.md`](AGENTS.md) for
other AI tools.

---

## 0) What you are building

**GameKit** — a clean, ad-free iOS suite of classic logic games
(Minesweeper first; Merge / Word Grid / Solitaire / Sudoku / Nonogram
/ Flow / Pattern Memory / Chess puzzles later). Local-only. No
accounts. No ads. Powered by the shared **DesignKit** Swift Package.

Sister projects in the same ecosystem (same DesignKit, same rules):
DesignKit · HabitTracker · FitnessTracker · PantryPlanner.

---

## 1) Absolute Constraints (Do Not Violate)

### Stack
- Swift 6 + SwiftUI
- SwiftData for stats persistence (default; UserDefaults acceptable
  for tiny key-value shapes)
- Lightweight MVVM
- iOS 17+
- Offline-only — no backend, no cloud, no analytics, no accounts

### Product
- **No ads. No coins. No fake currency. No energy systems. No
  aggressive subscriptions.** Ever. This is the differentiator.
- App must launch instantly. Cold-start latency is a P0 bug.
- No popups, modals, or push-y UX on first run.
- Settings stays small — theme · haptics · reset stats · about.

### Data safety
- Implement Export/Import JSON with `schemaVersion` for stats.
- Schema changes additive when possible.
- Never delete user data automatically.
- Avoid bundle ID changes once the app is in daily use.

### Design (non-negotiable)
- **No hard-coded colors / radii / spacing in UI.**
- All styling reads DesignKit semantic tokens.
- Games must remain usable under **any** DesignKit preset (Classic /
  Sweet / Bright / Soft / Moody / Loud) — don't assume a fixed
  aesthetic. Verify legibility on at least 4 contrasting presets
  before calling a game-screen polish pass done.
- "Personality" comes from preset + layout emphasis, not random
  styling.

---

## 2) DesignKit: how to consume it

### What goes into DesignKit
- Tokens: colors, typography, spacing, radii, motion
- ThemeManager: mode + preset + overrides + saved customs
- Generic components: `DKCard`, `DKButton`, `DKProgressRing`,
  `DKBadge`, `DKSectionHeader`, `DKThemePicker`
- Chart helpers (Swift Charts) — irrelevant to games for now

### What does NOT go into DesignKit
- Game logic (board generation, flood-fill, merge math, dictionary
  lookup, etc.)
- Game-specific views (`MinesweeperCellView`, `MergeTileView`)
- Game models (`MinesweeperCell`, `MergeBoard`, …)
- Game-specific haptics patterns *unless* the same pattern is reused
  in 2+ games — only then promote to `DKHaptics`.

### Available tokens — verify before using
Radii: `card | button | chip | sheet` (no `.medium` / `.small`).
Spacing: `xs | s | m | l | xl | xxl`.
Chart opacities: `theme.charts.{axisLabelOpacity, gridlineOpacity}`
(no hardcoded `0.3` / `0.5`). When reaching for a token, check
`../DesignKit/Sources/DesignKit/Layout/*.swift` or
`../DesignKit/Sources/DesignKit/Theme/Tokens.swift` first.

### Theme picker UX convention
- Main Settings: 5 Classic swatches (`PresetCatalog.core`) inline +
  "More themes & custom colors" `NavigationLink`.
- Linked screen: full `DKThemePicker(catalog: .all, maxGridHeight: nil)`.
- Rationale: forward-facing settings should not feel like a theme gallery.

---

## 3) Project structure (keep consistent)

```
App/         GameKitApp.swift, root scene, ThemeManager wiring
Core/        cross-game stores: GameStats, SettingsStore, ThemeStore
Games/
  <GameName>/  view + viewmodel + models + difficulty enum
Screens/     HomeView, SettingsView, StatsView (cross-game shells)
Resources/   assets, localized strings
Docs/        per-feature READMEs as needed
```

A new game = a new folder under `Games/`. Each game owns its view,
view model, models, and engine. Cross-game shells live in `Screens/`.
Cross-game shared state lives in `Core/`.

---

## 4) Rules for AI-assisted changes (avoid drift)

- **Reuse existing patterns in the repo.** Do not invent new
  architectures.
- **Smallest change that satisfies the requirement.** A bug fix isn't
  a refactor. A one-shot doesn't need a helper.
- **Promote to DesignKit only when proven** — used in 2+ games. Until
  then, keep it local to the game folder.
- **Game engines are pure / testable** — deterministic, no SwiftUI
  imports, no `modelContext`. Examples:
  - Minesweeper: `BoardGenerator`, `RevealEngine`, `WinDetector`
  - Merge: `MergeEngine`, `ScoreEngine`
  - Word Grid: `DictionaryService`, `PathValidator`
- **Write code immediately when asked to implement.** If a plan
  exists, implement it — do not produce another plan file. Plan only
  when explicitly asked.
- **Check the codebase before suggesting.** Use Grep/Read to verify
  what exists before recommending features or fixes. Do not assume
  something is missing without checking.

---

## 5) Testing expectations

- Unit tests for game engines (board gen, flood-fill, win detection,
  merge math, scoring) — these are the core IP and must be
  deterministic.
- Verify Export/Import round-trip where stats persist.
- UI tests minimal unless explicitly requested.
- New pure services ship with tests **in the same commit**: happy
  path · empty input · one edge case (first-tap-safe placement,
  flag-on-revealed-cell rejection, full-board win, etc.).

---

## 6) Definition of done (any task)

A task is done when:
- code compiles
- behavior is verified (state what was run / checked)
- structure + token rules followed
- works under at least one Classic preset *and* one Loud/Moody preset
  (game UI tasks)
- no new drift introduced

---

## 7) When unsure
Choose:
- vertical slice > architecture
- clarity > abstraction
- TODO hook > overbuilding

---

## 8) Session-derived rules (avoid repeating past pain)

### 8.1 File size cap (~400 lines)
If a view or service crosses ~400 lines, split by concern into sibling
files. Smells: multiple unrelated MARKs, multiple distinct `@State`
groups, more than two independent data-load paths in one view.

### 8.2 Reusable views are data-driven, not data-fetching
A view used in 2+ places takes props only — the parent owns the
SwiftData query. A reusable `BestTimesCard` gets `times: [BestTime]`,
never touches `modelContext`. Keeps fetch logic in one place and makes
SwiftUI previews trivial.

### 8.3 Every data-driven view ships with an explicit empty state
No blank screens. Write the copy ("No games played yet.", "No best
times for Hard.") before the chart or list is considered done.

### 8.4 Verify theme tokens exist before using them
See §2 — radii are `{card, button, chip, sheet}` only. Spacing is the
6-step scale. Don't invent tokens.

### 8.5 No monolithic Swift files (<500 lines hard cap)
Never generate a single Swift file over 500 lines. Split by view /
component / extension from the start.

### 8.6 SwiftUI correctness
Use `.foregroundStyle` not `.foregroundColor` (iOS 17+ targets).
Respect access modifiers. Confirm layout changes don't push content
off-screen on the smallest supported device.

### 8.7 Never tolerate Finder-dupe files (`X 2.swift`)
Xcode 16 (`objectVersion = 77`) uses `PBXFileSystemSynchronizedRootGroup`
— every `.swift` in the folder is compiled. Byte-identical `X 2.swift`
dupes cause "invalid redeclaration" and block the whole target. If one
appears in `git status` as `??`, confirm with `diff` then delete before
doing anything else.

### 8.8 New `.swift` files in existing folders auto-register
Do not hand-patch `project.pbxproj` to add a file. Dropping the file
into `Games/<game>/` or `Core/` is enough — synchronized root group
picks it up on next build. Only edit `project.pbxproj` for new
top-level folders or target-membership changes.

### 8.9 Test-runner crashes in `NSStagedMigrationManager` → uninstall, don't debug
If `xcodebuild test` aborts during host-app launch with
`_findCurrentMigrationStageFromModelChecksum:` in the crash report,
the simulator has a stale SwiftData store from a prior schema
version. Fix: `xcrun simctl uninstall <device-id> com.<bundle-id>`,
then retry. Not a code bug.

### 8.10 Commit discipline — one feature or one grouped batch per commit
Each large feature lands in its own commit. Small unrelated changes
get grouped into a single coherent commit. Never bundle a large
feature with unrelated fixes. If `git status` shows more than one
unrelated area modified, stage + commit them separately before
continuing. Always prompt to commit after a feature is verified —
don't let uncommitted work pile up.

### 8.11 First-tap safety in Minesweeper is a hard requirement
Do not place mines until *after* the user's first tap, then exclude
the tapped cell + its 8 neighbors from mine placement. A first-tap
loss is a bug, not RNG.

### 8.12 Game-screen theme passes are mandatory before "done"
Every game-screen change is verified against at least one Loud or
Moody preset (e.g. Voltage / Dracula) in addition to the default
Classic preset. If mines / numbers / flags stop being legible under
any preset, fix the token usage — don't carve out an exception.
