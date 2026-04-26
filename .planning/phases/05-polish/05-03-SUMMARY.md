---
phase: 05-polish
plan: 03
subsystem: haptics-audio-services
tags: [haptics, sfx, avaudio, corehaptics, environment-key, tdd, gating-at-source]
dependency_graph:
  requires:
    - "Foundation"
    - "CoreHaptics (CHHapticEngine + CHHapticPattern)"
    - "AVFoundation (AVAudioPlayer + AVAudioSession)"
    - "SwiftUI (EnvironmentKey + EnvironmentValues — for SFXPlayer injection seam)"
    - "Core/SettingsStore.swift (P5-01 baseline — hapticsEnabled / sfxEnabled flags consumed by callers, not by these services)"
    - "Core/GameStats.swift (analog — os.Logger + privacy: .public + @MainActor pattern)"
    - "Resources/Haptics/{win,loss}.ahap (P5-02 deliverables — AHAP file presence asserted)"
  provides:
    - "Haptics.playAHAP(named:hapticsEnabled:) — single static surface for AHAP playback"
    - "SFXPlayer.play(_:sfxEnabled:) — preloaded AVAudioPlayer per SFXEvent (.tap/.win/.loss)"
    - "EnvironmentValues.sfxPlayer — @Environment(\\.sfxPlayer) injection seam"
    - "@State sfxPlayer wired into GameKitApp.init() and injected on RootTabView"
  affects:
    - "Plan 05-06 — MinesweeperGameView fires Haptics.playAHAP + sfxPlayer.play in .onChange(of: vm.phase) — both gated at source with the SettingsStore flag passed explicitly"
    - "Plan 05-04 — SettingsView AUDIO section toggles hapticsEnabled / sfxEnabled, which flow through these services with no additional plumbing"
    - "Future: any new game (Merge, Word Grid, Sudoku, etc.) inherits the same Haptics + SFXPlayer surface — no per-game audio architecture needed"
tech-stack:
  added:
    - "CoreHaptics (first use in repo — AHAP playback via CHHapticEngine)"
    - "AVFoundation (first use in repo — AVAudioPlayer + AVAudioSession.ambient)"
  patterns:
    - "Gating-at-source (CONTEXT D-10): hapticsEnabled / sfxEnabled is the FIRST guard inside the service method; call sites pass settingsStore.{flag} explicitly, services have NO SettingsStore coupling"
    - "Non-fatal failure (CONTEXT D-11/D-12): missing file / decode error / engine error all log via os.Logger with privacy: .public on system error; init NEVER throws even when binary assets are absent"
    - "Single shared CHHapticEngine via lazy ensureEngine() + reset/stoppedHandler clears cache so next call re-initializes (CONTEXT D-11)"
    - "AVAudioSession.ambient set ONCE in SFXPlayer.init() — adversarial grep gate verifies no other site touches setCategory (CONTEXT D-09 + threat T-05-07)"
    - "EnvironmentKey injection mirroring Core/SettingsStore.swift:124-135 — @MainActor static let defaultValue + extension EnvironmentValues"
    - "TDD plan-level RED→GREEN gate (test commit precedes feat commit in git log for both Haptics and SFXPlayer)"
    - "#if DEBUG test seam: production callers see only the gated public API; tests get hasInitializedEngineForTesting + lastInvocationAttempt + lastPlayedEvent + preloadedTap/Win/Loss accessors"
    - "Swift Testing .disabled(if: condition, 'reason') trait for deferred-asset gating (CAF files not yet shipped — auto un-skips when 05-02 Task 3 lands)"
key-files:
  created:
    - "gamekit/gamekit/Core/Haptics.swift"
    - "gamekit/gamekit/Core/SFXPlayer.swift"
    - "gamekit/gamekitTests/Core/HapticsTests.swift"
    - "gamekit/gamekitTests/Core/SFXPlayerTests.swift"
  modified:
    - "gamekit/gamekit/App/GameKitApp.swift"
