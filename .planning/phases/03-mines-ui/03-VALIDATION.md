---
phase: 3
slug: mines-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `03-RESEARCH.md` § Validation Architecture (lines 900–947).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test` / `#expect`), bundled with Xcode 16 — for `gamekitTests`. XCTest for `DesignKitTests` (existing target convention; do NOT switch). |
| **Config file** | None separate — targets `gamekitTests` and `DesignKitTests` already exist (validated P1+P2). |
| **Quick run command** | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E' -only-testing:gamekitTests/MinesweeperViewModelTests` |
| **Full suite command** | `xcodebuild test -project gamekit/gamekit.xcodeproj -scheme gamekit -destination 'platform=iOS Simulator,id=51B89A5F-01EC-4DFA-AD8A-6CAEF0683E1E'` (gamekitTests + DesignKitTests) |
| **Estimated runtime** | ~5s quick, ~30s full |

---

## Sampling Rate

- **After every task commit:** Quick run command (≈5s).
- **After every plan wave:** Full suite command (≈30s).
- **Before `/gsd-verify-work`:** Full suite green AND 6 manual theme-preset screenshots in `03-VERIFICATION.md` AND 50-tap iPhone SE gesture log AND VoiceOver sweep log.
- **Max feedback latency:** 30 seconds.

---

## Per-Task Verification Map

> Populated by `gsd-planner` once tasks are emitted. Initial requirement → test mapping below.

| Requirement | Behavior | Test Type | Automated Command | File Exists |
|---|---|---|---|---|
| MINES-02 | VM `reveal(at:)` / `toggleFlag(at:)` state transitions | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/RevealAndFlagTests` | ❌ Wave 0 |
| MINES-05 timer | Pause on `.background`, resume on `.active`, freeze on terminal | unit (mock `Date.now`) | `… -only-testing:gamekitTests/MinesweeperViewModelTests/TimerStateTests` | ❌ Wave 0 |
| MINES-05 counter | `minesRemaining = total − flagged`; updates on toggleFlag | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/MineCounterTests` | ❌ Wave 0 |
| MINES-06 | Restart resets board to idle, keeps difficulty | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/RestartTests` | ❌ Wave 0 |
| MINES-07 | Win/loss outcome transitions; engines verified P2 ✓ | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/TerminalStateTests` | ❌ Wave 0 |
| MINES-11 | Wrong-flag detection in `lossContext`; mine count surfaced | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/LossContextTests` | ❌ Wave 0 |
| THEME-02 token | `theme.gameNumber(_:)` clamps `1...8`; returns palette entry | unit | `xcodebuild test … -only-testing:DesignKitTests/ThemeGameNumberTests` | ❌ Wave 0 |
| THEME-02 enforcement | Zero `Color()` literals in `Games/Minesweeper/` | smoke (CI shell + `.githooks/pre-commit`) | `git diff --cached` + grep | ✅ existing |
| A11Y-04 | Wong-safe Classic palette, ΔE ≥ 10 across protan/deutan/tritan | unit (deterministic) | `xcodebuild test … -only-testing:DesignKitTests/GameNumberPaletteWongTests` | ❌ Wave 0 |
| Diff persistence (D-11) | `mines.lastDifficulty` UserDefaults round-trip | unit | `… -only-testing:gamekitTests/MinesweeperViewModelTests/DifficultyPersistenceTests` | ❌ Wave 0 |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekit/gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` — covers MINES-02/05/06/07/11 + difficulty persistence
- [ ] `gamekit/gamekitTests/Helpers/MinesweeperVMFixtures.swift` — pre-built boards for state transition tests
- [ ] `DesignKit/Tests/DesignKitTests/ThemeGameNumberTests.swift` — token clamp + palette length contracts
- [ ] `DesignKit/Tests/DesignKitTests/GameNumberPaletteWongTests.swift` — A11Y-04 audit
- [ ] `DesignKit/Tests/DesignKitTests/Helpers/ColorVisionSimulator.swift` — Brettel/Machado matrix transforms + ΔE2000 (~80 lines pure Foundation)

*Framework: Swift Testing (gamekit) and XCTest (DesignKit) are bundled with Xcode 16 — no install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gesture misfire rate (50 taps, 0 misfires) | SC1 / MINES-02 | Cross-device touch latency varies; iPhone SE-class is the worst-case target | 50 alternating tap + long-press attempts on a fresh Hard board on iPhone SE 2nd-gen physical device — log each misfire in `03-VERIFICATION.md` |
| Cross-device timer pause/resume | SC2 / MINES-05 | Real device control-center pull, lock-screen flash, and full background each have distinct scenePhase sequences | Start a Hard game, pull control center, dismiss → verify elapsed unchanged. Lock screen 5s, unlock → verify elapsed advanced by 0s. Full background 30s, return → verify elapsed advanced by 0s. |
| Theme legibility (6 presets) | SC4 + CLAUDE.md §8.12 | Visual judgment required across Forest / Bubblegum / Barbie / Cream / Dracula / Voltage on Hard board + loss state | Capture screenshots per preset (Hard board mid-game, win overlay, loss overlay) — attach to `03-VERIFICATION.md` |
| VoiceOver row/col label sweep | A11Y-02 partial | `.accessibilityLabel` is unit-asserted but full focus-order requires human ear | VO-rotor through 10 random cells of a partially-revealed Hard board; verify each label reads expected `"Revealed, N mines adjacent, row R column C"` per D-19 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (5 files listed above)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
