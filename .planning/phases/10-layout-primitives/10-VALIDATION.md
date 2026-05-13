---
phase: 10
slug: layout-primitives
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-12
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Inherits P9 sampling rhythm. Source: `10-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test` macros) + XCTest host (existing v1.0 / v1.2 setup) |
| **Config file** | `gamekit/gamekit.xcodeproj` (gamekitTests target) — no new config |
| **Quick run command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:gamekitTests/VideoModeAwareTests -only-testing:gamekitTests/VideoModeSlotRouterTests` |
| **Full suite command** | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | quick ~15s · full ~95s |

> Device note: Phase 9 used "iPhone 17 Pro Max". Either fine — band fraction is
> device-independent (10-RESEARCH.md §Band Measurement).

---

## Sampling Rate

- **After every task commit:** Run quick run command (~15s)
- **After every plan wave:** Run full suite command (~95s)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

> Task IDs are placeholders pending PLAN.md task numbering. Update during plan-phase.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-00-* | 00 | 0 | (Wave 0 test stubs) | — | N/A | unit (RED) | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests` (expected FAIL) | ❌ W0 | ⬜ pending |
| 10-01-* | 01 | 1 | VIDEO-05 | — | N/A | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeSlotRouterTests/test_smallTopLeft_anchors` (+ 3 siblings: TR / BL / BR) | ❌ W0 | ⬜ pending |
| 10-01-* | 01 | 1 | VIDEO-06 (band) | — | N/A | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_largeTop_reservesBand` (+ largeBottom) | ❌ W0 | ⬜ pending |
| 10-01-* | 01 | 1 | VIDEO-06 (compactness) | — | N/A | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_onState_normal` (+ collapsedSettings + reducedTime) | ❌ W0 | ⬜ pending |
| 10-01-* | 01 | 1 | VIDEO-13 | — | N/A (no auth surface) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_offState_doesNotPublishCompactness` | ❌ W0 | ⬜ pending |
| 10-01-* | 01 | 1 | SC4 adoption API | — | N/A | smoke (build) | `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — compile passes IFF `.videoModeAware(minBoardHeight:)` extension exists | n/a (build) | ⬜ pending |
| 10-02-* | 02 | 2 | SC5 legibility | — | N/A | manual (Xcode canvas) | n/a — 12-tile `#Preview` matrix, manual sign-off in `10-VERIFICATION.md` | n/a (manual) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gamekit/gamekitTests/Core/VideoModeAwareTests.swift` — RED stubs for VIDEO-06 + VIDEO-13 (band reservation, compactness levels, off-state byte-identical). Includes `renderAndCapture(...)` env-probe helper.
- [ ] `gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift` — RED stubs for VIDEO-05 (24 anchor assertions across 6 zones × 4 slots).
- [ ] No framework install needed — Swift Testing already in use (verified via `VideoModeStoreTests.swift:22-25`).
- [ ] No shared fixtures needed — each test uses isolated `UserDefaults(suiteName:)` per `VideoModeStoreTests.makeIsolatedDefaults()` pattern.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SC5 legibility on Classic + Dracula across 6 PiP zones | (CLAUDE.md §8.12) | `#Preview` rendering is a visual property — chip / picker / info text legibility under preset color cannot be asserted automatically without snapshot-image diff infra (not in scope per CLAUDE.md §2 "no speculative tooling"). | Open `VideoModeAware.swift` in Xcode → Canvas → step through all 12 named previews (6 zones × {Classic, Dracula}). Confirm: chips legible, picker non-clipped, no covered corner, board within reserved band on Large zones. Sign off in `10-VERIFICATION.md`. |
| Off-restore on running stub | VIDEO-13 / SC3 | Unit test asserts structural invariant (compactness env stays `.normal` when `isEnabled == false`); a live-toggle behavioral check (no visual residue between on→off) requires running app + flipping Settings toggle. | Build & run on iPhone 17 Pro simulator → open stub `#Preview` runtime or temporary in-app surface → toggle Video Mode On → confirm reserved band appears → toggle Off → confirm immediate reversion (no relaunch). Document in `10-VERIFICATION.md`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
