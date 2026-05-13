# Phase 11: Minesweeper Adoption — Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 9 (2 new code · 1 new doc · 4 modified code · 2 modified doc)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `gamekit/gamekit/Games/Minesweeper/MinesRemainingChip.swift` | NEW · extracted subview (props-only chip) | render-from-props | `Games/Minesweeper/MinesweeperHeaderBar.swift` `counterChip(value:)` (lines 41-61) | exact (chip MARK ⊂ same file) |
| `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` | NEW · extracted subview (props-only chip + TimelineView) | render-from-props (1Hz tick) | `Games/Minesweeper/MinesweeperHeaderBar.swift` `timerChip` (lines 76-99) | exact (chip MARK ⊂ same file) |
| `.planning/phases/11-mines-adoption/11-VIDEO-MANUAL-CHECK.md` | NEW · matrix verification doc | manual verification | `.planning/phases/07-release/07-CHECKLIST.md` | role-match (matrix sign-off doc) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` | MODIFIED · consumer-of-extracted-chips | composition | itself (post-D-03 extraction) | self-refactor |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` | MODIFIED · video-mode-aware branch site | env-driven conditional layout | `Core/VideoModeAware.swift` `body(content:)` (lines 74-85, env-read pattern) | role-match (env consumer pattern, not yet on a game view) |
| `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` | MODIFIED · static-helper extension | pure-formula constant | itself (`minCellSize` + `cellSize(...)` static, lines 67-115) | self-extension |
| `gamekit/gamekit/Screens/HomeView.swift` | MODIFIED · `.videoModeAware()` call site | view-modifier application | `Core/VideoModeAware.swift` extension comment block (lines 167-175 adoption shape) | role-match (NavigationLink destination switch) |
| `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` | MODIFIED · slot-row table edit | doc-edit | itself (existing Mines section) | self-edit |
| `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` | MODIFIED · slot-row table edit | doc-edit | itself (existing Mines section) | self-edit |
| `Docs/releases/v1.2.md` | MODIFIED · release-log append | doc-edit | itself (existing Phase 9 / Phase 10 entries) | self-edit |

---

## Pattern Assignments

### `gamekit/gamekit/Games/Minesweeper/MinesRemainingChip.swift` (NEW · extracted subview)

**Analog:** `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` (lines 41-69 — current `counterChip(value:)` private @ViewBuilder)

**Imports + struct header pattern** (mirror lines 19-23 of HeaderBar):
```swift
import SwiftUI
import DesignKit

struct MinesRemainingChip: View {
    let theme: Theme
    let minesRemaining: Int
```

**Body pattern — lift `counterChip(value:)` verbatim** (HeaderBar lines 42-61):
```swift
HStack(spacing: theme.spacing.xs) {
    Image(systemName: "flag.fill")
        .foregroundStyle(theme.colors.danger)
    Text(formatCounter(minesRemaining))
        .font(theme.typography.monoNumber)
        .foregroundStyle(theme.colors.textPrimary)
        .monospacedDigit()
}
.padding(.horizontal, theme.spacing.m)
.padding(.vertical, theme.spacing.s)
.background(theme.colors.surface)
.clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
        .stroke(theme.colors.border, lineWidth: 1)
)
.accessibilityElement(children: .ignore)
.accessibilityLabel(Text("\(minesRemaining) mines remaining"))
```

**Helper to move with the chip** (HeaderBar lines 66-69):
```swift
private func formatCounter(_ n: Int) -> String {
    if n >= 0 { return String(format: "%03d", n) }
    return "\(n)"
}
```

**Notes / divergence:**
- Props-only per CLAUDE.md §8.2 — receives `theme` + `minesRemaining`; no env reads.
- Token discipline preserved verbatim — `theme.radii.chip`, `theme.spacing.{xs,s,m}`, `theme.colors.{danger,surface,textPrimary,border}`, `theme.typography.monoNumber`.
- A11Y label + `.accessibilityElement(children: .ignore)` carries over so VoiceOver behavior is identical to today.
- File-cap §8.5: ~35 lines, well under 400. Synchronized root group auto-registers per §8.8.

