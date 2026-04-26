# Phase 5: Polish - Context

**Gathered:** 2026-04-26
**Status:** Ready for research/planning

<domain>
## Phase Boundary

P5 ships the **differentiator-defining "premium feel" surface** that turns the playable, persisted Minesweeper from P3+P4 into something that feels good. Animation pass on `MinesweeperPhase`, haptics on key events, SFX with default-OFF toggle, full a11y (Dynamic Type + Reduce Motion + VoiceOver polish), 6-preset legibility audit, custom-palette pipeline through `ThemeManager.overrides`, full Settings spine, and the 3-step first-launch intro.

**P5 ships:**
- `Games/Minesweeper/MinesweeperPhase.swift` — `enum MinesweeperPhase` (animation orchestration: `.idle / .revealing(cells: [Index]) / .flagging(idx) / .winSweep / .lossShake(mineIdx)`).
- `Games/Minesweeper/MinesweeperViewModel.swift` edit — publish `phase: MinesweeperPhase` and drive transitions from existing terminal-state branches; tests cover phase transitions.
- `Games/Minesweeper/MinesweeperBoardView.swift` edit — observe `vm.phase`, drive cascade stagger via `.transition(.opacity.animation(.easeOut(duration: ...)))` per-cell using `revealed: [Index]` order from engine D-06.
- `Games/Minesweeper/MinesweeperGameView.swift` edit — `.phaseAnimator` for win sweep, `.keyframeAnimator` for loss shake, `.sensoryFeedback` modifier for tap/flag haptics, `AVAudioPlayer` for SFX, `@Environment(\.accessibilityReduceMotion)` integration.
- `Core/Haptics.swift` — wrapper around `CHHapticEngine` that loads + plays `.ahap` files for win arpeggio + loss rumble (gated on `settingsStore.hapticsEnabled`).
- `Core/SFXPlayer.swift` — `@MainActor final class` preloading `AVAudioPlayer` instances for tap/win/loss CAF files on `AVAudioSession.ambient` (gated on `settingsStore.sfxEnabled`).
- `Core/SettingsStore.swift` edit — add 3 new flags: `hapticsEnabled: Bool` (default `true`), `sfxEnabled: Bool` (default `false`), `hasSeenIntro: Bool` (default `false`). Keys: `gamekit.hapticsEnabled`, `gamekit.sfxEnabled`, `gamekit.hasSeenIntro`.
- `Screens/IntroFlowView.swift` — NEW `.fullScreenCover` content with `TabView(.page)` 3 steps (themes / stats / sign-in card with Skip).
- `Screens/SettingsView.swift` edit — replace P1 stub APPEARANCE + ABOUT sections with real content. Add new AUDIO section with 2 toggles. Keep P4 DATA section unchanged. Add full `DKThemePicker` `NavigationLink` destination.
- `Screens/RootTabView.swift` edit — present `IntroFlowView` via `.fullScreenCover` if `!settingsStore.hasSeenIntro`.
- `Resources/Audio/tap.caf` + `win.caf` + `loss.caf` (~50KB each, royalty-free or hand-rolled).
- `Resources/Haptics/win.ahap` + `loss.ahap` (CoreHaptics JSON files).
- `Resources/Localizable.xcstrings` edit — auto-extracted P5 strings (intro copy, audio toggle labels, about copy).
- Tests: `gamekitTests/Games/Minesweeper/MinesweeperPhaseTransitionTests.swift`, `Core/SettingsStoreFlagsTests.swift`, `Core/SFXPlayerTests.swift` (mock AVAudioPlayer), `Core/HapticsTests.swift` (presence + AHAP file load).

**Out of scope for P5** (owned by later phases):
- Sign in with Apple actual sign-in (P6 PERSIST-04/05/06) — P5 ships the intro CARD + Skip button only; the SIWA button is functional UI but does nothing yet (comment-documents P6 wire-up).
- CloudKit sync ON-by-default — stays OFF until P6.
- App icon real artwork (P7 FOUND-06 polish).
- Custom-palette editor UI — pipeline only per W-confirmed (D-23 below).
- Settings search affordance — deferred.
- Achievement system / win celebration overlay — deferred.

