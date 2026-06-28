# Roadmap: GameKit

**Created:** 2026-04-24
**Last updated:** 2026-06-25 (v1.5 Endless Arcade Primitive — 4 phases (15–18), 22/22 requirements mapped)
**Granularity:** standard (5–8 phases, 3–5 plans each)
**Coverage:** v1.0 — 38/38 requirements mapped ✓ · v1.2 — 14/14 requirements mapped ✓ · v1.5 — 22/22 requirements mapped ✓

## Milestones

GameKit ships in named, append-only milestones. Phase numbering never resets — each milestone continues from the prior milestone's last integer phase. Earlier-milestone phases are preserved verbatim once shipped; insertions use decimal phases (e.g., 06.1).

| Milestone | Phases | Status | Scope |
|-----------|--------|--------|-------|
| **v1.0** | 1 → 7 (incl. 6.1) | Phase 7 in progress (pre-flight) | MVP — Minesweeper-only ship to TestFlight / App Store |
| **v1.2** | 8 → 13 (incl. 12.1) | Complete (2026-05-14) | Video Mode — optional layout adaptation for PiP video overlays |
| **v1.5** | 15 → 18 | In progress (planning) | Endless Arcade Primitive — real-time loop substrate + Stack + Snake |

v1.1 (Merge / Nonogram graduation) shipped under the v1.0 phase set as a post-MVP follow-up and did not open a new milestone band; both games are in production binary as of 2026-05-12 and become Video-Mode adoption targets in v1.2 Phase 12.

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
- [x] 05-02-PLAN.md — Resources/Audio/{tap,win,loss}.caf + Resources/Haptics/{win,loss}.ahap + LICENSE.md (checkpoint:human-action for CAF placement)
- [x] 05-03-PLAN.md — Core/Haptics.swift + Core/SFXPlayer.swift + GameKitApp wiring + HapticsTests + SFXPlayerTests
- [x] 05-04-PLAN.md — Settings spine rebuild (APPEARANCE/AUDIO/DATA verbatim/ABOUT) + FullThemePickerView + xcstrings sync
- [x] 05-05-PLAN.md — IntroFlowView (3-step .fullScreenCover with TabView(.page)) + RootTabView wiring + SIWA entitlement + xcstrings sync
- [x] 05-06-PLAN.md — Mines animation pass (VM phase + BoardView cascade + CellView .sensoryFeedback + GameView .phaseAnimator/.keyframeAnimator/.onChange Haptics+SFX) + MinesweeperPhaseTransitionTests
- [x] 05-07-PLAN.md — Manual SC1-SC5 verification checkpoint (theme matrix, custom palette, full a11y sweep, gap log)
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
**Plans**: 9 plans
- [x] 06-01-PLAN.md — Wave-0 TDD RED — KeychainBackend + InMemoryKeychainBackend + AuthStoreTests skeleton (locks SC2 verbatim Keychain attrs; T-06-01)
- [x] 06-02-PLAN.md — Wave-0 TDD RED — SyncStatus enum + label(at:) + CloudSyncStatusObserverTests skeleton (locks D-10 4-state contract)
- [x] 06-03-PLAN.md — Wave-0 BLOCKING — entitlements verify (T-06-09) + DEBUG schema deploy preflight (Pitfall D — required before SC3)
- [x] 06-04-PLAN.md — Wave-1 GREEN — AuthStore production source (Keychain + revocation observer + scene-active validator) → 7/7 RED tests GREEN
- [x] 06-05-PLAN.md — Wave-1 GREEN — CloudSyncStatusObserver production source (eventChangedNotification translator) → 9/9 RED tests GREEN
- [x] 06-06-PLAN.md — Wave-2 — GameKitApp + RootTabView wiring (Environment injection + scenePhase observer + root Restart prompt alert D-04 verbatim)
- [x] 06-07-PLAN.md — Wave-2 — SettingsView SYNC section between AUDIO and DATA (extracted to SettingsSyncSection.swift) + xcstrings sync
- [x] 06-08-PLAN.md — Wave-2 — IntroFlowView Step 3 SIWA wire-up (replaces P5 D-21 no-op) + dismissIntro byte-identical preserved
- [x] 06-09-PLAN.md — Wave-3 — manual SC1-SC5 verification checkpoint (06-VERIFICATION.md template + sign-off)
**UI hint**: yes

### Phase 06.1: pre-release polish — Home cards 2-per-row grid + Mines flag-mode toggle + Hard-board horizontal-scroll fix; pre-deploy gate before P7 wave 2 (INSERTED)

**Goal**: Three pre-release polish items land before P7 wave 2 — Home shows a 2-column square grid (Mines hero + Upcoming sheet), Minesweeper gains a Reveal/Flag interaction-mode FAB toggle, and the Mines board auto-scales to fit width with pinch-zoom (graduates A11Y-V2-02 → v1).
**Requirements**: SHELL-05, MINES-12, A11Y-05
**Depends on:** Phase 6
**Plans:** 3 plans

Plans:
- [x] 06.1-01-PLAN.md — Home 2-col grid (Mines + Upcoming sheet) + UpcomingGamesView sibling — SHELL-05
- [x] 06.1-02-PLAN.md — Minesweeper Reveal/Flag interaction-mode toggle (VM + FAB) — MINES-12
- [x] 06.1-03-PLAN.md — Mines board auto-scale + pinch-zoom (MagnifyGesture + onGeometryChange) — A11Y-05 (graduates A11Y-V2-02)

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
**Plans:** 6 plans

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 8/8 | Complete | 2026-04-25 |
| 2. Mines Engines | 6/6 | Complete | 2026-04-25 |
| 3. Mines UI | 4/4 | Complete | 2026-04-25 |
| 4. Stats & Persistence | 6/6 | Complete | 2026-04-26 |
| 5. Polish | 7/7 | Complete | 2026-04-26 |
| 6. CloudKit + Sign in with Apple | 9/9 | Complete | 2026-04-27 |
| 7. Release | 0/6 | In progress | - |

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

## Milestone v1.2: Video Mode

