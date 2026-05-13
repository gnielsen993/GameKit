# Phase 9: Video Mode Foundation - Research (TARGETED)

**Researched:** 2026-05-12
**Domain:** SwiftUI iOS 17+, Swift 6, `@Observable` + custom `EnvironmentKey` injection
**Confidence:** HIGH (all three topics resolved from in-repo precedent + Phase 4/8 locks)

## Summary

Three open questions for Phase 9 are answered: (1) `VideoCompactControlRow` uses
**generic `@ViewBuilder` closure slots** — matches `DKCard<Content: View>` and every
`@ViewBuilder` site in the repo; minimal call-site code, no `AnyView`, no preference-key
plumbing. (2) The iPhone-outline picker uses **`GeometryReader` + explicit `frame`
proportions** (not `Grid`) because the 6 zones are an irregular layout (two full-width
bands + four corners), and zones must read `theme.radii.sheet` / `theme.colors.accent`
directly. (3) The `@Observable` + custom `EnvironmentKey` pattern from `SettingsStore.swift`
(2026-02, P4 D-29) is **still current** for iOS 17.5+ / Swift 6 strict-concurrency —
`AuthStore.swift` (P6, 2026-04) ships the same shape verbatim. Copy `SettingsStore`'s
shape; no drift.

**Primary recommendation:** Generic `@ViewBuilder` row + GeometryReader picker +
verbatim `SettingsStore` mirror for `VideoModeStore`.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-05:** `VideoModeStore` = `@Observable @MainActor final class`, custom
  `EnvironmentKey`, constructed once in `GameKitApp.init()`. NOT `ObservableObject`.
- **D-06:** Persistence = `UserDefaults.standard`, keys
  `gamekit.videoModeEnabled: Bool` + `gamekit.videoModeLocation: String`.
- **D-07:** `enum VideoModeLocation: String, CaseIterable, Sendable` — 6 cases
  `largeTop | largeBottom | smallTopLeft | smallTopRight | smallBottomLeft | smallBottomRight`.
- **D-01:** Settings `VIDEO MODE` card between `APPEARANCE` and `HAPTICS`; toggle
  always shown, NavigationLink row appears only when On.
- **D-02:** Picker is visual iPhone outline (not radio list); 6 tappable zones;
  selected fills `theme.colors.accent` low-alpha + "Your video will go here" label.
- **D-08:** Picker lives at `Screens/VideoMode/VideoLocationPickerView.swift`.
- **D-03:** Default selection when first flipped On = `largeBottom`.
- **D-10:** VIDEO-14 copy verbatim; sourced from `Localizable.xcstrings`.
- **D-11:** First toggle On does NOT auto-navigate.
- **D-12:** Component lives at `Core/VideoCompactControlRow.swift`.
- **D-13:** Token anchors locked — pill radius `theme.radii.button`, pill height
  `theme.spacing.xl`, gap `theme.spacing.s`. Slot order
  `Back | primary info | picker | secondary info | settings`.
- **D-04:** Stub = single `#Preview` block at bottom of component file, 3 game slot
  mappings shown.
- **D-15:** Off-state byte-identical: games in P9 never read `videoModeStore.isOn`
  yet — automatic.

### Claude's Discretion
- Localization key naming: `videoMode.location.{largeTop,…}` per existing xcstrings
  pattern.
- iPhone-outline aspect ratio + outer-frame corner = `theme.radii.sheet`; aspect
  ≈19.5:9 (no new tokens).
- VoiceOver container label phrasing beyond the locked zone names.
- Whether a tiny "Current: <label>" echo sits above the iPhone outline.

### Deferred Ideas (OUT OF SCOPE)
- Auto-detection of another app's PiP frame (no public iOS API).
- Promoting iPhone-outline pattern to DesignKit (wait for 2+ consumers).
- Live `ModelConfiguration` reconfiguration for the VideoMode keys.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIDEO-01 | Off/On toggle, default Off, persisted | Topic 3 — `SettingsStore` pattern verbatim |
| VIDEO-02 | 6-option vocabulary | D-07 enum locked; Topic 2 — 6 zones in picker |
| VIDEO-03 | Selected location persists + observable shared store | Topic 3 — `@Observable` + EnvironmentKey injection |
| VIDEO-04 | Shared compact row component, locked slot order, tokens only | Topic 1 — `@ViewBuilder` closures + Phase 8 token table |
| VIDEO-14 | One-paragraph "manual selection only" copy in Settings | Wired via D-10 + xcstrings (no research needed; copy is locked) |

