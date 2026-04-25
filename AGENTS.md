# AGENTS.md
## GameKit — agent rules (Codex / external AI tools)

Codex (and any non-Claude AI tool) reads this file before doing work.
Mirrors [`CLAUDE.md`](CLAUDE.md) — if the two ever drift, CLAUDE.md
wins for Claude Code, AGENTS.md wins for everyone else, and the diff
is a bug to be reconciled.

---

## 0) Goal

Build **GameKit** — a clean, ad-free iOS suite of classic logic
games, local-only, on top of the shared **DesignKit** Swift Package.

Sister projects in the same ecosystem (same DesignKit, same rules):
DesignKit · HabitTracker · FitnessTracker · PantryPlanner.

MVP scope: **Minesweeper only.** Roadmap: Merge · Word Grid ·
Solitaire · Sudoku · Nonogram · Flow · Pattern Memory · Chess puzzles.
Do not expand scope past MVP without an explicit ask.

---

## 1) Non-Negotiables (hard constraints)

### Tech & architecture
- Language: Swift 6
- UI: SwiftUI
- Persistence: SwiftData (default), UserDefaults for tiny shapes
- Pattern: lightweight MVVM (no TCA / Redux unless explicitly asked)
- iOS 17+
- Offline-first — no backend, no cloud, no analytics, no accounts
- Export/Import JSON backup (versioned) for persisted shapes

### Product
- **No ads. No coins. No fake currency. No energy systems. No
  aggressive subscriptions.** This is the differentiator — non-negotiable.
- Cold-start latency is a P0 bug.
- Settings screen is small: theme · haptics · reset stats · about.

### Design system
- **No hard-coded colors / radii / spacing in app UI.**
- All styling via DesignKit semantic tokens.
- Games must remain usable under **any** preset (Classic / Sweet /
  Bright / Soft / Moody / Loud). Don't assume a fixed aesthetic.
- Each game may pick a default preset, but must stay within the
  shared token system.

### Widgets (if requested)
- WidgetKit + App Intents for quick actions where applicable.
- Shared theme snapshot logic for widget chrome.
- Widgets are timeline-driven, not real-time.

---

## 2) Repository & module boundaries

### DesignKit (shared, lives at `../DesignKit`)
DesignKit contains ONLY:
- semantic tokens (colors, typography, spacing, radii, motion)
- generic reusable components (`DKCard`, `DKButton`, `DKProgressRing`,
  `DKBadge`, `DKSectionHeader`, `DKThemePicker`)
- chart styling helpers (Swift Charts)
- theme resolution (mode + preset + overrides)
- optional future hooks (category/icon overrides — not implemented
  unless requested)

DesignKit contains NO:
- game logic / engines
- game models
- game-specific views (`MinesweeperCellView`, etc.)
- game-specific haptics patterns (until proven reused in 2+ games)

### GameKit (this repo)
Contains:
- game engines (pure, testable, deterministic)
- game models (board, cell, difficulty, state)
- game views + view models
- cross-game shells (Home / Settings / Stats)
- stats + settings persistence
- app-specific assets

GameKit must NOT duplicate DesignKit styling logic. If a token is
missing, **add it to DesignKit**, don't work around it locally.

---

## 3) File / folder structure (use consistently)

```
App/         GameKitApp.swift, ThemeManager wiring
Core/        cross-game stores (GameStats, SettingsStore, ThemeStore)
Games/
  <Game>/    view, viewmodel, models, difficulty enum, engine(s)
Screens/     HomeView, SettingsView, StatsView (cross-game)
Resources/
Docs/        per-feature READMEs as needed
```

A new game = a new folder under `Games/`. Cross-game state lives in
`Core/`. Cross-game UI shells live in `Screens/`.

---

## 4) Coding standards

- Clarity > abstraction.
- No premature frameworks (no TCA / Redux / heavy DI).
- View models small and testable.
- `final` classes where appropriate.
- Engines are **pure functions / pure structs** — no SwiftUI imports,
  no `modelContext`, deterministic for a given seed.
- Unit tests for engine logic ship in the same commit as the engine.

---

