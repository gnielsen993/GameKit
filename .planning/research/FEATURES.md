# Feature Research

**Domain:** iOS Minesweeper (single-game MVP for GameKit suite)
**Researched:** 2026-04-24
**Confidence:** HIGH on table stakes / anti-features (well-established iOS Minesweeper market with 15+ years of competitor data); MEDIUM on differentiator nuances (some claims are App Store description-level, not deeply verified review-level).

## Scope Note

This research is **Minesweeper-only** — the long-term GameKit suite (Merge / Word
Grid / Solitaire / Sudoku / Nonogram / Flow / Pattern Memory / Chess puzzles) is
deliberately out of scope. Features that only make sense once a second game
exists (cross-game home tiles, shared progression, suite-wide stats) are
explicitly excluded — the brief is "prove one game well first."

The competitor field surveyed: Minesweeper Q / Minesweeper Q Premium (Spica,
$2 paid), Mineswifter (no-guess focused), Minesweeper GO (Tapinator,
freemium), Minesweeper Classic: Retro (Maple Media, freemium), Minesweeper
Classic (Maple Media), Minesweeper Mobile, Minesweeper: No Guessing,
Minesweep+, Mine Mine, Accessible Minesweeper (VoiceOver-first), Microsoft
Minesweeper. App Store review patterns surveyed via web search summaries —
not direct review scraping.

## Feature Landscape

### Table Stakes (Users Expect These)

If any of these is missing, the app feels broken or amateurish. Users do not
give credit for shipping them — they only penalize their absence.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Three classic difficulties (9×9/10, 16×16/40, 16×30/99) | Microsoft-original preset every Minesweeper player has muscle memory for | LOW | Already MINES-01 |
| Tap to reveal | Universal touch primitive for grid games | LOW | Already MINES-02 |
| Long-press to flag | Default touch idiom across every iOS Minesweeper surveyed (Q, GO, Classic Retro, Mineswifter, Minesweep+) | LOW | Already MINES-02 |
| First-tap safety | First-click loss feels like a bug to users; competitor "Evil Mineswifter" exists *as a joke* about it | LOW | Already MINES-03; mines placed post-tap, exclude tapped cell + 8 neighbors |
| Flood-fill on empty cells | Without it, the game is unplayable on Medium/Hard | LOW | Already MINES-04 |
| Mine counter (mines remaining = total − flagged) | Half the strategy depends on it | LOW | Already MINES-05 |
| Elapsed-game timer | Speed is the implicit second axis after correctness | LOW | Already MINES-05 |
| Restart button (in-game) | Mid-game "this is a guess, just restart" is core to the loop | LOW | Already MINES-06 |
| Win-state overlay | Acknowledgment of the win is the dopamine hit users came for | LOW | Already MINES-07 |
| Loss-state overlay (with restart) | Without it, users feel stranded; the loss must feel resolved, not punitive | LOW | Already MINES-07; reveal all mines on loss is the convention |
| Best time per difficulty | Single most-asked stat in every Minesweeper surveyed; users *will* leave a 1-star review without it | LOW | Already SHELL-03 |
| Games played / wins / win % per difficulty | Same — minimum stat triad on every competitor's stats screen | LOW | Already SHELL-03 |
| Stats persistence across launches / force-quit / reboot | Losing a best time would be a P0 trust-breaker | LOW | Already PERSIST-02 |
| Number-color scheme (1-blue, 2-green, 3-red, etc.) | The classic palette is mnemonic for muscle-memory players; deviating requires care | LOW | DesignKit semantic tokens must produce a recognizable scheme on Classic preset, with theme-derived variants on others |
| Reveal-mine-on-loss animation | Explains *why* you lost and which flags were wrong | LOW | Part of MINES-08 |
| Settings: theme + haptics + SFX + reset stats + about | The expected iOS Settings spine | LOW | Already SHELL-02 |

### Differentiators (Competitive Advantage)

