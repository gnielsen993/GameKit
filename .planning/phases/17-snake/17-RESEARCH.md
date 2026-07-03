# Phase 17: Snake — Research

**Researched:** 2026-07-03
**Domain:** Grid-based arcade game on the Phase 15 substrate — pure engine, Canvas rendering, direction queue, swipe + D-pad controls, smooth Gaffer interpolation, Reduce Motion jump-cut, score persistence, wall-mode toggle
**Confidence:** HIGH — all findings verified against live source files or cited from prior-phase research (15-RESEARCH.md, 16-RESEARCH.md)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Visual identity (SNAKE-06)**
- **D-01:** Snake renders as a **single continuous rounded path** (adjacent cells joined, capsule-like ends). Head distinguished by **two small eye dots** (`theme.colors.background` on body fill). No extra chrome.
- **D-02:** Body shades **along its length** using the same accent-derived ramp approach as `StackPalette.layer(forIndex:theme:)` — head darkest/most saturated, fading toward the tail. Reuse or adapt StackPalette (promotion to a shared arcade palette helper allowed if code is genuinely identical — satisfies 2+ games rule). Food is a **circle** filled with a clearly contrasting token — planner picks between `accentPrimary` and `success` after checking §8.12 contrast.
- **D-03:** **No grid lines.** Board is a clean "board well" treatment (`border`-tinted rounded container, like Merge's board). Flat well, no sheen — per DESIGN.md §3.0.
- **D-04:** Movement is **smooth-glide interpolated** between cells at normal motion (Gaffer-interpolation pattern Stack uses). Under Reduce Motion or animations-off: **jump-cut cell teleport per tick** (SNAKE-07, roadmap-locked). Growth extends tail smoothly; under RM appends instantly.

**Controls layout (SNAKE-03)**
- **D-05:** **Swipe anywhere on the board** is the primary control. Board area applies `.defersSystemGestures(on: .all)` (success criterion 1).
- **D-06:** **D-pad is a compact 4-button cross, bottom-center below the board** — in the slot other games use for the mode pill. Never overlaying the board. Always visible during play. Buttons: `surface` fill, 1pt `border`, `radii.button`, `chipShadow()`, `PressableButtonStyle`, ≥44pt hit targets. Opposite-direction button renders enabled but is a no-op at the queue level.
- **D-07:** A successful turn input (swipe or D-pad) that enqueues a direction fires `.selection` haptic. Rejected inputs (180° reversal, full queue) fire nothing.

**Eat & death feedback triples (DESIGN.md §10.6)**
- **D-08:** **Eat** = visual: food absorbed into head + body grows + score chip rolls via `.contentTransition(.numericText)` · haptic: `.impact(weight: .light, intensity: 0.7)` · animation: brief head pulse as food shrinks into it. All gated by `feedbackAnimation` / haptics settings.
- **D-09:** **New high score mid-run** (crossing persisted best, once per run) = `.impact(weight: .medium, intensity: 1.0)` + one-time score-chip pulse. No banner, no interruption.
- **D-10:** **Death** = collided segment/head flashes `danger`, whole snake **desaturates/color-drains**, then `VideoModeBanner` (final score + restart) after 500ms pre-roll (§10.3). Haptic: `.error` fires on collision. Under RM / animations-off: instant cut to banner, no drain. **Never any screen shake.**

**Wrap/wall mode surfacing (SNAKE-02)**
- **D-11:** Snake Home tile stays **modeless** (tap → straight into game, per ARCADE-09). Wrap/wall toggle lives in the **in-game toolbar menu** (`ellipsis.circle`, topBarTrailing — same slot as FiveLetter's strict-mode toggle). Label: "Wall mode: On/Off"; wrap is default.
- **D-12:** Toggling mode mid-run uses the **abandon-alert pattern** from Merge's `requestModeChange` (immediate apply if no progress; confirm-restart alert if food has been eaten). Last choice persists in UserDefaults under key `snake.wallMode` — naming locked, renaming = data break.

### Claude's Discretion

Grid dimensions, cell size, speed-ramp curve/plateau constants, body-ramp cycle length, and the Canvas-vs-LazyVGrid rendering choice remain planner/research tuning constants within the locked constraints above. (Research recommends Canvas; see §Architecture Patterns.)

### Deferred Ideas (OUT OF SCOPE)

- Full score-based stats screen shape for Stack + Snake — Phase 18 (ARCADE-07)
- DESIGN.md §12 entries + Video Mode exemption ADR finalization — Phase 18
- Daily seed / score trend charts / SFX cues — explicitly out of v1.5 scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SNAKE-01 | User can play Snake on a grid — swipe or tap-to-turn changes direction; eating food grows the snake | Engine contract §Pattern 1; direction queue §Pattern 3; swipe + D-pad gesture §Pattern 4 |
| SNAKE-02 | Default mode is wrap (toroidal, calm); a wall-death mode is selectable via toggle | Engine wallMode param; D-11/D-12 toolbar menu + abandon-alert §Pattern 6 |
| SNAKE-03 | On-screen directional D-pad available alongside swipe; both feed a direction queue so rapid turns are not dropped | D-pad component §Pattern 5; queue capacity-2 in VM §Pattern 3 |
| SNAKE-04 | Speed ramps with length then plateaus; colliding with self (and walls in wall mode) ends the run | Engine tickInterval ramp §Pattern 2; collision detection §Pattern 1 |
| SNAKE-05 | Score = food eaten; high score persisted | `GameStats.record()` + `BestScore` §Pattern 7 |
| SNAKE-06 | Renders with DesignKit tokens only; legible under Classic + one Loud/Moody preset (§8.12 audit) | Canvas rendering §Pattern 4; ArcadePalette §Pattern 8 |
| SNAKE-07 | Reduce Motion path — movement is jump-cut between cells (no interpolation) while gameplay unchanged | RM gate §Pattern 4; engine unchanged (view-layer only) |
</phase_requirements>

---

## Summary

Phase 17 makes Snake fully playable end-to-end on the Phase 15 arcade substrate. The architectural hard parts are already settled by Phase 16 (Stack): `ArcadeLoopDriver` delivers clamped dt at 1/60Hz fixed-step, `ArcadeGameState` owns the lifecycle, `VideoModeBanner` surfaces game-over, and `GameStats.record()` persists the score. Snake is structurally Stack's sibling — same substrate, same palette-signature idea, same calm game-over choreography, same "no chrome noise" board.

The genuinely new code is: (1) `SnakeEngine` — a pure Foundation-only struct with discrete grid movement, a seeded-RNG food spawner, and an internal cell-move tick accumulator; (2) `SnakeBoardCanvas` — a `Canvas` view that draws the continuous rounded-path body with Gaffer interpolation and RM jump-cut; (3) a VM-owned capacity-2 direction queue with 180° reversal rejection; (4) a D-pad component following the exact button spec from D-06; (5) a wall-mode toolbar menu with abandon-alert (mirroring FiveLetter + MergeViewModel patterns); and (6) `ArcadePalette` — the StackPalette body-ramp promoted to `Core/` as its second game consumer triggers the 2-game promotion threshold (CLAUDE.md §4).

The Phase 15 success criteria 3 ("zero diff on substrate files") is locked by design: Snake adds no changes to `ArcadeLoopDriver.swift` or `ArcadeGameState.swift`. The 500ms pre-roll, counter-trigger haptics, `feedbackAnimation`, `PressableButtonStyle`, and `chipShadow()` are all consumed exactly as Stack consumes them.

**Primary recommendation:** Build the engine first (gate it with the seed-determinism + ProMotion equivalence unit tests), then the VM + direction queue, then the Canvas board, then the D-pad + swipe gesture, then the toolbar wall-mode toggle, then persistence + score chip. This mirrors the Stack build order and keeps every step gate-checkable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Discrete grid movement, cell-move tick accumulator, collision, food spawn, direction queue | Pure engine (`SnakeEngine`, Foundation-only) | — | Deterministic IP; headlessly testable; mirrors Minesweeper/Merge/Stack purity (CLAUDE.md §4) |
| Fixed-step accumulator (1/60s), VM-owned direction queue (capacity-2), lifecycle, persistence call, event counters | `@Observable @MainActor` VM (`SnakeViewModel`) | — | Owns the loop bridge; SwiftData firewall; direction buffering between cell moves |
| Frame driver (TimelineView), dt clamp, anchor reset | `Core/ArcadeLoopDriver` (consumed as-is) | — | Phase 15 substrate; **zero modifications this phase** (SC3) |
| Board rendering — continuous snake path, Gaffer interpolation, RM jump-cut, food, board well | `Canvas` view (`SnakeBoardCanvas`) | `SnakeGameView` chrome | Immediate-mode draw avoids per-frame view-tree churn; same reason Stack uses Canvas |
| Score chip, D-pad control cluster, idle screen, game-over banner, scenePhase wiring, swipe gesture | `SnakeGameView` (view tree) | — | Chrome updates rarely; separate from 60Hz board state |
| Body color ramp (accent-derived, head-to-tail gradient) | `Core/ArcadePalette` (promoted from `StackPalette`) | — | 2nd game using identical code — 2+ games rule (CLAUDE.md §4) triggers Core/ promotion |
| Score persistence (food eaten → high score) | `GameStats.record()` + `BestScore` (existing, no changes) | `StatsView` @Query reads | ARCADE-05; same write path Stack uses; higher-only semantics correct for endless high score |
| Wall-mode persistence | `UserDefaults` (`snake.wallMode`) | `SnakeViewModel` + toolbar toggle | Simplest non-CloudKit store; consistent with other UserDefaults mode keys in the codebase |
| Stats display card | `SnakeStatsCard` (props-only, `Screens/`) | `StatsView` @Query | Replaces Phase 15 placeholder; StatsView already ~500 lines — separate file mandatory |

---

## Standard Stack

### Core (no new external dependencies)

| Component | Source | Purpose | Why Standard |
|-----------|--------|---------|--------------|
| `ArcadeLoopDriver` + `ArcadeGameState` | `Core/` [VERIFIED: codebase 2026-07-03] | Frame loop, dt clamp, lifecycle enum | Phase 15 substrate; consumed via `.arcadeLoop(isRunning:onTick:)`; zero changes |
| SwiftUI `Canvas` | iOS SDK [CITED: developer.apple.com/documentation/swiftui/canvas] | Immediate-mode snake + board rendering | Same reason Stack uses it: avoids per-frame view-tree churn at 60Hz |
| `TimelineView(.animation(paused:))` | iOS SDK | Time source for Gaffer interpolation FX | Same as StackGameView's board (the animation timer for between-cell lerp) |
| `DragGesture` + `.defersSystemGestures(on: .all)` | SwiftUI iOS 16+ [CITED: developer.apple.com/documentation/swiftui/view/deferssystemgestures(on:)] | Swipe-to-turn + left-edge protection | Required by SC1; `.disableInteractivePop()` on destination disables UIKit pop, `.defersSystemGestures` gives SwiftUI gesture priority |
| `GameStats.record()` + `BestScore` | `Core/GameStats.swift` [VERIFIED: codebase] | Higher-only high score persistence | Already exercised by Stack in Phase 16; no schema change; CloudKit-safe |
| `VideoModeBanner` | `Core/VideoModeBanner.swift` [VERIFIED: codebase] | Game-over surface (death banner) | Fires `.error` haptic on appear; carries restart CTA; same pattern as Stack |
| `DesignKit` tokens: `theme.charts.*`, `accentPrimary`, `success`, `danger`, `surface`, `border`, `background`, `textSecondary` | DesignKit (local SPM) [VERIFIED: codebase] | All Snake colors via tokens only | Token discipline (CLAUDE.md §1); §8.12 audit verifies legibility |
| `PressableButtonStyle` | `Core/PressableButtonStyle.swift` [VERIFIED: codebase] | D-pad button press feedback | Standard interactive-element treatment (D-06) |
| `SurfaceDepth.chipShadow()` | `Core/SurfaceDepth.swift` [VERIFIED: codebase] | D-pad button ambient shadow | Consistent chip/button depth treatment across all games |
| `MotionGate.feedbackAnimation(_:value:)` | `Core/MotionGate.swift` [VERIFIED: codebase] | Animation gate (RM + animationsEnabled combined) | Standard idiom for all feedback animations this phase |
| `.sensoryFeedback` counter-trigger | SwiftUI + `SettingsStore` [VERIFIED: codebase, MergeViewModel] | Haptic triggers (eat, direction enqueue) | Counter-trigger pattern: increment `Int` on VM; view attaches `.sensoryFeedback` |
| `@Environment(\.accessibilityReduceMotion)` | SwiftUI [CITED] | RM jump-cut gate | View-layer only; engine never reads it (engine purity rule) |
| Swift Testing (`@Suite`/`@Test`/`#expect`) | iOS SDK [VERIFIED: existing test target] | Seed-determinism + ProMotion equivalence tests | Matches all existing pure-engine test files in `gamekitTests/` |

### Supporting
| Component | Source | Purpose | When to Use |
|-----------|--------|---------|-------------|
| `inout some RandomNumberGenerator` injection | Swift stdlib | Food spawn seeding | Production: `SystemRandomNumberGenerator()`; tests: SplitMix64 from existing test target |
| `UserDefaults.standard` | Foundation [VERIFIED: existing SettingsStore pattern] | Wall-mode persistence (`snake.wallMode`) | Tiny key-value shape — SwiftData overkill per CLAUDE.md §1 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Canvas` (recommended) | `LazyVGrid` of cell views | LazyVGrid: per-cell view tree updated every cell-move tick. Canvas: direct draw, correct for smooth Gaffer interpolation at 60Hz. **LazyVGrid cannot produce the D-04 smooth-glide effect** — ruled out |
| VM-owned direction queue | Engine-owned queue | Engine is a value type; the VM already owns `pendingDrop` for Stack; VM ownership keeps engine input pure (just receives next direction per cell move) |
| `ArcadePalette` in `Core/` | Duplicate `SnakePalette.swift` with same code | Duplication violates CLAUDE.md §4 (2+ games threshold met). Promote. |
| `BestScore` mode key `"endless"` | New `@Model SnakeScore` | Schema change, CloudKit migration, unnecessary complexity. Existing `BestScore(difficultyRaw: "endless")` handles it cleanly — same path as Stack |

**Installation:** No packages to install. All code is first-party Swift on the existing stack. New files in `Games/Snake/` auto-register via `PBXFileSystemSynchronizedRootGroup` (CLAUDE.md §8.8 — do NOT hand-edit `project.pbxproj`).

---

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages. All code is built from the existing first-party stack (Swift standard library, SwiftUI, SwiftData, DesignKit local SPM, Phase 15 Core substrate). No registry lookups or slopcheck needed.

---

## Architecture Patterns

### System Architecture Diagram

```
 swipe / D-pad tap
       │
       ▼
SnakeGameView.enqueueDirection(_:)
  vm.tryEnqueueDirection(_:)       ← capacity-2, 180° reversal rejected here
  .selection haptic if enqueued    ← D-07: counter-trigger on vm.enqueueCount
       │
       │  .defersSystemGestures(on: .all) on board view
       │  .disableInteractivePop() on destination (Phase 15, still in place)
       │
scenePhase(.inactive/.background) ──> vm.pause()
scenePhase(.active) ──> vm.resume()

.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt:) }
  (TimelineView .animation; dt already clamped min(rawDt, 0.1) in driver)
       │
       ▼