## 5) Data safety & updates

- Never change bundle identifiers once daily use begins.
- Schema changes additive when possible.
- Export/Import always works. `schemaVersion` is mandatory.
- Never delete user data automatically.

---

## 6) Workflow for any task (Explore → Plan → Implement → Verify)

1. **Explore** — locate relevant files, note existing patterns.
2. **Plan** — propose a minimal change list + touched files.
3. **Implement** — small diffs, follow structure + tokens.
4. **Verify** — build / run tests; state what was run, what changed,
   and which presets were spot-checked for game-screen changes.

Write code immediately when asked to implement. If a plan already
exists, implement it — do not produce another plan file. Plan only
when explicitly asked.

---

## 7) If uncertain

Prefer:
- simplest approach that fits constraints
- vertical slice (one game, one feature, end-to-end)
- TODO hook over building a system "for later"

---

## 8) Commands

- Build: `xcodebuild -scheme GameKit -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Tests: `xcodebuild -scheme GameKit -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Open: `open GameKit.xcodeproj` (or `.xcworkspace` once SPM resolves)

---

## 9) Session-derived rules (avoid repeating past pain)

### 9.1 File size cap (~400 lines)
If a view or service crosses ~400 lines, split by concern into sibling
files. Smells: multiple unrelated MARKs, multiple distinct `@State`
groups, more than two independent data-load paths in one view.

### 9.2 Reusable views are data-driven, not data-fetching
Views used in 2+ places take props only. The parent owns the
SwiftData query. Keeps fetch logic in one place and makes previews
trivial.

### 9.3 Every data-driven view ships with an explicit empty state
No blank screens. Write the copy ("No games played yet.", "No best
times for Hard.") before the view is considered done.

### 9.4 Verify theme tokens exist before using them
Radii: `{card, button, chip, sheet}` only — no `.medium` / `.small`.
Spacing: `{xs, s, m, l, xl, xxl}`. Chart opacities use
`theme.charts.{axisLabelOpacity, gridlineOpacity}` — no hardcoded
`0.3` / `0.5`. Check `../DesignKit/Sources/DesignKit/Layout/*.swift`
or `Theme/Tokens.swift` first.

### 9.5 No monolithic Swift files (<500 lines hard cap)
Never generate a single Swift file over 500 lines. Split by view /
component / extension from the start.

### 9.6 SwiftUI correctness
Use `.foregroundStyle` not `.foregroundColor`. Respect access
modifiers. Confirm layout changes don't push content off-screen on
the smallest supported device.

### 9.7 Never tolerate Finder-dupe files (`X 2.swift`)
Xcode 16 (`objectVersion = 77`) uses
`PBXFileSystemSynchronizedRootGroup` — every `.swift` in the folder
is compiled. Dupes cause "invalid redeclaration" and block the
target. Delete on sight.

### 9.8 New `.swift` files in existing folders auto-register
Do not hand-patch `project.pbxproj`. Dropping into `Games/<game>/`
or `Core/` is enough. Only edit `project.pbxproj` for new top-level
folders or target-membership changes.

### 9.9 Test-runner crashes in `NSStagedMigrationManager` → uninstall, don't debug
Stale simulator SwiftData store from a prior schema version. Fix:
`xcrun simctl uninstall <device-id> com.<bundle-id>`, then retry.
Not a code bug.

### 9.10 Commit discipline — one feature or one grouped batch per commit
Each large feature lands in its own commit. Small unrelated changes
get grouped into a single coherent commit. Never bundle a large
feature with unrelated fixes. If `git status` shows more than one
unrelated area modified, stage + commit them separately before
continuing. Always prompt to commit after a verified feature.

### 9.11 First-tap safety (Minesweeper)
Mines are placed *after* the user's first tap, excluding the tapped
cell + its 8 neighbors. A first-tap loss is a bug, not RNG.

### 9.12 Game-screen theme passes are mandatory before "done"
Every game-screen change is verified against at least one Loud /
Moody preset (e.g. Voltage / Dracula) in addition to the default
Classic preset. Legibility regressions = fix the token usage, don't
carve out an exception.
