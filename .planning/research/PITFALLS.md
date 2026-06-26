# Pitfalls Research

**Domain:** Real-time endless arcade games added to a turn-based SwiftUI logic-game suite (GameDrawer v1.5 — Stack + Snake)
**Researched:** 2026-06-25
**Confidence:** HIGH (repo-specific analysis from codebase + verified gamedev literature)

> This file is scoped entirely to the risks that arise when a frame loop enters a codebase
> whose entire prior history is turn-based deterministic logic. Generic iOS advice is excluded;
> every pitfall here is specific to the interaction between the real-time loop and this stack
> (Swift 6 / SwiftUI / SwiftData / DesignKit / SettingsStore / CloudKit).

---

## Critical Pitfalls

Mistakes that cause rewrites, persistent data corruption, or P0 regressions.

---

### Pitfall 1: Frame-rate-dependent physics — movement tied to frame count, not dt

**What goes wrong:**
Snake's grid step or Stack's block slide speed is expressed as "move N cells per tick" rather
than "move N cells per second of real time". On a 60 Hz device the snake moves at the designed
speed. On a 120 Hz ProMotion device it moves twice as fast. On a loaded device that drops to 30 Hz
it moves half as fast. Because the existing engines are turn-based (one player action = one step),
there is no dt in the codebase yet, and the temptation to write `step()` without one is high.

**Why it happens:**
Turn-based games ignore dt entirely — a tap triggers a step, done. When a developer ports that
mental model to a continuous loop, the engine tick is called every frame and speed becomes a
function of hardware, not design intent.

**How to avoid:**
The substrate contract defined in the brief is correct: `mutating func step(dt: Double, input: Input) -> Frame`.
Every velocity in Stack (pixels per second) and every speed ramp in Snake (cells per second) must be
expressed in real-time units and multiplied by dt inside the engine, never inside the view. Lock this
in the engine protocol before writing either game, and add a unit test that runs the same engine at
dt=1/60 vs dt=1/120 and asserts identical game-seconds-elapsed-to-collision within epsilon.

**Warning signs:**
- Any engine property named `speedPerFrame`, `stepsPerTick`, or `moveEveryN` without a time unit.
- Speed ramp tests that use frame counts instead of elapsed seconds.
- Snake that "feels faster" on an iPad Pro vs an iPhone.

**Phase to address:** Substrate phase (Phase 1 — loop driver + engine contract). The dt parameter
must be in the contract before any game engine is written.

---

### Pitfall 2: Spiral of death in fixed-timestep accumulator

**What goes wrong:**
The fixed-timestep accumulator is the correct pattern (verified against Gaffer on Games), but if
`dt_fixed` is too small or the simulator runs slow, the accumulator fills faster than the engine
drains it. Each frame tries to catch up by running more ticks, which takes longer, which adds more
lag, which requires even more catch-up — a death spiral. The app freezes, the watchdog kills it.

**Why it happens:**
Developers implement the accumulator correctly but omit the max-dt clamp. A thermal throttle event,
a debugger breakpoint resumption, or a cold-start frame spike fills the accumulator with 500ms at once.
Without the clamp, the loop attempts ~30 fixed steps on that one frame.

**How to avoid:**
Always clamp the real-time delta before accumulating: `let frameDt = min(realDt, 0.25)`. This means
the simulation accepts at most 0.25 s of game-time per render frame, yielding a brief slow-motion
effect under load rather than a lockup. For Stack and Snake (grid-step logic), a fixed step of
1/60 s is appropriate. The clamp of 0.25 s allows at most 15 steps per frame before it cuts off —
plenty of headroom, never runaway.

**Warning signs:**
- Accumulator code that does not cap `realDt` before the while loop.
- The game "speed-skips" a half-second of game action after the debugger resumes.
- Unit tests that inject dt=10.0 and hang instead of terminating cleanly.

**Phase to address:** Substrate phase (Phase 1). The clamp is a one-liner but must be part of the
substrate, not added later per game.

---

### Pitfall 3: ProMotion 120 Hz divergence — physics speed doubles on newer iPhones

**What goes wrong:**
If the loop driver does NOT use fixed-timestep accumulator (or passes raw display-link dt to a
speed-times-dt engine without bounding it), the engine runs twice as many logic ticks per second
on a 120 Hz device than the developer tested on. Snake collides with itself twice as quickly; Stack's
block reaches the edge twice as fast. The game is unintentionally harder on premium hardware — the
inverse of the intended calm-endless feel.

**Why it happens:**
`TimelineView(.animation)` fires at the display rate, which is 120 Hz on ProMotion devices. If the
engine receives raw dt (about 8.3ms) at 120 Hz instead of the 60 Hz assumed during design (16.6ms),
all time-based logic is correct — BUT grid-based games like Snake that use "advance one cell per tick
at rate R" may inadvertently tick faster if the game step is tied to the display frame rather than
a fixed interval derived from the speed setting.

**How to avoid:**
Two-part protection: (a) use the fixed-timestep accumulator so Snake's grid step fires at a designed
interval (e.g. 0.2 s / cell at default speed), never at display rate; (b) explicitly run on-device
tests on a ProMotion simulator profile AND a 60 Hz simulator profile before merging any engine.
Do not rely on `preferredFramesPerSecond`/`maximumFramesPerSecond` as the fix — use the accumulator.

**Warning signs:**
- Snake speed settings expressed as "N frames between steps" rather than "N seconds between steps".
- No simulator test on the iPad Pro (120 Hz) profile before shipping.
- Speed unit tests that hard-code 60-step sequences without asserting wall-clock equivalence.

**Phase to address:** Substrate phase (Phase 1) — the accumulator is the structural fix. Snake
phase (Phase 3) — add device-rate regression test.

---

### Pitfall 4: Engine impurity — timing and physics leak into the ViewModel or View

**What goes wrong:**
The existing pattern (BoardGenerator, RevealEngine, WinDetector) is pure Foundation — no SwiftUI
imports, no modelContext. That purity is what makes unit tests trivial. Real-time games tempt
developers to put "just this one thing" in the ViewModel: `Date.now` for elapsed time, `CGSize`
for block positioning, a `CADisplayLink` callback that modifies `@Published` state directly. Once
one SwiftUI dependency enters the engine, the engine can no longer be tested headlessly — every
test needs a running RunLoop or a SwiftUI host.