SnakeViewModel.tick(dt)            [@MainActor]
  accumulator += dt                ← VM fixed-step accumulator (1/60s)
  while accumulator >= 1/60:
      let dir = directionQueue.popFirst()     ← pop one direction per step if available
      let frame = engine.step(dt: 1/60, nextDirection: dir)
      accumulator -= 1/60
  on frame.event == .ate:
      eatCount += 1                ← counter-trigger haptic D-08
      if frame.score > bestScore: highScoreCount += 1  ← D-09 mid-run pulse
  on frame.gameOver:
      state = .gameOver
      gameStats?.record(gameKind: .snake, mode: "endless", outcome: .loss,
                        durationSeconds: 0, score: frame.score)
       │
       │  SnakeEngine (pure value type, Foundation only)
       │  step(dt: 1/60, nextDirection:) → SnakeFrame
       │    cellAccumulator += dt
       │    if cellAccumulator >= tickInterval:
       │        apply nextDirection (update currentDirection)
       │        move head one cell (wrap or wall check)
       │        if collision: gameOver = true
       │        if on food: grow tail; spawnFood(using: &rng)
       │        cellAccumulator -= tickInterval
       │        tickInterval = max(minTickInterval, rampedInterval(score))
       │
       ▼
SnakeBoardCanvas (reads vm.body, vm.prevBody, vm.cellMoveAlpha, vm.food, vm.theme)
  Canvas { ctx, size in
      let cellSize = size.width / CGFloat(cols)
      // Board well (border-tinted rounded container, D-03)
      // Body: rounded path segments, colors from ArcadePalette.layer(forIndex:i, theme:)
      // Head: topmost segment + eye dots (theme.colors.background on body fill)
      // Food: circle, food token (accentPrimary or success — §8.12 verified)
      // RM: cellMoveAlpha forced to 0 → jump-cut teleport
      let alpha = reduceMotion ? 0 : vm.cellMoveAlpha
      // Each segment: lerp(prevBody[i], body[i], alpha)
  }

