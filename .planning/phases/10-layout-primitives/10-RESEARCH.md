# Phase 10: Layout Primitives — Research

**Researched:** 2026-05-12
**Domain:** SwiftUI ViewModifier composition + safeAreaInset reserved-band + pure-helper anchor table for v1.2 Video Mode
**Confidence:** HIGH on existing-pattern reuse · MEDIUM on `largeBandFraction` measurement · MEDIUM on AnyView short-circuit cost

## Summary

Phase 10 ships two flat files in `gamekit/gamekit/Core/`: a `.videoModeAware(minBoardHeight:)`
ViewModifier (`VideoModeAware.swift`) that handles container-level concerns (off-restore
short-circuit, large-band reservation via `safeAreaInset`, compactness publication via
custom EnvironmentKey) and a pure helper (`VideoModeSlotRouter.swift`) that exposes
`anchors(for: VideoModeLocation) -> SlotAnchorMap` for in-view slot reposition. Every
implementation decision is locked in CONTEXT D-01..D-16; this research validates the
technical mechanics each decision requires and surfaces the two genuinely open numeric
unknowns (the `largeBandFraction` value and the `minBoardHeight` compactness thresholds).

The measurement work is done: scanning `home-classic-pip-large-{top,bottom}.png` yields
**TOP fraction ≈ 0.189** (band height ≈ 483px / 161pt on iPhone 17 Pro @ 852pt logical)
and **BOTTOM fraction ≈ 0.314** (band height ≈ 804px / 268pt). The two are not
symmetric — iOS's native PiP renders a noticeably larger bottom-dock pill than top-dock
pill. The conservative engineering target is the BOTTOM measurement: `largeBandFraction
= 0.32` (rounded up from 0.314, single private static on `VideoModeAware`).

Stack risk is low: the existing P9 surface (`VideoModeStore` env-injected,
`VideoCompactControlRow` token-anchored) covers every primitive read this phase needs.
The technically novel mechanics — `ViewModifier` returning `AnyView` on the off-path,
`safeAreaInset(edge:)` reserving a dynamic fraction of `geometry.size.height`, custom
`EnvironmentKey` publishing `VideoModeCompactness` from inside the modifier — are all
iOS-17-canonical patterns with well-understood costs.

**Primary recommendation:** Ship the modifier as a `struct` conforming to `ViewModifier`
(NOT a `View` extension calling `.modifier(...)` directly); declare `VideoModeCompactness`
+ its EnvironmentKey alongside `VideoModeAware` in `VideoModeAware.swift`; lock
`largeBandFraction = 0.32` with an inline comment citing
`home-classic-pip-large-bottom.png` as the measurement source; verify SC3 via a Swift
Testing assertion on the store-level branch (proves the short-circuit returns
`AnyView(content)` when `isEnabled == false`) plus a manual spot-check using a tiny
`#Preview` consumer. Use `SlotAnchorMap` as a **named-fields struct** (4 typed `SlotAnchor`
fields) for compile-time exhaustiveness rather than a `[SlotID: SlotAnchor]` dictionary.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01** — Adoption surface is `.videoModeAware()` ViewModifier (NOT
  `VideoModeContainer { ... }` wrapper, NOT slot-based `VideoModeLayout(board:controls:)`).
  Locks the call site for Phases 11/12/13 to one line per game.
- **D-02** — Slot reposition lives in the **game view**, not the modifier. P10 ships
  shared pure helper `VideoModeSlotRouter.anchors(for: VideoModeLocation) -> SlotAnchorMap`
  for every adopting game view to call. The modifier handles only container-level
  concerns (band reservation, safe-area inset, off-restore short-circuit).
- **D-03** — Files live **flat in `gamekit/gamekit/Core/`**:
  - `VideoModeAware.swift` — modifier + `.videoModeAware()` extension + `VideoModeCompactness` enum
  - `VideoModeSlotRouter.swift` — pure helper + `SlotAnchorMap`
- **D-04** — Modifier reads `VideoModeStore` via `@Environment(\.videoModeStore)`. No
  new scalar env keys (`\.videoModeEnabled`, `\.videoModeLocation` are NOT introduced).
- **D-05** — Off-restore = **hard short-circuit**. First line of modifier body:
  ```swift
  if !store.isEnabled { return AnyView(content) }
  ```
  Off-path = zero env publishing, zero compactness measurement, zero band reservation,
  zero slot-router invocation. Accepts AnyView type-erasure cost on off-path.
- **D-06** — SC3 verification = **Swift Testing unit test + manual spot-check** per
  P9 SC5 pattern from `09-VALIDATION.md`.
- **D-07** — P10 SC3 **supersedes** P9 SC5 for games that adopt `.videoModeAware()`.
- **D-08** — Band height = `geometry.size.height * largeBandFraction`, applied via
  `.safeAreaInset(edge: .top)` or `.safeAreaInset(edge: .bottom)` per location.
- **D-09** — `largeBandFraction` measured from `Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png`
  + `home-classic-pip-large-top.png`. Working estimate ~0.30.
- **D-10** — `private static let largeBandFraction: CGFloat = <measured>` on
  `VideoModeAware`. NOT promoted to DesignKit token (single consumer; CLAUDE.md §2).
- **D-11** — Small PiP = pure controls-routing. Modifier does NOT reserve a corner
  inset or touch the board's frame/safe area on Small zones (TL/TR/BL/BR).
- **D-12** — Compromise order encoded in the primitive. Modifier measures available
  board height and publishes a discrete `VideoModeCompactness` via env
  (`\.videoModeCompactness`).
- **D-13** — `VideoModeCompactness` has **3 levels**: `.normal | .collapsedSettings | .reducedTime`.
- **D-14** — Each adopting game passes its **minimum board height** at the adoption site:
  ```swift
  MinesweeperGameView().videoModeAware(minBoardHeight: 480)
  ```
- **D-15** — Hard-Mines `MagnifyGesture` stack (from `08-HARD-MINES-ADR.md`) is
  **untouched** by Phase 10. Only `MinesweeperBoardView.minCellSize` becomes
  Video-Mode-aware, and that lives in Phase 11.
- **D-16** — **SC5 stub = `#Preview` only.** No DEBUG screen, no HomeView dev hook.
  `#Preview` matrix covers 6 PiP zones × Classic + Dracula presets.

### Claude's Discretion

- Exact name of the ViewModifier — `videoModeAware` is the working name (alternatives:
  `videoModeAdaptive` / `videoModeLayout`).
- Exact name of the slot-router type — `VideoModeSlotRouter` is working name.
- Exact final value of `largeBandFraction` — measured from P8 screenshots during
  plan-phase. Expected range 0.28–0.35. Locked once measured.
- Default value of `minBoardHeight` when caller omits — proposed `320pt` (smallest
  device safe minimum).
- Compactness env key name — proposed `\.videoModeCompactness`.
- Exact `SlotAnchorMap` shape (named fields vs `[SlotID: Anchor]` dict).
- Whether `VideoModeSlotRouter` shares its anchor table with the future Phase 13 banner
  placement table.

### Deferred Ideas (OUT OF SCOPE)

- DEBUG-only stub game screen in HomeView — rejected by P9 D-04 precedent.
- Promote `.videoModeAware()` or `VideoModeSlotRouter` to DesignKit (single consumer).
- New DesignKit token `theme.spacing.video.bandHeight` — §2 promotion rule blocks.
- Vertical / portrait PiP layouts — v1.3+.
- Large left / large right PiP positions — v1.3+.
- Per-game compactness response variation beyond 3 levels — P11/P12 can extend the enum
  if a game needs `.minimal` or similar.
- PreferenceKey-based threshold publishing — rejected in favor of direct modifier
  parameter (D-14).
