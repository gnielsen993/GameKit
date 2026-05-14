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
- [x] **SHELL-02
**: Settings screen with theme picker (5 Classic swatches inline + "More themes & custom colors" link to full `DKThemePicker`), haptics toggle, SFX toggle, reset stats, about
- [x] **SHELL-03
**: Stats screen shows per-difficulty: games played · wins · win % · best time
- [x] **SHELL-04
**: 3-step intro on first launch (themes → stats → optional sign-in card with Skip), dismissable, never shown again
- [x] **SHELL-05
**: Home shows 2 game-tile cards in a 2-column square grid: Mines (enabled) + Upcoming (opens list of planned games)

### Minesweeper

- [x] **MINES-01**: Three difficulties — Easy 9×9/10 mines, Medium 16×16/40, Hard 16×30/99 (Phase 02 Plan 01: locked in MinesweeperDifficulty enum)
- [x] **MINES-02
**: Tap to reveal, long-press to flag (composed `LongPressGesture(0.25s).exclusively(before: TapGesture())`)
- [x] **MINES-03**: First tap is always safe — mines placed *after* first tap, excluding tapped cell + its 8 bounds-clamped neighbors
- [x] **MINES-04
**: Iterative flood-fill reveal for empty cells to the next numbered border (no recursion)
- [x] **MINES-05
**: Mine counter (mines remaining = total − flagged) and elapsed wall-clock timer always visible; timer pauses on scene-phase background
- [x] **MINES-06
**: Restart button on the game screen
- [x] **MINES-07
**: Win = all non-mine cells revealed; Loss = mine revealed; both surface a clear end-state overlay using `theme.colors.{success,danger}`
- [x] **MINES-08
**: Polished animation pass — reveal cascade, flag spring, win-board sweep, loss-shake — all timed via `theme.motion.{fast,normal,slow}`
- [x] **MINES-09
**: DesignKit haptics on flag, reveal, win, loss; respects Settings haptics toggle
- [x] **MINES-10
**: Subtle SFX on tap / win / loss, **off by default**, toggle in Settings; uses `AVAudioSession.ambient` (does not duck user music)
- [x] **MINES-11
**: On loss, all mines reveal and incorrectly-flagged cells are marked with an X indicator (industry standard)
- [x] **MINES-12
**: Reveal/Flag interaction mode toggle. Tap action depends on current mode (.reveal: tap reveals, long-press flags; .flag: tap toggles flag, long-press reveals). Default = .reveal; resets per-game on restart()

### Persistence & Sync

- [x] **PERSIST-01
**: Stats backed by **SwiftData** with CloudKit-compatible schema from day 1 (all properties optional or defaulted, no `@Attribute(.unique)`, all relationships optional, `schemaVersion: Int = 1`)
- [x] **PERSIST-02
**: Stats survive app force-quit, crash, and device reboot — explicit `try modelContext.save()` on terminal-state detection
- [x] **PERSIST-03
**: Export/Import JSON of stats with `schemaVersion`; round-trips cleanly via `fileExporter`/`fileImporter`
- [x] **PERSIST-04**: Optional **Sign in with Apple + CloudKit private DB** for cross-device persistence; full feature parity without sign-in
- [x] **PERSIST-05**: Sign-in surfaced once in 3-step intro and again in Settings; never gates gameplay; never nags
- [x] **PERSIST-06
**: Anonymous local profile created on first launch; signing in promotes local data to cloud with no data loss; sync-status row in Settings reports state ("Synced just now" / "Syncing…" / "Not signed in" / "iCloud unavailable — last synced [date]")

### Theming Responsiveness

- [x] **THEME-01
**: Minesweeper UI verified legible on at least one preset from each DesignKit category — Classic, Sweet, Bright, Soft, Moody, Loud — for both play state AND loss state, before TestFlight
- [x] **THEME-02
**: Revealed-vs-unrevealed cells, mines, flags, and adjacency numbers all read from semantic tokens; new `theme.colors.gameNumber(_:)` token (1–8) added to DesignKit for the informational number palette
- [x] **THEME-03
**: Custom-palette overrides via `ThemeManager.overrides` work end-to-end through the Mines grid

### Accessibility

- [x] **A11Y-01
**: Dynamic Type respected on all non-grid text
- [x] **A11Y-02
**: VoiceOver labels on cells (state + position + adjacency), buttons, and overlays — baked in at view creation, not retrofit
- [x] **A11Y-03
**: Reduce-motion preference dampens the animation pass
- [x] **A11Y-04
**: Default number palette (the `theme.colors.gameNumber(_:)` token in DesignKit) is color-blind-safe by default — verified against Wong-palette principles for protanopia / deuteranopia / tritanopia
- [x] **A11Y-05
**: Pinch-to-zoom on Mines board (any difficulty); scale range 0.8x-2.0x; persists across restart within session (graduates A11Y-V2-02)

## v1.2 Requirements — Video Mode

**Defined:** 2026-05-12
**Scope:** Optional mode that keeps GameDrawer playable while a PiP video floats on screen. User picks the video location manually; layout adapts.

