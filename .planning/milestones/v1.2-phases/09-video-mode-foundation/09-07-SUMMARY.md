---
phase: 09-video-mode-foundation
plan: 07
subsystem: video-mode-ui
tags: [video-mode, picker, geometry-reader, designkit, a11y, wave-3, swiftui]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: VideoModeStore + VideoModeLocation + EnvironmentValues.videoModeStore (Plan 09-02), App-root injection (Plan 09-03), 13 videoMode.* xcstrings keys (Plan 09-04), Settings VIDEO MODE card NavigationLink (Plan 09-06)
provides:
  - VideoLocationPickerView push-destination sub-screen (D-08)
  - Visual iPhone-outline picker per D-02 / D-09 / D-10
  - Wave 3 user-visible payoff (paired with Plan 09-06 — Settings card and picker land together)
  - GREEN flip for VideoLocationPickerViewTests (rows 09-04-01, 09-04-02)
  - Resolution of the 09-06 interim build error (SettingsView NavigationLink destination now valid)
affects: [09-08-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GeometryReader + .aspectRatio(9.0/19.5, contentMode: .fit) iPhone-outline layout — NOT SwiftUI Grid (zones are irregular: 2 full-width bands + 4 corners)"
    - "@Environment(\\.videoModeStore) EnvironmentKey read+write — Pitfall 2 lock (@Observable + @EnvironmentObject are incompatible)"
    - "Per-zone DesignKit-tokenized RoundedRectangle Button (theme.radii.chip) with conditional accentPrimary.opacity(0.25) fill — Pitfall 5 lock (label color is textPrimary, NOT accentPrimary, so Loud/Moody presets remain legible)"
    - "Screens/<feature>/ subdirectory pattern — Xcode 16 PBXFileSystemSynchronizedRootGroup auto-registers without pbxproj edit (CLAUDE.md §8.8)"
    - "Per-zone A11Y: .accessibilityLabel(localizedLabel) + .accessibilityValue (Selected / empty) + .accessibilityAddTraits(.isButton) + container .accessibilityElement(children: .contain) + container label (D-09)"

key-files:
  created:
    - gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift
  modified:
    - Docs/releases/v1.1.md

key-decisions:
  - "Combined Wave 3 release-log entry covers Plan 09-06 + 09-07 together — the user-visible payoff (Settings card + picker) lands as a single payable feature, so a single bullet under Internal changes is the right unit (CLAUDE.md §8.14 + §8.10 grouped-coherent-batch precedent)"
  - "Selected-zone label uses theme.colors.textPrimary, NOT theme.colors.accentPrimary — the Pitfall 5 (Loud preset) failure mode is text-on-accent-fill becoming illegible; locking the label to textPrimary pre-empts that. Visual audit lands in Plan 09-08"
  - "padding(.horizontal, theme.spacing.s) on the middle HStack is the ONLY padding call in the file body (excluding the wrapper VStack's padding(theme.spacing.l)) — both are token-based, the Pitfall 4 negative grep passes"

patterns-established:
  - "Pattern: Screens/<feature>/ subdirectory for push-destination sub-screens — fits alongside FullThemePickerView pattern (top-level Screens/) without crowding the parent folder when a feature has multiple sub-screens"
  - "Pattern: GeometryReader-driven irregular layout for visual pickers — proportions captured as local `let` (bandH / midH / cornerW / cornerH) so the relationship between zones reads at a glance; aspectRatio modifier on the outer GeometryReader locks 9.0/19.5"

requirements-completed: [VIDEO-02, VIDEO-14]

# Metrics
duration: 3min
completed: 2026-05-13
---

# Phase 09 Plan 07: VideoLocationPickerView Summary

**Visual iPhone-outline picker with 6 tappable PiP zones — push-destination sub-screen for the VIDEO MODE Settings card; closes Wave 3 alongside Plan 09-06 and flips `VideoLocationPickerViewTests` from RED to GREEN.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-13T02:46:49Z
- **Completed:** 2026-05-13 (same session)
- **Tasks:** 1 / 1 completed
- **Files created:** 1
- **Files modified:** 1 (Docs/releases/v1.1.md)

## Accomplishments

- New `gamekit/gamekit/Screens/VideoMode/` subdirectory with `VideoLocationPickerView.swift` (138 lines, well under the §8.5 500-line cap)
- Visual iPhone-outline picker rendered via `GeometryReader` + `.aspectRatio(9.0 / 19.5, contentMode: .fit)` (RESEARCH Topic 2 verdict — Grid was the rejected alternative because zones are irregular)
- All 6 `VideoModeLocation` cases referenced as tappable Button zones in the D-07 vocabulary:
  - `largeTop`: full-width band, top 25% of height
  - `smallTopLeft` / `smallTopRight`: 40% w × 22.5% h corners in the middle 50%
  - `smallBottomLeft` / `smallBottomRight`: 40% w × 22.5% h corners in the middle 50%
  - `largeBottom`: full-width band, bottom 25% of height
- Selected zone fills with `theme.colors.accentPrimary.opacity(0.25)` and shows the "Your video will go here" label (centered, `theme.colors.textPrimary` per Pitfall 5 lock so Loud/Moody presets remain legible)
- VIDEO-14 manual-selection explanation paragraph below the outline, sourced from `videoMode.manualSelectionExplanation` xcstrings key (D-10 verbatim copy)
- A11Y per D-09 fully wired: per-zone `.accessibilityLabel` (via `VideoModeLocation.localizedLabel`), `.accessibilityValue` reading "Selected" when chosen, `.accessibilityAddTraits(.isButton)`; container has `.accessibilityElement(children: .contain)` + container label from `videoMode.pickerContainerA11yLabel`
- `videoModeStore.location` writes happen immediately on zone tap — no Apply gesture (D-08 / D-11)
- `xcodebuild build` SUCCEEDED — the interim build error from Plan 09-06 (`VideoLocationPickerView()` reference with no symbol) is now resolved
- `xcodebuild test -only-testing:gamekitTests/VideoLocationPickerViewTests` SUCCEEDED — both `test_zone_tap_updates_location()` and `test_zone_a11y_labels()` flipped RED → GREEN
- Token discipline verified by static grep: zero literal `cornerRadius: <int>`, zero literal `padding(<int>)`, zero `@EnvironmentObject` for `VideoModeStore`, zero `foregroundColor`
- Zone layout proportions: **25% top band / 50% middle (4 corners, 40% w × 22.5% h each) / 25% bottom band** (proportions captured per the plan output requirement)

## Task Commits

1. **Task 1: Create VideoLocationPickerView with iPhone-outline GeometryReader picker + VIDEO-14 explanation paragraph + A11Y** — `1094a28` (feat)

**Plan metadata commit:** (pending — final commit lands after this SUMMARY.md + STATE.md + ROADMAP.md updates + v1.1.md release-log entry)

## Files Created/Modified

### Created (1 file)

- `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift` — 138 lines. Top-level `VideoLocationPickerView` (wrapper shape mirrors `FullThemePickerView.swift` — `ScrollView` + `VStack` + `.background(...)` + `.navigationTitle(...)` + `.navigationBarTitleDisplayMode(.inline)` push-destination) + private `iPhoneOutline` subview (GeometryReader proportions + zone(_:) ViewBuilder).

### Modified (1 file)

- `Docs/releases/v1.1.md` — appended combined Wave-3 (Plans 09-06 + 09-07) entry to Internal changes section per CLAUDE.md §8.14; one paragraph covering both the Settings card and the picker since they ship as one user-visible payoff.

### xcstrings Keys Consumed (4)

All 4 keys were shipped by Plan 09-04 — VideoLocationPickerView only reads them:

| Key                                       | Used At                                              |
| ----------------------------------------- | ---------------------------------------------------- |
| `videoMode.pickerTitle`                   | `.navigationTitle(...)`                              |
| `videoMode.pickerContainerA11yLabel`      | container `.accessibilityLabel(...)` on iPhoneOutline |
| `videoMode.zoneFillLabel`                 | "Your video will go here" Text inside selected zone  |
| `videoMode.manualSelectionExplanation`    | Paragraph below the outline                          |

`videoMode.location.*` keys (6 of them) are consumed transitively via `VideoModeLocation.localizedLabel` per-zone `.accessibilityLabel`.

## Decisions Made

- **Combined release-log entry for Wave 3.** Plans 09-06 and 09-07 ship the user-visible Video Mode entry point as a paired feature (the Settings card has nowhere to navigate to without the picker; the picker has no in-app entry point without the Settings card). One Internal-changes bullet under `Docs/releases/v1.1.md` covers both — CLAUDE.md §8.14 + §8.10's grouped-coherent-batch precedent.
- **Selected-zone label is `textPrimary`, not `accentPrimary`.** 09-RESEARCH Pitfall 5 flags the "accent text on accent fill" Loud-preset failure mode (Voltage's bright red on red, Dracula's purple on purple). Locking the label to `theme.colors.textPrimary` against the `accentPrimary.opacity(0.25)` zone fill pre-empts that. Visual audit on Classic + at least one Loud preset is Plan 09-08's deliverable.
- **`.padding(.horizontal, theme.spacing.s)` is the only inner padding call.** Required by RESEARCH Topic 2's skeleton to keep the corner zones off the outline edge. Token-based, so the §8.4 / Pitfall 4 token-discipline check passes (`! grep -E "padding\(\s*[0-9]"` holds).
- **No `#Preview` block in this file.** Adding one would require a `VideoModeStore` injection seam in the preview and would not exercise a code path the plan asks for. Plan 09-08 owns the visual theme audit (and a `#Preview` if it wants one).

## Deviations from Plan

None — plan executed exactly as written.

The plan's verify block uses `\\\\.videoModeStore` (4-backslash escape in shell grep) which my static-grep verification rewrote as `\\.videoModeStore` (the literal pattern that matches `@Environment(\.videoModeStore)` in the source). The on-disk source matches the plan's specified Swift form verbatim.

## Follow-ups (in-phase gap closure, 2026-05-12)

The Phase 9 human-verify audit during plan 09-08 surfaced two UX failures
with the iPhone-outline layout shipped here:

1. The full 9:19.5 outline + 6 absolute-positioned zones overflowed the
   screen on iPhone 17 Pro Max (vertical bands extended past the safe
   area, forcing scroll).
2. The 4 corner zones rendered inside the *middle* 50% of the outline
   suggested the wrong mental model — that a "Small" PiP is its own
   floating element, distinct from the two Large bands. The locked
   D-07 vocabulary actually treats `smallTopLeft`/`smallTopRight` as
   variations *inside* the Top band (and likewise for Bottom).

**In-phase fix (commit lands as `feat(09-07)` follow-on, not a new plan):**
- Rewrote `VideoLocationPickerView` as a vertical-stack picker:
  segmented `Large | Small` size toggle at top + two stacked bands
  (Top / Bottom). Large mode renders each band as a single tappable
  zone; Small mode places two corner buttons inside each band.
- Flipping the size toggle preserves the user's Top/Bottom half
  (`.largeBottom` ↔ `.smallBottomRight` shrink path matches D-03 spirit).
- Fits without scrolling on iPhone 17 Pro Max and SE — no `GeometryReader`,
  band heights derived from `theme.spacing.xxl` multipliers (token-only).
- 3 additive xcstring keys: `videoMode.locationPicker.sizeLarge`,
  `videoMode.locationPicker.sizeSmall`, `videoMode.locationPicker.sizeA11yLabel`.
  The six `videoMode.location.*` zone-label keys are unchanged (D-07 lock).
- `VideoLocationPickerView`'s public surface is unchanged (still
  push-destination, still reads `@Environment(\.videoModeStore)`, still
  no NavigationStack wrapper). The 09-06 Settings card NavigationLink
  destination continues to compile against `VideoLocationPickerView()`.
