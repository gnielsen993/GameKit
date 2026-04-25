# GameKit

A clean, ad-free collection of classic logic games for iOS. Built in
Swift / SwiftUI on top of the shared **DesignKit** Swift Package.

> Classic logic games. No ads. No noise. Just play.

---

## Why this exists

Most Solitaire / Sudoku / Minesweeper / 2048 clones are cluttered with
banner ads, forced video ads, fake currencies, pushy subscriptions, and
overdesigned menus. GameKit is the opposite: a calm, polished, fast,
local-only suite where the user fully controls the visual identity
through DesignKit themes.

---

## Status

**MVP target: Minesweeper.** Everything else (Merge / Word Grid /
Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess puzzles)
is roadmap, not in scope until Minesweeper feels complete.

---

## Stack

- Swift 6 + SwiftUI
- SwiftData *or* UserDefaults (per-store choice — see §Persistence)
- DesignKit (local Swift Package, see `../DesignKit`)
- iOS 17+
- No backend. No accounts. No ads. No analytics.

---

## Project layout

```
GameKit/
├── App/
│   └── GameKitApp.swift            ← @main, ThemeManager wiring
├── Core/
│   ├── GameStats.swift             ← shared stats store
│   ├── SettingsStore.swift
│   └── ThemeStore.swift            ← persists DesignKit ThemeManager
├── Games/
│   └── Minesweeper/
│       ├── MinesweeperView.swift
│       ├── MinesweeperViewModel.swift
│       ├── MinesweeperBoard.swift
│       ├── MinesweeperCell.swift
│       └── MinesweeperDifficulty.swift
├── Screens/
│   ├── HomeView.swift
│   ├── SettingsView.swift
│   └── StatsView.swift
└── Resources/
```

DesignKit lives **outside** this repo (`../DesignKit`) and is consumed
as a local package dependency. Never duplicate styling logic into
GameKit — extend DesignKit if a token is missing.

---

## DesignKit integration (non-negotiable)

GameKit is a DesignKit consumer. Every visible pixel reads from a
theme token.

```swift
// Bad
Color.purple
.cornerRadius(8)

// Good
theme.colors.accentPrimary
.cornerRadius(theme.radii.card)
```

Available tokens (from DesignKit):

```
theme.colors.{background, surface, surfaceElevated, border,
              textPrimary, textSecondary, textTertiary,
              accentPrimary, accentSecondary, highlight,
              success, warning, danger,
              fillPressed, fillSelected, fillDisabled}

theme.typography.{title, titleLarge, headline, body, caption}
theme.spacing.{xs, s, m, l, xl, xxl}
theme.radii.{card, button, chip, sheet}
theme.motion.{fast, normal, slow}
theme.charts.{chart1…chart6, gridlineOpacity, axisLabelOpacity}
```

Radii are `{card, button, chip, sheet}` only — there is no `.medium` /
`.small`. Spacing is the 6-step scale above. Verify a token exists
before using it.

### Theme picker UX convention

- Settings shows the 5 Classic swatches inline (`PresetCatalog.core`)
  + a "More themes & custom colors" link.
- Link pushes a dedicated screen hosting
  `DKThemePicker(catalog: .all, maxGridHeight: nil)` for full catalog
  + Custom tab.

### Game-specific theming constraints

Games must remain usable under **any** preset (high contrast / minimal
/ bright / dark / loud). Don't assume a fixed aesthetic:

- Mines / numbers / flags must stay legible on any `theme.colors.surface`.
- Revealed-vs-unrevealed cells use distinct semantic tokens, not
  hand-picked greys.
- Win/loss overlays read from `theme.colors.{success,danger}`.

---

## Minesweeper (MVP)

### Difficulties

| Mode    | Grid    | Mines |
|---------|---------|-------|
| Easy    | 9×9     | 10    |
| Medium  | 16×16   | 40    |
| Hard    | 16×30   | 99    |

### Interaction

- **Tap** → reveal cell. First tap is always safe (mines placed
  *after* first tap).
- **Long-press** → toggle flag.
- Empty cells flood-fill to the next numbered border.
- Win = all non-mine cells revealed. Loss = mine revealed.

### Data models

```swift
struct MinesweeperCell {
    let row: Int
    let column: Int
    var hasMine: Bool
    var isRevealed: Bool
    var isFlagged: Bool
    var adjacentMineCount: Int
}

enum MinesweeperDifficulty { case easy, medium, hard }

struct MinesweeperBoard {
    var rows: Int
    var columns: Int
    var mineCount: Int
    var cells: [[MinesweeperCell]]
}

enum GameState { case ready, playing, won, lost }
```

### ViewModel responsibilities

Generate board · place mines (post-first-tap) · compute adjacency ·
reveal · flood-fill · flag · timer · win/loss detection · persist
stats via `GameStats`.

---

## Persistence

- **Settings + theme** → UserDefaults (DesignKit's `ThemeStorage`).
- **Stats / best times** → SwiftData (default) or UserDefaults JSON
  if SwiftData is overkill for the shape.
- **No cloud, no accounts, no telemetry.** Local only.
- Every persisted shape ships **Export / Import JSON** with a
  `schemaVersion` field. Schema changes are additive when possible.

---

## Stats screen

Per game: games played · wins · win % · best times (per difficulty).
Streaks are a Phase 5 / retention-layer item — not MVP.

---

## Roadmap

| Phase | Scope |
|-------|-------|
| **1. Foundation** | Project setup · DesignKit wired · ThemeManager injected · Home + Settings shells |
| **2. Minesweeper** | Board gen · mine placement · reveal · flood-fill · flag · win/loss · timer · restart |
| **3. Polish** | DesignKit haptics · animations · stats + best times · theme-responsiveness pass |
| **4. Second game** | 2048-style Merge — validates multi-game architecture + DesignKit reuse |
| **5. Retention** | Daily puzzles · streaks · history · optional reminders |

Long-term suite: Minesweeper · Merge · Solitaire · Sudoku · Word Grid
· Word Ladder · Nonogram · Flow · Pattern Memory · Chess puzzles.

---

## Build

Open `GameKit.xcodeproj` (or workspace) in Xcode 16+. DesignKit is a
local SPM dependency at `../DesignKit`.

```bash
xcodebuild -scheme GameKit -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme GameKit -destination 'platform=iOS Simulator,name=iPhone 16' test
```

---

## Monetization

Not now. Future options (in order of preference): one-time unlock for
the full suite · paid DesignKit theme packs · tip jar. **Never:** ads,
coins, energy systems, aggressive subscriptions.

---

## Success criteria (MVP)

- App launches instantly.
- Minesweeper is fully playable across all 3 difficulties.
- UI reads cleaner than any free competitor.
- Theme switching works universally — every preset is playable.
- Stats persist locally and survive app restarts.
- You'd personally use it daily.

---

## Related docs

- [`CLAUDE.md`](CLAUDE.md) — Claude Code working rules for this repo
- [`AGENTS.md`](AGENTS.md) — Codex / other-agent rules (mirrors CLAUDE)
- `../DesignKit/README.md` — design system reference
