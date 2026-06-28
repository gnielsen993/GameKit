---
phase: 16
slug: stack
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `16-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`) [VERIFIED: codebase] |
| **Config file** | None — Swift Testing via Xcode test target `gamekitTests` |
| **Quick run command** | `xcodebuild test -scheme gamekit -only-testing:gamekitTests/StackEngineTests -destination 'platform=iOS Simulator,name=iPhone 15'` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 15'` |
| **Estimated runtime** | ~60–120 seconds (full suite incl. simulator boot) |

---

## Sampling Rate

- **After every task commit:** Run `StackEngineTests` + `GameStatsTests` (quick, deterministic).
- **After every plan wave:** Run the full `gamekitTests` suite (must be green).
- **Before `/gsd:verify-work`:** Full suite green + manual §8.12 audit + Reduce Motion recipe + Instruments no-disk-I/O check.
- **Max feedback latency:** ~120 seconds.

---

## Per-Task Verification Map

| Req / SC | Behavior | Test Type | Automated Command / Recipe | File Exists |
|----------|----------|-----------|----------------------------|-------------|
| STACK-01 / SC1 | Tap drops; overhang trims; block narrows; near-perfect recovers + visible combo; run ends at width 0 | unit (engine) + manual (UI) | `StackEngineTests` (`completeMissGameOver`, `streakRecoveryAndReset`) + manual play recipe | ❌ W0 |
| STACK-02 | Speed ramps then plateaus ~80; ends on complete miss | unit | `StackEngineTests.rampSpeedPlateau` (`rampSpeed(forScore: 80) == rampSpeed(forScore: 200)`) | ❌ W0 |
| STACK-02 / SC2 | dt=1/60 ≡ dt=1/120 over 5s (score, gameOver, widths) | unit | `StackEngineTests.proMotionEquivalence` | ❌ W0 |
| STACK-03 | Streak-based width recovery (D-01) | unit | `StackEngineTests.streakRecoveryAndReset` | ❌ W0 |
| STACK-04 / SC3 | High score persisted once on game-over; best streak tracked; Stats shows high score + runs played | unit (persistence) + manual | `GameStatsTests.recordStackRunWritesStreakWithoutSchemaChange` + Stats-screen visual check | ❌ W0 |
| SC3 (perf) | Loop paused at game-over (0 CPU); no disk I/O during play; save exactly once | manual / Instruments | Time Profiler + Core Data instrument during a run | ❌ manual |
| STACK-05 / SC4 | Canvas legible Classic + Voltage/Dracula; tokens only | grep gate + manual §8.12 | `grep -rn "Color(red:\|Color(hex:\|\.green\b\|\.red\b" gamekit/gamekit/Games/Stack/` empty + visual audit | grep ✅ / visual ❌ manual |
| STACK-06 / SC5 | Reduce Motion jump-cut; gameplay unchanged | manual | Simulator → Accessibility → Reduce Motion; play a run | ❌ manual |
| Engine purity | No SwiftUI/SwiftData in engine | grep gate | `grep -rn "import SwiftUI\|import UIKit\|modelContext" gamekit/gamekit/Games/Stack/StackEngine.swift` empty | ✅ gate |
| File caps | All Stack files < 400 lines | grep gate | `wc -l gamekit/gamekit/Games/Stack/*.swift Screens/StackStatsCard.swift` | ✅ gate |
| No dupe files | No `* 2.swift` | gate | `git status` shows no `?? *2.swift` | ✅ gate |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekitTests/Games/Stack/StackEngineTests.swift` — covers STACK-01/02/03 + SC2 (determinism, complete-miss game-over, streak recovery/reset, ramp plateau)
- [ ] `gamekitTests/Core/GameStatsTests.swift` — add `recordStackRunWritesStreakWithoutSchemaChange` (STACK-04 / D-11)
- [ ] Framework install: none — Swift Testing + `gamekitTests` target already exist

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Canvas legibility across presets | STACK-05 / SC4 | Visual contrast judgment per §8.12 | Play Stack on Classic + Voltage (or Dracula); confirm blocks, overhang trim, and score chip remain legible |
| Reduce Motion jump-cut | STACK-06 / SC5 | Accessibility setting + visual observation | Simulator → Accessibility → Reduce Motion ON; play a run; confirm blocks jump-cut (no slide/spring), pulse→instant flash, slow-mo→instant cut; mechanics unchanged |
| No disk I/O during play; save once on game-over; loop paused (0 CPU) | SC3 | Requires Instruments profiling | Time Profiler + Core Data instrument during a full run; confirm one write at game-over, zero per-frame I/O, 0 CPU after banner |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