---

### `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` (NEW · extracted subview)

**Analog:** `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` (lines 71-132 — `timerChip` + `displayedElapsed` + `formatElapsed` + `formatElapsedSpoken`)

**Struct header — props mirror current HeaderBar timer dependencies** (HeaderBar lines 25-27):
```swift
struct TimerChip: View {
    let theme: Theme
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
```

**TimelineView body — lift `timerChip` verbatim** (HeaderBar lines 77-99):
```swift
TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1)) { context in
    HStack(spacing: theme.spacing.xs) {
        Image(systemName: "clock")
            .foregroundStyle(theme.colors.textPrimary)
        Text(formatElapsed(displayedElapsed(at: context.date)))
            .font(theme.typography.monoNumber)
            .foregroundStyle(theme.colors.textPrimary)
            .monospacedDigit()
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.s)
    .background(theme.colors.surface)
    .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
            .stroke(theme.colors.border, lineWidth: 1)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Time elapsed"))
    .accessibilityValue(Text(formatElapsedSpoken(displayedElapsed(at: context.date))))
}
```

**Time-math helpers (move all three)** (HeaderBar lines 103-132):
```swift
private func displayedElapsed(at now: Date) -> TimeInterval {
    guard let anchor = timerAnchor else { return pausedElapsed }
    return pausedElapsed + max(0, now.timeIntervalSince(anchor))
}
// formatElapsed + formatElapsedSpoken move verbatim.
```

**Notes / divergence:**
- Phase 3 D-05 timer invariants preserved — `TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))`. NO Timer.publish, NO Combine, NO Task-sleep loop.
- `.distantPast` anchor stops the tick when paused — DO NOT replace with a guard around TimelineView; the freeze depends on this anchor (HeaderBar lines 14-16, doc-commented invariant).
- File-cap §8.5: ~55 lines.
- Shared by HeaderBar (D-03 consumer) and compact-row slot-2 stacked subview (D-06).

---

### `.planning/phases/11-mines-adoption/11-VIDEO-MANUAL-CHECK.md` (NEW · matrix verification doc)

**Analog:** `.planning/phases/07-release/07-CHECKLIST.md` (whole-file structure; especially the per-SC matrix tables at lines 47-56 and 109-122)

**Front-matter pattern** (mirror lines 1-9 of 07-CHECKLIST.md):
```yaml
---
phase: 11-mines-adoption
type: video-manual-check
canonical: true
status: pending  # pending | in_progress | complete | blocked
signed_off_by: ""
signed_off_date: ""
---
```

**Matrix table shape** (mirror 07-CHECKLIST SC1 table, lines 47-56):
```markdown
| # | Difficulty | Zone | First-tap | Reveal | Long-press flag | Restart | Win/Loss completes | Pass/Fail | Notes |
|---|------------|------|-----------|--------|-----------------|---------|--------------------|-----------|-------|
| 1 | Easy   | largeTop         | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| 2 | Easy   | largeBottom      | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL |  |
| … | …      | …                | … | … | … | … | … | …               |  |
| 13 | Hard  | largeTop         | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | ADR ref: mines-hard-classic-pip-large.png, mines-hard-dracula-pip-large.png |
| 14 | Hard  | largeBottom      | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | ADR ref: same |
| 15-18 | Hard | small{TL,TR,BL,BR} | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ PASS / ☐ FAIL | ADR ref: mines-hard-dracula-pip-small-{tl,tr,bl,br}.png |
```

**Sign-off block** (mirror 07-CHECKLIST lines 161-171):
```markdown
**Verifier:** _______________  **Date:** ___________  **Status:** ☐ PASS / ☐ FAIL / ☐ DEFERRED

## Sign-off
| Criterion | Verifier | Date | Status |
|-----------|----------|------|--------|
| SC1 — Easy/Medium pass marks all 6 zones | _____ | _____ | ☐ PASS / ☐ FAIL |
| SC3 — Hard final-render parity vs ADR shots | _____ | _____ | ☐ PASS / ☐ FAIL |
```

