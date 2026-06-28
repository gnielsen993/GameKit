# Phase 16: Stack - Pattern Map

**Mapped:** 2026-06-27
**Files analyzed:** 13 (7 new · 4 modified · 1 deleted · 1 new test + 1 modified test)
**Analogs found:** 12 / 12 needing a match (the deleted harness needs none)

> Every new/modified file in this phase has a strong in-repo analog. This is a
> wiring-and-one-pure-engine phase — copy from the named analogs; do not invent
> new architecture (CLAUDE.md §4). The only genuinely novel code is the
> `StackEngine` drop/trim/streak math and the `Canvas` draw.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Games/Stack/StackEngine.swift` (NEW) | engine (pure value type) | transform / event-driven | `Games/Merge/Engine/MergeEngine.swift` + `Games/Minesweeper/Engine/RevealEngine.swift` | role-match (real-time vs turn-based, but identical purity contract) |
| `Games/Stack/StackConfig.swift` (NEW) | config (tuning constants) | n/a (static data) | inline `static let` constant blocks across engines (no dedicated analog) | partial — split-out per §8.1 |
| `Games/Stack/StackViewModel.swift` (NEW) | viewmodel (`@Observable @MainActor`) | request-response (tick loop bridge) + persistence | `Games/Merge/MergeViewModel.swift` (primary) + `Games/Stack/StackHarnessView.swift` `StackHarnessVM` (accumulator) | exact (counters + GameStats firewall) / exact (accumulator) |
| `Games/Stack/StackGameView.swift` (NEW) | view (chrome + lifecycle) | event-driven (scenePhase / arcadeLoop / tap) | `Games/Stack/StackHarnessView.swift` (loop+scenePhase) + `Games/Merge/MergeGameView.swift` (GameStats attach, banner, settings) | exact / role-match |
| `Games/Stack/StackBoardCanvas.swift` (NEW) | view (Canvas render) | streaming (per-frame draw) | none in repo (first `Canvas` real-time board) | no analog — see "No Analog Found" |
| `Games/Stack/StackPalette.swift` (NEW) | utility (color ramp helper) | transform | research Pattern 4 (`theme.charts.chart1…6`); no existing palette helper | partial — token-only contract is the binding rule |
| `Screens/StackStatsCard.swift` (NEW) | component (props-only card) | CRUD (read) | `MergeStatsCard` (StatsView.swift:253-294) + `MergeModeStatsRow` (296-339) | exact |
| `Core/GameStats.swift` (MODIFY — add `recordStackRun`) | service (SwiftData firewall) | CRUD (write) | existing `record(gameKind:mode:outcome:score:)` (GameStats.swift:113-144) + `evaluateBestScore` (261-289) | exact |
| `Screens/HomeView.swift` (MODIFY — swap destination) | route | request-response | existing `.stack` case (HomeView.swift:381-383) | exact (one-line swap) |
| `Screens/StatsView.swift` (MODIFY — replace placeholder) | view (section host) | CRUD (read) | existing `.merge` section (StatsView.swift:172-177) | exact |
| `gamekitTests/Games/Stack/StackEngineTests.swift` (NEW) | test | n/a | `gamekitTests/Engine/MergeEngineTests.swift` (`nonisolated @Suite`) | exact |
| `gamekitTests/Core/GameStatsTests.swift` (MODIFY — add streak test) | test | n/a | existing `@MainActor @Suite` + `makeStats()` helper (GameStatsTests.swift:24-59) | exact |
| `Games/Stack/StackHarnessView.swift` (DELETE) | — | — | n/a — throwaway per Phase 15 D-02 | n/a |

---

## Pattern Assignments

### `Games/Stack/StackEngine.swift` (engine, pure value type)

**Analog:** `Games/Merge/Engine/MergeEngine.swift` (purity contract) + research Pattern 1 (the concrete `StackEngine` shape).

**Purity header + import discipline** — copy the doc-comment intent and the single import from `MergeEngine.swift:1-21`:
```swift
import Foundation   // ONLY. No SwiftUI / SwiftData / UIKit / Combine / Date.now / CoreGraphics.
```
Grep gate (must return empty): `grep -rn "import SwiftUI\|import UIKit\|modelContext\|Date.now" gamekit/gamekit/Games/Stack/StackEngine.swift`

**Value-type event/result structs** — mirror `MergeEngine.swift:31-46` (`MergeEvent`/`SlideResult` are `Equatable, Sendable` value types). Stack's equivalents (`PlacedBlock`, `StackInput`, `StackEvent`, `StackFrame`) are spelled out verbatim in 16-RESEARCH.md Pattern 1 (lines 177-191). Make them `Equatable` so the SC2 determinism test can `#expect(a.placed.map(\.width) == b.placed.map(\.width))`.

