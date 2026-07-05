---
phase: 17-snake
reviewed: 2026-07-05T03:43:15Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - Docs/releases/v1.4.md
  - gamekit/gamekit/Core/ArcadePalette.swift
  - gamekit/gamekit/Core/GameStats.swift
  - gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift
  - gamekit/gamekit/Games/Snake/SnakeConfig.swift
  - gamekit/gamekit/Games/Snake/SnakeEngine.swift
  - gamekit/gamekit/Games/Snake/SnakeGameView.swift
  - gamekit/gamekit/Games/Snake/SnakeGameView+Chrome.swift
  - gamekit/gamekit/Games/Snake/SnakeScoreChip.swift
  - gamekit/gamekit/Games/Snake/SnakeViewModel.swift
  - gamekit/gamekit/Games/Stack/StackPalette.swift
  - gamekit/gamekit/Screens/HomeView.swift
  - gamekit/gamekit/Screens/SnakeStatsCard.swift
  - gamekit/gamekit/Screens/StatsView.swift
  - gamekit/gamekitTests/Core/GameStatsTests.swift
  - gamekit/gamekitTests/Games/Snake/SnakeEngineTests.swift
  - gamekit/gamekitTests/Games/Snake/SnakeGameViewTests.swift
  - gamekit/gamekitTests/Games/Snake/SnakeViewModelTests.swift
findings:
  critical: 1
  warning: 5
  info: 9
  total: 15
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-07-05T03:43:15Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Reviewed the Phase 17 Snake implementation: pure engine, view model, canvas
renderer, chrome/lifecycle view, palette promotion (StackPalette →
ArcadePalette), stats wiring, and tests. The architecture is sound — the
engine is genuinely Foundation-only and deterministic, the fixed-timestep /
Gaffer-alpha split is correctly implemented, the direction-queue contract
(180° rejection, capacity-2, pop-on-cell-move) is correct and well-tested,
and token discipline is followed throughout (no hard-coded colors, all
`.foregroundStyle`).

Traced through the interpolation math, wrap handling, and lifecycle
transitions, I found one correctness bug in the Reduce Motion render path
(the display permanently lags the engine by one cell move), one lifecycle
race that can re-show the game-over banner over a fresh idle screen, and a
wrap-boundary render gap for the head's eye dots. Several maintainability
issues (raw "endless" serialization-key literals, stale comments,
config-coupling between view and VM) round out the findings.

## Critical Issues

### CR-01: Reduce Motion render path shows the snake one full cell move behind the engine

**File:** `gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift:81` (root cause), with the incorrect justification at lines 78–80 and 162–167
**Issue:** Under Reduce Motion, `alpha` is forced to `0.0`, and `segPos`
returns `prevBody[i]` at alpha 0 — the body snapshot **before** the most
recent cell move. The comment claims "prev == curr when alpha is 0", but
that is only true on frames where no cell move occurred. On every cell-move
frame, `prevBody != body`, so the RM display permanently renders the
*previous* position: the snake trails the engine state by exactly one cell
move (100–200 ms) for the entire run.

Observable consequences for Reduce Motion users:
- Food is drawn at the engine's food position (`SnakeBoardCanvas.swift:149`),
  which respawns on the eat frame — so the food visibly teleports away and
  the score rolls while the rendered head is still one cell short of it.
  The head never visually touches the food.
- On self-collision in tight turns, the rendered head can appear one cell
  away from the body cell it "hit" — deaths look unfair.

The engine state itself is correct; this is a render-mapping bug, but it
makes the accessibility path behave visibly wrong on every single move.
(Wall/self-death resting position happens to render correctly only because
the engine assigns `prevBody = body` before the early-return on death,
`SnakeEngine.swift:122`.)

**Fix:** The jump-cut should snap to the *current* position, not the
previous one:
```swift
// SNAKE-07: Reduce Motion → snap to the post-move position (jump-cut).
// alpha = 1.0 → segPos returns snakeBody[i], matching engine state exactly.
let alpha = reduceMotion ? 1.0 : cellMoveAlpha
```
Then update the stale comments at lines 78–80, 49, and 164 (and the prop
doc at line 57) which all assert the 0.0 behavior. Verify with an RM
device pass that eating and death now align with the rendered head.

## Warnings

### WR-01: Stale 500 ms pre-roll Task can re-show the game-over banner over a fresh idle screen