**Notes / divergence:**
- 18 rows = 3 difficulties × 6 zones per D-14.
- Living doc per D-15: SC1 fills Easy + Medium rows; SC3 fills Hard rows with ADR-screenshot references in the Notes column.
- Hard rows must cite the 6 ADR screenshots verbatim per D-14: `mines-hard-classic-pip-large.png`, `mines-hard-dracula-pip-large.png`, `mines-hard-dracula-pip-small-{tl,tr,bl,br}.png`.
- Co-located with phase artifacts (D-13). NOT in `Docs/`.

---

### `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` (MODIFIED · consumer of D-03 extractions)

**Analog:** itself, post-extraction. After D-03, HeaderBar becomes a thin composer.

**Post-extraction body pattern** (replaces current lines 29-37):
```swift
var body: some View {
    HStack(spacing: theme.spacing.s) {
        MinesRemainingChip(theme: theme, minesRemaining: minesRemaining)
        Spacer()
        TimerChip(theme: theme, timerAnchor: timerAnchor, pausedElapsed: pausedElapsed)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.s)
}
```

**Lines deleted:** 39-132 (the `counterChip`, `timerChip`, `formatCounter`, `displayedElapsed`, `formatElapsed`, `formatElapsedSpoken` — all move with their chip).

**Notes / divergence:**
- HeaderBar shrinks from 133 lines → ~37 lines.
- Props on the struct (lines 24-27 `theme`, `minesRemaining`, `timerAnchor`, `pausedElapsed`) stay unchanged so call sites in `MinesweeperGameView.swift` lines 82-87 do not have to change.
- Single source of truth for chip rendering — both HeaderBar (non-Video / Small) and the compact-row slot-2 stack (Large) reference these same subviews per D-03 / D-06.
- Commit discipline §8.10: chip extraction is its own commit, separate from D-01 layout-branch commit.

---

### `gamekit/gamekit/Games/Minesweeper/MinesweeperGameView.swift` (MODIFIED · D-01/D-02 layout branch + D-18 compactness reads)

**Analog (env-read pattern):** `gamekit/gamekit/Core/VideoModeAware.swift` (lines 37-85 — store env-read + isEnabled branch)

**Env-read additions at the struct top** (mirror VideoModeAware.swift line 38 + locate next to other env reads at lines 43-68 of GameView):
```swift
@Environment(\.videoModeStore) private var videoModeStore
@Environment(\.videoModeCompactness) private var videoModeCompactness
```

**Branch site inside `body`** (replaces current ZStack at lines 77-172). Three-way branch per `<code_context>` Integration points block:
```swift
if !videoModeStore.isEnabled {
    existingLayout                       // current v1.0 ZStack body verbatim
} else if videoModeStore.location.isLarge {
    largeZoneLayout                      // D-01 — compact-row replaces HeaderBar + ModePill + toolbar
} else {
    smallZoneLayout                      // D-02 — existing layout + VideoModeSlotRouter.anchors(for:)
}
```

**`isLarge` computed property** — add to `VideoModeLocation.swift` per CONTEXT canonical_refs §"Locked foundation from Phase 9":
```swift
extension VideoModeLocation {
    /// True for the two large-PiP zones; false for the four small-corner zones.
    var isLarge: Bool {
        switch self {
        case .largeTop, .largeBottom: return true
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight: return false
        }
    }
}
```

