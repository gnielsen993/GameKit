# Phase 3: Mines UI - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

P3 delivers the **playable Minesweeper UI** on top of P2's locked engine API. Three-tier MVVM per `.planning/research/ARCHITECTURE.md`:

- **View layer** in `Games/Minesweeper/` (SwiftUI) — board grid, cell tile, mine counter, timer, end-state overlay, toolbar.
- **ViewModel** = `MinesweeperViewModel` (`@Observable final class`) orchestrating engine calls, timer state, scenePhase pause/resume, terminal-state transitions. ARCHITECTURE.md §pattern-2 already specifies `@Observable`.
- **DesignKit additions** — new semantic token `theme.colors.gameNumber(_ n: Int) -> Color` for adjacency numbers 1–8, ships across DesignKit `PresetTheme`s (THEME-02, A11Y-04).

**Engine API consumed (from `02-CONTEXT.md`, locked):**
- `BoardGenerator.generate(difficulty:firstTap:rng:)` (D-08, D-11)
- `RevealEngine.reveal(at:on:) -> (board, revealed: [Index])` (D-06)
- `WinDetector.isWon(_:) / isLost(_:)` (D-07)
- Models: `MinesweeperBoard`, `MinesweeperCell`, `MinesweeperIndex`, `MinesweeperDifficulty`, `MinesweeperGameState`

**Out of scope for P3** (owned by later phases):
- SwiftData persistence + GameRecord writes (P4)
- Polished animation cascade (reveal stagger, win-sweep, loss-shake) — P3 ships **functional** transitions only; P5 polishes
- Haptics, SFX (P5)
- Reduce-motion, Dynamic Type audit (P5)
- Settings spine, intro flow (P5)
- CloudKit / Sign in with Apple (P6)
- Custom-palette overrides through ThemeManager.overrides (THEME-03 → P5)

**v1 ROADMAP P3 success criteria carried forward as locked specs (no re-asking):**
- SC1 — Gesture composition: `LongPressGesture(0.25).exclusively(before: TapGesture())` with zero misfires across 50 manual taps on iPhone SE-class hardware
- SC2 — Mine counter = `total − flagged`; wall-clock timer; pause on `scenePhase == .background`; resume with correct elapsed on `.active`
- SC3 — Restart button always available; fresh board, same difficulty
- SC4 — Win → `theme.colors.success` overlay; loss → reveal all mines + X-mark wrong flags + `theme.colors.danger` overlay (MINES-11)
- SC5 — Zero `Color(...)` literals in `Games/Minesweeper/`; all reads from semantic tokens including new `theme.colors.gameNumber(_:)` (THEME-02)
- SC6 — `accessibilityLabel` baked at view creation: "Unrevealed, row 3 column 5" / "Revealed, 2 mines adjacent, row 3 column 5" / "Flagged, row 3 column 5" (A11Y-02 partial — full a11y audit P5)

</domain>

<decisions>
## Implementation Decisions

### End-state overlay
- **D-01:** End-state overlay = centered `DKCard` floating over a dimmed board backdrop. Win uses `theme.colors.success` accent; loss uses `theme.colors.danger`. Card is a single composed view (`MinesweeperEndStateCard`) parameterized by outcome + elapsed + mines-hit count.
- **D-02:** **No tap-to-dismiss on the dim backdrop.** User must tap the explicit Restart action inside the card. Per the calm-no-pushy ethos in PROJECT.md: a fast-replay loop comes from a clear primary button, not from a dismiss gesture that risks accidental restarts mid-celebration.
- **D-03:** Card surfaces **four pieces of content**:
  1. Outcome title ("You won!" / "Bad luck") localized via `String(localized:)` per FOUND-04.
  2. Final elapsed time (e.g. "2:14") prominently displayed.
  3. **(Loss only)** "X mines hit / Y remaining" line for context — educational rather than scolding (matches non-pushy UX bar in PROJECT.md).
  4. Two buttons: **Restart** (primary, same difficulty) and **Change difficulty** (secondary — opens the same toolbar Menu component used in `Games/Minesweeper/MinesweeperToolbarMenu.swift`, see D-05).
