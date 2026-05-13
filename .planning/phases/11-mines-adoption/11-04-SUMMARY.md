---
phase: 11-mines-adoption
plan: 04
subsystem: ui
tags: [minesweeper, video-mode, compact-row, large-zone, compactness, d-05, d-06, d-08, d-18]

# Dependency graph
requires:
  - phase: 11-mines-adoption
    provides: Plan 11-01 chip extractions (MinesRemainingChip + TimerChip) + Plan 11-03 three-way layout branch + TODO 11-04 marker + sibling-file extension shape
  - phase: 10-layout-primitives
    provides: \.videoModeCompactness env (D-12/D-13) — D-18 reactions consume this
  - phase: 09-video-mode-foundation
    provides: VideoCompactControlRow 5-slot component (D-12 contract; preserved byte-identical here)
provides:
  - MinesweeperGameView Large-zone branch composes VideoCompactControlRow per D-05 slot order
  - Slot 2 stacked-chip pattern (VStack { MinesRemainingChip; TimerChip if !.reducedTime }) inside VideoCompactControlRow's primaryInfo closure — preserves the 5-slot contract while rendering 2 sub-chips
  - Slot 4+5 composite pattern inside VideoCompactControlRow's secondaryInfo closure (Settings menu + Restart button side-by-side OR collapsed into a primary-action Menu under .collapsedSettings)
  - compactRestartButton — Restart button sized to match VideoCompactControlRow's backButton/settingsButton chrome (theme.spacing.xl square + theme.radii.button corner + theme.colors.surface background)
  - restartWithOverflowMenu — D-18 .collapsedSettings affordance: Menu(primaryAction: viewModel.restart) hosts a Change-difficulty Section beneath
  - largeZoneLayout — Large-zone view tree (board ZStack + compact row + animation surfaces); HeaderBar + ModePill omitted per D-01
affects: [11-05, 11-06, 11-07, 11-08]

# Tech tracking
tech-stack:
  added: []  # zero net-new dependencies — composes existing primitives
  patterns:
    - "Stacked-chip-in-slot-2 ad-hoc pattern (D-06): a single VideoCompactControlRow slot hosts a VStack subview rather than carving a 6th slot; preserves Phase 9 D-12 5-slot contract for Merge + Nonogram"
    - "Slot 4+5 composite via secondaryInfo closure: VideoCompactControlRow's secondaryInfo @ViewBuilder hosts BOTH the Settings menu (slot 4) AND the Restart button (slot 5) without an API change — Mines-specific ad-hoc"
    - "Compactness env reactions inside the slot composition body: videoModeCompactness gates TimerChip presence in slot 2 (.reducedTime) and Menu folding in slots 4+5 (.collapsedSettings)"
    - "VStack ordering for edge-aware compact row placement: .largeTop → row at bottom (compactRowComposed AFTER board); .largeBottom → row at top (compactRowComposed BEFORE board); .videoModeAware already reserves the band via .safeAreaInset on the opposite edge"

key-files:
  created: []
  modified:
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift
    - gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift

key-decisions:
  - "Sibling-file home for the new helpers. The Large-zone layout (largeZoneLayout), compact-row composition (compactRowComposed), compact-row-shaped restart button (compactRestartButton), and overflow-menu restart (restartWithOverflowMenu) all live in MinesweeperGameView+VideoMode.swift alongside the Plan 11-03 extracted helpers (existingLayout, smallZoneToolbarContent, etc). GameView.swift stayed at 304 lines; +VideoMode.swift grew from 245 → 467 lines. Combined 771 lines, both files ≤500 (CLAUDE.md §8.5)."
  - "Slot 4+5 composite via secondaryInfo (not via VideoCompactControlRow API change). Per D-07 the 5-slot contract is preserved — the component's `onSettings` closure is unused (slot 4 lives inside secondaryInfo instead), and `secondaryInfo` hosts an HStack of MinesweeperToolbarMenu + compactRestartButton. The VideoCompactControlRow component is byte-identical to HEAD; Merge + Nonogram (Phase 12) consume it unchanged."
  - "Compact restart button is a separate helper from the toolbar restart. The toolbar `restartButton` (44×44 chevron-style icon at top-leading) lives on per-ToolbarItem placement; the compact-row visual rhythm wants `theme.spacing.xl` square + `theme.radii.button` corner + `theme.colors.surface` background to match the backButton/settingsButton chrome inside VideoCompactControlRow. A separate `compactRestartButton` @ViewBuilder is the smallest-change shape (CLAUDE.md §4)."
  - "D-18 .reducedTime drops only the TimerChip half of slot 2's stack (not the whole slot). The plan-doc D-18 rule (and the §<specifics> note) prioritize keeping Mines remaining visible at the smallest compactness level — Mines remaining is more load-bearing than elapsed time during play."
  - "D-18 .collapsedSettings uses Menu(primaryAction:) on the Restart button. Tap = restart (the common case); long-press / menu-chevron = surface Change-difficulty Section. A11Y label `Restart game` preserved so VoiceOver users hear the same announcement as the standalone Restart in .normal compactness. The Menu list mirrors MinesweeperToolbarMenu's radio-style checkmark on the current difficulty."
  - "Animation surfaces preserved verbatim. The win-sweep wash (Rectangle().phaseAnimator(...)), confetti (ConfettiView when showConfetti), and end-state overlay (endStateOverlay when terminalOutcome != nil && endCardVisible) all sit inside largeZoneLayout's ZStack with the same triggers as existingLayout. Phase 5 D-02 / D-03 behavior carries through unchanged on the Large-zone path."

patterns-established:
  - "Per-game stacked-chip-in-slot-2 pattern. Mines stacks MinesRemainingChip + TimerChip in primaryInfo without an API change. Merge + Nonogram (Phase 12) can adopt the same shape if a future game needs 2 chips in a single slot, or stay with a single chip (current planner intent — see CONTEXT D-07)."
  - "Per-game slot 4+5 composite via secondaryInfo. Mines hosts Settings (Menu) + Restart (Button) in a single HStack inside the secondaryInfo closure. Reproducible by other games that want a 5th action without consuming the component's own settingsButton slot (which is gated by onSettings)."

requirements-completed: [VIDEO-07]

# Metrics
duration: 11min
completed: 2026-05-13
---

# Phase 11 Plan 04: Minesweeper Video Mode Large-Zone Composition Summary

**The Large-zone branch placeholder left by Plan 11-03 is now filled with the
D-05 slot order: Back | [MinesRemainingChip ⊥ TimerChip stacked] | MinesweeperModePill |
MinesweeperToolbarMenu | compactRestartButton. The 5-slot `VideoCompactControlRow`
contract from Phase 9 D-12 is preserved verbatim — slot 2 hosts a VStack subview
(no new slot, no API change), and slots 4+5 share the component's `secondaryInfo`
closure. HeaderBar + ModePill from the off-path do NOT render on the Large-zone
path (D-01); both roles migrate into the compact row. The compact row sits at
the edge OPPOSITE the reserved video band (.largeTop → row at bottom;
.largeBottom → row at top). Compactness reactions per D-18: `.reducedTime`
drops only the TimerChip half of slot 2's stack; `.collapsedSettings` folds the
Settings menu (slot 4) into a primary-action Menu attached to the Restart slot.
`VideoCompactControlRow.swift` and `MinesweeperBoardView.swift` are
byte-identical to HEAD (D-07 + D-17 untouched contracts preserved).**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-05-13T23:47:34Z
- **Completed:** 2026-05-13T23:53:00Z (approximate — single-task plan)
- **Tasks:** 1
- **Files modified:** 2 (0 created, 2 modified)

## Accomplishments