**Large-zone compact-row composition (D-05 slot order)** — mirror `VideoCompactControlRow.swift` #Preview lines 83-93 but with D-05 stacked slot-2:
```swift
VideoCompactControlRow(
    theme: theme,
    onBack: { dismiss() },
    onSettings: { /* opens MinesweeperToolbarMenu — D-08 */ }
) {
    // slot 2 — stacked chip (D-06). VStack inside, theme.spacing.{xs,s} per Discretion.
    VStack(spacing: theme.spacing.xs) {
        MinesRemainingChip(theme: theme, minesRemaining: viewModel.minesRemaining)
        if videoModeCompactness != .reducedTime {        // D-18 — drop Time at .reducedTime
            TimerChip(theme: theme,
                      timerAnchor: viewModel.timerAnchor,
                      pausedElapsed: viewModel.pausedElapsed)
        }
    }
} picker: {
    // slot 3 — Reveal/Flag mode pill (existing component)
    MinesweeperModePill(theme: theme,
                        mode: viewModel.interactionMode,
                        onSelect: { viewModel.setInteractionMode($0) })
} secondaryInfo: {
    // slot 4/5 — Settings (difficulty menu, D-08) and Restart (rightmost, D-05).
    // D-18 .collapsedSettings folds slot 4 into slot 5 overflow.
    // NOTE: VideoCompactControlRow has 5 slots; this builder uses the
    // secondaryInfo + settings slot pair to host both D-05 actions.
}
```

**Large-zone toolbar suppression (D-09)** — apply only on Large branch:
```swift
.toolbar(.hidden, for: .navigationBar)   // hide existing back/restart/menu items
.navigationTitle(String(localized: "Minesweeper"))   // title stays (D-09)
```

**Small-zone layout (D-02)** — re-use existing VStack at GameView.body lines 81-135; only the toolbar `placement:` arguments change per `VideoModeSlotRouter.anchors(for: store.location)`:
```swift
let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
// Map anchors.back / anchors.settings → ToolbarItem(placement: …)
// .topLeading → .topBarLeading
// .topTrailing → .topBarTrailing
// Existing items at GameView.swift lines 182-214 keep their bodies; only placement flips.
```

**Notes / divergence:**
- File is currently 401 lines (CLAUDE.md §8.5 cap is ~400). The D-01/D-02 branch is the natural split point — extract large/small layouts into sibling `MinesweeperGameView+VideoMode.swift` if total tips over (per `<code_context>` Established patterns).
- §8.7 vigilance: any `MinesweeperGameView 2.swift` Finder-dupe is a §8.7 hard failure — confirm + delete before continuing.
- D-17 untouched contract: this file does NOT pass `videoModeStore.isEnabled` to `MinesweeperBoardView` — D-10 reads from env directly inside the board view per next section. Keep `MinesweeperBoardView(...)` constructor call site byte-identical.
- D-16 (A2 NavigationStack inset) — empirical plan task; do NOT preemptively widen safe-area in this file. Measure first.

---

### `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` (MODIFIED · D-10 minCellSize Video-Mode-aware)

**Analog:** itself — extend existing static-helper pattern at lines 67-115.

**Existing pattern preserved verbatim** (lines 67, 81-88):
```swift
static let minCellSize: CGFloat = 18

static func cellSize(forWidth width: CGFloat, cols: Int, padding: CGFloat, spacing: CGFloat) -> CGFloat {
    guard cols > 0 else { return minCellSize }
    let colsF = CGFloat(cols)
    let usable = max(0, width - 2 * padding)
    let spacingTotal = max(0, colsF - 1) * spacing
    let computed = (usable - spacingTotal) / colsF
    return max(minCellSize, computed)
}
```

**New sibling constant (D-11 — value locked by plan task; placeholder shown)**:
```swift
/// Video Mode floor for Hard 16×30 on Large PiP zones. Locked from the
/// D-11 plan-task audit: render Hard at candidate floors (10/11/12/13pt)
/// on Dracula + Voltage, measure mine icon + 1-8 SF Symbol legibility per
/// CLAUDE.md §8.12. Audit screenshot reference:
/// Docs/screenshots/v1.2-design/mines-hard-{classic,dracula}-pip-large.png.
///
/// Rollback condition (08-HARD-MINES-ADR.md §Rollback): if mis-tap rate
/// regresses on iPhone 17 Pro Max, switch to warning-compromise as v1.3 fallback.
static let minCellSizeVideoMode: CGFloat = 12  // <measured> — replace before SC2 close
```