These are GameKit's competitive surface vs the App Store's free Minesweepers.
Aligns with PROJECT.md Core Value: *"calm, premium, fully theme-customizable
gameplay with zero friction."*

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Zero ads / coins / energy / pushy subs | Direct inverse of the dominant App Store experience users complain about ("ads on every win and loss," "ads got longer and longer," "kicked to the App Store mid-game") | LOW (work avoidance, not work) | The single biggest differentiator. Already PROJECT.md Out of Scope #1 |
| Full DesignKit theming (34 presets across 6 categories + custom) | No other Minesweeper offers anything close. Competitors offer 3–6 fixed skins (Classic Retro: paid skin packs; Q: a few options) | MEDIUM | Already FOUND-03, THEME-01-03 — work is making the *Minesweeper UI* read every preset |
| Custom number-color palette (per-numeral) | Power users (and color-blind users) want to override 1-8 colors. Trivial extension on top of DesignKit token mapping | LOW–MEDIUM | Differentiator + accessibility win. Surface as "Number colors" in Settings → Minesweeper section |
| Subtle, considered animations (DesignKit motion tokens) | Reveal cascade, flag spring, win sweep, loss shake — feel competitors fake with bad ease curves | MEDIUM | Already MINES-08 |
| First-class haptics (DesignKit haptic patterns) | Tactile differentiation premium iOS users notice immediately | LOW | Already MINES-09 |
| SFX off by default | Calm-by-default product posture; respects coffee-shop play. Competitors all default-on with intrusive sounds | LOW | Already MINES-10 |
| 3-step intro (themes → stats → optional sign-in) then never again | Most competitors either skip onboarding (confusing) or pop tutorials repeatedly. One-and-done is rare | LOW | Already SHELL-04 |
| Optional Sign in with Apple + CloudKit (never required) | Cross-device sync for users who want it; full feature parity for those who don't. Competitors either force accounts or have no sync at all | MEDIUM | Already PERSIST-04-06 |
| Export / Import JSON of stats | User-owned data; portability. No surveyed competitor offers this | LOW | Already PERSIST-03 |
| No telemetry / no phone home | Privacy posture. Competitors silently SDK-up | LOW (work avoidance) | Already PROJECT.md Out of Scope |
| No-guess board generator (every board solvable by pure logic) | Mineswifter / Minesweeper: No Guessing built entire products around this. Eliminates the genuine flaw of classic RNG | HIGH | Defer to v1.1 — see PITFALLS.md (generator can take 0–20s; needs background thread, retries, fallback). PROJECT.md already lists this as deferred |
| Chord (double-tap a number to reveal neighbors when flagged correctly) | Speedrunners and 3BV/s grinders need this. PROJECT.md lists it as deferred | LOW–MEDIUM | v1.1. Setting toggle so casual players don't accidentally trigger |
| Rich stats screen (3BV/s, distribution, recent history, streaks) | Competitors stop at win % + best time. Stats-curious users will adopt GameKit just for this | MEDIUM | v1.1 — SwiftData schema sized for it now (PERSIST-01) |
| Daily seed / daily challenge (deterministic per-day board) | Engagement *without* dark patterns. The seed is the engagement, no streak-shaming required | MEDIUM | v1.1+ — see Anti-Feature note re: streak coercion |
| VoiceOver-playable Minesweeper | "Accessible Minesweeper" exists as a separate app entirely *because* most are unplayable blind. Shipping it in the main product is rare | MEDIUM | A11Y-02 covers basic labels; cell coordinate announcements + flag/reveal verbs needed for full play |
| Color-blind-safe number palette (presetable) | Default Microsoft palette has 1-blue/2-green/3-red — green/red is the worst pairing for deuteranopia. A "Color-blind safe" variant is a 30-min win | LOW | Use blue/orange/yellow/dark axis (Wong palette principles) |
| Reduce Motion compliance | Already A11Y-03 — competitors rarely respect it | LOW | Dampen MINES-08 animations under `accessibilityReduceMotion` |

### Anti-Features (Commonly Requested, Often Problematic)

Each row is grounded in an actual competitor failure mode surfaced in App
Store review summaries during this research. These are deliberate refusals,
not omissions.

