# Phase 10: Layout Primitives - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 4 new files (2 source + 2 test)
**Analogs found:** 4 / 4 (with composite analogs for the ViewModifier)

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Core/VideoModeAware.swift` | view-modifier (struct conforming to `ViewModifier`) + `View` extension + `VideoModeCompactness` enum + custom `EnvironmentKey` + `#Preview` matrix | request-response (parent measures → publishes env → children react) | composite: `VideoModeStore.swift` (env-key shape, `@Observable` read), `VideoCompactControlRow.swift` (preset `#Preview` shape + token reads), `VideoLocationPickerView.swift` (`private static let` CGFloat ratio + `GeometryReader` pattern) | role-match (no existing `ViewModifier` in repo — first one); each individual pattern is exact-match |
| `gamekit/gamekit/Core/VideoModeSlotRouter.swift` | pure helper (`enum` namespace + `static func` exhaustive switch + `SlotAnchorMap` value-type struct + `SlotAnchor` enum) | transform (location → anchor map; no state) | `VideoModeLocation.swift` `localizedLabel` switch (exhaustive enum switch); composite with `GameKind.swift` / `Outcome.swift` for value-type enum + helper style | role-match (project has no other "pure router" helper, but the exhaustive switch over `VideoModeLocation` is established) |
| `gamekit/gamekitTests/Core/VideoModeAwareTests.swift` | unit test (`@Suite` + `@Test` + isolated `UserDefaults`) | request-response | `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` | exact (same framework, same `@MainActor` requirement, same `makeIsolatedDefaults()` helper, same `VideoModeStore` construction shape) |
| `gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift` | unit test (`@Suite` + `@Test` + flat assertion list) | transform | `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` `test_location_persists_all_cases` (loop over `VideoModeLocation.allCases`) | exact (same framework, identical loop pattern) |

---

## Pattern Assignments

### `Core/VideoModeAware.swift` (view-modifier + env-key + #Preview matrix)

> No project file currently conforms to `ViewModifier` — this is the project's
> first. Instead the planner composes three exact-match sub-patterns from
> existing files. Each sub-pattern below is copy-paste-ready.

#### Sub-pattern A — File header doc-comment shape

**Analog:** `gamekit/gamekit/Core/VideoModeStore.swift` lines 1-32
**Why:** Established header convention in the v1.2 Core/ flat layout — every
P9-shipped Video Mode file uses this exact header structure. P10 mirrors so
the file looks native next to its P9 siblings.

```swift
//
//  VideoModeAware.swift
//  gamekit
//
//  v1.2 Video Mode layout primitive — wraps a game view at the outermost layer
//  and applies container-level Video Mode behavior:
//    - off-restore short-circuit (D-05) — byte-identical to un-wrapped on Off
//    - large-band reservation (D-08) — .safeAreaInset(.top/.bottom) for largeTop/largeBottom
//    - compactness publication (D-12) — \.videoModeCompactness env value
//
//  Phase 10 invariants (per CONTEXT D-01..D-16):
//    - reads VideoModeStore via @Environment(\.videoModeStore) — NO new env key
//      for isEnabled / location (D-04). The store is the single source of truth.
//    - largeBandFraction is a private static let on VideoModeAware (D-10);
//      NOT promoted to a DesignKit token (CLAUDE.md §2 — single consumer).
//    - Small PiP zones do NOT touch board frame / safe area (D-11) — pure
//      controls-routing handled by VideoModeSlotRouter in the game view.
//    - #Preview matrix renders 6 zones × Classic + Dracula presets (D-16) —
//      SC5 verified by visual inspection on Xcode canvas. NO DEBUG screen.
//
```

#### Sub-pattern B — `@Observable` store read via `@Environment(\.videoModeStore)`

**Analog:** P9 surfaces that read the store (search `@Environment(\.videoModeStore)`
in P9 ship files). The canonical shape lives in
`gamekit/gamekit/Core/VideoModeStore.swift` lines 95-113 (the env-key
definition) — every reader copies the property-wrapper line below.

