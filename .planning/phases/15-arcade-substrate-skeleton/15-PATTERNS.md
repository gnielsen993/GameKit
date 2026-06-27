# Phase 15: Arcade Substrate + Skeleton — Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 13 (5 new, 6 modified, 1 deferred, 1 doc)
**Analogs found:** 12 / 13 (doc ADR has no analog — shape provided by RESEARCH.md Pattern 10)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `Core/ArcadeLoopDriver.swift` | middleware / ViewModifier | event-driven (real-time loop) | `Core/VideoModeAware.swift` | exact — same struct+extension View shape |
| `Core/ArcadeGameState.swift` | model (enum) | state-machine | `Games/Merge/MergeGameState.swift` | exact — same `nonisolated enum … Equatable, Hashable, Sendable` shape |
| `Games/Stack/StackHarnessView.swift` | component + viewmodel | event-driven (real-time loop) | `Games/Minesweeper/MinesweeperGameView.swift` (env/scenePhase) + `Games/Merge/MergeViewModel.swift` (@Observable shape) | role-match composite |
| `Games/Snake/SnakeHarnessView.swift` | component + viewmodel | event-driven (real-time loop) | same composite as Stack | role-match composite |
| `gamekitTests/Core/ArcadeLoopDriverTests.swift` | test | N/A | `gamekitTests/Engine/BoardGeneratorTests.swift` (nonisolated) | exact — same `nonisolated struct` + `@Suite` + `#expect` shape |
| `Core/GameKind.swift` (+2 cases) | model enum | N/A | self (existing file) | self-analog |
| `Core/GameRoute.swift` (+2 cases) | routing enum | N/A | self (existing file) | self-analog |
| `Core/GameDescriptor.swift` (+AccentRole slot9/10, +2 .all entries) | config / catalog | N/A | self (existing file) | self-analog |
| `Core/GameKind+AccentColor.swift` (+2 cases) | utility extension | N/A | self (existing file) | self-analog |
| `Core/GameStats.swift` (resetAll) | service | CRUD | self (existing file) | **DEFERRED** — no change in Phase 15 |
| `Screens/HomeView.swift` (+2 destination cases) | screen / router | request-response | self lines 355–357 (klondike precedent) | self-analog — klondike is exact precedent |
| `Screens/StatsView.swift` (+@Query pairs + placeholders) | screen / data-driven | CRUD | self lines 56–64 (merge @Query pair) + lines 113–121 (wordGrid BestScore pair) | self-analog |
| `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md` | doc | N/A | none — content in RESEARCH.md Pattern 10 | no analog |

---

## Pattern Assignments

### `Core/ArcadeLoopDriver.swift` (middleware, event-driven)

**Analog:** `Core/VideoModeAware.swift`

**Imports pattern** (VideoModeAware.swift lines 34–36):
```swift
import SwiftUI
import DesignKit
```
`ArcadeLoopDriver` imports SwiftUI only (no DesignKit — the driver has no UI tokens). Shape is otherwise identical.

**Struct declaration pattern** (VideoModeAware.swift lines 37–40):
```swift
struct VideoModeAware: ViewModifier {
    @Environment(\.videoModeStore) private var store
    let minBoardHeight: CGFloat
```
`ArcadeLoopDriver` uses stored properties instead of @Environment — same `struct Name: ViewModifier` header, same `let` parameters:
```swift
struct ArcadeLoopDriver: ViewModifier {
    let isRunning: Bool
    let onTick: (_ dt: Double) -> Void
    @State private var lastDate: Date? = nil
```

**Core ViewModifier body pattern** (VideoModeAware.swift lines 74–85):
```swift
func body(content: Content) -> some View {
    if !store.isEnabled { return AnyView(content) }
    return AnyView(onPath(content: content))
}
```
`ArcadeLoopDriver.body` does NOT use AnyView (no branching needed at top level — the `if isRunning` is inside `.background`). Use standard `@ViewBuilder`-free return:
```swift
func body(content: Content) -> some View {
    content
        .background {
            if isRunning {
                TimelineView(.animation) { context in
                    Color.clear
                        .onChange(of: context.date) { _, newDate in
                            let rawDt = lastDate.map { newDate.timeIntervalSince($0) } ?? 0
                            lastDate = newDate
                            onTick(min(rawDt, 0.1))
                        }
                }
            }
        }
        .onChange(of: isRunning) { _, running in
            if !running { lastDate = nil }
        }
}
```

