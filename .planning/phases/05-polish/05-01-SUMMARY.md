---
phase: 05-polish
plan: 01
subsystem: animation-foundations + settings-flags
tags: [minesweeper-phase, settings-store, tdd, foundation-only]
dependency_graph:
  requires:
    - "Foundation"
    - "Core/SettingsStore.swift (P4 baseline — cloudSyncEnabled + EnvironmentKey)"
    - "Games/Minesweeper/MinesweeperIndex.swift (engine type referenced by 2 cases)"
    - "gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift (makeIsolatedDefaults helper template)"
  provides:
    - "MinesweeperPhase enum (5 cases per CONTEXT D-06) — animation orchestration value type"
    - "MinesweeperPhase.isLossShake helper — keyframe-trigger gate"
    - "SettingsStore.hapticsEnabled / sfxEnabled / hasSeenIntro flags + their key constants"
  affects:
    - "Plan 05-02 — MinesweeperViewModel will publish phase + flag-toggle counts"
    - "Plan 05-03 — Core/Haptics.swift + Core/SFXPlayer.swift gate on hapticsEnabled / sfxEnabled at the source"
    - "Plan 05-04 — SettingsView AUDIO section binds 2 toggles to hapticsEnabled / sfxEnabled"
    - "Plan 05-05 — IntroFlowView writes hasSeenIntro on Skip/Done; RootTabView reads to gate .fullScreenCover"
    - "Plan 05-06 — MinesweeperGameView/BoardView observe vm.phase to drive .phaseAnimator / .keyframeAnimator / .transition"
tech-stack:
  added: []
  patterns:
    - "Foundation-only nonisolated enum (mirrors MinesweeperGameState shape)"
    - "Additive @Observable @MainActor store extension (preserves cloudSyncEnabled verbatim)"
    - "Default-true UserDefaults pattern: (object(forKey:) as? Bool) ?? true"
    - "Per-test isolated UserDefaults(suiteName: UUID) for parallel-safe Swift Testing"
    - "TDD plan-level RED→GREEN gate (test commit precedes feat commit in git log)"
key-files:
  created:
    - "gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift"
    - "gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift"
  modified:
    - "gamekit/gamekit/Core/SettingsStore.swift"
decisions:
  - "MinesweeperPhase declared Equatable + Sendable only (NOT Hashable, NOT Codable) — preserves [MinesweeperIndex] payload flexibility on .revealing case and matches the never-persist precedent of MinesweeperGameState"
  - "isLossShake helper added per RESEARCH §Pattern 2 — the keyframe trigger reads a Bool value-change rather than a payload-bearing case match, so a fresh .lossShake(mineIdx:) doesn't replay against the same payload pointer"
  - "hapticsEnabled init uses (object(forKey:) as? Bool) ?? true — bool(forKey:) returns false for unset keys per Apple docs (SettingsStore.swift:25-26 existing comment), and a default-true flag must survive fresh installs without .register(defaults:) (intentionally avoided per existing P4 invariant)"
  - "P5 doc-comment marker added at file head: '// P5 (D-10/D-23): hapticsEnabled / sfxEnabled / hasSeenIntro added; cloudSyncEnabled preserved unchanged.' — single line, makes the additive scope obvious without mutating the existing P4 invariants block"
metrics:
  duration_minutes: 18
  completed_date: 2026-04-26
  total_lines_added: 320
  files_created: 2
  files_modified: 1
  tests_added: 6
  tests_passing: 6
---

# Phase 5 Plan 01: Wave 1 Foundations (MinesweeperPhase + SettingsStore Flags) Summary

Wave 1 of P5 ships the contract artifacts every later wave reads from: a Foundation-only `MinesweeperPhase` enum (5 cases per CONTEXT D-06) for the upcoming animation pass, and 3 new `SettingsStore` flags (`hapticsEnabled` / `sfxEnabled` / `hasSeenIntro`) with TDD-proven round-trip persistence under isolated UserDefaults.

## Files

| File | Type | Lines | Purpose |
| ---- | ---- | -----:| ------- |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift` | NEW | 71 | Animation orchestration enum, Foundation-only, 5 cases + isLossShake helper |
| `gamekit/gamekit/Core/SettingsStore.swift` | EDIT (additive) | 135 (was ~78) | 3 new flags + 3 key constants + extended init; cloudSyncEnabled preserved verbatim |
| `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` | NEW | 114 | Swift Testing suite, 6 @Test cases covering defaults / round-trip / default-true / P4 regression |

## Commits (in TDD order)

| Step | Hash | Message |
| ---- | ---- | ------- |
| Task 1 | `81f8eec` | `feat(05-01): add MinesweeperPhase animation orchestration enum` |
| Task 2 RED | `64dc5be` | `test(05-01): add failing SettingsStoreFlagsTests for hapticsEnabled / sfxEnabled / hasSeenIntro` |
| Task 2 GREEN | `19c4f32` | `feat(05-01): extend SettingsStore with hapticsEnabled / sfxEnabled / hasSeenIntro flags` |

## Test Results

**SettingsStoreFlagsTests:** 6/6 passing (verified via `xcodebuild test -only-testing:gamekitTests/SettingsStoreFlags` → `** TEST SUCCEEDED **`).

| Test | Covers |
| ---- | ------ |
| `defaults_haveCorrectInitialValues` | cloudSync=false (P4) + haptics=true (D-10) + sfx=false (D-10) + hasSeenIntro=false (D-23) |
| `setHapticsEnabled_persistsToUserDefaults` | Round-trip — didSet writes + init reads |
| `setSfxEnabled_persistsToUserDefaults` | Round-trip — didSet writes + init reads |
| `setHasSeenIntro_persistsToUserDefaults` | Round-trip — didSet writes + init reads |
| `unsetHapticsEnabledKey_returnsTrueByDefault` | D-10 default-true caveat — `(object(forKey:) as? Bool) ?? true` survives fresh install |
| `cloudSyncEnabled_stillRoundTrips_p4Regression` | P4 D-28/D-29 regression guard |

**Full regression suite:** `xcodebuild test -scheme gamekit` → `** TEST SUCCEEDED **`. P3 MinesweeperViewModelTests + P4 GameStatsTests + StatsExporterTests + ModelContainerSmokeTests all still green; UI tests + launch perf tests also green.

## Foundation-only Proof (MinesweeperPhase.swift)

```
$ grep -c "^import" gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
1

