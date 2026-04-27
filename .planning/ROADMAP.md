# Roadmap: GameKit

**Created:** 2026-04-24
**Granularity:** standard (5–8 phases, 3–5 plans each)
**Coverage:** 35/35 v1 requirements mapped

## Overview

GameKit ships **Minesweeper-only** to TestFlight, then App Store. The journey is a deliberately tight seven-phase build order that the architecture and pitfalls research independently converged on: stand up the themed shell, prove the engine logic in pure Swift, wire the simplest correct UI on top, persist stats with a CloudKit-compatible schema, deliver the differentiator-defining polish pass (animation + haptics + SFX + a11y + theme matrix), then layer optional CloudKit + Sign in with Apple after the gameplay loop is shipped-quality, and finally clear the App Store / TestFlight checklist. "Mines-only at v1" is a hard scope constraint — Merge / Word Grid / Solitaire / Sudoku and the rest of the suite are PROJECT.md long-term vision, not roadmap phases.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - App shell, DesignKit wiring, ThemeManager, bundle ID lock, capabilities, lint hooks
- [x] **Phase 2: Mines Engines** - Pure value-type board / reveal / win-detect with deterministic Swift Testing coverage
- [x] **Phase 3: Mines UI** - Playable theme-token-pure board, gestures, timer, restart, win/loss overlays, baked-in a11y labels
- [x] **Phase 4: Stats & Persistence** - SwiftData stats with CloudKit-compatible schema, Stats screen, Export/Import JSON
- [ ] **Phase 5: Polish** - Animation pass, haptics, SFX, theme legibility audit, full accessibility, 3-step intro, Settings spine
- [ ] **Phase 6: CloudKit + Sign in with Apple** - Optional cross-device sync, sign-in lifecycle, anonymous→signed-in promotion
- [ ] **Phase 7: Release** - Real app icon, schema promoted to Production, privacy nutrition label, TestFlight, App Store

## Phase Details

### Phase 1: Foundation
**Goal**: App shell exists, reads DesignKit tokens, has invariants in place that make every later phase cheap.
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, SHELL-01
**Success Criteria** (what must be TRUE):
  1. App launches to a Home screen in <1s on cold start (recent simulator), with Minesweeper visible as the only enabled card and future-game placeholders disabled.
  2. Every visible pixel on every shell screen (Home / Settings / Stats / IntroFlow) reads from `theme.colors.*` / `theme.radii.*` / `theme.spacing.*` — switching to a Loud preset (e.g. Voltage) and back to Classic produces no hardcoded-color bleedthrough.
  3. Bundle identifier is `com.lauterstar.gamekit`, deployment target is iOS 17+, Swift 6 strict concurrency is ON, and the project builds without warnings.
  4. A pre-commit hook rejects `Color(...)` literals, hardcoded `cornerRadius:`/`padding(` integers in `Games/` and `Screens/`, and any `*\ 2.swift` Finder-dupe files.
  5. All user-facing strings reach the UI via `String(localized:)` with an `xcstrings` catalog populated; the catalog has zero stale entries flagged by Xcode.
**Plans**: 8 plans
- [ ] 01-PLAN-project-config.md — Lock pbxproj invariants (bundle ID com.lauterstar.gamekit, iOS 17.0, Swift 6 with strict concurrency complete) + pin CloudKit container ID in PROJECT.md per D-10
- [ ] 01-PLAN-precommit-hooks.md — Install scripts/install-hooks.sh + .githooks/pre-commit rejecting Color literals, numeric cornerRadius/padding in Games+Screens, and Finder-dupe "* 2.swift" files
- [ ] 01-PLAN-app-icon-placeholder.md — Generate three 1024x1024 placeholder PNGs (universal/dark/tinted) and update AppIcon Contents.json
- [ ] 01-PLAN-derived-data-doc.md — Document derived-data + simulator-store hygiene rituals per D-09
- [ ] 01-PLAN-designkit-link.md — Add DesignKit as local SPM dep at ../DesignKit via Xcode UI per D-07/D-08
- [ ] 01-PLAN-app-scene.md — Replace Xcode template with App/GameKitApp.swift owning ThemeManager @StateObject; create Screens/RootTabView.swift stub; delete legacy gamekitApp.swift + ContentView.swift
- [ ] 01-PLAN-shell-screens.md — Build RootTabView 3-tab root + HomeView (1 enabled Mines + 8 disabled placeholders + ComingSoonOverlay) + SettingsView/StatsView themed-scaffold stubs
- [ ] 01-PLAN-localization-catalog.md — Author Resources/Localizable.xcstrings with all P1 String(localized:) keys; verify zero stale entries
**UI hint**: yes