**Extension View pattern** (VideoModeAware.swift lines 150–175):
```swift
extension View {
    func videoModeAware(minBoardHeight: CGFloat = 320) -> some View {
        modifier(VideoModeAware(minBoardHeight: minBoardHeight))
    }
}
```
Copy this shape exactly — name the method `arcadeLoop(isRunning:onTick:)` with no default values:
```swift
extension View {
    func arcadeLoop(isRunning: Bool, onTick: @escaping (_ dt: Double) -> Void) -> some View {
        modifier(ArcadeLoopDriver(isRunning: isRunning, onTick: onTick))
    }
}
```

**File header comment pattern** (VideoModeAware.swift lines 1–32):
Copy the multi-line doc-comment block structure: file name, product name, one-line purpose, phase invariants list with D-xx references, adoption example. Adapt content for ArcadeLoopDriver.

**No #Preview block needed** — ArcadeLoopDriver is not visual on its own. VideoModeAware has previews (lines 227–392) because it affects layout; ArcadeLoopDriver does not.

---

### `Core/ArcadeGameState.swift` (model enum, state-machine)

**Primary analog:** `Games/Merge/MergeGameState.swift` (lines 1–25)
**Secondary analog:** `Games/Minesweeper/MinesweeperGameState.swift` (lines 1–35)

**Full analog — MergeGameState.swift** (lines 14–25):
```swift
import Foundation

nonisolated enum MergeGameState: Equatable, Hashable, Sendable {
    /// Pre-first-spawn. Board is empty.
    case idle
    /// Tiles are spawning / sliding. Standard play.
    case playing
    /// Reached 2048 in `.winMode`. View shows the win banner;
    case won
    /// No legal moves remain. Terminal state — only `restart()` exits this.
    case gameOver
}
```

`ArcadeGameState` follows this shape exactly — same modifiers (`nonisolated`, `Equatable, Hashable, Sendable`), same Foundation-only import, same four-case structure (idle / running / paused / gameOver). The only difference from MergeGameState is the case names reflect real-time arcade semantics (`.running` not `.playing`, `.paused` added):
```swift
import Foundation

nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable {
    case idle       // tap-to-start affordance shown; loop NOT running
    case running    // frame loop active; input accepted
    case paused     // scenePhase backgrounded; loop suspended, state preserved
    case gameOver   // terminal; score frozen; restart available
}
```

**File header** (MergeGameState.swift lines 1–12 as template):
```swift
//  MergeGameState.swift
//  gamekit
//
//  Lifecycle of a Merge session, owned by the ViewModel. Engines never read
//  or write this state — they transform Boards; the VM derives the next
//  state from the resulting Board via GameOverDetector predicates.
//
//  Foundation-only. Mirrors MinesweeperGameState discipline at
//  MinesweeperGameState.swift:26.
```
Adapt: "Shared lifecycle enum for endless arcade games. Foundation-only. Mirrors MergeGameState discipline at MergeGameState.swift:15. Both Stack and Snake VMs own a `private(set) var state: ArcadeGameState`. No persistence needed — the live state resets cleanly on restart."

---

### `Games/Stack/StackHarnessView.swift` and `Games/Snake/SnakeHarnessView.swift` (component + viewmodel, event-driven)

These are throwaway harness files. Each file contains both the view and its VM (two types in one file is acceptable here — both are under ~100 lines and the file is deleted at Phase 16/17 start).

**VM shape analog:** `Games/Merge/MergeViewModel.swift` lines 18–46

