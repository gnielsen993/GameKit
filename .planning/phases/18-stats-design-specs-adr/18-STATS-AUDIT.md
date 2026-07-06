# Phase 18 Stats Card Legibility Audit (18-02)

**ARCADE-07 / §8.12 + D-04 — ScoreStatsCard theme + Dynamic Type verification**

**Audit date:** 2026-07-05  
**Device:** iPhone 17 Pro simulator (iOS 26.2, arm64), UDID `C4F04A59-D773-4E23-B4E7-4986DD2FEB32`  
**Component under test:** `Screens/ScoreStatsCard.swift` (Phase 18-01), consumed by `StackStatsCard.swift` and `SnakeStatsCard.swift`  
**Automated by:** throwaway `StatsAuditUITest.swift` (deleted after verification, no product code committed)  
**Status:** Screenshots captured — awaiting human judgment (Task 2)

---

## Card Shape Under Test

The redesigned arcade stats card (`ScoreStatsCard`) renders:
1. **"HIGH SCORE" caption** — `caption.weight(.semibold)` / `textSecondary`
2. **Hero High Score numeral** — `titleLarge` (fixed 32pt bold rounded) + `.monospacedDigit()` / `textPrimary`
3. **1pt border rule** — `border` color token, spans both grid columns
4. **Metric grid rows** — label in `body` / value in `monoNumber + .monospacedDigit()` / `textPrimary`
5. **Empty state** — "No runs yet." in `body` / `textTertiary` when `records.isEmpty`

Seeded scores:
- Stack: high score `1,234,567` (7 digits, D-04 target), average score `770,325`, runs `5`, best streak `42`
- Snake: high score `987,654` (6 digits), average score `635,493`, runs `4`

---

## Captures

### Capture 01 — Classic preset (classicMuted), default Dynamic Type, seeded

- **Preset:** `classicMuted` (Chrome Diner)
- **Dynamic Type:** Default (Large — system default)
- **High score in frame:** Stack `1234567`, Snake `987654`
- **Screenshot file:** `screenshots/01-classic/CC20CCBA-81CE-44CB-8BB3-F49EC5DE930E.png`
- **Observation (automated):** Both STACK and SNAKE cards visible in a single viewport; hero numeral renders on one line at both digit counts; border rule and metric rows all present; section headers legible; card background / surface / text contrast visible.
- **Dark mode note:** Simulator was in system dark mode — "classicMuted" (Chrome Diner) renders in its dark variant here. Light-mode appearance is not separately captured but shares the same token set.

### Capture 02 — Voltage preset (Loud/Moody), default Dynamic Type, seeded

- **Preset:** `voltage` (Loud category — §8.12 mandatory Loud check)
- **Dynamic Type:** Default (Large)
- **High score in frame:** Stack `1234567`, Snake `987654`
- **Screenshot file:** `screenshots/02-voltage/3449FAE1-43C3-448E-8FEC-CE8CFAF1296F.png`
- **Observation (automated):** Same layout as Capture 01; background and card surfaces show Voltage palette (cooler/purple tint vs Classic's warm dark); hero numeral, border rule, and metric rows all visible; no element disappears into the background.

### Capture 03a — Classic preset, AccessibilityXXL Dynamic Type, seeded — Stack section

- **Preset:** `classicMuted`
- **Dynamic Type:** `UICTContentSizeCategoryAccessibilityXXL` (largest non-default accessibility size)
- **High score in frame:** Stack `1234567`
- **Screenshot file:** `screenshots/03-classic-large-dt/10B626F8-CB11-4E4A-AB10-9E87DB6F9B99.png`
- **Observation (automated — D-04 overflow check):**
  - `titleLarge` is defined as `.system(size: 32, weight: .bold, design: .rounded)` — **fixed size**, not DT-responsive. The `1234567` hero numeral stays at 32pt across all DT sizes and does NOT clip, truncate, or overflow at AccessibilityXXL.
  - Metric row labels (`body` + `monoNumber`) ARE DT-responsive and wrap at AccessibilityXXL (e.g. "Average Score" → two lines, "Runs Played" → two lines). This is expected SwiftUI behavior.
  - Border rule and layout structure remain intact under the wrapped label scenario.
  - **Design observation for reviewer:** At AccessibilityXXL, the DT-responsive metric labels grow larger than the fixed-size hero numeral, which reverses the visual hierarchy intended for normal sizes. This is an inherent consequence of the fixed `titleLarge` token; no clipping occurs.

### Capture 03b — Classic preset, AccessibilityXXL Dynamic Type, seeded — Snake section partial

- **Preset:** `classicMuted`
- **Dynamic Type:** `UICTContentSizeCategoryAccessibilityXXL`
- **Screenshot file:** `screenshots/03-classic-large-dt/ED5EA014-2B92-44D9-A42A-AC6DA0FCD1FC.png`
- **Observation:** Captured at the same scroll position as 03a (Snake header just entering the viewport bottom); the SNAKE "HIGH SCORE" / "987654" card appears in the subsequent DT-rendered frame. Visual hierarchy and no-clip behavior is the same as Stack (same component).

### Capture 04 — Classic preset, empty Stack/Snake store

- **Preset:** `classicMuted`
- **Dynamic Type:** Default (Large)
- **High score in frame:** None — both Stack and Snake have zero records
- **Screenshot file:** `screenshots/04-empty/766560EC-17ED-45B3-BF70-2DFE437652D0.png`
- **Observation (automated):** Both STACK and SNAKE sections show "No runs yet." centered in `textTertiary`. Text is visible on the card surface background; no blank/white card visible. Five Letter and Word Grid sections show their own "No … games played yet." copy above, confirming the empty-state rendering pattern is consistent across game types.

---

## Automated Verification

```
$ test -f .planning/phases/18-stats-design-specs-adr/18-STATS-AUDIT.md && \
  grep -qi "voltage" .planning/phases/18-stats-design-specs-adr/18-STATS-AUDIT.md && \
  echo PASS
PASS
```

---

## Result

_(Awaiting human judgment — see Task 2 checkpoint)_

---

## How to Verify (for Task 2 human reviewer)

Open the four screenshot files above (or navigate in the app to Stats → scroll to Stack/Snake) and confirm:

1. **Classic preset (Capture 01):** Hero numeral, caption label, border rule, and metric rows all clearly legible; contrast reads as premium.
2. **Voltage preset (Capture 02):** Same elements legible on the Loud palette — hero numeral does not vanish into the background (§8.12).
3. **Large DT with 7-digit score (Capture 03a):** Hero numeral "1234567" is NOT clipped, truncated, or pushed off-card (D-04). Note: `titleLarge` is fixed at 32pt so it does not scale, which means no DT overflow is possible at any DT size.
4. **Empty store (Capture 04):** "No runs yet." shows in muted text, centered; no blank card or missing section.

Reply "approved" if all four pass, or describe the specific preset/size/element and defect if any fail.
