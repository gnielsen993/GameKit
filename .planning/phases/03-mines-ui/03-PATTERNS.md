# Phase 3: Mines UI — Pattern Map

**Mapped:** 2026-04-25
**Files in scope:** 12 (9 NEW GameKit, 1 EDIT GameKit, 1 NEW DesignKit, 1 EDIT DesignKit, 1 EDIT GameKit Resources, 1 EDIT DesignKit, 1 NEW DesignKit Test) — see classification table for exact disposition.
**Analogs found:** 7 / 12 strong (Phase 1/2 file-header style, themed-scaffold view shape, DKCard wrapping, ThemeManager env wiring, hex-Color preset entry, P2 Swift Testing scaffold, pre-commit token discipline). 5 NEW PATTERNS — first SwiftUI game-screen phase, no `@Observable` VM in repo yet, no `TimelineView`/`scenePhase`/`.alert`/`Menu`/`.toolbar`/cell-grid gesture composition exists in repo yet.

**Genuine "NEW PATTERN" rows:** 5 — `MinesweeperViewModel` (no `@Observable` VM exists), `MinesweeperHeaderBar` (no `TimelineView` exists), `MinesweeperBoardView` (no `LazyVGrid` cell grid exists), `MinesweeperCellView` (no gesture composition exists), `MinesweeperToolbarMenu` (no `.toolbar` `Menu` exists in repo).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` (NEW, ~400 lines) | view-model (`@Observable @MainActor final class`) | event-driven (gesture → engine → state) + UserDefaults persist | None — first VM in repo | NEW PATTERN |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (NEW, ~250 lines) | view (top-level scene) | request-response (gestures → vm methods); event-driven (scenePhase → vm.pause/resume) | `gamekit/gamekit/Screens/HomeView.swift` (NavigationStack + theme env wiring) | role-match (NavigationStack + theme env), but adds `@State` `@Observable` VM, scenePhase, `.toolbar`, `.alert` |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` (NEW, ~120 lines) | view (data-driven, props-only) | request-response (renders `vm.minesRemaining` + `timerAnchor` per-tick via `TimelineView`) | `gamekit/gamekit/Screens/ComingSoonOverlay.swift` (chip-style HStack with token discipline) | role-match (chip pattern); `TimelineView` is NEW PATTERN |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` (NEW, ~200 lines) | view (composer of cells) | transform (board → grid of cells); horizontal `ScrollView` on Hard | None — first `LazyVGrid` cell grid | NEW PATTERN |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift` (NEW, ~220 lines) | view (single tile + gestures + a11y) | event-driven (`LongPressGesture(0.25).exclusively(before: TapGesture())` → `onTap`/`onLongPress` closures) | None — first composed-gesture view | NEW PATTERN |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperToolbarMenu.swift` (NEW, ~90 lines) | view (props-only, three-button `Menu`) | request-response (`vm.requestDifficultyChange(_:)`) | `gamekit/gamekit/Screens/HomeView.swift` cardRow (Button + Image+Text composition) | role-match (Button-driven props view), but `.toolbar`/`Menu`/`Picker` is NEW PATTERN |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift` (NEW, ~180 lines) | view (overlay card, props-only) | request-response (`onRestart` / `onChangeDifficulty` closures) | `gamekit/gamekit/Screens/HomeView.swift` `cardRow(_:)` (DKCard + HStack composition) AND `gamekit/gamekit/Screens/SettingsView.swift` (DKCard wrapping) | role-match (DKCard composition idiom) |
| `gamekit/gamekit/Screens/HomeView.swift` (EDIT, ~10-line diff) | view (existing scaffold) | unchanged | self (existing) | self-edit (replace `minesweeperPlaceholder` body with `MinesweeperGameView()` per D-12) |
| `gamekit/gamekit/Resources/Localizable.xcstrings` (EDIT, +~30 keys) | resource (string catalog) | resource | self (existing P1 25-key seed) | self-edit (auto-extracted via `SWIFT_EMIT_LOC_STRINGS=YES`) |
| `../DesignKit/Sources/DesignKit/Theme/Tokens.swift` (EDIT, +1 field on `ThemeColors`) | model (token struct) | value-type | self (existing 16-field `ThemeColors`) | self-edit (additive — extend init + stored property) |
| `../DesignKit/Sources/DesignKit/Theme/Theme.swift` (EDIT, +1 extension method) | model (Theme convenience) | pure function (`(Int) -> Color`, clamp to 1...8) | self (existing `Theme.resolve(...)` static methods) | self-edit (add `func gameNumber(_:)` extension) |
| `../DesignKit/Sources/DesignKit/Theme/PresetTheme.swift` (EDIT, +`gameNumberPalette` per-preset) | model + per-preset declarations | value-type (per-preset `[Color]` of length 8) | self lines 137–222 (Forest/Navy/Maroon/Walnut/Stone hex literals + `Color(hex:)` per-preset declarations) | self-edit (additive — same hex-literal pattern, new field) |
| `../DesignKit/Tests/DesignKitTests/GameNumberPaletteWongTests.swift` (NEW, ~250 lines) | test (XCTest, color science) | request-response (deterministic — preset × Wong-transform → ΔE assertion) | `../DesignKit/Tests/DesignKitTests/DesignKitTests.swift` (XCTest scaffold; NOT Swift Testing — DesignKit target uses XCTest) | role-match (XCTest scaffold + `Color` component extraction) |

**Folder note:** `Games/Minesweeper/` already exists (P2). All P3 GameKit views are siblings of the existing P2 model + Engine files — synchronized root group (Xcode 16 `objectVersion = 77`) auto-registers per CLAUDE.md §8.8 (validated empirically across all of P2 per STATE.md). DesignKit edits all land inside existing files — no new folders.

**Critical correction vs. RESEARCH §Code Examples 3:** The research example shows Swift Testing (`import Testing`, `@Test`) for `GameNumberPaletteWongTests.swift`. **The existing DesignKitTests target uses XCTest, not Swift Testing** (verified at `/Users/gabrielnielsen/Desktop/DesignKit/Tests/DesignKitTests/DesignKitTests.swift:1` `import XCTest`). The new Wong test must follow the existing target convention — XCTest. Swift Testing is correct for `gamekit/gamekitTests/` (per Phase 2) but NOT for `DesignKit/Tests/DesignKitTests/`.

---

