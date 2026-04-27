# Phase 5: Polish — Verification Report

**Date:** 2026-04-26 (Task 1 automated suite captured); SC1-SC5 manual sections PENDING USER VERIFICATION
**Build:** `1c125a1` (head of `gsd/phase-05-polish` work, post 05-06 ship)
**Devices:** iPhone 16 Simulator (iOS 18.5) — automated; physical iPhone PENDING (required for SC2 hardware-haptic verification)

> **Status:** Plan 05-07 Task 1 (automated audit suite) **COMPLETE**. Plan 05-07 Task 2 (manual SC1-SC5 audit) **AWAITING HUMAN VERIFICATION** — see `## Awaiting Human Verification` at bottom of file.

---

## Automated Gates (Task 1)

All 8 automated gates from `05-07-PLAN.md` Task 1, with raw command output captured.

| Gate | Result | Notes |
|------|--------|-------|
| 1a. FOUND-07 grep — `Color(.…)` literals in P5 files | **PASS** | Zero call-site matches; 3 grep hits are doc-comments forbidding such literals (CellView L22, HeaderBar L17, SettingsView L41) |
| 1b. FOUND-07 grep — hardcoded `padding(N)` / `cornerRadius: N` in `Games/`, `Screens/`, `Core/` | **PASS** | grep exit=1, zero matches |
| 2. VM Foundation-only invariant — `MinesweeperViewModel.swift` + `MinesweeperPhase.swift` | **PASS** | grep exit=1 on both files; no `import SwiftUI/Combine/SwiftData` |
| 3. Single `setCategory` call site | **PASS** | Exactly 1 call site at `Core/SFXPlayer.swift:83` (`try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)`); 2 other matches at L21 + L40 are doc-comments referring to the contract |
| 4. Full test suite green on iPhone 16 (iOS 18.5) | **PASS** | `** TEST SUCCEEDED **` — 11 expected suites all green |
| 5. File-size caps — every P5-touched Swift file < 500 lines (hard cap §8.5) | **PASS** | Largest is `MinesweeperViewModel.swift` at 381 lines; `SettingsView.swift` at 410 lines just over §8.1 ~400 soft cap (plan-anticipated; AcknowledgmentsView already extracted to a sibling file per 05-04 SUMMARY) |
| 6. No Finder-dupe `* 2.swift` files | **PASS** | `find` returned zero results |
| 7. xcstrings catalog integrity | **PASS** (proxy) | `Localizable.xcstrings` parses as valid JSON; 96 total keys; 52 with EN localizations populated; all 7 spot-checked P5 keys present (`Make it yours`, `Sound effects`, `Haptics`, `Skip`, `Continue`, `Done`, `Sync across devices`). 44 keys have empty value (these are auto-extracted bare keys whose source-string IS the EN value — standard xcstrings convention; not "stale"). True stale-entry check still requires Xcode catalog editor open for visual confirmation. |
| 8. Bundle assets present at runtime | **PARTIAL — see CAF blocker below** | AHAP files PRESENT (`Resources/Haptics/win.ahap` + `loss.ahap`); CAF audio files **MISSING** (`Resources/Audio/` has only `LICENSE.md`). Gate 4 HapticsTests passing proves AHAP bundle inclusion. SFXPlayerTests pass because the player no-ops on missing CAFs per the Plan 05-03 D-12 contract (`SFXPlayer.init` is non-throwing under all conditions). |

### Gate 1a — Raw output

```
$ grep -RnE "Color\(\." gamekit/gamekit/Games/Minesweeper/ \
    gamekit/gamekit/Screens/IntroFlowView.swift \
    gamekit/gamekit/Screens/FullThemePickerView.swift \
    gamekit/gamekit/Screens/SettingsView.swift \
    gamekit/gamekit/Screens/RootTabView.swift \
    gamekit/gamekit/Core/Haptics.swift \
    gamekit/gamekit/Core/SFXPlayer.swift
gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift:22://    - Zero Color(...) literals — FOUND-07 pre-commit hook rejects (RESEARCH
gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift:17://    - Zero Color(...) literals (FOUND-07 hook); zero raw integer paddings
gamekit/gamekit/Screens/SettingsView.swift:41://    - Token discipline: zero Color(...) literals; SF Symbols only;
EXIT=0
```

All 3 hits are explicit doc-comment statements forbidding `Color(...)` literals — verifying the rule, not violating it. Zero actual call sites.

