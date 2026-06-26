# Architecture Patterns — v1.5 Endless Arcade Primitive

**Domain:** Real-time loop substrate integration into an existing multi-game SwiftUI/SwiftData suite
**Researched:** 2026-06-25
**Confidence:** HIGH — all recommendations verified against the actual files in `gamekit/gamekit/`

---

## TL;DR (For Roadmap)

Two new `Core/` files (`ArcadeGameState` + `ArcadeLoopDriver`), two new `Games/<game>/` folders, and additive changes to seven existing files. No new SwiftData models — `BestScore` and `GameStats.record(gameKind:mode:outcome:score:)` already exist and already handle score-based high scores. The substrate is a `ViewModifier`, not a protocol on the VM; the engine contract lives at the engine layer (Foundation-only structs), not the VM layer. Video Mode is explicitly exempt for v1.5.

---

## 1. Where the Shared Substrate Lives

### Decision: `Core/`

Per CLAUDE.md §4: "Promote to Core/ when used in 2+ games." Both Stack and Snake consume the substrate from day one, so it qualifies immediately — the same rule that moved `VideoModeBanner`, `VideoModeTimerChip`, and `VideoCompactControlRow` into `Core/`.

### Concrete files (both NEW)

**`Core/ArcadeGameState.swift`**

Shared lifecycle enum used by both game VMs. Foundation-only, mirrors the shape of `MinesweeperGameState` (which is also a Foundation-only nonisolated enum):

```swift
nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable {
    case idle          // tap-to-start affordance shown; loop not running
    case running       // frame loop active; input accepted
    case paused        // scenePhase backgrounded; loop suspended, state preserved
    case gameOver      // terminal; score frozen; restart available
}
```

No `Codable` — the save-state structs (per-game, in `Games/<game>/`) hold the engine snapshot. The lifecycle itself resets cleanly on restart.

**`Core/ArcadeLoopDriver.swift`**

A `ViewModifier` that injects a `TimelineView(.animation)` background and delivers `dt` to the game VM on each display-linked frame. Kept as a modifier (not a generic `View`) so adoption is a single `.modifier(...)` call at the game view level — same pattern as `.videoModeAware(minBoardHeight:)` in `Core/VideoModeAware.swift`.

Concrete shape:

```swift
struct ArcadeLoopDriver: ViewModifier {
    let isRunning: Bool
    let onTick: (_ dt: Double) -> Void

    @State private var lastDate: Date? = nil

    func body(content: Content) -> some View {
        content
            .background {
                if isRunning {
                    TimelineView(.animation) { context in
                        Color.clear
                            .onChange(of: context.date) { _, newDate in
                                let dt = lastDate.map { newDate.timeIntervalSince($0) } ?? 0
                                lastDate = newDate
                                // Clamp dt to prevent spiral-of-death on stalled frames.
                                onTick(min(dt, 1.0 / 10.0))
                            }
                    }
                }
            }
            .onChange(of: isRunning) { _, running in
                if !running { lastDate = nil }
            }
    }
}

extension View {
    func arcadeLoop(isRunning: Bool, onTick: @escaping (_ dt: Double) -> Void) -> some View {
        modifier(ArcadeLoopDriver(isRunning: isRunning, onTick: onTick))
    }
}
```

Adoption in `StackGameView`:

```swift
boardView
    .arcadeLoop(isRunning: vm.state == .running) { dt in
        vm.tick(dt: dt)
    }
```

The modifier delivers `dt` to the VM's `tick(dt:)` method. The VM owns the engine instance and calls `engine.step(...)` internally. Scene-phase pause/resume lives in the game VM, not in the driver — same pattern as `MinesweeperViewModel+Timer.swift` where `pause()` and `resume()` live in the VM, triggered from `.onChange(of: scenePhase)` in the game view.

### What does NOT go in Core/

- `TickingEngine` protocol — no cross-game engine reuse is needed; each engine has a different state shape, different input type, different frame output. A shared protocol here would be a YAGNI extraction.
- End-state banner — `VideoModeBanner` already exists in `Core/` and is reused as-is (see §4 below).
- Per-game board rendering — `StackBoardView` and `SnakeBoardView` stay in their game folders.

---

## 2. Boundary: Pure Engine vs. Shared Substrate vs. Per-Game View

### Boundary map