SnakeGameView chrome:
  score chip · idle "swipe or tap D-pad to start" · VideoModeBanner(.loss)
  D-pad cluster (bottom-center, below board)
  toolbar: ellipsis.circle menu → "Wall mode: On/Off" toggle (D-11)

GameStats.record(gameKind:.snake, mode:"endless", ...)
  → BestScore(gameKindRaw:"snake", difficultyRaw:"endless")
  → StatsView @Query snakeBestScores
  → SnakeStatsCard (replaces Phase 15 placeholder)
```

### Recommended Project Structure

```
Games/Snake/
├── SnakeEngine.swift        # pure struct: step(dt:nextDirection:)->SnakeFrame, collision, food spawn (<350 lines)
├── SnakeConfig.swift        # tuning constants (grid dims, speed ramp, min interval) (<60 lines)
├── SnakeViewModel.swift     # @Observable @MainActor: VM accumulator, direction queue, counters, persistence (<220 lines)
├── SnakeBoardCanvas.swift   # Canvas draw: body path, head eyes, food, board well, Gaffer lerp, RM gate (<250 lines)
├── SnakeGameView.swift      # chrome: ZStack, lifecycle, gestures, D-pad, idle, banner, scenePhase (<250 lines)
└── SnakeScoreChip.swift     # props-only score chip (mirrors StackScoreChip) (<50 lines)

Core/
└── ArcadePalette.swift      # PROMOTED from StackPalette — body-ramp layer(forIndex:theme:) (<80 lines)
    StackPalette.swift        # EDITED: becomes a thin forwarding wrapper to ArcadePalette (or deleted with reference updates)

Screens/
└── SnakeStatsCard.swift     # props-only stats card (StatsView is ~500 lines — MUST be own file) (<80 lines)

DELETE: Games/Snake/SnakeHarnessView.swift
EDIT:   Screens/HomeView.swift → swap SnakeHarnessView() for SnakeGameView() (keep NO .videoModeAware per ADR)
EDIT:   Screens/StatsView.swift → replace Phase 15 Snake placeholder with SnakeStatsCard(...)
ADD:    gamekitTests/Games/Snake/SnakeEngineTests.swift
```

---

### Pattern 1: Pure `SnakeEngine` with RNG injection and cell-move tick accumulator (SNAKE-01/04, SC2)

**What:** Foundation-only value type. The engine has TWO time layers: (1) the outer fixed-step loop at 1/60s driven by the VM accumulator, and (2) an internal `cellAccumulator` that fires a cell move once per `tickInterval` (100–200ms). The cell move is the only moment direction changes apply and the only moment food/collision are tested.

**Why a second accumulator:** Decouples "simulation step" (1/60s) from "snake moves" (every 100–200ms). The Gaffer alpha (`cellAccumulator / tickInterval`) drives smooth-glide interpolation in the view — always in [0,1], always maps to exactly one cell-length of motion.

```swift
// Source: codebase-derived; matches StackEngine purity discipline (verified)
import Foundation

struct SnakeCell: Hashable {
    var col: Int
    var row: Int
}

enum SnakeDirection: Equatable {
    case up, down, left, right

    var opposite: SnakeDirection {
        switch self {
        case .up: return .down; case .down: return .up
        case .left: return .right; case .right: return .left
        }
    }
}

enum SnakeEvent: Equatable {
    case none
    case ate(food: SnakeCell)
    case died
}

struct SnakeFrame: Equatable {
    var body: [SnakeCell]         // index 0 = head; last = tail
    var prevBody: [SnakeCell]     // body BEFORE this step's cell move (for Gaffer lerp in view)
    var food: SnakeCell
    var currentDirection: SnakeDirection
    var score: Int                // food eaten count
    var cellMoveAlpha: Double     // cellAccumulator / tickInterval — Gaffer alpha for view
    var gameOver: Bool
    var event: SnakeEvent
}

struct SnakeEngine {
    let cfg: SnakeConfig

    private(set) var body: [SnakeCell]
    private(set) var prevBody: [SnakeCell]
    private(set) var food: SnakeCell
    private(set) var currentDirection: SnakeDirection = .right
    private(set) var score: Int = 0
    private(set) var gameOver: Bool = false

    private var cellAccumulator: Double = 0
    private var tickInterval: Double           // decreases with score, floors at cfg.minTickInterval
    private var rng: any RandomNumberGenerator

    init(cfg: SnakeConfig = .default, rng: some RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.cfg = cfg
        self.rng = rng
        // Starting body: 3 cells moving right at vertical center
        let mid = cfg.rows / 2
        self.body = [SnakeCell(col: 4, row: mid), SnakeCell(col: 3, row: mid), SnakeCell(col: 2, row: mid)]
        self.prevBody = body
        self.tickInterval = cfg.startTickInterval
        self.food = SnakeCell(col: 0, row: 0)
        spawnFood()  // uses rng; mutates self — called after body is set
    }

    /// Called once per fixed-step tick (dt = 1/60s from VM accumulator).
    /// `nextDirection`: the VM pops this from its direction queue; nil = keep current direction.
    mutating func step(dt: Double, nextDirection: SnakeDirection?) -> SnakeFrame {
        guard !gameOver else { return frame(event: .none) }
        cellAccumulator += dt

        // Most steps: no cell move — just advance interpolation alpha.
        guard cellAccumulator >= tickInterval else { return frame(event: .none) }
        cellAccumulator -= tickInterval
        // Update speed: ramp as score grows, then plateau.
        tickInterval = max(cfg.minTickInterval,
                           cfg.startTickInterval - Double(score) * cfg.intervalDecrement)

        // Apply direction (reject 180° reversals — enforced at VM queue level too, but double-checked here)
        if let dir = nextDirection, dir != currentDirection.opposite {
            currentDirection = dir
        }

        prevBody = body   // snapshot for Gaffer interpolation
        // Compute new head
        var newHead = body[0]
        switch currentDirection {
        case .up:    newHead.row -= 1
        case .down:  newHead.row += 1
        case .left:  newHead.col -= 1
        case .right: newHead.col += 1
        }

        // Wrap or wall
        if cfg.wallMode {
            if newHead.col < 0 || newHead.col >= cfg.cols ||
               newHead.row < 0 || newHead.row >= cfg.rows {
                gameOver = true
                return frame(event: .died)
            }
        } else {
            // Toroidal wrap (default)
            newHead.col = (newHead.col + cfg.cols) % cfg.cols
            newHead.row = (newHead.row + cfg.rows) % cfg.rows
        }

        // Self-collision (check against body BEFORE the tail moves)
        let bodyWithoutTail = body.dropLast()
        if bodyWithoutTail.contains(newHead) {
            gameOver = true
            return frame(event: .died)
        }

        // Grow or slide
        if newHead == food {
            body.insert(newHead, at: 0)   // grow: tail stays
            score += 1
            spawnFood()
            return frame(event: .ate(food: food))
        } else {
            body.insert(newHead, at: 0)
            body.removeLast()             // slide: tail retreats
            return frame(event: .none)
        }
    }

    private mutating func spawnFood() {
        let occupied = Set(body)
        var candidates = (0..<cfg.cols).flatMap { c in
            (0..<cfg.rows).map { r in SnakeCell(col: c, row: r) }
        }.filter { !occupied.contains($0) }
        guard !candidates.isEmpty else { return }   // board is full — rare win state
        let idx = Int.random(in: 0..<candidates.count, using: &rng)
        food = candidates[idx]
    }

