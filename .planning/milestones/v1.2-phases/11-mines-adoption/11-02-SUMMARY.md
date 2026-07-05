---
phase: 11-mines-adoption
plan: 02
subsystem: docs
tags: [docs, supersession, video-mode, slot-order]

# Dependency graph
requires:
  - phase: 08-video-mode-design
    provides: VIDEO-MODE-LAYOUTS.md + 08-COMPACT-ROW-TOKENS.md (the Phase-8 source docs whose Mines slot rows are revised here)
  - phase: 11-mines-adoption
    provides: 11-CONTEXT.md D-05 (the new Mines slot order being landed)
provides:
  - VIDEO-MODE-LAYOUTS.md §Minesweeper Easy/Medium/Hard rows reflect D-05
  - 08-COMPACT-ROW-TOKENS.md §Minesweeper entry + §Consumed-by reference reflect D-05
  - Single source of truth for the Mines compact-row slot order across all design + plan docs
affects: [11-04, 11-05, 11-07]

# Tech tracking
tech-stack:
  added: []  # zero net-new dependencies — doc-only edit
  patterns:
    - "Dated supersession note + backlink to source decision ID (11-CONTEXT D-05) co-located with the superseded text"

key-files:
  created: []
  modified:
    - .planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md
    - .planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md

key-decisions:
  - "Easy-section supersession note covers Easy / Medium / Hard transitively: Medium and Hard tables already used 'same slot order' / 'full slot order' / 'Compromise order steps 4–5' backreferences to the Easy verbatim string, so updating Easy + adding the note at the top of the Minesweeper Easy section propagates the change without re-printing the slot string four more times."
  - "Token Anchors table in 08-COMPACT-ROW-TOKENS.md left untouched per plan acceptance criterion — those tokens are Phase 9 D-13 locks and apply unchanged to the revised slot order."

patterns-established:
  - "Doc-side supersession pattern for design-doc → implementation-doc drift: a dated note ('Supersedes YYYY-MM-DD' / 'Slot-row supersession YYYY-MM-DD'), the source decision ID (e.g. D-05), and a path-backlink to the canonical source live inline at the superseded location. Future verifiers grep on the decision ID to confirm propagation."

requirements-completed: [VIDEO-07]

# Metrics
duration: 3min
completed: 2026-05-13
---

# Phase 11 Plan 02: Phase-8 Doc Supersession Summary

**Updated VIDEO-MODE-LAYOUTS.md and 08-COMPACT-ROW-TOKENS.md so the Minesweeper compact-row slot string everywhere reads `Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart` per 11-CONTEXT D-05; supersession notes + backlinks added at both sites; Merge + Nonogram slot strings preserved verbatim; Token Anchors table untouched.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-13T23:25:25Z
- **Completed:** 2026-05-13T23:28:04Z (approx)
- **Tasks:** 2
- **Files modified:** 2 (0 created, 2 doc-only edits)

## Accomplishments

- `VIDEO-MODE-LAYOUTS.md` — inserted a dated supersession blockquote immediately under the `## Minesweeper — Easy (9x9 / 10 mines)` heading; replaced the verbatim Mines Large-top slot string in the Easy zone table. Medium / Hard tables use shortened "same slot order" / "full slot order" / "Compromise order steps 4–5" backreferences that inherit the change transitively.
- `08-COMPACT-ROW-TOKENS.md` — inserted a dated supersession blockquote under §Per-Game Slot Mapping §Minesweeper; replaced the slot string on the line below it; updated the §Consumed-by Phase 11 reference to cite the revised slot order + backlink. Token Anchors table at lines 14-23 left untouched.
- Both files committed atomically in separate commits per CLAUDE.md §8.10 / task_commit_protocol.

## Task Commits

Each task was committed atomically:

1. **Task 1: Update VIDEO-MODE-LAYOUTS.md Minesweeper slot-order rows** — `ae75d60` (docs)
2. **Task 2: Update 08-COMPACT-ROW-TOKENS.md Minesweeper §Per-Game Slot Mapping** — `55b7eb8` (docs)

## Files Modified

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md` — MODIFIED. Net +3 / −1 line.
  - **Line 77 (new):** Supersession blockquote inserted under the `## Minesweeper — Easy (9x9 / 10 mines)` heading. Spans one logical line (markdown blockquote). Contains the new slot string verbatim + 11-CONTEXT D-05 backlink + rationale (Restart rightmost, slot 2 stacked subview, Settings = MinesweeperToolbarMenu).
  - **Line 98 (was line 96 before insertion):** Mines Easy Large-top zone-table row slot string updated. Old: `Back | Flags/mines | Reveal/Flag picker | Time | Settings`. New: `Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart`. Also adds an inline "(revised per `11-CONTEXT.md` D-05)" callout next to the `08-COMPACT-ROW-TOKENS.md` reference.
  - **Lines 99, 131, 132, 175, 176 (Medium + Hard tables):** unchanged — they already use shortened backreferences ("same slot order" / "full slot order" / "Compromise order steps 4–5 expected") that transitively inherit the Easy update.
  - **Lines 184, 261 area (§Hard ADR reference + cross-game summary):** unchanged (5 instances of `08-HARD-MINES-ADR.md` survive intact).
  - **Merge section (line 211) + Nonogram section (line 243):** unchanged.

- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md` — MODIFIED. Net +4 / −2 line.
  - **Line 32 (new):** Supersession blockquote inserted under `### Minesweeper`. Contains the rationale (Restart rightmost; slot 2 stacked subview hosting MinesRemainingChip top + TimerChip bottom; slot 4 = MinesweeperToolbarMenu only; Token Anchors above unchanged) + 11-CONTEXT D-05 backlink.
  - **Line 34 (was line 32 before insertion):** Mines slot string itself updated to the D-05 order.
  - **Line 63 (was line 61 before insertion) — §Consumed by Phase 11 line:** rewritten to dated + backlinked form with the new slot string verbatim.
  - **§Token Anchors table (lines 14-23):** unchanged — token grep returns 12 occurrences of `radii.button|spacing.xl|spacing.s|radii.chip|spacing.l`, satisfying the ≥ 5 acceptance bound and confirming Phase 9 D-13 locks are untouched.
  - **`### Merge` (line 36) + `### Nonogram` (line 40):** unchanged.

## Supersession-Note Text (verbatim, as inserted)

### Inserted into VIDEO-MODE-LAYOUTS.md (under §Minesweeper — Easy heading, line 77)

> **Slot-row supersession (2026-05-13):** the Minesweeper compact-row slot string in the Large-top / Large-bottom rows below has been revised per `11-CONTEXT.md` D-05. The new order is `Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart`. Restart is rightmost (most-tapped in-flight action under stress); slot 2 is a vertical-stack subview (Mines remaining on top, Time below) so the 5-slot `VideoCompactControlRow` contract (Phase 9 D-12) stays intact. Settings (slot 4) opens `MinesweeperToolbarMenu` (difficulty change menu) per D-08; global app Settings stays reachable from HomeView. Applies to Easy / Medium / Hard alike.

### Inserted into 08-COMPACT-ROW-TOKENS.md (under §Per-Game Slot Mapping §Minesweeper, line 32)

> **Supersedes 2026-05-13** (per `11-CONTEXT.md` D-05). Restart is the most-tapped in-flight action under stress and joins the compact row at slot 5 (rightmost). Slot 2 becomes a vertical-stack subview hosting both `MinesRemainingChip` (top) and `TimerChip` (bottom) so the 5-slot `VideoCompactControlRow` contract from Phase 9 D-12 is preserved unchanged. Slot 4 (Settings) opens `MinesweeperToolbarMenu` (difficulty change menu only) per D-08; global app Settings stays reachable from HomeView. Token anchors above are unchanged.

## Merge + Nonogram Preservation Confirmed

Per plan acceptance criteria — both grep'd to ensure no over-replace damage:

| Doc | Merge slot string | Nonogram slot string |
|---|---|---|
| `VIDEO-MODE-LAYOUTS.md` | 1 verbatim (line 211) | 1 verbatim (line 243) |
| `08-COMPACT-ROW-TOKENS.md` | 1 verbatim (line 38) | 1 verbatim (line 42) |

`### Merge` subsection: present (1 occurrence). `### Nonogram` subsection: present (1 occurrence).

## Decisions Made

- **Supersession at the Easy-section heading covers Medium + Hard via backreference.** The Medium and Hard zone tables in `VIDEO-MODE-LAYOUTS.md` never repeated the verbatim slot string in the first place — they used shortened "same slot order" / "full slot order" / "Compromise order steps 4–5" callbacks to the Easy line. So a single supersession note + single Easy-row update propagates the change without smearing four nearly-identical edits across three tables. The note explicitly says "Applies to Easy / Medium / Hard alike" to make this transitive scope unambiguous.
- **Token Anchors table left untouched.** Plan acceptance criterion: `radii.button / spacing.xl / spacing.s / radii.chip / spacing.l` token-count grep returns ≥ 5. Actual: 12 (Token Anchors table contains the radii/spacing tokens multiple times, plus the §Consumed-by Phase 9 SC4 line). Confirms Phase 9 D-13 locks survive verbatim.

## Deviations from Plan

None — plan executed exactly as written. Both tasks completed in their planned order. No auto-fixes triggered (Rules 1–4 dormant). No architectural changes. No auth gates.

