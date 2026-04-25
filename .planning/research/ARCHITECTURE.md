# Architecture Research

**Domain:** Multi-game iOS suite (SwiftUI + SwiftData + DesignKit), one-game-at-a-time MVP
**Researched:** 2026-04-24
**Confidence:** HIGH (validated against PROJECT.md, CLAUDE.md, AGENTS.md, DesignKit README, and SwiftData/CloudKit official + community sources)

---

## TL;DR (For Roadmap)

Ship Minesweeper as a **vertical slice through five clean layers** (App shell → Screens → Games/Minesweeper → Core → DesignKit dep). Folder layout in PROJECT.md is correct — keep it. **Game-agnostic stats keyed by `gameKind`** (one `@Model GameRecord`, one `@Model BestTime`) — not per-game models. **Single shared SwiftData container**, configured for CloudKit from day 1, but with a feature-flag that allows running it in `cloudKitDatabase: .none` until `PERSIST-04` is implemented. **No `GameProtocol`** until game 3. Build order: Foundation → Mines engines → Mines UI → Stats/Persistence → Theme polish → CloudKit → Release.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                       App/  (GameKitApp.swift)                       │
│   @main · ThemeManager · ModelContainer · root WindowGroup           │
│   Injects: .environmentObject(themeManager)                          │
│            .modelContainer(sharedContainer)                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ NavigationStack(path:)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Screens/  (cross-game shells)                       │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌─────────────────┐    │
│  │ HomeView │  │SettingsView│  │ StatsView│  │ IntroFlowView   │    │
│  └────┬─────┘  └─────┬──────┘  └────┬─────┘  └────────┬────────┘    │
│       │              │              │                  │             │
│       │ tap Mines    │ theme/HX/SFX │ read GameRecord  │ first run   │
│       ▼              ▼              ▼                  ▼             │
└───────┼──────────────┼──────────────┼──────────────────┼─────────────┘
        │              │              │                  │
┌───────┼──────────────┼──────────────┼──────────────────┼─────────────┐
│       │              │              │                  │             │
│       ▼   Games/Minesweeper/                           │             │
│  ┌──────────────────────────────────────────┐          │             │
│  │  MinesweeperView (SwiftUI)               │          │             │
│  │     ↕  reads viewModel.state              │          │             │
│  │  MinesweeperViewModel  (@Observable)     │          │             │
│  │     ↕  calls pure engines                │          │             │
│  │  ┌──────────────┐  ┌──────────────────┐  │          │             │
│  │  │BoardGenerator│  │ RevealEngine     │  │ pure /   │             │
│  │  │  (struct)    │  │ FloodFill        │  │ no       │             │
│  │  │              │  │ WinDetector      │  │ SwiftUI  │             │
│  │  └──────────────┘  └──────────────────┘  │          │             │
│  │  Models: Board · Cell · Difficulty · State│         │             │
│  └────────────┬─────────────────────────────┘          │             │
│               │ on win/loss → GameStats.record(...)    │             │
│               ▼                                         │             │
└───────────────┼─────────────────────────────────────────┼─────────────┘
                │                                         │
┌───────────────┼─────────────────────────────────────────┼─────────────┐
│               ▼   Core/  (cross-game services)         ▼             │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────────┐  │
│  │ GameStats    │  │SettingsStore │  │ ThemeStore                 │  │
│  │ (writes      │  │(haptics/SFX/ │  │ (DesignKit ThemeStorage    │  │
│  │  GameRecord) │  │ flags →      │  │  bridge — UserDefaults)    │  │
│  │              │  │ UserDefaults)│  │                            │  │
│  └──────┬───────┘  └──────────────┘  └────────────────────────────┘  │
│         │                                                            │
│         │  modelContext.insert(GameRecord(gameKind: .minesweeper…))  │
│         ▼                                                            │
└─────────┼────────────────────────────────────────────────────────────┘
          │
┌─────────┼────────────────────────────────────────────────────────────┐
│         ▼   Persistence Layer                                        │
│  ┌──────────────────────────────────────────────────────────┐        │
│  │  SwiftData ModelContainer (shared, single)               │        │
│  │  Schema: [GameRecord, BestTime]                          │        │
│  │  Configuration: ModelConfiguration(                      │        │
│  │    cloudKitDatabase: enabled ? .private(ckContainer)     │        │
│  │                              : .none                     │        │
│  │  )                                                       │        │
│  └──────────────────────────────────────────────────────────┘        │
│                                  ↕ (CloudKit mirroring, when on)    │
│                          ┌─────────────────┐                         │
│                          │ iCloud Private  │                         │
│                          │ Database        │                         │
│                          └─────────────────┘                         │
└──────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────┐
                    │  ../DesignKit  (SPM)    │
                    │  Tokens · ThemeManager  │
                    │  DKCard · DKButton ·    │
                    │  DKThemePicker · ...    │
                    └─────────────────────────┘
                    Consumed everywhere — never duplicated
