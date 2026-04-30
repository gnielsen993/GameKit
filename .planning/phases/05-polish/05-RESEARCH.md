# Phase 5: Polish - Research

**Researched:** 2026-04-26
**Domain:** SwiftUI iOS 17 animation pass (`.phaseAnimator` / `.keyframeAnimator` / `.sensoryFeedback` / `.symbolEffect`), CoreHaptics AHAP playback, AVAudioPlayer SFX preload on `AVAudioSession.ambient`, full a11y (Dynamic Type AX5, Reduce Motion, VoiceOver), 6-preset theme matrix, `ThemeManager.overrides` custom-palette pipeline, 3-step `.fullScreenCover` intro with `TabView(.page)`, `SignInWithAppleButton` UI-only.
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Animation timing + shapes (MINES-08 + SC1)**
- **D-01:** Reveal cascade — engine-order stagger, 250ms total cap. Per-cell delay = `min(8ms × index, 250ms / count)`. Per-cell `.transition(.opacity.animation(.easeOut(duration: theme.motion.fast)))`.
- **D-02:** Win sweep — full-board success-tint wash via `.phaseAnimator`. Overlay opacity 0 → 0.25 → 0 over `theme.motion.slow`.
- **D-03:** Loss shake — 3-bump horizontal `.keyframeAnimator`. Magnitude 8pt; +8 @ 100ms → −8 @ 200ms → +4 @ 300ms → 0 @ 400ms.
- **D-04:** Reduce Motion dampening (A11Y-03 + SC1) — every animation block reads `@Environment(\.accessibilityReduceMotion)` and falls back to instant rendering. Cascade simultaneous; win wash instant peak; loss shake static; flag spring instant.
- **D-05:** Animation is view-layer concern — VM publishes `phase: MinesweeperPhase`, view drives modifiers. VM owns no `Animation` types, no `withAnimation` calls.
- **D-06:** `MinesweeperPhase` enum: `.idle / .revealing(cells: [Index]) / .flagging(idx) / .winSweep / .lossShake(mineIdx)`.

**Haptics + SFX behavior (MINES-09 + MINES-10 + SC2)**
- **D-07:** 4 haptic events — Flag = `.sensoryFeedback(.impact(weight: .light), trigger: vm.flagToggleCount)`; Reveal = `.sensoryFeedback(.selection, trigger: vm.revealCount)`; Win = AHAP file (3 ascending intensity-0.7 transients over 0.6s); Loss = AHAP file (0.5s continuous-decay + 2 sharp transients @ 100/250ms).
- **D-08:** 3 SFX files — `tap.caf` (~30KB), `win.caf` (~50KB), `loss.caf` (~40KB). All preloaded via `AVAudioPlayer.prepareToPlay()` in `SFXPlayer.init()`.
- **D-09:** `AVAudioSession.ambient` so SFX never duck user music.
- **D-10:** Default toggle states — `hapticsEnabled: Bool = true`, `sfxEnabled: Bool = false`. Both gated at the source — no view-layer plumbing of the toggle.
- **D-11:** `Core/Haptics.swift` = `@MainActor enum Haptics`. Single shared `CHHapticEngine` lazy-loaded on first `playAHAP(named:)`. Failure logs via `os.Logger(subsystem:category:"haptics")` and silently no-ops. `engineResetHandler` callback re-loads engine.
- **D-12:** `Core/SFXPlayer.swift` = `@MainActor final class SFXPlayer`. Constructed at `GameKitApp.init()` after `SettingsStore`. Holds 3 `AVAudioPlayer` instances as let-stored properties. Method shape: `play(_ event: SFXEvent)` where `enum SFXEvent { case tap, win, loss }`. Injected via custom `EnvironmentKey` (mirrors P4 SettingsStore D-29 pattern).

**Settings spine (SHELL-02 + SC3)**
- **D-13:** Section order: APPEARANCE → AUDIO → DATA → ABOUT.
- **D-14:** APPEARANCE = 5 Classic preset swatches inline via `DKThemePicker(catalog: .core, maxGridHeight: nil)` + "More themes & custom colors" `NavigationLink` to `FullThemePickerView`.
- **D-15:** AUDIO = 2 toggle rows ("Haptics" → `settingsStore.hapticsEnabled`; "Sound effects" → `settingsStore.sfxEnabled`).
- **D-16:** DATA = unchanged from P4.
- **D-17:** ABOUT = Version row (`Bundle.main.releaseVersionNumber` + build); Privacy (brief inline copy); Acknowledgments (NavigationLink to static text screen).

**3-step intro (SHELL-04 + SC3)**
- **D-18:** Container = `.fullScreenCover` with `TabView(.page)`. Page indicator at bottom (`.page(indexDisplayMode: .always)`) with `.tint(theme.colors.accentPrimary)`.
- **D-19:** Step 1 = "Make it yours" (themes preview, 5 Classic swatches read-only).
- **D-20:** Step 2 = "Track your progress" (static StatsView mock with hand-coded sample stats).
- **D-21:** Step 3 = "Sync across devices" (sign-in card with SIWA button + Skip below). SIWA does NOTHING in P5 — comment-documents `// P6 wires actual SIWA via PERSIST-04`.
- **D-22:** Skip top-trailing on every step. Continue (steps 1+2) and Done (step 3) bottom-trailing. Both write `hasSeenIntro = true`.
- **D-23:** `hasSeenIntro` storage = UserDefaults key `gamekit.hasSeenIntro` (default `false`).
- **D-24:** IntroFlowView a11y — every step's title + body is `.dynamicTypeSize(...AX5)` enabled; VoiceOver reads each page in full when focused; Skip/Continue/Done have explicit `accessibilityLabel`.

**THEME-03 custom-palette overrides (SC4)**
- **D-25:** Pipeline only — plumb `ThemeManager.overrides` through Mines grid + visual smoke. No new editor UI.
- **D-26:** Verification = manual smoke via `DKThemePicker` Custom tab; override `accentPrimary` to non-default; observe Mines Restart button + numbered cells + win/loss overlays + header timer color honoring override; screenshot before/after.

**A11Y-01 Dynamic Type carve-outs (SC5)**
- **D-27:** All non-grid text uses theme typography tokens. AX5 audit covers HomeView card labels, Settings rows, StatsView per-difficulty rows, Settings ABOUT, IntroFlowView all 3 steps, end-state DKCard, mine counter + timer in HeaderBar.
- **D-28:** Grid stays fixed-size (cell-adjacency digit at `cellSize × 0.55` is the documented exception, preserved from P3).

### Claude's Discretion
- **AHAP JSON exact shape** — locked via D-07 + Specifics; planner authors AHAP JSON literally per the spec.
- **CAF file authoring** — hand-recorded WAV → `afconvert` to CAF, OR royalty-free CC0 source. License documented in `Resources/Audio/LICENSE.md`.
- **`MinesweeperPhase` integration shape** — recommend additive `@Published var phase` separate from `gameState`; transitions wired atomically alongside existing `gameState` mutations.
- **Per-cell `.transition` wiring** — recommend `ForEach(...) { cell in MinesweeperCellView(...).transition(...) }` directly on the cell view rather than a wrapper; iOS 17 idiom.
- **Privacy row tap behavior** — UI-SPEC locked option (A) inline-disclosure (`@State isPrivacyExpanded`).
- **`SignInWithAppleButton` style** — Apple HIG mandates `.signInWithAppleButtonStyle(.black or .white)` based on `colorScheme`; do NOT override DesignKit tints.
- **SIWA button height** — UI-SPEC noted system rounds to ~50pt; accept system's choice (do NOT force 44pt).
- **Reduce Motion `.symbolEffect` handling** — system respects Reduce Motion automatically AND we gate explicitly per D-04 (defensive belt-and-suspenders).