**Video-Mode-aware lookup pattern (two equivalent shapes per `<decisions>` D-10 + Discretion)**:
```swift
// Option A: static overload (preferred per Discretion working name)
static func minCellSize(videoModeOn: Bool) -> CGFloat {
    videoModeOn ? minCellSizeVideoMode : minCellSize
}
```

**Call-site change inside `body`** — current line 127-134 stays mostly verbatim, with `minCellSize` threaded through the existing `cellSize(...)` helper signature. The helper's body already references `minCellSize` (line 82, 87, 114). Two options:
- Refactor `cellSize(...)` to take `floor: CGFloat` as a parameter (signature change — all 2 call sites updated together).
- Or thread `videoModeOn` through and re-derive inside the helper.

Either way: read `videoModeStore.isEnabled` from `@Environment(\.videoModeStore)` inside `MinesweeperBoardView.body` (D-12 — purely env-gated, no `location.isLarge`, no `difficulty == .hard` conditioning per ADR §How-it-composes verbatim).

**D-17 untouched contract — MUST preserve byte-identical** (BoardView lines 14-20 doc-comment block + line 79's `Self.minCellSize` reference):
- `MagnifyGesture` + `.simultaneousGesture(...)` chain
- `.scaleEffect(zoomScale, anchor: .center)` on the `LazyVGrid`
- `clampZoomScale(_:)` `[0.8, 2.0]` range
- Cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())` in `MinesweeperCellView`
- `scrollAxis(for:)` horizontal-scroll fallback
- `zoomScale` / `baseZoomScale` dual-state pattern

**Notes / divergence:**
- The ADR §How-it-composes paragraph (08-HARD-MINES-ADR.md lines 281-298) is the verbatim contract — any divergence is an ADR amendment, not a plan task.
- D-12 single-gate verification: Easy + Medium should NEVER hit the new floor on iPhone 17 Pro Max width (their `(usable - spacing) / cols` exceeds the lowered floor); only Hard hits it on Large zones. Unit test this in the plan.
- §8.12 audit mandate: Classic + Dracula minimum, plus Voltage per D-11 sketch instruction.

---

### `gamekit/gamekit/Screens/HomeView.swift` (MODIFIED · D-04 wrap call site)

**Analog:** `gamekit/gamekit/Core/VideoModeAware.swift` (lines 167-176 — adoption-site shape documented in the extension doc comment) AND `HomeView.swift` lines 156-166 (existing `destination(for:)` switch).

**Existing destination switch** (HomeView lines 156-166):
```swift
@ViewBuilder
private func destination(for route: GameRoute) -> some View {
    switch route {
    case .minesweeper(let difficulty):
        MinesweeperGameView(initialDifficulty: difficulty)
    case .merge(let mode):
        MergeGameView(initialMode: mode)
    case .nonogram(let difficulty):
        NonogramGameView(initialDifficulty: difficulty)
    }
}
```

**Modified — add `.videoModeAware(minBoardHeight: 480)` to the Mines arm** (per D-04 + P10 D-14):
```swift
case .minesweeper(let difficulty):
    MinesweeperGameView(initialDifficulty: difficulty)
        .videoModeAware(minBoardHeight: 480)