- **D-04:** Card uses `theme.radii.card`, `theme.spacing.l` for outer padding, and outcome-tinted accent (`success` / `danger`) on the title only — body text stays on `theme.colors.textPrimary` so the overlay reads the same way under every preset (Classic / Sweet / Bright / Soft / Moody / Loud), not just the high-contrast ones (CLAUDE.md §1 + §8.12).

### Timer architecture (SC2)
- **D-05:** Timer rendered with `TimelineView(.periodic(from: vm.timerAnchor, by: 1))`. ViewModel owns a single `timerAnchor: Date?` plus an accumulator `pausedElapsed: TimeInterval`. The view derives `displayed = pausedElapsed + (now - timerAnchor)` per render tick. **No `Timer.publish`, no `Task` loop, no `Combine`.** Pure SwiftUI redraw cadence — matches research/ARCHITECTURE.md §pattern-3 ("ViewModel exposes state; view derives presentation").
- **D-06:** scenePhase integration in `MinesweeperView`:
  - `.onChange(of: scenePhase)` watches transitions:
    - On entering `.background`: VM calls `pause()` → `pausedElapsed += Date.now.timeIntervalSince(timerAnchor!)`; `timerAnchor = nil`. TimelineView stops ticking because anchor is nil.
    - On entering `.active` *while* `gameState == .playing`: VM calls `resume()` → `timerAnchor = Date.now`. TimelineView resumes from the new anchor.
  - Idle, won, and lost states never set `timerAnchor`, so backgrounding from those is a no-op.
- **D-07:** First tap starts the timer (VM sets `timerAnchor = Date.now` inside the same call that runs `BoardGenerator.generate(...)` + first `RevealEngine.reveal`). No "click-Start" affordance.
- **D-08:** Terminal-state transitions (`.won` / `.lost`) freeze elapsed: VM does the same `pausedElapsed += ...; timerAnchor = nil` math the pause path uses, so the end-state card's elapsed time and the live timer agree to the second.

### Difficulty switching surface
- **D-09:** Difficulty picker = top-trailing toolbar `Menu` (`MinesweeperToolbarMenu`) with three buttons (Easy / Medium / Hard). Reads from `vm.difficulty`, writes through `vm.setDifficulty(_:)`. Same component is reused inside the end-state card's "Change difficulty" secondary action (D-03).
- **D-10:** **Mid-game switch confirmation:** if `gameState == .playing` when user picks a different difficulty, show an `.alert("Abandon current game?", role: .destructive)` with Cancel / Abandon. Cancel = no-op; Abandon = fresh board at new difficulty + reset elapsed. From `idle`, `won`, or `lost` states: switch immediately, no alert (no progress to lose).
- **D-11:** **Difficulty persists across launches** via `UserDefaults` key `mines.lastDifficulty: String` (uses the `MinesweeperDifficulty` raw `String` value locked by D-02 in P2 — `"easy" | "medium" | "hard"`). Tiny key-value shape, per CLAUDE.md §1 "UserDefaults acceptable for tiny key-value shapes." Read once at VM init; written every time `setDifficulty(_:)` succeeds (after any abandon-confirmation). Default on first launch = `.easy`.
- **D-12:** Home-screen Mines card stays a single tap = "play last difficulty." No difficulty chip on Home for v1 — keeps the Home grid uniform with the 8 future-game placeholders. (Adding difficulty chips on Home is deferred — see Deferred Ideas.)

