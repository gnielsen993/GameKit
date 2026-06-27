---
phase: 15-arcade-substrate-skeleton
plan: "04"
subsystem: routing / catalog / documentation
tags: [gameroute, gamedescriptor, homeroute, adr, arcade, video-mode-exemption]
dependency_graph:
  requires: [15-02, 15-03]
  provides:
    - "GameRoute.stack / GameRoute.snake (plain cases, no associated value)"
    - "AccentRole.slot9 / slot10 with locked index entries 8/9"
    - "GameDescriptor.all Stack + Snake entries (captionKey 'Tap to play', modes: [])"
    - "HomeView.destination(for:) routing .stack → StackHarnessView, .snake → SnakeHarnessView"
    - "15-VIDEO-MODE-ADR.md — ARCADE-08 exemption ADR committed"
  affects:
    - "Core/GameRoute.swift"
    - "Core/GameDescriptor.swift"
    - "Screens/HomeView.swift"
    - ".planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md"
tech_stack:
  added: []
  patterns:
    - "Plain (no associated value) GameRoute cases for endless games with modes: []"
    - "AccentRole slot extension pattern — append slot N + index N-1 to AccentRole enum"
    - "GameDescriptor.all entry with modes: [] for direct-launch games (no mode-chip sub-menu)"
    - "HomeView destination routing with klondike precedent: only .disableInteractivePop(), no .videoModeAware()"
    - "ADR written in the phase where the code decision physically lands (D-11 pull-earlier)"
key_files:
  created:
    - .planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md
  modified:
    - gamekit/gamekit/Core/GameRoute.swift
    - gamekit/gamekit/Core/GameDescriptor.swift
    - gamekit/gamekit/Screens/HomeView.swift
decisions:
  - "D-09 honored: .stack and .snake GameRoute cases are plain (no associated value) — modes: [] in descriptor means no mode chip ever provides a parameter"
  - "D-06 honored: captionKey is 'Tap to play' (not 'Coming soon') — descriptor written once in final state"
  - "D-10/D-11 honored: ADR committed in Phase 15 where code decision physically lands; Phase 18 only references/closes"
  - "Klondike precedent confirmed as the exact pattern for VideoMode exemption: only .disableInteractivePop(), no .videoModeAware()"
  - "Symbols locked: square.stack.fill (Stack) and arrow.triangle.turn.up.right.diamond (Snake) — valid SF Symbols iOS 17"
metrics:
  duration_minutes: 5
  completed_date: "2026-06-27"
  tasks_completed: 3
  files_modified: 3
  files_created: 1
---

# Phase 15 Plan 04: Home Tile Wiring + Video Mode ADR Summary

**One-liner:** Wired Stack and Snake as enabled Home tiles routing to their harness views via plain GameRoute cases, with AccentRole slot9/slot10 descriptors carrying 'Tap to play' captions and no mode chips — and committed the ARCADE-08 Video Mode exemption ADR documenting why real-time games omit .videoModeAware().

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-27T02:42:00Z
- **Completed:** 2026-06-27T02:47:00Z
- **Tasks:** 3
- **Files created:** 1 (15-VIDEO-MODE-ADR.md)
- **Files modified:** 3 (GameRoute.swift, GameDescriptor.swift, HomeView.swift)

## Accomplishments

### Task 1: GameRoute cases + HomeView destination routing (commit 54b9d31)

- Added `case stack` and `case snake` as **plain** (no associated value) cases to `GameRoute` after `.wordGrid`
- Added `case .stack:` and `case .snake:` to `HomeView.destination(for:)` exhaustive switch, each routing to `StackHarnessView()` / `SnakeHarnessView()` with only `.disableInteractivePop()`
- No `.videoModeAware()` applied — klondike precedent upheld; ADR comment added at the code site pointing to 15-VIDEO-MODE-ADR.md
- Clean build, zero strict-concurrency warnings; exhaustive switch remains green

### Task 2: AccentRole slot9/slot10 + GameDescriptor entries (commit 582be05)