**Why it happens:**
The real-time loop lives in a ViewModel (the natural home for SwiftUI state), and it is convenient
to read `Date.now` or `UIScreen.main.bounds` directly inside the step function rather than injecting
them as parameters.

**How to avoid:**
Enforce the contract from the brief: `mutating func step(dt: Double, input: Input) -> Frame`.
The engine receives dt as a Double (Foundation primitive), input as an enum, and returns a Frame
value type. It never calls `Date.now`, never reads screen geometry, never accesses the modelContext.
The ViewModel owns the loop driver, snapshots the clock once per frame, and feeds dt+input to the
engine. Tests pass arbitrary dt sequences and assert on the returned Frame — no RunLoop needed.
Write the engine test suite first, then the ViewModel, then the View.

**Warning signs:**
- `import SwiftUI` or `import UIKit` appearing in StackEngine.swift or SnakeEngine.swift.
- An engine `init` that takes a `CGRect` or `UIScreen`.
- A unit test that requires `@MainActor` or a `XCTestExpectation` with a RunLoop wait.

**Phase to address:** Substrate phase (Phase 1) — the contract is fixed. Each game phase (2, 3)
— review engine file imports at PR time.

---

### Pitfall 5: Non-deterministic RNG breaks unit tests and makes bugs non-reproducible

**What goes wrong:**
Stack's food position (or Snake's food spawn) uses `Int.random(in:)` or `CGFloat.random(in:)`
without a seeded generator. Every test run produces a different sequence. A bug that only manifests
on a specific food-spawn position becomes non-reproducible. CI never catches it. Player reports "the
game freezes sometimes" and no one can reproduce it.

**Why it happens:**
Swift's `SystemRandomNumberGenerator` (the default behind `random(in:)`) is not seedable. Developers
reach for `random(in:)` because it is idiomatic Swift, not realizing it severs determinism.

**How to avoid:**
Use a custom seedable generator conforming to `RandomNumberGenerator`. The correct implementation
for iOS is `var rng = SeedableRNG(seed: UInt64)` passed to `random(in:using: &rng)`. The seed is
stored in the engine state (part of the Frame or engine struct). Tests fix the seed to reproduce
specific sequences. For production, seed from `UInt64.random(in:)` at game start and store the seed
in the engine for potential replay/debug export. This mirrors the pattern game engines at all scales
use (verified: Gaffer on Games, Swift Forums Deterministic Randomness thread).

**Warning signs:**
- `Int.random(in:)` without a `using:` parameter inside any engine file.
- Unit tests that pass sometimes and fail sometimes ("flaky tests").
- Food spawn logic that lives in the ViewModel rather than in the engine.

**Phase to address:** Each game phase (2, 3) — enforce in engine review before first test is written.

---

### Pitfall 6: Loop driver not paused on background / game-over — battery drain and wrong elapsed time

**What goes wrong:**
`TimelineView(.animation(paused:))` is the correct API, but if the `paused:` parameter is not wired
to game lifecycle state (idle, running, paused, game-over), the timeline continues firing 60+ times
per second when the game is on the game-over screen or when the app is backgrounded. On background:
iOS may suspend the process eventually, but during the grace period the loop drains battery. On
game-over screen: the "time elapsed" keeps accumulating even while the banner is visible, corrupting
the high-score timestamp.

Additionally, if `scenePhase` transitions are not handled (`.inactive` — save position, `.active`
— resume), the elapsed-since-background delta is injected into the engine on resume, instantly
killing the snake via the accumulated dt.

**Why it happens:**
The existing games (Minesweeper, Sudoku, etc.) have no loop driver — they are tap-triggered.
Adding a TimelineView is new infrastructure, and the `paused:` parameter and scenePhase wiring
are easy to forget as "we will add that later."

**How to avoid:**
Design the lifecycle state machine first: idle → running → paused → game-over → idle. The
`paused:` binding on `TimelineView(.animation(paused: viewModel.isLoopPaused))` must be a first-class
concern in Phase 1, not an afterthought. Additionally:
- On `scenePhase == .inactive/.background`: call `viewModel.pauseLoop()`, which sets `isLoopPaused = true`
  AND snapshots `Date.now` for resume correction.
- On `scenePhase == .active` from background: resume only if the game was running (not game-over);
  discard the backgrounded interval rather than injecting it as dt.
- On game-over: set `isLoopPaused = true` immediately, before showing the banner.

**Warning signs:**
- TimelineView with no `paused:` binding.
- No `onChange(of: scenePhase)` in the game view.
- High score increases after the game-over banner appears.
- Battery profiler shows 60 Hz GPU work while the game-over screen is static.

**Phase to address:** Substrate phase (Phase 1) — lifecycle state machine and loop pause/resume
must be part of the shared substrate, not added per game.

---

### Pitfall 7: SwiftUI view-tree churn per frame — Canvas bypass never considered

**What goes wrong:**
A developer builds Snake as a `LazyVGrid` of 400 cell views, each reading `snakeEngine.board[r][c]`.
On each tick, `@Observable` invalidates every cell view because the engine emits a new board snapshot.
SwiftUI diffs 400 views 60 times per second. On a large grid, this manifests as dropped frames and
CPU heat, which reads as poor battery life. The existing turn-based games never hit this because
they re-render on tap (rare), not on frame (60 Hz).

**Why it happens:**
The grid-of-views pattern is idiomatic and correct for Minesweeper (taps are rare). Developers
port it unchanged. The performance difference only surfaces under profiling at 60 Hz.