```swift
@Observable @MainActor
final class MergeViewModel {
    private(set) var board: MergeBoard
    private(set) var score: Int = 0
    private(set) var mode: MergeMode
    private(set) var state: MergeGameState = .idle
    private(set) var mergeCount: Int = 0     // counter-trigger pattern
    private(set) var terminalCount: Int = 0  // counter-trigger pattern
    private(set) var gameStats: GameStats?
```

`StackHarnessVM` / `SnakeHarnessVM` use the same `@Observable @MainActor final class` shape, same `private(set)` discipline, same `state: ArcadeGameState = .idle`. The harness VM is simpler (no engine, no stats, no save-state):
```swift
@Observable @MainActor
final class StackHarnessVM {
    private(set) var state: ArcadeGameState = .idle
    private(set) var tickCount: Int = 0   // drives harness visual; counter-trigger shape
    private var accumulator: Double = 0
    private let fixedDt = 1.0 / 60.0

    func tick(dt: Double) { ... }
    func start()  { state = .running }
    func pause()  { if state == .running { state = .paused } }
    func resume() { if state == .paused  { state = .running } }
    func stop()   { state = .idle; accumulator = 0 }
}
```

**View env declarations analog:** `Games/Minesweeper/MinesweeperGameView.swift` lines 41–50

```swift
struct MinesweeperGameView: View {
    @State var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
```

`StackHarnessView` / `SnakeHarnessView` declare the same env set minus `modelContext` (no stats in Phase 15). VM is owned via `@State` (same `@State var vm = StackHarnessVM()` idiom — NOT `@StateObject`):
```swift
struct StackHarnessView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = StackHarnessVM()
    private var theme: Theme { themeManager.theme(using: colorScheme) }
```

**scenePhase handler analog:** `Games/Minesweeper/MinesweeperGameView.swift` lines 160–172

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        viewModel.saveCurrentState()
        viewModel.pause()
    case .active:
        viewModel.resume()
    case .inactive:
        break    // no-op for Minesweeper — control-center pull should NOT pause timer
    @unknown default:
        break
    }
}
```

**CRITICAL DIFFERENCE for arcade harness:** `.inactive` MUST call `vm.pause()` for real-time loop games (RESEARCH.md Pitfall 1, D-03, D-05). A notification banner is `.inactive`. The Minesweeper precedent intentionally omits `.inactive` because pausing a turn-based timer on a control-center pull is wrong. For the arcade loop the opposite is true. Use this shape instead:
```swift
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active:
        vm.resume()
    case .inactive, .background:
        vm.pause()
    @unknown default:
        vm.pause()
    }
}
```

**arcadeLoop adoption in view body:**
```swift
someView
    .arcadeLoop(isRunning: vm.state == .running) { dt in
        vm.tick(dt: dt)
    }
```
This is the only call site in the harness view.

**Token-only colors** (CLAUDE.md §1 + RESEARCH.md Pitfall 7): harness view uses `theme.colors.accentPrimary` for the moving dot and `theme.colors.textSecondary` for readout text. No `Color.green`, no `Color.orange`. Hardcoded colors trigger the pre-commit hook even in throwaway files.

**No `.videoModeAware()` call** — confirmed by RESEARCH.md Pattern 8 + D-10 ADR. `.disableInteractivePop()` is applied in HomeView, not in the harness view itself.

---

### `gamekitTests/Core/ArcadeLoopDriverTests.swift` (test, N/A)

**Primary analog:** `gamekitTests/Engine/BoardGeneratorTests.swift` lines 1–17

```swift
import Testing
import Foundation
@testable import gamekit

