---
phase: 17
slug: snake
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-03
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `17-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`) [VERIFIED: existing test target] |
| **Config file** | None separate — Xcode test scheme `gamekitTests` |
| **Quick run command** | `xcodebuild test -scheme gamekit -only-testing:gamekitTests/SnakeEngineTests -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~60–120 seconds (full suite incl. simulator boot) |

---

## Sampling Rate

- **After every task commit:** Run `SnakeEngineTests` + `GameStatsTests` quick run (deterministic, <10s test body).
- **After every plan wave:** Run the full `gamekitTests` suite (must be green).
- **Before `/gsd:verify-work`:** Full suite green + SC1 device swipe test + §8.12 theme audit + Reduce Motion recipe + `git diff` SC3 check.
- **Max feedback latency:** ~120 seconds.

---

## Per-Task Verification Map

| Req / SC | Behavior | Test Type | Automated Command / Recipe | File Exists | Status |
|----------|----------|-----------|----------------------------|-------------|--------|
| SNAKE-01 / SC1 | Swipe / D-pad changes direction; eating food grows snake; left-edge swipe doesn't pop nav | unit (direction queue) + manual | `SnakeEngineTests` + manual device swipe test | ❌ W0 | ⬜ pending |
| SNAKE-02 | Wrap (default) and wall-death mode selectable; persisted in UserDefaults | unit + manual | `SnakeEngineTests.toroidalWrap` + `wallCollision` + manual toggle | ❌ W0 | ⬜ pending |
| SNAKE-03 / SC4 | D-pad visible + operational; rapid turns buffered; 180° reversal rejected; queue capacity-2 | unit (VM queue) + manual | VM queue unit test + manual D-pad verification | ❌ W0 | ⬜ pending |
| SNAKE-04 | Speed ramps then plateaus at ≥100ms tick; self/wall collision ends run | unit | `SnakeEngineTests.selfCollision` + `proMotionEquivalence` | ❌ W0 | ⬜ pending |
| SNAKE-05 | Score = food eaten; high score persisted once on game-over; higher-only | unit (persistence) | `GameStatsTests.recordSnakeRunHigherOnly` | ❌ W0 | ⬜ pending |
| SC2 | dt=1/60 ≡ dt=1/120 over 5s simulated; same seed → identical outcomes | unit | `SnakeEngineTests.proMotionEquivalence` + `seedDeterminism` | ❌ W0 | ⬜ pending |
| SNAKE-06 / §8.12 | Token-only colors; legible Classic + Voltage/Dracula | grep gate + manual audit | `grep -rn "Color(red:\|Color(hex:\|\.green\b" Games/Snake/` empty + visual audit | grep ✅ / visual manual | ⬜ pending |
| SNAKE-07 / SC5 | Reduce Motion: jump-cut movement; gameplay identical | manual | Simulator → Accessibility → Reduce Motion; play a run | manual | ⬜ pending |
| SC3 | Zero diff on `ArcadeLoopDriver.swift` + `ArcadeGameState.swift` | git gate | `git diff HEAD~N -- Core/ArcadeLoopDriver.swift Core/ArcadeGameState.swift` empty | ✅ gate | ⬜ pending |
| Engine purity | No SwiftUI/SwiftData in SnakeEngine | grep gate | `grep -rn "import SwiftUI\|import UIKit\|CGFloat\|modelContext" Games/Snake/SnakeEngine.swift` empty | ✅ gate | ⬜ pending |
| File caps | All Snake files < 400 lines | wc gate | `wc -l Games/Snake/*.swift` | ✅ gate | ⬜ pending |
| No dupe files | No `* 2.swift` | git check | `git status` shows no `?? *2.swift` (CLAUDE.md §8.7) | ✅ gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekitTests/Games/Snake/SnakeEngineTests.swift` — covers SNAKE-01/02/04 + SC2 (seed determinism, ProMotion equivalence, wrap, wall, self-collision)
- [ ] `gamekitTests/Core/GameStatsTests.swift` — add `recordSnakeRunHigherOnly` (SNAKE-05)
- [ ] `Core/ArcadePalette.swift` — extract from StackPalette before Snake references it
- [ ] Framework install: none — Swift Testing + `gamekitTests` target already exist

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Left-edge swipe does not pop NavigationStack | SNAKE-01 / SC1 | System gesture arbitration only reproduces on a real device | On device: start a run, swipe right starting from the left screen edge over the board; direction changes, no nav pop |
| §8.12 theme legibility | SNAKE-06 | Visual contrast judgment | Play under Classic + Voltage/Dracula; snake body ramp, food, and board well all legible |
| Reduce Motion jump-cut | SNAKE-07 / SC5 | Motion perception | Enable Reduce Motion; snake teleports cell-to-cell with no interpolation; gameplay unchanged |
| Speed-ramp feel calibration | SNAKE-04 | Tuning constants (grid size, ramp curve) need on-device feel check | Play several runs; confirm plateau feels calm at ≥100ms tick |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
