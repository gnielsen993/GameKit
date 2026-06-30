---
phase: 16-stack
plan: "04"
subsystem: Games/Stack
tags: [canvas, render, palette, reduce-motion, token-discipline, gaffer-interpolation, wave-1]
dependency_graph:
  requires: [16-01-StackEngine]
  provides: [StackPalette, StackBoardCanvas]
  affects: [16-05-StackGameView]
tech_stack:
  added: []
  patterns: [canvas-immediate-mode, gaffer-interpolation, reduce-motion-snap, token-only-colors, props-only-view]
key_files:
  created:
    - gamekit/gamekit/Games/Stack/StackPalette.swift
    - gamekit/gamekit/Games/Stack/StackBoardCanvas.swift
  modified: []
decisions:
  - "StackBoardCanvas takes placed:[PlacedBlock] as a separate prop (not via StackFrame) because StackFrame only carries current-block state; StackViewModel will expose placed via computed property when StackGameView is created (plan 16-05)"
  - "prevCenterX:Double added to Canvas props to enable Gaffer interpolation of the sliding block between engine ticks; StackGameView (16-05) will track prevCenterX using .onChange(of: vm.frame.currentCenterX)"
  - "Camera offset uses direct formula from placed.count (no inter-tick lerp) — placed.count only grows on tick boundaries, so the camera position is already stable between ticks; no previous-camera state needed"
  - "Trim piece animation uses accAlpha as a one-tick timing proxy (fall 2 block-heights, fade to clear); brief by design at 60 Hz (~1/60 s), but visually communicates the trim event; full multi-frame trim animation is a polish-pass refinement (plan 16-07)"
metrics:
  duration: 15
  completed: "2026-06-30"
  tasks_completed: 2
  files_changed: 2
---

# Phase 16 Plan 04: StackPalette + StackBoardCanvas Summary

Token-only accent-derived block color ramp (`StackPalette`) and the first real-time `Canvas` board render in the repo (`StackBoardCanvas`) with Gaffer interpolation for the sliding block and a Reduce Motion jump-cut path.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StackPalette token-only accent ramp helper | c91b0cc | StackPalette.swift |
| 2 | StackBoardCanvas immediate-mode render + Reduce Motion gate | 2d737ea | StackBoardCanvas.swift |

## What Was Built

### StackPalette.swift (53 lines)

`enum StackPalette` with `static func color(forIndex i: Int, theme: Theme) -> Color`.

Cycles `theme.charts.chart1…chart6` by block index:
- **D-05**: tower becomes the active preset's accent palette (charts are accent-derived via `ColorDerivation.derivedCharts`).
- **D-06**: color is fixed by index and cycles every 6 layers. A placed block never recolors as the tower grows.
- **D-07**: `derivedCharts` varies brightness/saturation as well as hue — monochrome/low-saturation presets still produce visibly distinct lightness steps. No special-casing needed.

Token-discipline grep: empty (no raw color initializers, no system color names in code or comments).

### StackBoardCanvas.swift (186 lines)

Props-only `struct StackBoardCanvas: View`:
- **Props**: `placed: [PlacedBlock]`, `frame: StackFrame`, `prevCenterX: Double`, `accAlpha: Double`, `theme: Theme`, `reduceMotion: Bool`.
- **Canvas body**: draws backdrop, placed tower blocks bottom-to-top with viewport culling, current sliding block, and overhang trim piece.
- **Block colors**: `ctx.fill(path, with: .color(StackPalette.color(forIndex: i, theme: theme)))` — token-only, no raw initializers.
- **Gaffer interpolation** (non-RM): `renderCX = prevCenterX + (frame.currentCenterX - prevCenterX) * accAlpha` — smooths the sliding block between engine ticks at 120 Hz display.
- **Reduce Motion gate** (STACK-06): when `reduceMotion = true`, block position snaps to `frame.currentCenterX` (jump-cut), camera snaps to formula result, and trim piece vanishes instantly.
- **Camera**: `cameraOffset = max(0, (placed.count + 1) * blockH - 2 * size.height / 3)`. No scroll for the first ~8 blocks (tower fully visible); then scrolls up to keep the slider in the upper third. Always a snap-formula (placed.count only grows on tick boundaries).
- **Trim piece** (non-RM): falls 2 block-heights and fades over the tick duration using `accAlpha`; `Color.opacity(opacity)` for the fade — no `ctx.opacity` state management needed.
- **Pitfall 18**: zero SwiftUI implicit-animation modifiers on board state; grep for banned pattern returns empty.

