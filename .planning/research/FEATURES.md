# Feature Research — v1.5 Endless Arcade Primitive

**Domain:** Calm endless arcade games (Stack + Snake) added to a shipped premium, ad-free iOS game suite
**Researched:** 2026-06-25
**Confidence:** HIGH on core mechanics (established genre conventions, 30+ years of Snake, 10+ years of Stack variants); MEDIUM on specific speed-ramp curves (no canonical public spec — conventions derived from surveyed implementations); HIGH on anti-features (GameKit brand constraints are explicit in PROJECT.md and CLAUDE.md)

---

## Scope Note

This research covers **Stack and Snake only** — the two calm endless arcade games scoped for v1.5. The seven shipped turn-based games (Minesweeper, Merge, Nonogram, Five Letter, Word Grid, FreeCell, Sudoku) are out of scope here. The **shared real-time substrate** (loop driver, lifecycle shell, high-score persistence) is a prerequisite for both games and is treated as a hard dependency below.

Both games are **calm, not twitch**. The product posture is "meditative, geometric, theme-token-perfect, one-more-try without stress." Any feature that tips these games toward rage, frustration coercion, or compulsion loops is an anti-feature by brand definition regardless of whether competitors do it.

---

## Game 1 — Stack

### Core Mechanic and Exact Rules

Stack is a precision-timing tower game. The player taps to drop a sliding block onto a growing tower.

**Block movement:** A block of the same width as the current tower top oscillates left-to-right (or appears alternating from left/right sides) directly above the topmost placed block. Movement is continuous and automatic — the player does not control the direction, only the moment of drop.

**Drop and overhang trimming:** When the player taps, the block falls. The section of the block directly above the previous block lands cleanly. Any overhang — the portion that extends past the previous block's edge — is trimmed off and falls away. The remaining overlap becomes the new top block, which is necessarily narrower than or equal to the previous one.

**Perfect drop:** A drop where the incoming block aligns exactly with the block below. Overhang is zero. The block lands at full width (no trimming). In most implementations a perfect drop also triggers a bonus: either restoring the block toward a larger size, growing the block incrementally over a streak, or expanding the landing zone after N consecutive perfects (5 consecutive perfects in some variants; a single perfect in the Ketchapp original triggers escalating size reward over a streak). The exact mechanic used should be decided at implementation time — both "single perfect restores" and "N-consecutive perfects expand" are well-established; the former is simpler and more forgiving (fits the calm brand better).

**Block width shrinks over time** as misses accumulate. When the block width reaches zero — i.e., the player taps when no overlap is possible — the game ends.

**Score:** One point per successfully placed block. Score = tower height in blocks. There is no multiplier on the score itself; height is the score. The combo/perfect streak does not multiply score; it affects block width (quality-of-life reward), keeping the score metric clean and honest.

**Speed ramp:** Block sliding speed increases as tower height grows. The Ketchapp original ramps speed approximately every 15–20 blocks and eventually plateaus — speed does not increase indefinitely. A soft cap prevents the game from becoming physically impossible.

**Game over condition:** The block is dropped and lands with zero overlap on the previous block (complete miss), OR the block width has been trimmed to a width that makes placement impossible. In either case the run ends immediately. No lives, no continues.

**Engine shape (per PROJECT.md brief):**
```
StackEngine.drop(at:) -> (placed: CGRect, overhang: CGRect, newWidth: CGFloat, gameOver: Bool)
```
The engine is pure (Foundation-only, no SwiftUI imports), deterministic given the input stream, and unit-testable.

### Scoring Model

- **Score = blocks placed** (integer count, starts at 0). Simple, honest, instantly understood.
- **Perfect streak counter** displayed during the run (e.g. "3 perfects in a row") — gives feedback without polluting the primary score.
- **No fake multipliers, no coins, no gems.** The score is the score.
- High score = personal best block count. Comparing yesterday's self to today's self is the only leaderboard this app needs.

### Difficulty Ramp

Stack is endless by definition. The ramp is built into the engine, not preset-selected.

| Phase | Tower Height | Sliding Speed | Block Width Behavior |
|-------|-------------|---------------|---------------------|
| Opening | 0–15 blocks | Slow | Full starting width; perfects very achievable |
| Developing | 16–40 blocks | Medium | Width narrows with each partial miss; perfects recover some width |
| Pressure | 41–80 blocks | Fast | Only clean players maintain width; partial misses compound |
| Plateau | 80+ blocks | Capped maximum | Speed doesn't increase further; difficulty is now purely the narrow landing zone |

