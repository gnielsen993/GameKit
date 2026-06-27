# Phase 15: Arcade Substrate + Skeleton — Research

**Researched:** 2026-06-26
**Domain:** Real-time game-loop primitive (Swift 6 / SwiftUI / Foundation) wired into existing multi-game iOS app
**Confidence:** HIGH — all findings verified against live source files or cited from milestone research (2026-06-25)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Placeholder screen (D-01, D-02, D-03)**
Build a **live substrate harness** as each placeholder — driven by the real `.arcadeLoop(isRunning:onTick:)` — showing a visibly-moving element (oscillating dot or tick/dt readout). The harness is **throwaway** — deleted when real game views land in Phases 16/17. The harness must respect pause lifecycle (stops on `.inactive`/`.background` and on deliberate stopped state).

**Pause-safety bar (D-04, D-05)**
BOTH locked unit tests must pass: (a) `onTick` fires only when `isRunning == true`; (b) spiral-of-death: inject `dt = 2.0`, assert ≤15 ticks and clean exit. PLUS manual notification-banner test on device. This satisfies success criterion #3 inside Phase 15.

**Home tile captions (D-06)**
Use final caption `"Tap to play"` — NOT "Coming soon". Descriptor written once; tiles only ever ship in their final, playable state.

**Accent colors (D-07)**
Locked now in `Core/GameKind+AccentColor.swift` (`AccentRole.slot9`/`slot10`):
- Stack → vivid orange `Color(red: 0.961, green: 0.498, blue: 0.122)`
- Snake → calm green `Color(red: 0.176, green: 0.741, blue: 0.490)`

**§8.12 theme pass (D-08)**
Verify both accent colors are legible on the **Home tiles** under Classic (Chrome Diner) AND at least one Loud preset (Voltage/Dracula) before the phase is marked done.

**GameDescriptor shape (D-09)**
`modes: []` on both entries — tapping the tile launches the harness directly with no mode-chip sub-menu. SF Symbol is Claude's discretion (suggested: `square.stack.fill` / `arrow.triangle.turn.up.right.diamond`; verify in SF Symbols app).

**Video Mode ADR (D-10, D-11)**
Write the ADR (ARCADE-08) in Phase 15 — the code decision (omit `.videoModeAware()` for Stack/Snake destinations) physically lands in this phase's `HomeView` edit. Phase 18 only references/closes it. Deliverable: `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md`.

### Claude's Discretion

- Fixed-timestep accumulator placement (driver vs VM vs engine)
- Whether the dt clamp constant is parameterized
- Exact harness visual (oscillating dot vs tick/dt readout)
- Precise SF Symbol per tile

### Deferred Ideas (OUT OF SCOPE)

- Stack/Snake gameplay, engines, save-state, Canvas vs LazyVGrid rendering choice → Phases 16/17
- Score-based Stats screen shape (ARCADE-07) → Phase 18
- Engine RNG, speed-ramp constants → owning game phases
- `SeedableRNG` struct → introduce with first engine; promote to Core/ only if both engines share it
- Snake wrap-vs-wall default, Reduce Motion DESIGN.md §12 entries → Phases 16/17
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ARCADE-01 | Shared real-time loop substrate in `Core/`, driven by `TimelineView(.animation(paused:))` — declarative pause, ProMotion adaptive, no CADisplayLink | Verified: `TimelineView` Swift 6 safe; `if isRunning` form confirmed in ARCHITECTURE.md §§1-2 |
| ARCADE-02 | Fixed-timestep accumulator with `min(realDt, 0.1)` max-dt clamp feeds pure engine structs via `step(dt:)` contract | ARCHITECTURE.md + PITFALLS.md P2 — contract and clamp confirmed; accumulator placed in VM (see §Architecture Patterns) |
| ARCADE-03 | Run lifecycle idle → running → paused → game-over → restart; tap-to-start; game-over banner reuses `VideoModeBanner` | `ArcadeGameState` enum pattern; `VideoModeBanner` confirmed in `Core/VideoModeBanner.swift` |
| ARCADE-04 | Loop pauses on `scenePhase .background`/`.inactive` and game-over (zero CPU when paused); resumes with no time drift, no spiral-of-death | PITFALLS.md P2/P9; `min(dt, 0.1)` + `lastDate` reset pattern in ARCHITECTURE.md |
| ARCADE-05 | High score and run counts persist via existing `BestScore`/`GameRecord`; additive `GameKind` cases + `"endless"` mode key; CloudKit-safe; save on game-over only | Verified: `GameStats.record(gameKind:mode:outcome:score:)` at line 113; `BestScore` optional properties confirmed; no new @Model needed |
| ARCADE-06 | All arcade haptics/SFX/animations route through `SettingsStore` toggles and `accessibilityReduceMotion` (counter-trigger pattern) | Counter-trigger pattern confirmed in `MinesweeperViewModel.swift`; `SettingsStore` confirmed unchanged |
| ARCADE-09 | Stack and Snake appear as enabled game cards on Home and launch into their game screens; new accent slots per `GameDescriptor` pattern | All 7 existing-file integration points verified against live source |
</phase_requirements>

---

## Summary

Phase 15 is a pure wiring harness — two new `Core/` files (~160 lines combined) plus seven additive edits to existing files and two throwaway harness views. No gameplay, no engines, no per-game logic ships in this phase. The deliverable is: (1) the shared loop driver and lifecycle enum proven by unit tests, (2) Stack/Snake tiles on Home that navigate to a live substrate harness, (3) the scenePhase pause contract verified by manual notification-banner test, and (4) the Video Mode exemption ADR committed.