**How to avoid:**
For Snake and Stack, prefer `Canvas` over a view-tree grid for the game board. `Canvas` uses
immediate-mode drawing: one view, one draw call, no diffing. The `TimelineView` + `Canvas` combination
is the Apple-documented pattern for continuous animation (WWDC 2021 "Add rich graphics to your SwiftUI
app"). The canvas closure receives the current engine frame via a closure capture, draws directly, and
never touches SwiftUI layout. Keep the chrome (score chip, game-over banner, restart button) in the
view tree — those update rarely. Only the game board pixels go through Canvas.

**Warning signs:**
- `ForEach(board.cells)` inside a `LazyVGrid` called from inside a `TimelineView`.
- Core Animation instruments showing 60 Hz layout passes (not just display passes).
- Frame rate drops on grid sizes above 15×15 in the simulator.

**Phase to address:** Each game phase (2 for Stack, 3 for Snake) — decide Canvas vs. grid
at architecture stage, not after profiling reveals the problem.

---

### Pitfall 8: Swift 6 concurrency — CADisplayLink callback crossing actor boundary

**What goes wrong:**
If the loop driver is a `CADisplayLink` (the alternative to `TimelineView`), the display link
callback fires on a background thread (or a dedicated thread, depending on the RunLoop). In Swift 6
strict concurrency, any mutation of `@MainActor`-isolated ViewModel properties from that callback
is a data-race error that the compiler rejects. Developers either suppress the error with
`@preconcurrency` bandaids or, worse, schedule a `DispatchQueue.main.async` hop inside the callback
— which adds one full frame of latency between physics and display.

**Why it happens:**
CADisplayLink predates Swift concurrency. Its callback signature is `@objc func displayLinkFired(_:)`
on a class that must be `NSObject`. Bridging this to Swift 6's actor model is non-trivial and
under-documented.

**How to avoid:**
Prefer `TimelineView(.animation(paused:))` as the loop driver. `TimelineView` fires its closure on
the `@MainActor` because it is a SwiftUI view — no actor hop required, no Sendable issues. The
closure receives a `TimelineView.Context` with `.date` for timing. Feed `context.date.timeIntervalSinceReferenceDate - lastDate` as dt to the engine. If CADisplayLink is chosen for any reason (e.g. precise vsync timing for Stack), it must be wrapped in a `@MainActor` nonisolated bridge class and its Sendable chain verified at compile time, not suppressed. Document the rationale in an ADR.

**Warning signs:**
- `DispatchQueue.main.async` inside any display-link callback.
- `@preconcurrency import QuartzCore` to silence Sendable warnings.
- `nonisolated` on ViewModel methods that mutate `@Published` state.

**Phase to address:** Substrate phase (Phase 1) — choose `TimelineView` over CADisplayLink by
default; document the decision so future phases do not revisit it.

---

### Pitfall 9: scenePhase double-counting elapsed time on resume

**What goes wrong:**
The game is running. User receives a notification; app enters `.inactive` for 2 seconds, then
returns to `.active`. If the ViewModel does not snapshot the pause timestamp on `.inactive` and
subtract the gap on `.active`, the next frame's dt is 2.0 seconds. The engine receives `step(dt: 2.0)`
and interprets it as 2 real seconds of game time. The snake teleports across the board and self-collides.
Or worse, if the loop uses a Date-difference without the clamp from Pitfall 2, the accumulator fills
with 2 s and runs 120 fixed steps in one frame.

**Why it happens:**
scenePhase wiring is new to this codebase (no existing game needs it). Developers add the `onChange`
but only handle `.background`, missing the subtler `.inactive` state (notification banners, control
center, incoming call) which also suspends the loop for seconds.

**How to avoid:**
On ANY scenePhase transition away from `.active`, immediately record `pausedAt = Date.now` and set
`isLoopPaused = true`. On return to `.active`, compute `adjustedLastFrameDate = Date.now` rather
than using `pausedAt` — effectively discarding the gap. The engine never sees the backgrounded
interval. Handle `.inactive` and `.background` identically. The max-dt clamp from Pitfall 2 is
a second line of defense but not a substitute for correct pause wiring.

**Warning signs:**
- `onChange(of: scenePhase)` that only handles `.background`, not `.inactive`.
- The snake "exploding" after a notification banner appears and is dismissed.
- Elapsed game timer jumping forward when returning from multitasking switcher.

**Phase to address:** Substrate phase (Phase 1) — the lifecycle state machine must handle all
three scenePhase states before either game is built on top of it.

---

### Pitfall 10: Gesture conflicts — swipe-to-turn vs. navigation back-swipe

**What goes wrong:**
Snake requires a swipe gesture for direction input. iOS's NavigationStack edge-swipe-back gesture
also responds to a horizontal swipe starting near the left edge. The player swipes left to turn the
snake and accidentally navigates back to the Home screen. Game state is lost; frustration is high.
A second variant: any full-screen drag gesture conflicts with the system's notification pull-down
(top edge) or Control Center (top-right edge on iPhone) unless `defersSystemGestures` is applied.

**Why it happens:**
The existing games use tap gestures (Minesweeper long-press for flag, Merge directional swipe on the
whole board via a different gesture stack). Snake is the first game with swipe input in all four
cardinal directions. The navigation back conflict only matters for swipe games — tap games are immune.

**How to avoid:**
Three mitigations applied together:
1. `navigationBarBackButtonHidden(true)` is already required by DESIGN.md §6 — this does NOT disable
   the swipe-back gesture unless the NavigationStack is also configured or `UIGestureRecognizerRepresentable` (iOS 18+) is used to disable it.
2. Add `.defersSystemGestures(on: .all)` on the snake board view to claim priority over system edges.
3. For the swipe input on Snake, use `DragGesture(minimumDistance: 10)` with direction clamping
   to the four cardinals, not a `SwipeGesture` (which has less configuration surface). Alternatively,
   implement tap-to-turn (tap left half = turn left, tap right half = turn right) as the primary
   input — simpler, no gesture conflict, already mentioned in the brief. Choose at design time, not
   after shipping a conflicting swipe.

**Warning signs:**
- Player can swipe back during active play.
- Swipe-left input occasionally navigating away instead of turning.
- No `defersSystemGestures` modifier on the game board.

**Phase to address:** Snake phase (Phase 3) — design the input verb before writing gesture code;
test on device (not just simulator) where edge interference is real.

---

### Pitfall 11: SwiftData schema corruption — adding score fields without CloudKit-safe defaults

**What goes wrong:**
The existing `GameRecord` and `BestTime` models support turn-based games (win/loss/time). Adding
a `highScore: Int` field (or `runsPlayed: Int`) for endless games without a default value or
marking it optional breaks CloudKit sync. CloudKit requires all attributes to be optional or have a
default value. Adding a non-optional field without a default causes `ModelContainer` initialization
to fail with a CloudKit schema validation error — the app crashes on launch for existing users.
Additionally, if the schema version is not bumped, `NSStagedMigrationManager` can produce the stale-
store crash (CLAUDE.md §8.9).

**Why it happens:**
Turn-based games fit naturally into `BestTime` (fastest completion time). Endless games need a
different shape (high score = highest value, not shortest time). Developers add a new property to
the existing model for convenience and forget the CloudKit optional rule.

**How to avoid:**
Keep score-based stats in a separate `@Model` type (e.g., `ArcadeRecord`) rather than shoehorning
them into `BestTime`. Mark ALL new properties `Optional` with a default of `nil`, or `= 0` / `= ""`.
Never add a required non-optional attribute to a CloudKit-backed model. Before shipping, verify
on a fresh simulator install AND on a simulator that has the prior-schema store. When adding a new
`@Model`, bump `ModelConfiguration` schema version and write a migration. Follow CLAUDE.md §8.9 for
the inevitable stale-simulator test failure.

**Warning signs:**
- A `@Model` property added without `?` and without `= defaultValue`.
- `ModelContainer` throwing on app launch after a schema change.
- CloudKit dashboard showing new field not deployed to production schema.

**Phase to address:** Persistence sub-phase within the substrate (Phase 1 or 2) — design
`ArcadeRecord` with CloudKit constraints before any game writes stats.

---

### Pitfall 12: High score saved on every frame tick instead of on game-over

**What goes wrong:**
The ViewModel watches `engine.frame.score` and calls `modelContext.insert(ArcadeRecord(...))` on
every frame where the score increases. At 60 Hz, a 30-second run writes 1,800 SwiftData inserts.
This causes: (a) significant CPU overhead, (b) disk I/O during active play, (c) the stats screen
showing hundreds of partial-run records instead of one completed-run record. CloudKit sync queue
floods with 1,800 change records.

**Why it happens:**
There is no prior art in this codebase for a score that increases continuously. Turn-based games
(Minesweeper, Sudoku) write one record per completed game. The habit of "save on event" has not
been tested against a 60 Hz event rate.

**How to avoid:**
Save exactly once, on game-over transition. The ViewModel watches `engine.frame.gameOver == true`
(a state transition, not a continuous value) and writes the final score to SwiftData. For force-
quit resilience, use `UserDefaults` to checkpoint the current run's score every N seconds (e.g.,
every 5 s), overwriting the same key — this is the one acceptable use of UserDefaults for gameplay
state per CLAUDE.md §1. On app re-launch after a force-quit, read the checkpoint and surface a
"run ended" record. Do not use SwiftData for mid-run checkpointing.

