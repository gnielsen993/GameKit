# Phase 5: Polish — Pattern Map

**Mapped:** 2026-04-26
**Files analyzed:** 16 (5 NEW + 9 edited + 2 resource folders)
**Analogs found:** 14 / 14 code files (resource folders have no Swift analog)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift` (NEW) | Model (presentation enum) | request-response (VM publishes, view observes) | `Games/Minesweeper/MinesweeperGameState.swift` | exact (sibling enum, same file pattern) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` (EDIT) | ViewModel | event-driven (state transitions) | itself (extend existing reveal/toggleFlag transition sites) | exact (in-place edit) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` (EDIT) | View (LazyVGrid) | request-response (props in, events out) | itself (add per-cell `.transition`) | exact (in-place edit) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift` (EDIT) | View (cell) | request-response | itself (add `.sensoryFeedback` + `.symbolEffect`) | exact (in-place edit) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (EDIT) | View (top-level scene) | event-driven (`.onChange` on phase) | itself (extend with `.phaseAnimator` / `.keyframeAnimator` / `.onChange` orchestration) | exact (in-place edit) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift` (EDIT — minor) | View (card) | request-response | itself (no-op or add fade-in via parent transition; mostly preserved) | exact |
| `gamekit/gamekit/Core/SettingsStore.swift` (EDIT) | Store (`@Observable`) | CRUD (UserDefaults read/write) | itself — additive `cloudSyncEnabled` precedent | exact (in-place edit, additive properties) |
| `gamekit/gamekit/Core/Haptics.swift` (NEW) | Service (`@MainActor enum`) | event-driven (call → AHAP playback) | `Core/GameStats.swift` (logger pattern) + `Core/SettingsStore.swift` (env-key injection of dependency) | role-match (no existing CoreHaptics service) |
| `gamekit/gamekit/Core/SFXPlayer.swift` (NEW) | Service (`@MainActor final class`) | event-driven (call → AVAudioPlayer trigger) | `Core/SettingsStore.swift` (`@Observable` `@MainActor` final class + EnvironmentKey) + `Core/GameStats.swift` (logger + `@MainActor`) | role-match |
| `gamekit/gamekit/Screens/IntroFlowView.swift` (NEW) | View (full-screen cover) | event-driven (page swipe + dismiss) | `Screens/SettingsView.swift` (NavigationStack scaffold + theme reads) + `Screens/RootTabView.swift` (TabView) | role-match (no existing TabView(.page) site) |
| `gamekit/gamekit/Screens/FullThemePickerView.swift` (NEW) | View (NavigationLink destination) | request-response (wraps DKThemePicker) | `Screens/StatsView.swift` (NavigationStack + ScrollView + DKCard wrapper pattern) | role-match (thin wrapper) |
| `gamekit/gamekit/Screens/SettingsView.swift` (EDIT) | View (Settings shell) | event-driven (toggle bindings + nav links) | itself — extend APPEARANCE / add AUDIO; preserve P4 DATA verbatim | exact (in-place edit) |
| `gamekit/gamekit/Screens/RootTabView.swift` (EDIT) | View (root tab shell) | event-driven (`.fullScreenCover` driver) | itself — add `@State isIntroPresented` + `.fullScreenCover` modifier | exact (in-place edit) |
| `gamekit/gamekit/App/GameKitApp.swift` (EDIT — minor) | App entry | wiring | itself — add `SFXPlayer()` construction + `.environment(\.sfxPlayer, ...)` injection | exact (in-place edit) |
| `gamekit/gamekitTests/Games/Minesweeper/MinesweeperPhaseTransitionTests.swift` (NEW) | Test | — | `gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` | exact (sibling test suite shape) |
| `gamekit/gamekitTests/Core/SettingsStoreFlagsTests.swift` (NEW) | Test | — | `gamekitTests/Core/GameStatsTests.swift` | role-match (Core service test using isolated UserDefaults suite per `MinesweeperViewModelTests.makeIsolatedDefaults`) |
| `gamekit/gamekitTests/Core/SFXPlayerTests.swift` (NEW) | Test | — | `gamekitTests/Core/GameStatsTests.swift` (`@MainActor @Suite` shape) | role-match |
| `gamekit/gamekitTests/Core/HapticsTests.swift` (NEW) | Test (file presence + bundle URL load) | — | `gamekitTests/Core/GameStatsTests.swift` | role-match |
| `gamekit/gamekit/Resources/Audio/{tap,win,loss}.caf` (NEW) | Resource | — | (no analog — first audio assets in repo) | none |
| `gamekit/gamekit/Resources/Haptics/{win,loss}.ahap` (NEW) | Resource | — | (no analog — first AHAP assets in repo) | none |

---

## Pattern Assignments

### `MinesweeperPhase.swift` (NEW — Model presentation enum)

**Analog:** `Games/Minesweeper/MinesweeperGameState.swift`

**Foundation-only enum file pattern** (entire file ~36 lines):

```swift
//
//  MinesweeperGameState.swift
//  gamekit
//
//  The lifecycle of a Minesweeper session, owned by the P3 ViewModel.
//  ...
//  Phase 2 invariants:
//    - Four cases: idle / playing / won / lost(mineIdx:)
//    - `lost` carries the triggering MinesweeperIndex so P3 can render the
//      mineHit overlay without reconstructing the trip cell from a diff
//    - No Codable
//    - MinesweeperPhase (animation orchestration enum) is a P3/P5 view-layer
//      concern (CONTEXT.md deferred — not shipped here)
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