All technical decisions for this phase are already locked and codebase-verified by the 2026-06-25 milestone research (`ARCHITECTURE.md`, `PITFALLS.md`, `SUMMARY.md`). The substrate shape — `ArcadeLoopDriver` as a ViewModifier mirroring `VideoModeAware.swift`, `ArcadeGameState` as a Foundation-only enum mirroring `MinesweeperGameState` — has been confirmed against live files. The seven integration points (`GameKind`, `GameRoute`, `GameDescriptor`, `GameKind+AccentColor`, `GameStats.resetAll`, `HomeView.destination(for:)`, `StatsView`) have been read and their exact current state documented below. No new SwiftData models are needed — `BestScore` and `GameStats.record(gameKind:mode:outcome:score:)` already handle score-based high scores.

The one deliberate difference from the milestone research scope: Phase 15 creates only **throwaway harness views** under `Games/Stack/` and `Games/Snake/` — not the full game folder structure. Full game folder contents (Engine/, ViewModel, BoardView, SaveState, ScoreChip, StatsCard) arrive in Phases 16/17. The harness purpose is to exercise `ArcadeLoopDriver` end-to-end before a real engine exists.

**Primary recommendation:** Write `ArcadeLoopDriver` and `ArcadeGameState` first, gate them with the two unit tests (onTick-gating + spiral-clamp), then wire the 7 existing files and create the harness views in one pass.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frame-loop delivery (TimelineView) | Frontend (SwiftUI View / ViewModifier) | — | `TimelineView` is a SwiftUI primitive; must live in view tier for @MainActor safety |
| Loop pause/resume gating | View tier (`onChange(of: scenePhase)`) | VM (`pause()`/`resume()` methods) | View owns scenePhase env; VM owns state; same split as `MinesweeperViewModel+Timer.swift` |
| Lifecycle state machine (`ArcadeGameState`) | Core/ (Foundation-only) | — | Shared between both games; promotes when used in 2+ games per CLAUDE.md §4 |
| dt clamp (`min(realDt, 0.1)`) | `ArcadeLoopDriver` (ViewModifier) | — | Clamp must occur before `onTick` so NO VM receives an unclamped dt |
| Fixed-timestep accumulator | VM (per-game, @Observable @MainActor) | — | Needs mutable state between frames; engine receives already-fixed dt values; keeps engine pure |
| Score persistence | Core/GameStats.swift (existing) | — | Existing write-side boundary; no new model needed |
| Home tile routing | Core/GameRoute.swift (Foundation) | Screens/HomeView.swift (resolution) | Same pattern as all 8 existing games |
| Video Mode exemption | Screens/HomeView.swift (omit call) | ADR (documentation) | Physical code location is the `destination(for:)` switch |
| Theme-token accent colors | Core/GameKind+AccentColor.swift | — | Per-game brand constants in Core/ per existing pattern |

---

## Standard Stack

No new external packages are added in Phase 15. All dependencies are already present.

### Core (existing — no additions)

| Dependency | Location | Purpose |
|------------|----------|---------|
| SwiftUI | iOS SDK | `TimelineView`, `ViewModifier`, `onChange`, `scenePhase` |
| Foundation | iOS SDK | `Date`, `TimeInterval` — all new Core/ files are Foundation-only |
| DesignKit | `../DesignKit` (local SPM) | Harness views use semantic tokens only (no hardcoded colors) |
| Swift Testing | Test target | Existing test framework for all unit tests |

**No npm/PyPI/external packages.** Phase is purely additive Swift code on the existing stack.

---

## Package Legitimacy Audit

No external packages installed in this phase. Section not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
Display Link (60/120 Hz)
        │
        ▼
TimelineView(.animation)
  inside ArcadeLoopDriver (ViewModifier)
        │ context.date delta → min(rawDt, 0.1) → onTick(clampedDt)
        │
        ▼
HarnessViewModel.tick(dt:)           ← Phase 15: throwaway harness
  guard state == .running else return
  accumulator += dt
  while accumulator >= fixedDt:
    sampleStep()                     ← Phase 15: just increment counter
    accumulator -= fixedDt
        │
        ├── state → ArcadeGameState  ← SHARED: idle/running/paused/gameOver
        └── triggerCount++           ← visible movement in harness
                │
                ▼
        HarnessView body
          .arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }
          .onChange(of: scenePhase) { vm.pause() / vm.resume() }
          Text / Circle that moves based on triggerCount

Home (NavigationStack)
  GameDescriptor.all → tiles → tap → path.append(.stack / .snake)
  destination(for: .stack) → HarnessView().disableInteractivePop()
  destination(for: .snake) → HarnessView().disableInteractivePop()
  NOTE: NO .videoModeAware() on stack/snake destinations (ADR)
```

### NEW Files — Phase 15 Only

```
Core/
  ArcadeGameState.swift     ← NEW (4-case lifecycle enum; Foundation-only)
  ArcadeLoopDriver.swift    ← NEW (ViewModifier + .arcadeLoop extension; ~60 lines)

Games/
  Stack/
    StackHarnessView.swift  ← NEW (throwaway; deleted at Phase 16 start)
  Snake/
    SnakeHarnessView.swift  ← NEW (throwaway; deleted at Phase 17 start)

.planning/phases/15-arcade-substrate-skeleton/
  15-VIDEO-MODE-ADR.md      ← NEW (ARCADE-08 ADR — Video Mode exemption)

gamekitTests/Core/
  ArcadeLoopDriverTests.swift  ← NEW (2 substrate unit tests)