### Deferred Ideas (OUT OF SCOPE)
- **Custom-palette editor UI inside Settings** — pipeline ships in P5; editor lands at P6 polish or drops permanently if `DKThemePicker`'s built-in custom-color UI is sufficient.
- **Richer SFX mapping** (flag.caf, reveal-numbered.caf, reveal-empty.caf differentiation) — defer unless user testing requests.
- **Haptic intensity slider** — single ON/OFF in P5; intensity slider is v2 polish.
- **Per-difficulty SFX profile** — defer.
- **Settings search bar** — small Settings, search not needed for v1.
- **About section rich content** (links to GitHub, full credits, dev blog) — minimal v1 (Version + Privacy + Acknowledgments).
- **Achievement system / win-streak overlay** — not in v1 ethos. Defer permanently.
- **Sign in with Apple wired** — P5 ships intro CARD + Skip path; SIWA button is functional UI but no-op until P6.
- **CloudKit sync ON-by-default** — stays OFF until P6.
- **Reduce Motion granular controls** ("dampen 50%" vs "off" vs "on") — single binary in P5.
- **Custom theme icon assets** — placeholder app icon stays through P5; real artwork at P7.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **MINES-08** | Polished animation pass — reveal cascade, flag spring, win-board sweep, loss-shake — all timed via `theme.motion.{fast,normal,slow}` | §Pattern 1 (`.phaseAnimator` win sweep) + §Pattern 2 (`.keyframeAnimator` loss shake) + §Pattern 3 (per-cell `.transition` cascade) + §Pattern 4 (`.symbolEffect(.bounce)` flag spring) + §Code Examples 1+2+3+4 |
| **MINES-09** | DesignKit haptics on flag, reveal, win, loss; respects Settings haptics toggle | §Pattern 5 (`.sensoryFeedback`) + §Pattern 6 (`CHHapticEngine` + AHAP file load) + §Code Examples 5+6 |
| **MINES-10** | Subtle SFX on tap / win / loss, off by default, toggle in Settings; uses `AVAudioSession.ambient` | §Pattern 7 (`AVAudioPlayer` preload + `.ambient` session) + §Code Examples 7 |
| **SHELL-02** | Settings screen with theme picker (5 Classic swatches inline + "More themes & custom colors" link), haptics toggle, SFX toggle, reset stats, about | §Pattern 8 (Settings spine sections) + §Code Examples 8 |
| **SHELL-04** | 3-step intro on first launch (themes → stats → optional sign-in card with Skip), dismissable, never shown again | §Pattern 9 (`.fullScreenCover` + `TabView(.page)`) + §Pattern 10 (`SignInWithAppleButton` no-op visual) + §Code Examples 9+10 |
| **THEME-01** | Minesweeper UI verified legible on at least one preset from each DesignKit category — Classic, Sweet, Bright, Soft, Moody, Loud — for both play state AND loss state | §Theme Matrix (UI-SPEC inheritance) + §Manual-Only Verifications (72 screenshots) |
| **THEME-03** | Custom-palette overrides via `ThemeManager.overrides` work end-to-end through the Mines grid | §Pattern 11 (`ThemeManager.overrides` plumb-through) + §Code Examples 11 |
| **A11Y-01** | Dynamic Type respected on all non-grid text | §Pattern 12 (Dynamic Type AX5 carve-outs) + §Manual Audit |
| **A11Y-02** | VoiceOver labels on cells (state + position + adjacency), buttons, and overlays — baked in at view creation, not retrofit | §Pattern 13 (`.accessibilityElement(children: .combine)` for IntroFlowView steps + preserved P3 cell pattern) |
| **A11Y-03** | Reduce-motion preference dampens the animation pass | §Pattern 14 (Reduce Motion contract per element) + §Code Examples 12 |
| **A11Y-04** | Default number palette is color-blind-safe by default — verified against Wong-palette principles | (P3 already shipped; P5 inherits — no new work) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Directive | Source | P5 Application |
|-----------|--------|-----------------|
| **Swift 6 + SwiftUI** | §1 Stack | All P5 code lands in this stack |
| **iOS 17+** | §1 | `.phaseAnimator`, `.keyframeAnimator`, `.sensoryFeedback`, `.symbolEffect`, `SignInWithAppleButton` SwiftUI native, `TabView(.page)` style with `.indexViewStyle` are all iOS 17 APIs |
| **No hard-coded colors / radii / spacing** | §1 + §2 | Every animation overlay reads `theme.colors.success`/`theme.motion.{fast,normal,slow}`/`theme.spacing.{token}`/`theme.radii.{card,button,chip,sheet}` |
| **Lightweight MVVM** | §1 | `MinesweeperPhase` is a presentation enum on the VM; views observe via `.onChange(of:)`. No new state-management library |
| **No popups, modals, or push-y UX on first run** | §1 | IntroFlowView is the ONLY first-run UX; SIWA button is no-op (no nag); Skip top-trailing on every step |
| **Cold-start latency is a P0 bug** | §1 | `Haptics.engine` lazy-loaded on first AHAP play; `SFXPlayer.init()` is constructed at app init AFTER first frame is rendered (per STACK §Cold Start budget tactic 5 — defer to `.task`) |
| **Implement Export/Import JSON** | §1 Data safety | (P4 already shipped; P5 inherits unchanged) |
| **Avoid bundle ID changes** | §1 + Pitfall 11 | Bundle ID `com.lauterstar.gamekit` preserved; container ID `iCloud.com.lauterstar.gamekit` preserved |
| **Tokens read via `theme.{spacing,colors,typography,radii,motion}`** | §2 | Every padding/duration/color read from theme; loss-shake 8pt magnitude is documented behavior constant (animation amplitude, not layout) |
| **Game engines are pure / testable** | §4 | `MinesweeperViewModel` stays Foundation-only; `MinesweeperPhase.swift` is Foundation-only (Equatable enum); `Core/Haptics.swift` imports CoreHaptics + os; `Core/SFXPlayer.swift` imports AVFoundation + os |
| **Tests in same commit as new pure services** | §5 | `MinesweeperPhaseTransitionTests.swift` + `Core/SettingsStoreFlagsTests.swift` + `Core/SFXPlayerTests.swift` + `Core/HapticsTests.swift` ship with their production files |
| **<400-line views; <500-line Swift files (hard cap)** | §8.1, §8.5 | IntroFlowView <300; FullThemePickerView <80; rebuilt SettingsView <400; SFXPlayer <150; Haptics <120 |
| **Reusable views are data-driven, not data-fetching** | §8.2 | `IntroStep1ThemesView` / `IntroStep2StatsView` / `IntroStep3SignInView` / `SettingsToggleRow` are file-private, props-only |
| **Every data-driven view ships with explicit empty state** | §8.3 | IntroStep2 uses HAND-CODED sample stats (Easy 12/8/67%/1:42, Medium 5/2/40%/4:15, Hard —/—/—/—) — explicitly does NOT show first-launch empty `@Query` state |
| **Theme tokens must exist before use** | §8.4 | All P5 tokens (`motion.fast/normal/slow`, `radii.card/button/chip/sheet`, `spacing.xs..xxl`, `gameNumber(_:)`) verified pre-existing in DesignKit |
| **`.foregroundStyle` not `.foregroundColor`** | §8.6 | All P5 view code uses `.foregroundStyle` |
| **No Finder-dupe `X 2.swift` files; no manual pbxproj edits** | §8.7, §8.8 | New `Resources/Audio/` and `Resources/Haptics/` folders auto-register via Xcode 16 PBXFileSystemSynchronizedRootGroup. New `Core/Haptics.swift`, `Core/SFXPlayer.swift`, `Screens/IntroFlowView.swift`, `Screens/FullThemePickerView.swift`, `Games/Minesweeper/MinesweeperPhase.swift` drop into existing folders |
| **Game-screen theme passes mandatory before "done"** | §8.12 | 6-preset audit set re-verified for play AND loss state per ROADMAP SC4 |
| **No `Color(...)` literals in `Games/` or `Screens/` (FOUND-07 hook)** | §1 | All P5 surfaces use `theme.colors.{...}` only; adversarial grep enforced post-implementation |

## Summary

P5 is the **largest UI surface in the milestone** and the phase that closes the "premium feel" promise. It ships the polished animation pass (`MinesweeperPhase` enum + `.phaseAnimator` + `.keyframeAnimator` + `.symbolEffect`), the haptic + SFX layer (`.sensoryFeedback` + AHAP files + preloaded `AVAudioPlayer` on `AVAudioSession.ambient`), full a11y (Dynamic Type AX5 audit, Reduce Motion gating, VoiceOver intro polish), the rebuilt Settings spine (APPEARANCE / AUDIO / DATA / ABOUT), the 3-step `.fullScreenCover` intro flow, and the `ThemeManager.overrides` custom-palette pipeline verification. THEME-01 closes here — the 6-preset (Classic/Sweet/Bright/Soft/Moody/Loud) legibility audit is mandatory for both play AND loss state.

**The hard parts are NOT the iOS 17 APIs themselves** (every modifier P5 uses is Apple-canonical and shipped on `theme.motion` tokens already on disk). **The hard parts are:**

1. **Reduce Motion contract per element (D-04)** — load-bearing for A11Y-03 + SC1 + SC5. Each animation block reads `@Environment(\.accessibilityReduceMotion)` independently and falls back instantly. Tested via `.environment(\.accessibilityReduceMotion, true)` PreviewProvider override + manual SC5 audit.
2. **`MinesweeperPhase` integration without breaking the P3 contract** — the enum is additive to the existing VM; `gameState` cases still drive logic, `phase` only drives view modifiers. P3 tests must continue to pass; P5 adds new tests for phase transitions.
3. **Haptic + SFX gating at the source (D-10)** — both `Haptics.playAHAP(...)` and `SFXPlayer.play(...)` early-return if their respective flag is false. NO view-layer plumbing of the toggle. This keeps Mines view code clean and forbids the toggle ever drifting between view and source.
4. **6-preset legibility audit (THEME-01 + SC4)** — 12 surfaces × 6 presets = **72 screenshots**, half play state and half loss state per ROADMAP SC4 verbatim. The litmus presets are Barbie (saturated hot-pink, page indicator inactive dot legibility risk) and Voltage (acid-yellow on violet-black, success-green vs accent-yellow proximity).
5. **THEME-03 pipeline verification (D-25/D-26)** — `ThemeManager.overrides` already exists in DesignKit (verified `[VERIFIED: ../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift:18-25]`). Plumbing reaches every Mines render path through the existing `Theme.resolve(preset:scheme:overrides:)` pipeline shipped in DesignKit. P5 verifies — does NOT extend.

Three subsystems land:

1. **Animation orchestration** (`Games/Minesweeper/MinesweeperPhase.swift` NEW + edits to VM/GameView/BoardView/CellView/EndStateCard) — 5-case enum, additive `@Published var phase`, `.phaseAnimator`/`.keyframeAnimator`/`.symbolEffect` driven via `.onChange(of: vm.phase)`.
2. **Haptic + SFX layer** (`Core/Haptics.swift` NEW + `Core/SFXPlayer.swift` NEW + 2 AHAP files + 3 CAF files) — gated at the source on `settingsStore.hapticsEnabled` / `settingsStore.sfxEnabled`. CoreHaptics for AHAP marquee moments; `.sensoryFeedback` for tap/flag.
3. **First-run + Settings spine** (`Screens/IntroFlowView.swift` NEW + `Screens/FullThemePickerView.swift` NEW + extended `SettingsView.swift` + extended `SettingsStore.swift` + extended `RootTabView.swift`) — `.fullScreenCover` first-launch flow; full Settings spine APPEARANCE/AUDIO/DATA/ABOUT.