$ grep "^import Foundation$" gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
import Foundation

$ grep -E "import (SwiftUI|Combine|SwiftData)" gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
(no matches — Foundation-only invariant satisfied per CONTEXT D-05)

$ grep -c "^    case " gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
5
```

ROADMAP P2 SC5 (engine purity) extends to this file because the VM that publishes `phase` must stay Foundation-only per `MinesweeperViewModel.swift:20`.

## Locked Decisions for Downstream Waves

These exact identifiers are now contract surface; rename = breaking change for the whole phase.

### MinesweeperPhase cases (Plan 05-02 / 05-06 read these)

```swift
nonisolated enum MinesweeperPhase: Equatable, Sendable {
    case idle
    case revealing(cells: [MinesweeperIndex])
    case flagging(idx: MinesweeperIndex)
    case winSweep
    case lossShake(mineIdx: MinesweeperIndex)

    var isLossShake: Bool { ... }
}
```

### SettingsStore flag identifiers (Plan 05-03 / 05-04 / 05-05 read these)

| Property | Type | Default | UserDefaults Key |
| -------- | ---- | ------- | ---------------- |
| `hapticsEnabled` | `Bool` | `true` (D-10) | `gamekit.hapticsEnabled` |
| `sfxEnabled` | `Bool` | `false` (D-10) | `gamekit.sfxEnabled` |
| `hasSeenIntro` | `Bool` | `false` (D-23) | `gamekit.hasSeenIntro` |

| Static key constant | Value |
| ------------------- | ----- |
| `SettingsStore.hapticsEnabledKey` | `"gamekit.hapticsEnabled"` |
| `SettingsStore.sfxEnabledKey` | `"gamekit.sfxEnabled"` |
| `SettingsStore.hasSeenIntroKey` | `"gamekit.hasSeenIntro"` |

The existing `SettingsStore.cloudSyncEnabledKey` (`"gamekit.cloudSyncEnabled"`) and the `EnvironmentValues.settingsStore` injection key remain unchanged — Plan 05-03 onward inherits the same `@Environment(\.settingsStore)` access path.

## Deviations from Plan

None — plan executed exactly as written.

The `grep` acceptance criterion in Task 2 (`grep "register(defaults:" ...` returns no matches) had to be refined to `grep -E "\.register\(defaults:"` because the existing P4 documentation comment in `SettingsStore.swift:26` legitimately contains the literal `register(defaults:)` token in its explanation of why the pattern is intentionally avoided. The actual call-site invariant (no `.register(defaults:)` invocation anywhere in the file) is satisfied.

## Authentication Gates

None — plan was fully autonomous.

## Planner-Discretion Choices (within action's stated bounds)

1. **`isLossShake` helper placement** — placed at end of enum (after all 5 cases) rather than between cases; matches Swift convention of keeping cases grouped at the top of an enum body.
2. **Per-case doc-comment phrasing** — each case cites both its trigger source (engine output / WinDetector predicate / restart) AND its view-tier consumer (RESEARCH §Pattern 1/2/3/4) so downstream agents can navigate both directions without re-deriving the mapping.
3. **P5 marker comment** — single line at file head (`// P5 (D-10/D-23): ...`) rather than a multi-line block, to keep the existing P4 invariants block visually intact.
4. **Init read-strategy comments** — added 3-line micro-comments above each new `self.<flag> = ...` line explaining why each uses `bool(forKey:)` vs `(object(forKey:) as? Bool) ?? true`, so the optional-cast pattern doesn't look like a copy-paste typo.

## Self-Check: PASSED

**Files claimed created:**
- `gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift` → FOUND (71 lines)
- `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` → FOUND (114 lines)

**Files claimed modified:**
- `gamekit/gamekit/Core/SettingsStore.swift` → FOUND (135 lines, was ~78 — additive only, cloudSyncEnabled preserved)

**Commits claimed exist:**
- `81f8eec` (Task 1 feat) → FOUND in `git log --oneline`
- `64dc5be` (Task 2 RED test) → FOUND in `git log --oneline`
- `19c4f32` (Task 2 GREEN feat) → FOUND in `git log --oneline`

**TDD gate compliance:** RED commit `64dc5be` precedes GREEN commit `19c4f32` in `git log --oneline`. Verified.

**Test results:** 6/6 SettingsStoreFlagsTests pass; full regression suite passes.
