---
phase: 12-merge-nonogram-adoption
plan: 03
subsystem: nonogram,video-mode
tags: [nonogram, refactor, chip-extraction, video-mode]
requires:
  - 11-mines-adoption/11-01 (MinesRemainingChip extraction template)
  - 12-merge-nonogram-adoption/12-01 (VideoModeTimerChip shared primitive
    in Core/; MergeScoreChip + MergeBestChip compact-variant API template)
provides:
  - NonogramSizeChip (props-only; compact: Bool = false API)
  - NonogramLivesChip (props-only; compact: Bool = false API; preserves
    NonogramGameMode.livesPerPuzzle as iteration bound + a11y denominator)
  - NonogramHeaderBar (thin composer; 44 lines)
affects:
  - NonogramHeaderBar (refactor; init signature byte-identical)
tech-stack:
  added: []
  patterns:
    - "Props-only chip extraction with `compact: Bool = false` default
      (off-path byte-identical to v1.1 inline shape) — third game's
      adoption of the P11-01 / P12-01 template"
    - "Thin-composer HeaderBar consuming per-game chips + shared
      VideoModeTimerChip — same shape as MergeHeaderBar / MinesweeperHeaderBar"
key-files:
  created:
    - gamekit/gamekit/Games/Nonogram/NonogramSizeChip.swift (54 lines)
    - gamekit/gamekit/Games/Nonogram/NonogramLivesChip.swift (46 lines)
  modified:
    - gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift (128 → 44 lines)
  deleted: []
decisions:
  - "D-12-OFFRESTORE preserved: NonogramHeaderBar consumes all three chips
    (NonogramSizeChip + NonogramLivesChip + VideoModeTimerChip) with
    `compact` left defaulted (no explicit argument) — proven by acceptance
    grep returning 0 for `compact: ` inside HeaderBar"
  - "T-12-NG-1 mitigation: NonogramHeaderBar init signature byte-identical
    (theme/sizeLabel/timerAnchor/pausedElapsed/livesRemaining in same order
    with same types) — NonogramGameView.swift:51-57 call site untouched
    (zero git diff)"
  - "T-12-NG-2 mitigation: NonogramGameMode.livesPerPuzzle preserved as
    iteration bound (line 27) AND a11y label denominator (line 44) in
    NonogramLivesChip; grep -c returns exactly 2"
  - "T-12-NG-3 + T-12-NG-4 mitigations: VideoModeTimerChip's Phase 3 D-05
    `.distantPast` anchor freeze invariant flows through to Nonogram via
    the shared Core/ primitive (not duplicated)"
  - "D-NG-17 not touched in this plan — NonogramBoardView.swift SHA
    fa6c2c0 unchanged across both tasks (verified pre + post). The
    Video-Mode-aware cell-size floor seam lands in Plan 12-05"
metrics:
  duration_seconds: 251
  completed_date: 2026-05-14
  task_count: 2
  file_count: 3
---

# Phase 12 Plan 03: Nonogram Chip Extraction — Summary

Extracted `NonogramSizeChip` + `NonogramLivesChip` as props-only sibling
subviews from `NonogramHeaderBar` (D-12-CHIPS pattern mirror of P11-01 +
P12-01) and replaced the inline `timerChip` ViewBuilder with the shared
`VideoModeTimerChip` (Core/, landed in Plan 12-01). NonogramHeaderBar
collapsed to a thin composer; off-path render byte-identical to v1.1.

## What shipped

| File | Delta | Notes |
|------|-------|-------|
| `gamekit/gamekit/Games/Nonogram/NonogramSizeChip.swift` | NEW (54 lines) | Props-only; `compact: Bool = false` API. Icon `square.grid.3x3.square` + monospaced size label. Default = byte-identical to v1.1 inline `sizeChip` ViewBuilder. |
| `gamekit/gamekit/Games/Nonogram/NonogramLivesChip.swift` | NEW (46 lines) | Sibling chip; 3-heart-glyph render with `i < remaining ? "heart.fill" : "heart"` toggle verbatim from v1.1 HeaderBar. `NonogramGameMode.livesPerPuzzle` preserved as iteration bound + a11y denominator. |
| `gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift` | 128 → 44 lines | Thin composer; 5 private helpers deleted (`sizeChip` / `livesChip(remaining:)` / `timerChip` / `displayedElapsed` / `formatElapsed`). Body now composes the 3 chips with `compact` defaulted. |

## Verification

