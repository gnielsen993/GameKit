# Phase 17: Snake - Pattern Map

**Mapped:** 2026-07-03
**Files analyzed:** 12 (9 new + 3 edited; 1 deleted)
**Analogs found:** 12 / 12

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Games/Snake/SnakeEngine.swift` | engine | transform | `Games/Stack/StackEngine.swift` | exact |
| `Games/Snake/SnakeConfig.swift` | config | — | `Games/Stack/StackConfig.swift` | exact |
| `Games/Snake/SnakeViewModel.swift` | store | event-driven | `Games/Stack/StackViewModel.swift` | exact |
| `Games/Snake/SnakeBoardCanvas.swift` | component | transform | `Games/Stack/StackBoardCanvas.swift` | exact |
| `Games/Snake/SnakeGameView.swift` | component | request-response | `Games/Stack/StackGameView.swift` | exact |
| `Games/Snake/SnakeScoreChip.swift` | component | transform | `Games/Stack/StackScoreChip.swift` | exact |
| `Core/ArcadePalette.swift` | utility | transform | `Games/Stack/StackPalette.swift` | exact (promoted verbatim) |
| `Screens/SnakeStatsCard.swift` | component | transform | `Screens/StackStatsCard.swift` | exact |
| `gamekitTests/Games/Snake/SnakeEngineTests.swift` | test | event-driven | `gamekitTests/Games/Stack/StackEngineTests.swift` | exact |
| `Games/Stack/StackPalette.swift` **[EDIT]** | utility | transform | itself | self-edit (thin wrapper) |
| `Screens/HomeView.swift` **[EDIT]** | component | request-response | itself (lines 400-402) | self-edit (one-line swap) |
| `Screens/StatsView.swift` **[EDIT]** | component | CRUD | itself (lines 221-237) | self-edit (replace placeholder) |
| `Games/Snake/SnakeHarnessView.swift` **[DELETE]** | — | — | — | — |

---

## Pattern Assignments

---

### `Games/Snake/SnakeEngine.swift` (engine, transform)

**Analog:** `Games/Stack/StackEngine.swift`

**Imports pattern** (StackEngine.swift lines 19):
```swift
import Foundation
```
No SwiftUI, no UIKit, no DesignKit. Engine is Foundation-only. All cells use `Int` (col/row); all time uses `Double` (seconds).

**Nonisolated value-type declaration** (StackEngine.swift lines 64-66):
```swift
nonisolated struct StackEngine {
    let cfg: StackConfig
    private(set) var placed: [PlacedBlock]
    // ...
    private(set) var gameOver = false
```
Snake mirrors this exactly: `nonisolated struct SnakeEngine { let cfg: SnakeConfig; private(set) var body: [SnakeCell]; private(set) var gameOver: Bool = false; ... }`. All associated value types (`SnakeCell`, `SnakeDirection`, `SnakeEvent`, `SnakeFrame`) carry `nonisolated` and `Sendable` where needed.

**RNG injection pattern** (StackEngine has no RNG — use RESEARCH.md Pattern 1 for this, which mirrors `Games/Merge/Engine/BoardSpawner.swift`'s seeded injection shape):
The `init(cfg:rng:)` takes `some RandomNumberGenerator` so production passes `SystemRandomNumberGenerator()` and tests pass `SeededGenerator(seed:)`. The `rng` field is stored as `any RandomNumberGenerator`.

**Core step function** (StackEngine.swift lines 128-133):
```swift
mutating func step(dt: Double, input: StackInput) -> StackFrame {
    guard !gameOver else { return frame(event: .none) }
    blockElapsed += dt
    guard input.drop else { return frame(event: .none) }
    // ... game logic ...
}
```
Snake's `step(dt:nextDirection:)` follows the same shape: guard on `gameOver`, advance `cellAccumulator += dt`, guard `cellAccumulator >= tickInterval` before executing a cell move, return `frame(event:)` at every exit point.

**Private frame helper** (StackEngine.swift lines 198-212):
```swift
private func frame(event: StackEvent) -> StackFrame {
    let top = placed[placed.count - 1]
    let c = currentSlideCenter
    return StackFrame(
        currentCenterX: axis == .x ? c : top.centerX,
        // ...
        gameOver: gameOver,
        event: event
    )
}
```
`SnakeEngine.frame(event:)` is identical in shape — pure function, constructs a `SnakeFrame` from current `private(set)` state including `cellMoveAlpha: min(cellAccumulator / tickInterval, 1.0)`.

**Speed ramp with plateau** (StackEngine.swift lines 121-124):
```swift
func rampSpeed(forScore s: Int) -> Double {
    let f = min(Double(s) / Double(cfg.plateauScore), 1.0)
    return cfg.startSpeed + (cfg.maxSpeed - cfg.startSpeed) * f
}
```
Snake mirrors: `tickInterval = max(cfg.minTickInterval, cfg.startTickInterval - Double(score) * cfg.intervalDecrement)`. Both are seconds-based (never frame counts) — SC2 / ProMotion-equivalence requirement.

**Post-gameOver guard** (StackEngine.swift line 129):
```swift
guard !gameOver else { return frame(event: .none) }
```
Identical in SnakeEngine — any `step()` call after `gameOver = true` is a no-op returning `.none`.

---

### `Games/Snake/SnakeConfig.swift` (config, —)

**Analog:** `Games/Stack/StackConfig.swift`

**Full file pattern** (StackConfig.swift lines 1-51):
```swift
import Foundation

nonisolated struct StackConfig: Sendable {
    let fixedDt: Double
    let playfieldWidth: Double
    // ... all tuning constants ...

    nonisolated static let `default` = StackConfig(
        fixedDt: 1.0 / 60.0,
        // ...
    )

    nonisolated static let testFixed = StackConfig(
        fixedDt: 1.0 / 60.0,
        // ... stable values decoupled from default calibration ...
    )
}
```
`SnakeConfig` mirrors exactly: `nonisolated struct SnakeConfig: Sendable` with all time-unit fields (`startTickInterval`, `minTickInterval`, `intervalDecrement`, `fixedDt: 1.0/60.0`), grid dimensions (`cols`, `rows`), `wallMode: Bool`, and two static constants — `default` (device-calibrated) and `testFixed` (stable for unit tests, small grid like 10×10).

**File header comment pattern** (StackConfig.swift lines 4-8):
```swift
//  Play-test tuning constants for StackEngine. Values are MEDIUM confidence
//  baselines — calibrate on device (16-CONTEXT D-03). No dt clamp here;
//  that lives in ArcadeLoopDriver only (ARCADE-02). Foundation only.
```
SnakeConfig header notes the same: no dt clamp, Foundation only, MEDIUM confidence for grid dims and speed ramp constants.

---

### `Games/Snake/SnakeViewModel.swift` (store, event-driven)

**Analog:** `Games/Stack/StackViewModel.swift`

**Class declaration + state surface** (StackViewModel.swift lines 16-47):
```swift
import Foundation

@Observable @MainActor
final class StackViewModel {

    private(set) var state: ArcadeGameState = .idle
    private(set) var frame: StackFrame
    private(set) var prevCenterX: Double
    private(set) var prevCenterZ: Double
    private(set) var perfectCount: Int = 0   // counter-trigger haptic
    private(set) var dropCount: Int = 0      // counter-trigger haptic
    private(set) var gameStats: GameStats?
```
`SnakeViewModel` mirrors: `@Observable @MainActor final class SnakeViewModel`. State surface includes `private(set) var state: ArcadeGameState = .idle`, `private(set) var frame: SnakeFrame`, `private(set) var prevBody: [SnakeCell]` (Gaffer anchor), `private(set) var eatCount: Int = 0`, `private(set) var enqueueCount: Int = 0`, `private(set) var highScoreCount: Int = 0`, `private(set) var gameStats: GameStats?`. Also owns `var showingAbandonAlert: Bool = false` and `private(set) var wallMode: Bool`.

**Fixed-timestep accumulator** (StackViewModel.swift lines 122-168):
```swift
func tick(dt: Double) {
    guard state == .running else { return }
    accumulator += dt
    while accumulator >= fixedDt {
        let input = StackInput(drop: pendingDrop)
        pendingDrop = false
        let beforeCenterX = frame.currentCenterX
        let newFrame = engine.step(dt: fixedDt, input: input)
        accumulator -= fixedDt
        frame = newFrame

        switch newFrame.event {
        case .perfect: perfectCount += 1; ...
        // ...
        }

        if newFrame.gameOver {
            state = .gameOver
            try? gameStats?.recordStackRun(score: newFrame.score, ...)
            return
        }
    }
}
```
`SnakeViewModel.tick(dt:)` follows exactly the same shape. The difference: instead of `pendingDrop`, the VM pops from `directionQueue` per cell-move (not per fixed step — the queue pop happens inside the engine's cell-move gate). On `.ate` event: `eatCount += 1`. On gameOver: `try? gameStats?.record(gameKind: .snake, mode: "endless", outcome: .loss, score: engine.score)` then `return`.

**Direction queue (Snake-specific addition)** (RESEARCH.md Pattern 3 — no direct analog but closest to `pendingDrop` in StackViewModel):
```swift
// VM-private fields
private var directionQueue: [SnakeDirection] = []
private let maxQueueDepth = 2
private(set) var enqueueCount: Int = 0

@discardableResult
func tryEnqueueDirection(_ dir: SnakeDirection) -> Bool {
    let effectiveCurrent = directionQueue.last ?? engine.currentDirection
    guard dir != effectiveCurrent.opposite else { return false }
    guard directionQueue.count < maxQueueDepth else { return false }
    directionQueue.append(dir)
    enqueueCount += 1   // fires .selection haptic via .sensoryFeedback in view
    return true
}
```
`enqueueCount += 1` is INSIDE the guard — never fires on rejected input (D-07).

**GameStats injection — lazy one-shot** (StackViewModel.swift lines 173-177):
```swift
func attachGameStats(_ stats: GameStats) {
    guard !didAttachStats else { return }
    didAttachStats = true
    gameStats = stats
}
```
Identical in `SnakeViewModel`. Called from `SnakeGameView.task` exactly once.

**Restart** (StackViewModel.swift lines 183-197):
```swift
func restart() {
    engine = StackEngine(cfg: engine.cfg)
    accumulator = 0
    perfectCount = 0; dropCount = 0
    pendingDrop = false
    prevCenterX = ...; prevCenterZ = ...
    frame = Self.initialFrame(cfg: engine.cfg)
    state = .idle
}
```
`SnakeViewModel.restart()` mirrors: re-create `engine = SnakeEngine(cfg: engine.cfg, rng: SystemRandomNumberGenerator())`, reset `accumulator`, counters, `directionQueue = []`, snap `prevBody`, set `state = .idle`.

**Lifecycle** (StackViewModel.swift lines 101-117):
```swift
func start() { accumulator = 0; state = .running }
func pause() { if state == .running { state = .paused } }
func resume() { if state == .paused { state = .running } }
func stop() { state = .idle; accumulator = 0 }
```
Identical in SnakeViewModel. `pause()` and `resume()` guard on current state to prevent spurious transitions.

**Wall-mode abandon-alert** (MergeViewModel.swift lines 175-207):
```swift
var showingAbandonAlert: Bool = false

func requestModeChange(_ newMode: MergeMode) {
    if score > 0 {
        pendingModeChange = newMode
        showingAbandonAlert = true
    } else {
        setMode(newMode)
    }
}
func confirmModeChange() { ...; showingAbandonAlert = false; setMode(target) }
func cancelModeChange()  { pendingModeChange = nil; showingAbandonAlert = false }
```
`SnakeViewModel` maps this to `requestWallModeToggle()` / `confirmWallModeChange()` / `cancelWallModeChange()`, gating on `engine.score > 0` (food eaten = meaningful progress). `applyWallModeToggle()` flips `wallMode`, writes to `UserDefaults.standard` under key `"snake.wallMode"`, then calls `restart()`.

---

### `Games/Snake/SnakeBoardCanvas.swift` (component, transform)

**Analog:** `Games/Stack/StackBoardCanvas.swift`

**Props-only Canvas declaration** (StackBoardCanvas.swift lines 42-93):
```swift
struct StackBoardCanvas: View {
    let placed: [PlacedBlock]
    let frame: StackFrame
    let prevCenterX: Double
    let prevCenterZ: Double
    let accAlpha: Double
    let theme: Theme
    let now: Date
    let fxEnabled: Bool
    let reduceMotion: Bool
    let lastPlacementAt: Date?
    // ... more FX props ...
```
`SnakeBoardCanvas` is props-only: `let body: [SnakeCell]`, `let prevBody: [SnakeCell]`, `let cellMoveAlpha: Double`, `let food: SnakeCell`, `let currentDirection: SnakeDirection`, `let theme: Theme`, `let reduceMotion: Bool`, `let fxEnabled: Bool`, `let cols: Int`, `let rows: Int`. No `@State`, no `@Environment`. Parent (`SnakeGameView`) owns all state.

**Canvas body skeleton** (StackBoardCanvas.swift lines 139-223 — key structural excerpts):
```swift
var body: some View {
    Canvas { ctx, size in
        let logicalH = size.height - bottomObscured
        let isoW = size.width * Self.isoWidthFraction
        // ... projection setup ...

        // Gaffer interpolation: lerp prev → current centers (snap under RM)
        let renderCX = reduceMotion
            ? frame.currentCenterX
            : prevCenterX + (frame.currentCenterX - prevCenterX) * accAlpha
```
`SnakeBoardCanvas.body` follows the same pattern:
```swift
var body: some View {
    Canvas { ctx, size in
        let cellSize = size.width / CGFloat(cols)
        let alpha = reduceMotion ? 0.0 : cellMoveAlpha   // SNAKE-07: RM = jump-cut

        // segPos(i): lerp prevBody[i] → body[i] at alpha
        // Wrap-boundary detection: if abs(curr.col - prev.col) > cols/2, skip stroke
        // Body: stroked Path per adjacent segment pair, colored from ArcadePalette
        // Head: topmost segment + eye dots (theme.colors.background)
        // Food: Circle fill (success token)
    }
}
```

**Palette usage in Canvas** (StackBoardCanvas.swift line 182-185):
```swift
let layer = StackPalette.layer(forIndex: i, theme: theme)
drawShadedBox(ctx, iso: iso, cx: cx, cz: cz,
              width: block.width, depth: block.depth,
              hBottom: hBottom, hTop: Double(i + 1), layer: layer)
```
Snake replaces `StackPalette` with `ArcadePalette`: `let layer = ArcadePalette.layer(forIndex: i, theme: theme)`. Index 0 = head (chart1, most saturated); last index = tail (least saturated). The `layer.base` colors the stroke; `layer.next` alpha-blended at `layer.blend` for the smooth gradient.

**Token-only face shading via blend modes** (StackBoardCanvas.swift lines 295-305):
```swift
var light = ctx
light.blendMode = .screen
light.fill(top, with: .color(layer.base.opacity(0.55)))
```
Snake does not need multi-face shading (it's 2D). But for the board well (`border`-tinted rounded container, D-03): `ctx.stroke(boardPath, with: .color(theme.colors.border), lineWidth: 1)`. No raw Color literals anywhere.

**TimelineView pausing** (StackGameView.swift line 241 — parent of StackBoardCanvas):
```swift
TimelineView(.animation(paused: !fxEnabled || vm.state == .idle || showBanner)) { tl in
    StackBoardCanvas(now: tl.date, ...)
}
```
`SnakeGameView` uses the same paused condition: `!fxEnabled || vm.state == .idle || showBanner`. Passes `tl.date` to `SnakeBoardCanvas` if FX are needed; under RM the canvas doesn't need a `now` prop (all positions are cell-snapped).

---

### `Games/Snake/SnakeGameView.swift` (component, request-response)

**Analog:** `Games/Stack/StackGameView.swift` + `Games/Stack/StackGameView+Chrome.swift`

**Imports + environment reads** (StackGameView.swift lines 28-43):
```swift
import SwiftUI
import SwiftData
import DesignKit

struct StackGameView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsStore) var settingsStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss

    @State var vm = StackViewModel()
    @State private var didInjectStats = false
    @State var showBanner: Bool = false
```
`SnakeGameView` mirrors exactly. **Key difference:** NO `@Environment(\.videoModeStore)` — Snake is Video Mode exempt per ADR. No `.videoModeAware()` in HomeView routing.

**Arcade loop + scenePhase wiring** (StackGameView.swift lines 88-96):
```swift
.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active:                  vm.resume()
    case .inactive, .background:   vm.pause()
    @unknown default:              vm.pause()
    }
}
```
Copy verbatim. Both `.inactive` AND `.background` must call `vm.pause()` — Pitfall 2 (notification banner triggers .inactive, not .background).

**Game-over pre-roll** (StackGameView.swift lines 128-158):
```swift
.onChange(of: vm.state) { _, newState in
    if newState == .gameOver {
        showBanner = false
        if fxEnabled {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeOut(duration: 0.3)) { showBanner = true }
            }
        } else {
            showBanner = true  // instant cut (RM or animations off)
        }
    } else if newState == .idle {
        showBanner = false
    }
}
```
Copy verbatim. The 500ms Task.sleep is DESIGN.md §10.3 "Game over = 500ms" pre-roll.

**Counter-trigger haptics — hapticsEnabled FIRST guard** (StackGameView.swift lines 161-164):
```swift
.sensoryFeedback(.impact(weight: .medium),
                 trigger: settingsStore.hapticsEnabled ? vm.perfectCount : 0)
