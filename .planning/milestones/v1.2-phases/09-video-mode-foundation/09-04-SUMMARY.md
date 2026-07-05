---
phase: 09-video-mode-foundation
plan: 04
subsystem: localization
tags: [xcstrings, l10n, video-mode, wave-2, video-14, copy-lock]

# Dependency graph
requires:
  - phase: 09-video-mode-foundation
    provides: 09-01 LocalizableCatalogTests RED gate (13-key contract) + 09-02 VideoModeLocation.localizedLabel accessor that reads `videoMode.location.<case>` keys
provides:
  - 13 `videoMode.*` keys in Localizable.xcstrings (all with `state: "translated"`, `extractionState: "manual"`)
  - VIDEO-14 verbatim manual-selection-explanation copy locked at the resource layer (D-10)
  - 6 zone labels (D-09 a11y vocabulary) now resolvable by `VideoModeLocation.localizedLabel` instead of raw-key fallback
  - LocalizableCatalogTests.test_videoMode_copy_keys_exist flipped RED -> GREEN
affects: [09-05-PLAN, 09-06-PLAN, 09-07-PLAN, 09-08-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "xcstrings catalog atomic key drop — all N keys for a feature land in ONE commit (09-RESEARCH Pitfall 3 + 09-PATTERNS §7 Pitfall 3); avoids silent-fallback failure mode when L10N-V2 adds a second locale"
    - "Manual extractionState + state: translated for hand-authored keys (vs Xcode's auto-extracted `state: new`) — marks EN value as ship-ready per FOUND-05"

key-files:
  created: []
  modified:
    - gamekit/gamekit/Resources/Localizable.xcstrings
    - Docs/releases/v1.1.md

key-decisions:
  - "Added 13 keys (not 11 as frontmatter `truths` field said, not 12 as plan body said) — LocalizableCatalogTests.requiredVideoModeKeys is the canonical source of truth (13-item array). The plan body explicitly notes the count is approximate; the test contract is authoritative."
  - "Kept the pre-existing drawer-related working-tree changes (`2048 · Classic`, `Drawer open. Tap a mode to play…`, `Infinite · Endless`, `Tap to open drawer and choose a mode.`) UNCOMMITTED — they are unrelated to Plan 09-04 and per CLAUDE.md §8.10 must not be bundled into the videoMode feature commit. Workflow: saved them off, reset xcstrings to HEAD, applied videoMode-only edit, committed, then re-applied drawer hunks to the working tree."
  - "Inserted videoMode.* keys alphabetically between `Version` and `Win` to match the catalog's natural sort order. xcstrings does not load-bear on insertion order (Xcode re-sorts on save), but matching convention keeps `git diff` reviewable."
  - "Used `extractionState: manual` + `state: translated` for all 13 keys (NOT `new`) — the `new` state triggers Xcode's translation-pending indicator; `translated` marks the EN value as ship-ready, matching FOUND-05's EN-only-at-v1 ship discipline."

patterns-established:
  - "Pattern: feature-prefix key namespace (`videoMode.<segment>`) — all 13 keys cluster under the prefix, making future grep / removal trivial and avoiding name collisions with generic single-word keys like `Version` / `Done`."
  - "Pattern: re-apply unrelated working-tree hunks via `git apply` after a feature-scoped commit — lets a session preserve in-flight user work while keeping commits atomic per CLAUDE.md §8.10."

requirements-completed: [VIDEO-14, VIDEO-02]

# Metrics
duration: 3min
completed: 2026-05-12
---

# Phase 09 Plan 04: videoMode.* Localization Catalog Drop Summary

**13 `videoMode.*` keys landed in Localizable.xcstrings as one atomic edit; VIDEO-14 verbatim copy now locked at the resource layer; LocalizableCatalogTests flipped RED → GREEN.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-13T01:21:25Z
- **Completed:** 2026-05-13T01:24:01Z
- **Tasks:** 1 / 1 completed
- **Files modified:** 2 (Localizable.xcstrings + Docs/releases/v1.1.md)

## Accomplishments

- All 13 required `videoMode.*` keys added in one atomic catalog edit per 09-RESEARCH Pitfall 3 (key explosion = single-commit discipline)
- VIDEO-14 verbatim copy (D-10) — `"Pick where your video is on screen — GameDrawer can't detect it automatically. Choose the zone closest to your video to keep the board and controls clear."` — locked at the catalog level. Em-dash, contraction `can't`, and brand `GameDrawer` all preserved.
- 6 zone labels (`videoMode.location.{largeTop, largeBottom, smallTopLeft, smallTopRight, smallBottomLeft, smallBottomRight}`) match `VideoModeLocation` enum raw values exactly; `VideoModeLocation.localizedLabel` (from Plan 09-02) now resolves to real strings instead of raw-key fallback
- LocalizableCatalogTests.test_videoMode_copy_keys_exist flipped RED → GREEN (VALIDATION row 09-05-01 satisfied)
- JSON validity preserved (`python3 -m json.tool` exits 0); diff is additive-only (156 lines inserted, 0 deletions)

## Task Commits

1. **Task 1: Add 13 videoMode.* keys to Localizable.xcstrings in one atomic edit** — `f2beac8` (feat)

## Files Created/Modified

### Modified

- `gamekit/gamekit/Resources/Localizable.xcstrings` — 13 new keys clustered alphabetically between `Version` and `Win`:

  | Key | EN Value |
  |-----|----------|
  | `videoMode.sectionHeader` | `VIDEO MODE` |
  | `videoMode.toggleLabel` | `Video Mode` |
  | `videoMode.locationRowTitle` | `Video location: %@` |
  | `videoMode.location.largeTop` | `Large top` |
  | `videoMode.location.largeBottom` | `Large bottom` |
  | `videoMode.location.smallTopLeft` | `Small top-left` |
  | `videoMode.location.smallTopRight` | `Small top-right` |
  | `videoMode.location.smallBottomLeft` | `Small bottom-left` |
  | `videoMode.location.smallBottomRight` | `Small bottom-right` |
  | `videoMode.pickerTitle` | `Video location` |
  | `videoMode.pickerContainerA11yLabel` | `Video location picker, choose where your video will appear` |
  | `videoMode.zoneFillLabel` | `Your video will go here` |
  | `videoMode.manualSelectionExplanation` | `Pick where your video is on screen — GameDrawer can't detect it automatically. Choose the zone closest to your video to keep the board and controls clear.` |

- `Docs/releases/v1.1.md` — appended Plan 09-04 bullet under "Internal changes" (per CLAUDE.md §0.3 / §8.14)

### Catalog line-count delta

`+156` insertions, `0` deletions. JSON re-parse exits 0; xcstringstool compile (during `xcodebuild test`) succeeds.

## Decisions Made

- **13 keys, not 11/12** — Plan frontmatter `truths` says "11 videoMode.* keys"; plan body table is 13 rows but its own footer says "12 keys total"; the canonical contract is `LocalizableCatalogTests.requiredVideoModeKeys` (line 45-59 of LocalizableCatalogTests.swift) which is an explicit 13-string array. The plan body anticipated this drift ("treat that as approximate — actual count is 12") and the GREEN test result confirms 13 is correct. Followed the test.
- **Insertion point: between `Version` and `Win` (line 980-area)** — matches catalog's case-insensitive alphabetical sort. xcstrings catalogs are re-sorted by Xcode on save anyway, but matching convention keeps `git diff` reviewable.
- **`state: "translated"`, not `"new"`** — the `new` state is Xcode's "translation pending" marker for auto-extracted strings. Manual-authored keys with locked EN copy should ship as `translated` (FOUND-05: EN-only at v1, so EN is the canonical complete state).
- **Atomic commit per CLAUDE.md §8.10 + 09-RESEARCH Pitfall 3** — splitting these 13 keys across multiple plans would create a silent-fallback failure mode: once L10N-V2 adds a second locale, missing-key lookups would return the raw key name (e.g. "videoMode.location.largeTop") instead of "Large top", but that only surfaces in non-EN locales. Single-commit drop avoids this entirely.
- **Pre-existing drawer-related working-tree mods preserved out-of-band** — `2048 · Classic`, `Drawer open. Tap a mode to play, or tap again to close.`, `Infinite mode → Infinite · Endless`, and `Tap to open drawer and choose a mode.` were already in the working tree (drawer-redesign work from the v1.1 build). They are NOT in scope for Plan 09-04 and would violate CLAUDE.md §8.10 if bundled into the videoMode commit. Workflow: saved diff to `/tmp/full-xcstrings.patch`, `git checkout HEAD -- xcstrings` to reset, edited only the videoMode region, committed, then `git apply` the drawer-only hunks back to the working tree (now unstaged). The user's drawer work is preserved verbatim and will land in its own future commit.

## Deviations from Plan

None — plan executed exactly as written.

The plan body explicitly authorized 13 keys (its action table lists 13 rows even though the footer math says 12) and called out that the `truths` field was approximate. The test contract (13 keys) is the authoritative count; following it is plan-compliant, not a deviation.

## Issues Encountered

- **Working tree had unrelated drawer-redesign edits in `Localizable.xcstrings`** carried from a prior session. Resolved by extracting them out-of-band (saved patch, reset to HEAD, applied videoMode-only edit, committed, re-applied drawer hunks to working tree). Drawer changes remain unstaged and will commit separately as part of the drawer-redesign feature. Did NOT contaminate the Plan 09-04 commit.

## TDD Gate Compliance

This plan is type `auto` with `tdd="true"` on its single task. The plan-level TDD cycle is satisfied by the cross-plan RED/GREEN sequence:

1. **RED gate (Plan 09-01):** `LocalizableCatalogTests.test_videoMode_copy_keys_exist` shipped with 13-key contract; failed loudly because keys didn't exist. Confirmed RED at start of this plan's execution (`** TEST FAILED **` on first `xcodebuild test` run).
2. **GREEN gate (Plan 09-04 — this plan):** Commit `f2beac8` adds the 13 keys; `xcodebuild test -only-testing:gamekitTests/LocalizableCatalogTests` returned `** TEST SUCCEEDED **`. RED → GREEN flip verified.
3. **REFACTOR:** Not applicable — single atomic edit, no cleanup pass needed.

## User Setup Required

None — no external service configuration required. xcstrings catalogs are compiled at build time; no Xcode UI step needed for the keys to take effect.

## Next Phase Readiness

- **Plan 09-05 (Settings card UI)** can now author `SettingsView` extensions referencing `String(localized: "videoMode.sectionHeader")`, `String(localized: "videoMode.toggleLabel")`, `String(localized: "videoMode.locationRowTitle")` and get real strings, not the raw-key fallback.
- **Plan 09-06 (VideoLocationPickerView)** can now author the iPhone-outline picker referencing `String(localized: "videoMode.pickerTitle")`, `String(localized: "videoMode.pickerContainerA11yLabel")`, `String(localized: "videoMode.zoneFillLabel")`, and `String(localized: "videoMode.manualSelectionExplanation")`. The VIDEO-14 paragraph copy is locked at the resource level, so the Settings sub-screen just renders what the catalog ships.
- **Plans 09-07 / 09-08** (regression + integration) have a stable copy contract to test against — no risk of copy drift between the test fixtures and the production catalog.

**No blockers.** LocalizableCatalogTests is GREEN. `VideoModeLocation.localizedLabel` (Plan 09-02) is now functional end-to-end.

---
*Phase: 09-video-mode-foundation*
*Completed: 2026-05-12*

## Self-Check: PASSED

- `09-04-SUMMARY.md` exists on disk
- `gamekit/gamekit/Resources/Localizable.xcstrings` exists on disk
- `Docs/releases/v1.1.md` exists on disk
- Commit `f2beac8` verified present in `git log --oneline --all`