nonisolated enum MinesweeperGameState: Equatable, Hashable, Sendable {
    case idle
    case playing
    case won
    case lost(mineIdx: MinesweeperIndex)
}
```
(Source: `Games/Minesweeper/MinesweeperGameState.swift:1-36`)

**Apply to `MinesweeperPhase.swift`:** Same file shape — Foundation-only header doc, `nonisolated enum MinesweeperPhase: Equatable, Sendable`, 5 cases per CONTEXT D-06 (`.idle / .revealing(cells: [MinesweeperIndex]) / .flagging(idx: MinesweeperIndex) / .winSweep / .lossShake(mineIdx: MinesweeperIndex)`). Mark `Hashable` only if Plan needs it (the upstream consumers `.onChange(of:)` need Equatable, which is auto-synthesized).

---

### `MinesweeperViewModel.swift` (EDIT — publish `phase`, mutate atomically)

**Analog:** itself, lines 135-168 (`reveal(at:)` is the canonical "mutate state, then derive terminal-state" call site)

**Existing terminal-state branch shape to piggyback on** (lines 152-167):

```swift
let result = RevealEngine.reveal(at: index, on: board)
board = result.board

// Engines are mutually exclusive (P2 verified — WinDetector.swift:42).
if WinDetector.isLost(board) {
    if let mineIdx = board.allIndices().first(where: { board.cell(at: $0).state == .mineHit }) {
        gameState = .lost(mineIdx: mineIdx)
        lossContext = computeLossContext()
    }
    freezeTimer()
    recordTerminalState(outcome: .loss)
} else if WinDetector.isWon(board) {
    gameState = .won
    freezeTimer()
    recordTerminalState(outcome: .win)
}
```
(Source: `Games/Minesweeper/MinesweeperViewModel.swift:152-167`)

**Apply to P5 edit:**
- Add `private(set) var phase: MinesweeperPhase = .idle` next to existing `gameState` (mirror `private(set)` discipline at line 43).
- Add `private(set) var revealCount: Int = 0` and `private(set) var flagToggleCount: Int = 0` Int triggers for `.sensoryFeedback` / `.symbolEffect` (per RESEARCH §Pattern 4 — value-change trigger pattern).
- After `RevealEngine.reveal(...)` writes `board`, atomically set `phase = .revealing(cells: result.revealed)` and bump `revealCount += 1`.
- In `.lost` branch: `phase = .lossShake(mineIdx: mineIdx)`. In `.won` branch: `phase = .winSweep`. Set BEFORE `recordTerminalState(...)` so SwiftData failure logging can't intercept the phase change.
- In `toggleFlag(at:)` (lines 172-199): on the `.hidden → .flagged` and `.flagged → .hidden` paths, set `phase = .flagging(idx: index)` then bump `flagToggleCount += 1`.
- In `restart()` (lines 202-209): reset `phase = .idle`, `revealCount = 0`, `flagToggleCount = 0`.

**Hard constraint** (CONTEXT D-05): VM owns NO `Animation` types, NO `withAnimation` calls, NO `import SwiftUI`. The Foundation-only invariant from MinesweeperViewModel.swift line 20 ("// no SwiftUI, no Combine, no SwiftData") MUST be preserved.

---

### `MinesweeperBoardView.swift` (EDIT — per-cell `.transition` cascade)

**Analog:** itself, lines 50-67 (existing `LazyVGrid` + `ForEach`)

**Existing ForEach pattern** (lines 50-67):

```swift
var body: some View {
    ScrollView(scrollAxis(for: board.difficulty), showsIndicators: false) {
        LazyVGrid(columns: columns, spacing: theme.spacing.xs) {
            ForEach(board.allIndices(), id: \.self) { index in
                MinesweeperCellView(
                    cell: board.cell(at: index),
                    index: index,
                    cellSize: cellSize,
                    theme: theme,
                    gameState: gameState,
                    onTap: onTap,
                    onLongPress: onLongPress
                )
            }
        }
        .padding(.horizontal, theme.spacing.l)
        .padding(.vertical, theme.spacing.s)
    }
}
```
(Source: `Games/Minesweeper/MinesweeperBoardView.swift:50-67`)

**Apply to P5 edit:**
- Add `let phase: MinesweeperPhase` prop alongside existing `gameState`. Pass through from `MinesweeperGameView`.
- Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` (per CONTEXT D-04 — every animated view reads independently).
- For each cell in `ForEach`, compute per-cell delay via the engine-order index in `phase.revealing` cells: `let perCellDelay: Double = reduceMotion ? 0 : min(0.008 * Double(orderIndex), theme.motion.normal / Double(count))` per CONTEXT D-01.
- Apply `.transition(.opacity.animation(.easeOut(duration: theme.motion.fast).delay(perCellDelay)))` directly on `MinesweeperCellView` (RESEARCH idiom from CONTEXT discretion, not a wrapper).
- Add outer `.offset(x: shakeOffset)` driven by `.keyframeAnimator(initialValue: 0, trigger: phase == .lossShake)` per CONTEXT D-03 — OR move the `.offset` to `MinesweeperGameView` and keep BoardView pure (recommended — see GameView pattern below).

---

### `MinesweeperCellView.swift` (EDIT — `.sensoryFeedback` + `.symbolEffect(.bounce)`)

**Analog:** itself, lines 38-59 (existing body modifier chain)

**Existing modifier chain** (lines 38-59):

```swift
var body: some View {
    tileBackground
        .frame(width: cellSize, height: cellSize)
        .overlay(glyph)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .exclusively(before: TapGesture())
                .onEnded { result in
                    switch result {
                    case .first:  onLongPress(index)
                    case .second: onTap(index)
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityAddTraits(.isButton)
}
```
(Source: `Games/Minesweeper/MinesweeperCellView.swift:38-59`)

**Apply to P5 edit:** Add new props `let revealCount: Int`, `let flagToggleCount: Int`, `let hapticsEnabled: Bool`, `let reduceMotion: Bool` (passed from BoardView from VM/Env). Insert these modifiers BEFORE `.accessibilityElement(...)`:

```swift
.sensoryFeedback(.selection, trigger: hapticsEnabled ? revealCount : 0)
.sensoryFeedback(.impact(weight: .light), trigger: hapticsEnabled ? flagToggleCount : 0)
.symbolEffect(.bounce, value: reduceMotion ? 0 : flagToggleCount)
```

**Critical Reduce Motion contract** (CONTEXT D-04): `flagToggleCount` is gated by `reduceMotion ? 0 : flagToggleCount` so that with Reduce Motion ON, the trigger value never changes and `.symbolEffect(.bounce)` does not animate. Same defensive pattern for haptics gating via `hapticsEnabled`.

