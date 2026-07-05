# Phase 18: Stats, Design Specs & ADR - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-05
**Phase:** 18-stats-design-specs-adr
**Areas discussed:** High-score card layout, Metric set, Shared card component, Cold-start verification
**Mode:** Advisor (research-backed comparison tables; 4 parallel gsd-advisor-researcher agents; calibration tier: minimal_decisive)

---

## High-score card layout

| Option | Description | Selected |
|--------|-------------|----------|
| Hero numeral | Uppercase caption label over a large monospaced numeral (`titleLarge` + `.monospacedDigit()`), border rule, then label\|value rows below | ✓ |
| Emphasized first row | Keep the 2-column grid, bump the High Score value's font | |

**User's choice:** Hero numeral (recommended)
**Notes:** Research confirmed DesignKit has no large mono token (`monoNumber` is body-sized) — hero uses `titleLarge` + `.monospacedDigit()`. Empty-state copy changes to roadmap-locked "No runs yet." in the same pass.

---

## Metric set

| Option | Description | Selected |
|--------|-------------|----------|
| Add Average Score | High Score + Average Score + Runs Played; Stack keeps Best Streak as 4th game-specific row | ✓ |
| Keep current metrics | High Score + Runs Played (+ Best Streak for Stack); read "average/total" as illustrative | |

**User's choice:** Add Average Score (recommended)
**Notes:** Research confirmed per-run score is already persisted on `GameRecord.score` for both games — average is pure derivation, zero schema risk. Average preferred over total (calm brand). Rounding/format left to planner.

---

## Shared card component

| Option | Description | Selected |
|--------|-------------|----------|
| Shared + thin wrappers | One `ScoreStatsCard` layout component; StackStatsCard/SnakeStatsCard become derivation-only wrappers | ✓ |
| Two siblings | Implement the hero layout independently in both files | |

**User's choice:** Shared + thin wrappers (recommended)
**Notes:** Cards are ~95% identical already; Phase 17 D-02 precedent blesses promotion when code is genuinely identical. Screens/-local — not a DesignKit promotion. StatsView call sites unchanged.

---

## Cold-start verification

| Option | Description | Selected |
|--------|-------------|----------|
| Combo + record baseline | Claude proves lazy-init structurally; user runs one Instruments App Launch session from a prepared recipe — number recorded as canonical baseline | ✓ |
| Structural proof only | Code inspection + simulator init-log audit; drop the device timing claim | |

**User's choice:** Combo + record baseline (recommended)
**Notes:** Research surfaced that no v1.4 baseline number exists in `.planning/` and Phase 15's identical Instruments item was deferred and never run (still pending in `15-HUMAN-UAT.md`). This phase's session establishes the baseline and retires that item.

---

## Claude's Discretion

- Average-score rounding/display format
- Hero-numeral Dynamic Type behavior
- Shared component exact API shape and name
- §12.6/§12.7 entry prose (content roadmap-locked by SC2; documents as-built)
- Instruments recipe wording

## Deferred Ideas

- Score trend charts / run-summary micro-screen — v2+ per FEATURES.md
- Daily seed, SFX cues, leaderboards — explicitly out of v1.5 scope