**v1 ROADMAP P5 success criteria carried forward as locked specs (no re-asking):**
- SC1 — `MinesweeperPhase` drives reveal cascade, flag spring, win sweep, loss shake; all timed via `theme.motion.{fast,normal,slow}`; dampened to near-zero when `accessibilityReduceMotion` is on.
- SC2 — Haptics fire on flag/reveal/win/loss via `.sensoryFeedback` + 2 CoreHaptics `.ahap` files; Settings haptics toggle silences. SFX on tap/win/loss via preloaded `AVAudioPlayer` on `AVAudioSession.ambient`; OFF by default; Settings SFX toggle controls.
- SC3 — Settings spine: 5 Classic preset swatches + "More themes & custom colors" link + haptics toggle + SFX toggle + reset stats (P4 already shipped) + about. 3-step intro on first launch only; `hasSeenIntro` persisted.
- SC4 — Mines UI legibility verified on at least one preset per category (Classic / Sweet / Bright / Soft / Moody / Loud) for play AND loss state. `theme.colors.gameNumber(_:)` Wong-palette default verified (P3 already shipped). `ThemeManager.overrides` custom-palette pipeline works through Mines grid.
- SC5 — VoiceOver reads state + position + adjacency for every cell (P3 partial, P5 finishes). Dynamic Type AX5 scales all non-grid text without layout breakage; grid stays fixed. Reduce Motion ON → static end-state overlay (no shake/sweep).

</domain>

<decisions>
## Implementation Decisions

### Animation timing + shapes (MINES-08 + SC1)
- **D-01:** **Reveal cascade — engine-order stagger, 250ms total cap.** Iterate `revealed: [Index]` from engine D-06 (P2 contract). Per-cell delay = `min(8ms × index, 250ms / count)`. On Hard flood-fill of 100+ cells, total cascade always finishes within `theme.motion.normal` budget. Each cell uses `.transition(.opacity.animation(.easeOut(duration: theme.motion.fast)))` with the staggered delay.
- **D-02:** **Win sweep — full-board success-tint wash via `.phaseAnimator`.** On `MinesweeperPhase = .winSweep`, the `MinesweeperBoardView` underlay animates a `theme.colors.success` overlay opacity from 0 → 0.25 → 0 over `theme.motion.slow`. End-state DKCard fades in concurrently per P3 contract.
- **D-03:** **Loss shake — 3-bump horizontal `.keyframeAnimator`.** Magnitude 8pt, total 0.4s. Three bumps: +8pt @ 100ms → −8pt @ 200ms → +4pt @ 300ms → 0 @ 400ms. Applied to the `MinesweeperBoardView` outer `.offset(x:)`. Triggers on `MinesweeperPhase = .lossShake(mineIdx)` transition.
- **D-04:** **Reduce Motion dampening (A11Y-03 + SC1).** Every animation block reads `@Environment(\.accessibilityReduceMotion) var reduceMotion` and falls back to instant rendering when `true`:
  - Cascade → all cells reveal simultaneously (no stagger, no opacity transition)
  - Win wash → instant `theme.colors.success` tint, no fade
  - Loss shake → no shake; the `mineHit` overlay just appears
  - Flag spring → no `.symbolEffect(.bounce)`; flag glyph swap is instant
  This is the load-bearing A11Y-03 requirement. Tested via a Reduce-Motion environment override in PreviewProvider + manual SC5 audit.