.sensoryFeedback(.impact(weight: .light),
                 trigger: settingsStore.hapticsEnabled ? vm.dropCount : 0)
```
Snake's version:
```swift
// D-08 eat — .impact(weight: .light, intensity: 0.7)
.sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                 trigger: settingsStore.hapticsEnabled ? vm.eatCount : 0)
// D-07 direction enqueue — .selection
.sensoryFeedback(.selection,
                 trigger: settingsStore.hapticsEnabled ? vm.enqueueCount : 0)
// D-09 new high score mid-run — .impact(weight: .medium, intensity: 1.0)
.sensoryFeedback(.impact(weight: .medium, intensity: 1.0),
                 trigger: settingsStore.hapticsEnabled ? vm.highScoreCount : 0)
```
`hapticsEnabled` is the FIRST guard (collapses trigger to 0 when false).

**GameStats injection — lazy one-shot** (StackGameView.swift lines 165-171):
```swift
.task {
    guard !didInjectStats else { return }
    didInjectStats = true
    let stats = GameStats(modelContext: modelContext)
    vm.attachGameStats(stats)
}
```
Copy verbatim into `SnakeGameView`.

**VideoModeBanner** (StackGameView.swift lines 211-223):
```swift
if showBanner {
    VideoModeBanner(
        theme: theme,
        content: gameOverContent,
        location: videoModeStore.isEnabled ? videoModeStore.location : .largeBottom,
        hapticsEnabled: settingsStore.hapticsEnabled,
        reduceMotion: reduceMotion,
        animationsEnabled: settingsStore.animationsEnabled
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .videoModeBannerTransition(reduceMotion: reduceMotion,
                               animationsEnabled: settingsStore.animationsEnabled)
}
```
Snake simplifies: no `videoModeStore` check. Always pass `location: .largeBottom` (Video Mode exempt).

**Game-over banner content** (StackGameView+Chrome.swift lines 18-33):
```swift
var gameOverContent: VideoModeBannerContent {
    VideoModeBannerContent(
        outcome: .loss,
        title: String(localized: "Game over"),
        subtitle: nil,
        primaryButtonLabel: String(localized: "Restart"),
        accessibilityLabel: String(
            format: String(localized: "Game over. Score %d. Restart"),
            vm.frame.score
        ),
        onPrimary: {
            vm.restart()
            showBanner = false
        }
    )
}
```
`SnakeGameView` mirror: identical shape, substitute `vm.frame.score` for Snake's score.

**Back chevron** (StackGameView+Chrome.swift lines 83-103):
```swift
@ToolbarContentBuilder var backChevron: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        Button { dismiss() } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to The Drawer"))
    }
}
```
Copy verbatim.

**Idle content** (StackGameView+Chrome.swift lines 57-79):
```swift
@ViewBuilder var idleContent: some View {
    VStack(spacing: theme.spacing.l) {
        Text(String(localized: "Stack"))
            .font(theme.typography.titleLarge)
            .foregroundStyle(theme.colors.textPrimary)
        Text(String(localized: "Tap anywhere to start"))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textSecondary)
        DKButton(String(localized: "Start"), theme: theme) { vm.start() }
            .frame(maxWidth: 220)
    }
    .padding(theme.spacing.xl)
    .background(
        RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .fill(theme.colors.surfaceElevated.opacity(0.94))
    )
    .padding(theme.spacing.l)
}
```
Snake's `idleContent` mirrors shape. Text reads `"Snake"` + `"Swipe or tap D-pad to start"`. The `DKButton("Start")` calls `vm.start()` (state transitions to `.running`).

**Toolbar menu — wall-mode toggle** (FiveLetterGameView.swift lines 186-199):
```swift
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        // ...
        Button(viewModel.strictModeEnabled ? "Strict mode: On" : "Strict mode: Off") {
            viewModel.toggleStrictMode()
        }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
    .accessibilityLabel(Text("Mode"))
}
```
Snake's version:
```swift
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        Button(vm.wallMode
               ? String(localized: "Wall mode: On")
               : String(localized: "Wall mode: Off")) {
            vm.requestWallModeToggle()
        }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
    .accessibilityLabel(Text("Options"))
}
```

**Abandon-alert binding** (MergeGameView.swift lines 112-124):
```swift
.alert(
    String(localized: "Abandon current game?"),
    isPresented: $viewModel.showingAbandonAlert
) {
    Button(String(localized: "Cancel"), role: .cancel) {
        viewModel.cancelModeChange()
    }
    Button(String(localized: "Abandon"), role: .destructive) {
        viewModel.confirmModeChange()
    }
} message: {
    Text(String(localized: "Switching modes resets the board. Your current score will be lost."))
}
```
`SnakeGameView` mirror: `$vm.showingAbandonAlert`, `vm.cancelWallModeChange()`, `vm.confirmWallModeChange()`. Message text: `"Switching modes resets the run. Your current score will be lost."`.

**Swipe gesture + deferred system gestures** (RESEARCH.md Pattern 5 — no direct analog in Stack; this is Snake-specific):
```swift
// Applied to the board view wrapper in SnakeGameView
.gesture(
    DragGesture(minimumDistance: 10, coordinateSpace: .local)
        .onEnded { value in
            let dx = value.translation.width, dy = value.translation.height
            if abs(dx) > abs(dy) {
                vm.tryEnqueueDirection(dx > 0 ? .right : .left)
            } else {
                vm.tryEnqueueDirection(dy > 0 ? .down : .up)
            }
        }
)
.defersSystemGestures(on: .all)
```

**grayscale drain on death** (StackGameView.swift lines 187-196):
```swift
Group {
    if includeBackdrop { backdrop }
    board
}
.grayscale(vm.state == .gameOver ? 1.0 : 0.0)
.animation(fxEnabled ? .easeOut(duration: 0.5) : nil,
           value: vm.state == .gameOver)