    private func frame(event: SnakeEvent) -> SnakeFrame {
        SnakeFrame(
            body: body, prevBody: prevBody, food: food,
            currentDirection: currentDirection, score: score,
            cellMoveAlpha: min(cellAccumulator / tickInterval, 1.0),
            gameOver: gameOver, event: event
        )
    }
}
```

**Why `inout some RandomNumberGenerator`:** Matches Minesweeper `BoardGenerator.generate(into:rng:)` discipline. Production passes `SystemRandomNumberGenerator()`; unit tests pass SplitMix64 (already in test target as `SeededGenerator`) for deterministic seed pinning. Keeps engine Foundation-only (no import of a custom seed type from the app target). [VERIFIED: STATE.md line 191, "02-02: SeededGenerator (SplitMix64) test PRNG ships in test target only"]

**Why `prevBody` exposed in the frame:** The view needs both the post-move and pre-move positions to lerp each segment. Embedding this in the frame (rather than storing separately in the VM) keeps the interpolation data co-located with the frame it belongs to. The VM updates its render state from the frame, mirroring Stack's `prevCenterX`/`prevCenterZ` pattern.

---

### Pattern 2: Speed ramp with plateau (SNAKE-04)

```swift
// In SnakeConfig.default (tuning constants — calibrate on device)
static let `default` = SnakeConfig(
    cols: 20,
    rows: 32,
    wallMode: false,                    // wrap is default (SNAKE-02)
    startTickInterval: 0.200,           // 5 moves/sec — calm opening
    minTickInterval:   0.100,           // 10 moves/sec — plateau (CONTEXT "≥100ms tick")
    intervalDecrement: 0.002,           // per food eaten: 0.002s faster until plateau
    // Plateau at (0.200 - 0.100) / 0.002 = 50 food eaten
    fixedDt: 1.0 / 60.0
)
```

`tickInterval` is expressed in **wall-clock seconds** (not frames) — decoupled from frame rate, satisfying the ProMotion equivalence requirement (SC2).

---

### Pattern 3: VM-Owned Direction Queue (Capacity-2, 180° Reversal Rejection)

**What:** The VM holds a `[SnakeDirection]` queue (max 2) separate from the engine. The engine receives one direction per cell move (popped from the queue). Rejected inputs fire silence (D-07).

**Why VM, not engine:** The engine is a value type — `enqueueDirection()` would need to mutate it outside the `step()` call. Keeping the queue in the VM means the view can call `vm.tryEnqueueDirection(.left)` from the gesture handler without going through the fixed-step accumulator loop.

```swift
// In SnakeViewModel (excerpt)
private var directionQueue: [SnakeDirection] = []  // max capacity 2
private let maxQueueDepth = 2
private(set) var enqueueCount: Int = 0             // counter-trigger for .selection haptic

/// Called by swipe gesture handler and D-pad buttons.
/// Returns true if the direction was accepted into the queue.
@discardableResult
func tryEnqueueDirection(_ dir: SnakeDirection) -> Bool {
    // Determine the "effective current direction" — the last item in the queue,
    // or the engine's current direction if queue is empty.
    let effectiveCurrent = directionQueue.last ?? engine.currentDirection
    guard dir != effectiveCurrent.opposite else { return false }  // reject 180°
    guard directionQueue.count < maxQueueDepth else { return false }  // queue full
    directionQueue.append(dir)
    enqueueCount += 1  // fires .selection haptic via .sensoryFeedback in the view
    return true
}

// Inside tick(), when a cell move fires:
let nextDir = directionQueue.isEmpty ? nil : directionQueue.removeFirst()
let frame = engine.step(dt: fixedDt, nextDirection: nextDir)
```

**Opposite-direction D-pad button behaviour:** The button that would cause a 180° reversal renders **enabled** (not grayed out) but `tryEnqueueDirection()` returns false and fires nothing. The queue rule is the single source of truth. D-06 is explicit: "renders enabled but is a no-op at the queue level." This avoids the confusing UX of buttons toggling between enabled/disabled mid-game.

---

### Pattern 4: Canvas Rendering with Gaffer Interpolation + Reduce Motion Jump-Cut (SNAKE-06/07)

**What:** `SnakeBoardCanvas` draws the board well, body, head eyes, and food via `Canvas { ctx, size in ... }`. The Gaffer alpha from the frame drives smooth segment positions between cell moves.

**Body as continuous rounded path** (D-01):

```swift
// Source: SwiftUI Canvas draw pattern (verified: StackBoardCanvas.swift uses same approach)
Canvas { ctx, size in
    let cellSize = size.width / CGFloat(cols)
    let alpha = reduceMotion ? 0.0 : frame.cellMoveAlpha

    // Lerp each segment position
    func segPos(_ i: Int) -> CGPoint {
        let prev = i < prevBody.count ? prevBody[i] : body[i]
        let curr = body[i]
        let lerpCol = Double(prev.col) + (Double(curr.col) - Double(prev.col)) * alpha
        let lerpRow = Double(prev.row) + (Double(curr.row) - Double(prev.row)) * alpha
        return CGPoint(x: (lerpCol + 0.5) * cellSize, y: (lerpRow + 0.5) * cellSize)
    }

    // Draw body as a thick stroked path (line width ≈ 0.8 × cellSize)
    // with rounded caps and joins — produces the D-01 continuous rounded look.
    // Gradient per-segment: draw each segment pair as a separate sub-path
    // colored from ArcadePalette.layer(forIndex: i, theme:).base
    for i in 0..<(body.count - 1) {
        var seg = Path()
        seg.move(to: segPos(i + 1))    // tail → head direction
        seg.addLine(to: segPos(i))
        let layer = ArcadePalette.layer(forIndex: i, theme: theme)
        ctx.stroke(seg, with: .color(layer.base),
                   style: StrokeStyle(lineWidth: cellSize * 0.78,
                                      lineCap: .round, lineJoin: .round))
    }

    // Head square/capsule (last segment, index 0)
    let headPt = segPos(0)
    // Eye dots (D-01): two small circles on the head, offset toward the direction of travel
    // Use theme.colors.background so they're always visible against the body fill
}
```

**Wrap-boundary handling:** When the snake wraps around (toroidal mode), adjacent segments in `body[]` may jump across the board (e.g., col 0 → col 19). The lerp would draw a line across the board. Fix: detect jumps > half the grid width/height and skip the connecting stroke, letting the rounded cap of each segment end cleanly at the edge. [KNOWN PITFALL — see Common Pitfalls §5]

**Under Reduce Motion:** `alpha = 0.0` → every segment renders at `prevBody[i]` positions (its current cell position) — jump-cut per cell move tick. All FX (head pulse on eat, color drain on death) collapse to instant changes via `feedbackAnimation`. SNAKE-07 is satisfied purely by setting `alpha = 0.0` — no engine change, no gameplay change.

---

### Pattern 5: D-Pad Component (SNAKE-03)

**What:** A compact 4-button cross below the board. Reuses all established component primitives (D-06).

```swift
// In SnakeGameView body (below the board, not overlaying it — D-06)
struct SnakeDPad: View {
    let theme: Theme
    let onDirection: (SnakeDirection) -> Void

    var body: some View {
        VStack(spacing: 2) {
            arrowButton(.up,    icon: "chevron.up")
            HStack(spacing: 2) {
                arrowButton(.left,  icon: "chevron.left")
                // Center dead zone (non-interactive, fills the cross gap)
                Color.clear.frame(width: 48, height: 48)
                arrowButton(.right, icon: "chevron.right")
            }
            arrowButton(.down,  icon: "chevron.down")
        }
        .padding(theme.spacing.m)
    }

    private func arrowButton(_ dir: SnakeDirection, icon: String) -> some View {
        Button { onDirection(dir) } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 48, height: 48)   // ≥44pt hit target (D-06)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
                .chipShadow()             // SurfaceDepth.chipShadow()
        }
        .buttonStyle(.pressable)          // PressableButtonStyle
        .accessibilityLabel(Text(dir.accessibilityLabel))
    }
}
```

**Swipe gesture** (D-05):

```swift
// On the board view (SnakeBoardCanvas wrapper in SnakeGameView)
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
.defersSystemGestures(on: .all)   // SC1: left-edge swipe must not pop navigation
```

**Combined with `.disableInteractivePop()`** already applied to the Snake destination in HomeView (Phase 15). Both modifiers are needed: `.disableInteractivePop()` disables the UIKit `interactivePopGestureRecognizer`; `.defersSystemGestures(on: .all)` gives SwiftUI's DragGesture priority over any remaining system gesture recognizers (e.g., iOS system back gesture) within the board area. SC1 verifies this on device.

---

### Pattern 6: Wall-Mode Toggle — Toolbar Menu + Abandon-Alert (SNAKE-02, D-11/D-12)

**Toolbar menu** (FiveLetter `ellipsis.circle` pattern — [VERIFIED: `FiveLetterGameView.swift:186-199`]):

```swift
// In SnakeGameView toolbar (topBarTrailing)
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

**VM abandon-alert pattern** (Merge `requestModeChange` — [VERIFIED: `MergeViewModel.swift:182-200`]):