**Critical preservation:** the `.gesture` chain at lines 44-55 — `LongPressGesture(0.25).exclusively(before: TapGesture())` — is locked from P3. Do not change to `.simultaneously(with:)` (RESEARCH Pitfall 7 fires both).

---

### `MinesweeperGameView.swift` (EDIT — `.phaseAnimator` win sweep + `.keyframeAnimator` loss shake + `.onChange` orchestration)

**Analog:** itself, lines 55-136 (existing body + `.onChange` + `.task` orchestration)

**Existing `.onChange` orchestration pattern** (lines 115-126):

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background:
        viewModel.pause()
    case .active:
        viewModel.resume()
    case .inactive:
        break
    @unknown default:
        break
    }
}
```
(Source: `Games/Minesweeper/MinesweeperGameView.swift:115-126`)

**Existing environment / theme read pattern** (lines 41-49):

```swift
struct MinesweeperGameView: View {
    @State private var viewModel: MinesweeperViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var didInjectStats = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }
```
(Source: `Games/Minesweeper/MinesweeperGameView.swift:41-49`)

**Apply to P5 edit:**
- Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.
- Add `@Environment(\.settingsStore) private var settingsStore`.
- Add `@Environment(\.sfxPlayer) private var sfxPlayer` (NEW key — see SFXPlayer below).
- Add `@State private var winWashPhase: WinWashPhase = .idle` (or use `.phaseAnimator([0.0, 0.25, 0.0], trigger: viewModel.phase == .winSweep)`).
- Wrap `MinesweeperBoardView` in `.offset(x: shakeOffset).keyframeAnimator(initialValue: 0.0, trigger: viewModel.phase) { content, value in content.offset(x: value) } keyframes: { _ in ... }` per RESEARCH §Pattern 2 + CONTEXT D-03 keyframes (`+8 @ 100ms → −8 @ 200ms → +4 @ 300ms → 0 @ 400ms`). Reduce Motion: skip the `.keyframeAnimator` modifier when `reduceMotion` is true.
- Add `.phaseAnimator` overlay above the board for `.winSweep` per CONTEXT D-02 — `theme.colors.success.opacity(animatedAlpha)` keyframes `0 → 0.25 → 0` over `theme.motion.slow`. Reduce Motion: emit single static peak.
- Add `.onChange(of: viewModel.phase)` handler — on `.winSweep`, call `Haptics.playAHAP(named: "win")` and `sfxPlayer.play(.win)`. On `.lossShake`, call `Haptics.playAHAP(named: "loss")` and `sfxPlayer.play(.loss)`. On `.revealing`, call `sfxPlayer.play(.tap)`.

**Constraint:** All terminal-state side effects (Haptics + SFX) fire via `.onChange(of: viewModel.phase)` — NOT via `.task` or `.onAppear` (avoids double-fire on re-render, RESEARCH Pitfall pattern from `didInjectStats` precedent at lines 47, 131).

---

### `Core/SettingsStore.swift` (EDIT — additive flags pattern)

**Analog:** itself, lines 32-78 (the entire existing `cloudSyncEnabled` precedent)

**Existing flag declaration pattern** (lines 43-57):

```swift
@Observable
@MainActor
final class SettingsStore {

    /// Whether SwiftData should construct its `ModelContainer` with
    /// `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` (D-08).
    var cloudSyncEnabled: Bool {
        didSet {
            userDefaults.set(cloudSyncEnabled, forKey: Self.cloudSyncEnabledKey)
        }
    }

    private let userDefaults: UserDefaults

    /// UserDefaults key for the cloud-sync flag (D-28).
    /// Renaming = preference loss for any user who already toggled the flag.
    static let cloudSyncEnabledKey = "gamekit.cloudSyncEnabled"
```
(Source: `Core/SettingsStore.swift:43-57`)

**Existing init + EnvironmentKey** (lines 61-78):

```swift
init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    self.cloudSyncEnabled = userDefaults.bool(forKey: Self.cloudSyncEnabledKey)
}

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
(Source: `Core/SettingsStore.swift:61-78`)

**Apply to P5 edit (additive — preserve cloudSyncEnabled verbatim):**
- Add three new `var` properties beside `cloudSyncEnabled` with identical `didSet { userDefaults.set(... , forKey: Self.<key>) }` shape:
  - `var hapticsEnabled: Bool` — key `gamekit.hapticsEnabled`, default `true` (per CONTEXT D-10)
  - `var sfxEnabled: Bool` — key `gamekit.sfxEnabled`, default `false` (per CONTEXT D-10)
  - `var hasSeenIntro: Bool` — key `gamekit.hasSeenIntro`, default `false` (per CONTEXT D-23)
- Add three new static key constants beside `cloudSyncEnabledKey`.
- Extend `init(userDefaults:)` — read each new flag with `userDefaults.bool(forKey: Self.<key>)`. **Default-true caveat for `hapticsEnabled`:** `userDefaults.bool(forKey:)` returns `false` for unset keys (Apple docs noted at lines 25-26). For a default-`true` flag, use the conventional pattern: `self.hapticsEnabled = userDefaults.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true`. Do NOT use `.register(defaults:)` — the file's existing comment (line 25) explicitly avoids that.
- The `EnvironmentKey` conformance + `extension EnvironmentValues` block require NO changes (the same `settingsStore` key carries the additive properties).

---

### `Core/Haptics.swift` (NEW — `@MainActor enum`)

**Analog:** `Core/GameStats.swift` (logger pattern + `@MainActor` final class) and `Core/SettingsStore.swift` (`@MainActor` annotation + EnvironmentKey)

**Logger pattern from `Core/GameStats.swift`** (lines 35-50):

```swift
import Foundation
import SwiftData
import os

@MainActor
final class GameStats {
    private let modelContext: ModelContext
    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "persistence"
    )
```
(Source: `Core/GameStats.swift:35-50`)