- **D-05:** **Animation is view-layer concern — VM publishes `phase: MinesweeperPhase`, view drives modifiers.** Per ARCHITECTURE.md §pattern-2 + P3 D-18 (animation deferred to P5). VM owns no `Animation` types, no `withAnimation` calls. Phase enum changes are observed by `MinesweeperGameView` + `MinesweeperBoardView` via `@Bindable var viewModel`. `.onChange(of: viewModel.phase)` triggers the right modifier.
- **D-06:** **`MinesweeperPhase` enum shape:**
  ```swift
  enum MinesweeperPhase: Equatable {
      case idle                                  // pre-first-tap
      case revealing(cells: [MinesweeperIndex])  // cascade in flight
      case flagging(idx: MinesweeperIndex)       // single-cell flag spring
      case winSweep                              // win wash + DKCard fade-in
      case lossShake(mineIdx: MinesweeperIndex)  // shake + mine reveal cascade
  }
  ```
  VM transitions phase atomically alongside its existing `gameState` transitions (e.g. `.lost(mineIdx: idx)` → set `phase = .lossShake(mineIdx: idx)`).

### Haptics + SFX behavior (MINES-09 + MINES-10 + SC2)
- **D-07:** **4 haptic events.** Per W-confirmed:
  - **Flag** = `.sensoryFeedback(.impact(weight: .light), trigger: vm.flagToggleCount)` on `MinesweeperCellView`. Light impact = subtle commitment cue.
  - **Reveal** = `.sensoryFeedback(.selection, trigger: vm.revealCount)` on `MinesweeperCellView`. Selection feedback = neutral, doesn't intrude.
  - **Win** = AHAP file `Resources/Haptics/win.ahap` — 3 ascending intensity-0.7 transients over 0.6s. Plays via `Haptics.playAHAP(named: "win")` on `phase = .winSweep` transition.
  - **Loss** = AHAP file `Resources/Haptics/loss.ahap` — 0.5s continuous-decay event + 2 sharp transients at 100ms + 250ms. Plays on `phase = .lossShake` transition.
- **D-08:** **3 SFX files** in `Resources/Audio/`: `tap.caf` (cell reveal sound, ~30KB), `win.caf` (chime, ~50KB), `loss.caf` (low thud, ~40KB). All preloaded via `AVAudioPlayer.prepareToPlay()` in `SFXPlayer.init()` so first playback has zero latency.
- **D-09:** **`AVAudioSession.ambient` category** so SFX never duck user music (per ROADMAP SC2 literal). `try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)` once at `SFXPlayer.init`.
- **D-10:** **Default toggle states + Settings binding:**
  - `hapticsEnabled: Bool = true` (default ON — premium feel)
  - `sfxEnabled: Bool = false` (default OFF per ROADMAP SC2 literal — sound is opt-in, never surprises a user)
  - Both gated at the source: `Haptics.play(...)` and `SFXPlayer.play(...)` early-return if their respective flag is false. No view-layer plumbing of the toggle.
- **D-11:** **`Core/Haptics.swift`** = `@MainActor enum Haptics` (static methods). Owns a single shared `CHHapticEngine` instance, lazy-loaded on first `playAHAP(named:)` call. Loads `.ahap` files from `Bundle.main.url(forResource:withExtension: "ahap")`. Failure is non-fatal — AHAP play failure logs via `os.Logger(subsystem:category: "haptics")` and silently no-ops. CHHapticEngine reset on `engineResetHandler` callback. NEVER use `--no-verify` on commits.
- **D-12:** **`Core/SFXPlayer.swift`** = `@MainActor final class SFXPlayer` injected via custom `EnvironmentKey` (mirrors `SettingsStore` pattern from P4 D-29). Constructed at `GameKitApp.init()` after `SettingsStore`; reads `settingsStore.sfxEnabled` per-call. Holds 3 `AVAudioPlayer` instances as let-stored properties, each pre-prepared. Method shape: `play(_ event: SFXEvent)` where `enum SFXEvent { case tap, win, loss }`.

### Settings spine (SHELL-02 + SC3)
- **D-13:** **Section order: APPEARANCE → AUDIO → DATA → ABOUT** (per W-confirmed). Section identity is iOS-native `Section { ... } header: { Text("APPEARANCE") }` form. Spacing/typography matches P4 DATA section verbatim (already approved in P4 UI-SPEC).
- **D-14:** **APPEARANCE section content:**
  - 5 Classic preset swatches inline via `DKThemePicker(catalog: .core, maxGridHeight: nil)` per CLAUDE.md §2 theme picker UX convention.
  - "More themes & custom colors" — `NavigationLink(destination: FullThemePickerView())` where `FullThemePickerView` is a thin wrapper rendering `DKThemePicker(catalog: .all, maxGridHeight: nil)` inside a themed scroll view.
