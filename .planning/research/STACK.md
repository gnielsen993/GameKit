# Stack Research — GameKit v1.5 Real-Time Game Loop

**Domain:** Real-time endless arcade games (Stack, Snake) added to an existing SwiftUI/Swift 6/DesignKit logic-game suite.
**Researched:** 2026-06-25
**Scope:** Additive stack decisions only. The existing stack (Swift 6, SwiftUI, SwiftData, DesignKit, CloudKit) is proven in production and is NOT re-researched here. This document covers only what v1.5 adds: a real-time frame loop, geometric Canvas rendering, real-time input handling, loop lifecycle management, and high-score persistence hookup.
**Overall confidence:** HIGH on frame driver, engine pattern, rendering choice, and persistence; MEDIUM on the Canvas/LazyVGrid tradeoff for Snake (either works; the distinction matters less than the engine design).

---

## TL;DR Decision Wall

| Concern | Decision | Confidence |
|---|---|---|
| Frame driver | `TimelineView(.animation(minimumInterval: nil, paused: isLoopPaused))` | HIGH |
| Engine tick contract | Pure `mutating func step(dt: Double, input: Input)` on a value-type engine; view model owns the fixed-timestep accumulator | HIGH |
| Fixed dt value | `1.0/60.0` (60 Hz sim) for both Stack and Snake | HIGH |
| Renderer — Stack | SwiftUI `Canvas` inside `TimelineView` | HIGH |
| Renderer — Snake | `LazyVGrid` of colored squares (matches board-game pattern in this codebase) | MEDIUM |
| SpriteKit? | No — overkill, bypasses DesignKit tokens, adds cognitive dependency | HIGH |
| DesignKit token feed into Canvas | Capture `theme` in closure scope; pass `theme.colors.X` (SwiftUI `Color`) to `GraphicsContext.Shading.color(_:)` | HIGH |
| Input — Stack | `.onTapGesture` sets `viewModel.pendingDrop = true`; consumed and cleared each engine tick | HIGH |
| Input — Snake | `DragGesture(minimumDistance: 20).onEnded` enqueues to `directionQueue: [Direction]` (capacity 2); one dequeued per engine tick | HIGH |
| Pausing on background | `.onChange(of: scenePhase)` — `.background` → pause loop, `.active` → resume; `.inactive` no-op. Same pattern as all existing games. | HIGH |
| Loop pause surface | `paused:` parameter on `TimelineView(.animation(paused:))` — declarative, no timer cancellation needed | HIGH |
| High-score persistence | Extend `GameKind` with `.stack` / `.snake`; reuse existing `BestScore` + `GameStats.record(gameKind:mode:outcome:score:)` unchanged | HIGH |
| Schema safety | `GameKind` enum additions are additive (no CloudKit constraint impact). `BestScore` / `GameRecord` models need no new fields. | HIGH |

---

## 1. Frame Driver — `TimelineView(.animation(paused:))`

### Decision

Use `TimelineView(.animation(minimumInterval: nil, paused: isLoopPaused))` as the frame driver. The `paused:` parameter gates the loop declaratively from view model state; no run-loop object to manage.

### Why not the alternatives

**CADisplayLink:**
CADisplayLink is the traditional UIKit display-sync tool and does fire at the actual screen refresh rate. However in a Swift 6 strict-concurrency codebase it has a concrete problem: `CADisplayLink` is not `Sendable`. Under Swift 6's complete concurrency checking you will get "cannot access property 'displayLink' with a non-sendable type 'CADisplayLink?' from non-isolated context" in `deinit` and similar isolation errors. Working around this requires an explicit `@MainActor`-isolated wrapper class with careful `add(to:forMode:)` / `invalidate()` lifecycle, `#selector` bridging, and a separate stored property for the link. That is non-trivial boilerplate for no tangible gameplay benefit in these two games.