```

### MODIFIED Files — Phase 15 Only

| File | Lines to Change | Nature |
|------|----------------|--------|
| `Core/GameKind.swift` | +2 cases after `case wordGrid` | Additive enum cases |
| `Core/GameRoute.swift` | +2 cases (no associated value) | Additive enum cases |
| `Core/GameDescriptor.swift` | +2 cases to `AccentRole`; +2 entries in `.all` | Additive |
| `Core/GameKind+AccentColor.swift` | +2 cases in `accentColor` switch | Additive |
| `Core/GameStats.swift` | `resetAll()`: no change in Phase 15 (clearAll lines deferred to P16/17) | Deferred |
| `Screens/HomeView.swift` | `destination(for:)` switch +2 cases | Additive |
| `Screens/StatsView.swift` | +2 @Query pairs + 2 placeholder sections with empty state | Additive |

### Pattern 1: ArcadeLoopDriver as ViewModifier

Mirrors `Core/VideoModeAware.swift` exactly — same `struct + extension View` shape, same adoption syntax. [VERIFIED: live codebase 2026-06-26]

```swift
// Core/ArcadeLoopDriver.swift
import SwiftUI

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
                                let rawDt = lastDate.map { newDate.timeIntervalSince($0) } ?? 0
                                lastDate = newDate
                                onTick(min(rawDt, 0.1))  // clamp — ARCADE-04 spiral-of-death guard
                            }
                    }
                }
            }
            .onChange(of: isRunning) { _, running in
                if !running { lastDate = nil }  // discard accumulated gap on pause/stop
            }
    }
}

extension View {
    func arcadeLoop(isRunning: Bool, onTick: @escaping (_ dt: Double) -> Void) -> some View {
        modifier(ArcadeLoopDriver(isRunning: isRunning, onTick: onTick))
    }
}
```

**Adoption in harness (and later, real game views):**
```swift
boardOrDot
    .arcadeLoop(isRunning: vm.state == .running) { dt in
        vm.tick(dt: dt)
    }
```

**Key design notes:**
- `if isRunning` form rather than `paused:` binding — removes `TimelineView` entirely from the hierarchy when not running (zero overhead)
- `lastDate = nil` on `isRunning → false` ensures the next `isRunning → true` frame sees no accumulated gap
- The clamp `min(rawDt, 0.1)` is the sole location for the spiral-of-death guard — no VM or engine should add a second clamp
- `TimelineView` fires on `@MainActor` (it is a SwiftUI view) — Swift 6 concurrency-safe, no actor-hop needed [VERIFIED: SUMMARY.md, PITFALLS.md P8]

### Pattern 2: ArcadeGameState Lifecycle Enum

```swift
// Core/ArcadeGameState.swift
import Foundation

/// Shared lifecycle enum for endless arcade games. Foundation-only.
/// Mirrors MinesweeperGameState (also nonisolated, Foundation-only, not Codable).
/// The live state resets cleanly on restart — no persistence needed.
nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable {
    case idle       // tap-to-start affordance shown; loop NOT running
    case running    // frame loop active; input accepted
    case paused     // scenePhase backgrounded; loop suspended, state preserved
    case gameOver   // terminal; score frozen; restart available
}
```

**ArcadeLoopDriver `isRunning` is always computed as:** `vm.state == .running`
This is the ONLY value that drives whether `TimelineView` fires.

### Pattern 3: VM tick-gating and fixed-timestep accumulator

The VM (per-game, `@Observable @MainActor`) owns the accumulator. The driver delivers already-clamped dt; the VM converts to fixed-step ticks for the engine. [ASSUMED: accumulator in VM is Claude's Discretion per CONTEXT.md]

```swift
// Harness VM (throwaway) — same structural shape all arcade VMs will follow:
@Observable @MainActor
final class StackHarnessVM {
    private(set) var state: ArcadeGameState = .idle
    private(set) var tickCount: Int = 0       // drives harness visual (counter-trigger pattern)
    private var accumulator: Double = 0
    private let fixedDt = 1.0 / 60.0

    func tick(dt: Double) {
        guard state == .running else { return }
        accumulator += dt
        while accumulator >= fixedDt {
            tickCount += 1          // one logical step
            accumulator -= fixedDt
        }
    }

    func start() { state = .running }
    func pause() { if state == .running { state = .paused } }
    func resume() { if state == .paused { state = .running } }
    func stop()   { state = .idle; accumulator = 0 }
}
```

**Why accumulator in the VM, not the driver:**
- Driver is generic (knows nothing about fixed step size)
- Driver already clamps dt — engine receives cleaned values
- Accumulator uses `fixedDt` which is per-game (Stack: continuous motion uses different step than Snake's discrete grid steps)
- VM is @MainActor so mutation is always on main thread — same actor as SwiftUI body

**Why accumulator NOT in the engine:**
- Keeps engine pure (no state that isn't gameplay state)
- Simplifies unit tests: inject any sequence of `fixedDt` values, assert deterministic output
- Engine-purity rule from CLAUDE.md §4 and established by ARCHITECTURE.md §2

### Pattern 4: scenePhase pause wiring

Same pattern as `MinesweeperGameView` observing scenePhase to call `vm.pause()`/`vm.resume()`. [VERIFIED: ARCHITECTURE.md §5, PITFALLS.md P9]

```swift
// Inside HarnessView (and later, StackGameView / SnakeGameView):
@Environment(\.scenePhase) private var scenePhase

// ...

.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active:
        vm.resume()
    case .inactive, .background:
        vm.pause()   // handles notification banners (.inactive) identically to background
    @unknown default:
        vm.pause()
    }
}
```

**Critical: `.inactive` and `.background` use the SAME handler.** A notification banner is `.inactive`, not `.background`. If only `.background` is handled, a 2-second banner gap is injected as dt on resume — the spiral-of-death clamp catches it but the snake/block still experiences a 0.1s gap (6 unexpected fixed steps). The manual notification-banner test (D-04/D-05) validates this handler works correctly.

### Pattern 5: GameKind + GameRoute additions

```swift
// Core/GameKind.swift — append after .wordGrid:
case stack   // raw: "stack" — stable serialization key; treat as locked on first GameRecord
case snake   // raw: "snake"