```

---

## Component Responsibilities

| Component | Lives in | Responsibility (one paragraph) | Implementation |
|-----------|----------|---------------------------------|----------------|
| **GameKitApp** | `App/` | The single `@main` scene. Owns the `ThemeManager` (`@StateObject`), constructs the shared `ModelContainer`, applies `preferredColorScheme` from theme mode, and injects both into the environment. Decides whether the model container is configured with `.private(ckContainer)` or `.none` based on `SettingsStore.cloudSyncEnabled`. Knows nothing about games. | `App` struct, ~80 lines |
| **HomeView** | `Screens/` | The grid of game cards. Minesweeper is the only enabled card; future games are visually present but disabled. Pushes onto a `NavigationStack` when tapped. Owns no game state. Owns no `@Query` for stats — it shows summary chrome only. | SwiftUI view, navigation source of truth |
| **SettingsView** | `Screens/` | Theme picker (5 inline + "More themes & custom colors" link to `DKThemePicker`), haptics toggle, SFX toggle, reset stats, sign-in card, about. All toggles read/write `SettingsStore`. Theme writes flow through `ThemeManager`. | SwiftUI form |
| **StatsView** | `Screens/` | Per-game/per-difficulty stats table — reads via `@Query` filtered on `gameKind`. For MVP this is Minesweeper-only; the `gameKind` filter is the structural seam that lets game 2's stats slot in without touching this view (split into a per-game tab when the second game lands, not before). | SwiftUI view |
| **IntroFlowView** | `Screens/` | 3-step first-launch intro (themes → stats → optional sign-in). Dismissable, written `hasSeenIntro` to UserDefaults. | SwiftUI sheet/full-screen cover |
| **MinesweeperView** | `Games/Minesweeper/` | Renders the board grid, mine counter, timer, restart, end-state overlay. Pure view — reads `viewModel.state`, reacts to `viewModel.phase`. Owns animation state derived from the phase enum. No model fetching, no engine calls. | SwiftUI view, ≤400 lines |
| **MinesweeperViewModel** | `Games/Minesweeper/` | The orchestration brain. `@Observable`. Holds `board`, `state`, `elapsed`, `phase` (enum: `.idle / .revealing(cells) / .won / .lost(mineRow,col)`). Calls pure engines, runs the timer, on terminal state writes a `GameRecord` via `GameStats`. Never imports SwiftData fetch APIs — it gets `GameStats` injected. | `@Observable final class`, ≤500 lines |
| **BoardGenerator** | `Games/Minesweeper/Engine/` | Pure struct. Given `(rows, cols, mineCount, firstTap, rng)` returns a populated `MinesweeperBoard` with mines placed (excluding first-tap cell + 8 neighbors) and adjacency precomputed. Deterministic for a given seed. | `struct`, no imports beyond Foundation |
| **RevealEngine** | `Games/Minesweeper/Engine/` | Pure functions. `reveal(at:on:)` returns a new board + a list of revealed cells (for animation). `floodFill(from:on:)` returns the cascade. No mutation of caller state — always return new board. | `enum` namespace of `static func`s |
| **WinDetector** | `Games/Minesweeper/Engine/` | Pure. `isWon(board)` → all non-mine cells revealed. `isLost(board)` → any revealed mine. Two functions, one file. | `enum` namespace |
| **GameStats** | `Core/` | The single write-side wrapper around `GameRecord` + `BestTime`. Exposes `record(gameKind:difficulty:outcome:durationSeconds:)`. Hides `modelContext.insert` from view models so engine code never sees SwiftData. Read-side is `@Query` in views. | `final class`, takes `ModelContext` |
| **SettingsStore** | `Core/` | `@Observable` wrapper over UserDefaults for tiny key-value flags (haptics, SFX, cloudSyncEnabled, hasSeenIntro). Not SwiftData — UserDefaults is correct for this shape per CLAUDE.md §1. | `@Observable final class` |
| **ThemeStore** | `Core/` | Thin bridge that persists DesignKit `ThemeManager`'s mode/preset/overrides via DesignKit's own `ThemeStorage`. Often this is just `ThemeManager()` with default storage — only exists if extra ecosystem-specific persistence is needed. | Optional thin wrapper |
| **DesignKit** | `../DesignKit` (SPM) | Tokens, `ThemeManager`, generic components. Consumed read-only — extend at the source if a token is missing, never work around. | External package |

---

## Validating the Folder Layout

The layout in PROJECT.md / CLAUDE.md / README.md is **correct as written**. Keep it.

```
GameKit/
├── App/
│   └── GameKitApp.swift
├── Core/
│   ├── GameStats.swift            ← write-side: insert GameRecord
│   ├── GameRecord.swift           ← @Model · gameKind discriminator
│   ├── BestTime.swift             ← @Model · gameKind discriminator
│   ├── GameKind.swift             ← enum, single source of truth for game IDs
│   ├── SettingsStore.swift        ← @Observable over UserDefaults
│   └── ThemeStore.swift           ← optional thin wrapper over DesignKit
├── Games/
│   └── Minesweeper/
│       ├── MinesweeperView.swift
│       ├── MinesweeperViewModel.swift
│       ├── MinesweeperBoard.swift          ← model
│       ├── MinesweeperCell.swift           ← model
│       ├── MinesweeperDifficulty.swift     ← enum
│       ├── MinesweeperGameState.swift      ← enum: .ready/.playing/.won/.lost
│       ├── MinesweeperPhase.swift          ← enum: animation orchestration
│       └── Engine/
│           ├── BoardGenerator.swift
│           ├── RevealEngine.swift
│           └── WinDetector.swift
├── Screens/
│   ├── HomeView.swift
│   ├── SettingsView.swift
│   ├── StatsView.swift
│   ├── IntroFlowView.swift
│   └── ThemeExplorerView.swift   ← hosts full DKThemePicker
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