### Phase 2: Mines Engines
**Goal**: The hardest correctness requirement (first-tap safety) is proven in pure Swift before any UI exists.
**Depends on**: Phase 1
**Requirements**: MINES-01, MINES-03, MINES-04
**Success Criteria** (what must be TRUE):
  1. Swift Testing suite passes: Easy 9×9/10, Medium 16×16/40, Hard 16×30/99 board generation produces exactly the specified mine count for every difficulty.
  2. First-tap-safety tests pass for Easy corner tap (0,0), Hard corner tap (0,0), and Hard center tap (8,15) — the tapped cell plus its bounds-clamped neighbors (3 / 5 / 8 depending on position) are mine-free, and exact mine count is preserved.
  3. Iterative flood-fill (no recursion) reveals empty cells to the next numbered border on a 16×30 board with mines clustered in one corner without stack growth.
  4. Win/loss detection is deterministic: a 16×30/99 board with 380 non-mine cells revealed reads as ongoing; with 381 revealed reads as won; revealing any mine reads as lost.
  5. Engines import only `Foundation` — no `SwiftUI`, no `SwiftData`, no `ModelContext` imports — verified by build target separation.
**Plans**: 6 plans
- [x] 02-01-PLAN.md — Models layer (Difficulty/Index/Cell/Board/GameState) — immutable Foundation-only value types per D-01..D-05, D-09, D-10
- [x] 02-02-PLAN.md — SeededGenerator (SplitMix64) test helper in `gamekitTests/Helpers/` per D-12
- [x] 02-03-PLAN.md — BoardGenerator engine + tests: single-shot first-tap-safe placement (Pitfall 1), adjacency precompute, perf bench (D-08, D-11, D-13–D-18)
- [x] 02-04-PLAN.md — RevealEngine engine + tests: iterative BFS flood-fill (no recursion), idempotence, flag protection, mine-hit transition (D-06, D-07, D-19)
- [x] 02-05-PLAN.md — WinDetector engine + tests: isWon/isLost predicates + mutual-exclusion fuzz (D-07, D-19)
- [x] 02-06-PLAN.md — Wave-3 cleanup: integrated engine purity grep (SC5), full test suite green, delete Xcode template stub

### Phase 3: Mines UI
**Goal**: The game is playable end-to-end on real hardware with theme-token-pure rendering, correct gesture composition, and accessibility labels baked in.
**Depends on**: Phase 2
**Requirements**: MINES-02, MINES-05, MINES-06, MINES-07, MINES-11, THEME-02
**Success Criteria** (what must be TRUE):
  1. User can tap a cell to reveal it and long-press (0.25s) to flag it; the composed `LongPressGesture(0.25).exclusively(before: TapGesture())` produces zero "tapped a cell, it flagged instead" misfires across 50 manual taps on iPhone SE-class hardware.
  2. Mine counter displays `total − flagged` and a wall-clock timer ticks while playing and pauses on `scenePhase == .background`, resuming with the correct elapsed time on `.active`.
  3. User can tap Restart at any moment and a fresh board appears in the same difficulty.
  4. Win surfaces an end-state overlay using `theme.colors.success`; loss reveals all mines, marks incorrectly-flagged cells with an X, and surfaces an overlay using `theme.colors.danger`.
  5. Revealed cells, unrevealed cells, mines, flags, and adjacency numbers 1–8 all read from the new `theme.colors.gameNumber(_:)` token (added to DesignKit) plus existing semantic tokens — zero `Color(...)` literals or hand-picked greys in `Games/Minesweeper/`.
  6. Every cell exposes a context-rich `accessibilityLabel` ("Unrevealed, row 3 column 5" / "Revealed, 2 mines adjacent, row 3 column 5" / "Flagged, row 3 column 5") at view creation, not retrofit.
