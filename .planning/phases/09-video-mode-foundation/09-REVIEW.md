---
phase: 09-video-mode-foundation
reviewed: 2026-05-13T04:02:26Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - gamekit/gamekit/App/GameKitApp.swift
  - gamekit/gamekit/Core/VideoCompactControlRow.swift
  - gamekit/gamekit/Core/VideoModeLocation.swift
  - gamekit/gamekit/Core/VideoModeStore.swift
  - gamekit/gamekit/Screens/SettingsView.swift
  - gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift
  - gamekit/gamekitTests/App/GameKitAppTests.swift
  - gamekit/gamekitTests/Core/VideoModeEnvironmentTests.swift
  - gamekit/gamekitTests/Core/VideoModeStoreTests.swift
  - gamekit/gamekitTests/Regression/SC5RegressionTests.swift
  - gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift
  - gamekit/gamekitTests/Screens/SettingsViewTests.swift
  - gamekit/gamekitTests/Screens/VideoLocationPickerViewTests.swift
findings:
  critical: 0
  warning: 3
  info: 7
  total: 10
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-05-13T04:02:26Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 9 (Video Mode Foundation) lands a clean, additive surface: the
`VideoModeStore` (`@Observable` + `@MainActor`) mirrors `SettingsStore`
verbatim, the `VideoModeLocation` enum is `Sendable` and the
UserDefaults key strings are locked as documented, the
`EnvironmentValues.videoModeStore` seam is wired at the App root, and
`SettingsView` reads via `@Environment` + `Bindable(...)` — never
`@EnvironmentObject`. Tests use Swift Testing (`import Testing` +
`@Test`), each suite owns its `makeIsolatedDefaults()` helper, and the
RED→GREEN gate is consistently applied (Wave 0 stubs with `TODO(09-NN)`
markers replaced by real assertions in later waves).

No critical issues. Three warnings and seven informational items are
called out below — all minor and mostly involving test coverage gaps,
clarity, or small token-discipline pinholes. The Pitfall 5 lock
(selected-zone label uses `theme.colors.textPrimary`, not
`accentPrimary`) is honored at `VideoLocationPickerView.swift:291`.

## Warnings

### WR-01: LocalizableCatalogTests does not assert the three new sizeToggle keys

**File:** `gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift:45-59`
**Issue:** The `requiredVideoModeKeys` list pins 13 keys, but the
picker now reads three additional keys at runtime that are absent from
the list:

- `videoMode.locationPicker.sizeA11yLabel` (used at `VideoLocationPickerView.swift:126`)
- `videoMode.locationPicker.sizeLarge` (used at line 120)
- `videoMode.locationPicker.sizeSmall` (used at line 122)

These keys ARE present in `Localizable.xcstrings` (verified at lines
1053 / 1065 / 1077). The risk is asymmetric — if a future translator
deletes one of the three sizeToggle keys, the picker silently falls
back to raw key text on the segmented control and the test suite
stays green. The PATTERNS file's "~11 keys verbatim" assertion drifts
silently.

**Fix:** Add the three keys to the required list so a delete or rename
trips the catalog test:
```swift
static let requiredVideoModeKeys: [String] = [
    "videoMode.sectionHeader",
    "videoMode.toggleLabel",
    "videoMode.locationRowTitle",
    "videoMode.location.largeTop",
    "videoMode.location.largeBottom",
    "videoMode.location.smallTopLeft",
    "videoMode.location.smallTopRight",
    "videoMode.location.smallBottomLeft",
    "videoMode.location.smallBottomRight",
    "videoMode.pickerTitle",
    "videoMode.pickerContainerA11yLabel",
    "videoMode.zoneFillLabel",
    "videoMode.manualSelectionExplanation",
    "videoMode.locationPicker.sizeLarge",
    "videoMode.locationPicker.sizeSmall",
    "videoMode.locationPicker.sizeA11yLabel"
]
```

### WR-02: Size-flip default discards left-half preference; size flip can also fire reentrantly via store sync

**File:** `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift:104-113`
**Issue:** Two adjacent quirks share this `.onChange(of: size)` block.

1. **Reentrancy risk.** The handler writes `videoModeStore.location`,
   which triggers the sibling `.onChange(of: videoModeStore.location)`
   at line 100, which writes `size`, which can re-enter this handler.
   The `guard oldSize != newSize else { return }` at line 105 prevents
   an infinite loop in the common case, but only after both onChange
   bodies execute once. If the store-side write happens to derive a
   different `VideoSize` than the user just picked (impossible today
   given the 6-case enum, but a 7th case added in a future-phase
   regression could break the symmetry), the bounce becomes visible.
   Consider gating both branches with a single
   "user-initiated vs store-initiated" flag to make the contract
   inspection-proof against enum growth (D-07 lock notwithstanding).