**Code to copy (from a P9 reader; replicated shape):**
```swift
@Environment(\.videoModeStore) private var store
```

**Why this shape:** `@EnvironmentObject` is INCOMPATIBLE with `@Observable`
(CLAUDE.md §1 P4 RESEARCH Pitfall 1 — already locked at P9). The
`@Environment(\.foo)` keypath form is the iOS-17 canonical seam.

#### Sub-pattern C — `private static let` CGFloat layout constant

**Analog:** `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift`
lines 143-145 — the exact-match precedent for "geometry-fraction constant
that is not a DesignKit token because it has a single consumer."

```swift
// Source: VideoLocationPickerView.swift:143-145 (verbatim shape)
private static let largeFootprintHeightRatio: CGFloat = 0.28
private static let smallFootprintWidthRatio:  CGFloat = 0.32
private static let smallFootprintHeightRatio: CGFloat = 0.15
```

**Application to P10 (CONTEXT D-10):**
```swift
/// Measured from Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png
/// (worst case): bottom PiP pill ≈ 809px / 2556px = 0.317 fraction. Locked to
/// 0.32 (rounded up) for safe symmetric reservation on both .largeTop and
/// .largeBottom. iOS native PiP top-dock is smaller (~0.19) — modest
/// over-reservation on Large top accepted in exchange for one constant.
/// Device-portable: fraction applies to any screen height via
/// geometry.size.height * largeBandFraction.
private static let largeBandFraction: CGFloat = 0.32
```

#### Sub-pattern D — Custom `EnvironmentKey` extension

**Analog:** `gamekit/gamekit/Core/VideoModeStore.swift` lines 95-113

```swift
// VideoModeStore.swift:95-113 (verbatim shape — copy for VideoModeCompactness)
private struct VideoModeStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = VideoModeStore()
}

extension EnvironmentValues {
    var videoModeStore: VideoModeStore {
        get { self[VideoModeStoreKey.self] }
        set { self[VideoModeStoreKey.self] = newValue }
    }
}
```

**Application to P10 (CONTEXT D-12):**
```swift
// VideoModeCompactness EnvironmentKey — exact same shape, default is the
// "no compactness reaction" value so off-path / un-wrapped readers see
// the safe default. NOT @MainActor on the static because the value-type
// enum is trivially Sendable.
private struct VideoModeCompactnessKey: EnvironmentKey {
    static let defaultValue: VideoModeCompactness = .normal
}

extension EnvironmentValues {
    var videoModeCompactness: VideoModeCompactness {
        get { self[VideoModeCompactnessKey.self] }
        set { self[VideoModeCompactnessKey.self] = newValue }
    }
}
```

**Cross-check:** Identical shape also exists at
`gamekit/gamekit/Core/SettingsStore.swift` lines 144-155 (`SettingsStoreKey`).
Two existing consumers prove this is the project's locked seam.

#### Sub-pattern E — Token reads in body

**Analog:** `gamekit/gamekit/Core/VideoCompactControlRow.swift` lines 38-47
(read `theme.spacing.xl` for the row height that P10 modifier subtracts
from available board height).

```swift
// VideoCompactControlRow.swift:38-47 — the row anchors at theme.spacing.xl = 24pt
HStack(spacing: theme.spacing.s) {
    backButton
    primaryInfo()
    picker()
    secondaryInfo()
    settingsButton
}
.frame(height: theme.spacing.xl)             // D-13 pill height anchor
```

**Application to P10 (subtraction in `pickCompactness`):**
The modifier reads `theme.spacing.xl` (24) to subtract the compact-row's
height from `proxy.size.height`. RESEARCH §Open Question 1 flags whether
the modifier reads `theme` via env or hardcodes `24` with a code comment
citing the token. Planner resolves in task 1.

