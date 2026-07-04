---
phase: 17-snake
plan: "04"
subsystem: snake-rendering
tags: [canvas, rendering, snake, gaffer-interpolation, reduce-motion, arcade-palette]
dependency_graph:
  requires: ["17-01 (SnakeEngine — SnakeCell/SnakeDirection/SnakeFrame types)", "17-02 (ArcadePalette.layer)"]
  provides: ["SnakeBoardCanvas — props-only Canvas consuming engine snapshot"]
  affects: ["17-05 (SnakeGameView wires SnakeBoardCanvas)"]
tech_stack:
  added: []
  patterns:
    - "Props-only Canvas (no @State/@Environment) — analog to StackBoardCanvas"
    - "ArcadePalette.layer(forIndex:theme:) for head-to-tail body gradient"
    - "Gaffer interpolation: alpha = reduceMotion ? 0.0 : cellMoveAlpha"
    - "Wrap-boundary skip-stroke: colJump/rowJump > grid/2 guard"
    - "headPulse prop scales head lineWidth for D-08 eat animation"
key_files:
  created:
    - gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift
  modified: []
decisions:
  - "Renamed body prop to snakeBody to avoid Swift naming conflict with SwiftUI View.body (Rule 1 auto-fix)"
  - "Drew body segments tail-to-head (stride down) so head paints last / on top"
  - "Used theme.colors.success for food (per plan spec; §8.12 audit in Plan 17-05 checkpoint)"
  - "drawEyes as private instance method following StackBoardCanvas.drawShadedBox pattern"
metrics:
  duration_seconds: 421
  completed_date: "2026-07-04"
  tasks_completed: 2
  files_changed: 1
---

# Phase 17 Plan 04: SnakeBoardCanvas Summary

SnakeBoardCanvas drawn from scratch as a direct analog of StackBoardCanvas — a props-only `Canvas` view that reads engine snapshot state and renders the Snake board with DesignKit tokens only.

## What Was Built

**`gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift`** (210 lines)

Props-only Canvas implementing all visual requirements for Plan 17-04:

- **Board well (D-03):** 1pt `theme.colors.border` stroke on a `RoundedRectangle(cornerRadius: theme.radii.card)`. Flat, no sheen, no grid lines — per DESIGN.md §3.0.
- **Body gradient (D-01/D-02):** Per-segment sub-paths stroked tail-to-head (head paints last = on top). Each segment uses `ArcadePalette.layer(forIndex: i, theme:)` where i=0 = head/most-saturated (`chart1`). The `layer.next` overlay at `layer.blend` opacity produces the smooth head-to-tail gradient using token-only colors.
- **Head eye dots (D-01):** Two `theme.colors.background` circles offset `forward + ±lateral` toward `currentDirection`. Drawn after body segments so they're never obscured.
- **Food circle:** Filled circle in `theme.colors.success`. Shape (circle) and color contrast with the body stroke for legibility on all presets.
- **Gaffer interpolation (D-04 / SNAKE-07):** `let alpha = reduceMotion ? 0.0 : cellMoveAlpha`. `segPos(_:cellSize:alpha:)` lerps `prevBody[i] → snakeBody[i]` at alpha. Under Reduce Motion alpha is 0.0 — every segment snaps to its cell center, producing the jump-cut teleport.
- **D-08 head pulse:** `headPulse: Double` prop scales the head segment's `lineWidth` by `1.0 + 0.25 * headPulse`. The parent (Plan 17-05) animates this 1→0 over ~150ms on `eatCount` change, gated by `fxEnabled`. Stays 0 when `!fxEnabled` or `reduceMotion`.
- **Wrap-boundary guard (Pitfall 1):** In the body loop, any segment pair where `abs(col_a - col_b) > cols/2` OR `abs(row_a - row_b) > rows/2` is skipped with `continue`. Rounded caps at each endpoint provide the clean edge exit/re-entry cue.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SnakeBoardCanvas — board well, body path, head eyes, food, Gaffer lerp | 2547f9e | SnakeBoardCanvas.swift (new, 210 lines) |
| 2 | Wrap-boundary guard + build verify | (no new commit — guard co-implemented in Task 1; BUILD SUCCEEDED verified) | — |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `body` prop renamed to `snakeBody`**
- **Found during:** Task 1 implementation
- **Issue:** Plan spec named the snake body prop `body: [SnakeCell]`, but SwiftUI's `View` protocol requires `var body: some View` as a computed property. Having both would be an "invalid redeclaration of 'body'" compile error in Swift.
- **Fix:** Renamed the stored property to `snakeBody: [SnakeCell]`. All internal references updated. The public interface matches conceptually; callers (Plan 17-05 SnakeGameView) will use `snakeBody:` when constructing the view.
- **Files modified:** `SnakeBoardCanvas.swift`
- **Commit:** 2547f9e

**2. [Rule 1 - Bug] Comment text reworded to pass token-discipline grep**
- **Found during:** Task 1 verification
- **Issue:** The file header comment contained the strings `Color(red:)` and `Color(hex:)` as documentation of what NOT to use. The automated token-discipline grep (`grep -Ec "Color\(red:|Color\(hex:|..."`) matched these comment lines, causing `TOKENS_OK` check to fail and would also trip the pre-commit hook.
- **Fix:** Reworded the comment to "No raw color initializers or system color names" (equivalent meaning, no false-positive pattern match).
- **Files modified:** `SnakeBoardCanvas.swift`
- **Commit:** 2547f9e (same commit)

## Verification Passed

- `struct SnakeBoardCanvas` present: YES
- `ArcadePalette.layer` present: YES
- Token-discipline grep (`TOKENS_OK`): PASSED
- `reduceMotion ? 0.0 : cellMoveAlpha` alpha gate: present at line 81
- `headPulse: Double` prop scales head lineWidth: present at lines 70, 127
- Wrap-boundary guard (`cols / 2`): present at line 113
- File line count: 210 (cap: 400)
- `xcodebuild build -scheme gamekit`: **BUILD SUCCEEDED**

## Pending (Plan 17-05)

- Visual §8.12 legibility audit (Classic + Loud/Moody presets) — requires SnakeGameView to mount the canvas
- Reduce Motion jump-cut functional verification — requires game loop wired in Plan 17-05
- `headPulse` animation wiring (parent animates 1→0 on `eatCount` change)
- `theme.colors.success` food token §8.12 contrast verification (open question in plan)

## Known Stubs

None — SnakeBoardCanvas is a complete, self-contained Canvas renderer. It is not yet mounted in a view (that is Plan 17-05's work), but all rendering logic is fully implemented.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| `gamekit/gamekit/Games/Snake/SnakeBoardCanvas.swift` exists | FOUND |
| `.planning/phases/17-snake/17-04-SUMMARY.md` exists | FOUND |
| Commit `2547f9e` exists in git log | FOUND |