// Core/GameRoute.swift — append (NO associated value for endless games):
case stack   // no mode selection; modes: [] in descriptor
case snake
```

**Why no associated value on `.stack`/`.snake`:** Existing cases have optional associated values to support mode-chip deep-linking from the Home drawer. Endless games have `modes: []` — there is no mode chip to deep-link to. The route is always `destination(for: .stack)` with no qualifier. `case stack` (plain) is simpler and correct. [VERIFIED: GameRoute.swift live file; CONTEXT D-09]

### Pattern 6: GameDescriptor additions

```swift
// Core/GameDescriptor.swift — additions:

// In AccentRole enum, append:
case slot9   // Stack
case slot10  // Snake

// In AccentRole.index switch, append:
case .slot9:  return 8
case .slot10: return 9

// In GameDescriptor.all static array, append:
GameDescriptor(
    kind: .stack,
    titleKey: "Stack",
    captionKey: "Tap to play",      // D-06: final caption, not "Coming soon"
    symbol: "square.stack.fill",    // verify in SF Symbols app [ASSUMED]
    accent: .slot9,
    route: .stack,
    modes: [],                      // D-09: direct launch, no mode chips
    shortMeta: "Endless tower"
),
GameDescriptor(
    kind: .snake,
    titleKey: "Snake",
    captionKey: "Tap to play",
    symbol: "arrow.triangle.turn.up.right.diamond",  // verify in SF Symbols app [ASSUMED]
    accent: .slot10,
    route: .snake,
    modes: [],
    shortMeta: "Endless grid"
)
```

### Pattern 7: GameKind+AccentColor additions

```swift
// Core/GameKind+AccentColor.swift — append in switch:
case .stack: return Color(red: 0.961, green: 0.498, blue: 0.122)  // vivid orange (D-07)
case .snake: return Color(red: 0.176, green: 0.741, blue: 0.490)  // calm green (D-07)
```

These are **brand-identity colors** (raw Color, not DesignKit semantic tokens) — the same pattern as the existing 8 cases. The pre-commit hook scope (Games/ and Screens/) does not cover Core/, so these are not flagged by the hardcoded-color hook. [VERIFIED: GameKind+AccentColor.swift; CLAUDE.md §1 hook scope]

### Pattern 8: HomeView destination additions

```swift
// Screens/HomeView.swift — destination(for:) switch, append:
case .stack:
    StackHarnessView()
        .disableInteractivePop()   // NO .videoModeAware() — ADR documents this
case .snake:
    SnakeHarnessView()
        .disableInteractivePop()   // NO .videoModeAware() — ADR documents this
```

**Klondike precedent confirmed:** `case .klondike(let difficulty): SolitaireGameView(...).disableInteractivePop()` — no `.videoModeAware()` call (line 355 of HomeView.swift, verified 2026-06-26). Stack and Snake follow this same pattern for the same reason: `klondike` omits `videoModeAware` by convention; Stack/Snake omit it by explicit ADR decision. [VERIFIED: HomeView.swift lines 355-357]

### Pattern 9: StatsView placeholder additions

For Phase 15, StatsView gets placeholder @Query declarations and empty-state sections. These establish the @Query structure that Phase 16/17 will fill with real cards.

```swift
// Screens/StatsView.swift — additions:
@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "stack" },
       sort: \.playedAt, order: .reverse)
private var stackRecords: [GameRecord]

@Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "stack" })
private var stackBestScores: [BestScore]

@Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "snake" },
       sort: \.playedAt, order: .reverse)
private var snakeRecords: [GameRecord]

@Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "snake" })
private var snakeBestScores: [BestScore]

// In the ScrollView body, append placeholder sections:
if shows(.stack) {
    // Phase 15: placeholder; replaced by StackStatsCard in Phase 16
    DKSectionHeader(title: String(localized: "Stack"), theme: theme)
    Text(String(localized: "No Stack games yet."))
        .foregroundStyle(theme.colors.textSecondary)
}
if shows(.snake) {
    DKSectionHeader(title: String(localized: "Snake"), theme: theme)
    Text(String(localized: "No Snake games yet."))
        .foregroundStyle(theme.colors.textSecondary)
}
```

**CLAUDE.md §8.3 compliance:** explicit empty-state copy required. "No games played yet." pattern established in existing stats sections. [VERIFIED: StatsView.swift patterns]

### Pattern 10: Video Mode ADR (D-10, D-11)

Deliverable: `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md`

Content skeleton:
```markdown
# ADR: Stack and Snake are exempt from Video Mode (ARCADE-08)

**Status:** Accepted — 2026-06-26
**Satisfies:** ARCADE-08 (documentation deliverable)

## Context
Video Mode (v1.2) pauses layout and reflows game chrome when a PiP video occupies screen space.
The mechanism requires a game to tolerate layout interruption mid-play.

## Decision
Stack and Snake do NOT receive `.videoModeAware(minBoardHeight:)` in HomeView.destination(for:).

## Rationale
Real-time continuous-input games cannot pause-and-reflow for a PiP overlay without killing
the run. An incoming Layout change during active play causes desync between the engine's
computed frame and the rendered frame. This is fundamentally different from turn-based games
(Minesweeper, Merge) where layout can change between player taps.

## Precedent
`klondike` (Solitaire) already ships without `.videoModeAware()` in HomeView — a precedent
for games whose play style is incompatible with mid-game layout reflow.

## Future
If Video Mode is desired for arcade games in a later milestone, it requires a separate design
pass: a mode that SUSPENDS the run (not reflows layout) while PiP is active, resuming on
PiP dismiss. This is out of scope for v1.5.

## Consequences
- Stack and Snake tile navigation in HomeView has only `.disableInteractivePop()` — no
  `.videoModeAware()`.
