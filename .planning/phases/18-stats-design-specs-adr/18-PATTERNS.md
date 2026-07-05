# Phase 18: Stats, Design Specs & ADR - Pattern Map

**Mapped:** 2026-07-05
**Files analyzed:** 5 (3 Swift + 2 DESIGN.md sections)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Screens/ScoreStatsCard.swift` (NEW) | component | transform | `Screens/StackStatsCard.swift` | exact — component being extracted into this file |
| `Screens/StackStatsCard.swift` (REWRITE) | component (wrapper) | transform | `Screens/SnakeStatsCard.swift` | exact — both become identical-shape wrappers |
| `Screens/SnakeStatsCard.swift` (REWRITE) | component (wrapper) | transform | `Screens/StackStatsCard.swift` | exact — both become identical-shape wrappers |
| `DESIGN.md` §12.6 (NEW section) | documentation | N/A | `DESIGN.md` §12.3 Nonogram | format-match — most comparable off-path game entry |
| `DESIGN.md` §12.7 (NEW section) | documentation | N/A | `DESIGN.md` §12.4 Sudoku | format-match — comparable complexity |

**Verification-only touches (no new files):**
- `Screens/HomeView.swift` — `destination(for:)` comment check only, no edits expected
- `Games/Stack/StackEngine.swift` + `Games/Snake/SnakeEngine.swift` — purity grep only
- `Docs/releases/v1.4.md` — §8.14 release-log append (MARKETING_VERSION = 1.4)

---

## Pattern Assignments

### `Screens/ScoreStatsCard.swift` (component, transform) — NEW

**Analogs:** `Screens/StackStatsCard.swift` (entire file, 117 lines — the body being extracted) and `Games/Stack/StackScoreChip.swift` (hero label idiom)

**Imports pattern** (`StackStatsCard.swift` lines 15-16):
```swift
import SwiftUI
import DesignKit
```
No SwiftData — props-only per CLAUDE.md §8.2.

**Struct signature (design decision — planner's discretion on exact API):**

The component takes pre-derived display strings (derivation lives in each wrapper):
```swift
struct ScoreStatsCard: View {
    let theme: Theme
    let heroValue: String           // High Score display string, "—" when none
    let metrics: [ScoreMetric]      // Average Score + Runs Played rows (+ any extras)
    let emptyStateCopy: String      // "No runs yet."
    let isEmpty: Bool               // Passed from wrapper (records.isEmpty)
}

struct ScoreMetric {
    let label: String
    let value: String
    let a11yLabel: String
}
```

**Hero numeral treatment — caption-label idiom from `StackScoreChip.swift` lines 25-32:**
```swift
VStack(alignment: .leading, spacing: 0) {
    Text(String(localized: "HIGH SCORE").uppercased())
        .font(theme.typography.caption.weight(.semibold))
        .foregroundStyle(theme.colors.textSecondary)
    Text(heroValue)
        .font(theme.typography.titleLarge)   // D-02: titleLarge = .system(size:32,weight:.bold,design:.rounded)
        .monospacedDigit()                   // D-02: NO monoNumber token — that is body-sized only
        .foregroundStyle(theme.colors.textPrimary)
}
```
Critical constraint D-02: `theme.typography.monoNumber` is `.system(.body, design: .monospaced)` — body-sized only. The hero numeral MUST use `theme.typography.titleLarge` + `.monospacedDigit()`. Do not use `monoNumber` for the hero.

**1pt border rule between hero and grid rows** (`StackStatsCard.swift` lines 77-80):
```swift
Rectangle()
    .fill(theme.colors.border)
    .frame(height: 1)
    .gridCellColumns(2)