2. **Lost left-half on user-initiated upsize.** A user on
   `.smallTopLeft` who flips to Large lands on `.largeTop`; flipping
   back to Small lands on `.smallTopRight`. The left preference is
   permanently lost across a size round-trip. This is the documented
   "shrink path mirrors D-03" behavior, but it is silent — the
   segmented toggle gives no hint that flipping size will reset the
   horizontal axis. The contract-test at
   `VideoLocationPickerViewTests.swift:138-169` asserts only vertical
   half is preserved, which means the test confirms the loss is
   intentional but does not surface it to the user.

**Fix:**
- For the reentrancy: gate with a flag, or fold the size-flip write
  into the segmented control's binding setter so only one onChange
  fires:
```swift
private var sizeToggle: some View {
    Picker("", selection: Binding(
        get: { VideoSize(for: videoModeStore.location) },
        set: { newSize in
            guard newSize != VideoSize(for: videoModeStore.location) else { return }
            let half = VerticalHalf(for: videoModeStore.location)
            videoModeStore.location = defaultLocation(size: newSize, half: half)
        }
    )) { ... }
}
```
  This collapses `@State private var size` entirely — the toggle
  derives from the store and writes to the store directly, removing
  both .onChange handlers.
- For the left-half loss: either remember the user's horizontal half
  in a transient `@State` (Phase 9 scope-creep) or document the
  behavior in `videoMode.manualSelectionExplanation` so the user
  understands tapping a Small left corner is required.

### WR-03: `iPhoneOutlineFrame` includes a 1.5pt stroke and a magic-number `theme.spacing.xxl * 7` width with no DesignKit token

**File:** `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift:234-237`
**Issue:** Two values escape the §2 token discipline:

1. `.frame(maxWidth: theme.spacing.xxl * 7)` — multiplying `xxl` by 7
   produces a width that has no semantic name. If `xxl` is rebalanced
   in DesignKit (raised from e.g. 48 → 56), the picker outline grows
   ~56pt without anyone noticing. A `theme.layout.deviceOutlineMaxWidth`
   token (or a local `private static let maxOutlineWidth: CGFloat`
   with a comment explaining the 9:19.5 aspect math) would be more
   honest.

2. `.stroke(theme.colors.border, lineWidth: 1.5)` — 1.5 is a
   half-point literal. The header comments claim §2 escape hatch for
   "stroke widths since DesignKit does not surface a stroke-width
   token", which is reasonable, but 1.5 is unusual (most strokes use 1
   or 2). On 2x displays this renders as 3 device pixels offset by 0.5
   — pixel rounding may produce a soft edge. Confirm visually under
   Voltage/Dracula presets before calling §8.12 done.

**Fix:** For (1), introduce a `private static let outlineMaxWidth: CGFloat
= 336` (matching `xxl=48 * 7`) with a comment, OR add the token to
DesignKit. For (2), prefer `lineWidth: 1` unless a visual audit shows
1pt disappears under Loud presets. Both fixes are minor and can be
landed together in a follow-up commit if visual review passes.

## Info

### IN-01: `VideoModeStoreKey.defaultValue` lazy-constructs a `VideoModeStore(.standard)` on every `EnvironmentValues()` access without an injection

**File:** `gamekit/gamekit/Core/VideoModeStore.swift:104-106`
**Issue:** `defaultValue` is a `static let`, so the default
`VideoModeStore()` is constructed once per process and reused. That's
correct, BUT: this default reads `UserDefaults.standard` even when the
view tree provides a custom store via `.environment(...)`. In tests
that exercise the EnvironmentKey default-value path (e.g.
`GameKitAppTests.test_videoModeStore_injected_at_app_root` at line
46), this means the test bundle touches the developer's actual
`UserDefaults.standard` for `gamekit.videoModeEnabled` and
`gamekit.videoModeLocation`. The reads are harmless (the values are
just consulted), but the construction is non-deterministic across CI
machines.

This mirrors `SettingsStoreKey.defaultValue` exactly
(`SettingsStore.swift:147`), so the precedent is consistent. Flagging
only because Pattern 5 escape hatch keeps growing — if Phase 10 adds
a third `@Observable` store, the same standard-defaults touch happens
a third time.

**Fix:** No change required for Phase 9 — pattern parity with
`SettingsStore` is more important than micro-optimizing the default.
Note for future: a `static let defaultValue = VideoModeStore(userDefaults:
.init(suiteName: "gamekit.environmentKeyDefault")!)` would isolate
the default-value path from `.standard` and remove the CI variance,
but it complicates the App-root override semantics.

### IN-02: GameKitApp.init body is now 113 lines (over the §8.5 500-line hard cap on a per-file basis is fine, but the init itself is dense)

**File:** `gamekit/gamekit/App/GameKitApp.swift:46-143`
**Issue:** The `init()` body is 98 lines including comments, with 5
distinct `@State` initializations, DEBUG-only schema deploy logic,
and the ModelContainer try/catch. The file is 182 lines total —
well under §8.1 — but `init()` itself is approaching the per-method
mental-load ceiling.

If Phase 10 adds another store (e.g. a `VideoEngineStore`), consider
extracting the per-store construction into a private `static func
makeStores(...) -> (SettingsStore, VideoModeStore, SFXPlayer,
AuthStore, CloudSyncStatusObserver)` so `init()` reads as wiring
rather than construction.

