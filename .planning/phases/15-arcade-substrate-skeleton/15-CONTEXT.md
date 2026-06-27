# Phase 15: Arcade Substrate + Skeleton - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the shared real-time loop substrate (`Core/ArcadeLoopDriver` + `Core/ArcadeGameState`) and wire Stack & Snake into the app as **enabled Home tiles that navigate to placeholder screens**. No gameplay, no engines, no per-game logic this phase — this is the wiring harness plus the loop primitive that both games will consume in Phases 16–17.

In scope: the two new `Core/` files, the 7 additive existing-file edits (`GameKind`, `GameRoute`, `GameDescriptor`, `GameKind+AccentColor`, `GameStats.resetAll`, `HomeView` destinations, `StatsView` placeholders), substrate unit tests, a throwaway live-harness placeholder, and the Video Mode exemption ADR.

Out of scope (later phases): Stack gameplay (Phase 16), Snake gameplay (Phase 17), the score-based Stats screen shape / ARCADE-07 (Phase 18), engine RNG, save-state round-trips, speed-ramp tuning.

</domain>

<decisions>
## Implementation Decisions

### Placeholder screen (what tapping Stack/Snake shows in Phase 15)
- **D-01:** Build a **live substrate harness** as each placeholder, not static text. The placeholder view is driven by the real `.arcadeLoop(isRunning:onTick:)` and shows a visibly-moving element (e.g. an oscillating dot or a tick/dt readout) so the whole substrate is exercised end-to-end before any game exists.
- **D-02:** The harness is **throwaway** — it is deleted and replaced by `StackGameView()` / `SnakeGameView()` when the real games land in Phases 16–17. It never ships to users; v1.5 releases only after the games replace it.
- **D-03:** The harness must respect the pause lifecycle: it stops ticking on `scenePhase` `.inactive`/`.background` and on a deliberate "stopped" state, so it is a faithful proof surface for the loop's pause-safety (not a free-running animation).

### Pause-safety verification bar for this phase
- **D-04:** Keep BOTH locked unit tests (`onTick` fires only when `isRunning == true`; spiral-of-death clamp: inject `dt = 2.0`, assert ≤15 ticks and clean exit) **AND** perform the manual notification-banner test on the live harness on a real device: trigger a banner, dismiss, confirm no dt-spike / time-jump reaches `onTick` on resume.
- **D-05:** The manual test is only possible because of the live harness (D-01). This satisfies success criterion #3 within Phase 15 rather than deferring it to Phase 16. `.inactive` and `.background` use the **same** pause handler (a notification banner is `.inactive`).

### Home tile presentation (written once, carries to shipped games)
- **D-06:** Use the **final** caption `"Tap to play"` now — same as every other game tile. Do NOT use a temporary "Coming soon" caption; the descriptor is written once and the tiles only ever ship in their final, playable state. This avoids touching `GameDescriptor` twice.
- **D-07:** **Lock the researched accent colors now** in `Core/GameKind+AccentColor.swift` (new `AccentRole.slot9`/`slot10`):
  - Stack → vivid orange `Color(red: 0.961, green: 0.498, blue: 0.122)`
  - Snake → calm green `Color(red: 0.176, green: 0.741, blue: 0.490)`
- **D-08:** Verify both accents are legible on the tiles under Classic (Chrome Diner) + at least one Loud preset (Voltage/Dracula) before the phase is marked done (§8.12 pass on the Home tiles).
- **D-09:** `modes: []` on both descriptor entries — tapping the tile launches directly with no mode-chip sub-menu (endless games have no difficulty tiers). Symbols follow the research suggestion (`square.stack.fill` / `arrow.triangle.turn.up.right.diamond`) but exact SF Symbol is Claude's discretion if a better-fitting one exists.

### Video Mode exemption ADR (ARCADE-08)
- **D-10:** **Write the ADR in Phase 15**, not Phase 18. The "omit `.videoModeAware()` for Stack/Snake" code decision physically lands in this phase's `HomeView.destination(for:)` edit, and the rationale (continuous real-time input cannot pause-and-reflow for a PiP overlay) is fully known today. Locking it here prevents re-litigation in Phases 16–17.
- **D-11:** This pulls the **ADR artifact** for ARCADE-08 earlier than the current ROADMAP/REQUIREMENTS mapping (which places ARCADE-08 in Phase 18). Phase 18 then only references/closes it. The planner should note ARCADE-08's documentation deliverable is satisfied in Phase 15. The exemption mechanism is precedented: `klondike` already ships without `.videoModeAware` in `HomeView`.

