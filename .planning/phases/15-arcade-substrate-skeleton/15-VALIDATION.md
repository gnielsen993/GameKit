---
phase: 15
slug: arcade-substrate-skeleton
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-26
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 15-RESEARCH.md "## Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Suite`, `@Test`, `#expect`) — already in use |
| **Config file** | none — Xcode test scheme `gamekitTests` |
| **Quick run command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:gamekitTests/ArcadeLoopDriverTests` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~5s quick (ArcadeLoopDriverTests) · full suite minutes |

---

## Sampling Rate

- **After every task commit:** Run quick command (`ArcadeLoopDriverTests` — SC1a + SC1b)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite green + D-04 manual notification-banner test + D-08 §8.12 Home-tile theme pass
- **Max feedback latency:** ~5s (pure-logic tests, no SwiftUI host needed)

---

## Per-Task Verification Map

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| ARCADE-01 | `TimelineView(.animation(paused:))` driver fires `onTick` on `@MainActor`; no CADisplayLink | unit (SC1a onTick gating) | `xcodebuild test -only-testing:gamekitTests/ArcadeLoopDriverTests/onTickGating` | ❌ W0 | ⬜ pending |
| ARCADE-02 | Fixed-timestep clamp `min(dt,0.1)`; inject dt=2.0 → ≤15 steps, clean exit | unit (SC1b spiral clamp) | `xcodebuild test -only-testing:gamekitTests/ArcadeLoopDriverTests/spiralOfDeathClamp` | ❌ W0 | ⬜ pending |
| ARCADE-03 | Lifecycle idle→running→paused→gameOver; harness shows a moving element | manual | launch harness on simulator, observe oscillation | — | ⬜ pending |
| ARCADE-04 | Loop pauses on `.inactive` AND `.background`; no time drift on foreground resume | manual (device) | D-04 notification-banner procedure (below) | — | ⬜ pending |
| ARCADE-05 | CloudKit-safe schema: `.stack`/`.snake` `GameKind` values pass smoke test, no migration | unit (existing) | `xcodebuild test -only-testing:gamekitTests/ModelContainerSmokeTests` | ✅ existing | ⬜ pending |
| ARCADE-06 | Counter-trigger haptic structure established; no haptic/SFX fires in the Phase 15 harness | N/A | harness has no haptic events to gate yet | — | ⬜ pending |
| ARCADE-09 | Stack/Snake tiles appear on Home; tap navigates to harness placeholder | manual | launch app → verify 2 new tiles → tap each | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Note on ARCADE-06:** Haptic routing is validated when real game VMs ship (Phase 16/17). In Phase 15 the harness has no haptic events — the counter-trigger pattern is established in code structure but has nothing to fire.

---

## Wave 0 Requirements

- [ ] `Core/ArcadeGameState.swift` — must exist before tests compile
- [ ] `Core/ArcadeLoopDriver.swift` — must exist before tests compile
- [ ] `gamekitTests/Core/ArcadeLoopDriverTests.swift` — covers ARCADE-01 (onTick gating) + ARCADE-02 (spiral-of-death clamp)
- [ ] `Games/Stack/StackHarnessView.swift` — must exist for HomeView compilation
- [ ] `Games/Snake/SnakeHarnessView.swift` — must exist for HomeView compilation

`ModelContainerSmokeTests` already exists and covers ARCADE-05 once `GameKind.swift` gains the two cases.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No dt-spike / time-jump after notification banner | ARCADE-04 (SC#3) | scenePhase `.inactive` transition from a real banner cannot be reproduced in a unit test | D-04 procedure below — on a real device |
| Cold-start unchanged from v1.4 baseline; no loop/engine alloc at launch | SC#5 | Launch-time allocation is an Instruments observation, not a unit assertion | Instruments App Launch template; confirm no `ArcadeLoopDriver`/engine state allocated before first tile tap |
| Tiles legible under Classic + one Loud preset | D-08 (SC §8.12) | Visual contrast judgement | Switch preset to Chrome Diner then Voltage/Dracula; confirm both accents legible on Home tiles |

### D-04 Manual Test Procedure (notification-banner gate)

1. Build and install on a real device.
2. Navigate to the Stack harness screen; confirm the dot is oscillating.
3. Pull down notification center to trigger `.inactive`; dismiss — confirm the dot resumes from its prior position (no jump/skip).
4. Trigger an actual notification banner (or Simulator > Features > Notification simulation).
5. After the banner appears and is dismissed, confirm the oscillation resumes without a noticeable jump (accumulated gap discarded, not replayed).
6. Record pass/fail in the Phase 15 verification notes.

---

## Validation Sign-Off

- [ ] All tasks have an automated verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (driver, state, test file, two harness views)
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for quick command
- [ ] `nyquist_compliant: true` set in frontmatter (after planner maps every task)

**Approval:** pending