**Primary recommendation:** Ship Wave 0 (4 test files + the `MinesweeperPhase` enum file) FIRST; then SettingsStore extension + Haptics/SFXPlayer; then IntroFlowView + FullThemePickerView; then the Mines animation pass; finally the 6-preset audit. The animation pass is last because it's the hardest to verify automatically — it gates on the manual audit, which gates on every other surface being settled.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `MinesweeperPhase` enum definition | **ViewModel-adjacent (Games/Minesweeper/)** | — | Pure Equatable Sendable enum; Foundation-only; published from VM but consumed by view |
| `MinesweeperPhase` transitions | **ViewModel (Games/Minesweeper/MinesweeperViewModel.swift)** | — | VM owns gameState transitions; phase transitions piggyback atomically on the same call sites (D-05) |
| Reveal cascade animation (per-cell `.transition`) | **View (Games/Minesweeper/MinesweeperBoardView.swift)** | ViewModel for the `revealing(cells:)` payload | View drives `.transition`; VM publishes the cell list ordered by engine D-06 contract |
| Win sweep `.phaseAnimator` overlay | **View (Games/Minesweeper/MinesweeperGameView.swift)** | — | Top-level view owns the board-overlay ZStack; `.phaseAnimator` is a SwiftUI modifier (view-tier) |
| Loss shake `.keyframeAnimator` offset | **View (Games/Minesweeper/MinesweeperGameView.swift)** | — | Same — `.keyframeAnimator` is view-tier; applied to `MinesweeperBoardView` outer container `.offset(x:)` |
| Flag spring `.symbolEffect(.bounce)` | **View (Games/Minesweeper/MinesweeperCellView.swift)** | ViewModel for `flagToggleCount` Int trigger | iOS 17 native symbol effect; tied to value-change trigger pattern |
| `.sensoryFeedback` immediate haptics | **View (Games/Minesweeper/MinesweeperCellView.swift)** | ViewModel for trigger value | `.sensoryFeedback` is a SwiftUI modifier; gated at the call site on `settingsStore.hapticsEnabled` per checker recommendation 1 |
| AHAP win/loss haptic playback | **Core/Haptics.swift** | View call site (`MinesweeperGameView.onChange`) | `Haptics.playAHAP(named:)` is the firewall; gated internally on `settingsStore.hapticsEnabled` |
| SFX tap/win/loss playback | **Core/SFXPlayer.swift** | View call site | Same — `SFXPlayer.play(_:)` is the firewall; gated internally on `settingsStore.sfxEnabled` |
| `AVAudioSession.ambient` configuration | **Core/SFXPlayer.swift init** | — | Set once per app lifecycle |
| Reduce Motion environment read | **View (every animated view)** | — | `@Environment(\.accessibilityReduceMotion)` is iOS 17 SwiftUI; each animation block reads independently per D-04 |
| `IntroFlowView` orchestration | **View (Screens/IntroFlowView.swift)** | SettingsStore for `hasSeenIntro` write | `.fullScreenCover` content; owns `@State currentStep` + composes 3 file-private step views |
| `hasSeenIntro` storage | **Core/SettingsStore.swift** | RootTabView for `.fullScreenCover(isPresented:)` driver | UserDefaults flag (P4 D-29 pattern); read once at RootTabView appear |
| Settings spine (APPEARANCE/AUDIO/DATA/ABOUT) | **View (Screens/SettingsView.swift)** | SettingsStore for toggle bindings | All view-tier; toggle bindings flow through `@Environment(\.settingsStore)` |
| `FullThemePickerView` destination | **View (Screens/FullThemePickerView.swift)** | DesignKit `ThemeManager.overrides` for custom-palette writes | Wraps `DKThemePicker(catalog: .all)` |
| `ThemeManager.overrides` plumb-through | (DesignKit already ships; P5 verifies) | Mines grid render path consumes via `theme.colors.gameNumber(_:)` already-shipped pipeline | THEME-03 verification = manual smoke (D-26) |
| `SignInWithAppleButton` UI | **View (Screens/IntroFlowView.swift, IntroStep3SignInView)** | — | `import AuthenticationServices`; iOS 17 SwiftUI native; no-op closures in P5 |
| `os.Logger` non-fatal failure logging | **Haptics / SFXPlayer / IntroFlowView SIWA tap** | — | Subsystem `com.lauterstar.gamekit`, categories `haptics` / `audio` / `auth` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (bundled) | `.phaseAnimator`, `.keyframeAnimator`, `.sensoryFeedback`, `.symbolEffect`, `TabView(.page)`, `.indexViewStyle`, `.fullScreenCover`, `.dynamicTypeSize`, `@Environment(\.accessibilityReduceMotion)` | `[CITED: developer.apple.com/documentation/swiftui]` — every modifier shipped iOS 17.0; no version gating needed against the project's iOS 17.0 deployment target |
| AuthenticationServices | iOS 17+ (bundled) | `SignInWithAppleButton(.signIn / .continue, onRequest:onCompletion:)`, `.signInWithAppleButtonStyle(.black/.white)` | `[CITED: developer.apple.com/documentation/authenticationservices/signinwithapplebutton]` — first-party SwiftUI control; iOS 14+ |
| CoreHaptics | iOS 13+ (bundled) | `CHHapticEngine`, `CHHapticPattern(contentsOf:)`, AHAP file format | `[CITED: developer.apple.com/documentation/corehaptics]` — Apple-canonical for custom haptic patterns; AHAP JSON shipped as bundle resource |
| AVFoundation | iOS 17+ (bundled) | `AVAudioPlayer(contentsOf:)`, `prepareToPlay()`, `AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)` | `[CITED: developer.apple.com/documentation/avfaudio]` — Apple-canonical for short SFX cues; `.ambient` category does not duck user music |
| Foundation | bundled | `Bundle.main.url(forResource:withExtension:)`, `Bundle.main.infoDictionary["CFBundleShortVersionString"]`, `os.Logger` | `[VERIFIED: codebase already imports across P1-P4]` |
| Observation | Swift 5.9+ stdlib | `@Observable` macro for `SettingsStore` (extended with 3 new flags) | `[VERIFIED: P4 SettingsStore already on @Observable]` — no `import Observation` needed |
| Swift Testing | bundled with Xcode 16+ | `@Test` / `#expect` / `@Suite` for the 4 new test files | `[VERIFIED: P2-P4 conventions]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `os.Logger` | iOS 14+ | Non-fatal failure logging — AHAP load failure, AVAudioPlayer init failure, SIWA tap (P5 no-op breadcrumb) | Inside `Haptics.playAHAP(...)` catch blocks; `SFXPlayer.init` catch blocks; IntroStep3SignInView SIWA tap closure. Subsystem `com.lauterstar.gamekit`, categories `haptics` / `audio` / `auth` |
| `UserDefaults.standard` | bundled | `SettingsStore` backing store for 3 new flags | Existing P4 pattern; key conventions `gamekit.hapticsEnabled` / `gamekit.sfxEnabled` / `gamekit.hasSeenIntro` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.sensoryFeedback(.impact(weight: .light), trigger:)` | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | `[CITED: useyourloaf.com/blog/swiftui-sensory-feedback]` — `.sensoryFeedback` is iOS 17+ declarative SwiftUI modifier; trigger-driven; no `.prepare()` lifecycle to manage. `UIImpactFeedbackGenerator` requires manual `.prepare()` to dodge first-fire latency, plus is imperative. **Reject `UIImpactFeedbackGenerator` for new code.** |
| `Animation.timingCurve(...)` for loss shake | `.keyframeAnimator(initialValue:0)` with 4 keyframe steps | `Animation.timingCurve` interpolates between 2 endpoints with a Bezier. Loss shake needs 4 distinct keyframes (+8 → −8 → +4 → 0), which `.keyframeAnimator` is purpose-built for. **Reject `timingCurve`.** |
| Manual `Timer` keyframes for the cascade stagger | Per-cell `.transition` with computed delay | Manual `Timer.scheduledTimer { ... }` to fire `withAnimation` for each cell would be deeply imperative and fight SwiftUI's diffing. The `.transition(.opacity.animation(.easeOut.delay(perCellDelay)))` idiom is one-line declarative and lets the cascade pop on first reveal of each cell. **Reject manual Timer.** |
| `withAnimation(_:_:completion:)` for win-sweep alpha | `.phaseAnimator([0.0, 0.25, 0.0], trigger: vm.phase == .winSweep)` | Both work for the alpha keyframe. `.phaseAnimator` is iOS 17 declarative — feeds the phase value into a `content.opacity(phase)` closure; `withAnimation` is imperative and harder to express the 3-keyframe shape. **Recommend `.phaseAnimator`.** |
| `.transaction { ... }` to control animation envelope | `.onChange(of: vm.phase) { withAnimation(.spring(...)) { ... } }` | `.transaction` is finer-grained but harder to read; `withAnimation` inside `.onChange` is sufficient for the win-sweep + loss-shake call sites. **Recommend `withAnimation`.** Note: P5 does NOT use `withAnimation` for the cascade per-cell stagger (that's `.transition`-based); only for terminal-state phase transitions if explicit envelope is needed. |
| `AVAudioSession.soloAmbient` | `AVAudioSession.ambient` | `.soloAmbient` would silence user music while SFX play. Per ROADMAP SC2 verbatim and CLAUDE.md §1 "calm" posture, the user's Spotify/Apple Music must keep playing. **`.ambient` is non-negotiable per D-09.** |
| `.wav` or `.m4a` audio files | `.caf` | CONTEXT D-08 + CONTEXT Specifics locked `.caf` (Core Audio Format, 16-bit 44.1kHz mono, ~50KB each, `afconvert` from any WAV source). CAF is Apple-native, decodes with zero overhead, smallest disk footprint at quality. **`.caf` is locked.** |
| `SystemSoundID` (`AudioServicesPlaySystemSound`) | `AVAudioPlayer` | `[CITED: STACK.md §6]` — SystemSoundID inherits ringer state (silent if user has ringer off); no volume control. A "subtle SFX" that goes silent because of ringer-off is broken. **Reject SystemSoundID.** |
| `AVAudioEngine` mixer | Single `AVAudioPlayer` per cue | AVAudioEngine is for overlapping/mixed audio (3+ concurrent tracks). P5 has 3 non-overlapping cues. Single `AVAudioPlayer` per cue is the simplest correct choice. **Reject `AVAudioEngine`.** |
| Inline AHAP JSON via `CHHapticPattern(events:parameters:)` Swift API | External `.ahap` JSON files via `CHHapticPattern(contentsOf:)` | Both are valid. External AHAP JSON files are tweakable by ear without recompile, version-controllable as text, and Apple's own [Pattern Generator](https://developer.apple.com/documentation/corehaptics/representing-haptic-patterns-in-ahap-files) docs reference this format. **Recommend external AHAP files** per CONTEXT D-07 + Specifics. |
| `NavigationLink` push for the intro flow | `.fullScreenCover` with `TabView(.page)` | `.fullScreenCover` is the iOS-canonical first-run UX (no NavigationStack chrome, no swipe-back to dismiss). `TabView(.page)` swipeable + page indicator. **`.fullScreenCover` + `TabView(.page)` is locked per D-18.** |
| Standalone `IntroStepXView.swift` files | File-private structs inside `IntroFlowView.swift` | UI-SPEC §Component Inventory line "promote to a sibling file only if `IntroFlowView.swift` approaches 400 lines." Three single-use views are below CLAUDE.md §4 promotion threshold. **Recommend file-private** per UI-SPEC. |

**Installation:**

```swift
// All system frameworks — no new SPM dependencies needed
import SwiftUI
import AuthenticationServices       // SignInWithAppleButton
import CoreHaptics                  // CHHapticEngine + AHAP file load
import AVFoundation                 // AVAudioPlayer + AVAudioSession
import os                           // Logger
// (Foundation auto-imported)
```

**Capabilities required (Signing & Capabilities → +Capability):**
- **Sign in with Apple** — required for `SignInWithAppleButton` to render and respond to taps. Even though P5 ships SIWA as no-op (the `onCompletion` closure does nothing), the **capability MUST be present** in the entitlements file or the button still renders but firing the SIWA flow at P6 will throw `ASAuthorizationErrorUnknown`. Add now to fail fast in P6 if the entitlement drifts.

**Version verification:** All APIs cited (`.phaseAnimator`, `.keyframeAnimator`, `.sensoryFeedback`, `.symbolEffect`, `SignInWithAppleButton`, `CHHapticEngine`, `AVAudioPlayer`, `AVAudioSession.ambient`) are iOS 17+ system frameworks bundled with the OS. No SPM resolution needed; verified against Apple developer documentation `[CITED: developer.apple.com]` and existing codebase (project iOS 17.0 deployment target per FOUND-04).

## Architecture Patterns

### System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│              App / GameKitApp.swift  (entry point)                     │
│   @main · @StateObject ThemeManager · @State SettingsStore             │
│   @State SFXPlayer                                                     │
│   constructs sharedContainer (P4 unchanged)                            │
│   .modelContainer + .environment(\.settingsStore) + .environment(      │
│      \.sfxPlayer) on RootTabView                                       │
└──────────────┬─────────────────────────────────────────────────────────┘
               │ environment injection
               ▼
   ┌─────────────────────────────────────────────────────────┐
   │   Screens/RootTabView.swift                             │
   │     @State isIntroPresented = !settingsStore.hasSeenIntro│
   │     .fullScreenCover(isPresented:) {                    │
   │       IntroFlowView(onDismiss: { setHasSeenIntro=true })│
   │     }                                                   │
   │     TabView(...) { Home / Stats / Settings }            │
   └──┬──────────────┬─────────────┬────────────────────────┬┘
      │              │             │                        │
      ▼              ▼             ▼                        ▼
 ┌──────────┐ ┌──────────────┐ ┌────────────┐ ┌─────────────────────────┐
 │ HomeView │ │ MinesGameView│ │ StatsView  │ │ SettingsView            │
 │ (P1)     │ │ (extended P5)│ │ (P4)       │ │ (rebuilt P5)            │
 │          │ │              │ │            │ │                         │
 │          │ │ @Env modelCtx│ │ @Query × 2 │ │ APPEARANCE              │
 │          │ │ @Env sfxPlayer│ │            │ │  DKThemePicker(.core)   │
 │          │ │ @Env settings│ │            │ │  NavLink → FullPicker   │
 │          │ │              │ │            │ │ AUDIO                   │
 │          │ │ MinesweeperVM│ │            │ │  Toggle Haptics         │
 │          │ │  + phase     │ │            │ │  Toggle SFX             │
 │          │ │              │ │            │ │ DATA (P4 verbatim)      │
 │          │ │ .onChange(of:│ │            │ │  Export/Import/Reset    │
 │          │ │  vm.phase)→ │ │            │ │ ABOUT                   │
 │          │ │  .winSweep:  │ │            │ │  Version (mono)         │
 │          │ │   Haptics    │ │            │ │  Privacy (inline disc.) │
 │          │ │   .playAHAP  │ │            │ │  NavLink Acknowledg.    │
 │          │ │   SFX.play   │ │            │ └────┬────────────────────┘
 │          │ │  .lossShake: │ │            │      │
 │          │ │   same       │ │            │      ▼
 │          │ │              │ │            │ ┌──────────────────────────┐
 │          │ │ .phaseAnim   │ │            │ │ FullThemePickerView      │
 │          │ │  win wash    │ │            │ │  (NEW)                   │
 │          │ │ .keyframeAnim│ │            │ │  DKThemePicker(.all)     │
 │          │ │  loss shake  │ │            │ │  including custom panel  │
 │          │ │              │ │            │ │  → ThemeManager.overrides│
 └──────────┘ └──────┬───────┘ └────────────┘ └──────────────────────────┘
                    │
                    │ MinesweeperBoardView per-cell
                    ▼
           ┌─────────────────────────────────────────┐
           │ MinesweeperCellView (extended P5)        │
           │   .sensoryFeedback(.selection, trigger:  │
           │     hapticsEnabled ? vm.revealCount : 0) │
           │   .sensoryFeedback(.impact(.light),      │
           │     trigger: hapticsEnabled ?            │
           │       vm.flagToggleCount : 0)            │
           │   .symbolEffect(.bounce,                 │
           │     value: reduceMotion ? 0 :            │
           │       vm.flagToggleCount)                │
           │   .transition(.opacity.animation(        │
           │     .easeOut(duration: theme.motion.fast)│
           │     .delay(perCellDelay)))               │
           │   per-cell delay = min(0.008 × idx,      │
           │     theme.motion.normal / count)         │
           └─────────────────────────────────────────┘

         ┌──────────────────────────────────────────────────┐
         │  Core/Haptics.swift (NEW)                        │
         │   @MainActor enum Haptics                        │
         │   private static var engine: CHHapticEngine?     │
         │     (lazy on first playAHAP call)                │
         │   static func playAHAP(named: String) {          │
         │     guard settingsStore.hapticsEnabled else {... }│
         │     // load engine, load CHHapticPattern,         │
         │     // makePlayer, start                          │
         │     // failure → os.Logger silent no-op           │
         │   }                                               │
         │   reads from Bundle.main.url(forResource: name,   │
         │     withExtension: "ahap")                        │
         └──────────────────────────────────────────────────┘

         ┌──────────────────────────────────────────────────┐
         │  Core/SFXPlayer.swift (NEW)                      │
         │   @MainActor final class SFXPlayer               │
         │   let tapPlayer/winPlayer/lossPlayer:             │
         │     AVAudioPlayer    (preloaded in init)         │
         │   init() {                                       │
         │     try AVAudioSession.shared.setCategory(.ambient,│
         │       mode: .default)                            │
         │     load 3 .caf, prepareToPlay each              │
         │   }                                              │
         │   func play(_ event: SFXEvent) {                 │
         │     guard settingsStore.sfxEnabled else { return }│
         │     switch event { /* play correct player */ }   │
         │   }                                              │
         │   enum SFXEvent { case tap, win, loss }          │
         └──────────────────────────────────────────────────┘

         ┌──────────────────────────────────────────────────┐
         │  Core/SettingsStore.swift (extended)             │
         │    cloudSyncEnabled (P4)                         │
         │    hapticsEnabled: Bool = true   (NEW)           │
         │    sfxEnabled: Bool = false      (NEW)           │
         │    hasSeenIntro: Bool = false    (NEW)           │
         │    didSet → UserDefaults write                   │
         └──────────────────────────────────────────────────┘

         ┌──────────────────────────────────────────────────┐
         │  Resources/Audio/ (NEW folder)                   │
         │    tap.caf  (~30KB)                              │
         │    win.caf  (~50KB)                              │
         │    loss.caf (~40KB)                              │
         │  Resources/Haptics/ (NEW folder)                 │
         │    win.ahap  (3 transients ascending)            │
         │    loss.ahap (continuous decay + 2 transients)   │
         └──────────────────────────────────────────────────┘
```

**Trace the primary use case (MINES-08 — user wins, full polish pass):**

1. User reveals last non-mine cell → `MinesweeperViewModel.reveal(at:)` runs.
2. `RevealEngine` returns updated board; `WinDetector.isWon(board) == true`.
3. VM atomically transitions: `gameState = .won`, `phase = .winSweep`, `freezeTimer()`, `recordTerminalState(outcome: .win)` (P4 unchanged).
4. `MinesweeperCellView.transition(.opacity.animation(.easeOut.delay(perCellDelay)))` triggers per-cell as `phase = .revealing(cells: ...)` flips to `.winSweep` — but per-cell `.transition` only fires on cell-state changes, NOT on phase change. The cascade for the final reveal already ran during `.revealing(cells: ...)`.
5. `.onChange(of: vm.phase) { _, new in ... }` in `MinesweeperGameView` fires:
   - `if new == .winSweep`: `Haptics.playAHAP(named: "win")` (gated on `hapticsEnabled`); `sfxPlayer.play(.win)` (gated on `sfxEnabled`).
6. `.phaseAnimator([0.0, 0.25, 0.0], trigger: vm.phase == .winSweep)` on the MinesweeperGameView win-wash overlay drives `theme.colors.success.opacity(animatedAlpha)` 0 → 0.25 → 0 over `theme.motion.slow`.
7. End-state DKCard fades in concurrently per P3 contract (preserved).
8. If `accessibilityReduceMotion == true`: phaseAnimator emits `[0.0]` only (no fade); win-wash overlay shows the peak alpha 0.25 instantly then disappears next render; the haptic + SFX still fire (Reduce Motion is visual, not tactile/audio).

### Recommended Project Structure

```
gamekit/gamekit/
├── App/
│   └── GameKitApp.swift              ← edited: construct SFXPlayer; inject .environment(\.sfxPlayer)
├── Core/
│   ├── (P4 files unchanged)
│   ├── Haptics.swift                  ← NEW: @MainActor enum; CHHapticEngine wrapper
│   ├── SFXPlayer.swift                ← NEW: @MainActor final class; AVAudioPlayer preload
│   └── SettingsStore.swift            ← edited: add 3 flags
├── Games/Minesweeper/
│   ├── MinesweeperPhase.swift         ← NEW: enum (Foundation-only, Equatable, Sendable)
│   ├── MinesweeperViewModel.swift     ← edited: add @Published var phase + transition wiring
│   ├── MinesweeperGameView.swift      ← edited: .phaseAnimator + .keyframeAnimator + .onChange(vm.phase)
│   ├── MinesweeperBoardView.swift     ← edited: per-cell .transition with stagger delay math
│   ├── MinesweeperCellView.swift      ← edited: .sensoryFeedback × 2 + .symbolEffect(.bounce)
│   └── MinesweeperEndStateCard.swift  ← edited (minor): preserved P3 fade-in; concurrency with win sweep
├── Screens/
│   ├── IntroFlowView.swift            ← NEW: .fullScreenCover + TabView(.page) + 3 file-private steps
│   ├── FullThemePickerView.swift      ← NEW: NavigationLink destination wrapping DKThemePicker(.all)
│   ├── SettingsView.swift             ← edited: rebuild APPEARANCE/AUDIO/ABOUT; preserve DATA verbatim
│   └── RootTabView.swift              ← edited: present IntroFlowView via .fullScreenCover
└── Resources/
    ├── Audio/                         ← NEW folder (auto-registers per CLAUDE.md §8.8)
    │   ├── tap.caf                    ← ~30KB
    │   ├── win.caf                    ← ~50KB
    │   ├── loss.caf                   ← ~40KB
    │   └── LICENSE.md                 ← provenance per UI-SPEC §Registry Safety
    ├── Haptics/                       ← NEW folder
    │   ├── win.ahap
    │   └── loss.ahap
    └── Localizable.xcstrings           ← edited: P5 strings auto-extracted

gamekit/gamekitTests/
├── Games/Minesweeper/
│   └── MinesweeperPhaseTransitionTests.swift  ← NEW (~6 tests)
└── Core/
    ├── SettingsStoreFlagsTests.swift          ← NEW (~5 tests)
    ├── SFXPlayerTests.swift                   ← NEW (~3 tests; AVAudioPlayer mock optional)
    └── HapticsTests.swift                     ← NEW (~3 tests; AHAP file presence + bundle URL)
```

</content>
</invoke>
### Pattern 1: `.phaseAnimator` for Win Sweep Overlay (MINES-08 + D-02)

**What:** `.phaseAnimator(_:trigger:)` is iOS 17's declarative API for stepping through a discrete sequence of animation phases. P5 uses it to drive the win-wash overlay opacity 0 → 0.25 → 0 over `theme.motion.slow` (0.40s).

**When to use:** Multi-keyframe sequences where each phase is reached deterministically once, triggered by a state change. Win sweep matches: enter `.winSweep` → animate alpha 0 → 0.25 → 0 → done.

**Trade-offs:**
- ✅ Declarative; reads as `phaseAnimator([phases], trigger: bool) { content, phase in content.opacity(phase) }`.
- ✅ Built-in spring timing between phases (smooth not linear).
- ✅ Reduce Motion override is one-line: `phaseAnimator(reduceMotion ? [0.0] : [0.0, 0.25, 0.0], ...)`.
- ⚠️ Trigger value must be `Equatable`. Using `vm.phase == .winSweep` (Bool) is the cleanest trigger.

**Example:**

```swift
// Source: D-02 + UI-SPEC §Motion + [CITED: developer.apple.com/documentation/swiftui/view/phaseanimator]
import SwiftUI
import DesignKit

struct MinesweeperGameView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: MinesweeperViewModel
    // ...

    var body: some View {
        ZStack {
            // ... existing content ...
        }
        .overlay(winWashOverlay)
    }

    @ViewBuilder
    private var winWashOverlay: some View {
        // Phases drive opacity 0 → 0.25 → 0 over theme.motion.slow.
        // Reduce Motion: single phase [0.0] = no animation; static rendering.
        let phases: [Double] = reduceMotion ? [0.0] : [0.0, 0.25, 0.0]
        Rectangle()
            .fill(theme.colors.success)
            .ignoresSafeArea()
            .allowsHitTesting(false)               // user can interact with end-state DKCard above
            .phaseAnimator(
                phases,
                trigger: viewModel.phase == .winSweep
            ) { content, alpha in
                content.opacity(alpha)
            } animation: { _ in
                .easeInOut(duration: theme.motion.slow)
            }
    }
}
```

**Notes:**
- The `animation:` trailing closure is the curve between phases. `.easeInOut(duration: theme.motion.slow)` matches D-02's "fade in + fade out" feel.
- z-order per UI-SPEC: above the board cells, BELOW the end-state DKCard. The `.overlay()` placement matters — apply BEFORE the `if let outcome = viewModel.terminalOutcome { endStateOverlay(...) }` ZStack arm so the DKCard renders on top.

### Pattern 2: `.keyframeAnimator` for Loss Shake (MINES-08 + D-03)

**What:** `.keyframeAnimator(initialValue:trigger:)` is iOS 17's declarative API for precise multi-keyframe animation. P5 uses it for the 3-bump loss shake: 0 → +8 → −8 → +4 → 0 over 400ms.

**When to use:** When `.spring` can't express the exact keyframe shape and `.phaseAnimator`'s spring-between-phases is wrong feel. Shake is impulsive — linear interpolation between bumps reads correctly; springs would soften the bounce off-feel.

**Trade-offs:**
- ✅ Exact keyframe control via `LinearKeyframe(value, duration:)` (or `SpringKeyframe`, `CubicKeyframe`).
- ✅ Trigger-driven; reset back to `initialValue` between triggers.
- ⚠️ Reduce Motion handling: pass `nil` trigger to disable, OR gate the offset modifier with `reduceMotion ? 0 : shakeOffset`.

**Example:**

```swift
// Source: D-03 + [CITED: developer.apple.com/documentation/swiftui/view/keyframeanimator]
import SwiftUI