```

**Metric row pattern** (`StackStatsCard.swift` lines 101-116):
```swift
@ViewBuilder
private func metricRow(label: String, value: String, a11yLabel: String) -> some View {
    GridRow {
        Text(label)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.leading)
        Text(value)
            .font(theme.typography.monoNumber)
            .monospacedDigit()
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(a11yLabel))
}
```
`monoNumber` (body-sized monospaced) is correct here — only the hero numeral steps up to `titleLarge`.

**Grid container pattern** (`StackStatsCard.swift` lines 65-69):
```swift
Grid(
    alignment: .leading,
    horizontalSpacing: theme.spacing.m,
    verticalSpacing: theme.spacing.s
) {
    // hero section (VStack), border Rectangle, then metricRow calls
}
```

**Empty state pattern** (`StackStatsCard.swift` lines 54-60):
```swift
@ViewBuilder
private var emptyState: some View {
    Text(String(localized: emptyStateCopy))
        .font(theme.typography.body)
        .foregroundStyle(theme.colors.textTertiary)
        .frame(maxWidth: .infinity)
}
```

**Body switch** (`StackStatsCard.swift` lines 44-50):
```swift
var body: some View {
    if isEmpty {
        emptyState
    } else {
        metricsContent   // hero + border + grid rows
    }
}
```

---

### `Screens/StackStatsCard.swift` (component wrapper, transform) — REWRITE

**Analog:** Current `Screens/StackStatsCard.swift` — keep the props signature and derived-value MARK; replace the body with a delegation to `ScoreStatsCard`.

**Props signature (unchanged):**
```swift
struct StackStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]
}
```
StatsView call site `StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)` does not change.

**Derived values MARK — score-based derivation pattern:**

High score (existing pattern, `StackStatsCard.swift` lines 26-30):
```swift
private var highScoreText: String {
    guard let score = bestScores.first(where: {
        $0.difficultyRaw == GameStats.stackEndlessMode
    })?.score else { return "—" }
    return "\(score)"
}
```

Average score — new derivation (D-06: `compactMap { $0.score }` over the already-passed records):
```swift
private var averageScoreText: String {
    let scores = records.compactMap { $0.score }.filter { $0 > 0 }
    guard !scores.isEmpty else { return "—" }
    let avg = scores.reduce(0, +) / scores.count
    return "\(avg)"   // integer average; planner discretion on rounding
}
```
No schema change — `GameRecord.score` is already persisted for all stack runs (GameStats.swift line 337).

Runs played (existing, `StackStatsCard.swift` line 33):
```swift
private var runsPlayed: Int { records.count }
```

Best streak (existing, `StackStatsCard.swift` lines 35-39 — Stack-only, D-07):
```swift
private var bestStreakText: String {
    guard let streak = bestScores.first(where: {
        $0.difficultyRaw == GameStats.stackPerfectStreakMode
    })?.score else { return "—" }
    return "\(streak)"
}
```

**Body — thin delegation:**
```swift
var body: some View {
    ScoreStatsCard(
        theme: theme,
        heroValue: highScoreText,
        metrics: [
            ScoreMetric(
                label: String(localized: "Average Score"),
                value: averageScoreText,
                a11yLabel: String(localized: "Average score: \(averageScoreText)")
            ),
            ScoreMetric(
                label: String(localized: "Runs Played"),
                value: "\(runsPlayed)",
                a11yLabel: String(localized: "Runs played: \(runsPlayed)")
            ),
            ScoreMetric(
                label: String(localized: "Best Streak"),
                value: bestStreakText,
                a11yLabel: String(localized: "Best perfect streak: \(bestStreakText)")
            ),
        ],
        emptyStateCopy: String(localized: "No runs yet."),   // D-03
        isEmpty: records.isEmpty
    )
}
```

---

### `Screens/SnakeStatsCard.swift` (component wrapper, transform) — REWRITE

**Analog:** Current `Screens/SnakeStatsCard.swift` — identical shape to new StackStatsCard wrapper, minus the streak row.

**Props signature (unchanged):**
```swift
struct SnakeStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]
}
```
StatsView call site unchanged.

**Derived values — score key difference from Stack:**
```swift
// Snake uses literal "endless" — not a GameStats constant (17-CONTEXT D-12: renaming = data break)
private var highScoreText: String {
    guard let score = bestScores.first(where: {
        $0.difficultyRaw == "endless"
    })?.score else { return "—" }
    return "\(score)"
}

private var averageScoreText: String {
    let scores = records.compactMap { $0.score }.filter { $0 > 0 }
    guard !scores.isEmpty else { return "—" }
    let avg = scores.reduce(0, +) / scores.count
    return "\(avg)"
}

