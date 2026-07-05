# Phase 18: Stats, Design Specs & ADR - Context

**Gathered:** 2026-07-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Close out v1.5 by making **Stack and Snake consumer-complete**: the score-based
Stats screen shape (ARCADE-07 — High Score prominent, distinct from turn-based
win/loss/best-time cards, empty state "No runs yet."), DESIGN.md §12 entries for
both games, Video Mode exemption ADR confirmation (ARCADE-08 — already written
and amended; verify + reference), and the milestone-close verification gates:
cold-start unchanged, engine purity, ≤400-line files.

In scope: `Screens/StackStatsCard.swift` + `Screens/SnakeStatsCard.swift`
redesign (via a new shared layout component), a new `DESIGN.md` §12.6/§12.7,
ADR call-site documentation check, cold-start verification (structural proof +
one user-run Instruments session that records the canonical baseline), purity
and file-size greps.

Out of scope: any engine/gameplay change to Stack or Snake; Video Mode adoption
work (Stack already adopted in Phase 16, Snake exempt per ADR); daily seed, SFX,
score trend charts, leaderboards (v1.5 out-of-scope list); any SwiftData model
change, migration, or schema-version bump (Phase 15 lock — never relaxed).

</domain>

<decisions>
## Implementation Decisions

**Mode note:** Advisor mode — each area was researched against the codebase and
presented as a comparison table; the user picked the recommended option in all
four areas.

### Stats card layout (ARCADE-07, SC1)
- **D-01:** **Hero-numeral treatment.** Uppercase "HIGH SCORE" caption label
  (`caption.weight(.semibold)`, `textSecondary` — the exact `StackScoreChip`
  label idiom) above a large numeral in `titleLarge` + `.monospacedDigit()`
  (`textPrimary`), then a 1pt `border` rule, then the existing label|value grid
  rows below. This is what makes the arcade cards visually distinct from the
  turn-based column-grid cards in StatsView.
- **D-02:** Token constraint confirmed by research: DesignKit's `monoNumber` is
  body-sized — there is NO large mono token. The hero numeral MUST be
  `titleLarge` + `.monospacedDigit()`. Do not invent a token.
- **D-03:** Empty-state copy changes to the roadmap-locked **"No runs yet."**
  (replacing "No Stack/Snake games played yet.") in the same pass.
- **D-04:** New card shape needs the standard §8.12 legibility pass (Classic +
  Voltage/Dracula) and a wrap/overflow check for 6-7 digit scores at large
  Dynamic Type.

### Metric set (ARCADE-07)
- **D-05:** Shared score-based shape = **High Score (hero) + Average Score +
  Runs Played**. Average chosen over total — an ever-growing total is
  gamified-clutter energy; average is the calm, meaningful number.
