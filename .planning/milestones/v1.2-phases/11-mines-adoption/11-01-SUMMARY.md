---
phase: 11-mines-adoption
plan: 01
subsystem: ui
tags: [minesweeper, refactor, chip-extraction, video-mode, swiftui, timelineview]

# Dependency graph
requires:
  - phase: 03-minesweeper-mvp
    provides: MinesweeperHeaderBar + Phase 3 D-05 timer-freeze invariant (.distantPast anchor)
  - phase: 09-video-mode-foundation
    provides: VideoCompactControlRow contract (5-slot, slot 2 will host the chip stack)
  - phase: 10-layout-primitives
    provides: D-15 untouched contract (chip extraction does not touch BoardView / MagnifyGesture)
provides:
  - MinesRemainingChip — props-only chip subview (single source of truth for mine-counter rendering)
  - TimerChip — props-only chip subview preserving Phase 3 D-05 TimelineView/.distantPast freeze invariant
  - MinesweeperHeaderBar as a thin composer (35 lines, byte-identical init signature)
affects: [11-04, 11-05, 12-merge-adoption, 12-nonogram-adoption]

# Tech tracking
tech-stack:
  added: []  # zero net-new dependencies — extraction-only refactor
  patterns:
    - "Chip extraction with shared rendering surface (HeaderBar + future compact-row slot 2)"
    - "Props-only sibling-file extraction preserving Phase 3 D-05 timer invariants verbatim"

key-files:
  created:
    - gamekit/gamekit/Games/Minesweeper/MinesRemainingChip.swift
    - gamekit/gamekit/Games/Minesweeper/TimerChip.swift
  modified:
    - gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift

key-decisions:
  - "Working names MinesRemainingChip + TimerChip locked (CONTEXT Discretion accepted)."
  - "Doc-comment in HeaderBar trimmed to keep file ≤ 40 lines per Task 2 acceptance criterion; D-05 invariants now documented inside TimerChip.swift where they are actually enforced."

patterns-established:
  - "Sibling-file chip extraction: subview owns its tokens / a11y / formatting helpers and is shared between HeaderBar (non-Video / Small zones) and Plan 11-04's compact-row slot-2 stack (Large zones)."
  - "Doc-comment locality: the file that owns the invariant carries the doc-comment; consumers reference it. Reduces drift risk when invariants change."

requirements-completed: [VIDEO-07]

# Metrics
duration: 3min
completed: 2026-05-13
---

# Phase 11 Plan 01: Minesweeper Chip Extraction Summary

**Extracted MinesRemainingChip + TimerChip as props-only sibling subviews from MinesweeperHeaderBar; HeaderBar shrinks 133 → 35 lines while preserving its public init signature and the Phase 3 D-05 TimelineView/.distantPast timer-freeze invariant verbatim.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-13T23:17:39Z
- **Completed:** 2026-05-13T23:20:39Z (approx)
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 refactored)

## Accomplishments

- `MinesRemainingChip.swift` (50 lines) — props-only chip surface; `theme` + `minesRemaining` in, view tree out. Owns `formatCounter(_:)` (3-digit zero-pad for ≥0, leading-minus for <0) and the `"\(value) mines remaining"` a11y label.
- `TimerChip.swift` (77 lines) — props-only timer surface; `theme` + `timerAnchor` + `pausedElapsed` in, ticking view tree out. Carries the verbatim Phase 3 D-05 `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))` construction plus `displayedElapsed(at:)`, `formatElapsed(_:)`, and `formatElapsedSpoken(_:)` helpers.
- `MinesweeperHeaderBar.swift` (35 lines) — thin composer: `HStack { MinesRemainingChip ; Spacer() ; TimerChip }` with the existing `theme.spacing.s` inter-item gap + `theme.spacing.m`/`theme.spacing.s` outer padding. All 6 prior helpers (`counterChip`, `timerChip`, `formatCounter`, `displayedElapsed`, `formatElapsed`, `formatElapsedSpoken`) deleted — they now live inside the chip files.
- Public init signature of `MinesweeperHeaderBar` is byte-identical (`theme`, `minesRemaining`, `timerAnchor`, `pausedElapsed` in same order with same types) — `MinesweeperGameView.swift` lines 82-87 call site compiles unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MinesRemainingChip + TimerChip sibling files** — `531ca8c` (feat)
2. **Task 2: Refactor MinesweeperHeaderBar to consume extracted chips** — `b6f494e` (refactor)

## Files Created/Modified

- `gamekit/gamekit/Games/Minesweeper/MinesRemainingChip.swift` — NEW (50 lines). Mine-counter chip subview. Props: `theme: Theme`, `minesRemaining: Int`.
- `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` — NEW (77 lines). Elapsed-timer chip subview with TimelineView. Props: `theme: Theme`, `timerAnchor: Date?`, `pausedElapsed: TimeInterval`.
- `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` — MODIFIED (133 → 35 lines, net -98). Now a thin composer of the two new chip subviews; identical public init signature.

## Line-count Deltas

| File | Before | After | Delta |
|------|--------|-------|-------|
| `MinesRemainingChip.swift` | 0 | 50 | +50 |
| `TimerChip.swift` | 0 | 77 | +77 |
| `MinesweeperHeaderBar.swift` | 133 | 35 | -98 |
| **Total** | **133** | **162** | **+29** |

