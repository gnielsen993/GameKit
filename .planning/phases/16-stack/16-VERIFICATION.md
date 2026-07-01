# Phase 16 (Stack) — Verification Record

Plan: 16-07 · Requirements: STACK-05, STACK-06 · Success criteria: SC3, SC4, SC5

---

## Task 1 — Automated phase gates (PASS)

Run 2026-07-01 on iPhone 16 Pro simulator (iOS 18.5).

| Gate | Command | Result |
|------|---------|--------|
| Token discipline | `grep -rn "Color(red:\|Color(hex:\|Color(white:\|\.green\b\|\.red\b\|\.blue\b\|\.orange\b" gamekit/gamekit/Games/Stack/` | **CLEAN** (empty) |
| Engine purity | `grep -rn "import SwiftUI\|import UIKit\|import SwiftData\|modelContext" gamekit/gamekit/Games/Stack/StackEngine.swift` | **CLEAN** (empty) |
| Finder-dupe (`* 2.swift`) | `git status` + disk scan | **none** |
| Full test suite | `xcodebuild test -scheme gamekit -only-testing:gamekitTests -parallel-testing-enabled NO` | **TEST SUCCEEDED** — 29 tests, 0 failures |

### File-cap gate (all < 400 lines) — PASS

| File | Lines |
|------|-------|
| StackBoardCanvas.swift | 186 |
| StackConfig.swift | 47 |
| StackEngine.swift | 163 |
| StackGameView.swift | 224 |
| StackPalette.swift | 53 |
| StackViewModel.swift | 157 |
| StackStatsCard.swift | 117 |

Note: a first `xcodebuild test` attempt failed with a CoreSimulator device-clone flake
("Failed to clone device 'iPhone 16 Pro' … connection abort"). Re-running with
`-parallel-testing-enabled NO` (no clone) succeeded — not a code failure. The
CloudKit/persistence log lines in the run are expected harness noise (no iCloud account
in the simulator; an intentional `FakeError` in AuthStoreTests).

---

## Task 2 — Manual SC3/SC4/SC5 + DESIGN §12.5 sign-off (PENDING USER)

**Blocking human-verification checkpoint.** All automated gates (Task 1) are green and the
game is built and runnable. The following require a human at the simulator + Instruments:

- [ ] **SC4 — §8.12 theme audit:** Play Stack on Classic (Chrome Diner) — tower blocks,
      sliding block, overhang trim, score + combo chips all legible and adjacent blocks
      distinguishable. Switch to Voltage **or** Dracula and replay — same legibility, no
      token bleedthrough, combo counter readable. Spot-check colorblind distinguishability
      (adjacent blocks differ in brightness, not just hue). _Preset(s) used: ____
- [ ] **SC5 — Reduce Motion:** Simulator → Settings → Accessibility → Motion → Reduce
      Motion ON. Blocks jump-cut each tick (no slide/spring); perfect-drop pulse → instant
      flash; combo bump → instant number change; game-over → instant cut to banner (no
      slow-mo, no color-drain, no shake). Mechanics + speed ramp unchanged vs RM off.
- [ ] **SC3 — Instruments:** Time Profiler + SwiftData/Core Data instrument. During active
      play: ZERO disk-write spikes. On game-over: exactly ONE write (recordStackRun save).
      After banner: loop paused (~0 CPU on the game view).
- [ ] **DESIGN.md §12.5 new-game done checklist:** walk each item for Stack.

**Resume signal:** reply `approved` if all four PASS, or describe the gaps to address.

_Results (fill on sign-off):_

---

## Task 3 — Release log (PASS)

MARKETING_VERSION = 1.4. `Docs/releases/v1.4.md` records the Stack feature under
Summary/User-facing/Internal changes (playable endless game, tap-to-drop + streak width
recovery, accent-palette Canvas, Reduce Motion path, high score + best perfect streak
persisted, minimal Stats section).