- `VideoLocationPickerViewTests` updated: the 2 original tests (`test_zone_tap_updates_location`,
  `test_zone_a11y_labels`) preserved with broader assertion; 2 new tests
  added (`test_size_toggle_derivation_matches_store_location`,
  `test_size_flip_preserves_vertical_half`) pin the size-derivation and
  half-preservation rules. All 4 GREEN on iPhone 16 Pro / iOS 18.5.
- `VideoModeLocation` enum LOCKED (D-07): 6 cases, no `largeMiddle`,
  raw values unchanged — UserDefaults migration not required.
- Token discipline holds: zero literal `cornerRadius: <int>`, zero
  literal `padding(<int>)`, zero `foregroundColor`, zero
  `@EnvironmentObject` references for `VideoModeStore` (negative grep
  passes). Selected-zone label remains `theme.colors.textPrimary` per
  Pitfall 5 lock.
- Release-log entry under `Docs/releases/v1.1.md` Fixes section (the
  current `MARKETING_VERSION` is still 1.1; Phase 13 ships the bump).

**Net effect on Phase 9:** unblocks the 09-08 visual-audit human-verify
checkpoint that flagged the original layout. The orchestrator will
re-present the 09-08 audit checkpoint for re-verification after this
follow-up lands.

## Issues Encountered