```

**Notes / divergence:**
- Smallest-change-that-satisfies (CLAUDE.md §4) — one line, one chained modifier, on the freshly constructed `MinesweeperGameView`. Matches the adoption-site shape documented at `VideoModeAware.swift:170-172`.
- `480` is the Mines floor per CONTEXT D-04; sibling games stay un-wrapped in P11 — they adopt in P12 with their own `minBoardHeight` per P10 D-14.
- Merge and Nonogram arms unchanged (out of scope per `<domain>`).
- D-04 explicitly places the wrap on the destination, NOT inside `MinesweeperGameView` itself — keeps GameView agnostic of the wrap and matches P10 D-15 "wraps Mines at the outermost layer."

---

### `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` (MODIFIED · D-05 slot row supersession)

**Analog:** itself — existing §Minesweeper section.

**Action:** locate the Mines slot row in the doc (per CONTEXT D-05 it reads `Back | Flags/mines | Reveal/Flag picker | Time | Settings`) and replace with the D-05 revised order:
```
Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart
```

Add an inline note explaining the supersession with a backlink to `11-CONTEXT.md` D-05.

**Notes / divergence:**
- This is a doc-edit only, no code impact. Plan task lands it in the same commit as the D-01/D-02 layout branch per §8.10.

---

### `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` (MODIFIED · D-05 slot row supersession)

**Analog:** itself — existing per-game slot mapping table.

**Action:** same as above — replace the Mines row with the D-05 order; add supersession note pointing to 11-CONTEXT.md D-05.

**Notes / divergence:**
- Token anchors (radii.button / spacing.xl / spacing.s) are NOT changed — those are P9 D-13-locked and stay verbatim.
- Only the slot-order row for Mines is touched.

---

### `Docs/releases/v1.2.md` (MODIFIED · release-log append per §8.14)

**Analog:** itself — existing Phase 9 + Phase 10 entries (lines 6-65 already in place).

**Append pattern** — add a Phase 11 entry under both `## User-facing changes` and `## Internal changes`. Pattern derived from existing P9 / P10 entries (release-log lines 14-65):
```markdown
- **Phase 11 (Minesweeper Video Mode adoption).** Minesweeper is the first
  game to reflow when Video Mode is On. On Large PiP zones (top/bottom),
  HeaderBar + ModePill + toolbar collapse into a single compact control
  row positioned opposite the reserved video band — Back, stacked
  Mines/Time chip, Reveal/Flag picker, Settings (difficulty menu),
  Restart. On Small PiP corners, the existing layout stays but Back /
  Restart / Menu reposition to the anti-PiP corner. Hard 16×30 renders
  at a smaller cell-size floor (<X>pt vs the v1.0 18pt) when Video Mode
  is On so the full board fits between the reserved band and the
  compact row; pinch-zoom remains the user's manual escape hatch.
```

**Internal-changes entry pattern**:
```markdown
- **MinesRemainingChip + TimerChip** (`Games/Minesweeper/`) — props-only
  chip subviews extracted from MinesweeperHeaderBar; single source of
  truth for chip rendering shared between HeaderBar (non-video / Small)
  and the compact row's stacked slot 2 (Large).
- **MinesweeperBoardView** — `minCellSize` becomes Video-Mode-aware
  (08-HARD-MINES-ADR.md smaller-cells variant). MagnifyGesture +
  auto-scale stack byte-identical.
- **MinesweeperGameView** — three-way layout branch on
  `videoModeStore.isEnabled` × `location.isLarge`; reacts to
  `\.videoModeCompactness` (.collapsedSettings → Settings into overflow;
  .reducedTime → drop Time chip).
- **HomeView** — Mines NavigationLink destination applies
  `.videoModeAware(minBoardHeight: 480)`.
```

**Notes / divergence:**
- §8.14 mandates same-commit append for every significant change. Multi-commit batch per §8.10 — the chip-extraction commit gets its bullet; the Video-Mode-wrap commit gets its bullet; the floor-lock commit gets its bullet.
- Check `MARKETING_VERSION` first per §0.3 before touching this file. Currently `v1.2.md` exists (verified) — Phase 11 appends, does not create.

---

## Shared Patterns

### Token discipline (CLAUDE.md §2 + §8.4)
**Source:** `gamekit/gamekit/Games/Minesweeper/MinesweeperHeaderBar.swift` lines 30-60 (every literal is a token lookup)
**Apply to:** all NEW + MODIFIED Swift files in this phase
```swift
// All radii: theme.radii.{chip, button, card, sheet}
// All spacing: theme.spacing.{xs, s, m, l, xl, xxl}
// All colors: theme.colors.{textPrimary, textSecondary, surface, background, border, danger, accentPrimary, ...}
// All fonts: theme.typography.{headline, caption, monoNumber}
// ZERO hardcoded cornerRadius:/padding(N)/Color(...)/numeric literals where a token exists
```
Pre-commit hook enforces in `Games/` + `Screens/` per §8.8 — `Core/` exempt but discipline carries.