private var runsPlayed: Int { records.count }
```
Note: **No bestStreak for Snake** (D-07). Snake uses the literal `"endless"` string, not `GameStats.stackEndlessMode`.

**Body — thin delegation (no streak metric):**
```swift
var body: some View {
    ScoreStatsCard(
        theme: theme,
        heroValue: highScoreText,
        metrics: [
            ScoreMetric(
                label: String(localized: "Average Score"),
                value: averageScoreText,
                a11yLabel: String(localized: "Average score: \(averageScoreText)")
            ),
            ScoreMetric(
                label: String(localized: "Runs Played"),
                value: "\(runsPlayed)",
                a11yLabel: String(localized: "Runs played: \(runsPlayed)")
            ),
        ],
        emptyStateCopy: String(localized: "No runs yet."),   // D-03
        isEmpty: records.isEmpty
    )
}
```

---

### `DESIGN.md` §12.6 Stack + §12.7 Snake (documentation, new sections)

**Analog:** `DESIGN.md` §12.3 Nonogram (lines 635–642) and §12.4 Sudoku (lines 644–654) — bullet-list format, 6–10 bullets, cites locked decisions by phase/ADR. Insert before §12.5 Future games checklist (currently at line 656).

**Format from §12.3 Nonogram:**
```markdown
### 12.3 Nonogram
- Lives chip: `NonogramLivesChip`, hearts, only when `gameMode == .lives`.
- Small Video Mode zones: show lives + timer only — NOT the size chip.
- Large Video Mode zones: single-slot size↔lives swap in compact row slot 2
  (D-NG-01). In Free mode: size chip. In Lives mode: lives chip. Never stack
  them.
- The slide gesture / super-cell rules / hint geometry in `NonogramBoardView`
  must never be touched when making Video Mode or layout changes (D-NG-17).
```

**Content for §12.6 Stack** (document as-built per D-11 — cite 16-CONTEXT decision codes):
- Video Mode: adopted (15-VIDEO-MODE-ADR.md amendment 2026-07-02). `StackGameView` carries `.videoModeAware(minBoardHeight: 480)`.
- No lives chip. No timer chip. Score chip: `StackScoreChip` (compact: true in Video Mode compact row slot 2).
- Per-layer accent ramp (16-CONTEXT D-05/D-07): block color cycles through `accentPrimary → accentSecondary → success → …` palette via `StackPalette`. Never hardcoded.
- Perfect-drop celebration (16-CONTEXT D-08): color pulse/glow + light haptic tick + animated combo-streak counter. Gated by `hapticsEnabled` + `feedbackAnimation`. Reduce Motion: pulse collapses to instant fill, no glow.
- Game-over choreography (16-CONTEXT D-09): ~0.5s slow-mo on losing final block + tower fade + banner. Reduce Motion: instant cut to banner. No screen shake (brand rule).
- Haptic vocabulary: normal block land = `.impact(weight: .light)`. Perfect drop = distinct `.light` tick. Game over = `.error`. No per-frame haptics.
- Stats shape: `StackStatsCard` (Phase 18 D-08). Hero metric = High Score; rows = Average Score + Runs Played + Best Streak (Stack-only, persisted via `"perfectStreak"` BestScore row, 16-CONTEXT D-10/D-11).

**Content for §12.7 Snake** (document as-built per D-11 — cite 17-CONTEXT decision codes):
- Video Mode: **exempt** (15-VIDEO-MODE-ADR.md, Accepted 2026-06-26). Pixel-derived grid cells + continuous steering — PiP reflow would desync state. `SnakeGameView` has no `.videoModeAware` modifier.
- No lives chip. No timer chip. Score chip: `SnakeScoreChip` (no compact variant needed — no compact row).
- Body ramp (17-CONTEXT D-02): head = `accentPrimary`; body segments fade toward `surface` via opacity steps. Food = `success` (green) or `accentPrimary` fallback (17-CONTEXT resolution).
- Direction input (17-CONTEXT D-04): swipe gesture + optional D-pad overlay. Swipe locked once per tick to prevent steer reversal.
- Input haptic (17-CONTEXT D-07): valid direction = `.selection`. Rejected input (reversal) = no haptic.
- Eat choreography (17-CONTEXT D-08): food absorbed + body grows + score roll (`contentTransition(.numericText)`). Haptic: `.impact(weight: .light, intensity: 0.7)`. Gated by `feedbackAnimation` / `hapticsEnabled`.
- New high score mid-run (17-CONTEXT D-09): `.success` haptic once per run on first crossing. Not repeated.
- Death choreography (17-CONTEXT D-10): body drain animation + banner. Reduce Motion + animations-off: instant cut to banner. No screen shake (brand rule).
- Stats shape: `SnakeStatsCard` (Phase 18 D-08). Hero metric = High Score; rows = Average Score + Runs Played. No streak row.

---

## Shared Patterns

### Props-only stats card (applies to all three files)
**Source:** `Screens/StackStatsCard.swift` (entire file) and CLAUDE.md §8.2
**Apply to:** `ScoreStatsCard`, `StackStatsCard` wrapper, `SnakeStatsCard` wrapper

No `@Query`, no `@Environment`, no `@State`. All data arrives as `let` props. StatsView owns queries; cards receive pre-fetched arrays.

### Token discipline (applies to all three files)
**Source:** `Screens/StackStatsCard.swift` lines 15-16, file header comment lines 9-10
```swift
// Token discipline: zero Color(...) literals; all fonts / spacing from theme.
// No queries here — StatsView owns the existing stackRecords / stackBestScores queries.
import SwiftUI
import DesignKit
```
Never use `Color(...)` literals. All fonts from `theme.typography.*`, spacing from `theme.spacing.*`, colors from `theme.colors.*`.

### monoNumber + .monospacedDigit() pairing (grid row values)
**Source:** `Screens/StackStatsCard.swift` lines 109-110
```swift
.font(theme.typography.monoNumber)
.monospacedDigit()
```
Always apply both together for stat numerals in grid rows. The `.monospacedDigit()` modifier is redundant with the monospaced design but locked per P3 StatsView comment ("required so digits don't jitter when stats update").

### Accessibility combine pattern (metric rows)
**Source:** `Screens/StackStatsCard.swift` lines 114-115
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(Text(a11yLabel))
```
Every `GridRow` carrying a stat value gets this pairing. The a11y label string should read naturally ("High score: 1250", not "High Score 1250").

