# Requirements: GameKit

**Defined:** 2026-04-24
**Core Value:** Calm, premium, fully theme-customizable gameplay with zero friction — no ads, no coins, no pushy subscriptions, no required accounts.

## v1 Requirements

Requirements for initial TestFlight → App Store release. MVP scope: **Minesweeper only.** Each maps to a roadmap phase.

### Foundation

- [x] **FOUND-01
**: App launches to Home in <1s on cold start (recent device)
- [x] **FOUND-02
**: DesignKit consumed as local SPM dependency from `../DesignKit`
- [x] **FOUND-03
**: Global `ThemeManager` injected via `@EnvironmentObject`; every visible pixel reads a theme token (no hardcoded colors / radii / spacing)
- [x] **FOUND-04
**: Bundle identifier is `com.lauterstar.gamekit`; iOS 17+ deployment target; Swift 6 strict concurrency ON
- [x] **FOUND-05
**: All user-facing strings use `String(localized:)` with an `xcstrings` catalog (EN-only at v1, future locales mechanical)
- [x] **FOUND-06
**: Placeholder app icon shipped (DesignKit colors); user replaces with real icon before App Store
- [x] **FOUND-07
**: Pre-commit hooks reject hardcoded `Color(...)`, `cornerRadius: <int>`, `padding(<int>)` in `Games/` and `Screens/`, plus Finder-dupe `* 2.swift` files

### App Shell

- [x] **SHELL-01
**: Home screen lists Minesweeper as the only active game card; future-game placeholders are visually present but disabled
- [ ] **SHELL-02**: Settings screen with theme picker (5 Classic swatches inline + "More themes & custom colors" link to full `DKThemePicker`), haptics toggle, SFX toggle, reset stats, about
- [ ] **SHELL-03**: Stats screen shows per-difficulty: games played · wins · win % · best time
- [ ] **SHELL-04**: 3-step intro on first launch (themes → stats → optional sign-in card with Skip), dismissable, never shown again

### Minesweeper

- [x] **MINES-01**: Three difficulties — Easy 9×9/10 mines, Medium 16×16/40, Hard 16×30/99 (Phase 02 Plan 01: locked in MinesweeperDifficulty enum)
- [x] **MINES-02
**: Tap to reveal, long-press to flag (composed `LongPressGesture(0.25s).exclusively(before: TapGesture())`)
- [ ] **MINES-03**: First tap is always safe — mines placed *after* first tap, excluding tapped cell + its 8 bounds-clamped neighbors
- [x] **MINES-04
**: Iterative flood-fill reveal for empty cells to the next numbered border (no recursion)
- [x] **MINES-05
**: Mine counter (mines remaining = total − flagged) and elapsed wall-clock timer always visible; timer pauses on scene-phase background
- [x] **MINES-06
**: Restart button on the game screen
- [x] **MINES-07
**: Win = all non-mine cells revealed; Loss = mine revealed; both surface a clear end-state overlay using `theme.colors.{success,danger}`
- [ ] **MINES-08**: Polished animation pass — reveal cascade, flag spring, win-board sweep, loss-shake — all timed via `theme.motion.{fast,normal,slow}`
- [ ] **MINES-09**: DesignKit haptics on flag, reveal, win, loss; respects Settings haptics toggle
- [ ] **MINES-10**: Subtle SFX on tap / win / loss, **off by default**, toggle in Settings; uses `AVAudioSession.ambient` (does not duck user music)
- [x] **MINES-11
**: On loss, all mines reveal and incorrectly-flagged cells are marked with an X indicator (industry standard)

### Persistence & Sync

- [x] **PERSIST-01
**: Stats backed by **SwiftData** with CloudKit-compatible schema from day 1 (all properties optional or defaulted, no `@Attribute(.unique)`, all relationships optional, `schemaVersion: Int = 1`)
- [ ] **PERSIST-02**: Stats survive app force-quit, crash, and device reboot — explicit `try modelContext.save()` on terminal-state detection
- [ ] **PERSIST-03**: Export/Import JSON of stats with `schemaVersion`; round-trips cleanly via `fileExporter`/`fileImporter`
- [ ] **PERSIST-04**: Optional **Sign in with Apple + CloudKit private DB** for cross-device persistence; full feature parity without sign-in
- [ ] **PERSIST-05**: Sign-in surfaced once in 3-step intro and again in Settings; never gates gameplay; never nags
- [ ] **PERSIST-06**: Anonymous local profile created on first launch; signing in promotes local data to cloud with no data loss; sync-status row in Settings reports state ("Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]")