### Gate 1b — Raw output

```
$ grep -RnE "padding\(\s*[0-9]+\s*\)|cornerRadius:\s*[0-9]+" gamekit/gamekit/Games/Minesweeper/ gamekit/gamekit/Screens/ gamekit/gamekit/Core/
EXIT=1
```

Zero matches.

### Gate 2 — Raw output

```
$ grep -E "^import (SwiftUI|Combine|SwiftData)" gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift
EXIT=1
$ grep -E "^import (SwiftUI|Combine|SwiftData)" gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
EXIT=1
```

Both files have zero forbidden imports. VM remains Foundation-only despite the P5 phase extension; phase enum stays Foundation-only (Equatable + Sendable, no Codable/Hashable adornments).

### Gate 3 — Raw output

```
$ grep -rn "setCategory" gamekit/gamekit/
gamekit/gamekit/Core/SFXPlayer.swift:21://      verification — `setCategory` should appear in exactly one Swift
gamekit/gamekit/Core/SFXPlayer.swift:40://      adversarial grep confirms no other site touches `setCategory`.
gamekit/gamekit/Core/SFXPlayer.swift:83:            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
```

Exactly 1 actual call site (L83); 2 other hits are doc-comments documenting the invariant. AVAudioSession session category is set exactly once across the codebase.

### Gate 4 — Test suite output (tail)

```
** TEST SUCCEEDED **
Test session results, code coverage, and logs:
    /Users/.../DerivedData/gamekit-.../Logs/Test/Test-gamekit-2026.04.26_20-33-10--0600.xcresult
```

**Suites observed (all green):**

| Suite | Source plan |
|-------|-------------|
| `BoardGeneratorTests` | P2 |
| `RevealEngineTests` | P2 |
| `WinDetectorTests` | P2 |
| `MinesweeperViewModelTests` (8 sub-suites) | P3 + P4 |
| `ModelContainerSmokeTests` | P4 |
| `GameStatsTests` | P4 |
| `StatsExporterTests` | P4 |
| `SettingsStoreFlagsTests` | P5-01 |
| `HapticsTests` | P5-03 |
| `SFXPlayerTests` | P5-03 |
| `MinesweeperPhaseTransitionTests` | P5-06 |
| `gamekitUITests` (`testExample`, `testLaunchPerformance`) | P1 baseline |
| `gamekitUITestsLaunchTests` (`testLaunch` × 4) | P1 baseline |

All required Plan 05-07 acceptance suites green. Total run time on iPhone 16 / iOS 18.5: ~74s for unit suites + ~30s for UI launch perf test.

### Gate 5 — File-size cap output

```
$ wc -l <P5-touched files>
     381 gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift
     116 gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift
     186 gamekit/gamekit/Games/Minesweeper/MinesweeperCellView.swift
     242 gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift
      71 gamekit/gamekit/Games/Minesweeper/MinesweeperPhase.swift
     274 gamekit/gamekit/Screens/IntroFlowView.swift
      38 gamekit/gamekit/Screens/FullThemePickerView.swift
     410 gamekit/gamekit/Screens/SettingsView.swift
      57 gamekit/gamekit/Screens/RootTabView.swift
     127 gamekit/gamekit/Core/Haptics.swift
     184 gamekit/gamekit/Core/SFXPlayer.swift
     135 gamekit/gamekit/Core/SettingsStore.swift
      92 gamekit/gamekit/App/GameKitApp.swift
    2313 total
```

Every file under §8.5 500-line hard cap. `SettingsView.swift` at 410 lines is 10 lines over §8.1 ~400 soft cap — Plan 05-04 SUMMARY documented this; `AcknowledgmentsView` already extracted to sibling `Screens/AcknowledgmentsView.swift` to keep the soft cap close. Largest file: `SettingsView.swift` (410 lines), still well within hard cap.

### Gate 6 — Raw output

```
$ find gamekit/gamekit/ -name "* 2.swift"
EXIT=0  (zero results)
```

No Finder-duplicate Swift files anywhere in the source tree.

### Gate 7 — xcstrings catalog (programmatic spot-check)