`CADisplayLink.preferredFrameRateRange` is the one thing CADisplayLink offers that `TimelineView` cannot express (a minimum-frame-rate floor for ProMotion throttling). Stack and Snake are simple enough that losing frames below 60Hz is a non-issue — neither relies on sub-frame interpolation. Promote to CADisplayLink only if a future game needs a guaranteed per-frame floor (e.g., a rhythm game where a dropped frame breaks a beat).

**Combine `Timer.publish` / `Timer.scheduledTimer`:**
Not screen-synchronized. Fires at fixed wall-clock intervals regardless of when the display actually repaints. The result is tearing and jitter visible as inconsistent delta times. Community-observed Snake implementations use this approach (because it is simple), but `Timer`-based loops are consistently the wrong approach for anything the player sees moving smoothly. Reject.

**Swift Concurrency `AsyncTimerSequence`:**
Not screen-synchronized. Off-main-thread by default; requires actor hops for every UI mutation. No ProMotion adaptivity. Produces the same jitter problem as `Timer`. Reject.

### TimelineView behavior: what it gives you

**ProMotion adaptivity (60/120Hz):** `TimelineView(.animation)` fires callbacks at the display's current refresh rate. On iPhone 15 Pro with ProMotion, that's up to 120Hz during active animation. The view automatically receives entries at 120Hz without any configuration. `minimumInterval: nil` allows the system to choose the fastest rate; passing a non-nil value (e.g. `1.0/60.0`) tells the system "don't go faster than this" — useful if you want to run the view loop at 60Hz even on 120Hz devices to save battery, but for v1.5 leave it `nil` and let ProMotion do its job.

**Background behavior:** When the app goes to background, `TimelineView` automatically stops delivering entries. You do NOT need to pass `paused: true` to kill the loop on background — the system stops it. However, the game's *state* still thinks it is running (the view model's lifecycle is still `.running`) until you explicitly pause it via `.onChange(of: scenePhase)`. The `paused:` parameter is for intentional in-game pausing (game-over banner, tap-to-start idle screen, manual pause); the `.onChange(of: scenePhase)` handler is for automatic OS-driven pausing.

**Cadence:** The context provides `context.cadence` which can be `.live`, `.seconds`, or `.minutes`. For a running game loop, cadence will always be `.live`. Use this signal only if you want to hide detail on a watch or low-power device — not relevant for iPhone gameplay.

**Battery:** `TimelineView(.animation)` does not spin when `paused: true`. It also does not spin when the view is off-screen or the app is backgrounded. There is no timer object to leak if you forget to cancel it. Safer than `CADisplayLink` where forgetting `invalidate()` in `deinit` causes a retain cycle.

### Confirmed API (iOS 15+, available on iOS 17+ baseline)

```swift
// Core7 verified:
static func animation(
    minimumInterval: Double? = nil,
    paused: Bool = false
) -> AnimationTimelineSchedule
```

The `paused: Bool` parameter stops entries from being generated at all — not just reduced frequency. This is the correct lever for pause/game-over/idle states.

---

## 2. Engine Pattern — Fixed-Timestep Accumulator

### Decision

The VIEW LAYER owns the variable-rate tick. The VIEW MODEL owns the accumulator and dispatches fixed-step ticks. The ENGINE receives only fixed `dt` values and pure `Input`.

### Why fixed timestep

Snake and Stack must behave identically at 60Hz and 120Hz. Without a fixed timestep:
- At 120Hz, Snake moves at 2× speed compared to 60Hz (each step covers one grid cell, twice as many steps per second)
- Stack's sliding block covers 2× distance per second at 120Hz

Fixed-timestep decouples the simulation rate from the render rate. The simulation always runs at 60Hz (`fixedDt = 1.0/60.0`) regardless of ProMotion frame rate. The render rate can be 60 or 120Hz without changing game physics.

### Architecture