extension MinesweeperGameView {
    @ViewBuilder
    private func boardWithShake(content: some View) -> some View {
        // Reduce Motion: pass nil-equivalent trigger so keyframes don't fire.
        // Use a separate Bool that flips on phase == .lossShake; reset to false elsewhere.
        let shouldShake = viewModel.phase.isLossShake && !reduceMotion
        content
            .keyframeAnimator(
                initialValue: 0.0,
                trigger: shouldShake
            ) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                LinearKeyframe(0.0, duration: 0.0)        // start at 0
                LinearKeyframe(8.0, duration: 0.1)        // +8 @ 100ms
                LinearKeyframe(-8.0, duration: 0.1)       // −8 @ 200ms
                LinearKeyframe(4.0, duration: 0.1)        // +4 @ 300ms
                LinearKeyframe(0.0, duration: 0.1)        // 0 @ 400ms
            }
    }
}

extension MinesweeperPhase {
    var isLossShake: Bool {
        if case .lossShake = self { return true }
        return false
    }
}
```

**Notes:**
- `LinearKeyframe(value, duration:)` is the simplest; the `duration:` is the time to reach this value from the previous one. So 5 keyframes at 0.1s each = 0.5s total — but D-03 specifies 0.4s, so use 4 transition steps after the initial `LinearKeyframe(0.0, duration: 0.0)` for a total of 0.4s. The first `LinearKeyframe(0.0, duration: 0.0)` is a "reset" anchor; total animation duration = sum of subsequent durations.
- Apply to the `MinesweeperBoardView` outer `.offset(x:)` per UI-SPEC §Layout — the shake shifts the whole board, not just cells.

### Pattern 3: Per-Cell `.transition` with Engine-Order Stagger (MINES-08 + D-01)

**What:** Each `MinesweeperCellView` declares `.transition(.opacity.animation(.easeOut(duration: theme.motion.fast).delay(perCellDelay)))`. The cascade is animated via SwiftUI's natural transition system — when a cell first appears in revealed state, its opacity transition fires with a per-cell-computed delay.

**When to use:** Whenever a list/grid of items reveals in order with a stagger. P5 uses this for the flood-fill cascade per engine D-06 contract.

**Trade-offs:**
- ✅ Declarative; SwiftUI handles the timer scheduling.
- ✅ Reduce Motion fallback: `.transition(reduceMotion ? .identity : .opacity.animation(...))` — instant render.
- ✅ No imperative `Timer.scheduledTimer` or `Task.sleep` needed.
- ⚠️ Per-cell delay computation uses the cell's index in the engine's `revealed: [Index]` list (P2 D-06 contract). The board view must observe `vm.phase = .revealing(cells:)` and compute per-cell delay from the cell's position in that list.

**Math (D-01):** `delay = min(0.008 × index, theme.motion.normal / count)`.

Per checker recommendation 3, use `theme.motion.normal` (0.28s) over the literal 250ms to honor the token system. The cap math: on Hard flood-fill of 100+ cells, `0.008 × 100 = 0.8s` would exceed budget; `theme.motion.normal / 100 = 0.0028s` per cell caps total cascade at `theme.motion.normal`. The `min()` picks whichever is smaller per cell.

**Example:**

```swift
// Source: D-01 + UI-SPEC §Motion + [CITED: developer.apple.com/documentation/swiftui/view/transition]
import SwiftUI
import DesignKit

