# Phase 17: Snake - Context

**Gathered:** 2026-07-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Make **Snake fully playable end-to-end** on the Phase 15 arcade substrate:
grid-based movement driven by the fixed-timestep loop, swipe + on-screen D-pad
feeding a capacity-2 direction queue (180° reversals rejected), food spawning
via seeded RNG, grow-on-eat, speed ramp with a calm plateau (≥100ms tick),
self-collision (and wall collision in wall mode) ending the run, score
persistence, Reduce Motion jump-cut path, and the §8.12 theme audit. Covers
requirements **SNAKE-01..07**.

In scope: `Games/Snake/` — `SnakeEngine` (pure, seeded, deterministic),
`SnakeViewModel` (owns the fixed-timestep accumulator with max-dt clamp),
`SnakeGameView` + board rendering, D-pad control cluster, engine unit tests
(seed determinism + ProMotion equivalence), score persistence hookup, deletion
of the throwaway `SnakeHarnessView`.

Out of scope: any change to `Core/ArcadeLoopDriver.swift` /
`Core/ArcadeGameState.swift` (success criterion 3 requires a **zero-diff** on
substrate files); Video Mode adoption (Snake is exempt per the amended Phase 15
ADR); full stats-screen shape (Phase 18); daily seed, SFX, leaderboards.

</domain>

<decisions>
## Implementation Decisions

**Delegation note:** The user reviewed the four gray areas and delegated all of
them to Claude's judgment ("you as the model may have the best opinions").
Decisions below are locked for planning; tuning constants remain planner/
research discretion.

### Visual identity (SNAKE-06)
- **D-01:** The snake renders as a **single continuous rounded path** (adjacent
  cells joined, capsule-like ends), not disjoint blocky cells. The head is
  distinguished by **two small eye dots** (`theme.colors.background` on the body
  fill) — personality with zero extra chrome. Calm, modern, premium; consistent
  with the app's soft-rounded component language.
- **D-02:** Palette signature mirrors Stack's "tower becomes a palette"
  identity: the body shades **along its length** using the same accent-derived
  ramp approach as `StackPalette.layer(forIndex:theme:)` — head darkest/most
  saturated, fading toward the tail. Reuse or adapt the StackPalette derivation
  (promotion to a shared arcade palette helper is allowed if the code is
  genuinely identical — that satisfies the 2+ games rule). Food is a **circle**
  (shape differs from the snake, so color is never the only channel) filled
  with a clearly contrasting token — planner picks between `accentPrimary` and
  `success` after checking §8.12 contrast on Classic + Voltage/Dracula against
  the body ramp.
- **D-03:** **No grid lines.** The board is a clean field using the established
  "board well" treatment (`border`-tinted rounded container, like Merge's
  board). Flat well, no sheen — per DESIGN.md §3.0, depth marks interactivity
  and the well is not a control.
- **D-04:** Movement is **smooth-glide interpolated** between cells at normal
  motion (positions lerped between ticks, same Gaffer-interpolation pattern
  Stack uses for its slider). Under Reduce Motion or animations-off: **jump-cut
  cell teleport per tick** (SNAKE-07, roadmap-locked). Growth extends the tail
  smoothly; under RM it appends instantly.

### Controls layout (SNAKE-03)
- **D-05:** **Swipe anywhere on the board** is the primary control. The board
  area applies `.defersSystemGestures(on: .all)` per success criterion 1 (left-
  edge swipe must not pop navigation).
- **D-06:** The **D-pad is a compact 4-button cross, bottom-center below the
  board** — in the slot other games use for the mode pill / number pad (§5.1
  skeleton), never overlaying the board. Always visible during play (SC4
  requires it operational, not discoverable). Buttons follow the component
  dictionary: `surface` fill, 1pt `border`, `radii.button`, `chipShadow()`,
  `PressableButtonStyle`, ≥44pt hit targets. Opposite-direction button (the
  rejected 180° reversal) renders enabled but is a no-op at the queue level —
  the queue rule is the single source of truth.
- **D-07:** A successful turn input (swipe or D-pad) that enqueues a direction
  fires `.selection` haptic (secondary-action class, §8.2). Rejected inputs
  (180° reversal, full queue) fire nothing — silence reads as "no-op".

### Eat & death feedback triples (DESIGN.md §10.6)
- **D-08:** **Eat** = visual: food absorbed into the head + body grows + score
  chip rolls via `.contentTransition(.numericText)` (the §10.2 idiom) ·
  haptic: `.impact(weight: .light, intensity: 0.7)` (normal move) · animation:
  brief head pulse as the food shrinks into it. All gated by the standard
  `feedbackAnimation` / haptics settings.
- **D-09:** **New high score mid-run** (crossing the persisted best, once per
  run) = `.impact(weight: .medium, intensity: 1.0)` (milestone class) + a
  one-time score-chip pulse. No banner, no interruption — calm.