**Plans**: 4 plans
- [x] 03-01-PLAN.md — DesignKit `theme.gameNumber(_:)` token + per-preset 8-color palettes (forest/bubblegum/barbie/cream/dracula/voltage) + Wong-audit XCTest infrastructure (D-13/D-14/D-15/D-16; A11Y-04)
- [x] 03-02-PLAN.md — `MinesweeperViewModel` (@Observable @MainActor, Foundation-only) + Swift Testing suite covering MINES-02/05/06/07/11 + UserDefaults difficulty persistence (D-05..D-12)
- [x] 03-03-PLAN.md — Four leaf views: `MinesweeperHeaderBar` + `MinesweeperCellView` + `MinesweeperToolbarMenu` + `MinesweeperEndStateCard` — props-only, gesture composition, theme-token-pure (D-01..D-04, D-09, D-17, D-19)
- [x] 03-04-PLAN.md — Composition: `MinesweeperBoardView` + `MinesweeperGameView` + HomeView wiring + xcstrings sweep + manual SC1/SC2/SC4/SC6 verification checkpoint (50-tap test + 6-preset theme matrix + VoiceOver sweep)
**UI hint**: yes

### Phase 4: Stats & Persistence
**Goal**: Stats survive force-quit / crash / reboot, schema is CloudKit-compatible from day 1, and the Stats screen reads the persisted truth.
**Depends on**: Phase 3
**Requirements**: PERSIST-01, PERSIST-02, PERSIST-03, SHELL-03
**Success Criteria** (what must be TRUE):
  1. Playing a Hard game to win or loss writes a `GameRecord` and updates `BestTime` synchronously via an explicit `try modelContext.save()` on terminal-state detection — verified by force-quitting the simulator immediately after game-over and relaunching to find the record present.
  2. Stats screen shows per-difficulty rows with games played, wins, win %, and best time, populated from `@Query` filtered by `gameKindRaw == "minesweeper"` — empty state displays explicit copy ("No games played yet…") not "0 / 0 / —".
  3. The `ModelContainer` constructs successfully when configured with `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` — a smoke test runs even though sync is still off, catching schema constraint violations (no `@Attribute(.unique)`, all properties optional/defaulted, all relationships optional, `schemaVersion: Int = 1`) the moment they're introduced.
  4. Export to JSON via `fileExporter` and re-import via `fileImporter` produces a byte-for-byte round-trip including `schemaVersion` — exporting a 50-game stats set, resetting stats, re-importing produces the original counts and best times.
  5. Stats persist across app force-quit, crash, and device reboot — verified by all three scenarios in a manual QA pass.
**Plans**: 6 plans
- [x] 04-01-PLAN.md — Schema foundation (GameKind/Outcome enums + GameRecord/BestTime @Model classes) + InMemoryStatsContainer test helper + ModelContainerSmokeTests (SC3 dual-config)
- [x] 04-02-PLAN.md — GameStats service (sync save per RESEARCH Pitfall 10) + Swift Testing coverage (~8 tests covering record/resetAll/BestTime-only-on-faster)
- [x] 04-03-PLAN.md — StatsExporter + envelope/error/document types + Swift Testing (round-trip-50 byte-equal SC4 + schema-mismatch + replace-on-import)
- [x] 04-04-PLAN.md — SettingsStore (@Observable UserDefaults wrapper + EnvironmentKey) + GameKitApp.swift edit (shared ModelContainer construction reading cloudSyncEnabled per D-08)
- [x] 04-05-PLAN.md — UI integration (VM 5th seam + GameView .task injection + StatsView rewrite + SettingsView Export/Import/Reset + xcstrings sweep)
- [x] 04-06-PLAN.md — Manual verification checkpoint (force-quit/crash/reboot survival + 6-preset matrix + real-device fileExporter round-trip + schema-mismatch alert + VoiceOver partial)

