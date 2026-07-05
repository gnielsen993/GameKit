---
phase: 13
plan: 01
subsystem: core/video-mode/banner
tags: [video-mode, banner, a11y, haptics-gating, shared-primitive, swift-testing]
requires:
  - VideoModeLocation (existing 6-case PiP-zone enum)
  - SettingsStore.hapticsEnabled / animationsEnabled (existing v1.0 toggles)
  - DesignKit DKButton + Theme tokens (theme.colors / theme.radii / theme.typography / theme.spacing)
provides:
  - VideoModeBannerEdge / VideoModeBannerAlignment / VideoModeBannerAnchor enum + struct trio
  - VideoModeBannerRouter.anchor(for:) — exhaustive 6-zone D-09 anchor table
  - VideoModeBannerContent PoD struct (C-02 LOCKED, 6 fields)
  - VideoModeBanner SwiftUI view (C-01 LOCKED, shared in Core/)
  - VideoModeBanner.playEntranceHaptic() — D-13-HAPTICS FIRST-guard firing surface
  - View.videoModeBannerTransition(reduceMotion:animationsEnabled:) — D-13-ANIM helper
affects:
  - .planning/phases/13-win-loss-banner-a11y-gating/13-02-PLAN.md (Wave 2 Minesweeper adoption depends on these primitives)
  - .planning/phases/13-win-loss-banner-a11y-gating/13-03-PLAN.md (Wave 2 Merge adoption)
  - .planning/phases/13-win-loss-banner-a11y-gating/13-04-PLAN.md (Wave 2 Nonogram adoption)
tech-stack:
  added: []                       # no new deps — DesignKit + Swift Testing only
  patterns:
    - foundation-only-helper (VideoModeBannerAnchor mirrors VideoModeSlotRouter shape)
    - first-guard-gated-haptic (mirrors v1.0 05-03 D-10 Haptics.playAHAP contract)
    - per-surface-reduce-motion-collapse (mirrors v1.0 05-06 D-04)
    - pod-content-struct (over @ViewBuilder slots) for compile-time field checklist
    - exhaustive-switch-on-VideoModeLocation (compile-time safety net for v1.3+ 7th case)
key-files:
  created:
    - gamekit/gamekit/Core/VideoModeBannerAnchor.swift (87 LOC)
    - gamekit/gamekit/Core/VideoModeBannerContent.swift (62 LOC)
    - gamekit/gamekit/Core/VideoModeBanner.swift (157 LOC)
    - gamekit/gamekitTests/Core/VideoModeBannerAnchorTests.swift (7 tests)
    - gamekit/gamekitTests/Core/VideoModeBannerHapticsGateTests.swift (4 tests)
  modified:
    - Docs/releases/v1.2.md (appended "Internal changes (13)" section per CLAUDE §0.3 + §8.14)
decisions:
  - "C-01: VideoModeBanner shipped as SHARED view in Core/, not per-game (3-game consumer threshold met)"
  - "C-02: PoD VideoModeBannerContent struct (not @ViewBuilder) — single-action lock baked in by absence of a second-button slot"
  - "C-03: Dedicated VideoModeBannerAnchor helper, NOT a SlotAnchorMap field — edge+alignment semantics don't fit the 4-corner SlotAnchor enum"
  - "D-13-HAPTICS encoded in playEntranceHaptic() with `guard hapticsEnabled else { return }` as line 1 (FIRST-guard mirror of v1.0 05-03 D-10 Haptics.playAHAP)"
  - "D-13-ANIM encoded in videoModeBannerTransition(reduceMotion:animationsEnabled:) — collapses to `.identity` when either dimming source is on"
  - "Banner surface stays NEUTRAL (theme.colors.surface fill + theme.colors.border stroke) — win/loss differentiation lives in title color only (success/danger). Avoids per-preset contrast pass."
metrics:
  duration_minutes: ~25
  completed_date: 2026-05-14
---

# Phase 13 Plan 01: VideoModeBanner Shared Primitive Summary

Shared SwiftUI banner pill + Foundation-only anchor router + PoD content struct that all 3 Video-Mode-adopter games (Mines, Merge, Nonogram) will consume in Wave 2. Closes UI-SPEC C-01 (shared in `Core/`), C-02 (PoD struct), and C-03 (dedicated anchor helper) as compile-time-verifiable artifacts before any game integrates.

## What shipped