```
Core/ArcadeGameState.swift           ← SHARED: lifecycle enum consumed by both VMs
Core/ArcadeLoopDriver.swift          ← SHARED: TimelineView delta-time injector
Core/VideoModeBanner.swift           ← SHARED: end-state banner (already exists)
Core/GameStats.swift                 ← SHARED: write-side persistence (already exists)

Games/Stack/Engine/StackEngine.swift ← PURE ENGINE: no SwiftUI, no SwiftData
Games/Stack/Engine/StackBoard.swift  ← PURE MODEL: Codable struct
Games/Stack/StackViewModel.swift     ← PER-GAME VM: @Observable @MainActor
Games/Stack/StackGameView.swift      ← PER-GAME VIEW: SwiftUI
Games/Stack/StackBoardView.swift     ← PER-GAME BOARD VIEW
(... etc.)

Games/Snake/Engine/SnakeEngine.swift ← PURE ENGINE
Games/Snake/Engine/SnakeBoard.swift  ← PURE MODEL
Games/Snake/SnakeViewModel.swift     ← PER-GAME VM
Games/Snake/SnakeGameView.swift      ← PER-GAME VIEW
(... etc.)
```

### Engine contract (Foundation-only pure structs)

Following the existing pattern (`RevealEngine`, `MergeEngine`, `BoardGenerator` — all Foundation-only with no SwiftUI or SwiftData):

**Stack engine**

```swift
// Games/Stack/Engine/StackEngine.swift
struct StackEngine {
    // Mutable state the VM holds onto between steps
    var tower: [StackBlock]       // placed blocks, bottom-up
    var slidingBlock: StackBlock  // current block sliding left/right
    var speed: Double             // current slide speed (ramps with score)
    var score: Int
    var isGameOver: Bool

    struct DropResult {
        let placed: StackBlock
        let overhangShaved: Double  // > 0 if width narrowed
        let newWidth: Double
        let scoreIncrement: Int
        let isGameOver: Bool
    }

    // Called when the user taps to drop. Deterministic given (state, tapTime).
    mutating func drop() -> DropResult { ... }

    // Called every frame to advance the sliding block.
    mutating func step(dt: Double) { ... }
}
```

**Snake engine**

```swift
// Games/Snake/Engine/SnakeEngine.swift
struct SnakeEngine {
    // Fixed-timestep: accumulate dt until >= cellDuration, then step.
    var snake: [GridPosition]       // head first
    var food: GridPosition
    var pendingGrow: Int
    var score: Int
    var accumulatedTime: Double
    let cellDuration: Double        // seconds per cell move (decreases with score)
    let gridSize: Int               // square grid side length

    struct StepFrame {
        let didMove: Bool           // false if not enough dt accumulated yet
        let ate: Bool               // true if head reached food this step
        let grew: Bool
        let isGameOver: Bool        // self-collision or wall
    }

    // Called every display frame with raw dt.
    mutating func step(dt: Double, pendingDir: GridDirection?) -> StepFrame { ... }
}
```

Fixed-timestep (accumulate dt inside the engine) keeps unit tests trivially deterministic: inject any sequence of `dt` values and direction inputs, assert the resulting frames match expectations exactly.

### VM contract (per-game, @Observable @MainActor)

Mirrors `MergeViewModel` (the closest existing analog — score-based, no difficulty presets, Foundation-only):

```swift
@Observable @MainActor
final class StackViewModel {
    private(set) var engine: StackEngine = .initial()
    private(set) var state: ArcadeGameState = .idle
    private(set) var scoreCount: Int = 0     // haptic trigger counter (bumped on score)
    private(set) var gameOverCount: Int = 0  // haptic trigger counter

    var gameStats: GameStats?

    func tick(dt: Double) {
        guard state == .running else { return }
        engine.step(dt: dt)
        // If user already tapped to drop this frame, drop() was called separately.
        // Detect score changes, bump scoreCount.
        if engine.isGameOver {
            state = .gameOver
            gameOverCount += 1
            recordTerminal()
        }
    }

    func drop() {
        guard state == .running else { return }
        let result = engine.drop()
        if result.scoreIncrement > 0 { scoreCount += 1 }
        if result.isGameOver { state = .gameOver; gameOverCount += 1; recordTerminal() }
    }

    func start() { state = .running }
    func restart() { engine = .initial(); state = .idle; scoreCount = 0; gameOverCount = 0 }

    func pause() { if state == .running { state = .paused } }
    func resume() { if state == .paused { state = .running } }

    private func recordTerminal() {
        clearSaveState()
        try? gameStats?.record(gameKind: .stack, mode: "endless", outcome: .loss, score: engine.score)
    }
}
```