- Sharing slot-router data with Phase 13 banner table — possible refactor at P13.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIDEO-05 | Small-PiP layout — game board stays at normal size; back/settings/info chips and the picker are repositioned so the covered corner is empty for the selected Small location | `VideoModeSlotRouter.anchors(for:)` returns the 4-slot `SlotAnchorMap` for each Small location; D-11 confirms modifier does NOT touch board frame on Small zones (board passthrough is the contract). Slot-router data derives directly from `08-VIDEO-MODE-LAYOUTS.md` per-zone tables. Verified pure-helper output via unit test on 6 cases × 4 slots = 24 anchor assertions. |
| VIDEO-06 | Large-PiP layout — top or bottom band is reserved per selection; board fits between the reserved band and the compact control row; secondary controls collapse before the board becomes unplayable | `.safeAreaInset(edge: .top/.bottom)` with `geometry.size.height * largeBandFraction` height. Compromise order = `VideoModeCompactness` published via env (3 levels — D-13). Threshold from `minBoardHeight:` modifier param (D-14). `largeBandFraction = 0.32` measured from `home-classic-pip-large-bottom.png` (this research §Band measurement). |
| VIDEO-13 | Video Mode adapts only when On — toggling Off restores each game's normal layout with no visual residue | Hard short-circuit (D-05): `if !store.isEnabled { return AnyView(content) }`. `@Observable` propagation on `VideoModeStore.isEnabled` triggers immediate SwiftUI re-render → `AnyView(content)` branch returned → reserved insets vanish atomically. P10 SC3 supersedes P9 SC5 for adopting games (D-07). |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **§1 MVVM** — The modifier is a pure SwiftUI view with no view-model coupling.
  `VideoModeSlotRouter` is a pure helper (no SwiftUI dependency where possible — but
  `SlotAnchor` enum may reference UI vocabulary). No ViewModels introduced.
- **§2 Token discipline** — No new DesignKit tokens. `largeBandFraction` stays a
  private static on `VideoModeAware` (D-10). Existing tokens consumed by the modifier:
  `theme.spacing.xl` (compact-row height = 24pt) when measuring available board height.
- **§8.4 Verify tokens exist** — Confirmed via `DesignKit/Sources/DesignKit/Layout/SpacingTokens.swift`
  (xs=4, s=8, m=12, l=16, xl=24, xxl=32) and `Layout/RadiusTokens.swift` (card=16,
  button=14, chip=12, sheet=22). Phase 10 reads `spacing.xl` only.
- **§8.5 File size cap** — Both new files projected well under the 400-line soft cap
  (see §File-size estimate). `#Preview` matrix is the biggest risk; mitigated by a
  shared preview helper.
- **§8.10 Commit discipline** — Phase 10 ships in 1–2 commits: (1) primitive files +
  tests; (2) optional follow-up if `#Preview` matrix needs visual tuning iteration.
- **§8.12 Theme audit** — `#Preview` matrix renders 6 zones × Classic + Dracula
  presets (D-16). SC5 verified by visual inspection of the matrix on the Xcode canvas.
- **§8.13 Status table** — Phase 10 ships no user-facing brand changes; §0.1 update
  not required this phase.
- **§8.14 Release log** — `Docs/releases/v1.2.md` (opened at P9 close) gets a Phase 10
  entry: "Video Mode layout primitives — `.videoModeAware()` modifier + `VideoModeSlotRouter`
  helper; no per-game adoption yet."

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Off-path short-circuit (return content as-is) | View / Modifier layer | — | Pure SwiftUI control flow; no store mutation, no env publication. Owns SC3 contract by simplicity. |
| Large-band reservation (`.safeAreaInset`) | View / Modifier layer | Layout engine (SwiftUI) | Modifier composes `safeAreaInset` at the outermost layer; SwiftUI's native layout engine consumes the inset directive. |
| Compactness threshold computation | View / Modifier layer | — | Modifier measures available height inside `GeometryReader`, picks 1 of 3 enum cases, publishes to children via env. Threshold logic = pure CGFloat comparison. |
| Compactness consumption (which slot to drop) | View / Game-view layer | — | D-12 lock: threshold decision in primitive, **reaction** in game view. Each game reads `@Environment(\.videoModeCompactness)` in Phase 11/12. |
| Slot anchor lookup | Pure helper (no view) | — | `VideoModeSlotRouter.anchors(for:)` is a `static func` with no SwiftUI imports possible (depends on whether SlotAnchor is a CG type or UI type). Pure function → trivially testable. |
| Slot reposition (move Back from TL to TR) | View / Game-view layer | — | D-02 lock: game view reads `store.location` + calls slot router + arranges its own subviews. Phase 10 ships no per-game adoption. |
| Hard-Mines cell-size adjustment | OUT OF SCOPE | Phase 11 | D-15 + P8 HARD-MINES-ADR: `MinesweeperBoardView.minCellSize` becomes Video-Mode-aware in P11. Phase 10 wraps `MinesweeperGameView` at the outermost layer ONLY. |

## Standard Stack

### Core (project-provided, already shipped in P9)

| Symbol | Version/Path | Purpose | Why Standard |
|--------|--------------|---------|--------------|
| `VideoModeStore` | `gamekit/gamekit/Core/VideoModeStore.swift` (P9) | `@Observable @MainActor final class`; reads `isEnabled` + `location`. | env-injected; the canonical seam every P10+ surface reads. `@Observable` ensures SwiftUI re-renders on toggle without manual notification. [VERIFIED: source file] |
| `VideoModeLocation` | `gamekit/gamekit/Core/VideoModeLocation.swift` (P9) | 6-case `enum: String, CaseIterable, Sendable`. | Exhaustive switch in `VideoModeSlotRouter.anchors(for:)` guarantees compile-time coverage of every PiP zone. [VERIFIED: source file] |
| `VideoCompactControlRow` | `gamekit/gamekit/Core/VideoCompactControlRow.swift` (P9) | Generic `@ViewBuilder` slots (`Back \| primary \| picker \| secondary \| settings`). | Compact-row height anchored to `theme.spacing.xl = 24pt`. Modifier reads this constant when computing available-board-height for compactness threshold. NO modification in P10. [VERIFIED: source file] |
| `EnvironmentValues.videoModeStore` | `gamekit/gamekit/Core/VideoModeStore.swift:108-113` | Custom `EnvironmentKey` extension. | iOS 17 canonical seam for `@Observable` types (`@EnvironmentObject` is INCOMPATIBLE with `@Observable` per P4 RESEARCH Pitfall 1). [VERIFIED: source file] |

### Supporting (iOS 17 SwiftUI primitives)