```swift
// In SnakeViewModel (mirrors MergeViewModel.requestModeChange verbatim)
private(set) var wallMode: Bool = UserDefaults.standard.bool(forKey: "snake.wallMode")
var showingAbandonAlert: Bool = false

func requestWallModeToggle() {
    if engine.score > 0 {          // food has been eaten = meaningful progress
        showingAbandonAlert = true
    } else {
        applyWallModeToggle()      // immediate apply if no progress
    }
}

func confirmWallModeChange() {
    showingAbandonAlert = false
    applyWallModeToggle()
}

func cancelWallModeChange() {
    showingAbandonAlert = false
}

private func applyWallModeToggle() {
    wallMode = !wallMode
    UserDefaults.standard.set(wallMode, forKey: "snake.wallMode")  // D-12: key is locked
    restart()
}
```

The `showingAbandonAlert` Bool binds to `.alert(isPresented:)` in SnakeGameView — same pattern as MergeGameView.

---

### Pattern 7: Score Persistence — `GameStats.record()` + `BestScore` (SNAKE-05, ARCADE-05)

**No new schema elements.** Snake reuses the exact same `GameStats.record(gameKind:mode:outcome:score:)` + `evaluateBestScore` path that Stack exercises in Phase 16. [VERIFIED: `GameStats.swift:113-289`]

```swift
// In SnakeViewModel, on game-over transition:
try? gameStats?.record(
    gameKind: .snake,
    mode: "endless",      // PERMANENT SERIALIZATION KEY — renaming = data break
    outcome: .loss,       // snake runs always end in loss (SC ARCADE-03)
    durationSeconds: 0,   // endless games don't track duration
    score: engine.score   // food eaten count (SNAKE-05)
)
```

The `BestScore(gameKindRaw:"snake", difficultyRaw:"endless")` row is written/updated by `evaluateBestScore` (higher-only semantics — correct for endless high score). `resetAll()` already deletes all `BestScore` rows — no explicit Snake clear needed. [VERIFIED: `GameStats.swift:175-185`]

**StatsView read path** already has `snakeBestScores` and `snakeRecords` @Query pairs (Phase 15 wiring — [VERIFIED: `StatsView.swift:138-145`]). SnakeStatsCard uses them:

```swift
// SnakeStatsCard (props-only, mirrors StackStatsCard shape)
let highScore = bestScores.first { $0.difficultyRaw == "endless" }?.score
let runsPlayed = records.count
```

---

### Pattern 8: ArcadePalette — Promoted from StackPalette (D-02, CLAUDE.md §4)

Stack uses `StackPalette.layer(forIndex:theme:)` for its per-block gradient. Snake uses an identical body-ramp function. Two games = the 2+ games promotion threshold (CLAUDE.md §4).

**Action:** Create `Core/ArcadePalette.swift` by moving the content of `StackPalette.swift`. Update `Games/Stack/StackPalette.swift` to forward to `ArcadePalette` (thin wrapper or typealias). Snake uses `ArcadePalette.layer(forIndex:theme:)` directly.

For Snake's body: `i = 0` is the head (most saturated — `chart1`), `i = body.count - 1` is the tail (least saturated). This produces the D-02 "head darkest, fading toward tail" effect using the same cycle as Stack's tower.

```swift
// Core/ArcadePalette.swift (extracted from StackPalette.swift verbatim)
import SwiftUI
import DesignKit

/// Accent-derived per-segment body/block color ramp for arcade games.
/// Consumed by Stack (per tower layer) and Snake (per body segment).
/// Layer.base + Layer.next + Layer.blend enable alpha-blend lerp
/// between adjacent chart tokens for smooth gradients using only tokens.
enum ArcadePalette {
    static let segmentsPerStop = 4   // (was blocksPerStop in StackPalette)
    struct Layer { let base: Color; let next: Color; let blend: Double }

    static func layer(forIndex i: Int, theme: Theme) -> Layer {
        // ... identical implementation to current StackPalette.layer(forIndex:theme:)
    }
}
```

---

### Anti-Patterns to Avoid

- **Velocity-based wrap-around segment lerp:** When a snake segment wraps from col 19 → col 0, the `prevBody` col is 19 and `body` col is 0. Naively lerping produces a line drawn diagonally across the board. Detect column/row jumps > half the grid size and draw each wrapped endpoint as a separate capsule end instead of a connected line. [KNOWN PITFALL — §5]
- **Engine importing SwiftUI or UIKit:** Engine must be Foundation-only. No `CGPoint`, no `Date.now`, no `CGFloat` in the engine. Use `Int` (col/row) for cells, `Double` for time. The view maps ints to screen points. [CLAUDE.md §4]
- **Second dt clamp in VM or engine:** `ArcadeLoopDriver` already clamps `min(rawDt, 0.1)`. Adding another clamp breaks the single-source invariant. [VERIFIED: ArcadeLoopDriver.swift]
- **Saving per tick:** `GameStats.record()` is called exactly once on the `.gameOver` transition, not per tick, not per food eaten. [Phase 16 Pitfall / ARCADE-05]
- **`.videoModeAware()` on Snake destination:** Snake is exempt per ADR (ARCADE-08 + Amendment 2026-07-02). The Amendment explicitly confirms "Snake remains exempt." HomeView destination: `SnakeGameView().disableInteractivePop()` only — no `.videoModeAware()`. [VERIFIED: 15-VIDEO-MODE-ADR.md + HomeView.swift:401-402]
- **Touching `Core/ArcadeLoopDriver.swift` or `Core/ArcadeGameState.swift`:** SC3 requires a zero diff on these files post-Phase 17. The substrate is consumed exactly as Phase 15 delivered it. [CONTEXT SC3]
- **Hardcoded `Color(red:)` / `Color(hex:)` / system names in `Games/Snake/`:** The pre-commit hook checks Games/ and Screens/. All snake colors via DesignKit semantic tokens or `ArcadePalette.layer()`. [CLAUDE.md §1, §8.7]
- **Publishing the whole SnakeFrame at 60Hz through @Observable:** Separate render state (Canvas reads engine snapshot + Gaffer alpha) from chrome state (score, gameOver, counters) so the score chip doesn't re-layout 60×/sec. Mirror Stack's `frame` + `prevCenterX` pattern. [Phase 16 Pitfall 16]
- **Direction queue in the engine:** Engine is a value type; direction enqueueing from the gesture handler happens outside the `step()` call. VM owns the queue; engine receives `nextDirection: SnakeDirection?` per cell move. [Pattern 3]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Frame loop / dt clamp | Custom CADisplayLink or Timer | `Core/ArcadeLoopDriver` via `.arcadeLoop(isRunning:onTick:)` | Phase 15 substrate; Swift 6 Sendable-clean; clamp already inside |
| Fixed-step accumulator | Variable dt to engine | VM accumulator at 1/60s (harness pattern) | Frame-rate-independent cell moves; SC2 ProMotion equivalence |
| Cell-move timing | Frame count (`if tickCount % 12`) | Seconds-based `cellAccumulator` in engine | Frame-rate dependent → fails SC2; sweeps/sec equivalent for Snake |
| Higher-only score store | New @Model or hand-rolled max | `GameStats.evaluateBestScore` + `BestScore` | CloudKit-safe; tested; write-once on game-over; already used by Stack |
| Game-over banner | Custom banner component | `Core/VideoModeBanner(outcome:.loss)` | Fires `.error` haptic on appear; a11y announce; gated transitions built in |
| Body color ramp | `Color(hue:saturation:brightness:)` math | `ArcadePalette.layer(forIndex:theme:)` | Accent-derived ramp computed by DesignKit; token discipline |
| 180° direction guard | Custom per-view check | VM `tryEnqueueDirection()` as single source of truth | One guard for both swipe and D-pad; D-06 explicit: "queue rule is the single source of truth" |
| Mode-change disruption | Immediate restart on toggle | `requestWallModeToggle()` + abandon-alert | Mirrors MergeViewModel pattern; preserves in-progress runs below score-0 threshold |
| Swipe-conflict with nav | `highPriorityGesture` | `.defersSystemGestures(on: .all)` + existing `.disableInteractivePop()` | Correct modern SwiftUI API for SC1; `.disableInteractivePop()` already on destination |

**Key insight:** Snake's genuinely new code is the grid engine and the Canvas board draw. Every surrounding concern — loop, lifecycle, persistence, haptics, banner, reset — reuses a proven component from Phase 15 or Phase 16.

---

## Common Pitfalls