**Opened:** 2026-05-12
**Granularity:** standard (5–8 phases, 3–5 plans each)
**Coverage:** 14/14 v1.2 requirements mapped ✓
**Phase band:** 8 → 13 (continues from v1.0's last integer phase; numbering never resets per the Milestones policy above)

### Milestone Overview

Video Mode is an optional layout adaptation that keeps GameDrawer playable while a floating PiP video sits on screen. The user manually picks one of six PiP positions (Large top/bottom, Small TL/TR/BL/BR) and every game screen reflows accordingly: small PiP nudges controls away from the covered corner, large PiP reserves a vertical band and shrinks the playable area instead of letting the video occlude it. The v1.2 build order is design-first: a real screenshot-driven design phase establishes the six-location matrix, picks the hard-Minesweeper strategy, and locks the compact-control-row shape **before** any code ships. Code phases then proceed in a deliberate order — foundation (store + Settings + shared row component), layout primitives (small/large/off behavior verified on a stub), Minesweeper adoption (hardest case first because Hard 16×30 is the squeeze test), Merge + Nonogram adoption (lower-risk grids), and finally a non-board-covering win/loss banner that gates haptics/SFX/animations through the existing Settings toggles and Reduce Motion.

The non-negotiable upstream gate is documented in `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` ("Design phase required"): the design must be driven by Gabe's screenshots, especially for large PiP and hard Minesweeper — **do not skip the design phase and jump straight to code.**

### v1.2 Phases

- [x] **Phase 8: Video Mode Design** (2026-05-12) - Screenshot-annotated layout doc + Hard-Mines strategy ADR + compact-row + win/loss banner sketch (design-only — no app code)
- [x] **Phase 9: Video Mode Foundation** (2026-05-12) - VideoModeStore + Settings UI (toggle + 6-location picker + manual-selection copy) + shared compact control row component + environment plumbing
- [x] **Phase 10: Layout Primitives** - Small-PiP reposition system + Large-PiP reserved-band system + Off restore; verified end-to-end on a stub game screen
- [x] **Phase 11: Minesweeper Adoption** (2026-05-13) - Easy + Medium across all 6 locations + Hard 16×30 strategy implemented per Phase 8 ADR (locked 12pt floor; SC1/SC3/SC4 PARTIAL — full sweep DEFERRED to TestFlight per 11-VIDEO-MANUAL-CHECK.md)
- [ ] **Phase 12: Merge + Nonogram Adoption** - Both grids reflow across all 6 locations with no legibility regression
- [ ] **Phase 13: Win/Loss Banner + A11y Gating** - Non-board-covering banner replaces full-screen overlays; haptics/SFX/animations gated by Settings + Reduce Motion

### v1.2 Phase Details

### Phase 8: Video Mode Design
**Goal**: Design is locked against Gabe's real screenshots before any code ships — the six-location matrix is annotated per game, the hard-Minesweeper strategy is chosen with rationale, the compact control row visual language is sketched, and the win/loss banner placement rules are pinned. This phase prevents the "jump straight to code" failure mode called out in `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` (§Design phase required).
**Depends on**: v1.0 Phase 6.1 (Merge + Nonogram both shipped — both games' current screens are required design inputs; v1.0 release work runs in parallel and is not a blocker)
**Requirements**: (no VIDEO-* mappings — design-only phase; this is the gate that unblocks Phase 9+)
**Success Criteria** (what must be TRUE):
  1. A screenshot-annotated layout doc (`.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` or equivalent) exists with Gabe's current screenshots of Mines Easy, Mines Medium, Mines Hard, Merge, and Nonogram, each marked with all 6 PiP zones overlaid, plus a per-game / per-zone "where the controls go, what happens to the board" note.
  2. A Hard Minesweeper strategy ADR records the chosen approach (smaller cells / scroll-pan / pinch-zoom / warning-and-compromise) with explicit rationale, screenshot evidence of the rejected alternatives, and a one-sentence rollback condition — referenced by name (e.g. "Phase 08 Hard-Mines ADR") from later phase Success Criteria so no downstream phase re-decides the approach.
  3. The compact control row design tokens are sketched (target order `Back | primary info | picker | secondary info | settings`, picker pill sizing, spacing, hit targets) at the token level — concrete DesignKit anchors named, no hardcoded sizes; explicit per-game label mappings for Mines / Merge / Nonogram captured.
  4. A non-board-covering win/loss banner placement sketch exists per PiP zone — every one of the 6 zones has a "banner goes here, primary action goes here, board stays visible" annotation, and the gating policy (haptics/SFX/animations + Reduce Motion) is restated for the banner explicitly.
  5. No production app code is written in this phase (sketch HTML / Figma / SwiftUI Preview throwaways are acceptable if they accelerate the decision; they do not ship in the `gamekit` target). The phase exit is a "design locked — Phase 9 can begin" sign-off by Gabe.
**Plans**: 6 plans
- [x] 08-01-screenshot-capture-PLAN.md — Capture 10 fresh game screenshots (Mines E/M/H + Merge + Nonogram x Classic + Dracula) on iPhone 17 Pro Max simulator + capture-log README (CONTEXT D-02..D-04)
- [x] 08-02-compact-row-tokens-PLAN.md — Author 08-COMPACT-ROW-TOKENS.md (radii.button / spacing.xl / spacing.s + per-game slot mappings) + compact-row HTML sketch (CONTEXT D-05..D-08; Phase 8 SC3)
- [x] 08-03-banner-placement-PLAN.md — Author 08-BANNER-PLACEMENT.md (6-row opposite-of-PiP anchor table + DKButton + dampen-to-identity) + banner-placement HTML sketch (CONTEXT D-09..D-12; Phase 8 SC4)
- [x] 08-04-layout-doc-PLAN.md — Author VIDEO-MODE-LAYOUTS.md (5 games x 6 PiP zones x both presets) + 5 per-game overlay HTML sketches (Phase 8 SC1; depends on 08-01)
- [x] 08-05-hard-mines-adr-PLAN.md — 4 candidate-variant HTML sketches + 08-HARD-MINES-ADR.md (Accepted 2026-05-12: smaller-cells / Variant 1) + warning-compromise rollback + 06.1-03 deconfliction (CONTEXT D-13 resolved; Phase 8 SC2)
- [x] 08-06-design-lock-PLAN.md — Pre-flight artifact audit + Gabe's design-lock sign-off + 08-DESIGN-LOCK.md (Phase 8 SC5; unblocks Phase 9) — completed 2026-05-12

### Phase 9: Video Mode Foundation
**Goal**: The plumbing every later phase consumes is in place — a `VideoModeStore` persists the on/off toggle and selected location across launches, Settings exposes both controls plus the "manual selection only" explanation copy, and a single shared compact-control-row component is available for every game screen to adopt. No game layout changes yet; the system reads "off" by default and the existing v1.0 + v1.1 game layouts stay byte-identical.
**Depends on**: Phase 8 (compact-row token spec + Settings copy come from the design doc)
**Requirements**: VIDEO-01, VIDEO-02, VIDEO-03, VIDEO-04, VIDEO-14
**Success Criteria** (what must be TRUE):
  1. Settings exposes a Video Mode Off/On toggle (default Off); flipping it and force-quitting the app, then relaunching, restores the chosen state — persisted under a dedicated UserDefaults key (mirroring the SettingsStore D-29 pattern locked in v1.0 04-04 / 05-01).
  2. When Video Mode is On, Settings reveals a video-location picker with exactly the 6 options from VIDEO-02 (Large top, Large bottom, Small top-left, Small top-right, Small bottom-left, Small bottom-right); the selected location persists across launches and is readable by every game screen via the shared `VideoModeStore` (`@Observable` + custom EnvironmentKey injection, same shape as SettingsStore / AuthStore / CloudSyncStatusObserver).
  3. Settings displays a short explanatory paragraph that includes the "manual selection only" copy from VIDEO-14 verbatim — clarifying that GameDrawer cannot detect another app's PiP automatically. Copy lives in `Localizable.xcstrings`; zero hardcoded strings in source.
  4. A shared `VideoCompactControlRow` (or equivalent) component exists in `Core/` (or `Screens/`) with the design-locked slot order `Back | primary info | picker | secondary info | settings`, reads DesignKit tokens only (zero `Color(...)` / hardcoded `cornerRadius:` / hardcoded `padding(` integers per the cross-cutting invariant), and is consumed by at least one stub call site that compiles.
  5. With Video Mode Off (the default), Minesweeper / Merge / Nonogram render byte-identical to their pre-v1.2 layout — no visual residue from the new system on the off-path. Legibility check passes on Classic preset AND at least one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 for the Settings screen's new Video Mode section.
**Plans**: 8 plans
- [x] 09-01-PLAN.md — Wave 0 TDD RED — 7 test files (14 @Test funcs) covering VIDEO-01..04 + VIDEO-14 + SC5 contract per 09-VALIDATION.md — completed 2026-05-12
- [x] 09-02-PLAN.md — Wave 1 — VideoModeLocation enum (6 cases per D-07) + VideoModeStore @Observable @MainActor class (verbatim SettingsStore mirror per D-05/D-06/D-03); EnvironmentKey extension also shipped here to unblock test-bundle compile (deviation — see 09-02-SUMMARY.md) — completed 2026-05-13
- [x] 09-03-PLAN.md — Wave 2 — VideoModeStore EnvironmentKey extension + GameKitApp.swift 5th-store injection (D-05 lock; closes VideoModeEnvironmentTests RED). EnvironmentKey shipped early in 09-02 (deviation); this plan ships the GameKitApp wiring — completed 2026-05-13
- [x] 09-04-PLAN.md — Wave 2 — 13 videoMode.* xcstring keys including VIDEO-14 verbatim copy (Pitfall 3 — one atomic edit, D-10); LocalizableCatalogTests GREEN — completed 2026-05-12
- [x] 09-05-PLAN.md — Wave 2 — VideoCompactControlRow component (generic @ViewBuilder slots, Phase 8 D-13 tokens, 3-game #Preview = SC4) — completed 2026-05-12
- [x] 09-06-PLAN.md — Wave 3 — SettingsView VIDEO MODE card (D-01 placement, conditional NavigationLink, D-11 no-auto-nav) — completed 2026-05-13
- [x] 09-07-PLAN.md — Wave 3 — VideoLocationPickerView (GeometryReader iPhone-outline per RESEARCH Topic 2, D-02/D-08/D-09/D-10) — completed 2026-05-13
- [x] 09-08-PLAN.md — Wave 4 — SC5 regression contract test + Docs/releases/v1.2.md opening + theme audit checkpoint (CLAUDE.md §8.12 + §8.14) — completed 2026-05-12 (after 4-iteration picker gap closure on 09-07; user-approved)
**UI hint**: yes

### Phase 10: Layout Primitives
**Goal**: The two reflow rules from `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Core rule ("Small PiP = control-aware, Large PiP = board-aware") are implemented as reusable layout primitives, not per-game one-offs. A stub game screen proves both small-PiP corner-avoidance and large-PiP reserved-band behavior across all 6 locations, and toggling Video Mode Off restores the stub's normal layout with no residue.
**Depends on**: Phase 9 (consumes `VideoModeStore` + compact control row component)
**Requirements**: VIDEO-05, VIDEO-06, VIDEO-13
**Success Criteria** (what must be TRUE):
  1. Small-PiP layout primitive: for any selected Small location (TL / TR / BL / BR), back/settings/info chips + the picker are repositioned so the covered corner is empty; the playable board stays at normal size; secondary controls move to the opposite side rather than shrinking the board (per v1.2 plan §Small PiP behavior). Verified on a stub game screen for all 4 Small locations.
  2. Large-PiP layout primitive: for Large top OR Large bottom, the corresponding band is reserved (board cannot extend into it); the board fits between the reserved band and the compact control row; the compromise order from `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Compromise order is honored (secondary controls collapse before the board becomes unplayable). Verified on a stub game screen for both Large locations.
  3. Off-restore: toggling Video Mode Off in Settings while the stub game screen is open restores the stub to its baseline layout immediately (no relaunch required), with no leftover compact-row chrome, no shrunken board, no reserved bands — verified by view-state diff against a control build with Video Mode never enabled.
  4. The primitives are exposed as parameterless or environment-driven SwiftUI surfaces (e.g. `.videoModeAware()` modifier, `VideoModeContainer { ... }` view) that any game screen can adopt with minimal call-site code — adoption shape locked here so Phase 11 / 12 each become "wrap the existing game view" rather than "redesign the existing game view".
  5. Stub game screen legibility verified on Classic preset AND at least one Loud preset (Voltage or Dracula) across all 6 PiP locations per CLAUDE.md §8.12 — chip / picker / info text stays legible on every preset when controls are repositioned.
**Plans**: 4 plans
- [x] 10-01-PLAN.md — Wave 0 RED gate: VideoModeAwareTests.swift (VIDEO-06 + VIDEO-13 SC3) + VideoModeSlotRouterTests.swift (VIDEO-05 — 24 anchor assertions)
- [x] 10-02-PLAN.md — Wave 1 GREEN: VideoModeSlotRouter.swift pure helper (Foundation-only; 6-zone exhaustive switch; VIDEO-05)
- [x] 10-03-PLAN.md — Wave 1 GREEN: VideoModeAware.swift ViewModifier + extension + VideoModeCompactness enum + EnvironmentKey + 12-tile #Preview matrix (VIDEO-06 + VIDEO-13 + SC4 + SC5 surface)
- [x] 10-04-PLAN.md — Wave 2: SC5 visual audit checkpoint + 10-VERIFICATION.md sign-off + Docs/releases/v1.2.md Phase 10 entry
**UI hint**: yes

### Phase 11: Minesweeper Adoption
**Goal**: Minesweeper — the hardest Video Mode case per `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Minesweeper — adopts the layout primitives. Easy + Medium are fully playable across all 6 PiP locations on Classic and one Loud preset. Hard 16×30 ships the strategy chosen in the Phase 8 Hard-Mines ADR (smaller cells, scroll/pan, zoom, or warning + compromise), with rationale traceable back to that ADR by name.
**Depends on**: Phase 10 (consumes layout primitives) AND Phase 8 (consumes the Hard-Mines strategy ADR)
**Requirements**: VIDEO-07, VIDEO-08
**Success Criteria** (what must be TRUE):
  1. Minesweeper Easy (9×9/10) and Medium (16×16/40) are playable across all 6 PiP locations — first-tap, reveal, long-press flag, restart, win, and loss all complete without controls being trapped under the PiP zone for the selected location; manual recipe documents the per-location quick-check (one tap + one flag + one restart per location).
  2. Minesweeper Hard (16×30/99) Video Mode implementation matches the Phase 8 Hard-Mines ADR exactly — the chosen approach (smaller cells / scroll-pan / pinch-zoom / warning + compromise) is implemented, referenced by name in the plan body, and the rejected alternatives are NOT re-debated in this phase. If the ADR mandates a copy string ("Video Mode works best with small PiP on Hard…"), it ships in `Localizable.xcstrings` with the Phase 8 wording.
  3. Hard Minesweeper Video Mode is validated against Gabe's real screenshots (the same screenshots that drove the Phase 8 ADR) — final render parity confirmed for at least Large-top, Large-bottom, and one Small location.
  4. Legibility regression check passes on Classic preset AND one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 for Easy, Medium, AND Hard play state — mines / flags / adjacency numbers stay readable across all 6 PiP locations on both presets.
  5. Video Mode Off restores the v1.0 / v1.0.6.1 Minesweeper layout byte-identical — pinch-zoom (A11Y-05), Reveal/Flag interaction-mode toggle (MINES-12), and the existing animation pass (MINES-08) all behave unchanged with the toggle Off (VIDEO-13 spot-check on Minesweeper).
**Plans**: 8 plans
- [x] 11-01-PLAN.md — Chip extraction: MinesRemainingChip + TimerChip from MinesweeperHeaderBar (CONTEXT D-03)
- [x] 11-02-PLAN.md — Doc supersession: VIDEO-MODE-LAYOUTS.md + 08-COMPACT-ROW-TOKENS.md Mines slot rows updated to D-05 revised order
- [x] 11-03-PLAN.md — Wrap site + three-way layout branch: HomeView `.videoModeAware(minBoardHeight: 480)` + MinesweeperGameView off/Large/Small branch + VideoModeLocation.isLarge (CONTEXT D-01/D-02/D-04/D-09)
- [x] 11-04-PLAN.md — Large-zone compact-row composition: VideoCompactControlRow with D-05 slot order + slot-2 stacked chip + D-18 compactness reactions (CONTEXT D-05/D-06/D-07/D-08/D-18) — 4 rounds of user-feedback polish amended trail (drop gear, compact variants, symmetric chip layout, tightened picker spacers)
- [x] 11-05-PLAN.md — Hard cell-size floor: MinesweeperBoardView.minCellSizeVideoMode locked by audit on Dracula + Voltage; D-12 single-gate; D-17 byte-identical gesture stack preserved (CONTEXT D-10/D-11/D-12/D-17; 08-HARD-MINES-ADR.md)
- [x] 11-06-PLAN.md — A2 NavigationStack safeArea measurement + adjustment (empirical; CONTEXT D-16; 10-VERIFICATION.md carry-forward) — A2 PASSED, no code change
- [x] 11-07-PLAN.md — Author 11-VIDEO-MANUAL-CHECK.md 18-row matrix (3 difficulties × 6 zones) for SC1 + SC3 verification (CONTEXT D-13/D-14/D-15)
- [x] 11-08-PLAN.md — SC4 legibility audit (Classic + Loud × E/M/H × 6 zones) + SC5 Off-restore spot-check + release-log append per CLAUDE.md §8.12 + §8.14 — matrix row 14 PASS, 17 rows DEFERRED to TestFlight; v1.2.md release log appended
**UI hint**: yes

### Phase 12: Merge + Nonogram Adoption
**Goal**: The two remaining v1.1 games — Merge (square board, swipe-driven) and Nonogram (grid + hints) — adopt the Video Mode layout primitives. Both reflow across all 6 PiP locations without legibility regression, with particular care given to Nonogram's row/column hints in Large-top and Large-bottom layouts where vertical real estate is most constrained.
**Depends on**: Phase 11 (consumes the Minesweeper adoption pattern as the worst-case template — Merge + Nonogram are deliberately the easier cases)
**Requirements**: VIDEO-09, VIDEO-10
**Success Criteria** (what must be TRUE):
  1. Merge plays across all 6 PiP locations — swipe-driven tile merging stays gesture-clean (no hijack from system swipe-back at edges; the `.navigationBarBackButtonHidden(true)` + custom toolbar back pattern from v1.0 commit `08d4bee` is preserved in Video Mode), score / mode-picker / best chips reflow per Phase 10 primitives, end-of-game flow remains reachable without an extra tap.
  2. Nonogram plays across all 6 PiP locations — the playable grid stays usable, and **the row + column hints remain readable in Large-top AND Large-bottom layouts** (the worst case for Nonogram per VIDEO-10); hints do not collide with the reserved PiP band, do not collide with the compact control row, and do not shrink below their legibility floor on the smallest supported device.
  3. Legibility regression check passes on Classic preset AND one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 for BOTH games across all 6 PiP locations — Merge tile gradients + Nonogram hint digits + filled/marked cell states all stay readable.
  4. Video Mode Off restores both games' baseline layouts byte-identical — Merge's swipe interaction, score persistence, and current end-of-game overlay all unchanged with the toggle Off (VIDEO-13 spot-check on Merge); Nonogram's swipe-fill / X-mark interactions and current overlays unchanged with the toggle Off (VIDEO-13 spot-check on Nonogram).
  5. The compact control row shape from Phase 9 is consumed verbatim for both games — Merge slots `Back | Score | Mode picker | Best/time | Settings`, Nonogram slots `Back | Lives/size | Fill/Mark picker | Time | Settings` per `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Compact control row; no per-game forking of the shared component.
**Plans**: 6 plans
- [x] 12-01-PLAN.md — Merge chip extraction (MergeScoreChip + MergeBestChip) + TimerChip MOVE to Core/VideoModeTimerChip.swift; Mines's 2 call sites updated (D-12-CHIPS)
- [x] 12-02-PLAN.md — Merge HomeView wrap + MergeGameView three-way layout branch + Large-zone compactRowComposed (D-MG-01) + MergeModePill compact API; MergeGameView+VideoMode.swift sibling extension
- [x] 12-03-PLAN.md — Nonogram chip extraction (NonogramSizeChip + NonogramLivesChip); HeaderBar consumes shared VideoModeTimerChip (D-12-CHIPS / D-12-OFFRESTORE)
- [x] 12-04-PLAN.md — Nonogram HomeView wrap + NonogramGameView three-way layout branch + Large-zone compactRowComposed (D-NG-01 single-slot Size↔Lives swap) + NonogramModePill compact API; NonogramGameView+VideoMode.swift sibling extension
- [x] 12-05-PLAN.md — Nonogram VM-aware cell-size floor seam in NonogramBoardView (D-NG-15) + human-verify audit locked minCellSizeVideoMode = 12pt on Dracula + Voltage @ Hard 15×15 largeBottom; D-NG-17 untouched contract; sibling-extension split per §8.5
- [x] 12-06-PLAN.md — Phase close: 12-VIDEO-MANUAL-CHECK.md 24-row matrix + manual SC1/SC2/SC3/SC4/SC5 sweep + Phase 12 entries in Docs/releases/v1.2.md (closes PARTIAL — SC2 + SC4 + SC5 PASS; SC1 + SC3 FAIL on small-zone routing — gap-closure via Phase 12.1)
**UI hint**: yes

### Phase 12.1: Small-Zone Routing Gap Closure (INSERTED 2026-05-13)
**Goal**: Close the P11 carryforward + P12 verification gap surfaced in `12-VERIFICATION.md` and `12-VIDEO-MANUAL-CHECK.md`: `VideoModeSlotRouter.anchors(for:)` returns correct `anchors.picker` (and a new `anchors.headerBar` seam) values, but `smallZoneToolbarContent` in all 3 adopter games (Minesweeper, Merge, Nonogram) reads only `anchors.back` + `anchors.settings`. The picker (ModePill) stays at default bottom-center where it collides with the bottom-PiP overlay on Bottom L/R Small zones; the HeaderBar chips stay at top-center where they collide with the top-PiP overlay on Top L/R Small zones. This phase wires both seams across all 3 games and re-audits the 4 affected Small-zone rows per game.
**Depends on**: Phase 11 (Mines adoption) + Phase 12 (Merge + Nonogram adoption); inserted between 12 and 13 because the gap blocks v1.2 ship.
**Requirements**: VIDEO-09 (Merge — closure), VIDEO-10 (Nonogram — closure); also closes the P11 carryforward defect against VIDEO-08 (Mines).
**Success Criteria** (what must be TRUE):
  1. **Picker routing wired**: `smallZoneToolbarContent` in `MinesweeperGameView+VideoMode.swift`, `MergeGameView+VideoMode.swift`, and `NonogramGameView+VideoMode.swift` consumes `anchors.picker` to reposition the per-game ModePill (`MinesweeperModePill` / `MergeModePill` / `NonogramModePill`) away from the bottom-center default on Bottom L/R Small zones. The router contract is unchanged — `VideoModeSlotRouter.anchors(for:)` already returns the correct anchor values; the gap is purely call-site consumption.
  2. **HeaderBar reposition seam exists**: A new `anchors.headerBar` slot (or per-game equivalent — planner's choice between extending `SlotAnchorMap` vs. computing inline at the call site) repositions `MinesweeperHeaderBar` / `MergeHeaderBar` / `NonogramHeaderBar` away from the top-center default on Top L/R Small zones so the chips do not collide with the top-PiP overlay. Off-path byte-identity is preserved (HeaderBar consumers still pass NO `compact:` arg on the off-path so the v1.1 / v1.0 render is unchanged).
  3. **Re-audited manual check**: 12 Small-zone matrix rows (4 zones × 3 games — smallTopLeft, smallTopRight, smallBottomLeft, smallBottomRight) re-audited on Classic + Voltage (or Dracula) per CLAUDE.md §8.12. SC1 + SC3 gaps from `12-VIDEO-MANUAL-CHECK.md` flip from FAIL to PASS for all 3 games. Sign-off appended to `12-VIDEO-MANUAL-CHECK.md` (or a sibling 12.1-MANUAL-CHECK.md) with date.
  4. **Off-path byte-identity preserved (VIDEO-13 anchor)**: With Video Mode toggled Off, `MinesweeperGameView` / `MergeGameView` / `NonogramGameView` render byte-identical to pre-12.1 HEAD. Verified via `git diff` confirming no edits to off-path branches AND a behavioral spot-check that `videoModeStore.isEnabled == false` resolves to the existing layout verbatim.
  5. **Large-zone path unchanged**: `compactRowComposed` and `largeZoneLayout` in all 3 games are untouched (or only structurally extracted — no behavioral changes). The Large-zone path already PASSES; do not regress it. Verified via git diff scoped to `largeZoneLayout` + `compactRowComposed` functions.
**Plans**: TBD
**UI hint**: yes

### Phase 13: Win/Loss Banner + A11y Gating
**Goal**: The existing full-screen win/loss overlays (which violate the "board stays visible" rule that defines Video Mode) are replaced by a non-board-covering banner/pill that avoids the selected PiP zone, exposes the primary action (Play Again / Continue) without an extra tap, and routes ALL of its haptics / SFX / animations (including any confetti) through the existing Settings toggles and `accessibilityReduceMotion`. This phase closes the milestone — every other phase's polish surface (animation, haptics, SFX) gets one final pass through the A11y gate.
**Depends on**: Phase 12 (consumes adopted Merge + Nonogram win/loss flows) AND Phase 11 (consumes adopted Minesweeper win/loss flow)
**Requirements**: VIDEO-11, VIDEO-12
**Success Criteria** (what must be TRUE):
  1. Win and loss surfaces in Video Mode use a non-board-covering banner/pill (per `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Win/loss screens "hybrid minimal banner") in all three games (Minesweeper / Merge / Nonogram) — the board remains fully visible behind the banner, and the banner placement avoids the selected PiP zone in all 6 PiP locations.
  2. The primary action on the banner (Play Again / Continue) is reachable in a single tap from the moment the banner appears — no second tap to expand a card, no "tap banner to reveal action" pattern. Manual recipe documents the per-location per-game one-tap-to-restart check.
  3. Haptics gating: any win-banner haptic (success cue, optional arpeggio) is silenced when `settingsStore.hapticsEnabled == false`, gated at the source per the v1.0 05-03 D-10 contract (`hapticsEnabled` is the FIRST guard inside any haptic-firing surface). Verified by a Swift Testing unit test mirroring the v1.0 HapticsTests shape.
  4. SFX gating: any win/loss banner sound is silenced when `settingsStore.sfxEnabled == false` (default false, matching MINES-10 / v1.0 05-03 lock); plays on `AVAudioSession.ambient` (does not duck user music) when enabled, mirroring the SFXPlayer construction lock from v1.0 05-03.
  5. Animation + Reduce Motion gating: any banner confetti / sweep / spring animation is dampened to near-zero when `accessibilityReduceMotion` is on (per the v1.0 05-06 D-04 per-surface lock — `.identity` transition, `.symbolEffect` value=0, `.keyframeAnimator` trigger=false patterns); legibility regression check passes on Classic preset AND one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 for play, win, AND loss states in all three games across all 6 PiP locations.
**Plans**: 5 plans

Plans:
- [ ] 13-01-PLAN.md — Shared `VideoModeBanner` view + `VideoModeBannerContent` PoD struct + `VideoModeBannerAnchor` router + 6-zone exhaustive router tests + haptics FIRST-guard test (Wave 1; C-01/C-02/C-03 LOCKED at UI-SPEC time)
- [ ] 13-02-PLAN.md — Minesweeper banner adoption — `MinesweeperGameView+EndBanner.swift` sibling + replace `endStateOverlay` on Video Mode path only (Wave 2)
- [ ] 13-03-PLAN.md — Merge banner adoption — `MergeGameView+EndBanner.swift` sibling + replace 4 `endStateOverlay(state:)` call sites in `+VideoMode.swift` (Wave 2)
- [ ] 13-04-PLAN.md — Nonogram banner adoption — `NonogramGameView+EndBanner.swift` sibling + replace `endStateOverlay` in `+VideoMode.swift` (Wave 2)
- [ ] 13-05-PLAN.md — Manual audit on iPhone 17 Pro Max sim (Classic + Dracula) + append Phase 13 entries to `Docs/releases/v1.2.md` + flip STATE/ROADMAP/REQUIREMENTS to v1.2 closed (Wave 3; autonomous=false)

**UI hint**: yes

### v1.2 Progress

**Execution Order:**
Phases execute in numeric order within the milestone: 8 (design) → 9 → 10 → 11 → 12 → 13

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 8. Video Mode Design | 6/6 | Complete | 2026-05-12 |
| 9. Video Mode Foundation | 8/8 | Complete | 2026-05-12 |
| 10. Layout Primitives | 4/4 | Complete | 2026-05-13 |
| 11. Minesweeper Adoption | 8/8 | Complete | 2026-05-13 |
| 12. Merge + Nonogram Adoption | 6/6 | Closed (gaps closed by Phase 12.1) | 2026-05-13 |
| 12.1. Small-Zone Routing Gap Closure | redesigned (audit rounds 1–7) | Complete | 2026-05-14 |
| 13. Win/Loss Banner + A11y Gating | shipped (centered card, 2-1 layout, all modes — design diverged from plan via live-sim iteration) | Complete | 2026-05-14 |

### v1.2 Research Flags

Phases that should run `/gsd-research-phase` before planning:

- **Phase 8 (Video Mode Design):** N/A — this phase IS the research/design surface; running a research phase on top of a design phase would be circular. Phase 8 produces the artifacts (annotated screenshots + Hard-Mines ADR + compact-row spec + banner sketch) that downstream phases consume.
- **Phase 10 (Layout Primitives):** YES — the SwiftUI surface for parameterless layout primitives that gracefully degrade across 6 PiP locations on the smallest supported device deserves a focused spike; the trade-off between `@Environment(\.videoModeLocation)` injection vs. a `VideoModeContainer { ... }` view modifier vs. a `.videoModeAware()` modifier is non-obvious and worth resolving before plan-writing.
- **Phase 11 (Minesweeper Adoption):** CONDITIONAL — only if the Phase 8 Hard-Mines ADR picks scroll/pan or pinch-zoom (both interact with the existing A11Y-05 pinch-zoom + auto-scale system from 06.1-03 in ways that need a focused spike to deconflict). If the ADR picks smaller cells or warning-and-compromise, skip research and proceed direct to planning.

Phases with standard patterns (skip research, proceed direct to planning):

- **Phase 9 (Foundation):** Mirrors v1.0 04-04 (SettingsStore) + 05-04 (Settings UI extraction) + 06-07 (Settings SYNC section) patterns — additive @Observable store + custom EnvironmentKey + extracted Settings section.
- **Phase 12 (Merge + Nonogram Adoption):** Once Phase 11 establishes the worst-case adoption template on Minesweeper, Merge + Nonogram are mechanical re-applications of the same wrap-the-game-view pattern.
- **Phase 13 (Win/Loss Banner + A11y Gating):** Reuses the v1.0 05-06 animation-gating + 05-03 haptics/SFX-gating patterns verbatim — banner is just another animation surface routed through the same toggles.

### v1.2 Cross-Cutting Invariants

In addition to the v1.0 cross-cutting invariants above, v1.2 adds:

- **Video Mode Off = byte-identical baseline:** Every Video-Mode-touching code path must include a "toggle Off restores prior layout with no visual residue" check (VIDEO-13). The off-path is the dominant runtime path — most users will never enable Video Mode — and any drift on the off-path is a P0 bug regardless of how well the on-path looks.
- **Manual selection only:** No code path attempts to auto-detect another app's PiP frame (no public iOS API exposes it per VIDEO-14 + PROJECT.md Key Decisions). The Settings copy gate from Phase 9 SC3 is the contract; any future "auto-detect" speculation is rejected at PR time.
- **A11y toggles gate everything Video-Mode-specific:** Every Video-Mode haptic, SFX, animation, banner confetti, and reflow motion routes through `settingsStore.hapticsEnabled`, `settingsStore.sfxEnabled`, and `accessibilityReduceMotion` — gated AT THE SOURCE per the v1.0 05-03 D-10 contract (the toggle is the FIRST guard inside the firing surface). No user-visible motion bypasses these toggles, even on banner confetti, even on the Settings preview rendering.
- **Six PiP locations only — no portrait, no left/right:** v1.2 ships exactly the 6 locations from VIDEO-02 (Large top/bottom, Small TL/TR/BL/BR). Vertical/portrait PiP and Large left/right are explicit Out of Scope per PROJECT.md and REQUIREMENTS.md v1.2 §Out of Scope — speculation on these positions is deferred to v1.3+.

### v1.2 Out-of-Scope Reminder

The following are v1.2-deferred per PROJECT.md and REQUIREMENTS.md and are **not** v1.2 roadmap phases:

- **Auto-detect of another app's PiP frame** — no public iOS API; deferred indefinitely.
- **Sudoku Video Mode adoption** — Sudoku not yet built; will be designed Video-Mode-aware when the game itself lands in a future milestone.
- **Vertical / portrait PiP layouts** — rare in practice; reconsidered at v1.3+ if real usage shows demand.
- **Large left / large right PiP positions** — current observed iOS PiP positions are top + bottom + 4 corners only.
- **Pinch-to-zoom hard Minesweeper as a Video-Mode-specific feature** — only enters scope if the Phase 8 Hard-Mines ADR picks it; otherwise stays a v1.3+ candidate.

---
*Roadmap created: 2026-04-24*
*Phase sequencing: load-bearing convergence between research/ARCHITECTURE.md and research/PITFALLS.md*
*Phase 6 planned: 2026-04-26 — 9 plans (3-wave + verification)*
*Milestone v1.2 (Video Mode) appended: 2026-05-12 — 6 phases (08 design + 09–13 code), 14/14 VIDEO-* requirements mapped*

---

## Milestone v1.5: Endless Arcade Primitive

**Opened:** 2026-06-25
**Granularity:** standard (5–8 phases, 3–5 plans each)
**Coverage:** 22/22 v1.5 requirements mapped ✓
**Phase band:** 15 → 18 (continues from v1.3/v1.4 last integer phase — 14-home-screen-overhaul; numbering never resets per Milestones policy)

### Milestone Overview

v1.5 adds a new interaction primitive to GameDrawer — continuous real-time input + frame loop + score-until-death — that every prior game lacks. The delivery strategy is substrate-first: two new `Core/` files (~160 lines) establish the shared loop driver (`ArcadeLoopDriver`) and lifecycle enum (`ArcadeGameState`), proven by unit tests, before either game compiles against them. Stack then proves the substrate end-to-end (Canvas rendering, drop physics, speed ramp, score persistence). Snake confirms genuine reuse — `Core/` files are unchanged after Snake lands. A final stats-and-polish phase completes the consumer surface: score-based stats screen shape for both games, `DESIGN.md` §12 entries, Video Mode exemption ADR, and cold-start regression check.

Brand constraint is absolute: these are calm endless games, not twitch arcade. Speed plateaus (Stack at ~80 blocks, Snake at ~100ms minimum tick interval), wrap mode default for Snake, no ads/coins/revives/leaderboards. Reduce Motion paths are mandatory — the first continuous-motion games in the suite.

**Architecture decisions locked by research:**
- `TimelineView(.animation(paused:))` as the frame driver (Swift 6 Sendable-safe, declarative pause, ProMotion-adaptive at no cost)
- Fixed-timestep accumulator in the VM with `min(realDt, 0.1)` clamp before the while loop (prevents spiral-of-death)
- `fixedDt = 1/60` for both games (60 Hz simulation; ProMotion renders extra frames without extra engine ticks)
- Pure `mutating func step(dt: Double, input: Input) -> Frame` engine contract (Foundation-only, no SwiftUI, deterministic, seeded RNG)
- Reuse existing `BestScore` / `GameRecord` / `GameStats.record(gameKind:mode:outcome:score:)` — no new SwiftData models needed
- `difficultyRaw = "endless"` for both games (one `BestScore` row per game kind)
- Video Mode explicitly exempt for v1.5 — continuous input cannot pause-and-reflow for PiP (ARCADE-08 ADR)

### v1.5 Phases

- [x] **Phase 15: Arcade Substrate + Skeleton** - Shared loop driver, lifecycle enum, fixed-timestep accumulator with spiral-of-death clamp, scenePhase pause/resume wiring, score persistence schema extensions, Home card stubs — all proven with unit tests before either game ships (completed 2026-06-27)
- [ ] **Phase 16: Stack** - Tap-to-drop tower game proves the substrate end-to-end; Canvas renderer; overhang trim + combo recovery; speed ramp; score persistence; §8.12 theme audit; Reduce Motion path
- [ ] **Phase 17: Snake** - Grid-based endless confirms substrate reuse with zero Core/ changes; swipe + D-pad direction queue; wrap/wall toggle; seeded RNG; §8.12 theme audit; Reduce Motion path
- [ ] **Phase 18: Stats, Design Specs & ADR** - Score-based stats screen shape; DESIGN.md §12 entries (Reduce Motion spec, haptic vocabulary, token map); Video Mode exemption ADR; cold-start regression check; engine purity sign-off

### v1.5 Phase Details

### Phase 15: Arcade Substrate + Skeleton
**Goal**: The shared real-time loop substrate is in place, tested, and paused-safe — both game cards appear on Home and navigate to placeholder screens, but no gameplay exists yet.
**Depends on**: v1.2/v1.4 codebase (additive changes to existing Core/ files only)
**Requirements**: ARCADE-01, ARCADE-02, ARCADE-03, ARCADE-04, ARCADE-05, ARCADE-06, ARCADE-09
**Success Criteria** (what must be TRUE):
  1. Two unit tests gate the substrate before any game is written: (a) `ArcadeLoopDriver` fires `onTick` when `isRunning == true` and produces zero ticks when `false` (game-over, idle, paused); (b) a spiral-of-death test injects `dt = 2.0` and asserts at most 15 engine ticks fire and the function exits cleanly without hanging.
  2. Stack and Snake appear as enabled game cards on Home (via additive `GameKind`, `GameRoute`, `GameDescriptor` cases) and tap-navigate to placeholder game screens; the app compiles with zero Swift 6 strict-concurrency warnings.
  3. The loop pauses on both `scenePhase == .background` AND `scenePhase == .inactive` (notification banners, incoming calls); on foreground resume the accumulated gap is discarded and no time-jump reaches the engine — verified by manual test: receive a notification banner during the placeholder screen, dismiss, confirm no engine time-spike.
  4. Score persistence schema extension is CloudKit-safe: adding `.stack` and `.snake` raw-string `GameKind` values passes the existing `ModelContainerSmokeTests` on both a clean simulator install and a prior-schema simulator store, with no migration and no schema-version bump at the model layer.
  5. Cold-start time on a real device is unchanged from the v1.4 baseline — no `ArcadeLoopDriver` or engine state is allocated at app launch; lazy init verified via Instruments App Launch template before the phase is marked done.
**Plans**: 5 plans
- [x] 15-01-PLAN.md — Substrate primitive (ArcadeGameState + ArcadeLoopDriver) + two locked gate tests
- [x] 15-02-PLAN.md — Throwaway Stack/Snake live-substrate harness views (pause-safe on .inactive + .background)
- [x] 15-03-PLAN.md — GameKind cases + D-07 accents + GameIconView tile icons + StatsView placeholders (CloudKit-safe schema)
- [x] 15-04-PLAN.md — GameRoute + GameDescriptor tiles + HomeView navigation (no .videoModeAware) + Video Mode ADR
- [x] 15-05-PLAN.md — Manual gates: D-04 banner pause, D-08 §8.12 tile theme pass, SC5 Instruments cold-start
**UI hint**: yes

### Phase 16: Stack
**Goal**: Stack is fully playable end-to-end — tap to drop, overhang trim, combo recovery, speed ramp, score persistence — proving the substrate delivers real gameplay through Canvas rendering.
**Depends on**: Phase 15 (`ArcadeLoopDriver` + `ArcadeGameState` + all 7 additive existing-file edits must exist for Stack to compile)
**Requirements**: STACK-01, STACK-02, STACK-03, STACK-04, STACK-05, STACK-06
**Success Criteria** (what must be TRUE):
  1. User can play Stack: tapping drops the oscillating block; overhang beyond the block below is trimmed and the block narrows; a near-perfect drop recovers block width and increments a visible combo counter; the run ends (game-over banner appears with final score) when block width reaches zero.
  2. A unit test with a fixed seed runs `StackEngine` at `dt = 1/60` and at `dt = 1/120` for 5 simulated seconds and asserts identical `score`, `isGameOver`, and tower-block widths — confirming ProMotion-safe physics and the fixed-timestep engine contract.
  3. Block speed ramps with height and plateaus at the calm cap (~80 blocks); the game-over banner appears and the loop is paused (zero CPU); Instruments shows no disk I/O spikes during active gameplay; the high score is persisted to `BestScore` exactly once on game-over (not per-frame); the Stats screen shows a Stack section with high score and runs played.
  4. Stack's `Canvas` board is legible under Classic preset (Chrome Diner) AND at least one Loud/Moody preset (Voltage or Dracula) per §8.12 — all block colors, overhang trim, and score chip read from DesignKit semantic tokens only (no `Color(red:)`, `Color(hex:)`, or SwiftUI system color names in `Games/Stack/`).
  5. Reduce Motion path: when `accessibilityReduceMotion == true`, blocks jump-cut to their computed position each tick (no spring or slide interpolation); gameplay mechanics and speed ramp are unchanged.
**Plans**: 7 plans (4 waves)

Plans:
- [x] 16-01-PLAN.md — StackEngine + StackConfig + determinism tests (Wave 0, STACK-01/02/03)
- [ ] 16-02-PLAN.md — GameStats.recordStackRun + persistence test (Wave 0, STACK-04)
- [ ] 16-03-PLAN.md — StackViewModel: accumulator + counters + save-on-game-over (Wave 1, STACK-01/03/04)
- [ ] 16-04-PLAN.md — StackPalette + StackBoardCanvas Reduce Motion render (Wave 1, STACK-05/06)
- [ ] 16-05-PLAN.md — StackGameView + Home swap + delete harness (Wave 2, STACK-01/03/05/06)
- [ ] 16-06-PLAN.md — StackStatsCard + StatsView wiring (Wave 1, STACK-04)
- [ ] 16-07-PLAN.md — §8.12 + Reduce Motion + Instruments sign-off + release log (Wave 3)
**UI hint**: yes

### Phase 17: Snake
**Goal**: Snake is fully playable — swipe or D-pad turns, grow on food, self-collision ends the run — confirming genuine substrate reuse with zero Core/ changes.
**Depends on**: Phase 16 (Stack exercises score-persistence path before Snake needs it; substrate is proven on a real game)
**Requirements**: SNAKE-01, SNAKE-02, SNAKE-03, SNAKE-04, SNAKE-05, SNAKE-06, SNAKE-07
**Success Criteria** (what must be TRUE):
  1. User can play Snake on a grid: swiping or tapping the D-pad changes direction; eating food grows the snake; self-collision (and wall collision in wall mode) ends the run with a game-over banner; swiping left from the board's left edge does NOT trigger a NavigationStack pop — verified on device with `.defersSystemGestures(on: .all)`.
  2. `SnakeEngine` unit tests run twice with the same pinned seed and assert identical food-spawn sequences, grow events, and collision outcomes; a ProMotion equivalence test confirms `dt = 1/60` vs `dt = 1/120` over 5 simulated seconds produces the same cell-move count and collision state.
  3. After Phase 17 commits land, `git diff HEAD~N -- Core/ArcadeGameState.swift Core/ArcadeLoopDriver.swift` returns empty — zero substrate modifications were needed to accommodate Snake, confirming genuine reuse.
  4. A direction queue of capacity 2 is functional: rapid swipes queued before the next tick fires are preserved; a 180-degree reversal (swipe left while moving right) is rejected; the on-screen D-pad is visible and operational as a secondary directional control.
  5. Snake's board is legible under Classic preset AND at least one Loud/Moody preset per §8.12; Reduce Motion path renders the snake as a jump-cut cell teleport each tick (no between-cell interpolation) while gameplay mechanics are unchanged.
**Plans**: TBD
**UI hint**: yes

### Phase 18: Stats, Design Specs & ADR
**Goal**: Both games are consumer-complete — score-based stats screen shape distinct from turn-based games, DESIGN.md §12 entries written for both games, Video Mode exemption ADR committed, cold-start and engine purity confirmed.
**Depends on**: Phase 17 (both games fully playable; stats screen shape, haptic vocabulary, and token-per-element map can only be written against real running games)
**Requirements**: ARCADE-07, ARCADE-08
**Success Criteria** (what must be TRUE):
  1. The Stats screen presents a score-based shape for Stack and Snake: "High Score" displayed prominently, "Runs Played" shown below; an explicit empty state ("No runs yet.") appears when no runs have been recorded — distinct from the win/loss/best-time columns shown for turn-based games.
  2. `DESIGN.md` §12 receives entries for Stack and Snake specifying: (a) Reduce Motion jump-cut spec — visual motion only, never game mechanics, gated via `@Environment(\.accessibilityReduceMotion)` in the View tier; (b) haptic vocabulary — block land / food eaten = `.impact(weight: .light)`, game-over = `.error`, no per-frame haptics ever; (c) per-element DesignKit token map — body/block = `accentPrimary`, food = `success`, game-over state = `danger`, board background = `background`.
  3. A Video Mode exemption ADR is committed to `.planning/` confirming Stack and Snake are exempt from `.videoModeAware()` in v1.5, with rationale: real-time continuous input cannot pause-and-reflow for a PiP overlay; the exemption call-site in `HomeView.destination(for:)` is documented as the future insertion point if Video Mode is revisited.
  4. Cold-start time on a real device is unchanged from the v1.4 baseline — Instruments App Launch confirms no substrate or engine state is allocated at app launch (all game views are lazily instantiated via `HomeView` navigation).
  5. All new Swift files in `Games/Stack/` and `Games/Snake/` are ≤400 lines; `grep -r "import SwiftUI" Games/Stack/Engine Games/Snake/Engine` returns empty — engine purity confirmed across both games before the milestone is closed.
**Plans**: TBD

### v1.5 Progress

**Execution Order:**
Phases execute in numeric order: 15 → 16 → 17 → 18

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 15. Arcade Substrate + Skeleton | 5/5 | Complete    | 2026-06-27 |
| 16. Stack | 1/7 | In Progress|  |
| 17. Snake | 0/TBD | Not started | - |
| 18. Stats, Design Specs & ADR | 0/TBD | Not started | - |

### v1.5 Research Flags

All phases proceed directly to planning (no research phase needed):

- **Phase 15 (Substrate):** All patterns codebase-verified by the research agent. `ViewModifier` shape confirmed against `VideoModeAware.swift`; persistence reuse confirmed by direct `GameStats.swift` source inspection at line 113.
- **Phase 16 (Stack):** Canvas + TimelineView confirmed via Apple docs; `GraphicsContext.Shading.color(_:)` takes `SwiftUI.Color` so DesignKit tokens feed directly. Speed ramp constants are MEDIUM confidence; tune on device during implementation.
- **Phase 17 (Snake):** Engine pattern, direction queue, and drag gesture all confirmed. One on-device profiling check early in the phase: LazyVGrid vs. Canvas at 60 Hz for the board — switch is local to `SnakeBoardView.swift` and does not affect engine or VM.
- **Phase 18 (Stats & Polish):** Checklist and tuning work. No research needed.

### v1.5 Cross-Cutting Invariants

In addition to the v1.0 / v1.2 cross-cutting invariants, v1.5 adds:

- **Engine purity:** `StackEngine` and `SnakeEngine` must have zero `import SwiftUI` and zero `import SwiftData`. Enforced by grep check returning empty at each game phase close. Same invariant as `RevealEngine` / `MergeEngine` — never relaxed.
- **Fixed-timestep accumulator with max-dt clamp:** Every arcade VM clamps real dt before accumulating: `min(realDt, 0.1)`. Missing this clamp = spiral-of-death on resume from background. Established in Phase 15; each game phase verifies the clamp is intact.
- **Save exactly once on game-over:** `BestScore` / `GameRecord` writes fire on the game-over state transition only — never inside the frame-tick closure. Disk I/O during active gameplay is a P0 regression (Instruments verifies at phase close).
- **No per-frame haptics:** Haptics carry information per DESIGN.md §8. Haptics fire only on milestone events (block land, food eaten, game-over). A haptic every tick at 60 Hz is vibration spam.
- **Reduce Motion = jump-cut, not game halt:** `accessibilityReduceMotion` suppresses visual interpolation only; game speed, rules, and mechanics are unchanged. Gated exclusively in the View tier — engine and VM never read accessibility flags.
- **Video Mode exempt:** Stack and Snake do not receive `.videoModeAware(minBoardHeight:)` in `HomeView.destination(for:)`. No `+VideoMode.swift` extension files for these games in v1.5. The exemption is documented in the Phase 18 ADR.

### v1.5 Out-of-Scope Reminder

The following are explicitly out of scope for v1.5 per `REQUIREMENTS.md §v1.5 Out of Scope`:

- Daily seed / daily challenge — engagement retention layer; parked for v1.6+
- Twitch/reflex arcade (Flappy-style, rhythm-tap, falling-blocks) — mood-gated for a later milestone; v1.5 is calm-only
- Video Mode adoption for Stack and Snake — real-time continuous input cannot pause-and-reflow for PiP (ARCADE-08 ADR closes this)
- Online leaderboards / accounts / any monetization — permanent exclusion per core value

---
*Milestone v1.5 (Endless Arcade Primitive) appended: 2026-06-25 — 4 phases (15–18), 22/22 ARCADE/STACK/SNAKE requirements mapped*