struct MinesweeperBoardView: View {
    let theme: Theme
    let board: MinesweeperBoard
    let phase: MinesweeperPhase
    let gameState: MinesweeperGameState
    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        flagToggleCount: viewModel.flagToggleCount,  // for .symbolEffect
                        revealCount: viewModel.revealCount,           // for .sensoryFeedback
                        onTap: onTap,
                        onLongPress: onLongPress
                    )
                    .transition(transitionFor(cellIndex: index))
                }
            }
            // ... padding
        }
    }

    private func transitionFor(cellIndex: MinesweeperIndex) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        guard case .revealing(let cells) = phase else { return .opacity }
        guard let position = cells.firstIndex(of: cellIndex) else { return .opacity }
        let count = cells.count
        let perCellDelay = min(0.008 * Double(position), theme.motion.normal / Double(count))
        return .opacity.animation(
            .easeOut(duration: theme.motion.fast).delay(perCellDelay)
        )
    }
}
```

**Notes:**
- Computing the delay per cell requires the board view to receive `phase` (or the `revealing(cells:)` payload) as a prop.
- Reduce Motion path: `.identity` transition = instant render, no opacity fade.
- The `firstIndex(of:)` lookup is O(n) per cell; for Hard 100+ cell cascade this is O(n²) — measure on iPhone SE before declaring done. If it's slow, precompute a `[MinesweeperIndex: Int]` dict in the board view's `body` once per `phase` change.

### Pattern 4: `.symbolEffect(.bounce)` for Flag Spring (MINES-08 + D-04)

**What:** iOS 17 `.symbolEffect(.bounce, value:)` is a native SF Symbol animation modifier. P5 uses it to make the flag glyph "spring" on toggle without a manual `withAnimation` block.

**When to use:** Any SF Symbol that should animate on a value change (counter increment, state flip). Trigger pattern: `.symbolEffect(.bounce, value: vm.flagToggleCount)` — the effect fires every time the value changes.

**Trade-offs:**
- ✅ One-liner; system handles spring physics.
- ✅ Respects Reduce Motion automatically AND we gate explicitly per D-04 (defensive).
- ⚠️ Only works on SF Symbols, not custom images.

**Example:**

```swift
// Source: D-04 + [CITED: developer.apple.com/documentation/swiftui/symboleffect]
import SwiftUI