None.

The plan also called out a "pre-commit hook (Screens/ token discipline)" in the verification list — inspection of `.git/hooks/` shows only `.sample` files (no active pre-commit hook installed). The token-discipline checks have been verified manually via the negative-grep block from the plan's verify section instead. This matches the CLAUDE.md §2 "no hardcoded colors / radii / spacing" rule directly, so the absent hook is not a gate failure.

## Pre-existing Working Tree State (untouched)

- `M gamekit/gamekit/Resources/Localizable.xcstrings` — drawer-redesign work; left alone per execution-context instructions.
- `?? .claude/` — untracked tooling directory; left alone.

## User Setup Required

None. The picker is reachable via the existing in-app surface (Settings → VIDEO MODE → toggle On → "Video location: <label>" row → push).

## Next Phase Readiness

- **Plan 09-08 (final Wave 4)** can now run the visual theme audit on Classic + Voltage/Dracula presets per CLAUDE.md §8.12, the SC5 regression sweep, and close the phase with a release-log entry.
- **Wave 3 closes here.** Settings card (09-06) + picker (09-07) ship as one user-visible payoff; both compile, both test-green, no interim build errors remaining.
- All Plan 09-01 Wave 0 RED gates are now GREEN with the exception of `SC5RegressionTests.test_off_state_byte_identical` (placeholder by design per CONTEXT D-15) and the manual-only verification rows (09-06-02 #Preview canvas sign-off).

**No blockers.**

---
*Phase: 09-video-mode-foundation*
*Completed: 2026-05-13*

## Self-Check: PASSED

- File exists on disk: `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift` — verified via `test -f`.
- Commit `1094a28` present in `git log --oneline -5` — verified.
- `xcodebuild build` SUCCEEDED — verified live.
- `xcodebuild test -only-testing:gamekitTests/VideoLocationPickerViewTests` SUCCEEDED with 2 passes — verified live.
- Pre-existing `Localizable.xcstrings` working-tree modification preserved (not staged, not committed) — verified via `git status --short`.