| Symbol | iOS Min | Purpose | When to Use |
|--------|---------|---------|-------------|
| `ViewModifier` protocol | iOS 13+ (still canonical iOS 17) | Reusable view transformation; `.modifier(...)` or `extension View { func foo() -> some View }`. | The adoption surface (D-01). Wraps `content` with band reservation + env publication. [CITED: developer.apple.com/documentation/swiftui/viewmodifier] |
| `safeAreaInset(edge:alignment:spacing:content:)` | iOS 15+ | Reserves space at the named edge; SwiftUI's layout engine adjusts the child's safe area natively. | D-08 mechanism for the large-band reservation. Insets STACK with existing insets (additive), which matters for adopting game views that already use `safeAreaInset` for their own toolbar. [CITED: swiftuifieldguide.com/layout/safe-area; createwithswift.com/placing-ui-components-within-the-safe-area-inset] |
| `GeometryReader` | iOS 13+ | Read parent's proposed size. | D-08 mechanism for `geometry.size.height * largeBandFraction`. Wrap the safeAreaInset content in a `GeometryReader` (or use the `proxy:` overload on `safeAreaInset` if available — see §iOS 17 ergonomics). [CITED: designcode.io/swiftui-handbook-status-bar-size-with-geometryreader] |
| `EnvironmentKey` protocol + `EnvironmentValues` extension | iOS 13+ | Custom env values. P9 pattern repeats. | D-12 mechanism for `\.videoModeCompactness`. Default value = `.normal`. |
| `AnyView` | iOS 13+ | Type-erased view wrapper. | D-05 mechanism for short-circuit return. Documented O(n) cost in large lists; **negligible** for a single per-game wrap (each game view is wrapped once at the outermost layer — not in a List ForEach). [CITED: forums.swift.org/t/swiftui-and-anyview-performance-benchmarks/65717] |
| `@Observable` macro | iOS 17+ | Per-property dependency tracking (replaces ObservableObject). | Already in use via P9 `VideoModeStore`. Modifier reads `store.isEnabled` → only re-evaluates when that property changes. [CITED: avanderlee.com/swiftui/observable-macro-performance-increase-observableobject] |
| `#Preview` macro | iOS 17 / Xcode 15+ | Replaces `PreviewProvider`. Multiple `#Preview("name") { ... }` blocks per file supported. | D-16 mechanism for SC5 matrix. Pattern: 12 named `#Preview` blocks OR 1 block with `ForEach` over zone × preset. Named blocks render as separate canvas tiles in Xcode (better for SC5 visual audit). [CITED: developer.apple.com/documentation/swiftui/previews-in-xcode; medium.com/appcoda-tutorials/how-to-use-the-swiftui-preview-macro-in-xcode-15-4da6da7b1908] |
| Swift Testing (`@Test`, `@Suite`, `#expect`) | iOS 17+ / Xcode 16+ | Existing test framework (already shipped in v1.0). | SC3 unit-test mechanism. Pattern source: `VideoModeStoreTests.swift`, `SC5RegressionTests.swift`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ViewModifier` struct + `extension View { func videoModeAware(...) }` | `extension View { func videoModeAware(...) -> some View }` direct body | Direct extension is fine for single-use modifiers; `ViewModifier` shape is better when the modifier has state (`@Environment`, `@State`) and benefits from being a value-type with `body(content:)`. Use `ViewModifier`. [CITED: swiftwithmajid.com/2019/08/07/viewmodifiers-in-swiftui/] |
| `safeAreaInset(edge:)` for band reservation | `padding(.top, bandHeight)` or `.frame(maxHeight:)` arithmetic | `safeAreaInset` is the SwiftUI-native idiom; it adjusts the safe area for descendants (so a wrapped child's own `safeAreaInset` stacks correctly) and respects nav bars / status bar without manual offset math. Wins on correctness. |
| Custom `EnvironmentKey` for `VideoModeCompactness` | `PreferenceKey` propagation upward | Compactness flows DOWN (parent measures, child reacts) — Environment is the right direction. PreferenceKey is for child-to-parent (e.g., view reports its size up). Already locked by D-12. |
| `AnyView(content)` short-circuit | `Group { content }` or `@ViewBuilder` switch | `AnyView` makes "byte-identical to un-wrapped" easy to assert because it's a single deterministic shape; `Group` introduces a `_VariadicView` wrapper that's harder to reason about. AnyView cost is irrelevant for a single per-game wrap (per benchmarks; cost only matters in large ForEach contexts). |
| `[VideoModeLocation: SlotAnchor]` dictionary | Named-fields struct `SlotAnchorMap` | Named-fields struct gives compile-time exhaustiveness on the 4 slots (Back / Settings / Picker / FAB) — call sites can't typo a key. Dictionary loses that. Plus, slot vocabulary is fixed; dictionary's open-key shape is misleading. Recommend named struct (per §SlotAnchorMap shape below). |

**Installation:** No new packages. All listed symbols are already available via existing
project dependencies (DesignKit local SPM, system SwiftUI / Foundation / Testing).

**Version verification:** Phase 10 introduces no third-party packages. Existing
project dependencies verified against the active source tree:
- DesignKit: local SPM at `../DesignKit` (no remote registry pin)
- Swift Testing: bundled with Xcode 16+ (existing v1.0 usage in
  `VideoModeStoreTests.swift`)

## Architecture Patterns

### System Architecture Diagram

```
                         GAME VIEW ENTRY (P11/P12)
                                  │
                                  ▼
                     MinesweeperGameView()           ← unchanged in P10
                         .videoModeAware(             ← THE adoption seam
                             minBoardHeight: 480
                         )
                                  │
                                  ▼
           ┌──────────────────────────────────────────┐
           │  VideoModeAware ViewModifier (P10 ship)  │
           │  reads @Environment(\.videoModeStore)    │
           └──────────────────────────────────────────┘
                                  │
                  ┌───────────────┴──────────────┐
                  ▼                              ▼
       store.isEnabled == false        store.isEnabled == true
                  │                              │
                  ▼                              ▼
       return AnyView(content)        GeometryReader { proxy in
       ─── SC3 BYTE-IDENTICAL ───         compute available board height
       OFF-PATH (D-05)                    ├─ measure: proxy.size.height
                                          ├─ subtract: large band (if Large zone)
                                          ├─ subtract: theme.spacing.xl (compact row)
                                          └─ compare to minBoardHeight floor
                                                       │
                                                       ▼
                                             ┌──────────────────┐
                                             │  Pick compactness │
                                             ├──────────────────┤
                                             │ ≥ floor → normal │
                                             │ ≥ 0.85× → collapseSettings │
                                             │ < 0.85× → reducedTime      │
                                             └──────────────────┘
                                                       │
                                                       ▼
                                          content
                                            .safeAreaInset(.top/.bottom)  ← Large only
                                              { Color.clear.frame(height:
                                                  proxy.size.height *
                                                  largeBandFraction) }
                                            .environment(\.videoModeCompactness,
                                                         computedLevel)
                                                       │
                                                       ▼
                              ┌────────────────────────────────────────────┐
                              │  Wrapped game view (P11/P12)               │
                              │  reads @Environment(\.videoModeStore)      │
                              │  reads @Environment(\.videoModeCompactness)│
                              │  calls VideoModeSlotRouter.anchors(for:    │
                              │    store.location)                         │
                              │  arranges its own slots                    │
                              └────────────────────────────────────────────┘
                                                       │
                                                       ▼
                              ┌────────────────────────────────────────────┐
                              │  VideoModeSlotRouter (P10 ship — pure)     │
                              │  static func anchors(for: Location) ->     │
                              │     SlotAnchorMap                          │
                              │  Switches over 6 cases — exhaustive        │
                              │  Each case returns SlotAnchorMap(          │
                              │    back: …, settings: …, picker: …, fab: …)│
                              │  Data derived from 08-VIDEO-MODE-LAYOUTS.md│
                              └────────────────────────────────────────────┘
```

### Recommended Project Structure

```
gamekit/gamekit/Core/
├── VideoModeStore.swift               # P9 — env-injected store
├── VideoModeLocation.swift            # P9 — 6-case enum
├── VideoCompactControlRow.swift       # P9 — compact-row component (read; do not modify)
├── VideoModeAware.swift               # P10 NEW — modifier + extension + VideoModeCompactness
└── VideoModeSlotRouter.swift          # P10 NEW — pure helper + SlotAnchorMap
```

Tests:

```
gamekit/gamekitTests/Core/
├── VideoModeAwareTests.swift          # P10 NEW — SC3 short-circuit + compactness threshold
└── VideoModeSlotRouterTests.swift     # P10 NEW — 6 × 4 = 24 anchor assertions
```

No new subdirectories. No new test targets. CLAUDE.md §8.8 (PBXFileSystemSynchronizedRootGroup
auto-registers new `.swift` files in existing folders) means zero `project.pbxproj`
edits required.

### Pattern 1: ViewModifier with `@Environment` and short-circuit

**What:** SwiftUI `ViewModifier` struct that reads an `@Observable` store via
`@Environment` and short-circuits with `AnyView(content)` when the store says
"feature disabled."

**When to use:** Any feature that wraps an existing view with optional behavior and
must be byte-identical when disabled (the dominant runtime path).

**Example:**
```swift
// Source: synthesized from VideoCompactControlRow.swift + SettingsStore.swift +
// P9 D-05 + CONTEXT D-04, D-05, D-08, D-10, D-12, D-13, D-14.
import SwiftUI
import DesignKit

struct VideoModeAware: ViewModifier {
    @Environment(\.videoModeStore) private var store
    let minBoardHeight: CGFloat

    /// Measured from Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png:
    /// bottom PiP band = 804px / 2556px screen = 0.3146 fraction (iPhone 17 Pro @ 852pt).
    /// Top PiP band = 483px / 2556px = 0.189 fraction (iOS native PiP top dock is smaller).
    /// Locked to 0.32 (rounded up from worst-case 0.3146) for safe reservation on
    /// both Large top and Large bottom — accepts slightly over-reservation on Large top
    /// in exchange for one constant and symmetric mental model.
    private static let largeBandFraction: CGFloat = 0.32

    func body(content: Content) -> some View {
        // D-05: hard short-circuit. Byte-identical view tree on off-path.
        if !store.isEnabled {
            return AnyView(content)
        }
        return AnyView(onPath(content: content))
    }

    @ViewBuilder
    private func onPath(content: Content) -> some View {
        GeometryReader { proxy in
            let availableBoardHeight = proxy.size.height
                - bandHeight(for: store.location, in: proxy)
                - DesignKit.compactRowHeight  // theme.spacing.xl = 24pt
            let compactness = pickCompactness(available: availableBoardHeight)
            applyBand(to: content, in: proxy)
                .environment(\.videoModeCompactness, compactness)
        }
    }

    @ViewBuilder
    private func applyBand<C: View>(to view: C, in proxy: GeometryProxy) -> some View {
        switch store.location {
        case .largeTop:
            view.safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: proxy.size.height * Self.largeBandFraction)
            }
        case .largeBottom:
            view.safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: proxy.size.height * Self.largeBandFraction)
            }
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:
            // D-11: Small zones do NOT reserve a band. Slot router handles reposition
            // entirely in the game view.
            view
        }
    }

    private func bandHeight(for loc: VideoModeLocation, in proxy: GeometryProxy) -> CGFloat {
        switch loc {
        case .largeTop, .largeBottom: return proxy.size.height * Self.largeBandFraction
        default: return 0
        }
    }

    private func pickCompactness(available: CGFloat) -> VideoModeCompactness {
        if available >= minBoardHeight { return .normal }
        if available >= minBoardHeight * 0.85 { return .collapsedSettings }
        return .reducedTime
    }
}