@Suite("BoardGenerator")
nonisolated struct BoardGeneratorTests {
```

`ArcadeLoopDriverTests` is `nonisolated` (same as BoardGeneratorTests) because it tests Foundation-only types (`ArcadeGameState`, the clamp math). No SwiftData = no `@MainActor` required (contrast with `GameStatsTests` and `ModelContainerSmokeTests` which are `@MainActor` because `ModelContext` is not Sendable).

**MARK grouping pattern** (VideoModeAwareTests.swift lines 119–121):
```swift
// MARK: - VIDEO-13 / D-05 / SC3: off-state byte-identical

@Test("Off state — modifier does NOT publish videoModeCompactness env (VIDEO-13 / D-05 / SC3)")
```
Each test gets a MARK comment referencing the ROADMAP success-criterion ID. Copy this convention:
```swift
// MARK: - SC1a: onTick gating (ROADMAP Phase 15 SC1a)

@Test("onTick is gated on .running — other states produce zero ticks")

// MARK: - SC1b: spiral-of-death clamp (ROADMAP Phase 15 SC1b)

@Test("spiral-of-death clamp: dt=2.0 produces at most 15 steps")
```

**#expect call pattern** (BoardGeneratorTests.swift lines 36–38):
```swift
#expect(board.cells.count(where: \.isMine) == 10,
    "Easy must place exactly 10 mines (seed: \(seed))")
```
Include a failure message string on every `#expect` — it identifies which scenario failed. The two required tests are pure math; no SwiftUI hosting or UIHostingController needed (unlike VideoModeAwareTests which needs UIKit to probe an env value).

**Full file import block:**
```swift
import Testing
import Foundation
@testable import gamekit
```
No SwiftUI, no SwiftData — the tests probe the clamp constant and the `ArcadeGameState` enum directly.

---

## Shared Patterns (apply to all modified files)

### GameKind enum — additive case pattern

**Source:** `Core/GameKind.swift` lines 24–33

```swift
enum GameKind: String, Codable, Sendable, CaseIterable {
    case minesweeper
    case merge
    case nonogram
    case sudoku
    case freeCell
    case klondike
    case fiveLetter
    case wordGrid
    // Phase 15: append here
    case stack   // raw: "stack" — stable serialization key; locked on first GameRecord write
    case snake   // raw: "snake"
}
```

Raw value = Swift identifier name = lowercase. No explicit `rawValue:` string needed. The raw value is the `gameKindRaw` column value written to `GameRecord` and `BestScore` rows. It is a **permanent lock** — never rename after first data write.

### GameRoute enum — plain case pattern (no associated value)

**Source:** `Core/GameRoute.swift` lines 26–35

```swift
enum GameRoute: Hashable, Sendable {
    case minesweeper(MinesweeperDifficulty?)
    // ...
    case klondike(SolitaireDifficulty?)
    case wordGrid(WordGridMode?)
    // Phase 15: append here — NO associated value for endless games (D-09)
    case stack   // modes: [] in descriptor; no mode chip ever deep-links here
    case snake
}
```

Existing cases have associated values for mode-chip deep-linking. `case stack` and `case snake` are plain (no associated value) because `modes: []` in the descriptor means no mode chip exists to supply a parameter.

### GameDescriptor.AccentRole — slot pattern

**Source:** `Core/GameDescriptor.swift` lines 34–57

```swift
enum AccentRole: Sendable {
    case slot1
    // ...
    case slot8

    var index: Int {
        switch self {
        case .slot1: return 0
        // ...
        case .slot8: return 7
        }
    }
}
```

Append two cases. Each must also get an `index` entry:
```swift
case slot9   // Stack
case slot10  // Snake

// In AccentRole.index switch:
case .slot9:  return 8
case .slot10: return 9
```

### GameDescriptor.all — entry shape

**Source:** `Core/GameDescriptor.swift` lines 241–254 (wordGrid — most recent entry, clearest template for a `modes: []` → `modes: [chips]` game):

```swift
GameDescriptor(
    kind: .wordGrid,
    titleKey: "Word Grid",
    captionKey: "Tap to play",
    symbol: "square.grid.3x3",
    accent: .slot8,
    route: .wordGrid(nil),
    modes: [
        GameModeChip(id: "wordgrid-timed", labelKey: "Timed", detailKey: "3 min", route: .wordGrid(.timed)),
        GameModeChip(id: "wordgrid-relaxed", labelKey: "Relaxed", detailKey: "No timer", route: .wordGrid(.relaxed))
    ],
    shortMeta: "Trace words"
)
```

