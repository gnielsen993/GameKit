# GameKit

## Current Milestone: v1.5 Endless Arcade Primitive

**Goal:** Expand the suite into a new category — real-time endless arcade — by building one reusable game-loop substrate and shipping two *calm* endless games on it.

**Target features:**
- Shared real-time loop substrate (`Core/`): `TimelineView`/`CADisplayLink` driver feeding a pure, deterministic `step(dt:input:)` tick-engine contract; idle→running→game-over→restart lifecycle; tap-to-start affordance + game-over banner.
- High-score persistence extending the existing SwiftData stats layer (`GameRecord` / `BestTime`) — score-based, not win/loss.
- **Stack** — flagship calm endless (tap-to-drop block tower, overhang shaving, speed ramp).
- **Snake** — classic calm endless (grid-based, swipe/tap-to-turn, growth + self-collision).
- Reduce Motion path for both (motion-heavy games).

**Out of scope for v1.5:**
- Twitch/reflex arcade (renamed Flappy-style, rhythm-tap, falling-blocks) — parked in `.planning/UPCOMING-GAMES.md` for a later, mood-gated milestone.
- Video Mode adoption for these games — real-time continuous input can't pause-and-reflow for PiP; likely exempt (confirm in discuss-phase).
- Chess puzzles (own milestone — needs move engine + puzzle DB).
- Word / Solitaire / Sudoku depth expansion (later "go deep" milestone).

> Shipped prior to v1.5: Minesweeper (v1.0), Merge + Nonogram (v1.1), FreeCell Solitaire + Sudoku (v1.3), Five Letter + Word Grid (v1.4). The "What This Is" / MVP framing below predates the multi-game suite and is refreshed at the next full milestone-complete review.

## What This Is

GameKit is a clean, ad-free iOS suite of classic logic games built in Swift /
SwiftUI on top of the shared **DesignKit** Swift Package. The MVP is
**Minesweeper only** — prove one game lands well before any second game enters
scope. Personal-use first, but engineered to be App Store–shippable from day 1
so no scope-driven rewrites are needed later.

> Classic logic games. No ads. No noise. Just play.

## Core Value

**Calm, premium, fully theme-customizable gameplay with zero friction —
no ads, no coins, no pushy subscriptions, no required accounts.** If
everything else fails, this differentiator must not.

## Requirements

### Validated

(None yet — ship to validate)

### Active

#### Foundation
- [ ] **FOUND-01**: App launches to Home in <1s on cold start
- [ ] **FOUND-02**: DesignKit consumed as local SPM dependency from `../DesignKit`
- [ ] **FOUND-03**: Global `ThemeManager` injected via `@EnvironmentObject`; every visible pixel reads a theme token (no hardcoded colors / radii / spacing)
- [ ] **FOUND-04**: Bundle identifier is `com.lauterstar.gamekit`; iOS 17+ deployment target
- [ ] **FOUND-05**: All user-facing strings use `String(localized:)` with an `xcstrings` catalog (EN-only at v1, future locales mechanical)
- [ ] **FOUND-06**: Placeholder app icon shipped (DesignKit colors); user replaces with real icon before App Store

#### App shell
- [ ] **SHELL-01**: Home screen lists Minesweeper as the only active game; future-game placeholders are visually present but disabled
- [ ] **SHELL-02**: Settings screen with theme picker (5 Classic swatches + "More themes & custom colors" link to full `DKThemePicker`), haptics toggle, SFX toggle, reset stats, about
- [ ] **SHELL-03**: Stats screen showing per-difficulty: games played · wins · win % · best time
- [ ] **SHELL-04**: 3-step intro on first launch (themes → stats → optional sign-in card with Skip), dismissable, never shown again