**One small refinement:** put Mines engines in `Games/Minesweeper/Engine/` (subfolder), not flat. Keeps the engine-vs-UI line visible at folder level — a future Mines reader instantly sees "everything in Engine/ is pure, no SwiftUI."

**Why this layout works for game 2:**
- New game = new folder under `Games/`. Zero touches to `App/`, `Core/`, or `Screens/` to add the *files*.
- HomeView gets one new card entry (data-driven from a small static array, not a protocol).
- StatsView gets a `gameKind` segmented control and a per-game tab — the schema already supports it.
- That's the entire delta. No protocol gymnastics.

---

## Recommended Patterns

### Pattern 1: Pure Engine + Observable ViewModel + Dumb View

**What:** Three-tier separation. Engines are deterministic structs/enums. ViewModel is `@Observable` and orchestrates. View is "render `viewModel.state`, send taps to `viewModel`."

**When to use:** Every game in the suite. This is the architectural constitution.

**Trade-offs:** Adds one indirection (View → VM → Engine) compared to "just put it in the View." The payoff is unit-testable game logic with zero SwiftUI in the test target — and unblocks all of `MINES-03/04/07` validation without UI tests.

**Example:**

```swift
// Engine: pure, no imports beyond Foundation
struct BoardGenerator {
    static func generate(
        rows: Int, columns: Int, mineCount: Int,
        excluding firstTap: Coordinate,
        rng: inout some RandomNumberGenerator
    ) -> MinesweeperBoard { ... }
}

// ViewModel: @Observable, owns state
@Observable
final class MinesweeperViewModel {
    private(set) var board: MinesweeperBoard
    private(set) var state: MinesweeperGameState = .ready
    private(set) var phase: MinesweeperPhase = .idle
    private(set) var elapsed: TimeInterval = 0

    private let stats: GameStats
    private var rng: SystemRandomNumberGenerator

    func tap(_ coord: Coordinate) {
        if state == .ready {
            board = BoardGenerator.generate(
                rows: board.rows, columns: board.columns,
                mineCount: board.mineCount,
                excluding: coord, rng: &rng
            )
            state = .playing
            startTimer()
        }
        let result = RevealEngine.reveal(at: coord, on: board)
        board = result.board
        phase = .revealing(result.cells)
        if WinDetector.isLost(board) {
            state = .lost
            stats.record(gameKind: .minesweeper,
                         difficulty: board.difficulty.rawValue,
                         outcome: .loss,
                         durationSeconds: elapsed)
        } else if WinDetector.isWon(board) { ... }
    }
}

// View: pure render
struct MinesweeperView: View {
    @State private var viewModel: MinesweeperViewModel
    var body: some View {
        BoardGrid(board: viewModel.board, onTap: viewModel.tap)
            .overlay(endStateOverlay)
            .onChange(of: viewModel.phase) { _, new in
                animate(for: new)
            }
    }
}
```

### Pattern 2: Game-agnostic SwiftData Schema with `gameKind` Discriminator

**What:** One `@Model` per *stat type* (record, best time), with a `gameKind: String` field that discriminates which game the row belongs to. Not one model per game.

**When to use:** Every persisted shape that's conceptually shared across games (game records, best times, possibly daily-puzzle history later).

