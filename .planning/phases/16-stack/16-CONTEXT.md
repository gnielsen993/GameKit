# Phase 16: Stack - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Make **Stack fully playable end-to-end** on the Phase 15 arcade substrate: tap to
drop an oscillating block, trim overhang, narrow the block, recover/expand width
via a perfect streak, ramp speed with a calm plateau, render through SwiftUI
`Canvas`, persist the score on game-over, and ship a Reduce Motion path plus the
§8.12 theme audit. Covers requirements **STACK-01..06**.

In scope: `Games/Stack/` — `StackEngine` (pure value type), `StackViewModel`
(owns the fixed-timestep accumulator), `StackGameView` (Canvas board + idle/
running/game-over lifecycle), engine unit tests (ProMotion-equivalence + edge
cases), score persistence hookup, a minimal Stack section on the Stats screen
(high score + runs played + best perfect streak).

Out of scope (later phases): Snake (Phase 17); the full score-based Stats screen
shape / ARCADE-07 polish (Phase 18); Video Mode (exempt — ADR already written in
Phase 15); daily seed; score trend charts; SFX cues. No changes to `Core/`
substrate files are expected — Stack consumes `ArcadeLoopDriver` +
`ArcadeGameState` as-is.

</domain>

<decisions>
## Implementation Decisions

### Combo / width-recovery feel (STACK-03)
- **D-01:** Recovery is **streak-based**, not single-perfect. Width only
  recovers/expands after **N consecutive perfects** (then expands more on
  continuation); a broken streak resets the counter and gives no recovery. This
  is a deliberately higher skill ceiling than the research default (which favored
  single-perfect-restores for calmness) — the user's call.
- **D-02:** A "perfect" is defined by a **small tolerance band** around dead-center
  (not pixel-exact). This keeps streaks achievable enough that the recovery
  mechanic actually triggers on long runs.
- **D-03:** Exact tolerance width, the streak threshold `N`, and the per-expansion
  width amount are **tuning constants** — research/planning calibrates them
  against the speed ramp so long runs stay viable but earned. Score is unaffected
  by combo (score = blocks placed; streak only affects width — STACK-04 keeps the
  score metric clean).
- **D-04:** The combo/streak counter is **visible during the run** (success
  criterion 1 requires a visible combo counter).

### Block color treatment (STACK-05)
- **D-05:** Tower blocks use a **per-layer gradient** derived from the active
  preset's accent — the "tower becomes a palette" differentiator, not a flat
  single color.
- **D-06:** The gradient **cycles by block index** (each block's color is fixed by
  its position; the ramp repeats every cycle-length as the view scrolls up). A
  placed block **never changes color** once landed. Cycle length is a tuning
  constant.
- **D-07:** For monochrome / low-hue presets the ramp falls back to **lightness
  variation** instead of hue, so the gradient still reads. All colors come from
  DesignKit semantic tokens only (no `Color(red:)`, `Color(hex:)`, or system
  color names anywhere in `Games/Stack/`). Must pass §8.12 (Classic + one Loud/
  Moody) and stay colorblind-distinguishable.

### Perfect-drop & game-over feedback (STACK-06 + DESIGN.md §8/§10)
- **D-08:** Perfect-drop celebration = **color pulse/glow on the landed block +
  a light haptic tick (distinct from the normal-drop impact) + an animated combo-
  counter bump**. **No SFX chime** (SFX not built this phase). All three gated by
  the existing haptics / animation settings; Reduce Motion collapses the pulse to
  an instant color flash and the counter bump to an instant number change.
- **D-09:** Game-over moment = **~0.5s slow-mo on the losing final block + tower
  color-drain/desaturate, then the `VideoModeBanner`** (final score + restart).
  Under Reduce Motion: **instant cut to banner**, no slow-mo. **Never any screen
  shake** (any preset, any setting). Timing follows DESIGN.md §10.3.

### Stats scope this phase (STACK-04, partial ARCADE-07)
- **D-10:** Persist and show **high score + runs played + best perfect streak**
  now. Best-perfect-streak is included this phase (not deferred) because the
  streak mechanic is core to Stack here, so capturing it at game-over avoids a
  second pass. Layout stays **minimal** — the full score-based Stats shape
  (ARCADE-07) is Phase 18.
- **D-11 (constraint for research, not re-opened with user):** Best-perfect-streak
  is a **new metric**. Phase 15 locked "no new SwiftData model / no migration /
  no schema-version bump at the model layer." Research/planning MUST find a
  **CloudKit-safe** way to persist it without a schema bump — candidate
  approaches: a `BestScore`-style higher-only record under a distinct
  mode/metric key, reusing an existing `GameRecord` field, or `UserDefaults` for
  this single Int. The high score itself reuses `GameStats.record(...)` +
  `BestScore` unchanged (higher-only, written once on game-over).

### Claude's Discretion
- Block oscillation style (left-right bounce vs alternating-sides), starting
  sliding speed, idle / tap-to-start screen content, exact danger-zone treatment
  when the block gets very narrow, cycle length for the gradient, tolerance/N/
  expansion tuning constants, and `SeedableRNG` placement (Stack needs no RNG for
  block X if oscillation is deterministic; introduce only if a feature needs it)
  are all left to research/planning.
- Fixed-timestep `fixedDt` (research locks `1.0/60.0`), accumulator placement (VM
  per Phase 15), and the `Frame` value-struct shape are research-confirmed
  defaults — adopt unless a concrete reason emerges.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.5 research (HIGH confidence, codebase-verified 2026-06-25)