### Claude's Discretion
- Fixed-timestep accumulator placement (driver vs VM vs engine), whether the dt clamp constant is parameterized, exact harness visual, and the precise SF Symbol per tile are all implementation details left to research/planning.
- `SeedableRNG` placement is deferred entirely — no RNG is needed until gameplay (Phases 16–17).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.5 research (substrate decisions — HIGH confidence, codebase-verified 2026-06-25)
- `.planning/research/ARCHITECTURE.md` — substrate file layout, `ArcadeLoopDriver` ViewModifier shape, boundary map (Core vs engine vs view), the 7 additive edits with line-level guidance, NEW-vs-MODIFIED scope table
- `.planning/research/SUMMARY.md` — locked technical decisions table, must-decide-before-coding items, phase-ordering rationale, confidence assessment
- `.planning/research/PITFALLS.md` — spiral-of-death clamp, ProMotion frame-rate trap, `paused:` binding, save-on-game-over-only, `.inactive` double-counting (the top-5 substrate pitfalls Phase 15 must prevent)
- `.planning/research/STACK.md` — Stack mechanics (Phase 16 reference; substrate must not preclude)
- `.planning/research/FEATURES.md` — must-have/anti-feature list (brand guard: calm, no twitch)

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — ARCADE-01..06, ARCADE-09 are this phase; ARCADE-07/08 mapped to Phase 18 (note D-11 pulls ARCADE-08's ADR into Phase 15)
- `.planning/ROADMAP.md` — Phase 15 goal + 5 success criteria (substrate unit tests, enabled tiles → placeholders, scenePhase pause, CloudKit-safe schema additions, unchanged cold-start)
- `.planning/v1.5-BRIEF.md` — milestone scope, out-of-scope, open decisions

### Project rules
- `CLAUDE.md` §1 (offline-first, no new network surface), §4 (engine purity, promote-to-Core rule), §8.1/§8.5 (file size caps), §8.7/§8.8 (synchronized-root-group; new top-level `Games/Stack`+`Games/Snake` folders need a one-time pbxproj group edit, files inside auto-register), §8.12 (theme pass)
- `DESIGN.md` §8 (haptic vocabulary + counter-trigger), §10 (animation/Reduce Motion gate), §12.5 (new-game done checklist)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core/VideoModeAware.swift` — the ViewModifier + `.videoModeAware(...)` adoption pattern `ArcadeLoopDriver` mirrors exactly.
- `Core/VideoModeBanner.swift` — end-state banner reused as-is for game-over later; takes `outcome: Outcome`, gates haptics via `trigger: hapticsEnabled ? n : 0`.
- `Core/BestScore.swift` + `Core/GameStats.swift` — `record(gameKind:mode:outcome:score:)` overload (line ~113) + `evaluateBestScore` (higher-only) already handle score-based high scores. **No new SwiftData model**; adding `.stack`/`.snake` raw-string `GameKind` values is additive, no migration, no schema-version bump.
- `Games/Merge/MergeViewModel.swift` — closest VM analog (score-based, no difficulty), `recordTerminal()` shape for Phases 16–17.

### Established Patterns
- `Core/GameKind.swift` — 8 cases today (minesweeper…wordGrid); raw values are stable serialization keys, locked on first write.
- `Core/GameDescriptor.swift` — `AccentRole` slots 1–8 all consumed; add `slot9`/`slot10` (+`index` 8/9). Existing entries use `captionKey: "Tap to play"`, `symbol:`, `shortMeta:`.
- `Screens/HomeView.swift` — `destination(for: GameRoute)` switch; `klondike` already omits `.videoModeAware` (precedent for the Stack/Snake exemption). All entries use `.disableInteractivePop()`.
- Counter-trigger haptics (`revealCount`, `mergeCount`, etc.) — incrementing `Int` on VM, `.sensoryFeedback(trigger:)` in view. Enforce on arcade VMs from day one (Phases 16–17).

### Integration Points
- `Core/GameRoute.swift` (+2 cases, no associated value), `Core/GameDescriptor.swift` (+2 slots, +2 `.all` entries pointing at the harness placeholders this phase), `Core/GameKind+AccentColor.swift` (+2 colors, D-07), `Core/GameStats.swift` `resetAll()` (+2 `clearAll()` lines — may be stubbed until save-state exists in 16/17), `Screens/HomeView.swift` destinations (+2 harness cases, NO `.videoModeAware`), `Screens/StatsView.swift` placeholders.

</code_context>

<specifics>
## Specific Ideas

- The placeholder is deliberately a *working* substrate demo, not chrome — its entire value is exercising `TimelineView(.animation(paused:))` + the `min(dt, 0.1)` clamp + scenePhase pause before a real game depends on them.
- Accent intent is explicitly "calm, not twitch" (FEATURES.md brand guard): orange/green chosen to read as distinct, friendly tiles in the Drawer, not arcade neon.

</specifics>

<deferred>
## Deferred Ideas

- Stack/Snake gameplay, engines, save-state, Canvas-vs-LazyVGrid rendering choice → Phases 16/17.
- Score-based Stats screen shape (High Score + Runs Played, no win-rate/best-time columns), ARCADE-07 → Phase 18.
- Snake wrap-vs-wall default, Reduce Motion jump-cut DESIGN.md §12 entries, speed-ramp constants → owning game phases (16/17), discuss there.
- `SeedableRNG` struct (Swift's RNG isn't seedable) → introduce with first engine; promote to `Core/` only if both engines share it.

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-arcade-substrate-skeleton*
*Context gathered: 2026-06-26*