**Logger usage with `privacy: .public`** (lines 91-94):

```swift
} catch {
    logger.error(
        "BestTime evaluation failed: \(error.localizedDescription, privacy: .public)"
    )
}
```
(Source: `Core/GameStats.swift:91-94`)

**Apply to `Core/Haptics.swift` (NEW):**
- File header doc citing CONTEXT D-11.
- `import Foundation`, `import CoreHaptics`, `import os`.
- `@MainActor enum Haptics` (per CONTEXT D-11 — static methods, no instance).
- `private static var engine: CHHapticEngine?` — lazy via `static func ensureEngine() throws` called inside `playAHAP(...)`.
- `private static let logger = Logger(subsystem: "com.lauterstar.gamekit", category: "haptics")` (matches GameStats subsystem; new category per RESEARCH §Architecture Map line 161).
- `static func playAHAP(named name: String, hapticsEnabled: Bool)` — ALL gating happens at the source per CONTEXT D-10. Signature recommendation: have the call site pass `settingsStore.hapticsEnabled` explicitly (cleaner than reading the env in a non-View). Early return on false.
- `Bundle.main.url(forResource: name, withExtension: "ahap")` per CONTEXT D-11 + Specifics.
- All catch blocks log via `logger.error("... \(error.localizedDescription, privacy: .public)")` and return — failure is non-fatal per CONTEXT D-11.
- Wire `engine.resetHandler = { Self.engine = nil }` so a system-triggered reset re-loads on next call.

---

### `Core/SFXPlayer.swift` (NEW — `@MainActor final class` injected via custom EnvironmentKey)

**Analog:** `Core/SettingsStore.swift` (the entire file — same shape, same EnvironmentKey injection)

**EnvironmentKey injection pattern from `Core/SettingsStore.swift`** (lines 67-78):

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
(Source: `Core/SettingsStore.swift:67-78`)

**Apply to `Core/SFXPlayer.swift` (NEW):**
- File header doc citing CONTEXT D-12.
- `import Foundation`, `import AVFoundation`, `import os`.
- `@MainActor final class SFXPlayer` (per CONTEXT D-12).
- Three `let`-stored `AVAudioPlayer?` properties: `tapPlayer`, `winPlayer`, `lossPlayer` — each constructed in `init()` via `try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "tap", withExtension: "caf")!)` then `.prepareToPlay()` per CONTEXT D-08.
- `enum SFXEvent { case tap, win, loss }` declared at module scope or as nested type per CONTEXT D-12.
- `func play(_ event: SFXEvent, sfxEnabled: Bool)` — gated at the source per CONTEXT D-10. Early return on false.
- AVAudioSession setup in init: `try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)` per CONTEXT D-09.
- Logger pattern from GameStats: `private let logger = Logger(subsystem: "com.lauterstar.gamekit", category: "audio")`.
- EnvironmentKey injection (mirror SettingsStore lines 67-78):

  ```swift
  private struct SFXPlayerKey: EnvironmentKey {
      @MainActor static let defaultValue = SFXPlayer()
  }

  extension EnvironmentValues {
      var sfxPlayer: SFXPlayer {
          get { self[SFXPlayerKey.self] }
          set { self[SFXPlayerKey.self] = newValue }
      }
  }
  ```

- `GameKitApp.init()` constructs the instance after `SettingsStore` (per CONTEXT D-12) and injects via `.environment(\.sfxPlayer, sfxPlayer)` on `RootTabView` (mirror existing `.environment(\.settingsStore, settingsStore)` at `App/GameKitApp.swift:70`).

---

### `Screens/IntroFlowView.swift` (NEW — `.fullScreenCover` content)

**Analog:** `Screens/SettingsView.swift` (NavigationStack + theme reads + ScrollView scaffold) + `Screens/RootTabView.swift` (TabView precedent)

**Theme + colorScheme env-read pattern from `Screens/SettingsView.swift`** (lines 37-49):

```swift
struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var isExporterPresented = false

    private var theme: Theme { themeManager.theme(using: colorScheme) }
```
(Source: `Screens/SettingsView.swift:37-49`)

**TabView pattern from `Screens/RootTabView.swift`** (lines 14-37):

```swift
struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: Int = 0

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(...) }
                .tag(0)
            ...
        }
        .tint(theme.colors.accentPrimary)
    }
}
```
(Source: `Screens/RootTabView.swift:14-37`)

**Apply to `Screens/IntroFlowView.swift` (NEW):**
- `@EnvironmentObject private var themeManager: ThemeManager` + `@Environment(\.colorScheme)` + computed `theme` property — copy verbatim from SettingsView lines 37-49.
- `@Environment(\.settingsStore) private var settingsStore` — read for `hasSeenIntro` write on dismiss.
- `@Environment(\.dismiss) private var dismiss` — for the Skip / Done buttons.
- `@State private var currentStep: Int = 0` — TabView `selection` binding.
- `TabView(selection: $currentStep)` with three `.tag(0/1/2)` step views, each a file-private `IntroStep1ThemesView` / `IntroStep2StatsView` / `IntroStep3SignInView` (per RESEARCH alternatives table — file-private structs, not separate files, since IntroFlowView stays under 400 lines).
- `.tabViewStyle(.page(indexDisplayMode: .always))` per CONTEXT D-18.
- `.tint(theme.colors.accentPrimary)` on the TabView (mirror RootTabView line 36).
- Skip button overlay: top-trailing on every step per CONTEXT D-22. `.toolbar { ToolbarItem(placement: .topBarTrailing) { ... } }` if wrapping in NavigationStack — but CONTEXT D-18 forbids NavigationStack inside the cover. Use `.overlay(alignment: .topTrailing) { Button(...) }` with `.padding(theme.spacing.l)`.
- Continue / Done button bottom-trailing per CONTEXT D-22 — DKButton-styled. Use `DKButton("Continue", style: .primary, theme: theme) { currentStep += 1 }` for steps 1+2; `DKButton("Done", style: .primary, theme: theme) { dismissIntro() }` for step 3.
- `private func dismissIntro() { settingsStore.hasSeenIntro = true; dismiss() }` — single dismissal path used by Skip + Done.
- Each step view receives `let theme: Theme` props-only (CLAUDE.md §8.2 — data-driven, not data-fetching).