**Core mutating step** — the full `mutating func step(dt:input:) -> StackFrame` is in 16-RESEARCH.md Pattern 1 (lines 235-286). Closed-form `tri()` oscillation is **mandatory** (SC2 keystone) — do NOT integrate velocity/bounce. No RNG (oscillation is deterministic; do not introduce `SeedableRNG`).

**Anti-pattern (CONTEXT + research):** no second `dt` clamp — `ArcadeLoopDriver.swift:42` already clamps `min(rawDt, 0.1)`.

---

### `Games/Stack/StackConfig.swift` (config, tuning constants)

**Analog:** none dedicated — split out per CLAUDE.md §8.1 to keep `StackEngine` < 300 lines (research structure note, line 154-156).

**Pattern:** a `struct StackConfig` with a `static let `default`` and a `static let testFixed` (the latter consumed by `StackEngineTests` per research line 456). All values from the Tuning Constants table in 16-RESEARCH.md (lines 503-520): `fixedDt = 1.0/60.0`, `playfieldWidth/Center = 1.0/0.5`, `startingWidth = 0.62`, `startSpeed = 0.35`, `maxSpeed = 0.90`, `plateauScore = 80`, `perfectTolerance = 0.025`, `streakThreshold = 5`, `expandAmount = 0.04`, `minWidth = 0.015`, gradient `cycleLength = 6`. These are play-test baselines (MEDIUM confidence) — comment them as tunable.

---

### `Games/Stack/StackViewModel.swift` (viewmodel, `@Observable @MainActor`)

**Analog:** `Games/Merge/MergeViewModel.swift` (state surface + GameStats firewall) + `StackHarnessVM` in `Games/Stack/StackHarnessView.swift:28-71` (accumulator + lifecycle).

**Class declaration + firewall** (MergeViewModel.swift:16-19, 44-45):
```swift
import Foundation   // SwiftData firewall: VM holds GameStats? and never imports SwiftData

@Observable @MainActor
final class StackViewModel {
    private(set) var state: ArcadeGameState = .idle   // from Core/ArcadeGameState.swift
    private(set) var gameStats: GameStats?
```
All public state is `private(set)` (MergeViewModel discipline, lines 23-37).

**Fixed-timestep accumulator** — copy `StackHarnessVM.tick/start/pause/resume/stop` verbatim (StackHarnessView.swift:40-70), then extend `tick` to drive the engine. Latch `pendingDrop` inside the `while accumulator >= fixedDt` loop and clear it (research diagram lines 123-131):
```swift
func tick(dt: Double) {
    guard state == .running else { return }
    accumulator += dt
    while accumulator >= fixedDt {
        let input = StackInput(drop: pendingDrop); pendingDrop = false
        let frame = engine.step(dt: fixedDt, input: input)
        accumulator -= fixedDt
        // bump counters on frame.event; on frame.gameOver → state = .gameOver + recordStackRun(...)
    }
}
```

**Counter-trigger haptic state** — mirror `mergeCount`/`terminalCount` (MergeViewModel.swift:31-37). Stack needs `private(set) var perfectCount: Int` and `private(set) var dropCount: Int` (research Pattern 5 table, lines 367-373). NOTE: do NOT add a game-over haptic counter — `VideoModeBanner` fires `.error` itself (VideoModeBanner.swift:126-129).

**GameStats injection** — copy `attachGameStats(_:)` one-shot guard (MergeViewModel.swift:79-83).

**Persistence call** — call `gameStats?.recordStackRun(...)` exactly once on the `.gameOver` transition (best-effort `try?`), mirroring `recordTerminal()` (MergeViewModel.swift:213-221). NEVER per-tick (Pitfall 12).

**`restart()`** — reset engine, counters, `accumulator = 0`, `state = .idle` (or `.running`). Mirror MergeViewModel.swift:149-157 + `StackHarnessVM.start()` accumulator clear (line 55).

**Test seam** — `#if DEBUG testHook_…` pattern (MergeViewModel.swift:274-281) if a known engine state must be injected.

---

### `Games/Stack/StackGameView.swift` (view, chrome + lifecycle)

**Analog:** `Games/Stack/StackHarnessView.swift:75-151` (loop + scenePhase + back chevron toolbar) + `Games/Merge/MergeGameView.swift` (GameStats attach, settings env, banner).