The VM never imports SwiftUI or SwiftData, matching the isolation boundary established in `MinesweeperViewModel.swift` and `MergeViewModel.swift`.

---

## 3. Stats Integration

### What already exists (no new models needed)

Inspecting `Core/BestScore.swift` and `Core/GameStats.swift`: `BestScore` is already a first-class SwiftData model, and `GameStats` already has a score-based record overload:

```swift
// Already in Core/GameStats.swift:
func record(gameKind: GameKind, mode: String, outcome: Outcome, score: Int) throws
```

This overload inserts a `GameRecord` with the score attached and calls `evaluateBestScore(gameKind:mode:score:)` internally (higher-only). The `evaluateBestScore` method updates `BestScore` whenever the new score exceeds the stored high score — regardless of outcome. Endless arcade games (where the outcome is always `.loss`) benefit from this correctly: every run updates the high score if it's a personal best.

### Smallest additive change

**No new SwiftData models.** The existing `BestScore` + `GameRecord.score` schema handles everything Stack and Snake need.

The only required changes are additive and in existing Swift files:

1. **`Core/GameKind.swift`** — add two enum cases:
   ```swift
   case stack
   case snake
   ```
   Raw values `"stack"` and `"snake"` are the stable serialization keys. Treat them as locked at the moment the first `GameRecord` with these kinds is written (same invariant as `"minesweeper"` per GameKind.swift line 29).

2. **`Core/GameStats.swift` / `resetAll()`** — add two `clearAll()` lines alongside the existing game save-state resets:
   ```swift
   StackSaveState.clearAll()
   SnakeSaveState.clearAll()
   ```

3. **`Screens/StatsView.swift`** — add `@Query` pairs and `if shows(.stack)` / `if shows(.snake)` sections following the identical pattern already used for `.merge` (records + BestScore):
   ```swift
   @Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "stack" }, ...)
   private var stackRecords: [GameRecord]

   @Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "stack" })
   private var stackBestScores: [BestScore]
   ```
   Each game gets a `StackStatsCard` and `SnakeStatsCard` component in its own folder (same pattern as `MergeStatsCard` in `Games/Merge/`).

### CloudKit safety

