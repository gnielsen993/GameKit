---
phase: 18-stats-design-specs-adr
verified: 2026-07-06T00:00:00Z
status: passed
score: 16/17 must-haves verified (1 accepted via override)
overrides_applied: 1
gaps:
  - truth: "A real-device Instruments App Launch session records the canonical cold-start baseline number — no prior v1.4 baseline exists to compare against (D-10)"
    status: accepted
    reason: "18-COLD-START-BASELINE.md explicitly states 'This baseline was NOT obtained from a formal Instruments App Launch session.' The user provided a subjective self-estimate (~200 ms) at the human-verify checkpoint instead of running Instruments. No device model or iOS version was captured. This was a user-directed scope adjustment — not auto-advanced — and is honestly documented. The structural proof (zero arcade allocation at launch) is the load-bearing SC4 evidence and is fully verified. The failure is the Instruments-trace component of the must-have, not the underlying allocation guarantee. Accepted via override below."
    artifacts:
      - path: ".planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md"
        issue: "Canonical Baseline section method = 'Developer subjective self-estimate'; device and iOS version not captured; no Instruments trace run"
    missing:
      - "A real-device Instruments App Launch session (3-5 runs, median ms, device model, iOS version) — OR an explicit developer override accepting the structural proof + subjective estimate as sufficient closure for SC4"
overrides:
  - must_have: "A real-device Instruments App Launch session records the canonical cold-start baseline number — no prior v1.4 baseline exists to compare against (D-10)"
    reason: "Structural proof (navigationDestination lazy-construction + App/ grep zero hits) is conclusive for the allocation claim. Timing half closed via developer subjective estimate (~200 ms), honestly labeled in 18-COLD-START-BASELINE.md. No prior v1.4 numeric baseline existed to compare against regardless. User explicitly directed this approach at the Plan 04 human-verify checkpoint. A future real-device Instruments trace may supersede this baseline if a hard numeric anchor is later needed."
    accepted_by: "gabriel"
    accepted_at: "2026-07-06T00:00:00Z"
---

# Phase 18: Stats, Design Specs & ADR — Verification Report

**Phase Goal:** Score-based stats screen shape for endless arcade games (High Score hero + runs played + average, distinct from win/loss columns, with empty state); DESIGN.md §12 game-specific entries for Stack and Snake (Reduce Motion jump-cut spec, haptic vocabulary, per-element token map); Video Mode exemption ADR call-site fidelity; cold-start regression check (structural allocation proof + recorded baseline); engine purity sign-off; file-size gate.

**Verified:** 2026-07-06

**Status:** passed (16/17 verified; 1 must-have accepted via developer override — see frontmatter `overrides`)