#### Minesweeper
- [ ] **MINES-01**: Three difficulties — Easy 9×9/10 mines, Medium 16×16/40, Hard 16×30/99
- [ ] **MINES-02**: Tap to reveal, long-press to flag
- [ ] **MINES-03**: First tap is always safe — mines placed *after* first tap, excluding tapped cell + its 8 neighbors
- [ ] **MINES-04**: Flood-fill reveal for empty cells to the next numbered border
- [ ] **MINES-05**: Mine counter (mines remaining = total − flagged) and elapsed timer always visible
- [ ] **MINES-06**: Restart button on the game screen
- [ ] **MINES-07**: Win = all non-mine cells revealed; Loss = mine revealed; both surface a clear end-state overlay using `theme.colors.{success,danger}`
- [ ] **MINES-08**: Polished animation pass — reveal cascade, flag spring, win-board sweep, loss-shake — all timed via `theme.motion.{fast,normal,slow}`
- [ ] **MINES-09**: DesignKit haptics on flag, reveal, win, loss; respects Settings haptics toggle
- [ ] **MINES-10**: Subtle SFX on tap / win / loss, **off by default**, toggle in Settings

#### Persistence & sync
- [ ] **PERSIST-01**: Stats backed by **SwiftData** (foundation sized for deeper stats later, even though MVP shows minimal)
- [ ] **PERSIST-02**: Stats survive app force-quit, crash, and device reboot — verified
- [ ] **PERSIST-03**: Export/Import JSON of stats with `schemaVersion`; round-trips cleanly
- [ ] **PERSIST-04**: Optional **Sign in with Apple + CloudKit private DB** for cross-device persistence; full feature parity without sign-in
- [ ] **PERSIST-05**: Sign-in surfaced once in 3-step intro and again in Settings; never gates gameplay; never nags
- [ ] **PERSIST-06**: Anonymous local profile created on first launch; signing in promotes local data to cloud (no data loss on sign-in)

#### Theming responsiveness
- [ ] **THEME-01**: Minesweeper UI verified legible on at least one preset from each DesignKit category — Classic, Sweet, Bright, Soft, Moody, Loud — before TestFlight
- [ ] **THEME-02**: Revealed-vs-unrevealed cells, mines, flags, and adjacency numbers all read from semantic tokens (no hand-picked greys)
- [ ] **THEME-03**: Custom-palette overrides via `ThemeManager.overrides` work end-to-end

#### Accessibility
- [ ] **A11Y-01**: Dynamic Type respected on all non-grid text
- [ ] **A11Y-02**: VoiceOver labels on cells (state + adjacency), buttons, and overlays
- [ ] **A11Y-03**: Reduce-motion preference dampens animation pass

#### Video Mode (v1.2)
- [ ] **VIDEO-01**: Settings exposes Video Mode Off/On toggle (default Off); state persisted across launches
- [ ] **VIDEO-02**: When Video Mode is On, Settings exposes a video-location picker with exactly 6 options: Large top, Large bottom, Small top-left, Small top-right, Small bottom-left, Small bottom-right
- [ ] **VIDEO-03**: Selected location persists across launches and is observable by every game screen via a shared store
- [ ] **VIDEO-04**: Shared compact control row component used by games in Video Mode — order Back | primary info | picker | secondary info | settings; reads DesignKit tokens only
- [ ] **VIDEO-05**: Small-PiP layout — game board stays at normal size; back/settings/info chips and the picker are repositioned so the covered corner is empty for the selected Small location
- [ ] **VIDEO-06**: Large-PiP layout — top or bottom band is reserved per selection; board fits between the reserved band and the compact control row; secondary controls collapse before the board becomes unplayable
- [ ] **VIDEO-07**: Minesweeper adopts Video Mode for Easy + Medium across all 6 locations with no legibility regression on Classic or one Loud preset
- [ ] **VIDEO-08**: Minesweeper Hard (16×30) Video Mode strategy validated against real screenshots — final approach (smaller cells / scroll / zoom / warning) chosen with rationale recorded in ADR
- [ ] **VIDEO-09**: Merge adopts Video Mode across all 6 locations with no legibility regression on Classic + one Loud preset
- [ ] **VIDEO-10**: Nonogram adopts Video Mode across all 6 locations; hints + grid stay readable in Large-top and Large-bottom layouts
- [ ] **VIDEO-11**: Win/loss surfaces use a non-board-covering banner/pill in Video Mode; primary action (Play Again / Continue) reachable without an extra tap; banner placement avoids the selected PiP zone
- [ ] **VIDEO-12**: All Video-Mode-related haptics, SFX, and animations (including any win banner confetti) respect existing Settings haptics/SFX/animations toggles and `accessibilityReduceMotion`
- [ ] **VIDEO-13**: Video Mode adapts only when On — toggling Off restores each game's normal layout with no visual residue
- [ ] **VIDEO-14**: Settings copy explains Video Mode in one short paragraph + clarifies that GameDrawer cannot detect another app's PiP automatically (manual selection only)