### Pitfall 1: Segment lerp across wrap boundary
**What goes wrong:** In toroidal mode, the snake's head wraps from col 19 → col 0. `prevBody[0].col = 19`, `body[0].col = 0`. Lerp at alpha=0.5 puts the head at col 9.5 — the CENTER of the board — drawing a horizontal stroke across the entire grid.
**Why it happens:** The lerp doesn't know the domain is periodic (it's just linear interpolation of int coordinates).
**How to avoid:** In `SnakeBoardCanvas.segPos()`, detect if `abs(curr.col - prev.col) > cols / 2` or `abs(curr.row - prev.row) > rows / 2`. If so, skip the connecting stroke (draw each endpoint with a rounded cap, both at the edge); OR for `prevBody` at the boundary, wrap the prev coordinate: `let adjustedPrev = SnakeCell(col: prev.col + (curr.col < prev.col ? cols : -cols), row: prev.row)` — adjust so the lerp travels the short way.
**Warning signs:** Unit tests pass but visual playtest shows diagonal streak across the board on every wrap event.

### Pitfall 2: Missing `.inactive` in scenePhase handler
**What goes wrong:** `.inactive` is not handled — a notification banner triggers `.inactive` (not `.background`). The 2-second banner gap is injected as dt on resume. The `ArcadeLoopDriver` clamp reduces it to 0.1s but the snake still experiences a false multi-cell-move burst.
**Prevention:** Both `.inactive` AND `.background` call `vm.pause()`. Same handler. [VERIFIED: Pattern 4 in 15-RESEARCH.md]
**Warning signs:** After dismissing a notification banner, the snake visibly jumps forward.

### Pitfall 3: ProMotion divergence from frame-count-based timing
**What goes wrong:** `tickInterval` expressed as "N frames" rather than seconds. At 120Hz the snake moves 2× faster.
**Prevention:** `tickInterval` is in seconds (`Double`). `cellAccumulator += dt` where `dt = 1/60.0`. This is identical at any frame rate because the VM's outer fixed-step loop guarantees consistent dt. [SC2 test catches this]

### Pitfall 4: Engine purity violation
**What goes wrong:** `SnakeEngine.swift` imports SwiftUI for `CGPoint` or accesses `Date.now` for timing.
**Prevention:** All coordinates are `Int` (col/row). All time is `Double` (seconds). The view maps `SnakeCell` → `CGPoint` using `cellSize`. Verify: `grep "import SwiftUI\|import UIKit\|CGFloat\|CGPoint\|Date.now" Games/Snake/SnakeEngine.swift` returns empty.

### Pitfall 5: Direction queue ignoring tail-direction reversal check
**What goes wrong:** Queue has [.left] pending. User taps .right (a 180° reversal of .left, which the snake will turn to next). The guard `dir != effectiveCurrent.opposite` should use `directionQueue.last ?? engine.currentDirection` as the effective current direction — but if the check accidentally uses only `engine.currentDirection`, a right tap after a queued left is accepted, causing a self-collision on the next cell move.
**Prevention:** `tryEnqueueDirection()` checks against `directionQueue.last ?? engine.currentDirection` — not just `engine.currentDirection`. The queue's last entry is the "pending" direction. [Pattern 3]

### Pitfall 6: 180° reversal check at wrong time
**What goes wrong:** The D-pad opposite-direction button (D-06 says it renders enabled) fires `tryEnqueueDirection()` which should reject silently. If the reject returns and the haptic still fires because the counter is incremented before the guard, `enqueueCount` increments spuriously.
**Prevention:** `enqueueCount += 1` is INSIDE the guard (after the rejection checks), not before. No haptic fires on rejected input (D-07: "Rejected inputs fire nothing").

### Pitfall 7: Monolithic file over file-size cap
**What goes wrong:** All game logic crammed into one SnakeGameView.swift — exceeds the §8.5 hard cap (500 lines).
**Prevention:** Six-file split per §Recommended Project Structure. `SnakeBoardCanvas.swift`, `SnakeScoreChip.swift`, `SnakeStatsCard.swift` are all separate files. Verify: `wc -l Games/Snake/*.swift Screens/SnakeStatsCard.swift` all < 400.

---

## Code Examples

### SC2 ProMotion Equivalence Test (seed-determinism + frame-rate independence — the Phase 17 gate)

```swift
// Source: Swift Testing pattern (codebase: ArcadeLoopDriverTests.swift / StackEngineTests.swift shape)
import Testing
import Foundation
@testable import gamekit

@Suite("SnakeEngine determinism")
nonisolated struct SnakeEngineTests {

    /// SC2a: same pinned seed → identical food-spawn sequences and outcomes across two runs.
    @Test("seed determinism: two identical seeds produce identical frame sequences")
    func seedDeterminism() throws {
        // SplitMix64 (SeededGenerator) is in the test target — inject same seed twice.
        var rng1 = SeededGenerator(seed: 42)
        var rng2 = SeededGenerator(seed: 42)
        var e1 = SnakeEngine(cfg: .testFixed, rng: rng1)
        var e2 = SnakeEngine(cfg: .testFixed, rng: rng2)

        // Simulate 10 seconds of play with a fixed direction sequence
        let dirs: [SnakeDirection?] = [nil, .up, nil, nil, .right, nil, nil, .down, nil, nil]
        let stepsPerSec = 60
        var dirIdx = 0

        for step in 0..<(10 * stepsPerSec) {
            let dir = step % stepsPerSec == 0 && dirIdx < dirs.count ? dirs[dirIdx++] : nil
            let f1 = e1.step(dt: 1.0/60.0, nextDirection: dir)
            let f2 = e2.step(dt: 1.0/60.0, nextDirection: dir)
            #expect(f1.food == f2.food)
            #expect(f1.body == f2.body)
            #expect(f1.gameOver == f2.gameOver)
            if f1.gameOver { break }
        }
        #expect(e1.score == e2.score, "identical scores after identical inputs")
    }

    /// SC2b: ProMotion equivalence — 60Hz steps vs 120Hz steps over 5s, same direction queue,
    /// same seed → identical cell-move count and collision state.
    @Test("ProMotion equivalence: dt=1/60 vs dt=1/120 produce same cell-move count")
    func proMotionEquivalence() {
        let eatTimes: [Double] = []   // no direction changes — straight run
        func run(fixedDt: Double) -> (score: Int, gameOver: Bool) {
            var rng = SeededGenerator(seed: 99)
            var e = SnakeEngine(cfg: .testFixed, rng: rng)
            let steps = Int((5.0 / fixedDt).rounded())
            for _ in 0..<steps {
                _ = e.step(dt: fixedDt, nextDirection: nil)
                if e.gameOver { break }
            }
            return (e.score, e.gameOver)
        }
        let r60  = run(fixedDt: 1.0/60.0)
        let r120 = run(fixedDt: 1.0/120.0)
        #expect(r60.score    == r120.score)
        #expect(r60.gameOver == r120.gameOver)
    }

    @Test("wall collision ends game in wall mode")
    func wallCollision() {
        var rng = SeededGenerator(seed: 1)
        var cfg = SnakeConfig.testFixed; cfg.wallMode = true; cfg.cols = 5; cfg.rows = 5
        var e = SnakeEngine(cfg: cfg, rng: rng)
        // Force snake to hit the right wall by stepping right repeatedly
        let maxSteps = 1000
        for _ in 0..<maxSteps {
            let f = e.step(dt: 1.0/60.0, nextDirection: .right)
            if f.gameOver { return }  // expected
        }
        #expect(Bool(false), "Expected wall collision but snake never died")
    }

    @Test("wrap mode: head exits right edge and re-enters left")
    func toroidalWrap() {
        var rng = SeededGenerator(seed: 2)
        var cfg = SnakeConfig.testFixed; cfg.wallMode = false; cfg.cols = 10; cfg.rows = 10
        var e = SnakeEngine(cfg: cfg, rng: rng)
        // Keep stepping right — head should wrap from col 9 to col 0 without dying
        var wrapped = false
        for _ in 0..<1000 {
            let prevHead = e.body[0]
            _ = e.step(dt: 1.0/60.0, nextDirection: .right)
            if prevHead.col == cfg.cols - 1 && e.body[0].col == 0 { wrapped = true; break }
            if e.gameOver { break }
        }
        #expect(wrapped, "Snake must wrap from last column to first without dying")
    }

    @Test("self-collision ends the run")
    func selfCollision() { /* drive snake into a U-turn that it collides with itself */ }
}
```

### Persistence Test (extends existing GameStatsTests in-memory container pattern)

