# Research Summary — v1.5 Endless Arcade Primitive

**Project:** GameKit (GameDrawer)
**Domain:** Real-time endless arcade games (Stack + Snake) added to a shipped SwiftUI/SwiftData logic-game suite
**Researched:** 2026-06-25
**Confidence:** HIGH on substrate, Stack, architecture, and pitfalls; MEDIUM on Snake rendering choice and speed-ramp constants

---

## Executive Summary

v1.5 adds a new interaction primitive to GameDrawer — continuous input + frame loop + score-until-death — that every prior game lacks. The four research streams converge on a clear delivery strategy: build one shared real-time substrate in `Core/` first (two new files, ~160 lines total), prove it with Stack, confirm reuse with Snake, then complete stats and polish. The substrate is the critical path; nothing else can start without it. The technical decisions are unusually locked: `TimelineView(.animation(paused:))` as the frame driver (Swift 6 concurrency-safe, declarative pause, zero timer-cancel boilerplate), a fixed-timestep accumulator in the view model (decouples simulation from ProMotion frame rate), and pure Foundation-only engine structs with a `mutating func step(dt: Double, input: Input) -> Frame` contract (mirrors the existing `RevealEngine`/`MergeEngine` purity pattern exactly). No SpriteKit, no CADisplayLink, no Combine timers.

The architecture agent verified directly against the live codebase: the existing `BestScore` model and `GameStats.record(gameKind:mode:outcome:score:)` overload already handle score-based high scores. No new SwiftData model is needed. The only schema-visible changes are two additive `GameKind` enum cases (`.stack`, `.snake`) stored as raw strings — CloudKit-safe, no migration, no schema-version bump at the model layer. Seven existing files receive additive-only edits. The pitfalls agent recommended a new `ArcadeRecord` model to avoid CloudKit constraint violations; this concern is valid in principle but moot here because `BestScore` already uses optional properties and `GameRecord.score: Int?` already exists. The architecture agent's codebase-verified finding is authoritative: reuse the existing schema.

The brand guard is absolute: these games are calm, not twitch. Speed plateaus (Stack at ~80 blocks, Snake at ~100ms tick interval), wrap mode default for Snake, no ads/coins/revives/leaderboards with accounts. Three cross-cutting decisions must be locked before coding begins: (1) Reduce Motion treatment for continuous-motion games (jump-cut, not game halt — DESIGN.md §12 needs an entry), (2) Video Mode exemption ADR (real-time continuous input cannot pause-and-reflow for PiP), and (3) Snake wrap-vs-wall default (wrap recommended for calm posture).

---

## Key Findings

### Recommended Stack

The existing stack (Swift 6, SwiftUI, SwiftData, DesignKit, CloudKit) is unchanged. v1.5 adds only a frame-loop layer on top of it. All decisions below are additive.

**Locked technical decisions:**

| Decision | One-line rationale |
|---|---|
| `TimelineView(.animation(minimumInterval: nil, paused: vm.state != .running))` | Swift 6 Sendable-safe; declarative pause via binding; auto-stops when backgrounded; ProMotion-adaptive at no cost |
| Fixed-timestep accumulator in the VM (not the engine) | Decouples simulation rate from display rate — Snake at 120 Hz must not run twice as fast as at 60 Hz |
| `min(realDt, 0.1)` clamp before accumulation | Prevents spiral-of-death when the app resumes after a foreground gap |
| `fixedDt = 1.0 / 60.0` for both games | 60 Hz simulation is sufficient; ProMotion renders extra frames without extra engine ticks |
| Pure `mutating func step(dt: Double, input: Input) -> Frame` engine contract | Mirrors `RevealEngine`/`MergeEngine` purity — no SwiftUI import, no `modelContext`, deterministic, unit-testable |
| `Canvas` for Stack board, `LazyVGrid` for Snake board (Canvas fallback if profiling warrants) | Stack needs sub-pixel geometry for overhang shaving; Snake's discrete grid maps to existing board-game pattern |
| No SpriteKit | DesignKit `Color` tokens cannot reach `SKNode`; adds a second rendering stack; no physics or particles needed |
| `DragGesture(minimumDistance: 20).onEnded` + direction queue (capacity 2) for Snake | Reliable 4-directional swipe; queue preserves rapid turns before a tick fires |
| `.onTapGesture { vm.pendingDrop = true }` for Stack | Consumed and cleared each engine tick; one drop per tap intent regardless of 120 Hz multi-fire |
| `GameKind` +2 cases (`.stack`, `.snake`); `BestScore` + `GameRecord` unchanged | Codebase-verified: `GameStats.record(gameKind:mode:outcome:score:)` and `GameRecord.score: Int?` already exist |
| `difficultyRaw = "endless"` for both games | No difficulty tiers; one BestScore row per game kind keyed on `(gameKind, "endless")` |
| `UserDefaults` checkpoint per-N-seconds for in-progress score | SwiftData saved once on game-over only; mid-run resilience follows the existing force-quit pattern |
| `ArcadeLifecycle` enum in `Core/` (idle / running / paused / gameOver) | Shared between Stack and Snake; Foundation-only; mirrors `MinesweeperGameState` shape |
| Video Mode exempt for v1.5 | Continuous input cannot pause-and-reflow for PiP; document in ADR |

