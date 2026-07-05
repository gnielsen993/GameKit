---
phase: 12-merge-nonogram-adoption
type: context
created: 2026-05-13
milestone: v1.2
milestone_name: Video Mode
requirements: [VIDEO-09, VIDEO-10]
upstream_phases: [11-mines-adoption, 10-layout-primitives, 09-video-mode-foundation, 08-video-mode-design]
target_plan_count: "6-7"
---

# Phase 12 — Merge + Nonogram Adoption — CONTEXT

Phase 12 mechanically replays Phase 11's locked Minesweeper Video Mode adoption pattern across the two remaining v1.1 games (Merge + Nonogram). The pattern was battle-tested through 4 rounds of user-feedback polish during P11 execution; this phase inherits it verbatim.

## Source

- ROADMAP §"Phase 12: Merge + Nonogram Adoption" — SC1 (Merge), SC2 (Nonogram), SC3 (legibility regression), SC4 (Off-restore byte-identity), SC5 (compact-row contract consumed verbatim).
- REQUIREMENTS: VIDEO-09 (Merge adoption), VIDEO-10 (Nonogram adoption with hint readability).
- Phase 11 lessons codified at `.planning/phases/11-mines-adoption/11-CONTEXT.md` and `.planning/phases/11-mines-adoption/11-04-SUMMARY.md` (the addendum trail covers 4 rounds of polish).

## Carried-forward decisions (locked by Phase 11, applied verbatim)

| Decision | Phase 11 origin | Phase 12 application |
|----------|-----------------|----------------------|
| Symmetric two-chip layout (chip-left / centered picker / chip-right + restart-with-overflow-menu) | 11-04 round 2 polish | Same shape for Merge + Nonogram compact rows |
| No standalone settings gear (`VideoCompactControlRow.onSettings: nil`) | 11-04 round 1 polish | Both games pass `nil` |
| Always-collapsed difficulty/settings menu folded into restart on Large zones | 11-04 round 1 polish | Both games use `restartWithOverflowMenu` unconditionally on Large |
| Center-anchored picker via `Spacer(minLength: 0).frame(maxWidth: theme.spacing.xs)` flanking the picker | 11-04 round 4 polish | Inherited from the shared `VideoCompactControlRow` |
| Per-game compact chip API (`compact: Bool = false` parameter; off-path stays byte-identical) | 11-01 + round 2-4 polish | Same API shape extended to MergeScoreChip / MergeBestChip / NonogramSizeChip / NonogramLivesChip |
| Compact ModePill API (`compact: Bool = false`, `.lineLimit(1)`, `.minimumScaleFactor(0.7)`) | 11-04 round 2 polish | Same shape for MergeModePill + NonogramModePill |
| Wrap GameView (NOT BoardView) at the outermost layer | CONTEXT D-15 | Wrap MergeGameView + NonogramGameView only |
| `MinesweeperBoardView`-style untouched contract (gestures + scale + render geometry byte-identical) | CONTEXT D-17 | Nonogram D-NG-17 below; Merge D-MG-17 below |
| Three-way layout branch (off / Small-zone slot-routed / Large-zone compactRowComposed) | 11-03 | Same three-way branch in each GameView |
| Sibling extension file pattern when GameView would exceed §8.5 500-line cap | 11-03 | NonogramGameView+VideoMode.swift very likely needed (BoardView is 512 LOC; GameView is 281 LOC) |
| Phase 9 D-12 5-slot contract softened to 5-or-4 via nullable `onSettings` | 11-04 round 1 polish | Already softened in the shared `VideoCompactControlRow.swift` |

## Decisions (this phase)

### D-MG-01: Merge compact-row slot mapping (Verbatim Mines pattern)
**Slot order:** `Back | Score | <spacer> Mode picker <spacer> | Best Restart-w/menu`
- Slot 1 (left): Back button (shared `VideoCompactControlRow.backButton`)
- Slot 2 (left chip): `MergeScoreChip(compact: true)` — current run score
- Slot 3 (centered picker): `MergeModePill(compact: true)` — current mode (Classic / Endless / etc.)
- Slot 4 (right chip): `MergeBestChip(compact: true)` — persisted best score for the current mode
- Slot 5 (right): `restartWithOverflowMenu` — Mines-style, tap = restart, menu hosts Change-mode (and any other settings entries)
- Slot 6 (gear): NOT rendered (`onSettings: nil`)

Merge has no live timer. The right-side chip is "Best", which is a stable persisted value. Use the same `compact` chip primitive shape (icon + monospaced value).