extension MinesweeperCellView {
    @ViewBuilder
    private var flagGlyph: some View {
        Image(systemName: "flag.fill")
            .resizable().scaledToFit()
            .frame(width: cellSize * 0.55, height: cellSize * 0.55)
            .foregroundStyle(theme.colors.danger)
            .symbolEffect(
                .bounce,
                value: reduceMotion ? 0 : flagToggleCount
            )
    }
}
```

**Notes:**
- Tying the trigger value to `0` when Reduce Motion is on effectively disables the trigger (value never changes from the constant).
- The cell view receives `flagToggleCount: Int` as a let prop from `MinesweeperBoardView`, which threads it from `MinesweeperViewModel.flagToggleCount`.

### Pattern 5: `.sensoryFeedback` for Tap and Flag Haptics (MINES-09 + D-07)

**What:** iOS 17 `.sensoryFeedback(_:trigger:)` is the declarative replacement for `UIImpactFeedbackGenerator`. P5 uses two variants:
- `.sensoryFeedback(.selection, trigger: vm.revealCount)` — neutral feedback on cell reveal.
- `.sensoryFeedback(.impact(weight: .light), trigger: vm.flagToggleCount)` — light impact on flag toggle.

**When to use:** For immediate per-event haptics (not multi-event AHAP patterns). Tap and flag fire dozens of times per game; AHAP would be overkill. AHAP is reserved for the 2 marquee win/loss moments.

**Trade-offs:**
- ✅ Declarative; trigger value must change for feedback to fire.
- ✅ Per checker recommendation 1: gate on `settingsStore.hapticsEnabled` via `trigger: hapticsEnabled ? vm.revealCount : 0` pattern — when toggle off, the trigger never changes from 0 and feedback never fires.
- ⚠️ The trigger value type must be `Equatable`; Int is canonical.

**Example:**

```swift
// Source: D-07 + checker recommendation 1 + [CITED: useyourloaf.com/blog/swiftui-sensory-feedback]
import SwiftUI

struct MinesweeperCellView: View {
    @Environment(\.settingsStore) private var settingsStore
    let flagToggleCount: Int
    let revealCount: Int
    // ...

    var body: some View {
        tileBackground
            // ... existing modifiers
            .sensoryFeedback(
                .selection,
                trigger: settingsStore.hapticsEnabled ? revealCount : 0
            )
            .sensoryFeedback(
                .impact(weight: .light),
                trigger: settingsStore.hapticsEnabled ? flagToggleCount : 0
            )
    }
}
```

**Subtypes worth noting:**
- `.selection` — neutral, for picker-like commits (cell reveal).
- `.impact(weight: .light)` — subtle thud (flag toggle).
- `.impact(weight: .medium)` — stronger thud (could be used for win/loss but AHAP is richer).
- `.success` / `.error` / `.warning` — pre-canned notification haptics; NOT used in P5 because AHAP gives richer per-pattern control.

### Pattern 6: `Core/Haptics.swift` — `CHHapticEngine` + AHAP File Loader (MINES-09 + D-11)

**What:** A `@MainActor enum` namespace with static `playAHAP(named:)` method. Owns a single shared `CHHapticEngine` lazy-loaded on first use. AHAP files load via `Bundle.main.url(forResource:withExtension:)` + `CHHapticPattern(contentsOf:)`. Failure is silent — `os.Logger` records, gameplay continues.

**When to use:** For multi-event custom haptic patterns synced with audio. P5 uses it for win (3-event arpeggio) and loss (continuous decay + 2 transients).

**Trade-offs:**
- ✅ AHAP files are tweakable text; no recompile to retune.
- ✅ Single shared engine: avoids the cost of `CHHapticEngine.start()` per playback.
- ⚠️ Engine reset can happen — `engineResetHandler` callback re-creates the engine.
- ⚠️ Engine starts/stops on app foreground/background. Per CONTEXT D-11, foreground-only playback is fine — backgrounded haptics make no sense.

**Example:**

```swift
// Source: D-11 + STACK.md §5 + [CITED: developer.apple.com/documentation/corehaptics/playing_a_custom_haptic_pattern_from_a_file]
import CoreHaptics
import Foundation
import os

@MainActor
enum Haptics {
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "haptics"
    )
    private static var engine: CHHapticEngine?

    /// Play an AHAP file from the app bundle. Gated on
    /// `settingsStore.hapticsEnabled`. Failure is silent — gameplay continues.
    /// Consumed via `Haptics.playAHAP(named: "win", settings: settingsStore)`.
    static func playAHAP(named name: String, settings: SettingsStore) {
        guard settings.hapticsEnabled else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "ahap") else {
            logger.error("AHAP file not found: \(name, privacy: .public)")
            return
        }
        do {
            try ensureEngine()
            try engine?.playPattern(from: url)
        } catch {
            logger.error("AHAP playback failed (\(name, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func ensureEngine() throws {
        if engine == nil {
            let e = try CHHapticEngine()
            e.resetHandler = { [weak e] in
                Self.logger.info("CHHapticEngine reset — restarting")
                try? e?.start()
            }
            e.stoppedHandler = { reason in
                Self.logger.info("CHHapticEngine stopped: \(String(describing: reason), privacy: .public)")
            }
            try e.start()
            engine = e
        } else {
            try engine?.start()  // idempotent if already running
        }
    }
}
```

**AHAP file shapes (locked per CONTEXT Specifics):**

`win.ahap` — 3 ascending intensity-0.7 transients @ t=0/0.2/0.4s, sharpness 0.5:

```json
{
  "Version": 1.0,
  "Metadata": { "Project": "GameKit", "Created": "2026-04-26" },
  "Pattern": [
    {
      "Event": {
        "Time": 0.0,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.7 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.5 }
        ]
      }
    },
    {
      "Event": {
        "Time": 0.2,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.7 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.5 }
        ]
      }
    },
    {
      "Event": {
        "Time": 0.4,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.7 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.5 }
        ]
      }
    }
  ]
}
```

`loss.ahap` — continuous decay 0–0.5s + 2 sharp transients @ 0.1s and 0.25s:

```json
{
  "Version": 1.0,
  "Metadata": { "Project": "GameKit", "Created": "2026-04-26" },
  "Pattern": [
    {
      "Event": {
        "Time": 0.0,
        "EventType": "HapticContinuous",
        "EventDuration": 0.5,
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 1.0 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.3 }
        ]
      }
    },
    {
      "ParameterCurve": {
        "ParameterID": "HapticIntensityControl",
        "Time": 0.0,
        "ParameterCurveControlPoints": [
          { "Time": 0.0, "ParameterValue": 1.0 },
          { "Time": 0.5, "ParameterValue": 0.2 }
        ]
      }
    },
    {
      "Event": {
        "Time": 0.1,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.9 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.9 }
        ]
      }
    },
    {
      "Event": {
        "Time": 0.25,
        "EventType": "HapticTransient",
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.7 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.8 }
        ]
      }
    }
  ]
}
```

**Tips:**
- Use Apple's AHAP Pattern Generator app or [reference docs](https://developer.apple.com/documentation/corehaptics/representing-haptic-patterns-in-ahap-files) to author.
- Test AHAP files on a real iPhone — simulator does not produce haptics.
- The `settings: SettingsStore` parameter in `playAHAP(named:settings:)` is required because `Haptics` is a static enum (no instance state); the call site passes the `@Environment(\.settingsStore)` value.

### Pattern 7: `Core/SFXPlayer.swift` — Preloaded `AVAudioPlayer` on `AVAudioSession.ambient` (MINES-10 + D-12)

**What:** A `@MainActor final class SFXPlayer` that preloads 3 `AVAudioPlayer` instances at init via `prepareToPlay()` so first-play has zero latency. Sets `AVAudioSession.ambient` once at init so SFX never duck user music.

**When to use:** For 1–4 short non-overlapping SFX cues (P5 has 3). Use AVAudioEngine if you ever need overlapping audio (3+ concurrent tracks).

**Trade-offs:**
- ✅ `prepareToPlay()` primes buffers; first-play latency drops from hundreds of ms to ~negligible.
- ✅ `.ambient` category does not duck user music.
- ✅ Three `let`-stored properties = zero allocation per `play(_:)` call.
- ⚠️ Constructed at app init AFTER first frame is rendered (per cold-start budget). Inject via `@State` in `GameKitApp`, then `.environment(\.sfxPlayer, sfxPlayer)` on RootTabView.
- ⚠️ Player initialization can fail (file missing, format unsupported) — log via `os.Logger`, continue silently.

**Example:**

```swift
// Source: D-08 + D-09 + D-12 + STACK.md §6 + [CITED: developer.apple.com/documentation/avfaudio/avaudioplayer]
import AVFoundation
import Foundation
import os

enum SFXEvent {
    case tap, win, loss
}

@MainActor
final class SFXPlayer {
    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "audio"
    )

    private let tapPlayer: AVAudioPlayer?
    private let winPlayer: AVAudioPlayer?
    private let lossPlayer: AVAudioPlayer?
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings

        // Set ambient session category once — does not duck user music (D-09).
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        } catch {
            Self.logger.error("AVAudioSession setCategory failed: \(error.localizedDescription, privacy: .public)")
        }

        self.tapPlayer = Self.preloadPlayer(named: "tap", logger: Self.logger)
        self.winPlayer = Self.preloadPlayer(named: "win", logger: Self.logger)
        self.lossPlayer = Self.preloadPlayer(named: "loss", logger: Self.logger)
    }

    private static func preloadPlayer(named name: String, logger: Logger) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            logger.error("CAF file not found: \(name, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.6   // calm headroom per STACK §6
            player.prepareToPlay()  // primes buffers; zero first-play latency
            return player
        } catch {
            logger.error("AVAudioPlayer init failed (\(name, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func play(_ event: SFXEvent) {
        guard settings.sfxEnabled else { return }
        let player: AVAudioPlayer? = {
            switch event {
            case .tap:  return tapPlayer
            case .win:  return winPlayer
            case .loss: return lossPlayer
            }
        }()
        player?.currentTime = 0
        player?.play()
    }
}