- `.planning/research/STACK.md` — frame driver, fixed-timestep accumulator
  (§2, with VM code), Canvas + DesignKit-token integration (§3), tap-to-drop
  input (§4), lifecycle/pausing (§5), high-score persistence write path (§6),
  what stays out of `Core/`/DesignKit (§7/§8). The primary implementation
  reference for this phase.
- `.planning/research/FEATURES.md` — Stack section: exact rules, table-stakes,
  differentiators, **anti-features (brand guard: no lives/coins/revives/ads, no
  shake, speed plateau ~80)**, difficulty-ramp table, accessibility/Reduce Motion
  matrix, stats surface.
- `.planning/research/PITFALLS.md` — spiral-of-death clamp (lives in the driver
  only), ProMotion frame-rate trap, save-on-game-over-only, `.inactive`
  double-counting.
- `.planning/research/ARCHITECTURE.md` — substrate boundary map (Core vs engine
  vs view); confirms Stack adds no `Core/` changes.

### Prior phase context (carried-forward locks)
- `.planning/phases/15-arcade-substrate-skeleton/15-CONTEXT.md` — D-01..D-11:
  loop driver shape, dt-clamp-in-driver-only, accents locked (Stack = vivid
  orange), `modes: []` direct launch, Video Mode exemption (ARCADE-08 ADR
  already written), BestScore/GameStats reuse, no new SwiftData model.
- `gamekit/gamekit/Core/ArcadeLoopDriver.swift` — `.arcadeLoop(isRunning:onTick:)`
  call-site contract; dt already clamped here (do NOT add a second clamp).
- `gamekit/gamekit/Core/ArcadeGameState.swift` — `idle / running / paused /
  gameOver` lifecycle enum the VM drives.

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — STACK-01..06 (lines 171-176); ARCADE-07 (full
  stats shape) mapped to Phase 18; ARCADE-08 Complete (Video Mode exempt).
- `.planning/ROADMAP.md` — Phase 16 goal + 5 success criteria (playable loop;
  60Hz/120Hz fixed-timestep equivalence test; speed plateau + persist-once +
  Stats section; §8.12 Canvas legibility; Reduce Motion jump-cut).

### Project rules
- `CLAUDE.md` §1 (no ads/coins/energy; offline-first), §4 (engine purity — no
  SwiftUI/modelContext in `StackEngine`), §8.1/§8.5 (file size caps — split
  Canvas drawing / VM / engine into siblings), §8.11-analog (deterministic
  engine), §8.12 (theme pass), §8.14 (release-log append), §5 (engine ships with
  tests in same commit).
- `DESIGN.md` §3 (info/score chip, VideoModeBanner end-state), §8 (haptic
  vocabulary + counter-trigger pattern — enforce on the arcade VM), §10
  (animation = causality, Reduce Motion gate, §10.3 pre-roll/timing), §12.5
  (new-game done checklist), §12 (add Stack chrome entries).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core/ArcadeLoopDriver.swift` + `Core/ArcadeGameState.swift` — the substrate
  Stack consumes verbatim; `.arcadeLoop(isRunning: vm.state == .running)`.
- `Core/VideoModeBanner.swift` — end-state banner reused as game-over surface
  (`outcome:`, haptics gated via `trigger:`).
- `Core/BestScore.swift` + `Core/GameStats.swift` — `record(gameKind:mode:
  outcome:score:)` (~line 113) + higher-only `evaluateBestScore`; `.stack`
  GameKind already added in Phase 15 (no migration).
- `Games/Merge/MergeViewModel.swift` — closest VM analog (score-based, no
  difficulty, `recordTerminal()` shape).
- `Games/Stack/StackHarnessView.swift` — **throwaway** Phase 15 harness; delete
  and replace with `StackGameView()` this phase (per Phase 15 D-02).

### Established Patterns
- Counter-trigger haptics: increment an `Int` on the VM, `.sensoryFeedback
  (trigger:)` in the view — use for the perfect-drop tick + normal-drop impact.
- `@Observable @MainActor` VM + dumb view; gesture callbacks on main actor (no
  Sendable concerns for `pendingDrop`).
- Engine purity: `StackEngine` is a pure `struct` with `mutating func step(dt:
  input:) -> Frame`, Foundation-only — mirrors `RevealEngine` / `MergeEngine`.

### Integration Points
- `Screens/HomeView.swift` — Stack destination already wired to the harness;
  swap to `StackGameView` (keep NO `.videoModeAware`).
- `Screens/StatsView.swift` — replace the Stack placeholder with the minimal
  score-based section (high score + runs played + best perfect streak).
- `Core/GameStats.swift` `resetAll()` — ensure Stack score/streak clears.

</code_context>

<specifics>
## Specific Ideas

- The user chose a **higher-difficulty, more skill-expressive** Stack than the
  research's calm default: streak-gated width expansion (not single-perfect
  restore) + slow-mo cinematic game-over. The calm-brand guard still holds
  elsewhere (speed plateau, no shake, no coins/revives) — the difficulty lives in
  the recovery mechanic, not in twitch acceleration.
- Visual signature = the **per-layer gradient tower** as a live expression of the
  current preset's palette; this is the thing that makes GameDrawer's Stack look
  unlike a generic clone.

</specifics>

<deferred>
## Deferred Ideas

- Full score-based Stats screen shape (average score, last-run, prominent
  layout), ARCADE-07 → Phase 18.
- SFX cue for block placement / perfect chime → not this phase (SFX off by
  default; revisit when an SFX pass lands).
- Daily seed, score trend charts, run-summary micro-screen → v2+ per FEATURES.md.

None beyond the above — discussion stayed within phase scope.

</deferred>

---

*Phase: 16-stack*
*Context gathered: 2026-06-27*