### D-NG-01: Nonogram compact-row slot mapping (Verbatim Mines pattern + Lives swap)
**Slot order:** `Back | Size-or-Lives | <spacer> Fill/Mark picker <spacer> | Time Restart-w/menu`
- Slot 1 (left): Back button
- Slot 2 (left chip): **In Free mode** `NonogramSizeChip(compact: true)`; **In Lives mode** `NonogramLivesChip(compact: true)` — single-slot conditional swap, NOT a stacked composite (D-06 stays superseded for this phase)
- Slot 3 (centered picker): `NonogramModePill(compact: true)` — Fill/Mark mode picker (the Reveal/Flag equivalent)
- Slot 4 (right chip): `VideoModeTimerChip(compact: true)` (the shared chip moved from Mines to `Core/` per D-12-CHIPS below)
- Slot 5 (right): `restartWithOverflowMenu` — tap = restart; menu hosts Change-difficulty / Change-mode (Free ↔ Lives)
- Slot 6 (gear): NOT rendered (`onSettings: nil`)

### D-12-CHIPS: Chip extraction strategy (per-game compact variants + shared TimerChip)
**Per-game compact variants:** Extract these as props-only siblings with `compact: Bool = false` parameter mirroring Plan 11-01:
- `MergeScoreChip` — icon `chart.line.uptrend.xyaxis` (or `Score` glyph), monospaced value
- `MergeBestChip` — icon `star.fill`, monospaced value
- `NonogramSizeChip` — icon `square.grid.3x3.square`, "10 × 10"-style label
- `NonogramLivesChip` — 3 heart glyphs with `i < remaining` dim/fill split (preserve existing `NonogramHeaderBar.livesChip` shape but as standalone view)

Each chip:
- Default `compact: false` → byte-identical to the inline shape currently in `MergeHeaderBar` / `NonogramHeaderBar` (off-path preservation per Plan 11-01 contract).
- `compact: true` → height drops to `theme.spacing.m`, horizontal padding to `theme.spacing.xs`, typography one Dynamic Type step down. Same scaling shape Plan 11-01's polish round 2 added.

**Shared timer chip — MOVE not duplicate:**
- Rename `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` → `gamekit/gamekit/Core/VideoModeTimerChip.swift`.
- Update Mines's existingLayout + compactRowComposed call sites to use the renamed type.
- Nonogram's existing `NonogramHeaderBar.timerChip` (inline) gets replaced by the shared `VideoModeTimerChip` (default `compact: false` → byte-identical to its current inline shape).
- This is a single rename commit, no behavior change, no risk to Mines off-path byte-identity (the props are game-agnostic — `theme`, `timerAnchor`, `pausedElapsed`).

**Why not a shared `VideoModeChip` generic primitive:** Considered and rejected. Adds an abstraction layer up front; the per-game chips have game-specific glyphs and accessibility labels that resist genericization. Per-game variants match Mines's locked pattern.

### D-NG-15: Nonogram cell-size floor (empirical audit lock, like Mines's 11-05)
- Add a Video-Mode-aware seam to `NonogramBoardView.swift` mirroring Mines's Plan 11-05 shape:
  - `static let minCellSizeVideoMode: CGFloat = <PLACEHOLDER>` — locked by Task 2 audit
  - `static func minCellSize(videoModeOn: Bool) -> CGFloat` — single-gate helper
  - Existing `cellSize(forWidth:height:cols:rows:padding:spacing:)` gains a defaulted `floor: CGFloat = minCellSize` parameter (backward compat preserved).
  - `@Environment(\.videoModeStore)` env read inside `NonogramBoardView.body`.
- Audit recipe (Plan 12-05 Task 2, mirroring 11-05 Task 2):
  - Build + run on iPhone 17 Pro Max sim.
  - Video Mode On → `largeBottom`. Nonogram → hardest difficulty (15×15 Hard).
  - Render at candidate floors (10 / 11 / 12 / 13 / 14pt). The legibility threshold for Nonogram is *different* from Mines because Nonogram cells render row+column hint digits 1–9 and fill/X marks (not adjacency 1–8 + mine glyph). Audit both readouts AND the hint-digit clarity at the row/column edges.
  - Audit on Dracula + Voltage per CLAUDE.md §8.12.
  - Lock the value that survives the §8.12 sweep AND keeps row+column hints readable without horizontal scroll.
- Working number guess: `~11–12pt`, but the audit is empirical. Off-path `minCellSize: 14` is untouched (byte-identical to current Phase 6 Nonogram floor).

### D-NG-17: NonogramBoardView untouched contract (mirror of Mines's D-17)
- The ONLY changes to `NonogramBoardView.swift` are the Video-Mode-aware floor seam (D-NG-15) — env read + defaulted `floor:` param + single call-site change in `body`.
- Slide gesture, super-cell rules, hint geometry (`colHintRowHeight`, `rowHintColumnWidth`, `maxRowHints`, `maxColHints`), fill/X mark rendering all byte-identical.
- Acceptance criterion (Plan 12-05): grep-vs-git-HEAD on `simultaneousGesture\(|slideGesture\(|superCellRules\(|TimelineView\(`-equivalents returns identical counts.
- Off-path byte-identity guaranteed by the defaulted `floor: CGFloat = minCellSize` parameter — any caller that doesn't pass `floor:` continues at the v1.0 14pt.