## Pattern Assignments

### Established pattern: file-header convention (applies to ALL 7 NEW GameKit files)

**Analog:** `gamekit/gamekit/App/GameKitApp.swift` lines 1–13; `gamekit/gamekit/Screens/HomeView.swift` lines 1–14; `gamekit/gamekit/Games/Minesweeper/MinesweeperBoard.swift` lines 1–22; `gamekit/gamekit/Games/Minesweeper/Engine/RevealEngine.swift` lines 1–19. P2's `02-PATTERNS.md` already locked this convention; P3 inherits.

**What to copy:** purpose blurb + phase-decision references in parentheses (e.g. "per D-05", "per D-19") + invariant callouts.

**Excerpt from `MinesweeperBoard.swift` (lines 1–22):**
```swift
//
//  MinesweeperBoard.swift
//  gamekit
//
//  The immutable Minesweeper board. Engines (BoardGenerator in Plan 03,
//  RevealEngine in Plan 04) produce NEW boards via the pure transforms
//  on this type — `replacingCell(at:with:)` and `replacingCells(_:)`.
//  This struct intentionally has zero `mutating func`s (D-10).
//
//  Phase 2 invariants (per D-10 + PATTERNS.md "immutable value-type Board"):
//    - All stored properties are `let` — no inout, no in-place mutation
//    ...
//
```

**Apply to each P3 view file:**
- 1-paragraph purpose blurb naming the responsibility (per UI-SPEC §Component Inventory).
- "Phase 3 invariants (per D-XX, D-YY)" block citing CONTEXT decisions.
- Anti-pattern call-outs where load-bearing — e.g. `MinesweeperViewModel.swift` header MUST mention "no `import SwiftUI`" (research §Anti-Patterns; ARCHITECTURE.md Anti-Pattern 1) and `MinesweeperCellView.swift` header MUST mention "no `Color(...)` literal" (RESEARCH Pitfall 7 + `.githooks/pre-commit` rule).

---

### Established pattern: themed view shell (applies to `MinesweeperGameView.swift`)

**Analog:** `gamekit/gamekit/Screens/HomeView.swift` lines 19–54.

**Imports + theme env wiring** (lines 16–26):
```swift
import SwiftUI
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingComingSoon: GameCard?
    @State private var navigateToMines: Bool = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }
```

**Apply to `MinesweeperGameView`:** same `@EnvironmentObject themeManager` + `@Environment(\.colorScheme)` + `private var theme` derivation. Hoist `theme` ONCE at the top-level scene; pass as `let theme: Theme` parameter into every child view (board, header, cell, end-state card, toolbar menu). Per RESEARCH Anti-Pattern "Re-fetching theme tokens inside cell views: All 480 cells re-evaluating `themeManager.theme(...)` on every redraw is wasteful."

**NavigationStack ownership:** `HomeView` already owns `NavigationStack` (line 29). `MinesweeperGameView` is pushed into it via `NavigationLink` (per D-12 + research ARCHITECTURE Anti-Pattern 3 — "no nested NavigationStack"). The current `HomeView.swift:42-44` `.navigationDestination(isPresented: $navigateToMines) { minesweeperPlaceholder }` becomes `.navigationDestination(isPresented: $navigateToMines) { MinesweeperGameView() }`. The `minesweeperPlaceholder` ViewBuilder (lines 105–123) is **deleted** as part of the same edit.

**Background pattern** (line 40):
```swift
.background(theme.colors.background.ignoresSafeArea())
.navigationTitle(String(localized: "GameKit"))
```

Apply identically to `MinesweeperGameView` with `String(localized: "Minesweeper")` title.

---

### Established pattern: DKCard wrapping (applies to `MinesweeperEndStateCard.swift`)

**Analog:** `gamekit/gamekit/Screens/HomeView.swift` lines 61–86 (DKCard with HStack content); `gamekit/gamekit/Screens/SettingsView.swift` lines 27–40 (DKCard wrapping prose).

**Excerpt from `HomeView.cardRow(_:)` (lines 61–86):**
```swift
DKCard(theme: theme) {
    HStack(spacing: theme.spacing.m) {
        Image(systemName: card.symbol)
            .font(.title2)
            .foregroundStyle(card.isEnabled
                ? theme.colors.accentPrimary
                : theme.colors.textTertiary)

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(card.title)
                .font(theme.typography.headline)
                .foregroundStyle(card.isEnabled
                    ? theme.colors.textPrimary
                    : theme.colors.textTertiary)
            ...
        }
        Spacer()
        Image(systemName: card.isEnabled ? "chevron.right" : "lock")
            .foregroundStyle(theme.colors.textTertiary)
    }
}
```

**What to copy:** `DKCard(theme: theme) { content }` is the exclusive container for surface-tinted UI in this app. **Do NOT redeclare** the radius/border/padding — `DKCard.swift` already supplies them (`/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Components/DKCard.swift:14-19` applies `theme.spacing.l` outer padding + `theme.radii.card` corner + `theme.colors.surface` fill + `theme.colors.border` 1pt stroke). Wrap a `VStack(spacing: theme.spacing.l)` child for the end-state card content per D-04.

**Critical:** UI-SPEC §Component Inventory: "Do not duplicate this styling locally."

**Reuse pattern for end-state card content** (composed from D-03):
```swift
DKCard(theme: theme) {
    VStack(spacing: theme.spacing.l) {
        Text(outcomeTitle)                                  // .titleLarge tinted success/danger
            .font(theme.typography.titleLarge)
            .foregroundStyle(outcome == .win ? theme.colors.success : theme.colors.danger)

        Text(elapsedString)                                 // monoNumber
            .font(theme.typography.title)
            .foregroundStyle(theme.colors.textPrimary)

        if outcome == .loss {                               // loss-only context line
            Text(String(localized: "\(minesHit) mines hit / \(safeCellsRemaining) safe cells left"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
        }

        VStack(spacing: theme.spacing.s) {                  // action stack
            DKButton(String(localized: "Restart"), style: .primary, theme: theme, action: onRestart)
            DKButton(String(localized: "Change difficulty"), style: .secondary, theme: theme, action: onChangeDifficulty)
        }
    }
}
```

---

### Established pattern: DKButton primary/secondary (applies to `MinesweeperEndStateCard.swift`)

**Analog:** `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/Components/DKButton.swift` lines 8–61.

