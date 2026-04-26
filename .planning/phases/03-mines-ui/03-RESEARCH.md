# Phase 3: Mines UI — Research

**Researched:** 2026-04-25
**Domain:** SwiftUI 17+ game UI on top of locked Foundation-only engine layer (P2 ✓ verified)
**Confidence:** HIGH on stack/architecture (verified against on-disk DesignKit + GameKit code, P2 verification report, Apple docs); MEDIUM on a few interaction-tuning specifics (gesture threshold cross-device, exact monospace font rendering on legacy presets) which are surfaced as Open Questions.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**End-state overlay**
- **D-01:** End-state overlay = centered `DKCard` floating over a dimmed board backdrop. Win uses `theme.colors.success` accent; loss uses `theme.colors.danger`. Card is a single composed view (`MinesweeperEndStateCard`) parameterized by outcome + elapsed + mines-hit count.
- **D-02:** No tap-to-dismiss on the dim backdrop. User must tap the explicit Restart action inside the card.
- **D-03:** Card surfaces four pieces of content — outcome title via `String(localized:)`, final elapsed time, (loss only) "X mines hit / Y remaining" line, and two buttons (Restart primary + Change difficulty secondary opening the same toolbar Menu).
- **D-04:** Card uses `theme.radii.card`, `theme.spacing.l` outer padding, outcome-tinted accent only on title; body stays on `theme.colors.textPrimary` for legibility under all 6 preset categories.

**Timer architecture (SC2)**
- **D-05:** `TimelineView(.periodic(from: vm.timerAnchor, by: 1))`. ViewModel owns `timerAnchor: Date?` + `pausedElapsed: TimeInterval`. View derives `displayed = pausedElapsed + (now - timerAnchor)`. **No `Timer.publish`, no `Task` loop, no `Combine`.**
- **D-06:** scenePhase: on `.background` → `pause()` (`pausedElapsed += now - timerAnchor; timerAnchor = nil`). On `.active` while `gameState == .playing` → `resume()` (`timerAnchor = .now`). Idle/won/lost backgrounding = no-op.
- **D-07:** First tap starts the timer (`timerAnchor = .now` set inside the same call as `BoardGenerator.generate` + first `RevealEngine.reveal`). No "click-Start" affordance.
- **D-08:** Terminal-state transitions freeze elapsed using the same pause math so end-state card and live timer agree to the second.

**Difficulty switching surface**
- **D-09:** Top-trailing toolbar `Menu` (`MinesweeperToolbarMenu`) with Easy/Medium/Hard. Reused inside end-state card "Change difficulty" secondary action.
- **D-10:** Mid-game switch confirmation when `gameState == .playing` — `.alert("Abandon current game?", role: .destructive)` with Cancel / Abandon. From idle/won/lost, switch immediately, no alert.
- **D-11:** Difficulty persists via `UserDefaults` key `mines.lastDifficulty: String` using `MinesweeperDifficulty` raw values (`"easy" | "medium" | "hard"`). Read once at VM init; written on every successful `setDifficulty(_:)`. Default `.easy`.
- **D-12:** Home Mines card stays a single tap = "play last difficulty." No difficulty chip on Home for v1.

**DesignKit `theme.colors.gameNumber(_:)` token (THEME-02 + A11Y-04)**
- **D-13:** `extension Theme { func gameNumber(_ n: Int) -> Color }` returning per-preset entry for adjacency 1–8 (clamped). Implemented in `DesignKit/Sources/DesignKit/Theme/Tokens.swift`; backed by a fixed-length 8-array on `Theme`.
- **D-14:** Per-preset designer-tuned 8-color array. Each `PresetTheme` ships its own `gameNumberPalette: [Color]`. Classic ships traditional Minesweeper colors (1=blue, 2=green, 3=red, 4=dark-blue, 5=maroon, 6=cyan, 7=black, 8=grey). Loud presets ship neon-spectrum variants.
- **D-15:** A11Y-04 verification per preset via `DesignKitTests/GameNumberPaletteWongTests.swift` — simulates protanopia/deuteranopia/tritanopia and asserts perceptual ΔE between adjacent palette entries above threshold. Loud-preset audit may legitimately fail and trigger per-preset `gameNumberPaletteWongSafe: [Color]?` override; **Classic must pass unconditionally**.
- **D-16:** Token (not component) added to DesignKit. `DKNumberedCell` view stays in `Games/Minesweeper/` until at least one other game (Sudoku / Nonogram) needs it.

**Loss-state mine reveal (MINES-11 + SC4)**
- **D-17:** On loss: the trip mine renders with `theme.colors.danger` background fill; every other mine flips to a revealed-as-mine glyph; flags on non-mine cells render with an X overlay (`theme.colors.danger`) over the standard flag glyph.
- **D-18:** Loss reveal ships **without animation in P3** — instant flip on terminal-state transition. P5 layers cascade via `phase: MinesweeperPhase`.

**Cell accessibility (SC6 + A11Y-02 partial)**
- **D-19:** Every `MinesweeperCellView` exposes `accessibilityLabel` at view creation (not `.onAppear` retrofit) using a switch on `cell.state` with row/col 1-indexed.
- **D-20:** Buttons + overlay text strings ship `accessibilityLabel` at view creation. Full a11y audit (Reduce Motion, Dynamic Type, VO rotor, A11Y-01 / A11Y-03) is P5.

### Claude's Discretion

- **Board layout strategy for Hard 16×30 on iPhone SE (320pt).** Recommend **horizontal `ScrollView`** with cells fixed at ~22pt; full visibility of Easy 9×9 and Medium 16×16 (no scroll needed); scroll-only-on-Hard.
- **Cell view file split.** Split by responsibility, ~6 files: `MinesweeperGameView`, `MinesweeperHeaderBar`, `MinesweeperBoardView`, `MinesweeperCellView`, `MinesweeperToolbarMenu`, `MinesweeperEndStateCard`. Each <400 lines (CLAUDE.md §8.5).
- **`@Observable` VM observation strategy.** Recommend `@State` ownership inside `MinesweeperGameView` (iOS 17+ idiom; deinit guarantees timer cleanup with the view).
- **Restart button placement.** Recommend toolbar leading.
- **Long-press on already-revealed cell.** Recommend no-op for v1 (chord-reveal is backlog).
- **Tap on flagged cell.** Recommend no-op (preserves "flags are intentional commitments").
- **Mine glyph + flag glyph asset source.** SF Symbols only — `flag.fill` (flag), `circle.fill` (mine), `xmark` (wrong-flag X), `arrow.counterclockwise` (Restart), `slider.horizontal.3` (difficulty Menu).
- **Animation duration tokens.** Use `theme.motion.fast/normal/slow` for any P3 transitions.

### Deferred Ideas (OUT OF SCOPE)