- **D-15:** **AUDIO section content (NEW):** 2 toggle rows using existing `SettingsToggleRow` pattern from P4 SettingsComponents.
  - "Haptics" row → bound to `settingsStore.hapticsEnabled`.
  - "Sound effects" row → bound to `settingsStore.sfxEnabled`.
  Both rows use `theme.typography.body` for label, system-tinted toggle.
- **D-16:** **DATA section** = unchanged from P4. Export / Import / Reset rows preserved verbatim.
- **D-17:** **ABOUT section content:** version row showing `Bundle.main.releaseVersionNumber` + build number; "Privacy" row showing brief inline copy ("All data stored locally. CloudKit sync optional."); "Acknowledgments" row with `NavigationLink` to a static text screen listing DesignKit (own work) + SF Symbols (Apple) — minimal v1 scope.

### 3-step intro (SHELL-04 + SC3)
- **D-18:** **Container: `.fullScreenCover` with `TabView(.page)`** (per W-confirmed). Swipeable; no NavigationStack. Page indicator at bottom (default `.page` style with `theme.colors.accentPrimary` for current dot). Swipe-back disabled past first step (default TabView .page allows it; lock via `tabViewStyle(.page(indexDisplayMode: .always))` only — first step is welcome step, no back-swipe before it).
- **D-19:** **Step 1: Themes preview.** Title "Make it yours", body copy explains DesignKit theming, visual = 5 Classic swatches in a horizontal scroll view (read-only; tap = no-op or focus indicator). User goes Continue → Step 2.
- **D-20:** **Step 2: Stats preview.** Title "Track your progress", body explains StatsView; visual = a static mock of the StatsView card (3 difficulty rows with hand-coded sample stats). User goes Continue → Step 3.
- **D-21:** **Step 3: Sign-in card with Skip.** Title "Sync across devices", body copy explains optional iCloud sync; visual = a sign-in CARD with Sign in with Apple button (DKButton primary style with Apple logo glyph from SF Symbols `applelogo`); pressing the SIWA button DOES NOTHING in P5 — comment in source says `// P6 wires actual SIWA via PERSIST-04`. Primary path is **Skip** button below (DKButton secondary). Tapping Skip OR Done dismisses the cover and writes `settingsStore.hasSeenIntro = true`.
- **D-22:** **Skip button placement: top-trailing on every step** (consistent across all 3 steps). `Continue` (steps 1+2) and `Done` (step 3) bottom-trailing per iOS convention. Both write `hasSeenIntro = true` on dismiss.
- **D-23:** **`hasSeenIntro` storage = UserDefaults key `gamekit.hasSeenIntro`** (default `false`, persisted via `SettingsStore`). Read by `RootTabView` on first appear via `@Environment(\.settingsStore)`; if false, present `.fullScreenCover` with `IntroFlowView`. On dismiss, the flag is set true and the cover never shows again.
- **D-24:** **IntroFlowView accessibility:** every step's title + body copy is `.dynamicTypeSize(...AX5)` enabled (no fixed font sizes); VoiceOver reads each page in full when it gains focus; Skip/Continue/Done buttons have explicit `accessibilityLabel`.

### THEME-03 custom-palette overrides (SC4)
- **D-25:** **Pipeline only — plumb `ThemeManager.overrides` through Mines grid + visual smoke** (per W-confirmed). P5 verifies that overriding `theme.colors.accentPrimary` / `theme.colors.danger` / `theme.colors.gameNumber(_:)` via `ThemeManager.overrides` reaches every Mines render path (cell tile, mine glyph, flag, end-state DKCard, header timer color). No new editor UI; verification via `DKThemePicker` custom-color UI manual smoke (DesignKit already exposes a custom-color editor inside the full picker per P4 D-25).
- **D-26:** **Verification protocol for THEME-03:** in P5 verification checkpoint, manually open `DKThemePicker` (full destination via D-14 NavigationLink), tap "Custom colors" or equivalent, override `accentPrimary` to a non-default color, observe the Mines grid (Restart button tint + numbered cells + win/loss overlays) honoring the override. Screenshot before + after for the verification report.