**Rendering note — Snake disagreement between agents:** The stack agent recommends `LazyVGrid` for consistency with existing board games. The pitfalls agent warns 400 cell-views at 60 Hz causes layout churn. Resolution: default to `LazyVGrid`, profile immediately on device, and switch `SnakeBoardView` to `Canvas` if Instruments shows layout passes at 60 Hz. The switch is local to one file and does not affect the engine or VM.

### Expected Features

**Must-have (table stakes):**

- Oscillating block above tower with tap-to-drop (Stack)
- Overhang trim visual with width shrink on imperfect drops (Stack)
- Perfect drop acknowledgment (color pulse) + width recovery on perfect (Stack)
- Speed ramp with hard cap: ~80 blocks (Stack), ~100ms tick interval floor (Snake)
- Grid-based snake with self-collision end condition (Snake)
- Wrap (toroidal) mode as default for Snake
- Input direction queue (capacity 1–2) for Snake
- Dynamic grid sizing based on available screen geometry (Snake) — 20×20 minimum
- Score chip + high-score chip during run (both games)
- Game-over banner reusing `VideoModeBanner` (both games)
- Instant restart with zero friction (both games)
- Haptics on key events only — never per-frame (both games)
- Theme-driven colors via DesignKit semantic tokens — never hardcoded (both games)
- Reduce Motion path: jump-cut rendering, not game halt (both games)
- Stats screen extension: high score, runs played, average score (both games)

**Should-have (differentiators):**

- Block color gradient derived from DesignKit accent ramp per tower layer (Stack)
- Perfect streak counter displayed during run (Stack)
- Snake body color gradient head-to-tail (Snake)
- Directional button row as secondary control for Snake (accessibility)
- Wall mode as optional toggle for Snake (low effort, post-wrap default)
- Run summary micro-screen (score + perfects + personal-best indicator) before restart CTA

**Defer to v1.6+:**

- Daily seed (engagement layer; not MVP)
- Video Mode adoption (confirm exempt; separate milestone if ever added)
- Score trend charts (post-launch demand signal needed)
- Global leaderboards (never — requires accounts; permanent brand exclusion)

**Anti-features — never build:**

| Feature | Rationale |
|---|---|
| Ads of any kind | CLAUDE.md §1 permanent ban |
| Coins / fake currency / revives | CLAUDE.md §1 permanent ban |
| Lives / heart systems | Dark pattern by definition |
| Speed spikes / random difficulty bursts | Manufactured frustration; contradicts calm-endless brand |
| Global leaderboards requiring accounts | Auth required; social comparison pressure; permanent exclusion |
| Streak shaming / push notifications | Coercive engagement bait |
| Power-ups / shields | Free-to-play monetization onramp |
| Screen shake on any event | Vestibular accessibility failure; permanent exclusion |
| Per-frame haptics | Vibration spam at 5–10 Hz; haptics carry information (DESIGN.md §8), not locomotion |

### Architecture Approach