---

## Topic 1 — `VideoCompactControlRow` Component API Shape (D-14)

### Verdict: **Generic `@ViewBuilder` closure slots** (option a)

```
VideoCompactControlRow<Primary, Picker, Secondary>(theme:, back:, settings:, @ViewBuilder primaryInfo:, @ViewBuilder picker:, @ViewBuilder secondaryInfo:)
```

Each slot is a generic `View`-conforming parameter built with `@ViewBuilder`.
`back` and `settings` are `() -> Void` action closures (icon button shape locked by
D-13 → `theme.radii.button`). Three slots are content; two are actions; total = five
slots in the locked `Back | primary info | picker | secondary info | settings` order.

### Rationale (2-3 sentences)

`DKCard<Content: View>` (`DesignKit/Components/DKCard.swift`) is the established
project precedent — generic `Content: View` + `@ViewBuilder` init. Every existing
SwiftUI composition site in the repo (`SettingsView.appearanceSection`,
`SettingsSyncSection`, `HomeView`, `StatsView`) uses `@ViewBuilder` for the same
reason: zero `AnyView` boxing, full type preservation through SwiftUI's diffing
algorithm, no `PreferenceKey`/environment-injection ceremony for one consumer
per game view. Option (c) (environment-injected slot bindings via `.videoModeSlots(…)`)
is **rejected** because P10 already needs `.videoModeAware()` for layout reflow and
stacking two environment-injected modifier surfaces on the same wrap site is
ergonomic poison; option (b) (typed struct of `AnyView`s) is **rejected** because
`AnyView` defeats SwiftUI's view-identity equality and is forbidden by the project's
"smallest change" rule (CLAUDE.md §4).

### Code skeleton (Mines call site, ≤25 lines)

```swift
// Core/VideoCompactControlRow.swift
public struct VideoCompactControlRow<Primary: View, Picker: View, Secondary: View>: View {
    let theme: Theme
    let onBack: () -> Void
    let onSettings: () -> Void
    @ViewBuilder let primaryInfo: () -> Primary
    @ViewBuilder let picker: () -> Picker
    @ViewBuilder let secondaryInfo: () -> Secondary

    public var body: some View {
        HStack(spacing: theme.spacing.s) {            // D-13 inter-item gap
            backButton; primaryInfo(); picker(); secondaryInfo(); settingsButton
        }
        .frame(height: theme.spacing.xl)              // D-13 pill height anchor
    }
    // backButton / settingsButton internal helpers read theme.radii.button.
}

// Mines call site (Phase 11 — illustrative only; P9 ships only the #Preview):
VideoCompactControlRow(theme: theme, onBack: { dismiss() }, onSettings: { openSettings() }) {
    InfoChip(theme: theme, label: "\(flagsRemaining)", glyph: "flag")        // primary info
} picker: {
    RevealFlagPicker(mode: $vm.interactionMode, theme: theme)                // picker (Mines = Reveal/Flag)
} secondaryInfo: {
    InfoChip(theme: theme, label: timer.formatted(), glyph: "timer")         // secondary info
}
```

This shape lets Phase 11 swap `RevealFlagPicker` for Merge's `ModePicker` or
Nonogram's `FillMarkPicker` with **zero changes to `VideoCompactControlRow`** — only
the call-site closure body changes. Phase 10's `.videoModeAware()` modifier can
sit outside this view entirely (composed on the wrapping `VStack`, not on the row).

---

## Topic 2 — iPhone-Outline Picker Layout (D-02, D-09)

### Verdict: **`GeometryReader` + explicit `frame` proportions** (not SwiftUI `Grid`)