The speed plateau is important for the calm brand. A game that keeps accelerating indefinitely until death is a twitch game. A game where speed plateaus and the challenge becomes purely spatial/precision is a skill game — more meditative. **Speed should cap no later than ~80 blocks.**

Perfects at any height partially restore block width, giving the player a recovery mechanic that keeps long runs viable rather than inevitably doomed. This makes the game satisfying rather than frustrating.

### Table Stakes

Features every Stack implementation must have to feel complete. Missing any of these = the game feels broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Oscillating block above tower | The entire mechanic — without it there is no game | S | Left-right or alternating sides; both are established |
| Tap anywhere to drop | Largest possible tap target; no precision required on the gesture | S | One-tap, not two-finger, not a specific zone |
| Overhang trimming (visual) | Players must see the trimmed piece fall away to understand the penalty | S | A falling chunk with brief animation communicates the rule without text |
| Width shrinks on imperfect drops | Core feedback loop; without it every drop feels equivalent | S | New block = overlap only |
| Perfect drop acknowledged visually | Without feedback, players don't know they hit one | S | Flash, color pulse, or brief glow on the top block |
| Speed increases with height | Without it the game never gets harder; trivially infinitely solvable | S | Ramp per block count, not per time |
| Speed plateau (hard cap) | Prevents the game from becoming physically impossible and un-calm | S | ~80 blocks as soft guidance |
| Game over when width = 0 or complete miss | Clear end condition; players must understand why the run ended | S | Show the final miss visually |
| Score display (block count) during run | Players must be able to see their current height | S | Top of screen or overlay chip |
| High score display during run | Compare current run to personal best in real time | S | Secondary, smaller than current score |
| Game over banner with final score and restart | Standard game-over affordance; without it the run just dies awkwardly | S | Matches the v1.2 banner pattern already in the suite |
| Instant restart (one tap from game over) | "One more try" loop depends on zero friction to restart | S | Tap the banner CTA; no confirmation dialog |
| Haptics on perfect drop, trim, game over | Tactile game is part of Stack's feel; wrong without it | S | Use DesignKit haptic patterns |
| Theme-driven block colors | App requires all UI via DesignKit tokens; block colors must derive from theme | M | Every preset must produce visually distinct blocks |

### Differentiators