**File:** `gamekit/gamekit/Games/Snake/SnakeGameView.swift:126-140`
**Issue:** When `vm.state` becomes `.gameOver` with `fxEnabled`, an
unstructured `Task` sleeps 500 ms and then sets `showBanner = true`
unconditionally. If the state leaves `.gameOver` during that window, the
stale task still fires. Concrete path: die with score 0 → tap the toolbar
menu → "Wall mode" within 500 ms → `requestWallModeToggle()` sees
`engine.score == 0` → `applyWallModeToggle()` → `restart()` → state
`.idle`, `showBanner = false` — then the sleeping task wakes and shows the
"Game over / Restart" banner on top of the idle card of a brand-new game.
(With score > 0 the same race exists via a fast Abandon confirm.) The task
is never cancelled and doesn't re-check state.
**Fix:** Guard the state after the sleep (or hold and cancel the task):
```swift
Task {
    try? await Task.sleep(for: .milliseconds(500))
    guard vm.state == .gameOver else { return }
    withAnimation(.easeOut(duration: 0.3)) { showBanner = true }
}
```

### WR-02: Head eye dots streak across the entire board during a toroidal wrap

**File:** `gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift:143-144, 168-175`
**Issue:** The wrap-boundary guard (lines 111–113) correctly skips body
*segment strokes* spanning more than half the grid, but the head center for
the eye dots is computed with a plain lerp: `segPos(0, ...)`. On a wrap
move (e.g., col 19 → col 0), `prevBody[0]` and `snakeBody[0]` are on
opposite edges, so the eyes interpolate backwards across the full board
width over the 100–200 ms tick — a visible pair of dots sweeping across
the play field on every wrap. Compounding this, the head segment stroke is
skipped by the guard during that same tick, so during a wrap the only
visible "head" is the streaking eyes.
**Fix:** Apply the same half-grid jump detection in `segPos` (or just for
the head point): when `abs(curr.col - prev.col) > cols / 2` or
`abs(curr.row - prev.row) > rows / 2`, snap to `curr` instead of lerping:
```swift
private func segPos(_ i: Int, cellSize: CGFloat, alpha: Double) -> CGPoint {
    let curr = snakeBody[i]
    var prev = i < prevBody.count ? prevBody[i] : curr
    if abs(curr.col - prev.col) > cols / 2 || abs(curr.row - prev.row) > rows / 2 {
        prev = curr   // wrap move — snap, don't streak
    }
    ...
}
```

### WR-03: Directional input remains live during .gameOver and .paused — fires .selection haptics on a dead game

**File:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift:130-143` (and mount sites `SnakeGameView.swift:80-82, 213`)
**Issue:** `handleDirectionInput` only special-cases `.idle`; in
`.gameOver` (including the 500 ms pre-banner window and while the banner is
up — the D-pad stays visible below it) and `.paused`, taps and swipes still
route into `tryEnqueueDirection`, which accepts them, increments
`enqueueCount`, and fires the `.selection` haptic for input that has no
effect on anything. DESIGN §8 says haptics carry information; a confirmation
haptic for a no-op on a dead game is misinformation. (Queued directions
don't leak into the next run — `restart()`/`start()` clear the queue — so
this is feedback-integrity only.)
**Fix:** Gate enqueue on an active run:
```swift
func handleDirectionInput(_ dir: SnakeDirection) {
    if state == .idle { start() }
    guard state == .running else { return }
    tryEnqueueDirection(dir)
}
```

### WR-04: PERMANENT serialization key "endless" duplicated as raw string literals in 4 places

**Files:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift:185, 202, 219`; `gamekit/gamekit/Screens/SnakeStatsCard.swift:29`
**Issue:** The write path, two read paths, and the stats-card filter each
spell the D-12 data-break-locked key `"endless"` as an independent literal.
The codebase already established the fix for exactly this hazard —
`GameStats.stackEndlessMode` (`GameStats.swift:315`) — but Snake did not
follow it. A typo in any one site compiles cleanly and silently produces
a stats card that never shows a high score, or a high-score haptic that
fires every run. The comments saying "renaming = data break" make the
raw-literal duplication more dangerous, not less.
**Fix:** Add `static let snakeEndlessMode = "endless"` to the `GameStats`
extension (or a Snake-local constant) and use it at all four sites,
mirroring the Stack precedent.

### WR-05: Snake shipped-work appended to v1.4.md while §0.1 marks v1.4 as already shipped

**File:** `Docs/releases/v1.4.md:27, 30` (and `gamekit/gamekit.xcodeproj/project.pbxproj` `MARKETING_VERSION = 1.4`)
**Issue:** CLAUDE.md §0.1 states "v1.4 shipped — Word Games release"
(2026-06-22), and §0.3 states "never mutate a shipped version's file."
The Phase 17 Snake entries (lines 26–30) were appended to `v1.4.md`
because `MARKETING_VERSION` was never bumped after the v1.4 ship. Either
the version bump was missed (Snake work will ship as a new App Store
version and its notes belong in `v1.5.md`), or §0.1 is stale. As it
stands, the release log for a shipped version no longer matches what
shipped.
**Fix:** Bump `MARKETING_VERSION` to 1.5, create `Docs/releases/v1.5.md`
from the template, and move the Snake bullets (v1.4.md lines 26–30) there.
If v1.4 in fact has not shipped, update CLAUDE.md/AGENTS.md §0.1 instead
(per §8.13, in the same commit).