- `MinesweeperGameView.swift` body's Large-zone arm now renders `largeZoneLayout` instead of `existingLayout`. The `.toolbar(.hidden, for: .navigationBar)` modifier carries over from Plan 11-03 (D-09 nav-bar suppression on Large zones).
- `MinesweeperGameView+VideoMode.swift` grew from 245 → 467 lines with 4 new helpers:
  - `largeZoneLayout` (~80 lines) — Large-zone view tree: board ZStack with the win-sweep / confetti / end-state animation surfaces preserved verbatim, and the compact row positioned at the edge opposite the reserved video band.
  - `compactRowComposed` (~60 lines) — D-05 slot composition. Slot 2 is a VStack of MinesRemainingChip + (TimerChip if !.reducedTime). Slot 3 reuses MinesweeperModePill verbatim from the off-path. The secondaryInfo closure branches on `videoModeCompactness == .collapsedSettings`: `.collapsedSettings` renders `restartWithOverflowMenu` alone; otherwise renders MinesweeperToolbarMenu + compactRestartButton in an HStack.
  - `compactRestartButton` (~12 lines) — Restart button shaped to match the compact-row's backButton/settingsButton chrome (theme.spacing.xl square + theme.radii.button corner + theme.colors.surface background).
  - `restartWithOverflowMenu` (~25 lines) — D-18 `.collapsedSettings` affordance. `Menu(primaryAction: viewModel.restart) { Section("Change difficulty") { ... } }` so tap = restart and menu = Change difficulty.
- `difficultyLabel(_:)` — a private helper inside the extension that maps `MinesweeperDifficulty` to its localized display name. Duplicated from `MinesweeperToolbarMenu.displayName` because that function is `private` to the menu component; the strings themselves ("Easy"/"Medium"/"Hard") are already in `Localizable.xcstrings` from Phase 3 onward.

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace Large-zone TODO marker with VideoCompactControlRow composition + chrome hiding** — `e1c83a9` (feat)

## Files Created/Modified

| File | Status | Before | After | Delta | Purpose |
|------|--------|--------|-------|-------|---------|
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` | MODIFIED | 304 | 304 | 0 | Body's Large-zone arm now renders `largeZoneLayout` (was `existingLayout`); doc comment updated to reference Plan 11-04 |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` | MODIFIED | 245 | 467 | +222 | Adds `largeZoneLayout`, `compactRowComposed`, `compactRestartButton`, `restartWithOverflowMenu`, `difficultyLabel(_:)` |

Net code delta: +222 lines, +0 / -0 outside the sibling-file extension. No new files created.

## Large-Zone View Tree Shape

```
ZStack {
    theme.colors.background.ignoresSafeArea()

    VStack(spacing: theme.spacing.m) {
        // Conditional ordering — band edge opposite compact row:
        //   .largeTop    (band on top)    → compactRowComposed AT BOTTOM (after board)
        //   .largeBottom (band on bottom) → compactRowComposed AT TOP (before board)

        if location == .largeBottom { compactRowComposed }

        MinesweeperBoardView( … )       // D-17 byte-identical constructor
            .keyframeAnimator( … )      // P5 D-03 loss-shake (8pt amplitude)

        if location == .largeTop    { compactRowComposed }
    }

    Rectangle(theme.colors.success)     // P5 D-02 win-sweep wash
        .ignoresSafeArea()
        .phaseAnimator( … )

    if showConfetti {
        ConfettiView( … )                // confetti on win
            .ignoresSafeArea()
    }

    if let outcome = viewModel.terminalOutcome, endCardVisible {
        endStateOverlay(outcome:)        // Phase 5 D-01/D-02 end-state card
    }
}
```

**HeaderBar + ModePill are NOT rendered on this path** (D-01). Both roles
migrate into the compact row: HeaderBar's chips → slot 2 stack; ModePill →
slot 3 picker.

## D-05 Slot Mapping

