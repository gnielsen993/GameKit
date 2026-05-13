# Phase 9: Video Mode Foundation — Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 14 (4 new prod + 1 modified prod + 1 modified app-root + 1 modified resource + 7 new tests)
**Analogs found:** 14 / 14 (every new file has an in-repo precedent — zero greenfield surfaces)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `gamekit/gamekit/Core/VideoModeStore.swift` | Store (`@Observable @MainActor final class`) | KV persistence (UserDefaults read-on-init / write-on-didSet) | `gamekit/gamekit/Core/SettingsStore.swift` | **exact** (D-05 RESEARCH Topic 3: copy verbatim, swap fields) |
| `gamekit/gamekit/Core/VideoModeLocation.swift` | Model enum (`String, CaseIterable, Sendable`) | static / case-iteration | `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift` | **exact** (raw-string enum, stable-rawValue contract) |
| `gamekit/gamekit/Core/VideoCompactControlRow.swift` | Component (generic `@ViewBuilder` SwiftUI view) | request-response (pure render of injected closures + 2 action callbacks) | `../DesignKit/Sources/DesignKit/Components/DKCard.swift` | **exact** (Topic 1 verdict: generic `Content: View` + `@ViewBuilder` init) |
| `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift` | Screen (`NavigationLink` destination, no own NavigationStack) | request-response (read selection from store, write on tap) | `gamekit/gamekit/Screens/FullThemePickerView.swift` | **strong** (push-destination shape) + secondary analog `Games/Minesweeper/MinesweeperBoardView.swift` lines 126–134 for `GeometryReader` sizing |
| `gamekit/gamekit/Screens/SettingsView.swift` (modify) | Screen (existing card spine) | UI composition | `SettingsView.swift` itself (insert pattern between `appearanceSection` and `audioSection`) | **self-analog** — clone the `audioSection` shape |
| `gamekit/gamekit/App/GameKitApp.swift` (modify) | App-root | dependency injection | `GameKitApp.swift` itself (the existing 4-store injection pattern at lines 38–79, 140–143) | **self-analog** — add a 5th store row |
| `gamekit/gamekit/Resources/Localizable.xcstrings` (modify) | Resource (JSON catalog) | data | existing catalog entries (any) | **self-analog** — append ~10 `videoMode.*` keys |
| `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` (new) | Test (`@Suite struct` Swift Testing) | unit | `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` | **exact** (isolated-UserDefaults helper) |
| `gamekit/gamekitTests/Core/VideoModeLocationTests.swift` *(merge into above per VALIDATION.md or keep separate)* | Test | unit | `SettingsStoreFlagsTests.swift` | **exact** |
| `gamekit/gamekitTests/Core/VideoModeEnvironmentTests.swift` (new) | Test | unit (environment injection round-trip) | `gamekit/gamekitTests/Core/AuthStoreTests.swift` | **strong** (`@MainActor @Suite` shape) |
| `gamekit/gamekitTests/App/GameKitAppTests.swift` (new) | Test | unit | `AuthStoreTests.swift` | **strong** |
| `gamekit/gamekitTests/Screens/SettingsViewTests.swift` (new) | Test (UI-binding) | unit | `SettingsStoreFlagsTests.swift` | role-match (no existing SwiftUI Settings test, so unit-test the binding via Bindable round-trip) |
| `gamekit/gamekitTests/Screens/VideoLocationPickerViewTests.swift` (new) | Test (zone tap + a11y) | unit | `SettingsStoreFlagsTests.swift` | role-match |
| `gamekit/gamekitTests/Resources/LocalizableCatalogTests.swift` (new) | Test (string-key existence) | unit | `gamekit/gamekitTests/Core/ModelContainerSmokeTests.swift` | partial (smoke / existence-check shape) |
| `gamekit/gamekitTests/Regression/SC5RegressionTests.swift` (new) | Test (snapshot regression) | unit | `SettingsStoreFlagsTests.swift` + D-15 (`isOn` is the only branch — placeholder/compile-only test until P10–P12 introduce real reads) | partial |