**Trade-offs:**
- ✅ Adding a game = no migration. Just start writing `gameKind: "merge"` rows.
- ✅ CloudKit-friendly: one schema, one container, one mirroring stream — adding game 2 doesn't change the schema CloudKit sees.
- ✅ Cross-game stats trivially queryable (total games played across the suite, etc.).
- ⚠️ Per-game extension fields require either JSON-blob "metadata" columns or per-model subclass / additional model. For Mines MVP this is moot — the columns below are universal. Cross when game 2 needs unique fields (and the answer is usually: add a sibling `MinesweeperRunDetail` model linked by `gameRecordID`, not a column).
- ❌ You cannot use `@Attribute(.unique)` on synced models — already true regardless of design choice.

**Example:**

```swift
// Core/GameKind.swift
enum GameKind: String, Codable, CaseIterable {
    case minesweeper
    // future: merge, sudoku, wordGrid, solitaire, nonogram, flow, patternMemory, chess
}

// Core/GameRecord.swift
@Model
final class GameRecord {
    // SwiftData + CloudKit: ALL properties optional or defaulted, NO .unique
    var id: UUID = UUID()
    var gameKindRaw: String = GameKind.minesweeper.rawValue
    var difficulty: String = ""           // "easy" | "medium" | "hard" — game-defined
    var outcomeRaw: String = ""           // "win" | "loss" | "abandoned"
    var durationSeconds: Double = 0
    var playedAt: Date = .now
    var schemaVersion: Int = 1

    var gameKind: GameKind { GameKind(rawValue: gameKindRaw) ?? .minesweeper }
    var outcome: Outcome { Outcome(rawValue: outcomeRaw) ?? .abandoned }

    init(gameKind: GameKind, difficulty: String,
         outcome: Outcome, durationSeconds: Double) {
        self.gameKindRaw = gameKind.rawValue
        self.difficulty = difficulty
        self.outcomeRaw = outcome.rawValue
        self.durationSeconds = durationSeconds
    }
}

// StatsView reads:
@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" },
       sort: \.playedAt, order: .reverse)
private var minesRecords: [GameRecord]
```

### Pattern 3: Phase Enum for Animation Orchestration

**What:** ViewModel exposes a `phase: MinesweeperPhase` enum (`.idle`, `.revealing(cells)`, `.flagToggling(coord)`, `.winSweep`, `.lossShake(mineCoord)`). The View observes phase changes and triggers animations with `.onChange(of:)`. View-local `@State` is only for transient render-only flags (e.g. shake offset).

**When to use:** Any game with multi-step orchestrated animations. (`MINES-08`: reveal cascade, flag spring, win-board sweep, loss-shake.)

**Trade-offs:**
- ✅ Animation timing is testable — assert phase transitions in unit tests without rendering.
- ✅ Reduce-motion is a single switch in the View's `animate(for:)` (`A11Y-03`).
- ✅ Reorderable: change cascade → win sweep timing in one place.
- ⚠️ Slight overhead vs. pure view-local `@State` for one-off animations. Not worth it for trivial cases (e.g. button press feedback should remain view-local).

**Rule of thumb:** Animation that affects **gameplay state** (won, lost, revealed) → phase enum on the VM. Animation that's **pure decoration** (button bounce on press) → view-local `@State`.

### Pattern 4: ThemeManager via `@EnvironmentObject` — No Prop-Drilling

**What:** `ThemeManager` injected once at the App scene level. Every view that styles itself reads `@EnvironmentObject var themeManager` + `@Environment(\.colorScheme)`, then derives `theme = themeManager.theme(using: colorScheme)`. Game views inherit this for free — no parameter passing.

**When to use:** Always. Per FOUND-03.

**Trade-offs:** None — this is the DesignKit-prescribed integration pattern.

```swift
struct MinesweeperView: View {
    @EnvironmentObject private var themeManager: DesignKit.ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { themeManager.theme(using: colorScheme) }
    // ... use theme.colors / theme.spacing / theme.radii everywhere
}
```

### Pattern 5: Conditional CloudKit via `ModelConfiguration` Swap at App Boot

**What:** The app constructs its `ModelContainer` once at launch, with `cloudKitDatabase` set based on `SettingsStore.cloudSyncEnabled`. Toggling the setting at runtime requires the user to relaunch (one-time UX dialog), which is acceptable and is what the system supports cleanly. **The store path is the same in both modes** — flipping the flag promotes the existing local rows into the CloudKit-mirrored store (CloudKit mirrors the local store; it does not migrate to a separate store).

**When to use:** When `PERSIST-04` lands. Until then, ship with `.none`.