### Phase 5: Polish (animation + haptics + SFX + accessibility + theme matrix)
**Goal**: The differentiator-defining "premium feel" surface lands — animations, haptics, SFX, accessibility, theme legibility, intro flow, full Settings spine.
**Depends on**: Phase 4 (animations fire `stats.record()` against a real persistence layer; without P4, win/loss animations on stub stats produce drift bugs that look like animation bugs)
**Requirements**: MINES-08, MINES-09, MINES-10, SHELL-02, SHELL-04, THEME-01, THEME-03, A11Y-01, A11Y-02, A11Y-03, A11Y-04
**Success Criteria** (what must be TRUE):
  1. The `MinesweeperPhase` enum drives a reveal cascade (per-cell stagger), flag spring (`.symbolEffect(.bounce)` or scale spring), win sweep (`phaseAnimator`), and loss shake (`keyframeAnimator`) — all timed via `theme.motion.{fast,normal,slow}` and dampened to near-zero when `accessibilityReduceMotion` is on.
  2. Haptics fire on flag, reveal, win, and loss via DesignKit's `.sensoryFeedback` surface plus two CoreHaptics `.ahap` files (win arpeggio, loss rumble); the Settings haptics toggle silences them all. SFX fires on tap / win / loss via preloaded `AVAudioPlayer` on `AVAudioSession.ambient` (does not duck user music), is **off by default**, and the Settings SFX toggle controls it.
  3. Settings screen ships the full spine: 5 Classic preset swatches inline + "More themes & custom colors" link to full `DKThemePicker`, haptics toggle, SFX toggle, reset stats (with confirmation alert), about. The 3-step intro (themes → stats → optional sign-in card with Skip) shows on first launch only — `hasSeenIntro` flag persisted, verified by a first-launch / second-launch test.
  4. Minesweeper UI legibility verified on at least one preset from each DesignKit category (Classic / Sweet / Bright / Soft / Moody / Loud) for **both play state and loss state**; the `theme.colors.gameNumber(_:)` default palette is verified Wong-palette-compatible for protanopia / deuteranopia / tritanopia; custom-palette overrides via `ThemeManager.overrides` work end-to-end through the Mines grid.
  5. VoiceOver navigates a partial board reading state + position + adjacency for every cell; Dynamic Type at AX5 scales all non-grid text without layout breakage while the grid stays fixed-size; Reduce Motion ON during a win replay produces a static end-state overlay with no shake or sweep.
**Plans**: 7 plans
- [x] 05-01-PLAN.md — MinesweeperPhase enum + SettingsStore extension (hapticsEnabled / sfxEnabled / hasSeenIntro flags) + SettingsStoreFlagsTests
- [ ] 05-02-PLAN.md — Resources/Audio/{tap,win,loss}.caf + Resources/Haptics/{win,loss}.ahap + LICENSE.md (checkpoint:human-action for CAF placement)
- [x] 05-03-PLAN.md — Core/Haptics.swift + Core/SFXPlayer.swift + GameKitApp wiring + HapticsTests + SFXPlayerTests
- [x] 05-04-PLAN.md — Settings spine rebuild (APPEARANCE/AUDIO/DATA verbatim/ABOUT) + FullThemePickerView + xcstrings sync
- [x] 05-05-PLAN.md — IntroFlowView (3-step .fullScreenCover with TabView(.page)) + RootTabView wiring + SIWA entitlement + xcstrings sync
- [ ] 05-06-PLAN.md — Mines animation pass (VM phase + BoardView cascade + CellView .sensoryFeedback + GameView .phaseAnimator/.keyframeAnimator/.onChange Haptics+SFX) + MinesweeperPhaseTransitionTests
- [ ] 05-07-PLAN.md — Manual SC1-SC5 verification checkpoint (theme matrix, custom palette, full a11y sweep, gap log)
**UI hint**: yes

