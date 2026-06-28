# Phase 16: Stack - Research

**Researched:** 2026-06-27
**Domain:** Real-time tap-to-drop tower game on the Phase 15 arcade substrate (Swift 6 / SwiftUI `Canvas` / pure value-type engine / SwiftData score persistence / DesignKit tokens)
**Confidence:** HIGH on engine contract, persistence path, rendering, and feedback wiring (all codebase-verified); MEDIUM on speed-ramp and combo tuning constants (device-calibration values, flagged for play-test)

## Summary

This phase makes Stack fully playable on the substrate proven in Phase 15. The hard architecture is already settled in `STACK.md` (frame driver, fixed-timestep accumulator in the VM, `Canvas` rendering, tap-to-drop, lifecycle, save-on-game-over). The substrate ships exactly as `STACK.md` describes and is **codebase-confirmed**: `ArcadeLoopDriver` already clamps `dt` to `min(rawDt, 0.1)` and resets its anchor on every `isRunning` transition (`ArcadeLoopDriver.swift:42,47-53`), so the engine and VM add **no second clamp**. The VM owns the fixed-timestep accumulator exactly as the throwaway `StackHarnessVM` already demonstrates (`StackHarnessView.swift:45-71`).

The four genuine Phase-16 gaps resolve cleanly against the real source: (1) **D-11 best-perfect-streak persistence** is solved with zero schema change by writing it as a second `BestScore` row under a distinct mode key, reusing the existing higher-only `evaluateBestScore` (`GameStats.swift:261-289`); (2) the **`StackEngine` contract** is a pure `struct` with closed-form oscillation on accumulated sim-time — this is the specific design choice that makes SC2 (dt=1/60 ≡ dt=1/120) provable; (3) the **per-layer gradient** (D-05/06/07) maps to the existing accent-derived `theme.charts.chart1…chart6` tokens (public, codebase-confirmed in `Tokens.swift`/`ColorDerivation.swift`), cycled by block index — accent-derived, token-only, with built-in brightness variation that satisfies the low-hue fallback; (4) **feedback wiring** reuses the existing counter-trigger `.sensoryFeedback` pattern and `VideoModeBanner` (which already fires the `.error` game-over haptic itself).

**Primary recommendation:** Persist best-perfect-streak as a `BestScore` row keyed `(gameKind: .stack, mode: "perfectStreak")` via a single new additive `GameStats.recordStackRun(score:perfectStreak:)` method that writes ONE `GameRecord` (mode `"endless"`) and evaluates two `BestScore` rows in one `save()`. This is CloudKit-safe, needs no new model / no migration / no schema-version bump, and `resetAll()` already deletes all `BestScore` rows so the streak clears for free.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
**Combo / width-recovery feel (STACK-03)**
- **D-01:** Recovery is **streak-based**, not single-perfect. Width only recovers/expands after **N consecutive perfects** (then expands more on continuation); a broken streak resets the counter and gives no recovery.
- **D-02:** A "perfect" is defined by a **small tolerance band** around dead-center (not pixel-exact).
- **D-03:** Exact tolerance width, the streak threshold `N`, and per-expansion width amount are **tuning constants** — calibrate against the speed ramp. Score is unaffected by combo (score = blocks placed; streak only affects width).
- **D-04:** The combo/streak counter is **visible during the run**.