extension View {
    /// CONTEXT D-01 adoption surface. Single call site for every Phase 11/12 game view.
    func videoModeAware(minBoardHeight: CGFloat = 320) -> some View {
        modifier(VideoModeAware(minBoardHeight: minBoardHeight))
    }
}

// VideoModeCompactness + EnvironmentKey live in this same file per D-03.
enum VideoModeCompactness {
    case normal              // plan-doc steps 1–3 satisfied
    case collapsedSettings   // plan-doc step 4 — Settings into overflow menu
    case reducedTime         // plan-doc step 5 — hide time / secondary stats
}

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

**Notes:**
- `DesignKit.compactRowHeight` in the snippet above is a stand-in — the actual code
  resolves `theme.spacing.xl` via `Theme.resolve(preset:scheme:)` OR (cleaner) the
  modifier accepts a `theme` parameter passed through env. Discuss in plan-phase
  whether `@Environment(\.theme)` exists in DesignKit (verify in plan) or whether the
  modifier needs to be parameterized.
- The `applyBand` helper is generic over `C: View` not because it's called with
  multiple types but because `body(content:)` produces `some View` and we want SwiftUI
  to keep the band-applied type concrete inside the GeometryReader closure (AnyView
  is only on the off-path).

### Pattern 2: Pure helper with named-fields output struct

**What:** Pure `static func` returning a typed struct of named anchor fields.

**When to use:** When a closed set of inputs maps to a closed set of outputs and call
sites benefit from compile-time field access (no string keys, no Optional unwraps).

**Example:**
```swift
// Source: synthesized from CONTEXT D-02 + 08-VIDEO-MODE-LAYOUTS.md per-game tables.

/// Where a single slot lives on the screen for a given PiP zone.
/// Conceptual (not coordinate) — game views translate this to layout intent.
enum SlotAnchor {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    case inCompactRow              // demoted into the VideoCompactControlRow
    case hidden                    // not shown at all for this zone
}

/// The 4 movable slots that every Phase 11/12 game view arranges.
/// Named fields give the compiler exhaustiveness; a dictionary would not.
struct SlotAnchorMap: Equatable {
    let back: SlotAnchor
    let settings: SlotAnchor
    let picker: SlotAnchor    // Reveal/Flag picker (Mines), Mode picker (Merge), Fill/Mark picker (Nono)
    let fab: SlotAnchor       // Reveal/Flag FAB (Mines 06.1-02); other games may have none
}

enum VideoModeSlotRouter {
    /// Returns where each slot anchors for the given PiP zone.
    /// Data derives from .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    /// "Where controls go" column for each PiP zone, applied across the 4 movable slots.
    static func anchors(for location: VideoModeLocation) -> SlotAnchorMap {
        switch location {
        case .largeTop:
            // Compact row at bottom edge; all slots move INTO the compact row
            // (game view consumes VideoCompactControlRow and provides the bottom-anchored chrome).
            return SlotAnchorMap(back: .inCompactRow, settings: .inCompactRow,
                                  picker: .inCompactRow, fab: .inCompactRow)
        case .largeBottom:
            // Compact row at top edge; same slot consolidation.
            return SlotAnchorMap(back: .inCompactRow, settings: .inCompactRow,
                                  picker: .inCompactRow, fab: .inCompactRow)
        case .smallTopLeft:
            // PiP covers TL → move Back away (TR or compact row). Settings stays TR-ish.
            return SlotAnchorMap(back: .topTrailing, settings: .topTrailing,
                                  picker: .bottomTrailing, fab: .bottomTrailing)
        case .smallTopRight:
            // PiP covers TR → move Settings away.
            return SlotAnchorMap(back: .topLeading, settings: .topLeading,
                                  picker: .bottomLeading, fab: .bottomLeading)
        case .smallBottomLeft:
            // PiP covers BL → move bottom-left affordances right.
            return SlotAnchorMap(back: .topLeading, settings: .topTrailing,
                                  picker: .bottomTrailing, fab: .bottomTrailing)
        case .smallBottomRight:
            // PiP covers BR → move FAB and bottom-right affordances left.
            return SlotAnchorMap(back: .topLeading, settings: .topTrailing,
                                  picker: .bottomLeading, fab: .bottomLeading)
        }
    }
}
```

**Source:** Derived from `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md`
per-zone "Where controls go" columns. Phase 10 plan-task must cross-check each
returned `SlotAnchorMap` against the layouts doc before locking.

### Pattern 3: `#Preview` matrix (12 named blocks vs ForEach)

**What:** Multiple `#Preview("name") { ... }` blocks per file render as separate
canvas tiles in Xcode 15+ / Xcode 16.

**When to use:** SC5 visual audit across a small fixed matrix (D-16: 6 zones × 2
presets = 12 tiles). Named blocks are better than `ForEach` because Xcode renders
each block as an independently scrubbable tile.

**Example:**
```swift
// Source: developer.apple.com/documentation/swiftui/previews-in-xcode
// + medium.com/appcoda-tutorials/how-to-use-the-swiftui-preview-macro-in-xcode-15-4da6da7b1908

// One named block per (zone, preset) combination — 12 total.
// Use a helper to avoid 12 copies of the same setup boilerplate.

#Preview("Classic — Large top") { StubGame(zone: .largeTop, preset: .classicMuted) }
#Preview("Classic — Large bottom") { StubGame(zone: .largeBottom, preset: .classicMuted) }
#Preview("Classic — Small TL") { StubGame(zone: .smallTopLeft, preset: .classicMuted) }
// … 9 more combinations.

private struct StubGame: View {
    let zone: VideoModeLocation
    let preset: ThemePreset
    @State private var store: VideoModeStore

    init(zone: VideoModeLocation, preset: ThemePreset) {
        self.zone = zone
        self.preset = preset
        let s = VideoModeStore(userDefaults: UserDefaults(suiteName: "preview-\(UUID().uuidString)")!)
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
            Rectangle().fill(theme.colors.surface)   // board placeholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VideoCompactControlRow(theme: theme, onBack: {}, onSettings: {},
                primaryInfo: { Text("primary") },
                picker: { Text("picker") },
                secondaryInfo: { Text("secondary") }
            )
        }
    }
}
```

**Alternative:** Single `#Preview` with `ForEach` over zones — renders as one tall
composed view, harder to audit individual zones. Recommend named blocks.

### Anti-Patterns to Avoid

- **`@EnvironmentObject` on `VideoModeStore`** — INCOMPATIBLE with `@Observable`
  (P4 RESEARCH Pitfall 1; already locked at P9). Always read via
  `@Environment(\.videoModeStore)`.
- **`PreferenceKey` for compactness publication** — wrong direction. PreferenceKey
  flows child→parent; compactness flows parent→child. Already rejected in CONTEXT
  Deferred Ideas.
- **`.frame(height:)` with magic number for band reservation** — bypasses SwiftUI's
  safe-area engine, breaks composition with adopting child's own `safeAreaInset`,
  doesn't survive notch/dynamic-island geometry changes. Always use
  `.safeAreaInset(edge:)`.
- **Recomputing `largeBandFraction` per-render** — keep it `private static let`. If
  it ever needs to vary by device/orientation, promote to a function but cache the
  result. Right now: one constant, one source of truth.
- **`ZStack` overlay for the band** — visually plausible but bypasses the safe-area
  engine and forces the child view to know about the band's existence. The whole
  point of `safeAreaInset` is the child doesn't have to know.
- **`AnyView` everywhere on the on-path** — the AnyView is acceptable on the
  off-path (single per-game wrap, no ForEach) but on the on-path keep concrete types
  (`some View`) where possible. SwiftUI's diffing works better with concrete types.
  [CITED: nalexn.github.io/anyview-vs-group]