### Theming Responsiveness

- [ ] **THEME-01**: Minesweeper UI verified legible on at least one preset from each DesignKit category — Classic, Sweet, Bright, Soft, Moody, Loud — for both play state AND loss state, before TestFlight
- [x] **THEME-02
**: Revealed-vs-unrevealed cells, mines, flags, and adjacency numbers all read from semantic tokens; new `theme.colors.gameNumber(_:)` token (1–8) added to DesignKit for the informational number palette
- [ ] **THEME-03**: Custom-palette overrides via `ThemeManager.overrides` work end-to-end through the Mines grid

### Accessibility

- [ ] **A11Y-01**: Dynamic Type respected on all non-grid text
- [x] **A11Y-02
**: VoiceOver labels on cells (state + position + adjacency), buttons, and overlays — baked in at view creation, not retrofit
- [ ] **A11Y-03**: Reduce-motion preference dampens the animation pass
- [x] **A11Y-04
**: Default number palette (the `theme.colors.gameNumber(_:)` token in DesignKit) is color-blind-safe by default — verified against Wong-palette principles for protanopia / deuteranopia / tritanopia

## v2 Requirements

Deferred to a post-MVP milestone. Tracked but not in the current roadmap.

### Minesweeper Variants

- **MINES-V2-01**: Chord clicks — tap a number with all flags placed reveals neighbors (classic PC behavior)
- **MINES-V2-02**: No-guess board generator — guarantees boards solvable without guessing (HIGH algorithmic complexity, requires perf spike)
- **MINES-V2-03**: Hint system — user can request a hint (reveals one safe cell, logged in stats)
- **MINES-V2-04**: Custom board sizes — user-defined rows/columns/mines beyond easy/medium/hard
- **MINES-V2-05**: Question-mark cell state (opt-in, off by default)

### Stats Depth

- **STATS-V2-01**: 3BV / 3BV/s computed at win-time and surfaced in Stats
- **STATS-V2-02**: Win-rate trend chart over time (Swift Charts via DesignKit)
- **STATS-V2-03**: Time-distribution histogram per difficulty
- **STATS-V2-04**: Recent-history list (last 20 games)

### Engagement (the GOOD kind)

- **DAILY-V2-01**: Daily seed / daily challenge with deterministic-seed source
- **DAILY-V2-02**: Streak counter (neutral display only — no shaming)
- **DAILY-V2-03**: Share card for daily challenge result

### Themes & A11y Extensions

- **THEME-V2-01**: Color-blind named DesignKit preset(s) (Wong / IBM palettes)
- **A11Y-V2-01**: VoiceOver-playable Mines as a deliberate feature (full play, not just labels)
- **A11Y-V2-02**: Pinch-to-zoom on Hard board

### Suite Expansion (separate milestones each)

- **SUITE-V2-01**: 2048-style Merge — second game; validates multi-game architecture + DesignKit reuse
- **SUITE-V2-02**: Word Grid — drag-to-form-words, dictionary validation
- **SUITE-V2-03**: Solitaire (Klondike)
- **SUITE-V2-04**: Sudoku
- **SUITE-V2-05**: Nonogram, Flow, Pattern Memory, Chess puzzles (further milestones)

### Localization

- **L10N-V2-01**: Translations beyond English (xcstrings catalog already in place)

### Distribution

- **DIST-V2-01**: Per-game alt-icon variants (alt icons API)
- **DIST-V2-02**: App Shortcuts ("Start Easy game", "Continue last")

## Out of Scope