Stack and Snake entries differ only in `modes: []` (D-09 — direct launch, no chips) and `route: .stack` (plain, no associated value):
```swift
GameDescriptor(
    kind: .stack,
    titleKey: "Stack",
    captionKey: "Tap to play",
    symbol: "square.stack.fill",    // verify in SF Symbols app — may need fallback
    accent: .slot9,
    route: .stack,
    modes: [],
    shortMeta: "Endless tower"
),
GameDescriptor(
    kind: .snake,
    titleKey: "Snake",
    captionKey: "Tap to play",
    symbol: "arrow.triangle.turn.up.right.diamond",  // verify in SF Symbols app
    accent: .slot10,
    route: .snake,
    modes: [],
    shortMeta: "Endless grid"
)
```

### GameKind+AccentColor — brand color case pattern

**Source:** `Core/GameKind+AccentColor.swift` lines 13–28

```swift
extension GameKind {
    var accentColor: Color {
        switch self {
        case .minesweeper: return Color(red: 0.184, green: 0.482, blue: 0.965)
        // ...
        case .wordGrid:    return Color(red: 0.871, green: 0.278, blue: 0.522)
        }
    }
}
```

Append two cases. Values are locked by D-07:
```swift
case .stack: return Color(red: 0.961, green: 0.498, blue: 0.122)  // vivid orange
case .snake: return Color(red: 0.176, green: 0.741, blue: 0.490)  // calm green
```

These are raw `Color(red:green:blue:)` values — NOT DesignKit tokens. The file's header explicitly documents this is intentional (single-consumer brand constants, Core/ scope exempts from the Screens/ hardcoded-color hook).

### HomeView destination(for:) — routing case pattern

**Source:** `Screens/HomeView.swift` lines 336–370

The exact precedent for Stack/Snake is `case .klondike` at lines 355–357 — the only existing case that omits `.videoModeAware()`:

```swift
@ViewBuilder
private func destination(for route: GameRoute) -> some View {
    switch route {
    case .minesweeper(let difficulty):
        MinesweeperGameView(initialDifficulty: difficulty)
            .videoModeAware(minBoardHeight: 480)
            .disableInteractivePop()
    // ...
    case .klondike(let difficulty):
        SolitaireGameView(initialDifficulty: difficulty ?? .easy)
            .disableInteractivePop()       // NO .videoModeAware() — klondike precedent
    // ...
    }
}
```

Append after the last case (`.wordGrid`). Stack and Snake follow the klondike pattern (no `.videoModeAware()`), documented by the ADR (D-10):
```swift
case .stack:
    StackHarnessView()
        .disableInteractivePop()   // ADR ARCADE-08: no .videoModeAware() for real-time games
case .snake:
    SnakeHarnessView()
        .disableInteractivePop()   // ADR ARCADE-08: same exemption
```

Note: existing cases bind associated values (`let difficulty`, `let mode`). Stack and Snake have plain cases — no binding needed, no `nil` default.

### StatsView @Query pair pattern — score-based (BestScore) variant

**Source:** `Screens/StatsView.swift` lines 56–64 (merge — closest analog: score-based, `BestScore` not `BestTime`) and lines 113–121 (wordGrid — also BestScore):

```swift
@Query(
    filter: #Predicate<GameRecord> { $0.gameKindRaw == "merge" },
    sort: \.playedAt,
    order: .reverse
)
private var mergeRecords: [GameRecord]

@Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "merge" })
private var mergeBestScores: [BestScore]
```

Stack and Snake are endless/score-based (Phase 18 will use BestScore, not BestTime). Phase 15 adds the @Query declarations even though the placeholder body doesn't use the score data yet:
```swift
@Query(
    filter: #Predicate<GameRecord> { $0.gameKindRaw == "stack" },
    sort: \.playedAt,
    order: .reverse
)
private var stackRecords: [GameRecord]

@Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "stack" })
private var stackBestScores: [BestScore]

@Query(
    filter: #Predicate<GameRecord> { $0.gameKindRaw == "snake" },
    sort: \.playedAt,
    order: .reverse
)
private var snakeRecords: [GameRecord]

@Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "snake" })
private var snakeBestScores: [BestScore]
```