### `gamekit/gamekit/Core/VideoModeBannerAnchor.swift` (87 LOC, Foundation-only)
- `VideoModeBannerEdge` enum: `.top` / `.bottom`
- `VideoModeBannerAlignment` enum: `.leading` / `.trailing` / `.fullWidth`
- `VideoModeBannerAnchor` struct: `edge` + `alignment`, Sendable + Equatable
- `VideoModeBannerRouter.anchor(for:)`: exhaustive switch on `VideoModeLocation` returning the row from the D-09 anchor table:
  - `largeTop` → `(bottom, fullWidth)`
  - `largeBottom` → `(top, fullWidth)`
  - `smallTopLeft` → `(bottom, trailing)`
  - `smallTopRight` → `(bottom, leading)`
  - `smallBottomLeft` → `(top, trailing)`
  - `smallBottomRight` → `(top, leading)`
- No `default:` case — adding a 7th `VideoModeLocation` in v1.3+ fires a compile error here (mirrors `VideoModeSlotRouter` precedent).

### `gamekit/gamekit/Core/VideoModeBannerContent.swift` (62 LOC, Foundation-only)
PoD struct with the C-02 LOCKED shape:
```swift
struct VideoModeBannerContent: Sendable {
    enum Outcome: Sendable, Equatable { case win, loss }
    let outcome: Outcome
    let title: String
    let subtitle: String?
    let primaryButtonLabel: String
    let accessibilityLabel: String
    let onPrimary: () -> Void
}
```
Nested `Outcome` (intentionally distinct from the top-level `Core/Outcome.swift` raw-string persistence enum) is the presentation distinction that drives win/loss title tint + haptic cue.

### `gamekit/gamekit/Core/VideoModeBanner.swift` (157 LOC, SwiftUI)
- `RoundedRectangle(cornerRadius: theme.radii.button)` filled `theme.colors.surface`, stroked `theme.colors.border` 1pt hairline.
- `HStack(spacing: theme.spacing.s)` — title leading `VStack` (title + optional subtitle) + `Spacer(minLength: theme.spacing.s)` + exactly ONE `DKButton(...)` trailing with `.fixedSize()` so the CTA hugs its label and the title takes remaining width.
- Title: `theme.typography.title`, color = `theme.colors.success` (win) / `theme.colors.danger` (loss). Subtitle (when non-nil): `theme.typography.body` / `theme.colors.textSecondary`.
- Outer `.padding(.horizontal, theme.spacing.m)`, inner `.padding(theme.spacing.l)`.
- `playEntranceHaptic()` line 1 is `guard hapticsEnabled else { return }` — D-13-HAPTICS FIRST-guard mirror of v1.0 05-03 D-10.
- Declarative `.sensoryFeedback(content.outcome == .win ? .success : .error, trigger: hapticsEnabled ? hapticTrigger : 0)` — defense-in-depth on top of the explicit-call FIRST-guard.
- `.accessibilityElement(children: .combine)` + `.accessibilityLabel(content.accessibilityLabel)` + `.accessibilityAddTraits(.isHeader)` on the title.
- `.onAppear` posts `UIAccessibility.post(.announcement, argument: content.accessibilityLabel)` (mirrors v1.0 EndStateCard VoiceOver convention).
- `View.videoModeBannerTransition(reduceMotion:animationsEnabled:)` extension: `.transition(.identity)` when either is true; `.transition(.opacity)` otherwise.

### Tests (Swift Testing, `@MainActor`, 11 cases total)
- `VideoModeBannerAnchorTests` (7 tests) — one per zone + exhaustiveness loop. Every assertion uses literal `(edge, alignment)` values from the D-09 table.
- `VideoModeBannerHapticsGateTests` (4 tests) — `hapticsEnabled=false` early-return shape (D-13-HAPTICS FIRST-guard), `hapticsEnabled=true` no-crash, win-outcome propagation, loss-outcome propagation. Uses canonical `Theme.resolve(preset: .classicMuted, scheme: .light)` fixture mirroring `VideoCompactControlRow.swift:103` preview pattern.

## How the design decisions landed in code

