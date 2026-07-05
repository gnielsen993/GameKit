---
phase: 12-merge-nonogram-adoption
plan: 02
subsystem: merge,video-mode
tags: [merge, video-mode, layout-branch, wrap-site, compact-row, large-zone, sibling-extension]
requires:
  - 11-mines-adoption/11-03 (three-way layout branch template)
  - 11-mines-adoption/11-04 (compact-row composition + round-2 polish locks)
  - 12-merge-nonogram-adoption/12-01 (MergeScoreChip + MergeBestChip extracted)
provides:
  - MergeModePill compact:Bool=false API (P12 mirror of MinesweeperModePill)
  - MergeGameView three-way Video Mode body branch (off / Large / Small)
  - MergeGameView+VideoMode.swift sibling extension (308 lines)
  - HomeView Merge destination wrapped in .videoModeAware(minBoardHeight: 480)
affects:
  - MergeGameView (192 → 148 LOC; access modifiers promoted to internal for extension visibility)
  - MergeModePill (56 → 69 LOC; compact-variant API added)
  - HomeView (1 line added — Merge arm of destination(for:) wrap)
tech-stack:
  added: []
  patterns:
    - "Three-way Group { off / Large / Small } body branch on videoModeStore.isEnabled + location.isLarge"
    - "Sibling-extension file pattern for §8.5 file-size-cap split (existingLayout + chrome lives in +VideoMode.swift)"
    - "VideoCompactControlRow with onSettings: nil (no gear; Mode picker covers settings — D-MG-01 lock)"
    - "Restart-with-overflow-menu always-collapsed (NOT gated on videoModeCompactness — P11-04 round 1 polish lesson)"
    - "Symmetric chip-left / picker-center / chip-right compact-row layout (D-MG-01 = P11-04 round 2 mirror)"
key-files:
  created:
    - gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift (308 lines)
  modified:
    - gamekit/gamekit/Games/Merge/MergeModePill.swift (56 → 69 lines; compact:Bool=false API)
    - gamekit/gamekit/Games/Merge/MergeGameView.swift (192 → 148 lines; three-way branch + access promotion)
    - gamekit/gamekit/Screens/HomeView.swift (+1 line; Merge arm wrap)
decisions:
  - "D-MG-17 PROVEN: MergeBoardView.swift SHA 4aec1416... byte-identical from plan start to plan end. Confirmed via `git rev-parse 111b340c:gamekit/gamekit/Games/Merge/MergeBoardView.swift` == `git rev-parse HEAD:gamekit/gamekit/Games/Merge/MergeBoardView.swift`. The swipe-driven merge gesture composition is bit-for-bit unchanged."
  - "D-MG-01 SLOT MAPPING SHIPPED VERBATIM: Slot 1 backButton + onBack closure / Slot 2 MergeScoreChip(compact:true) / Slot 3 MergeModePill(compact:true) / Slot 4+5 HStack(MergeBestChip(compact:true) + restartWithOverflowMenu) / Slot 6 onSettings:nil. No per-game forking of VideoCompactControlRow — consumed verbatim."
  - "D-12-OFFRESTORE PRESERVED: existingLayout in the sibling extension constructs MergeHeaderBar / MergeBoardView / MergeModePill with the SAME prop list and modifier chain as the pre-12-02 MergeGameView body (verbatim ZStack + VStack(spacing: theme.spacing.m) + same sensoryFeedback triggers + same opacity/allowsHitTesting on the ModePill terminal-state gate). Off-path renders the v1.1 view tree structurally identical to pre-plan state."
  - "Sibling extension file split chosen UP FRONT (not after the host file crossed §8.5): MergeGameView would have been ~330 LOC if everything stayed inline — under the 500-line hard cap but heavy enough that the established P11-03/04 pattern argues for the split. The actual outcome: 148 LOC host + 308 LOC extension."
  - "Access modifier promotions to internal: viewModel, settingsStore, dismiss, theme, isTerminal, endStateForOverlay, endStateOverlay(state:). Same shape Mines used during Plan 11-03 — extension needs read access to these via the host struct."
  - "Restart-with-overflow-menu uses primaryAction { viewModel.restart() } + Section('Change mode') { ForEach(MergeMode.allCases) }. Tap = restart, long-press / chevron = Change-mode list. Always collapsed (not gated on videoModeCompactness == .collapsedSettings) per the P11-04 round 1 polish lesson — that threshold didn't fire reliably in practice."
metrics:
  duration_seconds: 404
  completed_date: 2026-05-14
  task_count: 4
  file_count: 4
---

# Phase 12 Plan 02: Merge Video Mode Wrap + Compact-Row Composition — Summary