- Difficulty chip on Home Mines card (deferred indefinitely — defer)
- Chord-reveal on long-press of revealed numbered cell (v2 backlog)
- Custom theme overrides for the gameNumber palette via `ThemeManager.overrides` (P5 THEME-03)
- Pinch-zoom on the board (P5 a11y polish)
- Animation cascade for reveal flood-fill (P5 MINES-08)
- Best-time celebration on win (P4/P5)
- "Are you sure?" on Restart from in-progress game (overkill — defer)
- Picker-on-Difficulty-tap without alert when game is paused (D-10's `.playing` rule covers what matters)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **MINES-02** | Tap to reveal, long-press to flag (`LongPressGesture(0.25s).exclusively(before: TapGesture())`) | §Pattern 1 (Gesture Composition); CONTEXT D-19, UI-SPEC §Gesture Composition |
| **MINES-05** | Mine counter (total − flagged) and elapsed wall-clock timer always visible; timer pauses on scene-phase background | §Pattern 2 (Timer + scenePhase); CONTEXT D-05/D-06; UI-SPEC §Typography (`monoNumber`) |
| **MINES-06** | Restart button on the game screen | §Pattern 4 (Toolbar layout); CONTEXT Discretion (toolbar leading) |
| **MINES-07** | Win = all non-mine cells revealed; Loss = mine revealed; both surface a clear end-state overlay using `theme.colors.{success,danger}` | §Pattern 3 (End-state overlay); CONTEXT D-01..D-04; engine `WinDetector.isWon`/`isLost` already verified P2 ✓ |
| **MINES-11** | On loss, all mines reveal and incorrectly-flagged cells are marked with an X indicator | §Pattern 5 (Loss-state reveal); CONTEXT D-17; engine `MinesweeperGameState.lost(mineIdx:)` already carries trip cell |
| **THEME-02** | Revealed/unrevealed cells, mines, flags, adjacency numbers all read from semantic tokens; new `theme.colors.gameNumber(_:)` (1–8) added to DesignKit | §Pattern 6 (DesignKit token addition); CONTEXT D-13..D-16; existing `Theme.swift` extension point verified |
| **A11Y-02 (partial)** | VoiceOver labels on cells baked at view creation | §Pattern 7 (Cell accessibilityLabel); CONTEXT D-19/D-20; iOS 17 `LocalizedStringKey`/`String(localized:)` patterns |
| **A11Y-04 (partial)** | Default number palette color-blind-safe by default — verified against Wong palette principles | §Pattern 6 + §Standard Stack — Color-blind audit; DesignKitTests Swift Testing pattern; CONTEXT D-15 |
</phase_requirements>

## Summary

P3 builds the playable Minesweeper UI on the verified P2 engine layer. The technical surface is small (one game scene, ~6 view files, one `@Observable` VM, one DesignKit token addition) but the correctness bar is high — gestures must not misfire, the timer must survive backgrounding/lock, color-blindness must be safe by default on the Classic preset, and zero `Color(...)` literals can leak into `Games/Minesweeper/`.

Three architectural decisions are non-negotiable and already locked in CONTEXT/UI-SPEC: (1) **`@Observable @MainActor` VM owned as `@State` by `MinesweeperGameView`**, (2) **`TimelineView(.periodic)` over a VM-owned `Date?` anchor — no `Timer.publish` or Combine**, and (3) **gesture composition `LongPressGesture(0.25).exclusively(before: TapGesture())`** at the cell level, not the board level. Three pre-commit hook constraints are also non-negotiable (the FOUND-07 hook in `.githooks/pre-commit` is verified to greenly reject `Color(...)`, numeric `cornerRadius:`, and numeric `padding(<int>)` only inside `Games/` and `Screens/` — App/ and Core/ are intentionally out of scope, and the new DesignKit `gameNumberPalette` lands in DesignKit not GameKit so its `Color(hex:)` calls are not subject to the hook).

**Primary recommendation:** Implement in five stages — (a) DesignKit `gameNumber(_:)` token + per-preset palette + Wong audit test (lands first because UI consumes it); (b) `MinesweeperViewModel` with all engine wiring + scenePhase + UserDefaults; (c) `MinesweeperHeaderBar` + `MinesweeperToolbarMenu` (smallest surfaces, validate timer + difficulty Menu); (d) `MinesweeperBoardView` + `MinesweeperCellView` (largest surface, gestures); (e) `MinesweeperEndStateCard` + `MinesweeperGameView` integration. This order minimizes rework — each stage is independently buildable and testable, and the engines are already locked.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Tap/long-press gesture arbitration | View (`MinesweeperCellView`) | — | iOS gesture system is view-tier; ViewModel only sees `reveal(at:)`/`toggleFlag(at:)` calls |
| Timer redraw cadence | View (`TimelineView` in `MinesweeperHeaderBar`) | ViewModel (state source) | View redraws via `TimelineView`; VM exposes `timerAnchor: Date?` and `pausedElapsed: TimeInterval` only |
| scenePhase pause/resume | View (`MinesweeperGameView` `.onChange(of: scenePhase)`) | ViewModel (handler) | SwiftUI exposes scenePhase only at the View tier; VM gets `pause()`/`resume()` calls |
| Engine orchestration (generate, reveal, flag) | ViewModel | — | View never imports engine modules; calls VM methods only |
| Win/loss detection | ViewModel (post-reveal hook) | — | VM calls `WinDetector.isWon/isLost` after every reveal pass and transitions `gameState` |
| Difficulty persistence | ViewModel + `UserDefaults` | — | Per CLAUDE.md §1: tiny key-value shape → UserDefaults wrapper, not SwiftData |
| Color-blind-safe number palette | DesignKit `Theme.gameNumber(_:)` token | View (consumer) | Token belongs in DesignKit per CLAUDE.md §2; 8-array data is per-preset (DesignKit owns `PresetTheme`) |
| End-state overlay rendering | View (`MinesweeperEndStateCard`) | ViewModel (outcome data) | VM exposes `outcome: GameOutcome`, `elapsed: TimeInterval`, `minesHit: Int` — view composes the DKCard |
| Loss-state mine flip + wrong-flag X | View (`MinesweeperBoardView` switching on `gameState`) | — | `Cell.state` only carries `.mineHit` for the trip cell; non-trip mines + wrong flags are rendered by VIEW reading the terminal `gameState` and the immutable Board, not by mutating Cell.state |
| Localization | View (every `String(localized:)` call site) | — | Engine layer is intentionally unlocalized (P2 D-03); view tier owns every user-visible string |
| Pre-commit hook discipline | Build/CI | All view files | `.githooks/pre-commit` enforces no `Color(...)`, no numeric `cornerRadius:`, no numeric `padding(<int>)` in `Games/` |

## Standard Stack

### Core (verified on disk; HIGH confidence)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 6.0+ (strict concurrency complete; verified `SWIFT_STRICT_CONCURRENCY = complete` from STATE.md) | Language | `@Observable @MainActor` VM is the iOS 17+ idiom — pre-locked by `.planning/research/ARCHITECTURE.md` §pattern-2 [VERIFIED: STATE.md] |
| SwiftUI | iOS 17.0 baseline | UI layer | All required APIs present in iOS 17 — `TimelineView(.periodic)` (iOS 15+), `LongPressGesture.exclusively(before:)` (iOS 13+), `@Observable` macro (iOS 17), `.onChange(of:scenePhase)` (iOS 17 two-arg form), `.alert(_:isPresented:actions:message:)` (iOS 15+) [CITED: developer.apple.com/documentation/swiftui/timelineview] |
| Foundation | iOS 17 | Engine layer (already there) | Engines stay Foundation-only — P2 SC5 verified, no engine work in P3 |
| DesignKit | local SPM dep at `../DesignKit` (no version pin per P1 D-08) | Tokens + DKCard/DKButton | Already linked; verified `Theme.swift`, `ThemeManager.swift`, `DKCard.swift`, `DKButton.swift` on disk [VERIFIED: file reads 2026-04-25] |
| Swift Testing | Xcode 16+ bundled | DesignKit `GameNumberPaletteWongTests` | P2 already replaced XCTest template with Swift Testing — same convention for DesignKitTests target [VERIFIED: STATE.md "02-06: Swift Testing replaces template scaffold"] |

### Supporting (in-ecosystem; no new third-party deps)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `UserDefaults` (`Foundation`) | iOS 17 | Persist `mines.lastDifficulty` (D-11) | Tiny key-value shape — CLAUDE.md §1 explicitly endorses; no SwiftData yet (P4) |
| `String(localized:)` (`Foundation`) | iOS 15+ | All P3 user-facing strings (`Resources/Localizable.xcstrings`) | FOUND-04/FOUND-05 already lock this convention; xcstrings catalog already exists with 25 P1 keys |
| `LocalizedStringKey` (`SwiftUI`) | iOS 14+ | `accessibilityLabel`/`accessibilityHint` accept it directly so interpolations land in the catalog automatically | Per Apple docs: both modifiers accept `LocalizedStringKey`, no manual extraction needed [CITED: developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv] |
| `TimelineView` + `.periodic(from:by:)` | iOS 15+ | Timer redraw cadence in `MinesweeperHeaderBar` (D-05) | SwiftUI may coalesce updates to conserve resources, so 1-second cadence is the right granularity (no millisecond display) [CITED: developer.apple.com/documentation/swiftui/timelineview] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `TimelineView(.periodic)` (D-05 LOCKED) | `Timer.publish` + Combine | Drifts on background per PITFALLS.md Pitfall 10; D-05 explicitly forbids |
| `@State viewModel: MinesweeperViewModel` (Discretion → recommend) | `@StateObject` (deprecated for `@Observable`) | `@StateObject` is for `ObservableObject`; `@Observable` requires `@State` per Apple iOS 17 idiom [CITED: forums.swift.org/t/state-usage-in-combination-with-injecting-observable-models-into-swiftui-views/84621] |
| Cell-level gesture composition | Board-level `DragGesture` arbitration | Loses per-cell hit-testing precision; complicates accessibility — UI-SPEC locks cell-level |
| `.simultaneously(with:)` | `.exclusively(before:)` (locked by UI-SPEC) | `.simultaneously` fires both, causing the "tap → reveal AND flag" misfire mode PITFALLS Pitfall 7 documents |
| SwiftData for last-difficulty | `UserDefaults` (D-11 LOCKED) | SwiftData is overkill for a single-key string; CLAUDE.md §1 explicitly carves out UserDefaults |

**Installation:** No `npm install` equivalent. Add no new SPM packages — DesignKit is already linked, and there are no new third-party deps in P3 per the constitution. New folders (`Games/Minesweeper/Engine/` already exists; `Games/Minesweeper/` will gain new top-level files alongside the existing engine + models) auto-register through `PBXFileSystemSynchronizedRootGroup` (`objectVersion = 77`) — empirically validated across all of P2 [VERIFIED: STATE.md "02-06: CLAUDE.md §8.8 fully validated"].

**Version verification:** All dependencies are first-party Apple frameworks bundled with iOS 17 / Xcode 16. DesignKit is a local-path SPM dep (no version pin per P1 D-08); the four verified files (`Theme.swift`, `Tokens.swift`, `DKCard.swift`, `DKButton.swift`) are read from `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/` directly.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Phase 3 Surface Map                         │
└─────────────────────────────────────────────────────────────────┘

USER GESTURE                                    OS / SYSTEM EVENT
   │                                                     │
   ▼                                                     ▼
┌────────────────────────┐                    ┌───────────────────┐
│  MinesweeperCellView   │                    │  scenePhase       │
│  (Tap or LongPress)    │                    │  (.bg/.active)    │
│  .gesture(LongPress    │                    └────────┬──────────┘
│   .exclusively(before: │                             │
│   TapGesture()))       │                             │
└──────────┬─────────────┘                             │
           │                                           │
           │ vm.reveal(at:) /                          │ .onChange(of: scenePhase)
           │ vm.toggleFlag(at:)                        │ → vm.pause() / vm.resume()
           ▼                                           ▼
   ┌─────────────────────────────────────────────────────────────┐
   │            MinesweeperViewModel  (@Observable @MainActor)    │
   │                                                              │
   │   board: MinesweeperBoard                                    │
   │   gameState: MinesweeperGameState  (idle/playing/won/lost)   │
   │   difficulty: MinesweeperDifficulty                          │
   │   timerAnchor: Date?           (nil = paused)                │
   │   pausedElapsed: TimeInterval  (accumulator)                 │
   │   private rng = SystemRandomNumberGenerator()                │
   │                                                              │
   │   func reveal(at:)        ← engine: BoardGenerator.generate  │
   │                              (first tap), then               │
   │                              RevealEngine.reveal             │
   │                              then WinDetector.isWon/isLost   │
   │   func toggleFlag(at:)    ← Board.replacingCell only         │
   │   func setDifficulty(_:)  ← writes UserDefaults              │
   │   func restart()          ← board=empty, anchor=nil, state=  │
   │                              .idle, keep difficulty           │
   │   func pause()/resume()   ← timer math (D-06)                │
   └────────┬──────────────────────────┬───────────────────┬──────┘
            │                          │                   │
            │ derived state            │ engine calls      │ UserDefaults
            ▼                          ▼                   ▼
   ┌────────────────┐    ┌──────────────────────────┐  ┌──────────────┐
   │  Header / Card │    │  P2 Engines (LOCKED)     │  │  UserDefaults│
   │  views         │    │  - BoardGenerator        │  │  "mines.last │
   │  TimelineView  │    │  - RevealEngine          │  │   Difficulty"│
   │  derives the   │    │  - WinDetector           │  └──────────────┘
   │  display       │    │  Foundation-only,        │
   │  string from   │    │  pure value types        │
   │  vm.timerAnchor│    └──────────────────────────┘
   └────────────────┘

DesignKit (read-only):
  ┌──────────────────────────────────────────────────────────────┐
  │  ../DesignKit/Sources/DesignKit/                             │
  │   Theme/Tokens.swift           ← gameNumber(_:) extension    │
  │                                  + ThemeColors gameNumber-   │
  │                                  Palette: [Color] (length 8) │
  │   Theme/PresetTheme.swift      ← + gameNumberPalette per     │
  │                                  preset (or central catalog) │
  │   Theme/ThemeResolver.swift    ← merges per-preset palette   │
  │                                  into resolved Theme         │
  │   Components/DKCard.swift      ← end-state overlay wrapper   │
  │   Components/DKButton.swift    ← Restart + Change difficulty │
  │   Tests/GameNumberPalette                                    │
  │     WongTests.swift            ← Swift Testing audit (D-15)  │
  └──────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
gamekit/gamekit/
├── App/
│   └── GameKitApp.swift                       # (no changes — P1 ✓)
├── Core/                                      # (no changes in P3 — Core stays cross-game)
├── Games/
│   └── Minesweeper/
│       ├── MinesweeperBoard.swift             # P2 ✓ (do not modify)
│       ├── MinesweeperCell.swift              # P2 ✓
│       ├── MinesweeperDifficulty.swift        # P2 ✓
│       ├── MinesweeperGameState.swift         # P2 ✓
│       ├── MinesweeperIndex.swift             # P2 ✓
│       ├── Engine/                            # P2 ✓ (do not modify)
│       │   ├── BoardGenerator.swift
│       │   ├── RevealEngine.swift
│       │   └── WinDetector.swift
│       │
│       ├── MinesweeperViewModel.swift         # NEW — orchestration brain (~350-450 lines)
│       ├── MinesweeperGameView.swift          # NEW — top-level scene (~250 lines)
│       ├── MinesweeperHeaderBar.swift         # NEW — counter + timer (~120 lines)
│       ├── MinesweeperBoardView.swift         # NEW — grid layout (~200 lines)
│       ├── MinesweeperCellView.swift          # NEW — single tile + gestures + a11y (~220 lines)
│       ├── MinesweeperToolbarMenu.swift       # NEW — difficulty Menu (~80 lines)
│       └── MinesweeperEndStateCard.swift      # NEW — overlay (~180 lines)
│
├── Resources/
│   └── Localizable.xcstrings                  # AUGMENTED — ~30 new keys (a11y templates + UI strings)
├── Screens/
│   ├── HomeView.swift                         # MINOR EDIT — replace `minesweeperPlaceholder`
│   │                                            (current line 105–123) with NavigationLink to
│   │                                            `MinesweeperGameView` per D-12
│   └── (others unchanged — P1 ✓)

../DesignKit/Sources/DesignKit/
├── Theme/
│   ├── Tokens.swift                           # AUGMENTED — add `gameNumberPalette: [Color]`
│   │                                            field to ThemeColors + gameNumber(_:) helper
│   ├── PresetTheme.swift                      # AUGMENTED — per-preset gameNumberPalette
│   │                                            (or sibling Palette.swift catalog)
│   ├── Theme.swift                            # AUGMENTED — `func gameNumber(_ n: Int) -> Color`
│   │                                            convenience that clamps + reads ThemeColors
│   └── ThemeResolver.swift                    # AUGMENTED — propagates gameNumberPalette through
│                                                resolve(preset:scheme:overrides:) — including the
│                                                Wong-safe override fallback per D-15
└── Tests/
    └── DesignKitTests/
        └── GameNumberPaletteWongTests.swift   # NEW — Swift Testing, per D-15
```

### Pattern 1: Cell-Level Gesture Composition (MINES-02 / SC1)

**What:** Each `MinesweeperCellView` carries its own `.gesture(LongPressGesture(minimumDuration: 0.25).exclusively(before: TapGesture()))`. Long-press wins if the user holds; tap fires only on quick release.

**When to use:** The locked SC1 spec — cell-level, not board-level. Board-level gesture arbitration (`DragGesture` over the grid) loses per-cell hit testing and breaks VoiceOver per-cell focus order.

**Example (from CONTEXT D-19 + UI-SPEC §Gesture):**

```swift
// MinesweeperCellView body
// Source: composed from CONTEXT D-19, UI-SPEC §Gesture, PITFALLS Pitfall 7
struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let index: MinesweeperIndex
    let cellSize: CGFloat
    let theme: Theme
    let gameState: MinesweeperGameState
    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    var body: some View {
        TileBackground(cell: cell, theme: theme, gameState: gameState)
            .frame(width: cellSize, height: cellSize)
            .overlay(glyph)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
            .contentShape(Rectangle()) // ensures full-tile hit area
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first:  onLongPress(index)   // long-press won
                        case .second: onTap(index)          // tap won
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
    }

    // Computed at view creation — D-19. Returns a LocalizedStringKey
    // so SwiftUI auto-extracts to the xcstrings catalog without a
    // separate String(localized:) call.
    private var accessibilityLabel: LocalizedStringKey {
        switch cell.state {
        case .hidden:
            return "Unrevealed, row \(index.row + 1) column \(index.col + 1)"
        case .revealed where cell.adjacentMineCount == 0:
            return "Revealed, 0 mines adjacent, row \(index.row + 1) column \(index.col + 1)"
        case .revealed:
            return "Revealed, \(cell.adjacentMineCount) mines adjacent, row \(index.row + 1) column \(index.col + 1)"
        case .flagged:
            return "Flagged, row \(index.row + 1) column \(index.col + 1)"
        case .mineHit:
            return "Mine, row \(index.row + 1) column \(index.col + 1)"
        }
    }
}
```

**Why `.exclusively(before:)`:** prevents the "tap → reveal AND flag fired" misfire mode. The 0.25s threshold is load-bearing per ROADMAP SC1.

**Anti-Pattern to avoid:** `.simultaneously(with:)` — both gestures fire, breaks the reveal/flag invariant.

### Pattern 2: Timer via TimelineView + scenePhase Pause/Resume Math (MINES-05 / SC2)

**What:** Timer is rendered with `TimelineView(.periodic(from: vm.timerAnchor, by: 1))` inside `MinesweeperHeaderBar`. The VM owns `timerAnchor: Date?` and `pausedElapsed: TimeInterval`. The view derives `displayed = pausedElapsed + (now - (timerAnchor ?? now))` per render tick. **No `Timer.publish`. No `Combine`. No `Task.sleep` loop.**

**When to use:** The locked D-05 architecture. Wall-clock-based; survives backgrounding because the `Date` arithmetic happens at every redraw on `.active`, and `pause()` snapshots the elapsed before the OS suspends the app.

**Example:**

```swift
// MinesweeperHeaderBar body — derived from D-05 + D-06 + D-08
struct MinesweeperHeaderBar: View {
    let theme: Theme
    let minesRemaining: Int
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            // Mine counter — vm.minesRemaining derived from total - flaggedCount
            counterChip(value: minesRemaining)
            Spacer()
            // Timer chip — TimelineView redraws once per second
            // SwiftUI coalesces sub-second updates [CITED: developer.apple.com/documentation/swiftui/timelineview]
            timerChip
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    @ViewBuilder
    private var timerChip: some View {
        // When anchor is nil, the periodic schedule still fires once with
        // the current date, but our display math returns pausedElapsed —
        // so the timer reads as frozen. This is correct behavior in idle
        // (00:00) and won/lost (frozen final time) states.
        TimelineView(.periodic(from: timerAnchor ?? .now, by: 1)) { context in
            Text(formatElapsed(displayedElapsed(at: context.date)))
                .font(theme.typography.monoNumber)        // monospace — no jitter
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityLabel(timerA11yLabel)
                .accessibilityValue(formatElapsedSpoken(displayedElapsed(at: context.date)))
        }
    }