**Trade-offs:**
- ✅ No data migration code: same store, just starts mirroring.
- ✅ Sign-out keeps local data intact (CloudKit mirroring stops; local rows remain).
- ⚠️ Schema constraints must be CloudKit-compatible **from day 1** even if cloud is off (all-optional / all-defaulted, no `.unique`, no required-non-optional relationships). Designing the schema this way at PERSIST-01 is free; retrofitting is expensive.
- ⚠️ Switching the flag requires app relaunch — acceptable and well-precedented (Apple Notes, Reminders, etc. behave similarly).

```swift
// App/GameKitApp.swift
@main
struct GameKitApp: App {
    @StateObject private var themeManager = DesignKit.ThemeManager()
    let container: ModelContainer

    init() {
        let useCloud = SettingsStore.shared.cloudSyncEnabled
        let config = ModelConfiguration(
            cloudKitDatabase: useCloud ? .private("iCloud.com.lauterstar.gamekit") : .none
        )
        // CloudKit-compatible schema from day 1 — all optional/defaulted, no .unique
        self.container = try! ModelContainer(
            for: GameRecord.self, BestTime.self,
            configurations: config
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .modelContainer(container)
        }
    }
}
```

**Sign-in flow (PERSIST-06):** First launch creates anonymous local data via `cloudKitDatabase: .none`. When the user signs in via Sign in with Apple, the app:
1. Sets `SettingsStore.cloudSyncEnabled = true`.
2. Shows "Restart to enable iCloud sync" dialog with one-tap Restart.
3. Next launch reconfigures with `.private(...)`. SwiftData/CloudKit sees existing local rows and pushes them up.
4. Sign-out keeps `cloudSyncEnabled = true` until the user toggles it off; local data is not deleted.

---

## Data Flow

### Cold Start → Home → Game → Stats

```
[App launch]
    ↓
GameKitApp.init: read SettingsStore (UserDefaults, sync read, ~ms)
    ↓                                    ↓
construct ModelContainer            construct ThemeManager
    ↓                                    ↓
WindowGroup → RootView → (hasSeenIntro? IntroFlowView : HomeView)
    ↓
HomeView shows Minesweeper card
    ↓ tap
NavigationStack pushes MinesweeperView(viewModel: MinesweeperViewModel(stats: ...))
    ↓ first tap
ViewModel.tap(coord):
    BoardGenerator.generate(excluding: coord)  → board
    RevealEngine.reveal(at: coord, on: board)  → (board', revealed cells)
    phase = .revealing(cells)
    ↓
MinesweeperView observes phase change, triggers animation
    ↓ subsequent taps continue, eventually:
WinDetector → state = .won
    ↓
GameStats.record(gameKind: .minesweeper, difficulty: .medium, .win, 87.2)
    ↓
modelContext.insert(GameRecord(...))    [if cloud on, mirrored to iCloud]
    ↓
StatsView (next time user navigates) @Query refetches
```

### Sign-In → CloudKit Promotion

```
[User in Settings taps "Sign in with Apple"]
    ↓
ASAuthorizationController flow → success
    ↓
SettingsStore.cloudSyncEnabled = true   [UserDefaults, persists across launch]
SettingsStore.appleUserID = identifier
    ↓
Show alert: "Restart to enable iCloud sync"  [user taps Restart]
    ↓
[Next cold launch]
GameKitApp.init: useCloud = true
ModelConfiguration(cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit"))
    ↓
SwiftData opens existing local store, sees cloudKitDatabase config
    ↓
CloudKit mirroring begins: existing local GameRecord/BestTime rows push to iCloud
    ↓
On other devices signed in to same iCloud account, same app: rows pulled down
```

**Sign-out behavior:** The user signs out of *iCloud* at the system level (not in-app — there is no app-level sign-out for CloudKit-mirrored stores). When they do, mirroring stops. **Local data remains untouched.** This matches Apple Notes behavior. The app should not surface a "sign out" button — it's a system action, not an app one.

### Theme Change → Game Re-render

```
[User picks new preset in DKThemePicker]
    ↓
ThemeManager.preset = .dracula                   (@Published / @Observable)
    ↓
SwiftUI invalidates every view reading themeManager
    ↓
MinesweeperView re-derives theme.colors.surface, etc.
    ↓
Cells re-render with new tokens — no game state touched
```

---

## Build Order (Maps to Phase Names)

The roadmap should follow this ordering. Each phase is a clean, shippable boundary — you could call it done and merge if scope shifts.

