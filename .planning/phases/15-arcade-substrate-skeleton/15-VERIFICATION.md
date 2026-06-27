---
phase: 15-arcade-substrate-skeleton
verified: 2026-06-27T12:00:00Z
status: human_needed
score: 15/16 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run Instruments App Launch template on a real device against the v1.4 baseline"
    expected: "Cold-start time within noise of the v1.4 baseline; NO ArcadeLoopDriver, StackHarnessVM, or SnakeHarnessVM instance allocated in the launch trace before the first tile tap"
    why_human: "Instruments App Launch timing requires a physical device and a Release/Profiling build. The lazy-init precondition (no arcade references in App/) is verified statically; only the clock reading is pending. Plan 05 Task 3 explicitly sanctions this deferral."
deferred:
  - truth: "ARCADE-05 save-on-game-over and force-quit survival"
    addressed_in: "Phase 16 (Stack) / Phase 17 (Snake)"
    evidence: "Phase 15 scope for ARCADE-05 is schema extension only (ROADMAP SC4). GameStats.record() call site, 'endless' mode key, and force-quit survival require a game-over trigger that does not exist until Phase 16 StackVM / Phase 17 SnakeVM. Schema foundation (GameKind.stack/.snake raw values + existing evaluateBestScore) is in place."
  - truth: "ARCADE-03 game-over → restart path and VideoModeBanner game-over banner"
    addressed_in: "Phase 16 (Stack)"
    evidence: "Plan 15-01 ARCADE-03 scope note: 'The remaining ARCADE-03 surface — entering .gameOver, the VideoModeBanner game-over banner, and the game-over→restart path — is DEFERRED to Phase 16, where the first real game-over trigger exists. Phase 15's harness has no real end-game condition.'"
---

# Phase 15: Arcade Substrate + Skeleton — Verification Report

**Phase Goal:** The shared real-time loop substrate is in place, tested, and paused-safe — both game cards (Stack, Snake) appear on Home and navigate to placeholder screens, but no gameplay exists yet.
**Verified:** 2026-06-27
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ArcadeLoopDriver forwards onTick only while isRunning == true; idle/paused/gameOver produce zero ticks | VERIFIED | `ArcadeLoopDriverTests.onTickGating` — nonisolated test proves guard contract; `ArcadeLoopDriver.swift:46-43` applies `min(rawDt, 0.1)` only inside `if isRunning { TimelineView ... }` |
| 2 | A 2.0s raw dt clamps to 0.1 and drains to at most 15 fixed-timestep ticks | VERIFIED | `ArcadeLoopDriverTests.spiralOfDeathClamp` — literal `rawDt=2.0`, `maxDt=0.1`, `fixedDt=1/60`; asserts `steps <= 15` and loop termination |
| 3 | ArcadeGameState lifecycle enum exists, Foundation-only, nonisolated | VERIFIED | `Core/ArcadeGameState.swift` — `nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable` with four cases; `import Foundation` only (no SwiftUI/SwiftData) |
| 4 | Each harness drives real .arcadeLoop(isRunning:onTick:) and shows a visibly-moving element | VERIFIED | Both files contain `.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }` (lines 135/136) with sine-oscillating Circle; harness VM is throwaway per THROWAWAY header comment |
| 5 | Each harness pauses on BOTH .inactive AND .background via same handler, resumes with no time-jump | VERIFIED | Both harness files: `case .inactive, .background: vm.pause()`; ArcadeLoopDriver WR-04 fix (commit 6f67d1c): `lastDate = nil` on ANY isRunning transition (not just →false), so no stale anchor on rapid pause/resume |
| 6 | The harness VM owns the fixed-timestep accumulator and gates tick() on state == .running | VERIFIED | Both VMs: `guard state == .running else { return }` at start of `tick(dt:)`; `accumulator += dt; while accumulator >= fixedDt { ... }` below the guard |
| 7 | GameKind has additive .stack and .snake cases with stable lowercase raw strings | VERIFIED | `Core/GameKind.swift:34-35` — `case stack` (raw "stack"), `case snake` (raw "snake") appended after .wordGrid |
| 8 | Adding .stack/.snake passes ModelContainerSmokeTests with no migration | VERIFIED | 15-03-SUMMARY.md task 1 commit c6748ff: "ModelContainerSmokeTests (all 3 cases) passed, proving ROADMAP SC4" |
| 9 | Stack and Snake render distinct tile icons via GameIconView Canvas draws | VERIFIED | `Screens/GameIconView.swift:33-34` — `case .stack: drawStack(&ctx, s: s, color: color)`, `case .snake: drawSnake(&ctx, s: s, color: color)`; both draw functions at lines 233/257 use only `color` param (no literal Color) |
| 10 | StatsView shows Stack and Snake sections with explicit empty-state copy | VERIFIED | `Screens/StatsView.swift:128,134,138,144` — four @Query declarations (`stackRecords`, `stackBestScores`, `snakeRecords`, `snakeBestScores`); lines 225/236: `Text(String(localized: "No Stack games yet."))` and `"No Snake games yet."` |
| 11 | Stack and Snake appear as enabled tiles on Home, captioned 'Tap to play', modes: [] | VERIFIED | `Core/GameDescriptor.swift:260-276` — two entries with `kind: .stack`/`.snake`, `captionKey: "Tap to play"`, `modes: []`; no "Coming soon" token present |
| 12 | Tapping a tile navigates to its harness with NO .videoModeAware() applied | VERIFIED | `Screens/HomeView.swift:381-388` — `case .stack: StackHarnessView().disableInteractivePop()`, `case .snake: SnakeHarnessView().disableInteractivePop()`; grep confirms no videoModeAware on those two cases; modeless fix (commit 3f8bb9d): `if descriptor.modes.isEmpty { path.append(descriptor.route) }` |
| 13 | Video Mode exemption is recorded in 15-VIDEO-MODE-ADR.md | VERIFIED | File exists; contains "ARCADE-08", "Accepted — 2026-06-26", Decision section naming `.videoModeAware()` and `destination(for:)`, klondike precedent |
| 14 | Banner pause-safety: resume after notification banner with no dt-spike / time-jump (SC3) | VERIFIED (manual gate) | 15-05-SUMMARY.md Task 1: "User confirmed the harness element resumes smoothly with no time-jump / no multi-step burst after the app returns from .inactive"; gate_results.d04_banner_pause: pass |
| 15 | Stack and Snake tiles legible on Classic (Chrome Diner) and one Loud preset (D-08 / §8.12) | VERIFIED (manual gate) | 15-05-SUMMARY.md Task 2: "User confirmed both Stack and Snake tiles are legible on Classic (Chrome Diner) and on a Loud preset (Voltage/Dracula)"; gate_results.d08_theme_pass: pass |
| 16 | Cold-start unchanged from v1.4 baseline, no arcade state at launch (SC5) | PARTIAL — human_needed | Lazy-init VERIFIED statically: no ArcadeLoopDriver/StackHarnessVM/SnakeHarnessVM referenced in App/; both VMs are `@State private var vm = …HarnessVM()` inside harness views. Instruments App Launch timing trace DEFERRED — no device available at verification time (plan-sanctioned fallback per 15-05-PLAN.md Task 3). |