> **Note on test file count:** 09-VALIDATION.md lists **7 new test files** (some Wave-0 stubs may consolidate VIDEO-01/02/03 into one file). The pattern is identical across all of them — the per-test isolated-UserDefaults helper from `SettingsStoreFlagsTests.swift:36-39`.

---

## Pattern Assignments

### 1. `gamekit/gamekit/Core/VideoModeStore.swift` (Store, KV persistence)

**Analog:** `gamekit/gamekit/Core/SettingsStore.swift`
**RESEARCH verdict:** Topic 3 — pattern is non-drifted (Apr 2026 `AuthStore.swift` ships identical shape). Copy lines 34–155 verbatim, swap fields.

**Header doc-comment pattern** (`SettingsStore.swift:1-29`) — preserve the §"Phase N invariants:" block structure documenting D-05/D-06/D-07 verbatim:
```swift
//  Phase 9 invariants (per D-05, D-06, D-07):
//    - @Observable + @MainActor final class — matches SettingsStore.swift:34-36
//      shape. iOS-17-canonical for SwiftUI views observing the value.
//    - Custom EnvironmentKey injection — @EnvironmentObject is INCOMPATIBLE
//      with @Observable (Pitfall 2 below; P4 RESEARCH Pitfall 1 inheritance).
//    - UserDefaults.bool(forKey:) returns false for unset keys — no
//      register(defaults:) needed for the isEnabled default-false case.
//    - VideoModeLocation rawValue is the persisted form; corrupt strings
//      fall back to .largeBottom per D-03 default.
```

**Class declaration** (`SettingsStore.swift:34-36`) — all three attributes are load-bearing per RESEARCH Topic 3 invariant #1:
```swift
@Observable
@MainActor
final class SettingsStore {
```

**Stored property + didSet** (`SettingsStore.swift:45-49` — the load-bearing shape per Pitfall 1 below):
```swift
var cloudSyncEnabled: Bool {
    didSet {
        userDefaults.set(cloudSyncEnabled, forKey: Self.cloudSyncEnabledKey)
    }
}
```
For Phase 9, the `location` property mirrors this exactly but with raw-string write:
```swift
// RESEARCH Topic 3 invariant #4 — raw-string round-trip, ?? .largeBottom defense
var location: VideoModeLocation {
    didSet {
        userDefaults.set(location.rawValue, forKey: Self.videoModeLocationKey)
    }
}
```

**Constants pattern** (`SettingsStore.swift:104-122`) — `static let` keys at file scope inside the class, comment block on each marking "Renaming = preference loss; locked." For Phase 9: `gamekit.videoModeEnabled` + `gamekit.videoModeLocation` (D-06 verbatim).

**Init pattern** (`SettingsStore.swift:126-141`) — two flavors visible in the file:
- Default-false flag (use plain `bool(forKey:)`):
  ```swift
  self.cloudSyncEnabled = userDefaults.bool(forKey: Self.cloudSyncEnabledKey)
  ```
  → Phase 9 `isEnabled` uses this (default false per ROADMAP SC2).