Landed the Merge Video Mode wrap site + three-way layout branch + Large-zone
compactRowComposed in a single wave-2 deliverable (combines the P11-03 wrap-site
template and P11-04 compact-row composition template — Merge is simpler than
Mines because MergeBoardView stays byte-identical per D-MG-17, so both
templates collapse into one plan per the D-12-WAVES contract).

## What shipped

| File | Delta | Notes |
|------|-------|-------|
| `gamekit/gamekit/Games/Merge/MergeModePill.swift` | 56 → 69 lines | Added `compact: Bool = false` API mirroring MinesweeperModePill's compact variant: 13pt glyph (vs 16pt), `theme.typography.body` (vs `.headline`), `theme.spacing.s` horizontal pad (vs `.l`), `theme.spacing.xs` vertical pad (vs `.s`), `theme.spacing.l` minHeight (vs 44), `.lineLimit(1) + .minimumScaleFactor(0.7)`. Off-path callers (compact omitted → false) get v1.1 pill byte-identical. |
| `gamekit/gamekit/Screens/HomeView.swift` | +1 line | Merge arm of `destination(for:)` chains `.videoModeAware(minBoardHeight: 480)`. Mines arm unchanged (already wrapped in P11-03). Nonogram arm unchanged (wraps in Plan 12-04 per D-12-WAVES). |
| `gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift` | NEW (308 lines) | Sibling extension hosting `existingLayout`, `backButton`, `restartButton`, `existingToolbarContent`, `smallZoneToolbarContent`, `toolbarPlacement(for:)` static, `largeZoneLayout`, `compactRowComposed`, `restartWithOverflowMenu`, `modeLabel(_:)` private helper. Mirrors `MinesweeperGameView+VideoMode.swift` shape verbatim, adapted for Merge (no timer chip — Merge has none — and one fewer slot variant since no `.reducedTime` compactness reaction). |
| `gamekit/gamekit/Games/Merge/MergeGameView.swift` | 192 → 148 lines | Body rewritten as `Group { off / Large / Small }`. Toolbar block removed (moved to sibling extension). Env reads added (`@Environment(\.videoModeStore)`, `@Environment(\.videoModeCompactness)`). Access modifiers on `viewModel`, `settingsStore`, `dismiss`, `theme`, `isTerminal`, `endStateForOverlay`, `endStateOverlay(state:)` promoted from private → internal so the sibling extension can read them. |

## D-MG-17 byte-identity confirmation (the central correctness gate)

`MergeBoardView.swift` SHA was **NOT** modified across this plan:

```
SHA at plan start (commit 111b340c, parent of 8a00bfc):
  4aec14161b00ac2dbd1ea00e3bebb696bea6fc26

SHA at plan end (commit ff28930):
  4aec14161b00ac2dbd1ea00e3bebb696bea6fc26
```

Both SHAs are bit-for-bit identical. `git diff HEAD~4..HEAD -- gamekit/gamekit/Games/Merge/MergeBoardView.swift` produces zero output. The swipe-driven merge gesture composition, the tile-render arithmetic, and the board's input geometry are untouched. T-12-MG-1 mitigation confirmed.

## Off-path structural byte-identity (D-12-OFFRESTORE / SC4)

When `videoModeStore.isEnabled == false`, the body branch resolves to:

```swift
existingLayout
    .toolbar { existingToolbarContent }
```

…where:

- `existingLayout` is the verbatim extraction of the pre-12-02 `MergeGameView.body` ZStack: `theme.colors.background.ignoresSafeArea()` + `VStack(spacing: theme.spacing.m) { MergeHeaderBar + MergeBoardView + MergeModePill }` + the end-state overlay. Same props, same closures, same `.sensoryFeedback` triggers (`.impact(weight: .light)` on `viewModel.mergeCount`, `.success` on `viewModel.terminalCount`), same `.opacity(isTerminal ? 0 : 1)` + `.allowsHitTesting(!isTerminal)` on the ModePill.
- `MergeModePill` is invoked without an explicit `compact:` argument → defaults to `false` → v1.1 pill shape byte-identical.
- `MergeHeaderBar` continues to consume `MergeScoreChip` + `MergeBestChip` with `compact` defaulted to `false` per Plan 12-01's contract — v1.1 chip render preserved.
- `existingToolbarContent` recreates the v1.1 toolbar items at the original placements (Back + Restart at `.topBarLeading`; MergeToolbarMenu at `.topBarTrailing`) — byte-identical button bodies (44×44 chevron + counterclockwise arrow, same accessibility labels).

Off-path render is structurally byte-identical to v1.1 (the user-visible composition matches; the view-tree is the same).

## D-MG-01 slot mapping (compact-row composition)

The `compactRowComposed` in the sibling extension wires the Large-zone branch to `VideoCompactControlRow` with the D-MG-01 slot order verbatim:

| Slot | Content | Notes |
|------|---------|-------|
| 1 | `onBack: { dismiss() }` | Back closure invokes `dismiss` from the host's environment. |
| 2 | `MergeScoreChip(theme:, score: viewModel.score, compact: true)` | Single chip, not stacked (mirror of P11-04 round 2 symmetric-layout polish). |
| 3 | `MergeModePill(theme:, mode: viewModel.mode, onSelect: { viewModel.requestModeChange($0) }, compact: true)` | Center-anchored via `VideoCompactControlRow`'s Spacer flanking. Mid-game mode change routes through the existing `showingAbandonAlert` (T-12-MG-5 mitigation — no new path bypasses the alert). |
| 4 + 5 (secondaryInfo HStack) | `MergeBestChip(theme:, bestScore: viewModel.bestScore, compact: true)` + `restartWithOverflowMenu` | `HStack(spacing: theme.spacing.s)`. Best chip is the right-side persistent value (Merge has no live timer — D-MG-01 explicit). Restart hosts the always-collapsed Change-mode menu. |
| 6 | `onSettings: nil` | Gear dropped — Mode picker covers settings role (D-MG-01 lock; matches Mines P11-04 round 1 polish carry-over). |

`restartWithOverflowMenu` uses `Menu { Section("Change mode") { ForEach(MergeMode.allCases) … } } label: { ... } primaryAction: { viewModel.restart() }`. Tap = restart (the common case during play); long-press / chevron tap surfaces the Change-mode list with a checkmark on the current mode. Always-collapsed (NOT gated on `videoModeCompactness == .collapsedSettings`) per the P11-04 round 1 polish lesson.

## File-split decision (sibling extension created from the start)

The plan called for a sibling extension up front rather than waiting for the host file to cross §8.5's 500-line hard cap. Rationale:

- Pre-12-02 MergeGameView was 192 LOC.
- Adding env reads (+5) + three-way branch (+15) + the Large-zone branch's body (~80 LOC if inline) + compactRowComposed (~35 LOC if inline) + restartWithOverflowMenu (~25 LOC if inline) + existingLayout (~50 LOC if extracted but inline) would have pushed the host to ~330–400 LOC — under the 500-line hard cap but heavy enough that the established P11-03/04 pattern argues for splitting.
- Actual outcome: 148 LOC host + 308 LOC extension. Both well under §8.5's 500-line hard cap. Each file's MARK sections stay coherent (host = "scene wiring + body branch + end-state derivation"; extension = "Video Mode layout helpers").

## xcstrings keys

All localized strings consumed by the new sibling extension already exist in `Localizable.xcstrings`:

- `"Back to The Drawer"` — existed (Phase 2; MergeGameView toolbar)
- `"Restart game"` — existed (Phase 4; cross-game)
- `"Change mode"` — existed (Phase 6.1 for the Merge abandon-alert / toolbar flow)
- `"Win"` — existed (MergeModePill consumes; Phase 8+)
- `"Infinite"` — existed (MergeModePill consumes; Phase 8+)

No new `xcstrings` keys introduced.

`gamekit/gamekit/Resources/Localizable.xcstrings` showed a pre-existing uncommitted modification at plan start (Xcode auto-managed additions accumulated from prior MergeToolbarMenu / Drawer surface edits — not introduced by this plan and not within Task 1–4 acceptance criteria scope). Left uncommitted; will sweep in a separate housekeeping commit or a downstream phase-close commit. Per executor SCOPE BOUNDARY rule (out-of-scope discoveries are not auto-fixed).

## Verification