- **D-06:** Average Score is **derived only** — per-run score is already
  persisted on `GameRecord.score` for both games (`GameStats.recordStackRun`
  ~line 329; Snake's score overload). `compactMap { $0.score }` over the
  already-queried records props. Zero schema risk, no new write path. Guard
  nil scores and empty denominator. Rounding/display format is planner
  discretion.
- **D-07:** **Best Streak stays Stack-only**, appended as the last row —
  game-specific metric outside the shared score shape. It already persists via
  the `"perfectStreak"` `BestScore` row (Phase 16 D-10/D-11); do not touch its
  persistence.

### Component structure
- **D-08:** **Shared layout + thin wrappers.** One new shared layout component
  (working name `ScoreStatsCard`, taking a metrics array + empty-state text) in
  `Screens/`; `StackStatsCard` and `SnakeStatsCard` shrink to derivation-only
  wrappers (mode-key lookups, metric derivation, empty copy stay local to each
  wrapper). StatsView call sites unchanged. Per-metric a11y labels plumb
  through the metrics array (keep the `.accessibilityElement(children:
  .combine)` row pattern). Matches the Phase 17 D-02 promotion precedent
  ("genuinely identical across 2+ games"). This is Screens/-local — NOT a
  DesignKit promotion.

### Cold-start verification (SC4)
- **D-09:** **Combination approach.** Claude closes the allocation half
  structurally: code inspection (lazy `navigationDestination` construction in
  `HomeView.destination(for:)` ~line 359; zero arcade/engine references in
  `App/`) plus a temporary `#if DEBUG` init-log run on simulator (reverted
  before commit — no product code ships). The user closes the timing half: one
  Instruments App Launch session on a real device from a prepared step-by-step
  recipe, as a blocking human-verification checkpoint (the proven Phase 16/17
  pattern).
- **D-10:** **No v1.4 baseline number exists anywhere in `.planning/`** — the
  research confirmed "unchanged from v1.4 baseline" has no numeric anchor, and
  Phase 15's identical Instruments item was plan-sanctioned-deferred and never
  run (still `pending` in `15-HUMAN-UAT.md`). This phase's Instruments session
  **records the absolute number as the canonical cold-start baseline** (ms,
  device model, OS noted in the verification doc) rather than pretending to
  compare against a phantom number. It also retires the pending Phase 15 UAT
  item.

### DESIGN.md §12 entries + ADR (content roadmap-locked, not re-discussed)
- **D-11:** §12 entries for Stack and Snake document the roadmap-SC2 content:
  Reduce Motion jump-cut spec (visual motion only, View-tier
  `@Environment(\.accessibilityReduceMotion)` gate), haptic vocabulary (block
  land / food eaten = light impact, game-over = `.error`, no per-frame haptics
  ever), per-element token map. **Document as-built** — where the shipped
  implementation refined the roadmap sketch (e.g., Stack's per-layer accent
  ramp, Snake's body ramp + `success`/`accentPrimary` food resolution), the
  entry records what shipped, citing 16/17 CONTEXT decisions.
- **D-12:** ARCADE-08's ADR (`15-VIDEO-MODE-ADR.md`, amended 2026-07-02: Stack
  exemption lifted, Snake remains exempt) already satisfies SC3. Phase 18
  verifies the `HomeView.destination(for:)` call-site comments still match the
  amended state and does NOT rewrite the ADR.

### Verification gates (mechanical, already scouted)
- **D-13:** Engine purity already passes — `StackEngine.swift` /
  `SnakeEngine.swift` are Foundation-only. NOTE: the roadmap SC5 grep path
  (`Games/Stack/Engine`, `Games/Snake/Engine`) references subdirectories that
  don't exist — engines are flat files in the game folders. The verification
  step greps the actual engine/config files; this is a check-path fix, not a
  code change.
- **D-14:** File-size gate already passes — largest Stack/Snake file is 386
  lines (`StackBoardCanvas.swift`). Verify-and-record, no splitting expected.

### Claude's Discretion
- Average-score rounding/format (integer vs one decimal), exact hero-numeral
  size behavior under Dynamic Type, the shared component's exact API shape and
  name, §12 entry prose, and the Instruments recipe wording.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §Phase 18 — goal + success criteria 1-5
- `.planning/REQUIREMENTS.md` — ARCADE-07 (line ~165, Pending), ARCADE-08
  (line ~166, Complete with 2026-07-02 amendment note)

### The ADR being confirmed (SC3)
- `.planning/phases/15-arcade-substrate-skeleton/15-VIDEO-MODE-ADR.md` —
  Accepted 2026-06-26, **Amended 2026-07-02** (Stack exemption lifted; Snake
  remains exempt). Verify call-site docs against it; do not rewrite.

### Prior phase context (carried-forward locks)
- `.planning/phases/16-stack/16-CONTEXT.md` — D-10/D-11 (best-streak metric +
  CloudKit-safe persistence via `"perfectStreak"` BestScore row); feedback and
  palette decisions the §12.6 entry documents
- `.planning/phases/17-snake/17-CONTEXT.md` — D-01..D-12 (visual identity,
  haptics D-07..D-10, wall-mode) the §12.7 entry documents
- `.planning/phases/15-arcade-substrate-skeleton/15-HUMAN-UAT.md` — pending
  Instruments item (SC5) that this phase's baseline session retires

### Design system
- `DESIGN.md` §2 (color semantics), §4 (typography — monospacedDigit rules),
  §8.2 (haptic vocabulary the §12 entries cite), §10.2/§10.3 (animation
  vocabulary), §11 (empty states), §12.5 (future-games checklist — the new
  entries land as §12.6 Stack / §12.7 Snake alongside it), §12.1-12.4
  (existing entries — match their format)
- `CLAUDE.md` §8.12 (theme audit), §8.1/§8.5 (file caps), §8.14 (release-log
  append), §2 (token verification)
- `../DesignKit/Sources/DesignKit/Typography/TypographyTokens.swift` —
  confirms `monoNumber` is body-sized; `titleLarge` is the only large type
  token (D-02 constraint)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `gamekit/gamekit/Screens/StackStatsCard.swift` +
  `gamekit/gamekit/Screens/SnakeStatsCard.swift` — the ~95%-identical Phase
  16/17 placeholder cards being consolidated; their `Grid`/`metricRow`/
  `emptyState` skeleton seeds the shared component
- `gamekit/gamekit/Games/Stack/StackScoreChip.swift` — the uppercase-caption-
  over-numeral label idiom the hero treatment reuses
- `gamekit/gamekit/Core/GameStats.swift` (`recordStackRun` ~line 329) +
  `Core/BestScore.swift` — per-run `GameRecord.score` already persisted for
  both games; average is pure derivation

### Established Patterns
- Props-only stats cards (§8.2): StatsView owns all SwiftData queries; cards
  receive `records`/`bestScores` arrays — the shared component keeps this
- Per-game section shape in StatsView: `settingsSectionHeader` + `DKCard`
  wrapping the card — call sites unchanged
- Blocking human-verification checkpoint with prepared recipe (Phase 16
  `16-07-PLAN.md` Task 2; Phase 17 device-approved 2026-07-04) — reuse for
  the Instruments session

### Integration Points
- `gamekit/gamekit/Screens/StatsView.swift` (488 lines — near the ~400 soft
  cap; do not grow it) — hosts both cards; no query changes needed
- `gamekit/gamekit/Screens/HomeView.swift` `destination(for:)` ~line 359 —
  ADR call-site comments + structural lazy-init proof
- `DESIGN.md` §12 — new §12.6/§12.7 entries
- `Docs/releases/` — §8.14 release-log append for the stats redesign (check
  current `MARKETING_VERSION` in pbxproj)

</code_context>

<specifics>
## Specific Ideas

- The arcade cards should read as a deliberately different *shape class* from
  the turn-based cards — vertical hero hierarchy vs column grid — while staying
  inside GameDrawer's existing visual language (StackScoreChip label idiom, DKCard
  hosting, token discipline). Distinct, not foreign.
- Honesty over theater in verification: record a real cold-start baseline
  number instead of claiming comparison against a baseline that was never
  measured.

</specifics>

<deferred>
## Deferred Ideas

- Score trend charts / run-summary micro-screen — v2+ per FEATURES.md
- Daily seed, SFX cues, leaderboards — explicitly out of v1.5 scope
- Roadmap SC5 grep-path correction (`Games/*/Engine` subdirs don't exist) —
  handled as a verification-step path fix inside this phase, noted here so the
  verifier doesn't flag a false failure

None beyond the above — discussion stayed within phase scope.

</deferred>

---

*Phase: 18-stats-design-specs-adr*
*Context gathered: 2026-07-05*