### D-MG-17: MergeBoardView untouched contract
- `MergeBoardView.swift` is UNTOUCHED in Phase 12 — no Video-Mode seam needed because Merge's biggest grid is the 4×4 standard (small board, fits at any reasonable floor on every PiP zone).
- The swipe-driven merge gesture composition stays byte-identical. Phase 12 wraps `MergeGameView` only; the BoardView is invisible to Phase 12 changes.
- Acceptance criterion (Plan 12-02): `MergeBoardView.swift` SHA unchanged across the phase.

### D-12-WAVES: Per-game waves + 6-7 plan count
**Wave structure (per-game, not per-surface):**

| Wave | Plans | Scope |
|------|-------|-------|
| 1 | 12-01 | Merge chip extraction (MergeScoreChip + MergeBestChip) + TimerChip move from `Games/Minesweeper/` to `Core/VideoModeTimerChip.swift` (one shared rename commit; updates Mines's two call sites — existingLayout + compactRowComposed) |
| 2 | 12-02 | Merge HomeView wrap + MergeGameView three-way branch + Large-zone compactRowComposed |
| 3 | 12-03 | Nonogram chip extraction (NonogramSizeChip + NonogramLivesChip) — TimerChip already moved in wave 1 |
| 4 | 12-04, 12-05 | 12-04: Nonogram HomeView wrap + NonogramGameView three-way branch + Large-zone compactRowComposed (likely sibling extension file per §8.5). 12-05: Nonogram VM-aware cell-size floor + audit checkpoint (mirrors Plan 11-05) — autonomous=false |
| 5 | 12-06 | Phase close — fill 12-VIDEO-MANUAL-CHECK.md matrix (mirror 11-VIDEO-MANUAL-CHECK), append Phase 12 entries to `Docs/releases/v1.2.md`, verify + close |

**Target plan count: 6 plans.** The planner may split 12-04 if the Nonogram GameView+VideoMode sibling extension grows past `~400` lines, bringing it to 7.

Per-game waves preferred over per-surface (rejected option) because:
- Cleaner rollback per game (Merge or Nonogram can be reverted independently).
- The Nonogram audit checkpoint (12-05) blocks Nonogram's phase-close but not Merge's, so per-game waves naturally serialize the human-verify step.
- Phase 11's polish iterations taught us that user-feedback rounds compound; per-game waves let Merge land + visually approve before Nonogram's polish surface adds noise.

### D-12-MATRIX: Manual verification matrix doc
- Author `.planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md` mirroring `11-VIDEO-MANUAL-CHECK.md` shape.
- Rows: 2 games × 3 difficulties × 6 PiP zones = 36 rows? Probably too dense. **Decision:** 2 games × 2 representative difficulties × 6 zones = 24 rows. The "representative difficulties" are the easy and the hardest for each game — middle difficulties inherit by geometric inheritance per Phase 11's deferred-row rationale.
- Verification will be DEFERRED to TestFlight build per the same precedent Phase 11 set; only the worst-case Large-zone rows are signed off during execution.

### D-12-OFFRESTORE: Off-restore byte-identity contract (mirror of P11 SC5)
- Both `MergeGameView` and `NonogramGameView` off-path (`videoModeStore.isEnabled == false`) MUST render byte-identical to v1.1.
- Mechanism: the `existingLayout` call site in each GameView consumes the default `compact: false` chip API → v1.1 chip shape verbatim.
- Acceptance: `MergeBoardView.swift` + `NonogramBoardView.swift` SHA unchanged for non-floor-seam code; `MergeHeaderBar.swift` + `NonogramHeaderBar.swift` continue to render the inline chip shape OR get refactored to consume the extracted chips with `compact: false` (planner picks; both preserve off-path identity).

### D-12-RELEASELOG: Append Phase 12 to v1.2 release log
- Per CLAUDE.md §0.3 + §8.14, append Phase 12 entries to `Docs/releases/v1.2.md` in the final close commit. MARKETING_VERSION still 1.1 in pbxproj; the v1.2.md file is the milestone log per project convention.
- One User-facing bullet (adoption summary for both games), Internal-changes bullets (per plan), Risks/notes (any new design-doc divergences relative to Phase 8 D-05 slot order).

## Deferred / out of scope

| Idea | Why deferred |
|------|--------------|
| Win/loss banner replacing full-screen end-state cards | Phase 13 scope (VIDEO-11, VIDEO-12) — not Phase 12 |
| MARKETING_VERSION bump 1.1 → 1.2 | Phase 13 ship plan per v1.2.md Risks/notes |
| 36-row full matrix sweep (every difficulty × every zone) | Same deferral pattern as Phase 11 — moves to TestFlight build alongside PF-06 |
| Shared `VideoModeChip` generic primitive across all 3 games | Considered + rejected this phase per D-12-CHIPS rationale |
| Re-debating the locked Mines compact-row pattern | Explicitly out of scope per D-MG-01 / D-NG-01 / D-12-WAVES |
| Restoring Phase 8 D-06 stacked chip variant | Superseded for Mines in P11; stays superseded for Phase 12 |
| Nonogram hint typography tuning beyond cell-size floor | The audit (D-NG-15) covers hint legibility; if it fails, the path is to lower the floor or fall back to existingLayout on Large zones — not to retype hints |

## Canonical refs (mandatory upstream reads for researcher/planner)

- `.planning/ROADMAP.md` §"Phase 12: Merge + Nonogram Adoption"
- `.planning/REQUIREMENTS.md` VIDEO-09 + VIDEO-10
- `.planning/phases/11-mines-adoption/11-CONTEXT.md` (the locked pattern source)
- `.planning/phases/11-mines-adoption/11-04-SUMMARY.md` (4-round polish trail — what the pattern actually is after iteration)
- `.planning/phases/11-mines-adoption/11-05-SUMMARY.md` (audit-lock shape for D-NG-15)
- `.planning/phases/11-mines-adoption/11-VIDEO-MANUAL-CHECK.md` (matrix shape for D-12-MATRIX)
- `.planning/phases/10-layout-primitives/10-CONTEXT.md` (D-05/D-08/D-11/D-12 — the underlying layout-primitives contract)
- `.planning/phases/09-video-mode-foundation/09-CONTEXT.md` (D-12 5-slot contract baseline — now softened to 5-or-4)
- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` §Merge + §Nonogram
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` §Merge + §Nonogram slot mappings (note: the Mines mapping was superseded by P11; Merge + Nonogram mappings here are the upstream source)
- `gamekit/gamekit/Core/VideoCompactControlRow.swift` (post-P11 state: nullable onSettings + center-anchored picker spacers + 5-or-4 slot contract)
- `gamekit/gamekit/Core/VideoModeAware.swift` (the `.videoModeAware(minBoardHeight:)` modifier)
- `gamekit/gamekit/Core/VideoModeSlotRouter.swift` (Small-zone slot anchors)
- `gamekit/gamekit/Games/Merge/MergeGameView.swift` (target — 192 LOC, wraps cleanly)
- `gamekit/gamekit/Games/Merge/MergeHeaderBar.swift` (current chip shape; source of extraction)
- `gamekit/gamekit/Games/Merge/MergeModePill.swift` (target — 56 LOC, gains `compact: Bool = false`)
- `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift` (target — 281 LOC, wraps cleanly)
- `gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift` (current chip shape; source of extraction)
- `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` (target for D-NG-15 floor seam — 512 LOC, ALREADY at §8.5 cap; the planner must NOT add bulk beyond the floor seam)
- `gamekit/gamekit/Games/Nonogram/NonogramModePill.swift` (target — 71 LOC, gains `compact: Bool = false`)
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` (sibling-extension shape to mirror for Nonogram)
- `gamekit/gamekit/Games/Minesweeper/MinesRemainingChip.swift` (compact-variant chip shape to mirror)
- `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` (this MOVES to Core/VideoModeTimerChip.swift in Plan 12-01)
- `~/.claude/projects/-Users-gabrielnielsen-Desktop-GameKit/memory/feedback_video_mode_compact_row.md` (the user-feedback memo that locked the polish pattern)
- `CLAUDE.md` §0.3 release-log discipline · §8.5 500-line cap · §8.10 commit discipline · §8.12 theme legibility · §8.14 release-log append

## Success criteria mapping (ROADMAP → CONTEXT decisions)

| SC | Maps to |
|----|---------|
| SC1 — Merge plays across all 6 zones, swipe stays clean, score/picker/best reflow | D-MG-01 + D-MG-17 |
| SC2 — Nonogram plays across all 6 zones, hints readable on Large-top + Large-bottom | D-NG-01 + D-NG-15 + D-NG-17 |
| SC3 — Legibility regression Classic + Loud × both games × 6 zones | D-NG-15 audit + D-12-MATRIX (DEFERRED-style coverage) |
| SC4 — Off-restore byte-identity for both games | D-12-OFFRESTORE |
| SC5 — Compact-row consumed verbatim, no per-game forking | D-MG-01 + D-NG-01 (both use the shared `VideoCompactControlRow`; only the slot-content closures vary) |

## Next

1. `/gsd-plan-phase 12` — draft the 6-7 plans against this CONTEXT
2. Researcher will surface NonogramBoardView's existing layout/hint formulas + any Merge swipe-edge interaction quirks before planning