decisions:
  - "Haptics is @MainActor enum (NOT class) per CONTEXT D-11 — static methods only, no instance, no env-key injection. Call sites use Haptics.playAHAP(...) directly without environment lookup."
  - "SFXPlayer is @MainActor final class injected via custom EnvironmentKey — mirrors Core/SettingsStore.swift:124-135 pattern; @Environment(\\.sfxPlayer) in views (Plan 05-06)."
  - "Test seam pattern: lastInvocationAttempt set BEFORE the gate (records every call), lastPlayedEvent set ONLY AFTER the gate passes — distinguishes 'method called with disabled' from 'method never called', proves D-10 contract directly."
  - "init non-throwing under all conditions (CAFs missing OR present): missing CAFs → players become nil → play(...) is a no-op via optional-chain. Critical because Plan 05-02 Task 3 (CAF binaries) is deferred and SFXPlayer must construct cleanly so GameKitApp.init() does not crash on app launch."
  - "Swift Testing .disabled(if: Bundle.main.url(...) == nil, 'TODO(05-02-CAF)...') gates the file-presence assertion — auto un-skips when CAF files land. Cleaner than try #require which would fail the test."
  - "AVAudioSession.setCategory called inside do/catch with local Logger (Logger pre-self.logger isn't usable until all stored properties are set) — non-fatal per D-11/D-12. Failure logged with privacy: .public matching Core/GameStats.swift:92 precedent."
  - "SFXPlayer EnvironmentKey defaultValue = SFXPlayer() means a default no-op instance exists when no environment injection is present (e.g. previews) — graceful degradation matches SettingsStore EnvironmentKey pattern."
  - "GameKitApp.swift edit purely additive: @State sfxPlayer + 2-line init block (sfx construction + state binding) + 1-line .environment modifier — P4 themeManager / settingsStore / ModelContainer wiring preserved verbatim, diff is 8 lines net."
metrics:
  duration_minutes: 12
  completed_date: 2026-04-26
  total_lines_added: 528
  files_created: 4
  files_modified: 1
  tests_added: 11
  tests_passing: 10
  tests_skipped: 1
---

# Phase 5 Plan 03: Haptics + SFXPlayer Service Layer Summary

Wave 2 of P5 ships the differentiator-defining audio + haptic service layer: a `@MainActor enum Haptics` for CoreHaptics AHAP playback and a `@MainActor final class SFXPlayer` for preloaded AVAudioPlayer SFX, both gated at the source on their respective SettingsStore flags. SFXPlayer is wired into `GameKitApp.init()` via a custom EnvironmentKey mirroring the Plan 04 `SettingsStore` injection pattern. All 11 Swift Testing assertions execute against missing-CAF and missing-AHAP edge cases — services are correct by construction even before Plan 05-02 Task 3 (CAF binaries) lands.

## Files

| File | Type | Lines | Purpose |
| ---- | ---- | -----:| ------- |
| `gamekit/gamekit/Core/Haptics.swift` | NEW | 127 | `@MainActor enum Haptics` — `playAHAP(named:hapticsEnabled:)` static method; lazy CHHapticEngine + reset/stoppedHandler; non-fatal failure via `os.Logger(category: "haptics")` |
| `gamekit/gamekit/Core/SFXPlayer.swift` | NEW | 184 | `@MainActor final class SFXPlayer` — 3 preloaded `AVAudioPlayer?` (tap/win/loss); `AVAudioSession.ambient` once in init; `EnvironmentKey` injection seam |
| `gamekit/gamekit/App/GameKitApp.swift` | EDIT (additive) | 92 (was 84) | `@State private var sfxPlayer: SFXPlayer` + `init()` construction after `SettingsStore` (D-12) + `.environment(\.sfxPlayer, sfxPlayer)` modifier on `RootTabView` |
| `gamekit/gamekitTests/Core/HapticsTests.swift` | NEW | 94 | Swift Testing suite, 6 `@Test` cases — file presence × 2, CHHapticPattern parseability × 2, D-10 gate, non-fatal failure path |
| `gamekit/gamekitTests/Core/SFXPlayerTests.swift` | NEW | 115 | Swift Testing suite, 5 `@Test` cases — init non-throwing, preload (CAF-gated skip), `.ambient` session, D-10 gating disabled+enabled |