| UI-SPEC reference | Code line | Verification |
|---|---|---|
| C-01 shared view in Core/ | `gamekit/gamekit/Core/VideoModeBanner.swift` (NOT per-game) | File path |
| C-02 PoD struct (6 fields) | `VideoModeBannerContent.swift` lines 27-51 | Struct member count |
| C-03 dedicated anchor helper | `VideoModeBannerAnchor.swift` exists as new file; `SlotAnchorMap` left untouched | `git diff` shows zero changes to `VideoModeSlotRouter.swift` |
| D-09 anchor table (6 zones) | `VideoModeBannerRouter.anchor(for:)` switch lines 64-83 | `VideoModeBannerAnchorTests` 7 GREEN |
| D-10 pill shape | `.background(RoundedRectangle(cornerRadius: theme.radii.button) ...)` | `grep theme.radii.button` returns 3 |
| D-11 single explicit DKButton | One `DKButton(...)` invocation in body, no tap gesture on banner surface | `grep -c 'DKButton('` returns exactly 1 |
| D-12 / D-13-ANIM Reduce Motion | `videoModeBannerTransition(reduceMotion:animationsEnabled:)` extension | Transition collapses to `.identity` when either is true |
| D-13-HAPTICS FIRST-guard | `playEntranceHaptic()` line 1 = `guard hapticsEnabled else { return }` | `VideoModeBannerHapticsGateTests.playEntranceHaptic_disabled_doesNotCrash` GREEN |

## Verification

```
xcodebuild -project gamekit.xcodeproj -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:gamekitTests/VideoModeBannerAnchorTests test
→ ** TEST SUCCEEDED **  (7 tests GREEN)

xcodebuild ... -only-testing:gamekitTests/VideoModeBannerHapticsGateTests test
→ ** TEST SUCCEEDED **  (4 tests GREEN)

xcodebuild ... build
→ ** BUILD SUCCEEDED **
```

Acceptance-criteria grep audit (all green):
- `DKButton(` count in `VideoModeBanner.swift` = **1** (single-action lock)
- `guard hapticsEnabled else { return }` count = **2** (function body + doc-comment anchor — function body is the runtime guard)
- Hardcoded color/cornerRadius/padding literal count = **0** (FOUND-07 token-discipline hook reapplied)
- `foregroundColor` count = **0** (CLAUDE.md §8.6 — `.foregroundStyle` only)
- `default:` count in anchor router = **0** (exhaustive switch invariant preserved)
- `import SwiftUI` count in Foundation-only files = **0** for both `VideoModeBannerAnchor.swift` and `VideoModeBannerContent.swift`
- File LOC: 87 / 62 / 157 — all comfortably under CLAUDE.md §8.5 ≤500 cap

## Deviations from Plan

None — plan executed exactly as written. The plan template was followed verbatim with one substantive implementation refinement:

**Refinement (within plan's spec, NOT a deviation):** `DKButton` inside the HStack is wrapped with `.fixedSize()` so the CTA hugs its label width. DKButton declares `frame(maxWidth: .infinity)` internally for full-row contexts (intro flow, MinesweeperEndStateCard); inside this banner's HStack with a leading title `VStack`, the natural-width behavior is the correct read of the UI-SPEC "title leading, CTA trailing" requirement. Matches the `IntroFlowView.swift:88` `.frame(width: 140)` pattern in spirit — natural CTA size, title takes remaining row width.

**Auto-fix attempts:** 0. No bugs, missing critical functionality, or blocking issues discovered during execution. No Rule 1/2/3 events.

## Auth Gates

None. This plan introduces no network surface, no auth, no third-party SDK.

## Threat Flags

None. All threat-register entries from the plan's `<threat_model>` are satisfied as written:
- **T-13-01 (Tampering, banner haptic surface)** — mitigated via `guard hapticsEnabled else { return }` as line 1 of `playEntranceHaptic()`; both branches unit-tested.
- **T-13-02 (Repudiation, banner CTA dispatch)** — accepted as planned; `onPrimary` is a direct closure invocation, same trust model as existing EndStateCard `onRestart`.
- **T-13-03 (Info Disclosure, UIAccessibility.announcement)** — accepted as planned; banner posts the pre-composed `content.accessibilityLabel` that the per-game adopter builds (no PII; same payload as v1.0 EndStateCard).
- **T-13-04 (DoS, banner entrance animation)** — mitigated via `videoModeBannerTransition(reduceMotion:animationsEnabled:)` collapsing to `.identity` when either dimming source is on.

No new surface introduced outside the plan's threat model.

## Self-Check

Verified files exist:
- FOUND: `gamekit/gamekit/Core/VideoModeBannerAnchor.swift` (87 LOC)
- FOUND: `gamekit/gamekit/Core/VideoModeBannerContent.swift` (62 LOC)
- FOUND: `gamekit/gamekit/Core/VideoModeBanner.swift` (157 LOC)
- FOUND: `gamekit/gamekitTests/Core/VideoModeBannerAnchorTests.swift` (7 tests, all GREEN)
- FOUND: `gamekit/gamekitTests/Core/VideoModeBannerHapticsGateTests.swift` (4 tests, all GREEN)

## Self-Check: PASSED