**Environment + theme** (StackHarnessView.swift:77-83 + MergeGameView.swift:40-56):
```swift
@EnvironmentObject private var themeManager: ThemeManager
@Environment(\.colorScheme) private var colorScheme
@Environment(\.scenePhase) private var scenePhase
@Environment(\.modelContext) private var modelContext
@Environment(\.settingsStore) var settingsStore        // hapticsEnabled / animationsEnabled
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.dismiss) private var dismiss
@State private var vm = StackViewModel()
private var theme: Theme { themeManager.theme(using: colorScheme) }
```

**Loop driver + scenePhase pause** — copy verbatim from StackHarnessView.swift:135-149:
```swift
.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active: vm.resume()
    case .inactive, .background: vm.pause()   // BOTH stop the loop (Pitfall 1)
    @unknown default: vm.pause()
    }
}
```

**Back chevron toolbar** — copy verbatim StackHarnessView.swift:120-133 (`chevron.backward`, 44×44 hit target, `.accessibilityLabel("Back to The Drawer")`). Keep `navigationBarBackButtonHidden(true)`.

**GameStats attach** — copy MergeGameView.swift:128-133 `.task { ... GameStats(modelContext:) ... attachGameStats }` with the `didInjectStats` guard (line 45).

**Game-over surface** — present `VideoModeBanner(outcome: .loss …)` on `state == .gameOver`. Pass plain Bools from settings (`hapticsEnabled`, `reduceMotion`, `animationsEnabled`) per VideoModeBanner.swift:49-51. The banner fires its own `.error` haptic — do NOT add another. Gate the entrance with `.videoModeBannerTransition(reduceMotion:animationsEnabled:)` (VideoModeBanner.swift:177-189).

**Counter-trigger haptics (view side)** — attach `.sensoryFeedback` keyed on the VM counters with `hapticsEnabled` as the FIRST guard collapsing the trigger to 0 (pattern proven at VideoModeBanner.swift:126-129):
```swift
.sensoryFeedback(.impact(weight: .medium), trigger: settingsStore.hapticsEnabled ? vm.perfectCount : 0)
.sensoryFeedback(.impact(weight: .light),  trigger: settingsStore.hapticsEnabled ? vm.dropCount : 0)
```

**Idle / tap-to-start + score/streak chips** — `theme.colors.background.ignoresSafeArea()` ZStack base (StackHarnessView.swift:86-88); idle button at StackHarnessView.swift:108-114; timers/counters use `theme.typography.*.monospacedDigit()` (DESIGN.md §4; StackHarnessView.swift:101). Combo counter must be visible during the run (D-04). Every data view ships an explicit empty/idle state (§8.3).

**Tap input** — `.onTapGesture { vm.pendingDrop = true }` (research diagram line 114; `pendingDrop` is main-actor, no Sendable concern).

**Anti-pattern:** keep NO `.videoModeAware()` (CONTEXT integration note; HomeView.swift:378-380 ADR ARCADE-08).

---

### `Games/Stack/StackBoardCanvas.swift` (view, Canvas render) — NO direct analog

**Analog:** none in repo (first real-time `Canvas` board). Build from research Pattern 4 (lines 343-363) + RESEARCH structure (line 156).

**Contract:** a props-only `Canvas { ctx, size in … }` view that reads an engine snapshot each frame and draws via `ctx.fill(path, with: .color(StackPalette.color(forIndex: i, theme: theme)))`. `GraphicsContext.Shading.color(_:)` takes a `SwiftUI.Color` so DesignKit tokens feed it directly. Camera/scroll stays in this view layer (NOT the engine); interpolate the offset using the accumulator remainder, and **snap** under `reduceMotion` (research lines 363, 375). Render only the visible window (~12-16 top blocks, research Open Question 2).

**Anti-pattern:** never `.animation()` on tower/block state (Pitfall 18) — interpolate inside the Canvas draw.

---

### `Games/Stack/StackPalette.swift` (utility, color ramp)

**Analog:** none — token-discipline contract is the binding rule (research Pattern 4, lines 348-355):
```swift
enum StackPalette {
    static func color(forIndex i: Int, theme: Theme) -> Color {
        let ramp = [theme.charts.chart1, theme.charts.chart2, theme.charts.chart3,
                    theme.charts.chart4, theme.charts.chart5, theme.charts.chart6]
        return ramp[i % ramp.count]   // D-06: fixed by index, cycles (length 6)
    }
}
```
`theme.charts.chart1…6` are public, accent-derived, and brightness-varied (DesignKit `ColorDerivation.derivedCharts`) — satisfies D-05 (accent palette), D-07 (low-hue lightness fallback built in). Grep gate (must be empty): `grep -rn "Color(red:\|Color(hex:\|\.green\b\|\.red\b\|\.blue\b" gamekit/gamekit/Games/Stack/`.