**Construction excerpt** (lines 15–27):
```swift
public init(
    _ title: String,
    style: DKButtonStyle = .primary,
    theme: Theme,
    isEnabled: Bool = true,
    action: @escaping () -> Void
) {
```

**What to copy:** Use the `DKButton(_:style:theme:action:)` initializer. The button already supplies `minHeight: 44` (line 33), `theme.radii.button` corner (line 43), `theme.colors.accentPrimary` background on `.primary` (line 57), `theme.colors.highlight` background on `.secondary` (line 58), and `theme.typography.headline` text (line 32). **Do not redeclare** any of these locally per UI-SPEC §Component Inventory.

**Two button instances in P3** (per D-03, D-09, D-10):
1. End-state card "Restart" — `.primary` (D-03 part 4).
2. End-state card "Change difficulty" — `.secondary` (D-03 part 4).

**Toolbar Restart** is NOT a `DKButton` — it's a `ToolbarItem` with `Image(systemName: "arrow.counterclockwise")` (UI-SPEC §Layout & Sizing — Toolbar). The 44pt min target is supplied by `ToolbarItem` placement automatically.

**Alert "Abandon" button** is NOT a `DKButton` either — it's a SwiftUI `Button(role: .destructive)` inside `.alert(actions:)` (per D-10 + RESEARCH Pitfall 4); the system styles it.

---

### Established pattern: ThemeManager environment wiring (applies to `MinesweeperGameView.swift`)

**Analog:** `gamekit/gamekit/App/GameKitApp.swift` lines 19–27 (creator) + `gamekit/gamekit/Screens/RootTabView.swift` lines 14–37 (consumer).

**Creator excerpt** (`GameKitApp.swift` lines 19–27):
```swift
@main
struct GameKitApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(themeManager)
                .preferredColorScheme(preferredScheme)
        }
    }
```

**Consumer excerpt** (`RootTabView.swift` lines 14–37):
```swift
struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    ...
    private var theme: Theme { themeManager.theme(using: colorScheme) }
```

**Apply to:** `MinesweeperGameView`, `MinesweeperHeaderBar`, `MinesweeperBoardView`, `MinesweeperCellView`, `MinesweeperToolbarMenu`, `MinesweeperEndStateCard`. Only `MinesweeperGameView` reads from environment (`@EnvironmentObject`); the others receive `theme: Theme` as a `let` parameter (per RESEARCH Anti-Pattern "Re-fetching theme tokens inside cell views").

---

### Established pattern: localized strings via `String(localized:)` (applies to all view files + xcstrings catalog)

**Analog:** `gamekit/gamekit/Screens/HomeView.swift` lines 41, 76, 111, 114, 136–144 (catalog use across feature surface); `gamekit/gamekit/Screens/RootTabView.swift` lines 25, 29, 33; existing 25-key `Resources/Localizable.xcstrings` (verified via STATE.md).

**Excerpts:**
```swift
.navigationTitle(String(localized: "Minesweeper"))                       // HomeView:122
Text(String(localized: "Coming soon"))                                   // HomeView:76
Label(String(localized: "Home"), systemImage: "house")                   // RootTabView:25
GameCard(id: "minesweeper", title: String(localized: "Minesweeper"), ...)// HomeView:136
```

**Apply to all P3 user-visible strings.** UI-SPEC §Copywriting Contract enumerates ~20 keys (titles, button labels, alert copy, a11y templates). Auto-extraction is on (`SWIFT_EMIT_LOC_STRINGS=YES` per FOUND-04 — verified in STATE.md), so every `String(localized:)` call site lands in `Localizable.xcstrings` automatically.

**Two acceptable forms** (per RESEARCH §Pattern 7):
1. **`String(localized: "...")`** — explicit; use for navigation titles, button text, alert titles, body Text.
2. **`LocalizedStringKey` interpolation** — implicit; SwiftUI's `accessibilityLabel(_:)`, `Text(_:)` and `.alert(_:)` accept `LocalizedStringKey` directly. For accessibility labels per D-19, prefer the implicit form because the label is a single string interpolation:
   ```swift
   .accessibilityLabel("Revealed, \(cell.adjacentMineCount) mines adjacent, row \(row + 1) column \(col + 1)")
   ```

**Pre-commit gate:** before committing, open `Localizable.xcstrings` in Xcode, filter "Stale," delete any orphans (RESEARCH Pitfall 8).

---

### NEW PATTERN: `@Observable @MainActor` ViewModel (applies to `MinesweeperViewModel.swift`)

**No analog in repo.** Reference: `.planning/research/ARCHITECTURE.md` §pattern-2; CONTEXT D-05 / D-06 / D-07 / D-08 / D-11; RESEARCH §Pattern 2 ("ViewModel pause/resume math") + §Code Examples 1 ("VM `reveal(at:)` — first-tap timer start + engine orchestration").

**Imports:** `import Foundation` only — VM does NOT import SwiftUI (RESEARCH §Anti-Patterns; ARCHITECTURE Anti-Pattern 1). The `@Observable` macro lives in `Observation` module which is part of stdlib in Swift 5.9+; no explicit import needed.