- **Build:** `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → `** BUILD SUCCEEDED **` after each task.
- **NonogramViewModelTests:** `** TEST SUCCEEDED **` (no VM behavior change post-refactor; HeaderBar consumes the same props in the same order).
- **D-12-OFFRESTORE byte-identity:** `grep -c "compact: "` inside `NonogramHeaderBar.swift` returns `0` — HeaderBar leaves all three chips' `compact` parameter defaulted to `false`, so the off-path render tree is shape-identical to v1.1.
- **NonogramHeaderBar init signature:** `theme/sizeLabel/timerAnchor/pausedElapsed/livesRemaining` unchanged. `NonogramGameView.swift:51-57` call site has zero git diff vs HEAD~2.
- **NonogramBoardView SHA unchanged:** `git rev-parse HEAD:gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` returns `fa6c2c0711357fd642210e352047d35e9b097f25` both pre-execution and post-execution. D-NG-17 contract preserved (D-NG-15 floor seam intentionally deferred to Plan 12-05).
- **D-05 timer freeze invariant:** Flows through unchanged via the shared `VideoModeTimerChip` in Core/. NonogramHeaderBar no longer hosts the `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))` directly — it consumes the chip that does.
- **No Finder dupes:** `find gamekit/gamekit/Games/Nonogram -name "* 2.swift"` returns nothing.
- **Token discipline:** `grep -cE "Color\(|cornerRadius: [0-9]|padding\([0-9]"` returns `0` for both new chip files (CLAUDE.md §2 + FOUND-07 hook clean). The heart-glyph `.system(size: 11/14)` exception is preserved from v1.1's HeaderBar line 48 (per-component visual constant, already an established exception).
- **File-size cap (§8.5):** NonogramSizeChip = 54 lines, NonogramLivesChip = 46 lines, NonogramHeaderBar = 44 lines — all well under the 500-line hard cap; all under the plan's per-file soft caps (≤ 80 / ≤ 80 / ≤ 45).
- **livesPerPuzzle preservation (T-12-NG-2):** `grep -c "NonogramGameMode.livesPerPuzzle" NonogramLivesChip.swift` returns `2` (iteration bound at line 27 + a11y label denominator at line 44).

## Commits

| Task | Type | Hash | Message |
|------|------|------|---------|
| 1 | feat | `02fde26` | feat(12-03): extract NonogramSizeChip + NonogramLivesChip from NonogramHeaderBar |
| 2 | refactor | `ab529da` | refactor(12-03): collapse NonogramHeaderBar into thin composer of extracted chips |

## Deviations from Plan

**Documentation polish (out-of-band but expected):**
- During Task 1, the initial `NonogramLivesChip.swift` had `NonogramGameMode.livesPerPuzzle` referenced 4× (2 in docstring + 2 in code). Acceptance criterion required exactly `2` (iteration bound + a11y denominator). Trimmed the docstring to read `0...livesPerPuzzle` (unqualified short form) so the grep count matches the acceptance contract literally without losing prop documentation. No behavior change.
- During Task 2, the initial NonogramHeaderBar.swift came out to 46 lines (1 over the ≤ 45 cap). Consolidated the top-of-file comment block from 2 paragraphs into 1 tight paragraph to land at 44 lines. No code change.

No Rule 1-4 deviations triggered (no bugs, no missing critical functionality, no blocking issues, no architectural changes).

## Off-path byte-identity confirmations (P12 SC4 / T-12-NG-3)

- `NonogramHeaderBar` invokes `NonogramSizeChip(theme: theme, sizeLabel: sizeLabel)` with no `compact:` argument → resolves to defaulted `false` → identical view tree to the pre-extraction private `sizeChip` ViewBuilder (same `HStack(spacing: theme.spacing.xs)`, same `square.grid.3x3.square` icon with `accentPrimary`, same `theme.typography.headline` text with `monospacedDigit().lineLimit(1)`, same `theme.spacing.m/s` padding, same `theme.colors.surface` bg, same `theme.radii.chip` clip + border, same `"Puzzle size \(sizeLabel)"` a11y label).
- `NonogramHeaderBar` invokes `NonogramLivesChip(theme: theme, remaining: livesRemaining)` (inside the `if let livesRemaining` binding) with no `compact:` → identical view tree to the pre-extraction private `livesChip(remaining:)` ViewBuilder (same `HStack(spacing: theme.spacing.xs / 2)`, same `ForEach(0..<NonogramGameMode.livesPerPuzzle)`, same `i < remaining ? "heart.fill" : "heart"` glyph toggle, same `i < remaining ? danger : textTertiary` color toggle, same `.system(size: 14, weight: .semibold)` heart-glyph size, same `theme.spacing.s/s` padding, same chip surface, same `"\(remaining) of \(NonogramGameMode.livesPerPuzzle) lives remaining"` a11y label).
- `NonogramHeaderBar` invokes `VideoModeTimerChip(theme:, timerAnchor:, pausedElapsed:)` with no `compact:` → identical view tree to the pre-extraction inline `timerChip` ViewBuilder. The `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))` Phase 3 D-05 freeze invariant is now provided by the shared chip (Plan 12-01 verified).

## Downstream consumers

- **Plan 12-04 (Nonogram Large-zone compose):** Will consume `NonogramSizeChip(compact: true)` at slot 2 in Free mode, `NonogramLivesChip(compact: true)` at slot 2 in Lives mode (single-slot conditional swap per D-NG-01), and `VideoModeTimerChip(compact: true)` at slot 4 of `VideoCompactControlRow`. Both extracted chips' compact-variant API surface is ready.
- **Plan 12-05 (Nonogram cell-size floor seam):** Will touch `NonogramBoardView.swift` for the first time in Phase 12 (env read + defaulted `floor:` param). This plan's SHA-preservation guarantee means the floor seam lands on a known-clean baseline.

## Shared VideoModeTimerChip — consumer count

Post-Plan-12-03, the shared timer chip is now consumed by:
- `MinesweeperHeaderBar` (Plan 12-01) — off-path / Small PiP zones, `compact: false`
- `MinesweeperGameView+VideoMode.compactRowComposed` (Plan 12-01) — Large zones, `compact: true`
- `NonogramHeaderBar` (this plan) — off-path / Small PiP zones, `compact: false`

Plan 12-04 will add the 4th call site (Nonogram Large-zone compact row, `compact: true`).

## Self-Check: PASSED

- `gamekit/gamekit/Games/Nonogram/NonogramSizeChip.swift`: FOUND
- `gamekit/gamekit/Games/Nonogram/NonogramLivesChip.swift`: FOUND
- `gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift`: MODIFIED (44 lines, was 128)
- `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift`: UNCHANGED (SHA fa6c2c0711357fd642210e352047d35e9b097f25)
- `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift`: UNCHANGED (zero git diff)
- Commit `02fde26`: FOUND
- Commit `ab529da`: FOUND