#### Sub-pattern F — `#Preview` matrix with private setup helper

**Analog:** `gamekit/gamekit/Core/VideoCompactControlRow.swift` lines 74-155
— single `#Preview` block with private `PreviewChip` / `PreviewPicker` helpers.

```swift
// VideoCompactControlRow.swift:76-123 — Theme constructed via canonical resolver,
// preview helpers as `private struct` not exported.
#Preview {
    let theme = Theme.resolve(preset: .classicMuted, scheme: .light)
    return VStack(spacing: theme.spacing.l) {
        VideoCompactControlRow(
            theme: theme,
            onBack: {},
            onSettings: {}
        ) {
            PreviewChip(theme: theme, glyph: "flag.fill", label: "10")
        } picker: {
            PreviewPicker(theme: theme, label: "Reveal/Flag")
        } secondaryInfo: {
            PreviewChip(theme: theme, glyph: "timer", label: "1:23")
        }
        // … 2 more game variations
    }
    .padding(theme.spacing.l)
    .background(theme.colors.background)
}

// MARK: - Preview helpers (private — not exported, used only by the preview)

private struct PreviewChip: View {
    let theme: Theme
    let glyph: String
    let label: String
    var body: some View { /* … */ }
}
```

**Application to P10 (CONTEXT D-16 + RESEARCH §Pattern 3):**

P9 used a single `#Preview` block; P10 needs 12 named blocks (6 zones × 2
presets). Pattern: same private-helper-struct approach to keep boilerplate
out of each `#Preview` body, but use **named blocks** so Xcode renders
each as a separately scrubbable tile.

```swift
// 12 named blocks — same factoring (private StubGame + StubGameContent)
#Preview("Classic — Large top") {
    StubGame(zone: .largeTop, preset: .classicMuted)
}
#Preview("Classic — Large bottom") {
    StubGame(zone: .largeBottom, preset: .classicMuted)
}
// … 10 more

private struct StubGame: View {
    let zone: VideoModeLocation
    let preset: ThemePreset
    @State private var store: VideoModeStore

    init(zone: VideoModeLocation, preset: ThemePreset) {
        self.zone = zone
        self.preset = preset
        let s = VideoModeStore(
            userDefaults: UserDefaults(
                suiteName: "preview-\(UUID().uuidString)"
            )!
        )
        s.isEnabled = true
        s.location = zone
        _store = State(initialValue: s)
    }

    var body: some View {
        let theme = Theme.resolve(preset: preset, scheme: .light)
        StubGameContent(theme: theme)
            .videoModeAware(minBoardHeight: 480)
            .environment(\.videoModeStore, store)
            .background(theme.colors.background)
    }
}

private struct StubGameContent: View {
    let theme: Theme
    var body: some View {
        VStack {
            Rectangle()
                .fill(theme.colors.surface)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VideoCompactControlRow(
                theme: theme,
                onBack: {},
                onSettings: {},
                primaryInfo: { Text("primary") },
                picker: { Text("picker") },
                secondaryInfo: { Text("secondary") }
            )
        }
    }
}
```

**Watch:** RESEARCH Assumption A6 — Xcode previews historically have issues
with `@Observable` types constructed at init time. If preview fails to
render, fall back to a static `@MainActor static let` `VideoModeStore` at
file scope visible to all `#Preview` blocks.

---

### `Core/VideoModeSlotRouter.swift` (pure helper)

**Analog:** `gamekit/gamekit/Core/VideoModeLocation.swift` lines 45-54 — the
exhaustive `switch` over the 6-case enum is the established project pattern;
P10's `VideoModeSlotRouter.anchors(for:)` mirrors it.