```swift
// Source: codebase GameStatsTests.swift pattern (verified: Phase 16 adopted same shape)
@Test("Snake record: one GameRecord (endless) + one BestScore row; higher-only for best")
func recordSnakeRunHigherOnly() throws {
    let (stats, ctx, _) = try makeStats()
    try stats.record(gameKind: .snake, mode: "endless", outcome: .loss,
                     durationSeconds: 0, score: 15)
    let records = try ctx.fetch(FetchDescriptor<GameRecord>(
        predicate: #Predicate { $0.gameKindRaw == "snake" }))
    #expect(records.count == 1)
    let best = try ctx.fetch(FetchDescriptor<BestScore>(
        predicate: #Predicate { $0.gameKindRaw == "snake" }))
    #expect(best.first?.score == 15)
    // Lower score does not overwrite
    try stats.record(gameKind: .snake, mode: "endless", outcome: .loss,
                     durationSeconds: 0, score: 8)
    let best2 = try ctx.fetch(FetchDescriptor<BestScore>(
        predicate: #Predicate { $0.gameKindRaw == "snake" && $0.difficultyRaw == "endless" }))
    #expect(best2.first?.score == 15, "higher-only: best stays 15, not 8")
}
```

---

## Tuning Constants (MEDIUM confidence — calibrate on device)

`SnakeConfig.default` starting values; treat as a play-test baseline. All time-unit based (never frame counts).

| Constant | Default | Rationale | Confidence |
|----------|---------|-----------|------------|
| `cols` | `20` | Standard Snake column count; cells ≈ 17pt on 375pt board | MEDIUM |
| `rows` | `32` | Uses vertical space (650pt ÷ 20px ≈ 32 rows) | MEDIUM |
| `startTickInterval` | `0.200s` (5 moves/sec) | Calm opening; ~2 sec to cross the board | MEDIUM |
| `minTickInterval` | `0.100s` (10 moves/sec) | CONTEXT: "≥100ms tick" — this is the floor | HIGH (locked by CONTEXT) |
| `intervalDecrement` | `0.002s per food` | Plateau at 50 food eaten: (200-100)/2 | MEDIUM |
| `startLength` | 3 cells | Standard snake starting length | MEDIUM |
| `ramp palette cycle` | `ArcadePalette.segmentsPerStop = 4` | Cycles chart1→6 every 4 segments | MEDIUM |
| `body stroke width` | `cellSize × 0.78` | Leaves ~11% inter-segment gap for visual separation | MEDIUM |
| `game-over pre-roll` | `500ms` | DESIGN.md §10.3 "Game over = 500ms" | HIGH |
| `fixedDt` (VM step) | `1.0/60.0` | Research-locked sim rate (matches Stack) | HIGH |

---

## State of the Art

| Old Approach | Current Approach | Applied In | Impact |
|--------------|------------------|------------|--------|
| Frame-count timer (`if tickCount % 12`) | Seconds-based `cellAccumulator` in engine | SNAKE-04 / SC2 | ProMotion-safe; same cell speed on 60Hz and 120Hz |
| CADisplayLink + per-frame timer | `TimelineView(.animation)` via ArcadeLoopDriver | ARCADE-01 | Swift 6 actor-safe; already proven by Phase 15 |
| Separate @Model for arcade high score | Reuse `BestScore(difficultyRaw:"endless")` | ARCADE-05 | Zero schema change; CloudKit-safe; matches Stack |
| Bool toggle for haptic trigger | Incrementing Int counter (counter-trigger) | ARCADE-06 | Rapid multi-fire safe; established pattern |
| Screen shake on death | No shake (banned) | D-10 | Brand rule — shake is reserved for wrong-move board games (DESIGN §10.2) |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Speed ramp tuning constants (start/min interval, decrement) produce a "calm then challenging" feel that's on-brand | Tuning Constants | Game feels too fast/slow; mitigated by on-device play-test before §12.5 sign-off. Pure tuning, no architectural impact |
| A2 | `SnakeConfig.testFixed` (a minimal-grid variant for fast unit tests) can use a small grid (e.g., 10×10) without the wrap-lerp pitfall impacting test correctness | Code Examples | If test config triggers wrap-lerp in assertions, add explicit wrap-detection to `SnakeFrame.body` comparison or use a non-wrapping test config |
| A3 | `Int.random(in:using:)` with the engine's `rng` produces deterministic sequences across Swift versions for the same SplitMix64 seed | Pattern 1 | Swift stdlib may change Int.random implementation; mitigated by using an explicit SplitMix64 bit-extraction rather than `Int.random(in:using:)` if test proves flaky |
| A4 | `ArcadePalette.layer(forIndex:0, theme:)` produces the "darkest/most saturated" end of the ramp (head) on all presets | Pattern 8 | For some presets chart1 may not be the most saturated; §8.12 audit will catch this; planner can reverse the index mapping if needed |

**All load-bearing claims (substrate contract, persistence path, token availability, ADR exemption) are VERIFIED against live source — not in this table.**

---

## Open Questions (RESOLVED)

1. **Food token: `accentPrimary` vs `success`**
   - What we know: D-02 says planner picks after checking §8.12 contrast. Food must be "clearly contrasting" against the body ramp (which uses `charts.chart1…6`).
   - What's unclear: under which preset does each token fail to contrast. This requires a visual audit on Classic (Chrome Diner) + Voltage/Dracula.
   - Recommendation: start with `success` (a distinct semantic: "positive event, not player choice") and verify in §8.12 pass. If `success` is too close to `charts.chart2` on a specific Loud preset, switch to `accentPrimary` for that comparison only, but keep `success` as the default (color is never the only channel — food is a CIRCLE vs body path).
   - RESOLVED: Plan 17-04 T1 adopts `theme.colors.success` as the default food fill; the §8.12 checkpoint in Plan 17-05 T3 may flip to `accentPrimary` if a preset fails contrast.

2. **ArcadePalette promotion: refactor Stack or forward-wrapper?**
   - What we know: both approaches satisfy the 2+ games rule. Forward-wrapper keeps StackPalette intact (zero Stack file changes). Full promotion removes duplication entirely.
   - Recommendation: Use a forward-wrapper in Phase 17 to minimize Stack regression risk. The wrapper is 3 lines: `typealias StackPalette = ArcadePalette` plus a `blocksPerStop` alias. If Phase 18 touches Stack for any reason, do the full rename then.
   - RESOLVED: Plan 17-02 implements the forward-wrapper (`typealias StackPalette = ArcadePalette` shim); full rename deferred to a future phase that touches Stack.

3. **Wrap-boundary lerp: skip stroke or adjust coordinates?**
   - What we know: both approaches prevent the diagonal-streak artifact. Skip-stroke is simpler but leaves a tiny visual gap at the boundary. Coordinate adjustment is invisible but slightly more complex.
   - Recommendation: Skip-stroke with rounded caps. The rounded cap on each endpoint at the boundary naturally reads as "the snake disappears at the edge and reappears on the other side," which is the correct toroidal metaphor. The gap is at the boundary pixel — imperceptible at normal cell sizes.
   - RESOLVED: Plan 17-04 T2 implements skip-stroke with rounded caps; visual confirmation folded into the Plan 17-05 T3 human-verify checkpoint.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ (objectVersion 77) | PBXFileSystemSynchronizedRootGroup auto-reg | ✓ | Confirmed (§8.8 validated Phase 16) | — |
| iOS 17 Simulator | Unit tests + manual play | ✓ | Project target iOS 17+ | — |
| `SwiftUI.View.defersSystemGestures(on:)` | SC1 board swipe | ✓ | iOS 16+ API (project targets 17+) | — |
| Real device (iPhone) | SC1 left-edge swipe verification | Must confirm | — | Simulator approximate; device required for SC1 confidence |
| SeededGenerator (SplitMix64) | SC2 seed-determinism test | ✓ | Already in `gamekitTests` target | — |

**Missing dependencies with no fallback:** Real device for SC1 verification. The Simulator cannot fully replicate the iOS navigation back gesture conflict that `.defersSystemGestures(on: .all)` solves.

---

## Validation Architecture