The substrate is two new `Core/` files (~160 lines combined): `ArcadeGameState.swift` (4-case lifecycle enum) and `ArcadeLoopDriver.swift` (a `ViewModifier` delivering `dt` via `onTick` callback, adopted as `.arcadeLoop(isRunning:onTick:)`). Both games consume these from day one — the "promote to Core/ when used in 2+ games" rule applies immediately. Seven existing files receive additive-only edits; no existing file is structurally changed.

**File scope — NEW vs MODIFIED:**

| File | Status | Change |
|---|---|---|
| `Core/ArcadeGameState.swift` | NEW | 4-case lifecycle enum |
| `Core/ArcadeLoopDriver.swift` | NEW | ViewModifier + extension; ~60 lines |
| `Games/Stack/Engine/StackEngine.swift` | NEW | Pure engine struct; unit tested |
| `Games/Stack/Engine/StackBoard.swift` | NEW | Codable model |
| `Games/Stack/StackViewModel.swift` | NEW | @Observable @MainActor |
| `Games/Stack/StackGameView.swift` | NEW | SwiftUI screen |
| `Games/Stack/StackBoardView.swift` | NEW | Canvas board |
| `Games/Stack/StackSaveState.swift` | NEW | UserDefaults JSON |
| `Games/Stack/StackScoreChip.swift` | NEW | Info chip |
| `Games/Stack/StackStatsCard.swift` | NEW | Props-only card |
| `Games/Snake/Engine/SnakeEngine.swift` | NEW | Pure engine; fixed-timestep accumulator inside engine |
| `Games/Snake/Engine/SnakeBoard.swift` | NEW | Codable model |
| `Games/Snake/SnakeViewModel.swift` | NEW | @Observable @MainActor |
| `Games/Snake/SnakeGameView.swift` | NEW | SwiftUI screen |
| `Games/Snake/SnakeBoardView.swift` | NEW | LazyVGrid board (Canvas if profiling warrants) |
| `Games/Snake/SnakeSaveState.swift` | NEW | UserDefaults JSON |
| `Games/Snake/SnakeStatsCard.swift` | NEW | Props-only card |
| `Core/GameKind.swift` | MODIFIED | +2 cases — additive |
| `Core/GameRoute.swift` | MODIFIED | +2 cases — additive |
| `Core/GameDescriptor.swift` | MODIFIED | +AccentRole.slot9/slot10; +2 entries to `.all` |
| `Core/GameKind+AccentColor.swift` | MODIFIED | +2 color cases |
| `Core/GameStats.swift` | MODIFIED | `resetAll()` +2 `clearAll()` lines only |
| `Screens/HomeView.swift` | MODIFIED | `destination(for:)` switch +2 cases; NO `.videoModeAware()` |
| `Screens/StatsView.swift` | MODIFIED | +2 `@Query` pairs; +2 `if shows()` sections |

No other files are touched. `VideoModeBanner`, `BestScore`, `BestTime`, `GameRecord`, `SettingsStore`, all existing game files — unchanged.

**Major components:**

1. `Core/ArcadeGameState` — Shared lifecycle enum; Foundation-only; mirrors `MinesweeperGameState`
2. `Core/ArcadeLoopDriver` — ViewModifier delivering `dt` on each display-linked frame; same adoption pattern as `VideoModeAware.swift`
3. `StackEngine` / `SnakeEngine` — Pure value-type structs; no SwiftUI; `step(dt:input:)` contract; seeded RNG in engine state
4. `StackViewModel` / `SnakeViewModel` — @Observable @MainActor; owns engine; fixed-timestep accumulator; records BestScore once on game-over; counter-trigger haptics
5. `BestScore` / `GameStats` (existing, unchanged) — Score-based high-score persistence already works; `evaluateBestScore` uses higher-only semantics, correct for endless games

**Key invariants:**

- Engine purity: zero `import SwiftUI` or `import SwiftData` in any engine file
- Counter-trigger pattern for haptics: incrementing `Int` counters on VM, not `Bool` toggles (DESIGN.md §8.2)
- File size cap: all view files ≤400 lines, all Swift files ≤500 lines (CLAUDE.md §8.1/§8.5)
- Synchronized-root-group: new `.swift` files in `Games/Stack/` and `Games/Snake/` do not require `project.pbxproj` edits; only a new top-level folder does
- `paused:` binding on `TimelineView` from day one — not an afterthought
- `modes: []` on `GameDescriptor` entries — tapping the home tile launches directly, no mode-chip sub-menu

