---
phase: 12-merge-nonogram-adoption
plan: 01
subsystem: merge,minesweeper,video-mode
tags: [merge, minesweeper, refactor, chip-extraction, video-mode, shared-chip]
requires:
  - 11-mines-adoption/11-01 (MinesRemainingChip extraction template)
  - 11-mines-adoption/11-04 (round 2 compact-variant API polish)
provides:
  - MergeScoreChip (props-only; compact: Bool = false API)
  - MergeBestChip (props-only; compact: Bool = false API)
  - VideoModeTimerChip (shared Core/ primitive; renamed from
    Games/Minesweeper/TimerChip.swift)
  - MergeHeaderBar (thin composer; 30 lines)
affects:
  - MergeHeaderBar (refactor; init signature preserved)
  - MinesweeperHeaderBar (1 call site renamed: TimerChip → VideoModeTimerChip)
  - MinesweeperGameView+VideoMode (1 call site renamed)
tech-stack:
  added: []
  patterns:
    - "Props-only chip extraction with `compact: Bool = false` default
      (off-path byte-identical to v1.1 inline shape)"
    - "Shared-timer-chip MOVE not duplicate (single source of truth in
      Core/) — Mines + Nonogram + Merge all consume same primitive"
key-files:
  created:
    - gamekit/gamekit/Games/Merge/MergeScoreChip.swift (50 lines)
    - gamekit/gamekit/Games/Merge/MergeBestChip.swift (43 lines)
    - gamekit/gamekit/Core/VideoModeTimerChip.swift (90 lines)
  modified:
    - gamekit/gamekit/Games/Merge/MergeHeaderBar.swift (50 → 30 lines)
    - gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift (1 type-name update)
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift (1 type-name update)
  deleted:
    - gamekit/gamekit/Games/Minesweeper/TimerChip.swift (renamed → Core/VideoModeTimerChip.swift)
decisions:
  - "D-12-OFFRESTORE preserved: MergeHeaderBar consumes MergeScoreChip +
    MergeBestChip with compact left defaulted (no explicit argument) —
    proven by acceptance grep returning 0 for `compact: ` inside HeaderBar"
  - "D-12-CHIPS shared timer chip is a MOVE not a duplicate: Mines's
    TimerChip.swift is gone; both Mines call sites now consume the new
    Core/VideoModeTimerChip type. Nonogram (Plan 12-03) will consume the
    same primitive without re-creating the TimelineView logic"
  - "T-12-01 mitigation: MergeHeaderBar init signature byte-identical
    (theme/score/bestScore/mode in same order with same types) —
    MergeGameView.swift:44-49 call site untouched"
metrics:
  duration_seconds: 323
  completed_date: 2026-05-14
  task_count: 3
  file_count: 6
---

# Phase 12 Plan 01: Merge Chip Extraction + Shared Timer Chip Rename — Summary

Extracted `MergeScoreChip` + `MergeBestChip` as props-only sibling subviews
from `MergeHeaderBar` (D-12-CHIPS pattern mirror of P11-01 round 2 polish)
AND renamed `Games/Minesweeper/TimerChip.swift` →
`Core/VideoModeTimerChip.swift` so Plan 12-02 (Merge compose) and Plan 12-03
(Nonogram chip extract) can consume the shared timer chip without
duplicating its TimelineView logic.

## What shipped

| File | Delta | Notes |
|------|-------|-------|
| `gamekit/gamekit/Games/Merge/MergeScoreChip.swift` | NEW (50 lines) | Props-only; `compact: Bool = false` API. Default = byte-identical to v1.1 inline chip in MergeHeaderBar. |
| `gamekit/gamekit/Games/Merge/MergeBestChip.swift` | NEW (43 lines) | Sibling of MergeScoreChip; same shape, different label/data. |
| `gamekit/gamekit/Core/VideoModeTimerChip.swift` | NEW (90 lines) | Renamed from `Games/Minesweeper/TimerChip.swift`; body verbatim. Phase 3 D-05 freeze invariants preserved. |
| `gamekit/gamekit/Games/Merge/MergeHeaderBar.swift` | 50 → 30 lines | Thin composer; private `chip(label:value:)` ViewBuilder deleted. |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` | 1-line change | `TimerChip(…)` → `VideoModeTimerChip(…)`. Args identical. |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` | 1-line change | Same type-name update at the `compactRowComposed.secondaryInfo` slot. |
| `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` | DELETED | Renamed to Core/. |

## Verification