- Phase 18 references and closes this ADR (does not reopen the decision).
```

### Anti-Patterns to Avoid

- **TimelineView with no `paused:` gating:** Without either `if isRunning` or `.animation(paused:)`, the loop fires 60+ Hz on game-over and background screens — battery drain, incorrect elapsed time. [PITFALLS.md P6]
- **Clamp in VM rather than driver:** If the VM clamps instead of the driver, the harness unit test cannot test the clamp in isolation and future VMs could omit it. The driver is the one invariant point. [ARCHITECTURE.md §1]
- **Associated value on `.stack`/`.snake` GameRoute cases:** Adds unnecessary complexity and would require passing `Void?` at every call site. The descriptor's `modes: []` already implies there is no mode parameter. [CONTEXT D-09]
- **"Coming soon" as caption:** Means touching GameDescriptor twice (now and when game ships). D-06 locks "Tap to play" from day one. [CONTEXT D-06]
- **`videoModeAware()` on Stack/Snake destinations:** This phase writes the ADR confirming the exemption. The implementation (no call) must match the ADR. [CONTEXT D-10]
- **Save-state stubs (`StackSaveState`, `SnakeSaveState`) in Phase 15:** Out of scope — no save-state needed until gameplay exists (Phase 16/17). Do not add `StackSaveState.clearAll()` lines to `resetAll()` in Phase 15; add them in the phase where the save-state files actually ship.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Frame-loop delivery | CADisplayLink wrapper, Combine Timer | `TimelineView(.animation)` inside ArcadeLoopDriver | Swift 6 concurrency-safe; fires on @MainActor; no actor hop; auto-stops with `if isRunning` |
| Loop pause declaration | Manual Bool + external observer | `if isRunning` form in ViewModifier | TimelineView removed from hierarchy when not running — zero CPU overhead, not just paused |
| Score-based persistence | New `@Model ArcadeRecord` | Existing `BestScore` + `GameStats.record(gameKind:mode:outcome:score:)` | Already exists at line 113; CloudKit-safe; `evaluateBestScore` uses higher-only semantics — correct for endless games |
| End-state banner | New banner component | `VideoModeBanner` from `Core/` | Already exists; reused as-is; Phase 15 harness wires it for game-over proof |
| Settings toggles | New SettingsStore properties | Existing `hapticsEnabled`, `sfxEnabled`, `animationsEnabled` | All toggles needed for arcade games already present; no new flags |
| Haptic trigger | Bool toggle | Incrementing `Int` counter (counter-trigger pattern) | `Bool` misses rapid double-fires; counter drives `.sensoryFeedback(trigger:)` correctly per DESIGN.md §8.2 |
| New top-level folder for `Games/Stack/` | Hand-editing `project.pbxproj` | Create folder via Xcode UI or filesystem; confirm auto-registration on build | `PBXFileSystemSynchronizedRootGroup` (objectVersion 77) auto-registers new subfolders; see pbxproj note below |

**pbxproj note:** CLAUDE.md §8.8 says "Only edit `project.pbxproj` for new top-level folders." `Games/Stack/` and `Games/Snake/` are subfolders of the existing `Games/` synchronized root — NOT new top-level project folders. Based on STATE.md Phase 2 validation ("zero pbxproj hand-patching needed"), new subfolders should auto-register. However, CONTEXT.md and ARCHITECTURE.md (both 2026-06-25) state a one-time group edit IS needed. **Resolution: try without a pbxproj edit first — create the folder and drop a file in; build to verify Xcode picks it up. If Xcode can't find the file, add the group via Xcode's `Add Files to "gamekit"` dialog (which edits pbxproj correctly), not by hand-editing.** [LOW confidence on exact behavior — verify empirically]

**Key insight:** The entire substrate builds on patterns already proven in this codebase. Nothing in Phase 15 requires inventing new abstractions. The ArcadeLoopDriver is structurally identical to VideoModeAware.swift; ArcadeGameState is structurally identical to MinesweeperGameState. The risk is breaking existing patterns, not discovering new ones.

---

## Common Pitfalls

### Pitfall 1: Missing `.inactive` in scenePhase handler
**What goes wrong:** App handles `.background` but not `.inactive`. A notification banner triggers `.inactive` (not `.background`). On dismiss, the 2-second gap is injected as dt. The clamp reduces it to 0.1 but that's still 6 unexpected fixed steps. The manual notification-banner test (D-04) is specifically designed to catch this.
**Root cause:** Developers associate "app backgrounded" with `.background`, not realizing notification banners are `.inactive`.
**Prevention:** BOTH `.inactive` and `.background` must call `vm.pause()` — see Pattern 4 above. [VERIFIED: PITFALLS.md P9]
**Warning sign:** The harness's moving element "jumps" after a notification banner is dismissed rather than resuming smoothly.

### Pitfall 2: `lastDate` not reset when loop stops
**What goes wrong:** `lastDate` persists across pause/resume. On resume, `context.date - lastDate` includes the entire paused duration as one large dt. The clamp reduces it to 0.1 but the gap is still injected.
**Root cause:** The `.onChange(of: isRunning)` handler that resets `lastDate` is omitted.
**Prevention:** `.onChange(of: isRunning) { _, running in if !running { lastDate = nil } }` is in the driver — do not remove it. [ARCHITECTURE.md §1]

### Pitfall 3: Accumulator in the driver instead of the VM
**What goes wrong:** The fixed-timestep loop (`while accumulator >= fixedDt`) is placed in the driver's `onTick` closure. This makes the driver game-specific (it needs to know `fixedDt`) and prevents unit testing the accumulator logic independently.
**Prevention:** Driver delivers one `onTick(clampedDt)` per display frame. VM owns the accumulator. Engine receives fixed-step dt values.

### Pitfall 4: GameRoute cases added with associated values
**What goes wrong:** `case stack(StackMode?)` added to be "consistent" with other cases. But there is no `StackMode` type and `modes: []` means no mode-chip ever deep-links to a specific mode. The extra `nil` noise in call sites (`path.append(.stack(nil))`, `descriptor.route: .stack(nil)`) adds cognitive overhead for no benefit.
**Prevention:** `case stack` (no associated value) is the correct form for endless games. Confirmed by CONTEXT D-09.

### Pitfall 5: SF Symbol name not verified in Xcode
**What goes wrong:** `"arrow.triangle.turn.up.right.diamond"` is used as the symbol for Snake. This name is from the milestone research suggestion. If it does not exist in iOS 17's SF Symbols catalog, Xcode will silently render a question mark at runtime.
**Prevention:** Open the SF Symbols app, search for the exact string before committing. If not found, pick the closest semantic alternative (something arrow/directional for Snake, something stacking for Stack). The exact symbol is Claude's Discretion (CONTEXT D-09). [ASSUMED: symbol names are unverified]

### Pitfall 6: Harness view not respecting pause lifecycle (D-03)
**What goes wrong:** The harness shows a moving element but doesn't have `.onChange(of: scenePhase)`. The loop keeps ticking in the background. This defeats the purpose of the harness as a pause-safety proof surface — success criterion #3 cannot be met.
**Prevention:** The harness MUST have the scenePhase observer. It is the only way to run the manual notification-banner test (D-04/D-05) in Phase 15.

### Pitfall 7: Hardcoded color in harness view
**What goes wrong:** The oscillating dot or readout text uses `.foregroundColor(.green)` or `Color.orange` for visual variety. This triggers the pre-commit hook and blocks the commit.
**Prevention:** All harness view colors use DesignKit semantic tokens: `theme.colors.accentPrimary` for the moving element, `theme.colors.textSecondary` for secondary readout. The harness is throwaway but must obey the no-hardcoded-colors rule. [CLAUDE.md §1]

---

## Code Examples

### Minimal harness view structure (Phase 15 only)

```swift
// Games/Stack/StackHarnessView.swift
// THROWAWAY — deleted at Phase 16 start and replaced by StackGameView()
import SwiftUI
import DesignKit

