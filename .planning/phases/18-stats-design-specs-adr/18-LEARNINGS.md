---
phase: 18
phase_name: "stats-design-specs-adr"
project: "GameKit"
generated: "2026-07-06"
counts:
  decisions: 6
  lessons: 6
  patterns: 6
  surprises: 3
missing_artifacts:
  - "UAT.md"
---

# Phase 18 Learnings: stats-design-specs-adr

## Decisions

### Extract shared ScoreStatsCard; shrink game cards to derivation-only wrappers (D-08)
The score-based stats layout (HIGH SCORE hero numeral + metric grid + empty state) was extracted into one props-only `ScoreStatsCard`. `StackStatsCard` and `SnakeStatsCard` became thin wrappers whose entire body is a single `ScoreStatsCard(...)` call plus local derivation of average score.

**Rationale:** The arcade cards must read as a deliberately different shape class from the turn-based win/loss/best-time cards while staying inside one component, so future arcade games inherit the shape for free. Keeps fetch logic in `StatsView` (§8.2 data-driven views).
**Source:** 18-01-SUMMARY.md

### Structural cold-start proof is load-bearing; timing is only corroborating (SC4)
The allocation half of SC4 was closed by SwiftUI's structural `navigationDestination` lazy-construction guarantee plus a zero-hit grep of `App/`-scope files, not by a runtime measurement.

**Rationale:** A structural guarantee ("no arcade/engine state is constructible at launch scope") is stronger and more durable than a single timing sample. The ~200 ms figure only confirms the guarantee feels fast.
**Source:** 18-04-SUMMARY.md

### Honesty-over-theater cold-start baseline (D-09/D-10)
The recorded baseline is a developer subjective self-estimate (~200 ms), explicitly labeled as NOT an Instruments trace, with no device/iOS/run-count fabricated. Phase 15's SC5 Instruments UAT item was retired with a note stating the actual closure mechanism.

**Rationale:** No prior v1.4 numeric baseline existed to compare against, so recording an honest absolute (even if subjective) beats manufacturing false precision or claiming a session that never happened.
**Source:** 18-04-SUMMARY.md

### Hero numeral stays fixed-size; inverted hierarchy at AXXXL accepted as observation
`titleLarge` (fixed 32pt) was left unchanged for the HIGH SCORE numeral even though, at AccessibilityXXL, body-font metric labels grow larger than the hero numeral.

**Rationale:** Reviewer explicitly chose to treat the inversion as an observation, not a defect — only the mid-number value wrap was a real bug worth fixing.
**Source:** 18-02-SUMMARY.md

### Video Mode: Stack adopts, Snake stays exempt (ARCADE-08 ADR amendment)
The as-built DESIGN.md §12 entries and the HomeView call-sites reflect the 2026-07-02 ADR amendment: Stack carries `.videoModeAware(minBoardHeight: 480)` (normalized-coordinate engine makes reflow safe); Snake has no modifier and an exempt comment.

**Rationale:** ARCADE-08's original "both exempt" framing was superseded once Stack's engine proved reflow-safe. The gate verifies code matches the amended ADR, not the original.
**Source:** 18-03-SUMMARY.md, REQUIREMENTS.md

### Formal verification override for the user-directed cold-start deviation
Rather than leaving Phase 18 in `gaps_found` over the missing Instruments trace, an `overrides` block (`accepted_by: gabriel`) was added to 18-VERIFICATION.md, flipping status to `passed` with the deviation documented.

**Rationale:** The gap was a user-directed scope choice already made at the checkpoint, and the structural proof is conclusive for the allocation claim. Re-litigating it would block a complete phase indefinitely.
**Source:** 18-VERIFICATION.md

---

## Lessons

### Header comments containing token-like patterns trip automated grep gates
Comments such as "zero `Color(...)` literals" and "Snake has no Best Streak row" caused false-positive failures in the plan's `! grep -nE "Color\("` and `! grep -q "Best Streak"` verification checks.

**Context:** Reword self-referential comments so they don't echo the exact string a negative grep gate is hunting for (e.g. "zero hard-coded color literals", "omits the perfect-streak metric").
**Source:** 18-01-SUMMARY.md

### macOS BSD grep treats `{` as ambiguous — use `grep -F` for literal braces
The plan's combined verification script used `grep -q "compactMap { \$0.score }"` which fails on macOS BSD grep. All individual checks passed; only the script was broken.

**Context:** When a verification pattern contains `{`/`}` or other BRE-ambiguous characters, use fixed-string mode (`grep -F`) or run checks individually.
**Source:** 18-01-SUMMARY.md

### `String(localized:)` needs `LocalizationValue`, not a plain `String`
The PATTERNS.md snippet `Text(String(localized: emptyStateCopy))` would not compile because `emptyStateCopy` is a `String`. The wrappers already pass a pre-localized string, so `Text(emptyStateCopy)` (verbatim init) is correct.

**Context:** Don't feed an already-resolved `String` into `String(localized:)`. Localize at the call site that owns the key, pass the resolved string down to props-only views.
**Source:** 18-01-SUMMARY.md

### Fixed-size numerals still wrap mid-number at large Dynamic Type unless constrained
Even though the hero numeral was fixed-size, the Average Score *value* (`770325`) split as `77032` / `5` across two lines at AccessibilityXXL, misreading as two numbers.