- `AccentRole` gains `case slot9` (index 8) and `case slot10` (index 9)
- `GameDescriptor.all` gains two enabled entries:
  - Stack: `kind: .stack`, `captionKey: "Tap to play"`, `symbol: "square.stack.fill"`, `accent: .slot9`, `route: .stack`, `modes: []`, `shortMeta: "Endless tower"`
  - Snake: `kind: .snake`, `captionKey: "Tap to play"`, `symbol: "arrow.triangle.turn.up.right.diamond"`, `accent: .slot10`, `route: .snake`, `modes: []`, `shortMeta: "Endless grid"`
- D-06 (final caption, never "Coming soon") confirmed by grep
- D-09 (modes: [], direct launch) honored — no mode-chip sub-menu for endless games
- Clean build; two new enabled tiles appear on Home

### Task 3: Video Mode exemption ADR (commit c6a7cf8)

- Created `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md`
- Status: "Accepted — 2026-06-26", Satisfies: ARCADE-08
- Decision section names `.videoModeAware()` and `destination(for:)` explicitly
- Klondike precedent documented (existing game that already omits Video Mode)
- Rationale: real-time games cannot tolerate mid-play layout reflow — engine desync
- Future path documented: SUSPEND-on-PiP (out of scope v1.5)
- D-11 noted: ARCADE-08 doc deliverable pulled into Phase 15; Phase 18 closes it

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | GameRoute + HomeView routing | 54b9d31 | GameRoute.swift, HomeView.swift |
| 2 | AccentRole + GameDescriptor | 582be05 | GameDescriptor.swift |
| 3 | Video Mode exemption ADR | c6a7cf8 | 15-VIDEO-MODE-ADR.md |

## Deviations from Plan

None — plan executed exactly as written. All three tasks completed on the first attempt with clean builds at each step. The klondike precedent was exactly as described at HomeView lines 355–357.

## Success Criteria

- [x] `Core/GameRoute.swift` contains `case stack` and `case snake` with no parentheses/associated value
- [x] `Screens/HomeView.swift` `destination(for:)` contains `case .stack:` → `StackHarnessView()` and `case .snake:` → `SnakeHarnessView()`, each with `.disableInteractivePop()` and without `.videoModeAware()`
- [x] `Core/GameDescriptor.swift` contains `case slot9`, `case slot10`, their index entries, and two `.all` entries with `captionKey: "Tap to play"` and `modes: []`
- [x] No `captionKey: "Coming soon"` anywhere in GameDescriptor.swift
- [x] `15-VIDEO-MODE-ADR.md` exists, contains "ARCADE-08", "Accepted", and "klondike"
- [x] Clean build, zero strict-concurrency warnings across all three file modifications
- [x] ARCADE-09 completed (enabled tiles navigate to placeholder screens)
- [x] ARCADE-08 documentation deliverable satisfied in Phase 15 (D-11)

## Known Stubs

None introduced in this plan. The Stack/Snake tiles route to `StackHarnessView` and `SnakeHarnessView` — both are intentional throwaway harnesses from Plan 02 that prove the arcade substrate end-to-end. They are not stubs of this plan's work; they are the Plan 02 deliverable that this plan wires in.

## Threat Flags

None — no new network/auth/persistence surface introduced. Routing and catalog data are app-internal, static, and trusted. STRIDE T-15-04 (Video Mode exemption) accepted per plan: Stack/Snake omit `.videoModeAware()`, so no PiP overlay surface is exposed for these games — the exemption bounds rather than expands the surface.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| gamekit/gamekit/Core/GameRoute.swift | FOUND — contains `case stack`, `case snake` (plain) |
| gamekit/gamekit/Core/GameDescriptor.swift | FOUND — contains `case slot9`, `case slot10`, `kind: .stack`, `kind: .snake` |
| gamekit/gamekit/Screens/HomeView.swift | FOUND — contains `StackHarnessView()`, `SnakeHarnessView()`, no videoModeAware on those cases |
| .planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md | FOUND — contains ARCADE-08, Accepted, klondike |
| commit 54b9d31 (Task 1) | VERIFIED |
| commit 582be05 (Task 2) | VERIFIED |
| commit c6a7cf8 (Task 3) | VERIFIED |
| Build succeeded | CONFIRMED (zero errors, zero strict-concurrency warnings) |
| No `captionKey: "Coming soon"` | CONFIRMED |
| No `.videoModeAware()` on .stack or .snake | CONFIRMED |

---
*Phase: 15-arcade-substrate-skeleton*
*Completed: 2026-06-27*