### Phase 6: CloudKit + Sign in with Apple
**Goal**: Optional cross-device persistence works without ever blocking gameplay; sign-in promotes anonymous local data with zero loss.
**Depends on**: Phase 4 (CloudKit-compatible schema must already be live; flipping `cloudKitDatabase` from `.none` to `.private(...)` is the entire promotion when schema is correct from day 1) and Phase 5 (gameplay must be shipped-quality before adding the most fragile network surface)
**Requirements**: PERSIST-04, PERSIST-05, PERSIST-06
**Success Criteria** (what must be TRUE):
  1. User can play full-feature Minesweeper without ever signing in — every gameplay path, every stat, every theme works identically signed-out and signed-in.
  2. User can sign in via the Sign in with Apple button in Settings (with `request.requestedScopes = []`); the Apple `userID` persists in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; `getCredentialState(forUserID:)` runs on every scene-active and a `credentialRevokedNotification` observer is registered.
  3. Anonymous→signed-in promotion: a user with 50 local games signs in, sees a "Restart to enable iCloud sync" dialog, restarts, and on relaunch all 50 games are present and begin mirroring to CloudKit — verified by checking the same iCloud account on a second simulator and seeing the rows appear.
  4. Settings shows a sync-status row that reports state ("Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]") subscribed to `NSPersistentCloudKitContainer.eventChangedNotification`.
  5. Sign-in is surfaced once in the 3-step intro (with Skip) and once in Settings; never modal, never push, never re-prompted after dismissal. Cold-start time remains <1s after enabling CloudKit (FOUND-01 not regressed).
**Plans**: TBD
**Research**: YES — `/gsd-research-phase` recommended. Open questions: (a) launch-only vs always-on `.private(...)` vs hot-swap `ModelConfiguration` reconfiguration on sign-in (research stream conflict, MEDIUM confidence on hot-swap, HIGH on launch-only with Restart prompt); (b) exact `ModelContainer` teardown/recreate sequence; (c) test matrix for sign-in / revocation / reinstall combinations; (d) CloudKit Dashboard schema deployment workflow.

### Phase 7: Release
**Goal**: Pre-submission gating — the App Store / TestFlight failure modes are all checklist-preventable, and this is the checklist.
**Depends on**: Phase 6
**Requirements**: (no new REQ-IDs — this is the ship gate that verifies cross-cutting invariants from earlier phases)
**Success Criteria** (what must be TRUE):
  1. Real app icon (replacing the placeholder from FOUND-06) ships in `Assets.xcassets`; CloudKit schema has been promoted from Development to Production in CloudKit Dashboard (verified by toggling environment); `iCloud.com.lauterstar.gamekit` container ID is identical to P1's lock and unchanged in `Info.plist` / entitlements.
  2. Privacy nutrition label is answered "Data Not Collected" with documented reasoning ("CloudKit private DB, encrypted, dev has no access; no analytics SDKs; MetricKit acceptable") and matches the binary; the label was decided in advance, not in a 2-minute submission rush.
  3. Sign in with Apple is verified working in the **production** environment via TestFlight (not just dev sandbox); CloudKit sync is verified working in TestFlight by signing in on two TestFlight devices and watching stats sync.
  4. Final theme-matrix legibility audit passes: a Hard board sample renders correctly on at least one preset from each DesignKit category for play state AND loss state; flag color verified distinct from mine indicator on warm-accent presets (Forest / Ember / Voltage / Maroon).
  5. Release checklist documented in `.planning/Docs/` (or equivalent) covering every step: capabilities verified, entitlements diffed, schema promoted, container ID stable, label completed, SIWA tested in production. TestFlight build is uploaded, internal testers invited.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 8/8 | Complete | 2026-04-25 |
| 2. Mines Engines | 6/6 | Complete | 2026-04-25 |
| 3. Mines UI | 3/4 | In progress | - |
| 4. Stats & Persistence | 1/6 | In progress | - |
| 5. Polish | 1/7 | In progress | - |
| 6. CloudKit + Sign in with Apple | 0/TBD | Not started | - |
| 7. Release | 0/TBD | Not started | - |