### Critical Pitfalls

**Top 5 — wrong here = rewrite or data corruption:**

1. **Fixed-timestep clamp missing (spiral-of-death)** — Cap `realDt` with `min(realDt, 0.1)` before the accumulator `while` loop. A 30-second background gap otherwise fills the accumulator and the engine runs thousands of ticks on the first resume frame. One-liner; must be in the substrate. Prevention: Phase 1.

2. **Frame-rate-dependent physics (ProMotion trap)** — If any velocity is in "per frame" units rather than "per second" units, Snake moves twice as fast at 120 Hz. The `step(dt: Double)` contract prevents this at the engine level; the fixed-timestep accumulator prevents it at dispatch. Unit test: same engine at `dt=1/60` and `dt=1/120` over 5 simulated seconds must produce identical game state. Prevention: Phase 1.

3. **Non-deterministic RNG** — `Int.random(in:)` without `using:` severs reproducibility. Snake food spawn and any Stack randomness must use a `SeedableRNG` struct stored in engine state; tests pin the seed. Prevention: Phases 2, 3.

4. **SwiftData save on every frame tick** — `modelContext.insert()` inside the tick closure = ~1,800 inserts per 30-second run; floods CloudKit sync queue; spikes disk I/O. Save exactly once on game-over. Checkpoint in-progress score to `UserDefaults` every ~5 seconds (overwrite same key) for force-quit resilience. Prevention: Phase 1/2 persistence design.

5. **`paused:` binding absent** — Without `paused: vm.state != .running`, the loop runs at 60 Hz on the game-over screen and during background. High-score timestamp accrues falsely; battery drains. Also: handle `.inactive` scenePhase identically to `.background` — a notification banner is `.inactive`, and the 2-second gap becomes spurious dt on resume. Prevention: Phase 1.

**Moderate pitfalls:**

- **Engine impurity** — Any `import SwiftUI` in an engine file makes it untestable headlessly. Verify with `grep -r "import SwiftUI" Games/Stack/ Games/Snake/` at PR time.
- **DesignKit token bypass** — Real-time games invite hardcoded "arcade" colors. Map all elements to semantic tokens before any color decision: snake body = `accentPrimary`, food = `success`, game-over = `danger`, board = `background`. §8.12 audit mandatory before each game phase is done.
- **Gesture conflict (Snake left-swipe vs. NavigationStack back-swipe)** — Add `.defersSystemGestures(on: .all)` on the Snake board view. Test on device.
- **Reduce Motion path absent** — First continuous-motion games in the suite. Without a jump-cut rendering path this is an App Store review risk. Define the treatment before writing animation code.
- **Observable state thrash per frame** — Separate rendering state (Canvas closure captures engine frame directly) from UI state (score, isGameOver — published as isolated properties). Only properties the chrome reads should trigger layout.

---

## Must-Decide Before Coding

These four decisions are cross-cutting and must be locked before Phase 2 begins.

### 1. Reduce Motion Jump-Cut Spec (add to DESIGN.md §12)

- **Stack (Reduce Motion ON):** Block sliding visible as position change (no spring interpolation); trim disappears instantly (no fall animation); game-over cuts directly to banner (no slow-mo pre-roll).
- **Snake (Reduce Motion ON):** Snake body teleports cell-to-cell each tick (no between-cell interpolation); food-eat is instant color change (no bounce); game-over cuts directly to banner.
- Both: Reduce Motion gates visual motion only, never game mechanics or speed. Gate: `@Environment(\.accessibilityReduceMotion)` in the View tier — never in the engine or VM.

Add to DESIGN.md §12 before Phase 2 begins.

### 2. Video Mode Exemption ADR