## Info

### IN-01: Stale header comment references a file that does not exist

**File:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift:9-10`
**Issue:** The header says persistence and wall-mode methods "live in
SnakeViewModel+Persistence.swift (Plan 17-03 Task 2)", but no such file
exists — both live in this file (lines 181–189, 234–264).
**Fix:** Delete or correct the comment.

### IN-02: Redundant `!reduceMotion` in the head-pulse guard

**File:** `gamekit/gamekit/Games/Snake/SnakeGameView.swift:143`
**Issue:** `guard fxEnabled && !reduceMotion` — `fxEnabled` is defined as
`animationsEnabled && !reduceMotion` (line 52), so the second condition is
dead.
**Fix:** `guard fxEnabled else { return }`.

### IN-03: Magic `+ 2` in starting-body placement; no validation against small grids

**File:** `gamekit/gamekit/Games/Snake/SnakeEngine.swift:89`
**Issue:** `col: cfg.startLength - 1 - i + 2` places the head at column
`startLength + 1` with an undocumented `+ 2` offset. If a config ever has
`startLength + 2 > cols` (the wall-collision test already runs cols = 5
with startLength 3, i.e. head at the last column), the head spawns out of
bounds with no assertion.
**Fix:** Name the offset (`let startColInset = 2`), document it, and clamp
or `assert(cfg.startLength + startColInset <= cfg.cols)`.

### IN-04: View hardcodes `SnakeConfig.default` grid dimensions instead of reading the VM's engine config

**File:** `gamekit/gamekit/Games/Snake/SnakeGameView.swift:204-205, 222`
**Issue:** `SnakeBoardCanvas` receives `cols: SnakeConfig.default.cols`,
but the VM builds its engine from a *copy* of `.default` (with wallMode
mutated). They agree today; if config ever varies per mode/difficulty, the
canvas coordinate mapping silently desyncs from the engine grid.
**Fix:** Expose `var cols: Int { engine.cfg.cols }` (and rows) on the VM
and pass those.

### IN-05: `var` RNG locals never mutated in engine tests — compiler warnings

**File:** `gamekit/gamekitTests/Games/Snake/SnakeEngineTests.swift:29-30, 86, 106, 140, 169`
**Issue:** `var rng1 = SeededGenerator(...)` etc. are passed by value into
`SnakeEngine.init` and never mutated locally, producing "variable was never
mutated; consider changing to 'let'" warnings on every test.
**Fix:** Change to `let`.

### IN-06: First food of a first-ever run fires the "new high score" haptic

**File:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift:171-174`
**Issue:** With no persisted best, `bestScoreAtStart == 0`, so score 1
satisfies `score > bestScoreAtStart` and the D-09 medium-impact haptic
fires on the very first food eaten (also after every stats reset).
Technically it *is* a high score, but on the first-ever run every food
milestone is one; confirm this matches the intended D-09 feel.
**Fix (if unintended):** require `bestScoreAtStart > 0` for the crossing.

### IN-07: Board-full spawnFood leaves food co-located with the head; no win state

**File:** `gamekit/gamekit/Games/Snake/SnakeEngine.swift:175`
**Issue:** When the snake fills the board, `spawnFood()` silently returns,
leaving `food` equal to the just-eaten cell (now the head). The comment
acknowledges the "rare win state" but nothing surfaces it — the run ends
only via the inevitable self-collision. Acceptable for v1 scope, but the
food renders inside the head for that final stretch.
**Fix:** Optional — treat empty candidates as a terminal win/perfect state,
or at minimum skip drawing food when it collides with the body.

### IN-08: v1.4.md structural drift — duplicated "User-facing changes" section

**File:** `Docs/releases/v1.4.md:26`
**Issue:** `## User-facing changes (cont.)` is a second copy of an earlier
section header rather than an entry appended under the existing section
(§0.3 says append under the appropriate section). Subsumed by WR-05 if the
Snake bullets move to v1.5.md; otherwise merge into the original section.
**Fix:** Fold line 27 under the existing `## User-facing changes`.

### IN-09: "snake.wallMode" UserDefaults key literal duplicated

**File:** `gamekit/gamekit/Games/Snake/SnakeViewModel.swift:70, 262`
**Issue:** The PERMANENT key `"snake.wallMode"` is spelled twice (read in
`init`, write in `applyWallModeToggle`). Same typo-risk class as WR-04,
smaller blast radius.
**Fix:** `private static let wallModeKey = "snake.wallMode"`, use at both
sites.

---

_Reviewed: 2026-07-05T03:43:15Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