| # | Suggested Phase Name | Scope | Requirements It Closes |
|---|----------------------|-------|------------------------|
| 1 | **Foundation** | Xcode project · DesignKit SPM dep · `GameKitApp` with `ThemeManager` injection · empty `HomeView` / `SettingsView` / `StatsView` shells reading theme tokens · `SettingsStore` over UserDefaults · placeholder app icon · localizable strings catalog · bundle ID set | FOUND-01..06, SHELL-01 (skeletal), THEME-01 (skeletal) |
| 2 | **Mines logic (engines)** | `MinesweeperBoard/Cell/Difficulty/GameState`, `BoardGenerator`, `RevealEngine`, `WinDetector` — pure structs — with full Swift Testing / XCTest coverage. **No UI in this phase.** First-tap-safe placement explicitly tested. | MINES-01, MINES-03, MINES-04 (engine layer), MINES-07 (detection layer) |
| 3 | **Mines UI** | `MinesweeperViewModel`, `MinesweeperView`, board grid, mine counter, timer, restart, end-state overlay using `theme.colors.{success,danger}`. Hooked to engines. Theme-token-pure from the start. | MINES-02, MINES-05, MINES-06, MINES-07 (UI), THEME-02 |
| 4 | **Stats + Persistence** | `GameKind` enum · `GameRecord` and `BestTime` `@Model`s with CloudKit-compatible schema (all optional/defaulted, no `.unique`) · `GameStats.record()` · `StatsView` showing per-difficulty data via `@Query` · Export/Import JSON with `schemaVersion` · ModelConfiguration with `cloudKitDatabase: .none` | PERSIST-01, PERSIST-02, PERSIST-03, SHELL-03 |
| 5 | **Polish (animation + haptics + SFX + a11y + theme matrix)** | Phase enum on VM · reveal cascade · flag spring · win sweep · loss shake · DesignKit haptics · SFX (off by default) · VoiceOver labels · Dynamic Type · Reduce Motion · legibility check on Classic + Sweet + Bright + Soft + Moody + Loud presets · 3-step intro | MINES-08..10, SHELL-02, SHELL-04, THEME-01, THEME-03, A11Y-01..03 |
| 6 | **CloudKit + Sign in with Apple** | iCloud capability · CKContainer setup · `cloudKitDatabase: .private(...)` swap · Sign in with Apple flow · "Restart to enable" dialog · settings card · local-data-survives-sign-out verified | PERSIST-04, PERSIST-05, PERSIST-06 |
| 7 | **Release prep** | Real app icon · TestFlight build · privacy nutrition labels (none collected) · App Store copy · final theme-matrix legibility audit | (ship gate) |

**Ordering rationale:**
- Engines before UI: catches first-tap-safety bugs (`MINES-03` is a hard requirement) without needing to play the game manually.
- Persistence before polish: stats writes need to exist before win/loss animations can fire `stats.record`. Animations on top of stub stats produce drift.
- CloudKit *after* polish: PERSIST-04 is "optional sign in," not gameplay — keep it after the core loop is shipped-quality so a CloudKit hiccup never blocks the gameplay phase.

---

## Stay-Out-Of List (Tempting-But-Wrong Patterns)

These are abstractions to *not* introduce until games 2 and 3 prove the shape they should take. Premature abstraction here is the largest architectural risk for a multi-game suite.

### 1. Do not invent a `GameProtocol` / `Playable` protocol on day 1

**Tempting because:** "It's a multi-game suite. Surely each game implements `protocol Game { var name: String; func startNewGame() }`." Feels like good design.

**Why wrong:** You don't know the right protocol shape until games 2 *and* 3 exist. Mines, Merge, and Word Grid have nearly nothing useful in common at the type level: Mines has cells + difficulties, Merge has continuous state + score, Word Grid has a dictionary service. A protocol invented from one example will need to be rewritten when game 2 lands, *and again* when game 3 lands. Each rewrite ripples into game 1.

**Do this instead:** Each game folder is self-contained. `HomeView` has a static `[GameCard]` array of card metadata (name, icon, isEnabled, destination view). When game 3 ships, look at what the three view models actually share, *then* extract.

### 2. Do not build per-game SwiftData models (`MinesweeperGameRecord`, `MergeGameRecord`)

**Tempting because:** "Each game's stats are different." Feels typesafe.

**Why wrong:** It triples migration work for each new game (new `@Model` → schema change → CloudKit container change → StatsView branches). And the fields you actually persist for a "game session" (`playedAt`, `outcome`, `duration`, `difficulty`) are universal across the entire suite.

**Do this instead:** One `GameRecord` with a `gameKind` discriminator (Pattern 2 above). When a game truly has unique fields, add a sibling `@Model GameRunDetail` linked by `gameRecordID` rather than a per-game record model.

### 3. Do not build a runtime "game registry" / plug-in architecture

**Tempting because:** Sounds elegant. "Games register themselves at launch and the home screen renders dynamically."