### Settings & Persistence

- [x] **VIDEO-01
**: Settings exposes Video Mode Off/On toggle (default Off); state persisted across launches
- [x] **VIDEO-02
**: When Video Mode is On, Settings exposes a video-location picker with exactly 6 options: Large top, Large bottom, Small top-left, Small top-right, Small bottom-left, Small bottom-right
- [x] **VIDEO-03
**: Selected location persists across launches and is observable by every game screen via a shared store
- [x] **VIDEO-14
**: Settings copy explains Video Mode in one short paragraph + clarifies that GameDrawer cannot detect another app's PiP automatically (manual selection only)

### Layout Engine

- [x] **VIDEO-04
**: Shared compact control row component used by games in Video Mode — order Back | primary info | picker | secondary info | settings; reads DesignKit tokens only
- [x] **VIDEO-05
**: Small-PiP layout — game board stays at normal size; back/settings/info chips and the picker are repositioned so the covered corner is empty for the selected Small location
- [ ] **VIDEO-06**: Large-PiP layout — top or bottom band is reserved per selection; board fits between the reserved band and the compact control row; secondary controls collapse before the board becomes unplayable
- [ ] **VIDEO-13**: Video Mode adapts only when On — toggling Off restores each game's normal layout with no visual residue

### Per-Game Adoption

- [x] **VIDEO-07
**: Minesweeper adopts Video Mode for Easy + Medium across all 6 locations with no legibility regression on Classic or one Loud preset
- [x] **VIDEO-08
**: Minesweeper Hard (16×30) Video Mode strategy validated against real screenshots — final approach (smaller cells / scroll / zoom / warning) chosen with rationale recorded in ADR
- [ ] **VIDEO-09**: Merge adopts Video Mode across all 6 locations with no legibility regression on Classic + one Loud preset
- [ ] **VIDEO-10**: Nonogram adopts Video Mode across all 6 locations; hints + grid stay readable in Large-top and Large-bottom layouts

### Win/Loss & A11y Gating

- [ ] **VIDEO-11**: Win/loss surfaces use a non-board-covering banner/pill in Video Mode; primary action (Play Again / Continue) reachable without an extra tap; banner placement avoids the selected PiP zone
- [ ] **VIDEO-12**: All Video-Mode-related haptics, SFX, and animations (including any win banner confetti) respect existing Settings haptics/SFX/animations toggles and `accessibilityReduceMotion`

### Out of Scope for v1.2

| Feature | Reason |
|---------|--------|
| Auto-detect of another app's PiP frame | No public iOS API exposes another app's PiP location to third-party apps |
| Sudoku adoption | Game not built yet; will be designed Video-Mode-aware when added |
| Vertical / portrait PiP layouts | Rare in practice; reconsider v1.3+ if usage shows it matters |
| Large left / large right PiP | Current observed PiP positions are top and bottom only |
| Pinch-to-zoom hard board (if not chosen for VIDEO-08) | Stays a v1.3+ candidate if scroll or smaller cells win |

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
| FOUND-01 | Phase 1 | Complete (01) |
| FOUND-02 | Phase 1 | Complete (01) |
| FOUND-03 | Phase 1 | Complete (01) |
| FOUND-04 | Phase 1 | Complete (01) |
| FOUND-05 | Phase 1 | Complete (01) |
| FOUND-06 | Phase 1 | Complete (01) |
| FOUND-07 | Phase 1 | Complete (01) |
| SHELL-01 | Phase 1 | Complete (01) |
| SHELL-02 | Phase 5 | Complete (05-04) |
| SHELL-03 | Phase 4 | Complete (04-05) |
| SHELL-04 | Phase 5 | Complete (05-05) |
| SHELL-05 | Phase 6.1 | Complete (06.1-01) |
| MINES-01 | Phase 2 | Complete (02-01) |
| MINES-02 | Phase 3 | Complete (03-04) |
| MINES-03 | Phase 2 | Complete (02-03) |
| MINES-04 | Phase 2 | Complete (02-04) |
| MINES-05 | Phase 3 | Complete (03-03) |
| MINES-06 | Phase 3 | Complete (03-04) |
| MINES-07 | Phase 3 | Complete (03-03) |
| MINES-08 | Phase 5 | Complete (05-06) |
| MINES-09 | Phase 5 | Complete (05-03) |
| MINES-10 | Phase 5 | Complete (05, G-1 deferred) |
| MINES-11 | Phase 3 | Complete (03-03) |
| MINES-12 | Phase 6.1 | Complete (06.1-02) |
| PERSIST-01 | Phase 4 | Complete (04-01) |
| PERSIST-02 | Phase 4 | Complete (04-06) |
| PERSIST-03 | Phase 4 | Complete (04-03) |
| PERSIST-04 | Phase 6 | Complete (06-08) |
| PERSIST-05 | Phase 6 | Complete (06-08) |
| PERSIST-06 | Phase 6 | Complete (06-08) |
| THEME-01 | Phase 5 | Complete (05-07) |
| THEME-02 | Phase 3 | Complete (03-01) |
| THEME-03 | Phase 5 | Complete (05-07) |
| A11Y-01 | Phase 5 | Complete (05-05) |
| A11Y-02 | Phase 5 | Complete (05-05) |
| A11Y-03 | Phase 5 | Complete (05-06) |
| A11Y-04 | Phase 5 | Complete (05-07) |
| A11Y-05 | Phase 6.1 | Complete (06.1-03) |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 38 ✓
- Unmapped: 0