**SignInWithAppleButton in `IntroStep3SignInView`** (per CONTEXT D-21 + RESEARCH alternatives):

```swift
import AuthenticationServices

SignInWithAppleButton(.signIn, onRequest: { _ in
    // P6 wires actual SIWA via PERSIST-04 — no-op in P5
}, onCompletion: { _ in
    // P6 PERSIST-04
})
.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
```

Constraint: per RESEARCH "Claude's Discretion" line — DesignKit does NOT override SIWA tints (Apple HIG forbids). Accept system's ~50pt height (do NOT force 44pt).

---

### `Screens/FullThemePickerView.swift` (NEW — thin wrapper)

**Analog:** `Screens/StatsView.swift` (lines 56-76 — NavigationStack + ScrollView + DKCard wrap)

**Wrapper pattern from `Screens/StatsView.swift`** (lines 56-76):

```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                settingsSectionHeader(theme: theme, String(localized: "MINESWEEPER"))
                DKCard(theme: theme) {
                    MinesStatsCard(...)
                }
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Stats"))
    }
}
```
(Source: `Screens/StatsView.swift:56-76`)

**Apply to `Screens/FullThemePickerView.swift` (NEW):**
- This view is rendered as a `NavigationLink` destination from `SettingsView` — so it does NOT own its own `NavigationStack` (Settings already has one at line 56). Use a bare `ScrollView` root.
- Same `theme` env-read pattern as StatsView lines 56-76.
- Body content: `DKThemePicker(themeManager: themeManager, theme: theme, scheme: colorScheme, catalog: PresetCatalog.all, maxGridHeight: nil)` per CONTEXT D-14.
- `DKThemePicker` requires `ThemeManager` + `Theme` + `ColorScheme` — see `DesignKit/Sources/DesignKit/Components/DKThemePicker.swift:25-40` for the init signature.
- `.background(theme.colors.background.ignoresSafeArea())` and `.navigationTitle(String(localized: "Themes"))` (or similar).

---

### `Screens/SettingsView.swift` (EDIT — replace P1 stub APPEARANCE + ABOUT, add AUDIO; preserve P4 DATA verbatim)

**Analog:** itself, lines 113-174 (existing `appearanceSection` / `dataSection` / `aboutSection` shape) + private `SettingsActionRow` at lines 217-239

**Existing section shape pattern** (lines 113-123):

```swift
@ViewBuilder
private var appearanceSection: some View {
    // P1 stub — UNCHANGED. SHELL-02 polish at P5.
    settingsSectionHeader(theme: theme, String(localized: "APPEARANCE"))
    DKCard(theme: theme) {
        Text(String(localized: "Theme controls coming in a future update."))
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```
(Source: `Screens/SettingsView.swift:113-123`)

**Existing P4 DATA section divider pattern** (lines 138-152) — REUSE for AUDIO + ABOUT row dividers:

```swift
SettingsActionRow(
    theme: theme,
    glyph: "square.and.arrow.up",
    label: String(localized: "Export stats"),
    glyphTint: theme.colors.textPrimary
) { ... }
Rectangle()
    .fill(theme.colors.border)
    .frame(height: 1)
SettingsActionRow(
    theme: theme,
    glyph: "square.and.arrow.down",
    label: String(localized: "Import stats"),
    ...
```
(Source: `Screens/SettingsView.swift:130-148`)

**Existing private `SettingsActionRow` pattern** (lines 217-239) — copy shape for new file-private `SettingsToggleRow` (per UI-SPEC §Component Inventory line 24):

```swift
private struct SettingsActionRow: View {
    let theme: Theme
    let glyph: String
    let label: String
    let glyphTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.s) {
                Image(systemName: glyph)
                    .foregroundStyle(glyphTint)
                Text(label)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)               // HIG min target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```
(Source: `Screens/SettingsView.swift:217-239`)

**Apply to `Screens/SettingsView.swift` (EDIT):**
- Section order in `body` `VStack`: `appearanceSection → audioSection → dataSection → aboutSection` per CONTEXT D-13.
- **APPEARANCE section** (replace P1 stub at lines 113-123): inside `DKCard`, render `DKThemePicker(themeManager: themeManager, theme: theme, scheme: colorScheme, catalog: PresetCatalog.core, maxGridHeight: nil)` (5 inline swatches per CONTEXT D-14). Below the picker, add a 1pt divider `Rectangle()` (mirror DATA divider pattern at line 139), then `NavigationLink(destination: FullThemePickerView()) { settingsNavRow(theme: theme, title: String(localized: "More themes & custom colors")) }` — `settingsNavRow` already exists at `Screens/SettingsComponents.swift:24-36`.
- **AUDIO section (NEW)**: identical card+divider shape as DATA section. Two `SettingsToggleRow` instances:
  - "Haptics" → `Toggle("Haptics", isOn: Bindable(settingsStore).hapticsEnabled)` — leading glyph `iphone.radiowaves.left.and.right` per UI-SPEC line 25
  - 1pt divider `Rectangle()`
  - "Sound effects" → `Toggle("Sound effects", isOn: Bindable(settingsStore).sfxEnabled)` — leading glyph `speaker.wave.2.fill` per UI-SPEC line 25
  - Both `Toggle`s carry `.tint(theme.colors.accentPrimary)` per UI-SPEC line 103
- **DATA section** (lines 126-162): preserved verbatim per CONTEXT D-16.
- **ABOUT section** (replace P1 stub at lines 164-174): three rows in `DKCard` separated by 1pt dividers (mirror DATA divider pattern):
  - "Version" row — trailing value `Bundle.main.releaseVersionNumber + " (" + buildNumber + ")"` rendered with `theme.typography.monoNumber` + `.monospacedDigit()` per UI-SPEC §Typography line 65
  - "Privacy" row — inline-disclosure: `@State private var isPrivacyExpanded = false`; tap toggles, expansion shows brief copy with `theme.colors.textSecondary` per CONTEXT D-17 + UI-SPEC line 91
  - "Acknowledgments" row — `NavigationLink(destination: AcknowledgmentsView()) { settingsNavRow(theme: theme, title: ...) }`. Acknowledgments destination view = bare ScrollView with `theme.typography.caption` text rows per UI-SPEC line 66
