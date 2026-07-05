---
phase: 10-layout-primitives
plan: 03
subsystem: ui-modifier
tags: [swiftui, view-modifier, environment-key, safe-area-inset, video-mode, tdd-green]

# Dependency graph
requires:
  - phase: 10-layout-primitives
    plan: 01
    provides: VideoModeAwareTests.swift (4 RED assertions — off-state + 3 compactness levels), 0.32 / 0.85 / 24pt locked literals, renderAndCapture probe helper
  - phase: 09-video-mode-foundation
    provides: VideoModeStore (@Observable), EnvironmentValues.videoModeStore env-key, VideoModeLocation enum, VideoCompactControlRow component
provides:
  - gamekit/gamekit/Core/VideoModeAware.swift (modifier + extension + compactness enum + custom EnvironmentKey + 12-tile #Preview matrix)
  - SC4 adoption surface — `.videoModeAware(minBoardHeight:)` chainable extension proven compile-clean
  - SC5 manual audit surface — 12 #Preview tiles (6 zones × Classic + Dracula)
  - VIDEO-06 production source (band reservation + compactness publication)
  - VIDEO-13 production source (off-restore short-circuit, byte-identical to un-wrapped on Off)
affects: [10-04, 11-mines-adoption, 12-merge-nonogram-adoption, 13-win-loss-banner]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ViewModifier with @Environment(\\.videoModeStore) reading @Observable store at body() top — per-property tracking sees the read at the correct scope (CONTEXT D-04 / Pitfall 2)"
    - "Hard short-circuit via AnyView(content) on off-path — byte-identical to un-wrapped tree (CONTEXT D-05; D-13)"
    - ".safeAreaInset(edge: .top/.bottom) with Color.clear.frame(height:) sized at proxy.size.height * 0.32 — native band reservation, shrinks descendant available height without manual frame math (CONTEXT D-08; D-09)"
    - "Exhaustive switch on VideoModeLocation in both applyBand and bandHeight — NO default: case so adding a 7th zone is a compile-time error (CONTEXT §code_context)"
    - "Custom EnvironmentKey with .normal default → safe baseline for descendants without an ancestor; matches VideoModeStoreKey / SettingsStoreKey shapes (P9 precedent)"
    - "12 named #Preview blocks scrubbable in Xcode canvas — no DEBUG screen, no HomeView dev hook (CONTEXT D-16; P9 D-04 precedent)"
    - "Theme.resolve(preset:scheme:) used in preview helpers — same canonical resolver SettingsView reads at runtime (Shared Pattern 4)"

key-files:
  created:
    - gamekit/gamekit/Core/VideoModeAware.swift
  modified:
    - gamekit/gamekitTests/Core/VideoModeAwareTests.swift  # test-infra fix: attach UIWindow so onAppear fires

key-decisions:
  - "0.85× collapsedSettingsRatio threshold locked in production source matching Plan 10-01 RED test literal — if changed, all 3 compactness tests break."
  - "compactRowHeight = 24 CGFloat constant cites theme.spacing.xl in comment (A1 fallback). No Theme env-key on iOS 17; threading would force every adopter call site to pass it. If DesignKit later exposes @Environment(\\.theme), constant can be deleted."
  - "AnyView(content) on off-path accepted — single per-game wrap, type-erasure cost negligible (10-RESEARCH §AnyView Anti-Patterns)."
  - "12 #Preview tiles use ForEach-free named blocks per CONTEXT D-16 — scrubbable per-tile audit benefit beats DRYness."
  - "renderAndCapture test helper required UIWindow attachment fix — UIHostingController whose view is unattached to a UIWindow does not fire .onAppear; captureBox stayed nil and 3 on-state tests previously passed by accident on env default."

# Performance / Verification

verification:
  - xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' → ** BUILD SUCCEEDED **
  - xcodebuild test -scheme gamekit -only-testing:gamekitTests/VideoModeAwareTests -only-testing:gamekitTests/VideoModeSlotRouterTests → ** TEST SUCCEEDED **
    - VideoModeAwareTests: 4/4 passing (off-state, normal, collapsedSettings, reducedTime)
    - VideoModeSlotRouterTests: 7/7 passing (still GREEN — Plan 10-02 unaffected)
  - 12 named #Preview blocks present (grep -c "^#Preview(" → 12); file 329 lines (within plan 230–400 range)
  - No project.pbxproj edits — PBXFileSystemSynchronizedRootGroup auto-registered per CLAUDE.md §8.8
  - No Color literals in production source or preview helpers — token discipline carries through

# Issues encountered

issues:
  - title: "renderAndCapture probe captureBox stayed nil → 3 on-state tests passing by accident"
    detail: |
      Plan 10-01's renderAndCapture mounts the modifier in a UIHostingController, layouts it,
      and waits 0.05s for SwiftUI to publish the env value via a Color.clear().onAppear probe.
      But onAppear does NOT fire when the hosting controller's view is unattached to a
      UIWindow. captureBox stayed nil; all 4 tests read the env DEFAULT (.normal) and the
      off-state test passed by accident while masking the 3 on-state assertions.
    resolution: |
      Attach the hosting controller to a transient off-screen UIWindow before the layout
      pass; detach after capture. Committed as `test(10-01)` fixup against the helper from
      Plan 10-01. All 4 modifier tests now fire onAppear and assert against the modifier's
      published value rather than the env default.
  - title: "SourceKit indexer reports 'No such module DesignKit' / 'Testing'"
    detail: |
      Xcode SourceKit (the live indexer) sometimes lags behind the build system on freshly
      created files in the synchronized root group. Real xcodebuild build + test succeed —
      the noise is editor-only.
    resolution: |
      Informational. Will resolve on next IDE rebuild. Not a blocker.

# Plan deviations

deviations: []  # None — file body matches plan <action> verbatim except for the test-helper window-attach fix already documented above.

## Task Commits

- e2bbc18 — feat(10-03): add VideoModeAware modifier + compactness env-key (Task 1)
- 1a6720b — test(10-01): attach UIWindow so renderAndCapture probe fires onAppear (test-infra fix prerequisite for GREEN flip)
- 9e8ceae — feat(10-03): append #Preview matrix (6 zones x Classic+Dracula = 12 tiles) (Task 2)

## Headline

**VideoModeAware ViewModifier + compactness env-key + 12-tile preview matrix shipped — VideoModeAwareTests turn GREEN (4/4), VIDEO-06 + VIDEO-13 production source landed, Phases 11/12 adoption is now a one-line `.videoModeAware(minBoardHeight:)` call away.**