Stack and Snake do not receive `.videoModeAware(minBoardHeight:)` in `HomeView.destination(for:)` for v1.5. No `+VideoMode.swift` extension files for these games. If Video Mode is desired in a later milestone, it requires a separate design pass. Document in `.planning/` ADR before Phase 2.

### 3. Snake Wrap-vs-Wall Default

**Recommendation: wrap (toroidal) as default.** Eliminates "hit a wall I didn't see" frustration; calm brand requires deaths to feel earned. Wall mode can ship as an optional toggle in v1.5 or v1.5.1 at low effort. Speed plateau at ~100ms tick is the actual difficulty ceiling; wall mode adds frustration, not skill.

### 4. Score-Stats Model Shape

**Recommendation: reuse existing `BestScore` + `GameRecord` — no new model.**

The pitfalls agent (Pitfall 11) recommended a new `ArcadeRecord` model to avoid CloudKit constraint violations. The architecture agent verified against actual source files that `BestScore` already uses optional properties, `GameRecord.score: Int?` already exists, and `GameStats.record(gameKind:mode:outcome:score:)` already exists. The concern does not apply. Architecture agent's codebase-verified finding is authoritative.

Stats screen shape for endless games: High Score (large, prominent) + Runs Played. No best-time column, no win-rate column — endless games always end in "loss"; those columns are meaningless.

---

## Implications for Roadmap

### Phase 1: Substrate + Skeleton

**Rationale:** Hard dependency for both games. Loop driver, lifecycle enum, and all 7 existing-file additive edits must exist before either game can compile. Phase 1 is the critical path.

**Delivers:**
- `Core/ArcadeGameState.swift` — 4-case lifecycle enum
- `Core/ArcadeLoopDriver.swift` — ViewModifier + `.arcadeLoop(isRunning:onTick:)` extension
- All 7 additive existing-file edits (GameKind, GameRoute, GameDescriptor, GameKind+AccentColor, GameStats.resetAll, HomeView stubs, StatsView placeholders)
- Unit test: `ArcadeLoopDriver` fires `onTick` when running, silent when not
- Unit test: spiral-of-death clamp — inject `dt = 2.0`, assert ≤15 ticks fire
- `paused:` binding wired and verified before any game touches it
- scenePhase wiring: `.inactive` and `.background` both pause, same handler
- App compiles; Stack and Snake tiles appear on Home with placeholder text

**Research flags:** None — all patterns established and codebase-verified.

**Avoids:** Spiral-of-death, ProMotion divergence, loop-not-paused, scenePhase double-counting.

---

### Phase 2: Stack (proves substrate end-to-end)

**Rationale:** Stack is the simpler game and the harder renderer (Canvas). Proving Canvas here makes Snake's LazyVGrid comparatively straightforward. Stack also exercises the score persistence path before Snake needs it.

**Delivers:**
- `StackEngine` (pure Foundation): `step(dt:)` + `drop() -> DropResult`; seeded RNG; speed ramp capped at ~80 blocks; perfect detection + width recovery
- `StackViewModel` (@Observable @MainActor): fixed-timestep accumulator; records BestScore on game-over only; counter-trigger haptics; UserDefaults checkpoint
- `StackBoardView` (Canvas): sliding block + tower in DesignKit tokens; Reduce Motion jump-cut path
- `StackGameView`: `.arcadeLoop`, scenePhase, `.onTapGesture`
- `StackSaveState` (Codable, UserDefaults)
- `StackScoreChip` + `StackStatsCard` (props-only)
- StatsView Stack section; HomeView Stack destination
- Unit tests: drop/overhang/game-over; perfect detection; zero-width collapse; ProMotion equivalence test
- §8.12 audit: Classic + Voltage (or Dracula) — block colors legible before phase done

**Research flags:** None — Canvas + TimelineView confirmed via Context7.

---

### Phase 3: Snake (confirms substrate reuse, no new Core/ changes)

**Rationale:** Snake consumes `ArcadeGameState` and `ArcadeLoopDriver` without modification — clean reuse is the phase-success signal. Also exercises the gesture conflict surface that Stack does not have.

