# Phase 14 — Home Screen Overhaul

**Goal:** Replace the accordion `DrawerRow` layout with a 3-col icon grid +
expand-in-place interaction and new game-specific icons.

**Wireframe reference:** `assets/HomeScreenDesign.html` (SpringExpandV2 pattern
with v8 icons). The HTML prototype is directional — content and paths are adapted
to match the real app below.

---

## Step 1 — `GameIconView.swift` (new file)

Pure SwiftUI shape views for all 6 games, translated from the v8 SVG glyphs in
`assets/v8-icons.jsx`. Each icon takes `size: CGFloat` and `color: Color`. No
image assets. Standalone so it can be reused in stats, future widgets, etc.

| Game | Icon concept |
|---|---|
| Minesweeper | Flag pole + triangular flag + 5-dot grid base |
| Merge | Two overlapping rounded tiles (back faded, front solid) |
| Nonogram | 5×5 pixel-heart grid (filled + ghost cells) |
| Sudoku | 3×3 grid outline + subdivision lines + bold "9" in center cell |
| Solitaire | 3 fanned playing cards, front card shows heart corner pip |
| FreeCell | Row of 4 cell outlines (second filled) + 3 fanned cards below |

Placement: `Screens/GameIconView.swift` (shared across home + future uses).

---

## Step 2 — `GameDescriptor` additions

Add three properties to each descriptor entry in `Core/GameDescriptor.swift`:

- `accentColor: Color` — per-game identity color
- `isNew: Bool` — drives the `!` badge; set true for Solitaire + FreeCell at
  launch, cleared after first tap or on next version
- `shortMeta: String` — subtitle shown in the detail panel (e.g. "Klondike",
  "Standard", "Logic")

Color assignments:
| Game | Accent |
|---|---|
| Minesweeper | `#2F7BF6` (blue) |
| Merge | `#29C254` (green) |
| Nonogram | `#E84743` (red) |
| Sudoku | `#E89A1F` (amber) |
| Solitaire | `#1AB4C2` (teal) |
| FreeCell | `#A458EE` (purple) |

No routing changes — `GameDescriptor.routes` already drives the mode picker.

---

## Step 3 — `HomeView` grid + expand state

Replace the `ForEach(GameDescriptor.all)` `DrawerRow` VStack with:

**Closed state (no game selected):**
- `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())])` of icon tiles
- Each tile: 78pt colored rounded-square + `GameIconView` + game name label below
- `!` badge top-right if `descriptor.isNew`
- Upcoming entry as the last cell — dimmed sparkle tile, same grid slot

**Open state (game selected):**
- Selected tile renders at 96pt with a stronger shadow
- All other tiles shrink to 44pt and reflow into a **horizontal `ScrollView`
  strip** pinned above the detail panel (not a 6-col grid — avoids breaking
  at 7+ games)
- `@State var expandedKind: GameKind?` already exists — no new state needed

Animation: `withAnimation(.spring(response: 0.42, dampingFraction: 0.78))`
— matches the existing accordion spring already in HomeView.

Tap behaviour:
- Tap closed tile → expand (set `expandedKind`)
- Tap open tile → collapse (set `expandedKind = nil`)
- Tap background → collapse (existing `.onTapGesture` on ZStack background)

---

## Step 4 — `HomeDetailPanel.swift` (new file)

Appears below the horizontal strip when `expandedKind != nil`.

Props:
```swift
struct HomeDetailPanel: View {
    let descriptor: GameDescriptor
    let theme: Theme
    var onSelect: (GameRoute) -> Void
    var onStats: () -> Void
}
```

Layout:
```
[96pt icon tile]  Game Name     ← theme.typography.headline
                  shortMeta     ← theme.typography.caption, muted

MODE / DIFFICULTY               ← mono caption label
[Chip]  [Chip]  [Chip]          ← one per descriptor.routes entry

Stats  ›                        ← caption link, calls onStats
```

Mode chips:
- Driven by `descriptor.routes` — each entry produces one chip
- Accent border on the chip matching last-played difficulty (stored in
  UserDefaults per the existing `{game}.lastDifficulty` key pattern)
- Tapping any chip: calls `onSelect(route)`, HomeView sets
  `expandedKind = nil` then `path.append(route)`

No Continue button, no Daily Challenge — those slots are reserved for when
the features exist (mid-game save state is a separate phase).

Placement: `Screens/HomeDetailPanel.swift`

---

## Step 5 — Settings / Stats access (unchanged)

`person.crop.circle` menu in `topBarTrailing` stays. The Stats link inside
`HomeDetailPanel` calls `onStats` which sets `showingStats = true` in HomeView
(already exists), presenting `StatsView` — ideally pre-filtered to that game
if `StatsView` gains a filter parameter, otherwise opens normally.

---

## Step 6 — Cleanup

Once HomeView is wired and verified:
- Delete `DrawerRow.swift`
- Grep for `DrawerChrome` — delete if only used by DrawerRow
- Verify build is clean and all 6 games launch

---

## File change summary

| File | Action |
|---|---|
| `Screens/GameIconView.swift` | Create |
| `Screens/HomeDetailPanel.swift` | Create |
| `Core/GameDescriptor.swift` | Add `accentColor`, `isNew`, `shortMeta` |
| `Screens/HomeView.swift` | Rewrite layout section |
| `DrawerRow.swift` (wherever it lives) | Delete after verification |

---

## Definition of done

- All 6 games launchable from the new grid
- Expand/collapse animates correctly on all supported devices
- Upcoming tile still opens the Upcoming sheet
- Settings and Stats still reachable from the profile menu
- `isNew` badge visible on Solitaire and FreeCell tiles
- No hard-coded colors — all styling reads DesignKit tokens (accentColor
  passes through as a raw Color from GameDescriptor, not a token; this is
  intentional since it's per-game identity, not semantic)
- Verified on Classic preset + one Loud/Moody preset (CLAUDE.md §8.12)

---

## Out of scope for this phase

- Mid-game resume / Continue button (tracked separately — save state for 5
  games is its own phase)
- Daily challenge feature
- Per-game stats filtering in StatsView
- Clearing `isNew` automatically after first play (can be a follow-up)