---

### `Screens/StackStatsCard.swift` (component, props-only read card)

**Analog:** `MergeStatsCard` (StatsView.swift:253-294) + `MergeModeStatsRow` (296-339).

**Props-only signature** (StatsView.swift:253-256) — data-driven, never `@Query` (CLAUDE.md §8.2). MUST be its own file (StatsView.swift is already 496 lines, near the §8.5 hard cap):
```swift
struct StackStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]
    // ...
}
```

**Empty state first** — copy the `records.isEmpty` branch (StatsView.swift:259-263): "No Stack games played yet." (§8.3).

**Field derivation** (research Pattern 3, lines 326-331; filter pattern from MergeModeStatsRow.swift:302-311):
```swift
let highScore  = bestScores.first { $0.difficultyRaw == "endless" }?.score
let bestStreak = bestScores.first { $0.difficultyRaw == "perfectStreak" }?.score
let runsPlayed = records.count   // all stack records are "endless" → no filter needed
```
Three metrics only (D-10): high score · runs played · best perfect streak. Minimal layout — full ARCADE-07 shape is Phase 18. Numbers use `theme.typography.monoNumber.monospacedDigit()` (MergeModeStatsRow.swift:326-328). Add `.accessibilityElement(children: .combine)` + label (line 336-337).

---

### `Core/GameStats.swift` (service, SwiftData firewall) — MODIFY

**Analog:** existing `record(gameKind:mode:outcome:score:)` (GameStats.swift:113-144) + `evaluateBestScore` (261-289). The full `recordStackRun` body is in 16-RESEARCH.md Pattern 3 (lines 302-321). Key invariants to copy from the existing score path:

- Insert `GameRecord` FIRST (mode `"endless"`, `outcome: .loss`, `score:`), evaluate `BestScore` SECOND wrapped in best-effort `do/catch`, `try modelContext.save()` THIRD (GameStats.swift:119-143). One `GameRecord` per run keeps runs-played honest.
- Two `evaluateBestScore` calls in ONE save: mode `"endless"` (high score) and mode `"perfectStreak"` (streak). Reuses the higher-only logic verbatim (lines 261-289) — equal-score is a no-op.
- Add `static let stackEndlessMode = "endless"` / `stackPerfectStreakMode = "perfectStreak"` — **permanent serialization keys; renaming = data break** (research line 405).
- This is **additive — not a schema change** (no new `@Model`, no migration, no `schemaVersion` bump). CloudKit-safe (D-11).
- `resetAll()` already deletes all `BestScore` rows (GameStats.swift:180) → streak clears for free. Verify no Stack-specific UserDefaults needs adding to the `resetAll` clear list (lines 186-194) — Stack persists nothing in UserDefaults this phase, so likely none.

---

### `Screens/HomeView.swift` (route) — MODIFY (one-line swap)

**Analog:** existing `.stack` case (HomeView.swift:381-383). Swap `StackHarnessView()` → `StackGameView()`. Keep `.disableInteractivePop()`; keep NO `.videoModeAware()` (ADR ARCADE-08 comment, lines 378-380, stays). Snake's `.snake` case (line 384-386) is untouched (Phase 17).

---

### `Screens/StatsView.swift` (view, section host) — MODIFY

**Analog:** existing `.merge` section (StatsView.swift:172-177). Replace the Stack placeholder block (lines 221-230) with the real card, mirroring the Merge shape:
```swift
if shows(.stack) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "STACK")) }
    DKCard(theme: theme) {
        StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)
    }
}
```
The `stackRecords` / `stackBestScores` `@Query` pairs already exist (StatsView.swift:127-135) — no new query needed.

---

### `gamekitTests/Games/Stack/StackEngineTests.swift` (test) — NEW

**Analog:** `gamekitTests/Engine/MergeEngineTests.swift:18-23` (`nonisolated @Suite` — engine is Foundation-only, no actor isolation needed).
```swift
import Testing
import Foundation
@testable import gamekit

@Suite("StackEngine determinism")
nonisolated struct StackEngineTests { /* ... */ }
```
Required tests (research lines 447-480 + Validation map lines 568-571): `proMotionEquivalence` (SC2 — dt=1/60 ≡ dt=1/120 over 5s; full body at research lines 452-473), `completeMissGameOver`, `streakRecoveryAndReset` (D-01), `rampSpeedPlateau` (assert `rampSpeed(forScore: 80) == rampSpeed(forScore: 200)`). Use `StackConfig.testFixed` for deterministic runs.

---

### `gamekitTests/Core/GameStatsTests.swift` (test) — MODIFY