**Score:** 15/16 truths verified (SC5 timing deferred per plan)

---

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | ARCADE-03: game-over → restart path and game-over banner | Phase 16 | Plan 15-01 ARCADE-03 scope note: deferred to Phase 16 where the first real game-over trigger exists |
| 2 | ARCADE-05: "save fires on game-over, survives force-quit" behavior | Phase 16 / Phase 17 | ROADMAP SC4 scopes Phase 15 to schema extension only; GameStats.record() call site and "endless" mode key are Phase 16/17 implementation |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Core/ArcadeGameState.swift` | Foundation-only nonisolated enum, 4 cases | VERIFIED | 24 lines; `nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable`; import Foundation only |
| `Core/ArcadeLoopDriver.swift` | TimelineView-based ViewModifier + arcadeLoop extension | VERIFIED | Contains `min(rawDt, 0.1)`, `TimelineView(.animation)`, `lastDate = nil` on any isRunning change (WR-04 fix); 62 lines |
| `gamekitTests/Core/ArcadeLoopDriverTests.swift` | Two locked gate tests | VERIFIED | `nonisolated struct ArcadeLoopDriverTests`; `@Test onTickGating` + `@Test spiralOfDeathClamp`; `@testable import gamekit`; no SwiftUI/SwiftData |
| `Games/Stack/StackHarnessView.swift` | Throwaway harness + VM driving .arcadeLoop, dual-phase pause | VERIFIED | THROWAWAY comment; `.arcadeLoop(isRunning:)`; `case .inactive, .background: vm.pause()`; `guard state == .running`; token-only colors; IN-04 fix: `accumulator = 0` in start() |
| `Games/Snake/SnakeHarnessView.swift` | Structurally identical to Stack harness | VERIFIED | Same patterns as Stack harness; vertical oscillation; `case .inactive, .background: vm.pause()` |
| `Core/GameKind.swift` | Additive .stack / .snake cases | VERIFIED | `case stack` (raw "stack"), `case snake` (raw "snake") at lines 34-35 |
| `Core/GameKind+AccentColor.swift` | D-07 brand accent colors | VERIFIED | `case .stack: Color(red: 0.961, green: 0.498, blue: 0.122)`, `case .snake: Color(red: 0.176, green: 0.741, blue: 0.490)` |
| `Screens/GameIconView.swift` | drawStack / drawSnake + switch cases | VERIFIED | `case .stack:` + `case .snake:` in switch; `func drawStack` at line 233, `func drawSnake` at line 257; color-param-only draw functions |
| `Screens/StatsView.swift` | Stack/Snake @Query pairs + empty states | VERIFIED | Four @Query declarations; "No Stack games yet." and "No Snake games yet." with `theme.colors.textSecondary` |
| `Core/GameRoute.swift` | Plain .stack / .snake cases | VERIFIED | `case stack` and `case snake` at lines 36-37; no associated value |
| `Core/GameDescriptor.swift` | slot9/slot10 + two .all entries | VERIFIED | `case slot9` (index 8), `case slot10` (index 9); both entries with `captionKey: "Tap to play"`, `modes: []`, `route: .stack`/`.snake` |
| `Screens/HomeView.swift` | destination(for:) routing to harnesses, no videoModeAware | VERIFIED | Lines 381-388: `case .stack: StackHarnessView().disableInteractivePop()`, `case .snake: SnakeHarnessView().disableInteractivePop()`; modeless direct-nav at line 164 |
| `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md` | ARCADE-08 exemption ADR | VERIFIED | "ARCADE-08", "Accepted — 2026-06-26", klondike precedent, decision section with `.videoModeAware()` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Core/ArcadeLoopDriver.swift` | onTick closure | `min(rawDt, 0.1)` — sole spiral-of-death guard | WIRED | Clamp at line 42; `TimelineView(.animation)` at line 37 |
| `gamekitTests/Core/ArcadeLoopDriverTests.swift` | ArcadeGameState | `@testable import gamekit` | WIRED | Line 16; `nonisolated struct` tests probe Foundation-only types |
| `StackHarnessView / SnakeHarnessView` | ArcadeLoopDriver | `.arcadeLoop(isRunning: vm.state == .running) { dt in vm.tick(dt: dt) }` | WIRED | Both files; arcadeLoop modifier applied to ZStack |
| harness scenePhase handler | `vm.pause()` | `case .inactive, .background: vm.pause()` | WIRED | Both files lines 143/143; `@unknown default: vm.pause()` also present |
| `Core/GameDescriptor.all` | HomeView tile grid | two new descriptors → two enabled tiles | WIRED | ForEach over `GameDescriptor.all` at HomeView line 130/144; both entries confirmed enabled |
| `Screens/HomeView.destination(for:)` | StackHarnessView / SnakeHarnessView | `.disableInteractivePop()` with NO `.videoModeAware()` | WIRED | Lines 381-388; ADR comment at line 378 |
| `descriptor.modes.isEmpty` | `path.append(descriptor.route)` | Direct navigation for modeless games | WIRED | HomeView line 164-166; commit 3f8bb9d |
| `Core/GameKind.swift` raw values | `GameRecord.gameKindRaw` / `BestScore.gameKindRaw` | String raw-value serialization key | WIRED | `gameKindRaw` is a `String` field; schema-level link confirmed by StatsView @Query predicates matching `"stack"`/`"snake"` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `StackHarnessView` | `vm.tickCount` | `.arcadeLoop → vm.tick(dt:) → accumulator drain` | Yes — real TimelineView ticks drive count | FLOWING (throwaway; intentional placeholder) |
| `SnakeHarnessView` | `vm.tickCount` | Same as Stack | Yes | FLOWING |
| `Screens/StatsView.swift` Stack/Snake sections | `stackRecords`, `stackBestScores`, `snakeRecords`, `snakeBestScores` | SwiftData @Query — no GameRecord with gameKindRaw=="stack"/"snake" yet exists | Empty result (expected for substrate phase) | STATIC — intentional; data flows when Phase 16/17 add gameplay and call GameStats.record() |