- **D-10:** **Death** = mirror of Stack's game-over language: the collided
  segment/head flashes `danger`, the whole snake **desaturates/color-drains**,
  then `VideoModeBanner` (final score + restart) after the 500ms game-over
  pre-roll (§10.3). Haptic: `.error` fires on the collision itself. Under
  Reduce Motion / animations-off: instant cut to banner, no drain. **Never any
  screen shake** (brand rule, carried from Stack D-09).

### Wrap/wall mode surfacing (SNAKE-02)
- **D-11:** Snake's Home tile stays **modeless** (tap → straight into the game,
  per ARCADE-09 — do not add a HomeDetailPanel mode picker). The wrap/wall
  toggle lives in the **in-game toolbar menu** (`ellipsis.circle`, topBarTrailing
  — same slot as Five Letter's strict-mode toggle). Label style: "Wall mode:
  On/Off" with wrap as default.
- **D-12:** Toggling mode mid-run uses the **abandon-alert pattern** from
  Merge's `requestModeChange` (immediate apply if no progress; confirm-restart
  alert if food has been eaten). Last choice persists in UserDefaults under a
  stable key (`snake.wallMode` — naming locked, renaming = data break).

### Claude's Discretion
The user delegated all four gray areas — the decisions above are Claude's
picks and can be revisited if playtesting disagrees. Grid dimensions, cell
size, speed-ramp curve/plateau constants, body-ramp cycle length, and the
Canvas-vs-LazyVGrid rendering choice (roadmap flags a 60Hz profiling check)
remain **planner/research tuning constants** within the locked constraints
above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §Phase 17 — goal, success criteria 1–5, dependency on Phase 16
- `.planning/REQUIREMENTS.md` SNAKE-01..07 (lines ~180–186) — requirement wording

### Arcade substrate & precedents
- `.planning/phases/15-arcade-substrate-skeleton/15-CONTEXT.md` — substrate decisions (fixed-timestep accumulator, max-dt clamp, pause semantics)
- `.planning/phases/16-stack/16-CONTEXT.md` — Stack's locked feel decisions (D-05..D-11): palette ramp, game-over choreography, stats-minimalism — Snake mirrors this language
- `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md` — Video Mode exemption; **amended in Phase 16** (Stack adopted Video Mode; Snake REMAINS exempt — pixel-derived grid cells + continuous steering; see HomeView routing comment)

### Design system
- `DESIGN.md` §2 (color semantics), §3.0 (depth rules — new), §3 (component dictionary), §5 (layout skeleton), §8 (haptic vocabulary), §10 (animation vocabulary incl. the new §10.2 rows: numeric-roll chips, press feedback, placement pops), §12.5 (new-game checklist)
- `CLAUDE.md` §8.12 (theme audit), §8.11 n/a, §1 (token discipline)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core/ArcadeLoopDriver.swift` + `Core/ArcadeGameState.swift` — consume as-is; **zero diffs allowed** (SC3)
- `Games/Stack/StackViewModel.swift` — the fixed-timestep accumulator + max-dt clamp + Gaffer interpolation pattern to mirror
- `Games/Stack/StackPalette.swift` (`layer(forIndex:theme:)`) — accent-ramp derivation for the body gradient (adapt or promote)
- `Core/VideoModeBanner.swift` — game-over surface (standard)
- `Core/MotionGate.swift` (`feedbackAnimation`) + `Core/PressableButtonStyle.swift` + `Core/SurfaceDepth.swift` (`chipShadow`) — the new app-wide feel idioms; D-pad and chips must use them
- `Games/Stack/StackScoreChip.swift` / `StackStatsCard.swift` — score chip + stats card shapes to mirror
- `Games/Snake/SnakeHarnessView.swift` — throwaway Phase 15 harness; **delete** when the real game view lands

### Established Patterns
- Engine purity: pure value-type engine, seeded RNG injection, no SwiftUI imports (Stack/Minesweeper discipline)
- `GameKind.snake`, `GameRoute.snake`, `GameDescriptor` snake entry already wired (Phase 15) — no routing work needed beyond swapping the destination view
- Merge's `requestModeChange` abandon-alert pattern for mid-run mode toggles
- Five Letter's toolbar-menu toggle placement for the wall-mode switch

### Integration Points
- `Screens/HomeView.swift` `destination(for:)` — swap `SnakeHarnessView()` for `SnakeGameView()`; Snake stays WITHOUT `.videoModeAware` (exemption)
- `GameStats` / `BestScore` — score persistence path already exercised by Stack (Phase 16)

</code_context>

<specifics>
## Specific Ideas

- Snake should feel like Stack's sibling: same substrate, same palette-signature
  idea (color IS the identity), same calm game-over choreography, same
  "no chrome noise" board.
- "Special but simple": the eye dots on the head and the once-per-run high-score
  pulse are the only personality flourishes — nothing else.

</specifics>

<deferred>
## Deferred Ideas

- Full score-based stats screen shape for Stack + Snake — Phase 18 (ARCADE-07)
- DESIGN.md §12 entries + Video Mode exemption ADR finalization — Phase 18
- Daily seed / score trend charts / SFX cues — explicitly out of v1.5 scope

</deferred>

---

*Phase: 17-snake*
*Context gathered: 2026-07-03*