| Feature | Why Requested | Real Competitor Failure | Why GameKit Refuses | Alternative |
|---------|---------------|-------------------------|---------------------|-------------|
| Banner / interstitial / video ads | "Free" monetization | Maple Media's Minesweeper Classic: ads "got longer and longer, sometimes over a minute and requiring 6 or 7 clicks to get back to the game"; users "kicked to App Store mid-game with no warning" | Annihilates the calm, premium feel — the entire reason GameKit exists | One-time unlock or theme-pack tip jar (later) |
| Aggressive subscription prompts after every game | Recurring revenue | Same Maple Media app: post-update became "an ad for $9.99/mo subscription service even though this was already a paid app"; another: "must say no to buying ad-free version after practically every game" | Pushy UX is permanently barred (CLAUDE.md §1) | One-time price if monetized at all |
| Coins / fake currency / power-ups | "Engagement loop" | Minesweeper: Collector ships a coin economy with power-ups; Minesweeper Classic: Retro has coins for "optional in-game board reskins" | Dilutes the logic puzzle into a pseudo-progression slot machine | Theming via DesignKit, no economy needed |
| Energy / hearts / lives / wait-to-play | Force return visits | Common in casual puzzle clones — surveyed Minesweepers mostly don't do this, but it's a known anti-pattern in the broader puzzle category | Logic puzzles played at user pace, period | Unlimited play, always |
| Required account / forced sign-in | Marketing list / cross-device sync | Some apps gate stats/sync behind mandatory login | Sign-in is *opt-in only*; never blocks gameplay (PERSIST-05) | Anonymous local profile from launch; promote on opt-in |
| "Streak-or-lose-it" daily-streak shaming | Engagement metric | Duolingo-style coercion is bleeding into puzzle apps | Streaks-as-coercion = engagement bait by another name (PROJECT.md Out of Scope) | Daily seed *available*; missing a day costs nothing; show streak as a stat without a guilt UI |
| Notifications nagging to come back | DAU goose | Cross-genre dark pattern | App posture is "play when you want." No reminder push notifications in MVP | If reminders ever ship: opt-in once during onboarding, never re-prompted |
| Pop-up rate-this-app / share-this-app prompts | App Store ranking | Every freemium Minesweeper surveyed has these | Modal interruptions in a calm puzzle violate the product posture | Use Apple's `SKStoreReviewController` rule (system-rate-limited, only at natural pause points like a milestone best-time, never on first launch) |
| Bigger custom boards (50×50, 100×100, etc.) | Power users | Minesweeper X: Classic Reboot offers 72×72; Minesweeper Q allows arbitrary configs | Thumb-reach + perf-cost + theming-headache for tiny niche; PROJECT.md explicitly defers custom board sizes from MVP | Defer to v1.x; if implemented, cap at a sane upper bound (e.g., 24×40) and require pinch-to-zoom |
| Question-mark (?) marks | "Microsoft did it" | Most surveyed apps still have it on by default | Adds a third tap-cycle state most modern players don't use; clutters the cell visual under varied themes | Defer; if added later, opt-in toggle, off by default |
| Hint button / solver button (free, unlimited) | "I'm stuck" | Mineswifter offers AI-driven hints | Tension between *premium feel* and *pure logic puzzle*; offering free unlimited hints turns the game into an autosolver demo | Defer; if shipped, gate behind no-guess mode where it's a teaching tool, not an autoplay button. Track "perfect game" stat (no-hint, no-undo) — same pattern Mineswifter uses |
| Undo (free, unlimited) | "I misclicked" | Mineswifter offers undo with a 10-second penalty | Undo trivializes the loss state; conflicts with the dopamine of a clean win | Defer; if shipped, time-penalty model OR limit to "undo-the-last-move-if-it-was-a-loss" (post-mortem only). Not in MVP |
| Multiplayer / leaderboards / social | "Engagement" | Several apps integrate Game Center leaderboards | Out of GameKit posture (no servers we don't own; PROJECT.md Out of Scope) | Personal stats are the social surface |
| Achievements / badges system | Casual gamification | Microsoft Minesweeper, Minesweeper Online have these | Achievements-as-engagement-bait edge; out of MVP scope. Best times *are* the achievement | Defer past v1.x; if ever shipped, derive automatically from stats, not as a notification carousel |
| Per-game alt-icon variants | Cool factor | Niche iOS feature | Adds a phase; PROJECT.md explicitly lists as Out of Scope | Defer |
| Localization beyond EN | Reach | n/a | i18n-ready from day 1 (FOUND-05) but actual translations come later | Defer translations to a later milestone |
| Question-asking / forced rating modal mid-game | App Store optimization | Universal anti-pattern | Same posture as pop-up prompts | None — never |
| Analytics SDKs (Firebase, Adjust, etc.) | "Understand users" | Standard practice in freemium | PROJECT.md Out of Scope; CLAUDE.md "no phone home" | Local stats only; user can export if curious |

### Stretch (Earned Later, Not v1)

Features that are good ideas, fit the product posture, and *should* exist
eventually — but are not v1 because they fail the "essential to validate the
concept" test.

| Feature | Why Stretch | Trigger to Add | Complexity |
|---------|-------------|----------------|------------|
| No-guess board generator | Excellent; flagged as v1.1 in PROJECT.md. Algorithmic complexity (SAT/CSP solver, retry loop, background thread) doesn't belong in MVP | After MINES-01..10 stabilize on TestFlight | HIGH |
| Chord (double-tap to reveal neighbors) | Speedrun-tier feature; PROJECT.md defers explicitly | After basic interaction is solid | LOW–MEDIUM |
| 3BV / 3BV/s / IOE display in stats | Power-user metric; SwiftData schema in MVP must already support adding these | v1.1 stats expansion phase | MEDIUM (engine must compute 3BV at win-time, not just count clicks) |
| Win-rate trend chart (7/30/90-day) | Power-user retention; uses Swift Charts via DesignKit | v1.1 retention layer (PROJECT.md Phase 5) | MEDIUM |
| Time-distribution histogram per difficulty | Power-user stat | Same trigger | MEDIUM |
| Streak counter (current / longest, displayed neutrally) | Self-reported curiosity, not coercion | v1.1+ when daily-seed mode lands | LOW |
| Daily seed / daily challenge (deterministic per-day board) | Best engagement mechanic that fits the product posture | v1.1+ | MEDIUM (deterministic seed; render an "already played today" state without scolding) |
| Daily-seed result share card | Wordle-style spoiler-free emoji grid result | After daily lands and feels right | LOW–MEDIUM |
| Custom-board-size mode | Some users want 24×30/120 mines etc. PROJECT.md defers explicitly | v1.x | MEDIUM (theming + thumb-reach considerations) |
| Pinch-to-zoom on Hard board | Helps Hard (16×30) on smaller iPhones | Opportunistic — if review feedback flags Hard as cramped on iPhone SE/mini | LOW–MEDIUM |
| Swipe-to-flag gesture (alt input) | Some users prefer it to long-press | After watching first-week TestFlight ergonomics | LOW |
| Tap-mode toggle (reveal-mode vs flag-mode quick switch) | Microsoft Minesweeper-style touch alternative | Same trigger | LOW |
| Question-mark (?) cell state | Classic-purist users will ask | Opt-in toggle, off by default | LOW |
| Hint system (gated to no-guess mode) | Teaching aid, not autoplay | After no-guess ships and "perfect game" tracking exists | MEDIUM |
| Undo with time penalty (gated to no-guess mode) | Same | Same | MEDIUM |
| App Shortcuts: "Start Easy game" / "Continue last" | iOS-native power-user surface | v1.x polish | LOW |
| Widgets (small: best times; medium: today's daily seed status) | Calm engagement surface (no nag) | After daily seed exists | MEDIUM |
| Color-blind palette presets (Wong / IBM) | Accessibility. Cheap if number-color overrides already shipped | v1.1 | LOW |
| iCloud sync conflict resolution UI | If two devices both make a new best time on the same difficulty offline, which wins? CloudKit handles last-write-wins, but a "merged stats" view is courteous | When a real bug report surfaces | MEDIUM |
| Achievements (derived, not notification-spammy) | Auto-derived from stats: "first sub-1-min Easy," "100 Hard wins." No popups, no badges drawer that nags | After stats are rich | MEDIUM |

## Feature Dependencies

```
MINES-01 (difficulties) ──┐
                          ├──> MINES-02 (tap/long-press) ──> MINES-03 (first-tap safety)
                          │                                        └──> MINES-04 (flood-fill)
                          │                                                      │
                          │                                                      v
                          │                                              MINES-07 (win/loss)
                          │                                                      │
                          v                                                      v
                   MINES-05 (timer + counter) ─────────────────────────> SHELL-03 (stats)
                                                                                 │
                                                                                 v
                                                                          PERSIST-01 (SwiftData)
                                                                                 │
                                                                       ┌─────────┼─────────┐
                                                                       v         v         v
                                                                PERSIST-02  PERSIST-03  PERSIST-04
                                                                (durable)   (Export/    (CloudKit)
                                                                            Import)         │
                                                                                            v
                                                                                     PERSIST-05/06
                                                                                     (anon→signed)

THEME (FOUND-03, DesignKit) ──> all UI ──> THEME-01..03 (preset legibility pass)
                                                  │
                                                  v
                                          custom number-color palette
                                                  v
                                          color-blind safe preset (stretch)

A11Y-01 (Dynamic Type) ──> A11Y-02 (VoiceOver labels) ──> stretch: full VoiceOver play
A11Y-03 (Reduce Motion) ──enhances──> MINES-08 (animations)

No-guess generator (stretch) ──enables──> hint system (stretch)
                              ──enables──> undo with penalty (stretch)
                              ──enables──> "perfect game" stat (stretch)

Daily seed (stretch) ──enables──> share card (stretch)
                     ──enables──> daily-seed widget (stretch)
                     ──enables──> streak stat (stretch)

Chord (stretch) ──enables──> 3BV/s as a meaningful speed metric

Reset stats (SHELL-02) ──conflicts──> CloudKit sync (PERSIST-04):
   reset must clear local AND prompt user about cloud copy. Solve at sync feature time.
```

### Dependency Notes

- **MINES-03 (first-tap safety) requires MINES-02:** mine placement is
  deferred until after the first tap fires. Implementation order: gesture
  → engine.placeMines(excluding: tappedCell + neighbors) → reveal.
- **PERSIST-04 (CloudKit) requires PERSIST-01 (SwiftData):** SwiftData's
  CloudKit integration is the chosen sync path. Don't ship CloudKit before
  the local schema is stable, or you'll migrate twice.
- **PERSIST-06 (anon → signed promotion) requires PERSIST-04 + PERSIST-01:**
  needs the local store as the source of truth at sign-in moment, with a
  documented "merge rules" decision (last-write-wins on per-stat-row,
  best-time = `min(local, cloud)`, games-played = `local + cloud` if the
  user genuinely played on both pre-link, or `max` if conservative).
- **No-guess generator enables hint + undo:** without solvability guarantee,
  hints/undo become "bail out of bad luck" instead of "learn from a logic
  mistake." Don't ship hint/undo before no-guess.
- **Daily seed enables streak / share / widget stretches:** all three depend
  on a single deterministic-seed source.
- **Chord makes 3BV/s honest:** without chord, 3BV/s caps at ~2 because every
  number-around-flags requires manual neighbor reveals. Speedrunner audience
  notices instantly.
- **Theming pass conflicts with hand-picked greys:** every "just one shade
  darker for unrevealed cells" is a token-system regression. THEME-02 keeps
  this honest.
- **Reset stats conflicts with CloudKit:** reset must be explicit about
  scope ("Reset on this device" vs "Reset everywhere") once sync ships.

## MVP Definition

### Launch With (v1) — The Differentiator-Defining Cut

Goal: every requirement currently in PROJECT.md *Active*, nothing more,
nothing less. Already a tight cut.

- [x] **MINES-01..10** — Three difficulties, tap/long-press, first-tap
  safety, flood-fill, mine counter, timer, restart, win/loss overlays,
  animation pass, haptics, SFX-off-by-default. *(Already in active scope.)*
- [x] **SHELL-01..04** — Home / Settings / Stats / 3-step intro. *(Already
  in active scope.)*
- [x] **PERSIST-01..06** — SwiftData stats, durability, export/import, opt-in
  CloudKit, anonymous→signed promotion. *(Already in active scope.)*
- [x] **THEME-01..03** — Token-only styling, preset legibility pass, custom
  overrides. *(Already in active scope.)*
- [x] **A11Y-01..03** — Dynamic Type, VoiceOver labels, Reduce Motion.
  *(Already in active scope.)*
- [x] **FOUND-01..06** — Cold-start <1s, DesignKit dep, ThemeManager,
  bundle ID, localized strings, placeholder icon. *(Already in active scope.)*

**Recommendations to add to v1 active scope (genuine table-stakes gaps):**

- [ ] **A11Y-04 (new)**: Number-color palette is verified
  color-blind-readable on at least one Loud preset. *Trivial work; large
  inclusion win; aligns with THEME-01.* Complexity: LOW.
- [ ] **MINES-11 (new)**: On loss, animate revealing all mines and visibly
  mark incorrect flags (red X) — the dominant convention; without it the
  loss feels confusing. *Already implied by MINES-08 but worth explicit
  acceptance criterion.* Complexity: LOW.

### Add After Validation (v1.1) — The Power-User Cut

Trigger: MVP is on TestFlight, stable, and at least one external person has
played it daily for a week.

- [ ] **No-guess board generator** — biggest single quality-of-play upgrade,
  but high algorithmic risk. Defer until MVP UX is validated.
- [ ] **Chord (double-tap a satisfied number)** — speedrunner-grade input.
- [ ] **Question-mark cell state (opt-in toggle)** — for classic purists.
- [ ] **Rich stats screen** — 3BV / 3BV/s / win-rate trend chart / time
  distribution / recent history. SwiftData schema sized for this in MVP, so
  no migration.
- [ ] **Color-blind preset(s)** — surface as one or two named palettes
  derived from the Wong (Nature Methods) palette: blue/orange/yellow/dark.

### Future Consideration (v2+) — Earned by Real Demand

Trigger: a real user (not the maintainer) asks for it more than once.

- [ ] **Daily seed / daily challenge** — engagement layer. Works only if the
  product is loved enough that *some* engagement layer is welcomed.
- [ ] **Streak counter (neutral display)** — only after daily seed exists.
- [ ] **Share-card export of daily result** — Wordle-style.
- [ ] **Daily-seed widget** — calm engagement surface.
- [ ] **App Shortcuts** — "Start Easy game", "Continue last game".
- [ ] **Custom board size mode** — explicitly deferred in PROJECT.md.
- [ ] **Pinch-to-zoom on Hard** — only if iPhone SE/mini reviews flag Hard
  as cramped.
- [ ] **Hint system gated to no-guess mode** — teaching tool, with "perfect
  game" stat to keep purists honest.
- [ ] **Undo (time-penalty model)** — same gating as hints.
- [ ] **Achievements derived from stats (no popups)** — only if stats screen
  proves engaging.
- [ ] **Localizations beyond EN** — strings are already i18n-ready; this is
  a translation-budget call, not an engineering call.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| First-tap safety (MINES-03) | HIGH | LOW | P1 |
| Flood-fill (MINES-04) | HIGH | LOW | P1 |
| Three difficulties (MINES-01) | HIGH | LOW | P1 |
| Best time per difficulty (SHELL-03) | HIGH | LOW | P1 |
| Stats persistence (PERSIST-02) | HIGH | LOW | P1 |
| Win/loss overlay + reveal-on-loss (MINES-07/11) | HIGH | LOW | P1 |
| DesignKit theming legibility (THEME-01..03) | HIGH | MEDIUM | P1 |
| Animation pass (MINES-08) | HIGH | MEDIUM | P1 |
| Haptics (MINES-09) | MEDIUM | LOW | P1 |
| SFX off-by-default (MINES-10) | MEDIUM | LOW | P1 |
| 3-step intro (SHELL-04) | MEDIUM | LOW | P1 |
| Optional Sign-in + CloudKit (PERSIST-04..06) | MEDIUM | MEDIUM | P1 |
| Export/Import JSON (PERSIST-03) | MEDIUM | LOW | P1 |
| VoiceOver labels (A11Y-02) | HIGH (for affected users) | LOW | P1 |
| Dynamic Type (A11Y-01) | MEDIUM | LOW | P1 |
| Reduce Motion (A11Y-03) | MEDIUM | LOW | P1 |
| Color-blind-safe number palette default-check | MEDIUM | LOW | P1 |
| No-guess board generator | HIGH | HIGH | P2 |
| Chord (double-tap) | MEDIUM | LOW–MEDIUM | P2 |
| Rich stats screen (3BV/s, charts, history) | MEDIUM | MEDIUM | P2 |
| Color-blind preset (named) | MEDIUM | LOW | P2 |
| Question-mark state | LOW | LOW | P2 |
| Daily seed | MEDIUM | MEDIUM | P3 |
| Share card | LOW | LOW | P3 |
| Widgets | LOW | MEDIUM | P3 |
| Custom board size | LOW | MEDIUM | P3 |
| Hint system (gated) | LOW | MEDIUM | P3 |
| Undo (penalty model) | LOW | MEDIUM | P3 |
| Achievements (derived) | LOW | MEDIUM | P3 |
| Pinch-to-zoom | LOW | LOW–MEDIUM | P3 |
| Banner/interstitial/video ads | NEGATIVE | n/a | NEVER |
| Aggressive sub paywall | NEGATIVE | n/a | NEVER |
| Coins / energy / hearts | NEGATIVE | n/a | NEVER |
| Required accounts | NEGATIVE | n/a | NEVER |
| Streak shaming | NEGATIVE | n/a | NEVER |
| Push notifications nagging return | NEGATIVE | n/a | NEVER |
| Telemetry / analytics SDKs | NEGATIVE | n/a | NEVER |

**Priority key:**
- **P1**: Must have for v1 ship. (Almost entirely already in PROJECT.md Active.)
- **P2**: v1.1 — power-user cut, after MVP stabilizes on TestFlight.
- **P3**: v2+ — earned by real user demand.
- **NEVER**: Refused on principle; documented in PROJECT.md Out of Scope.

## Competitor Feature Analysis

| Feature | Minesweeper Q ($2 paid) | Minesweeper GO (freemium) | Minesweeper Classic: Retro (freemium) | Mineswifter (no-guess) | Accessible Minesweeper | GameKit (planned v1) |
|---------|-------------------------|---------------------------|---------------------------------------|------------------------|------------------------|---------------------|
| Three classic difficulties | Yes | Yes | Yes | Yes | Yes | Yes (MINES-01) |
| Custom board size | Yes (arbitrary) | No | Yes | No | No | Deferred to v1.x |
| First-tap safety | Yes | Yes | Yes | Yes | Yes | Yes (MINES-03) |
| No-guess generator | No | Campaign mode (1000+ levels) | Yes (in some modes) | Yes (core feature) | No | v1.1 stretch |
| Long-press to flag | Yes | Yes | Yes | Yes | Yes (VO-adapted) | Yes (MINES-02) |
| Chord (double-tap) | Yes | Yes | Yes | Yes | n/a | v1.1 stretch |
| Swipe-to-flag | No | No | No | No | n/a | v1.x stretch |
| Hint system | Configurable | No | No | Yes (AI) | No | v2+ (gated to no-guess) |
| Undo | No | No | No | Yes (10s penalty) | No | v2+ (gated to no-guess) |
| Question-mark state | Optional | Optional | Optional | No | No | v1.x opt-in |
| Stats per difficulty | Yes (rich) | Yes | Yes | Yes (incl "perfect game") | Yes | Yes (SHELL-03) |
| 3BV / 3BV/s | Yes | No | No | Yes | No | v1.1 stretch |
| Win-rate / streak / history charts | Limited | Limited | Limited | Limited | No | v1.1 stretch |
| Themes / skins | A few | A few (some paid) | Multiple skin packs (paid) | "Modern beautiful UI" customizable | Audio-first, minimal visual | 34 presets + custom (DesignKit) |
| Custom number-color palette | No | No | No | No | n/a | v1 (LOW lift) |
| Color-blind-safe palette preset | No | No | No | No | n/a | v1.1 |
| Daily challenge / daily seed | No | Yes (campaign-style) | No | No | No | v2+ |
| iCloud sync | No | Yes (Apple Sign In) | Yes (themes + stats) | No | No | Yes, opt-in (PERSIST-04) |
| Export/Import JSON | No | No | No | No | No | Yes (PERSIST-03) |
| VoiceOver-playable | Limited | Limited | Limited | Limited | Yes (only fully accessible app surveyed) | Aim for yes (A11Y-02 + stretch) |
| Dynamic Type | Limited | Limited | Limited | Limited | n/a | Yes (A11Y-01) |
| Reduce Motion respect | Unknown | Unknown | Unknown | Unknown | n/a | Yes (A11Y-03) |
| Ads | None (paid) | Yes (removable for ~$2) | Yes (heavy, monetization changed under users) | None (paid) | None | None, ever |
| Subscriptions | None | None reported | $9.99/mo prompt added post-launch (1-star reviews) | None | None | None, ever |
| Coins / power-ups / energy | None | None | Yes (skin economy) | None | None | None, ever |
| Required account | None | Optional Apple Sign In | Optional | None | None | Optional Sign in with Apple |
| Telemetry / analytics | Likely | Likely | Likely | Unknown | Unknown | None, ever |

## Open Questions for Roadmap / Phase Research

These are gaps where research couldn't deliver a definitive answer; flag for
phase-specific research later.

- **No-guess generator perf budget on iOS hardware.** SAT/CSP solvers can
  take 0–20s per board. iPhone 12-class device behavior unknown without
  prototyping. Phase that ships no-guess needs a perf spike first.
- **CloudKit sync conflict UX.** Two devices both setting a new best time
  for Hard while offline — last-write-wins is wrong here (`min(time)` is the
  right merge). Needs schema decision *before* PERSIST-04 ships.
- **Daily-seed time zone & wraparound rules.** Midnight UTC vs midnight
  local? Affects whether two players "have the same daily." Needs a
  decision when daily ships.
- **VoiceOver chord/long-press equivalents.** Long-press has a default
  VoiceOver gesture (double-tap-and-hold) but it conflicts with chord's
  double-tap. Need explicit gesture remap when both ship; investigate
  `.accessibilityActions` SwiftUI API.
- **Theming the loss state.** Themes that use `theme.colors.danger` close
  to a number-color (e.g., red 3) make exploded-mine visually noisy. The
  pass under THEME-01 must explicitly check the *loss* state on Voltage,
  Dracula, and any high-saturation Loud preset, not just the play state.
- **First-tap-safe rule edge case on Hard.** 16×30 with 99 mines means the
  3×3 first-tap-safe region is ~2% of the board; mine placement still
  fits but generator must guard against the impossible (e.g., a tiny
  custom board where exclusion = entire board). Defensive check needed,
  even pre-custom-board feature.

## Sources

- [Minesweeper Q on App Store](https://apps.apple.com/us/app/minesweeper-q/id421576027)
- [Minesweeper GO on App Store](https://apps.apple.com/us/app/minesweeper-go-classic-game/id1451053153)
- [Minesweeper Classic: Retro on App Store](https://apps.apple.com/us/app/minesweeper-classic-retro/id1287818410)
- [Minesweeper Classic on App Store](https://apps.apple.com/us/app/minesweeper-classic/id306937053)
- [Mineswifter on App Store](https://apps.apple.com/us/app/mineswifter-minesweeper/id1521190195)
- [Minesweeper: No Guessing on App Store](https://apps.apple.com/us/app/minesweeper-no-guessing/id6757227897)
- [Minesweep+ on App Store](https://apps.apple.com/kw/app/minesweep/id6756476910)
- [Minesweeper: Collector on App Store](https://apps.apple.com/us/app/minesweeper-collector/id1068208194)
- [Mine Mine on App Store](https://apps.apple.com/us/app/mine-mine-simple-minesweeper/id6741587531)
- [Accessible Minesweeper on App Store](https://apps.apple.com/us/app/accessible-minesweeper/id405094331)
- [Accessible Minesweeper on AppleVis](https://www.applevis.com/apps/ios/games/accessible-minesweeper)
- [Minesweeper Q Premium review (game-solver.com)](https://game-solver.com/minesweeper-q-premium/)
- [No-Guess generator algorithm overview (minesweeper.house)](https://www.minesweeper.house/docs/gamemodes/no-guess)
- [SAT-solver no-guess Minesweeper (GitHub: jwang541)](https://github.com/jwang541/Minesweeper-Solver-SAT)
- [JSMinesweeper solver/analyzer (GitHub: DavidNHill)](https://github.com/DavidNHill/JSMinesweeper)
- [3BV explainer (Minesweeper Wiki)](https://minesweeper.fandom.com/wiki/3bv)
- [3BV/s explainer (Minesweeper Wiki)](https://minesweeper.fandom.com/wiki/3bv/s)
- [Minesweeper Statistics conventions (minesweepergame.com)](https://minesweepergame.com/statistics.php)
- [Win-streak coefficient (minesweeper.online)](https://minesweeper.online/help/c-ws)
- [Chording mechanic explainer (Minesweeper Wiki)](https://minesweeper.fandom.com/wiki/Chording)
- [Onboarding HIG (Apple Developer)](https://developer.apple.com/design/human-interface-guidelines/onboarding)
- [Wong color-blind-safe palette principles (David Mathlogic)](https://davidmathlogic.com/colorblind/)
- [Color-blind-safe schemes (NCEAS)](https://www.nceas.ucsb.edu/sites/default/files/2022-06/Colorblind%20Safe%20Color%20Schemes.pdf)
- [iCloud sync caveats for game data (tabletish.com)](https://tabletish.com/sync-game-data-android-ios/)
- [Banned dark patterns vs permitted tricks (Adapty)](https://adapty.io/blog/dark-patterns-and-tricks-in-mobile-apps/)

---
*Feature research for: iOS Minesweeper, GameKit MVP*
*Researched: 2026-04-24*