```
$ python3 -c "import json; d=json.load(open('Localizable.xcstrings'))"
sourceLanguage=en version=1.0
total_keys=96
en_localized_keys=52
empty_value_keys=44     # bare auto-extracted keys (key IS the EN value per xcstrings convention)
SAMPLE P5 KEYS PRESENT:
  - 'Make it yours'           # IntroFlowView Step 1 title
  - 'Sound effects'           # SettingsView AUDIO section
  - 'Haptics'                 # SettingsView AUDIO section
  - 'Skip'                    # IntroFlowView Skip button
  - 'Continue'                # IntroFlowView Continue button
  - 'Done'                    # IntroFlowView Done button
  - 'Sync across devices'     # IntroFlowView Step 3 title
```

Catalog is well-formed JSON. All 7 spot-checked P5 keys present. The 44 empty-value keys are bare auto-extracted entries (Apple's xcstrings format treats the key itself as the EN value when localizations is empty); this is standard, not "stale." A definitive stale-entry check requires opening the catalog in Xcode's UI editor — defer to Task 2 manual gate.

### Gate 8 — Bundle assets

```
$ ls -la gamekit/gamekit/Resources/Haptics/ gamekit/gamekit/Resources/Audio/
gamekit/gamekit/Resources/Audio/:
-rw-r--r--   1424 LICENSE.md          # Plan 05-02 Task 2 — license stub for future CAFs

gamekit/gamekit/Resources/Haptics/:
-rw-r--r--   1128 loss.ahap           # Plan 05-02 Task 1 — 4-event AHAP (continuous + 2 transients)
-rw-r--r--    883 win.ahap            # Plan 05-02 Task 1 — 3-transient AHAP (ascending arpeggio)
```

**HAPTICS:** Both AHAP files present. HapticsTests `winAhap_existsInBundle` + `lossAhap_existsInBundle` + `winAhap_parsesAsValidCHHapticPattern` + `lossAhap_parsesAsValidCHHapticPattern` PASS in Gate 4 — AHAP bundle inclusion proven by runtime parse.

**SFX (CAF):** ⚠️ **`tap.caf`, `win.caf`, `loss.caf` NOT YET PLACED.** Per `05-02-SUMMARY.md`, Plan 05-02 Task 3 (CAF placement) was deferred at user request — CAF binary audio is creative input requiring user-supplied source files. SFXPlayerTests pass because `SFXPlayer.init` is non-throwing under missing-CAF conditions (Plan 05-03 D-12 / SUMMARY decision); `play(.tap/.win/.loss)` is a silent no-op via optional-chain when the underlying `AVAudioPlayer` is nil. This means **SC2 SFX-related substeps (2.6, 2.7) cannot be fully verified** until CAFs land — see SC2 known gap below.

---

## SC1 — Animation pass (MINES-08 + A11Y-03)

**Status:** PENDING MANUAL VERIFICATION (Task 2 checkpoint)

| Step | Expected | Observed | Screenshot |
|------|----------|----------|------------|
| 1.2 cascade | Per-cell staggered fade from engine-ordered reveal list (D-01); total ≤ `theme.motion.normal` (≤250ms) | _pending user_ | `sc1-cascade.png` _pending_ |
| 1.3 flag spring | `.symbolEffect(.bounce)` on `flag.fill` glyph at long-press commit (D-04) | _pending user_ | `sc1-flag.png` _pending_ |
| 1.4 flag remove spring | `.symbolEffect(.bounce)` replays on second long-press | _pending user_ | _pending_ |
| 1.5 win wash | `theme.colors.success` overlay alpha 0→0.25→0 over `theme.motion.slow` (D-02); end-state DKCard fades in concurrently | _pending user_ | `sc1-win.png` _pending_ |
| 1.6 loss shake | `.keyframeAnimator` 4-keyframe horizontal shake +8 → −8 → +4 → 0 over 400ms (D-03); all mines reveal; incorrectly-flagged X'd; end-state DKCard fades in | _pending user_ | `sc1-loss.png` _pending_ |
| 1.7 cascade Reduce Motion ON | All cells reveal simultaneously, no fade (D-04) | _pending user_ | `sc1-rm-cascade.png` _pending_ |
| 1.8 flag spring Reduce Motion ON | Glyph swap is instant, no bounce (D-04) | _pending user_ | `sc1-rm-flag.png` _pending_ |
| 1.9 win wash Reduce Motion ON | Instant tint at peak, no fade (D-04) | _pending user_ | `sc1-rm-win.png` _pending_ |
| 1.10 loss shake Reduce Motion ON | No shake; `mineHit` overlay just appears (D-04) | _pending user_ | `sc1-rm-loss.png` _pending_ |

---

## SC2 — Haptics + SFX (MINES-09 + MINES-10)

**Status:** PENDING MANUAL VERIFICATION (Task 2 checkpoint) — **partially blocked** by deferred Plan 05-02 Task 3 CAF placement.

| Step | Expected | Observed | Notes |
|------|----------|----------|-------|
| 2.1 tap selection haptic | `.sensoryFeedback(.selection)` fires on each successful reveal (D-07). Hardware required (simulator no-op). | _pending physical device_ | requires real iPhone |
| 2.2 flag impact haptic | `.sensoryFeedback(.impact(weight:.light))` + `.symbolEffect(.bounce)` fire on flag commit (D-07) | _pending physical device_ | requires real iPhone |
| 2.3 win AHAP | `Haptics.playAHAP("win")` fires 3 ascending transients over 0.6s (D-07) | _pending physical device_ | requires real iPhone; AHAP file present in bundle (Gate 4 proof) |
| 2.4 loss AHAP | `Haptics.playAHAP("loss")` fires 0.5s decay + 2 sharp transients (D-07) | _pending physical device_ | requires real iPhone; AHAP file present in bundle (Gate 4 proof) |
| 2.5 Haptics OFF gating | All 4 haptic events silenced; no `.sensoryFeedback` fires; `Haptics.playAHAP` early-returns at gating-at-source D-10 | _pending physical device_ | gating-at-source proven by SFXPlayerTests + HapticsTests; manual sensory verification still needed |
| **2.6 SFX ON — tap/win/loss CAF playback** | `tap.caf` per reveal, `win.caf` on win, `loss.caf` on loss; `AVAudioSession.ambient` does not duck user music (D-09) | ⚠️ **CANNOT VERIFY** | **CAF files not placed** (Plan 05-02 Task 3 deferred). SFXPlayer no-ops silently on missing files per D-12 contract — verification of audible playback requires CAF source files first. |
| **2.7 SFX OFF gating** | All SFX silenced via `sfxEnabled=false` early-return | Partially testable now | Even with CAFs absent, the gating logic is exercised by `SFXPlayerTests/play_disabled_doesNotInvokePlay` (Gate 4 PASS) — but audible verification of "yes I hear nothing" requires CAFs. |

**Known gap (carried over from Plan 05-02 SUMMARY):**

> Plan 05-02 Task 3 — CAF audio placement — deferred at user request. CAF binary audio is creative input requiring source files (16-bit / 44.1 kHz / mono per CONTEXT D-08). SC2 substeps 2.6 + audible-silence in 2.7 cannot be verified until 3 CAFs are placed in `gamekit/gamekit/Resources/Audio/` and `LICENSE.md` Source/License columns are updated. AHAP-side haptic verification (2.1-2.5) is unblocked.

---

## SC3 — Settings spine + intro (SHELL-02 + SHELL-04)

**Status:** PENDING MANUAL VERIFICATION (Task 2 checkpoint)

| Step | Expected | Observed | Screenshot |
|------|----------|----------|------------|
| 3.1 first-launch intro | Fresh install → IntroFlowView appears via `.fullScreenCover` (D-23) | _pending user_ | `sc3-intro-step1.png` _pending_ |
| 3.2 Step 1 layout | "Make it yours" title at `theme.typography.titleLarge`; 5 Classic swatches read-only (D-19); Continue bottom-trailing; Skip top-trailing (D-22) | _pending user_ | `sc3-intro-step1-detail.png` _pending_ |
| 3.3 Step 2 stats card | "Track your progress"; hand-coded sample (Easy 12/8/67%/1:42 ; Medium 5/2/40%/4:15 ; Hard —) (D-20) | _pending user_ | `sc3-intro-step2.png` _pending_ |
| 3.4 Step 3 SIWA card | "Sync across devices"; SIWA button + Skip below in DKCard (D-21); SIWA tap = no-op (or system sheet that dismisses immediately, depending on simulator behavior) | _pending user_ | `sc3-intro-step3.png` _pending_ |
| 3.5 Skip dismisses cover | Tap Skip top-trailing → cover dismisses; tab bar visible (D-22) | _pending user_ | _pending_ |
| 3.6 Cold-relaunch no intro | Relaunch app → intro does NOT show (`hasSeenIntro=true` persisted, D-23) | _pending user_ | _pending_ |
| 3.7 Done dismisses cover | Step 3 Done = same path as Skip; relaunch — no intro (D-22 single source of truth) | _pending user_ | _pending_ |
| 3.8 Settings section order | APPEARANCE → AUDIO → DATA → ABOUT (D-13) | _pending user_ | `sc3-settings-spine.png` _pending_ |
| 3.9 APPEARANCE | 5 Classic swatches inline; "More themes & custom colors" → FullThemePickerView pushes; back-arrow returns | _pending user_ | _pending_ |
| 3.10 AUDIO toggles | Haptics + SFX toggles round-trip persisted across kill/relaunch (D-15) | _pending user_ | _pending_ |
| 3.11 DATA preserved | P4 Export/Import/Reset rows render unchanged; Reset alert opens & cancels (D-16) | _pending user_ | _pending_ |
| 3.12 ABOUT section | Version row "1.0 (1)"; Privacy inline disclosure; Acknowledgments NavigationLink → AcknowledgmentsView with 3 credits (D-17) | _pending user_ | _pending_ |

---

## SC4 — Theme matrix + custom palette (THEME-01 + THEME-03 + A11Y-04)

**Status:** PENDING MANUAL VERIFICATION (Task 2 checkpoint)

### Theme Matrix Audit (6 audit-set presets × at minimum play + loss + 1 win = ~18 screenshots; spec target = 72)

| Preset | Category | Play | Loss | Win | Notes |
|--------|----------|------|------|-----|-------|
| `forest` | Classic | _pending_ `sc4-forest-play.png` | _pending_ `sc4-forest-loss.png` | _pending_ `sc4-forest-win.png` | Default Classic-category baseline |
| `bubblegum` | Sweet | _pending_ | _pending_ | _pending_ | |
| `barbie` | Bright | _pending_ | _pending_ | _pending_ | UI-SPEC line 117 risk: inactive page indicator dot legibility |
| `cream` | Soft | _pending_ | _pending_ | _pending_ | |
| `dracula` | Moody | _pending_ | _pending_ | _pending_ | OLED dim litmus per UI-SPEC §Color |
| `voltage` | Loud | _pending_ | _pending_ | _pending_ | UI-SPEC line 120 risk: success-green vs accent-yellow proximity |

**Per-preset legibility checks (each preset, both play + loss):**
- numbered cells distinct from background
- flag color distinct from mine
- X overlay distinct from cell tile
- end-state DKCard text contrast adequate

### THEME-03 custom palette pipeline (D-25 / D-26)

| Step | Expected | Observed | Screenshot |
|------|----------|----------|------------|
| 4.6 open Custom tab | Settings → APPEARANCE → "More themes & custom colors" → DKThemePicker Custom tab | _pending user_ | _pending_ |
| 4.7 override `accentPrimary` to magenta | ThemeManager.overrides accepts new color | _pending user_ | `sc4-custom-before.png` _pending_ |
| 4.8 verify pipeline reaches Mines | Restart button background tint, mine flag color, header timer color all honor magenta override (UI-SPEC §THEME-03 verification list); numbered cells (gameNumber palette) DO NOT inherit `accentPrimary` per UI-SPEC line 124 | _pending user_ | `sc4-custom-after.png` _pending_ |
| 4.9 reset overrides | Default colors return | _pending user_ | _pending_ |

---

## SC5 — Accessibility (A11Y-01 + A11Y-02 + A11Y-03)

**Status:** PENDING MANUAL VERIFICATION (Task 2 checkpoint)

### Dynamic Type AX5 (D-27 surface list)

| Surface | Scaled cleanly? | Screenshot |
|---------|-----------------|------------|
| HomeView card labels | _pending user_ | `sc5-ax5-home.png` _pending_ |
| Settings rows | _pending user_ | _pending_ |
| StatsView per-difficulty rows | _pending user_ | _pending_ |
| Settings ABOUT (Version / Privacy / Acknowledgments) | _pending user_ | _pending_ |
| IntroFlowView all 3 steps | _pending user_ | _pending_ |
| End-state DKCard title/body | _pending user_ | _pending_ |
| HeaderBar mine counter + timer | _pending user_ | _pending_ |

**Mines grid stays fixed-size at AX5 (D-28 carve-out):** _pending user_

### VoiceOver

| Element | Reads as (expected) | PASS/FAIL |
|---------|---------------------|-----------|
| Cells (unrevealed) | "Unrevealed, row N column M" | _pending user_ |
| Cells (revealed) | "Revealed, X mines adjacent, row N column M" | _pending user_ |
| Cells (flagged) | "Flagged, row N column M" | _pending user_ |
| Restart button | "Restart" | _pending user_ |
| Toolbar difficulty picker | reads sensibly | _pending user_ |
| End-state Restart + Change difficulty | reads sensibly | _pending user_ |
| Settings AUDIO toggles | "Haptics, switch button, on/off" / "Sound effects, switch button, on/off" | _pending user_ |
| Settings NavigationLink rows | reads as a button | _pending user_ |
| IntroFlowView Step 1 on focus | "Step 1 of 3. Make it yours. Pick a theme that fits your mood. ..." | _pending user_ |
| Skip button | "Skip intro" | _pending user_ |
| Continue button | "Continue to next step" | _pending user_ |
| Done button | "Finish intro" | _pending user_ |

### Reduce Motion (overlap with SC1 1.7-1.10)

| Step | Expected | Observed |
|------|----------|----------|
| Win replay with RM ON | Static end-state overlay with NO shake or sweep | _pending user_ |

---

## Gap Log

| ID | SC | Severity | Description | Resolution |
|----|----|----------|-------------|------------|
| G-1 | SC2 (2.6 + audible 2.7) | **major** for SC2 audible verification, **minor** for shipping (silent SFX is acceptable v1 fallback per D-12) | CAF audio files (`tap.caf`, `win.caf`, `loss.caf`) not yet placed in `Resources/Audio/`. SC2 audible SFX verification + ambient-mix-with-music check (D-09) cannot be performed. SFXPlayer no-ops silently per Plan 05-03 D-12 contract. | **Defer with rationale**: per Plan 05-02 SUMMARY, CAF placement is a `human-action` gate (creative input). When the user supplies the 3 CAFs (16-bit / 44.1 kHz / mono per D-08): drop into `gamekit/gamekit/Resources/Audio/`, update `LICENSE.md` columns, re-run Gate 4 (auto-unskips the `.disabled(if: …)`-guarded SFXPlayerTests file-presence assertion per Plan 05-03 SUMMARY), then re-run SC2 manual substeps 2.6 + 2.7. No code change required — synchronized root group auto-registers. |
| G-2 | SC1-SC5 | **blocker** for sign-off | Manual SC1-SC5 audit not yet performed (this is Plan 05-07 Task 2 — the human-verify checkpoint itself) | **Resume signal:** user runs the SC1-SC5 audit per `05-07-PLAN.md` Task 2 instructions, fills the `_pending user_` cells, attaches screenshots, then types the resume signal per `<resume-signal>` block. |
| G-3 | Gate 7 (xcstrings stale check) | **minor** | Programmatic JSON check confirms catalog is well-formed and all 7 spot-checked P5 keys present, but a true "no stale entries" pass requires opening `Resources/Localizable.xcstrings` in Xcode's catalog editor and visually scanning the State column for any orange "Stale" badges. | Defer to Task 2 manual gate — bundled into SC3 verification flow (user has Settings open anyway). |

---

## Awaiting Human Verification

This file is a **draft** populated with Task 1 (automated audit) results only. To complete this verification report, the user must:

1. Build + install the app on **iPhone 16 simulator** (Xcode → Product → Run, or `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'`).
2. Build + install on a **physical iPhone** (haptics require hardware per Apple docs — simulator AHAP playback is a no-op).
3. Walk through SC1-SC5 substeps in order per `05-07-PLAN.md` `<how-to-verify>` block. Take a screenshot at every numbered step.
4. Fill the `_pending user_` cells in this file with observed-vs-expected. Attach or path-record screenshots into a sibling `.planning/phases/05-polish/screenshots/` folder (or wherever the user prefers).
5. Update Gap Log with any new findings discovered during the manual sweep.
6. Add a Sign-off line.
7. Per `<resume-signal>`:
   - All gaps MINOR / deferred → type "**ship phase 5**" — orchestrator marks ROADMAP P5 complete.
   - Any MAJOR gaps → type "**gaps found — running --gaps**" — orchestrator invokes `/gsd-plan-phase --gaps` to author closure plans.

---

## Sign-off

_Pending user verification of SC1-SC5 manual substeps._