**Why wrong:** Games are added at compile time, not runtime. There is no scenario where the suite needs to load a game it didn't ship with. Every line of registry/plug-in code is dead-weight scaffolding around what should be a literal `[GameCard]` array.

**Do this instead:** Static array. Add an entry when you add a game. That's the entire registry.

### 4. Do not introduce TCA / Redux / heavy state management

**Tempting because:** "Each game has complex state — surely TCA reducers are the answer."

**Why wrong:** Per AGENTS.md §1, this is explicitly excluded. `@Observable` ViewModels are sufficient for board state (Mines is ~800 cells max; Merge is 16 tiles; Word Grid is ~25 letters). Adding TCA imposes a learning tax on every future game and adds a dependency that competes with DesignKit's role as the cross-cutting framework.

**Do this instead:** `@Observable` final class per game, pure engine structs, view-local `@State` for transient UI. This is a mature, Apple-supported pattern in iOS 17+.

### 5. Do not build a generic "AnimationCoordinator" service

**Tempting because:** Mines has reveal cascade + flag spring + win sweep + loss shake — feels like animations need a coordinator.

**Why wrong:** Each game's animation vocabulary is different. A generic coordinator becomes a thin wrapper over `withAnimation { ... }` that obscures rather than clarifies. The phase-enum-on-VM pattern (Pattern 3) is sufficient and per-game-flexible.

**Do this instead:** Phase enum on each game's VM. One `animate(for: phase)` switch in each game's view. If you find yourself copy-pasting an animation primitive between games, *then* promote it — first to a local helper, then (when proven across 2+ games) to DesignKit motion.

### 6. Do not create per-game settings classes (`MinesweeperSettings`, `MergeSettings`)

**Tempting because:** "Mines has board grid style; Merge will have swipe sensitivity."

**Why wrong:** For MVP, none of these per-game settings exist as requirements. Adding the slot creates pressure to fill it. When game 2 actually needs a per-game setting, the right home is a single `GameSettings` keyed by `gameKind`, or just a few additional fields on `SettingsStore` — not a class hierarchy.

**Do this instead:** `SettingsStore` holds shared toggles only (haptics, SFX, theme, cloudSync, hasSeenIntro). Per-game preferences are deferred to whenever the second game's first per-game preference is concretely required.

### 7. Do not split DesignKit consumption into per-game theme adapters

**Tempting because:** "Mines might want a 'minesweeper-tuned' palette."

**Why wrong:** Per the THEME requirements, every game must read raw DesignKit tokens. An adapter layer means a token change in DesignKit doesn't propagate cleanly. Worse, it creates a place to hide hardcoded colors disguised as "Mines defaults."

**Do this instead:** Read `theme.colors.surface` directly in `MinesweeperCellView`. If a token is missing, *extend DesignKit*. If Mines genuinely needs a "revealed cell" color distinct from `surface`, the right answer is `theme.colors.fillSelected` or proposing a new semantic token to DesignKit — not a Mines-only override layer.

---

## Anti-Patterns

### Anti-Pattern 1: ViewModel imports SwiftUI

**What people do:** `import SwiftUI` at the top of `MinesweeperViewModel.swift`, then use `Color`, `Animation`, or `withAnimation` inside the VM.

**Why it's wrong:** Couples logic to the UI framework. Tests now need a UI host. Logic isn't reusable for previews or alternate UIs (e.g. a hypothetical macOS variant).

**Do this instead:** ViewModel imports only `Foundation` (and `Observation` for `@Observable`). Animation is the View's job — it observes the phase enum and wraps state changes in `withAnimation`.

### Anti-Pattern 2: Engine touches `ModelContext`

**What people do:** `RevealEngine.reveal(...)` writes directly to SwiftData.

**Why it's wrong:** Engine is no longer pure. Cannot test without a model container. Can no longer be replayed deterministically from a seed.

**Do this instead:** Engine returns the new board + a list of side-effect descriptions. ViewModel translates terminal states into `GameStats.record(...)` calls. SwiftData stays out of the engine layer.

### Anti-Pattern 3: NavigationStack scattered across views

**What people do:** `NavigationStack` declared in every screen that wants to push.

**Why it's wrong:** Multiple navigation stacks → broken back-button behavior → lost state on rotation. Hard to deep-link.

**Do this instead:** Single `NavigationStack(path: $path)` at `RootView`. All `Screens/*` views push via `NavigationLink(value:)` with a typed enum (`enum Route { case minesweeper, settings, themeExplorer, stats }`). Future deep links land here.

### Anti-Pattern 4: `@Query` inside reusable cards

**What people do:** A reusable `BestTimesCard` does its own `@Query`.