// EnvironmentKey injection
private struct SFXPlayerKey: EnvironmentKey {
    @MainActor static let defaultValue: SFXPlayer? = nil
}
extension EnvironmentValues {
    var sfxPlayer: SFXPlayer? {
        get { self[SFXPlayerKey.self] }
        set { self[SFXPlayerKey.self] = newValue }
    }
}
```

**App-init wiring:**

```swift
// In GameKitApp.init() — after SettingsStore construction
let store = SettingsStore()
_settingsStore = State(initialValue: store)
_sfxPlayer = State(initialValue: SFXPlayer(settings: store))
// ...
// In body:
.environment(\.sfxPlayer, sfxPlayer)
```

**Notes:**
- `defaultValue: SFXPlayer? = nil` (Optional) so tests don't need to construct one. Production wires the real player; previews / unit tests get nil and silently skip.
- `.ambient` mode is the locked default per D-09 — never `.playback` (would interrupt user music) or `.soloAmbient` (would duck user music).

### Pattern 8: Settings Spine Sections (SHELL-02 + D-13/D-15/D-17)

**What:** SettingsView body composes 4 sections: APPEARANCE → AUDIO → DATA → ABOUT. Each is `settingsSectionHeader(theme:_:)` followed by `DKCard { rows }`. AUDIO ships 2 toggle rows; APPEARANCE replaces the P1 stub with `DKThemePicker(catalog: .core)` + nav row; ABOUT replaces the P1 stub with Version/Privacy/Acknowledgments rows.

**When to use:** Any iOS Settings-style screen with grouped rows. Reuses the established P1+P4 visual rhythm.

**Trade-offs:**
- ✅ Familiar iOS-native pattern (DKCard groupings instead of system Form rows — matches P4 DATA card precedent).
- ✅ File-private `SettingsToggleRow` is single-screen; below CLAUDE.md §4 promotion bar.
- ⚠️ AUDIO toggle accent tint is recommended `.tint(theme.colors.accentPrimary)` to avoid system-blue token bypass per UI-SPEC §Color refined accent reservation.

**Example:**

See **Pattern 8 Code Example** below for the full SettingsView rebuild.

### Pattern 9: `.fullScreenCover` + `TabView(.page)` IntroFlowView (SHELL-04 + D-18)

**What:** `.fullScreenCover(isPresented:)` over RootTabView presents `IntroFlowView` if `!hasSeenIntro`. Inside the cover: `TabView(selection: $currentStep)` with `.tabViewStyle(.page(indexDisplayMode: .always))`. 3 file-private step views: Step 1 (themes preview), Step 2 (stats mock), Step 3 (sign-in card).

**When to use:** First-run onboarding, step-by-step disclosure. iOS-canonical for premium first-launch experiences (no NavigationStack chrome, no swipe-back to dismiss).

**Trade-offs:**
- ✅ Swipeable; page indicator at bottom; `.indexViewStyle(.page(backgroundDisplayMode: .always))` gives the dots a backdrop pill.
- ✅ Skip top-trailing on every step + Continue/Done bottom-trailing per D-22.
- ⚠️ `@State currentStep: Int = 0` drives `TabView(selection:)`; Continue button increments; Done button writes `hasSeenIntro = true` + dismisses.
- ⚠️ VoiceOver focus order: Skip → step content → Continue/Done. Natural top-to-bottom flow per UI-SPEC; no explicit `.accessibilitySortPriority` overrides needed.

**Example:**

```swift
// Source: D-18 + D-22 + D-23 + UI-SPEC §Layout & Sizing
// [CITED: developer.apple.com/documentation/swiftui/view/fullscreencover]
// [CITED: developer.apple.com/documentation/swiftui/tabviewstyle/page]
import SwiftUI
import DesignKit

struct IntroFlowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 0
    private let totalSteps = 3

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            TabView(selection: $currentStep) {
                IntroStep1ThemesView(theme: theme)
                    .tag(0)
                IntroStep2StatsView(theme: theme)
                    .tag(1)
                IntroStep3SignInView(
                    theme: theme,
                    onSkip: dismissIntro,
                    onSignIn: { /* P6 wires actual SIWA via PERSIST-04 */ }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .tint(theme.colors.accentPrimary)
        }
        .overlay(alignment: .topTrailing) {
            DKButton(
                String(localized: "Skip"),
                style: .secondary,
                theme: theme,
                action: dismissIntro
            )
            .accessibilityLabel(String(localized: "Skip intro"))
            .padding(theme.spacing.l)
            .frame(width: 100)
        }
        .overlay(alignment: .bottomTrailing) {
            primaryButton
                .padding(theme.spacing.l)
                .frame(width: 140)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if currentStep < totalSteps - 1 {
            DKButton(
                String(localized: "Continue"),
                style: .primary,
                theme: theme,
                action: { currentStep += 1 }
            )
            .accessibilityLabel(String(localized: "Continue to next step"))
        } else {
            DKButton(
                String(localized: "Done"),
                style: .primary,
                theme: theme,
                action: dismissIntro
            )
            .accessibilityLabel(String(localized: "Finish intro"))
        }
    }

    private func dismissIntro() {
        settingsStore.hasSeenIntro = true
        dismiss()
    }
}
```

### Pattern 10: `SignInWithAppleButton` UI-Only (SHELL-04 + D-21)

**What:** `SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })` from `AuthenticationServices`. iOS 17 SwiftUI native. P5 ships the button as functional UI but its closures are no-ops. P6 wires actual SIWA via PERSIST-04.

**When to use:** First-run intro Step 3 sign-in card. NEVER restyle Apple's button — HIG forbids overriding the system black/white pill.

**Trade-offs:**
- ✅ One-liner SwiftUI native control.
- ✅ Apple-handles a11y label ("Sign in with Apple"), VoiceOver, Dynamic Type internally.
- ⚠️ Style must follow `colorScheme` (`.black` on light, `.white` on dark). Use `.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)`.
- ⚠️ Even though P5 ships closures as no-ops, the **Sign in with Apple capability MUST be added to entitlements file now** (not at P6) so the button renders without `ASAuthorizationErrorUnknown`.

**Example:**

```swift
// Source: D-21 + STACK.md §3 + [CITED: developer.apple.com/documentation/authenticationservices/signinwithapplebutton]
import SwiftUI
import AuthenticationServices
import DesignKit
import os

struct IntroStep3SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: Theme
    let onSkip: () -> Void
    let onSignIn: () -> Void

    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "auth"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            Text(String(localized: "Sync across devices"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Sign in with Apple to sync your stats across iPhone, iPad, and Mac. Optional — the app works fully without it."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.leading)

            DKCard(theme: theme) {
                VStack(spacing: theme.spacing.s) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { _ in
                            // P6 wires actual SIWA via PERSIST-04.
                            // Until then, log a breadcrumb and no-op.
                            Self.logger.info("SIWA tap (P5 no-op)")
                            onSignIn()
                        },
                        onCompletion: { _ in
                            // No-op until P6.
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 44)   // HIG min; system rounds to ~50pt, accept

                    DKButton(
                        String(localized: "Skip"),
                        style: .secondary,
                        theme: theme,
                        action: onSkip
                    )
                }
            }
            .frame(maxWidth: 480)        // iPad-class width cap per UI-SPEC §Layout
        }
        .padding(.horizontal, theme.spacing.l)
        .padding(.top, theme.spacing.xxl)
        .accessibilityElement(children: .combine)   // VoiceOver reads full step
    }
}
```

### Pattern 11: `ThemeManager.overrides` Plumb-Through (THEME-03 + D-25/D-26)

**What:** `ThemeManager.overrides: ThemeOverrides?` is the existing DesignKit API for custom-color overrides. Setting `themeManager.overrides = ThemeOverrides(colors: ThemeColorOverrides(accentPrimary: .red, ...))` causes every `themeManager.theme(using:).colors.{...}` call to honor the override. P5 verifies — does NOT extend.

**When to use:** Whenever the user customizes colors. The DKThemePicker(.all)'s Custom tab already provides 4 color wells (Primary / Background / Surface / Text) wired to `themeManager.setOverrideAnchor(...)`.

**Verification (D-26):**

1. Open Settings → APPEARANCE → "More themes & custom colors" → FullThemePickerView.
2. Tap "Custom" tab → 4 color wells.
3. Override `accentPrimary` to a non-default color (e.g., bright red).
4. Navigate back to Mines game; observe these surfaces honoring the override:
   - **Restart button background tint** (P3 — `DKButton(.primary)` reads `accentPrimary` via DesignKit).
   - **Mines toolbar Menu open-state glyph tint** (P3 — preserved).
   - **IntroFlowView Continue/Done buttons** (P5 — but P5 doesn't re-show intro; manual reset of `hasSeenIntro` for verification only).
   - **AUDIO Toggle on-state pill tint** (P5 — `.tint(theme.colors.accentPrimary)`).
   - **TabView active page indicator dot** (P5 — `.tint(theme.colors.accentPrimary)`).
5. Override `gameNumberPalette` is NOT in scope — `accentPrimary` override does NOT bleed into `gameNumber(_:)`. (`accentPrimary` and `gameNumberPalette` are separate token paths.)
6. Screenshot before / after attached to `05-VERIFICATION.md`.

**Code (no new code — verify existing pipeline):**

```swift
// In MinesweeperGameView (existing pattern preserved):
@EnvironmentObject private var themeManager: ThemeManager
@Environment(\.colorScheme) private var colorScheme
private var theme: Theme { themeManager.theme(using: colorScheme) }
//                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                          ThemeManager already reads its own .overrides
//                          property internally and applies it via
//                          Theme.resolve(preset:scheme:overrides:).
//                          Nothing to add in P5.

