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

## 0.1) Project status — current facts

Slow-moving facts. **Update in the same commit** when any change.
Mirror of `CLAUDE.md` §0.1 — drift between the two is a bug.

| Fact | Value | Last updated |
|------|-------|--------------|
| Display name (home screen) | **GameDrawer** | 2026-05-01 |
| Full brand (App Store / marketing) | **GameDrawer** (no suffix) | 2026-05-01 |
| Bundle ID | `com.lauterstar.gamekit` | locked — never change per §5 |
| Repo / target name | `gamekit` | locked |
| Target iOS | 17+ | — |
| Swift / UI | Swift 6 + SwiftUI | — |
| Current milestone | `v1.0` (verifying, ~94% per `.planning/STATE.md`) | see STATE.md for live % |
| Current MVP game | Minesweeper | — |
| Next game (post-MVP) | Nonogram (Game 3, after Merge) | 2026-04-28 |
| Icon | Stack-of-three-game-boxes (light / dark / tinted) | 2026-04-30 ev. |
| Classic preset | Chrome Diner (cream + brushed grey + diner red) | 2026-04-28 |

Naming history (display name only — bundle ID never changes):
GameKit (internal/repo) → PixelParlor (rejected — genre mismatch) →
PlayCore (superseded same day) → CorePlay (superseded next day —
abstraction over concrete metaphor) → **GameDrawer** (current).
Full provenance: `assets/icon/AI_PROVENANCE.md`.

## 0.2) Where to look for live state

Don't duplicate fast-moving state in this file. Read the canonical
sources at session start instead.

| Question | Source |
|----------|--------|
| What changed recently? | `git log --oneline -20` |
| What phase / plan are we on? | `.planning/STATE.md` (front-matter + Current Position) |
| What's the milestone scope? | `.planning/ROADMAP.md` + `v1.0-MILESTONE-AUDIT.md` |
| What's the active phase doing? | `.planning/phases/<NN>-<name>/PLAN.md` (latest mtime) |
| Why was X chosen? | matching ADR/PRD in `.planning/phases/.../` + commit body |
| Icon / branding history | `assets/icon/AI_PROVENANCE.md` |

Rule: when the user asks "what's going on" / "status" / "where are
we", read `STATE.md` + `git log` first, then §0.1 — do not answer
from this file alone.

## 0.3) Release Log — `Docs/releases/`

Per-version release notes for the iOS app live in `Docs/releases/`,
keyed off `MARKETING_VERSION` (in
`gamekit/gamekit.xcodeproj/project.pbxproj`). Mirrors the convention
used across the sibling repos.

**Steps for every significant feature, fix, or change:**
1. Check the current `MARKETING_VERSION`.
2. If `Docs/releases/v{version}.md` does not exist, create it from
   `Docs/releases/TEMPLATE.md`.
3. Add the change under the appropriate section (Summary,
   User-facing changes, Internal changes, Fixes, Risks/notes).
4. Keep entries brief and factual.
5. Land the release-log update in the same commit as the code change.

A new file is opened on every `MARKETING_VERSION` bump. Don't mutate
a shipped version's file. Skip the log for self-explanatory or
doc-only commits.

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

### Classic preset — restomod policy
Classic (`ThemePreset.classicMuted`) is **Chrome Diner**: cream paper
bg, white card surfaces, brushed-grey bezels, diner-red accent. The
aesthetic is "rethink of classics with modern styles" — old design
language, modern execution.

Hard rules for new games and screens:
- Layout, spacing, radii, motion, typography weights stay modern.
  Classic only changes colors + surface treatment ("the skin"). Do NOT
  add serif fonts, skeuomorphic depth, or retro layout shifts when the
  preset is Classic.
- Default consumer baseline = Chrome Diner. New games inherit it for
  free; no Classic-specific code ships with a new game by default.
- Per-context overrides arrive only when needed. Felt-table games
  (Solitaire, Sudoku) will need a green-felt board surface. When the
  first such game lands, plumb a `@Environment(\.classicAnchorOverride)`
  hook from DesignKit so consumers can swap a narrow subset of anchors
  (typically just the game-board background) without forking the whole
  preset. Until then: don't speculate-build the override surface.
- Visual audit on Classic + one Loud preset (Voltage / Dracula) is
  still required for game-screen changes.

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

### 9.13 Brand / project-status changes update §0.1 + CLAUDE.md in the same commit
When any user-facing fact in §0.1 changes (display name, full brand,
bundle ID, target iOS, current milestone label, MVP/next-game pick,
icon direction, Classic-preset character), update **both** files in
the same commit:
1. `AGENTS.md` §0.1 row + `Last updated` date
2. `CLAUDE.md` §0.1 (mirror — drift is a bug)

Plus the canonical artifact (e.g. `AI_PROVENANCE.md` for icon /
naming, `pbxproj` for display name). Never let §0.1 drift past
truth — a stale §0.1 misleads every future session.

### 9.14 Every significant change appends to `Docs/releases/v{current}.md`
See §0.3. Pull `MARKETING_VERSION` from `pbxproj`, append a bullet
under the right section, land in the same commit as the code. Skip
only for self-explanatory refactors, doc-only edits, and work that
didn't actually ship in this `MARKETING_VERSION`.