```swift
// VideoModeLocation.swift:45-54 — exhaustive switch over VideoModeLocation
var localizedLabel: String {
    switch self {
    case .largeTop:         return String(localized: "videoMode.location.largeTop")
    case .largeBottom:      return String(localized: "videoMode.location.largeBottom")
    case .smallTopLeft:     return String(localized: "videoMode.location.smallTopLeft")
    case .smallTopRight:    return String(localized: "videoMode.location.smallTopRight")
    case .smallBottomLeft:  return String(localized: "videoMode.location.smallBottomLeft")
    case .smallBottomRight: return String(localized: "videoMode.location.smallBottomRight")
    }
}
```

**Application to P10 (CONTEXT D-02):**
```swift
// Foundation-only — keeps the helper reusable from any context (engine layer,
// tests, snapshot rigs). NO SwiftUI import.
import Foundation

/// Where a single slot lives on the screen for a given PiP zone.
/// Conceptual (not coordinate) — game views translate this to layout intent.
enum SlotAnchor: Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    case inCompactRow              // demoted into VideoCompactControlRow
    case hidden                    // not shown at all for this zone
}

/// The 4 movable slots that every Phase 11/12 game view arranges.
/// Named fields give the compiler exhaustiveness — a [SlotID: SlotAnchor]
/// dictionary would lose that.
struct SlotAnchorMap: Equatable, Sendable {
    let back: SlotAnchor
    let settings: SlotAnchor
    let picker: SlotAnchor    // Reveal/Flag (Mines), Mode (Merge), Fill/Mark (Nono)
    let fab: SlotAnchor       // Reveal/Flag FAB (Mines 06.1-02); other games may have none
}

enum VideoModeSlotRouter {
    /// Returns where each slot anchors for the given PiP zone.
    /// Data derives from
    /// .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    /// "Where controls go" column for each PiP zone.
    static func anchors(for location: VideoModeLocation) -> SlotAnchorMap {
        switch location {
        case .largeTop:
            return SlotAnchorMap(back: .inCompactRow, settings: .inCompactRow,
                                 picker: .inCompactRow, fab: .inCompactRow)
        case .largeBottom:
            return SlotAnchorMap(back: .inCompactRow, settings: .inCompactRow,
                                 picker: .inCompactRow, fab: .inCompactRow)
        case .smallTopLeft:
            return SlotAnchorMap(back: .topTrailing, settings: .topTrailing,
                                 picker: .bottomTrailing, fab: .bottomTrailing)
        case .smallTopRight:
            return SlotAnchorMap(back: .topLeading, settings: .topLeading,
                                 picker: .bottomLeading, fab: .bottomLeading)
        case .smallBottomLeft:
            return SlotAnchorMap(back: .topLeading, settings: .topTrailing,
                                 picker: .bottomTrailing, fab: .bottomTrailing)
        case .smallBottomRight:
            return SlotAnchorMap(back: .topLeading, settings: .topTrailing,
                                 picker: .bottomLeading, fab: .bottomLeading)
        }
    }
}
```

**File header (mirror VideoModeLocation.swift:1-22 shape):**
```swift
//
//  VideoModeSlotRouter.swift
//  gamekit
//
//  Pure helper exposing per-zone slot-anchor data derived from
//  .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md.
//
//  CONTEXT D-02 lock: slot reposition lives in the GAME VIEW, not the modifier.
//  Every Phase 11/12 adopting game view calls
//  `VideoModeSlotRouter.anchors(for: store.location)` and arranges its own
//  subviews per the returned SlotAnchorMap. Phase 10 ships zero adoption.
//
//  Foundation-only — no SwiftUI import keeps this helper reusable from any
//  context (engine layer, tests, snapshot rigs).
//
//  Phase 13 forward-compat NOTE: the future banner-placement table in
//  08-BANNER-PLACEMENT.md encodes the same "opposite-of-PiP" geometry. If
//  Phase 13 chooses to share, extend SlotAnchorMap with a `banner: SlotAnchor`
//  field and update the switch with anchors from 08-BANNER-PLACEMENT.md.
//  Don't pre-extend now (CLAUDE.md §2 — needs 2+ consumers for promotion).
//
```

---

