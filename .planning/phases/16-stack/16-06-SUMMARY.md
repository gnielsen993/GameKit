---
phase: 16-stack
plan: "06"
subsystem: stats-ui
tags: [swiftui, stats, stack, props-only, designkit]
dependency_graph:
  requires: [16-02]
  provides: [StackStatsCard, StatsView-stack-section]
  affects:
    - gamekit/gamekit/Screens/StackStatsCard.swift
    - gamekit/gamekit/Screens/StatsView.swift
tech_stack:
  added: []
  patterns: [props-only-stats-card, empty-state-first, monoNumber-monospacedDigit, accessibilityElement-combine]
key_files:
  created:
    - gamekit/gamekit/Screens/StackStatsCard.swift
  modified:
    - gamekit/gamekit/Screens/StatsView.swift
    - Docs/releases/v1.4.md
decisions:
  - "StackStatsCard placed in Screens/ (not Games/Stack/) to mirror MergeStatsCard location; StatsView is already 496 lines and can reference it cleanly from the same module"
  - "Uses GameStats.stackEndlessMode / stackPerfectStreakMode constants rather than bare string literals per D-11 serialization-key rule"
  - "Three metrics only (D-10, minimal): high score + runs played + best streak; full per-session breakdown deferred to Phase 18 ARCADE-07"
  - "Accessibility: per-metric-row .accessibilityElement(children: .combine) + .accessibilityLabel, matching MergeModeStatsRow pattern"
metrics:
  duration: 7
  completed_date: "2026-06-30"
  tasks_completed: 2
  files_modified: 3
---

# Phase 16 Plan 06: StackStatsCard + StatsView Wiring Summary

## One-liner

Props-only `StackStatsCard` with three metrics (high score, runs played, best perfect streak) wired into StatsView, replacing the Phase 15 placeholder via the existing `stackRecords` / `stackBestScores` queries.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StackStatsCard props-only card with empty state | cb4d963 | Screens/StackStatsCard.swift |
| 2 | Wire StackStatsCard into StatsView (replace placeholder) | 08147dc | Screens/StatsView.swift |

## What Was Built

### StackStatsCard.swift (117 lines, under 200 cap)

New props-only component at `Screens/StackStatsCard.swift`:

- **Signature:** `struct StackStatsCard: View { let theme: Theme; let records: [GameRecord]; let bestScores: [BestScore] }`
- **Empty state first (§8.3):** `records.isEmpty` branch renders "No Stack games played yet." in `theme.colors.textTertiary`
- **Three metrics (D-10):** 2-column Grid with label left / value right
  - High Score: `bestScores.first { $0.difficultyRaw == GameStats.stackEndlessMode }?.score` → "—" if nil
  - Runs Played: `records.count`
  - Best Streak: `bestScores.first { $0.difficultyRaw == GameStats.stackPerfectStreakMode }?.score` → "—" if nil
- **Typography:** `theme.typography.monoNumber.monospacedDigit()` for all numeric values
- **Accessibility:** `.accessibilityElement(children: .combine)` + `.accessibilityLabel` per row
- **Token discipline:** zero `Color(...)` literals; all fonts, spacing, colors from theme tokens
- **No queries:** parent (StatsView) owns all data

### StatsView.swift (492 lines, under 500 cap)

Replaced the Phase 15 placeholder block (10 lines) with the real section (5 lines):

```swift
if shows(.stack) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "STACK")) }
    DKCard(theme: theme) {
        StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)
    }
}
```

- Uses existing `stackRecords` / `stackBestScores` `@Query` pairs (lines 127–135) — no new query
- Mirrors the `.merge` section shape exactly
- Snake placeholder unchanged (Phase 17)
- Net change: −5 lines (placeholder removed, shorter call site added)

## Verification

- `test -f StackStatsCard.swift && test -z "$(grep -n '@Query' StackStatsCard.swift)" && grep -q 'struct StackStatsCard'` → OK
- `wc -l StackStatsCard.swift` → 117 (< 200 cap)
- `wc -l StatsView.swift` → 492 (< 500 cap, §8.5 safe)
- `grep -q 'StackStatsCard(theme:' StatsView.swift` → present
- `grep 'No Stack games yet' StatsView.swift` → empty (old placeholder removed)
- `xcodebuild build` → **BUILD SUCCEEDED**

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. StackStatsCard reads already-persisted BestScore rows via props passed from StatsView; T-16-10 (unknown mode keys) and T-16-11 (non-PII stats content) mitigated as noted in the plan threat register.

## Self-Check: PASSED

- Screens/StackStatsCard.swift: FOUND (117 lines)
- Screens/StatsView.swift: FOUND (492 lines, placeholder replaced)
- commit cb4d963: FOUND
- commit 08147dc: FOUND