### DesignKit `theme.colors.gameNumber(_:)` token (THEME-02 + A11Y-04)
- **D-13:** Token shape: `extension Theme { func gameNumber(_ n: Int) -> Color }` returning the per-preset palette entry for adjacency number `n` (1–8). Implemented in `DesignKit/Sources/DesignKit/Theme/Tokens.swift`. The function clamps `n` to `1...8` and returns the entry from a fixed-length 8-array stored on `Theme`.
- **D-14:** Palette source = **per-preset designer-tuned 8-color array.** Each `PresetTheme` (Classic, Sweet, Bright, Soft, Moody, Loud) ships its own `gameNumberPalette: [Color]` of length 8 tuned for its aesthetic. Classic ships the traditional Minesweeper palette (1=blue, 2=green, 3=red, 4=dark blue, 5=maroon, 6=cyan, 7=black, 8=grey); loud presets (Voltage / Dracula) ship neon-spectrum variants tuned to the preset's accent.
- **D-15:** **A11Y-04 verification per preset** (color-blind safety against Wong-palette principles for protanopia / deuteranopia / tritanopia): every preset's `gameNumberPalette` must be audited via a deterministic test (`DesignKitTests/GameNumberPaletteWongTests.swift`) that simulates each colorblindness type and asserts perceptual ΔE between adjacent palette entries above a threshold. Loud-preset audit may legitimately fail and trigger a per-preset fallback (`gameNumberPaletteWongSafe: [Color]?` override) — but **Classic must pass unconditionally** because it is the default first-run preset.
- **D-16:** `theme.colors.gameNumber(_:)` is added to `DesignKit` in P3, **not** promoted to a generic component. CLAUDE.md §2 + §4: "promote to DesignKit only when proven — used in 2+ games." Numbered-cell rendering is currently a 1-game pattern; the token is OK in DesignKit because it's a *token* (per CLAUDE.md §2 "Tokens: colors, typography, spacing, radii, motion") not a component. A `DKNumberedCell` view stays in `Games/Minesweeper/` until at least one other game (Sudoku / Nonogram) needs it.

### Loss-state mine reveal (MINES-11 + SC4)
- **D-17:** On `WinDetector.isLost(board)` flipping true, VM transitions to `.lost(mineIdx:)` (engine D-09). View renders the loss in two passes:
  1. The mine that triggered loss renders with `theme.colors.danger` background fill (the "you stepped here" highlight).
  2. **Every other mine** on the board renders the mine glyph (theme-tinted, no danger fill) — flipped from the `hidden` state to a `revealed-as-mine` visual.
  3. **Every flag placed on a non-mine cell** renders the flag glyph crossed out with an X — `theme.colors.danger` X overlay on the standard flag glyph.
- **D-18:** Loss reveal ships **without animation in P3** — instant flip on terminal-state transition. The polished cascade (loss-shake, mine-reveal stagger) is owned by P5 (MINES-08). P3's loss view must be authored so P5 can layer animation in via `phase: MinesweeperPhase` enum changes (research/ARCHITECTURE.md §pattern-2) without touching V/VM contracts.

### Cell accessibility (SC6 + A11Y-02 partial)
- **D-19:** Every `MinesweeperCellView` exposes `accessibilityLabel` at view creation (not `.onAppear` retrofit) using a switch on `cell.state`:
  - `.hidden` → `"Unrevealed, row \(row + 1) column \(col + 1)"`
  - `.revealed(adjacent: 0)` → `"Revealed, 0 mines adjacent, row \(row + 1) column \(col + 1)"`
  - `.revealed(adjacent: n)` → `"Revealed, \(n) mines adjacent, row \(row + 1) column \(col + 1)"`
  - `.flagged` → `"Flagged, row \(row + 1) column \(col + 1)"`
  - `.mineHit` → `"Mine, row \(row + 1) column \(col + 1)"`
  Row/col indices are 1-indexed in the spoken label per the ROADMAP exemplar ("row 3 column 5" not "row 2 column 4").
- **D-20:** Buttons + overlay text strings ship `accessibilityLabel` at view creation. Full a11y audit (Reduce Motion, Dynamic Type, VO rotor, A11Y-01 / A11Y-03) is P5 per REQUIREMENTS.md mapping — P3 lays the foundation, P5 polishes.

### Claude's Discretion
The user did not lock the following — planner has flexibility, but should align with research / CLAUDE.md / AGENTS.md / ARCHITECTURE.md:

- **Board layout strategy for Hard 16×30 on iPhone SE (320pt).** Three viable approaches: (a) fit-to-width with cells ~10pt — fails MINES-02 gesture accuracy, hard reject; (b) horizontal `ScrollView` with cells fixed at ~22pt — reliable touch targets, native iOS feel, recommended; (c) pinch-zoom (`MagnificationGesture`) — overengineered for v1. **Recommend (b) horizontal scroll** with the fully visible width of the board on Easy 9×9 and Medium 16×16 (no scroll needed) and scroll-only-on-Hard.
- **Cell view file split.** `MinesweeperBoardView` (grid layout) vs `MinesweeperCellView` (single tile) vs `MinesweeperToolbarMenu` (difficulty + restart) vs `MinesweeperEndStateCard` (overlay) vs `MinesweeperHeaderBar` (mine counter + timer) vs `MinesweeperGameView` (top-level scene). Recommend split by responsibility (~6 files) — per CLAUDE.md §8.5 (<500 lines/file, <400 lines for views).
- **`@Observable` VM observation strategy.** ARCHITECTURE.md already locks `@Observable`. Open question is whether `MinesweeperViewModel` lives at module scope or inside `MinesweeperGameView` as a `@State` property. Recommend `@State` ownership (iOS 17+ idiom; deinit guarantees timer cleanup with the view).
- **Restart button placement.** Toolbar leading vs footer button vs top-leading vs end-state-only. Recommend toolbar leading (always-visible per SC3, single tap, mirrors the difficulty Menu placement on the trailing side, no footer to clutter the small iPhone SE width).
- **Long-press on already-revealed cell.** No-op vs chord-reveal preview. Recommend no-op for v1 — chord-reveal is a power-user feature backlog item, not in v1 scope.
- **Tap on flagged cell.** No-op (must unflag first) vs auto-unflag-then-reveal. Recommend no-op — preserves the "flags are intentional commitments" UX.
- **Mine glyph + flag glyph asset source.** SF Symbol (`flag.fill`, `circle.fill` tinted) vs custom SVG. Recommend SF Symbols — Dynamic Type support, theme tinting via `.foregroundStyle()`, no asset shipping cost. Mine = `circle.fill` with `theme.colors.textPrimary`; flag = `flag.fill` with `theme.colors.danger`.
- **Animation duration tokens.** Use `theme.motion.fast/normal/slow` for any P3 transitions (state changes, button feedback) per CLAUDE.md §2. P3 ships functional defaults; P5 owns the polished pass.

### Folded Todos
None — STATE.md `Pending Todos` is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules + invariants
- `CLAUDE.md` — Project constitution (DesignKit token rules §2, file-size caps §8.5, theme-pass requirement §8.12, no-Color-literal rule §1, UserDefaults vs SwiftData rule §1)
- `AGENTS.md` — Mirror of CLAUDE.md for non-Claude tools
- `.planning/PROJECT.md` — Vision, principles, "calm premium ad-free" non-negotiables
- `.planning/REQUIREMENTS.md` — Phase 3 requirement IDs (MINES-02, MINES-05, MINES-06, MINES-07, MINES-11, THEME-02) + full text
- `.planning/ROADMAP.md` — Phase 3 entry: goal, success criteria SC1–SC6, dependency on Phase 2