- **Add new file-private `SettingsToggleRow`** (mirror `SettingsActionRow` shape from lines 217-239): props `theme: Theme`, `glyph: String`, `label: String`, `isOn: Binding<Bool>`. Body composes `HStack { Image + Text + Spacer + Toggle("", isOn: isOn).labelsHidden().tint(theme.colors.accentPrimary) }.frame(minHeight: 44)`.

**Hard constraint** (CONTEXT D-16 + UI-SPEC §Component Inventory): the existing `SettingsActionRow` private struct (lines 217-239) and the entire DATA section block (lines 126-162) must remain byte-identical. Adding the new `SettingsToggleRow` is purely additive.

---

### `Screens/RootTabView.swift` (EDIT — `.fullScreenCover` driver)

**Analog:** itself, lines 14-37 (existing TabView shape) + `Screens/SettingsView.swift` lines 84-99 (existing `.alert(isPresented:)` modifier pattern as the "modal-with-binding" precedent for `.fullScreenCover`)

**Existing TabView shape** (lines 22-37):

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        HomeView()
            .tabItem { Label(String(localized: "Home"), systemImage: "house") }
            .tag(0)
        StatsView()
            .tabItem { Label(String(localized: "Stats"), systemImage: "chart.bar") }
            .tag(1)
        SettingsView()
            .tabItem { Label(String(localized: "Settings"), systemImage: "gearshape") }
            .tag(2)
    }
    .tint(theme.colors.accentPrimary)
}
```
(Source: `Screens/RootTabView.swift:22-37`)

**Apply to `Screens/RootTabView.swift` (EDIT):**
- Add `@Environment(\.settingsStore) private var settingsStore`.
- Add `@State private var isIntroPresented: Bool = false` (initialized from `settingsStore.hasSeenIntro` in `.onAppear`).
- Append `.fullScreenCover(isPresented: $isIntroPresented) { IntroFlowView() }` to the TabView per CONTEXT D-23.
- Add `.onAppear { isIntroPresented = !settingsStore.hasSeenIntro }` — read once on first appear. The IntroFlowView writes `hasSeenIntro = true` on dismiss (per IntroFlowView pattern above), so subsequent app launches see `hasSeenIntro = true` and the cover never re-presents.

---

### `App/GameKitApp.swift` (EDIT — minor, inject SFXPlayer)

**Analog:** itself, lines 36-83 (existing settingsStore injection)

**Existing dependency-construction pattern** (lines 42-72):

```swift
init() {
    // SettingsStore must be constructed BEFORE the container so
    // cloudSyncEnabled is available for ModelConfiguration (D-08).
    let store = SettingsStore()
    _settingsStore = State(initialValue: store)

    let schema = Schema([GameRecord.self, BestTime.self])
    let config = ModelConfiguration(...)
    do {
        sharedContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to construct shared ModelContainer: \(error)")
    }
}