---

### Behavioral Spot-Checks

Automated behavioral checks require a running simulator and are excluded from static verification. The two locked unit tests and the manual gate results in 15-05-SUMMARY.md serve as the verification record.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| onTickGating test | `xcodebuild test … -only-testing:gamekitTests/ArcadeLoopDriverTests/onTickGating` | Passed per 15-01-SUMMARY.md | PASS |
| spiralOfDeathClamp test | `xcodebuild test … -only-testing:gamekitTests/ArcadeLoopDriverTests/spiralOfDeathClamp` | Passed per 15-01-SUMMARY.md | PASS |
| Full gamekit suite | `xcodebuild test -scheme gamekit` | "TEST SUCCEEDED" per 15-05-SUMMARY.md | PASS |
| Cold-start Instruments trace | Instruments App Launch on real device | NOT RUN — no device available (plan-sanctioned deferral) | SKIP |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ARCADE-01 | 15-01 | TimelineView(.animation) real-time loop, no CADisplayLink | SATISFIED | `ArcadeLoopDriver.swift:37` — `TimelineView(.animation)`; ProMotion-adaptive; no CADisplayLink import anywhere |
| ARCADE-02 | 15-01 | Fixed-timestep accumulator + min(rawDt, 0.1) clamp; deterministic engine contract | SATISFIED | Clamp at line 42; accumulator in VMs at 48/48; spiralOfDeathClamp test gates it |
| ARCADE-03 | 15-01 | Run lifecycle idle→running→paused→game-over→restart; tap-to-start; game-over banner | PARTIAL (scoped) | idle/running/paused lifecycle + tap-to-start proven in Phase 15. game-over entry, banner, restart path deferred to Phase 16 per plan's explicit ARCADE-03 scope note |
| ARCADE-04 | 15-02 | Pauses on .background/.inactive; no time drift on resume | SATISFIED | `case .inactive, .background: vm.pause()` in both harnesses; WR-04 fix ensures lastDate=nil on any isRunning change; D-04 manual gate PASS |
| ARCADE-05 | 15-03 | Persistence schema extension: .stack/.snake CloudKit-safe additive raw values | SATISFIED (schema scope) | GameKind.stack/.snake raw strings; ModelContainerSmokeTests pass (15-03-SUMMARY.md); save-on-game-over deferred to Phase 16/17 where game-over exists |
| ARCADE-06 | 15-02 | Haptics/SFX/animations route through SettingsStore; counter-trigger pattern | SATISFIED | Both VMs expose `private(set) var tickCount: Int` as counter-trigger per DESIGN.md §8; SettingsStore wiring follows in Phases 16/17 with real haptics |
| ARCADE-08 | 15-04 | Stack and Snake exempt from Video Mode; ADR committed | SATISFIED | `15-VIDEO-MODE-ADR.md` committed; HomeView destination cases carry only `.disableInteractivePop()`; klondike precedent cited |
| ARCADE-09 | 15-03/15-04 | Stack/Snake enabled cards on Home; navigate to game screens | SATISFIED | Two enabled GameDescriptor entries; two HomeView destination cases; modeless fix (commit 3f8bb9d) enables direct navigation; D-08 theme pass confirmed visually |
| ARCADE-07 | — | Stats score-based shape | PENDING (Phase 18) | Not claimed by Phase 15; placeholder empty-state sections are the Phase 15 deliverable |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Screens/HomeView.swift` | 128, 174, 210 | Pre-existing hardcoded spacing (`26`, `8`) and font literal (`.system(size: 13)`) | Warning (pre-existing) | Not introduced by Phase 15; tracked as WR-02 in 15-REVIEW.md |
| `Screens/GameIconView.swift` | 149, 203, 226 | Pre-existing `.white` literal in three draw functions (drawSolitaire, drawFiveLetter, drawWordGrid) | Warning (pre-existing) | Not introduced by Phase 15; tracked as WR-03 in 15-REVIEW.md; Phase 15 draw functions (drawStack/drawSnake) correctly use color param only |
| `Screens/StatsView.swift` | 496 lines | File is 4 lines below the §8.5 500-line hard cap | Warning (pre-existing risk) | Tracked as WR-01 in 15-REVIEW.md; first Phase 16/17 stats card addition will breach cap; split recommended before Phase 16 |

No TBD, FIXME, or XXX markers found in any Phase 15-modified file. WR-04 (ArcadeLoopDriver lastDate reset) and IN-04 (harness VM start() accumulator clear) were both fixed in commit 6f67d1c before verification.

---

### Human Verification Required

#### 1. SC5 Cold-Start Instruments Timing Trace

**Test:** Build the app for Release/Profiling on a real device. Open Instruments → App Launch template. Cold-launch (kill first). Compare launch time against v1.4 baseline. Confirm in the allocation/launch trace that NO `ArcadeLoopDriver`, `StackHarnessVM`, or `SnakeHarnessVM` instance is allocated before the first tile tap.

**Expected:** Cold-start time within noise of the v1.4 baseline; zero arcade-substrate allocations before navigating to a harness screen.

**Why human:** Instruments App Launch template requires a physical device and a Release/Profiling build. The lazy-init precondition (no ArcadeLoopDriver or harness VM references in `App/`) has been verified statically — the clock reading is the remaining check. Plan 05 Task 3 explicitly sanctions this as a fallback deferral.

---

### Gaps Summary

No gaps. All must-have truths are either verified or have human verification pending per the plan-sanctioned SC5 deferral. The two deferred items (ARCADE-03 game-over banner, ARCADE-05 save-on-game-over) are correctly scoped to Phases 16/17 per ROADMAP and plan documentation.

---

_Verified: 2026-06-27_
_Verifier: Claude (gsd-verifier)_