The 6 zones are an **irregular** layout: two full-width bands occupy ~25% of the
outline's vertical space each (top + bottom), and the middle ~50% holds a 2×2 grid
of the four corner rects. `Grid` would force a uniform row/column structure that
doesn't match the design — large bands span all columns, small corners span one.
`GeometryReader` reads the available size, the outer outline applies
`.aspectRatio(9.0/19.5, contentMode: .fit)` (iPhone 17 Pro Max ratio, CONTEXT D-04
from Phase 8), and each zone is positioned with `.frame(width:height:)` derived from
`geo.size`. No hardcoded pixel sizes — every dimension is a ratio of
`geo.size.width` / `geo.size.height`.

### Rationale (2-3 sentences)

The picker's job is to communicate spatial location, not to be a pixel-perfect device
mockup, so absolute sizing is the wrong tool; ratio-of-container is correct because
the outline must resize with Dynamic Type and iPad sidebars without re-layout. The
outer rounded-rect frame reads `theme.radii.sheet` for its corner (Discretion lock
above) and `theme.colors.surface` for fill — matches D-02 verbatim. A11Y wires
through `accessibilityElement(children: .contain)` on the outline + per-zone
`accessibilityLabel` / `accessibilityValue` / `.accessibilityAddTraits(.isButton)`
per D-09, so VoiceOver gets a six-button picker without seeing the visual diagram.

### Code skeleton (≤30 lines)

```swift
// Screens/VideoMode/VideoLocationPickerView.swift (excerpt)
struct iPhoneOutline: View {
    let theme: Theme; let selected: VideoModeLocation; let onSelect: (VideoModeLocation) -> Void
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let bandH = h * 0.25, midH = h * 0.50, cornerW = w * 0.40, cornerH = midH * 0.45
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: theme.radii.sheet, style: .continuous)
                    .fill(theme.colors.surface)
                    .overlay(RoundedRectangle(cornerRadius: theme.radii.sheet).stroke(theme.colors.border, lineWidth: 1))
                VStack(spacing: 0) {
                    zone(.largeTop).frame(width: w, height: bandH)
                    HStack(spacing: 0) {
                        VStack(spacing: theme.spacing.s) {
                            zone(.smallTopLeft).frame(width: cornerW, height: cornerH)
                            zone(.smallBottomLeft).frame(width: cornerW, height: cornerH)
                        }
                        Spacer()
                        VStack(spacing: theme.spacing.s) {
                            zone(.smallTopRight).frame(width: cornerW, height: cornerH)
                            zone(.smallBottomRight).frame(width: cornerW, height: cornerH)
                        }
                    }.frame(width: w, height: midH).padding(.horizontal, theme.spacing.s)
                    zone(.largeBottom).frame(width: w, height: bandH)
                }
            }
        }.aspectRatio(9.0/19.5, contentMode: .fit)
    }
    @ViewBuilder private func zone(_ loc: VideoModeLocation) -> some View {
        Button { onSelect(loc) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .fill(selected == loc ? theme.colors.accentPrimary.opacity(0.25) : Color.clear)
                if selected == loc { Text(String(localized: "Your video will go here")).font(theme.typography.caption) }
            }
        }
        .accessibilityLabel(Text(loc.localizedLabel))           // D-09: "Large top", "Small bottom-left", …
        .accessibilityValue(Text(selected == loc ? String(localized: "Selected") : ""))
        .accessibilityAddTraits(.isButton)
    }
}
```

`VideoModeLocation.localizedLabel` is a `String(localized:)` accessor on the enum
reading the 6 `videoMode.location.*` xcstring keys (Discretion lock). The outline
itself gets `.accessibilityElement(children: .contain)` plus a container label like
"Video location picker, choose where your video will appear".

---

## Topic 3 — `@Observable` + Custom `EnvironmentKey` Drift Check (Phase 4 D-29)

### Verdict: **Pattern is still current — copy `SettingsStore.swift` verbatim**

The exact pattern in `SettingsStore.swift` (Feb 2026, P4 D-29) is preserved
verbatim in `AuthStore.swift` (Apr 2026, P6 D-13). Both ship in production under
Swift 6 strict concurrency. No drift items between then and 2026-05.