**Type-declaration shape:**
```swift
import Foundation
// NO `import SwiftUI`. NO `import Combine`. NO `import SwiftData`.
// VM is animation-blind, persistence-blind. Engines are Foundation-only;
// VM is also Foundation-only (ARCHITECTURE Anti-Pattern 1).

@Observable @MainActor
final class MinesweeperViewModel {
    // Read-only state surface (every var is private(set))
    private(set) var board: MinesweeperBoard
    private(set) var gameState: MinesweeperGameState = .idle
    private(set) var difficulty: MinesweeperDifficulty
    private(set) var flaggedCount: Int = 0
    private(set) var timerAnchor: Date?               // nil = paused/idle/terminal (D-05)
    private(set) var pausedElapsed: TimeInterval = 0  // accumulator (D-06)
    private(set) var lossContext: (minesHit: Int, safeCellsRemaining: Int)?

    // Difficulty-switch confirmation flow state (Pitfall 4)
    var showingAbandonAlert: Bool = false
    private(set) var pendingDifficultyChange: MinesweeperDifficulty?

    // Production RNG — SeededGenerator stays in test target only (P2 D-12)
    private var rng = SystemRandomNumberGenerator()

    // Derived presentations (no caching — recomputed per access)
    var minesRemaining: Int { board.mineCount - flaggedCount }
    var frozenElapsed: TimeInterval { /* see below */ }
    var terminalOutcome: GameOutcome? { /* switch on gameState */ }

    init(difficulty: MinesweeperDifficulty? = nil) {
        let d = difficulty
            ?? MinesweeperDifficulty(rawValue: UserDefaults.standard.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy                                       // D-11 default
        ...
    }

    // Public API consumed by views
    func reveal(at index: MinesweeperIndex)            // D-07 first-tap-starts-timer
    func toggleFlag(at index: MinesweeperIndex)        // engine no-op on revealed/.mineHit
    func restart()                                     // D-12 same difficulty, fresh board
    func setDifficulty(_ d: MinesweeperDifficulty)     // writes UserDefaults
    func requestDifficultyChange(_ d: MinesweeperDifficulty)  // Pitfall 4 — alert path
    func confirmDifficultyChange()                     // alert "Abandon" handler
    func cancelDifficultyChange()                      // alert "Cancel" handler
    func pause()                                       // D-06 scenePhase .background
    func resume()                                      // D-06 scenePhase .active

    private static let lastDifficultyKey = "mines.lastDifficulty"
}

enum GameOutcome: Equatable, Sendable { case win, loss }
```

**Observation:** `@State private var viewModel: MinesweeperViewModel` in `MinesweeperGameView`. `@StateObject` is API-incompatible with `@Observable` (RESEARCH §Alternatives Considered + Pitfall 1). `init() { _viewModel = State(initialValue: MinesweeperViewModel()) }`.

**Engine consumption pattern** (per RESEARCH §Code Examples 1, lines 747–772):
```swift
func reveal(at index: MinesweeperIndex) {
    if case .idle = gameState {
        // First tap: generate + place mines + start timer (D-07)
        board = BoardGenerator.generate(difficulty: difficulty, firstTap: index, rng: &rng)
        gameState = .playing
        timerAnchor = .now
        pausedElapsed = 0
    }
    guard case .playing = gameState else { return }

    let result = RevealEngine.reveal(at: index, on: board)
    board = result.board

    if WinDetector.isLost(board) {
        if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
            gameState = .lost(mineIdx: mineIdx)
            lossContext = computeLossContext()
        }
        freezeTimer()                                 // D-08
    } else if WinDetector.isWon(board) {
        gameState = .won
        freezeTimer()                                 // D-08
    }
}
```

**Timer pause/resume math** (per CONTEXT D-06; RESEARCH §Pattern 2 lines 401–411):
```swift
func pause() {
    guard case .playing = gameState, let anchor = timerAnchor else { return }
    pausedElapsed += Date.now.timeIntervalSince(anchor)
    timerAnchor = nil
}

func resume() {
    guard case .playing = gameState, timerAnchor == nil else { return }
    timerAnchor = .now
}

private func freezeTimer() {                          // D-08 terminal-state freeze
    if let anchor = timerAnchor {
        pausedElapsed += Date.now.timeIntervalSince(anchor)
    }
    timerAnchor = nil
}
```

**UserDefaults persist** (per D-11):
```swift
func setDifficulty(_ d: MinesweeperDifficulty) {
    difficulty = d
    UserDefaults.standard.set(d.rawValue, forKey: Self.lastDifficultyKey)
    restart()                                         // fresh board at new difficulty
}
```

---

### NEW PATTERN: scenePhase wiring at top-level scene (applies to `MinesweeperGameView.swift`)

**No analog in repo.** Reference: CONTEXT D-06; RESEARCH §Code Examples 2 (lines 813–842); RESEARCH Pitfall 2 (`.inactive` vs `.background` confusion).

**Shape:**
```swift
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
        boardScene                                    // ZStack with header + board + end-state overlay
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Minesweeper"))
            .toolbar { /* Restart leading + Menu trailing — UI-SPEC §Layout */ }
            .alert(                                   // D-10 — Pitfall 4
                String(localized: "Abandon current game?"),
                isPresented: $viewModel.showingAbandonAlert
            ) {
                Button(String(localized: "Cancel"), role: .cancel) {
                    viewModel.cancelDifficultyChange()
                }
                Button(String(localized: "Abandon"), role: .destructive) {
                    viewModel.confirmDifficultyChange()
                }
            } message: {
                Text(String(localized: "Your in-progress game will be lost."))
            }
            .onChange(of: scenePhase) { _, newPhase in    // iOS 17 two-arg form
                switch newPhase {
                case .background:
                    viewModel.pause()                 // D-06
                case .active:
                    viewModel.resume()                // D-06
                case .inactive:
                    break                             // RESEARCH Pitfall 2 — NO-OP
                @unknown default:
                    break
                }
            }
    }
}
```

**Critical:** watch `.background` ONLY for the pause path. `.inactive` (control-center pull, lock-screen flash) is a no-op (Pitfall 2 + D-06 verbatim).

---

### NEW PATTERN: `TimelineView(.periodic)` timer chip (applies to `MinesweeperHeaderBar.swift`)

**No analog in repo.** Reference: CONTEXT D-05; RESEARCH §Pattern 2 (lines 330–411); UI-SPEC §Component Inventory (`MinesweeperHeaderBar` props-only contract).

**Shape (props-only — view does NOT touch ViewModel directly per CLAUDE.md §8.2):**
```swift
struct MinesweeperHeaderBar: View {
    let theme: Theme
    let minesRemaining: Int
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            counterChip(value: minesRemaining)        // theme.surface fill + theme.radii.chip
            Spacer()
            timerChip                                 // TimelineView, see below
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    @ViewBuilder
    private var timerChip: some View {
        // When anchor is nil (paused/idle/terminal), TimelineView still fires
        // once and the display math returns pausedElapsed — timer reads as
        // frozen. CORRECT for idle (00:00) and terminal (final time) states.
        TimelineView(.periodic(from: timerAnchor ?? .now, by: 1)) { context in
            Text(formatElapsed(displayedElapsed(at: context.date)))
                .font(theme.typography.monoNumber)    // monospace — no jitter
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityLabel(String(localized: "Time elapsed"))
                .accessibilityValue(formatElapsedSpoken(displayedElapsed(at: context.date)))
        }
    }

    private func displayedElapsed(at now: Date) -> TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + now.timeIntervalSince(anchor)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))                    // RESEARCH §Pattern 2 — system-clock-rollback safety
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
```