| Slot | Position | Content | Source | D-18 reactions |
|------|----------|---------|--------|----------------|
| 1 | leftmost | Back chevron | VideoCompactControlRow's own backButton (driven by `onBack: { dismiss() }`) | none — always rendered |
| 2 | left-of-center | Stacked chip: MinesRemainingChip (top) + TimerChip (bottom) | VideoCompactControlRow's `primaryInfo` closure | `.reducedTime` → TimerChip omitted; MinesRemainingChip alone in slot 2 |
| 3 | center | MinesweeperModePill (Reveal / Flag flipper) | VideoCompactControlRow's `picker` closure | none — always rendered |
| 4 | right-of-center | MinesweeperToolbarMenu (Easy / Medium / Hard selector with checkmark on current) | HStack inside `secondaryInfo` closure | `.collapsedSettings` → slot 4 folds into slot 5 as a primary-action Menu |
| 5 | rightmost | compactRestartButton (theme.spacing.xl square, arrow.counterclockwise icon, theme.colors.surface background, theme.radii.button corner) | HStack inside `secondaryInfo` closure (or `restartWithOverflowMenu` when `.collapsedSettings`) | `.collapsedSettings` → Menu(primaryAction: viewModel.restart) hosts Change-difficulty Section |

The VideoCompactControlRow's own `onSettings` closure is unused — Mines's
Settings slot lives in `secondaryInfo` per the ad-hoc Mines slot-5 pattern.
This preserves the 5-slot D-07 contract verbatim (no API change to the
shared component).

## Compactness Reaction Implementations (D-18)

### `.normal` (full-chrome)

All 5 D-05 slots render:

```swift
// Slot 2:
VStack(spacing: theme.spacing.xs) {
    MinesRemainingChip(theme: theme, minesRemaining: viewModel.minesRemaining)
    TimerChip(theme: theme,
              timerAnchor: viewModel.timerAnchor,
              pausedElapsed: viewModel.pausedElapsed)
}

// Slots 4 + 5:
HStack(spacing: theme.spacing.s) {
    MinesweeperToolbarMenu( … )
    compactRestartButton
}
```

### `.reducedTime`

`TimerChip` is omitted from slot 2's stack. `MinesRemainingChip` renders alone:

```swift
VStack(spacing: theme.spacing.xs) {
    MinesRemainingChip(theme: theme, minesRemaining: viewModel.minesRemaining)
    // TimerChip omitted — videoModeCompactness == .reducedTime
}
```

Per CONTEXT D-18 + `<specifics>`: Mines remaining is more load-bearing than
elapsed time during play, so it stays visible at the smallest compactness
level.

### `.collapsedSettings`

Slot 4 (MinesweeperToolbarMenu) folds into slot 5 as a primary-action Menu:

```swift
HStack(spacing: theme.spacing.s) {
    restartWithOverflowMenu          // Menu(primaryAction: restart) { Change-difficulty Section }
    // MinesweeperToolbarMenu NOT rendered standalone — folded into Menu above.
}
```

`restartWithOverflowMenu` is:

```swift
Menu {
    Section(String(localized: "Change difficulty")) {
        ForEach(MinesweeperDifficulty.allCases, id: \.self) { … }
    }
} label: {
    Image(systemName: "arrow.counterclockwise")
        .frame(width: theme.spacing.xl, height: theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, …))
} primaryAction: {
    viewModel.restart()
}
.accessibilityLabel(Text("Restart game"))
```

Tap = restart (the common case); long-press / menu-chevron tap surfaces the
Change-difficulty list. A11Y label `"Restart game"` preserved so VoiceOver
users hear the same announcement as `.normal` compactness's standalone
restart.

## D-07 + D-17 Untouched-Contract Byte-Identity Verification

| Contract | File | git hash before | git hash after | diff vs HEAD |
|----------|------|-----------------|----------------|--------------|
| D-07 — VideoCompactControlRow 5-slot contract | `gamekit/gamekit/Core/VideoCompactControlRow.swift` | `b95b1be3776f297190a66f70b40a113d93e3f340` | `b95b1be3776f297190a66f70b40a113d93e3f340` | 0 lines |
| D-17 — MinesweeperBoardView MagnifyGesture chain | `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` | `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` | `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` | 0 lines |