var body: some Scene {
    WindowGroup {
        RootTabView()
            .environmentObject(themeManager)
            .environment(\.settingsStore, settingsStore)
            .preferredColorScheme(preferredScheme)
            .modelContainer(sharedContainer)
    }
}
```
(Source: `App/GameKitApp.swift:42-72`)

**Apply to P5 edit:**
- Add `@State private var sfxPlayer: SFXPlayer` next to existing `@State private var settingsStore`.
- In `init()`, after `let store = SettingsStore()` line: `let sfx = SFXPlayer(); _sfxPlayer = State(initialValue: sfx)` — construction order respects CONTEXT D-12 ("Constructed at GameKitApp.init() after SettingsStore").
- Append `.environment(\.sfxPlayer, sfxPlayer)` to the RootTabView modifier chain at line 70.

---

### Tests — `MinesweeperPhaseTransitionTests.swift` (NEW)

**Analog:** `gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift`

**Existing test suite shape** (lines 19-43):

```swift
import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("MinesweeperViewModel")
struct MinesweeperViewModelTests {

    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    static func makeVM(
        difficulty: MinesweeperDifficulty? = nil,
        seed: UInt64 = 1,
        clockReturns date: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> (vm: MinesweeperViewModel, defaults: UserDefaults) {
        let defaults = makeIsolatedDefaults()
        let vm = MinesweeperViewModel(
            difficulty: difficulty,
            userDefaults: defaults,
            clock: { date },
            rng: SeededGenerator(seed: seed)
        )
        return (vm, defaults)
    }
```
(Source: `gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift:19-43`)

**Existing test method pattern** (lines 64-78):

```swift
@Test
func firstReveal_idleToPlaying_generatesFirstTapSafeBoard() {
    let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
    #expect(vm.gameState == .idle)
    #expect(vm.timerAnchor == nil)

    let firstTap = MinesweeperIndex(row: 0, col: 0)
    vm.reveal(at: firstTap)

    #expect(vm.gameState == .playing)
    ...
}
```
(Source: `gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift:64-78`)

**Apply to `MinesweeperPhaseTransitionTests.swift`:**
- `@MainActor @Suite("MinesweeperPhaseTransitions")` shape.
- Reuse `MinesweeperViewModelTests.makeVM(...)` static factory directly (it's `static` so tests in a sibling suite can call it as `MinesweeperViewModelTests.makeVM(...)` — verified at line 81 of the same file where `RevealAndFlagTests` uses it).
- Test cases (one per CONTEXT D-06 transition):
  - `firstReveal_setsPhaseToRevealing_withEngineOrderedCells`
  - `toggleFlag_setsPhaseToFlagging_andBumpsFlagToggleCount`
  - `revealMine_setsPhaseToLossShake_withTrippedMineIndex`
  - `revealLastSafe_setsPhaseToWinSweep`
  - `restart_resetsPhaseToIdle_andClearsCounters`

---

### Tests — `Core/SettingsStoreFlagsTests.swift` (NEW)

**Analog:** `gamekitTests/Core/GameStatsTests.swift` + `gamekitTests/Games/Minesweeper/MinesweeperViewModelTests.swift` (the `makeIsolatedDefaults()` helper at lines 25-28)

**Isolated UserDefaults pattern** (from `MinesweeperViewModelTests.swift:25-28`):

```swift
static func makeIsolatedDefaults() -> UserDefaults {
    let suite = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}
```

**Apply to `SettingsStoreFlagsTests.swift`:**
- `@MainActor @Suite("SettingsStoreFlags")` shape per GameStatsTests line 25.
- Per-test isolated `UserDefaults(suiteName: "test-\(UUID().uuidString)")!` per the above helper (avoids cross-test bleed).
- Test cases:
  - `defaults_haveCorrectInitialValues` — `cloudSyncEnabled == false` (P4 preserved), `hapticsEnabled == true` (CONTEXT D-10), `sfxEnabled == false` (CONTEXT D-10), `hasSeenIntro == false` (CONTEXT D-23).
  - `setHapticsEnabled_persistsToUserDefaults` — write, re-read via `UserDefaults.bool(forKey: SettingsStore.hapticsEnabledKey)`.
  - Same for `sfxEnabled` and `hasSeenIntro`.
  - `unsetHapticsEnabledKey_returnsTrueByDefault` — verifies the `object(forKey:) as? Bool ?? true` default-true pattern works for fresh installs.

---

### Tests — `Core/SFXPlayerTests.swift` + `Core/HapticsTests.swift` (NEW)

**Analog:** `gamekitTests/Core/GameStatsTests.swift` (`@MainActor @Suite` + per-test factory)

**Apply:**
- Both follow `@MainActor @Suite(...)` shape.
- `SFXPlayerTests`: verify `init()` constructs without throwing, verifies all 3 `AVAudioPlayer` instances are non-nil after init (proves CAF files are bundled), verify `play(.tap, sfxEnabled: false)` does NOT call `.play()` (mock or use post-condition state — `AVAudioPlayer.isPlaying` reads false). Note: full audio playback is not unit-testable; assert the gating-at-source contract (CONTEXT D-10) instead of audio output.
- `HapticsTests`: verify `Bundle.main.url(forResource: "win", withExtension: "ahap")` returns non-nil; verify `playAHAP(named: "win", hapticsEnabled: false)` is a no-op (no engine construction); minimal smoke that the engine attempt does not crash on iOS Simulator (CHHapticEngine is documented to be a no-op on Simulator — verify the catch path logs and returns).

---

## Shared Patterns

### Pattern A — `@MainActor` Core service + EnvironmentKey injection

**Source:** `Core/SettingsStore.swift:32-78` (entire file)

**Apply to:** `Core/SFXPlayer.swift`, and recommended for `Core/Haptics.swift` if planner prefers an instance over an enum (CONTEXT D-11 specifies enum, but the EnvironmentKey shape is the canonical Core-service injection seam).

```swift
@Observable             // omit on SFXPlayer (no observable state); keep on SettingsStore
@MainActor
final class <ServiceName> {
    init(...) { ... }
}

private struct <ServiceName>Key: EnvironmentKey {
    @MainActor static let defaultValue = <ServiceName>()
}

extension EnvironmentValues {
    var <serviceName>: <ServiceName> {
        get { self[<ServiceName>Key.self] }
        set { self[<ServiceName>Key.self] = newValue }
    }
}
```

### Pattern B — `os.Logger` non-fatal failure logging

**Source:** `Core/GameStats.swift:47-50` and `91-94`

**Apply to:** `Core/Haptics.swift` (category `"haptics"`), `Core/SFXPlayer.swift` (category `"audio"`), `Screens/IntroFlowView.swift` SIWA tap closure (category `"auth"`).

```swift
private let logger = Logger(
    subsystem: "com.lauterstar.gamekit",
    category: "<category>"
)
// ...
logger.error("<failure description>: \(error.localizedDescription, privacy: .public)")
```

Always use `privacy: .public` for system-error descriptions (matches GameStats line 92 + StatsExporter precedent at `Core/StatsExporter.swift:39`). Failure must be non-fatal (silent no-op + log) for both Haptics and SFX per CONTEXT D-11/D-12.

### Pattern C — Theme env-read at View root

**Source:** `Screens/SettingsView.swift:37-49`, `Screens/RootTabView.swift:14-20`, `Games/Minesweeper/MinesweeperGameView.swift:41-49`

**Apply to:** EVERY new P5 view (`IntroFlowView`, `FullThemePickerView`, `AcknowledgmentsView`, all file-private step views).

```swift
@EnvironmentObject private var themeManager: ThemeManager
@Environment(\.colorScheme) private var colorScheme
private var theme: Theme { themeManager.theme(using: colorScheme) }
```

Child views get `theme: Theme` as a let prop (RESEARCH §Anti-Pattern "Re-fetching theme tokens inside cell views" — preserved from P3, see `MinesweeperGameView.swift:7-9`).

### Pattern D — Token-only styling (zero `Color(...)` literals)

**Source:** `Games/Minesweeper/MinesweeperCellView.swift:23` ("Zero Color(...) literals — FOUND-07 pre-commit hook rejects") + `Games/Minesweeper/MinesweeperHeaderBar.swift:17` (same)

**Apply to:** EVERY P5 file. Zero `Color(red:...)`, `Color(hex:)`, `.foregroundColor(...)`. All colors via `theme.colors.{...}`; all paddings via `theme.spacing.{xs|s|m|l|xl|xxl}`; all radii via `theme.radii.{card|button|chip|sheet}`; all durations via `theme.motion.{fast|normal|slow}`. Use `.foregroundStyle(...)` not `.foregroundColor(...)` per CLAUDE.md §8.6.

### Pattern E — Reduce Motion contract per animated view (load-bearing for A11Y-03)

**Source:** No existing analog — P5 introduces this. Pattern derived from CONTEXT D-04 + RESEARCH §Pattern 14.

**Apply to:** `MinesweeperBoardView`, `MinesweeperCellView`, `MinesweeperGameView` (all three animated views).

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// ...
// Cascade: per-cell delay = reduceMotion ? 0 : min(0.008 * idx, theme.motion.normal / count)
// Win wash: emit single static peak instead of phaseAnimator
// Loss shake: skip the .keyframeAnimator modifier entirely
// Flag spring: gate the trigger value — .symbolEffect(.bounce, value: reduceMotion ? 0 : flagToggleCount)
```

Each animated view reads `@Environment(\.accessibilityReduceMotion)` independently — do NOT centralize in VM (VM has no `import SwiftUI` per CONTEXT D-05).

### Pattern F — LocalizedStringKey for auto-extraction to xcstrings

**Source:** `Games/Minesweeper/MinesweeperCellView.swift:151-164` (the `accessibilityLabelKey` returns `LocalizedStringKey` for `SWIFT_EMIT_LOC_STRINGS=YES` auto-extraction per RESEARCH §Pattern 7) and ubiquitous use of `String(localized: "...")` across Settings/RootTabView (`Screens/SettingsView.swift:67, 88, 95-98, 102-103`)

**Apply to:** EVERY user-visible string in `IntroFlowView` (titles, body copy, button labels, accessibility labels), AUDIO toggle labels, ABOUT row labels, Acknowledgments destination text. Use `String(localized: "...")` for ad-hoc strings; use `LocalizedStringKey` for accessibility-label getters (mirror MinesweeperCellView.swift:151-164).

### Pattern G — Tappable row HIG carve-out

**Source:** `Screens/SettingsView.swift:233-235` (`SettingsActionRow` `.frame(minHeight: 44)`)

**Apply to:** new `SettingsToggleRow` (mirror exactly), AUDIO + ABOUT rows that are tappable (Privacy disclosure tap target, Acknowledgments NavigationLink row).

---

## No Analog Found

| File | Role | Reason |
|------|------|--------|
| `Resources/Audio/{tap,win,loss}.caf` | Audio resource | First audio assets in repo. Author per CONTEXT Specifics (16-bit 44.1kHz mono CAF, ~30-50KB each, `afconvert` from royalty-free WAV). Folder auto-registers via Xcode 16 PBXFileSystemSynchronizedRootGroup per CLAUDE.md §8.8. |
| `Resources/Haptics/{win,loss}.ahap` | Haptic JSON resource | First AHAP assets in repo. Hand-author per CONTEXT Specifics + RESEARCH alternative (external AHAP JSON over inline Swift API). `win.ahap` = 3 transient events at t=0/200/400ms, Intensity=0.7, Sharpness=0.5. `loss.ahap` = continuous event 0–500ms with decay 1.0→0.2 + transients @ 100ms (I=0.9 S=0.9) + 250ms (I=0.7 S=0.8). |
| `Screens/AcknowledgmentsView.swift` (if planner extracts as separate file) | View (static text destination) | No prior static-text destination view. If Plan keeps it as a file-private nested struct in `SettingsView.swift`, no new file is needed. Planner discretion — if file is created, follow Pattern C (theme env-read) + UI-SPEC §Typography line 66 (`theme.typography.caption` + `theme.colors.textSecondary`). |

---

## Metadata

**Analog search scope:**
- `gamekit/gamekit/Games/Minesweeper/` (12 Swift files)
- `gamekit/gamekit/Core/` (10 Swift files)
- `gamekit/gamekit/Screens/` (7 Swift files)
- `gamekit/gamekit/App/` (1 Swift file)
- `gamekit/gamekitTests/` (10 Swift files)
- `../DesignKit/Sources/DesignKit/` (Components, Theme, Motion, Layout — for token + component reference)

**Files scanned:** 35 production files + 10 test files + 6 DesignKit reference files = 51

**Pattern extraction date:** 2026-04-26

---

## Pattern → Plan Mapping Hint (for the planner)

The 5 NEW source files cluster naturally into three implementation waves per RESEARCH "Primary recommendation" (line 138):

1. **Wave A — Foundations (gateable independently):**
   - `MinesweeperPhase.swift` — pattern from `MinesweeperGameState.swift`
   - `Core/SettingsStore.swift` extension — additive flags pattern from itself (lines 43-57)
   - 4 test files — pattern from `MinesweeperViewModelTests.swift` + `GameStatsTests.swift`

2. **Wave B — Services + Settings rebuild:**
   - `Core/Haptics.swift` — Pattern A (Core service) + Pattern B (logger)
   - `Core/SFXPlayer.swift` — Pattern A (`@MainActor` + EnvironmentKey from `SettingsStore`)
   - `Screens/SettingsView.swift` rebuild — analog is itself (preserve P4 DATA verbatim, replace stubs)
   - `Screens/FullThemePickerView.swift` — analog is `StatsView` (NavigationStack + DKCard wrapper)
   - `Screens/IntroFlowView.swift` — analog is `RootTabView` (TabView shape)
   - `Screens/RootTabView.swift` edit — `.fullScreenCover` driver
   - `App/GameKitApp.swift` edit — inject SFXPlayer

3. **Wave C — Mines animation pass:**
   - `MinesweeperViewModel.swift` edit — publish `phase`, atomic transitions piggybacking on existing terminal-state branches
   - `MinesweeperBoardView.swift` edit — per-cell `.transition` cascade
   - `MinesweeperCellView.swift` edit — `.sensoryFeedback` + `.symbolEffect(.bounce)`
   - `MinesweeperGameView.swift` edit — `.phaseAnimator` win sweep + `.keyframeAnimator` loss shake + `.onChange(of: vm.phase)` orchestrator
   - `Resources/Audio/*.caf` + `Resources/Haptics/*.ahap` (gated by Wave B services existing)

The analog map above gives every file in every wave a concrete code excerpt to copy from.