### Engine API (consumed, do not modify)
- `.planning/phases/02-mines-engines/02-CONTEXT.md` — Locked engine API decisions (D-01..D-19)
- `.planning/phases/02-mines-engines/02-VERIFICATION.md` — Proof of engine correctness (mine counts, first-tap-safety, BFS flood-fill, win/loss)
- `gamekit/gamekit/Games/Minesweeper/Engine/BoardGenerator.swift`
- `gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift`
- `gamekit/gamekit/Games/Minesweeper/Engine/WinDetector.swift`
- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` (immutable, value-type — never mutate)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperCell.swift`
- `gamekit/gamekit/Games/Minesweeper/MinesweeperIndex.swift`
- `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift`
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameState.swift`

### Architecture + research
- `.planning/research/ARCHITECTURE.md` — Three-tier MVVM separation (§pattern-2 `@Observable` VM; §pattern-3 view derives presentation; `MinesweeperPhase` enum animation orchestration)
- `.planning/research/PITFALLS.md` — Known traps (Pitfall 1 first-tap-safety addressed in P2; Pitfall on gesture composition relevant to MINES-02)
- `.planning/research/STACK.md` — SwiftUI + SwiftData + iOS 17+ stack constraints

### DesignKit (sibling SPM package — read but do not duplicate)
- `../DesignKit/Sources/DesignKit/Theme/Tokens.swift` — Where `gameNumber(_:)` lands (D-13)
- `../DesignKit/Sources/DesignKit/Theme/PresetTheme.swift` — Per-preset 8-color array source (D-14)
- `../DesignKit/Sources/DesignKit/Theme/Theme.swift` — Public Theme contract
- `../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift` — Active preset state (consumed by `MinesweeperView` via environment)
- `../DesignKit/Sources/DesignKit/Theme/PresetCatalog.swift` (if exists) — Verify all 6 presets to update with `gameNumberPalette`
- `../DesignKit/Sources/DesignKit/Components/DKCard.swift` — End-state overlay container (D-01)
- `../DesignKit/Sources/DesignKit/Components/DKButton.swift` — Primary/secondary action style on Restart + Change difficulty
- `../DesignKit/Sources/DesignKit/Layout/Spacing.swift` (or wherever spacing is defined) — Verify `theme.spacing.l` (D-04)

### Phase 1 foundation (read-only context, do not modify)
- `gamekit/gamekit/App/GameKitApp.swift` — `ThemeManager` `@StateObject` wiring, file-header style template
- `gamekit/gamekit/Screens/RootTabView.swift` — Where `MinesweeperGameView` is presented from
- `gamekit/gamekit/Screens/HomeView.swift` — Mines card entry point (D-12 reaffirms single-tap launch)
- `gamekit/gamekit/Screens/SettingsView.swift` — Existing 5-Classic-swatch theme picker pattern (do NOT duplicate; per CLAUDE.md §2 theme picker UX convention)

### Localization
- `gamekit/gamekit/Resources/Localizable.xcstrings` — All P3 user-facing strings ("You won!", "Bad luck", "Restart", "Change difficulty", "Abandon current game?", a11y label templates) ship with zero stale entries (FOUND-04 carries forward)

</canonical_refs>

<specifics>
## Specific Ideas

- End-state card title strings: **"You won!"** for win, **"Bad luck"** for loss. Localized via `String(localized:)`.
- Loss-only context line format: `"\(minesHit) mines hit / \(minesRemaining) safe cells left"` — educational, not scolding.
- Elapsed time display format: `mm:ss` for elapsed < 60min (typical case); `h:mm:ss` if > 60min (vanishingly rare on Hard but cheap to handle).
- Cell glyphs via SF Symbols — `flag.fill` (flag), `circle.fill` (mine glyph), `xmark` (wrong-flag X overlay on loss), `\(n)` text (adjacency numbers 1–8 rendered with `theme.colors.gameNumber(n)`).
- Toolbar Menu uses SF Symbol `slider.horizontal.3` or `gauge.medium` for the difficulty selector affordance (planner picks based on what reads cleanly under all 6 presets).
- Restart button uses SF Symbol `arrow.counterclockwise` (universal redo glyph).

</specifics>

<deferred>
## Deferred Ideas

- **Difficulty chip on Home Mines card** (so user picks before launching). Adds Home complexity that the current 8-disabled-placeholder grid avoids. Owner: future Home polish phase if needed; otherwise drop.
- **Chord-reveal on long-press of revealed numbered cell** (auto-reveal all unrevealed neighbors when flag count matches the number). Power-user MS feature; not in v1 — backlog.
- **Custom theme overrides for the gameNumber palette via `ThemeManager.overrides`** — owned by P5 THEME-03, not P3.
- **Pinch-zoom on the board** for accessibility (low-vision users). Likely lands as part of A11Y polish in P5; v1 ships horizontal-scroll-on-Hard only.
- **Animation cascade for reveal flood-fill** — engine D-06 returns the ordered `[Index]` list, but P3 ships instant render. P5 (MINES-08) layers animation via `phase: MinesweeperPhase`.
- **Best-time celebration** on win (record-setting overlay treatment). Owns P4/P5 once persistence ships.
- **"Are you sure?" on Restart from in-progress game.** Likely overkill; Restart is the primary "I want to start over" action — confirmation-on-Restart adds friction without preventing real mistakes. Defer unless user testing shows accidental-Restart problems.
- **Picker-on-Difficulty-tap (without alert) when game is paused** rather than on `.playing`. Edge case; D-10's `.playing` rule covers what matters.

</deferred>

---

*Phase: 03-mines-ui*
*Context gathered: 2026-04-25*