### `gamekitTests/Core/VideoModeAwareTests.swift` (Swift Testing unit test)

**Analog:** `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` (exact match)

**Imports + suite-header pattern (lines 27-43):**
```swift
import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("VideoModeStore")    // P10: rename to "VideoModeAware short-circuit (SC3)"
struct VideoModeStoreTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Each test gets a fresh suite name so writes in one test never bleed
    /// into a sibling test running in parallel under Swift Testing.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }
}
```

**Test-body pattern with store construction (lines 47-56):**
```swift
@Test("isEnabled defaults to false on fresh UserDefaults suite (VIDEO-01 / 09-01-02)")
func test_isEnabled_defaults_to_false() {
    let defaults = Self.makeIsolatedDefaults()
    #expect(defaults.object(forKey: VideoModeStore.isEnabledKey) == nil)
    let store = VideoModeStore(userDefaults: defaults)
    #expect(store.isEnabled == false)
}
```

**Application to P10 (mirror exactly — see RESEARCH §Code Example 1):**

Build a `makeStore(enabled:location:)` static helper that produces a
configured `VideoModeStore`, then write the 4 contract tests:

| Test name | Asserts | RESEARCH ref |
|-----------|---------|--------------|
| `test_offState_doesNotPublishCompactness` | When `store.isEnabled == false`, descendant reads `.normal` (the env default — proves modifier never overrode it) | VIDEO-13 / D-05 / D-06 |
| `test_onState_normal` | On + comfortable size → `.normal` | VIDEO-06 D-13 |
| `test_onState_collapsedSettings` | On + tight (between floor and 0.85× floor) → `.collapsedSettings` | VIDEO-06 D-13 |
| `test_onState_reducedTime` | On + very tight (< 0.85× floor) → `.reducedTime` | VIDEO-06 D-13 |

**Open implementation question (RESEARCH §Open Q + Example 1 note):**
`renderAndCapture(store:minBoardHeight:forcedHeight:)` helper — two viable
implementations: (1) mount in `UIHostingController` of fixed size + probe-child
read; (2) `ViewInspector` SPM dep. Recommendation: approach 1 (no 3rd-party
dep). Planner resolves in plan task.

---

### `gamekitTests/Core/VideoModeSlotRouterTests.swift` (Swift Testing unit test)

**Analog:** `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` lines 85-95
(the `for loc in VideoModeLocation.allCases` round-trip loop pattern)

**Code to copy (lines 85-95):**
```swift
@Test("location round-trips through UserDefaults for all 6 cases (VIDEO-02 / VIDEO-03 / 09-01-03)")
func test_location_persists_all_cases() {
    for loc in VideoModeLocation.allCases {
        let defaults = Self.makeIsolatedDefaults()
        let store = VideoModeStore(userDefaults: defaults)
        store.location = loc
        let reloaded = VideoModeStore(userDefaults: defaults)
        #expect(reloaded.location == loc, "Round-trip failed for \(loc.rawValue)")
    }
}
```

**Application to P10 (VIDEO-05 — 24 anchor assertions; RESEARCH §Example 2):**
```swift
import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("VideoModeSlotRouter")
struct VideoModeSlotRouterTests {

    @Test("Large top — all slots consolidate into compact row")
    func test_largeTop_allInCompactRow() {
        let map = VideoModeSlotRouter.anchors(for: .largeTop)
        #expect(map.back == .inCompactRow)
        #expect(map.settings == .inCompactRow)
        #expect(map.picker == .inCompactRow)
        #expect(map.fab == .inCompactRow)
    }

    // 5 more @Test funcs (one per VideoModeLocation case) × 4 #expect each
    // = 24 anchor assertions total per VIDEO-05.

    @Test("All 6 locations switch exhaustively (compile-time guarantee)")
    func test_all_cases_have_mappings() {
        // The switch in anchors(for:) is exhaustive; this test simply
        // walks every case to confirm no crash / fatal-error path.
        for loc in VideoModeLocation.allCases {
            _ = VideoModeSlotRouter.anchors(for: loc)
        }
        #expect(VideoModeLocation.allCases.count == 6)
    }
}
```