**Total:** 528 net lines added across 4 new files + 8-line additive edit to `App/GameKitApp.swift`.

## Commits (in TDD order)

| Step | Hash | Message |
| ---- | ---- | ------- |
| Task 1 RED | `bf38819` | `test(05-03): add failing HapticsTests for file presence + parseability + gating` |
| Task 1 GREEN | `695f753` | `feat(05-03): implement Haptics service with lazy CHHapticEngine and gating-at-source` |
| Task 2 RED | `a7fa1ec` | `test(05-03): add failing SFXPlayerTests for init / preload / gating / .ambient session` |
| Task 2 GREEN | `a2116a6` | `feat(05-03): implement SFXPlayer service + wire into GameKitApp via EnvironmentKey` |

**TDD gate compliance:** RED commits `bf38819` and `a7fa1ec` precede their corresponding GREEN commits `695f753` and `a2116a6` in `git log --oneline`. Verified.

## Test Results

### HapticsTests — 6/6 passing

| Test | Covers |
| ---- | ------ |
| `winAhap_existsInBundle` | Plan 05-02 win.ahap auto-registered via PBXFileSystemSynchronizedRootGroup |
| `lossAhap_existsInBundle` | Plan 05-02 loss.ahap auto-registered |
| `winAhap_parsesAsValidCHHapticPattern` | win.ahap JSON is valid CoreHaptics format (CHHapticPattern parses without throwing) |
| `lossAhap_parsesAsValidCHHapticPattern` | loss.ahap JSON valid |
| `playAHAP_disabled_doesNotInitializeEngine` | **D-10 source-gate proof** — engine remains nil after `playAHAP(... hapticsEnabled: false)` |
| `playAHAP_missingFile_doesNotCrash` | **D-11 non-fatal failure proof** — playAHAP with nonexistent filename returns cleanly, no crash |

### SFXPlayerTests — 4/5 passing + 1 deferred-skip

| Test | Status | Covers |
| ---- | ------ | ------ |
| `init_doesNotThrow` | passed | Init non-throwing under all conditions (CAFs missing OR present) — critical because Plan 05-02 Task 3 deferred |
| `init_preloadsAllThreeAVAudioPlayers` | **skipped** | CAF-presence assertion gated via `.disabled(if: Bundle.main.url(... == nil, "TODO(05-02-CAF)...")` — auto un-skips when CAFs land |
| `init_setsAVAudioSessionCategoryToAmbient` | passed | **CONTEXT D-09 proof** — `AVAudioSession.sharedInstance().category == .ambient` after init |
| `play_disabled_doesNotInvokePlay` | passed | **D-10 source-gate proof** — `lastInvocationAttempt` recorded but `lastPlayedEvent` remains nil after disabled call |
| `play_enabled_invokesPlay` | passed | **D-10 gate-pass proof** — `lastPlayedEvent == .win` after `play(.win, sfxEnabled: true)` |

### Full regression suite — `** TEST SUCCEEDED **`

All P3 (MinesweeperViewModelTests + 4 sub-suites), P4 (GameStatsTests + StatsExporterTests + ModelContainerSmokeTests + InMemoryStatsContainer), and P5-01 (SettingsStoreFlagsTests) green. UI tests + launch-perf tests also green.

## Confirmation: AVAudioSession.ambient is set ONCE and ONLY ONCE

```
$ grep -rn "setCategory" gamekit/gamekit/
gamekit/gamekit/Core/SFXPlayer.swift:21://      verification — `setCategory` should appear in exactly one Swift
gamekit/gamekit/Core/SFXPlayer.swift:40://      adversarial grep confirms no other site touches `setCategory`.
gamekit/gamekit/Core/SFXPlayer.swift:83:            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
```