```
Snake mirrors: `.grayscale(vm.state == .gameOver ? 1.0 : 0.0)` on the board Group. Same 0.5s easeOut duration, same `fxEnabled` gate. D-10: "whole snake desaturates/color-drains."

**navigationBarBackButtonHidden + navigationBarTitleDisplayMode** (StackHarnessView.swift lines 119-120, also StackGameView via stack navigation):
```swift
.navigationBarBackButtonHidden(true)
.navigationTitle(String(localized: "Snake"))
.navigationBarTitleDisplayMode(.inline)
.toolbar { backChevron; wallModeToolbar }
```

---

### `Games/Snake/SnakeScoreChip.swift` (component, transform)

**Analog:** `Games/Stack/StackScoreChip.swift`

**Full file pattern** (StackScoreChip.swift lines 1-45):
```swift
struct StackScoreChip: View {
    let theme: Theme
    let score: Int
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Score").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(score)")
                .font(compact ? theme.typography.caption : theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
        }
        .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.m)
        .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score)"))
    }
}
```
`SnakeScoreChip` is identical except: name is `SnakeScoreChip`, no `compact` variant needed (Snake has no Video Mode compact row — exempt per ADR). The chip also applies `.contentTransition(.numericText(countsDown: false))` on the score `Text` for D-08's score roll animation. Gate with `.feedbackAnimation(.default, value: score)`.

---

### `Core/ArcadePalette.swift` (utility, transform)

**Analog:** `Games/Stack/StackPalette.swift` (promoted verbatim)

**Full source to promote** (StackPalette.swift lines 31-64):
```swift
enum StackPalette {
    static let blocksPerStop = 4
    struct Layer {
        let base: Color
        let next: Color
        let blend: Double
    }
    static func layer(forIndex i: Int, theme: Theme) -> Layer {
        let ramp: [Color] = [
            theme.charts.chart1, theme.charts.chart2,
            theme.charts.chart3, theme.charts.chart4,
            theme.charts.chart5, theme.charts.chart6,
        ]
        let pos = Double(max(i, 0)) / Double(blocksPerStop)
        let seg = Int(pos) % ramp.count
        let frac = pos - pos.rounded(.down)
        return Layer(base: ramp[seg],
                     next: ramp[(seg + 1) % ramp.count],
                     blend: frac)
    }
}
```
`ArcadePalette` is this enum renamed, with `blocksPerStop` renamed to `segmentsPerStop` (both Stack's tower layers and Snake's body segments). The function signature `layer(forIndex:theme:)` is unchanged.

**Updated `StackPalette.swift` (EDIT — thin wrapper)**:
```swift
// Games/Stack/StackPalette.swift
// PROMOTED to Core/ArcadePalette in Phase 17 (2+ games rule).
// This file is now a forwarding shim — do not add logic here.
import SwiftUI
import DesignKit

