---
phase: 12-merge-nonogram-adoption
plan: 06
subsystem: video-mode / phase-close
tags: [verification, legibility-audit, off-restore, release-log, checkpoint, video-mode, phase-close, gaps-found]
status: partial
gaps_found: true
gap_closure_plan: phase-12.1
requirements: [VIDEO-09, VIDEO-10]
requirements_addressed: [VIDEO-09, VIDEO-10]

dependency_graph:
  requires: [12-01, 12-02, 12-03, 12-04, 12-05]
  provides: [phase-12-close-doc, v1.2-release-log-phase-12-entries, 24-row-manual-check-matrix, sc-signoff-block]
  affects: [phase-13-planning, phase-12.1-gap-closure-planning]

tech_stack:
  added: []
  patterns: [manual-verification-matrix, sc-signoff-doc, append-only-release-log]

key_files:
  created:
    - .planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md
    - .planning/phases/12-merge-nonogram-adoption/12-06-SUMMARY.md
  modified:
    - Docs/releases/v1.2.md

decisions:
  - "Top-level status PARTIAL — SC2 + SC4 + SC5 PASS; SC1 + SC3 FAIL on small-zone routing"
  - "Small-zone picker (ModePill) + HeaderBar chip routing gap is a P11 carryforward; surfaces in all 3 adopter games (Mines, Merge, Nonogram); closure via Phase 12.1"
  - "Nonogram cell-size floor locked at 12pt (Plan 12-05) confirmed by Row 20 audit on Classic + Dracula + Voltage"
  - "VideoCompactControlRow.swift SHA unchanged across phase (5 wave commits) — SC5 grep-vs-git-HEAD proof"
  - "MergeBoardView.swift SHA unchanged across phase — D-MG-17 untouched contract preserved"
  - "NonogramBoardView.swift only gained the minCellSizeVideoMode floor seam in 12-05 — D-NG-17 byte-identity verified at 12-05 acceptance"
  - "22 of 24 matrix rows DEFERRED to TestFlight per P11 precedent (D-12-MATRIX)"

metrics:
  duration_minutes: ~25
  task_count: 4
  file_count: 2
  completed_date: "2026-05-13"
---

# Phase 12 Plan 06: Phase Close — Manual Verification Matrix + Release Log Summary

Phase 12 closes with PARTIAL status — Plans 12-01..12-05 landed the Merge + Nonogram adoption code correctly and the Large-zone + Off-path surfaces all PASS, but Plan 12-06's tighter small-zone audit caught a P11 carryforward defect: `VideoModeSlotRouter.anchors(for:)` returns correct `anchors.picker` values for all 6 zones, but none of the 3 adopter games (Mines, Merge, Nonogram) wire it into their Small-zone `existingLayout` branch — leaving the ModePill (bottom-center) covered on Bot L/R PiP zones and the HeaderBar chips (top-center) covered on Top L/R PiP zones.

## Tasks Completed

| Task | Name | Commit |
|------|------|--------|
| 1 | Author 12-VIDEO-MANUAL-CHECK.md scaffolding (24-row matrix) | 7a26ed9 |
| 2 | Manual worst-case audit + Off-restore spot-check (checkpoint) | (human-verify, resolved 2026-05-13 with SC1 FAIL signal) |
| 3 | Fill matrix marks + sign-off based on Task 2 results | 2fceb1c |
| 4 | Append Phase 12 entries to Docs/releases/v1.2.md | ca48330 |

## Audit Results — Per-Row Matrix

### Verified during execution (2 rows)

| # | Row | Result | Notes |
|---|-----|--------|-------|
| 2 | Merge × winMode × largeBottom × Classic + Dracula | **PASS** | Swipe gestures clean across both presets (no edge-swipe-back hijack — `.navigationBarBackButtonHidden(true)` preserved). Restart fires fresh board. Mode-change abandon-alert fires mid-game. End-state overlay appears on 2048 reach. SC1 acceptance row PASS on largeBottom worst-case squeeze. |
| 20 | Nonogram × Hard 15×15 × largeBottom × Classic + Dracula + Voltage | **PASS** | Hint digits 1–9 legible WITHOUT pinch-zoom at the 12pt floor. Fill marks + X marks distinguishable. Super-cell rules (bold 5×5 grid lines) visible across all 3 presets. Final renders match Plan 12-05 locked screenshots. |