### v1.2 Traceability

Populated 2026-05-12 by the roadmapper. Phase numbering continues from v1.0's last integer phase (7) — v1.2 occupies the 8–13 band, design-first (Phase 8) followed by code phases (9–13).

| Requirement | Phase | Status |
|-------------|-------|--------|
| VIDEO-01 | Phase 9 | Complete (09-02 + 09-06) |
| VIDEO-02 | Phase 9 | Complete (09-02 + 09-07) |
| VIDEO-03 | Phase 9 | Complete (09-02 + 09-03) |
| VIDEO-04 | Phase 9 | Complete (09-05) |
| VIDEO-05 | Phase 10 | Pending |
| VIDEO-06 | Phase 10 | Pending |
| VIDEO-07 | Phase 11 | Pending |
| VIDEO-08 | Phase 11 | Pending |
| VIDEO-09 | Phase 12 | Pending |
| VIDEO-10 | Phase 12 | Pending |
| VIDEO-11 | Phase 13 | Pending |
| VIDEO-12 | Phase 13 | Pending |
| VIDEO-13 | Phase 10 | Pending |
| VIDEO-14 | Phase 9 | Complete (09-04 + 09-07) |

**v1.2 Coverage:**
- v1.2 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0
- Phase 8 (Video Mode Design) intentionally has no VIDEO-* mappings — it is the design-gate phase that produces the screenshot-annotated layout doc + Hard-Mines ADR + compact-row design tokens + win/loss banner sketch consumed by Phases 9–13. Per `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §"Design phase required": "Do not skip this and jump straight to code."

**Notes on v1.2 placement:**
- **VIDEO-04 (compact control row component) is in Phase 9, not Phase 10**, because the component is plumbing every other phase consumes — building it alongside the store + Settings UI keeps the foundation phase coherent ("everything every game needs to read Video Mode state") while Phase 10 stays focused on the small/large/off reflow primitives that consume that component.
- **VIDEO-13 (Off-restore) is in Phase 10, not Phase 9**, because the off-restore guarantee is fundamentally a layout-primitive concern — it asserts that the layout primitives degrade gracefully to the baseline layout, which can only be proven once the primitives exist. Each adoption phase (11 / 12 / 13) then carries a per-game off-restore spot-check in its own Success Criteria.
- **VIDEO-08 (Hard Minesweeper strategy) is implemented in Phase 11**, but the *decision* (smaller cells / scroll / zoom / warning) is locked at Phase 8 in the Hard-Mines ADR. Phase 11's Success Criteria reference the ADR by name rather than re-deciding the approach.
- **VIDEO-11 + VIDEO-12 (banner + a11y gating) bundled into Phase 13** because the banner IS the surface the a11y gates apply to — splitting them would create a phase where the banner ships without proper gating (a P0 a11y bug) or the gating ships without the surface to gate.

**Notes on v1 placement (carried forward):**
- **A11Y-02 (VoiceOver labels) is mapped to Phase 5** but cell-level `accessibilityLabel` is *baked in* at Phase 3 per PITFALLS Pitfall 13 (cheaper to bake in with the cell view than retrofit). Phase 5 polishes the labels on buttons, overlays, and the full VoiceOver navigation pass — Phase 3 ensures cells aren't retrofit.
- **MINES-03 / MINES-04 / MINES-07 (engine-side) at Phase 2; MINES-07 (UI-side overlay) at Phase 3** — engine detection of win/loss lands at P2 in WinDetector tests; the actual user-visible overlay using `theme.colors.{success,danger}` lands at P3.
- **THEME-02 at Phase 3** because the new `theme.colors.gameNumber(_:)` token must be added to DesignKit and consumed by Mines cells in Phase 3 (no hardcoded greys from day 1). The full 6-category legibility audit is Phase 5 (THEME-01).
- **SHELL-01 at Phase 1** ships the skeletal Home with Minesweeper as the only enabled card; SHELL-02 / SHELL-04 (Settings spine, intro flow) ship with the polish pass at Phase 5 alongside the haptics/SFX toggles they configure.
- **A11Y-05 graduated from A11Y-V2-02** at Phase 6.1 — pinch-zoom delivered as part of the pre-release polish pass alongside the auto-scale cellSize formula that eliminates Hard horizontal scroll on standard iPhone widths.

---
*Requirements defined: 2026-04-24*
*Traceability populated: 2026-04-24 — all 35 v1 requirements mapped*
*v1.2 Video Mode requirements added: 2026-05-12 — VIDEO-01..14*
*v1.2 Traceability populated: 2026-05-12 — all 14 v1.2 requirements mapped (Phase 8 design gate, Phases 9–13 implementation)*