**Fix:** Not required this phase. Bookmark for Phase 10.

### IN-03: SC5RegressionTests is a contract test masquerading as a regression test

**File:** `gamekit/gamekitTests/Regression/SC5RegressionTests.swift:47-74`
**Issue:** The test name implies "byte-identical regression" but the
body asserts only `store.isEnabled == false` and `store.location ==
.largeBottom`. The TODO at line 69 acknowledges this. That's exactly
what CONTEXT D-15 specifies — Phase 9 has no game-view branches that
could regress yet — but a future reader scanning the test file may
infer the assertion does more than it does.

The `@Suite("SC5Regression")` name + the file path `Regression/`
amplify the false signal.

**Fix:** Either rename the suite to `@Suite("SC5OffStateContract")`
with a matching file move to `Contract/`, or beef up the test name to
make the placeholder shape explicit:
```swift
@Test("SC5 D-15 off-state contract: store defaults guarantee byte-identical render (real snapshot diff lands in P11/P12)")
```

### IN-04: `Bindable(videoModeStore).isEnabled` inside a SettingsView body re-wraps every render

**File:** `gamekit/gamekit/Screens/SettingsView.swift:198`
**Issue:** `Bindable(videoModeStore).isEnabled` constructs a fresh
`Bindable` wrapper on every body recompute. SwiftUI handles this
efficiently (Bindable is a tiny wrapper), but the recommended iOS 17
pattern is to declare `@Bindable var videoModeStore = ...` as a
property, OR to use the `@Bindable` property wrapper alongside
`@Environment`:
```swift
@Environment(\.videoModeStore) private var videoModeStore
// In body:
@Bindable var bindableStore = videoModeStore
```

The current form works and is also used at lines 238, 247 for
`settingsStore`, so it's consistent with the codebase pattern. Flag
only because Swift 6 strict-concurrency mode is picky and a future
compiler rev could warn on the per-render alloc.

**Fix:** No change required. Document the pattern decision in
`09-PATTERNS.md` if it surfaces in Phase 10.

### IN-05: VideoCompactControlRow preview block uses `private struct` helpers that won't be reachable for unit tests

**File:** `gamekit/gamekit/Core/VideoCompactControlRow.swift:127-155`
**Issue:** `PreviewChip` and `PreviewPicker` are declared `private`
file-scoped helpers. They satisfy the SC4 preview-block requirement
(the file's three slot-mapping previews work), but if Phase 11/12
adoption needs to share the chip shape across games, the privacy
modifier will force a refactor. Two options:

1. Leave as-is — `private` is correct for preview-only types.
2. Promote `PreviewChip` to `DKVideoCompactChip` in DesignKit once
   used in 2+ games (CLAUDE.md §4 "promote when proven").

Adopting #2 prematurely is a §4 violation; flagging only because the
naming `PreviewChip` may invite an adopter to reach for it and discover
the privacy wall.

**Fix:** Rename to `VideoCompactControlRow_PreviewChip` to make the
preview-only intent explicit, or leave with a header comment confirming
the §4 promotion path. Not blocking.

### IN-06: `VideoModeStore`'s `init` reads location with `?? ""` then `?? .largeBottom` — slightly opaque

**File:** `gamekit/gamekit/Core/VideoModeStore.swift:87-89`
**Issue:** The two-level fallback works but obscures the intent. A
reader has to mentally trace: missing key → `nil` → `?? ""` → empty
string → `VideoModeLocation(rawValue: "")` → `nil` → `?? .largeBottom`.

The header comment at lines 83-86 explains it well, but the code
itself could be more direct:
```swift
let stored = userDefaults.string(forKey: Self.locationKey)
    .flatMap(VideoModeLocation.init(rawValue:))
self.location = stored ?? .largeBottom
```
This makes the "parse if present, else default" intent obvious in
two lines.

**Fix:** Cosmetic refactor; defer until Phase 10 unless touching the
file anyway.

### IN-07: GameKitApp `#Preview` for `VideoCompactControlRow` resolves a Theme outside ThemeManager

**File:** `gamekit/gamekit/Core/VideoCompactControlRow.swift:80`
**Issue:** `Theme.resolve(preset: .classicMuted, scheme: .light)` is
called directly in the preview body. That's reasonable for a preview
(no ThemeManager in scope), but a future reader could copy this
pattern into production code and bypass `ThemeManager`'s preset
resolution / override logic. Add a comment marker:
```swift
// PREVIEW ONLY — production code reads `theme` via
// themeManager.theme(using: colorScheme), never via the
// resolver shortcut. See ThemeManager.swift for the canonical path.
let theme = Theme.resolve(preset: .classicMuted, scheme: .light)
```
The current comment at lines 78-79 says "same shape SettingsView
reads at runtime" — that's misleading because SettingsView goes
through `themeManager.theme(using:)`, not `Theme.resolve(...)`
directly.

**Fix:** Tighten the comment per snippet above. One-line edit.

---

_Reviewed: 2026-05-13T04:02:26Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