typealias StackPalette = ArcadePalette
```
Stack source files continue compiling unchanged. `StackPalette.blocksPerStop` → `ArcadePalette.segmentsPerStop` (if the rename is applied) OR keep `blocksPerStop` as an alias in ArcadePalette so Stack code compiles with zero changes.

---

### `Screens/SnakeStatsCard.swift` (component, transform)

**Analog:** `Screens/StackStatsCard.swift`

**Full file pattern** (StackStatsCard.swift lines 1-117):
```swift
struct StackStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    private var highScoreText: String {
        guard let score = bestScores.first(where: {
            $0.difficultyRaw == GameStats.stackEndlessMode
        })?.score else { return "—" }
        return "\(score)"
    }
    private var runsPlayed: Int { records.count }
    // ...
    var body: some View {
        if records.isEmpty { emptyState } else { metricsGrid }
    }
    @ViewBuilder private var emptyState: some View {
        Text(String(localized: "No Stack games played yet."))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity)
    }
    @ViewBuilder private var metricsGrid: some View {
        Grid(alignment: .leading,
             horizontalSpacing: theme.spacing.m,
             verticalSpacing: theme.spacing.s) {
            metricRow(label: "High Score", value: highScoreText, ...)
            // border separator
            Rectangle().fill(theme.colors.border).frame(height: 1).gridCellColumns(2)
            metricRow(label: "Runs Played", value: "\(runsPlayed)", ...)
        }
    }
    @ViewBuilder private func metricRow(label:, value:, a11yLabel:) -> some View {
        GridRow {
            Text(label).font(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
            Text(value).font(theme.typography.monoNumber).monospacedDigit()
                       .foregroundStyle(theme.colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(a11yLabel))
    }
}
```
`SnakeStatsCard` is identical in structure. Two metrics (Phase 17 scope — full shape deferred to Phase 18): `High Score` (from `BestScore` where `difficultyRaw == "endless"`) and `Runs Played` (from `records.count`). Empty state: `"No Snake games played yet."`. The `"endless"` key must match the VM's write path exactly (D-12: naming locked, renaming = data break).

**StatsView integration** (StatsView.swift lines 228-237 — the placeholder to replace):
```swift
// CURRENT (Phase 15 placeholder — delete):
if shows(.snake) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SNAKE")) }
    DKCard(theme: theme) {
        Text(String(localized: "No Snake games yet."))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textSecondary)
            .padding(theme.spacing.m)
    }
}