### Verified pattern invariants (from `SettingsStore.swift:34-155`)

1. **Class declaration:** `@Observable` + `@MainActor` + `final class` — all three
   needed; `@Observable` triggers the macro, `@MainActor` keeps `didSet` UserDefaults
   writes main-actor-isolated (Swift 6 strict-concurrency clean), `final` enables
   the macro's stored-property tracking optimization.

2. **Stored property + `didSet`:** `var foo: Bool { didSet { userDefaults.set(foo, forKey: Self.fooKey) } }`
   shape — the `@Observable` macro only tracks **stored properties** (per `AuthStore.swift:120-123`
   in-file comment, "P7.1 fix: stored, not computed. The @Observable macro only
   tracks stored properties"). Computed properties that read from a backing store
   do NOT trigger SwiftUI invalidation. This is a load-bearing detail.

3. **`UserDefaults.bool(forKey:)` returns `false` for unset keys** (Apple docs) —
   for `videoModeEnabled` defaulting to `false` (CONTEXT D-06, ROADMAP SC2 "default Off"),
   plain `userDefaults.bool(forKey:)` is correct. No optional-cast fallback needed.

4. **String round-trip for the enum** — `videoModeLocation`: write
   `userDefaults.set(location.rawValue, forKey: …)`; read via
   `VideoModeLocation(rawValue: userDefaults.string(forKey: …) ?? "") ?? .largeBottom`.
   The `?? .largeBottom` honors D-03 default on fresh installs AND on any corrupt
   string (defensive — a hand-edited plist can't crash the store).

5. **Custom `EnvironmentKey` injection:**
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
   Identical to `SettingsStore.swift:144-155`. Consumers use
   `@Environment(\.videoModeStore) private var videoModeStore`.
   **NEVER** `@EnvironmentObject` — `@Observable` is not `ObservableObject` and the
   compiler will silently let `@EnvironmentObject` typecheck through `as!`-style
   bridging that crashes at first view body access (P4 RESEARCH Pitfall 1).

6. **App-level injection** — in `GameKitApp.init()`, add
   `_videoModeStore = State(initialValue: VideoModeStore())` (mirrors P6
   `_authStore = State(initialValue: auth)` at `GameKitApp.swift:69`), then add
   `.environment(\.videoModeStore, videoModeStore)` to the `RootTabView()` modifier
   chain at line 142.

7. **Bindable for two-way writes** — Settings toggle binding uses
   `Bindable(videoModeStore).isOn` (mirrors `SettingsView.swift:197`'s
   `Bindable(settingsStore).hapticsEnabled` for the Haptics toggle). `Bindable` is
   the iOS-17-canonical bridge from `@Observable` to SwiftUI's `Binding<T>`.

### Drift items: **None.**

No `@Observable` macro changes affecting `var x: Bool { didSet { … } }` shape on
`@MainActor final class` between iOS 17.0 (where the pattern was specified) and
iOS 17.5 / Xcode 16 / Swift 6. Swift 6 strict-concurrency adds no new requirements
to this pattern — the `@MainActor` annotation is already what makes UserDefaults
writes safe. **Recommendation: copy `SettingsStore.swift` lines 34–155 verbatim,
swap the two flags for `isEnabled` + `location`, ship it.**

---

## Pitfalls (Planner Must Guard Against)

1. **Computed property mistake.** Do NOT write
   `var location: VideoModeLocation { userDefaults.string(...) }`. `@Observable`
   only tracks **stored** properties — SwiftUI won't redraw on writes through a
   computed getter. This was the P7.1 fix in `AuthStore.swift:120-123`. The
   property must be `private(set) var location: VideoModeLocation { didSet { … } }`
   with the value mirrored to UserDefaults in `didSet`.

2. **`@EnvironmentObject` slip-in.** `@Observable` is **not** `ObservableObject`.
   Any Settings/picker view that mistakenly types
   `@EnvironmentObject private var videoModeStore: VideoModeStore` will compile
   but crash on first `body` evaluation (P4 RESEARCH Pitfall 1 — locked anti-pattern).
   Consumers must use `@Environment(\.videoModeStore)`. Plan-checker should grep
   for `@EnvironmentObject.*VideoModeStore` and fail.

3. **`Localizable.xcstrings` key explosion.** Six location labels + the
   "Your video will go here" label + the VIDEO-14 explanation paragraph + the
   "Video Mode" / "Video location" Settings row labels = ~10 new keys. Add ALL
   in one task, ALL with the `videoMode.*` prefix (FOUND-05 discipline), ALL
   referenced via `String(localized:)`. Missing one = silent fallback to key-name
   in non-EN locales (relevant once L10N-V2-01 ships).

4. **Token discipline on the iPhone outline.** The picker sub-screen lives in
   `Screens/VideoMode/` so the pre-commit hook rejects `cornerRadius: <int>` /
   `padding(<int>)` (CLAUDE.md §8 + CONTEXT code_context). The skeleton above
   uses `theme.radii.sheet`, `theme.radii.chip`, `theme.spacing.s` — verify
   none of the GeometryReader-derived sizes accidentally pass an integer to a
   `padding(...)` or `cornerRadius(...)` call. Use `.frame(width:height:)` for
   computed sizes (which is fine; the hook targets the literal forms).

5. **Theme audit on Loud preset (§8.12).** The selected-zone fill is
   `theme.colors.accent` (low-alpha) per D-02. Verify on Voltage / Dracula that
   the "Your video will go here" label remains legible — accent on accent at
   low alpha is the failure mode. If illegible on any Loud preset, switch the
   label to `theme.colors.textPrimary` (it already reads against any surface).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (iOS 17+, in-project — see `SettingsStoreFlagsTests.swift:23-29`) |
| Config file | none (Xcode auto-discovers `@Suite` types in `gamekitTests/`) |
| Quick run command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:gamekitTests/VideoModeStoreTests` |
| Full suite command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIDEO-01 | `isEnabled` defaults `false` on fresh install | unit | `xcodebuild ... -only-testing:gamekitTests/VideoModeStoreTests/defaults_isEnabledFalse` | Wave 0 |
| VIDEO-01 | Toggling `isEnabled = true` persists to UserDefaults key `gamekit.videoModeEnabled` | unit | `... -only-testing:gamekitTests/VideoModeStoreTests/setIsEnabled_persists` | Wave 0 |
| VIDEO-01 | `isEnabled` round-trips across store init | unit | `... -only-testing:gamekitTests/VideoModeStoreTests/isEnabled_roundTrips` | Wave 0 |
| VIDEO-02 | `VideoModeLocation` enum has exactly 6 cases, raw strings match D-07 | unit | `... -only-testing:gamekitTests/VideoModeLocationTests/sixCases_rawValuesLocked` | Wave 0 |
| VIDEO-03 | `location` defaults `.largeBottom` on fresh install | unit | `... -only-testing:gamekitTests/VideoModeStoreTests/defaults_locationLargeBottom` | Wave 0 |
| VIDEO-03 | Setting `location = .smallTopRight` persists, round-trips | unit | `... -only-testing:gamekitTests/VideoModeStoreTests/setLocation_persists` | Wave 0 |
| VIDEO-03 | Corrupt UserDefaults string falls back to `.largeBottom` | unit | `... -only-testing:gamekitTests/VideoModeStoreTests/corruptLocation_fallsBackToLargeBottom` | Wave 0 |
| VIDEO-04 | `VideoCompactControlRow` `#Preview` compiles in `gamekit` target | smoke | `xcodebuild build -scheme gamekit` (compile-only, SC4) | inherent |
| VIDEO-14 | xcstrings has `videoMode.explanation` key with VIDEO-14 verbatim copy | manual | xcstrings inspection (no automated assert — string content review) | manual-only (string content) |

### Sampling Rate
- **Per task commit:** `xcodebuild test ... -only-testing:gamekitTests/VideoModeStoreTests`
  (≤ 5 sec on iPhone 17 Pro Max sim, in-memory UserDefaults suite)
- **Per wave merge:** Full `xcodebuild test -scheme gamekit` (re-runs P4/P5/P6 regressions)
- **Phase gate:** Full suite green + visual theme audit on Classic + Voltage (CLAUDE.md §8.12)

### Wave 0 Gaps
- [ ] `gamekit/gamekitTests/Core/VideoModeStoreTests.swift` — covers VIDEO-01 + VIDEO-03
  (mirror `SettingsStoreFlagsTests.swift`'s isolated-UserDefaults helper at lines 36–39)
- [ ] `gamekit/gamekitTests/Core/VideoModeLocationTests.swift` — covers VIDEO-02
  (exhaustive enum test: case count + raw values)
- [ ] No new framework install needed — Swift Testing is already in the test target

### 8 Validation Dimensions

| Dimension | Coverage in Phase 9 |
|-----------|---------------------|
| **Correctness** | Unit tests on store defaults + round-trip + corrupt-fallback (table above) |
| **Persistence** | `setIsEnabled_persists` + `setLocation_persists` write-then-read-fresh-store tests |
| **Concurrency** | `@MainActor` on store class enforces main-thread access; Swift 6 strict-concurrency clean by inheritance from `SettingsStore` |
| **Theming** | Visual audit on Classic (Chrome Diner) + Voltage Loud preset — picker zones + "Your video will go here" label legible (CLAUDE.md §8.12) |
| **A11y** | VoiceOver pass on `VideoLocationPickerView` — 6 zone buttons announce as "Large top, button, Selected" / "Small bottom-left, button" etc.; container label "Video location picker, choose where your video will appear" |
| **Localization** | All 10 new strings via `String(localized:)` in `Localizable.xcstrings`; no hardcoded `Text("…")` (FOUND-05) |
| **Off-state byte-identity (SC5)** | Manual screenshot diff: launch v1.2 binary with `isEnabled = false`, capture Mines / Merge / Nonogram game screens, byte-diff against v1.1.x baseline. Automatic since no P9 game view reads `videoModeStore.isOn` (D-15) |
| **Compilation (SC4)** | `VideoCompactControlRow.swift` `#Preview` block compiles in `gamekit` target with 3 game-slot mappings (Mines / Merge / Nonogram per Phase 8 D-08) — `xcodebuild build` is the assert |

## Sources

### Primary (HIGH confidence — in-repo, verified)
- `gamekit/gamekit/Core/SettingsStore.swift:34-155` — pattern source, P4 D-29 lock
- `gamekit/gamekit/Core/AuthStore.swift:92-155, 281-296` — same pattern, 2 months newer
- `gamekit/gamekit/App/GameKitApp.swift:36-147` — injection site
- `gamekit/gamekit/Screens/SettingsView.swift:130-210` — Bindable + EnvironmentKey consumption
- `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift:23-60` — isolated-UserDefaults test pattern
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — token anchors verbatim
- `../DesignKit/Sources/DesignKit/Components/DKCard.swift` — generic `@ViewBuilder` precedent

### Secondary (MEDIUM confidence)
- Apple docs: `UserDefaults.bool(forKey:)` returns `false` for unset keys (referenced in
  `SettingsStore.swift:25-26` in-file comment) — pattern relies on this documented behavior

### Tertiary
- None used for this targeted pass.

## Metadata

**Confidence breakdown:**
- Topic 1 (Component API shape): HIGH — DKCard generic `@ViewBuilder` precedent + 19 in-repo `@ViewBuilder` sites
- Topic 2 (iPhone-outline layout): HIGH — GeometryReader is the only correct tool for irregular layouts; Grid rejected on geometry, not preference
- Topic 3 (`@Observable` drift): HIGH — `AuthStore.swift` (Apr 2026) ships identical pattern in production; no drift items

**Research date:** 2026-05-12
**Valid until:** 2026-06-12 (30-day stable window — pattern is iOS 17 baseline, unlikely to drift mid-milestone)

## Assumptions Log

*Table empty — all claims in this research are verified against in-repo source files or cited from CONTEXT.md / Phase 8 design lock. No `[ASSUMED]` items requiring user confirmation.*