**Analog:** existing `@MainActor @Suite` + `makeStats()` in-memory container helper (GameStatsTests.swift:24-35) — SwiftData `ModelContext` is not Sendable, so `@MainActor` (not `nonisolated`). Add `recordStackRunWritesStreakWithoutSchemaChange` — full body at research lines 487-500. Asserts: exactly 1 `GameRecord` (runs honest), 2 `BestScore` rows ("endless" + "perfectStreak"), and higher-only behavior (a lower second run does not overwrite the streak).

---

## Shared Patterns

### SwiftData firewall (write side)
**Source:** `Core/GameStats.swift` — `@MainActor final class`, insert→evaluate(best-effort)→synchronous `save()` (lines 62-104, 113-144).
**Apply to:** `StackViewModel` (holds `GameStats?`, never imports SwiftData), `StackGameView` (`GameStats(modelContext:)` in `.task`). Save exactly once on game-over (Pitfall 12).

### Counter-trigger haptics (gated)
**Source:** `Core/VideoModeBanner.swift:126-129` + `Games/Merge/MergeViewModel.swift:31-37`.
**Apply to:** `StackViewModel` exposes `perfectCount`/`dropCount` Ints; `StackGameView` attaches `.sensoryFeedback(trigger: hapticsEnabled ? counter : 0)`. `hapticsEnabled` is the FIRST guard (DESIGN §8.2/§8.3 — haptics fire even when animations off). Game-over `.error` is owned by `VideoModeBanner` — never duplicate it.

### Reduce Motion / animation gating
**Source:** `Core/VideoModeBanner.swift:177-189` (`videoModeBannerTransition`) + research Pattern 5 (lines 367-376).
**Apply to:** `StackBoardCanvas` (snap camera, jump-cut block, no trim fall, no slow-mo when `reduceMotion`); `StackGameView` (skip the 500ms game-over pre-roll, instant cut to banner). Engine NEVER reads `reduceMotion` — render-layer only.

### Arcade loop + lifecycle
**Source:** `Games/Stack/StackHarnessView.swift:40-70, 135-149` (consuming `Core/ArcadeLoopDriver` + `Core/ArcadeGameState`).
**Apply to:** `StackViewModel` (accumulator/start/pause/resume/stop) + `StackGameView` (`.arcadeLoop` + scenePhase `.inactive`/`.background` both pause). No second `dt` clamp.

### DesignKit token discipline
**Source:** every analog reads `theme.colors.*` / `theme.typography.*` / `theme.spacing.*` / `theme.radii.*` / `theme.charts.*`; zero literals.
**Apply to:** all `Games/Stack/*` files. Grep gate must be empty for `Color(red:`/`Color(hex:`/system color names. §8.12 audit on Classic + Voltage/Dracula before done.

### Props-only data-driven views
**Source:** `MergeStatsCard` (StatsView.swift:253-294) — receives `records`/`bestScores`, never `@Query`.
**Apply to:** `StackStatsCard` (own file), `StackBoardCanvas` (reads injected engine snapshot). Parent owns the query/state.

---

## No Analog Found

| File | Role | Data Flow | Reason | Planner Guidance |
|------|------|-----------|--------|------------------|
| `Games/Stack/StackBoardCanvas.swift` | view (Canvas) | streaming (per-frame) | No real-time `Canvas` board exists in repo — all current games are turn-based view-tree renders | Use RESEARCH Pattern 4 (lines 343-363): `ctx.fill(_, with: .color(token))`, camera in view layer with accumulator-remainder interpolation, RM snap. Token discipline + Pitfall 18 (no `.animation()` on board state) are the binding rules. |
| `Games/Stack/StackPalette.swift` | utility | transform | No accent-ramp helper exists | RESEARCH Pattern 4 exact snippet (lines 348-355) — `theme.charts.chart1…6` cycle. |
| `Games/Stack/StackConfig.swift` | config | static | No dedicated config-struct precedent (engines inline their constants) | Split-out for §8.1 file-cap. Values from Tuning Constants table (research lines 503-520). |

---

## Metadata

**Analog search scope:** `gamekit/gamekit/Games/{Merge,Stack,Minesweeper}`, `gamekit/gamekit/Core`, `gamekit/gamekit/Screens`, `gamekit/gamekitTests/{Engine,Core}`
**Files scanned (read):** MergeViewModel, StackHarnessView, VideoModeBanner, GameStats, MergeEngine (head), StatsView (3 ranges), GameStatsTests (head), MergeEngineTests (head), MergeGameView (2 ranges), HomeView (.stack case)
**Pattern extraction date:** 2026-06-27