**Warning signs:**
- `modelContext.insert()` or `modelContext.save()` called inside the frame-tick closure.
- Stats screen showing run counts far higher than actual play sessions.
- Instruments showing disk I/O spikes during gameplay.

**Phase to address:** Persistence sub-phase (Phase 1/2). Establish the "save on game-over only,
checkpoint in UserDefaults" pattern before any game implements scoring.

---

### Pitfall 13: Reduce Motion path missing — motion-heavy game ships without an accessible fallback

**What goes wrong:**
Stack and Snake are by definition motion-heavy: continuous sliding animation (Stack block), continuous
locomotion (Snake body). A player with Reduce Motion enabled expects either no animation or a clearly
reduced one. Without a Reduce Motion path, the app fails Apple's Reduce Motion evaluation criteria
and is technically out of compliance with WCAG 2.3 (no mechanism to suppress non-essential animation).
This is also an App Store review risk — Apple's accessibility review specifically flags this for
games with continuous motion (verified: Apple Reduce Motion evaluation criteria docs).

The existing animation vocabulary (DESIGN.md §10.2) gates decoration animations (wash, confetti,
shake) but does NOT address continuous locomotion — a new category for this codebase.

**Why it happens:**
Developers follow the DESIGN.md §10.2 gate (which handles event animations) and consider the job done.
The distinction between "decoration animation" (suppress on Reduce Motion) and "locomotion animation"
(the snake moving IS the game) is not yet established in DESIGN.md for real-time games.

**How to avoid:**
Define the Reduce Motion behavior per game before writing animation code:
- Snake (Reduce Motion ON): Suppress the smooth-glide tweening between cells; jump-cut the
  snake's body to the next cell position each tick. The game is still playable; it just looks like
  a grid-based tile jump instead of a smooth slide. This is the correct treatment: the game mechanic
  is preserved, the continuous smooth motion is suppressed.
- Stack (Reduce Motion ON): Suppress the parallax/slide of the moving block between ticks; show
  the block at its computed position without interpolation. The drop-and-shave animation should also
  suppress its tween and hard-cut to the result.
- In both cases, do NOT pause the game or remove core gameplay. Reduce Motion gates VISUAL motion
  only, not game mechanics.
- Gate: `@Environment(\.accessibilityReduceMotion) var reduceMotion`. Use it in the View's rendering
  logic, not in the engine (the engine is always pure).

Add an explicit DESIGN.md §12 entry for real-time games before shipping.

**Warning signs:**
- No `accessibilityReduceMotion` check in any game view file.
- "Animations enabled" SettingsStore toggle treated as the only gate (it is different from the
  OS accessibility switch — both must be respected independently).
- Simulator testing done only in the default accessibility configuration.

**Phase to address:** Each game phase (2 for Stack, 3 for Snake). Reduce Motion behavior must be
specified in the design doc for each game before the first line of animation code is written.

---

### Pitfall 14: Feedback (haptics, SFX, animation) not gated by SettingsStore