### Props-only subview pattern (CLAUDE.md §8.2)
**Source:** `MinesweeperHeaderBar.swift` lines 23-27 + `MinesweeperBoardView.swift` lines 35-55 + `MinesweeperModePill.swift` lines 12-16 + `MinesweeperToolbarMenu.swift` lines 23-26
**Apply to:** `MinesRemainingChip.swift`, `TimerChip.swift`
```swift
struct FooChip: View {
    let theme: Theme
    let /* primitive value(s) */: ...
    // NO @State, NO @Environment(...) (themeManager / modelContext / videoModeStore),
    // NO @ObservedObject. Receive everything as props from MinesweeperGameView.
}
```

### `@Environment(\.videoModeStore)` env-read pattern (P9 D-05 + P10 D-04)
**Source:** `gamekit/gamekit/Core/VideoModeAware.swift` lines 37-38, 83
**Apply to:** `MinesweeperGameView.swift`, `MinesweeperBoardView.swift`
```swift
@Environment(\.videoModeStore) private var videoModeStore
// Read videoModeStore.isEnabled + videoModeStore.location at the top of body
// (NOT in nested closures — @Observable per-property tracking lives in body scope).
```

### Exhaustive-switch over `VideoModeLocation` (P10 D-02 pattern)
**Source:** `gamekit/gamekit/Core/VideoModeSlotRouter.swift` lines 88-141 + `VideoModeAware.swift` lines 115-129
**Apply to:** any `MinesweeperGameView` location branching; `VideoModeLocation.isLarge` extension
```swift
switch location {
case .largeTop, .largeBottom:
    // Large branch
case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:
    // Small branch
}
// NO default: case — a future 7th case fires a compile error at every adopter (safety net).
```

### Compactness env-read (P10 D-12/D-13)
**Source:** `gamekit/gamekit/Core/VideoModeAware.swift` lines 193-215
**Apply to:** `MinesweeperGameView.swift` Large-branch composition
```swift
@Environment(\.videoModeCompactness) private var videoModeCompactness
// Switch in the Large branch:
//   .normal               → all 5 D-05 slots
//   .collapsedSettings    → Settings folds into Restart slot overflow (D-18)
//   .reducedTime          → drop TimerChip half of slot-2 stack (D-18)
```

### A11Y label / value / element pattern
**Source:** `MinesweeperHeaderBar.swift` lines 59-60, 95-97 + `MinesweeperToolbarMenu.swift` lines 49-50
**Apply to:** `MinesRemainingChip.swift`, `TimerChip.swift`, any new toolbar reposition in `MinesweeperGameView.swift`
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(Text("..."))
.accessibilityValue(Text("..."))   // for stateful chips
```

### Localization — String(localized:) only
**Source:** `MinesweeperGameView.swift` lines 173, 193, 206, 217, 220, 223, 227 (everywhere a string appears)
**Apply to:** all new user-facing text (likely zero net-new keys per CONTEXT D-08 / D-09)
```swift
Text(String(localized: "Mines remaining"))     // NOT "Mines remaining" literal
// Localizable.xcstrings — existing Mines toolbar labels reused; confirm before SC1 close.
```

---

## No Analog Found

None. Every new/modified file has a close existing analog inside the repo (HeaderBar's chip MARK is the structural template for both new files; 07-CHECKLIST.md is the template for the verification doc; VideoModeAware.swift is the template for env-read patterns).

---

## Metadata

**Analog search scope:**
- `gamekit/gamekit/Games/Minesweeper/` — all 14 files
- `gamekit/gamekit/Core/VideoMode*.swift` — 4 files (Store, Location, Aware, SlotRouter, CompactControlRow)
- `gamekit/gamekit/Screens/HomeView.swift`
- `.planning/phases/07-release/07-CHECKLIST.md` (matrix doc template)
- `.planning/phases/08-video-mode-design/` — ADR + LAYOUTS + TOKENS docs
- `Docs/releases/v1.2.md` — release-log convention

**Files scanned:** ~28
**Pattern extraction date:** 2026-05-13