**Why it's wrong:** Per CLAUDE.md §8.2 — duplicates fetch logic, breaks previews, makes the card unreusable on screens that need a filtered subset.

**Do this instead:** Reusable cards accept data as props (`times: [BestTime]`). The owning screen does the `@Query`.

### Anti-Pattern 5: Hardcoded colors with "TODO: themeify"

**What people do:** `Color.gray.opacity(0.3)` with a comment.

**Why it's wrong:** Per CLAUDE.md §1, theme-token purity is non-negotiable. The TODO never gets done. Loud/Moody presets become unreadable.

**Do this instead:** First time: `theme.colors.fillDisabled` or similar. If no token fits, *extend DesignKit*. Never commit a `Color.X` literal in app code.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 game (Mines, MVP) | The structure described. Single container, single Stats view, no abstractions. |
| 2-3 games | StatsView grows a `gameKind` segmented control. Home array gets more entries. **Look at shared VM patterns now** — if 2 of 3 use a "place items, win condition" loop, *consider* extracting a helper. Do not extract a protocol unless 3 of 3 share the shape. |
| 4-9 games (full roadmap) | Per-game stats may want their own subview — refactor StatsView into a switch on `gameKind`. If shared engine helpers emerge (RNG seeding, daily-puzzle date math), they go in `Core/`. CloudKit container may need a schema migration as cross-game shared shapes evolve — keep the schemaVersion field. |

**First bottleneck:** SwiftData query performance once a user has thousands of `GameRecord` rows. Mitigation: paginate or cap StatsView queries with a `fetchLimit`. Not an MVP concern.

**Second bottleneck:** Theme-matrix verification time. With 34 presets × 9 games × multiple game states, manual visual QA explodes. Mitigation: snapshot tests for each game's main screen across `PresetCatalog.all` once game 3 lands. Not an MVP concern.

---

## Integration Points

### External

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| DesignKit (SPM) | Local path dep at `../DesignKit` | Never vendor. Extend at source. Keep `ThemeManager` injection at App scene. |
| iCloud / CloudKit | `ModelConfiguration(cloudKitDatabase: .private(...))` | Schema must be CloudKit-compatible from day 1 (all-optional, no `.unique`). Toggle requires app relaunch. |
| Sign in with Apple | `ASAuthorizationController` in SettingsView's sign-in card | Only persists `appleUserID` and a signed-in flag. CloudKit handles the actual data sync — Sign in with Apple is the gating UX, not the data path. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | View reads VM properties (`@Observable`); calls VM methods | View never calls engines directly |
| ViewModel ↔ Engine | VM calls pure static functions / structs | Engine never imports SwiftUI/SwiftData |
| ViewModel ↔ GameStats | Constructor injection | VM doesn't see ModelContext |
| GameStats ↔ ModelContext | `record(...)` method that calls `context.insert(...)` | Single write seam for the entire app's stats |
| Screens ↔ Games/* | NavigationStack push with typed Route | One-way: Screens push into games, never the reverse |
| Anywhere ↔ DesignKit | `@EnvironmentObject ThemeManager` + `@Environment(\.colorScheme)` → `theme = themeManager.theme(using:)` | The single allowed way to style. No bypass. |

---

## Sources

- `/Users/gabrielnielsen/Desktop/GameKit/.planning/PROJECT.md` — requirement IDs, decisions
- `/Users/gabrielnielsen/Desktop/GameKit/CLAUDE.md` — engine purity rule, file size caps, folder structure
- `/Users/gabrielnielsen/Desktop/GameKit/AGENTS.md` — non-negotiables, MVVM lightweight pattern
- `/Users/gabrielnielsen/Desktop/GameKit/README.md` — current folder layout and Mines models
- `/Users/gabrielnielsen/Desktop/DesignKit/README.md` — token surface, ThemeManager API, integration patterns
- [Apple — Syncing model data across a person's devices (SwiftData + CloudKit)](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) — `cloudKitDatabase` ModelConfiguration option, schema constraints
- [Hacking with Swift — How to sync SwiftData with iCloud](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud) — practical setup; "all properties must be optional or default; no `.unique`; relationships optional"
- [Apple Developer Forums — Local SwiftData to CloudKit migration](https://developer.apple.com/forums/thread/756538) — confirms the same store path works for both modes when schema is CloudKit-compatible from day 1
- [Apple Developer Forums — Disable automatic iCloud sync with SwiftData](https://developer.apple.com/forums/thread/731375) — `cloudKitDatabase: .none` to opt out per-launch

---

*Architecture research for: GameKit multi-game iOS suite (MVP: Minesweeper)*
*Researched: 2026-04-24*