The net +29 line growth is the duplicated boilerplate of two structs (header comments + imports + struct decl) — the chip-rendering bytes themselves are not duplicated. This is the expected cost of the single-source-of-truth pattern; the win is that Plan 11-04 can now reference these chips from inside `VideoCompactControlRow`'s slot 2 stack without copy-pasting the chip body.

## Decisions Made

- **Working names accepted (CONTEXT Discretion).** `MinesRemainingChip` and `TimerChip` from the PATTERNS template are kept verbatim. No alternative names considered — they describe the chips exactly and Plan 11-04 will reference them by these names.
- **HeaderBar doc-comment trimmed to satisfy the ≤ 40 line Task 2 criterion.** Initial post-refactor file was 46 lines because I preserved the full original Phase 3 D-05 invariants doc-comment block. Since those invariants now live inside `TimerChip.swift` (where they are actually enforced), the HeaderBar header was compressed to a 14-line summary plus a backlink to TimerChip. Doc-comment locality reduces drift risk and the final file is 35 lines.

## Deviations from Plan

None — plan executed exactly as written. Both tasks completed in their planned order. No auto-fixes triggered (Rules 1–4 dormant). No architectural changes. No auth gates.

The HeaderBar doc-comment trim described above is not a deviation — the PATTERNS template explicitly allowed the comment to be edited if needed to satisfy file-size criteria.

## Issues Encountered

- **Pre-existing xcstrings drift observed (out of scope).** `gamekit/gamekit/Resources/Localizable.xcstrings` had 3 unrelated key stubs (`"2048 · Classic"`, `"Drawer open. Tap a mode to play, or tap again to close."`, `"Infinite · Endless"`) modified before this plan started. These are leftover from an earlier session, not introduced by Plan 11-01. Logged in `.planning/phases/11-mines-adoption/deferred-items.md` per executor scope-boundary rules; left unstaged.

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — **BUILD SUCCEEDED** (both after Task 1 and after Task 2).
- `xcodebuild test -only-testing:gamekitTests/MinesweeperViewModelTests` — **20 cases passed**, no test referenced any of the 6 deleted private helpers.
- Token discipline grep: `grep -cE "Color\(|cornerRadius: [0-9]|padding\([0-9]"` returns `0` for all 3 files (CLAUDE.md §2 + §8.4 + FOUND-07 pre-commit hook).
- Finder-dupe scan: `find gamekit/gamekit/Games/Minesweeper -name "* 2.swift"` returns nothing (CLAUDE.md §8.7).
- Phase 3 D-05 timer-freeze invariant grep: `grep "TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))" TimerChip.swift` returns the construction once in the body + once in the doc-comment header — verbatim contract preserved.
- HeaderBar struct init signature grep: `grep "MinesweeperHeaderBar(" MinesweeperGameView.swift` returns `1` (call site at lines 82-87 byte-identical, unchanged).

## Plan-spec Confirmations (per `<output>` block)

- **3 files touched, line-count deltas:** see table above (+50 chip 1, +77 chip 2, −98 HeaderBar). ✓
- **MinesweeperHeaderBar init signature unchanged:** props `theme: Theme`, `minesRemaining: Int`, `timerAnchor: Date?`, `pausedElapsed: TimeInterval` preserved in same order. GameView call site recompiled clean without edits. ✓
- **No Finder dupes:** find returns empty. ✓
- **Phase 3 D-05 timer-freeze invariant (`.distantPast` anchor) preserved verbatim in TimerChip:** the exact string `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))` appears in TimerChip.swift line 27. ✓

## Next Phase Readiness

- **Plan 11-02 ready.** The two new chip subviews are the prerequisite for Plan 11-04's compact-row slot 2 stack (per CONTEXT D-06). No follow-up cleanup needed.
- **SC5 byte-identical-off precondition delivered.** HeaderBar renders pixel-identical to pre-refactor when Video Mode is Off (token-driven, same view tree, same `theme.spacing.s` gap, same `theme.spacing.m`/`.s` outer padding). Plan 11-02 will add the `videoModeStore` env reads and the layout branch.
- **No release-log entry appended this commit.** Per CLAUDE.md §8.10 + §0.3, a pure internal refactor with no shipped user-facing change is grouped with the Phase 11 wrap-up commit (likely Plan 11-08). The `Docs/releases/v1.2.md` internal-changes line in PATTERNS will be appended once Phase 11 ships a user-facing surface (Plans 11-02 / 11-04 onward).

## Self-Check: PASSED

- `MinesRemainingChip.swift`: FOUND (50 lines).
- `TimerChip.swift`: FOUND (77 lines).
- `MinesweeperHeaderBar.swift`: FOUND (35 lines, modified).
- Commit `531ca8c`: FOUND (Task 1 — chip files create).
- Commit `b6f494e`: FOUND (Task 2 — HeaderBar refactor).
- Build: green.
- Tests: green (MinesweeperViewModelTests/20 cases).

---
*Phase: 11-mines-adoption*
*Completed: 2026-05-13*
