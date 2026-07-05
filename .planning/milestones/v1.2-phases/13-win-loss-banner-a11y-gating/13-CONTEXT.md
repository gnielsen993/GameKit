# Phase 13: Win/Loss Banner + A11y Gating — Context

**Gathered:** 2026-05-14
**Status:** Ready for UI-SPEC (next: `/gsd-ui-phase 13`) → planning
**Source:** /gsd-discuss-phase (4 gray areas, locked in one batch)

<domain>
## Phase Boundary

Replace the full-screen win/loss `EndStateCard` overlays — which cover the board and violate Video Mode's "board stays visible" rule — with a non-board-covering banner/pill. The banner ships ONLY on the Video Mode path (`videoModeStore.isEnabled == true`) in all 3 games (Minesweeper / Merge / Nonogram). Off-path keeps the existing v1.0 / v1.1 `EndStateCard` byte-identical per VIDEO-13.

All banner haptics / SFX / animations route through the existing Settings toggles (`settingsStore.hapticsEnabled` / `settingsStore.sfxEnabled` / `settingsStore.animationsEnabled`) and `accessibilityReduceMotion`, mirroring the v1.0 05-03 D-10 + 05-06 D-04 gating contracts.

This phase closes the v1.2 milestone.

</domain>

<decisions>
## Implementation Decisions

### Per-game banner copy + primary action (D-13-COPY)
- **D-01:** Mirror the existing `EndStateCard` strings + primary CTAs verbatim — no relearning for returning players. Banner is a smaller surface, NOT a new vocabulary. Exact strings per game:
  - **Mines win** → title `"You won!"`, primary CTA `String(localized: "Restart")`
  - **Mines loss** → title `"Bad luck"`, primary CTA `String(localized: "Restart")`
  - **Merge winMode (reached 2048)** → title `"2048!"` (or matching existing title — confirm at execute time), primary CTA `String(localized: "Continue")` (keep playing in infinite mode — preserves the existing affordance)
  - **Merge gameOver (no moves)** → title `"No moves"`, primary CTA `String(localized: "Restart")`
  - **Nonogram won** → title `String(localized: "Solved")` + puzzle title (Nonogram convention — title hidden during play, revealed on win), primary CTA `String(localized: "New puzzle")`
  - **Nonogram gameOver (Lives 3-strikes)** → title `String(localized: "Out of lives")`, primary CTA `String(localized: "Try again")`
- **D-02:** Banner has ONE primary action (the explicit `DKButton` per 08-BANNER-PLACEMENT D-11). The existing secondary actions on the `EndStateCard` (Mines's "Change difficulty", Merge's "Change mode", Nonogram's "Change size", Merge winMode's secondary "Restart") DO NOT migrate to the banner. The toolbar menu (`MinesweeperToolbarMenu` / `MergeToolbarMenu` / `NonogramToolbarMenu`) already covers difficulty/mode/size selection from the nav bar; the banner stays single-action per VIDEO-11 SC2.

### Off-path coexistence (D-13-OFFPATH)
- **D-03:** The existing full-screen `MinesweeperEndStateCard` / `MergeEndStateCard` / `NonogramEndStateCard` STAY on the off-path (`videoModeStore.isEnabled == false`). Banner ONLY renders on the Video Mode path. Implementation pattern matches Phase 11/12: a body-level branch decides which surface to render based on `videoModeStore.isEnabled`.
- **D-04:** This preserves VIDEO-13 (off-restore byte-identity) — users not using Video Mode see ZERO change from v1.1 binary. No release-note user-facing copy for them; no muscle-memory disruption.
- **D-05:** Code-level concern: each adopter game's existing `endStateOverlay` call site (currently rendered inside `existingLayout` + `largeZoneLayout` + the 12.1 small-zone layouts) keeps the EndStateCard. Phase 13 adds a parallel banner surface that the Video-Mode path renders INSTEAD of (not in addition to) the `endStateOverlay` call. The plan-writer must decide whether to (a) gate the existing `endStateOverlay` call on `!videoModeStore.isEnabled` so it only renders off-path, or (b) introduce a `endStateBanner` sibling that the Video Mode path uses. Either way the OFF path stays byte-identical.