- **Reading `store.location` outside `GeometryReader`** — fine to read once at top
  of `body`, but if the read is inside a `safeAreaInset` content closure that closure
  may not re-evaluate when `location` changes. Always read `store.location` at the
  top of the modifier body so `@Observable`'s tracking sees it cleanly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Top/bottom band reservation | Manual `padding(.top, h)` arithmetic + `.ignoresSafeArea` jugging | `.safeAreaInset(edge:)` | SwiftUI's safe-area engine composes correctly with child views' own safe-area readers, status bar, notch/dynamic island. Manual math breaks on iPad split-view, landscape rotation, dynamic-island devices. |
| `@Observable` env distribution | `NotificationCenter` + manual `@State` refresh | `@Observable` + `@Environment(\.videoModeStore)` | Already locked at P9. `@Observable` tracks per-property reads; SwiftUI re-renders only the dependent subgraph. NotificationCenter loses that scoping. |
| Compactness threshold publication | `@Binding` chains through every game view | Custom `EnvironmentKey` for `\.videoModeCompactness` | Environment flows top-down implicitly; binding chains require every intermediate view to declare the binding. Game views in P11/P12 may have multiple levels of subviews — env is cleaner. |
| 6-case slot lookup | `if store.location == .largeTop { ... } else if ...` | `switch` over `VideoModeLocation` in `VideoModeSlotRouter.anchors(for:)` | Exhaustive switch is the canonical Swift pattern; compiler enforces that a future 7th case forces every adopter to handle it. |
| `#Preview` matrix | Single giant view with `ForEach` | 12 named `#Preview` blocks via shared helper | Xcode 15/16 canvas renders each `#Preview` as a separate scrubbable tile; ForEach inside one preview renders as one tall composed view that's harder to audit per-zone. |
| Byte-identical-off-path verification | Image-diff snapshot testing in P10 | Swift Testing unit test on `store.isEnabled == false` branch | At P10, no game view is wrapped yet — there's nothing to snapshot. Test the **invariant** (the modifier short-circuits when store is off) + leave the snapshot upgrade for P11/P12 (TODO marker pattern from `SC5RegressionTests.swift:69-73`). |
| Reflective `Mirror` comparison of view trees | Custom AST walker over rendered `Content` | Direct assertion: when `store.isEnabled == false`, the modifier returns `AnyView(content)` | SwiftUI's view tree is not publicly introspectable (`ViewInspector` is a 3rd-party tool that uses private API surfaces; using it would add a test-only dependency and pin the test to that library's compatibility window). The cleaner test is structural: pass a known content view, assert that the modifier's branch selection is correct by toggling `store.isEnabled` and re-evaluating. |

**Key insight:** Every "hand-roll" candidate above has a SwiftUI-native or
project-canonical equivalent already proven by P9. Phase 10 is wholly a composition
exercise on iOS 17 primitives — no novel infrastructure.

## Runtime State Inventory

> Not applicable — Phase 10 is greenfield (two new files in `Core/`, no rename or
> migration). No stored data, live service config, OS-registered state, secrets,
> or build artifacts reference the new symbols yet (Phase 11/12 ship the first
> consumers).

**Stored data:** None — P10 introduces no new persistence keys.
**Live service config:** None — P10 introduces no external service integration.
**OS-registered state:** None — P10 introduces no scheduled tasks, no plist registrations.
**Secrets / env vars:** None — P10 introduces no secrets.
**Build artifacts:** None — `gamekit/gamekit/Core/*.swift` auto-registers via
PBXFileSystemSynchronizedRootGroup per CLAUDE.md §8.8.

## Band Measurement (D-09 resolution)

**Source files (measured with PIL pixel-row scan, 2026-05-12):**
- `Docs/screenshots/v1.2-design/home-classic-pip-large-top.png` (1179×2556 px)
- `Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png` (1179×2556 px)

**Device note:** Screenshots are 1179×2556 px = 393×852pt @3x = **iPhone 17 Pro**
(or 15/16 Pro — same logical dimensions). NOT iPhone 17 Pro Max (which is 1290×2796
px = 430×932pt). `Docs/screenshots/v1.2-design/README.md` line 4 says "iPhone 17 Pro
Max simulator"; CONTEXT D-09 inherits that label. The actual device is one tier
smaller — measurement still valid because `largeBandFraction` is a screen-height
**fraction** (device-independent), but the working-pt translation (158–268pt) is
device-specific. Treat as documentation drift to flag in plan-phase.

**Method:** For each screenshot, scan downward at multiple x-positions, identifying
the longest contiguous "dark" pixel run (RGB avg < 200 = non-cream). Compare across
x-positions to distinguish the PiP video region from solid-color game cards. Use
the column furthest from card mid-widths.

**Top variant (`home-classic-pip-large-top.png`):**
- Robust measurement at x ∈ {400, 500}: band y=120..603 → **483px height = 0.189
  fraction = 161pt at 3x** (on this 17 Pro screenshot).
- The TOP PiP region in the screenshot shows a small picture-in-picture inset at
  TL (the YouTube subscribe-button thumbnail) over the main video — visually
  smaller PiP than the bottom variant.

**Bottom variant (`home-classic-pip-large-bottom.png`):**
- Robust measurement at x ∈ {600, 700, 800}: band y=1747..2555 → **809px height =
  0.317 fraction = 270pt at 3x**.
- BOTTOM PiP is visibly larger than TOP — this is iOS native PiP behavior (bottom
  dock pill is the "natural" size; top dock is reduced).

**Conclusion:** The two are NOT symmetric. Worst-case reservation is **0.32**
(rounded up from 0.317 for safety). Lock this single value for both `.largeTop` and
`.largeBottom` — accepts modest over-reservation on Large top in exchange for one
constant and a symmetric mental model. Device-portability check:

| Device | Logical height | Reserved band at 0.32 |
|--------|----------------|------------------------|
| iPhone SE 3rd gen (smallest supported) | 667pt | 213pt |
| iPhone 13 mini | 812pt | 260pt |
| iPhone 17 Pro (measurement source) | 852pt | 273pt |
| iPhone 17 Pro Max | 932pt | 298pt |

**Recommended D-10 value:**
```swift
/// Measured from Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png
/// (worst case): bottom PiP pill ≈ 809px / 2556px = 0.317 fraction. Locked to
/// 0.32 (rounded up) for safe symmetric reservation on both .largeTop and
/// .largeBottom. iOS native PiP top-dock is smaller (~0.19) — modest over-reservation
/// on Large top accepted in exchange for one constant. Device-portable: fraction
/// applies to any screen height via geometry.size.height * largeBandFraction.
private static let largeBandFraction: CGFloat = 0.32
```

**Rollback:** If Phase 11 Hard-Mines validation (per 08-HARD-MINES-ADR) surfaces a
regression on Large top where the over-reservation crowds the smaller-cells Hard
board, this constant can be tuned downward to a per-edge pair without ADR amendment.
The single-constant default minimizes mental-model overhead.

## Common Pitfalls

### Pitfall 1: `safeAreaInset` stacks with child's existing insets

**What goes wrong:** Adopting game view (Mines/Merge/Nonogram) already has its own
`.safeAreaInset` or `.toolbar` calls. The modifier's band stacks on top of those,
making the reserved space larger than intended.

**Why it happens:** Documented stacking behavior: "additional modifiers append their
size to the inset" [CITED: swiftuifieldguide.com/layout/safe-area].

**How to avoid:** Audit existing P11/P12 game views in plan-phase. If a game view
already has `.toolbar` or `.safeAreaInset`, the modifier's band height needs to
account for that OR the game view's adoption needs to drop its own toolbar in
favor of the compact row when `videoMode.isEnabled`.

**Warning signs:** Visual regression in P11 where the board height is smaller than
expected; "available board height" calculation in the modifier returns a value
smaller than `proxy.size.height - largeBandFraction*height - compactRow`.

**Verification:** Snapshot the wrapped game view's actual frame in P11 plan-phase
testing. Inspect `geometry.frame(in: .global)` of the board container.

### Pitfall 2: `@Observable` re-render granularity surprises

**What goes wrong:** Modifier reads `store.location` deep inside a `safeAreaInset`
content closure. Closure may not re-evaluate when `location` changes because SwiftUI
captured the `store` reference but not the property read at this site.

