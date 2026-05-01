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

## 0.1) Project status — current facts

Slow-moving facts. **Update in the same commit** when any change.
Ordered by how often a session needs them.

| Fact | Value | Last updated |
|------|-------|--------------|
| Display name (home screen) | **GameDrawer** | 2026-05-01 |
| Full brand (App Store / marketing) | **GameDrawer** (no suffix) | 2026-05-01 |
| Bundle ID | `com.lauterstar.gamekit` | locked — never change per §1 |
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
| Persistent decisions across sessions | Claude Code memory (auto-loaded) |

Rule: when the user asks "what's going on" / "status" / "where are
we", read `STATE.md` + `git log` first, then this §0.1 block — do
not answer from prior-session memory alone.

## 0.3) Release Log — `Docs/releases/`

Per-version release notes for the iOS app live in `Docs/releases/`,
keyed off `MARKETING_VERSION` (in
`gamekit/gamekit.xcodeproj/project.pbxproj`). Mirrors the convention
used in sibling repos (ParkedUp / FitnessTracker / DesignKit) so a
session crossing repos sees the same shape.

**Steps for every significant feature, fix, or change:**
1. Check the current `MARKETING_VERSION` in the project file.
2. If `Docs/releases/v{version}.md` does not exist, create it from
   [`Docs/releases/TEMPLATE.md`](Docs/releases/TEMPLATE.md).
3. Append the change under the appropriate section (Summary,
   User-facing changes, Internal changes, Fixes, Risks/notes).
4. Keep entries brief — bullet points, what + why, no per-file lists.
5. Land the release-log update **in the same commit as the code
   change** (or as the wrap-up commit of a multi-commit feature
   batch).

A new file is opened when `MARKETING_VERSION` is bumped — never
mutate a shipped version's file.

What NOT to log: self-explanatory commits, doc-only changes, comment
tweaks, in-flight work that did not ship in that `MARKETING_VERSION`.

---

## 1) Absolute Constraints (Do Not Violate)

### Stack
- Swift 6 + SwiftUI
- SwiftData for stats persistence (default; UserDefaults acceptable
  for tiny key-value shapes)
- Lightweight MVVM
- iOS 17+
- **Offline-first. Optional iCloud sync via Sign in with Apple
  (Phase 06).** No third-party backend, no analytics SDKs, no
  required accounts. iCloud sync never gates gameplay — the user
  can play forever signed-out, and signing out preserves local
  stats. CloudKit container `iCloud.com.lauterstar.gamekit` is the
  only network surface; SIWA is the only auth surface.

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

### Classic preset — restomod policy
The `Classic` preset (`ThemePreset.classicMuted` in DesignKit) is
**Chrome Diner**: cream paper bg, white card surfaces, brushed-grey
bezels, diner-red accent. The aesthetic is "rethink of classics with
modern styles" — old design language, modern execution.

Hard rules for new games and screens:
- **Layout, spacing, radii, motion, typography weights stay modern.**
  Classic only changes colors + surface treatment ("the skin"). Do NOT
  add serif fonts, skeuomorphic depth, or retro layout shifts when the
  preset is Classic.
- **Default consumer baseline = Chrome Diner.** A new game ships with
  no Classic-specific code — it inherits Chrome Diner from DesignKit.
- **Per-context overrides arrive only when needed.** Felt-table games
  (Solitaire, Sudoku) will need a green-felt board surface. When the
  first such game lands, plumb a `@Environment(\.classicAnchorOverride)`
  hook from DesignKit so consumers can swap a narrow subset of anchors
  (typically just the game-board background) without forking the whole
  preset. Until then: don't speculate-build the override surface.
- **Visual audit on Classic + one Loud preset (Voltage / Dracula).**
  Game-screen changes still need the §8.12 contrast pass.

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

### 8.13 Brand / project-status changes update §0.1 + AGENTS.md in the same commit
When any user-facing fact in §0.1 changes (display name, full brand,
bundle ID, target iOS, current milestone label, MVP/next-game pick,
icon direction, Classic-preset character), update **all three** in
the same commit:
1. `CLAUDE.md` §0.1 row + `Last updated` date
2. `AGENTS.md` §0.1 (mirror)
3. Relevant memory file under `~/.claude/projects/.../memory/` if
   the fact is also pinned there (e.g. `project_app_name.md`).

Plus the canonical artifact (e.g. `AI_PROVENANCE.md` for icon /
naming, `pbxproj` for display name). Never let §0.1 drift past
truth — a stale §0.1 misleads every future session.

### 8.14 Every significant change appends to `Docs/releases/v{current}.md`
See §0.3. Pull `MARKETING_VERSION` from `pbxproj`, append a bullet
under the right section, land in the same commit as the code. Skip
only for: self-explanatory refactors, comment / doc-only edits, and
work that didn't actually ship in this `MARKETING_VERSION`.