**Counter chip pattern** — model on `ComingSoonOverlay.swift` lines 17–35 (chip styling with token discipline):

**Excerpt from `ComingSoonOverlay.swift` (lines 17–35):**
```swift
HStack(spacing: theme.spacing.s) {
    Image(systemName: "sparkles")
        .foregroundStyle(theme.colors.accentPrimary)
    Text(title)
        .font(theme.typography.caption)
        .foregroundStyle(theme.colors.textPrimary)
}
.padding(.horizontal, theme.spacing.m)
.padding(.vertical, theme.spacing.s)
.background(theme.colors.surfaceElevated)
.clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
        .stroke(theme.colors.border, lineWidth: 1)
)
```

**Apply** to both counter chip ("`042`") and timer chip ("`02:14`"). Use `theme.colors.surface` (revealed-cell-tone) per UI-SPEC §Color "Secondary (30%)" for the chip background; the unrevealed-cell tone `surfaceElevated` is reserved for cell tiles to keep the visual hierarchy consistent.

**Forbidden alternatives (RESEARCH §Don't Hand-Roll):** `Timer.publish` / `Timer.scheduledTimer` / `Task { while ... await Task.sleep }` — D-05 explicitly forbids; PITFALLS Pitfall 10 documents background drift.

---

### NEW PATTERN: `LazyVGrid` + horizontal `ScrollView` board (applies to `MinesweeperBoardView.swift`)

**No analog in repo.** Reference: CONTEXT Discretion (a) "horizontal `ScrollView` on Hard"; UI-SPEC §Layout & Sizing (cell dimensions); RESEARCH §Pattern 5 (loss-state per-cell view switch).

**Shape:**
```swift
struct MinesweeperBoardView: View {
    let theme: Theme
    let board: MinesweeperBoard
    let gameState: MinesweeperGameState
    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    private var cellSize: CGFloat {                   // intrinsic component constant — UI-SPEC §Spacing exception
        switch board.difficulty {
        case .easy:   44                              // HIG min
        case .medium: 40
        case .hard:   36                              // documented carve-out
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: theme.spacing.xs),
              count: board.cols)
    }

    var body: some View {
        ScrollView(scrollAxisFor(board.difficulty)) { // .horizontal on Hard, [] on Easy/Medium
            LazyVGrid(columns: columns, spacing: theme.spacing.xs) {
                ForEach(board.allIndices(), id: \.self) { index in
                    MinesweeperCellView(
                        cell: board.cell(at: index),
                        index: index,
                        cellSize: cellSize,
                        theme: theme,
                        gameState: gameState,
                        onTap: onTap,
                        onLongPress: onLongPress
                    )
                }
            }
            .padding(.horizontal, theme.spacing.l)
        }
    }

    private func scrollAxisFor(_ d: MinesweeperDifficulty) -> Axis.Set {
        d == .hard ? .horizontal : []
    }
}
```

**Token discipline check:** every padding/spacing reads `theme.spacing.{xs,m,l}`. Cell tile `.frame(width: cellSize, height: cellSize)` is OK — the `.githooks/pre-commit` regex `\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)` does NOT match `.frame(width:height:)` (verified at line 25 of `.githooks/pre-commit`). Cell-size constants are intrinsic component dimensions per UI-SPEC §Spacing carve-out.

---

### NEW PATTERN: cell-level gesture composition + a11y (applies to `MinesweeperCellView.swift`)

**No analog in repo.** Reference: CONTEXT D-19 / D-20; UI-SPEC §Gesture Composition (load-bearing); RESEARCH §Pattern 1 (lines 274–323); RESEARCH §Pattern 5 (loss-state glyph switch); RESEARCH §Pattern 7 (LocalizedStringKey auto-extraction); RESEARCH Pitfall 5 (`.accessibilityElement(children: .ignore)`).

**Shape (composed from RESEARCH §Pattern 1 + §Pattern 5 + §Pattern 7):**
```swift
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
            .contentShape(Rectangle())                // full-tile hit area
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
            .accessibilityElement(children: .ignore)        // RESEARCH Pitfall 5
            .accessibilityLabel(accessibilityLabel)         // baked at view creation per D-19
            .accessibilityAddTraits(.isButton)
    }

    // Glyph rendering — switches on cell.state × cell.isMine × gameState
    // per D-17 (RESEARCH §Pattern 5 lines 469–504)
    @ViewBuilder
    private var glyph: some View {
        switch (cell.state, cell.isMine, gameState) {
        case (.mineHit, _, _):
            Image(systemName: "circle.fill")
                .foregroundStyle(theme.colors.textPrimary)
                .background(theme.colors.danger)            // D-17 step 1

        case (.hidden, true, .lost):
            Image(systemName: "circle.fill")                // D-17 step 2 — non-trip mines
                .foregroundStyle(theme.colors.textPrimary)

        case (.flagged, false, .lost):                      // D-17 step 3 — wrong flag
            ZStack {
                Image(systemName: "flag.fill").foregroundStyle(theme.colors.danger)
                Image(systemName: "xmark").foregroundStyle(theme.colors.danger)
            }

        case (.flagged, _, _):
            Image(systemName: "flag.fill").foregroundStyle(theme.colors.danger)

        case (.revealed, _, _) where cell.adjacentMineCount > 0:
            Text("\(cell.adjacentMineCount)")
                .font(.system(size: cellSize * 0.55, weight: .bold, design: .rounded)) // UI-SPEC carve-out
                .foregroundStyle(theme.gameNumber(cell.adjacentMineCount))              // NEW token

        case (.revealed, _, _):
            EmptyView()                                     // 0-adjacency blank

        default:
            EmptyView()
        }
    }

    // Accessibility label baked at view creation (D-19). LocalizedStringKey
    // auto-extracts to xcstrings — no manual String(localized:) needed
    // (RESEARCH §Pattern 7).
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

// Sibling view — surface vs surfaceElevated based on cell.state
private struct TileBackground: View {
    let cell: MinesweeperCell
    let theme: Theme
    let gameState: MinesweeperGameState
    var body: some View {
        Rectangle().fill(fill)
    }
    private var fill: Color {
        switch cell.state {
        case .revealed, .mineHit: return theme.colors.surface         // revealed = secondary surface
        case .hidden, .flagged:   return theme.colors.surfaceElevated // unrevealed = elevated (UI-SPEC §Color)
        }
    }
}
```

**Load-bearing constants:**
- **0.25s long-press threshold** — locked by ROADMAP SC1; do NOT change without re-running 50-tap manual test on iPhone SE.
- **`.exclusively(before:)`** — NOT `.simultaneously(with:)`. The latter fires both gestures (PITFALLS Pitfall 7 + RESEARCH §Pattern 1 Anti-Pattern).

**SF Symbol glyphs (UI-SPEC §Component Inventory):** `circle.fill` (mine), `flag.fill` (flag), `xmark` (wrong-flag X). All tinted via `.foregroundStyle()` reading semantic tokens — never `Color(...)` literal.

---

### NEW PATTERN: `.toolbar` `Menu` (applies to `MinesweeperToolbarMenu.swift`)

**No analog in repo.** Reference: CONTEXT D-09 / D-10 / D-11; RESEARCH Pitfall 4 (mid-game switch race condition).

**Shape (props-only — view writes through callback, no VM coupling):**
```swift
struct MinesweeperToolbarMenu: View {
    let theme: Theme
    let currentDifficulty: MinesweeperDifficulty
    let onSelect: (MinesweeperDifficulty) -> Void     // routes to vm.requestDifficultyChange(_:)

    var body: some View {
        Menu {
            ForEach(MinesweeperDifficulty.allCases, id: \.self) { d in
                Button(action: { onSelect(d) }) {
                    Label(displayName(for: d), systemImage: currentDifficulty == d ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Text(displayName(for: currentDifficulty))
                    .font(theme.typography.title)
                Image(systemName: "slider.horizontal.3")  // UI-SPEC §Component Inventory
            }
            .foregroundStyle(theme.colors.textPrimary)
        }
        .accessibilityLabel(String(localized: "Difficulty"))
        .accessibilityValue(displayName(for: currentDifficulty))
    }

    private func displayName(for d: MinesweeperDifficulty) -> String {
        switch d {
        case .easy:   return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard:   return String(localized: "Hard")
        }
    }
}
```

**Toolbar wiring (applies to `MinesweeperGameView.swift`):**
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button(action: { viewModel.restart() }) {
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(theme.colors.textPrimary)  // accent reserved — UI-SPEC §Color
        }
        .accessibilityLabel(String(localized: "Restart game"))
    }
    ToolbarItem(placement: .topBarTrailing) {
        MinesweeperToolbarMenu(
            theme: theme,
            currentDifficulty: viewModel.difficulty,
            onSelect: { viewModel.requestDifficultyChange($0) }
        )
    }
}
```

**Critical (Pitfall 4):** the Menu calls `viewModel.requestDifficultyChange(_:)` NOT `viewModel.setDifficulty(_:)` directly. The VM internally checks `gameState`: from `.idle`/`.won`/`.lost` it calls `setDifficulty(_:)` immediately; from `.playing` it stashes `pendingDifficultyChange` and flips `showingAbandonAlert = true`. The View sees the alert via `.alert(isPresented: $viewModel.showingAbandonAlert)` and the user explicitly Cancel/Abandon. This avoids the "board flickers between difficulties on cancel" race.

**Display name source (D-03 in P2):** Engine layer `MinesweeperDifficulty` exposes only mechanical properties. The view tier owns `String(localized:)` mapping per P2 D-03 — keep `displayName(for:)` local to this view file (or shared in a tiny `MinesweeperDifficulty+Display.swift` extension if reused in `MinesweeperEndStateCard.swift` — discretion, recommend in-file until duplicated).

---

### Established pattern: Wong-audit XCTest (applies to `GameNumberPaletteWongTests.swift`)

**Analog:** `/Users/gabrielnielsen/Desktop/DesignKit/Tests/DesignKitTests/DesignKitTests.swift` (entire file, 448 lines).

**Imports excerpt** (lines 1–11):
```swift
import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import DesignKit