### Empty state copy (D-03)
**Source:** `Screens/StackStatsCard.swift` line 56 (old copy being replaced)
```swift
// OLD (being replaced by D-03):
Text(String(localized: "No Stack games played yet."))
// NEW (roadmap-locked copy, both games):
Text(String(localized: "No runs yet."))
```
Both `StackStatsCard` and `SnakeStatsCard` adopt "No runs yet." in this phase.

### StatsView call-site pattern (unchanged — for verification)
**Source:** `Screens/StatsView.swift` lines 221-233
```swift
if shows(.stack) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "STACK")) }
    DKCard(theme: theme) {
        StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)
    }
}
if shows(.snake) {
    if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SNAKE")) }
    DKCard(theme: theme) {
        SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)
    }
}
```
These call sites do NOT change. `ScoreStatsCard` is an implementation detail of the wrappers.

---

## No Analog Found

No files in this phase are without a close codebase match. All patterns are well-established.

---

## Verification Checklist (mechanical — no new files)

| Gate | What to check | Expected result |
|------|---------------|-----------------|
| Engine purity (D-13) | `grep -n "import SwiftUI\|import SwiftData" Games/Stack/StackEngine.swift Games/Stack/StackConfig.swift Games/Snake/SnakeEngine.swift Games/Snake/SnakeConfig.swift` | Zero hits — Foundation-only confirmed |
| File size (D-14) | `wc -l Games/Stack/*.swift Games/Snake/*.swift` | Largest: `StackBoardCanvas.swift` at 386 lines — passes §8.1/§8.5 |
| ADR call-site (D-12) | `HomeView.swift` lines 392-406 (`destination(for:)`) | Stack has `.videoModeAware`; Snake has `// NOTE: NO Video Mode modifier` comment; both match 15-VIDEO-MODE-ADR.md amended state. Already correct — no edit needed. |
| MARKETING_VERSION | `grep -m1 MARKETING_VERSION gamekit.xcodeproj/project.pbxproj` | `1.4` — release log goes to `Docs/releases/v1.4.md` |

---

## Metadata

**Analog search scope:** `gamekit/gamekit/Screens/`, `gamekit/gamekit/Games/Stack/`, `gamekit/gamekit/Games/Snake/`, `gamekit/gamekit/Games/Words/`, `gamekit/gamekit/Core/`, `DESIGN.md`, `DesignKit/Sources/DesignKit/Typography/`
**Files scanned:** 12 Swift files + DESIGN.md + TypographyTokens.swift
**Pattern extraction date:** 2026-07-05