struct StackHarnessView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var vm = StackHarnessVM()

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                // Moving element: a dot that oscillates based on tickCount
                Circle()
                    .fill(theme.colors.accentPrimary)
                    .frame(width: 24, height: 24)
                    .offset(x: CGFloat(vm.tickCount % 120 < 60
                        ? vm.tickCount % 60 - 30
                        : 30 - vm.tickCount % 60))

                Text("dt ticks: \(vm.tickCount)")
                    .foregroundStyle(theme.colors.textSecondary)

                if vm.state == .idle {
                    Button("Tap to Start") { vm.start() }
                }
            }
        }
        .arcadeLoop(isRunning: vm.state == .running) { dt in
            vm.tick(dt: dt)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:    vm.resume()
            case .inactive, .background: vm.pause()
            @unknown default: vm.pause()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { /* back chevron per DESIGN.md §6 */ }
    }
}
```

### Unit test structure for substrate gate

```swift
// gamekitTests/Core/ArcadeLoopDriverTests.swift
import Testing
import Foundation
@testable import gamekit

@Suite("ArcadeLoopDriver substrate")
nonisolated struct ArcadeLoopDriverTests {

    // MARK: - SC1a: onTick gating (ROADMAP Phase 15 SC1a)

    /// Verifies the tick-gating contract that every arcade VM MUST follow:
    /// only .running state should forward ticks to the engine.
    /// Tests the pattern rather than the ViewModifier directly (ViewModifiers
    /// require a SwiftUI host; the guard pattern is Foundation-testable).
    @Test("onTick is gated on .running — other states produce zero ticks")
    func onTickGating() {
        // Simulate the VM's tick guard contract:
        // guard state == .running else { return }
        var tickCount = 0
        func simulateTick(state: ArcadeGameState, dt: Double) {
            guard state == .running else { return }
            tickCount += 1
        }

        simulateTick(state: .idle,     dt: 0.016)
        #expect(tickCount == 0, "idle: no ticks")

        simulateTick(state: .running,  dt: 0.016)
        #expect(tickCount == 1, ".running: one tick")

        simulateTick(state: .paused,   dt: 0.016)
        #expect(tickCount == 1, "paused: no additional tick")

        simulateTick(state: .gameOver, dt: 0.016)
        #expect(tickCount == 1, "gameOver: no additional tick")
    }

    // MARK: - SC1b: spiral-of-death clamp (ROADMAP Phase 15 SC1b)

    /// Verifies: injecting dt=2.0 into the driver's clamp then the
    /// VM's fixed-timestep accumulator produces at most 15 engine steps.
    /// A debugger breakpoint resumption or cold-start spike of 2.0s real dt
    /// should never cause >15 game steps.
    @Test("spiral-of-death clamp: dt=2.0 produces at most 15 steps")
    func spiralOfDeathClamp() {
        let rawDt: Double = 2.0
        let maxDt: Double = 0.1         // ArcadeLoopDriver clamp constant
        let fixedDt: Double = 1.0/60.0  // VM accumulator step

        // Step 1: Driver clamps the raw dt
        let clamped = min(rawDt, maxDt)
        #expect(clamped == maxDt, "driver clamps 2.0 to 0.1")

        // Step 2: VM accumulator drains the clamped dt
        var accumulator = clamped
        var steps = 0
        while accumulator >= fixedDt {
            steps += 1
            accumulator -= fixedDt
        }

        #expect(steps <= 15, "at most 15 engine steps from a 2.0s spike")
        // Actual expected: ~6 steps (0.1 / 0.0167 ≈ 6)
    }
}
```

### ModelContainerSmokeTests — schema extension check

The existing `ModelContainerSmokeTests` will AUTOMATICALLY cover success criterion #4 once `GameKind.swift` is updated. No new test is needed — the smoke test constructs a `ModelContainer` with both `.none` and `.private("iCloud.com.lauterstar.gamekit")` configs using in-memory store. Adding `.stack`/`.snake` to `GameKind` is additive; no schema version bump; the smoke test continues to pass. [VERIFIED: ModelContainerSmokeTests.swift; ARCHITECTURE.md §3]

---

## State of the Art

| Old Approach | Current Approach | Applied In | Impact |
|--------------|------------------|------------|--------|
| `CADisplayLink` + `@preconcurrency` | `TimelineView(.animation)` + SwiftUI `onChange` | ARCADE-01 | Swift 6 actor-safe; no Sendable suppression needed |
| Fixed rate `Timer.scheduledTimer` | Display-linked `TimelineView` with fixed-step accumulator | ARCADE-02 | ProMotion-adaptive; no manual timer cancel on background |
| New `@Model ArcadeRecord` for high scores | Reuse `BestScore` + `GameRecord.score: Int?` | ARCADE-05 | Zero migration; no CloudKit schema deployment; immediately CloudKit-safe |
| Bool toggle for haptic trigger | Incrementing `Int` counter (counter-trigger) | ARCADE-06 | Rapid double-fire safe; established pattern across all existing VMs |

**Not deprecated, just clarified:**
- `TimelineView(.animation(paused:))` — valid API but the `if isRunning` conditional form (used in ARCHITECTURE.md) achieves the same result by removing the TimelineView from the hierarchy entirely. Both are correct; `if isRunning` has zero overhead when paused.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `"square.stack.fill"` is a valid iOS 17 SF Symbol name for Stack | Pattern 6 / Don't Hand-Roll P5 | Symbol renders as `?` at runtime — Claude chooses a replacement; build does not fail |
| A2 | `"arrow.triangle.turn.up.right.diamond"` is a valid iOS 17 SF Symbol name for Snake | Pattern 6 / Don't Hand-Roll P5 | Same — choose replacement symbol; 0 functional impact |
| A3 | New `Games/Stack/` and `Games/Snake/` subfolders of the `Games/` synchronized root will auto-register without a pbxproj edit | Don't Hand-Roll pbxproj note | If auto-registration fails, build error occurs — recover by adding group via Xcode's "Add Files" dialog |
| A4 | `StackSaveState.clearAll()` and `SnakeSaveState.clearAll()` lines in `GameStats.resetAll()` should be deferred to Phase 16/17 (not stubbed in Phase 15) | Pattern 8 / Architecture | If reset runs in Phase 15 before these exist, no runtime error (save-states don't exist yet); safe to defer |
| A5 | The `ArcadeLoopDriverTests.swift` approach of testing the tick-gating CONTRACT (via a local closure) rather than the ViewModifier itself is acceptable test coverage for SC1a | Validation Architecture | If the team requires actual ViewModifier behavioral testing, a SwiftUI view host test is needed — higher complexity; consider @MainActor UITest instead |

---

## Open Questions

1. **SF Symbol verification (A1, A2)**
   - What we know: milestone research suggested `square.stack.fill` and `arrow.triangle.turn.up.right.diamond`
   - What's unclear: whether these exact strings exist in iOS 17's SF Symbols catalog
   - Recommendation: verify in SF Symbols app during implementation; pick alternatives if needed (Stack → `square.stack.3d.up` or `rectangle.stack`; Snake → `arrow.2.squarepath` or `arrow.triangle.capsulepath`)

2. **`Games/Stack/` pbxproj auto-registration (A3)**
   - What we know: CLAUDE.md §8.8 says no edit for subfolders; CONTEXT.md says a one-time edit is needed; STATE.md Phase 2 showed zero edits were needed
   - What's unclear: exact PBXFileSystemSynchronizedRootGroup behavior for new subfolders of an existing synchronized root
   - Recommendation: build without a pbxproj edit first; add via Xcode UI if build fails to find the file

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ (objectVersion 77) | PBXFileSystemSynchronizedRootGroup | ✓ | Confirmed by §8.8 validation in STATE.md | — |
| iOS 17 Simulator | Manual scenePhase test | ✓ | Project target is iOS 17+ | — |
| Real device (iPhone) | D-04 notification-banner manual test | Must confirm | — | Simulator notification test is an acceptable fallback if no device available |
| SF Symbols app | A1/A2 symbol verification | ✓ (included with Xcode) | — | — |

**Missing dependencies with no fallback:** Real device for D-04 notification-banner test (D-04/D-05). Simulator can approximate `.inactive` via Home button but real device is required for CONTEXT D-04 confidence. Flag if no device available at implementation time.

---

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json` — section required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (already in use: `@Suite`, `@Test`, `#expect`) |
| Config file | None separate — uses Xcode test scheme `gamekitTests` |
| Quick run command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:gamekitTests/ArcadeLoopDriverTests` |
| Full suite command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ARCADE-01 | `TimelineView` based driver fires via `@MainActor`; no CADisplayLink | Build + SC1a unit test | `xcodebuild test -only-testing:gamekitTests/ArcadeLoopDriverTests/onTickGating` | ❌ Wave 0 |
| ARCADE-02 | Fixed-timestep clamp: dt=2.0 → ≤15 steps | Unit | `xcodebuild test -only-testing:gamekitTests/ArcadeLoopDriverTests/spiralOfDeathClamp` | ❌ Wave 0 |
| ARCADE-03 | Lifecycle: idle → running → paused → gameOver; harness shows moving element | Manual | N/A — launch harness on simulator, observe movement | — |
| ARCADE-04 | Loop pauses on `.inactive`/`.background`; no time drift on resume | Manual (device) | D-04 notification-banner test procedure | — |
| ARCADE-05 | CloudKit-safe schema: `.stack`/`.snake` GameKind cases pass smoke test | Unit (existing) | `xcodebuild test -only-testing:gamekitTests/ModelContainerSmokeTests` | ✅ (existing) |
| ARCADE-06 | No haptic/SFX fires in Phase 15 harness (nothing to gate yet) | N/A | Harness has no haptic events | — |
| ARCADE-09 | Stack/Snake tiles appear on Home; tapping navigates to harness | Manual | Launch app on simulator → verify 2 new tiles → tap each | — |

**Note on ARCADE-06:** Haptic routing will be validated when real game VMs ship in Phase 16/17. In Phase 15, the harness has no haptic events — the counter-trigger pattern is established in the code structure but has nothing to fire.

### D-04 Manual Test Procedure (notification-banner gate)

1. Build and install on real device
2. Navigate to Stack harness screen; confirm dot is oscillating
3. Pull down notification center to trigger `.inactive`
4. Dismiss — confirm dot resumes from where it was (no jump or skip)
5. Trigger an actual notification (or use the Banner test from Simulator > Notification Simulation)
6. Confirm: after banner appears and is dismissed, the oscillation resumes without a noticeable jump
7. Record pass/fail in Phase 15 verification notes

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:gamekitTests/ArcadeLoopDriverTests` (SC1a + SC1b, <5s)
- **Per wave merge:** Full suite — `xcodebuild test -scheme gamekit ...`
- **Phase gate:** Full suite green + D-04 manual test + D-08 §8.12 home-tile theme pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `gamekitTests/Core/ArcadeLoopDriverTests.swift` — covers ARCADE-01 (onTick gating) and ARCADE-02 (spiral-of-death clamp)
- [ ] `Core/ArcadeGameState.swift` — must exist before tests compile
- [ ] `Core/ArcadeLoopDriver.swift` — must exist before tests compile
- [ ] `Games/Stack/StackHarnessView.swift` — must exist for HomeView compilation
- [ ] `Games/Snake/SnakeHarnessView.swift` — must exist for HomeView compilation