**Block color treatment (STACK-05)**
- **D-05:** Tower blocks use a **per-layer gradient** derived from the active preset's accent.
- **D-06:** The gradient **cycles by block index** (each block's color fixed by position; repeats every cycle-length). A placed block **never changes color** once landed. Cycle length is a tuning constant.
- **D-07:** For monochrome / low-hue presets the ramp falls back to **lightness variation** instead of hue. All colors from DesignKit semantic tokens only (no `Color(red:)`, `Color(hex:)`, or system color names anywhere in `Games/Stack/`). Must pass §8.12 and stay colorblind-distinguishable.

**Perfect-drop & game-over feedback (STACK-06 + DESIGN.md §8/§10)**
- **D-08:** Perfect-drop celebration = **color pulse/glow on the landed block + a light haptic tick (distinct from normal-drop impact) + an animated combo-counter bump**. **No SFX chime.** All three gated by haptics/animation settings; Reduce Motion collapses pulse → instant color flash, counter bump → instant number change.
- **D-09:** Game-over = **~0.5s slow-mo on the losing final block + tower color-drain/desaturate, then `VideoModeBanner`** (final score + restart). Under Reduce Motion: **instant cut to banner**, no slow-mo. **Never any screen shake.** Timing follows DESIGN.md §10.3.

**Stats scope this phase (STACK-04, partial ARCADE-07)**
- **D-10:** Persist and show **high score + runs played + best perfect streak** now. Layout stays **minimal** (full ARCADE-07 shape is Phase 18).
- **D-11 (research constraint):** Best-perfect-streak is a **new metric**. MUST be persisted **CloudKit-safe without a schema bump** (no new SwiftData model / no migration / no schema-version bump at the model layer). High score itself reuses `GameStats.record(...)` + `BestScore` unchanged (higher-only, written once on game-over).

### Claude's Discretion
- Block oscillation style, starting sliding speed, idle / tap-to-start screen content, danger-zone treatment when the block gets very narrow, gradient cycle length, tolerance/N/expansion tuning constants, and `SeedableRNG` placement (no RNG needed if oscillation is deterministic) — all left to research/planning.
- `fixedDt` (research locks `1.0/60.0`), accumulator in VM, and the `Frame` value-struct shape are research-confirmed defaults — adopt unless a concrete reason emerges.

### Deferred Ideas (OUT OF SCOPE)
- Full score-based Stats screen shape (average score, last-run, prominent layout), ARCADE-07 → Phase 18.
- SFX cue for block placement / perfect chime → not this phase.
- Daily seed, score trend charts, run-summary micro-screen → v2+.
- Snake (Phase 17). Video Mode (exempt — ADR already written in Phase 15).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STACK-01 | Tap to drop an oscillating block; overhang beyond the block below is trimmed and the block narrows | `StackEngine` contract §Architecture Pattern 1; closed-form oscillation; overhang-trim math |
| STACK-02 | Speed ramps with height then plateaus at a calm cap; run ends when a drop completely misses (width → 0) | Speed-ramp curve §Architecture Pattern 2; game-over on `overlapWidth <= 0` |
| STACK-03 | Near-perfect drops restore width and build a combo (streak-based recovery, D-01/02/03) | Streak/recovery state machine §Architecture Pattern 1; tuning defaults §Tuning Constants |
| STACK-04 | Score = blocks placed; high score persisted; best perfect-streak tracked | D-11 persistence path §Architecture Pattern 3 (load-bearing) |
| STACK-05 | Renders via `Canvas` using DesignKit tokens only; §8.12 legible | Accent-ramp gradient via `theme.charts.*` §Architecture Pattern 4 |
| STACK-06 | Reduce Motion path — block drop jump-cut (no slide/bounce), gameplay unchanged | RM gate §Architecture Pattern 5; engine unchanged, view-layer interpolation only |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Drop physics, overhang trim, streak/width recovery, score, game-over | Pure engine (`StackEngine`, Foundation-only) | — | Deterministic IP; must be headlessly testable (CLAUDE.md §4, Pitfall 4) |
| Fixed-timestep accumulator, input latching, lifecycle, event counters, persistence call | `@Observable @MainActor` VM (`StackViewModel`) | — | Owns the loop bridge; SwiftData firewall (holds `GameStats?`, never imports SwiftData) |
| Frame driver (TimelineView), dt clamp, anchor reset | `Core/ArcadeLoopDriver` (consumed as-is) | — | Phase 15 substrate; **no changes this phase** |
| Tower/block rendering, color ramp, camera/scroll, trim & slow-mo animation, RM gate | SwiftUI `Canvas` view (`StackBoardCanvas`) | `StackGameView` chrome | Immediate-mode draw avoids per-frame view-tree churn (Pitfall 7/16) |
| Score/streak chips, idle screen, game-over banner, scenePhase wiring | `StackGameView` (view tree) | — | Chrome updates rarely; separate from 60Hz board state |
| High score + best streak + runs played storage | `GameStats` + `BestScore` (one additive method) | `StatsView` read | Reuse existing higher-only write path; CloudKit-safe |
| Stats display | `StackStatsCard` (props-only view, own file) | `StatsView` `@Query` | Data-driven not data-fetching (CLAUDE.md §8.2); StatsView already 496 lines |

## Standard Stack

### Core
No new external libraries. Stack is built entirely from the existing project stack and Phase 15 substrate.

| Component | Source | Purpose | Why Standard |
|-----------|--------|---------|--------------|
| `TimelineView(.animation)` + `ArcadeLoopDriver` | `Core/ArcadeLoopDriver.swift` [VERIFIED: codebase] | Frame loop, dt clamp, anchor reset | Phase 15 locked; consumed as-is via `.arcadeLoop(isRunning:onTick:)` |
| `ArcadeGameState` | `Core/ArcadeGameState.swift` [VERIFIED: codebase] | `idle/running/paused/gameOver` lifecycle | Shared enum the VM drives |
| SwiftUI `Canvas` + `GraphicsContext.Shading.color(_:)` | SwiftUI [CITED: developer.apple.com/documentation/swiftui/graphicscontext] | Immediate-mode tower rendering | Accepts `SwiftUI.Color` (DesignKit tokens) directly |
| `BestScore` @Model + `GameStats.record`/`evaluateBestScore` | `Core/GameStats.swift:113-289` [VERIFIED: codebase] | Higher-only score persistence | Already handles score games; `.stack` GameKind exists |
| `VideoModeBanner` | `Core/VideoModeBanner.swift` [VERIFIED: codebase] | Game-over surface | Fires `.error` haptic itself; takes plain Bool gates |
| DesignKit `theme.charts.chart1…6`, `accentPrimary`, `surface`, `background`, `danger`, `textSecondary` | DesignKit `Tokens.swift` [VERIFIED: codebase] | Accent-derived block gradient + chrome | `charts` are public and accent-derived (`ColorDerivation.derivedCharts`) |

### Supporting
| Component | Source | Purpose | When to Use |
|-----------|--------|---------|-------------|
| `.sensoryFeedback(trigger:)` counter pattern | DESIGN.md §8.2 [VERIFIED: codebase, MergeViewModel `mergeCount`] | Perfect-tick + normal-drop haptics | Increment Int on VM, gate `hapticsEnabled ? counter : 0` |
| `@Environment(\.accessibilityReduceMotion)` | SwiftUI [CITED] | RM jump-cut gate | Render-layer only; engine never reads it |
| `@Environment(\.scenePhase)` | SwiftUI [VERIFIED: harness] | Pause on `.inactive` AND `.background` | Same handler for both (Pitfall 1/9) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `theme.charts.*` ramp | `theme.colors.gameNumberPalette` (Wong-safe 8-color) | Colorblind-certified BUT **not accent-derived** — every preset's tower would look identical (blue/green/red), defeating D-05's "tower becomes the preset's palette." Rejected as primary. |
| `theme.charts.*` ramp | `accentPrimary.opacity(rampValue)` over surface | Token-only and trivially accent-derived, but opacity over a scrolling background composites unpredictably; reads as fade not gradient. Viable fallback. |
| Closed-form oscillation | Velocity + bounce integration (`pos += speed*dt`, reflect at bounds) | Bounce reflection point is sub-step-size sensitive → SC2 (dt=1/60 ≡ dt=1/120) would fail at edges. **Closed-form is mandatory for determinism.** |
| `[Double]` engine coordinates | `CGRect`/`CGFloat` | CoreGraphics import is tolerable but `Double` keeps the engine cleanly Foundation-only and matches existing pure engines. |

**Installation:** None — no `npm`/`pip`/SPM dependency added. New files drop into `Games/Stack/` and auto-register via `PBXFileSystemSynchronizedRootGroup` (CLAUDE.md §8.8 — do NOT hand-edit `project.pbxproj`).

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages. All code is built from the existing first-party stack (Swift standard library, SwiftUI, SwiftData, the in-repo DesignKit Swift Package already integrated, and Phase 15 `Core/` substrate). No registry lookups, no slopcheck needed.

## Architecture Patterns

### System Architecture Diagram

```
 user tap ──> StackGameView.onTapGesture ──> vm.pendingDrop = true
                                                     │
 scenePhase(.inactive/.background) ──> vm.pause()    │
 scenePhase(.active) ──> vm.resume()                 │
                                                     ▼
 .arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt:) }
   (TimelineView .animation; dt already clamped min(rawDt,0.1) in driver)
                                                     │ dt (clamped, pre-anchored)
                                                     ▼
 StackViewModel.tick(dt)            [@MainActor]
   accumulator += dt
   while accumulator >= 1/60:
       input = StackInput(drop: pendingDrop); pendingDrop = false
       frame = engine.step(dt: 1/60, input: input)    ─────────┐
       accumulator -= 1/60                                      │
   on frame events: bump perfectCount / dropCount;             │ pure value type
   on frame.gameOver: state=.gameOver; recordStackRun(...)     │ (Foundation only)
                                                     │          ▼
                                                     │   StackEngine.step → Frame
                                                     │   { currentCenterX, currentWidth,
                                                     │     placed[], score, streak,
                                                     │     bestStreak, gameOver, event }
                                                     ▼
 StackBoardCanvas (reads engine snapshot each frame)      GameStats.recordStackRun
   draws placed tower (color = ramp(index)),                (1 GameRecord "endless"
   current sliding block, trim piece, camera scroll          + 2 BestScore rows:
   RM gate: jump-cut vs interpolate                           "endless" + "perfectStreak")
                                                                     │
 StackGameView chrome: score chip · streak chip ·              BestScore @Model
   idle "tap to start" · VideoModeBanner(.loss)               (CloudKit-synced)
                                                                     ▼
                                                       StatsView @Query stackBestScores
                                                       (high = "endless", streak = "perfectStreak")
```

### Recommended Project Structure
```
Games/Stack/
├── StackEngine.swift        # pure struct: step(dt:input:)->Frame, overhang/streak math, ramp (<300)
├── StackConfig.swift        # tuning constants (split out if StackEngine nears 400) (<60)
├── StackViewModel.swift     # @Observable @MainActor: accumulator, counters, persistence (<200)
├── StackGameView.swift      # ZStack chrome, lifecycle, scenePhase, .arcadeLoop, banner, idle (<250)
├── StackBoardCanvas.swift   # Canvas draw: tower, block, trim, camera, RM gate (<250)
└── StackPalette.swift       # block-color ramp helper (chart-cycle, token-only) (<80)
Screens/
└── StackStatsCard.swift     # props-only stats card (StatsView is already 496 lines — MUST be own file)
DELETE: Games/Stack/StackHarnessView.swift  (throwaway per Phase 15 D-02)
EDIT:   Screens/HomeView.swift  (swap harness destination → StackGameView(); keep NO .videoModeAware)
EDIT:   Screens/StatsView.swift (replace Stack placeholder block with StackStatsCard(...))
ADD:    gamekitTests/Games/Stack/StackEngineTests.swift  (determinism + edge cases)
EDIT:   gamekitTests/Core/GameStatsTests.swift  (recordStackRun: 1 record + 2 best rows)
```

### Pattern 1: Pure `StackEngine` with closed-form deterministic oscillation (STACK-01/02/03, SC2)

**What:** Foundation-only value type. Oscillation position is a **closed-form function of accumulated per-block sim-time**, not integrated velocity — this is what makes dt=1/60 and dt=1/120 produce identical results (SC2).

**When to use:** All Stack game logic. Mirrors `RevealEngine`/`MergeEngine` purity (CLAUDE.md §4).

```swift
// Source: pattern derived from STACK.md §2 + codebase RevealEngine/MergeEngine purity
import Foundation

struct PlacedBlock: Equatable { var centerX: Double; var width: Double }   // y = index * blockHeight (view derives y)

struct StackInput: Equatable { var drop: Bool = false }

enum StackEvent: Equatable { case none, perfect(index: Int), trim(overhangWidth: Double), miss }

struct StackFrame: Equatable {
    var currentCenterX: Double
    var currentWidth: Double
    var score: Int
    var streak: Int
    var bestStreak: Int
    var gameOver: Bool
    var event: StackEvent
}

struct StackEngine {
    // --- config (see StackConfig) ---
    let cfg: StackConfig
    // --- state (pure value semantics) ---
    private(set) var placed: [PlacedBlock]
    private var currentWidth: Double
    private var blockElapsed: Double = 0          // sim-time since current block spawned
    private var oscSpeed: Double                  // sweeps/sec, fixed at spawn from score
    private var startSide: Double = 0             // 0 = sweep starts at left, phase offset
    private(set) var streak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var gameOver = false

    var score: Int { placed.count }

    init(cfg: StackConfig = .default) {
        self.cfg = cfg
        // first placed block is the base, centered, full width
        self.placed = [PlacedBlock(centerX: cfg.playfieldCenter, width: cfg.startingWidth)]
        self.currentWidth = cfg.startingWidth
        self.oscSpeed = cfg.startSpeed
    }

    /// Triangle wave in [0,1]; closed-form ⇒ identical at any dt chunking.
    private func tri(_ t: Double) -> Double {
        let p = (t + startSide).truncatingRemainder(dividingBy: 1.0)
        let q = p < 0 ? p + 1 : p
        return q < 0.5 ? q * 2 : 2 - q * 2
    }

    private var currentCenterX: Double {
        let travel = cfg.playfieldWidth - currentWidth        // edge-to-edge travel for this width
        let minC = cfg.playfieldCenter - travel / 2
        return minC + travel * tri(blockElapsed * oscSpeed)
    }

    private func rampSpeed(forScore s: Int) -> Double {
        // STACK-02: linear ramp to plateau, then constant. Time-unit based (Pitfall 1/3).
        let f = min(Double(s) / Double(cfg.plateauScore), 1.0)
        return cfg.startSpeed + (cfg.maxSpeed - cfg.startSpeed) * f
    }

    mutating func step(dt: Double, input: StackInput) -> StackFrame {
        guard !gameOver else { return frame(event: .none) }
        blockElapsed += dt
        guard input.drop else { return frame(event: .none) }

        let cx = currentCenterX
        let top = placed[placed.count - 1]
        let curL = cx - currentWidth / 2, curR = cx + currentWidth / 2
        let topL = top.centerX - top.width / 2, topR = top.centerX + top.width / 2
        let overlapL = max(curL, topL), overlapR = min(curR, topR)
        let overlapW = overlapR - overlapL

        if overlapW <= cfg.minWidth {            // complete miss → game over (width reaches zero)
            gameOver = true
            bestStreak = max(bestStreak, streak)
            return frame(event: .miss)
        }

        let offset = abs(cx - top.centerX)
        if offset <= cfg.perfectTolerance {       // PERFECT
            streak += 1
            bestStreak = max(bestStreak, streak)
            var newWidth = top.width             // perfect ⇒ no trim, keep width
            if streak >= cfg.streakThreshold {    // D-01: expand only after N consecutive
                newWidth = min(newWidth + cfg.expandAmount, cfg.startingWidth)
            }
            placed.append(PlacedBlock(centerX: top.centerX, width: newWidth))
            spawnNext(width: newWidth)
            return frame(event: .perfect(index: placed.count - 1))
        } else {                                  // IMPERFECT → trim
            streak = 0                            // D-01: broken streak, no recovery
            let newCenter = (overlapL + overlapR) / 2
            let overhang = currentWidth - overlapW
            placed.append(PlacedBlock(centerX: newCenter, width: overlapW))
            spawnNext(width: overlapW)
            return frame(event: .trim(overhangWidth: overhang))
        }
    }

    private mutating func spawnNext(width: Double) {
        currentWidth = width
        blockElapsed = 0
        oscSpeed = rampSpeed(forScore: score)
        startSide = startSide == 0 ? 0.5 : 0       // alternate start side (Claude's Discretion)
    }

    private func frame(event: StackEvent) -> StackFrame {
        StackFrame(currentCenterX: currentCenterX, currentWidth: currentWidth,
                   score: score, streak: streak, bestStreak: bestStreak,
                   gameOver: gameOver, event: event)
    }
}
```

**Why closed-form (the SC2 keystone):** `blockElapsed` is accumulated by `+= dt`, but `currentCenterX` is a pure function `tri(blockElapsed * oscSpeed)`. The fixed-timestep accumulator guarantees the engine receives exactly `1/60` per step regardless of render rate, so over 5 simulated seconds it runs exactly 300 steps whether the driver fired at 60Hz or 120Hz. With drops scheduled at the same sim-times, `blockElapsed` at each drop is identical → identical positions → identical widths/score/gameOver. A velocity-bounce model would diverge at reflection points. **No RNG is needed** (Claude's Discretion: oscillation is deterministic; do not introduce `SeedableRNG`).

### Pattern 2: Speed ramp with plateau (STACK-02 / SC3)

`rampSpeed` (above) is linear from `startSpeed` to `maxSpeed` across `0…plateauScore` blocks, then constant. Expressed in **sweeps/sec** (time units, never frames) — satisfies Pitfalls 1/3. Plateau ≤ 80 blocks keeps the brand calm: after the cap the challenge is purely spatial (narrow landing zone), not reaction-speed.

### Pattern 3: D-11 best-perfect-streak persistence — LOAD-BEARING (STACK-04)

**Recommendation: a second `BestScore` row under a distinct mode key, via one additive `GameStats` method.**

```swift
// Source: extends existing GameStats.swift:113-289 (same file as evaluateBestScore)
// Additive method — NOT a schema change. No new @Model, no migration, no schemaVersion bump.
extension GameStats {
    static let stackEndlessMode = "endless"          // permanent serialization key — lock on first write
    static let stackPerfectStreakMode = "perfectStreak"

    func recordStackRun(score: Int, perfectStreak: Int) throws {
        // ONE GameRecord (runs-played source) under the "endless" mode key.
        let record = GameRecord(gameKind: .stack, difficulty: Self.stackEndlessMode,
                                outcome: .loss, durationSeconds: 0, playedAt: .now, score: score)
        modelContext.insert(record)
        if score > 0 {
            do { try evaluateBestScore(gameKind: .stack, mode: Self.stackEndlessMode, score: score) }
            catch { /* logger.error — best-effort, GameRecord still flushes */ }
        }
        if perfectStreak > 0 {
            do { try evaluateBestScore(gameKind: .stack, mode: Self.stackPerfectStreakMode, score: perfectStreak) }
            catch { /* logger.error */ }
        }
        try modelContext.save()      // single synchronous save (force-quit survival, Pitfall 12)
    }
}
```

Read path needs **no new `@Query`** — `StatsView` already has `stackBestScores: [BestScore]` (filtered by `gameKindRaw == "stack"`, `StatsView.swift:134`) which returns *both* rows. The card filters by `difficultyRaw`:

```swift
// StackStatsCard (props-only, mirrors MergeStatsCard at StatsView.swift:296-339)
let highScore = bestScores.first { $0.difficultyRaw == "endless" }?.score
let bestStreak = bestScores.first { $0.difficultyRaw == "perfectStreak" }?.score
let runsPlayed = records.count        // all stack GameRecords are "endless" → no filter needed
```

**Why this wins (D-11 candidate evaluation against the real source):**

| Candidate | Verdict | Reasoning |
|-----------|---------|-----------|
| **(a) `BestScore` row, distinct mode key** ✅ RECOMMENDED | **Adopt** | Reuses higher-only `evaluateBestScore` verbatim (`GameStats.swift:261`); `BestScore` is an existing CloudKit-synced `@Model` (no new model, no migration, no schema bump); `resetAll()` already `delete(model: BestScore.self)` (`GameStats.swift:180`) → streak clears for free. One `GameRecord` per run keeps runs-played honest. CloudKit-safe identical to the high score. |
| (b) reuse an existing `GameRecord` field | Reject | Would overload `durationSeconds` (Double seconds) to carry an Int streak — a semantic hack that corrupts export/import meaning and any future duration logic. |
| (c) `UserDefaults` single Int | Reject | **Not CloudKit-synced** → inconsistent with the high score across devices (D-11 demands CloudKit-safe). `NSUbiquitousKeyValueStore` would add a *new* network surface, violating CLAUDE.md §1 ("CloudKit container is the only network surface"). |

**Zero-`GameStats`-change fallback** (if planning forbids touching `GameStats`): call the existing public `record(gameKind:mode:outcome:score:)` twice (modes `"endless"` and `"perfectStreak"`) → creates two `GameRecord` rows, so `runsPlayed` must filter `difficultyRaw == "endless"`. Cost: doubles `GameRecord`/CloudKit volume per run. The single-method approach is cleaner; adding a method is not a schema change and CONTEXT explicitly anticipates a `GameStats` touch ("`resetAll()` — ensure Stack score/streak clears").

### Pattern 4: Accent-derived per-layer gradient via `theme.charts` (STACK-05, D-05/06/07)

```swift
// Source: theme.charts.chart1…6 are public + accent-derived (DesignKit Tokens.swift:73-79,
//         ColorDerivation.derivedCharts:83-96 rotates hue around accent + varies brightness/saturation)
// StackPalette.swift — token-only, no Color(red:)/Color(hex:)/system names
enum StackPalette {
    static func color(forIndex i: Int, theme: Theme) -> Color {
        let ramp = [theme.charts.chart1, theme.charts.chart2, theme.charts.chart3,
                    theme.charts.chart4, theme.charts.chart5, theme.charts.chart6]
        return ramp[i % ramp.count]          // D-06: fixed by index, cycles (cycle length 6)
    }
}
```

- **Accent-derived (D-05):** `derivedCharts` builds chart2…6 by rotating hue ±0.08…0.33 around the accent and scaling brightness 0.92–1.05 / saturation — the tower literally becomes the current preset's accent palette.
- **Low-hue fallback (D-07):** because the derivation also varies *brightness*, a monochrome/low-saturation accent still yields visibly distinct steps (lightness variation) — the fallback is built into the token, no special-casing needed.
- **Colorblind (D-07):** adjacent layers differ in brightness as well as hue, and blocks are positionally stacked (redundant non-color cue). Verify in the §8.12 audit; if a specific Loud preset fails, the documented escape hatch is the Wong-safe `theme.colors.gameNumberPalette` for that preset — but default to charts.
- `GraphicsContext.Shading.color(_:)` takes a `SwiftUI.Color` [CITED: developer.apple.com/documentation/swiftui/graphicscontext], so these tokens feed `ctx.fill(path, with: .color(StackPalette.color(...)))` directly.

**Camera/scroll:** keep camera in the **view layer** (rendering concern, not engine). Render only the visible window (top ~K blocks); camera offset = `f(towerHeight)` so the current block sits in the upper third. Interpolate the offset inside the `Canvas` draw using the accumulator remainder (Gaffer alpha) — **never** a SwiftUI `.animation()` on board state (Pitfall 18). Under Reduce Motion, snap the offset (no interpolation).

### Pattern 5: Feedback wiring — counter-trigger haptics + RM gates (STACK-06, D-08/09)

| Event | Visual (DESIGN §10.6) | Haptic (DESIGN §8.2, gated `hapticsEnabled` FIRST) | Animation (gated `animationsEnabled` && `!reduceMotion`) | Reduce Motion fallback |
|-------|----------------------|-----------------------------------------------------|----------------------------------------------------------|------------------------|
| Normal (imperfect) drop | block lands trimmed; overhang piece falls+fades | `.impact(.light, 0.7)` via `dropCount` | trim piece short fall + fade | trim vanishes instantly |
| **Perfect drop** | color pulse/glow on landed block + combo-counter bump | **`.impact(.medium, 1.0)` via `perfectCount`** (distinct milestone class — satisfies D-08 "distinct from normal-drop") | pulse + counter bump | instant color flash + instant number change |
| Game over | tower color-drain/desaturate, ~0.5s slow-mo on final block, then banner | `.error` — **already fired by `VideoModeBanner` on appear** (`VideoModeBanner.swift:126-136`); do NOT add a second | 0.5s pre-roll per §10.3 (Game over = 500ms) | **instant cut to banner**, no slow-mo, no drain |

- Counter-trigger pattern (codebase-verified, `MergeViewModel.swift:35` + `VideoModeBanner.swift:128`): VM exposes `private(set) var perfectCount`, `dropCount`; view attaches `.sensoryFeedback(.impact(weight:.medium), trigger: hapticsEnabled ? vm.perfectCount : 0)` etc.
- **Gate order (05-03 D-10):** `hapticsEnabled` is the FIRST guard; `animationsEnabled` and `accessibilityReduceMotion` are independent gates for animation. Haptics fire even when animations are off (DESIGN §8.3 Q3).
- **Slow-mo implementation:** the loop is already stopped at `state == .gameOver` (`.arcadeLoop(isRunning:)` is false), so there is no live sim to slow. The slow-mo + drain is a **view-only** chrome animation (allowed) running during the 500ms pre-roll, then `VideoModeBanner` presents. When animations off / RM on, skip the pre-roll entirely (§10.3) — never `Task.sleep` purely for delay.
- **NEVER screen shake** (D-09 + FEATURES anti-feature + DESIGN §10.2 reserves shake for wrong-move board games only).

### Anti-Patterns to Avoid
- **Second dt clamp** in VM/engine — the driver already clamps `min(rawDt, 0.1)` (`ArcadeLoopDriver.swift:42`). Adding another breaks the single-source invariant.
- **Velocity-bounce oscillation** — fails SC2. Use closed-form.
- **`.animation()` on tower/block state** — visual lag + restart snap (Pitfall 18). Interpolate inside Canvas.
- **Saving per frame** — save exactly once on game-over (Pitfall 12). `recordStackRun` is called from the `.gameOver` transition, not the tick loop.
- **Publishing the whole `Frame` via `@Observable`** at 60Hz — separate render state (Canvas reads engine snapshot) from chrome state (`score`, `streak`, `gameOver`, counters) so the score chip doesn't re-layout 60×/sec (Pitfall 16).
- **Inlining `StackStatsCard` into `StatsView`** — it is already 496 lines (over the §8.1 soft cap, near §8.5 hard cap). The card MUST be its own file.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Frame loop / dt clamp / anchor reset | Custom `CADisplayLink` or `Timer` | `Core/ArcadeLoopDriver` (`.arcadeLoop`) | Phase 15 locked; Swift 6 Sendable-clean; clamp already inside |
| Fixed timestep | Variable dt to engine | VM accumulator (harness pattern) | Frame-rate-independent physics; SC2 |
| Higher-only score store | New `@Model` or hand-rolled max logic | `GameStats.evaluateBestScore` + `BestScore` | CloudKit-safe, tested, write-once-on-game-over |
| Game-over surface | Custom banner | `Core/VideoModeBanner(outcome:.loss)` | Fires `.error` haptic, a11y announce, gated transitions built in |
| Accent color ramp | `Color(hue:saturation:brightness:)` math in `Games/Stack/` | `theme.charts.chart1…6` | Accent-derived ramp already computed by DesignKit; keeps token discipline |
| Color HSB/blend math | Reimplement `ColorDerivation.blend`/`hsbComponents` | `theme.charts.*` tokens | Those helpers are `internal`/`private` to DesignKit — not accessible from app; don't duplicate |

**Key insight:** Almost everything Stack needs already exists. The genuinely *new* code is the pure `StackEngine` (drop/trim/streak math) and the `Canvas` draw. Everything else is wiring proven components.

## Runtime State Inventory

This is primarily a greenfield gameplay phase, but it deletes the Phase 15 harness and adds persistence keys. Audit:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `BestScore` rows under new mode keys `"endless"` + `"perfectStreak"`; `GameRecord` rows `gameKind=.stack`. No pre-existing Stack data (Phase 15 shipped only a harness, never wrote stats). | Code only — first writes establish the keys. Lock `"endless"`/`"perfectStreak"` as permanent serialization keys (renaming = data break). |
| Live service config | None — no external service holds "stack" state beyond the app's own CloudKit container (which syncs `BestScore`/`GameRecord` automatically). | None. |
| OS-registered state | None — no Task Scheduler/launchd/pm2 equivalents on iOS for this game. | None. |
| Secrets/env vars | None. | None. |
| Build artifacts | `StackHarnessView.swift` (throwaway) deleted; new files in `Games/Stack/` auto-register via synchronized root group. No stale `.egg-info`/binary equivalent. | Delete harness file + remove harness wiring from `HomeView`. Verify no `?? *2.swift` dupes (CLAUDE.md §8.7). |

**Verified by:** grep of `GameStats.resetAll()` (clears `BestScore`/`GameRecord` + per-game UserDefaults), `StatsView.swift` (`stack` `@Query` already present), `HomeView` harness destination (to be swapped). No runtime state survives a source rename because Stack has shipped no user data yet.

## Common Pitfalls

The full catalog is in `.planning/research/PITFALLS.md` (P1–P22). The ones this phase MUST actively prevent (others are substrate-level, already handled in Phase 15):

### Pitfall: Frame-rate-dependent physics / ProMotion divergence (P1/P3)
**What goes wrong:** oscillation tied to frame count → 2× speed on 120Hz. **Avoid:** speed in sweeps/sec × closed-form on accumulated sim-time; fixed-timestep accumulator. **Warning sign:** any `speedPerFrame`/`stepsPerTick`. **Verify:** SC2 test.

### Pitfall: Engine impurity (P4)
**Avoid:** `StackEngine.swift` imports Foundation only — no SwiftUI/UIKit/SwiftData, no `Date.now`, no screen geometry. **Verify:** `grep -r "import SwiftUI\|import UIKit\|modelContext" gamekit/gamekit/Games/Stack/StackEngine.swift` returns empty.

### Pitfall: High score saved per frame (P12)
**Avoid:** `recordStackRun` called only on the `.gameOver` transition. **Verify:** Instruments shows no disk I/O during play; exactly one `GameRecord` per run.

### Pitfall: DesignKit token bypass / illegible under Loud presets (P15)
**Avoid:** all colors via tokens (`theme.charts.*`, `accentPrimary`, `surface`, `danger`, `background`). **Verify:** §8.12 audit on Classic + Voltage/Dracula; `grep -rn "Color(red:\|Color(hex:\|\.green\|\.red\|\.blue" gamekit/gamekit/Games/Stack/` returns empty.

### Pitfall: Reduce Motion path missing (P13)
**Avoid:** `@Environment(\.accessibilityReduceMotion)` in the view; jump-cut block position, no trim fall, no slow-mo. Engine unchanged. **Verify:** Simulator → Accessibility → Reduce Motion; game still fully playable.

### Pitfall: Feedback not gated (P14) / per-frame haptic
**Avoid:** counter-trigger with `hapticsEnabled` first-guard; NO per-tick haptic (only perfect, normal-drop, and the banner's game-over). **Verify:** haptics OFF in Settings → silent.

### Pitfall: Monolithic file > cap (P21 / CLAUDE §8.1/§8.5)
**Avoid:** six-file split above; `StackStatsCard` separate (StatsView already 496 lines). **Verify:** `wc -l` all new/edited files < 400.

## Code Examples

### SC2 determinism test (ProMotion equivalence — the locked Phase-16 gate)
```swift
// Source: Swift Testing pattern (codebase: ArcadeLoopDriverTests.swift uses @Suite/@Test/#expect)
import Testing
import Foundation
@testable import gamekit

@Suite("StackEngine determinism")
nonisolated struct StackEngineTests {

    /// SC2: same fixed config, drops at the same sim-times, dt=1/60 vs dt=1/120
    /// over 5 simulated seconds ⇒ identical score / gameOver / tower widths.
    @Test("ProMotion equivalence: 60Hz step stream ≡ 120Hz step stream")
    func proMotionEquivalence() {
        let dropTimes: [Double] = [0.8, 1.6, 2.5, 3.1, 4.2]   // seconds
        func run(fixedDt: Double) -> StackEngine {
            var e = StackEngine(cfg: .testFixed)
            var t = 0.0
            var di = 0
            let steps = Int((5.0 / fixedDt).rounded())
            for _ in 0..<steps {
                t += fixedDt
                let drop = di < dropTimes.count && t >= dropTimes[di]
                if drop { di += 1 }
                _ = e.step(dt: fixedDt, input: StackInput(drop: drop))
            }
            return e
        }
        let a = run(fixedDt: 1.0/60.0)
        let b = run(fixedDt: 1.0/120.0)
        #expect(a.score == b.score)
        #expect(a.gameOver == b.gameOver)
        #expect(a.placed.map(\.width) == b.placed.map(\.width))
    }

    @Test("complete miss (no overlap) ends the run")
    func completeMissGameOver() { /* drive a drop far off-center; #expect frame.event == .miss && gameOver */ }

    @Test("N consecutive perfects expand width; one imperfect resets streak")
    func streakRecoveryAndReset() { /* D-01: width grows only after threshold; broken streak → no recovery */ }
}
```

### Persistence test (extends GameStatsTests' in-memory container)
```swift
// Source: codebase GameStatsTests.swift:24-38 (@MainActor @Suite, makeStats() in-memory ModelContainer)
@Test("recordStackRun: one GameRecord (endless) + two higher-only BestScore rows")
func recordStackRunWritesStreakWithoutSchemaChange() throws {
    let (stats, ctx, _) = try makeStats()
    try stats.recordStackRun(score: 42, perfectStreak: 7)
    let records = try ctx.fetch(FetchDescriptor<GameRecord>(predicate: #Predicate { $0.gameKindRaw == "stack" }))
    #expect(records.count == 1)                       // runs-played stays honest
    let best = try ctx.fetch(FetchDescriptor<BestScore>(predicate: #Predicate { $0.gameKindRaw == "stack" }))
    #expect(best.count == 2)                          // "endless" + "perfectStreak"
    #expect(best.first { $0.difficultyRaw == "endless" }?.score == 42)
    #expect(best.first { $0.difficultyRaw == "perfectStreak" }?.score == 7)
    // higher-only: a lower streak does not overwrite
    try stats.recordStackRun(score: 10, perfectStreak: 3)
    let best2 = try ctx.fetch(FetchDescriptor<BestScore>(predicate: #Predicate { $0.gameKindRaw == "stack" && $0.difficultyRaw == "perfectStreak" }))
    #expect(best2.first?.score == 7)
}
```

## Tuning Constants (MEDIUM confidence — calibrate on device, D-03)

`StackConfig.default` starting values; treat as a play-test baseline, not gospel. All time-unit based (Pitfall 1/3). Coordinates normalized to playfield width = 1.0.

| Constant | Default | Rationale | Confidence |
|----------|---------|-----------|------------|
| `fixedDt` | `1.0/60.0` | Research-locked sim rate | HIGH |
| `playfieldWidth` / `playfieldCenter` | `1.0` / `0.5` | Normalized; view maps to screen | HIGH |
| `startingWidth` | `0.62` | Generous opening landing zone | MEDIUM |
| `startSpeed` | `0.35` sweeps/sec | ~2.9s per L→R→L sweep; calm opening (FEATURES "first 2 min meditative") | MEDIUM |
| `maxSpeed` | `0.90` sweeps/sec | ~1.1s per sweep; challenging, not twitch | MEDIUM |
| `plateauScore` | `80` blocks | FEATURES brand guard "cap no later than ~80" | MEDIUM (HIGH on the ≤80 ceiling) |
| `perfectTolerance` | `0.025` (≈4% of startingWidth) | Small band (D-02); achievable enough that streaks trigger | MEDIUM |
| `streakThreshold` (N) | `5` | Echoes Ketchapp/Coolmath 5-consecutive convention | MEDIUM |
| `expandAmount` | `0.04` per perfect ≥ N, capped at `startingWidth` | Generous recovery keeps long runs viable | MEDIUM |
| `minWidth` (game-over floor) | `0.015` | Overlap below this = miss | MEDIUM |
| gradient cycle length | `6` | Matches `theme.charts.chart1…6` | MEDIUM |
| game-over pre-roll | `500ms` | DESIGN §10.3 "Game over = 500ms" | HIGH |

## State of the Art

No moving target here — the stack is the project's own proven Swift 6 / SwiftUI / SwiftData / DesignKit foundation plus the Phase-15 substrate. The only "current vs old" note: real-time loops in this codebase use `TimelineView(.animation(paused:))`, NOT `CADisplayLink` (Swift 6 Sendable friction) and NOT `Timer` (not display-synced) — decided and locked in Phase 15 (STACK.md §1, ARCADE-08 ADR).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | All speed-ramp + combo tuning constants (start/max speed, tolerance, N, expandAmount, cycle length) | Tuning Constants | Game feels too easy/hard or non-calm; mitigated by on-device play-test calibration before §12.5 sign-off. Pure tuning, no architectural impact. |
| A2 | `theme.charts.*` is an acceptable semantic reuse for tower blocks (tokens are named for Swift Charts but are literally an accent-derived ramp) | Pattern 4 | Mild semantic stretch; if the user/planner objects, fallback is `accentPrimary.opacity()` ramp or a small public DesignKit `accentRamp` helper. Does not affect determinism or persistence. |
| A3 | Alternating start-side oscillation (vs pure left-right) | Pattern 1 `spawnNext` | Pure feel choice (Claude's Discretion); zero correctness impact. |
| A4 | `startingWidth`/playfield normalized to 1.0 with view-layer screen mapping | Tuning / Pattern 1 | Engine stays Foundation-only; if planning prefers point units, swap config — no logic change. |

**All load-bearing claims (D-11 path, engine determinism, token availability, file split, banner reuse) are VERIFIED against source — not in this table.**

## Open Questions (RESOLVED)

1. **Gradient token semantics (A2).**
   - What we know: `theme.charts.chart1…6` are public, accent-derived, brightness-varied — the best-fit token-only accent ramp.
   - What's unclear: whether reusing chart tokens for a game board is considered clean by the user, or whether a dedicated `theme.accentRamp(count:)` DesignKit helper is preferred.
   - **RESOLVED:** ship with `theme.charts.*` (no DesignKit change, CLAUDE.md "promote only when proven"); revisit only if the §8.12 audit fails a specific preset. Adopted in 16-04 (StackPalette).

2. **Camera/scroll feel.**
   - What we know: camera belongs in the view layer, interpolated in Canvas, snapped under RM.
   - What's unclear: exact visible-window size K and whether the base of the tower ever scrolls fully off.
   - **RESOLVED:** render last ~12–16 blocks; keep current block in upper third; tune visually in the §8.12 pass. Adopted in 16-04 Task 2.

## Environment Availability

Skipped — this phase is pure first-party Swift/SwiftUI code built with the existing Xcode toolchain. No external tools, services, runtimes, or package registries are involved. (Build/test via the existing `xcodebuild` setup; note CLAUDE.md §8.9 — if a `NSStagedMigrationManager` crash appears in tests, `xcrun simctl uninstall <id> com.lauterstar.gamekit` and retry; though this phase adds **no** new `@Model`, so it is unlikely.)

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`) [VERIFIED: codebase] |
| Config file | None — Swift Testing via Xcode test target `gamekitTests` |
| Quick run command | `xcodebuild test -scheme gamekit -only-testing:gamekitTests/StackEngineTests -destination 'platform=iOS Simulator,name=iPhone 15'` |
| Full suite command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 15'` |

### Phase Requirements & Success Criteria → Validation Map
| Req / SC | Behavior | Method | Automated Command / Recipe | Exists? |
|----------|----------|--------|----------------------------|---------|
| STACK-01 / SC1 | Tap drops; overhang trims; block narrows; near-perfect recovers + visible combo; run ends at width 0 | unit (engine) + manual (UI) | `StackEngineTests` (`completeMissGameOver`, `streakRecoveryAndReset`) + manual play recipe | ❌ Wave 0 |
| STACK-02 | Speed ramps then plateaus ~80; ends on complete miss | unit | `StackEngineTests.rampSpeedPlateau` (assert `rampSpeed(forScore: 80) == rampSpeed(forScore: 200)`) | ❌ Wave 0 |
| STACK-02 / SC2 | dt=1/60 ≡ dt=1/120 over 5s (score, gameOver, widths) | unit | `StackEngineTests.proMotionEquivalence` | ❌ Wave 0 |
| STACK-03 | Streak-based width recovery (D-01) | unit | `StackEngineTests.streakRecoveryAndReset` | ❌ Wave 0 |
| STACK-04 / SC3 | High score persisted once on game-over; best streak tracked; Stats shows high score + runs played | unit (persistence) + manual | `GameStatsTests.recordStackRunWritesStreakWithoutSchemaChange` + Stats-screen visual check | ❌ Wave 0 |
| SC3 (perf) | Loop paused at game-over (0 CPU); no disk I/O during play; save exactly once | manual / Instruments | Time Profiler + Core Data instrument during a run | ❌ manual |
| STACK-05 / SC4 | Canvas legible Classic + Voltage/Dracula; tokens only | grep gate + manual §8.12 | `grep -rn "Color(red:\|Color(hex:\|\.green\b\|\.red\b" gamekit/gamekit/Games/Stack/` empty + visual audit | grep ✅ / visual ❌ manual |
| STACK-06 / SC5 | Reduce Motion jump-cut; gameplay unchanged | manual | Simulator → Accessibility → Reduce Motion; play a run | ❌ manual |
| Engine purity | No SwiftUI/SwiftData in engine | grep gate | `grep -rn "import SwiftUI\|import UIKit\|modelContext" gamekit/gamekit/Games/Stack/StackEngine.swift` empty | ✅ gate |
| File caps | All Stack files < 400 lines | grep gate | `wc -l gamekit/gamekit/Games/Stack/*.swift Screens/StackStatsCard.swift` | ✅ gate |
| No dupe files | No `* 2.swift` | gate | `git status` shows no `?? *2.swift` | ✅ gate |

### Sampling Rate
- **Per task commit:** `StackEngineTests` + `GameStatsTests` (quick, deterministic).
- **Per wave merge:** full `gamekitTests` suite green.
- **Phase gate:** full suite green + manual §8.12 audit + Reduce Motion recipe + Instruments no-disk-I/O check before `/gsd:verify-work`.

### Wave 0 Gaps
- [ ] `gamekitTests/Games/Stack/StackEngineTests.swift` — covers STACK-01/02/03 + SC2 (determinism, miss, streak, ramp plateau)
- [ ] `gamekitTests/Core/GameStatsTests.swift` — add `recordStackRunWritesStreakWithoutSchemaChange` (STACK-04 / D-11)
- [ ] Framework install: none — Swift Testing + `gamekitTests` target already exist

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (treat as enabled), but this phase's attack surface is effectively nil: an offline, local-only single-player game with no user input parsing beyond a tap, no network calls (CloudKit sync is the app's only network surface and is untouched here), no auth, no secrets.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth in scope (offline game) |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | Local single-user |
| V5 Input Validation | minimal | Only input is a boolean tap; engine clamps `minWidth`; `BestScore` reads use safe-fallback `GameKind(rawValue:) ?? .merge` (existing) |
| V6 Cryptography | no | No crypto; never hand-rolled |
| V9 Data Protection | minimal | Scores persist via SwiftData/CloudKit (existing, encrypted at rest by iOS); no PII; `Never delete user data automatically` (CLAUDE.md §1) — `resetAll()` is explicit user action only |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale SwiftData store crash after schema drift | Denial of Service (self) | This phase adds NO new `@Model` → no migration risk; CLAUDE.md §8.9 runbook if a stale simulator store crashes tests |
| Corrupt/unknown persisted `GameKind`/mode raw value | Tampering (local) | Existing safe-fallback accessors (`BestScore.gameKind`); unknown mode rows simply don't match the `"endless"`/`"perfectStreak"` filters and are ignored |

## Sources

### Primary (HIGH confidence — codebase-verified 2026-06-27)
- `Core/ArcadeLoopDriver.swift` — dt clamp `min(rawDt,0.1)` (L42), anchor reset on any `isRunning` change (L47-53)
- `Core/ArcadeGameState.swift` — `idle/running/paused/gameOver`
- `Core/GameStats.swift` — `record(gameKind:mode:outcome:score:)` (L113), `evaluateBestScore` higher-only (L261-289), `resetAll` deletes `BestScore` (L180)
- `Core/BestScore.swift` — `(gameKindRaw, difficultyRaw, score)` keying; difficultyRaw stores the mode key
- `Core/GameKind.swift` — `.stack` case present (Phase 15, additive, no schema bump)
- `Core/VideoModeBanner.swift` — `.error` haptic fired on appear (L126-136), gated Bool inputs
- `Games/Merge/MergeViewModel.swift` — `@Observable @MainActor` + counter-trigger + `recordTerminal` analog
- `Games/Stack/StackHarnessView.swift` — VM accumulator pattern (L45-71); to be deleted
- `Screens/StatsView.swift` — `stackBestScores`/`stackRecords` `@Query` already present (L127-135); `MergeStatsCard` props-only pattern (L296-339); file is 496 lines
- DesignKit `Theme/Tokens.swift` (public `charts.chart1…6`, `gameNumberPalette`) + `Theme/ColorDerivation.swift` (`derivedCharts` accent rotation L83-96; `blend`/`hsbComponents` are internal/private)
- `gamekitTests/Core/ArcadeLoopDriverTests.swift`, `GameStatsTests.swift` — Swift Testing patterns + in-memory container helper
- `.planning/REQUIREMENTS.md` (STACK-01..06, L171-176), `.planning/ROADMAP.md` (Phase 16 SC1-5, L496-501)
- `.planning/research/STACK.md`, `FEATURES.md`, `PITFALLS.md`, `ARCHITECTURE.md`; `16-CONTEXT.md`, `15-CONTEXT.md`; `CLAUDE.md`; `DESIGN.md` §8/§10/§12.5

### Secondary (MEDIUM/CITED)
- Apple Developer — GraphicsContext / `Shading.color(_:)`, TimelineView, `accessibilityReduceMotion`, scenePhase (via STACK.md/PITFALLS.md citations)
- Gaffer on Games — fixed-timestep accumulator + alpha interpolation (via STACK.md/PITFALLS.md)

## Metadata

**Confidence breakdown:**
- Engine contract & determinism: HIGH — closed-form design directly satisfies SC2; mirrors existing pure engines
- D-11 persistence path: HIGH — reuses verified higher-only `evaluateBestScore`; integrates with existing `@Query` reads
- Rendering / gradient: MEDIUM-HIGH — `theme.charts.*` confirmed public + accent-derived; semantic reuse is the one soft spot (A2)
- Feedback wiring: HIGH — counter-trigger + `VideoModeBanner` are codebase-proven
- Tuning constants: MEDIUM — sound defaults, require device calibration (A1)

**Research date:** 2026-06-27
**Valid until:** ~2026-07-27 (stable first-party stack; no fast-moving external dependencies)