    private func displayedElapsed(at now: Date) -> TimeInterval {
        guard let anchor = timerAnchor else {
            return pausedElapsed                // paused / idle / terminal
        }
        return pausedElapsed + now.timeIntervalSince(anchor)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
    // formatElapsedSpoken — see UI-SPEC §Copywriting "A11y: Timer"
}
```

**ViewModel pause/resume math:**

```swift
@Observable @MainActor
final class MinesweeperViewModel {
    var timerAnchor: Date?
    var pausedElapsed: TimeInterval = 0
    var gameState: MinesweeperGameState = .idle

    func pause() {
        guard case .playing = gameState, let anchor = timerAnchor else { return }
        pausedElapsed += Date.now.timeIntervalSince(anchor)
        timerAnchor = nil
    }

    func resume() {
        guard case .playing = gameState, timerAnchor == nil else { return }
        timerAnchor = .now
    }
}
```

**Subtlety — system-clock change during play:** if the user rolls back the system clock while the timer is running, `now.timeIntervalSince(anchor)` returns a negative interval. The `max(0, Int(t))` clamp in `formatElapsed` keeps the displayed string at "0:00" rather than "-1:30". For a calm-premium app this is correct — better to under-display than to crash, panic, or freeze. Documented as Open Question Q1 (no recommended P3 fix; flag for P5 if user reports).

**Subtlety — lock-screen brief lock vs full background:** iOS sends `.inactive` briefly between `.active` and `.background` (e.g. control-center pull, lock-screen flash). D-06 watches `.background` only — `.inactive` is a no-op. This is correct: a one-second lock-screen flash should not pause the timer. Verified via `scenePhase` enum cases — `.active`, `.inactive`, `.background`. We act on `.background → pause`, `.active → resume`, ignore `.inactive`.

### Pattern 3: End-State Overlay via DKCard + Backdrop ZStack (MINES-07 / SC4)

**What:** End-state card is a centered `DKCard` floating over a dimmed full-board backdrop. Visibility driven by `vm.gameState != .playing && vm.gameState != .idle` — i.e. `.won` or `.lost(_)`. No tap-to-dismiss on the dim layer per D-02.

**Backdrop choice:** `ZStack` with `theme.colors.background.opacity(0.85)` covering the full board (UI-SPEC §Layout). Rejected alternatives:
- `.overlay(alignment:)` — gives correct positioning but doesn't dim the underlying board so the loss-state mine reveal underneath can't be glanced back at after dismissing context.
- `.fullScreenCover` / `.sheet` — fully obscures the final board; user can't see the trip mine + revealed mines. UI-SPEC explicitly chose ZStack to preserve glance-back.
- `Material.regularMaterial` — opacity not theme-token-controlled, would invalidate THEME-02 token discipline. **Reject.**

**Example:**

```swift
// MinesweeperGameView body excerpt
ZStack {
    boardScene  // header, board, toolbar — always rendered

    if let outcome = vm.terminalOutcome {
        // Backdrop — token-compliant; tap-through is INTENTIONALLY blocked
        // (no .onTapGesture), per D-02
        theme.colors.background
            .opacity(0.85)
            .ignoresSafeArea()
            .accessibilityHidden(true)            // backdrop is not a focus stop

        MinesweeperEndStateCard(
            theme: theme,
            outcome: outcome,
            elapsed: vm.frozenElapsed,
            minesHit: vm.lossContext?.minesHit ?? 0,
            safeCellsRemaining: vm.lossContext?.safeCellsRemaining ?? 0,
            onRestart: { vm.restart() },
            onChangeDifficulty: { showingDifficultyMenu = true }
        )
        .frame(maxWidth: 320)
        .padding(theme.spacing.l)
    }
}
```

### Pattern 4: Toolbar Layout — Restart Leading + Difficulty Menu Trailing (MINES-06)

**What:** `.toolbar` with `ToolbarItem(placement: .topBarLeading)` for Restart and `ToolbarItem(placement: .topBarTrailing)` for the `MinesweeperToolbarMenu`. Restart uses SF Symbol `arrow.counterclockwise` rendered on `theme.colors.textPrimary`; Menu uses `slider.horizontal.3`.

**When to use:** Always-visible per SC3. iOS-native convention (mirrors Mail, Notes, Reminders). Single-tap, no footer clutter, friendly to iPhone SE (no horizontal pressure).

### Pattern 5: Loss-State Mine Reveal — Per-Cell View Switch on `gameState` (MINES-11 / SC4)

**What:** When `gameState == .lost(mineIdx:)`, `MinesweeperCellView` switches its rendering by reading the terminal `gameState` plus the immutable Board:

```swift
// MinesweeperCellView rendering logic — derived from D-17
private var glyph: some View {
    switch (cell.state, cell.isMine, gameState) {
    // Trip cell — flagged red background (D-17 step 1)
    case (.mineHit, _, _):
        Image(systemName: "circle.fill")
            .foregroundStyle(theme.colors.textPrimary)
            .background(theme.colors.danger)

    // Other un-flagged mines after loss (D-17 step 2)
    case (.hidden, true, .lost):
        Image(systemName: "circle.fill")
            .foregroundStyle(theme.colors.textPrimary)

    // Wrong-flag — flag glyph + xmark overlay after loss (D-17 step 3)
    case (.flagged, false, .lost):
        ZStack {
            Image(systemName: "flag.fill").foregroundStyle(theme.colors.danger)
            Image(systemName: "xmark").foregroundStyle(theme.colors.danger)
        }

    case (.flagged, _, _):
        Image(systemName: "flag.fill").foregroundStyle(theme.colors.danger)

    case (.revealed, _, _) where cell.adjacentMineCount > 0:
        Text("\(cell.adjacentMineCount)")
            .font(.system(size: cellSize * 0.55, weight: .bold, design: .rounded))
            .foregroundStyle(theme.gameNumber(cell.adjacentMineCount))

    case (.revealed, _, _):
        EmptyView()                               // 0-adjacency — blank

    default:
        EmptyView()
    }
}
```

**Why this works:** The engine's `Board` is immutable (D-10). The Cell.state enum has only 4 cases — `.hidden / .revealed / .flagged / .mineHit`. The trip mine is the only mine with `.mineHit`; non-trip mines stay `.hidden` and wrong flags stay `.flagged`. The view tier derives the loss-state reveal by reading `gameState` and `cell.isMine` together — no engine extension needed. P5 layers animation via `MinesweeperPhase` enum without changing this contract.

### Pattern 6: DesignKit Token Addition — `theme.gameNumber(_:)` (THEME-02 + A11Y-04)

**What:** Add a per-preset 8-color palette to DesignKit and expose a `Theme.gameNumber(_ n: Int) -> Color` convenience that clamps `n` to `1...8`.

**Three concrete file edits in `../DesignKit/Sources/DesignKit/`:**

1. **`Theme/Tokens.swift`** — extend `ThemeColors` with a new field:
   ```swift
   public struct ThemeColors {
       // ... existing 16 fields ...
       public let gameNumberPalette: [Color]  // length 8 — invariant: count == 8
       // update init to accept gameNumberPalette: [Color]
   }
   ```
2. **`Theme/PresetTheme.swift`** (or a sibling `Palette.swift`) — extend `PresetAnchors` with `gameNumberPalette: [Color]?` (nil = use a Wong-safe default catalog), then per-preset declarations specify their palette explicitly.
3. **`Theme/Theme.swift`** — add the convenience function:
   ```swift
   public extension Theme {
       func gameNumber(_ n: Int) -> Color {
           let clamped = max(1, min(8, n))
           return colors.gameNumberPalette[clamped - 1]
       }
   }
   ```

**Why this layout:** The hex literals live in DesignKit — they're not subject to the GameKit pre-commit hook (the hook scopes to `gamekit/gamekit/(Games|Screens)/`, verified at `.githooks/pre-commit`). Existing `PresetTheme.swift` already uses `Color(hex: "...")` extensively (e.g. line 137 `legacyLightBG = Color(hex: "#F8FAFC")`). Adding `gameNumberPalette` follows the same pattern.

**Wong-safe default catalog (Classic, default):** Traditional Minesweeper:
- 1: `#0000FF` (blue)
- 2: `#008000` (green)
- 3: `#FF0000` (red)
- 4: `#000080` (dark blue)
- 5: `#800000` (maroon)
- 6: `#008080` (cyan)
- 7: `#000000` (black) → falls back to `theme.colors.textPrimary` rendering on dark presets via per-preset override
- 8: `#808080` (grey)

Note on entry 7: the literal "black" obviously fails legibility on Dracula/dark presets. The per-preset palette declaration is mandatory — Classic ships the traditional palette but Dracula must ship a dark-preset variant. This is exactly the per-preset gating D-14 contemplates.

**Wong-audit test (D-15):** `DesignKitTests/GameNumberPaletteWongTests.swift` simulates protanopia/deuteranopia/tritanopia transformations and asserts perceptual ΔE ≥ threshold (typically ΔE ≥ 10 for "noticeably distinct" per CIE ΔE2000) between every adjacent pair (1↔2, 2↔3, ..., 7↔8) AND non-adjacent pairs that commonly co-occur (1 and 4 are both blue-family — must remain distinguishable).

**Color-blind transform implementations** (Swift, no third-party):
- The simulation matrices (Brettel et al. 1997, Vienot et al. 1999, refined Machado et al. 2009) are 3×3 RGB transforms. ~30 lines of `simd_float3x3`-or-equivalent matrix math operating on linear RGB. [CITED: openaccess.thecvf.com — Machado et al. "A Physiologically-based Model for Simulation of Color Vision Deficiency"]
- ΔE2000: ~50 lines. Convert sRGB → Lab via `Color`'s `cgColor` → `CGColorConverter` doesn't exist on iOS, so do the math in Swift directly. Pure Foundation.

**This is a one-time test that pays off forever** — each new preset added to DesignKit gets audited mechanically. Per D-15 the Classic preset assertion is unconditional; loud-preset failures may opt in to a `gameNumberPaletteWongSafe: [Color]?` override.

### Pattern 7: Cell Accessibility — `LocalizedStringKey` Auto-Extraction (A11Y-02 partial)

**What:** SwiftUI's `accessibilityLabel(_:)` accepts `LocalizedStringKey` directly [CITED: developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv]. The xcstrings extractor (`SWIFT_EMIT_LOC_STRINGS=YES`, already on per FOUND-04) auto-extracts string interpolations passed to `accessibilityLabel(_:)` — no manual `String(localized:)` call needed.

**Pattern (from D-19):**
```swift
.accessibilityLabel("Revealed, \(cell.adjacentMineCount) mines adjacent, row \(index.row + 1) column \(index.col + 1)")
```

This single literal lands in `Localizable.xcstrings` automatically with the interpolations parameterized. `String(localized:)` is also acceptable but redundant — pick one convention per file and stay consistent. Recommend the `LocalizedStringKey`-implicit form for simple cases (cell labels, button titles) and explicit `String(localized:)` for non-Text/non-accessibility consumers (e.g. alert title strings passed to `.alert(_:isPresented:)` which wants `LocalizedStringKey`).

**VoiceOver focus order on a 480-cell grid (Hard):** SwiftUI defaults to top-to-bottom, left-to-right traversal which matches the row/column-numbered labels users hear. No `.accessibilitySortPriority` needed. The 480-cell `LazyVGrid` may show an audible-traversal latency hitch on iPhone SE — flag as Open Question Q3 (P5 polish to address if user reports).

**`.accessibilityElement(children: .ignore)` per cell:** prevents the SF Symbol glyph (e.g. `flag.fill`) from being announced as "image" between the cell's spoken label and the next cell's label. Required.

### Anti-Patterns to Avoid

- **Re-fetching theme tokens inside cell views:** All 480 cells re-evaluating `themeManager.theme(using: colorScheme)` on every redraw is wasteful. Hoist `let theme = themeManager.theme(using: colorScheme)` to the parent view (`MinesweeperGameView` or `MinesweeperBoardView`) and pass `theme` as a `let` to children.
- **Importing SwiftUI in `MinesweeperViewModel`:** ARCHITECTURE.md Anti-Pattern 1. VM imports only `Foundation` (and `Observation` for `@Observable`). Animation is the View's job.
- **Calling `WinDetector` inside `RevealEngine`:** ARCHITECTURE.md Anti-Pattern 2 / Engine D-07. VM is the integrator.
- **Multiple `NavigationStack`s for the game scene:** ARCHITECTURE.md Anti-Pattern 3. `HomeView` already owns its `NavigationStack` (verified at line 29) — `MinesweeperGameView` is pushed into it via `NavigationLink`.
- **`@Query` inside reusable card subviews:** Not applicable in P3 (no SwiftData yet) but ensures P4 doesn't slip a query into `MinesweeperEndStateCard`. The card takes pre-computed props only.
- **`Color(...)` literal anywhere in `Games/Minesweeper/`:** PITFALLS Pitfall 8 + the FOUND-07 hook will reject it. The new `theme.gameNumber(_:)` token has 8 palette entries that DesignKit owns — `Games/` consumes via `theme.gameNumber(n)`.
- **Numeric `.padding(<int>)` or `cornerRadius: <int>`:** same hook. Even cell tile dimensions (44/40/36pt) are intrinsic component constants — pass through `private let cellSize: CGFloat` declared at function scope, then use `.frame(width: cellSize, height: cellSize)` (the hook regex matches `.padding(\s*[0-9]+)`, NOT `.frame(width:height:)`). Verified: hook regex `\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)` does not match `.frame(width: cellSize, height: cellSize)`.
- **`Timer.publish` / `Timer.scheduledTimer`:** D-05 explicitly forbids. Use `TimelineView`.
- **`@StateObject` for `@Observable` types:** API mismatch — `@StateObject` requires `ObservableObject`. Use `@State` for `@Observable` types (iOS 17+ idiom).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Periodic timer redraw | `Timer.publish` / `Task { while ... await Task.sleep }` accumulator | `TimelineView(.periodic(from:by:))` (D-05) | TimelineView coalesces sub-second updates and cooperates with SwiftUI's redraw budget; Timer.publish drifts on background per PITFALLS Pitfall 10 |
| Tap/long-press arbitration | Custom `DragGesture.onChanged` state machine | `LongPressGesture(0.25).exclusively(before: TapGesture())` | Built-in primitive; locked by SC1; PITFALLS Pitfall 7 lists every misfire mode of hand-rolled |
| Tiny key-value persistence | SwiftData `@Model` for last-difficulty | `UserDefaults` wrapper (D-11) | CLAUDE.md §1 explicit carve-out; SwiftData is overkill |
| Localized string interpolation | Manual `Localizable.strings` + `NSLocalizedString` | `String(localized:)` + `Localizable.xcstrings` (already at `Resources/`) | FOUND-05 locks this; xcstrings auto-extracts via `SWIFT_EMIT_LOC_STRINGS=YES` |
| Color-blind simulation | New SPM dependency for color science | ~80 lines Swift in DesignKitTests using Brettel/Machado matrices + ΔE2000 | One-time test investment; never adds to runtime; no third-party (constitution) |
| Card visual treatment for end-state overlay | Custom `RoundedRectangle.stroke + fill` recipe | `DKCard(theme:content:)` (already in DesignKit) | DKCard already supplies `theme.spacing.l` outer padding + `theme.radii.card` + `theme.colors.surface` background + `theme.colors.border` stroke. UI-SPEC explicitly bans local restyling |
| Restart / Change-difficulty buttons | Custom Button + RoundedRectangle + foreground | `DKButton(_:style:.primary/.secondary, theme:, action:)` | Already supplies 44pt min height + accent fill + token-correct corner; verified at `DKButton.swift:33-44` |
| Cell glyphs (mine, flag, X, restart, menu trigger) | Custom SVG / PNG assets | SF Symbols (`circle.fill`, `flag.fill`, `xmark`, `arrow.counterclockwise`, `slider.horizontal.3`) | Dynamic Type, theme tinting via `.foregroundStyle()`, no asset shipping cost; UI-SPEC §Component Inventory explicit |
| Counter / timer chip styling | Custom HStack pill | Reuse `theme.colors.surface` fill + `theme.radii.chip` corner inside HeaderBar | Token-correct; matches future game HeaderBars without new patterns |
| Mid-game-switch confirmation | Custom modal sheet | `.alert(_:isPresented:actions:message:)` with `.destructive` Abandon button (D-10) | Native; matches iOS HIG; auto-localizes Cancel via system; far less code |

**Key insight:** Every hand-roll temptation in P3 has an Apple-native or DesignKit-native equivalent. The constitution forbids third-party deps and the existing P1 + P2 commits prove the team has held the line; P3 should not be the first time it's broken.

## Common Pitfalls

(Drawn from PITFALLS.md and applied to the P3 surface.)

### Pitfall 1: `@State`-owned `@Observable` VM memory leak (iOS 17.0–17.1)

**What goes wrong:** Storing a reference type as `@State` could leak the VM after view dismissal in iOS 17.0/17.1 [CITED: developer.apple.com/forums/thread/736239]. The leak was fixed in iOS 17.2 beta 1 [CITED: developer.apple.com/forums/thread/736239 — Apple confirmed].

**Why it happens:** SwiftUI's regression around `@Observable` reference type ownership; `@StateObject` was the intended owner originally for reference types but is API-incompatible with `@Observable`.

**How to avoid:** Set the iOS deployment target to 17.0 (already locked at 17.0 per FOUND-04) but document in PR description that the VM uses `@State` per Apple's iOS 17.2+ guidance. For users on iOS 17.0/17.1: the leak is a one-time per game-screen-dismiss event of `MinesweeperViewModel` size (~few KB plus the immutable Board ~4KB on Hard). Acceptable for v1; not worth working around with a `@StateObject` shim that fights the `@Observable` macro.

**Warning signs:** Memory use grows on repeated game-scene push/pop cycles. Use Instruments → Allocations and verify VM deinits on `MinesweeperGameView` dismissal. If it leaks: add `.onDisappear { vm.invalidate() }` calling a manual nil-out helper. Not expected to be needed.

**Phase to address:** P3 (acknowledge + monitor); P5 if symptomatic.

### Pitfall 2: `scenePhase` `.inactive` vs `.background` confusion

**What goes wrong:** Pausing on `.inactive` instead of `.background`. iOS sends `.inactive` for control-center pulls, lock-screen flashes, and incoming-call interruptions even when the app isn't actually backgrounded. Pausing on `.inactive` makes a 1-second control-center pull stop the timer.

**Why it happens:** `scenePhase` enum has three cases — `.active`, `.inactive`, `.background`. Confusing the first two is common.

**How to avoid:** Watch `.background` ONLY for the pause path (D-06 verbatim). On `.active` while `gameState == .playing`, resume. `.inactive` is a no-op.

**Warning signs:** Timer freezes when the user pulls down control center.

**Phase to address:** P3.

### Pitfall 3: 480-cell `LazyVGrid` re-renders all cells on every state change

**What goes wrong:** PITFALLS Pitfall 6. Every reveal causes 480 cells to re-evaluate body. Frame drops on Hard.

**Why it happens:** `MinesweeperCell` is `Equatable, Hashable, Codable, Sendable` (verified at MinesweeperCell.swift:30) — SwiftUI diffing CAN short-circuit, BUT only if the cell view itself is structured to take a single `Cell` value (not a closure capturing `self`). And the cell view receiving `theme` as a parameter recomputes when `theme` reference identity changes — every theme switch redraws everything (acceptable; theme switches are rare).

**How to avoid:**
1. `MinesweeperCellView` takes `cell: MinesweeperCell` by value (already a `struct`; cheap).
2. Pass `theme` explicitly as a parameter, not via environment lookup inside the cell — hoists the theme derivation to the parent.
3. Pass `cellSize` and `gameState` as `let` props; `gameState` changes infrequently (only on terminal state) so the all-cells redraw on win/loss is correct (loss-state mine reveal switches every cell's glyph).
4. If profiling on iPhone SE shows hitches, escalate per PITFALLS Pitfall 6 escalation order: `.equatable()` modifier → `drawingGroup()` on the board container → `Canvas` (last resort).

**Warning signs:** Frame drops during reveal cascade on iPhone SE / iPhone 11 in Instruments.

**Phase to address:** P3 (defensive structure now); P5 if profiling shows actual drops.

### Pitfall 4: `MinesweeperToolbarMenu` mid-game switch race condition

**What goes wrong:** User picks Hard from the Menu while a Medium game is playing. The naive flow — set `vm.difficulty = .hard` then show alert — causes the View to read the new difficulty before the user confirms, briefly displaying a Hard board. If they Cancel, you have to revert.

**Why it happens:** Coupling the user's pick to `vm.difficulty` immediately, then asking permission afterwards.

**How to avoid:** The Menu calls `vm.requestDifficultyChange(.hard)`. The VM checks `gameState`:
- If `.idle`/`.won`/`.lost`: apply immediately + write UserDefaults.
- If `.playing`: set `vm.pendingDifficultyChange = .hard` and `vm.showingAbandonAlert = true`. The View reads `vm.showingAbandonAlert` for the `.alert` presentation. The Abandon button calls `vm.confirmDifficultyChange()` which actually applies; Cancel calls `vm.cancelDifficultyChange()` which clears `pendingDifficultyChange`.

**Warning signs:** Board flickers between difficulties on cancel.

**Phase to address:** P3.

### Pitfall 5: VoiceOver "image" announcement between cell labels

**What goes wrong:** SF Symbol glyph inside the cell announces as "image, [cell label]" rather than just "[cell label]." Causes 480 redundant "image" calls on a Hard board.

**Why it happens:** SwiftUI exposes child `Image` views as their own accessibility elements unless explicitly hidden.

**How to avoid:** `.accessibilityElement(children: .ignore)` on the cell's outer Tile view (after `.accessibilityLabel`). SF Symbols inside are then non-announcing.

**Warning signs:** VoiceOver sweep over a partial Hard board takes noticeably longer than expected, repeats "image."

**Phase to address:** P3 (bake in at view creation per A11Y-02).

### Pitfall 6: `gameNumberPalette` per-preset failure mode silently degrades

**What goes wrong:** Per D-15, loud-preset Wong audits are allowed to fail and trigger `gameNumberPaletteWongSafe: [Color]?` override. If the override path isn't actually wired into `ThemeResolver.swift`, the failing palette ships with the preset and a colorblind user reads a Voltage-themed Hard board with indistinguishable 1/2/3.

**Why it happens:** Two-path code (default palette vs Wong-safe override) where the test asserts the test path, not the runtime path.

**How to avoid:** The Wong audit test must call `Theme.resolve(preset:scheme:)` (the production resolver) and read `theme.colors.gameNumberPalette` — not test the per-preset declaration field directly. This way the resolver-applied override IS the thing under test.

**Warning signs:** Test passes for preset X, but `theme.gameNumber(2)` returns the failing color in production.

**Phase to address:** DesignKit pre-P3-completion.

### Pitfall 7: Pre-commit hook false-positive on legitimate Color uses

**What goes wrong:** The hook regex matches `Color\.gray|Color\.red|...` — any legit reference like `theme.colors.danger` does NOT match, but a quick-prototype `let warningTint = Color.red` slips into a feature commit and gets blocked.

**Why it happens:** Developer copy-pastes from elsewhere or muscle-memory.

**How to avoid:** Document the violation patterns in the plan task descriptions so any new contributor knows the hook is there. Read .githooks/pre-commit before authoring view files. **The hook only scopes to `gamekit/gamekit/(Games|Screens)/`** — DesignKit edits are NOT subject to it (verified at line 14: `^gamekit/gamekit/(Games|Screens)/.*\.swift$`). New `gameNumberPalette` Color literals in DesignKit are fine.

**Warning signs:** Commit gets blocked at hook stage with "hardcoded Color literal" message.

**Phase to address:** Plan-task description level (planner inserts a "no Color() literals" reminder in task body).

### Pitfall 8: Localizable.xcstrings stale entries on rename

**What goes wrong:** Hardcoded a11y string template ("Revealed, %d mines adjacent...") gets renamed mid-implementation. Old key sticks around in `Localizable.xcstrings` as a "Stale" entry; passes the build but pollutes the catalog and adds dead translation overhead.

**Why it happens:** xcstrings auto-extracts new keys but does not auto-delete stale ones.

**How to avoid:** Pre-commit (manual) — open `Localizable.xcstrings` in Xcode's catalog editor, filter "Stale," delete. PITFALLS-style ship gate.

**Warning signs:** Catalog grows; "Stale" badge in Xcode.

**Phase to address:** P3 plan task ending — verification step "no stale entries in xcstrings."

## Code Examples

### Example 1: VM `reveal(at:)` — first-tap timer start + engine orchestration

```swift
// MinesweeperViewModel — derived from CONTEXT D-07, D-08, ARCHITECTURE Pattern 1, P2 verified engine API
@Observable @MainActor
final class MinesweeperViewModel {
    private(set) var board: MinesweeperBoard
    private(set) var gameState: MinesweeperGameState = .idle
    private(set) var difficulty: MinesweeperDifficulty
    private(set) var flaggedCount: Int = 0
    private(set) var timerAnchor: Date?
    private(set) var pausedElapsed: TimeInterval = 0
    private(set) var lossContext: (minesHit: Int, safeCellsRemaining: Int)?

    private var rng = SystemRandomNumberGenerator()

    var minesRemaining: Int { board.mineCount - flaggedCount }
    var frozenElapsed: TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + Date.now.timeIntervalSince(anchor)
    }
    var terminalOutcome: GameOutcome? {
        switch gameState {
        case .won:    return .win
        case .lost:   return .loss
        default:      return nil
        }
    }

    init(difficulty: MinesweeperDifficulty? = nil) {
        let d = difficulty
            ?? MinesweeperDifficulty(rawValue: UserDefaults.standard.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy
        self.difficulty = d
        self.board = MinesweeperBoard(
            difficulty: d,
            cells: Array(repeating: MinesweeperCell(isMine: false, adjacentMineCount: 0), count: d.cellCount)
        )
    }

    func reveal(at index: MinesweeperIndex) {
        // Idle → first tap: generate populated board, start timer
        if case .idle = gameState {
            board = BoardGenerator.generate(difficulty: difficulty, firstTap: index, rng: &rng)
            gameState = .playing
            timerAnchor = .now
            pausedElapsed = 0
        }
        guard case .playing = gameState else { return }

        let result = RevealEngine.reveal(at: index, on: board)
        board = result.board

        // Win/loss check after every reveal pass — engines are mutually exclusive (P2 ✓)
        if WinDetector.isLost(board) {
            // Find the trip mine to surface in MinesweeperGameState.lost(mineIdx:)
            if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
                gameState = .lost(mineIdx: mineIdx)
                lossContext = computeLossContext()
            }
            freezeTimer()
        } else if WinDetector.isWon(board) {
            gameState = .won
            freezeTimer()
        }
    }

    func toggleFlag(at index: MinesweeperIndex) {
        guard case .playing = gameState else { return }
        let cell = board.cell(at: index)
        switch cell.state {
        case .hidden:
            board = board.replacingCell(at: index,
                with: MinesweeperCell(isMine: cell.isMine, adjacentMineCount: cell.adjacentMineCount, state: .flagged))
            flaggedCount += 1
        case .flagged:
            board = board.replacingCell(at: index,
                with: MinesweeperCell(isMine: cell.isMine, adjacentMineCount: cell.adjacentMineCount, state: .hidden))
            flaggedCount -= 1
        case .revealed, .mineHit:
            return  // no-op per Discretion ("flags are intentional commitments")
        }
    }

    private func freezeTimer() {
        if let anchor = timerAnchor {
            pausedElapsed += Date.now.timeIntervalSince(anchor)
        }
        timerAnchor = nil
    }

    private func computeLossContext() -> (minesHit: Int, safeCellsRemaining: Int) {
        let minesHit = board.cells.filter { $0.state == .mineHit }.count
        let safeCellsRemaining = board.cells.filter { !$0.isMine && $0.state != .revealed }.count
        return (minesHit, safeCellsRemaining)
    }

    private static let lastDifficultyKey = "mines.lastDifficulty"
}

enum GameOutcome: Equatable, Sendable { case win, loss }
```

### Example 2: scenePhase wiring in the top-level scene

```swift
// MinesweeperGameView.swift — derived from CONTEXT D-06
struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    init() {
        _viewModel = State(initialValue: MinesweeperViewModel())
    }

    var body: some View {
        // ... boardScene ZStack ...
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    viewModel.pause()
                case .active:
                    viewModel.resume()
                case .inactive:
                    break  // no-op per D-06 Pitfall 2
                @unknown default:
                    break
                }
            }
    }
}
```

### Example 3: DesignKit Wong-audit test (Swift Testing)

```swift
// DesignKitTests/GameNumberPaletteWongTests.swift — derived from D-15
import Testing
import SwiftUI
@testable import DesignKit

@Suite("Game Number Palette — Wong-Safe Audit")
struct GameNumberPaletteWongTests {

    @Test("Classic preset palette must be perceptually distinct under all 3 CVD types — UNCONDITIONAL per D-15",
          arguments: [
              ColorVisionDeficiency.protanopia,
              .deuteranopia,
              .tritanopia
          ])
    func classicPalettePassesWongAudit(cvd: ColorVisionDeficiency) {
        let theme = Theme.resolve(preset: .forest, scheme: .light)
        let palette = theme.colors.gameNumberPalette
        #expect(palette.count == 8, "gameNumberPalette must contain exactly 8 entries")

        // For every adjacent pair (1↔2, 2↔3, ..., 7↔8) AND blue-family
        // collisions (1↔4 — blue and dark blue), assert ΔE2000 ≥ 10
        let pairs = (0..<7).map { ($0, $0 + 1) } + [(0, 3)]
        for (i, j) in pairs {
            let dE = perceptualDelta(palette[i], palette[j], simulating: cvd)
            #expect(dE >= 10.0, "Classic palette entries \(i+1) and \(j+1) too similar under \(cvd) (ΔE = \(dE))")
        }
    }

    @Test("Loud presets may use Wong-safe override — verify resolver applies it",
          arguments: [ThemePreset.voltage, .vaporwave, .ember, .ghostOrchid, .frostlime])
    func loudPresetsResolverAppliesWongSafeOverride(preset: ThemePreset) {
        let theme = Theme.resolve(preset: preset, scheme: .dark)
        // The resolver must always emit a length-8 palette — even if the
        // preset declared `gameNumberPaletteWongSafe` only.
        #expect(theme.colors.gameNumberPalette.count == 8)
    }
}
```

## Runtime State Inventory

P3 is a greenfield-features phase (no rename / refactor / migration), but the phase introduces persistence — so a quick inventory:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — first time UserDefaults `mines.lastDifficulty` is written. No prior writes to read or migrate. | None — fresh install |
| Live service config | None — no n8n, no datadog, no external service. Verified by reading STATE.md + project structure (no `.cloudkit`, no external API config). | None |
| OS-registered state | None — no Windows Task Scheduler, no launchd plists, no pm2. iOS app sandbox only. | None |
| Secrets/env vars | None — no API keys, no env vars. iCloud / SIWA capabilities are P6, not P3. | None |
| Build artifacts | None new beyond compiled `.swift` → `.o`. The 7 new view files auto-register through `PBXFileSystemSynchronizedRootGroup` (P2 validated). DesignKit edits propagate via local-path SPM. | None — verified P2 §STATE.md "02-06: §8.8 fully validated" |

**Nothing found in any category** that requires a data migration or out-of-source-control update.

## Validation Architecture

> Required by `workflow.nyquist_validation: true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` / `#expect`), bundled with Xcode 16 |
| Config file | None separate — test target is `gamekitTests` (already exists, P1+P2 validated) and `DesignKitTests` (already exists in DesignKit) |
| Quick run command | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:gamekitTests/MinesweeperViewModelTests` |
| Full suite command | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 15'` (runs gamekitTests + DesignKitTests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MINES-02 | Tap reveals; long-press flags; gestures don't misfire | manual-only on real iPhone SE (cross-device touch latency varies); auto-test the VM-level reveal/toggleFlag transitions | `xcodebuild test … -only-testing:gamekitTests/MinesweeperViewModelTests/RevealAndFlagTests` | ❌ Wave 0 |
| MINES-05 (timer) | Timer pauses on `.background`, resumes on `.active`, freezes on terminal | unit (mock `Date.now`) | `… -only-testing:gamekitTests/MinesweeperViewModelTests/TimerStateTests` | ❌ Wave 0 |
| MINES-05 (counter) | `minesRemaining = total − flagged`; updates on toggleFlag | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/MineCounterTests` | ❌ Wave 0 |
| MINES-06 | Restart resets board to idle, keeps difficulty | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/RestartTests` | ❌ Wave 0 |
| MINES-07 (overlay) | Win → `.won` outcome; loss → `.lost(mineIdx:)` outcome (engines verified P2; here: VM transitions correctly) | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/TerminalStateTests` | ❌ Wave 0 |
| MINES-11 (loss reveal) | Wrong-flag detection in `lossContext`; mine count surfaced | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/LossContextTests` | ❌ Wave 0 |
| THEME-02 (token) | `theme.gameNumber(_:)` clamps `n` to `1...8`; returns palette entry | unit | `xcodebuild test … -only-testing:DesignKitTests/ThemeGameNumberTests` | ❌ Wave 0 |
| THEME-02 (no Color() literals in Games/) | grep adversarial — `grep -RE 'Color\.(red\|gray\|blue\|...)' gamekit/gamekit/Games/Minesweeper/` returns 0 | smoke (CI shell + `.githooks/pre-commit`) | `git diff --cached` | ✅ (`.githooks/pre-commit` exists) |
| A11Y-04 | Wong-safe Classic palette under protanopia/deuteranopia/tritanopia (ΔE ≥ 10) | unit (deterministic; pure math) | `xcodebuild test … -only-testing:DesignKitTests/GameNumberPaletteWongTests` | ❌ Wave 0 |
| Difficulty persistence (D-11) | `mines.lastDifficulty` UserDefaults round-trip | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/DifficultyPersistenceTests` | ❌ Wave 0 |
| **Manual / human-only** | — | — | — | — |
| SC1 (gesture misfire rate) | 50 manual taps on iPhone SE-class hardware, 0 misfires | manual-only | n/a — recorded in `03-VERIFICATION.md` | n/a |
| SC2 (cross-device timer) | Timer pauses correctly on real device control-center pull, lock-screen flash, full background | manual-only | n/a | n/a |
| SC4/CLAUDE.md §8.12 (theme legibility) | Hard board + loss state visually verified on 6 presets (Forest / Bubblegum / Barbie / Cream / Dracula / Voltage) per UI-SPEC §Theme Matrix | manual-only — screenshots attached to `03-VERIFICATION.md` | n/a | n/a |
| VoiceOver navigation | VO sweep through partial Hard board reads correct row/col labels | manual-only | n/a (`.accessibilityLabel` is unit-asserted; full focus-order sweep needs human ear) | n/a |

### Sampling Rate

- **Per task commit:** `xcodebuild test … -only-testing:gamekitTests/MinesweeperViewModelTests` — VM-only run, completes in ≈ 5 seconds.
- **Per wave merge:** Full `xcodebuild test … gamekit` + `swift test` in DesignKit — completes in ≈ 30 seconds.
- **Phase gate:** Full suite green AND all 6 manual screenshots in `03-VERIFICATION.md` AND 50-tap iPhone SE gesture log AND VO sweep log before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` — covers MINES-02/05/06/07/11 + difficulty persistence (Wave 0 gap)
- [ ] `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` — pre-built boards for state transition tests (Wave 0 gap)
- [ ] `DesignKit/Tests/DesignKitTests/ThemeGameNumberTests.swift` — token clamp + palette length contracts (Wave 0 gap)
- [ ] `DesignKit/Tests/DesignKitTests/GameNumberPaletteWongTests.swift` — A11Y-04 audit (Wave 0 gap)
- [ ] `DesignKit/Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift` — Brettel/Machado matrix transforms + ΔE2000 (Wave 0 gap, ~80 lines pure Foundation)
- [ ] No framework install needed — Swift Testing is bundled.

## Project Constraints (from CLAUDE.md)

Phase 3 must verify compliance with these directives. Planner must include a verification step for each.

| Directive | Source | P3 Application |
|-----------|--------|----------------|
| Swift 6 + SwiftUI + SwiftData (no SwiftData yet — P4) | §1 Stack | Swift 6 strict concurrency on; SwiftUI for all P3 view code; engines stay Foundation-only |
| Lightweight MVVM | §1 Stack | `@Observable @MainActor` VM; pure value-type Board (verified P2) |
| iOS 17+ | §1 Stack | `TimelineView`, `@Observable`, `LongPressGesture.exclusively(before:)` all available |
| Offline-only — no backend, no cloud, no analytics, no accounts | §1 Stack | P3 has no network code; UserDefaults only |
| No ads / coins / fake currency / energy / aggressive subs | §1 Product | No P3 surface adds any of these |
| App must launch instantly. Cold-start latency is P0 | §1 Product | P3 adds no startup work; `MinesweeperGameView` is `NavigationLink`-pushed lazily |
| No popups, modals, or push-y UX on first run | §1 Product | Only modal in P3 is the mid-game-switch confirmation alert (D-10) — explicitly user-initiated |
| Implement Export/Import JSON with `schemaVersion` for stats | §1 Data | N/A in P3 (P4) |
| Schema changes additive when possible | §1 Data | N/A in P3 |
| Never delete user data automatically | §1 Data | Restart resets board state but does NOT touch UserDefaults difficulty preference (verified design) |
| Avoid bundle ID changes once the app is in daily use | §1 Data | P3 makes no `pbxproj` edits |
| **No hard-coded colors / radii / spacing in UI** | §1 Design (NON-NEGOTIABLE) | Pre-commit hook enforces; new `theme.gameNumber(_:)` token covers number palette; cell dimensions are intrinsic component constants in `private let cellSize: CGFloat` (hook regex doesn't match `.frame(width:cellSize)` — verified) |
| All styling reads DesignKit semantic tokens | §1 Design | Every P3 view file imports DesignKit; reads `theme.colors.*`, `theme.spacing.*`, `theme.radii.*`, `theme.typography.*`, `theme.motion.*` |
| **Games must remain usable under any DesignKit preset** | §1 Design | UI-SPEC §Theme Matrix names 6 audit presets (Forest / Bubblegum / Barbie / Cream / Dracula / Voltage); §8.12 mandates verification |
| "Personality" comes from preset + layout emphasis, not random styling | §1 Design | P3 adds no preset-specific carve-outs in `Games/Minesweeper/` — all preset variation lives in DesignKit's per-preset palette |
| What goes into DesignKit: Tokens · ThemeManager · Generic components | §2 DesignKit | `theme.gameNumber(_:)` is a TOKEN (per-game palette); the cell view is single-game and stays in `Games/` |
| What does NOT go into DesignKit: Game logic / game-specific views / game-specific haptics unless 2+ games | §2 DesignKit | `MinesweeperCellView`, `MinesweeperEndStateCard`, etc. all stay in `Games/Minesweeper/` |
| Available radii: `card | button | chip | sheet`; spacing: `xs | s | m | l | xl | xxl`; chart opacities | §2 DesignKit | Verified all radius and spacing tokens used in UI-SPEC are in DesignKit (`Tokens.swift`, `SpacingTokens.swift`, `RadiusTokens.swift`) |
| Theme picker UX: 5 Classic swatches inline + "More themes…" link | §2 DesignKit | N/A in P3 (Settings is P5) |
| Project structure: `App/`, `Core/`, `Games/<Name>/`, `Screens/` | §3 Structure | P3 ships 7 new files into existing `Games/Minesweeper/` (no new top-level folders) |
| Reuse existing patterns; don't invent | §4 Rules | P3 reuses ARCHITECTURE.md §pattern-2 (Observable VM) + Pattern 3 (Phase enum) |
| Smallest change that satisfies the requirement | §4 Rules | P3 adds 7 view files, 1 VM, 4 DesignKit edits — no scaffolding |
| Promote to DesignKit only when proven (2+ games) | §4 Rules | `theme.gameNumber(_:)` is a TOKEN (allowed in DesignKit single-game per §2); no view promotion |
| Game engines are pure / testable | §4 Rules | Engines locked P2; P3 only consumes |
| Write code immediately when asked to implement | §4 Rules | Planner inserts implement steps, not plan-files |
| Check the codebase before suggesting | §4 Rules | This research already verified all DesignKit surfaces, hook scope, existing model files |
| Unit tests for game engines | §5 Testing | N/A — engines verified P2 ✓; P3 unit-tests the VM only |
| Verify Export/Import round-trip where stats persist | §5 Testing | N/A in P3 |
| UI tests minimal unless explicitly requested | §5 Testing | P3 ships zero XCUITests; manual SC1 gesture verification + theme legibility audit instead |
| New pure services ship with tests in same commit | §5 Testing | `MinesweeperViewModel` ships with `MinesweeperViewModelTests.swift` in the same commit |
| Definition of done: code compiles + behavior verified + structure/token rules followed + works under Classic + Loud/Moody preset | §6 Done | P3 plans must include a "verified on Forest + Voltage" checkbox before marking done |
| Vertical slice > architecture; clarity > abstraction; TODO hook > overbuilding | §7 Unsure | All applied in plan ordering recommendation |
| File size cap ~400 lines (views) / 500 lines (hard cap, all .swift) | §8.1 / §8.5 | UI-SPEC §Component Inventory caps each view <400 lines; VM <500 lines |
| Reusable views are data-driven, not data-fetching | §8.2 | `MinesweeperEndStateCard`, `MinesweeperHeaderBar`, `MinesweeperBoardView`, `MinesweeperCellView` all take props only — no `@Query`, no `@Environment(ModelContext)` (no SwiftData yet) |
| Every data-driven view ships with explicit empty state | §8.3 | UI-SPEC §Copywriting "Empty state — initial board" defines the pre-first-tap state explicitly (silent — no "Tap to start" affordance) |
| Verify theme tokens exist before using them | §8.4 | This research verified `radii.{card, button, chip, sheet}`, `spacing.{xs..xxl}`, `motion.{fast, normal, slow, ease}`, `typography.{titleLarge, title, headline, body, caption, monoNumber}` all on disk |
| No monolithic Swift files (<500 lines hard cap) | §8.5 | Per UI-SPEC, all 7 view files <250 lines except VM <500 |
| `.foregroundStyle` not `.foregroundColor` (iOS 17+) | §8.6 | Every code example uses `.foregroundStyle()` |
| Confirm layout doesn't push content off-screen on smallest device | §8.6 | UI-SPEC §Layout: iPhone SE 320pt verified for Easy (no scroll) and explicitly horizontal-scrolls on Hard |
| Never tolerate Finder-dupe `* 2.swift` files | §8.7 | `.githooks/pre-commit` blocks; verified at line 5 |
| New `.swift` files in existing folders auto-register | §8.8 | P2 fully validated; P3 same path |
| Test-runner crashes in NSStagedMigrationManager → uninstall, don't debug | §8.9 | P3 adds no SwiftData; not applicable |
| Commit discipline — one feature or one grouped batch per commit | §8.10 | Planner enforces (research suggests 5 stages = 5+ commits) |
| First-tap safety in Minesweeper is a hard requirement | §8.11 | Engine-side verified P2 ✓ (400-assertion fuzz test). P3 wires VM to call `BoardGenerator.generate(firstTap:)` correctly |
| Game-screen theme passes mandatory before "done" | §8.12 | UI-SPEC §Theme Matrix names the 6 audit presets explicitly; verification artifact = screenshots attached to `03-VERIFICATION.md` |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Timer.scheduledTimer` accumulator | `TimelineView(.periodic)` + `Date` anchor | iOS 15 (TimelineView ships); iOS 17 strict concurrency makes the timer-actor coupling cleaner | D-05 locks the modern path |
| `@StateObject` for view model ownership | `@State` for `@Observable final class` | iOS 17 (`@Observable` macro replaces `ObservableObject` for new code) | iOS 17.0/17.1 had a leak regression; fixed 17.2+ — accept and monitor |
| `accessibilityLabel(_:)` taking only `Text` | Accepts `LocalizedStringKey` for auto-extraction to `.xcstrings` | iOS 14+ (long-stable) | Single literal at call site lands correctly in catalog |
| `.onChange(of:)` single-arg form | `.onChange(of:initial:)` two-arg form (or new closure with old/new) | iOS 17 | Two-arg form `.onChange(of: scenePhase) { _, newPhase in ... }` is the new idiom — used in code examples |
| Manual `Timer.publish + Combine.assign` plumbing | Single `TimelineView { context in derive(at: context.date) }` | iOS 15 → recommended over Combine for time-based UI | Less code, no concurrency hand-tuning |

**Deprecated/outdated:**
- `Timer.publish().autoconnect()` for UI timers — drifts on background; PITFALLS Pitfall 10 documents the replacement
- `@ObservedObject` for view-owned models — replaced by `@State` + `@Observable` for new code
- `.foregroundColor()` modifier — replaced by `.foregroundStyle()` in iOS 17 per CLAUDE.md §8.6

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | iPhone SE 1st-gen / 2nd-gen / iPhone 13 mini width budget — 320pt usable for Easy fits at 44pt cells, Medium scrolls at 40pt | UI-SPEC §Layout (carried into Pattern 1) | If wrong, Easy 9×9 with 4pt gap = 432pt > 320pt — would need horizontal scroll on Easy too. Acceptable fallback; UI-SPEC already documents `Easy 432pt` and recommends scrolling. | [ASSUMED — needs measurement on real iPhone SE] |
| A2 | iOS 17.0/17.1 `@State`-owned `@Observable` leak is fixed in 17.2+ as Apple says | §Pitfall 1 | If unfixed in production, MinesweeperViewModel leaks per game-scene-dismiss (~few KB). Bounded; acceptable for v1. | [CITED: developer.apple.com/forums/thread/736239 — but not personally verified on hardware] |
| A3 | The `.githooks/pre-commit` regex doesn't match `.frame(width: cellSize, height: cellSize)` | §Pattern 1 + Pitfall 7 | If the hook DOES match cellSize (it shouldn't — regex requires literal digits), every cell view edit would be blocked. Verifiable in seconds at plan time. | [VERIFIED: regex `\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)` requires digits, `cellSize` is identifier] |
| A4 | `LongPressGesture(0.25).exclusively(before:)` works correctly across iPhone SE / iPhone 14+ without misfires when threshold is 0.25s | §Pattern 1 | If iPhone SE shows >0% misfire rate, SC1 fails — would need to bump threshold or add explicit `DragGesture`-arbitrated state machine | [ASSUMED — locked by UI-SPEC; manual 50-tap test on real SE is in the verification path] |
| A5 | Color-blind matrices (Brettel/Machado) reduce a ~50-line implementation; ΔE2000 ~50 lines; total ~100 lines pure Swift | §Don't Hand-Roll + Pattern 6 | If implementation is more complex than ~100 lines, the "no third-party dep" calculus shifts (still doable, just longer). Doesn't change the architectural decision. | [CITED: openaccess.thecvf.com Machado et al. — but the Swift implementation is hypothetical] |
| A6 | Existing `Localizable.xcstrings` accepts new keys via `SWIFT_EMIT_LOC_STRINGS=YES` already enabled | §Pattern 7 | Verified `extractionState: "manual"` on existing P1 entries — the build setting is on; new strings auto-extract | [VERIFIED: Localizable.xcstrings line 6 `extractionState : "manual"` — but build setting per FOUND-04 history] |
| A7 | Hex literals in DesignKit's new `gameNumberPalette` are NOT subject to GameKit's pre-commit hook | §Pattern 6 | Verified by reading `.githooks/pre-commit` — hook scope is `gamekit/gamekit/(Games|Screens)/`, not DesignKit | [VERIFIED: pre-commit line 14] |
| A8 | iPhone SE 320pt + 432pt Easy board (no scroll) passes touch-target HIG (44pt min) — but the Easy board AT 432pt overflows 320pt by 112pt, so Easy MUST scroll on iPhone SE | UI-SPEC §Layout | UI-SPEC explicitly documents "Easy 432pt — fits iPhone SE (320pt) with horizontal scroll" — confirmed not at-issue | [VERIFIED: UI-SPEC line 167] |
| A9 | The new `Theme.gameNumber(_:)` token can be added to DesignKit without causing a major version break for sister apps (HabitTracker, FitnessTracker, PantryPlanner) | §Pattern 6 | If sister apps use `Theme.colors.*` reflectively or have a `ThemeColors` shape lock, adding a field requires their bumps. Best practice: add as default-valued in init, sister apps continue to compile. | [ASSUMED — not verified by reading sister app code] |

## Open Questions

1. **System clock change during play**
   - **What we know:** `Date.now.timeIntervalSince(anchor)` returns a negative interval if the user rolls back the system clock mid-game. The `max(0, Int(t))` clamp in `formatElapsed` handles display, but `frozenElapsed` could underflow if a clock-rollback happens between an active anchor and `freezeTimer()`.
   - **What's unclear:** How often this actually happens in practice (probably never on iOS — iOS doesn't expose a quick clock-change UI like macOS does, but timezone changes from travel still trigger it).
   - **Recommendation:** Defer to P5. Add a `max(0, …)` clamp inside `frozenElapsed` and move on.

2. **`MinesweeperPhase` enum upfront vs deferred**
   - **What we know:** ARCHITECTURE.md §Pattern 3 + UI-SPEC explicitly says P3 lays the foundation, P5 adds animations. CONTEXT D-18 says "P3's loss view must be authored so P5 can layer animation in via `phase: MinesweeperPhase` enum changes without touching V/VM contracts."
   - **What's unclear:** Whether to ship a stub `MinesweeperPhase.idle` enum in P3 (hold the V/VM seam) or wait until P5.
   - **Recommendation:** Ship a minimal stub `enum MinesweeperPhase: Equatable { case idle }` on the VM as `var phase: MinesweeperPhase = .idle`. P5 adds cases without touching the View/VM contract. ~5 lines of forward-compatibility insurance. Planner decides whether to include in P3 plan or defer to P5; either is defensible.

3. **VoiceOver focus-order on 480-cell Hard board**
   - **What we know:** SwiftUI defaults to top-to-bottom, left-to-right traversal. Per-cell `.accessibilityElement(children: .ignore)` + parameterized `accessibilityLabel` per D-19.
   - **What's unclear:** Whether iPhone SE has audible-traversal latency hitches on 480 elements. Anecdotal: 100+ elements in a single screen sometimes shows VO lag.
   - **Recommendation:** Treat as P5 polish; ship the labels in P3 per D-19 (mandatory), defer perf tuning. If user reports lag, P5 can add `.accessibilityElement(children: .combine)` on row containers to chunk navigation.

4. **iPhone SE-class hardware availability**
   - **What we know:** SC1 requires "50 manual taps on iPhone SE-class hardware (320pt width)." The current iPhone SE 3rd-gen (released 2022) has 375pt width per `Device.swift` measurements, NOT 320pt. The original iPhone SE (2016) and SE 2nd-gen (2020) are 320pt.
   - **What's unclear:** Whether the team has a 320pt SE 1st/2nd-gen device available for SC1 verification, or whether SE 3rd-gen at 375pt suffices.
   - **Recommendation:** Verify on the smallest-width iOS 17-supported device the team has. iOS 17 deprecated SE 1st-gen (which doesn't run iOS 17 anyway — iPhone 8 and SE 1st-gen capped at iOS 16). Smallest iOS 17 device is iPhone SE 2nd-gen (320pt) or iPhone Mini 13 (375pt). Recommend the team test on whichever they own; flag in `03-VERIFICATION.md`.

5. **`@Bindable` not needed for `@Observable`**
   - **What we know:** `@Bindable` enables `$vm.foo` two-way binding for `@Observable` types (typically for TextField).
   - **What's unclear:** P3 uses `@State` ownership and reads VM state — no two-way bindings needed (the user gestures call VM methods, not bind to VM properties).
   - **Recommendation:** No `@Bindable` in P3. If a future surface needs `$vm.something` for `.alert(isPresented:)`, decide between exposing a VM-internal `Bool` via `@Bindable` vs deriving from VM state. The mid-game-switch alert in D-10 suggests a VM-internal `var showingAbandonAlert: Bool` is needed — bind via `@Bindable` at presentation site.

## Environment Availability

(P3 has no external service dependencies — pure code/config phase. Skip is appropriate but documented for completeness.)

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16 | Swift Testing, `@Observable`, iOS 17 | ✓ (verified P1+P2 builds) | 16.x (per STATE.md "Xcode 16 (`objectVersion = 77`)") | None — required |
| iOS 17 Simulator | Test runs | ✓ (P2 verified `xcodebuild test` exit 0) | 17.x (P2 used `iPhone 15` simulator) | iPhone SE 320pt simulator for SC1 — 16 supports SE 2nd-gen |
| DesignKit (local SPM) | All view files + `theme.gameNumber(_:)` token addition | ✓ (P1 wired; verified file reads) | local-path (no version pin per P1 D-08) | None |
| Real iPhone SE 320pt | SC1 manual gesture test | Open Question Q4 — TBD | iOS 17+ | If unavailable, document on simulator + flag for early-TestFlight feedback |

**Missing dependencies with no fallback:** None blocking implementation; SC1 hardware is the only nominally external requirement and can be substituted with simulator + early TestFlight if needed.

## Sources

### Primary (HIGH confidence — verified on disk or via Apple docs in this session)

- `/Users/gabrielnielsen/Desktop/GameKit/CLAUDE.md` — Project constitution (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/phases/03-mines-ui/03-CONTEXT.md` — 20 locked design decisions (D-01..D-20) (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/phases/03-mines-ui/03-UI-SPEC.md` — 6/6 PASS design contract (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/phases/02-mines-engines/02-VERIFICATION.md` — Engine API verified passing (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/research/ARCHITECTURE.md` — `@Observable` VM, MinesweeperPhase pattern (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/research/PITFALLS.md` — All 14 pitfalls with phase mapping (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.planning/research/STACK.md` — Stack decisions (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/.githooks/pre-commit` — Token-discipline hook scope verified (read 2026-04-25)
- `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/Games/Minesweeper/*.swift` — All 5 P2 model files + 3 engine files read 2026-04-25
- `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Theme/{Theme,Tokens,PresetTheme,ThemeManager}.swift` — DesignKit surfaces verified
- `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Components/{DKCard,DKButton}.swift` — verified
- `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Layout/{SpacingTokens,RadiusTokens}.swift` — verified
- [TimelineView | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/timelineview)
- [accessibilityLabel(_:) | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv)
- [LongPressGesture | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/longpressgesture)

### Secondary (MEDIUM confidence — community sources cross-referenced with Apple docs)

- [State usage in combination with injecting @Observable models — Swift Forums](https://forums.swift.org/t/state-usage-in-combination-with-injecting-observable-models-into-swiftui-views/84621)
- [State ViewModel memory leak in iOS 17 (new Observable) — Apple Developer Forums](https://developer.apple.com/forums/thread/736239)
- [SwiftUI View Models: Lifecycle Quirks — The Swift Cooperative](https://medium.com/the-swift-cooperative/swiftui-view-models-lifecycle-quirks-8dd967e84e31)
- [Mastering TimelineView in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/)
- [Custom accessibility content in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2021/10/06/custom-accessibility-content-in-swiftui/)
- [Conditional SwiftUI Accessibility Labels — Use Your Loaf](https://useyourloaf.com/blog/conditional-swiftui-accessibility-labels/)

### Tertiary (LOW confidence — flagged in Assumptions Log)

- A5 (Wong matrix Swift implementation length) — based on cross-reference with Brettel/Machado papers; not personally implemented in this session

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries Apple-bundled, verified on disk
- Architecture: HIGH — every pattern traceable to a CONTEXT or UI-SPEC lock + ARCHITECTURE.md prior decision
- Pitfalls: HIGH — all 14 PITFALLS.md items mapped to P3 specifically; iOS 17 leak is the highest-risk item, mitigated
- DesignKit token surface: HIGH — verified `Theme`, `ThemeColors`, `PresetTheme` shapes on disk
- Color-blind audit implementation: MEDIUM — Brettel/Machado matrices are public-domain math but Swift implementation is from-scratch (no existing reference)
- iPhone SE physical hardware availability: LOW — Open Question Q4

**Research date:** 2026-04-25
**Valid until:** 2026-05-25 (30 days for stable iOS 17 stack; sooner if iOS 18 ships and changes `@Observable` lifecycle behavior; revisit if DesignKit gets a major version bump from a sister app's needs)