### Deferred to TestFlight per P11 precedent (22 rows)

Per CONTEXT D-12-MATRIX line 124, non-worst-case rows inherit by geometric interpolation. Specifically deferred:

- **Merge rows 1, 3-12** (11 rows): largeTop, all 4 Small zones × 2 modes (Win + Infinite), largeBottom × infinite.
- **Nonogram rows 13-19, 21-24** (11 rows): all Tiny 5×5 rows (trivially fit at any floor), Hard 15×15 × largeTop, Hard 15×15 × all 4 Small zones.

These rows inherit from the verified rows (2 + 20). Re-audit will run in TestFlight sweep plus the gap-closure re-audit in Phase 12.1.

## SC Sign-off Summary

| SC | Description | Result | Notes |
|----|-------------|--------|-------|
| SC1 | Merge plays across 6 zones | **FAIL** | Small-zone ModePill not consuming `anchors.picker` — Bot L/R PiP covers the Win/Infinite picker. Large-zone branch (Row 2) PASS. |
| SC2 | Nonogram Hard hint legibility in Large zones | **PASS** | Plan 12-05 locked at 12pt floor; Row 20 audited on Classic + Dracula + Voltage at largeBottom × Hard 15×15. |
| SC3 | Classic + Loud × both games × 6 zones legibility | **FAIL** | Small-zone HeaderBar chips not routed; Top L/R PiP covers Score/Best (Merge), Size/Lives/Timer (Nonogram). Large-zone audit (Rows 2 + 20) PASS. |
| SC4 | Off-restore byte-identity (Merge + Nonogram) | **PASS** | VM Off → both games render v1.1/v1.0 identical: ModePill, board, toolbar, end-state overlay all present and at v1.1 sizes. NonogramBoardView reads 14pt floor when `videoModeOn: false`. |
| SC5 | Compact row consumed verbatim | **PASS** | `git diff HEAD~6 HEAD -- gamekit/gamekit/Core/VideoCompactControlRow.swift` produces zero output — shared component byte-identical across all 5 wave commits. Both games consume it with `onSettings: nil` per D-MG-01 / D-NG-01. |
| **Top-level** | Phase 12 ships | **PARTIAL** | SC2 + SC4 + SC5 PASS; SC1 + SC3 FAIL on small-zone routing. Gap closure required via Phase 12.1 before v1.2 can ship. |

## Off-restore Spot-check Detail (SC4 PASS)

**Merge off-restore (Video Mode → Off):**
- `MergeHeaderBar` visible at top (Score chip on left, Best chip on right) at v1.1 inline sizes.
- `MergeBoardView` renders 4×4 grid at v1.1 size; swipe gesture works.
- `MergeModePill` (Win / Infinite) visible below the board at v1.1 (non-compact) variant.
- Nav-bar toolbar shows: Back chevron, Restart icon, MergeToolbarMenu — all at v1.1 positions.
- End-state overlay fires correctly on Win or GameOver.

**Nonogram off-restore (Video Mode → Off):**
- `NonogramHeaderBar` visible at top (Size chip + optional Lives chip + Timer chip) at v1.1 inline sizes.
- `NonogramBoardView` renders at v1.0 14pt floor (NOT lowered Video-Mode 12pt floor) — confirmed by reading `Self.minCellSize(videoModeOn: false)` path.
- Slide-fill gestures + super-cell rules + hint digits all render at v1.0 size.
- `NonogramModePill` (Place / Mark) visible below the board at v1.1 (non-compact) variant.
- Nav-bar toolbar shows: Back + Restart + NonogramToolbarMenu (with Change-difficulty + Change-mode submenus).
- Confetti + end-state overlay fires on win.

No regressions observed. SC4 PASS — no rollback target triggered.