// REPLACE WITH (mirroring Stack pattern at lines 221-226):
if shows(.snake) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SNAKE")) }
    DKCard(theme: theme) {
        SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)
    }
}
```
The `snakeRecords` and `snakeBestScores` `@Query` pairs are already declared at StatsView.swift lines 137-145 — no new queries needed.

---

### `gamekitTests/Games/Snake/SnakeEngineTests.swift` (test, event-driven)

**Analog:** `gamekitTests/Games/Stack/StackEngineTests.swift`

**Suite declaration** (StackEngineTests.swift lines 17-18):
```swift
import Testing
import Foundation
@testable import gamekit

@Suite("StackEngine determinism")
nonisolated struct StackEngineTests {
```
`SnakeEngineTests` mirrors:
```swift
import Testing
import Foundation
@testable import gamekit

@Suite("SnakeEngine determinism")
nonisolated struct SnakeEngineTests {
```
`nonisolated struct` — engine is Foundation-only, no actor isolation needed. Same as StackEngineTests, MergeEngineTests.

**ProMotion equivalence test shape** (StackEngineTests.swift lines 55-83):
```swift
@Test("ProMotion equivalence: 60 Hz step stream ≡ 120 Hz step stream")
func proMotionEquivalence() {
    func run(fixedDt: Double) -> StackEngine {
        var e = StackEngine(cfg: .testFixed)
        let totalSteps = Int((5.0 / fixedDt).rounded())
        for step in 1...totalSteps {
            _ = e.step(dt: fixedDt, input: StackInput(drop: ...))
        }
        return e
    }
    let a = run(fixedDt: 1.0 / 60.0)
    let b = run(fixedDt: 1.0 / 120.0)
    #expect(a.score == b.score)
    #expect(a.gameOver == b.gameOver)
}
```
`SnakeEngineTests.proMotionEquivalence` runs the same shape: straight run (no direction changes, `nextDirection: nil`) for 5 simulated seconds at 60Hz and 120Hz, expects equal `score` and `gameOver`.

**Seed determinism test** (no direct Stack analog — but `SeededGenerator` injection is the pattern):
```swift
@Test("seed determinism: same seed → identical frame sequences")
func seedDeterminism() throws {
    var rng1 = SeededGenerator(seed: 42)
    var rng2 = SeededGenerator(seed: 42)
    var e1 = SnakeEngine(cfg: .testFixed, rng: rng1)
    var e2 = SnakeEngine(cfg: .testFixed, rng: rng2)
    // Step both with identical direction sequences; #expect food/body/gameOver match
}
```

**SeededGenerator usage** (gamekitTests/Helpers/SeededGenerator.swift lines 25-39 — already in test target):
```swift
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 { ... /* SplitMix64 */ }
}
```
Test target only — never in production target. Inject into `SnakeEngine(cfg:rng:)` for deterministic food-spawn tests.

**Edge-case test shape** (StackEngineTests.swift lines 123-143):
```swift
@Test("complete miss (no overlap) ends the run")
func completeMissGameOver() {
    var engine = StackEngine(cfg: .testFixed)
    var missFrame: StackFrame?
    for _ in 0..<20 {
        let f = engine.step(dt: 0, input: StackInput(drop: true))
        if f.event == .miss { missFrame = f; break }
    }
    #expect(missFrame != nil, ...)
    #expect(engine.gameOver)
    // Post-gameOver step is a no-op
    let noOp = engine.step(dt: 1.0, input: StackInput(drop: true))
    #expect(noOp.event == .none)
}
```
Snake edge-case tests follow the same pattern: `var rng = SeededGenerator(seed: N); var e = SnakeEngine(cfg: .testFixed, rng: rng)`. Required tests: `wallCollision`, `toroidalWrap`, `selfCollision`, `proMotionEquivalence`, `seedDeterminism`.

**Persistence test** (GameStatsTests.swift lines 24-35 — `makeStats()` helper):
```swift
@MainActor
@Suite("GameStats")
struct GameStatsTests {
    private func makeStats() throws -> (GameStats, ModelContext, ModelContainer) {
        let container = try InMemoryStatsContainer.make()
        let context = ModelContext(container)
        let stats = GameStats(modelContext: context)
        return (stats, context, container)
    }
    @Test("...")
    func someTest() throws {
        let (stats, ctx, _) = try makeStats()
        try stats.record(gameKind: .snake, mode: "endless", outcome: .loss, score: 15)
        let records = try ctx.fetch(FetchDescriptor<GameRecord>(...))
        #expect(records.count == 1)
        // ...
    }
}
```
The Snake persistence test `recordSnakeRunHigherOnly` is added to the existing `GameStatsTests` file (NOT a new file) — it uses the same `makeStats()` helper and `@MainActor` struct pattern.

---

### `Screens/HomeView.swift` (EDIT — one-line swap)

**Analog:** itself (lines 400-402)

**Current routing** (HomeView.swift lines 400-402):
```swift
case .snake:
    SnakeHarnessView()
        .disableInteractivePop()
```

**Replacement:**
```swift
case .snake:
    SnakeGameView()
        .disableInteractivePop()
        // NOTE: NO .videoModeAware() — Snake exempt per 15-VIDEO-MODE-ADR.md
        // Compare Stack at lines 396-399: StackGameView().videoModeAware(...).disableInteractivePop()
```

---

## Shared Patterns

### 1. Arcade Loop Driver
**Source:** `Core/ArcadeLoopDriver.swift` (consumed as-is — zero modifications)
**Apply to:** `SnakeGameView.swift`
```swift
// ArcadeLoopDriver exposes this modifier — no import needed (it's in Core/)
.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
```
`ArcadeLoopDriver` already clamps `min(rawDt, 0.1)` — never add a second clamp.

### 2. ScenePhase Pause (both .inactive and .background)
**Source:** `Games/Stack/StackGameView.swift` lines 90-96
**Apply to:** `SnakeGameView.swift`
```swift
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active:                  vm.resume()
    case .inactive, .background:   vm.pause()   // BOTH: notification banners trigger .inactive
    @unknown default:              vm.pause()
    }
}
```

### 3. Counter-Trigger Haptics (hapticsEnabled FIRST guard)
**Source:** `Games/Stack/StackGameView.swift` lines 161-164
**Apply to:** `SnakeGameView.swift`
```swift
.sensoryFeedback(.someHaptic, trigger: settingsStore.hapticsEnabled ? vm.someCounter : 0)
```
`hapticsEnabled ? vm.counter : 0` collapses the trigger to a constant when haptics are disabled — no haptic fires. VideoModeBanner fires its own `.error` haptic on appear — no duplicate in SnakeGameView.

### 4. feedbackAnimation Gate
**Source:** `Core/MotionGate.swift` lines 36-38
**Apply to:** All animated feedback in `SnakeGameView.swift` and `SnakeBoardCanvas.swift`
```swift
.feedbackAnimation(.spring(response: 0.3), value: someValue)
// Collapses to nil when accessibilityReduceMotion || !settingsStore.animationsEnabled
```

### 5. chipShadow() + PressableButtonStyle
**Source:** `Core/SurfaceDepth.swift` + `Core/PressableButtonStyle.swift`
**Apply to:** `SnakeDPad` buttons in `SnakeGameView.swift`
```swift
.chipShadow()            // ambient shadow — shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2)
.buttonStyle(.pressable) // scale 0.94 on press, gated on RM + animationsEnabled
```

### 6. Token Discipline
**Source:** `CLAUDE.md §1`, `Games/Stack/StackBoardCanvas.swift` (entire file)
**Apply to:** All `Games/Snake/` and `Screens/SnakeStatsCard.swift` files
- Zero `Color(red:)`, `Color(hex:)`, or system color names (`.green`, `.blue`, etc.)
- All colors via `theme.colors.*`, `theme.charts.*`, or `ArcadePalette.layer(forIndex:theme:)`
- Verification gate: `grep -rn "Color(red:\|Color(hex:\|\.green\b\|\.blue\b" Games/Snake/` must return empty

### 7. Engine Purity (nonisolated struct, Foundation-only)
**Source:** `Games/Stack/StackEngine.swift` lines 19, 64
**Apply to:** `Games/Snake/SnakeEngine.swift`
```swift
import Foundation   // only import in SnakeEngine.swift
nonisolated struct SnakeEngine { ... }
nonisolated struct SnakeCell: Hashable { ... }
nonisolated enum SnakeDirection: Equatable, Sendable { ... }
```
Verification gate: `grep -rn "import SwiftUI\|import UIKit\|CGFloat\|CGPoint\|Date.now\|modelContext" Games/Snake/SnakeEngine.swift` must return empty.

### 8. VideoModeBanner (game-over surface)
**Source:** `Core/VideoModeBanner.swift` (consumed as-is)
**Apply to:** `SnakeGameView.swift`
```swift
VideoModeBanner(
    theme: theme,
    content: VideoModeBannerContent(
        outcome: .loss,
        title: String(localized: "Game over"),
        subtitle: nil,
        primaryButtonLabel: String(localized: "Restart"),
        accessibilityLabel: "Game over. Score \(vm.frame.score). Restart",
        onPrimary: { vm.restart(); showBanner = false }
    ),
    location: .largeBottom,   // Snake: no Video Mode, always largeBottom
    hapticsEnabled: settingsStore.hapticsEnabled,
    reduceMotion: reduceMotion,
    animationsEnabled: settingsStore.animationsEnabled
)
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
.videoModeBannerTransition(reduceMotion: reduceMotion, animationsEnabled: settingsStore.animationsEnabled)
```

### 9. GameStats.record() — Score Persistence Path
**Source:** `Core/GameStats.swift` lines 113-144
**Apply to:** `SnakeViewModel.swift` (called exactly once on `.gameOver` transition)
```swift
// Inside tick(), on gameOver:
state = .gameOver
try? gameStats?.record(
    gameKind: .snake,
    mode: "endless",     // PERMANENT KEY — renaming = data break (D-12)
    outcome: .loss,      // snake runs always end in loss
    score: engine.score  // food eaten count
)
return   // halts the while loop
```

---

## No Analog Found

No files in this phase lack a codebase analog. All nine new files have exact Stack/Core/gamekitTests matches.

---

## File: Delete

| File | Action | Reason |
|---|---|---|
| `Games/Snake/SnakeHarnessView.swift` | DELETE | Phase 15 throwaway — replaced by `SnakeGameView()` in HomeView routing |

---

## Metadata

**Analog search scope:** `Games/Stack/`, `Core/`, `Games/Merge/`, `Games/Words/FiveLetter/`, `Screens/`, `gamekitTests/`
**Files scanned:** 15 source files read, 4 grep searches
**Pattern extraction date:** 2026-07-03

**Critical invariants confirmed in source:**
- `ArcadeLoopDriver` clamps `min(rawDt, 0.1)` — no second clamp in VM or engine (ArcadeLoopDriver.swift line 42)
- `snakeRecords` + `snakeBestScores` @Query pairs already declared (StatsView.swift lines 137-145)
- Snake routing is `SnakeHarnessView().disableInteractivePop()` with NO `.videoModeAware()` (HomeView.swift lines 400-402)
- `GameStats.record(gameKind:mode:outcome:score:)` is the correct overload for arcade scores (GameStats.swift lines 113-144)
- `SeededGenerator` is test-target-only (gamekitTests/Helpers/SeededGenerator.swift)
- `StackPalette.layer(forIndex:theme:)` is the exact function to promote to `ArcadePalette` (StackPalette.swift lines 48-63)