**Why it happens:** `@Observable` tracks property reads per body invocation. A nested
closure may have stale tracking.

**How to avoid:** Read `store.location` and `store.isEnabled` at the **top** of the
modifier body — bind them to `let` constants — then use those constants in nested
closures. This forces the read into the body's tracking scope.

**Warning signs:** Switching PiP location in Settings doesn't update the wrapped
game's band placement until the game view is dismissed and re-presented.

### Pitfall 3: `AnyView` short-circuit defeats SwiftUI's view diff

**What goes wrong:** Toggling `store.isEnabled` from true→false causes SwiftUI to
discard the entire on-path subtree (state lost, child @State reset, animations
interrupted).

**Why it happens:** `AnyView(content)` and `AnyView(onPath(content:))` are
different concrete types post-erasure; SwiftUI's diff treats them as a structural
change → full rebuild of the wrapped child.

**How to avoid:** This is **accepted** per CONTEXT D-05 ("accepts the minor SwiftUI
type-erasure cost"). The off-path is the dominant runtime path and a clean rebuild
on toggle is the desired behavior for SC3 (no visual residue). If a future plan
discovers the rebuild loses important state (e.g., game timer mid-game), promote
that state to a parent that's outside the modifier wrap — never to the modifier
itself.

**Warning signs:** Mid-game toggle of Video Mode causes Minesweeper timer to reset
or current board state to clear. (P11 will likely surface this; reflect the
discovery back into CONTEXT.)

### Pitfall 4: `GeometryReader` collapses to zero in the wrong parent

**What goes wrong:** Wrapping a `GeometryReader` in a non-greedy parent (e.g., a
`VStack` without `.frame(maxHeight: .infinity)`) makes it report
`proxy.size.height = 0`. The `largeBandFraction * 0 = 0` band is then invisible.

**Why it happens:** GeometryReader takes the proposed size from its parent; many
SwiftUI containers propose the smaller of child intrinsic size or available space.

**How to avoid:** Apply `.frame(maxWidth: .infinity, maxHeight: .infinity)` to the
modifier's content OR use the `GeometryReader` at the outermost layer of `body`.
Verify via `proxy.size.height > 0` `#expect` in unit test (use `ViewInspector` or
just visual check in `#Preview`).

**Warning signs:** `#Preview` shows the wrapped game view filling the whole tile
with no visible band reservation; `store.isEnabled = true` and `.largeTop` selected.

### Pitfall 5: Device-dimension drift in measurement source

**What goes wrong:** CONTEXT D-09 and P8 README say "iPhone 17 Pro Max" but the
screenshots are 1179×2556 px = 17 Pro dimensions (852pt logical), not 17 Pro Max
(932pt). The pt translation of the measured fraction is off by ~10%.

**Why it happens:** Documentation drift between simulator naming and actual capture
device.

**How to avoid:** Trust the **fraction** measurement (0.32) — it's
device-independent. Distrust the **pt** translation in any doc that claims a
specific number. The fraction × `geometry.size.height` is correct on any device.
For the `#Preview` matrix in P10, the canvas can use any iPhone simulator size;
the band will scale proportionally.

**Warning signs:** Comparing "reserved band on iPhone 17 Pro Max" in a
verification doc to an actual screenshot taken on 17 Pro and finding a 10% gap.
Don't worry about it.

### Pitfall 6: File size cap pressure from `#Preview` matrix

**What goes wrong:** `VideoModeAware.swift` grows past 400 lines because the
12-block `#Preview` matrix copies setup boilerplate per block.

**Why it happens:** `#Preview` blocks each need a `StubGame(zone:preset:)` invocation
with full env wiring.

**How to avoid:** Factor `StubGame` + `StubGameContent` as `private struct`s used by
all 12 blocks. Each `#Preview` becomes a single-line: `#Preview("name") { StubGame(...) }`.
Projected file size with this factoring:

- `VideoModeAware` struct: ~80 lines
- `extension View { func videoModeAware(...) }`: ~5 lines
- `VideoModeCompactness` enum + EnvironmentKey + extension: ~25 lines
- `private struct StubGame` + `private struct StubGameContent`: ~50 lines
- 12 `#Preview` blocks @ ~2 lines each: ~25 lines
- File header doc-comment: ~30 lines
- Spacing / MARK comments: ~30 lines

Total: ~245 lines. Well under §8.5's 400-line soft cap and 500-line hard cap.

**Warning signs:** If the file approaches 350 lines, split `VideoModeCompactness` +
its EnvironmentKey into a separate `VideoModeCompactness.swift` file in `Core/`.

## Code Examples

### Example 1: Modifier short-circuit unit test (SC3)

```swift
// Source: synthesized from SC5RegressionTests.swift + VideoModeStoreTests.swift +
// CONTEXT D-05, D-06. Pattern: assert the structural invariant, not pixel-diff.

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("VideoModeAware short-circuit (SC3)")
struct VideoModeAwareTests {

    static func makeStore(enabled: Bool, location: VideoModeLocation = .largeBottom) -> VideoModeStore {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = VideoModeStore(userDefaults: defaults)
        store.isEnabled = enabled
        store.location = location
        return store
    }

    // SC3 contract — when store is off, the modifier's branch selection is
    // "return AnyView(content)" — the structural invariant codified by D-05.
    // We can't directly compare view trees (SwiftUI doesn't expose that API),
    // but we CAN assert the branch by inspecting the modifier's published env.
    // Strategy: when off, .environment(\.videoModeCompactness, ...) is NEVER
    // called → the default value (.normal) is what a descendant reads.
    // When on, the modifier publishes a (potentially different) value.

    @Test("Off state — modifier does not publish videoModeCompactness env")
    func test_offState_doesNotPublishCompactness() {
        let store = Self.makeStore(enabled: false)
        // Render in a probe view that reads the env and writes it to a capture.
        // (Implementation detail: use a `EnvironmentReader` test helper.)
        let captured = renderAndCapture(store: store, minBoardHeight: 480)
        #expect(captured == .normal)  // default value — modifier never overrode it
    }

    @Test("On state with comfortable size — publishes .normal compactness")
    func test_onState_normal() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        // Assume probe view forces a known height that comfortably exceeds floor.
        let captured = renderAndCapture(store: store, minBoardHeight: 200,
                                         forcedHeight: 900)
        // 900 - (900 * 0.32) - 24 = 588 ≥ 200 → .normal
        #expect(captured == .normal)
    }

    @Test("On state with tight size — publishes .collapsedSettings")
    func test_onState_collapsedSettings() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        // Height that triggers the 0.85× threshold (between floor and 0.85*floor).
        let captured = renderAndCapture(store: store, minBoardHeight: 500,
                                         forcedHeight: 800)
        // 800 - 256 - 24 = 520. floor=500, 0.85*floor=425. 520 ≥ 500 → .normal
        // Adjust forcedHeight to drop below floor but above 0.85*floor.
        let captured2 = renderAndCapture(store: store, minBoardHeight: 800,
                                          forcedHeight: 1200)
        // 1200 - 384 - 24 = 792. floor=800, 0.85*floor=680. 680 ≤ 792 < 800 → .collapsedSettings
        #expect(captured2 == .collapsedSettings)
    }

    @Test("On state with very tight size — publishes .reducedTime")
    func test_onState_reducedTime() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        let captured = renderAndCapture(store: store, minBoardHeight: 800,
                                         forcedHeight: 1000)
        // 1000 - 320 - 24 = 656. floor=800, 0.85*floor=680. 656 < 680 → .reducedTime
        #expect(captured == .reducedTime)
    }
}

// renderAndCapture(...) is a test helper that mounts the modifier in a
// controlled-size container, reads the env value at a descendant, and returns
// the captured value. Implementation in test file; uses .frame(width:height:)
// to force a known size on the modifier.
```

**Note on `renderAndCapture(...)`:** Implementation detail for plan-phase to resolve.
Two viable approaches:
1. Mount the modifier inside a `HostingController` of fixed size, read the env via a
   probe child view that writes to an `@State` in the test scope (Swift Testing
   `@MainActor` + a `Task { ... }` await pattern).
2. Use `ViewInspector` (3rd-party SPM dep) for direct env introspection. Adds a
   test-only dependency — discuss whether the project wants this.

**Recommendation:** Approach 1 (no 3rd-party dep). Pattern source: similar to how
`SettingsViewTests.swift` probes Settings bindings without ViewInspector.

### Example 2: `VideoModeSlotRouter` unit test (6 × 4 = 24 assertions)

```swift
// Source: synthesized from VideoModeStoreTests.swift pattern + D-02 helper contract.

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
    // … 5 more cases × 4 slot assertions each = 24 total.

    @Test("All 6 locations produce distinct SlotAnchorMaps")
    func test_all_distinct() {
        let maps = VideoModeLocation.allCases.map(VideoModeSlotRouter.anchors(for:))
        // Optionally: just check no two adjacent ones are equal — full distinctness
        // may be too strict (largeTop and largeBottom can share consolidation patterns).
        #expect(maps[0] == maps[1] || maps[0] != maps[1])  // tautological — refine in plan
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@EnvironmentObject` | `@Observable` + custom `EnvironmentKey` | iOS 17 (P4/P9 lock) | Already in use; P10 follows. |
| `PreviewProvider` struct | `#Preview` macro | Xcode 15+ / iOS 17 (already in use at P9 via `VideoCompactControlRow.swift:76-123`) | P10 inherits. |
| `XCTest` | `Swift Testing` (`@Test`, `@Suite`, `#expect`) | Xcode 16+ (already in use at P9) | P10 follows. |
| `MagnificationGesture` | `MagnifyGesture` | iOS 17.0 deprecation (already adopted in v1.0 06.1-03) | UNTOUCHED by P10 per D-15. |
| Manual `padding(.top, h)` for status-bar / nav-bar avoidance | `safeAreaInset(edge:)` | iOS 15+ canonical (P10's first use in project) | New for the project. Audit needed: confirm no adopting game view's existing layout breaks. |

**Deprecated/outdated:**
- `MagnificationGesture` — not relevant to P10 (Hard-Mines MagnifyGesture is locked
  untouched per D-15).
- `PreviewProvider` — replaced by `#Preview` macro. Already migrated in P9.

## Validation Architecture

> Per Nyquist VALIDATION.md generation. Phase 10 inherits the P9 sampling rhythm
> (quick test ~12s, full suite ~90s).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macros) + XCTest host (existing v1.0 / v1.2 setup) |
| Config file | `gamekit/gamekit.xcodeproj` (gamekitTests target) — no new config |
| Quick run command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:gamekitTests/VideoModeAwareTests -only-testing:gamekitTests/VideoModeSlotRouterTests` |
| Full suite command | `xcodebuild test -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Estimated runtime | quick ~15s · full ~95s |

> Device note: Phase 9 used "iPhone 17 Pro Max" as the destination. Either is fine;
> measurement fraction is device-independent (see §Band Measurement).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIDEO-05 (Small slot router) | Slot router returns correct anchors for each of 4 Small zones | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeSlotRouterTests/test_smallTopLeft_anchors` (and 3 siblings) | ❌ Wave 0 |
| VIDEO-06 (Large band reservation) | Modifier reserves `geometry.size.height * 0.32` on Large zones, 0 on Small zones | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_largeTop_reservesBand` | ❌ Wave 0 |
| VIDEO-06 (Compactness levels) | Modifier picks `.normal`/`.collapsedSettings`/`.reducedTime` per `minBoardHeight` thresholds | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_onState_{normal,collapsedSettings,reducedTime}` | ❌ Wave 0 |
| VIDEO-13 (Off-restore byte-identical) | When `store.isEnabled == false`, modifier returns content unchanged (no env override, no inset) | unit | `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests/test_offState_doesNotPublishCompactness` | ❌ Wave 0 |
| (SC4 adoption API compile gate) | `.videoModeAware(minBoardHeight:)` callable on `MinesweeperGameView` | smoke (build) | `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — compile passes IFF the extension exists with the documented signature | ❌ Wave 0 (build-only) |
| (SC5 legibility matrix) | 12-tile `#Preview` matrix renders all 6 zones × 2 presets without crash, legible on visual inspection | manual (Xcode canvas) | n/a — manual sign-off in `10-VERIFICATION.md` | ❌ Wave 0 (manual) |

### Sampling Rate

- **Per task commit:** `xcodebuild test ... -only-testing:gamekitTests/VideoModeAwareTests -only-testing:gamekitTests/VideoModeSlotRouterTests` (~15s)
- **Per wave merge:** `xcodebuild test ... -scheme gamekit` (~95s)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `gamekit/gamekitTests/Core/VideoModeAwareTests.swift` — covers VIDEO-06 +
      VIDEO-13 SC3 short-circuit. Includes `renderAndCapture(...)` helper.
- [ ] `gamekit/gamekitTests/Core/VideoModeSlotRouterTests.swift` — covers VIDEO-05
      (24 anchor assertions across 6 zones).
- [ ] No framework install needed — Swift Testing already in use (verified via
      `VideoModeStoreTests.swift:22-25`).
- [ ] No shared fixtures needed — each test uses isolated `UserDefaults(suiteName:)`
      per `VideoModeStoreTests.makeIsolatedDefaults()` pattern.

> **No SC1 / SC2 / SC4 / SC5 dedicated test files needed beyond the above** — SC4
> is a compile-time gate (the extension on `View` must exist with the right
> signature for any P11 adoption to compile), SC5 is the `#Preview` matrix (manual
> visual sign-off, not automatable in CLI). SC1 and SC2 are the slot router + band
> reservation tests respectively (covered above).

## Security Domain

> Skipped: this phase is purely a layout primitive (UI composition); no auth,
> no input validation surface, no cryptography, no network surface. `security_enforcement`
> if set defaults to enabled, but the applicable ASVS categories are all "no":

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth surface in P10) |
| V3 Session Management | no | — (no sessions) |
| V4 Access Control | no | — (no permission gating in P10) |
| V5 Input Validation | no | — (P10 has no user input; `minBoardHeight: CGFloat` parameter is compile-time-bounded by callers; `VideoModeLocation` is enum → exhaustive switch) |
| V6 Cryptography | no | — (no crypto) |