Plan 11-05 owns the only board-level change (the `minCellSize`
Video-Mode-aware lookup, D-10). Plan 11-04 reads `viewModel.minesRemaining /
.timerAnchor / .pausedElapsed / .interactionMode / .difficulty / .restart() /
.setInteractionMode / .requestDifficultyChange` — all existing VM accessors;
zero VM signature changes.

## File-Split Decision

`MinesweeperGameView.swift` is untouched in line count (304 lines — the
Large-zone arm change is purely a function-name swap from `existingLayout`
to `largeZoneLayout` plus a doc-comment refresh; no net line delta). All the
new helpers were added to the sibling file `MinesweeperGameView+VideoMode.swift`
established by Plan 11-03:

- `MinesweeperGameView.swift`: **304 lines** (unchanged)
- `MinesweeperGameView+VideoMode.swift`: **467 lines** (+222 over Plan 11-03's 245)
- Combined: **771 lines** — both files individually ≤500.

The sibling-file pattern continues to use Swift extension syntax + non-private
host-struct properties (Plan 11-03's Rule 3 deviation #1 — those properties
are still consumed by the new helpers added here).

## xcstrings Keys Touched

Net new keys: **0**. All strings used by the new code already exist in
`gamekit/gamekit/Resources/Localizable.xcstrings`:

- `"Restart game"` — used by Plan 11-03's `restartButton` and by the existing
  toolbar restart since Phase 3.
- `"Change difficulty"` — already present (used by `MinesweeperEndStateCard`
  and by Plan 11-04's restartWithOverflowMenu Section title).
- `"Easy"` / `"Medium"` / `"Hard"` — already present (used by
  `MinesweeperToolbarMenu` and elsewhere).

Pre-commit verification: `grep -c "\"Change difficulty\"" Localizable.xcstrings`
returns `2` (key + value entries); `grep -c "\"Restart game\""` returns `2`.

## Decisions Made

- **Sibling-file home for the new helpers.** Plan 11-03 already established
  the `+VideoMode.swift` extension pattern; Plan 11-04's helpers fit
  naturally there alongside `existingLayout` / `smallZoneToolbarContent` /
  `backButton` / `restartButton`. No new file created — single sibling file
  hosts all the Video-Mode-specific chrome for Mines.
- **Slot 4+5 composite via `secondaryInfo` (not via API change).** The plan
  body explicitly walked the trade-off: extending `VideoCompactControlRow`
  to 6 slots would force Merge + Nonogram (Phase 12) into a contract change
  they don't need. Hosting both slot 4 and slot 5 inside the `secondaryInfo`
  @ViewBuilder closure keeps Phase 9 D-12 intact; the component's
  `onSettings` closure is unused on the Mines Large-zone path.
- **Separate `compactRestartButton` from toolbar `restartButton`.** The
  toolbar restart (44×44 chevron-style icon at top-leading nav-bar slot,
  Plan 11-03) and the compact-row restart (theme.spacing.xl square,
  theme.radii.button corner, theme.colors.surface background) need
  different visual rhythms. Two ViewBuilders is the smallest-change shape
  per CLAUDE.md §4.
- **D-18 `.reducedTime` drops only the Time half of slot 2's stack.** Per
  CONTEXT `<specifics>`: Mines remaining is more load-bearing than elapsed
  time during play. Dropping the whole slot would lose both; dropping just
  the TimerChip keeps the Mines counter visible at the smallest compactness
  level.
- **D-18 `.collapsedSettings` uses `Menu(primaryAction: viewModel.restart)`.**
  Tap = restart (the common case); long-press / chevron tap surfaces the
  Change-difficulty Section. A11Y label `"Restart game"` preserved so
  VoiceOver behavior matches `.normal` compactness.
- **Animation surfaces preserved verbatim.** The win-sweep wash, confetti,
  and end-state overlay all sit inside largeZoneLayout's ZStack with the
  same triggers as existingLayout. Phase 5 D-02 / D-03 behavior carries
  through unchanged on the Large-zone path — no new animation surface
  introduced; no existing surface modified.

## Deviations from Plan

None. The plan executed exactly as written; no Rule 1 / Rule 2 / Rule 3 /
Rule 4 deviations triggered. No auth gates.

Two minor verification-tooling notes (not code deviations):

1. The plan's `<acceptance_criteria>` grep for `MinesweeperModePill(theme: theme`
   returns `0` because both call sites span lines (`MinesweeperModePill(`
   on one line, `theme: theme,` on the next). Verified the same intent via
   `perl -0777` multiline regex: `MinesweeperModePill\s*\(\s*theme:\s*theme`
   matches 2 times (off-path existingLayout + Large-zone slot 3). Same shape
   as Plan 11-03 deviation #2.
2. Same multiline issue for `MinesRemainingChip(theme: theme` and `TimerChip(`.
   Multiline regex verifies the intended counts (1 and 1 respectively).

## Issues Encountered

- **Pre-existing xcstrings drift carried forward (out of scope).**
  `gamekit/gamekit/Resources/Localizable.xcstrings` still shows the
  unstaged modification carried over from before Plan 11-01 (the 3 key
  stubs `"2048 · Classic"`, `"Drawer open. Tap a mode to play, or tap
  again to close."`, `"Infinite · Endless"`). Left unstaged in the
  Plan 11-04 commit. Same as Plan 11-03's `<issues>` entry.
- **Pre-existing Nonogram warning (out of scope).** `xcodebuild build`
  emits one warning from
  `gamekit/gamekit/Games/Nonogram/Engine/NonogramLibrary.swift:24:5`
  ("'nonisolated(unsafe)' is unnecessary for a constant with 'Sendable'
  type 'NSLock'"). Not introduced by Plan 11-04; touching Nonogram is out
  of phase scope per `11-CONTEXT.md` `<domain>` ("Merge + Nonogram
  adoption → Phase 12").

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — **BUILD SUCCEEDED**.
- `xcodebuild test -only-testing:gamekitTests/MinesweeperViewModelTests` — **TEST SUCCEEDED** (no VM behavior change; all cases pass).
- `grep -c "TODO 11-04" gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` → `0` ✓ (placeholder removed)
- `perl -0777` count of `VideoCompactControlRow(` → 1 invocation in +VideoMode.swift (the Large-zone composition) ✓
- `perl -0777` count of `MinesRemainingChip(theme: theme` → 1 (slot 2) ✓
- `perl -0777` count of `TimerChip(` → 1 (slot 2 with `.reducedTime` guard) ✓
- `grep -rc "videoModeCompactness != .reducedTime" …` → `1` ✓ (D-18 .reducedTime check)
- `grep -rc "videoModeCompactness == .collapsedSettings" …` → `1` ✓ (D-18 .collapsedSettings check)
- `perl -0777` count of `MinesweeperModePill\s*\(\s*theme:\s*theme` → 2 (off-path + Large-zone slot 3) ✓
- `perl -0777` count of `MinesweeperToolbarMenu\s*\(` → 3 (off-path toolbar + small-zone toolbar + Large-zone slot 4) ✓
- `grep -rc "viewModel.restart()" …` → 4 total (off-path restartButton + endStateOverlay onRestart + compactRestartButton + restartWithOverflowMenu primaryAction) ✓
- `diff <(git show HEAD:.../VideoCompactControlRow.swift) .../VideoCompactControlRow.swift` → **0 lines** ✓ (D-07 byte-identity)
- `diff <(git show HEAD:.../MinesweeperBoardView.swift) .../MinesweeperBoardView.swift` → **0 lines** ✓ (D-17 byte-identity)
- `git hash-object gamekit/gamekit/Core/VideoCompactControlRow.swift` → `b95b1be3776f297190a66f70b40a113d93e3f340` ✓ (unchanged)
- `git hash-object gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` ✓ (unchanged)
- `wc -l gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` → `304` ✓ (≤500)
- `wc -l gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift` → `467` ✓ (≤500)
- `find gamekit/gamekit/Games/Minesweeper -name "* 2.swift"` → empty ✓ (no Finder dupes)
- `grep -E "Color\(|cornerRadius: [0-9]+|padding\([0-9]+" …` → **empty** ✓ (no hardcoded literals in modified files; all radii/spacing/colors via theme tokens)

## Plan-spec Confirmations (per `<output>` block)

- **Large-zone view tree shape (compact row position + board + animation surfaces):** documented above. ✓
- **Exact slot mapping for D-05 (slot 2 stack, slot 3 ModePill, slot 4 Menu, slot 5 Restart):** documented above. ✓
- **Compactness reaction implementations (.reducedTime, .collapsedSettings):** documented above with code snippets. ✓
- **`VideoCompactControlRow.swift` + `MinesweeperBoardView.swift` unmodified:** git hashes unchanged before AND after Plan 11-04; `diff` against HEAD produces zero output. ✓
- **File-split decision:** All new helpers landed in `MinesweeperGameView+VideoMode.swift` (the sibling file established by Plan 11-03). `MinesweeperGameView.swift` line count unchanged at 304; sibling file grew from 245 → 467. Both ≤500. ✓
- **`xcstrings` keys touched:** zero net-new keys. `"Restart game"`, `"Change difficulty"`, `"Easy"` / `"Medium"` / `"Hard"` all already present. ✓

## Next Phase Readiness

- **Plan 11-05 ready.** This plan did NOT touch `MinesweeperBoardView.swift`
  per D-17 untouched contract (git hash byte-identical before and after).
  Plan 11-05 will add the `minCellSize` Video-Mode-aware lookup (D-10) +
  the locked `minCellSizeVideoMode` constant (D-11) + the §8.12 Dracula +
  Voltage legibility audit. The cell-size floor change will be evaluated
  against the Large-zone composition shipped here.
- **Plan 11-06 ready.** Plan 11-04 does NOT pre-add the `safeAreaInsets.top`
  adjustment (D-16). The largeZoneLayout VStack just flips `compactRowComposed`
  position based on `videoModeStore.location`; the `.videoModeAware` modifier
  already reserves the band via `.safeAreaInset` on the OTHER edge. Plan
  11-06 will measure the NavigationStack-mounted available board height
  empirically and decide whether the inset adjustment is needed.
- **Plan 11-07 ready.** The Large-zone composition shipped here is the
  surface against which the manual verification matrix
  (`11-VIDEO-MANUAL-CHECK.md`) will be filled — Easy + Medium pass marks
  for `largeTop` / `largeBottom` come from running the app against this
  build.
- **Plan 11-08 ready.** SC1 + SC4 + SC5 sweep will exercise the
  `compactRowComposed` body across Classic + Voltage/Dracula on Easy +
  Medium + Hard for each of the 6 PiP zones. The Large-zone branch is now
  fully composed; only the Hard cell-size floor (Plan 11-05) is missing
  before SC2's Hard validation can run.
- **Release-log entry:** Not appended in this commit per CLAUDE.md §8.10 +
  §0.3 grouping precedent (Plan 11-01 / 11-02 / 11-03 also deferred). The
  Phase 11 release-log line in 11-PATTERNS will be appended once Phase 11
  ships its first user-facing surface that lands cleanly through SC1 — most
  likely Plan 11-08's wrap-up commit.

## Self-Check: PASSED

- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift`: FOUND (304 lines, modified — body's Large-zone arm now references `largeZoneLayout`).
- `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView+VideoMode.swift`: FOUND (467 lines, modified — +222 lines for new helpers).
- Commit `e1c83a9`: FOUND (Task 1 — Large-zone composition).
- Build: green (BUILD SUCCEEDED).
- Tests: green (MinesweeperViewModelTests, all cases pass).
- D-07 contract: VideoCompactControlRow byte-identical (hash `b95b1be3776f297190a66f70b40a113d93e3f340` unchanged).
- D-17 contract: BoardView byte-identical (hash `ef2d2831aa5c35c2b92cc5c9e3d97c329bd757c3` unchanged).
- No Finder dupes.
- No deletions in the commit (`git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty).

---
*Phase: 11-mines-adoption*
*Completed: 2026-05-13*