```
TimelineView(.animation(paused: vm.isLoopPaused))  ← view layer, variable dt
     ↓  context.date
ViewModel.tick(now: Date)                            ← MainActor, accumulator
     ↓  fixedDt ticks
Engine.step(dt: fixedDt, input: Input) -> Frame     ← pure value type, deterministic
```

**View model (MainActor):**

```swift
@Observable @MainActor
final class StackViewModel {
    private(set) var engine = StackEngine()
    private(set) var lifecycle: ArcadeLifecycle = .idle
    var pendingDrop = false

    private var accumulator: Double = 0
    private var lastTickDate: Date? = nil
    private let fixedDt: Double = 1.0 / 60.0

    func tick(now: Date) {
        guard lifecycle == .running else { return }
        guard let last = lastTickDate else { lastTickDate = now; return }
        let wallDt = min(now.timeIntervalSince(last), 0.1)  // cap at 100ms to prevent spiral-of-death
        lastTickDate = now
        accumulator += wallDt
        while accumulator >= fixedDt {
            let input = Input(drop: pendingDrop)
            pendingDrop = false
            let frame = engine.step(dt: fixedDt, input: input)
            if frame.gameOver { transition(to: .gameOver) }
            accumulator -= fixedDt
        }
    }
}
```

**Engine (pure value type, no SwiftUI, no Foundation async):**

```swift
struct StackEngine {
    // All state here — pure value semantics
    mutating func step(dt: Double, input: Input) -> Frame {
        // deterministic physics tick
    }
}

struct SnakeEngine {
    mutating func step(dt: Double, input: Input) -> Frame {
        // deterministic grid tick
    }
}
```

**Key design notes:**
- `wallDt` is capped at 100ms (`min(..., 0.1)`) to prevent the "spiral of death" — if the app was backgrounded for 30 seconds and the accumulator gets fed 30 seconds of dt on resume, the engine would run thousands of ticks before the first frame paints. Cap it.
- `lastTickDate = nil` on pause/resume so the first tick after resume starts fresh.
- No interpolation is needed for Snake (grid-snaps are instant) or Stack (block drop is instantaneous; only block sliding needs interpolation, which is handled in the view layer as a visual-only transition, not engine state).
- The engine's `Frame` type is a simple value struct carrying the view state needed for the next render — no SwiftUI imports.

### Testability

Because the engine is a pure value type with `step(dt:input:)`:

```swift
@Test func snakeGrowsOnFoodCollect() {
    var engine = SnakeEngine(seed: 42)
    let _ = engine.step(dt: 1.0/60.0, input: .noInput)
    // advance to food position, confirm length increase
    #expect(engine.snakeLength == 2)
}
```

The engine is as deterministic and testable as `BoardGenerator` or `RevealEngine`. Tests replay exact (dt, input) streams. This mirrors the project's existing engine-purity pattern exactly.

---

## 3. Rendering — Canvas (Stack) and LazyVGrid (Snake)

### Stack: SwiftUI Canvas

Stack's board is continuous-coordinate (the block slides across a fractional x position, the overhang is a sub-pixel trim operation). It is NOT a grid. Canvas is the correct renderer because:

- The coordinate space is a real-valued rectangle, not a discrete cell grid.
- The number of drawable objects per frame is small (≤ 20 tower layers + 1 sliding block). Canvas draw calls are cheap at this scale.
- No per-block tapping or accessibility affordance is needed during play — the only interaction is a full-board tap.
- Canvas naturally handles sub-pixel widths for overhang shaving.

**DesignKit token integration into Canvas:**

DesignKit tokens are SwiftUI `Color` values. `Canvas`'s `GraphicsContext` accepts them directly via `GraphicsContext.Shading.color(_:)`. The closure captures `theme` from the enclosing view scope:

```swift
// Confirmed via Apple docs: GraphicsContext.Shading.color(_ color: Color) is valid
// 'theme' is captured from the enclosing view's @Environment or parent let binding

Canvas { ctx, size in
    // current block (sliding)
    let blockRect = CGRect(...)
    ctx.fill(Path(blockRect), with: .color(theme.colors.accentPrimary))

    // tower layers
    for layer in engine.tower {
        ctx.fill(Path(layer.rect), with: .color(theme.colors.surface))
    }

    // danger zone highlight when very narrow
    if engine.towerWidth < dangerThreshold {
        ctx.fill(Path(dangerRect), with: .color(theme.colors.danger.opacity(0.2)))
    }
}
```

All color decisions use semantic DesignKit tokens — the Canvas renderer is as theme-correct as any other game view. The `GraphicsContext` has an `environment` property that exposes the SwiftUI environment, but in practice it is simpler and cleaner to capture `theme` in the closure scope rather than reading from `context.environment` (the latter requires resolving `EnvironmentKey` types, not just `Color` values).

**Confidence:** HIGH. `GraphicsContext.Shading.color(_:)` takes a `SwiftUI.Color`, which is exactly what DesignKit tokens are. Verified in Context7 Apple docs.

### Snake: LazyVGrid

Snake is grid-based. Its board state is `[Position: CellKind]` where CellKind is `.snake / .food / .empty`. This maps naturally to the existing board-game pattern:

```swift
LazyVGrid(columns: columns, spacing: 0) {
    ForEach(cells) { cell in
        Rectangle()
            .fill(colorForCell(cell, theme: theme))
            .aspectRatio(1, contentMode: .fit)
    }
}
```

This is the exact pattern used by Minesweeper, Nonogram, and Sudoku. It is proven, accessible (VoiceOver can read cell states if needed), and does not require any new rendering infrastructure.

Alternative: Canvas for Snake is also valid and slightly more efficient (avoids N^2 view objects for a 20x20 grid = 400 views). Choose Canvas if performance profiling reveals issues; default to LazyVGrid for consistency with existing board games.

**Decision: LazyVGrid for Snake, Canvas for Stack.** This gives Snake zero new rendering patterns to learn, and gives Stack the coordinate-space control it needs for continuous sliding.

### Why not SpriteKit

SpriteKit requires `SpriteView` to embed in SwiftUI. `SpriteView` renders in a `SKView` underneath the SwiftUI layer, which means:

- DesignKit's `Color` tokens cannot reach `SKNode` children — SpriteKit uses `UIColor`, not SwiftUI `Color`. Every theme change would require a `UIColor` extraction step and manual propagation to scene nodes.
- Theme-switching at runtime would require rebuilding or re-tinting the entire scene graph.
- PhysicsBody / SKActions / SKEmitterNode are irrelevant for Stack (custom pure math) and Snake (grid logic).
- Adds a second rendering stack (Metal-backed SpriteKit + SwiftUI) to what is currently a pure SwiftUI app.
- No performance benefit: Stack's 20 rectangles and Snake's 400 grid cells are trivial for Canvas or LazyVGrid.

SpriteKit is the right tool for physics simulations, particle-heavy effects, or tile-map games. It is overkill here and actively harmful to the DesignKit theming requirement.

---

## 4. Input Handling

### Stack — tap-to-drop

```swift
// In StackGameView:
.onTapGesture {
    viewModel.pendingDrop = true
}
```

`pendingDrop` is a Bool on the `@MainActor` view model. The engine tick reads and clears it:

```swift
let input = Input(drop: pendingDrop)
pendingDrop = false  // cleared after consumption, before step
```

If the player taps multiple times before the engine processes a tick (happens at 120Hz where 2 view redraws may precede 1 engine tick): only one drop fires per tick. That is correct Stack behavior — one drop per tap intent, not per rendered frame.

### Snake — swipe-to-turn

```swift
// In SnakeGameView:
.gesture(
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            let dx = value.translation.width
            let dy = value.translation.height
            let dir: Direction = abs(dx) > abs(dy)
                ? (dx > 0 ? .right : .left)
                : (dy > 0 ? .down : .up)
            viewModel.enqueueDirection(dir)
        }
)
```