@MainActor
final class DesignKitTests: XCTestCase {
```

**Color-component extraction helper** (lines 411–432) — REUSE this exact helper for ΔE2000 input:
```swift
private func colorComponents(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
#if canImport(UIKit)
    let platformColor = UIColor(color)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    return (red, green, blue, alpha)
#elseif canImport(AppKit)
    let platformColor = NSColor(color)
    guard let rgbColor = platformColor.usingColorSpace(.sRGB) else { return nil }
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
#else
    return nil
#endif
}
```

**Cross-preset iteration** (lines 156–170):
```swift
func testThemeResolverMatchesPaletteWithoutOverrides() {
    for preset in ThemePreset.allCases {
        for scheme in [ColorScheme.light, .dark] {
            let resolved = Theme.resolve(preset: preset, scheme: scheme)
            ...
        }
    }
}
```

**Apply to Wong test** (per CONTEXT D-15; RESEARCH §Pattern 6 + §Code Examples 3 — but **swap Swift Testing for XCTest**):
```swift
import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import DesignKit

@MainActor
final class GameNumberPaletteWongTests: XCTestCase {

    /// Per D-15: every preset's gameNumberPalette must pass Wong simulation
    /// for protanopia/deuteranopia/tritanopia EXCEPT loud-preset opt-out
    /// via `gameNumberPaletteWongSafe: [Color]?` override.
    /// Classic preset MUST pass unconditionally — first-run default.
    func testForestGameNumberPaletteIsWongSafe() {
        let theme = Theme.resolve(preset: .forest, scheme: .light)  // resolver path — Pitfall 6
        let palette = theme.colors.gameNumberPalette                // length 8
        XCTAssertEqual(palette.count, 8)
        for i in 0..<7 {
            let dE = ciedE2000(palette[i], palette[i+1])
            XCTAssertGreaterThanOrEqual(dE, 10.0, "Forest palette adjacent pair \(i+1)/\(i+2) ΔE \(dE) below threshold")
        }
        // ... protanopia / deuteranopia / tritanopia simulations ...
    }
    // ... per-preset tests ...
}
```

**Critical (RESEARCH Pitfall 6):** the test calls `Theme.resolve(preset:scheme:)` (the production resolver) and reads `theme.colors.gameNumberPalette` — NOT the per-preset declaration field directly. This way the resolver-applied Wong-safe override IS the thing under test.

**Color-science scope (RESEARCH §Pattern 6):**
- ~30 lines of Brettel/Machado matrix simulation in `simd_float3x3` (or equivalent) over linear-RGB.
- ~50 lines of CIE ΔE2000 (sRGB → XYZ → Lab → ΔE).
- Reference: openaccess.thecvf.com — Machado et al. 2009.
- No third-party dep — pure Swift in DesignKitTests target.

---

## Shared Patterns

### File-size cap (CLAUDE.md §8.1, §8.5)

**Source:** CLAUDE.md ≤500-line hard cap; ≤400-line soft cap for views.

**Apply to:** all 7 NEW GameKit files. UI-SPEC §Component Inventory locks per-file expected sizes:

| File | Hard cap | Trigger to split |
|------|----------|------------------|
| `MinesweeperGameView.swift` | <300 | If toolbar + alert + scenePhase + body crosses 300, split toolbar into `MinesweeperGameView+Toolbar.swift` extension |
| `MinesweeperHeaderBar.swift` | <150 | n/a — small props-only view |
| `MinesweeperBoardView.swift` | <250 | If layout-strategy logic grows, split `MinesweeperBoardLayout.swift` |
| `MinesweeperCellView.swift` | <250 | If glyph switch crosses 100 lines, split `MinesweeperCellGlyph.swift` |
| `MinesweeperToolbarMenu.swift` | <100 | n/a — small props-only view |
| `MinesweeperEndStateCard.swift` | <200 | n/a — single composed card |
| `MinesweeperViewModel.swift` | <500 (CLAUDE.md §8.5 hard) | If timer logic grows, extract `MinesweeperTimerController.swift` (per UI-SPEC §Component Inventory) |

---

### Token discipline (CLAUDE.md §1, §8.4; FOUND-07 hook)

**Source:** `gamekit/.githooks/pre-commit` lines 14–35; CLAUDE.md §1 + §8.4.

**Excerpt from `.githooks/pre-commit` (lines 14–35):**
```bash
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^gamekit/gamekit/(Games|Screens)/.*\.swift$' || true)
if [ -n "$staged" ]; then
  bad=""
  for f in $staged; do
    if git diff --cached "$f" | grep -E '^\+' | grep -E 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' > /dev/null; then
      bad="${bad}${f}: hardcoded Color literal\n"
    fi
    if git diff --cached "$f" | grep -E '^\+' | grep -E 'cornerRadius:\s*[0-9]+' > /dev/null; then
      bad="${bad}${f}: numeric cornerRadius literal (use theme.radii.{card,button,chip,sheet})\n"
    fi
    if git diff --cached "$f" | grep -E '^\+' | grep -E '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)' > /dev/null; then
      bad="${bad}${f}: numeric padding literal (use theme.spacing.{xs,s,m,l,xl,xxl})\n"
    fi
  done
  if [ -n "$bad" ]; then
    echo -e "ERROR: token-discipline violations under Games/ or Screens/:\n${bad}"
    exit 1
  fi
fi
```

**Apply to:** all 7 NEW GameKit files + the EDIT to `HomeView.swift`.

**Rules:**
- **No `Color(red:...)` / `Color(hex:...)` / `Color.gray|red|blue|...` in `Games/Minesweeper/`.** Tints come from `theme.colors.*` (semantic tokens) and the new `theme.gameNumber(_:)` (D-13).
- **No `cornerRadius: <int>`.** Use `theme.radii.{card, button, chip, sheet}` (verified — `RadiusTokens.swift` defines exactly those four).
- **No `.padding(<int>)`.** Use `theme.spacing.{xs, s, m, l, xl, xxl}` (verified — `SpacingTokens.swift` defines exactly those six).
- **Cell-tile dimensions are exempt** — `.frame(width: cellSize, height: cellSize)` is a different regex (RESEARCH Pitfall 7 + UI-SPEC §Spacing carve-out documented). Constants live as `private let cellSize: CGFloat` at function/method scope.

**DesignKit edits NOT subject to hook** (verified — hook scopes to `gamekit/gamekit/(Games|Screens)/.*\.swift$` at line 14 of `.githooks/pre-commit`). New `gameNumberPalette` `Color(hex: "...")` in `PresetTheme.swift` is fine — same pattern as existing `legacyLightBG = Color(hex: "#F8FAFC")` (line 137) and the `customChartColors` arrays (lines 151, 156, 167, 172, etc.).

**Available tokens** (verified — never invent new ones per CLAUDE.md §8.4):
- **Spacing:** `xs (4) | s (8) | m (12) | l (16) | xl (24) | xxl (32)` — from `SpacingTokens.swift:12-17`.
- **Radii:** `card (16) | button (14) | chip (12) | sheet (22)` — from `RadiusTokens.swift:10-13`.
- **Motion:** `fast (0.18) | normal (0.28) | slow (0.40)` + `ease: Animation` — from `MotionTokens.swift:9-18`.
- **Typography:** `titleLarge | title | headline | body | caption | monoNumber` — from `TypographyTokens.swift:12-17`.
- **Colors:** 16 fields including `success`, `danger`, `accentPrimary`, `surface`, `surfaceElevated`, `border`, `textPrimary`, `textSecondary`, `textTertiary`, `highlight`, `fillDisabled`, etc. — from `Tokens.swift:3-19`.

---

### Foundation-only ViewModel (ARCHITECTURE Anti-Pattern 1)

**Source:** ARCHITECTURE.md §pattern-2 + Anti-Pattern 1; RESEARCH §Anti-Patterns; PITFALLS.md "Anti-Pattern 1: ViewModel imports SwiftUI".

**Apply to:** `MinesweeperViewModel.swift` only.

**Rule:** ViewModel imports `Foundation` only (Observation comes from stdlib in Swift 5.9+; no explicit import needed). Any `import SwiftUI` / `import Combine` / `import SwiftData` in `MinesweeperViewModel.swift` is a bug. Animation is the View's job — VM exposes `gameState`, view derives presentation per ARCHITECTURE §pattern-3.

**Enforcement (planner suggestion):** Add `MinesweeperViewModel.swift` to the engine-purity grep already proposed in `02-PATTERNS.md` "Foundation-only purity" — extend it to fail if anyone slips `import SwiftUI` into a VM.

---

### `LocalizedStringKey` for accessibility (research §Pattern 7)

**Source:** RESEARCH §Pattern 7; UI-SPEC §Copywriting Contract a11y rows; D-19 / D-20.

**Apply to:** `MinesweeperCellView.swift`, `MinesweeperHeaderBar.swift`, `MinesweeperToolbarMenu.swift`, `MinesweeperEndStateCard.swift`, `MinesweeperGameView.swift` (toolbar Restart button).

**Rule:** `accessibilityLabel(_:)` accepts `LocalizedStringKey` directly — string interpolations passed to it auto-extract to `Localizable.xcstrings` via `SWIFT_EMIT_LOC_STRINGS=YES` (already on per FOUND-04, verified in STATE.md). No manual `String(localized:)` call needed for accessibility labels:
```swift
.accessibilityLabel("Revealed, \(cell.adjacentMineCount) mines adjacent, row \(row + 1) column \(col + 1)")
```

**Conversely:** for `String`-typed surfaces (alert titles via `.alert(_:)`, navigation titles, button text inside `DKButton(_:)`), use the explicit `String(localized: "...")` form because those APIs accept `String` not `LocalizedStringKey`. UI-SPEC §Copywriting locks the per-call-site convention.

---

### `@State`-owned `@Observable` VM with iOS 17.0/17.1 leak acknowledgement (RESEARCH Pitfall 1)

**Source:** RESEARCH §Alternatives Considered + RESEARCH Pitfall 1.

**Apply to:** `MinesweeperGameView.swift`.

**Rule:**
```swift
@State private var viewModel: MinesweeperViewModel

init() {
    _viewModel = State(initialValue: MinesweeperViewModel())
}
```

**Why not `@StateObject`:** `@StateObject` requires `ObservableObject` conformance; `@Observable` macro generates a different observation surface. API-incompatible.

**iOS 17.0/17.1 leak (Apple-confirmed):** `@State` reference-type leak per developer.apple.com/forums/thread/736239. Fixed in iOS 17.2+. Acceptable for v1 — leak is one VM (~few KB) per game-screen dismiss; not worth a `@StateObject` shim that fights the macro. Plan task ending should add a one-liner Instruments check on Allocations to confirm VM deinits on `MinesweeperGameView` dismissal.

---

### Localization completeness gate (extends FOUND-05)

**Source:** RESEARCH Pitfall 8; UI-SPEC §Copywriting "Localization completeness gate".

**Apply to:** `Resources/Localizable.xcstrings` after every commit that touches a P3 view file.

**Rule:** Open `Localizable.xcstrings` in Xcode catalog editor → filter "Stale" → delete. xcstrings auto-extracts NEW keys from `String(localized:)` and `LocalizedStringKey` interpolations but does NOT auto-delete renamed/removed keys. Pre-merge gate: zero stale entries.

**Existing seed:** 25 P1 keys (verified via STATE.md). P3 adds ~30 keys (per UI-SPEC §Copywriting enumeration). Final count ~55 keys, EN-only.

---

## No Analog Found

Five files are **NEW PATTERNS** — P3 is the first SwiftUI game-screen phase. The closest reference for each is a planning doc, not a sibling source file:

| File | Reference |
|------|-----------|
| `MinesweeperViewModel.swift` | `.planning/research/ARCHITECTURE.md` §pattern-2; CONTEXT D-05/D-06/D-07/D-08/D-11; RESEARCH §Code Examples 1 (lines 711–807) |
| `MinesweeperGameView.swift` | RESEARCH §Code Examples 2 (lines 813–842); RESEARCH §Pattern 3 (end-state ZStack overlay); UI-SPEC §Layout & Sizing (toolbar) |
| `MinesweeperHeaderBar.swift` | RESEARCH §Pattern 2 (lines 330–411); CONTEXT D-05; UI-SPEC §Typography (`monoNumber`) |
| `MinesweeperBoardView.swift` | UI-SPEC §Layout & Sizing (cell sizes per difficulty); CONTEXT Discretion (a) horizontal `ScrollView` on Hard |
| `MinesweeperCellView.swift` | RESEARCH §Pattern 1 + §Pattern 5 + §Pattern 7; CONTEXT D-17 / D-19 |
| `MinesweeperToolbarMenu.swift` | CONTEXT D-09 / D-10 / D-11; RESEARCH Pitfall 4 |

**Planner instruction:** When writing PLAN.md actions, treat these references as the canonical specifications — quote the RESEARCH §Pattern 1 gesture composition (lines 285–303) verbatim into the cell-view plan; quote the RESEARCH §Pattern 2 timer math (lines 366–387) verbatim into the header-bar plan; quote the RESEARCH §Code Examples 1 reveal flow (lines 747–772) verbatim into the VM plan. There is no in-repo file to copy from for these surfaces.

---

## Metadata

**Analog search scope:** `gamekit/gamekit/` (App, Screens, Resources, Games/Minesweeper); `/Users/gabrielnielsen/Desktop/DesignKit/Sources/DesignKit/`; `/Users/gabrielnielsen/Desktop/DesignKit/Tests/DesignKitTests/`; `gamekit/gamekitTests/` (engine tests + helpers); `gamekit/.githooks/`.
**Files scanned:** 22 (`.swift` + xcstrings + githook).
**Files producing usable patterns:** 11 — file-header convention from P1 + P2 files; themed-shell view shape from `HomeView.swift` + `SettingsView.swift` + `StatsView.swift`; chip styling from `ComingSoonOverlay.swift`; DKCard/DKButton consumption from `HomeView.cardRow(_:)`; ThemeManager env wiring from `GameKitApp.swift` + `RootTabView.swift`; pre-commit token discipline from `.githooks/pre-commit`; XCTest helper functions from `DesignKitTests.swift`; `Color(hex:)` per-preset declaration pattern from `PresetTheme.swift`.
**Files producing no usable pattern:** 4 — `Engine/*.swift` files use Foundation-only and import nothing UI-related (correct per P2 architecture; UI-tier patterns must be NEW); `gamekitUITests/*.swift` (XCUITest, wrong layer for P3); test files in `gamekitTests/Engine/` use Swift Testing which is correct for that target but the new DesignKit Wong test must use XCTest per its target convention.
**Critical correction noted:** RESEARCH §Code Examples 3 shows Swift Testing for the Wong test; the DesignKitTests target is XCTest (verified `DesignKitTests.swift:1`). Plan must use XCTest for that file.
**Pattern extraction date:** 2026-04-25.