**Delivers:**
- `SnakeEngine` (pure Foundation): `step(dt:pendingDir:) -> StepFrame`; seeded RNG; fixed-timestep accumulator inside engine; wrap default; food on random empty cell; self-collision; speed ramp 250ms → 100ms floor
- `SnakeViewModel` (@Observable @MainActor): direction queue capacity 2; reverse-block guard; BestScore on game-over only; UserDefaults checkpoint
- `SnakeBoardView` (LazyVGrid default; Canvas if profiling warrants): Reduce Motion jump-cut (no between-cell interpolation); dynamic grid sizing; `.defersSystemGestures(on: .all)`
- `SnakeGameView`: `DragGesture(minimumDistance: 20).onEnded` direction; directional button row (secondary control)
- `SnakeSaveState` (Codable, UserDefaults)
- `SnakeStatsCard` (props-only)
- StatsView Snake section; HomeView Snake destination; `GameStats.resetAll()` +2 clearAll lines
- Unit tests: grow on food; self-collision; wrap boundary; fixed-timestep consistency; ProMotion equivalence; seeded food-spawn reproducibility (run twice, identical output)
- On-device test: swipe left from left edge — assert no NavigationStack pop
- §8.12 audit: Classic + Voltage (or Dracula)

**Research flags:** Profile LazyVGrid vs. Canvas for the board on device early in the phase; do not wait for visible symptoms.

---

### Phase 4: Stats, Home, and Polish

**Rationale:** Both games playable; complete the consumer-facing surface and lock all design specs.

**Delivers:**
- Stats screen final design: High Score (large) + Runs Played per game; no win-rate / no best-time columns
- Haptic vocabulary audit: `.impact(weight: .light)` for score events, `.error` for game-over
- Accessibility: `.accessibilityLabel` on score chip, board, back button, restart button
- Save-state round-trip: force-quit mid-game → relaunch → run state restores
- DESIGN.md §12 entries for Stack and Snake: Reduce Motion spec, haptic vocabulary, token-per-element map
- Video Mode exemption ADR committed to `.planning/`
- Cold-start regression check: Instruments App Launch on device — unchanged from v1.4 baseline
- File length check: all game files ≤400 lines

**Research flags:** None — checklist and tuning work.

---

### Phase Ordering Rationale

- **Substrate before both games:** Hard dependency — loop driver and all 7 additive file edits must exist before either game compiles.
- **Stack before Snake:** Stack proves Canvas rendering (harder); Snake reuses the substrate and adds the gesture surface (swipe conflict) which is lower risk.
- **Games before polish:** Stats screen shape, haptic vocabulary, and DESIGN.md §12 entries depend on the games being fully playable. Locking specs before play produces documents that don't match reality.
- **No CloudKit or SIWA work in v1.5:** Two additive `GameKind` string values in `BestScore` are CloudKit-safe with no deployment steps.

### Research Flags

Phases needing deeper research during planning:
- **Phase 3 (Snake board rendering):** LazyVGrid vs. Canvas — profile on device before finalizing `SnakeBoardView`. Canvas switch is local to one file.

Phases with standard patterns (proceed directly to implementation):
- **Phase 1:** All patterns codebase-verified. ViewModifier shape confirmed against `VideoModeAware.swift`.
- **Phase 2:** Canvas + TimelineView confirmed via Context7. `GraphicsContext.Shading.color(_:)` takes `SwiftUI.Color` — DesignKit tokens feed directly.
- **Phase 3:** Engine pattern, direction queue, drag gesture all confirmed. Unknowns are profiling and on-device gesture testing only.
- **Phase 4:** Checklist and tuning work.