- **Build:** `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → `** BUILD SUCCEEDED **` after Task 4 (the Task 3 acceptance criterion explicitly noted that the sibling-extension commit alone leaves the build red until Task 4 wires it; the sequenced pair lands green end-to-end).
- **MergeViewModelTests:** `** TEST SUCCEEDED **` — all 9 test cases (`restartResets / initReadsPersistedMode / winBannerInWinMode / noBannerInInfiniteMode / initSeedsBoardImmediately / scoreIncrementsOnMerge / gameOverPath / setModePersists / continuePastWinPath`) pass on Clone 1 of iPhone 17 Pro. VM behavior unchanged.
- **D-MG-17:** `git rev-parse 111b340c:gamekit/gamekit/Games/Merge/MergeBoardView.swift` == `git rev-parse HEAD:gamekit/gamekit/Games/Merge/MergeBoardView.swift` == `4aec14161b00ac2dbd1ea00e3bebb696bea6fc26`. Byte-identical.
- **D-12-OFFRESTORE:** Off-path view tree structurally byte-identical (same props, same closures, same modifier chain).
- **File-size cap (§8.5):** MergeModePill 69 / MergeGameView 148 / MergeGameView+VideoMode 308. All well under the 500-line hard cap and the plan's per-file soft caps (≤80 / ≤180 / ≤400).
- **Token discipline (§2 / FOUND-07):** `grep -cE "Color\(|cornerRadius: [0-9]|padding\([0-9]"` returns `0` for MergeModePill.swift AND MergeGameView+VideoMode.swift.
- **§8.7 no Finder dupes:** `find gamekit/gamekit/Games/Merge -name "*\ 2.swift"` returns nothing.
- **Manual smoke (deferred to Plan 12-06):** Per the plan's verification block, the full SC sweep moves to Plan 12-06's 24-row manual matrix. This plan needed only build + tests + D-MG-17 byte-identity, which are all green.

## Commits

| Task | Type | Hash | Message |
|------|------|------|---------|
| 1 | feat | `8a00bfc` | feat(12-02): add compact:Bool=false API to MergeModePill |
| 2 | feat | `eb638cb` | feat(12-02): wrap Merge NavigationLink destination in .videoModeAware |
| 3 | feat | `3930442` | feat(12-02): add MergeGameView+VideoMode sibling extension |
| 4 | refactor | `ff28930` | refactor(12-02): three-way Video Mode branch in MergeGameView body |

## Deviations from Plan

None — plan executed exactly as written. All 4 tasks landed in their own commits per CLAUDE.md §8.10 commit discipline. No Rule 1–4 deviations triggered:

- No bugs surfaced (Rule 1 not invoked).
- No missing critical functionality (Rule 2 not invoked) — auth/mid-game-mode-change route through the existing abandon-alert (T-12-MG-5 mitigation preserved); back-chevron + edge-swipe-back hijack prevention preserved on all 3 branches (T-12-MG-6 mitigation preserved); compact-row picker mid-game alert routing inherits the existing VM behavior (no new bypass).
- No blocking issues (Rule 3 not invoked) — all required types (`MergeScoreChip`, `MergeBestChip`, `VideoCompactControlRow`, `VideoModeSlotRouter`, `SlotAnchor`, `MergeMode.allCases`) existed at plan start and have unchanged public surfaces.
- No architectural decisions surfaced (Rule 4 not invoked) — the plan inherits the locked Mines pattern verbatim.

Localizable.xcstrings has a pre-existing uncommitted change (from prior Xcode auto-management, present in `git status` at session start) that is out of scope and remains uncommitted. Not a deviation — explicit SCOPE BOUNDARY rule preserves it.

## Downstream consumers (Plans 12-03 / 12-04 / 12-05 / 12-06)

- **Plan 12-03 (Nonogram chip extract):** Independent of this plan's surface — extracts `NonogramSizeChip` + `NonogramLivesChip` from `NonogramHeaderBar`. Same `compact: Bool = false` API shape as Merge's chips.
- **Plan 12-04 (Nonogram wrap + compact-row):** Will mirror this plan's shape: HomeView Nonogram arm gets `.videoModeAware(minBoardHeight: 480)`; NonogramGameView gets a three-way Group branch; a `NonogramGameView+VideoMode.swift` sibling extension hosts the layout members; `compactRowComposed` consumes `NonogramSizeChip` / `NonogramLivesChip` (slot 2 conditional swap on Free vs Lives mode), `NonogramModePill(compact:true)` (slot 3), `VideoModeTimerChip(compact:true)` (slot 4 — Nonogram has a live timer, unlike Merge), and `restartWithOverflowMenu` (slot 5).
- **Plan 12-05 (Nonogram cell-size floor audit):** Independent of Merge — Nonogram-only. Mirrors P11-05 audit shape.
- **Plan 12-06 (phase close):** Manual matrix sweep across both Merge + Nonogram × 2 difficulties × 6 zones. Off-path SC4 sweep will visually confirm the structural byte-identity claim made in this summary (D-12-OFFRESTORE).

## Self-Check: PASSED

- `gamekit/gamekit/Games/Merge/MergeModePill.swift`: FOUND (compact API present)
- `gamekit/gamekit/Games/Merge/MergeGameView.swift`: FOUND (three-way branch, 148 LOC)
- `gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift`: FOUND (308 LOC sibling extension)
- `gamekit/gamekit/Screens/HomeView.swift`: FOUND (Merge arm wrap)
- `gamekit/gamekit/Games/Merge/MergeBoardView.swift`: PRESENT and SHA UNCHANGED (`4aec1416...` matches HEAD~4)
- Commit `8a00bfc` (Task 1): FOUND
- Commit `eb638cb` (Task 2): FOUND
- Commit `3930442` (Task 3): FOUND
- Commit `ff28930` (Task 4): FOUND
- Build: `** BUILD SUCCEEDED **`
- MergeViewModelTests: `** TEST SUCCEEDED **`