## Gap Description (SC1 + SC3 FAIL)

**P11 carryforward — Small-zone picker (ModePill) + HeaderBar chip routing not wired.**

`VideoModeSlotRouter.anchors(for:)` returns correct per-zone anchor positions:

```swift
// Example for .smallBottomLeft (illustrative — source of truth is the router):
SlotAnchorMap(back: .top, settings: .top, picker: .top, fab: .top)
```

…but the Small-zone branches in all 3 adopter games (Mines, Merge, Nonogram) consume only `back`, `settings`, `fab` (the toolbar items) — the `picker` anchor is never wired into the existing layout, leaving the ModePill at its default bottom-center position. The same omission applies to the HeaderBar chips on Top L/R zones (no HeaderBar reposition seam exists).

### Affected zones per game

| Game | Zone | What gets covered |
|------|------|---------|
| Mines | smallTopLeft / smallTopRight | MinesRemaining + Timer chips (HeaderBar) |
| Mines | smallBottomLeft / smallBottomRight | Reveal/Flag ModePill |
| Merge | smallTopLeft / smallTopRight | Score + Best chips (MergeHeaderBar) |
| Merge | smallBottomLeft / smallBottomRight | Win/Infinite ModePill |
| Nonogram | smallTopLeft / smallTopRight | Size/Lives + Timer chips (NonogramHeaderBar) |
| Nonogram | smallBottomLeft / smallBottomRight | Place/Mark ModePill |

### Why P11 didn't catch this

The Phase 11 manual-check matrix worst-case row (Row 14: Mines × Hard × largeBottom × Voltage) is a Large-zone row — Large zones use `compactRowComposed` (no HeaderBar, no ModePill — those collapse into the compact control row), so the Small-zone passthrough's missing picker / chip routing was never exercised.

Plan 12-06 caught it because the audit explicitly probed all 6 zones for the two new adopter games, and the same gap surfaced symmetrically — exposing it as a P11 carryforward rather than a per-game bug.

### Closure plan (Phase 12.1)

`/gsd-plan-phase 12.1 --gaps` will author Phase 12.1 to:

1. Add a Small-zone ModePill reposition seam in each game's `+VideoMode.swift` extension that reads `anchors.picker` and overlays the ModePill at that anchor (likely a top-edge overlay on Top L/R zones; a bottom-edge overlay on Bot L/R zones; existing bottom-center default if the picker anchor is unused for that zone).
2. Add a Small-zone HeaderBar chip reposition seam (most likely: hide HeaderBar on Top L/R zones, since the Mines/Merge/Nonogram HeaderBar chips are duplicate information available via the Restart submenu's mode context; OR re-anchor the HeaderBar to the bottom edge when the PiP is at the top).
3. Re-audit the 4 small-zone rows per game (Rows 3-6 + 9-12 for Merge, Rows 15-18 + 21-24 for Nonogram, plus the equivalent Mines rows from `11-VIDEO-MANUAL-CHECK.md`).

Phase 12 does NOT close until 12.1 lands.

## Untouched-Contract Proofs

| Contract | File | Proof |
|----------|------|-------|
| SC5 — VideoCompactControlRow consumed verbatim | `gamekit/gamekit/Core/VideoCompactControlRow.swift` | `git diff HEAD~6 HEAD -- gamekit/gamekit/Core/VideoCompactControlRow.swift` returns zero output across the 5 wave commits (12-01..12-05) + 12-06. |
| D-MG-17 — MergeBoardView gesture/scale stack untouched | `gamekit/gamekit/Games/Merge/MergeBoardView.swift` | `git diff HEAD~6 HEAD -- gamekit/gamekit/Games/Merge/MergeBoardView.swift` returns zero output (no MergeBoardView change in Phase 12). |
| D-NG-17 — NonogramBoardView gesture/drag-state byte-identical | `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` | Plan 12-05 verified at acceptance — `slideGesture` / `superCellRules` / hint geometry constants / drag state names byte-identical; only `minCellSizeVideoMode` constant + `minCellSize(videoModeOn:)` helper added. |

## Release Log Entries Appended (Task 4)

Per CLAUDE.md §8.14 + §0.3 + D-12-RELEASELOG, the following appended to `Docs/releases/v1.2.md`:

- **§User-facing changes** — 1 new Phase 12 bullet covering Merge + Nonogram adoption from user perspective (Large-zone compact row composition, Nonogram 12pt floor, Off-restore byte-identity, **known gap on Small-zone picker/chip coverage**).
- **§Internal changes** — 6 new Phase 12 bullets (Plans 12-01 through 12-06) with cross-references to each plan's SUMMARY file.
- **§Risks / notes** — 4 new Phase 12 bullets covering:
  1. Nonogram cell-size floor lock (12pt) + rollback condition.
  2. D-MG-17 / D-NG-17 off-path byte-identity proof.
  3. Small-zone picker + chip routing gap (the SC1 + SC3 FAIL) with closure plan pointing to Phase 12.1.
  4. MARKETING_VERSION still at 1.1 (bump deferred per CONTEXT line 141).

Existing P9 + P10 + P11 entries preserved (no overwrites — append-only edit).

## Cross-references

- `.planning/phases/12-merge-nonogram-adoption/12-01-SUMMARY.md` — Merge chip extraction + TimerChip MOVE
- `.planning/phases/12-merge-nonogram-adoption/12-02-SUMMARY.md` — Merge wrap + three-way branch + compactRowComposed
- `.planning/phases/12-merge-nonogram-adoption/12-03-SUMMARY.md` — Nonogram chip extraction
- `.planning/phases/12-merge-nonogram-adoption/12-04-SUMMARY.md` — Nonogram wrap + three-way branch + compactRowComposed
- `.planning/phases/12-merge-nonogram-adoption/12-05-SUMMARY.md` — Nonogram cell-size floor lock at 12pt
- `.planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md` — filled matrix + SC sign-off + gap description

## Phase Status

**Phase 12 closes with `gaps_found: true`.** Phase 12.1 planned via `/gsd-plan-phase 12.1 --gaps` to close SC1 + SC3 small-zone routing gap. v1.2 cannot ship until 12.1 closes; Phase 13 (Win/Loss Banner + A11y Gating) can begin planning in parallel since the gap is layout-routing-only and doesn't affect 13's compositional surface.

## Deferred Items

| Item | Rationale | Closure |
|------|-----------|---------|
| 22 of 24 matrix rows | P11 precedent (D-12-MATRIX line 124) — non-worst-case rows inherit | TestFlight sweep + Phase 12.1 re-audit |
| Small-zone ModePill routing (3 games × 4 zones) | P11 carryforward defect surfaced 2026-05-13 | Phase 12.1 — `/gsd-plan-phase 12.1 --gaps` |
| Small-zone HeaderBar chip routing (3 games × 2 top zones) | Same as above | Phase 12.1 |
| MARKETING_VERSION bump 1.1→1.2 | Deferred to Phase 13 ship plan per CONTEXT line 141 | Phase 13 |

## Self-Check: PASSED

- File `.planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md` exists.
- File `Docs/releases/v1.2.md` modified — Phase 12 entries appended.
- Commits exist:
  - `7a26ed9` (Task 1 — matrix scaffold)
  - `2fceb1c` (Task 3 — matrix fill + sign-off)
  - `ca48330` (Task 4 — release log append)
- `git diff HEAD~6 HEAD -- gamekit/gamekit/Core/VideoCompactControlRow.swift` returns zero — SC5 proof holds.
- `git diff HEAD~6 HEAD -- gamekit/gamekit/Games/Merge/MergeBoardView.swift` returns zero — D-MG-17 proof holds.
- YAML frontmatter in 12-VIDEO-MANUAL-CHECK.md: `status: partial`, `signed_off_by: gabrielnielsen`, `signed_off_at: 2026-05-13`, `gaps: [SC1-small-zone-picker-routing, SC3-small-zone-headerbar-chip-routing]`.