**Header (mirror VideoModeStoreTests.swift:1-29):**
```swift
//
//  VideoModeSlotRouterTests.swift
//  gamekitTests
//
//  Phase 10 — locks the VIDEO-05 (Small-PiP slot reposition) contract that
//  VideoModeSlotRouter.anchors(for:) satisfies:
//    - 6 VideoModeLocation cases × 4 SlotAnchorMap fields = 24 assertions
//    - Large zones consolidate all slots into .inCompactRow (D-02 + D-08)
//    - Small zones place slots opposite the covered corner (D-11)
//
//  Pattern source: VideoModeStoreTests.swift:27-29 (@Suite header) +
//  VideoModeStoreTests.swift:85-95 (loop over VideoModeLocation.allCases).
//
//  Cross-check: Each switch case must match
//  .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
//  "Where controls go" column (RESEARCH §Assumption A3).
//
```

---

## Shared Patterns

### Shared Pattern 1 — `@Observable` + custom `EnvironmentKey` seam

**Source:** `gamekit/gamekit/Core/VideoModeStore.swift` lines 95-113
(and `SettingsStore.swift` lines 144-155 for cross-check).
**Apply to:** `VideoModeAware.swift` (when defining `VideoModeCompactnessKey`
+ `EnvironmentValues.videoModeCompactness`).

```swift
private struct VideoModeStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = VideoModeStore()
}

extension EnvironmentValues {
    var videoModeStore: VideoModeStore {
        get { self[VideoModeStoreKey.self] }
        set { self[VideoModeStoreKey.self] = newValue }
    }
}
```

**Why locked:** `@EnvironmentObject` requires `ObservableObject`, which is
INCOMPATIBLE with the `@Observable` macro (P4 RESEARCH Pitfall 1 inheritance
through P9). Every `@Observable` store in the project uses this exact seam.

### Shared Pattern 2 — Per-test isolated `UserDefaults` helper

**Source:** `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` lines 36-43
**Apply to:** Both new test files.

```swift
/// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
/// Each test gets a fresh suite name so writes in one test never bleed
/// into a sibling test running in parallel under Swift Testing.
static func makeIsolatedDefaults() -> UserDefaults {
    let suite = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}
```