**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Stack and Snake stats cards show High Score as a large hero numeral (titleLarge + monospacedDigit) above smaller metric rows | VERIFIED | `ScoreStatsCard.swift` line 87: `theme.typography.titleLarge` + `.monospacedDigit()`; hero VStack spans both grid columns |
| 2  | Average Score (derived, no schema change) and Runs Played appear as grid rows under the hero numeral | VERIFIED | `StackStatsCard.swift` lines 36-39: `compactMap { $0.score }.filter { $0 > 0 }` derivation; `SnakeStatsCard.swift` same pattern |
| 3  | Stack card shows a Best Streak row; Snake card does not | VERIFIED | `StackStatsCard.swift` lines 46-51 + third ScoreMetric. `SnakeStatsCard.swift` has no Best Streak metric; comment references "D-07 — Stack-only" |
| 4  | When no runs are recorded the card shows "No runs yet." | VERIFIED | Both wrappers pass `emptyStateCopy: String(localized: "No runs yet.")` and `isEmpty: records.isEmpty` to `ScoreStatsCard` |
| 5  | StatsView call sites unchanged; both are thin wrappers over shared ScoreStatsCard | VERIFIED | `StatsView.swift` lines 224, 231: unchanged 3-prop signatures. Both wrapper bodies call `ScoreStatsCard(` as their entire body |
| 6  | String catalog lists "No runs yet." and "HIGH SCORE"; old "No Stack/Snake games played yet." keys absent | VERIFIED | Python JSON check: both new keys PRESENT; both old keys ABSENT; catalog is valid JSON |
| 7  | Hero High Score numeral is legible on Classic and on a Loud preset (§8.12 pass) | VERIFIED | `18-STATS-AUDIT.md` Result table: Capture 01 (classicMuted) PASS, Capture 02 (voltage) PASS; reviewer instruction referenced in 18-02-SUMMARY confirming human involvement |
| 8  | 6-7 digit scores do not clip or truncate at large Dynamic Type (D-04) | VERIFIED | `ScoreStatsCard.swift` lines 125-126: `.lineLimit(1)` + `.minimumScaleFactor(0.7)` on metric value Text; STATS-AUDIT fix commit 8b805aa confirmed; re-capture 03c-fixed-axxxl-stack.png on disk |
| 9  | "No runs yet." empty state is legible on both preset families | VERIFIED | `18-STATS-AUDIT.md` Capture 04 (classicMuted empty store): PASS recorded |
| 10 | DESIGN.md §12 has a §12.6 Stack entry and a §12.7 Snake entry | VERIFIED | DESIGN.md line 656: `### 12.6 Stack`; line 680: `### 12.7 Snake`; both appear after §12.4 Sudoku (line 644) and before §12.5 Future games (line 701) — correct ordering |
| 11 | Each §12 entry documents Reduce Motion jump-cut spec, haptic vocabulary, and per-element token map | VERIFIED | §12.6: "Reduce Motion: pulse → instant fill; … instant cut to danger banner" + "Haptic vocabulary: land = `.impact(.light)` … `.error`" + "board background = background token … danger token"; §12.7: "Reduce Motion: death drain + eat cut instantly" + "Haptic vocabulary: valid direction = `.selection` … `.error`" + "head = `accentPrimary` … food = `success` … background token". Both cite decision codes (16-CONTEXT, 17-CONTEXT, 15-VIDEO-MODE-ADR) |
| 12 | Video Mode ADR call-site in HomeView matches the amended ADR state; ADR itself not rewritten | VERIFIED | `HomeView.swift` lines 392-405: Stack case has `.videoModeAware(minBoardHeight: 480)`; Snake case has no such modifier + explicit exempt comment "NO Video Mode modifier — Snake exempt per 15-VIDEO-MODE-ADR.md". Comment block at lines 392-395 explains the 2026-07-02 amendment rationale. `15-VIDEO-MODE-ADR.md` has Amendment section confirming Stack adoption |
| 13 | Stack and Snake engine/config files import neither SwiftUI nor SwiftData | VERIFIED | `grep -nE 'import (SwiftUI|SwiftData)'` across StackEngine.swift, StackConfig.swift, SnakeEngine.swift, SnakeConfig.swift: ZERO HITS |
| 14 | All Games/Stack and Games/Snake Swift files are ≤400 lines | VERIFIED | Max: StackBoardCanvas.swift at 386 lines. Full listing (wc -l): 386 / 331 / 265 / 244 / 214 / 211 / 198 / 193 / 165 / 150 / 104 / 89 / 52 / 51 — all within cap |
| 15 | No arcade substrate or engine state is allocated at app launch — all game views instantiate lazily via HomeView navigation | VERIFIED | `HomeView.swift` line 102: `.navigationDestination(for: GameRoute.self)` closure; StackGameView() and SnakeGameView() constructed only inside that closure. `grep` of App/ (GameKitApp.swift, AppInfo.swift, DummyDataSeeder.swift) for StackEngine/SnakeEngine/StackGameView/SnakeGameView: ZERO HITS. Structural guarantee — no measurement required. (Debug init-log marked optional in plan action and skipped; structural inspection conclusive.) |
| 16 | A real-device Instruments App Launch session records the canonical cold-start baseline number | FAILED | `18-COLD-START-BASELINE.md` Canonical Baseline section explicitly states: "This baseline was NOT obtained from a formal Instruments App Launch session." Method = "Developer subjective self-estimate (~200 ms)". No device model or iOS version captured. User provided this at the human-verify checkpoint (not auto-advanced). |
| 17 | The pending Phase 15 Instruments UAT item is retired | VERIFIED | `15-HUMAN-UAT.md` frontmatter `status: retired`; SC5 item shows `result: retired — 2026-07-06 via Phase 18 Plan 04`; retirement note documents two-part closure and honestly states "No formal Instruments session was performed this phase" |