// ... usage:
DKButton(
    String(localized: "Restart"),
    style: .primary,
    theme: theme,                        // theme.colors.accentPrimary respects overrides
    action: { viewModel.restart() }
)
```

**Notes:**
- Confidence HIGH: `[VERIFIED: ../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift:18-25 — @Published var overrides + saveOverrides on didSet]` — the override pipeline already exists end-to-end. P5 verifies it reaches every Mines render path via the manual smoke per D-26.

### Pattern 12: Dynamic Type AX5 Carve-Out (A11Y-01 + D-27/D-28)

**What:** All non-grid text uses `theme.typography.{token}` which scales with Dynamic Type by default. The cell-adjacency digit font is the documented exception — it stays fixed at `cellSize × 0.55` regardless of Dynamic Type setting (locked at P3 D-19).

**When to use:** Always. Dynamic Type respect is a system-wide accessibility expectation; SwiftUI views that use `.font(theme.typography.{token})` get scaling for free.

**Trade-offs:**
- ✅ DesignKit `theme.typography.{titleLarge,title,headline,body,caption,monoNumber}` tokens internally use `Font.system(.body, design: .default).leading(...)` style which scales automatically.
- ⚠️ Common breakage: fixed `.frame(width:)` on text containers (overflow at AX5); `.fixedSize()` modifier mid-text (truncates); `.layoutPriority()` issues.
- ⚠️ Buttons may wrap at AX5 — accept the wrap (per UI-SPEC), do NOT truncate.

**Audit surfaces (D-27 — must verify at AX5):**
- HomeView card labels (P1)
- Settings rows (P5 + P4) — APPEARANCE/AUDIO/DATA/ABOUT
- StatsView per-difficulty rows (P4)
- Settings ABOUT content (P5) — Version/Privacy/Acknowledgments
- IntroFlowView all 3 steps (P5)
- End-state DKCard title/body (P3 preserved)
- Mine counter + timer in HeaderBar (P3 preserved)

**Grid carve-out (D-28):** the cell-adjacency digit `.font(.system(size: cellSize * 0.55, weight: .bold, design: .rounded))` is preserved unchanged from P3. AX5 audit must confirm grid layout doesn't break — only non-grid text scales.

**Test override:**

```swift
#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
        .dynamicTypeSize(.accessibility5)         // AX5 audit
}
```

### Pattern 13: VoiceOver `.accessibilityElement(children: .combine)` for Intro Steps (A11Y-02 + D-24)

**What:** Each IntroFlowView step uses `.accessibilityElement(children: .combine)` on its outer VStack so VoiceOver reads the entire step (title + body) as one phrase when focus enters the step. Buttons (Skip, Continue, Done, SIWA) preserve their own a11y elements.

**When to use:** Intro/onboarding steps where reading title-then-body separately would be choppy. Combine the prose, leave the actionable controls separate.

**Trade-offs:**
- ✅ Single VoiceOver phrase per step; users navigate steps with the rotor.
- ✅ Buttons still receive focus separately — `accessibilityLabel("Skip intro")` etc. per D-24.
- ⚠️ TabView page indicator: system-rendered. VoiceOver reads "Page X of 3" automatically when focus enters the indicator. Do NOT override.

**Example:**

```swift
struct IntroStep1ThemesView: View {
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            Text(String(localized: "Make it yours"))
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(String(localized: "Pick a theme that fits your mood. Five Classic palettes here, dozens more in Settings."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.s) {
                    // 5 Classic preset swatches — read-only
                    // (visual preview only; no theme commit during intro per D-19)
                }
            }
        }
        .padding(.horizontal, theme.spacing.l)
        .padding(.top, theme.spacing.xxl)
        .accessibilityElement(children: .combine)   // D-24
    }
}
```

### Pattern 14: Reduce Motion Per-Element Contract (A11Y-03 + D-04 — load-bearing)

**What:** Every animation block independently reads `@Environment(\.accessibilityReduceMotion)` and falls back to instant rendering when `true`. Tested via PreviewProvider `.environment(\.accessibilityReduceMotion, true)` for every animated surface, plus a manual SC5 audit ("Reduce Motion ON during a win replay produces a static end-state overlay with no shake or sweep").

**When to use:** Always. A11Y-03 + ROADMAP SC1 + SC5 are non-negotiable.

**The four contracts:**

| Animation | Normal Behavior | Reduce Motion Behavior |
|-----------|-----------------|------------------------|
| Cascade | per-cell `.transition(.opacity.animation(.easeOut(duration: theme.motion.fast).delay(perCellDelay)))` | All cells reveal simultaneously, no opacity transition (`.transition(.identity)`) |
| Flag spring | `.symbolEffect(.bounce, value: vm.flagToggleCount)` | `.symbolEffect(.bounce, value: 0)` — value never changes from constant 0, effect never fires |
| Win wash | `.phaseAnimator([0.0, 0.25, 0.0], trigger:) { content, phase in content.opacity(phase) }` | `.phaseAnimator([0.0], trigger:)` — single phase, no fade in/out |
| Loss shake | `.keyframeAnimator(initialValue: 0.0, trigger: vm.phase.isLossShake) { ... }` with 4 keyframes | `.keyframeAnimator` trigger = false — keyframes never fire; offset stays 0 |

**Code:** see Pattern 1+2+3+4 examples — each gates on `reduceMotion`.

**Note:** Haptics + SFX are NOT gated by Reduce Motion. Reduce Motion is a visual preference; tactile/audio are independent. Haptics ARE gated by `settingsStore.hapticsEnabled` only; SFX by `settingsStore.sfxEnabled`. iOS does not expose a separate "reduce haptics" environment value (verified `[CITED: STACK.md §5]`).

### Anti-Patterns to Avoid

- **`UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` for new code.** `[CITED: STACK.md §5]` — these are pre-iOS-17; require manual `.prepare()` lifecycle. Use `.sensoryFeedback` declarative modifier instead.
- **`Animation.timingCurve` for the loss shake.** `timingCurve` interpolates between 2 endpoints with a Bezier; loss shake needs 4 distinct keyframes. Use `.keyframeAnimator` with `LinearKeyframe` steps.
- **Manual `Timer.scheduledTimer` for the cascade stagger.** Imperative; fights SwiftUI diffing. Use per-cell `.transition(.opacity.animation(...).delay(perCellDelay))` declarative pattern.
- **`AVAudioSession.soloAmbient`.** Would silence user music. D-09 locks `.ambient` — never override.
- **`AudioServicesPlaySystemSound` for SFX.** Inherits ringer state; no volume control. STACK §6 explicit reject. Use preloaded `AVAudioPlayer`.
- **AVAudioPlayer instances created on the play call.** First-play latency runs hundreds of ms — feels broken. Preload via `prepareToPlay()` in `SFXPlayer.init()`.
- **`Task.detached` in `App.init`.** Competes with first-frame render. Move `SFXPlayer` construction to `.task` modifier on first view OR construct via `@State initialValue` synchronously (reads UserDefaults only — fast).
- **`@Query` inside reusable IntroStep views.** Step 2 uses HAND-CODED sample stats; explicitly NOT `@Query` (would show first-launch empty state). UI-SPEC locked.
- **`Color(...)` literal anywhere in P5-edited files.** Pre-commit hook FOUND-07 rejects.
- **Re-creating `CHHapticEngine` per playback.** Costly; engine init is non-trivial. Lazy-load shared instance per Pattern 6.
- **`@StateObject` for `SettingsStore` extension.** `@Observable` is iOS 17 idiom; `@EnvironmentObject` requires `ObservableObject` and is incompatible. Use custom `EnvironmentKey` (P4 pattern).
- **Restyling `SignInWithAppleButton`.** Apple HIG forbids. Use `.signInWithAppleButtonStyle(.black or .white)` only.
- **Re-fetching theme tokens inside cell views.** P3 anti-pattern (RESEARCH §Anti-Patterns); cells receive `theme: Theme` as a let prop. P5 preserves.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cascade per-cell stagger | `Timer.scheduledTimer` per cell | `.transition(.opacity.animation(.easeOut(duration:).delay(perCellDelay)))` | SwiftUI handles scheduling declaratively; one-line per cell |
| Win sweep keyframe alpha | Custom `withAnimation` with manual delays | `.phaseAnimator([0.0, 0.25, 0.0], trigger:)` | iOS 17 declarative; trigger-driven; respects Reduce Motion via single-phase override |
| Loss shake bumps | Custom `Animation.timingCurve` | `.keyframeAnimator(initialValue: 0.0)` with 4 `LinearKeyframe` steps | Purpose-built for multi-keyframe motion; exact control |
| Flag bounce animation | Custom `withAnimation(.spring) { scale = 1.2 }` | `.symbolEffect(.bounce, value:)` | One-line iOS 17 native; respects Reduce Motion automatically |
| Tap/flag haptics | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | `.sensoryFeedback(.impact(weight: .light), trigger:)` | iOS 17 declarative; no `.prepare()` lifecycle |
| Win/loss custom haptic patterns | Hand-coded `CHHapticEvent` arrays | External AHAP JSON files via `CHHapticPattern(contentsOf:)` | Tweakable text format; Apple-canonical; no recompile to retune |
| `CHHapticEngine` lifecycle | Per-playback `try CHHapticEngine().start()` | Single shared `@MainActor` static engine, lazy-loaded; `engineResetHandler` re-creates | Engine init is costly; shared instance is the standard pattern |
| SFX preload | Lazy `AVAudioPlayer(contentsOf:)` on first play | `AVAudioPlayer.prepareToPlay()` in `SFXPlayer.init()` | First-play latency drops from hundreds of ms to ~negligible |
| Audio session category | `AVAudioSession.sharedInstance().setCategory(.playback)` | `.setCategory(.ambient, mode: .default)` | `.playback` interrupts user music; `.ambient` does not duck |
| First-run flag storage | Custom `Codable` JSON to disk | `UserDefaults.standard.bool(forKey: "gamekit.hasSeenIntro")` via `SettingsStore` `@Observable` | Tiny key-value shape; UserDefaults is correct per CLAUDE.md §1 |
| First-run UX | Custom modal sheet with manual dismiss | `.fullScreenCover(isPresented:)` with `TabView(.page)` | iOS-canonical; no NavigationStack chrome; system-handles swipe gesture |
| Theme picker swatch grid | Custom GridItem layout | `DKThemePicker(catalog: PresetCatalog.core, maxGridHeight: nil)` | Already shipped; reuse from DesignKit |
| Custom-palette editor UI | Hand-rolled color wells + ThemeManager.overrides setter | `DKThemePicker(catalog: .all)` Custom tab — already ships 4 color wells | DesignKit-shipped; THEME-03 verifies pipeline only |
| Sign in with Apple button | Custom button styled like SIWA | `SignInWithAppleButton(.signIn, onRequest:onCompletion:)` from `AuthenticationServices` | First-party SwiftUI control; Apple-mandated styling; correct a11y |
| About-screen version display | Hand-coded version string | `Bundle.main.infoDictionary["CFBundleShortVersionString"] + ["CFBundleVersion"]` | Auto-updates with Info.plist version bumps |
| Reduce Motion gate | Custom `UIAccessibility.isReduceMotionEnabled` notification observer | `@Environment(\.accessibilityReduceMotion)` per-view | iOS 17 declarative; per-view scope; SwiftUI handles propagation |

**Key insight:** iOS 17 SwiftUI ships canonical solutions for every animation, haptic, audio, and a11y problem in P5. The trap is reaching for older patterns (`UIImpactFeedbackGenerator`, `Animation.timingCurve`, manual `Timer`, `AVAudioSession.playback`) that pre-date the modern stack. Every time you're tempted to write imperative animation code, the answer is `.phaseAnimator` / `.keyframeAnimator` / `.transition` / `.symbolEffect`.