All existing CloudKit safety invariants are preserved:
- No `@Attribute(.unique)` decorators on `BestScore` or `GameRecord` (both already lack them)
- All `BestScore` properties are optional or defaulted
- The existing `BestScore.gameKindRaw` column stores `"stack"` / `"snake"` — additive, no migration
- `schemaVersion` stays at its current value (adding new `gameKindRaw` values is not a schema change; it's new data in the same column)

### What "difficultyRaw" stores for endless games

Endless games have no difficulty presets. Store `"endless"` as the `difficultyRaw` / `mode` key. This gives the BestScore table one row per game kind keyed on `(gameKindRaw: "stack", difficultyRaw: "endless")`. If a difficulty tier is added in a future milestone, add new rows — don't mutate the existing `"endless"` key.

---

## 4. Home Screen and Navigation Integration

### What the home screen already is (verified against `HomeView.swift`)

`HomeView` is a `NavigationStack` with a `destination(for: GameRoute)` switch. Adding a game requires:
1. A new `GameRoute` case
2. A new `GameDescriptor` entry in `GameDescriptor.all`
3. A new branch in the `destination(for:)` switch

The v1.4 "home-screen overhaul" already shipped (phases 14+). The current architecture uses `GameDescriptor.all` (a static array) and `GameRoute` (a typed enum) — exactly the intended extensibility seam. No structural changes to `HomeView` itself are needed; only additive file edits.

### Specific additive changes

**`Core/GameRoute.swift`** — add two cases (no associated value — endless games have one mode):

```swift
case stack
case snake
```

`GameRoute` is `Hashable + Sendable` and Foundation-only. Adding cases here is additive and safe.

**`Core/GameDescriptor.swift`** — add `AccentRole.slot9` and `.slot10`, then two entries to `.all`:

Currently 8 slots are defined (`slot1` through `slot8`) and all 8 are consumed by the existing games. Stack and Snake need two new slots. Adding slot9 and slot10 to the `AccentRole` enum is a two-line additive change.

```swift
// in AccentRole enum:
case slot9   // Stack
case slot10  // Snake

// in .all array (appended):
GameDescriptor(
    kind: .stack,
    titleKey: "Stack",
    captionKey: "Tap to play",
    symbol: "square.stack.fill",
    accent: .slot9,
    route: .stack,
    modes: [],          // endless = no mode chips; tap the tile directly launches
    shortMeta: "Endless tower"
),
GameDescriptor(
    kind: .snake,
    titleKey: "Snake",
    captionKey: "Tap to play",
    symbol: "arrow.triangle.turn.up.right.diamond",
    accent: .slot10,
    route: .snake,
    modes: [],
    shortMeta: "Endless grid"
)
```

`modes: []` means tapping the tile in the home drawer launches the game directly with no mode-chip sub-menu — same shape as a single-mode game. The `GameModeChip` path is for games with difficulty tiers; Stack and Snake have none.

**`Core/GameKind+AccentColor.swift`** — add two brand colors:

```swift
case .stack: return Color(red: 0.961, green: 0.498, blue: 0.122) // vivid orange
case .snake: return Color(red: 0.176, green: 0.741, blue: 0.490) // calm green
```

Exact hex values are a design decision for later; the file follows the same raw-Color pattern already used for all eight existing games.

**`Screens/HomeView.swift` — `destination(for:)` switch** — add two cases:

```swift
case .stack:
    StackGameView()
        .disableInteractivePop()
case .snake:
    SnakeGameView()
        .disableInteractivePop()
```

Note the deliberate absence of `.videoModeAware(minBoardHeight:)`. Stack and Snake are Video Mode exempt for v1.5 (per PROJECT.md: "real-time continuous input can't pause-and-reflow for PiP"). If Video Mode is added in a later milestone, the call site is the insertion point.

---

## 5. Settings and Feedback Integration

### SettingsStore is unchanged

`SettingsStore` already exposes every toggle these games need:
- `hapticsEnabled` — gate haptic feedback (already default `true`)
- `sfxEnabled` — gate SFX (already default `false`)
- `animationsEnabled` — gate choreography (already default `true`)

No new flags are needed. The existing EnvironmentKey injection pattern (`@Environment(\.settingsStore)`) is the consumption surface.

### How the game view wires feedback (counter-trigger pattern)

Matching the established haptic pattern from `MinesweeperViewModel` (lines 116-133) and `MergeViewModel` (lines 32-38):

```swift
// In StackViewModel (per-game):
private(set) var scoreCount: Int = 0     // bumped when block lands successfully
private(set) var gameOverCount: Int = 0  // bumped on game over

// In StackGameView (per-game):
boardView
    .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: vm.scoreCount)
    .sensoryFeedback(.error, trigger: vm.gameOverCount)
```

The VM bumps the counter; SwiftUI's `.sensoryFeedback(trigger:)` fires on value-change. This is the same counter-trigger approach used by `revealCount`, `flagToggleCount`, `mergeCount`, and `terminalCount` in the existing VMs.

The "haptics gated on `hapticsEnabled`" rule is satisfied by the existing `.sensoryFeedback` modifier — if `hapticsEnabled` is false, wrap the trigger in a guard (set to 0), same pattern as `VideoModeBanner.swift` line 129: `trigger: hapticsEnabled ? hapticTrigger : 0`.

### Reduce Motion path

These are the first motion-heavy games in the suite. Two categories of motion to gate:

1. **Board animations** (speed-ramp visual effects, parallax, screen shake on Snake wall-hit): gate on `settingsStore.animationsEnabled && !reduceMotion`. When false, show immediate static state change.

2. **End-state banner transition**: already handled by `VideoModeBanner` which accepts `animationsEnabled` and `reduceMotion` as plain Bools and collapses its `.opacity` transition to `.identity` when either is off.

The VM reads neither `animationsEnabled` nor `reduceMotion` directly — those stay in the View tier. The VM publishes trigger counters; the View decides whether to animate them. This is the established "animation is the View's job" invariant from `MinesweeperViewModel.swift` lines 96-108.

### Loop pause on scene-phase background

The game view observes `@Environment(\.scenePhase)` and calls `vm.pause()` / `vm.resume()`, exactly as `MinesweeperGameView` calls `vm.pause()` / `vm.resume()` in the Timer extension. The `ArcadeLoopDriver` modifier automatically stops firing `onTick` when `isRunning` is false (it checks `state == .running` before passing the VM's live state to the driver).

### End-state banner

Reuse `VideoModeBanner` from `Core/` as-is. For endless games, `outcome` is always `.loss` (game over). The banner title is "Game Over", subtitle shows the score, primary CTA is "Play Again". `VideoModeBannerContent` already supports arbitrary titles and subtitles. No new banner component is needed.

---

## 6. Build Order and Phase Decomposition

### Phase 1 — Substrate + Skeleton (blocks nothing, no gameplay yet)

Files:
- NEW: `Core/ArcadeGameState.swift`
- NEW: `Core/ArcadeLoopDriver.swift`
- MODIFIED: `Core/GameKind.swift` (+2 cases)
- MODIFIED: `Core/GameRoute.swift` (+2 cases)
- MODIFIED: `Core/GameDescriptor.swift` (+AccentRole slots, +2 stub entries pointing at placeholder views)
- MODIFIED: `Core/GameKind+AccentColor.swift` (+2 color cases)
- MODIFIED: `Screens/HomeView.swift` (+2 destination stubs returning placeholder Text views)

Deliverable: App compiles. Stack and Snake tiles appear on Home (tapping shows "Coming soon" placeholder). `ArcadeLoopDriver` has a unit test confirming `onTick` fires when `isRunning == true` and doesn't fire when false.

No gameplay. No stats. No save state. Purely the wiring harness.

### Phase 2 — Stack (proves the substrate end-to-end)

Files:
- NEW: `Games/Stack/Engine/StackEngine.swift`
- NEW: `Games/Stack/Engine/StackBoard.swift`
- NEW: `Games/Stack/StackGameState.swift` (if needed — or just use `ArcadeGameState` directly)
- NEW: `Games/Stack/StackViewModel.swift`
- NEW: `Games/Stack/StackGameView.swift`
- NEW: `Games/Stack/StackBoardView.swift`
- NEW: `Games/Stack/StackSaveState.swift`
- NEW: `Games/Stack/StackScoreChip.swift`
- NEW: `Games/Stack/StackStatsCard.swift`
- MODIFIED: `Screens/StatsView.swift` (+Stack @Query pair, +Stack stats section)
- MODIFIED: `Screens/HomeView.swift` (replace Stack placeholder with `StackGameView()`)
- MODIFIED: `Core/GameStats.swift` (resetAll adds `StackSaveState.clearAll()`)

Deliverable: Stack is fully playable through HomeView. Score persists to BestScore. Stats screen shows Stack high score. Engine has unit tests (drop/overhang/game-over, including edge cases: perfect placement, single-cell tower collapse).

### Phase 3 — Snake (confirms substrate reuse, no new Core/ changes)

Files:
- NEW: `Games/Snake/Engine/SnakeEngine.swift`
- NEW: `Games/Snake/Engine/SnakeBoard.swift`
- NEW: `Games/Snake/SnakeViewModel.swift`
- NEW: `Games/Snake/SnakeGameView.swift`
- NEW: `Games/Snake/SnakeBoardView.swift`
- NEW: `Games/Snake/SnakeSaveState.swift`
- NEW: `Games/Snake/SnakeStatsCard.swift`
- MODIFIED: `Screens/StatsView.swift` (+Snake @Query pair, +Snake stats section)
- MODIFIED: `Screens/HomeView.swift` (replace Snake placeholder with `SnakeGameView()`)
- MODIFIED: `Core/GameStats.swift` (resetAll adds `SnakeSaveState.clearAll()`)

Snake consumes `ArcadeGameState` and `ArcadeLoopDriver` from Core/ without modification — confirming genuine reuse.

Deliverable: Snake fully playable. Stats screen shows Snake high score. Engine has unit tests (grow, self-collision, wall rule, fixed-timestep accumulator behavior).

### Phase 4 — Polish

- Theme audit: Classic (Chrome Diner) + at least one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 and DESIGN.md §12.5. Every cell/block/score chip must be legible on both.
- Haptic vocabulary audit: confirm `scoreCount` fires `.light(0.7)` (normal move) and `gameOverCount` fires `.error` (wrong move / death) per DESIGN.md §8.2.
- Reduce Motion path: verify immediate-cut behavior when `settingsStore.animationsEnabled == false` or `accessibilityReduceMotion == true`.
- Accessibility: `.accessibilityLabel` on score chip, board (combined element with score/state), back button (`"Back to The Drawer"`), restart button (`"Restart game"`).
- Save-state round-trip: verify force-quit mid-game restores correctly (both engines are Codable structs → straightforward JSON round-trip via UserDefaults, same pattern as `MergeSaveState`).

---

## 7. NEW vs MODIFIED — Explicit Scope Table

| File | Status | Change |
|------|--------|--------|
| `Core/ArcadeGameState.swift` | **NEW** | 4-case lifecycle enum; Foundation-only |
| `Core/ArcadeLoopDriver.swift` | **NEW** | ViewModifier + extension; ~60 lines |
| `Games/Stack/Engine/StackEngine.swift` | **NEW** | Pure engine struct; unit tested |
| `Games/Stack/Engine/StackBoard.swift` | **NEW** | Pure model; Codable |
| `Games/Stack/StackViewModel.swift` | **NEW** | @Observable @MainActor; ~200 lines |
| `Games/Stack/StackGameView.swift` | **NEW** | SwiftUI game screen; ~200 lines |
| `Games/Stack/StackBoardView.swift` | **NEW** | Board rendering; ~150 lines |
| `Games/Stack/StackSaveState.swift` | **NEW** | Codable; UserDefaults JSON |
| `Games/Stack/StackScoreChip.swift` | **NEW** | Info chip following §3.3 spec |
| `Games/Stack/StackStatsCard.swift` | **NEW** | Props-only card; no @Query |
| `Games/Snake/Engine/SnakeEngine.swift` | **NEW** | Pure engine; fixed-timestep accumulator |
| `Games/Snake/Engine/SnakeBoard.swift` | **NEW** | Pure model; Codable |
| `Games/Snake/SnakeViewModel.swift` | **NEW** | @Observable @MainActor; ~200 lines |
| `Games/Snake/SnakeGameView.swift` | **NEW** | SwiftUI game screen |
| `Games/Snake/SnakeBoardView.swift` | **NEW** | Grid rendering |
| `Games/Snake/SnakeSaveState.swift` | **NEW** | Codable; UserDefaults JSON |
| `Games/Snake/SnakeStatsCard.swift` | **NEW** | Props-only card; no @Query |
| `Core/GameKind.swift` | **MODIFIED** | +2 cases (`.stack`, `.snake`); additive |
| `Core/GameRoute.swift` | **MODIFIED** | +2 cases (`.stack`, `.snake`); additive |
| `Core/GameDescriptor.swift` | **MODIFIED** | +AccentRole.slot9/slot10; +2 entries to `.all` |
| `Core/GameKind+AccentColor.swift` | **MODIFIED** | +2 color cases |
| `Core/GameStats.swift` | **MODIFIED** | `resetAll()` +2 `clearAll()` lines only |
| `Screens/HomeView.swift` | **MODIFIED** | `destination(for:)` switch +2 cases only |
| `Screens/StatsView.swift` | **MODIFIED** | +2 `@Query` pairs; +2 `if shows()` sections |

**No other files are touched.** `VideoModeBanner`, `VideoModeAware`, `BestScore`, `BestTime`, `GameRecord`, `SettingsStore`, `Haptics`, `SFXPlayer`, and all existing game files are unchanged.

---

## 8. System Diagram — v1.5 Addition to Existing Architecture

```
Core/                              Core/ (EXISTING, unchanged)
  ArcadeGameState.swift  ◄─────┐    GameStats.swift
  ArcadeLoopDriver.swift ◄───┐ │    BestScore.swift
                             │ │    VideoModeBanner.swift
                             │ │
Games/Stack/                 │ │  Games/Snake/
  Engine/StackEngine.swift   │ │    Engine/SnakeEngine.swift
  StackViewModel.swift ──────┘ │    SnakeViewModel.swift ──┘
    owns StackEngine             │      owns SnakeEngine
    state: ArcadeGameState       │      state: ArcadeGameState
    calls gameStats.record() ───►│      calls gameStats.record()
                                 │
  StackGameView.swift            │  SnakeGameView.swift
    .arcadeLoop(isRunning:       │    .arcadeLoop(isRunning:
               onTick: vm.tick)  │               onTick: vm.tick)
    reads settingsStore ──────►  │    reads settingsStore
    shows VideoModeBanner        │    shows VideoModeBanner

Screens/HomeView.swift (MODIFIED — 2 new destination cases only)
Screens/StatsView.swift (MODIFIED — 2 new @Query pairs + sections)
Core/GameKind.swift (MODIFIED — +2 cases)
Core/GameRoute.swift (MODIFIED — +2 cases)
Core/GameDescriptor.swift (MODIFIED — +2 AccentRole slots, +2 entries)
Core/GameKind+AccentColor.swift (MODIFIED — +2 color cases)
```

---

## 9. Key Invariants to Carry Forward

**Engine purity:** `StackEngine` and `SnakeEngine` must have zero SwiftUI imports and zero SwiftData imports. The isolation test in `MinesweeperViewModel.swift` line 14 documents this explicitly as a structural invariant; apply the same to the arcade engines.

**File size cap:** Per CLAUDE.md §8.1/§8.5, view files ≤400 lines, Swift files ≤500 lines. The VM is likely to approach this limit for complex games; split into `StackViewModel+SaveState.swift` and `StackViewModel+Persistence.swift` following the existing Minesweeper split (4 files for one VM).

**Counter-trigger, not Bool-toggle:** Every haptic and animation trigger uses an incrementing `Int` counter, not a `Bool`. This is established across all existing VMs (DESIGN.md §8.2 "The trigger is always an incrementing view-model counter"). Enforce from day one on arcade VMs.

**No new SwiftData models:** `BestScore` is the high-score store. `GameRecord.score` carries the per-run score. Adding `.stack` and `.snake` GameKind cases is the only schema-visible change, and it is additive (no migration, no CloudKit schema change).

**synchronized-root-group:** Per CLAUDE.md §8.8, dropping `.swift` files into `Games/Stack/` and `Games/Snake/` is sufficient for Xcode 16 to pick them up (objectVersion 77, PBXFileSystemSynchronizedRootGroup). Do not hand-edit `project.pbxproj` for files in these new folders. A new top-level folder under `Games/` does require a one-time `project.pbxproj` edit to add the folder group itself — the files inside it are then auto-registered.

**Video Mode exempt:** Stack and Snake do not receive `.videoModeAware(minBoardHeight:)` wrapping in `HomeView.destination(for:)`. No `+VideoMode.swift` extension files for these games in v1.5. The exemption rationale (continuous input cannot pause-and-reflow) should be noted in an ADR if the decision is made to keep this permanent.

---

## Sources

All claims are verified against files read directly from the repository (2026-06-25):

- `gamekit/gamekit/Core/ArcadeGameState` — does not yet exist (confirmed by directory listing)
- `gamekit/gamekit/Core/BestScore.swift` — exists; `BestScore` model confirmed; `GameStats.evaluateBestScore()` confirmed
- `gamekit/gamekit/Core/GameStats.swift` — `record(gameKind:mode:outcome:score:)` overload confirmed at line 113
- `gamekit/gamekit/Core/GameKind.swift` — 8 existing cases confirmed; `.stack`/`.snake` not yet present
- `gamekit/gamekit/Core/GameRoute.swift` — 8 existing cases confirmed
- `gamekit/gamekit/Core/GameDescriptor.swift` — `AccentRole` slots 1-8 confirmed; `.all` array has 8 entries
- `gamekit/gamekit/Core/GameKind+AccentColor.swift` — 8 color cases confirmed
- `gamekit/gamekit/Core/SettingsStore.swift` — `hapticsEnabled`, `sfxEnabled`, `animationsEnabled` confirmed
- `gamekit/gamekit/Core/VideoModeBanner.swift` — reusable banner pattern confirmed; takes `outcome: Outcome`
- `gamekit/gamekit/Core/VideoModeAware.swift` — ViewModifier pattern confirmed; adoption syntax validated
- `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` — counter-trigger pattern confirmed; Foundation-only invariant confirmed
- `gamekit/gamekit/Games/Merge/MergeViewModel.swift` — score-based record path confirmed; `recordTerminal()` shape confirmed
- `gamekit/gamekit/Screens/HomeView.swift` — `destination(for:)` switch confirmed; `.videoModeAware()` call sites confirmed
- `gamekit/gamekit/Screens/StatsView.swift` — `@Query` pair + `if shows()` pattern confirmed for each game
- `DESIGN.md` §8, §10 — haptic vocabulary and animation rules confirmed
- `CLAUDE.md` §4, §8 — engine purity rule, promotion rule, file size caps confirmed
- `.planning/PROJECT.md` — Video Mode exempt status confirmed; fixed-timestep recommendation confirmed
- `.planning/v1.5-BRIEF.md` — scope, out-of-scope, open decisions confirmed