---

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Frame driver (TimelineView) | HIGH | `paused: Bool` parameter confirmed via Context7 Apple docs |
| Engine contract (fixed-timestep) | HIGH | Mirrors existing codebase purity; Gaffer on Games pattern verified |
| Canvas rendering (Stack) | HIGH | `GraphicsContext.Shading.color(_:)` takes `SwiftUI.Color` — confirmed |
| Persistence (reuse BestScore) | HIGH | Architecture agent read actual source files; `GameStats.record(gameKind:mode:outcome:score:)` exists at line 113 of `Core/GameStats.swift` |
| Architecture (7 additive edits) | HIGH | All 7 files confirmed with line-level guidance from actual source reading |
| Pitfalls | HIGH | Grounded in repo-specific code analysis; all critical pitfalls have concrete prevention phases |
| Stack mechanics | HIGH | 10+ year genre; speed ramp constants are MEDIUM (no canonical public spec) |
| Snake mechanics | HIGH | 30+ year genre; wrap default recommendation is HIGH; tick interval constants are MEDIUM |
| Snake rendering choice | MEDIUM | Agents disagree; LazyVGrid vs. Canvas requires on-device profiling to resolve |
| Speed ramp constants | MEDIUM | Derived from surveyed implementations; tune on device |
| Reduce Motion jump-cut spec | MEDIUM | Pattern agreed in principle; exact visual thresholds need design validation on device |

**Overall confidence: HIGH.** Four research streams converge on identical phase structure, engine contract, and persistence approach. The one genuine disagreement (LazyVGrid vs. Canvas for Snake) is low-cost to resolve and does not affect any other decision.

### Gaps to Address During Planning

- **DESIGN.md §12 entry before Phase 2** — Reduce Motion jump-cut spec must be written before animation code. The principle is agreed; the exact visual thresholds are not.
- **Video Mode exemption ADR before Phase 2** — Prevents re-litigation during game phases.
- **Snake wrap-vs-wall default before Phase 3** — Affects `SnakeEngine` init parameter and DESIGN.md §12 entry; easier with a locked decision.
- **Speed ramp constants are MEDIUM confidence** — Plan a play-test step in each game phase to tune on device. Architecture is unaffected; only constants change.
- **Seeded RNG implementation** — Swift's `SystemRandomNumberGenerator` is not seedable. A `SeedableRNG` struct conforming to `RandomNumberGenerator` is needed; keep local to each engine initially; promote to `Core/` if both engines use the same implementation.

---

## Sources

### Primary (HIGH confidence)
- Context7 `/websites/developer_apple_swiftui` — TimelineView, `AnimationTimelineSchedule.init(minimumInterval:paused:)`, Canvas, `GraphicsContext.Shading.color(_:)`, DragGesture, scenePhase
- Apple Developer Documentation — `AnimationTimelineSchedule.init(minimumInterval:paused:)`, `TimelineView.Context.Cadence`, `GraphicsContext`, `DragGesture`, `ScenePhase`
- Gaffer on Games — "Fix Your Timestep!" — fixed-timestep accumulator, spiral-of-death cap
- Apple — Reduce Motion evaluation criteria for App Store review
- Codebase direct inspection (2026-06-25): `Core/BestScore.swift`, `Core/GameStats.swift`, `Core/GameKind.swift`, `Core/GameRoute.swift`, `Core/GameDescriptor.swift`, `Core/GameKind+AccentColor.swift`, `Core/SettingsStore.swift`, `Core/VideoModeBanner.swift`, `Core/VideoModeAware.swift`, `Games/Minesweeper/MinesweeperViewModel.swift`, `Games/Merge/MergeViewModel.swift`, `Screens/HomeView.swift`, `Screens/StatsView.swift`
- CLAUDE.md §1, §4, §8 — engine purity, file caps, commit discipline
- DESIGN.md §8 (haptic vocabulary, counter-trigger), §10 (animation vocabulary, Reduce Motion gate), §12.5 (new game done checklist)

### Secondary (MEDIUM confidence)
- SwiftUI Lab — TimelineView Part 4 — `context.date` behavior
- NilCoalescing — TimelineView in SwiftUI — cadence property
- Jacob's Tech Tavern — SwiftUI Game Engine — Canvas + TimelineView validation
- fatbobman — SwiftUI gesture customization — `defersSystemGestures`
- Swift Forums — Deterministic Randomness in Swift — seedable RNG pattern
- App Store Stack and Snake implementations (Ketchapp Stack, Google Snake) — mechanic verification

### Tertiary (LOW confidence — validate on device)
- Speed ramp curves — derived from surveyed implementations; tune during implementation
- LazyVGrid vs. Canvas at 60 Hz for 400 Snake cells — profile on device before committing

---

*Research completed: 2026-06-25*
*Ready for roadmap: yes*