One actual call site (line 83 of SFXPlayer.swift); the two other matches are doc-comment references inside the same file documenting the invariant. Threat T-05-07 (Audio session category drift) is mitigated by construction.

## Locked Call-Site Contract for Plan 05-06

`MinesweeperGameView` (Plan 05-06) MUST fire haptics + SFX with this exact shape:

```swift
.onChange(of: viewModel.phase) { _, newPhase in
    switch newPhase {
    case .winSweep:
        Haptics.playAHAP(named: "win", hapticsEnabled: settingsStore.hapticsEnabled)
        sfxPlayer.play(.win, sfxEnabled: settingsStore.sfxEnabled)
    case .lossShake:
        Haptics.playAHAP(named: "loss", hapticsEnabled: settingsStore.hapticsEnabled)
        sfxPlayer.play(.loss, sfxEnabled: settingsStore.sfxEnabled)
    case .revealing:
        sfxPlayer.play(.tap, sfxEnabled: settingsStore.sfxEnabled)
    case .idle, .flagging:
        break  // flag/tap haptic uses .sensoryFeedback at the cell view per CONTEXT D-07
    }
}
```

**Both gated at the source with the SettingsStore flag passed explicitly** — no view-layer plumbing of conditional logic, no service-layer SettingsStore coupling. The contract surface is the `(named:hapticsEnabled:)` and `(_:sfxEnabled:)` parameter shapes; renaming = breaking change for the whole phase.

Required environment values at MinesweeperGameView:
- `@Environment(\.settingsStore) private var settingsStore` (P4 baseline)
- `@Environment(\.sfxPlayer) private var sfxPlayer` (P5-03 — this plan)

`Haptics` requires no environment lookup — it's a `@MainActor enum` with static methods.

## Test-Seam Choices (#if DEBUG — non-production-touching)

These accessors are visible ONLY via `@testable import gamekit` and do NOT alter the production API surface:

### Haptics
- `internal static func resetForTesting()` — clears cached `engine` so each test starts from a known state. Called explicitly at the top of `playAHAP_disabled_doesNotInitializeEngine` to make the assertion order-independent.
- `internal static var hasInitializedEngineForTesting: Bool { engine != nil }` — used by the same test to assert the gate fires before engine construction.

### SFXPlayer
- `internal var lastInvocationAttempt: (event: SFXEvent, enabled: Bool)?` — set BEFORE the D-10 gate inside `play(_:sfxEnabled:)`; tests assert the method was called at all.
- `internal var lastPlayedEvent: SFXEvent?` — set ONLY AFTER the D-10 gate passes; tests assert the gate was respected.
- `internal var preloadedTap/Win/Loss: AVAudioPlayer?` — exposes the optional players for the (currently skipped) file-presence assertion.

All 5 accessors are wrapped in `#if DEBUG` so production builds (Release configuration) do not include them. Production callers see only `Haptics.playAHAP(named:hapticsEnabled:)` and `SFXPlayer.play(_:sfxEnabled:)`.

## Deviations from Plan

None — plan executed exactly as written, with one cleaner-than-spec'd refinement noted below.