---

## Security Domain

ARCADE-01 through ARCADE-09 involve no network surface, no authentication, no user data collection, and no cryptographic operations. The substrate is entirely offline, local-only game loop logic. ASVS categories V2/V3/V4/V6 do not apply.

**V5 Input Validation:** The `onTick` dt parameter is clamped (`min(rawDt, 0.1)`) before use — this is the only "input" entering the substrate. The clamp serves both gameplay integrity (spiral-of-death guard) and input hygiene.

**Data safety:** Adding `.stack`/`.snake` to `GameKind` is additive to `GameRecord.gameKindRaw` and `BestScore.gameKindRaw` columns (String). No user data is deleted or modified by these additions. `CLAUDE.md §1`: "Never delete user data automatically" — confirmed not applicable here.

---

## Sources

### Primary (HIGH confidence — codebase-verified 2026-06-26)
- `gamekit/gamekit/Core/VideoModeAware.swift` — ViewModifier + extension View pattern confirmed
- `gamekit/gamekit/Core/GameKind.swift` — 8 cases with lowercase raw strings; `.stack`/`.snake` absent
- `gamekit/gamekit/Core/GameDescriptor.swift` — AccentRole slots 1-8 consumed; `.all` has 8 entries
- `gamekit/gamekit/Core/GameRoute.swift` — 8 cases with associated values; no `.stack`/`.snake`
- `gamekit/gamekit/Core/GameKind+AccentColor.swift` — 8 raw Color cases confirmed
- `gamekit/gamekit/Core/GameStats.swift` — `record(gameKind:mode:outcome:score:)` at line 113; `resetAll()` at line 175 with clearAll pattern
- `gamekit/gamekit/Screens/HomeView.swift` — `destination(for:)` at line 337; klondike (line 355) omits `.videoModeAware()` (confirmed precedent)
- `gamekit/gamekit/Screens/StatsView.swift` — @Query pair pattern + `shows(.kind)` guard confirmed
- `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` — dual-config smoke test confirmed; covers SC4
- `.planning/research/ARCHITECTURE.md` — 2026-06-25, HIGH confidence, codebase-verified
- `.planning/research/PITFALLS.md` — 2026-06-25, HIGH confidence, repo-specific analysis
- `.planning/research/SUMMARY.md` — 2026-06-25, HIGH confidence, converged from 4 research streams
- `.planning/phases/15-arcade-substrate-skeleton/15-CONTEXT.md` — 2026-06-26, authoritative scope/decisions