## Research Flags

Phases that should run `/gsd-research-phase` before planning:

- **Phase 5 (Polish):** YES — (a) decide whether to ship the 34-preset contrast smoke test as a build gate vs one-per-category visual audit (PITFALLS Pitfall 9 sketches but does not specify the implementation cost); (b) `.ahap` haptic file authoring is ear-tuned, not docs-driven — plan iteration time, not specification time.
- **Phase 6 (CloudKit + Sign in with Apple):** YES — anonymous→signed-in container promotion has MEDIUM confidence on hot-swap and HIGH confidence on the launch-only Restart-prompt path; research stream conflict (STACK / ARCHITECTURE / PITFALLS disagree); needs a focused spike to nail the exact `ModelContainer` reconfigure sequence and the test matrix for sign-in / revocation / reinstall.

Phases with standard patterns (skip research-phase, proceed direct to planning):

- **Phase 1 (Foundation):** Apple-canonical scaffolding, fully specified in STACK.md / ARCHITECTURE.md.
- **Phase 2 (Mines Engines):** Pure value-type Swift, classical Minesweeper rules, first-tap-safety rule fully specified in PITFALLS Pitfall 1.
- **Phase 3 (Mines UI):** Standard `@Observable` VM + dumb view + composed gesture pattern; both research streams produced near-identical code skeletons.
- **Phase 4 (Stats & Persistence):** Single shared `ModelContainer` with `gameKind` discriminator, schema-design rules codified.
- **Phase 7 (Release):** Checklist work, no research surface.

## Cross-Cutting Invariants

These are not phase-bounded — they begin at P1 and are enforced through P7. Failing any of them at any time is a build break, not a phase-end gate:

- **DesignKit token discipline:** No `Color(...)` literals, hardcoded `cornerRadius:`/`padding(` integers, or hand-picked greys in `Games/` or `Screens/`. Pre-commit hook from P1; ongoing audit through P5; final pass at P7.
- **CloudKit-compatible schema:** All SwiftData models ship with optional or defaulted properties, no `@Attribute(.unique)`, all relationships optional, `schemaVersion: Int = 1` field. Designed at P1 even though CloudKit only turns on at P6.
- **Bundle ID stability:** `com.lauterstar.gamekit` locked at P1; CI / pre-commit flag any `PRODUCT_BUNDLE_IDENTIFIER` change in `project.pbxproj`; re-verified at P7.
- **Accessibility cell labels:** Baked into `MinesweeperCellView` at P3, polished at P5 — never retrofit.
- **String localization:** `String(localized:)` everywhere from P1; "Use Compiler to Extract Swift Strings" build setting ON; EN-only ship at v1, future locales mechanical.
- **Project hygiene:** No `*\ 2.swift` Finder dupes (pre-commit hook from P1); never hand-patch `project.pbxproj` to add a Swift file (Xcode 16 synchronized root group auto-registers); always uninstall stale simulator stores before debugging `NSStagedMigrationManager` crashes.

## Out-of-Scope Reminder (Hard Constraints)

The following are PROJECT.md long-term vision and are **not** roadmap phases:

- A second game in v1 (Merge / Word Grid / Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess puzzles) — earned only after Minesweeper is shipping clean.
- Banner / interstitial / video ads, coins / fake currency / energy / hearts, aggressive subscription paywalls, required accounts, streak-shaming, push-notification nagging, pop-up rate-this-app modals, third-party backend, analytics / telemetry SDKs, multiplayer / leaderboards / social, asset-heavy games, localizations beyond EN, per-game alt-icon variants, `CKSyncEngine`, `@ModelActor` for MVP writes, `Canvas`-rendered Mines board, `GameProtocol` / runtime game registry / per-game `@Model`s, TCA / Redux.

---
*Roadmap created: 2026-04-24*
*Phase sequencing: load-bearing convergence between research/ARCHITECTURE.md and research/PITFALLS.md*