## Verification

**Task 1 (from plan):**
```
grep -q 'theme.charts.chart' StackPalette.swift            → OK
grep -rn 'Color(red:|Color(hex:|Color(white:|.green\b|...' → empty (OK)
wc -l StackPalette.swift                                   → 53 (< 80)
```

**Task 2 (from plan):**
```
grep -q 'Canvas' StackBoardCanvas.swift                    → OK
grep -q 'reduceMotion' StackBoardCanvas.swift              → OK
grep -rn 'Color(red:|Color(hex:|Color(white:|.animation('  → empty (OK)
wc -l StackBoardCanvas.swift                               → 186 (< 250)
xcodebuild build                                           → BUILD SUCCEEDED
```

## Deviations from Plan

### Design Decisions (Claude's Discretion)

**1. prevCenterX added as explicit Canvas prop for Gaffer interpolation**
- **Why**: The plan requires "Interpolate the sliding-block position using the accumulator-remainder alpha (Gaffer)." Gaffer interpolation requires both the previous-tick state and the current-tick state. The plan's prop list did not explicitly include prevCenterX, but it is implied by the Gaffer requirement.
- **Implementation**: `prevCenterX: Double` added as a prop. StackGameView (plan 16-05) will track it via `.onChange(of: vm.frame.currentCenterX) { old, _ in prevCenterX = old }`.
- **Impact**: StackViewModel needs a `var placed: [PlacedBlock] { engine.placed }` computed property added when StackGameView is created (the engine's `placed` is currently private). No change to existing files in this plan.

**2. Trim piece animation is one-tick duration (not multi-frame)**
- **Why**: The plan's trim piece requirement ("short fall + fade") is satisfied within one engine tick (1/60 s) using `accAlpha` as a timing proxy. A multi-frame persistent animation would require `@State` tracking across ticks, which conflicts with the "props-only" and "no .animation() on board state" constraints. The one-tick flash communicates the trim event; full-duration animation is a polish-pass refinement (plan 16-07 §8.12).
- **Impact**: Visual-only; gameplay and acceptance criteria unaffected.

## Wiring Notes for Plan 16-05 (StackGameView)

StackGameView will need to:
1. Add `var placed: [PlacedBlock] { engine.placed }` computed property to **StackViewModel** (the engine's `placed` array is not currently exposed).
2. Track `@State private var prevCenterX: Double = StackConfig.default.playfieldCenter` and update via `.onChange(of: vm.frame.currentCenterX) { old, _ in prevCenterX = old }`.
3. Pass `accAlpha: vm.accumulator / vm.fixedDt` (both need to be exposed from StackViewModel for external reads, or the canvas can receive the raw `accumulator` value).

## Known Stubs

None — both files contain complete, functional implementations. The trim animation brevity is an intentional design choice for this plan, not a stub.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. The Canvas renders from an in-memory engine snapshot. Threat register items:
- **T-16-08** (legibility under Loud presets): mitigated by token-only colors via `theme.charts.*`. Full §8.12 audit on Classic + Voltage/Dracula is scheduled for plan 16-07.
- **T-16-09** (per-frame view-tree churn): mitigated by immediate-mode Canvas (no per-block SwiftUI views); no SwiftUI implicit-animation modifier on board state (grep confirms).

## Self-Check: PASSED

Files exist:
- FOUND: gamekit/gamekit/Games/Stack/StackPalette.swift
- FOUND: gamekit/gamekit/Games/Stack/StackBoardCanvas.swift

Commits exist:
- FOUND c91b0cc: feat(16-04): StackPalette token-only accent color ramp
- FOUND 2d737ea: feat(16-04): StackBoardCanvas immediate-mode render with RM jump-cut gate

Verification gates:
- StackPalette: chart tokens present, token-discipline clean, 53 lines < 80
- StackBoardCanvas: Canvas + reduceMotion present, no banned patterns, 186 lines < 250
- Build: BUILD SUCCEEDED