**StatsView body section pattern** (StatsView.swift lines 148–153, merge entry):
```swift
if shows(.merge) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "MERGE")) }
    DKCard(theme: theme) {
        MergeStatsCard(theme: theme, records: mergeRecords, bestScores: mergeBestScores)
    }
}
```

Phase 15 placeholder sections replace `MergeStatsCard(...)` with an empty-state `Text(...)` (CLAUDE.md §8.3 — every data-driven view ships with explicit empty state):
```swift
if shows(.stack) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "STACK")) }
    DKCard(theme: theme) {
        // Phase 15: placeholder; replaced by StackStatsCard in Phase 16
        Text(String(localized: "No Stack games yet."))
            .foregroundStyle(theme.colors.textSecondary)
            .padding(theme.spacing.m)
    }
}
if shows(.snake) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SNAKE")) }
    DKCard(theme: theme) {
        // Phase 15: placeholder; replaced by SnakeStatsCard in Phase 17
        Text(String(localized: "No Snake games yet."))
            .foregroundStyle(theme.colors.textSecondary)
            .padding(theme.spacing.m)
    }
}
```

`shows()` function (StatsView.swift lines 125–127) is already defined and works for any `GameKind`:
```swift
private func shows(_ kind: GameKind) -> Bool {
    focusedKind == nil || focusedKind == kind
}
```
No change needed to this function — it automatically works once `.stack` and `.snake` exist in `GameKind`.

---

## `Core/GameStats.swift` resetAll() — DEFERRED

Per RESEARCH.md MODIFIED table and CONTEXT.md deferred section: `StackSaveState.clearAll()` and `SnakeSaveState.clearAll()` lines in `resetAll()` are **not added in Phase 15**. No save-state files exist until Phase 16/17. Adding a stub call to a non-existent type causes a compile error. Add in the same commit that ships each save-state file.

**Source for when it does land** (GameStats.swift lines 186–194):
```swift
NonogramPicker.resetSeen()
SudokuSaveState.clearAll()
MinesweeperSaveState.clearAll()
NonogramSaveState.clearAll()
FreeCellSaveState.clearAll()
SolitaireSaveState.clearAll()
MergeSaveState.clearAll()
FiveLetterSaveState.clearAll()
WordGridSaveState.clearAll()
// Phase 16: StackSaveState.clearAll()
// Phase 17: SnakeSaveState.clearAll()
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `15-VIDEO-MODE-ADR.md` | doc | N/A | No existing ADR files in the phase directory to mirror; content fully specified in RESEARCH.md Pattern 10 |

---

## Metadata

**Analog search scope:** `gamekit/gamekit/Core/`, `gamekit/gamekit/Games/Minesweeper/`, `gamekit/gamekit/Games/Merge/`, `gamekit/gamekit/Screens/`, `gamekit/gamekitTests/Core/`, `gamekit/gamekitTests/Engine/`
**Files read:** 16 source files + 2 test files
**Pattern extraction date:** 2026-06-26

**Key distinctions planner must preserve:**
1. `ArcadeLoopDriver` is simpler than `VideoModeAware` — no GeometryReader, no EnvironmentKey, no `@ViewBuilder` helpers. The core pattern is just `content.background { if isRunning { TimelineView ... } }`.
2. `ArcadeGameState` diverges from `MinesweeperGameState` in one case name: `.paused` (new) vs MinesweeperGameState's no-pause-case. MergeGameState is the closer analog.
3. scenePhase handler in harness MUST include `.inactive` calling `vm.pause()`. MinesweeperGameView (the env pattern analog) omits `.inactive` — that is turn-based behavior, not arcade behavior.
4. HomeView new cases use plain `case .stack:` with no binding — all other existing cases bind `let mode` or `let difficulty`. Do not add a nil-binding to plain cases.
5. StatsView uses `BestScore` (not `BestTime`) for score-based games — the merge/wordGrid @Query pairs are the template, not the minesweeper/sudoku pairs.