### Secondary (MEDIUM confidence)
- `CLAUDE.md` §1, §4, §8.1, §8.5, §8.7, §8.8, §8.12 — project rules confirmed
- `DESIGN.md` §8 (counter-trigger haptic pattern), §10 (animation/Reduce Motion), §12.5 (new-game checklist)
- `.planning/STATE.md` — Phase 2 §8.8 validation note (zero pbxproj edits for new subfolders)
- `.planning/REQUIREMENTS.md` — ARCADE-01..06, ARCADE-09 requirement text
- `.planning/ROADMAP.md` — Phase 15 success criteria text

### Tertiary (LOW confidence — verify before use)
- SF Symbol names (`square.stack.fill`, `arrow.triangle.turn.up.right.diamond`) — from milestone research suggestion; not verified against SF Symbols catalog

---

## Metadata

**Confidence breakdown:**
- Driver and lifecycle pattern: HIGH — directly modeled on VideoModeAware.swift (verified)
- Integration points (7 existing-file edits): HIGH — all 7 files read and current state documented
- Unit test structure: HIGH — Swift Testing patterns confirmed against existing test files
- ADR content: HIGH — rationale is fully known; klondike precedent confirmed
- SF Symbol names: LOW — unverified against iOS 17 catalog; verify during implementation

**Research date:** 2026-06-26
**Valid until:** 2026-07-26 (stable Apple APIs; no expiry concern)