**Refinement (within action's stated bounds):** Plan 05-03 Task 1 STEP B suggests a single `internal static var hasInitializedEngineForTesting` accessor. The implementation also adds `internal static func resetForTesting()` so the gating test is order-independent regardless of which test ran before it. The plan notes "Use an `internal static var hasInitializedEngineForTesting: Bool { engine != nil }` accessor" — adding `resetForTesting()` is a strict superset that satisfies the contract more robustly without changing the production surface. Documented here so the planner sees the precise test-seam shape.

## Authentication Gates

None — plan was fully autonomous. CAF deferral handled via Swift Testing `.disabled(if:_:)` trait (compile-time) rather than as a checkpoint, since the user's objective explicitly instructed to handle missing CAFs by skipping the dependent assertion and proceeding.

## Planner-Discretion Choices (within action's stated bounds)

1. **`Haptics.resetForTesting()` test seam** — adds a `resetForTesting()` static func alongside the spec'd `hasInitializedEngineForTesting` accessor; makes the gating test order-independent. Both are `#if DEBUG`-gated.
2. **SFXPlayer test seam ordering** — implementation sets `lastInvocationAttempt` BEFORE the gate (matches plan's "set BEFORE the gate" recommendation) and `lastPlayedEvent` AFTER the gate (matches plan's "the cleaner contract" alternative). Both seams kept; the dual-seam pattern proves the gate fires at the exact right boundary.
3. **CAF-presence skip wording** — `.disabled(if:_:)` reason string is `"TODO(05-02-CAF): un-skip when tap/win/loss CAF files land in Resources/Audio/ (deferred per 05-02 SUMMARY)"` — references the SUMMARY artifact directly so the deferral provenance is discoverable without reading the test source.
4. **Logger pre-self pattern in SFXPlayer.init** — `setCategory` is called BEFORE all stored properties are set (it doesn't depend on player construction). Apple's actor-isolation rules mean `self.logger` isn't accessible until init completes, so the early-init logger uses a locally-constructed `Logger(subsystem:category:)` matching `self.logger`'s configuration verbatim. Same pattern in `Self.makePlayer(name:)` static helper.
5. **GameKitApp.swift edit minimization** — the `.environment(\.sfxPlayer, ...)` modifier is placed BETWEEN `.environment(\.settingsStore, ...)` and `.preferredColorScheme(...)` so the diff is a single contiguous addition (no interleaving with unrelated lines).

## Self-Check: PASSED

**Files claimed created:**
- `gamekit/gamekit/Core/Haptics.swift` → FOUND (127 lines)
- `gamekit/gamekit/Core/SFXPlayer.swift` → FOUND (184 lines)
- `gamekit/gamekitTests/Core/HapticsTests.swift` → FOUND (94 lines)
- `gamekit/gamekitTests/Core/SFXPlayerTests.swift` → FOUND (115 lines)

**Files claimed modified:**
- `gamekit/gamekit/App/GameKitApp.swift` → FOUND (92 lines, was 84 — additive only, P4 wiring preserved)

**Commits claimed exist:**
- `bf38819` (Task 1 RED test) → FOUND in `git log --oneline`
- `695f753` (Task 1 GREEN feat) → FOUND in `git log --oneline`
- `a7fa1ec` (Task 2 RED test) → FOUND in `git log --oneline`
- `a2116a6` (Task 2 GREEN feat) → FOUND in `git log --oneline`

**TDD gate compliance:** RED `bf38819` precedes GREEN `695f753`; RED `a7fa1ec` precedes GREEN `a2116a6`. Both pairs verified in `git log --oneline`.

**Test results:** HapticsTests 6/6 pass; SFXPlayerTests 4/5 pass + 1 skipped (CAF-deferred); full regression suite `** TEST SUCCEEDED **`.

**Adversarial grep:** `grep -rn "setCategory" gamekit/gamekit/` returns 1 actual call site (Core/SFXPlayer.swift:83) + 2 doc-comment references inside the same file. Threat T-05-07 mitigated by construction.

## TDD Gate Compliance

Plan 05-03's two `type="auto" tdd="true"` tasks both followed the strict RED→GREEN sequence:

- **Task 1 (Haptics):** Test commit `bf38819` added `HapticsTests.swift` referencing `Haptics` (not yet defined) → build fail "Cannot find 'Haptics' in scope" → feat commit `695f753` added `Core/Haptics.swift` → tests pass 6/6.
- **Task 2 (SFXPlayer):** Test commit `a7fa1ec` added `SFXPlayerTests.swift` referencing `SFXPlayer` (not yet defined) → build fail "Cannot find 'SFXPlayer' in scope" → feat commit `a2116a6` added `Core/SFXPlayer.swift` + edited `App/GameKitApp.swift` → tests pass 4/5 + 1 skipped.

Both pairs visible in `git log --oneline -8`. No REFACTOR commits needed — implementations were already minimal (127 + 184 lines, well under CLAUDE.md §8.5 cap).