**Why locked:** Swift Testing runs tests in parallel by default. Shared
`.standard` UserDefaults causes write-bleed between tests. Every P9 test
file declares this helper per-file (NOT shared across files — Swift
Testing's parallel execution makes shared module-scope helpers risky).

### Shared Pattern 3 — Exhaustive switch over `VideoModeLocation`

**Source:** `gamekit/gamekit/Core/VideoModeLocation.swift` lines 45-54
**Apply to:** `VideoModeSlotRouter.anchors(for:)` switch + the modifier's
`applyBand(to:in:)` / `bandHeight(for:in:)` helpers.

**Why locked:** Adding a 7th case to `VideoModeLocation` (future v1.3+) is
a contract change — compiler-enforced exhaustiveness in every adopter is
the project's safety net (CONTEXT §code_context note "new case = compile-time
error in every adopter").

### Shared Pattern 4 — Theme construction in `#Preview` via `Theme.resolve(preset:scheme:)`

**Source:** `gamekit/gamekit/Core/VideoCompactControlRow.swift` line 80
**Apply to:** `StubGame.body` inside `VideoModeAware.swift` `#Preview` blocks.

```swift
let theme = Theme.resolve(preset: .classicMuted, scheme: .light)
```

**Why locked:** Same canonical resolver `SettingsView` reads at runtime; no
preview-only `Theme.classicLight()` shortcut. CLAUDE.md §2 token discipline
carries — preview theme must be a real resolved theme so the legibility
audit (CLAUDE.md §8.12) is meaningful.

### Shared Pattern 5 — Foundation-only imports for non-SwiftUI files

**Source:** `gamekit/gamekit/Core/VideoModeLocation.swift` line 24
**Apply to:** `VideoModeSlotRouter.swift` (pure helper — no SwiftUI).

```swift
import Foundation
```

**Why locked:** CONTEXT §code_context — "Foundation-only — no SwiftUI import
keeps the enum reusable from any context (engine layer, tests, snapshot
rigs)." `VideoModeSlotRouter` and `SlotAnchorMap` are pure data — they have
no SwiftUI dependency and must remain importable from non-SwiftUI test
contexts.

---

## No Analog Found

No new file lacks an analog. The closest gap is the `ViewModifier` struct
shape itself — no other file in `gamekit/` or `DesignKit/Sources/` conforms
to `ViewModifier`. The planner should:

1. Treat the `ViewModifier` body shape as **synthesized from RESEARCH Pattern 1**
   (RESEARCH §Pattern 1 code example lines 313-407 is copy-paste-ready).
2. Cite Apple's `ViewModifier` documentation in the file header
   (`developer.apple.com/documentation/swiftui/viewmodifier`) since there's
   no project precedent to cite.

| File / Concern | Reason |
|----------------|--------|
| `ViewModifier` body shape | No `: ViewModifier` conformance exists yet in the project. RESEARCH §Pattern 1 provides the iOS-17-canonical body; planner imports it verbatim with `private` factoring of `onPath` / `applyBand` / `bandHeight` / `pickCompactness` helpers per RESEARCH file-size estimate (~245 lines). |
| `safeAreaInset(edge:)` band reservation | No precedent in the codebase (this is the project's first `.safeAreaInset` consumer). Use the SwiftUI iOS-15+ canonical idiom from RESEARCH §Standard Stack + Anti-Patterns ("don't ZStack overlay; don't `.frame` math"). |
| `renderAndCapture(store:minBoardHeight:forcedHeight:)` test helper | No project file mounts a SwiftUI modifier and probes its env via a child reader. Planner picks between (a) `UIHostingController` + fixed-size + probe-child + `@MainActor Task`, or (b) `ViewInspector` SPM dependency. Recommendation per RESEARCH: approach (a). |

---

## Metadata

**Analog search scope:**
- `gamekit/gamekit/Core/*.swift` (25 files)
- `gamekit/gamekit/Screens/**/*.swift`
- `gamekit/gamekitTests/Core/*.swift`
- `gamekit/gamekitTests/Regression/SC5RegressionTests.swift`
- `DesignKit/Sources/DesignKit/**/*.swift` (no `ViewModifier` conformances found)

**Files scanned:** ~40 (focused on Core/ + tests; full DesignKit not loaded — confirmed via grep)

**Pattern extraction date:** 2026-05-12

**Cross-references confirmed:**
- `EnvironmentKey` pattern: 2 existing consumers (`VideoModeStore`, `SettingsStore`) → P10's `VideoModeCompactnessKey` is the 3rd.
- Exhaustive `VideoModeLocation` switch: 1 existing consumer (`VideoModeLocation.localizedLabel`) → P10's `VideoModeSlotRouter.anchors(for:)` and `VideoModeAware.applyBand(to:in:)` are 2nd + 3rd.
- `makeIsolatedDefaults()` helper: every P9 test file (`VideoModeStoreTests`, `VideoModeEnvironmentTests`, `SC5RegressionTests`, `SettingsStoreFlagsTests`) → P10 mirrors exactly.
- `private static let CGFloat` ratio constant: `VideoLocationPickerView` (3 consumers) → P10's `largeBandFraction` is the 4th in the v1.2 surface.
- `Theme.resolve(preset:scheme:)` in `#Preview`: `VideoCompactControlRow.swift:80` → P10 `StubGame.body` is the 2nd.