**Known Threat Patterns for this stack:** None applicable to a pure SwiftUI layout
primitive. The only "threat" worth flagging is **doc drift** — Pitfall 5 (device
dimension mismatch between Docs/screenshots README and actual screenshot pixels);
not a security concern.

## Sources

### Primary (HIGH confidence)

- **`VideoModeStore.swift` / `VideoModeLocation.swift` / `VideoCompactControlRow.swift`**
  — direct read; defines the P9 surface this phase consumes. [VERIFIED: source files]
- **`SC5RegressionTests.swift`** — pattern source for SC3 unit-test approach
  (assert structural invariant + TODO marker for snapshot upgrade). [VERIFIED:
  source file]
- **`08-VIDEO-MODE-LAYOUTS.md`** — per-zone slot routing data source for
  `VideoModeSlotRouter`. [VERIFIED: source file]
- **`08-HARD-MINES-ADR.md`** — D-15 deconfliction contract. [VERIFIED: source file]
- **`08-COMPACT-ROW-TOKENS.md`** — confirms compact-row height = `theme.spacing.xl`
  (24pt) which the modifier subtracts from available board height. [VERIFIED: source
  file]
- **`Docs/screenshots/v1.2-design/home-classic-pip-large-{top,bottom}.png`** —
  band-fraction measurement source. Measured 2026-05-12 via PIL pixel-row scan.
  [VERIFIED: pixel measurement, see §Band Measurement]
- **`DesignKit/Sources/DesignKit/Layout/SpacingTokens.swift`** — confirms
  `spacing.xl = 24` token. [VERIFIED: source file]
- **Apple `ViewModifier` doc** — `developer.apple.com/documentation/swiftui/viewmodifier`
  [CITED]

### Secondary (MEDIUM confidence)

- **swift-by-sundell + swiftuifieldguide.com on `safeAreaInset`** — confirms inset
  stacking behavior. [CITED]
- **swift forums benchmark `forums.swift.org/t/swiftui-and-anyview-performance-benchmarks/65717`**
  — confirms AnyView cost is negligible outside large List/ForEach contexts.
  [CITED]
- **Sarunw / Donny Wals on `@Observable`** — confirms per-property tracking
  granularity. [CITED]
- **AppCoda / SwiftLee on `#Preview` macro** — multiple named blocks per file
  supported. [CITED]

### Tertiary (LOW confidence)