### Win celebration intensity in Video Mode (D-13-CELEBRATION)
- **D-06:** Keep the existing win-sweep wash (P5 D-02 `Rectangle.fill(theme.colors.success).phaseAnimator(...)`) + confetti (Mines `ConfettiView`) on the Video Mode path. Both are already routed through `accessibilityReduceMotion` per the v1.0 05-06 D-04 lock and the existing `animationsEnabled` toggle.
- **D-07:** Banner appears WITH the celebration — does not preempt it. Existing `runWinChoreography` / `endCardVisible` gates that delay the `endStateOverlay` until the sweep + confetti finish their pre-roll continue to work; the banner inherits the same gate (renders after celebration's pre-roll). When `accessibilityReduceMotion == true` OR `animationsEnabled == false`, both celebration AND banner entrance animations dampen to `.identity` per 08-BANNER-PLACEMENT D-12.
- **D-08:** No new celebration surfaces in Phase 13. The banner is chrome, not a celebration moment — confetti / sweep / spring stay as the celebration channel.

### Banner persistence (D-13-PERSIST)
- **D-09 (LOCAL):** Banner persists until the primary action (`DKButton`) is tapped. NO auto-dismiss timer. Reason: lets the user inspect the final board state — revealed mines (Mines), completed 2048 tile chain (Merge), solved picture + reveal title (Nonogram) — for as long as they want, without losing the call-to-action. Matches `EndStateCard` behavior (also no auto-dismiss).
- **D-10 (LOCAL):** No back-to-back stacking surface. The banner replaces itself when a new win/loss state arrives (`viewModel.terminalOutcome` transitions). This case is rare (only happens if user taps Restart and immediately hits a new terminal — first-tap-safe in Mines per §8.11 means at least one cell is revealed before the terminal can fire again).

### Banner anchor + shape (LOCKED — inherited from 08-BANNER-PLACEMENT.md)
- **D-09 (08-BANNER, LOCKED):** 6-row "opposite-of-PiP" anchor table — Phase 13 consumes this table verbatim. Downstream agents MUST read `08-BANNER-PLACEMENT.md` for the per-PiP-zone banner docking edge.
- **D-10 (08-BANNER, LOCKED):** Pill shape, full-width-minus-margins (`spacing.m` horizontal), `radii.button` corner.
- **D-11 (08-BANNER, LOCKED):** Explicit `DKButton` primary action — FORBIDDEN to use tap-anywhere-on-banner-to-trigger pattern.
- **D-12 (08-BANNER, LOCKED):** Reduce Motion dampens to `.identity` (mirrors 05-06 D-04 per-surface lock).

### Haptics / SFX / Animation gating (LOCKED — inherited from v1.0 patterns)
- **D-13-HAPTICS:** Banner haptic (win = success cue; loss = optional notification) gated by `settingsStore.hapticsEnabled` as the FIRST guard inside the firing surface (v1.0 05-03 D-10 contract). Unit test mirrors v1.0 `HapticsTests` shape. Mines win uses `SensoryFeedback.success`; Mines loss uses `SensoryFeedback.error`. Merge / Nonogram match.
- **D-13-SFX:** Banner SFX gated by `settingsStore.sfxEnabled` as FIRST guard. Default `false` (matches MINES-10 + v1.0 05-03 lock). Plays on `AVAudioSession.ambient` (does NOT duck user music — important since Video Mode implies user is consuming external audio). SFXPlayer construction lock from v1.0 05-03 carries.
- **D-13-ANIM:** Banner entrance + exit animation gated by `accessibilityReduceMotion` AND any future `animationsEnabled` toggle. Per-surface lock pattern (`.identity` transition, `.symbolEffect` value=0, `.keyframeAnimator` trigger=false) matches v1.0 05-06 D-04.

### Component shape (Claude's Discretion)
- **C-01:** Whether to ship a SHARED `VideoModeBanner` view in `Core/` that all 3 games consume vs per-game banner views (`MinesweeperEndBanner.swift` / `MergeEndBanner.swift` / `NonogramEndBanner.swift`). UI-SPEC + planner pick: shared component is preferred (3+ consumers → CLAUDE.md §2 promotion threshold met) but per-game ergonomics may push toward per-game thin composers around a shared primitive. Locked at UI-SPEC time.
- **C-02:** Whether the banner consumes a single `BannerContent` struct (title + CTA label + onTap closure) or a more flexible `@ViewBuilder` shape. Same: locked at UI-SPEC time per UI-SPEC component-API decisions.
- **C-03:** Whether Phase 13 needs a router extension (e.g., `SlotAnchorMap.banner: SlotAnchor`) mirroring the Phase 12.1 `headerBar` field. The 08-BANNER-PLACEMENT.md anchor table is fixed at 6 entries and the rule is the same shape as the existing `picker` + `headerBar` anchors — extending the router is the cleanest move (Compile-time exhaustive). Planner picks.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Banner design lock (the source of truth for placement + shape + A11y)
- `.planning/phases/08-video-mode-design/08-BANNER-PLACEMENT.md` — D-09 anchor table, D-10 shape, D-11 primary action, D-12 Reduce Motion. **MANDATORY read.**
- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — per-zone layout context the banner anchors into.
- `Docs/GameDrawer-v1.2-Video-Mode-Plan.md` §Win/loss screens — "hybrid minimal banner" direction.

### Existing end-state overlays being replaced (Video Mode path only)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperEndStateCard.swift` — current full-screen win/loss card for Mines. Off-path consumer.
- `gamekit/gamekit/Games/Merge/MergeEndStateCard.swift` — Merge card. Off-path consumer.
- `gamekit/gamekit/Games/Nonogram/NonogramEndStateCard.swift` — Nonogram card. Off-path consumer.

### Patterns inherited (gating + surface locks)
- `.planning/phases/05-polish/05-03-haptics-PLAN.md` D-10 — `hapticsEnabled` FIRST guard inside firing surface.
- `.planning/phases/05-polish/05-03-haptics-PLAN.md` SFX section — `sfxEnabled` FIRST guard, `AVAudioSession.ambient`, default `false`.
- `.planning/phases/05-polish/05-06-animations-PLAN.md` D-04 — per-surface animation gating (`.identity` / value=0 / trigger=false).
- `gamekit/gamekit/Core/SettingsStore.swift` — `hapticsEnabled`, `sfxEnabled`, `animationsEnabled` are the gates.

### Existing celebration surfaces (kept; gated; unchanged)
- `gamekit/gamekit/Core/ConfettiView.swift` — Mines win confetti. Already gated.
- Win-sweep wash — `Rectangle.fill(theme.colors.success).phaseAnimator(...)` inline in each game's adopter file (`MinesweeperGameView+VideoMode.swift` largeZoneLayout, `MinesweeperGameView+SmallZone.swift` etc.). Already gated.

### Video Mode path infrastructure (banner integrates here)
- `gamekit/gamekit/Core/VideoModeStore.swift` — `isEnabled` + `location` are the gates the banner consumes.
- `gamekit/gamekit/Core/VideoModeLocation.swift` — 6 PiP zones + `isLarge` / `isTopSmall` helpers (Phase 12.1 added `isTopSmall`).
- `gamekit/gamekit/Core/VideoModeSlotRouter.swift` — `SlotAnchorMap` (Phase 12.1 added `headerBar` field). Phase 13 may extend with a `banner` field per C-03.

### Phase 12.1 patterns the banner inherits
- `.planning/phases/12.1-small-zone-routing-gap-closure/12.1-CONTEXT.md` D-07 / D-08 / D-09 — chip / picker packing OPPOSITE the covered PiP corner. Same rule the banner anchor table encodes (08-BANNER-PLACEMENT D-09). The banner is a logical continuation of this routing pattern.

### Project rules
- `CLAUDE.md` §1 — smallest change.
- `CLAUDE.md` §2 — DesignKit token discipline; promote to DesignKit only when used in 2+ games (banner = 3 games → promotion threshold met for shared primitive).
- `CLAUDE.md` §8.5 — ≤500-line cap per Swift file.
- `CLAUDE.md` §8.6 — `.foregroundStyle` not `.foregroundColor`; respect access modifiers.
- `CLAUDE.md` §8.12 — game-screen change verified on Classic + one Loud preset (Voltage / Dracula).
- `CLAUDE.md` §0.3 + §8.14 — append Phase 13 entries to `Docs/releases/v1.2.md`.

### v1.2 release log
- `Docs/releases/v1.2.md` — Phase 13 entries appended on closure.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`DKButton`** (DesignKit) — primary action button. 08-BANNER-PLACEMENT D-11 mandates this.
- **`Theme` tokens** — `theme.radii.button`, `theme.spacing.m` (banner margins), `theme.spacing.l` (banner inner padding), `theme.colors.success` / `theme.colors.danger` (win vs loss tinting), `theme.typography.headline` (banner title).
- **`SettingsStore`** — already exposes `hapticsEnabled` / `sfxEnabled` / `animationsEnabled` plus `accessibilityReduceMotion` reads.
- **`SFXPlayer`** — v1.0 05-03 construction lock; banner SFX consumes the same player (no new audio infrastructure).
- **`ConfettiView`** — Mines win confetti. Reused as-is; banner does NOT replace it.
- **`VideoModeSlotRouter.anchors(for:)`** — already returns per-zone routing; Phase 13 either extends with `banner: SlotAnchor` (C-03) or maps from the 08-BANNER-PLACEMENT.md table inline.

### Established Patterns
- **Phase 11/12/12.1 body-branch pattern** — `Group { if !isEnabled { existing } else if location.isLarge { large } else if location.isTopSmall { smallTop } else { smallBottom } }`. Banner integrates at the body level — likely via a `.overlay(alignment:)` modifier or a sibling ZStack layer per `08-BANNER-PLACEMENT.md` D-09 anchor edge.
- **Per-game end-state state** — `viewModel.terminalOutcome` (Mines: `.win` / `.loss`), `viewModel.state` (Nonogram: `.won` / `.gameOver`), Merge has similar. Banner reads from the same source-of-truth state the EndStateCard reads.
- **`endCardVisible` gate** — Mines uses this to delay end-card render until win choreography pre-roll completes. Banner consumes the same gate (D-07).

### Integration Points
- **`MinesweeperGameView.body` / `MergeGameView.body` / `NonogramGameView.body`** — Phase 13 adds an overlay or branches the 4-way body into a banner-aware branch when `videoModeStore.isEnabled == true && viewModel.terminalOutcome != nil`.
- **`MinesweeperGameView+VideoMode.swift` / `MergeGameView+VideoMode.swift` / `NonogramGameView+VideoMode.swift`** — host the existing `endStateOverlay(outcome:)` helpers. Phase 13 may rename / split these into `videoModeEndStateBanner` + existing card.

</code_context>

<specifics>
## Specific Ideas

### Anchor algorithm (verbatim from 08-BANNER-PLACEMENT.md)
```
| PiP location | Banner docks |
|--------------|--------------|
| Large top    | bottom edge  |
| Large bottom | top edge     |
| Small TL     | bottom-right |
| Small TR     | bottom-left  |
| Small BL     | top-right    |
| Small BR     | top-left     |
```
Same rule applied for chips/picker in Phase 12.1 (D-09b). Implementation can re-use the same `pickerOnLeading` / `chipsTrailing` boolean logic the Phase 12.1 small-zone files already shipped.

### Banner shape (verbatim from 08-BANNER-PLACEMENT.md D-10)
- Pill: `RoundedRectangle(cornerRadius: theme.radii.button)`.
- Width: full-screen minus `theme.spacing.m` horizontal margins.
- Vertical footprint: minimal — single line of title + DKButton on the trailing side.
- Reads as chrome, not as a modal — no scrim, no dim background.

### Animation surface
- Entrance: `.transition(.opacity)` (collapses to `.transition(.identity)` when Reduce Motion is on per 08-BANNER-PLACEMENT D-12).
- No spring / bounce per default — banner is informational chrome. Confetti / sweep deliver the celebration moment.

### Accessibility surface
- Banner is an `accessibilityElement(children: .combine)` so VoiceOver reads "You won! Restart button" as a single statement, then the focus lands on the DKButton for one-tap activation.
- Banner appearance triggers a `UIAccessibility.post(.announcement: ...)` per VoiceOver convention (mirrors v1.0 EndStateCard).

</specifics>

<deferred>
## Deferred Ideas

- **Banner stacking for back-to-back wins** — out of scope per 08-BANNER-PLACEMENT "Out of scope" + D-10 LOCAL above. If needed in a future phase, the design would be a queue + transition between banners.
- **Per-game banner color theming variants** — banner uses `theme.colors.success` (win) / `theme.colors.danger` (loss) tinting per existing EndStateCard convention. Per-game color overrides (e.g., Merge winMode gold) are NOT in scope; aesthetic stays unified across the 3 games.
- **Banner haptic arpeggio for win** — 08-BANNER-PLACEMENT notes "optional arpeggio" for win haptic. Phase 13 ships with a single `SensoryFeedback.success` cue; arpeggio (e.g., a short pattern of impacts) is a v1.3+ polish item.
- **Banner SFX sounds** — Phase 13 ships with `settingsStore.sfxEnabled` default `false`. If user enables, the sounds played are whatever the SFXPlayer's existing sound bank exposes (`.win` / `.loss`). New custom banner SFX sounds are NOT in scope.
- **Vertical / portrait PiP zone support** — v1.3+ candidate per 08-CONTEXT open questions.
- **Animated banner content transitions** (e.g., title text crossfade when state changes from win → loss within the same session) — banner replaces itself per D-10 LOCAL above; no in-place text animation in v1.2.

</deferred>

---

*Phase: 13-win-loss-banner-a11y-gating*
*Context gathered: 2026-05-14 via /gsd-discuss-phase (single-batch 4 gray areas)*