`workflow.nyquist_validation: true` in `.planning/config.json` — section required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`) [VERIFIED: existing test target] |
| Config file | None separate — Xcode test scheme `gamekitTests` |
| Quick run command | `xcodebuild test -scheme gamekit -only-testing:gamekitTests/SnakeEngineTests -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req / SC | Behavior | Method | Automated Command / Recipe | Exists? |
|----------|----------|--------|----------------------------|---------|
| SNAKE-01 / SC1 | Swipe / D-pad changes direction; eating food grows snake; left-edge swipe doesn't pop nav | unit (direction queue) + manual | `SnakeEngineTests` + manual device swipe test | ❌ Wave 0 |
| SNAKE-02 | Wrap (default) and wall-death mode selectable; persisted in UserDefaults | unit + manual | `SnakeEngineTests.toroidalWrap` + `wallCollision` + manual toggle | ❌ Wave 0 |
| SNAKE-03 / SC4 | D-pad visible + operational; rapid turns buffered; 180° reversal rejected; queue capacity-2 | unit (VM queue) + manual | VM queue unit test + manual D-pad verification | ❌ Wave 0 |
| SNAKE-04 | Speed ramps then plateaus at ≥100ms tick; self/wall collision ends run | unit | `SnakeEngineTests.selfCollision` + `proMotionEquivalence` | ❌ Wave 0 |
| SNAKE-05 | Score = food eaten; high score persisted once on game-over; higher-only | unit (persistence) | `GameStatsTests.recordSnakeRunHigherOnly` | ❌ Wave 0 |
| SC2 | dt=1/60 ≡ dt=1/120 over 5s simulated; same seed → identical outcomes | unit | `SnakeEngineTests.proMotionEquivalence` + `seedDeterminism` | ❌ Wave 0 |
| SNAKE-06 / §8.12 | Token-only colors; legible Classic + Voltage/Dracula | grep gate + manual audit | `grep -rn "Color(red:\|Color(hex:\|\.green\b" Games/Snake/` empty + visual audit | grep ✅ / visual ❌ manual |
| SNAKE-07 / SC5 | Reduce Motion: jump-cut movement; gameplay identical | manual | Simulator → Accessibility → Reduce Motion; play a run | ❌ manual |
| SC3 | Zero diff on `ArcadeLoopDriver.swift` + `ArcadeGameState.swift` | git gate | `git diff HEAD~N -- Core/ArcadeLoopDriver.swift Core/ArcadeGameState.swift` empty | ✅ gate (structural) |
| Engine purity | No SwiftUI/SwiftData in SnakeEngine | grep gate | `grep -rn "import SwiftUI\|import UIKit\|CGFloat\|modelContext" Games/Snake/SnakeEngine.swift` empty | ✅ gate |
| File caps | All Snake files < 400 lines | wc gate | `wc -l Games/Snake/*.swift Screens/SnakeStatsCard.swift` | ✅ gate |
| No dupe files | No `* 2.swift` | git check | `git status` shows no `?? *2.swift` (CLAUDE.md §8.7) | ✅ gate |

### Sampling Rate

- **Per task commit:** `SnakeEngineTests` + `GameStatsTests` quick run (deterministic, <10s)
- **Per wave merge:** Full `gamekitTests` suite green
- **Phase gate:** Full suite green + SC1 device swipe test + §8.12 theme audit + Reduce Motion recipe + `git diff` SC3 check before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `gamekitTests/Games/Snake/SnakeEngineTests.swift` — covers SNAKE-01/02/04 + SC2 (seed determinism, ProMotion, wrap, wall, self-collision)
- [ ] `gamekitTests/Core/GameStatsTests.swift` — add `recordSnakeRunHigherOnly` (SNAKE-05)
- [ ] `Core/ArcadePalette.swift` — extract from StackPalette before Snake references it
- [ ] Framework install: none — Swift Testing + `gamekitTests` target already exist

---

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (treat as enabled). Snake's attack surface is effectively nil — offline, local-only, single-player game with no user-input parsing beyond directional swipes.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Offline game; no auth surface |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | Local single-user |
| V5 Input Validation | minimal | Direction enum (only 4 values); `tryEnqueueDirection()` rejects 180° reversals; dt clamped by ArcadeLoopDriver |
| V6 Cryptography | no | No crypto; never hand-rolled |
| V9 Data Protection | minimal | Scores via SwiftData/CloudKit (iOS encrypted at rest); no PII; `UserDefaults` stores one Bool (`snake.wallMode`) — not sensitive |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale SwiftData store crash | Denial of Service (self) | Phase adds NO new @Model → no migration risk; CLAUDE.md §8.9 runbook for stale simulator store |
| Unknown GameKind raw value | Tampering (local) | Existing safe-fallback on `BestScore.gameKind` (unknown rows are filtered by `gameKindRaw == "snake"` predicate, not panic) |
| UserDefaults `snake.wallMode` tampering | Tampering (local) | Bool with a known good default (`false` = wrap mode); no gameplay security implications |

---

## Sources

### Primary (HIGH confidence — codebase-verified 2026-07-03)

- `Core/ArcadeLoopDriver.swift` — dt clamp `min(rawDt, 0.1)`, anchor reset on `isRunning` change
- `Core/ArcadeGameState.swift` — `idle/running/paused/gameOver` enum
- `Core/GameStats.swift` — `record(gameKind:mode:outcome:score:)` (L113), `evaluateBestScore` higher-only (L261-289), `resetAll` deletes BestScore (L175-185)
- `Core/VideoModeBanner.swift` — `.error` haptic on appear, gated Bool inputs, vertically-centered placement
- `Core/MotionGate.swift` — `feedbackAnimation(_:value:)` modifier (RM + animationsEnabled)
- `Core/PressableButtonStyle.swift` — `.pressable` / `.pressableSubtle` ButtonStyle
- `Core/SurfaceDepth.swift` — `chipShadow()`, `SurfaceDepth.raisedSheen`, `activeGlow()`
- `Core/SwipeBackDisabler.swift` — `.disableInteractivePop()` already on Snake destination
- `Games/Stack/StackPalette.swift` — `layer(forIndex:theme:)` function to be promoted to ArcadePalette
- `Games/Stack/StackViewModel.swift` — `@Observable @MainActor`, accumulator pattern, counter-trigger haptics, `attachGameStats()`
- `Games/Stack/StackGameView.swift` — chrome skeleton, `coreStack()`, `arcadeLoop`, scenePhase wiring, `videoModeAware` (Snake omits this per ADR)
- `Games/Stack/StackGameView+Chrome.swift` — back chevron, idle content, score overlay pattern
- `Games/Stack/StackScoreChip.swift` — score chip shape to mirror for `SnakeScoreChip`
- `Games/Snake/SnakeHarnessView.swift` — throwaway to delete; confirms harness VM shape
- `Games/Words/FiveLetter/FiveLetterGameView.swift:186-199` — `ellipsis.circle` toolbar menu pattern (D-11)
- `Games/Merge/MergeViewModel.swift:182-200` — `requestModeChange` abandon-alert pattern (D-12)
- `Screens/HomeView.swift:400-403` — Snake destination (SnakeHarnessView, to be swapped; NO `.videoModeAware`)
- `Screens/StatsView.swift:138-145, 228-237` — existing `snakeBestScores`/`snakeRecords` @Query pairs + Phase 15 placeholder (to be replaced by SnakeStatsCard)
- `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md` — Snake remains exempt; ADR amendment 2026-07-02
- `.planning/phases/15-arcade-substrate-skeleton/15-RESEARCH.md` — substrate patterns, ArcadeLoopDriver contract
- `.planning/phases/16-stack/16-RESEARCH.md` — Stack adoption patterns, D-11 persistence path, Canvas rendering precedents

### Secondary (MEDIUM confidence — cited from official docs/prior research)

- Apple Developer — `View.defersSystemGestures(on:)` iOS 16+, `Canvas`, `DragGesture`, `accessibilityReduceMotion`, `scenePhase`, `TimelineView`
- DESIGN.md §3.0 (depth rules), §6 (toolbar back chevron), §8 (haptic vocabulary), §10 (animation vocabulary, §10.3 pre-roll timing), §12.5 (new-game checklist)
- CLAUDE.md §1 (token discipline), §4 (engine purity + 2-game promotion rule), §8.1/§8.5 (file size caps), §8.7 (no dupe files), §8.8 (pbxproj), §8.12 (§8.12 theme audit), §8.14 (release log)

### Tertiary (LOW confidence — verify empirically)

- Grid dimensions (20×32) and speed-ramp constants — reasonable starting values; calibrate on device
- Wrap-boundary lerp approach (skip-stroke) — visually plausible; confirm in playtest

---

## Metadata

**Confidence breakdown:**
- Engine contract & determinism: HIGH — value-type pure engine mirrors existing engines; cell-move accumulator pattern is well-understood
- Substrate consumption: HIGH — ArcadeLoopDriver and ArcadeGameState consumed as-is; zero modifications allowed (SC3)
- Persistence path: HIGH — identical to Stack's Phase 16 path; verified against live `GameStats.swift`
- Canvas rendering / Gaffer interpolation: HIGH — same pattern as StackBoardCanvas; wrap-boundary lerp handling is Medium (verify in playtest)
- Direction queue / gesture handling: HIGH — VM pattern well-specified; `.defersSystemGestures` API is iOS 16+ (target is 17+)
- Tuning constants: MEDIUM — reasonable defaults; device calibration required

**Research date:** 2026-07-03
**Valid until:** ~2026-08-03 (stable first-party Apple APIs; no fast-moving external dependencies)