### A11Y-01 Dynamic Type carve-outs (SC5)
- **D-27:** **All non-grid text uses theme typography tokens** (already enforced from P3+P4). At AX5 scale, the manual audit covers: HomeView card labels, Settings rows, StatsView per-difficulty rows, Settings ABOUT content, IntroFlowView all 3 steps, end-state DKCard title/body, mine counter + timer in HeaderBar.
- **D-28:** **Grid stays fixed-size** per ROADMAP SC5 carve-out + A11Y-01 literal text. The cell-adjacency digit font is already locked at a non-Dynamic-Type fixed size (`theme.typography.monoNumber.bold`) per P3. AX5 audit must confirm grid layout doesn't break — only non-grid text scales.

### Folded Todos
None — STATE.md `Pending Todos` is empty.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules + invariants
- `CLAUDE.md` — Project constitution (§1 stack, §2 theme picker UX, §8.5 file caps, §8.6 .foregroundStyle, §8.12 theme matrix)
- `AGENTS.md` — Mirror
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` — MINES-08/09/10 + SHELL-02/04 + THEME-01/03 + A11Y-01/02/03/04 full text
- `.planning/ROADMAP.md` — Phase 5 entry: goal, SC1–SC5

### Architecture + research
- `.planning/research/ARCHITECTURE.md` — `MinesweeperPhase` enum already specified §pattern-2 + §pattern-3
- `.planning/research/PITFALLS.md`
- `.planning/research/STACK.md`

### Engine + UI prior decisions (consumed, do not modify)
- `.planning/phases/02-mines-engines/02-CONTEXT.md` — D-06 `RevealEngine.reveal(at:on:) -> (board, revealed: [Index])` — engine returns ordered reveal list, drives D-01 cascade order
- `.planning/phases/03-mines-ui/03-CONTEXT.md` — D-18 (animation deferred to P5; functional defaults shipped); D-19 (a11y label format)
- `.planning/phases/03-mines-ui/03-VERIFICATION.md` — VM API surface (`reveal`, `toggleFlag`, terminal-state branches)
- `.planning/phases/04-stats-persistence/04-CONTEXT.md` — D-28/D-29 SettingsStore extension precedent (extending now with 3 new flags); D-22/D-23 Reset alert (preserved unchanged)

### Existing source (extending in P5)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift` — adds `phase: MinesweeperPhase` published property + transitions
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` — observes phase, drives `.phaseAnimator` (win) + `.keyframeAnimator` (loss)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` — cascade stagger via per-cell `.transition`
- `gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift` — `.sensoryFeedback` modifiers for flag + reveal
- `gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift` — fade-in with win wash
- `gamekit/gamekit/Core/SettingsStore.swift` — extend with `hapticsEnabled`, `sfxEnabled`, `hasSeenIntro`
- `gamekit/gamekit/Screens/SettingsView.swift` — replace P1 stub APPEARANCE + ABOUT; add new AUDIO section; preserve P4 DATA verbatim
- `gamekit/gamekit/Screens/RootTabView.swift` — present `IntroFlowView` via `.fullScreenCover` if `!hasSeenIntro`
- `gamekit/gamekit/Resources/Localizable.xcstrings` — auto-extracted P5 strings

### NEW source (P5 ships)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift`
- `gamekit/gamekit/Core/Haptics.swift`
- `gamekit/gamekit/Core/SFXPlayer.swift`
- `gamekit/gamekit/Screens/IntroFlowView.swift`
- `gamekit/gamekit/Screens/FullThemePickerView.swift` (or inline NavigationLink destination if planner prefers)
- `gamekit/gamekit/Resources/Audio/{tap,win,loss}.caf`
- `gamekit/gamekit/Resources/Haptics/{win,loss}.ahap`