The view model holds a small direction queue:

```swift
private var directionQueue: [Direction] = []  // max capacity 2

func enqueueDirection(_ dir: Direction) {
    // Ignore if it reverses current movement (can't go back on yourself)
    guard !dir.isOpposite(to: engine.currentDirection) else { return }
    if directionQueue.count < 2 {
        directionQueue.append(dir)
    }
}
```

Each engine tick dequeues one direction:

```swift
let pendingDir = directionQueue.isEmpty ? nil : directionQueue.removeFirst()
let input = Input(direction: pendingDir)
engine.step(dt: fixedDt, input: input)
```

**Why a queue (not just a single pending value):**
A player turning right then immediately up before the next engine tick would lose the "up" if there's only one slot. The queue (capacity 2) preserves recent intent without going deeper than needed.

**Alternative: 4 directional buttons.** Valid for accessibility and avoids swipe-detection ambiguity. V1.5 should ship BOTH: swipe gesture primary, directional button row as a secondary control row (per DESIGN.md §5.1 `numberPadOrControls` slot). Some players cannot swipe comfortably.

### Input isolation (Swift 6)

Both `pendingDrop` and `directionQueue` live on the `@MainActor` view model. Gesture callbacks run on the main actor by default in SwiftUI. No cross-actor access. No `Sendable` concerns. The pattern is identical to how existing view models receive user events.

---

## 5. Lifecycle and Pausing

### ArcadeLifecycle enum (new, in Core/)

```swift
enum ArcadeLifecycle: Equatable {
    case idle         // tap-to-start affordance shown
    case running      // loop active, engine ticking
    case paused       // user-paused or scene backgrounded
    case gameOver     // terminal, score shown
}
```

This enum lives in `Core/` and is shared by both Stack and Snake. It is the analog of `MinesweeperGameState` for real-time games.

### TimelineView pausing

```swift
TimelineView(.animation(paused: viewModel.lifecycle != .running)) { context in
    // game board
}
```

When `lifecycle != .running`, no entries are generated. CPU cost is zero. No timer to cancel, no `invalidate()` to call.

### ScenePhase integration

Identical to every existing game — verbatim copy of the existing `.onChange(of: scenePhase)` pattern:

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        viewModel.pauseForBackground()  // saves lastTickDate = nil, sets lifecycle = .paused
    case .active:
        viewModel.resumeFromBackground()  // restores lifecycle = .running if was running
    case .inactive:
        break  // no-op: control-center pulls, lock-screen flashes are transient
    @unknown default:
        break
    }
}
```

**Background pause stores the pre-pause lifecycle** so `resumeFromBackground()` only resumes if the game was actively running (not idle or game-over):

```swift
func pauseForBackground() {
    guard lifecycle == .running else { return }
    lifecycleBeforeBackground = .running
    lifecycle = .paused
    lastTickDate = nil      // reset accumulator anchor — prevents spiral-of-death on resume
}