What a calm, premium, theme-customizable version adds beyond the commodity Stack experience.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Block colors driven by DesignKit preset | No other Stack game has 34-preset theming; the tower becomes a palette | M | Each block layer gets a graduated hue derived from the theme's accent ramp, so the tower looks like a color gradient specific to the current preset |
| Satisfying "perfect" visual within Reduce Motion limits | Premium feel without screen shake or scale pops; a clean color pulse or glow | S | Two paths: full motion (scale bounce + particle shimmer) and Reduce Motion (instant color flash only) |
| Smooth falling animation for trimmed overhang | Makes the trim feel physics-grounded rather than abrupt | S | Short fall + fade-out; skip under Reduce Motion |
| Width recovery on perfect (generous mechanic) | Calm brand: the game should reward skill, not just punish mistakes | S | A perfect restores a defined amount of width (e.g. +8pt of the original block width, capped at original) |
| Run summary screen (score + perfect count + best perfect streak) | A moment of reflection before restarting; feels premium vs raw score only | S | Stats surface: final score, perfects hit this run, longest perfect streak this run |
| Stats history (high score, runs played, best perfect streak overall) | Players want to see growth over time | S | Uses existing SwiftData stats layer extended for score-based games |
| SFX: a distinct chime or tone per block placed (not per frame) | The Ketchapp original used musical tones; calm and satisfying | S | Off by default; respects SFX toggle in Settings |
| Gentle slow-motion landing effect on the final block (not Reduce Motion) | The game-over moment deserves a beat; not a sudden cut | S | 0.5s slow-mo effect on the last block before banner; skip under Reduce Motion |
| Zero-ad interruptions (the entire product's differentiator) | No interstitials between runs; no rewarded video for a "continue" | S (avoidance) | Permanent brand rule |

### Anti-Features

Explicit refusals with rationale specific to Stack in this product context.

| Feature | Why Requested | Why Refuse | Alternative |
|---------|---------------|------------|-------------|
| Rewarded video for "continue" after game over | "Feels fair to players who want to keep going" | It normalizes ad interruptions in what must be an ad-free product; monetizes the loss moment which is the worst possible time to interrupt | No continues. Instant restart is the loop. |
| Lives / heart system | "Gives players more chances" | Artificial gate on play; metered access is a dark pattern by definition (PROJECT.md §1) | Unlimited runs always |
| Coin reward per block / per perfect | "Engagement loop" | Fake currency is permanently excluded (CLAUDE.md §1); dilutes the score into a pseudo-economy | Score IS the reward |
| Daily-streak shaming if player misses a day | "Retention metric" | Coercive engagement bait; brand posture is "play when you want" | Show streak as a neutral stat if daily seed is later added; never guilt on miss |
| Global leaderboard (requires accounts) | "Social competition" | Requires accounts or Game Center auth; out of scope (PROJECT.md §1); social comparison pressure is not the calm brand | Personal high score is the only leaderboard needed |
| Aggressive speed-up without plateau | "Increasing difficulty" | Endless acceleration turns a calm precision game into a reflex-twitch rage game | Speed plateau at ~80 blocks; difficulty becomes spatial, not purely reaction-speed |
| Random difficulty spikes (sudden speed burst mid-run) | "Surprise factor" | Manufactured frustration; the player should always understand why a run ended | Smooth deterministic ramp only |
| Push notifications to return ("Your high score is waiting!") | "Re-engagement" | Brand posture is "play when you want" | Never. No push notifications except explicit opt-in (none in v1.5) |
| Block skin packs (paid) | "Cosmetic monetization" | In a fully-themed system the preset IS the skin; selling skins would undercut the DesignKit theming story | Theming via DesignKit presets is already the mechanic |
| Screen shake on game over | "Impact" | Reduces accessibility (vestibular sensitivity); not calm | Color drain + freeze frame under full motion; instant cut to banner under Reduce Motion |

### Replay Loop and Retention (Without Dark Patterns)

The calm, no-dark-pattern engagement loop for Stack:

1. **Instant restart** is the single most powerful retention mechanic. Zero friction from game over to next run.
2. **In-run high score chip** shows the player exactly how many blocks they need to beat their record. The goal is always specific and just ahead.
3. **Streak momentum** within a run (consecutive perfects building visible feedback) creates natural internal flow state — the player wants to maintain the streak, not the game nagging them.
4. **Personal high score as the only external goal.** No leaderboards, no badges. The intrinsic motivation is "beat yourself."
5. **Optional daily seed (future):** A fixed-seed run for the day where everyone who plays on the same day gets the same block sequence. No compulsion mechanic — missing a day costs nothing. This is a v2+ consideration for this game, not v1.5 scope.
6. **Run summary micro-moment:** A 2-second summary screen (final score, perfects hit, personal best indicator) before the restart CTA. This creates a small reflection pause that paradoxically increases the desire to restart rather than closing the app.

### Stats Surface

Score-based games show different stats than win/loss games. The existing suite (Minesweeper, Merge, etc.) shows wins/losses/win-rate/best-time. Stack needs:

| Stat | Display | Notes |
|------|---------|-------|
| High Score (all-time personal best) | Large, prominent | The primary KPI; always shown on the pre-run idle screen |
| Current run score | Large, in-run only | Replaces high score display during run; or shown alongside it |
| Runs Played (total) | Stats screen | Shows investment in the game |
| Average Score (last N runs or all-time) | Stats screen | Gives sense of consistency vs peak |
| Best Perfect Streak (all-time) | Stats screen | Secondary skill metric beyond raw height |
| Last Run Score | Stats screen (or game-over banner) | Gives immediate context after each run |

No win-rate column, no "wins" — this is not a win/loss game. The stats shape differs from the logic games and should not force-fit the same schema visually.

### Accessibility

| Concern | Requirement | Implementation |
|---------|-------------|----------------|
| Reduce Motion | Full motion: block slide, trim fall, perfect bounce, slow-mo game-over. Reduce Motion: slide still visible (pure position change, no spring bounce), trim disappears instantly (no fall animation), game-over is instant cut to banner — no slow-mo | Check `accessibilityReduceMotion` at render time; the engine itself is unchanged |
| Vestibular safety | No screen shake ever (game over or any other event) | A color drain or desaturation on game over is safe; shake is not |
| Colorblind safety | Block colors are derived from DesignKit theme tokens, which must themselves be colorblind-distinguishable | The block-color gradient relies on hue shift across layers; for monochromatic themes the gradient uses lightness variation instead of hue — both are token-driven |
| One-handed play | Tap anywhere to drop — no specific zone required | Already achieved by the core mechanic; no additional work needed |
| Font sizing | Score chip uses a fixed display size (it's a number counter, not body copy); Dynamic Type only applies to non-game UI (banner text, stats screen, home tile) | Standard GameKit rule |
| VoiceOver | Not meaningfully playable with VoiceOver (the game requires real-time visual tracking); VoiceOver users should see a clear "real-time action game" description on the home tile so they can make an informed choice | Match the convention for other real-time games |

---

## Game 2 — Snake

### Core Mechanic and Exact Rules

Snake is a grid-based endless game. The player controls a snake that moves continuously through a bounded grid, eating food to grow and avoiding collisions.

**Grid:** A rectangular grid of cells (e.g. 20×20 to 30×30 depending on device screen size). The snake occupies a chain of cells. Each tick the snake advances one cell in the current direction.

**Direction input:** The player swipes to change the snake's current direction by 90 degrees. Swiping in the exact reverse direction (180 degrees) is ignored — the snake cannot reverse into itself. Queuing one ahead-of-tick direction change is the standard mechanic (tapping quickly during a tick still registers for the next step).

**Food:** One piece of food exists on the grid at a time, placed at a random empty cell. When the snake's head enters the food cell, the snake grows by one segment (the tail does not retract on that tick), score increments, and new food spawns at a new random empty cell.

**Self-collision:** If the snake's head enters a cell occupied by any body segment, the run ends immediately.

**Wall collision variants:**
- **Classic (walls kill):** Head entering any cell outside the grid boundary ends the run. This is the harder, more familiar variant.
- **Wrap (toroidal):** Head exiting one edge appears on the opposite edge. The grid is effectively a torus. This is an easier, calmer variant — the wall can never be a surprise cause of death; only self-collision ends runs.

**Recommended variant for calm brand:** Wrap (toroidal) as the default, with Classic walls as an optional mode. The wrap variant eliminates "I hit a wall I didn't see coming" frustration that contradicts the calm posture.

**Score:** Number of food items eaten = number of times the snake grew. Score starts at 0. This is the cleanest and most universally understood Snake scoring model. High score = personal best food count.

**Tick rate:** The snake moves once per tick. A tick interval of ~200ms (5 moves/sec) is a reasonable starting pace. Speed ramp decreases the tick interval over time.

**Engine shape (per PROJECT.md brief):**
```
SnakeEngine.step(dir: Direction) -> Frame
// Frame: { grid state, score, event: .none | .ate | .died }
```
The engine receives one direction input per step, returns the new frame. Pure, deterministic, no SwiftUI.

### Scoring Model

- **Score = food eaten** (integer count, starts at 0). The snake's visible length on screen is score + initial_length, which gives a natural at-a-glance sense of progress.
- **No multipliers, no coins.** The score is the food count.
- **Speed bonus scoring (optional variant):** Some Snake implementations add a small time bonus for eating food quickly. This can add nuance but also stress. For the calm brand, keep scoring flat: 1 food = 1 point.
- High score = personal best food count. The high score displayed during a run gives a concrete target.

### Difficulty Ramp

Snake's ramp is built into the engine — no preset difficulty levels.

| Phase | Score (food eaten) | Tick Interval | Feel |
|-------|-------------------|---------------|------|
| Opening | 0–5 | ~250ms (4 steps/sec) | Relaxed; grid feels spacious; mistakes forgiven by wrap |
| Developing | 6–15 | ~200ms (5 steps/sec) | Snake is noticeably longer; space management starts to matter |
| Pressure | 16–30 | ~150ms (6.7 steps/sec) | Grid getting crowded; direction changes must be planned ahead |
| Expert | 31–50 | ~120ms (8.3 steps/sec) | Self-trap avoidance is the core skill; intentional path planning required |
| Plateau | 50+ | ~100ms (10 steps/sec) | Speed plateaus; difficulty is now purely spatial self-trap avoidance |

**The speed plateau is essential.** At 100ms per tick the game is challenging but not physically impossible for a human. Reducing tick interval below ~100ms makes the game a reflex test rather than a spatial planning game — that's the twitch boundary the calm brand must stay above.

The natural difficulty ramp from self-trap avoidance (a longer snake occupies more space, limiting available paths) provides increasing challenge even after the speed plateau, keeping the game interesting indefinitely without artificial acceleration.

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Grid-based movement (discrete cells) | Snake's defining primitive; without discrete movement collision is ambiguous | M | Cell size must fit the device with at least 20×20 grid (18×18 minimum on small iPhones in landscape is acceptable) |
| Swipe to change direction | Standard iOS touch idiom for Snake | S | 4-directional swipe; queue one input ahead per tick |
| Food appears as a single visible cell | Universal expectation | S | Distinct color from snake body; theme-token driven |
| Snake grows on eating food | Core rule; without it there is no end state | S | Tail stays in place for the tick food is eaten |
| Self-collision ends the run | Core rule | S | Head enters any body segment cell = game over |
| Score displayed during run (food count) | Players need to see current progress | S | Top of screen or overlay chip |
| High score chip during run | Gives a target | S | Secondary to current score |
| Game over banner with final score and restart | Standard end state | S | Reuses v1.2 banner pattern |
| Instant restart | Zero-friction loop | S | One tap from banner |
| Speed increases as score grows | Without it the game is trivially easy; speed provides the time pressure | S | Smooth ramp, plateau at ~50 food eaten |
| Food spawns at a random empty (not snake-occupied) cell | Without this guarantee food can spawn inside the snake | S | Engine responsibility: filter occupied cells from candidate positions |
| Haptics on food eaten, game over | Tactile feedback expected | S | DesignKit haptic patterns |
| Theme-driven snake and food colors | All UI must use DesignKit tokens | M | Snake body: accent color; food: a contrasting token (e.g., theme success or a secondary accent) |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Wrap mode as default (toroidal grid) | Eliminates wall-surprise deaths; calmer and more forgiving than classic walls for the GameDrawer brand posture | S | Wall mode available as a toggle for users who want the classic hard experience |
| Input queue (one direction buffered per tick) | Prevents missed swipes from causing accidental self-reversal during rapid direction changes; reduces frustration | S | Standard in quality Snake implementations; often omitted in quick clones |
| Snake body rendered with rounded cell corners | Visual polish that makes the snake feel like a continuous object vs discrete squares | S | DesignKit border radius tokens applied to each body cell, with head and tail getting unique cap shapes |
| Color gradient along the snake body | Head is bright accent; tail fades toward a softer variant of the same hue; visually elegant and helps players track the head | M | Derived from DesignKit theme — every preset makes a different gradient |
| Food eaten animation (brief pulse/pop) | Acknowledges the eat moment satisfyingly | S | Two paths: bounce + particle under full motion; instant color flash under Reduce Motion |
| Grid cell count adapts to device size | A 20×20 grid on iPhone SE vs 28×28 on Pro Max; each cell is always a comfortable visual size | M | Dynamic grid sizing at run start based on available screen area |
| Countermeasure against self-trap awareness (no hint) | The challenge is spatial; the game does not assist or warn about impending self-traps — that's the skill | S (avoidance) | No "danger" indicators or path highlights — those belong to a different game type |
| Run summary with snake length visualization | The final snake length drawn small on the game-over banner as a visual callback | M | Nice touch; shows visual representation of the run |
| Stats history (high score, runs, average score) | Tracks growth over sessions | S | Same SwiftData extension as Stack |

### Anti-Features

| Feature | Why Requested | Why Refuse | Alternative |
|---------|---------------|------------|-------------|
| Shields / invincibility power-ups | "Extends runs" | Power-ups are a free-to-play monetization onramp; the first shield is free, then they want to sell more | No power-ups; skill is the only path to longer runs |
| Speed boost collectibles | "Variety" | Sudden speed changes are jarring and un-calm | Speed ramp is smooth and predictable |
| Obstacle cells spawning mid-run | "Increasing difficulty" | Random obstacles shift the game from spatial planning to reaction avoidance; that's the twitch category | Self-collision from growth is the only obstacle |
| Revive-for-coins on death | "Second chance" | Introduces fake currency (CLAUDE.md §1 permanent exclusion) | Instant restart; the run ends cleanly |
| Snake "skins" as IAP | "Cosmetic monetization" | DesignKit presets ARE the skins; selling skins undercuts the theming system | 34 presets give effectively infinite snake appearances |
| Leaderboard requiring Game Center / account | "Social" | Requires auth; out of scope (PROJECT.md §1) | Personal high score only |
| Aggressive speed ramp beyond the calm plateau | "Gets harder" | Sub-100ms tick intervals tip Snake from spatial planning to pure reflex; that's the twitch category | Hard speed cap; space constraint provides ongoing challenge |
| Banner ads between runs | "Monetization" | Permanently excluded (CLAUDE.md §1) | None |
| Vibration-based haptics on every snake move tick | "Immersion" | Per-tick haptics at 5–10 steps/sec become vibration spam; distracting rather than informative | Haptics only on food eaten and game over |
| Reverse-direction as "U-turn" power-up | "Fun mechanic" | Breaks the established mental model; players expect the reverse-block rule | Standard reverse-block maintained always |

### Replay Loop and Retention (Without Dark Patterns)

The calm engagement loop for Snake:

1. **Instant restart** — same as Stack; the most powerful mechanic; zero friction.
2. **In-run high score chip** — gives a specific score target. Players naturally orient toward "I need 3 more food to beat my record."
3. **Intrinsic spatial challenge** — the longer the snake gets, the harder it becomes to navigate without the game doing anything. The difficulty curve is self-generating. This is the "one more run" engine.
4. **Wrap mode removes cheap frustrating deaths** — removing wall deaths means the player can always blame themselves rather than the board. This is important for calm engagement; the run ending must feel earned, not arbitrary.
5. **No friction points** — no interstitials, no confirmation dialogs, no prompts between runs. The game should feel like a loop: run → dead → banner → tap → new run.
6. **Daily seed (future, v2+):** A fixed food-position sequence for the day. Mild engagement layer. Same no-compulsion rule: missing a day is fine.

### Stats Surface

| Stat | Display | Notes |
|------|---------|-------|
| High Score (personal best food eaten) | Large, prominent; shown on idle pre-run screen | Primary KPI |
| Current Score (food eaten this run) | Large, in-run | Primary in-run display |
| Runs Played | Stats screen | Investment metric |
| Average Score (all-time or last 10) | Stats screen | Tracks improvement trend |
| Longest Run Duration (time) | Stats screen | Optional secondary metric — some players care about session length even if score isn't high |
| Last Run Score | Game-over banner or stats screen | Immediate post-run feedback |

Like Stack, there are no wins/losses in the traditional sense. Every run ends in death — the framing is "score" not "win/loss."

### Accessibility

| Concern | Requirement | Implementation |
|---------|-------------|----------------|
| Reduce Motion | Full motion: smooth snake movement animation between cells, food eat pop, death animation. Reduce Motion: snake teleports cell-to-cell (no between-cell interpolation), food eat is instant color change, death is instant cut to banner | The engine tick governs position; only the renderer interpolates between ticks; Reduce Motion disables interpolation |
| Vestibular safety | No screen shake at any point (death or otherwise) | Color drain on game over is safe; shake is not |
| Colorblind safety | Snake body and food must be distinguishable by shape (snake is a chain of cells; food is a single isolated cell) as well as color | Shape difference alone makes them distinguishable even if theme colors are low-contrast; color provides redundant cue, not the only cue |
| One-handed play | Swipe in any quadrant of the screen to change direction | Standard; already one-handed by nature |
| Left-handed play | Swipe detection is symmetric; no directional bias in the gesture recognizer | No special work needed beyond standard swipe implementation |
| Input sensitivity | Allow swipe threshold to be short enough for quick direction changes; too long a swipe threshold causes missed inputs at high speed | Tune swipe detection distance during implementation; flag for testing |
| VoiceOver | Not meaningfully playable (real-time visual game); label the home tile as "Snake — real-time action game, not optimized for VoiceOver" so users can decide | Same convention as Stack |
| Smallest device | iPhone SE 3rd gen (~375pt width); grid must not be so dense that cells are untappable; minimum cell size ~14pt recommended | Dynamic grid sizing at engine init time |

---

## Shared Substrate — Feature Implications

Both games depend on a **shared real-time loop substrate** in `Core/`. The feature implications:

| Substrate Feature | Stack Requires | Snake Requires | Notes |
|------------------|----------------|----------------|-------|
| Loop driver (TimelineView or CADisplayLink) | Yes — continuous block position update | Yes — tick interval clock | Both games drive off the same driver contract |
| Fixed-timestep tick engine (`step(dt:input:)`) | Yes — block position is continuous but drop is a discrete event | Yes — movement is discrete per tick | Snake is purely discrete; Stack has a continuous position component for the sliding block |
| Lifecycle (idle → running → game-over → restart) | Yes | Yes | Shared tap-to-start affordance and game-over banner shape |
| High-score persistence (SwiftData extension) | Yes | Yes | New `ArcadeGameRecord` or similar; score-based not win/loss |
| Reduce Motion path | Yes | Yes | Each game handles its own render-layer response; substrate provides the `@Environment` value |
| Haptics contract | Yes | Yes | Existing DesignKit haptic patterns; event vocabulary is per-game |

**Video Mode:** Both games are likely Video-Mode-exempt for v1.5 (stated in the v1.5 brief as a probable exemption). Real-time continuous-input games cannot pause-and-reflow for PiP the way turn-based games do. Confirm in discuss-phase; document the exemption decision in an ADR.

---

## Feature Dependencies

```
Shared Substrate (Core/LoopDriver + ArcadeLifecycle + ArcadeStatsStore)
    ├──required by──> Stack (engine + view + viewmodel)
    └──required by──> Snake (engine + view + viewmodel)

ArcadeStatsStore (SwiftData extension)
    ├──required by──> Stack high score persistence
    └──required by──> Snake high score persistence

Stack:
  StackEngine.drop() ──> StackViewModel ──> StackView
  StackView ──requires──> DesignKit token block colors
  Haptics (on perfect, on trim, on game over) ──requires──> existing HapticService
  Reduce Motion path ──requires──> @Environment(\.accessibilityReduceMotion)

Snake:
  SnakeEngine.step() ──> SnakeViewModel ──> SnakeView
  SnakeView ──requires──> DesignKit token snake/food colors
  Input queue ──decorates──> SnakeViewModel (between view and engine)
  Wrap vs Wall mode ──configures──> SnakeEngine at init
  Grid size ──computed from──> available view geometry at init

Shared Substrate ──must ship before──> either game (build order dependency)
```

---

## MVP Definition for v1.5

### Ship with Substrate + Both Games

- [ ] **SUBSTRATE-01:** Loop driver (TimelineView-based) at device refresh rate
- [ ] **SUBSTRATE-02:** Fixed-timestep contract `step(dt:input:) -> Frame`
- [ ] **SUBSTRATE-03:** Idle → running → game-over → restart lifecycle shell
- [ ] **SUBSTRATE-04:** Tap-to-start affordance on idle state
- [ ] **SUBSTRATE-05:** Game-over banner reusing v1.2 VideoModeBanner pattern
- [ ] **SUBSTRATE-06:** SwiftData high-score persistence (score-based, not win/loss)
- [ ] **STACK-01:** `StackEngine.drop(at:)` pure engine — placed rect, overhang rect, new width, game-over flag
- [ ] **STACK-02:** Oscillating block visual driven by engine position
- [ ] **STACK-03:** Overhang trim visual (falling piece)
- [ ] **STACK-04:** Perfect drop detection + acknowledgment (color pulse)
- [ ] **STACK-05:** Width recovery on perfect (+fixed amount, capped at original width)
- [ ] **STACK-06:** Speed ramp (every ~15 blocks, hard cap ~80 blocks)
- [ ] **STACK-07:** Score chip (block count) + high-score chip during run
- [ ] **STACK-08:** Block colors derived from DesignKit theme tokens
- [ ] **STACK-09:** Haptics (perfect, trim, game-over) via DesignKit haptic patterns
- [ ] **STACK-10:** Reduce Motion path (no spring bounce, no falling trim animation, no slow-mo game-over)
- [ ] **STACK-11:** Stats screen extension (high score, runs played, average score, best perfect streak)
- [ ] **SNAKE-01:** `SnakeEngine.step(dir:)` pure engine — grid state, score, event enum
- [ ] **SNAKE-02:** Grid rendering with rounded body cells and head/tail caps
- [ ] **SNAKE-03:** Swipe gesture for direction change with input queue (1 ahead)
- [ ] **SNAKE-04:** Self-collision detection + game-over event
- [ ] **SNAKE-05:** Wrap (toroidal) mode as default; Wall mode as optional toggle
- [ ] **SNAKE-06:** Food spawn at random empty cell
- [ ] **SNAKE-07:** Score chip (food count) + high-score chip during run
- [ ] **SNAKE-08:** Speed ramp (tick interval decrease from ~250ms to ~100ms floor)
- [ ] **SNAKE-09:** Snake and food colors derived from DesignKit theme tokens
- [ ] **SNAKE-10:** Haptics (food eaten, game-over) via DesignKit haptic patterns
- [ ] **SNAKE-11:** Reduce Motion path (no between-cell interpolation; instant cell-to-cell movement)
- [ ] **SNAKE-12:** Dynamic grid sizing based on available screen geometry
- [ ] **SNAKE-13:** Stats screen extension (high score, runs played, average score)

### Deferred to Post-v1.5

- [ ] Daily seed for Stack or Snake — v2+; engagement layer, not MVP
- [ ] Video Mode for either game — confirm exempt in discuss-phase; document ADR
- [ ] Rich stat charts (trend chart for score over sessions) — v2+
- [ ] Color gradient along snake body — nice touch, cut if time-pressed
- [ ] Run summary snake-length visualization — nice touch, cut if time-pressed
- [ ] Wall mode toggle for Snake (if wrap ships clean, Wall is a low-effort add in v1.5.1)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Shared substrate (loop driver + lifecycle) | HIGH | MEDIUM | P1 (foundation; nothing ships without it) |
| ArcadeStatsStore (SwiftData extension) | HIGH | LOW | P1 |
| StackEngine (pure, deterministic) | HIGH | MEDIUM | P1 |
| SnakeEngine (pure, deterministic) | HIGH | MEDIUM | P1 |
| Stack: overhang trim + width shrink | HIGH | LOW | P1 |
| Stack: perfect detection + width recovery | HIGH | LOW | P1 |
| Stack: speed ramp + plateau | HIGH | LOW | P1 |
| Snake: wrap mode (toroidal) | HIGH | LOW | P1 |
| Snake: input queue | HIGH | LOW | P1 |
| Snake: speed ramp + plateau | HIGH | LOW | P1 |
| Snake: dynamic grid sizing | HIGH | MEDIUM | P1 |
| Reduce Motion path (both games) | HIGH (for affected users) | LOW | P1 |
| DesignKit theme token block/snake colors | HIGH (brand requirement) | MEDIUM | P1 |
| Haptics (both games) | MEDIUM | LOW | P1 |
| Stats screen extension (both games) | MEDIUM | LOW | P1 |
| Stack color gradient per layer | MEDIUM | LOW | P2 |
| Snake body gradient head-to-tail | MEDIUM | MEDIUM | P2 |
| Snake wall mode toggle | LOW | LOW | P2 |
| Daily seed (either game) | LOW (v1.5 audience too small) | MEDIUM | P3 |
| Score trend charts | LOW | MEDIUM | P3 |
| Video Mode adoption (either game) | LOW (likely exempt) | HIGH | P3 or NEVER |
| Ads / coins / revives / IAP skins | NEGATIVE | n/a | NEVER |
| Global leaderboards | LOW (requires auth) | MEDIUM | NEVER (v1.5) |
| Power-ups or shields | NEGATIVE | MEDIUM | NEVER |
| Screen shake (any event) | NEGATIVE (accessibility) | n/a | NEVER |
| Push notifications to re-engage | NEGATIVE | LOW | NEVER |

---

## Sources

- [Stack by Ketchapp on App Store](https://apps.apple.com/us/app/stack/id1080487957)
- [Stack Tips and Tricks — iMore](https://www.imore.com/stack-tips-and-tricks)
- [Stack Ketchapp Tips & Cheats — Level Winner](https://www.levelwinner.com/stack-ketchapp-tips-tricks-cheats-to-get-a-high-score/)
- [Stack Block Blast mechanics overview — Firefly Tech](https://thefireflytech.com/blogs/stack-block-blast-stacking-one-tap-mobile-game)
- [Stack Game — Coolmath Games (5-consecutive-perfects mechanic)](https://www.coolmathgames.com/0-stack-game)
- [Snake Game Mechanics Tutorial — MonoGame Docs](https://docs.monogame.net/articles/tutorials/building_2d_games/22_snake_game_mechanics/index.html)
- [How to Play Snake — Coolmath Games](https://www.coolmathgames.com/blog/how-to-play-snake-mastering-a-classic)
- [Psychology of Snake engagement loop — The Original Snake](https://theoriginalsnake.com/blog/psychology-of-snake)
- [Google Snake rules — kickthebuddy.app](https://kickthebuddy.app/blog/Snake-Game-Google)
- [Colorblind game design — Filament Games](https://www.filamentgames.com/blog/color-blindness-accessibility-in-video-games)
- [Colorblind friendly game design — Chris Fairfield](https://chrisfairfield.com/unlocking-colorblind-friendly-game-design/)
- [iOS Reduce Motion — Apple Support](https://support.apple.com/guide/iphone/reduce-onscreen-motion-iph0b691d3ed/ios)
- [Reducing Motion in SwiftUI — Use Your Loaf](https://useyourloaf.com/blog/reducing-motion-of-animations/)
- GameKit PROJECT.md (v1.5 Endless Arcade Primitive milestone scope)
- GameKit v1.5-BRIEF.md (brand guard, substrate spec, open decisions)
- GameKit CLAUDE.md §1 (no ads, no coins, no energy, no aggressive subscriptions — permanent exclusions)

---

*Feature research for: v1.5 Endless Arcade Primitive — Stack + Snake*
*Researched: 2026-06-25*