### Out of Scope

- **Banner ads / interstitials / video ads** — out of scope for current milestones, but no longer permanently excluded (stance shifted 2026-07-12; nothing implemented). External copy says "no ads" in the present tense only — never "ever"/"never"/"permanent"
- **Coins, fake currency, energy systems, daily-reward streaks-as-engagement-bait** — same reason
- **Aggressive subscriptions / paywalls** — never. Future monetization (if any) is one-time unlock or theme-pack tip jar
- **Required accounts** — sign-in is *optional only*; never blocks gameplay
- **Third-party backend / Firestore / custom server** — Apple-native (CloudKit) only; if it requires a backend GameKit doesn't own, it's deferred or cut
- **Analytics / telemetry** — the app does not phone home. Period
- **Multiplayer / leaderboards / social** — out of scope through MVP and likely beyond
- **A second game in v1** — Merge / Word Grid / Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess puzzles all stay roadmap until Minesweeper feels complete and is shipping clean
- **Chord clicks, no-guess board generator, hint system, custom board size** — known wanted features for later, deferred from MVP to keep scope honest
- **Localization beyond EN at v1 ship** — strings are i18n-ready; actual translations come later
- **Per-game alt-icon variants** — cool but adds a phase. Not v1
- **Asset-heavy games (anything requiring custom illustrations)** — DesignKit-only games for the foreseeable suite
- **Video Mode auto-detect of another app's PiP frame** (v1.2) — no public iOS API exposes another app's PiP; deferred indefinitely
- **Video Mode for Sudoku** (v1.2) — game not yet built; will be designed Video-Mode-aware when it lands
- **Vertical/portrait PiP layouts** (v1.2) — rare in practice; reconsider v1.3+ if real usage shows it matters
- **Large left/right PiP positions** (v1.2) — current observed PiP positions are top and bottom only

## Context

- **Ecosystem:** GameKit lives alongside DesignKit (shared Swift Package),
  HabitTracker, FitnessTracker, and PantryPlanner. Same Balanced-Luxury design
  language, same architectural constitution. Bundle prefix `com.lauterstar.*`
  is consistent across the ecosystem.
- **DesignKit is at `../DesignKit`** and is consumed as a *local* SPM dependency
  — changes to tokens / components flow back to the shared kit, so all sibling
  apps benefit. **Do not vendor or fork.**
- **DesignKit ships 34 presets across 6 categories** (Classic / Sweet / Bright
  / Soft / Moody / Loud) plus a Custom tab with user-saved palettes. Game UI
  must remain legible under every category — that's a hard ship gate, not a
  polish item.
- **Why this exists:** the user (and target audience) is tired of clean
  classic-game concepts being ruined by ads, coins, fake rewards, and pushy UX.
  GameKit is the deliberate inverse.
- **Distribution:** TestFlight first (close-circle beta) → App Store. Personal
  use is the immediate driver; broader audience comes once it feels right.
- **Audience posture:** "personal-first, shippable from day 1" — the app must
  not require a rewrite to go public, even though it isn't being marketed yet.
- **Engine purity rule:** Minesweeper logic (board generation, reveal,
  flood-fill, win detection) lives in pure / testable structs that import no
  SwiftUI and touch no `modelContext`. This is the pattern every future game
  inherits.

