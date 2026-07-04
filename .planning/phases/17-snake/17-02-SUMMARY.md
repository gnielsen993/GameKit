---
phase: 17-snake
plan: "02"
subsystem: Core/ArcadePalette
tags: [refactor, palette, token-discipline, stack, snake]
dependency_graph:
  requires: [17-01]
  provides: [Core/ArcadePalette.swift, StackPalette-shim]
  affects: [17-04-SnakeBoardCanvas]
tech_stack:
  added: []
  patterns: [typealias-forwarding-shim, two-game-promotion]
key_files:
  created:
    - gamekit/gamekit/Core/ArcadePalette.swift
  modified:
    - gamekit/gamekit/Games/Stack/StackPalette.swift
decisions:
  - "segmentsPerStop replaces blocksPerStop as canonical name; blocksPerStop kept as alias for Stack backward-compat"
  - "typealias StackPalette = ArcadePalette chosen over wrapper struct — zero call-site diff, shim is 3 lines"
  - "Index contract documented: forIndex:0 = chart1 (head/most-saturated); Plan 04 inherits this direction"
metrics:
  duration_seconds: 180
  completed_date: "2026-07-04"
  tasks_completed: 2
  files_changed: 2
---

# Phase 17 Plan 02: ArcadePalette Promotion Summary

**One-liner:** Promoted StackPalette's accent-derived color ramp to `Core/ArcadePalette` as a shared arcade palette consumed by Stack (via typealias shim) and Snake (Plan 04 direct import).

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Extract ArcadePalette to Core/ and forward StackPalette | ef67022 | Core/ArcadePalette.swift (new), Games/Stack/StackPalette.swift (shim) |
| 2 | Build-verify Stack regression + Snake body-ramp index mapping | ef67022 | No new files — build verification only |

## What Was Built

`Core/ArcadePalette.swift` — promoted verbatim from `StackPalette`, with:
- `segmentsPerStop = 4` (renamed from `blocksPerStop`; covers both Stack tower layers and Snake body segments)
- `static var blocksPerStop: Int { segmentsPerStop }` alias preserving all Stack call sites
- Full index contract comment: `forIndex: 0` maps to `chart1` (head/most-saturated end of ramp)
- Zero raw color initializers — 100% DesignKit chart tokens

`Games/Stack/StackPalette.swift` — converted to a 3-line forwarding shim:
```swift
typealias StackPalette = ArcadePalette
```
No Stack call site was modified. `StackPalette.layer(forIndex:theme:)`, `StackPalette.Layer`, and `StackPalette.blocksPerStop` all resolve through the typealias unchanged.

## Verification Results

```
PALETTE_OK                         (grep checks passed)
** BUILD SUCCEEDED **              (full app target with Stack compiling through shim)
```

- `grep -q "enum ArcadePalette"` → PASS
- `grep -q "ArcadePalette"` in StackPalette.swift → PASS
- `grep -Ec "Color(red:|Color(hex:"` in ArcadePalette.swift → 0 (PASS)
- No `project.pbxproj` change in `git status` → PASS (auto-registered by PBXFileSystemSynchronizedRootGroup per CLAUDE.md §8.8)

## Deviations from Plan

None — plan executed exactly as written. Index contract documentation was included in Task 1's doc comment (ArcadePalette.swift) rather than requiring a separate edit in Task 2; both tasks committed as ef67022 since Task 2 produced no file changes.

## Known Stubs

None.

## Threat Surface Scan

No new trust boundaries introduced. This plan moves a pure token-derivation function between files; no input handling, persistence, or network surface was added. T-17-03 (Stack regression via promotion) mitigated by forwarding shim + BUILD SUCCEEDED confirmation.

## Self-Check: PASSED

- `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/Core/ArcadePalette.swift` — FOUND
- `/Users/gabrielnielsen/Desktop/GameKit/gamekit/gamekit/Games/Stack/StackPalette.swift` — FOUND (shim)
- Commit ef67022 — FOUND