**What goes wrong:**
A milestone event (Snake eats food: haptic + sound) fires without checking `settingsStore.hapticsEnabled`
or `settingsStore.sfxEnabled`. The player disabled haptics in Settings. The game ignores the preference.
This violates CLAUDE.md §1 ("Any haptics, confetti, sound, or celebratory animation must respect user
settings") and DESIGN.md §8.2 ("All haptic events are gated on `settingsStore.hapticsEnabled`"). It
is also the only way for the calm-first brand to degrade into an uncontrolled sensory experience.

The existing logic games gate haptics correctly. Real-time games add new event categories — continuous
movement haptics, speed-ramp sounds — that have no prior art in the codebase and are easy to forget.

**How to avoid:**
Explicitly enumerate every new haptic and SFX event per game before coding. For each:
1. What DESIGN.md §8.2 vocabulary class does it map to? (Normal move / milestone / win / error)
2. Is it gated by `settingsStore.hapticsEnabled` (for haptics) or `settingsStore.sfxEnabled` (for SFX)?
3. Is continuous-movement haptic warranted at all? (Almost certainly NO — a per-cell haptic at 60 Hz
   would be unusable. Haptics are for milestone events, not locomotion.)
4. Does `.sensoryFeedback` use a counter trigger (not a Bool) per DESIGN.md §8.2?

Add to DESIGN.md §12 game-specific rules for Stack and Snake before Phase 2 begins.

**Warning signs:**
- `.sensoryFeedback` or `UIImpactFeedbackGenerator` calls with no `if settingsStore.hapticsEnabled` guard.
- SFX that plays on every frame tick.
- A Bool toggle haptic instead of an incrementing counter trigger (misses rapid double-fires).

**Phase to address:** Each game phase (2, 3). Verified at the §12.5 done checklist gate.

---

### Pitfall 15: DesignKit token bypass — hardcoded neon/arcade colors for visual excitement

**What goes wrong:**
The game board for Stack or Snake is given a hardcoded neon green (`Color(hex: "#00FF00")`) or a
vivid gradient to make it "feel" like an arcade game. Under the Soft or Sweet presets, the neon
color is visually jarring; under Dracula/Moody it disappears entirely. The game is no longer legible
across the 34 DesignKit presets. This violates CLAUDE.md §1 (no hardcoded colors) and DESIGN.md §1.3,
and triggers the mandatory §8.12 theme audit that will fail and block the phase.

**Why it happens:**
Real-time games with a "retro arcade" association invite color choices that feel authentic to the
genre (green-on-black terminal aesthetic for Snake, bright primary-color Stack blocks). The existing
turn-based games do not have this pressure because their genre is "modern logic puzzle."

**How to avoid:**
Map game elements to semantic tokens before any color decision is made:
- Snake body: `theme.colors.accentPrimary` (player's active element — correct per DESIGN.md §2.2).
- Snake food: `theme.colors.success` (positive outcome — correct per DESIGN.md §2).
- Stack block (current): `theme.colors.accentPrimary`.
- Stack block (placed): `theme.colors.textSecondary` or a surface variant.
- Game over state: `theme.colors.danger`.
- Board background: `theme.colors.background`.

If a token is missing (e.g., a "placed tile slightly muted from accent" semantic), extend DesignKit
with a new token — do not hardcode locally. The calm-endless brand demands the game looks equally
correct under Chrome Diner and Dracula.

**Warning signs:**
- Any `Color(red:green:blue:)` or `Color(hex:)` in a game view file.
- Colors referenced as `.green`, `.red` (SwiftUI system colors, not semantic tokens).
- The board looking great on Classic but washed-out or invisible on Voltage.

**Phase to address:** Each game phase (2, 3). Review at design-token pass before visual implementation.
Mandatory §8.12 audit before done.

---

## Moderate Pitfalls

Significant regressions that require targeted fixes but not full rewrites.

---

### Pitfall 16: State thrash — ViewModel emits per-frame Observable updates causing full view diff

**What goes wrong:**
The ViewModel is `@Observable`. Every frame tick mutates `frame.score`, `frame.snakeBody`, etc.
SwiftUI observes all changed properties and schedules body re-evaluations for every view that reads
any of them. If the game view has a score chip, a board, AND a toolbar in the same body, all three
re-evaluate at 60 Hz — even though only the board changes meaningfully per frame. The score chip
does SwiftUI layout 60 times per second even when the score has not changed.

**How to avoid:**
Separate the ViewModel into rendering state (changes every frame, drives the Canvas/board) and UI
state (changes rarely: score updates, lives, game-over flag). The Canvas closure captures the engine
frame value directly; SwiftUI chrome (score chip, banner) reads only the UI-state properties. Use
`@Observable` with property-level observation granularity — only the specific properties that the
board view reads should invalidate the board view. Avoid publishing the entire engine frame as one
blob (`currentFrame: Frame`) if Frame is large; instead publish only the fields the chrome needs
(currentScore, isGameOver) and let the Canvas read the raw frame from a non-observed snapshot.

**Warning signs:**
- Instruments showing 60 Hz layout passes on views that only show score or game-over status.
- `body` of the game view logged more than the Canvas `draw` block.
- SwiftUI warning "onChange(of:) action tried to update multiple times per frame."

**Phase to address:** Each game phase (2, 3). Profile early with Instruments before finalizing
the state model.

---

### Pitfall 17: Cold-start regression — game-loop substrate increases app launch time

**What goes wrong:**
The substrate initializes a loop driver or engine state at app launch rather than lazily on game
entry. If allocation happens in `GameKitApp.swift`, any Core store `init`, or a view that is part
of the always-shown navigation stack, the Home screen load time increases. Cold-start under 1 s is
a P0 requirement (CLAUDE.md §1). The existing games have pure lazy initialization — the word list
loads when Word Grid is opened, not at app launch.

**How to avoid:**
The game-loop substrate must be initialized lazily: only when the player navigates to a Stack or
Snake game screen. `TimelineView` is only instantiated when the game view appears. No engine state
is pre-allocated in `GameKitApp.swift` or any cross-game Core store. Verify cold-start time on a
real device (not simulator) before and after adding each game. Use the Instruments "App Launch"
template.

**Warning signs:**
- Any game engine or engine-related allocation in `GameKitApp.swift`, `ThemeStore`, or any `init`
  called from the app scene.
- Cold-start profiler showing increased time in `GameKitApp.body`.
- TimelineView instantiated in a view that is part of the always-shown navigation stack.

**Phase to address:** Substrate phase (Phase 1) — establish the lazy-init pattern. Each game phase
(2, 3) — verify cold-start is unchanged before marking phase done.

---

### Pitfall 18: Animation fighting the manual loop — SwiftUI implicit animations interpolating engine state

**What goes wrong:**
The developer adds `.animation(.easeInOut(duration: 0.1), value: viewModel.frame.snakeBody)` to
smooth the snake's movement. SwiftUI creates implicit animations between successive body positions.
But the loop also manually positions the snake; the implicit animation runs behind the physics, causing
the visual snake to lag behind the engine's computed position. At game-over, the implicit animation
completes AFTER the game-over banner appears, creating a visual desync. If the game restarts while
an animation is in flight, the view snaps.

**How to avoid:**
Never apply implicit SwiftUI animations to game-board state that is driven by a manual loop. The
Canvas-based board draws the engine's computed positions directly (no SwiftUI animation needed).
The only smooth motion comes from interpolating between the previous and current engine frames using
the accumulator remainder (the alpha value from the Gaffer on Games pattern) inside the Canvas draw
call — no SwiftUI `.animation()` required. Reserve SwiftUI `.animation()` for chrome transitions
(game-over banner appearing, score chip updating) per the existing DESIGN.md vocabulary.

**Warning signs:**
- `.animation()` modifier on any view or property that updates 60 times per second.
- The snake's visual position lagging behind where taps "feel" like they should register.
- SwiftUI "onChange(of:) action tried to update multiple times per frame" warning.

**Phase to address:** Each game phase (2, 3). Established as a principle in the substrate design.

---

## Minor Pitfalls / Process Traps

Repo-specific process traps from CLAUDE.md §8, extended for v1.5.

---

### Pitfall 19: Finder-dupe files — "SnakeEngine 2.swift" causes redeclaration compile error

**What goes wrong (CLAUDE.md §8.7):**
Xcode 16 uses `PBXFileSystemSynchronizedRootGroup` — every `.swift` file in a folder is automatically
compiled. If a Finder copy creates `SnakeEngine 2.swift` alongside `SnakeEngine.swift`, both compile,
the compiler sees duplicate `SnakeEngine` type declarations, and the entire target fails to build.
This is especially likely when the AI assistant generates a new engine file and the developer
simultaneously has the prior draft open.

**How to avoid:** Check `git status` for `?? *2.swift` files before every build. Delete dupes
immediately. Never use Finder's "duplicate" on a `.swift` file.

**Phase to address:** Every phase. Add to done checklist: "No `* 2.swift` files in `git status`."

---

### Pitfall 20: Hand-editing pbxproj to register new engine files

**What goes wrong (CLAUDE.md §8.8):**
A developer adds `StackEngine.swift` to `Games/Stack/` and then also edits `project.pbxproj` to
register it, following old Xcode habits. Synchronized root group picks up the file automatically.
The hand edit creates a duplicate entry, causing Xcode to show the file twice in the project navigator
and sometimes failing to compile the target.

**How to avoid:** Drop the file into the folder. Do not touch `pbxproj` unless adding a new top-level
folder or changing target membership. New files in existing game folders auto-register.

**Phase to address:** Every phase. Part of the existing CLAUDE.md §8.8 rule, included here for visibility.

---

### Pitfall 21: Monolithic loop + engine + view model in one file exceeding 500 lines

**What goes wrong (CLAUDE.md §8.5):**
The loop driver, the engine, the ViewModel, and the view scaffolding end up in one file
(`SnakeGame.swift`) because they are developed together. File grows past 500 lines. Future sessions
have trouble navigating it. The hard 500-line cap becomes impossible to enforce after the fact.

**How to avoid:** Establish the split before writing code:
- `Core/ArcadeLoopDriver.swift` — loop substrate, lifecycle, dt computation (target <100 lines)
- `Games/Snake/SnakeEngine.swift` — pure Foundation engine (target <200 lines)
- `Games/Snake/SnakeViewModel.swift` — @Observable ViewModel, owns loop driver and engine (target <150 lines)
- `Games/Snake/SnakeView.swift` — SwiftUI view, Canvas board, chrome (target <200 lines)
- `Games/Snake/SnakeInputHandler.swift` — gesture recognizers, input enum mapping (target <100 lines)

Each file must be planned under 400 lines. Split at phase design time, not after the fact.

**Phase to address:** Substrate phase (Phase 1) — establish the file split template. Each game
phase (2, 3) — use the template.

---

### Pitfall 22: NSStagedMigrationManager crash after adding ArcadeRecord model

**What goes wrong (CLAUDE.md §8.9):**
When `ArcadeRecord` is added as a new `@Model`, the simulator's existing SwiftData store does not
have the new entity. On next test run, `NSStagedMigrationManager` attempts to reconcile the old
store with the new schema and crashes during the host-app launch with
`_findCurrentMigrationStageFromModelChecksum:` in the stack trace.

**How to avoid:** Per CLAUDE.md §8.9 — do not debug this crash; uninstall the app from the test
simulator: `xcrun simctl uninstall <device-id> com.lauterstar.gamekit`. Then re-run tests. Add this
step to the test runner runbook comment in any phase that adds a new `@Model`. Also: write an automated
migration stage (even a trivial identity migration) when adding `ArcadeRecord` so future schema
additions have a documented migration path.

**Phase to address:** Persistence sub-phase (Phase 1/2). Document in the phase PLAN.md.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use variable dt (skip accumulator) | Simpler loop, one fewer concept | Frame-rate-dependent physics; ProMotion bugs; untestable engine behavior | Never — the accumulator is a one-liner |
| Store game loop in the View (not ViewModel) | No ViewModel boilerplate | Engine tied to SwiftUI render cycle; untestable; violates MVVM | Never |
| `Int.random(in:)` without seeded RNG | Simpler spawn code | Flaky tests; non-reproducible bugs; no seed-share debug path | Never in engine code |
| Skip `paused:` binding on TimelineView | Fewer state vars | Battery drain on game-over; loop runs in background; incorrect elapsed time | Never |
| Save high score inside step() | Convenient | SwiftData overwhelmed at 60 Hz; CloudKit flood; partial-run records | Never |
| Use a view grid for the board | Idiomatic SwiftUI | Frame drops at board sizes above ~10×10 at 60 Hz | Acceptable as a prototype only; switch to Canvas before shipping |
| Hard-code a fixed 60 Hz loop rate | Simpler math | 120 Hz devices run physics twice as fast; 30 Hz devices run it half as fast | Never |
| `.animation()` on engine-driven state | "Free" smooth motion | Visual lag behind physics; desync on restart; hard to remove later | Never for board state; fine for chrome/banner |
| Add high-score field to existing BestTime model | One fewer model type | CloudKit optional constraint violated; schema migration required anyway | Never — create ArcadeRecord |

---

## Integration Gotchas

Risks at the boundary between the new real-time substrate and existing GameDrawer systems.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| DesignKit motion tokens in real-time board | Using `theme.motion.slow` inside the Canvas draw loop for per-frame interpolation | Use raw seconds (e.g., `0.016`) inside the engine; use motion tokens only for chrome animations (banner, score chip) |
| SettingsStore haptics gate | Checking `settingsStore.hapticsEnabled` inside the engine | Check in the ViewModel's event observer; never let SettingsStore dependency enter the engine |
| SwiftData ModelContainer shared across all games | Adding ArcadeRecord without optional defaults | All new @Model fields must be optional or have a default; verify on clean + upgraded simulator |
| VideoModeBanner reuse | Reusing VideoModeBanner verbatim with "elapsed time" subtitle (meaningless for score-based game) | Adapt the subtitle slot to show final score; confirm Video Mode exemption for real-time games (per v1.5 brief open decision) |
| ThemeManager environment injection | Reading ThemeManager inside the engine for token colors | Pass resolved color values as parameters from the View layer into Canvas; engine never reads environment |
| NavigationStack back gesture | Left-swipe input for Snake triggering navigation pop | Apply `defersSystemGestures` and test the edge swipe on device, not simulator |
| scenePhase wiring | Only watching at the View level (can be missed if the game view is not the root scene observer) | Watch scenePhase from the game View's `onChange`, forward it immediately to the ViewModel via a method call |

---

## Performance Traps

Patterns that cause frame drops under real gameplay conditions.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `ForEach` grid of cell views inside TimelineView | CPU over 80% during play; Instruments layout pass every frame | Replace board grid with `Canvas`; keep chrome in view tree | Breaks at ~10×10 grid, 60 Hz |
| `@Observable` publishing entire Frame struct per tick | All views reading any Frame property re-render at 60 Hz | Separate rendering state (Canvas capture) from UI state (@Observable); only publish score/gameOver/lives | Breaks any time the ViewModel has more than 2 consumers |
| Score chip reading engine frame every tick | Score chip re-layouts 60 Hz even when score unchanged | Debounce: only update score chip when `frame.score != displayedScore` | Breaks when chrome is in same observed scope as the board |
| Allocating per-frame data structures | GC pressure, stutters every N frames | Pre-allocate board arrays in engine init; mutate in place | Breaks at high tick rates with large boards |
| SwiftData save() inside frame tick | Disk I/O on main thread at 60 Hz; frame drops, thermal throttle | Save only on game-over; checkpoint score in UserDefaults every 5 s | Breaks immediately at 60 Hz |
| CADisplayLink without actor hop fix | Sendable violations in Swift 6, race conditions | Use TimelineView as the loop driver instead | Breaks at compile time in Swift 6 |

---

## UX Pitfalls

Brand and user experience risks specific to the calm-endless category.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No Reduce Motion path | Motion-sensitive users cannot play; App Store review flag | Implement jump-cut rendering when `accessibilityReduceMotion == true`; specify this in design before coding |
| Speed ramp too aggressive | Game feels like twitch reflex, not calm endless — brand violation | Tune ramp curve so first 2 minutes feel meditative; conduct a play-test at design time |
| Haptic on every snake step | Haptic "buzzing" at 5 Hz is nauseating | Haptics only for milestone events (food eaten = `.medium`; game over = `.error`); no per-step haptic |
| Game-over banner blocks the final frame | Player cannot see what killed them | 500ms pre-roll delay (DESIGN.md §10.3); during pre-roll, board is visible and frozen |
| Score displayed mid-game with live counter animation | Constant animated change distracts from calm play | Score visible but non-animated mid-game; save animation for food-eat milestone flash only |
| High-score pressure UI | Anxiety-inducing compare-and-fail loop — brand violation | Show "your best" as a quiet secondary label; do not build a prominent shame UI |
| Illegible blocks under Loud/Moody presets | Game board unplayable for a third of presets | §8.12 mandatory audit: Classic + Voltage (or Dracula) before marking any phase done |
| Tap-to-start absent — game starts on navigation | Player surprised by live game board mid-swipe | Implement idle state with clear "tap to start" before the loop begins |

---

## "Looks Done But Isn't" Checklist

Items that appear complete during development but are missing critical pieces.

- [ ] **Loop driver:** The TimelineView fires — but is `paused:` wired to lifecycle state? Verify game-over, background, and inactive all pause the loop.
- [ ] **Engine purity:** The engine builds and tests pass — but does `SnakeEngine.swift` contain `import SwiftUI`? Check imports.
- [ ] **Fixed timestep:** Physics feel correct in the simulator — but has it been tested at 120 Hz (iPad Pro simulator profile)? Run the device-rate test.
- [ ] **Seeded RNG:** Food spawns work — but does the test fix the seed? Run the food-spawn test twice; assert identical output.
- [ ] **SwiftData:** The app launches — but was `ArcadeRecord` added without an optional default? Verify on a simulator with the prior schema store installed.
- [ ] **Reduce Motion:** Game plays smoothly — but does it play at all with Reduce Motion enabled? Test in Simulator > Accessibility > Reduce Motion.
- [ ] **SettingsStore gate:** Haptic fires on food — but is it gated by `settingsStore.hapticsEnabled`? Check with haptics OFF in Settings.
- [ ] **Token audit:** Board looks great on Classic — but has it been checked on Voltage or Dracula? Mandatory §8.12 check.
- [ ] **scenePhase:** Game pauses on app switch — but does it also pause when a notification banner appears (`.inactive` state)? Simulate incoming call.
- [ ] **Cold-start:** App launch feels fast — but was cold-start time measured on device before and after adding the new game? Run the Instruments "App Launch" template.
- [ ] **File sizes:** Phase complete — but has any game file crossed 400 lines? Check file lengths before committing.
- [ ] **No dupe files:** Build passes — but is there a `SnakeEngine 2.swift`? Check `git status` for `??` files.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Frame-rate-dependent physics discovered post-ship | HIGH — engine rewrite | Introduce dt parameter to `step()`, convert all speed constants to units/second, add ProMotion test |
| Spiral of death freeze in production | MEDIUM — one-liner fix | Add `let frameDt = min(realDt, 0.25)` before accumulator, ship patch |
| SwiftData schema corruption (crash on launch) | HIGH — data migration required | Write `VersionedSchema` + `SchemaMigrationPlan`; test on clean and upgraded simulator; deploy CloudKit schema |
| High score saved 1,800 times per session | MEDIUM — remove save from tick, add game-over save | Audit all `modelContext.insert/save` call sites; replace with game-over observer |
| Finder dupe build failure | LOW — delete file | Delete `"Games/Snake/SnakeEngine 2.swift"`, rebuild |
| NSStagedMigrationManager test crash | LOW — uninstall simulator app | `xcrun simctl uninstall <id> com.lauterstar.gamekit`, rerun tests |
| Missing Reduce Motion path (App Store rejection) | MEDIUM — add render branch | Gate visual interpolation on `accessibilityReduceMotion`; jump-cut branch requires Canvas refactor if not planned up front |
| Gesture conflict (navigate-back on swipe-left) | LOW-MEDIUM — add defersSystemGestures | Add `.defersSystemGestures(on: .all)` on board view; test on device |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-----------------|--------------|
| Frame-rate-dependent physics (P1) | Phase 1 — Substrate | Unit test: same engine at dt=1/60 and dt=1/120 yields identical game-time-to-collision |
| Spiral of death (P2) | Phase 1 — Substrate | Unit test: inject dt=2.0, assert at most 15 ticks fire, engine exits cleanly |
| ProMotion 120 Hz divergence (P3) | Phase 1 + Phase 3 | Run Snake on 120 Hz simulator profile; assert cells-per-second matches design |
| Engine impurity (P4) | Phase 1 (contract) + Phase 2/3 (review) | `grep -r "import SwiftUI" Games/Stack/ Games/Snake/` returns empty |
| Non-deterministic RNG (P5) | Phase 2 (Stack) + Phase 3 (Snake) | Test: seed=42 produces identical food spawn sequence on 10 consecutive calls |
| Loop not paused on background/game-over (P6) | Phase 1 — Substrate | Manual: background app during game-over; foreground; verify timer did not increment |
| View-tree churn per frame (P7) | Phase 2/3 — design decision | Instruments: Core Animation shows no layout passes for board view at 60 Hz |
| Swift 6 concurrency / CADisplayLink (P8) | Phase 1 — Substrate | Build succeeds with zero concurrency warnings; no `@preconcurrency` on QuartzCore |
| scenePhase double-counting (P9) | Phase 1 — Substrate | Manual: receive notification banner mid-game; snake position unchanged after dismiss |
| Gesture conflicts (P10) | Phase 3 — Snake | On-device test: swipe left from left edge; assert no navigation pop |
| SwiftData schema corruption (P11) | Phase 1/2 — Persistence | Test on simulator with prior-schema store; assert no launch crash |
| High score saved per frame (P12) | Phase 1/2 — Persistence | Instruments: no disk I/O during active gameplay; one record inserted on game-over |
| Reduce Motion missing (P13) | Phase 2 (Stack) + Phase 3 (Snake) | Simulator: Reduce Motion ON; game still playable, no smooth tweening |
| Feedback not gated by SettingsStore (P14) | Phase 2/3 | Manual: haptics OFF in Settings; no haptic on food-eat event |
| DesignKit token bypass (P15) | Phase 2/3 | §8.12: Classic + Voltage legibility audit passes before done |
| Finder-dupe files (P16) | Every phase | `git status` shows no `?? * 2.swift` before each commit |
| Monolithic file over 500 lines (P17) | Phase 1 (template) + Phase 2/3 | File lengths checked — all under 400 before committing |
| NSStagedMigrationManager crash (P18) | Phase 1/2 | Test run on clean simulator + upgraded simulator both pass without uninstall |
| State thrash per-frame Observable (P19) | Phase 2/3 | Instruments: views reading only score/gameOver evaluate body at most 1 Hz, not 60 Hz |
| Cold-start regression (P20) | Phase 1 (lazy init) + Phase 2/3 (verify) | Instruments App Launch: cold-start on device unchanged from v1.4 baseline |

---

## Sources

- Gaffer on Games — "Fix Your Timestep!" (https://gafferongames.com/post/fix_your_timestep/) — fixed timestep accumulator, spiral of death prevention, alpha interpolation
- Apple Developer Documentation — TimelineView, `animation(minimumInterval:paused:)` schedule, scenePhase, CADisplayLink, accessibilityReduceMotion
- Apple — Reduce Motion evaluation criteria for App Store review (https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/)
- fatbobman.com — "Designing Models for CloudKit Sync: Core Data & SwiftData Rules" — CloudKit optional constraint requirements
- fatbobman.com — SwiftUI gesture customization — defersSystemGestures, exclusive vs. simultaneous gestures
- Swift Forums — Deterministic Randomness in Swift — seedable RNG pattern
- CLAUDE.md §1, §4, §5, §8.1–8.16 — project-specific rules (file caps, commit discipline, dupe files, pbxproj, NSStagedMigration)
- DESIGN.md §8 (haptic vocabulary, counter-trigger pattern), §10 (animation vocabulary, Reduce Motion gate), §12.5 (new game checklist)
- GameKit v1.5 BRIEF (.planning/v1.5-BRIEF.md) — substrate contract, engine purity requirement, Reduce Motion requirement
- GameKit PROJECT.md — engine purity rule, existing game patterns (BoardGenerator, RevealEngine, WinDetector)

---
*Pitfalls research for: Real-time endless arcade games (Stack + Snake) in GameDrawer v1.5*
*Researched: 2026-06-25*