### DesignKit (sibling SPM — read but do not duplicate)
- `../DesignKit/Sources/DesignKit/Theme/Tokens.swift` — `theme.motion.{fast,normal,slow}` (animation timing source)
- `../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift` — `ThemeManager.overrides` API (THEME-03 pipeline target)
- `../DesignKit/Sources/DesignKit/Components/DKThemePicker.swift` — embedded inline (5 swatches) + full destination
- `../DesignKit/Sources/DesignKit/Theme/PresetCatalog.swift` — `.core` (5 Classic) and `.all` filters per CLAUDE.md §2

### Apple frameworks
- CoreHaptics (`CHHapticEngine`) — for `.ahap` playback
- AVFoundation (`AVAudioPlayer`, `AVAudioSession`) — for SFX

</canonical_refs>

<specifics>
## Specific Ideas

- AHAP file format: standard CoreHaptics JSON. Hand-author or use Apple's [Pattern Generator](https://developer.apple.com/documentation/corehaptics/representing-haptic-patterns-in-ahap-files) reference.
- `win.ahap` shape: 3 transient events at t=0/200/400ms, each Intensity=0.7, Sharpness=0.5, ascending pitch implied by spacing.
- `loss.ahap` shape: continuous event 0–500ms with decay curve (1.0 → 0.2), plus 2 sharp transients at 100ms (Intensity=0.9, Sharpness=0.9) and 250ms (Intensity=0.7, Sharpness=0.8).
- CAF files: 16-bit 44.1kHz mono, ~50KB each. `afconvert` from any WAV source.
- Settings AUDIO toggle labels: "Haptics" / "Sound effects".
- Intro step titles: "Make it yours" (themes) / "Track your progress" (stats) / "Sync across devices" (sign-in card).
- Skip button label: "Skip" (top-trailing, all steps).
- Continue/Done button labels: "Continue" (steps 1+2) / "Done" (step 3).
- About section row labels: "Version" / "Privacy" / "Acknowledgments".
- VoiceOver intro page announcement: full step body read on focus.
- Animation curve: `.easeOut` for cascade per-cell opacity; `.spring(duration: theme.motion.normal)` for win sweep `.phaseAnimator`; `.linear` for loss shake `.keyframeAnimator` (already locked by keyframe spec).
- Resource path: `Bundle.main.url(forResource: "tap", withExtension: "caf")` etc.
- Audio assets in `gamekit/gamekit/Resources/Audio/`; haptics in `gamekit/gamekit/Resources/Haptics/`. New folders auto-register via Xcode 16 PBXFileSystemSynchronizedRootGroup per CLAUDE.md §8.8.

</specifics>

<deferred>
## Deferred Ideas

- **Custom-palette editor UI inside Settings** (THEME-03 polish) — pipeline ships in P5; the editor lands at P6 polish OR drops permanently if `DKThemePicker`'s built-in custom-color UI is sufficient.
- **Richer SFX mapping** — flag.caf, reveal-numbered.caf, reveal-empty.caf differentiation. Per ROADMAP SC2 "subtle" — defer richer mapping unless user testing requests.
- **Haptic intensity slider** in Settings — single ON/OFF in P5; intensity slider is a v2 polish.
- **Per-difficulty SFX profile** (different tap pitch on Easy vs Hard). Defer.
- **Settings search bar** — small Settings, search not needed for v1.
- **About section rich content** — links to GitHub, full credits, dev blog. Minimal v1 (Version + Privacy + Acknowledgments).
- **Achievement system / win-streak overlay** — not in v1 ethos (calm + non-pushy). Defer permanently.
- **Sign in with Apple wired** — P5 ships the intro CARD + Skip path; SIWA button is functional UI but no-op until P6.
- **CloudKit sync ON-by-default** — stays OFF until P6.
- **Reduce Motion granular controls** ("dampen 50%" vs "off" vs "on") — single binary in P5.
- **Custom theme icon assets** — placeholder app icon stays through P5; real artwork at P7.

</deferred>

---

*Phase: 05-polish*
*Context gathered: 2026-04-26*