- Enum raw-string with safe default (use the corruption-resilient pattern from RESEARCH Topic 3 invariant #4):
  ```swift
  self.location = VideoModeLocation(
      rawValue: userDefaults.string(forKey: Self.videoModeLocationKey) ?? ""
  ) ?? .largeBottom
  ```
  This honors D-03 default on fresh installs AND any corrupt plist value.

**EnvironmentKey injection** (`SettingsStore.swift:144-155`) — copy verbatim, rename type:
```swift
private struct SettingsStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SettingsStore()
}

extension EnvironmentValues {
    var settingsStore: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
```

---

### 2. `gamekit/gamekit/Core/VideoModeLocation.swift` (Model enum)

**Analog:** `gamekit/gamekit/Games/Minesweeper/MinesweeperDifficulty.swift`

**Full enum shape** (`MinesweeperDifficulty.swift:17-53`):
```swift
//  - Raw values are the stable serialization key for P4 stats and JSON
//    export (D-02) — renaming any case = data break
//  - Foundation-only — ROADMAP P2 SC5

import Foundation

nonisolated enum MinesweeperDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard

    var rows: Int { ... }
    var cols: Int { ... }
    var mineCount: Int { ... }
}
```

**Adaptation for Phase 9** (D-07 + RESEARCH Topic 2 invariants):
```swift
import Foundation

/// 6-zone PiP vocabulary frozen from Phase 8 VIDEO-MODE-LAYOUTS.md (D-07).
/// Raw values are persisted to UserDefaults via VideoModeStore (D-06) —
/// renaming any case = preference loss on existing installs.
enum VideoModeLocation: String, CaseIterable, Sendable {
    case largeTop
    case largeBottom        // D-03 default
    case smallTopLeft
    case smallTopRight
    case smallBottomLeft
    case smallBottomRight
}
```
**Differences from `MinesweeperDifficulty`:**
- No `Codable` (not exported to JSON envelope — local UserDefaults only).
- No `nonisolated` (not consumed from an engine context; SwiftUI views read it main-actor-side).
- `localizedLabel` accessor (Discretion lock from RESEARCH Topic 2) reading `videoMode.location.<case>` xcstrings keys — define here, not in the View.

---

### 3. `gamekit/gamekit/Core/VideoCompactControlRow.swift` (Component)

**Analog:** `../DesignKit/Sources/DesignKit/Components/DKCard.swift`
**RESEARCH verdict:** Topic 1 — generic `@ViewBuilder` closure slots (option a), zero `AnyView`.

**Generic-Content + @ViewBuilder init pattern** (`DKCard.swift` full file, 22 lines):
```swift
import SwiftUI

public struct DKCard<Content: View>: View {
    private let theme: Theme
    private let content: Content

    public init(theme: Theme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        content
            .padding(theme.spacing.l)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
    }
}
```

**Adaptation for `VideoCompactControlRow`** (RESEARCH Topic 1 skeleton — 3 generic slots + 2 action closures, slot order locked by D-13):
```swift
public struct VideoCompactControlRow<Primary: View, Picker: View, Secondary: View>: View {
    let theme: Theme
    let onBack: () -> Void
    let onSettings: () -> Void
    @ViewBuilder let primaryInfo: () -> Primary
    @ViewBuilder let picker: () -> Picker
    @ViewBuilder let secondaryInfo: () -> Secondary

    public var body: some View {
        HStack(spacing: theme.spacing.s) {           // D-13 inter-item gap
            backButton; primaryInfo(); picker(); secondaryInfo(); settingsButton
        }
        .frame(height: theme.spacing.xl)             // D-13 pill height anchor
    }
    // backButton / settingsButton internal helpers read theme.radii.button (D-13).
}
```

**Stub `#Preview` pattern** (D-04, SC4) — the file ships with **exactly one** `#Preview` block at the bottom showing all 3 game slot mappings (Mines / Merge / Nonogram per Phase 8 D-08). No DEBUG-only screen, no HomeView dev preview (per D-04 — leaves no cleanup trail for P11/P12).

**Token discipline reminder** (D-13 + CONTEXT code_context line 222): `Core/` is **exempt** from the pre-commit hook that rejects literal `cornerRadius:` / `padding(N)`, but discipline carries — every dimension comes from `theme.radii.*` / `theme.spacing.*`. Verify against the audited token names in CLAUDE.md §2: radii are `{card, button, chip, sheet}` only; spacing is the 6-step `{xs, s, m, l, xl, xxl}` scale.

---

### 4. `gamekit/gamekit/Screens/VideoMode/VideoLocationPickerView.swift` (Screen)

**Primary analog:** `gamekit/gamekit/Screens/FullThemePickerView.swift`
**Secondary analog (for GeometryReader sizing):** `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift:126-148`
**RESEARCH verdict:** Topic 2 — `GeometryReader` + explicit `frame` proportions; outer `.aspectRatio(9.0/19.5, contentMode: .fit)`.

**Push-destination shape** (`FullThemePickerView.swift` full file, 39 lines) — this is the **exact wrapper shape** the picker uses (no own NavigationStack — pushed onto Settings' stack):
```swift
struct FullThemePickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                DKThemePicker(...)
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "More themes"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Adaptation for `VideoLocationPickerView`:**
- Add `@Environment(\.videoModeStore) private var videoModeStore` (NOT `@EnvironmentObject` — Pitfall 2).
- Replace the `DKThemePicker(...)` call with the `iPhoneOutline` subview (RESEARCH Topic 2 skeleton lines 168–209).
- Add the VIDEO-14 explanation paragraph below the outline (D-10 verbatim copy from `Localizable.xcstrings`).
- Navigation title: `String(localized: "Video location")`.

**GeometryReader proportion pattern** (`MinesweeperBoardView.swift:126-134`) — the in-repo precedent for "size from `proxy.size`, derive dimensions from theme + ratios":
```swift
GeometryReader { proxy in
    let cs = Self.cellSize(
        forWidth: proxy.size.width,
        height: proxy.size.height,
        cols: board.cols,
        rows: board.rows,
        padding: theme.spacing.s,
        spacing: 0
    )
    // ...
}
```
For Phase 9, derive `bandH = h * 0.25`, `midH = h * 0.50`, `cornerW = w * 0.40`, `cornerH = midH * 0.45` (RESEARCH Topic 2 skeleton line 174). Outer outline uses `theme.radii.sheet`, zones use `theme.radii.chip`.

**A11Y pattern (D-09)** — each zone:
```swift
.accessibilityLabel(Text(loc.localizedLabel))            // "Large top", "Small bottom-left", …
.accessibilityValue(Text(selected == loc ? String(localized: "Selected") : ""))
.accessibilityAddTraits(.isButton)
```
Container outline: `.accessibilityElement(children: .contain)` + container label "Video location picker, choose where your video will appear" (Discretion lock).

---

### 5. `gamekit/gamekit/Screens/SettingsView.swift` (modify — insert VIDEO MODE card)

**Self-analog:** the existing `audioSection` (`SettingsView.swift:178-210`) is the **exact card shape** to clone — section header + `DKCard` + `SettingsToggleRow`s separated by 1pt `Rectangle().fill(theme.colors.border)` dividers.

**Insertion site** (`SettingsView.swift:78-82` — main `body` VStack):
```swift
VStack(alignment: .leading, spacing: theme.spacing.l) {
    appearanceSection
    audioSection                         // ← INSERT videoModeSection between these two (D-01)
    SettingsSyncSection(theme: theme)
    dataSection
    SettingsAboutSection(theme: theme)
}
```

**Card pattern to clone** (`SettingsView.swift:190-210`):
```swift
settingsSectionHeader(theme: theme, String(localized: "FEEL"))
DKCard(theme: theme) {
    VStack(spacing: 0) {
        SettingsToggleRow(
            theme: theme,
            glyph: "iphone.radiowaves.left.and.right",
            label: String(localized: "Haptics"),
            isOn: Bindable(settingsStore).hapticsEnabled
        )
        Rectangle()
            .fill(theme.colors.border)
            .frame(height: 1)
        SettingsToggleRow(...)
    }
}
```

**Adaptation for VIDEO MODE card** (D-01 + D-11):
```swift
settingsSectionHeader(theme: theme, String(localized: "VIDEO MODE"))
DKCard(theme: theme) {
    VStack(spacing: 0) {
        SettingsToggleRow(
            theme: theme,
            glyph: "play.rectangle",                 // candidate; Discretion
            label: String(localized: "Video Mode"),
            isOn: Bindable(videoModeStore).isEnabled
        )
        if videoModeStore.isEnabled {                // D-01: row appears only when On
            Rectangle().fill(theme.colors.border).frame(height: 1)
            NavigationLink(destination: VideoLocationPickerView()) {
                settingsNavRow(
                    theme: theme,
                    title: String(localized: "Video location: \(videoModeStore.location.localizedLabel)")
                )
            }
            .buttonStyle(.plain)
        }
    }
}
```

**Bindable + Environment pattern** (`SettingsView.swift:65, 197`) — already proven:
```swift
@Environment(\.settingsStore) private var settingsStore
// ...
isOn: Bindable(settingsStore).hapticsEnabled
```
Mirror for Phase 9:
```swift
@Environment(\.videoModeStore) private var videoModeStore
// ...
isOn: Bindable(videoModeStore).isEnabled
```

**Existing local helpers reused** (no new components needed):
- `SettingsToggleRow` (file-private, `SettingsView.swift:330-351`)
- `settingsSectionHeader(theme:_:)` (`SettingsComponents.swift:14-21`)
- `settingsNavRow(theme:title:)` (`SettingsComponents.swift:24-36`)

---

### 6. `gamekit/gamekit/App/GameKitApp.swift` (modify — inject VideoModeStore)

**Self-analog:** the existing 4-store injection at `GameKitApp.swift:38-79, 140-143` — Phase 9 adds a 5th store row following the same shape.

**Property declaration pattern** (`GameKitApp.swift:39-42`):
```swift
@State private var settingsStore: SettingsStore
@State private var sfxPlayer: SFXPlayer
@State private var authStore: AuthStore
@State private var cloudSyncStatusObserver: CloudSyncStatusObserver
```
Add: `@State private var videoModeStore: VideoModeStore` (placement: after `settingsStore`, before `sfxPlayer` — keeps user-preference stores adjacent).

**Init pattern** (`GameKitApp.swift:54-69`):
```swift
let store = SettingsStore()
_settingsStore = State(initialValue: store)
// ...
let sfx = SFXPlayer()
_sfxPlayer = State(initialValue: sfx)
// ...
let auth = AuthStore()
_authStore = State(initialValue: auth)
```
Mirror for Phase 9 (RESEARCH Topic 3 invariant #6):
```swift
let videoMode = VideoModeStore()
_videoModeStore = State(initialValue: videoMode)
```
Placement: right after `_settingsStore`, before `_sfxPlayer`, so the order matches the property declaration block.

**Environment injection pattern** (`GameKitApp.swift:138-145`):
```swift
RootTabView()
    .environmentObject(themeManager)
    .environment(\.settingsStore, settingsStore)
    .environment(\.sfxPlayer, sfxPlayer)
    .environment(\.authStore, authStore)
    .environment(\.cloudSyncStatusObserver, cloudSyncStatusObserver)
    .preferredColorScheme(preferredScheme)
    .modelContainer(sharedContainer)
```
Add one line — placement: right after `\.settingsStore`, before `\.sfxPlayer`:
```swift
.environment(\.videoModeStore, videoModeStore)
```

---

### 7. `gamekit/gamekit/Resources/Localizable.xcstrings` (modify — add ~10 keys)

**Self-analog:** existing key entries in the catalog (every `Text(String(localized: "..."))` site in `SettingsView.swift`).

**Key naming pattern** (Discretion lock + CONTEXT line 130): `videoMode.<segment>` prefix, all keys clustered:
- `videoMode.sectionHeader` → "VIDEO MODE"
- `videoMode.toggleLabel` → "Video Mode"
- `videoMode.locationRowTitle` → "Video location: %@" (interpolation of selected label)
- `videoMode.location.largeTop` → "Large top"
- `videoMode.location.largeBottom` → "Large bottom"
- `videoMode.location.smallTopLeft` → "Small top-left"
- `videoMode.location.smallTopRight` → "Small top-right"
- `videoMode.location.smallBottomLeft` → "Small bottom-left"
- `videoMode.location.smallBottomRight` → "Small bottom-right"
- `videoMode.pickerTitle` → "Video location"
- `videoMode.pickerContainerA11yLabel` → "Video location picker, choose where your video will appear"
- `videoMode.zoneFillLabel` → "Your video will go here"
- `videoMode.manualSelectionExplanation` → VIDEO-14 verbatim copy (D-10):
  > "Pick where your video is on screen — GameDrawer can't detect it automatically. Choose the zone closest to your video to keep the board and controls clear."

**Catalog mechanics:** xcstrings is a JSON catalog (`sourceLanguage: en`, `strings: { ... }` with per-key `comment` / `localizations.en.stringUnit.{state: translated, value: "..."}`). FOUND-05 discipline: ALL keys land in ONE task (Pitfall 3 below).

---

### 8. Test files (7 new — Wave 0)

**Primary analog for all:** `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift`

**Top-of-file pattern** (`SettingsStoreFlagsTests.swift:23-29`):
```swift
import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("SettingsStoreFlags")
struct SettingsStoreFlagsTests {
    // ...
}
```

**Isolated-UserDefaults helper** (`SettingsStoreFlagsTests.swift:36-39`) — load-bearing for Swift Testing's default concurrent execution:
```swift
static func makeIsolatedDefaults() -> UserDefaults {
    let suite = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}
```

**Default-value test pattern** (`SettingsStoreFlagsTests.swift:43-55`):
```swift
@Test("Defaults: cloudSync=false, haptics=true, sfx=false, hasSeenIntro=false")
func defaults_haveCorrectInitialValues() {
    let defaults = Self.makeIsolatedDefaults()
    let store = SettingsStore(userDefaults: defaults)
    #expect(store.cloudSyncEnabled == false)
    #expect(store.hapticsEnabled == true)
    // ...
}
```

**Round-trip persistence test pattern** (`SettingsStoreFlagsTests.swift:59-69`):
```swift
@Test("Setting hapticsEnabled = false persists to UserDefaults under gamekit.hapticsEnabled key")
func setHapticsEnabled_persistsToUserDefaults() {
    let defaults = Self.makeIsolatedDefaults()
    let store = SettingsStore(userDefaults: defaults)
    store.hapticsEnabled = false
    // Re-read directly from defaults — proves didSet wrote through
    #expect(defaults.bool(forKey: SettingsStore.hapticsEnabledKey) == false)
    // Re-construct a fresh store from the same defaults — proves init reads back
    let reloaded = SettingsStore(userDefaults: defaults)
    #expect(reloaded.hapticsEnabled == false)
}
```

**Adaptation for `VideoModeStoreTests.swift`** (covers 09-VALIDATION.md tasks 09-01-01 through 09-01-05):
- `test_isEnabled_defaults_to_false` — bool(forKey:) returns false for unset key (covers Apple-docs invariant).
- `test_isEnabled_persists` — `store.isEnabled = true` → re-read direct + reload-store.
- `test_location_default_is_largeBottom` — fresh suite → `store.location == .largeBottom` (D-03).
- `test_location_persists_all_cases` — loop over `VideoModeLocation.allCases`, write each, reload, `#expect` match (covers VIDEO-02 6-case exhaustiveness).
- `test_location_enum_has_6_cases` — `#expect(VideoModeLocation.allCases.count == 6)`.
- `test_corruptLocation_fallsBackToLargeBottom` — `defaults.set("garbage", forKey: ...)` then construct store → `#expect(store.location == .largeBottom)` (RESEARCH Topic 3 invariant #4).

**Environment-injection test pattern** — there is no exact in-repo test for `@Environment(\.fooStore)` injection round-trip yet. Closest analog is the construction pattern in `AuthStoreTests.swift:74-80` (constructor seam + #expect against the published surface). For Phase 9, the simplest unit shape:
```swift
@Test("EnvironmentValues.videoModeStore returns the injected store, not the default")
func test_environmentKey_returns_injected() {
    let injected = VideoModeStore(userDefaults: makeIsolatedDefaults())
    var env = EnvironmentValues()
    env.videoModeStore = injected
    #expect(env.videoModeStore === injected)
}
```
(Identity check works because `VideoModeStore` is a class.)

**SC5 regression test** (09-07-01) — per D-15, P9 game views don't read `videoModeStore.isOn` yet, so the test is a *placeholder compile-only assertion* until P10–P12 introduces real branches. Suggested shape: `#expect(true)` with a comment pointing to D-15 + a `// TODO(P11): swap to actual snapshot diff` marker. The real snapshot infrastructure is a Phase 10/11 deliverable.

---

## Shared Patterns

### Auth / Guard
**Not applicable to Phase 9** — VideoMode has no auth gating (it's a local preference). No middleware pattern to apply.

### Error Handling
**Source:** `SettingsStore.swift:130-141` — defensive defaults (`?? true`, `?? .largeBottom`) replace exception flow; UserDefaults reads never throw, so no try/catch needed.
**Apply to:** `VideoModeStore.init` only — the `location` raw-string read uses the `?? .largeBottom` fallback for both fresh-install and corrupt-plist defense (one pattern handles both cases).

### Logging
**Not used in Phase 9.** `os.Logger` is reserved for security-relevant or user-visible-failure paths (`AuthStore.swift:99-102`, `SettingsView.swift:68-71`). A UserDefaults round-trip has no failure mode worth logging.

### Token discipline (CLAUDE.md §2 + §8.4)
**Source:** `SettingsView.swift:138-176` (`appearanceSection`) — every dimension reads `theme.{spacing|radii|colors|typography}.<token>`. Zero literal integers.
**Apply to:** `VideoCompactControlRow.swift` (Core, hook-exempt but discipline carries) + `VideoLocationPickerView.swift` (Screens — hook-enforced). Token allowlist:
- Radii: `card | button | chip | sheet` only — no `.medium` / `.small` per CLAUDE.md §2.
- Spacing: `xs | s | m | l | xl | xxl` only.
- Phase 8 D-13 anchors for the row: pill radius `theme.radii.button`, height `theme.spacing.xl`, gap `theme.spacing.s`.
- iPhone-outline: outer corner `theme.radii.sheet`, zone corner `theme.radii.chip`, fill `theme.colors.surface` / selected `theme.colors.accentPrimary.opacity(0.25)`.

### Localization (FOUND-05)
**Source:** every `String(localized: "...")` call in `SettingsView.swift` (e.g. line 105 `String(localized: "Reset all stats?")`).
**Apply to:** every Phase 9 user-visible string — Settings labels, picker title, zone labels (via `VideoModeLocation.localizedLabel`), VIDEO-14 explanation paragraph, "Your video will go here" zone fill label. **Zero hardcoded `Text("...")`** anywhere in the new code.

### Theme audit (CLAUDE.md §8.12)
**Source:** Phase 8 audit corpus (`.planning/phases/08-video-mode-design/`).
**Apply to:** picker sub-screen (`VideoLocationPickerView`) **before calling Phase 9 done** — verify on Classic (Chrome Diner) + one Loud preset (Voltage / Dracula). Failure mode flagged by RESEARCH Pitfall 5: selected-zone fill is `theme.colors.accentPrimary.opacity(0.25)`, "Your video will go here" label sits on top — accent-on-accent at low alpha is the legibility-fail case. If illegible, swap label to `theme.colors.textPrimary` (which already reads against any surface).

---

## Pitfalls (Per-File)

> Inherited from RESEARCH §"Pitfalls" — repeated here keyed to the specific file that triggers them so the planner can cite per-task.

### `VideoModeStore.swift`
1. **Pitfall 1 — Computed-property mistake (RESEARCH lines 292-297).** Do NOT write `var location: VideoModeLocation { userDefaults.string(...) }`. `@Observable` only tracks **stored** properties — SwiftUI won't redraw on writes through a computed getter. Mirror the `SettingsStore.swift:45-49` `var x: T { didSet { ... } }` shape exactly. This was the P7.1 fix in `AuthStore.swift:120-123`.

### `VideoLocationPickerView.swift` + `SettingsView.swift` (consumers)
2. **Pitfall 2 — `@EnvironmentObject` slip-in (RESEARCH lines 299-304).** `@Observable` is **not** `ObservableObject`. Any view that types `@EnvironmentObject private var videoModeStore: VideoModeStore` will compile but crash on first `body` evaluation. ALWAYS `@Environment(\.videoModeStore) private var videoModeStore`. Planner / pre-merge check: grep `@EnvironmentObject.*VideoModeStore` and fail if found.

### `Localizable.xcstrings`
3. **Pitfall 3 — Key explosion handled in ONE task (RESEARCH lines 306-311).** Six location labels + zone fill label + explanation paragraph + Settings row labels = ~10 new keys. Add ALL in one task / one commit with the `videoMode.*` prefix, ALL referenced via `String(localized:)`. Missing one = silent fallback to the key-name string in non-EN locales when L10N-V2-01 ships.

### `VideoLocationPickerView.swift`
4. **Pitfall 4 — Token discipline on the iPhone outline (RESEARCH lines 313-318).** `Screens/VideoMode/` triggers the pre-commit hook rejecting literal `cornerRadius: <int>` / `padding(<int>)`. The RESEARCH skeleton uses `theme.radii.sheet`, `theme.radii.chip`, `theme.spacing.s` — verify none of the GeometryReader-derived sizes accidentally pass an integer to `padding(...)` / `cornerRadius(...)`. Use `.frame(width:height:)` for computed sizes (hook targets literal forms only).

5. **Pitfall 5 — Theme audit on Loud preset (RESEARCH lines 320-325, CLAUDE.md §8.12).** Selected-zone fill is `theme.colors.accentPrimary.opacity(0.25)`. On Voltage / Dracula, accent-on-accent at low alpha can collapse the "Your video will go here" label. If illegible, switch the label to `theme.colors.textPrimary`. The audit is a phase-gate, not optional.

### `VideoCompactControlRow.swift`
6. **D-04 enforcement** — exactly ONE `#Preview` block at the bottom showing all 3 game slot mappings (Mines / Merge / Nonogram per Phase 8 D-08). NO DEBUG-only standalone screen, NO HomeView dev preview hook (those leave a trail P11/P12 has to clean up).

### `GameKitApp.swift`
7. **Construction order** — `VideoModeStore()` constructor has no dependencies, so it can land anywhere in `init()`. Suggested placement (matches property declaration order): right after `_settingsStore = State(initialValue: store)` on `GameKitApp.swift:55`, before `_sfxPlayer` on line 62. This keeps user-preference stores adjacent.

---

## No Analog Found

**None.** Every file Phase 9 ships has a strong in-repo precedent. RESEARCH Topic 3 verified the foundational store/environment pattern is non-drifted between Feb 2026 (`SettingsStore`) and Apr 2026 (`AuthStore`); Topic 1 verified the component shape (`DKCard`); Topic 2 verified the picker layout tool (`GeometryReader` + aspect ratio).

---

## Metadata

**Analog search scope:**
- `gamekit/gamekit/Core/` (24 files — stores, models, services)
- `gamekit/gamekit/Screens/` (13 files — Settings spine, theme picker, root tab)
- `gamekit/gamekit/App/` (3 files — app root + DEBUG seeder)
- `gamekit/gamekit/Games/Minesweeper/` + `Games/Merge/` + `Games/Nonogram/` (sampled for enum + GeometryReader patterns)
- `gamekit/gamekitTests/Core/` (9 files — `SettingsStoreFlagsTests` is the universal test analog)
- `../DesignKit/Sources/DesignKit/Components/DKCard.swift` (generic `@ViewBuilder` precedent)

**Files scanned for content:** 12 (read in full or relevant range; no re-reads).

**Pattern extraction date:** 2026-05-12
**Phase:** 09-video-mode-foundation