## Constraints

- **Tech stack:** Swift 6, SwiftUI, lightweight MVVM, SwiftData (local + CloudKit), DesignKit (local SPM dep) — established to keep ecosystem consistency and avoid invented architectures.
- **iOS target:** 17+ — required for the SwiftUI features and DesignKit token APIs already in use across the ecosystem.
- **Storage backbone:** SwiftData — chosen for natural CloudKit integration and to size persistence for deeper stats without a future migration.
- **Auth backbone:** Sign in with Apple + CloudKit private DB — Apple-native, free for users, zero third-party backend, preserves the "no analytics, no servers we don't own" posture.
- **Design system:** No hardcoded colors / radii / spacing in app code. All styling via DesignKit tokens. If a token is missing, *extend DesignKit* — don't work around it locally.
- **Theming requirement:** Game UI must remain usable under any of the 34 presets. Legibility regression on any preset = ship blocker.
- **First-tap safety:** Mines are never placed in or adjacent to the user's first tap. First-tap loss is a P0 bug, not RNG.
- **Persistence robustness:** Stats must survive force-quit, crash, and reboot. Verified before TestFlight.
- **Cold-start latency:** <1s on a recent device. P0 bug if it slips.
- **Localization-readiness:** Strings via `String(localized:)` + xcstrings from day 1, even though only EN ships at v1.
- **No backend:** App is local-first. CloudKit is the only network surface, and only when the user opts in.
- **No telemetry:** No analytics SDKs. No phone-home.
- **File size cap:** ≤400-line views, ≤500-line Swift files (hard cap). Split early.
- **Atomic commits:** One feature per commit (or one coherent grouped batch). Never bundle a feature with unrelated fixes.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| MVP = Minesweeper only | Prove one game well before splitting focus across multi-game bug surface | — Pending |
| Sign-in via Apple + CloudKit (optional) | Apple-native, no third-party backend, preserves privacy posture, syncs across user's own devices | — Pending |
| SwiftData as storage backbone | Pairs naturally with CloudKit; sized for deeper stats without re-architecting | — Pending |
| DesignKit as local SPM dep (not vendored) | Ecosystem-consistent; token improvements flow back to sibling apps | — Pending |
| Localization-ready from day 1 (EN-only ship) | Cheap to do early, expensive to retrofit later | — Pending |
| Polished animation pass in MVP (not later) | Defines "premium feel" — the core differentiator. Cutting it would undercut the value prop | — Pending |
| Subtle SFX off by default | Calm-by-default product posture; opt-in respects coffee-shop play | — Pending |
| 3-step intro on first launch | Surfaces themes + stats + optional sign-in once, then never again | — Pending |
| Bundle ID `com.lauterstar.gamekit` | Matches existing FitnessTracker namespace; ecosystem-consistent | — Pending |
| CloudKit container ID `iCloud.com.lauterstar.gamekit` | Pinned at P1 per D-10 / Pitfall 3 to prevent stranded-TestFlight-data drift; capability provisioning deferred to P6 alongside Sign in with Apple | — Pending |
| Video Mode location is user-selected, not auto-detected (v1.2) | iOS does not expose another app's PiP frame to third-party apps via public API; manual selection is the reliable path | — Pending |
| Video Mode = small PiP control-aware, large PiP board-aware (v1.2) | Small PiP usually blocks controls more than the board; large PiP can claim enough screen to force the board itself to reflow | — Pending |
| Shared compact control row across games (v1.2) | One pattern keeps Video-Mode UI predictable per game and avoids per-game reinvention | — Pending |
| Win/loss banner replaces full-screen end overlays (v1.2) | Video-Mode rule "board stays visible" extends to end-of-game; haptics/SFX/confetti gated by existing settings + Reduce Motion | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-05 — Phase 17 complete: Snake playable (SNAKE-01…07 verified 19/19); substrate reuse confirmed with zero arcade-Core changes*