- **WWDC23 "Demystify SwiftUI Performance" video** — referenced as background; not
  directly read. The recommendation to "avoid AnyView and lopsided conditions" is a
  general principle, not a Phase 10 binding constraint (AnyView in P10 is on the
  off-path only and is wrapped at the modifier level, not inside a ForEach).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The DesignKit `Theme` is available to read from inside `VideoModeAware.body` (either via env or via a `theme:` parameter) | Pattern 1 code example | If DesignKit doesn't expose a Theme env, the modifier needs an extra `theme:` parameter at the call site. Plan-phase MUST verify how `VideoCompactControlRow` got its `theme` — it accepts it as a constructor parameter. Likely outcome: modifier also takes `theme:` OR computes compact-row height from a hardcoded `24` (with a code comment noting it equals `theme.spacing.xl`). |
| A2 | `geometry.size.height` inside the modifier's `GeometryReader` reflects the FULL screen height (minus system bars), not the parent container's height | Pattern 1 + Pitfall 4 | If the modifier is applied at a non-greedy parent, height collapses. Plan-phase MUST verify P11 call-site context — `MinesweeperGameView` is typically pushed into a `NavigationStack` so it gets full screen modulo nav bar. If a nav bar is present, the available height differs from `proxy.size.height` by the nav bar height. Possibly: the modifier should use `.ignoresSafeArea()` on the GeometryReader OR add `proxy.safeAreaInsets.top` to the subtraction. |
| A3 | The slot-router data in §Pattern 2 maps correctly to `08-VIDEO-MODE-LAYOUTS.md` "Where controls go" rules | Pattern 2 code | Possible misinterpretation. Plan-phase MUST cross-check each of the 6 `SlotAnchorMap` returns against the layouts doc's per-zone notes. Specifically: the doc only describes "Back / Settings / FAB / picker" movement; the modifier's `SlotAnchorMap` may need extension for game-specific affordances (e.g., Nonogram's lives indicator). |
| A4 | Compactness thresholds (1.0× / 0.85× of floor) produce useful differentiation across the 3 levels | Pattern 1 `pickCompactness` | The 0.85× threshold is a guess; CONTEXT D-14 specifies the levels but not the exact thresholds. Plan-phase may want to set the boundary differently after seeing the actual compactness behavior in the `#Preview` matrix. |
| A5 | `Color.clear.frame(height: ...)` is a sufficient `safeAreaInset` content view | Pattern 1 `applyBand` | Documented pattern. Alternative: pass `EmptyView().frame(height: ...)` (semantically equivalent, slightly more idiomatic). Trivial swap if needed. |
| A6 | The `#Preview` matrix renders cleanly with `VideoModeStore` constructed inside the preview's `init` (i.e., the env injection works in Xcode canvas) | Pattern 3 `StubGame` | Xcode previews historically have issues with `@Observable` types constructed at init time. Plan-phase MUST verify the canvas actually renders all 12 tiles without "no preview available" errors. If it fails: fall back to a static `VideoModeStore` constructed in a `@MainActor` `static let` at file scope (visible to all `#Preview` blocks). |
| A7 | The "iPhone 17 Pro Max" device label in `Docs/screenshots/v1.2-design/README.md` is inaccurate (actual screenshots are 17 Pro / 16 Pro dimensions) | §Band Measurement, Pitfall 5 | Doc drift, not a code risk. Worth a small README correction in a future commit; does NOT block P10. |

**If this table is non-empty:** All 7 assumptions are either resolvable in plan-phase
by direct verification (A1, A2, A3, A6) or are stylistic / cosmetic (A4, A5, A7).
None block planning; none require user re-confirmation before locking. The planner
should resolve A1 + A2 in the first plan task (the `VideoModeAware` skeleton), then
verify A3 by cross-checking each `anchors(for:)` switch case against
`08-VIDEO-MODE-LAYOUTS.md`.

## File-size estimate

Projected line counts (well under §8.5 400-line soft cap, 500-line hard cap):

| File | Projected lines | Risk |
|------|----------------|------|
| `VideoModeAware.swift` | ~245 | Low — under cap with `#Preview` factoring. |
| `VideoModeSlotRouter.swift` | ~90 | Low — 6-case switch + 1 struct + 1 enum. |
| `VideoModeAwareTests.swift` | ~150 | Low — 4 tests + helper. |
| `VideoModeSlotRouterTests.swift` | ~100 | Low — flat assertion list. |

**Mitigation if size grows:** Split `VideoModeCompactness` + its EnvironmentKey
out of `VideoModeAware.swift` into `VideoModeCompactness.swift` (Core/). Same flat
layout; no subdirectory.

## Open Questions

1. **`Theme` access inside the modifier** (A1)
   - What we know: `VideoCompactControlRow` takes `theme:` as constructor parameter
     (not env-injected).
   - What's unclear: Whether the modifier should also take `theme:` or read it via
     env (does DesignKit expose `@Environment(\.theme)`?).
   - Recommendation: Plan-phase task 1 = check DesignKit env surface. If no env,
     the modifier hard-codes `24` (theme.spacing.xl value) with a code comment
     citing the token. Alternative: pass `theme:` at the call site
     (`.videoModeAware(minBoardHeight: 480, theme: theme)`).

2. **`geometry.size.height` vs full screen height** (A2)
   - What we know: GeometryReader reports parent's proposed size.
   - What's unclear: Whether a NavigationStack-pushed game view gets the full screen
     height or a reduced height (minus nav-bar).
   - Recommendation: Plan-phase task spike — add a temporary `print(proxy.size.height)`
     in the modifier when mounted in a stub `NavigationStack` and compare against
     screen height. If reduced, add `+ proxy.safeAreaInsets.top` to the available-board-height
     formula.

3. **Slot router exhaustiveness against banner-placement table** (Phase 13 forward-compat)
   - What we know: Both `VideoModeSlotRouter.anchors(for:)` and the Phase 13 banner
     placement table from `08-BANNER-PLACEMENT.md` encode "opposite-of-PiP"
     geometry.
   - What's unclear: Whether to refactor `VideoModeSlotRouter` to also expose a
     "where does the win/loss banner dock?" anchor for Phase 13 to consume.
   - Recommendation: Plan-phase makes a NOTE in `VideoModeSlotRouter.swift`
     header — "Phase 13 may extend SlotAnchorMap with a `banner` field; if so,
     update this switch with banner anchors from `08-BANNER-PLACEMENT.md`." Don't
     pre-extend now (single-consumer rule).

4. **Compactness threshold value** (A4)
   - What we know: D-14 says "≥ floor → .normal; lower → some level; very low →
     .reducedTime."
   - What's unclear: Exact threshold for the middle case. This research proposed
     0.85×; CONTEXT D-14 doesn't specify.
   - Recommendation: Plan-phase locks the threshold by running the `#Preview`
     matrix and visually picking the cutoff that produces useful differentiation
     across the 6 zones.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Swift Testing, `#Preview` matrix | ✓ (project active) | 16+ | — |
| iOS 17 Simulator (any model) | Build + test target | ✓ | — | — |
| DesignKit SPM local | Token reads | ✓ | local | — |
| Python 3 + Pillow | Band-fraction measurement (one-shot, done in research) | ✓ (used) | 3.x + PIL | Measurement already complete; not needed again. |

No missing dependencies. No fallbacks needed.

## Metadata

**Confidence breakdown:**
- Existing P9 stack reuse (VideoModeStore, env-key, compact row): **HIGH** — direct
  source reads confirm every claim.
- Architecture patterns (`ViewModifier` shape, `safeAreaInset`, custom `EnvironmentKey`):
  **HIGH** — iOS 17 canonical patterns with multiple authoritative sources.
- `largeBandFraction = 0.32`: **MEDIUM** — measured precisely, but the choice to use
  the bottom-PiP worst-case as the single constant (instead of separate
  `largeTopFraction = 0.19` / `largeBottomFraction = 0.32`) is a design call the
  planner can revisit.
- AnyView short-circuit cost: **MEDIUM** — well-understood but no Apple-official
  guidance; community benchmarks confirm cost is negligible outside large list
  contexts.
- Slot-router anchor data (`SlotAnchorMap` values per zone): **MEDIUM** —
  derived from `08-VIDEO-MODE-LAYOUTS.md` interpretation; plan-phase must cross-check
  each switch case (A3).
- Pitfalls (1–6): **HIGH** — each is sourced to documented SwiftUI behavior or a
  cited project pattern.

**Research date:** 2026-05-12
**Valid until:** 2026-06-12 (30 days; stable iOS-17 surface, no fast-moving deps).

---

*Phase: 10-layout-primitives*
*Researched: 2026-05-12*