Explicit exclusions. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Banner / interstitial / video ads | Kills the differentiator. Permanent. |
| Coins, fake currency, energy systems, hearts, power-ups | Same. Calm-and-premium posture is the product. |
| Aggressive subscription paywalls | Same. Future monetization is one-time unlock or tip jar only. |
| Required accounts | Sign-in is *optional only*; never blocks gameplay. |
| Streak-shaming / push-notification-nagging-return / pop-up rate-this-app modals | Dark patterns. Permanent NEVER list. |
| Third-party backend (Firebase, Supabase, custom server) | CloudKit-only; preserves "no analytics, no servers we don't own" posture. |
| Analytics / telemetry SDKs | App does not phone home. Period. |
| Multiplayer / leaderboards / social | Out of scope through MVP and likely beyond. |
| A second game in v1 | Prove Minesweeper before splitting focus across multi-game bug surface. |
| Asset-heavy games (custom illustrations, sprites) | DesignKit-only games for the foreseeable suite. |
| Localizations beyond EN at v1 ship | Strings are i18n-ready; translations come later. |
| `CKSyncEngine` for CloudKit | SwiftData's built-in mirror is the right default for private-DB-only. |
| `@ModelActor` for MVP writes | All Mines writes are <10ms and main-actor-bound. Add only when measurement justifies. |
| `Canvas`-rendered Mines board | Loses per-cell accessibility and hit-testing. `LazyVGrid`/`Grid` of cell views is correct. |
| `GameProtocol` / runtime game registry / per-game `@Model`s | Premature abstraction — the right shape emerges from games 2/3, not from speculation. |
| TCA / Redux / heavy state libraries | Lightweight MVVM with `@Observable` is sufficient. |

## Traceability

Each v1 requirement maps to exactly one phase. Phase numbers populated 2026-04-24 by the roadmapper.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Pending |
| FOUND-02 | Phase 1 | Pending |
| FOUND-03 | Phase 1 | Pending |
| FOUND-04 | Phase 1 | Pending |
| FOUND-05 | Phase 1 | Pending |
| FOUND-06 | Phase 1 | Pending |
| FOUND-07 | Phase 1 | Pending |
| SHELL-01 | Phase 1 | Pending |
| SHELL-02 | Phase 5 | Pending |
| SHELL-03 | Phase 4 | Pending |
| SHELL-04 | Phase 5 | Pending |
| MINES-01 | Phase 2 | Complete (02-01) |
| MINES-02 | Phase 3 | Pending |
| MINES-03 | Phase 2 | Pending |
| MINES-04 | Phase 2 | Pending |
| MINES-05 | Phase 3 | Pending |
| MINES-06 | Phase 3 | Pending |
| MINES-07 | Phase 3 | Pending |
| MINES-08 | Phase 5 | Pending |
| MINES-09 | Phase 5 | Pending |
| MINES-10 | Phase 5 | Pending |
| MINES-11 | Phase 3 | Pending |
| PERSIST-01 | Phase 4 | Complete |
| PERSIST-02 | Phase 4 | Pending |
| PERSIST-03 | Phase 4 | Pending |
| PERSIST-04 | Phase 6 | Pending |
| PERSIST-05 | Phase 6 | Pending |
| PERSIST-06 | Phase 6 | Pending |
| THEME-01 | Phase 5 | Pending |
| THEME-02 | Phase 3 | Pending |
| THEME-03 | Phase 5 | Pending |
| A11Y-01 | Phase 5 | Pending |
| A11Y-02 | Phase 5 | Pending |
| A11Y-03 | Phase 5 | Pending |
| A11Y-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35 ✓
- Unmapped: 0

**Notes on placement:**
- **A11Y-02 (VoiceOver labels) is mapped to Phase 5** but cell-level `accessibilityLabel` is *baked in* at Phase 3 per PITFALLS Pitfall 13 (cheaper to bake in with the cell view than retrofit). Phase 5 polishes the labels on buttons, overlays, and the full VoiceOver navigation pass — Phase 3 ensures cells aren't retrofit.
- **MINES-03 / MINES-04 / MINES-07 (engine-side) at Phase 2; MINES-07 (UI-side overlay) at Phase 3** — engine detection of win/loss lands at P2 in WinDetector tests; the actual user-visible overlay using `theme.colors.{success,danger}` lands at P3.
- **THEME-02 at Phase 3** because the new `theme.colors.gameNumber(_:)` token must be added to DesignKit and consumed by Mines cells in Phase 3 (no hardcoded greys from day 1). The full 6-category legibility audit is Phase 5 (THEME-01).
- **SHELL-01 at Phase 1** ships the skeletal Home with Minesweeper as the only enabled card; SHELL-02 / SHELL-04 (Settings spine, intro flow) ship with the polish pass at Phase 5 alongside the haptics/SFX toggles they configure.

---
*Requirements defined: 2026-04-24*
*Traceability populated: 2026-04-24 — all 35 v1 requirements mapped*