- **Build:** `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → `** BUILD SUCCEEDED **` after each task.
- **MinesweeperViewModelTests:** `** TEST SUCCEEDED **` (no Mines VM behavior change post-rename).
- **D-OFFRESTORE byte-identity:** `grep -c "compact: " gamekit/gamekit/Games/Merge/MergeHeaderBar.swift` returns `0` — HeaderBar leaves `compact` defaulted, so the off-path render tree is shape-identical to v1.1.
- **MergeHeaderBar init signature:** `theme/score/bestScore/mode` unchanged. `MergeGameView.swift:44-49` call site unmodified.
- **D-05 timer freeze invariant:** `grep -c "TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))" gamekit/gamekit/Core/VideoModeTimerChip.swift` returns `2` (once in docstring, once in body). The body invocation is verbatim from the deleted `TimerChip.swift`.
- **Rename complete:** `grep -rE "\bTimerChip\(" gamekit/gamekit/ --include="*.swift" | wc -l` returns `0`. `grep -rE "\bVideoModeTimerChip\(" gamekit/gamekit/ --include="*.swift" | wc -l` returns `2` (Mines HeaderBar + Mines GameView+VideoMode).
- **No Finder dupes:** `find gamekit/gamekit -name "* 2.swift"` returns nothing across `Merge/`, `Minesweeper/`, and `Core/`.
- **Token discipline:** `grep -cE "Color\(|cornerRadius: [0-9]|padding\([0-9]" …new chip files` returns `0` for both new chip files (CLAUDE.md §2).
- **File-size cap (§8.5):** MergeScoreChip = 50 lines, MergeBestChip = 43 lines, VideoModeTimerChip = 90 lines, MergeHeaderBar = 30 lines — all well under the 500-line hard cap; all under the plan's per-file soft caps (≤ 80 / ≤ 80 / ≤ 90 / ≤ 35).

## Commits

| Task | Type | Hash | Message |
|------|------|------|---------|
| 1 | feat | `c4bf5bb` | feat(12-01): extract MergeScoreChip + MergeBestChip from MergeHeaderBar |
| 2 | refactor | `629f237` | refactor(12-01): collapse MergeHeaderBar into thin composer of extracted chips |
| 3 | refactor | `c53c0ea` | refactor(12-01): rename TimerChip → VideoModeTimerChip; move to Core/ |

## Deviations from Plan

None — plan executed exactly as written. All three tasks landed in their own commits per CLAUDE.md §8.10 commit discipline. No Rule 1-4 deviations triggered.

## Off-path byte-identity confirmations (P12 SC4 / T-12-OFFRESTORE)

- `MergeHeaderBar` invokes both extracted chips with no `compact:` argument → resolves to defaulted `false` → identical view tree to the pre-extraction private `chip()` ViewBuilder (same `VStack(alignment: .leading, spacing: 0)`, same `theme.typography.caption.weight(.semibold)` label, same `theme.typography.monoNumber` value, same `theme.spacing.m / s` padding, same `theme.colors.surface` bg, same `theme.radii.chip` clip + border).
- `MinesweeperHeaderBar` invokes `VideoModeTimerChip(theme:, timerAnchor:, pausedElapsed:)` with no `compact:` → identical view tree to the pre-rename `TimerChip(…)` call (same struct body, same `compact: Bool = false` default, same `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))`).
- `MinesweeperGameView+VideoMode.compactRowComposed.secondaryInfo` invokes `VideoModeTimerChip(…, compact: true)` — same argument list as the pre-rename `TimerChip(…, compact: true)`, same struct body. P11 SC5 carry-forward preserved.

## Downstream consumers (Plans 12-02 / 12-03 / 12-04)

- **Plan 12-02 (Merge Large-zone compose):** Will consume `MergeScoreChip(compact: true)` at slot 2 and `MergeBestChip(compact: true)` at slot 4 of `VideoCompactControlRow`.
- **Plan 12-03 (Nonogram chip extract):** Will leave `Core/VideoModeTimerChip.swift` untouched and add `NonogramSizeChip` + `NonogramLivesChip` sibling files. Nonogram's existing inline timer chip will be replaced by the shared `VideoModeTimerChip(compact: false)`.
- **Plan 12-04 (Nonogram Large-zone compose):** Will consume `VideoModeTimerChip(compact: true)` at slot 4 of its `VideoCompactControlRow`.

## Self-Check: PASSED

- `gamekit/gamekit/Games/Merge/MergeScoreChip.swift`: FOUND
- `gamekit/gamekit/Games/Merge/MergeBestChip.swift`: FOUND
- `gamekit/gamekit/Core/VideoModeTimerChip.swift`: FOUND
- `gamekit/gamekit/Games/Minesweeper/TimerChip.swift`: ABSENT (renamed)
- `gamekit/gamekit/Games/Merge/MergeHeaderBar.swift`: MODIFIED (30 lines)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift`: MODIFIED (call site updated)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift`: MODIFIED (call site updated)
- Commit `c4bf5bb`: FOUND
- Commit `629f237`: FOUND
- Commit `c53c0ea`: FOUND