**Context:** Any numeric value in a constrained (e.g. trailing Grid) column needs `.lineLimit(1)` + `.minimumScaleFactor(...)` so it scales down rather than wrapping. Labels (words) may wrap normally.
**Source:** 18-02-SUMMARY.md

### Roadmap success-criteria can name paths that don't exist as-built
SC5's engine-purity gate named `Games/*/Engine` subdirectories; Stack and Snake actually ship flat files in `Games/Stack/` and `Games/Snake/`. The grep was adapted to real paths.

**Context:** Verification gates written during planning may reference a speculative structure. Confirm the path exists before trusting a gate's literal wording; adapt to the as-built tree.
**Source:** 18-03-SUMMARY.md

### An unprotected persistence key duplicated across files silently degrades on drift
Snake's `"endless"` high-score key appeared as a raw literal in six sites (view model ×3, seeder ×2, stats card, tests). If the write path changed, reads would silently return the empty fallback with no compiler warning.

**Context:** Persistence/mode keys shared across read and write paths belong in a single named constant (mirror the existing `GameStats.stackEndlessMode` with `snakeEndlessMode`). Surfaced by code review WR-02.
**Source:** 18-REVIEW.md, 18-REVIEW-FIX.md

---

## Patterns

### Shared props-only card + thin derivation wrappers
A reusable card takes fully-resolved props (`highScore`, `metrics`, `isEmpty`, `emptyStateCopy`); per-game wrappers own only the SwiftData-array-to-props derivation. No `modelContext` in the shared component.

**When to use:** Any time 2+ screens render the same visual shape from different data sources — keeps the fetch in one parent and makes previews trivial (§8.2).
**Source:** 18-01-SUMMARY.md

### Divide-by-zero guard for derived averages
Average Score is computed as `records.compactMap { $0.score }.filter { $0 > 0 }` then `guard !scores.isEmpty` before dividing (threat T-18-03).

**When to use:** Any derived aggregate (average, rate, ratio) computed from a possibly-empty or all-zero collection — guard before the division, return the empty-state display instead.
**Source:** 18-01-SUMMARY.md

### `lineLimit(1)` + `minimumScaleFactor` for numerics in constrained columns
Numeric values that must stay atomic get `.lineLimit(1)` + `.minimumScaleFactor(0.7)` so they shrink-to-fit instead of wrapping across lines at large Dynamic Type.

**When to use:** Multi-digit values (scores, counts, times) placed in a fixed/trailing column where wrapping would misread as multiple values.
**Source:** 18-02-SUMMARY.md

### Named-constant mirror for parallel persistence keys
When two games share a persistence pattern, define parallel named constants (`GameStats.stackEndlessMode`, `GameStats.snakeEndlessMode`) and reference them from every read/write/test site rather than repeating a literal.

**When to use:** Any string key that crosses a read/write boundary or appears in 2+ files, especially inside a `#Predicate` (capture via a local `let` for macro-friendliness).
**Source:** 18-REVIEW-FIX.md

### Structural allocation proof as cold-start evidence
Prove "nothing expensive is constructed at launch" structurally: grep the launch-scope files for zero references to the subsystem, and rely on `navigationDestination`'s lazy closure construction so per-screen views are only built on navigation.

**When to use:** Cold-start / lazy-init regression checks where a structural guarantee is available — it's more durable than a single timing sample and doesn't need a device.
**Source:** 18-04-SUMMARY.md, 18-COLD-START-BASELINE.md

### Verification override block for user-accepted deviations
When a must-have fails only because the developer deliberately chose a different (honestly-documented) closure, record an `overrides:` frontmatter entry (`must_have`, `reason`, `accepted_by`, `accepted_at`) and set status to `passed` rather than looping on a decided question.

**When to use:** A single gap that is a user-directed scope choice with load-bearing alternative evidence — not for genuine missing work.
**Source:** 18-VERIFICATION.md

---

## Surprises

### The §8.12 theme audit caught a real bug, not just a legibility nit
The mandatory theme/Dynamic-Type audit surfaced the AccessibilityXXL mid-number value wrap — a genuine correctness/readability defect — rather than only confirming token legibility across presets.

**Impact:** Turned a "verify and sign off" checkpoint into a fix + re-capture cycle (`8b805aa`); reinforces that the audit is a real gate, not a formality.
**Source:** 18-02-SUMMARY.md

### The simulator silently shut down twice mid-capture
CoreSimulator shut the sim down without warning during the re-capture run, requiring re-boot and re-setting Dynamic Type + theme between runs. The seeded SwiftData store survived the reboots.

**Impact:** Added friction to visual verification; already documented in memory `reference_sim_visual_verification.md` §6 as expected flakiness to plan around.
**Source:** 18-02-SUMMARY.md

### No v1.4 cold-start baseline existed anywhere
The phase set out to confirm cold-start was "unchanged from the v1.4 baseline," but no numeric baseline was ever recorded in `.planning/`, so there was nothing to compare against.

**Impact:** Forced a reframing (D-10) from "compare against baseline" to "record the first canonical baseline honestly" — and ultimately to the subjective-estimate + structural-proof closure.
**Source:** 18-04-SUMMARY.md