func resumeFromBackground() {
    guard lifecycleBeforeBackground == .running else { return }
    lifecycleBeforeBackground = nil
    lifecycle = .running
}
```

### Game-over banner pause

When the engine returns `frame.gameOver == true`:

```swift
lifecycle = .gameOver  // TimelineView pauses immediately (paused: lifecycle != .running)
// After delay (500ms per DESIGN.md §10.3), show VideoModeBanner
```

No special timer manipulation. The existing `VideoModeBanner` (DESIGN.md §3.6) is the end-state surface.

---

## 6. High-Score Persistence

### Schema changes required

**GameKind enum** — add two cases (additive, CloudKit-safe, no schemaVersion bump at the model layer):

```swift
enum GameKind: String, Codable, Sendable, CaseIterable {
    // existing cases...
    case stack   // rawValue = "stack"
    case snake   // rawValue = "snake"
}
```

Raw values are the stable serialization key. "stack" and "snake" are correct — never abbreviate or change.

**BestScore model** — no changes. Already accommodates score-based games with CloudKit-safe schema.

**GameRecord model** — no changes. `score: Int?` already exists. Duration (`durationSeconds`) stores `0` for endless games (no run time tracked, just final score).

**JSON export envelope** — bump `schemaVersion` from 2 to 3 at the envelope level to signal the new game kinds in imports. The model layer stays at SwiftData lightweight migration (additive case additions to an enum stored as `String` require no migration).

### Write path

For both games, use the existing score overload of `GameStats.record`:

```swift
// In StackViewModel / SnakeViewModel, on game over:
try gameStats?.record(
    gameKind: .stack,          // or .snake
    mode: "endless",           // difficultyRaw — no difficulty presets for endless games
    outcome: .loss,            // always loss in endless (score-until-death)
    score: engine.score
)
```

`BestScore` is automatically evaluated inside `GameStats.record` via `evaluateBestScore` — "higher only" semantics, CloudKit-safe, explicitly saved before returning.

### Stats screen shape

Endless games show a different stats layout than win/loss games. Per the brief's open question on stats shape:

- **High score** (from `BestScore`)
- **Games played** (count of `GameRecord` rows for this `gameKindRaw`)
- NO best time (not applicable)
- NO win/loss ratio (endless games always end in "loss")

The Stats screen adapts to show the `BestScore` view instead of a BestTime view for `.stack` and `.snake` game kinds. This is a view-layer concern — the schema supports it already.

---

## 7. Core/ Substrate — What Goes There

Two new files in `Core/` that are shared by both Stack and Snake (and any future arcade games):

| File | Contents |
|------|----------|
| `Core/ArcadeLifecycle.swift` | `ArcadeLifecycle` enum (idle / running / paused / gameOver) |
| `Core/ArcadeGameInput.swift` | `ArcadeGameInput` struct (pendingDrop: Bool, pendingDirection: Direction?) — or keep this per-game since Stack/Snake input shapes differ |

Everything else stays in `Games/Stack/` or `Games/Snake/`. Do not over-abstract. Two games is not enough to justify a `GameLoopHost` generic view or an `ArcadeViewModel` base class — that would be speculative architecture.

---

## 8. What Does NOT Change or Go Into DesignKit

| Item | Status |
|------|--------|
| `TimelineView` for timer display | Already in `Core/VideoModeTimerChip.swift` — the existing periodic timer chip is NOT the game loop driver; they are different uses of `TimelineView` |
| DesignKit tokens | No new tokens needed. Stack uses existing `accentPrimary`, `surface`, `danger`, `background`. Snake uses `success` (food), `accentPrimary` (snake body), `danger` (self-collision flash). |
| DesignKit components | No new components. Score display uses the existing generic Info Chip (§3.3). High-score display uses same chip with different label. |
| DKHaptics | Existing haptic vocabulary covers all arcade events: `.impact(.medium)` for block drop / food eat; `.error` for game over. No new patterns that warrant DesignKit promotion until 3+ arcade games share them. |
| SFXPlayer | Existing cue system. Consider adding a `drop.m4a` cue for Stack (block placement). Off by default per product posture. |
| VideoModeBanner | Already in `Core/`. End-state for endless games reuses it with "Game Over — Score: X" content. |
| Video Mode adoption | Exempt for v1.5 per brief. Continuous-input real-time games cannot pause-and-reflow for PiP. |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|---|---|---|
| `TimelineView(.animation(paused:))` | `CADisplayLink` | Swift 6 Sendable friction; no gameplay benefit for Stack/Snake; `paused:` parameter on TimelineView is cleaner |
| `TimelineView(.animation(paused:))` | `Timer.scheduledTimer` / Combine timer | Not screen-synchronized; causes jitter; fires even when no display update pending |
| `TimelineView(.animation(paused:))` | `AsyncTimerSequence` | Not screen-synchronized; off-main-thread; no ProMotion adaptivity |
| Canvas (Stack) | `LazyVGrid` of shapes | Stack's continuous coordinates and sub-pixel overhang shaving need direct coordinate control |
| `LazyVGrid` (Snake) | Canvas | Consistent with existing board game pattern; 400 cells is not a perf problem on SwiftUI; easier to add VoiceOver if needed later |
| Fixed-timestep accumulator | Variable dt passed directly to engine | Simulation rate becomes frame-rate dependent; Snake moves at 2× speed on ProMotion; engine tests become non-deterministic |
| `BestScore` + `GameStats` (existing) | New persistence layer | Unnecessary. The existing schema already handles score-based games. GameKind is the only additive change. |
| `DragGesture.onEnded` + direction queue | Custom gesture recognizer via `UIGestureRecognizer` bridge | UIKit bridging in a pure SwiftUI app adds complexity. SwiftUI's DragGesture with `minimumDistance: 20` is reliable for 4-directional swipe detection. |

---

## Sources

### Context7 (authoritative, current)

- `/websites/developer_apple_swiftui` — `TimelineView`, `AnimationTimelineSchedule`, `AnimationTimelineSchedule.init(minimumInterval:paused:)`, `TimelineView.Context.Cadence`, `Canvas`, `GraphicsContext.Shading.color(_:)`, `DragGesture`, `onTapGesture`
- Context7 confirmed: `paused: Bool` parameter on `.animation(minimumInterval:paused:)` stops entry generation entirely when `true`. Cadence values: `.live`, `.seconds`, `.minutes` — no auto-background-pause from cadence, that is separate from `paused:`.

### Apple Developer Documentation

- [AnimationTimelineSchedule.init(minimumInterval:paused:)](https://developer.apple.com/documentation/swiftui/animationtimelineschedule/init%28minimuminterval%3Apaused%3A%29) — verified `paused: Bool` parameter
- [TimelineView.Context.Cadence](https://developer.apple.com/documentation/swiftui/timelineview/context/cadence-swift.enum) — `.live` / `.seconds` / `.minutes`
- [GraphicsContext](https://developer.apple.com/documentation/swiftui/graphicscontext) — `resolveSymbol`, `Shading.color(_:)`, `environment` property
- [DragGesture](https://developer.apple.com/documentation/swiftui/draggesture) — `minimumDistance`, `onChanged`, `onEnded`, `value.translation`
- [ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase) — `.background` / `.inactive` / `.active` and `.onChange` pattern

### Verified Community Sources (MEDIUM confidence)

- [SwiftUI Lab — TimelineView Part 4](https://swiftui-lab.com/swiftui-animations-part4/) — multiple recompilations per update caveat; `context.date` behavior
- [NilCoalescing — TimelineView in SwiftUI](https://nilcoalescing.com/blog/TimelineViewInSwiftUI/) — cadence property and detail-level adjustment
- [Gaffer on Games — Fix Your Timestep](https://gafferongames.com/post/fix_your_timestep/) — fixed-timestep accumulator pattern, spiral-of-death cap
- [Hacking With Swift — CADisplayLink](https://www.hackingwithswift.com/example-code/system/how-to-synchronize-code-to-drawing-using-cadisplaylink) — CADisplayLink basics; non-Sendable issue surfaced via Swift 6 search
- [Jacob's Tech Tavern — SwiftUI Game Engine](https://blog.jacobstechtavern.com/p/swiftui-game-engine) — Canvas + TimelineView for a simple game loop (confirms the Canvas + TimelineView pattern works; also confirms it's only for loading-screen-scale games, not full productions)
- [NSTimer vs CADisplayLink](https://dev.to/fassko/nstimer-vs-cadisplaylink-1086) — CADisplayLink fires at screen refresh; Timer does not

---

*Stack research for: GameKit v1.5 — Real-Time Endless Arcade Primitive*
*Researched: 2026-06-25*
