# Project Research Summary

**Project:** GameKit
**Domain:** iOS suite of classic logic games (MVP = Minesweeper only) — local-first, optional CloudKit sync, DesignKit-themed, ad-free, no-telemetry, "calm and premium" product posture
**Researched:** 2026-04-24
**Confidence:** HIGH

## Executive Summary

GameKit is a single-game-at-MVP iOS app built on the Apple-canonical Swift 6 / SwiftUI / SwiftData stack with optional CloudKit private-DB mirroring and Sign in with Apple — consumed against a local SPM dependency on the sibling `DesignKit` package. The four research streams converge unusually tightly: every researcher independently arrives at the same five load-bearing rules — (1) pure-value-type engines + `@Observable` `@MainActor` view models + dumb views, (2) one shared SwiftData container whose schema is CloudKit-compatible from day one regardless of when CloudKit actually turns on, (3) game-agnostic persistence with a `gameKind` discriminator (not per-game models), (4) DesignKit token purity with no hardcoded colors, radii, or spacing in `Games/` or `Screens/`, and (5) build engines before UI before persistence before polish before CloudKit before release. There is essentially no architectural ambiguity in the corpus.

The risk surface is concentrated in four named places, and three of them are designable-around-once: SwiftData↔CloudKit schema constraints (no `@Attribute(.unique)`, all properties optional/defaulted, all relationships optional — must be obeyed from PERSIST-01 even though CloudKit only turns on at PERSIST-04), Sign in with Apple credential lifecycle (revocation observer + `getCredentialState` on scene-active, plus the anonymous→signed-in container promotion which is the single trickiest UX path in the project), tap/long-press gesture composition (must be `LongPressGesture(0.25s).exclusively(before: TapGesture())` — naive composition produces TestFlight-grade bug reports), and theme legibility across 34 DesignKit presets (Mines's informational number palette — the 1-blue/2-green/3-red Microsoft scheme — needs a dedicated `theme.colors.gameNumber(_:)` token added to DesignKit, not local hand-picks).

The recommended approach is the seven-phase build order that the architecture and pitfalls research independently proposed identical sequencing for: **Foundation → Mines Engines → Mines UI → Stats & Persistence → Polish → CloudKit + Sign in with Apple → Release**. Each phase is a clean shippable boundary; CloudKit deliberately lands *after* the gameplay loop is polish-quality so a sync hiccup never blocks the differentiator-defining cut. The "calm, premium, ad-free, no-telemetry" product posture in PROJECT.md is preserved by zero third-party dependencies (other than DesignKit local SPM), CloudKit-only network surface, and a permanent ban on analytics SDKs.

## Key Findings

### Recommended Stack

The stack is fully Apple-native, zero third-party SDKs beyond DesignKit (local SPM at `../DesignKit`), and intentionally constrained — every choice protects the privacy/calm posture as much as it serves the engineering.

**Core technologies:**
- **Swift 6 (strict concurrency ON)** — non-negotiable for the `@MainActor` SwiftData/CloudKit/SIWA boundary; `@Observable @MainActor` view models, pure `Sendable` value-type engines, no `@unchecked Sendable`, no premature `@ModelActor`
- **SwiftUI (iOS 17 baseline)** — `phaseAnimator` (win-board sweep), `keyframeAnimator` (loss-shake), `.sensoryFeedback` (haptics primary surface), `.symbolEffect(.bounce)` (flag spring), `LazyVGrid`/`Grid` for the board (NOT `Canvas` — loses per-cell accessibility)
- **SwiftData with `ModelConfiguration(cloudKitDatabase: …)`** — single shared container; ships with `.none` until PERSIST-04, swaps to `.private("iCloud.com.lauterstar.gamekit")` once Sign in with Apple lands; schema must be CloudKit-compatible from day 1
- **CloudKit (private DB only)** — built-in SwiftData mirror (NOT `CKSyncEngine`); no public/shared scope ever; one-tap "Restart to enable" UX after sign-in (hot-swap is MEDIUM confidence; launch-only swap is HIGH)
- **AuthenticationServices (`SignInWithAppleButton`)** — `request.requestedScopes = []` (no name/email needed, just the user identifier in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); `getCredentialState` on every scene-active + `credentialRevokedNotification` observer
- **CoreHaptics + SwiftUI `.sensoryFeedback`** — `.sensoryFeedback` for 90% of cues; CoreHaptics + 2 `.ahap` files for the win arpeggio and loss rumble only
- **AVFoundation `AVAudioPlayer` (preloaded with `prepareToPlay()`)** — `.m4a`, `AVAudioSession.ambient` (does not duck user music), off by default per MINES-10, NOT `AudioServicesPlaySystemSoundID`
- **Swift Testing (`@Test` / `#expect`)** — pure-engine sweet spot, parameterized over difficulty, parallel-by-default; XCTest retained for `XCUIApplication` and `measure` blocks only
- **String Catalogs (`Localizable.xcstrings`)** — `String(localized:)` everywhere from day 1; "Use Compiler to Extract Swift Strings" build setting ON; EN-only ship, future locales mechanical
- **DesignKit (local SPM at `../DesignKit`)** — tokens only (`theme.colors.*`, `theme.radii.*`, `theme.motion.*`, `theme.typography.*`); `DKCard`, `DKButton`, `DKThemePicker`, `DKBadge`, `DKSectionHeader` consumed; new `DKHaptics`-style abstractions stay local until a second game needs them, then promote

See `STACK.md` for the full TL;DR decision wall, version compatibility matrix, and the alternatives-considered table.

### Expected Features

The MVP scope in PROJECT.md is *already* a tight, opinionated cut — the feature researcher confirmed it covers all genuine table stakes and concentrates the differentiator surface where the product posture says it should.

**Must have (table stakes — users penalize absence, give no credit for presence):**
- Three classic difficulties (9×9/10, 16×16/40, 16×30/99) — Microsoft-original muscle memory
- Tap to reveal, long-press to flag, first-tap safety (cell + 8 neighbors), flood-fill on empty cells
- Mine counter (remaining = total − flagged), elapsed timer, in-game restart
- Win/loss overlays with reveal-mine-on-loss + incorrect-flag indicators
- Best time / games played / wins / win % per difficulty, persistent across force-quit/crash/reboot
- Recognizable adjacency-number colors (the 1-blue/2-green/3-red mnemonic) on every preset
- Settings spine: theme picker + haptics toggle + SFX toggle + reset stats + about

**Should have (the differentiator surface — this is where GameKit wins):**
- **Zero ads / coins / energy / pushy subs** — the single biggest differentiator vs the App Store's freemium Minesweeper field; literal work avoidance
- **34-preset DesignKit theming** — no surveyed competitor offers anything close (most ship 3–6 fixed skins)
- **Custom number-color palette** — accessibility win + power-user surface; trivial extension on top of DesignKit tokens
- **Polished animations** (reveal cascade, flag spring, win sweep, loss shake) timed via `theme.motion.{fast,normal,slow}`
- **First-class haptics + SFX off by default** — calm-by-default, premium feel
- **3-step intro then never again** — competitors either skip onboarding (confusing) or pop tutorials repeatedly
- **Optional Sign in with Apple + CloudKit** — full feature parity without sign-in; cross-device for those who want it
- **Export/Import JSON of stats** — user-owned data, no surveyed competitor offers this
- **No telemetry, no phone home** — privacy posture as competitive surface
- **Color-blind-safe number palette default verification** (proposed new A11Y-04) — 30-min win using Wong-palette principles
- **Reduce Motion + Dynamic Type + VoiceOver labels** — competitors rarely respect these

**Defer (v1.1 — earned by TestFlight stability):**
- No-guess board generator (HIGH algorithmic complexity, 0–20s SAT/CSP solving — needs a perf spike before scoping)
- Chord (double-tap to reveal neighbors when flagged correctly)
- 3BV / 3BV/s in stats screen (engine must compute at win-time)
- Win-rate trend chart, time-distribution histogram (Swift Charts via DesignKit)
- Color-blind named preset(s) (Wong / IBM palettes)
- Question-mark cell state (opt-in, off by default)

**Defer (v2+ — earned by real user demand):**
- Daily seed / daily challenge, share card, daily-seed widget, streak counter (neutral display only)
- App Shortcuts ("Start Easy game", "Continue last")
- Custom board sizes, pinch-to-zoom on Hard
- Hint system / undo (gated to no-guess mode, time-penalty model)
- Achievements derived from stats (no popups)
- Localizations beyond EN

**Anti-features (permanent NEVER list — refused on principle, documented in PROJECT.md Out of Scope):**
- Banner / interstitial / video ads
- Aggressive subscription paywalls
- Coins / fake currency / power-ups / energy / hearts
- Required accounts / forced sign-in
- Streak-shaming, push notifications nagging return, pop-up rate-this-app modals
- Analytics SDKs / telemetry / phone-home

See `FEATURES.md` for the full prioritization matrix, competitor-by-competitor analysis, and feature dependency graph.

### Architecture Approach

Vertical slice through five layers — App shell → Screens → Games/Minesweeper → Core → DesignKit dep — with a deliberate stay-out-of list around premature abstraction (no `GameProtocol` until game 3, no per-game `@Model`s, no runtime game registry, no TCA, no `AnimationCoordinator`). The folder layout in PROJECT.md is correct as written; the only refinement is putting Mines engines in `Games/Minesweeper/Engine/` so the engine-vs-UI line is visible at folder level.

**Major components:**
1. **`GameKitApp` (App/)** — single `@main`, owns `ThemeManager` (`@StateObject`), constructs the shared `ModelContainer` with `cloudKitDatabase` based on `SettingsStore.cloudSyncEnabled`, injects both into the environment. Knows nothing about games.
2. **Screens/ (cross-game shells)** — `HomeView` (game-card grid, Mines is the only enabled card), `SettingsView` (theme picker + toggles + reset + about + sign-in card), `StatsView` (`@Query` filtered by `gameKindRaw == "minesweeper"`), `IntroFlowView` (3-step first-launch).
3. **Games/Minesweeper/** — `MinesweeperView` (dumb render), `MinesweeperViewModel` (`@Observable @MainActor`, owns `board`/`state`/`phase` enum, calls pure engines, on terminal state writes via injected `GameStats`), and `Engine/` containing pure-struct `BoardGenerator` / `RevealEngine` / `WinDetector` that import only Foundation.
4. **Core/ (cross-game services)** — `GameKind` enum (single source of truth for game IDs), `GameRecord`/`BestTime` `@Model`s with `gameKindRaw` discriminator (CloudKit-compatible: all optional or defaulted, no `.unique`), `GameStats.record(...)` (single SwiftData write seam — view models never see `ModelContext`), `SettingsStore` (`@Observable` over UserDefaults), optional `ThemeStore` (DesignKit `ThemeStorage` bridge).
5. **Persistence layer** — single shared `ModelContainer`, schema `[GameRecord, BestTime]`, configuration toggles between `cloudKitDatabase: .none` (P1–P3) and `.private("iCloud.com.lauterstar.gamekit")` (P4+). Same store path in both modes — flipping the flag promotes existing local rows into the CloudKit-mirrored store with no migration code.

Five canonical patterns underwrite the architecture: (1) **Pure Engine + Observable ViewModel + Dumb View** (the constitutional three-tier separation), (2) **Game-agnostic SwiftData schema with `gameKind` discriminator** (one model per stat type, not per game), (3) **Phase enum on the VM for animation orchestration** (`.idle / .revealing(cells) / .flagToggling / .winSweep / .lossShake`), (4) **`ThemeManager` via `@EnvironmentObject` — no prop-drilling**, (5) **Conditional CloudKit via `ModelConfiguration` swap at app boot** with one-tap restart UX.

See `ARCHITECTURE.md` for the full system diagram, component responsibilities, the seven anti-patterns to avoid, and the integration-point boundary table.

### Critical Pitfalls

The pitfalls research identified 14 named traps; the five below are the load-bearing ones — get these wrong and the project ships a P0 bug. Detailed prevention/recovery for each lives in `PITFALLS.md`.

1. **First-tap safety must exclude tapped cell + 8 bounds-clamped neighbors, never loop "until tap is a 0".** Naive corner-tap implementations crash on out-of-bounds neighbor indices or hang on Hard mode (~21% mine density). Ship three deterministic unit tests with the engine: Easy corner tap, Hard corner tap, Hard center tap — assert mine-free safe set + exact mine count. **Phase: P2 (Mines Engines).** P0 per CLAUDE.md §8.11.
2. **SwiftData models that ship with `@Attribute(.unique)`, non-optional fields, or required relationships will crash `ModelContainer` init the day CloudKit turns on at P4.** The constraints are not enforced at compile time — they surface only when `cloudKitDatabase: .private(...)` is set. Mitigation: design models for CloudKit constraints from day 1 (P1) and add a smoke test that constructs a container with the CloudKit config even before sync is enabled. **Phase: P1 design / P4 verify.**
3. **Anonymous→signed-in container promotion is the trickiest UX path and naive implementations lose local stats.** Constructing a *different* `ModelContainer` URL when the user signs in orphans the local SQLite store; user with a 0:42 Easy best time signs in to "back up" and sees "—". Mitigation: same store path in both modes; CloudKit mirroring is a no-op without iCloud and turns on with no migration code. Confidence on hot-swap is MEDIUM; **launch-only swap with a "Restart to enable iCloud sync" dialog is the bulletproof path.** **Phase: P4.**
4. **Tap and long-press gesture composition fails in three common ways unless explicit.** `.onTapGesture { … }.onLongPressGesture { … }` produces TestFlight reports of "tapped a cell, it flagged instead." Use a single composed gesture: `LongPressGesture(minimumDuration: 0.25).exclusively(before: TapGesture())` attached via `.gesture(...)`, with both handlers no-op-ing on revealed cells, and a haptic at the 0.25s commit threshold. Test on iPhone SE / 11 (older touch latency feel). **Phase: P2 wire / P3 tune.**
5. **DesignKit token discipline must be enforced from P1, not retrofit at P3.** Every `Color(...)` literal, hardcoded `cornerRadius: <int>`, or hand-picked grey "just for the cell grid" eventually breaks legibility on at least one of 34 presets. Pre-commit grep that fails on `Color(`, `cornerRadius:\s*\d+`, `padding(\s*\d+` in `Games/` or `Screens/`. When a token is missing (e.g., Mines's informational number palette 1–8), **add it to DesignKit** as `theme.colors.gameNumber(_:)` — generic enough that Sudoku/Nonogram inherit it later. **Phase: P1 lint / P3 audit gate.**

Beyond the top five: silent CloudKit sync failures with no UI affordance (P4 needs a sync-status row in Settings), Sign in with Apple credential revocation observer (P4), Hard-board grid re-render perf (P3 — Equatable cells, separate timer view, profile in Instruments before optimizing), 480-cell win/loss animation timing budget, theme presets wrecking flag-vs-mine and adjacency-number contrast (P3 — contrast smoke test across all 34 presets is cheap insurance), force-quit losing a game's worth of stats + timer drift across backgrounding (P2 wall-clock timer + scene-phase pauses), App Store nutrition label drift / capability provisioning / bundle ID stability (P5 release checklist + P1 invariant), `ModelContainer` cold-start blocking Home (P4 — defer container construction past Home render to preserve FOUND-01's <1s budget), accessibility regressions (cell `accessibilityLabel` baked in at P2; Reduce Motion + Dynamic Type at P3), and the project-hygiene class of bugs already burned into CLAUDE.md §8 (Finder-dupe `*\ 2.swift` files, hand-patched `project.pbxproj`, stale simulator SwiftData stores).

## Implications for Roadmap

The architecture and pitfalls researchers independently proposed identical phase sequencing — that is the load-bearing convergence. The roadmap should follow this seven-phase build order with no reordering.

### Phase 1: Foundation
**Rationale:** Every later phase depends on token discipline, the shared `ModelContainer` skeleton, and bundle-ID stability — three things that are cheap to do early and irreversibly expensive to retrofit. The pitfalls research flags Phase 1 as the *prevention* phase for SwiftData CloudKit constraints (Pitfall 2), DesignKit consumer mistakes (Pitfall 8), and project hygiene (Pitfall 14).
**Delivers:** Xcode project; DesignKit local SPM dep wired; `GameKitApp` with `ThemeManager` injection; empty `HomeView` / `SettingsView` / `StatsView` / `IntroFlowView` shells reading theme tokens; `SettingsStore` over UserDefaults; placeholder app icon; `Localizable.xcstrings` scaffolding with "Use Compiler to Extract Swift Strings" ON; bundle ID `com.lauterstar.gamekit` locked; pre-commit hooks for Finder dupes + hardcoded color/radius/padding literals; capabilities (iCloud/CloudKit, Sign in with Apple, Background Modes/Remote Notifications, Push Notifications) added but CloudKit container left at `cloudKitDatabase: .none`.
**Addresses:** FOUND-01..06, SHELL-01 (skeletal), THEME-01 (skeletal).
**Avoids:** Pitfalls 2, 8, 11, 14.

### Phase 2: Mines Engines
**Rationale:** Pure-engine work has zero UI dependencies and unblocks the hardest correctness requirement (MINES-03 first-tap safety) without needing the game to be playable manually. The architecture research's "engines before UI" rule and the pitfalls research's "treat first-tap-loss as P0" rule converge here.
**Delivers:** `MinesweeperBoard` / `MinesweeperCell` / `MinesweeperDifficulty` / `MinesweeperGameState` value types; `BoardGenerator` (with injected `RandomNumberGenerator` for deterministic tests); `RevealEngine` (iterative flood-fill, NOT recursive — Pitfall trap); `WinDetector`; full Swift Testing coverage with the three first-tap-safety tests (Easy corner, Hard corner, Hard center) plus win/loss correctness, flagged-cell no-op, and Hard 16×30 with 99 mines determinism. **No UI in this phase.**
**Addresses:** MINES-01, MINES-03, MINES-04 (engine), MINES-07 (detection).
**Uses:** Swift 6 strict concurrency (pure `Sendable` value types), Swift Testing (`@Test`, `#expect`, parameterized).
**Implements:** Pattern 1 (Pure Engine layer).

### Phase 3: Mines UI
**Rationale:** Engines exist and are correct; now wire the simplest playable UI on top. Animation polish is deliberately deferred to P5 — at P3 the goal is "playable, theme-token-pure, gesture-correct," not "polished." The pitfalls research flags this as the right time to wire tap/long-press correctly (Pitfall 7) and bake `accessibilityLabel` into the cell view (Pitfall 13 — cheaper to bake in now than retrofit at P5).
**Delivers:** `MinesweeperViewModel` (`@Observable @MainActor` with phase enum); `MinesweeperView` (`LazyVGrid`/`Grid` of `Equatable` cells, mine counter, wall-clock timer with scene-phase pauses, restart, win/loss overlays using `theme.colors.{success,danger}`); composed `LongPressGesture(0.25).exclusively(before: TapGesture())`; cell `accessibilityLabel` baked in from day 1; theme tokens only — zero hardcoded colors.
**Addresses:** MINES-02, MINES-05, MINES-06, MINES-07 (UI), THEME-02 (skeletal).
**Uses:** SwiftUI iOS 17 (`LazyVGrid`/`Grid`), `@Observable`, `@EnvironmentObject ThemeManager`.
**Implements:** Patterns 1 (View tier), 3 (Phase enum), 4 (ThemeManager via env).
**Avoids:** Pitfalls 7, 13 (cell labels).

### Phase 4: Stats & Persistence
**Rationale:** Win/loss animations should fire `stats.record(...)` against a real persistence layer — animations on top of stub stats produce drift, and the architecture research is explicit that persistence comes before polish. The pitfalls research flags this as the prevention phase for SwiftData CloudKit constraints (Pitfall 2 verification), wall-clock timer / force-quit safety (Pitfall 10), and the "no `Color(...)` literals in `Games/`" lint that runs continuously.
**Delivers:** `GameKind` enum; `GameRecord` and `BestTime` `@Model`s with CloudKit-compatible schema (all optional/defaulted, no `.unique`, all relationships optional, `schemaVersion: Int = 1` field); `GameStats.record(...)` — the single SwiftData write seam; `StatsView` reading via `@Query` filtered by `gameKindRaw`; explicit `try modelContext.save()` on terminal-state detection (not relying on autosave); Export/Import JSON via `fileExporter`/`fileImporter` with `schemaVersion` round-trip; smoke test that constructs a `ModelContainer` with `cloudKitDatabase: .private(...)` even though sync is still off — catches schema violations early.
**Addresses:** PERSIST-01, PERSIST-02, PERSIST-03, SHELL-03.
**Uses:** SwiftData with `cloudKitDatabase: .none`; `@Query`.
**Implements:** Pattern 2 (game-agnostic schema), Pattern 5 (preview of conditional CloudKit).
**Avoids:** Pitfalls 2, 4, 10.

### Phase 5: Polish (animation + haptics + SFX + accessibility + theme matrix)
**Rationale:** With a stable core loop and persisted stats, the differentiator-defining surface (the "premium feel") gets full attention. The pitfalls research flags this as the audit/measurement phase for grid re-render perf (Pitfall 6), theme legibility across all 34 presets (Pitfall 9), and accessibility regressions (Pitfall 13 — Reduce Motion, Dynamic Type, VoiceOver navigation). The animation pass is the differentiator; cutting it would undercut the value prop.
**Delivers:** Phase enum drives reveal cascade (per-cell `withAnimation` + `Task.sleep` stagger), flag spring (`.symbolEffect(.bounce)` or scale spring), win sweep (`phaseAnimator`), loss shake (`keyframeAnimator`); `DKHaptics` wrapper with `.sensoryFeedback` for cues + CoreHaptics + 2 `.ahap` files for win/loss; `SFXPlayer` with preloaded `AVAudioPlayer` instances on `AVAudioSession.ambient`, off by default; full VoiceOver labels (state + position + adjacency); Dynamic Type respected on all non-grid text (cell text uses fixed-size `theme.typography.gameCell`); Reduce Motion dampens motion tokens; 3-step intro; legibility audit on at least one preset per DesignKit category (Classic / Sweet / Bright / Soft / Moody / Loud) plus optional contrast smoke test across all 34 presets; Mines-specific informational number palette `theme.colors.gameNumber(_:)` added to DesignKit; flag color verified distinct from mine indicator on warm-accent presets.
**Addresses:** MINES-08, MINES-09, MINES-10, SHELL-02, SHELL-04, THEME-01, THEME-03, A11Y-01, A11Y-02, A11Y-03; proposed new A11Y-04 (color-blind-safe number palette default verification) and MINES-11 (explicit reveal-all-mines + incorrect-flag indicators on loss).
**Uses:** SwiftUI `phaseAnimator` / `keyframeAnimator` / `.sensoryFeedback` / `.symbolEffect`; CoreHaptics; AVFoundation.
**Implements:** Pattern 3 (Phase enum drives polish).
**Avoids:** Pitfalls 6, 9, 13.

### Phase 6: CloudKit + Sign in with Apple
**Rationale:** Gameplay is shipped-quality; now layer on the optional cross-device surface. Putting CloudKit *after* polish means a sync hiccup never blocks the gameplay phase. The architecture research is explicit that the same `ModelContainer` store path works for both modes when the schema is CloudKit-compatible from day 1 — flipping `cloudKitDatabase` from `.none` to `.private(...)` is the entire promotion. Pitfalls research flags this as the prevention phase for sign-in promotion data loss (Pitfall 4), credential revocation (Pitfall 5), silent sync failures (Pitfall 3), and `ModelContainer` cold-start regression (Pitfall 12).
**Delivers:** iCloud capability + CKContainer `iCloud.com.lauterstar.gamekit` provisioned; `ModelConfiguration(cloudKitDatabase: .private(...))` swap on `SettingsStore.cloudSyncEnabled = true`; `SignInWithAppleButton` in Settings sign-in card with `request.requestedScopes = []`; Apple `userID` stored in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; `getCredentialState(forUserID:)` on every scene-active; `credentialRevokedNotification` observer; "Restart to enable iCloud sync" dialog (launch-only swap is the bulletproof path); sync-status row in Settings ("Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]"); `try await container.initializeCloudKitSchema()` once in dev to materialize record types; manual test matrix (sign in → force-quit → relaunch; sign in → revoke via system Settings → relaunch; sign in → delete app → reinstall); cold-start measurement to confirm CloudKit init hasn't regressed FOUND-01.
**Addresses:** PERSIST-04, PERSIST-05, PERSIST-06.
**Uses:** SwiftData CloudKit mirror, AuthenticationServices, Keychain.
**Implements:** Pattern 5 (Conditional CloudKit via ModelConfiguration swap).
**Avoids:** Pitfalls 3, 4, 5, 12.

### Phase 7: Release
**Rationale:** Pre-submission gating: the App Store / TestFlight failure modes (Pitfall 11) are all checklist-preventable but only if the checklist exists. Privacy nutrition label is "Data Not Collected" (CloudKit private DB the dev cannot access, plus zero analytics) but must be answered with documented reasoning, not in a 2-minute submission rush.
**Delivers:** Real app icon (replacing placeholder); CloudKit schema promoted from Development to Production in CloudKit Dashboard; entitlements file diffed and committed; bundle ID stability re-verified; privacy nutrition label answered with documented reasoning; App Store copy + screenshots; TestFlight build; final theme-matrix legibility audit pass; release checklist in `Docs/` covering capabilities verified, schema promoted, container ID stable, label completed, Sign in with Apple tested in production.
**Addresses:** Ship gate.
**Avoids:** Pitfall 11.

### Phase Ordering Rationale

- **Engines before UI (P2 → P3):** First-tap safety (MINES-03 / Pitfall 1) is unit-testable without a UI host; catching corner-tap edge cases at P2 is orders of magnitude cheaper than discovering them through manual play at P3+.
- **UI before persistence (P3 → P4):** A working game with stub stats is debuggable; stats writes against a half-built game produce confusing failure modes.
- **Persistence before polish (P4 → P5):** Win/loss animations need to fire `stats.record()` against a real layer — animations on top of stubs cause "stats didn't update" bugs that look like animation bugs.
- **Polish before CloudKit (P5 → P6):** CloudKit is *optional* and is the most fragile network surface. Keep it out of the critical path until the differentiator-defining gameplay loop is shipped-quality.
- **CloudKit before release (P6 → P7):** PERSIST-04..06 are scoped requirements, not stretch — they ship in v1. Production schema promotion has to happen before TestFlight for any user to see sync work.
- **Cross-cutting from day 1:** Token discipline (P1 lint, enforced through P5 audit), CloudKit-compatible schema (P1 design, P4 verify, P6 enable), accessibility cell labels (P3 bake-in, P5 polish), bundle ID stability (P1 lock, P7 verify) — these can't be sequenced as their own phases because they're invariants, not features.

### Research Flags

Phases likely needing deeper research during planning (`/gsd-research-phase`):

- **Phase 6 (CloudKit + Sign in with Apple):** Anonymous→signed-in container promotion has MEDIUM confidence on hot-swap; the "Restart to enable" launch-only swap is HIGH confidence. The phase needs a research spike to nail down the exact `ModelContainer` teardown/recreate sequence and to author the test matrix for sign-in / revocation / reinstall combinations. CloudKit Dashboard schema deployment workflow is also worth a focused walkthrough before the first TestFlight build that has CloudKit on.
- **Phase 5 (Polish — specifically the theme matrix audit):** The contrast smoke test across all 34 DesignKit presets is described in PITFALLS.md but the implementation (luminance computation + pairwise contrast assertions) is sketched not specified. A short research/spike to decide whether to ship the smoke test as a hard build gate (HIGH cost up-front, HIGH ongoing value) or rely on visual audit on one preset per category (LOW cost, MEDIUM ongoing value) is appropriate.
- **Phase 5 (Polish — `.ahap` haptic file authoring):** CoreHaptics win-arpeggio and loss-rumble patterns need ear-tuning, not docs reading. Plan for iteration time, not specification time.

Phases with standard patterns (skip research-phase, proceed direct to implementation):

- **Phase 1 (Foundation):** Pure scaffolding — Apple-canonical SwiftUI app shell, SPM local-dep wiring, capabilities/entitlements UI, pre-commit hooks. Every choice is documented in STACK.md and ARCHITECTURE.md.
- **Phase 2 (Mines Engines):** Pure value-type Swift, deterministic algorithms, Swift Testing. The classical Minesweeper rules are well-documented; the only nuance (first-tap safety = cell + 8 bounds-clamped neighbors) is fully specified in PITFALLS.md Pitfall 1.
- **Phase 3 (Mines UI):** Standard `@Observable` view model + dumb view + composed gesture pattern. Both researchers independently produced near-identical code skeletons.
- **Phase 4 (Stats & Persistence):** Single shared `ModelContainer`, `gameKind` discriminator pattern, `@Query` in views, single-write-seam. The schema-design rules (all optional/defaulted, no `.unique`) are codified.
- **Phase 7 (Release):** Checklist work, no research surface.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Apple-canonical (SwiftUI + SwiftData + CloudKit + Swift Testing); multiply confirmed via Apple docs, Apple Developer Forums (multiple verified threads), Hacking With Swift, Mike Tsai's WWDC25 roundup, Use Your Loaf. Single MEDIUM hedge: anonymous→signed-in container hot-swap has community-mixed results; launch-only swap is the bulletproof fallback. |
| Features | HIGH | Well-established 15+ year iOS Minesweeper market with rich competitor data; surveyed Minesweeper Q, Mineswifter, Minesweeper GO, Minesweeper Classic: Retro, Minesweeper: No Guessing, Accessible Minesweeper, and Microsoft Minesweeper. Each anti-feature is grounded in an actual competitor failure mode. MEDIUM hedge: differentiator nuances (some claims are App Store description-level, not deeply verified review-level). |
| Architecture | HIGH | Validated against PROJECT.md, CLAUDE.md, AGENTS.md, DesignKit README, and SwiftData/CloudKit official + community sources. The "engine purity + Observable VM + dumb View" trio is the project's existing constitution; the `gameKind` discriminator and "no `GameProtocol` until game 3" calls are opinionated but well-justified. |
| Pitfalls | HIGH | Each named pitfall has a concrete prevention strategy and a phase to address. CloudKit constraints, App Store 4.8, Sign in with Apple revocation flow, and gesture/grid trade-offs verified against Apple docs + multiple credible sources. MEDIUM hedge on animation budget specifics, theme legibility breakage thresholds, and project-hygiene rules (drawn from CLAUDE.md session-derived rules — should be treated as the team's own remembered pain). |

**Overall confidence:** HIGH. The four streams converge with unusual tightness — there is essentially no architectural ambiguity, and the disagreements that do exist are minor and clearly signaled.

### Cross-Research Convergence (Load-bearing — these are the rules that won't bend)

These are the points where STACK / FEATURES / ARCHITECTURE / PITFALLS independently arrive at the same conclusion. Treat as non-negotiable:

1. **Engine purity + `@Observable @MainActor` view model + dumb view** — STACK §1 (`@MainActor` placement table), ARCHITECTURE Pattern 1, PITFALLS implicitly throughout (engines testable without UI host). The project's existing constitution (CLAUDE.md §1, AGENTS.md §4) reinforces this.
2. **Single shared `ModelContainer`, schema CloudKit-compatible from day 1** — STACK §2 (CloudKit hard constraints), ARCHITECTURE Pattern 5 (conditional CloudKit), PITFALLS Pitfall 2 (`@Attribute(.unique)` will crash) and Pitfall 4 (sign-in promotion data loss). All three say: design for CloudKit at PERSIST-01 even though it turns on at PERSIST-04.
3. **Game-agnostic persistence with `gameKind` discriminator, NOT per-game `@Model`s** — ARCHITECTURE Pattern 2 + Stay-Out-Of List #2; FEATURES doesn't address the schema directly but the cross-game stats it implies (game 2's stats slotting in without StatsView changes) requires this shape; PITFALLS reinforces by warning against schema migrations under CloudKit.
4. **DesignKit token purity, no hardcoded colors/radii in `Games/` or `Screens/`** — STACK §"DesignKit Consumption", ARCHITECTURE Anti-Pattern 5, PITFALLS Pitfall 8 (lint) + Pitfall 9 (theme legibility). Solution converges: when a token is missing, *add it to DesignKit*. Specifically, add `theme.colors.gameNumber(_:)` for the Mines informational number palette so Sudoku/Nonogram inherit it later.
5. **Build order Foundation → Engines → UI → Persistence → Polish → CloudKit → Release** — ARCHITECTURE "Build Order" table and PITFALLS "Pitfall-to-Phase Mapping" propose identical sequencing; STACK §3 (anonymous→signed-in flow) and FEATURES "MVP Definition" both implicitly require persistence before polish before CloudKit.
6. **No premature abstraction (no `GameProtocol`, no per-game models, no game registry, no TCA, no `AnimationCoordinator`, no per-game settings classes, no per-game theme adapters)** — ARCHITECTURE Stay-Out-Of List explicitly; STACK §"What NOT to Use" implicitly (excluded TCA, Combine-heavy state); FEATURES MVP cut implicitly (Mines-only is the right scope to *not* prematurely shape the multi-game APIs).
7. **Tap + long-press must use `LongPressGesture(0.25).exclusively(before: TapGesture())`** — STACK §"Animation Tools" decision matrix (no naive composition), ARCHITECTURE doesn't address gestures specifically, PITFALLS Pitfall 7 (named, with prevention).
8. **Wall-clock timer with scene-phase pauses, NOT `Timer.publish` accumulator** — STACK doesn't address directly, ARCHITECTURE doesn't address directly, PITFALLS Pitfall 10 named explicitly. Single-source but technically uncontested.
9. **`@MainActor` on view models, no `@ModelActor` for MVP** — STACK §1 (placement table), ARCHITECTURE Pattern 1; both explicitly say "skip ModelActor until you have a writer that takes >10ms."
10. **Sign in with Apple with `request.requestedScopes = []` (only the user identifier, no name/email)** — STACK §3 explicitly; FEATURES "Differentiators" reinforces (no consent friction, no nags); PITFALLS Pitfall 5 confirms the credential lifecycle requirements.

### Cross-Research Conflicts and Open Questions

The four streams disagree or punt in five places. These are the hot-spots for `/gsd-research-phase` once roadmap planning gets concrete:

1. **Hot-swap vs launch-only `ModelContainer` reconfiguration on sign-in.** STACK §3 says hot-swap is "supported but historically touchy" (MEDIUM confidence) and recommends launch-only as bulletproof (HIGH confidence). ARCHITECTURE Pattern 5 commits to launch-only with a "Restart to enable iCloud sync" dialog. PITFALLS Pitfall 4 prefers the "same store path always, mirroring no-ops without iCloud" approach which is *neither* hot-swap nor restart-required — it's "configure with `.private(...)` always, let CloudKit be passive when not signed in." **Open question for P6 research:** is the right pattern (a) launch-only with a Restart prompt, (b) always-on `.private(...)` with passive mirroring when no iCloud account, or (c) hot-swap with explicit teardown? The three answers have different UX consequences; the architecture researcher's preference (b) is the most elegant but needs verification it actually behaves correctly when the user has no iCloud account.
2. **Should the contrast smoke test across 34 presets be a build-gate or a manual visual audit?** PITFALLS Pitfall 9 sketches a "loads every preset, generates a Hard board sample, asserts pairwise contrast ≥ 3:1 between adjacent number values" smoke test as "cheap insurance, ~one-time test using `Color`'s luminance." STACK doesn't address. ARCHITECTURE doesn't address. FEATURES (THEME-01) only requires "one preset per category." **Open question for P5 research:** worth the engineering cost, or is one-per-category visual audit sufficient?
3. **No-guess generator scope and timing.** FEATURES marks it v1.1 (HIGH complexity, "0–20s SAT/CSP solving"). STACK doesn't address. PITFALLS doesn't address. ARCHITECTURE explicitly says "deferred to v1.x." **Open question (deferred to v1.1 planning, not MVP):** SAT/CSP solver perf budget on iPhone 12-class hardware, background-thread + retry + fallback strategy, "perfect game" stat alongside.
4. **CloudKit conflict resolution UX for offline best times.** FEATURES open-question section flags "two devices both setting a new best time for Hard while offline — last-write-wins is wrong here (`min(time)` is the right merge)." STACK §2 doesn't address custom conflict resolution (notes that's why one might choose `CKSyncEngine`, but recommends against it). ARCHITECTURE doesn't address. PITFALLS doesn't address. **Open question for P4 research:** does the schema decision (e.g., `BestTime` as a derived materialized row vs. computed-from-`GameRecord` query) need to land before PERSIST-04 ships, or can it be retrofitted post-launch?
5. **VoiceOver gesture conflict between long-press-to-flag and chord (when chord eventually ships).** FEATURES open-question section flags this — long-press has a default VoiceOver gesture (double-tap-and-hold) that conflicts with chord's double-tap. STACK doesn't address. ARCHITECTURE doesn't address. PITFALLS Pitfall 13 covers VoiceOver labels but not the chord/long-press gesture conflict. **Open question (deferred to v1.1 chord planning):** investigate `.accessibilityActions` SwiftUI API for explicit gesture remap.

### Gaps to Address

Beyond the conflicts above, four gaps need attention during planning/execution:

- **First-tap-safe rule edge case on tiny boards.** A 3×3 first-tap-safe region is ~2% of a Hard board (fine), but on a custom 5×5 board with high mine density the safe set could exceed the available cells. Pre-emptive defensive check needed at P2, even though custom boards are deferred. Trivial — assert `(rows*cols) - safeCount >= mineCount` and clamp.
- **Theming the *loss* state, not just the play state.** Themes that use `theme.colors.danger` close to a number-color (e.g., red 3) make exploded-mine visually noisy. The legibility audit at P5 must explicitly check the loss state on Voltage, Dracula, and high-saturation Loud presets — not just the play state. Add to P5 audit checklist.
- **`AVAudioSession` interaction with CoreHaptics.** STACK and PITFALLS describe the systems independently but don't address whether starting `CHHapticEngine` competes with `AVAudioSession.ambient` or vice versa. Test at P5 — likely fine, but verify.
- **CloudKit Production schema deployment workflow.** PITFALLS Pitfall 3 mandates promoting schema to Production before the first TestFlight build that has CloudKit enabled, and re-promoting after every additive schema change. STACK doesn't sketch the workflow. **Capture in P7 release checklist with a step-by-step runbook.**

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `ModelConfiguration.CloudKitDatabase`, `ASAuthorizationAppleIDProvider`, `Canvas`, Core Haptics, String Catalogs, animation timing/movements API surface
- Context7 — `/websites/developer_apple_swiftdata`, `/websites/developer_apple_swiftui`, `/swiftlang/swift-testing`, `/websites/developer_apple_testing`
- Apple Developer Forums — verified pain points: 731334, 731375, 731435, 744491, 756538, 98401, 708415, 750911, 735349, 710456
- Internal: `/Users/gabrielnielsen/Desktop/GameKit/.planning/PROJECT.md`, `/Users/gabrielnielsen/Desktop/GameKit/CLAUDE.md` §1–§8, `/Users/gabrielnielsen/Desktop/GameKit/AGENTS.md` §1–§9, `/Users/gabrielnielsen/Desktop/GameKit/README.md`, `/Users/gabrielnielsen/Desktop/DesignKit/README.md`

### Secondary (MEDIUM confidence)
- Hacking With Swift — Syncing SwiftData with CloudKit, How SwiftData works with concurrency, How to stop SwiftData syncing with CloudKit, How to use gestures in SwiftUI
- Massicotte — "ModelActor is Just Weird" (concurrency pitfalls)
- Use Your Loaf — SwiftUI Sensory Feedback
- SwiftLee — App launch time performance, SwiftUI Grid/LazyVGrid/LazyHGrid explained
- SimpleLocalize — XCStrings String Catalog guide
- Mike Tsai — SwiftData and Core Data at WWDC25
- swiftlang/swift-testing GitHub
- fatbobman — Designing Models for CloudKit Sync
- Alex Logan — SwiftData, meet iCloud (WWDC23 walkthrough)
- firewhale.io — Some Quirks of SwiftData with CloudKit
- leojkwan — Deploy CloudKit-backed SwiftData entities to production
- Adapty — Banned dark patterns vs permitted tricks (mobile)
- David Mathlogic — Wong color-blind-safe palette principles
- Minesweeper Wiki — 3BV, 3BV/s, Chording mechanic explainers
- App Store competitor surveys — Minesweeper Q, Mineswifter, Minesweeper GO, Minesweeper Classic: Retro, Minesweeper Classic, Microsoft Minesweeper, Accessible Minesweeper, Minesweeper: No Guessing

### Tertiary (LOW confidence — needs validation)
- App Store review-pattern summaries surveyed via web search — used for anti-feature grounding
- Specific `.ahap` file contents for win/loss CoreHaptics patterns — tuned by ear at P5
- AVAudioPlayer + CoreHaptics simultaneous behavior — verified at P5

---
*Research completed: 2026-04-24*
*Ready for roadmap: yes*