## Issues Encountered

- **Pre-existing xcstrings drift carried forward (out of scope).** `gamekit/gamekit/Resources/Localizable.xcstrings` still shows the same unstaged modification carried over from before Plan 11-01. Logged in `.planning/phases/11-mines-adoption/deferred-items.md` per executor scope-boundary rules. Left unstaged in both 11-02 commits.

## Verification

- `grep -cF "Back | Flags/mines | Reveal/Flag picker | Time | Settings" VIDEO-MODE-LAYOUTS.md` → `0` ✓
- `grep -cF "Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart" VIDEO-MODE-LAYOUTS.md` → `2` ✓ (supersession note + Easy table row)
- `grep -cF "Back | Score | Mode picker | Best/time | Settings" VIDEO-MODE-LAYOUTS.md` → `1` ✓ (Merge preserved)
- `grep -cF "Back | Lives/size | Fill/Mark picker | Time | Settings" VIDEO-MODE-LAYOUTS.md` → `1` ✓ (Nonogram preserved)
- `grep -cF "Slot-row supersession" VIDEO-MODE-LAYOUTS.md` → `1` ✓
- `grep -cF "11-CONTEXT" VIDEO-MODE-LAYOUTS.md` → `2` ✓ (note + Easy-row inline callout)
- `grep -cF "08-HARD-MINES-ADR.md" VIDEO-MODE-LAYOUTS.md` → `5` ✓ (ADR references intact)
- `grep -cF "Back | Flags/mines | Reveal/Flag picker | Time | Settings" 08-COMPACT-ROW-TOKENS.md` → `0` ✓
- `grep -cF "Back | [Mines⊥Time stacked chip] | Reveal/Flag picker | Settings | Restart" 08-COMPACT-ROW-TOKENS.md` → `2` ✓ (§Minesweeper + §Consumed by)
- `grep -cF "### Merge" 08-COMPACT-ROW-TOKENS.md` → `1` ✓; `grep -cF "### Nonogram" 08-COMPACT-ROW-TOKENS.md` → `1` ✓
- `grep -cF "Back | Score | Mode picker | Best/time | Settings" 08-COMPACT-ROW-TOKENS.md` → `1` ✓
- `grep -cF "Back | Lives/size | Fill/Mark picker | Time | Settings" 08-COMPACT-ROW-TOKENS.md` → `1` ✓
- `grep -cF "11-CONTEXT" 08-COMPACT-ROW-TOKENS.md` → `2` ✓ (§Minesweeper + §Consumed by)
- `grep -cE "radii.button|spacing.xl|spacing.s|radii.chip|spacing.l" 08-COMPACT-ROW-TOKENS.md` → `12` ✓ (≥ 5; Token Anchors table untouched)
- `grep -cF "Supersedes 2026-05-13" 08-COMPACT-ROW-TOKENS.md` → `1` ✓
- `git diff --stat` for the two 11-02 commits shows exactly 2 `.md` files changed, both under `.planning/phases/08-video-mode-design/` ✓ (no code, no xcstrings).

## Plan-spec Confirmations (per `<output>` block)

- **Two doc files modified:** `VIDEO-MODE-LAYOUTS.md` + `08-COMPACT-ROW-TOKENS.md`. ✓
- **Exact line ranges replaced:** documented in "Files Modified" section above (LAYOUTS line 77 new + line 98 updated; TOKENS line 32 new + line 34 updated + line 63 rewritten). ✓
- **Merge + Nonogram slot strings unchanged:** confirmed by grep (1 verbatim each, in both files). ✓
- **Supersession-note text inserted into each doc:** captured verbatim above. ✓

## Next Phase Readiness

- **Plan 11-03 ready.** The two design docs now read with the D-05 slot order; Plan 11-04 (compact-row composition) can implement against an unambiguous slot mapping. Wave 1 complete (Plan 11-01 chip extraction + Plan 11-02 doc supersession both landed).
- **No release-log entry appended this commit.** Per CLAUDE.md §8.10 + §0.3, a pure planning-doc supersession with no user-facing shipped change is grouped with the Phase 11 wrap-up commit (likely Plan 11-08).

## Self-Check: PASSED

- `.planning/phases/08-video-mode-design/VIDEO-MODE-LAYOUTS.md`: FOUND, modified.
- `.planning/phases/08-video-mode-design/08-COMPACT-ROW-TOKENS.md`: FOUND, modified.
- Commit `ae75d60`: FOUND (Task 1 — LAYOUTS supersession).
- Commit `55b7eb8`: FOUND (Task 2 — TOKENS supersession).
- All grep acceptance criteria pass (counts above).
- No deletions detected in either commit.

---
*Phase: 11-mines-adoption*
*Completed: 2026-05-13*