**Score:** 16/17 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `gamekit/gamekit/Screens/ScoreStatsCard.swift` | Shared score-based stats layout (hero + border rule + metric grid + empty state) | VERIFIED | 132 lines; `struct ScoreStatsCard: View` + `struct ScoreMetric`; props-only; no SwiftData; no hard-coded colors; `.foregroundStyle` throughout |
| `gamekit/gamekit/Screens/StackStatsCard.swift` | Stack thin wrapper delegating to ScoreStatsCard | VERIFIED | 80 lines; body is a single `ScoreStatsCard(` call; derives highScoreText, averageScoreText, runsPlayed, bestStreakText from props; no SwiftData |
| `gamekit/gamekit/Screens/SnakeStatsCard.swift` | Snake thin wrapper delegating to ScoreStatsCard | VERIFIED | 70 lines; body is a single `ScoreStatsCard(` call; uses `"endless"` literal for high score; no Best Streak row; no SwiftData |
| `gamekit/gamekit/Resources/Localizable.xcstrings` | New arcade keys present; orphaned old keys pruned; valid JSON | VERIFIED | "No runs yet.", "HIGH SCORE", "Average Score", "Runs Played", "Best Streak" all present; "No Stack games played yet." and "No Snake games played yet." both absent |
| `Docs/releases/v1.4.md` | Release log entry for arcade stats redesign | VERIFIED | Line 27: bullet describing High Score hero numeral, Average Score, Runs Played, Best Streak (Stack), "No runs yet." empty state, and the score-based vs. win/loss distinction |
| `DESIGN.md` | §12.6 Stack and §12.7 Snake entries | VERIFIED | Both present and correctly ordered after §12.4 Sudoku and before §12.5 Future games checklist |
| `.planning/phases/18-stats-design-specs-adr/18-STATS-AUDIT.md` | §8.12 + D-04 audit with Result section | VERIFIED | Four captures indexed (01 Classic, 02 Voltage, 03a-c AXXXL, 04 empty store); Result table shows PASS for Classic and Voltage; D-04 fix documented; screenshot files confirmed on disk |
| `.planning/phases/18-stats-design-specs-adr/18-COLD-START-BASELINE.md` | Structural proof + canonical baseline | VERIFIED (partial) | Structural proof section: complete and conclusive. Canonical Baseline section: exists but records a subjective estimate (see gap #16), not a formal Instruments trace |
| `.planning/phases/15-arcade-substrate-skeleton/15-HUMAN-UAT.md` | SC5 Instruments item retired | VERIFIED | `status: retired`; honest two-part retirement note; no false Instruments claim made |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `StackStatsCard.swift` | `ScoreStatsCard.swift` | `ScoreStatsCard(` in body | WIRED | Line 56: `ScoreStatsCard(theme: theme, heroValue: highScoreText, ...)` |
| `SnakeStatsCard.swift` | `ScoreStatsCard.swift` | `ScoreStatsCard(` in body | WIRED | Line 51: `ScoreStatsCard(theme: theme, heroValue: highScoreText, ...)` |
| `StackStatsCard.swift` | `GameRecord.score` | `compactMap { $0.score }` | WIRED | Line 36: `records.compactMap { $0.score }.filter { $0 > 0 }` |
| `SnakeStatsCard.swift` | `"endless"` literal | high-score BestScore row key | WIRED | Line 32: `$0.difficultyRaw == "endless"` — matches 17-CONTEXT D-12 write path |
| `StatsView.swift` | `StackStatsCard`, `SnakeStatsCard` | 3-prop call sites | WIRED | Lines 224, 231: `StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)` and `SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)` — unchanged |
| `HomeView.destination(for:)` | `StackGameView` + `.videoModeAware(minBoardHeight: 480)` | `.stack` case | WIRED | Line 397-398: Stack case confirmed |
| `HomeView.destination(for:)` | `SnakeGameView` (no `.videoModeAware`) | `.snake` case | WIRED | Lines 400-405: Snake case exempt; no modifier present |
| `18-COLD-START-BASELINE.md` | `15-HUMAN-UAT.md` | retirement pointer | WIRED | 15-HUMAN-UAT.md references `18-COLD-START-BASELINE.md` in the retirement note |

---

### Data-Flow Trace (Level 4)

`ScoreStatsCard` is props-only — it renders `heroValue: String`, `metrics: [ScoreMetric]`, `emptyStateCopy: String`, and `isEmpty: Bool` passed by the wrappers. No internal data fetching. `StackStatsCard` and `SnakeStatsCard` receive pre-queried `[GameRecord]` and `[BestScore]` arrays from `StatsView`, which owns the SwiftData queries. The data path is: SwiftData (StatsView) → derived Strings in wrappers → `ScoreStatsCard` renders. No hollowed props or hardcoded empty arrays at call sites.

---

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| ScoreStatsCard uses `.foregroundStyle` not `.foregroundColor` | `grep -n foregroundColor ScoreStatsCard.swift StackStatsCard.swift SnakeStatsCard.swift` | No output | PASS |
| No hard-coded `Color(` literals in stats card files | `grep -n "Color(" ScoreStatsCard.swift StackStatsCard.swift SnakeStatsCard.swift` | No output | PASS |
| No `import SwiftData` in stats card files | `grep -n "import SwiftData"` across all three | No output | PASS |
| Engine purity — zero SwiftUI/SwiftData in engine+config files | `grep -nE 'import (SwiftUI|SwiftData)'` across four files | No output (exit 1) | PASS |
| File-size gate — max ≤400 lines | `wc -l Games/Stack/*.swift Games/Snake/*.swift` | Max: 386 (StackBoardCanvas.swift) | PASS |
| App/ scope clean of arcade references | `grep -nE 'StackEngine|SnakeEngine|StackGameView|SnakeGameView' App/*.swift` | No output | PASS |
| String catalog valid JSON | `python3 -c "import json; json.load(open('Localizable.xcstrings'))"` | No exception | PASS |
| `.lineLimit(1)` + `.minimumScaleFactor(0.7)` fix in ScoreStatsCard | `grep -n "lineLimit\|minimumScaleFactor" ScoreStatsCard.swift` | Lines 125-126 | PASS |
| DESIGN.md §12.6 before §12.5 (ordering) | `grep -n "### 12\." DESIGN.md` | 12.6 at 656, 12.7 at 680, 12.5 at 701 — correct | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ARCADE-07 | 18-01, 18-02 | Stats screen presents score-based shape for endless games (High Score, Runs Played, average/total), explicit empty state | SATISFIED | ScoreStatsCard + wrappers verified; §8.12 audit PASS; string catalog synced |
| ARCADE-08 | 18-03, 18-04 | Stack and Snake Video Mode exemption ADR; amended: Stack adopted 2026-07-02; Snake remains exempt | SATISFIED | ADR call-site matches amended state; 15-VIDEO-MODE-ADR.md Amendment section present; DESIGN.md §12.7 documents exemption; engine purity confirmed; file-size gate confirmed |

No orphaned requirements for Phase 18 in REQUIREMENTS.md — ARCADE-07 and ARCADE-08 are the only phase 18 entries (traceability table rows 376-377).

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `18-STATS-AUDIT.md` | 9 | Header status line reads "awaiting human judgment (Task 2)" — not updated after Task 2 Result section was filled in | Info | Cosmetic only. The Result section at the bottom is authoritative (PASS after fix). 18-02-SUMMARY references "reviewer instruction" confirming human review occurred. No product code impact. |
| ROADMAP.md | SC3 wording (~line 540) | SC3 says "confirming Stack and Snake are exempt from `.videoModeAware()`" — outdated since Stack adopted Video Mode (2026-07-02 amendment) | Info | REQUIREMENTS.md line 166 and 15-VIDEO-MODE-ADR.md Amendment correctly reflect the current state. Code is correct. ROADMAP wording not updated after the amendment. Not a code gap. |

No `TBD`, `FIXME`, or `XXX` markers found in any file modified by this phase.

---

### Human Verification Required

None. All Phase 18 human-verify checkpoints (Plan 02 Task 2 §8.12 audit; Plan 04 Task 2 cold-start baseline) were completed during execution. The §8.12 audit checkpoint produced a human-approved result (Result section present; reviewer instruction documented in 18-02-SUMMARY). The cold-start checkpoint produced a user-directed scope adjustment (subjective estimate accepted in place of Instruments trace), which is the one gap flagged.

---

### Gaps Summary

**One gap identified: Instruments cold-start baseline not obtained.**

The ROADMAP SC4 requires "Instruments App Launch confirms no substrate or engine state is allocated at app launch" and the Plan 04 must_have requires "A real-device Instruments App Launch session records the canonical cold-start baseline number." Neither was satisfied — no formal Instruments trace was run.

**What exists instead:**
- `18-COLD-START-BASELINE.md` Structural Proof section: conclusive — `App/` grep returns zero arcade references; `HomeView.navigationDestination` lazy-construction guarantee is structural, not runtime. This is the primary SC4 evidence.
- `18-COLD-START-BASELINE.md` Canonical Baseline section: developer subjective self-estimate of ~200 ms. Honestly labeled as "NOT an Instruments trace." No device or iOS version captured.

**Root cause:** The user directed at the Plan 04 human-verify checkpoint to accept the subjective estimate rather than run a formal Instruments session ("honesty-over-theater" framing in resume instructions). The SUMMARY documents this as a user-directed scope adjustment.

**Structural proof is load-bearing.** The allocation claim (no arcade state at cold launch) is closed by the structural inspection and has stronger guarantees than a measurement. The gap is specifically the Instruments timing trace, not the allocation guarantee.

---

**Override suggestion — if developer accepts this closure:**

The structural proof provides equivalent or stronger evidence for the allocation half of SC4. If the developer accepts the subjective ~200 ms estimate as sufficient corroborating evidence for the timing half, add the following to this file's frontmatter to suppress the gap in subsequent re-verifications:

```yaml
overrides:
  - must_have: "A real-device Instruments App Launch session records the canonical cold-start baseline number — no prior v1.4 baseline exists to compare against (D-10)"
    reason: "Structural proof (navigationDestination lazy-construction + App/ grep zero hits) is conclusive for the allocation claim. Timing half closed via developer subjective estimate (~200 ms), honestly labeled in 18-COLD-START-BASELINE.md. No prior v1.4 numeric baseline existed to compare against regardless. User explicitly directed this approach at the Plan 04 human-verify checkpoint."
    accepted_by: "gabriel"
    accepted_at: "2026-07-06T00:00:00Z"
```

---

_Verified: 2026-07-06_
_Verifier: Claude (gsd-verifier)_
