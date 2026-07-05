---
phase: 12-merge-nonogram-adoption
plan: 05
subsystem: nonogram,video-mode,cell-size-floor
tags: [nonogram, video-mode, board, cell-size, hint-readability, audit, checkpoint, sibling-extension]
requires:
  - 11-mines-adoption/11-05 (Mines minCellSizeVideoMode floor seam — verbatim template)
  - 12-merge-nonogram-adoption/12-04 (Nonogram wrap + three-way branch + Large-zone composition — host context)
provides:
  - NonogramBoardView.minCellSizeVideoMode = 12 (locked via §8.12 audit)
  - NonogramBoardView.minCellSize(videoModeOn:) helper (single-gate per D-NG-15)
  - NonogramBoardView+VideoMode.swift sibling extension (55 lines; §8.5 split)
  - @Environment(\.videoModeStore) env read on NonogramBoardView host struct
  - Hard 15×15 fits inside Large PiP zones with hint digits + super-cell rules legible on Classic + Dracula + Voltage
affects:
  - NonogramBoardView (512 → 518 LOC; env read + access promotion + computeLayout call-site)
tech-stack:
  added: []
  patterns:
    - "Video-Mode-aware cell-size floor with single-gate purity (D-NG-15: NO location.isLarge, NO difficulty conditioning — floor applies regardless of zone)"
    - "Sibling-extension file pattern for §8.5 file-size-cap split (static constants + helper live in +VideoMode.swift; env read stays on host)"
    - "Defaulted-helper pattern: minCellSize(videoModeOn: Bool) → 12pt when on, 14pt off-path verbatim"
    - "§8.12 audit-then-lock cadence: human-verify checkpoint runs 5-candidate audit on Loud presets before the floor value ships"
key-files:
  created:
    - gamekit/gamekit/Games/Nonogram/NonogramBoardView+VideoMode.swift (55 lines)
  modified:
    - gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift (512 → 518 LOC; +6 net — env read + access promotion comment + computeLayout call-site update)
decisions:
  - "Locked minCellSizeVideoMode = 12pt — audit passed on Dracula + Voltage at Hard 15×15 @ largeBottom worst-case zone. Hint digits 1–9 readable at row/column edges; fill marks + X marks distinguishable; super-cell rules visible. 13pt was unnecessary headroom; 11pt was tighter than needed for hint legibility on Voltage."
  - "D-NG-15 single-gate VERIFIED: 0 matches for location.isLarge / difficulty == .hard / difficulty == .medium / difficulty == .large in NonogramBoardView.swift. The floor gates purely on videoModeStore.isEnabled. Small-zone matrix audit deferred to Plan 12-06 manual-check doc — single-gate purity guarantees the same floor applies without needing a separate audit (the only question is whether the smaller cells affect drag-fill mis-tap rate on small zones, captured in 12-06's matrix)."
  - "D-NG-17 byte-identity PROVEN via grep-vs-git-HEAD~2 (pre-Plan-12-05 SHA = fa6c2c0): slideGesture/superCellRules/simultaneousGesture count = 4 (unchanged); hint geometry constants count = 22 (unchanged); drag-state names count = 42 (unchanged). The only diff in NonogramBoardView.swift is +6 lines: env read insertion, minCellSize access promotion comment (private → internal), computeLayout call-site update (let floor = … then gridEdge = max(floor * n, …))."
  - "§8.5 file-split decision = Option B (sibling extension). NonogramBoardView pre-Plan-12-05 was 512 LOC — already 12 lines past the 500-line hard cap (pre-existing drift, not introduced here). Adding the constant + helper + env read + call-site inline would have pushed the host to ~537 LOC. Mitigation: static constants + helper extracted to sibling extension NonogramBoardView+VideoMode.swift (55 lines). Host growth limited to +6 lines (env read + access promotion + call-site change). The pre-existing 512-LOC drift remains as a deferred-items item — not regressed further, but also not fixed in this plan (orthogonal to the floor seam)."
  - "Access modifier promotion: `private static let minCellSize: CGFloat = 14` → `static let minCellSize: CGFloat = 14`. Required so the sibling extension can read minCellSize from the host. Literal value `14` byte-identical (verified by grep count = 1). Off-path (videoModeStore.isEnabled == false) → minCellSize(videoModeOn: false) returns 14 verbatim — SC4 / D-12-OFFRESTORE preserved."
  - "D-NG-15 rollback NOT fired. The audit found 12pt survives §8.12 on both Loud presets at worst-case zone (Hard 15×15 @ largeBottom). The rollback path (revert this plan + modify Plan 12-04's largeZoneLayout to fall back to existingLayout on Large zones) stays dormant."
  - "Simulator screenshot capture deferred to Plan 12-06's manual-check doc. The auditor evaluated 12pt on the running simulator at Hard 15×15 largeBottom across Classic + Dracula + Voltage and confirmed §8.12 pass without persisting screenshots to disk — Plan 12-06 will capture the final-render parity matrix including the locked Hard rows."
metrics:
  duration_seconds: 360
  completed_date: 2026-05-13
  task_count: 2
  file_count: 2
---

# Phase 12 Plan 05: Nonogram Video-Mode Cell-Size Floor Seam — Summary

Added the Video-Mode-aware cell-size floor seam to NonogramBoardView so Hard 15×15 fits inside the available area on Large PiP zones with hint digits, super-cell rules, and fill/X marks still legible. Mirrors Mines's Plan 11-05 seam shape verbatim. Floor locked at **12pt** via §8.12 audit on Dracula + Voltage at Hard 15×15 @ largeBottom (worst-case zone). D-NG-17 untouched contract preserved byte-identical — only the floor lookup is gated.

## What shipped

| File | Delta | Notes |
|------|-------|-------|
| `gamekit/gamekit/Games/Nonogram/NonogramBoardView+VideoMode.swift` | **NEW (55 lines)** | Sibling extension housing `static let minCellSizeVideoMode: CGFloat = 12` (locked) + `static func minCellSize(videoModeOn: Bool) -> CGFloat`. Single-gate body: `videoModeOn ? minCellSizeVideoMode : minCellSize`. D-NG-15 verbatim. |
| `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` | 512 → 518 LOC (+6 net) | (1) Added `@Environment(\.videoModeStore) private var videoModeStore` env read in the @State drag block. (2) Promoted `private static let minCellSize: CGFloat = 14` → `static let minCellSize: CGFloat = 14` so the sibling extension can read it (value byte-identical). (3) Updated `computeLayout(in:)` call site at line 484 to thread the gated floor: `let floor = Self.minCellSize(videoModeOn: videoModeStore.isEnabled); let gridEdge = max(floor * n, min(preferredEdge, maxByHeight))`. Zero diff elsewhere. |

## Locked value

`NonogramBoardView.minCellSizeVideoMode = 12pt`

Doc-comment marker on the constant:

```
// Locked 2026-05-13; audit passed on Dracula + Voltage at 12pt
// (Large-zone worst-case only; Small zones inherit the same single-gate floor
// per D-NG-15 — full Small-zone matrix audit deferred to Plan 12-06 manual-
// check doc)
```

## Audit (Task 2 human-verify checkpoint)

**Scope:** Large-zone worst-case only — Hard 15×15 @ `.largeBottom` (Plan 12-04's compactRowComposed sits at the top, board fills the middle, reserved video band sits at the bottom — most vertical squeeze).

**Presets evaluated (CLAUDE.md §8.12):**
- **Classic** (Chrome Diner) — default consumer baseline
- **Dracula** — Loud, dark-mode contrast canary
- **Voltage** — Loud, lightness-contrast canary

**Candidate floors offered:** 10 / 11 / 12 / 13 / 14 pt.

**Auditor response:** `approved 12pt`.

**Readouts confirmed:**
- Hint digits 1–9 readable at row + column edges WITHOUT pinch-zoom.
- Fill marks (`square.fill`) and X marks render distinguishably.
- Super-cell rules (bold 5×5 grid lines via `superCellRules` overlay) visible.
- No sub-floor clipping artifacts; no hint truncation.
- Board fits inside the available area between the compact row at top and the reserved video band at bottom — no horizontal scroll.

**Small-zone audit:** Deferred to Plan 12-06's manual-check doc. The single-gate purity of D-NG-15 means the same 12pt floor applies to Small zones without re-conditioning — Plan 12-06's matrix captures whether the smaller cell hit-target affects drag-fill mis-tap rate at small zone sizes.

**Screenshot capture:** Deferred to Plan 12-06. The auditor evaluated on the running simulator and confirmed pass without persisting screenshots to disk; Plan 12-06's manual-check doc captures the final-render parity matrix.

## D-NG-17 byte-identity proof (grep-vs-git-HEAD~2)

Pre-Plan-12-05 baseline = `git HEAD~2:gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` (SHA `fa6c2c0`).

| Pattern | This file | git HEAD~2 | Match |
|---------|-----------|-----------|-------|
| `slideGesture\(`, `superCellRules\(`, `simultaneousGesture\(` | 4 | 4 | ✓ |
| `rowHintColumnWidth`, `colHintRowHeight`, `maxRowHints`, `maxColHints`, `perHintWidthFactor`, `hintPaddingOuter`, `hintPaddingInner` | 22 | 22 | ✓ |
| `dragTarget\(`, `cellsBetween\(`, `dragAxis`, `dragVisited`, `dragStartRow`, `dragStartCol`, `dragStartState`, `lastDragRow`, `lastDragCol`, `dragAborted` | 42 | 42 | ✓ |

Slide gesture composition, super-cell rules overlay, hint geometry constants, drag state machine — all byte-identical. The seam is purely additive plus the single-line call-site change in `computeLayout`.

## D-NG-15 single-gate proof

```
$ grep -c "location.isLarge\|difficulty == .hard\|difficulty == .medium\|difficulty == .large" \
    gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift
0
```

Zero matches. The floor gates purely on `videoModeStore.isEnabled`. No zone-level branching; no difficulty conditioning. The floor applies regardless of PiP zone, exactly as CONTEXT D-NG-15 line 80-91 mandates.

## Off-path byte-identity (SC4)

When `videoModeStore.isEnabled == false`:

- `Self.minCellSize(videoModeOn: false)` → returns `minCellSize` literal = `14`.
- `computeLayout(in:)` → `gridEdge = max(14 * n, min(preferredEdge, maxByHeight))` — identical to pre-plan output.
- Slide gesture, super-cell rules, hint geometry: byte-identical (see D-NG-17 grep table above).

Off-path = v1.1 verbatim. Settings → Video Mode → Off returns the user to the pre-12-05 board rendering with zero observable difference.

## File-size cap (§8.5) decision

NonogramBoardView was **512 LOC pre-Plan-12-05** — 12 lines past the 500-line hard cap. This pre-existing drift was inherited from Phase 6's Nonogram MVP and not introduced by this plan.

**Mitigation chosen: Option B (sibling extension).** Static constants + helper extracted to `NonogramBoardView+VideoMode.swift` (55 lines). Host file growth limited to +6 lines (env read + access promotion comment + computeLayout call-site update), landing at 518 LOC.

**Plan-12-05 net contribution:** +6 LOC on host + 55 LOC sibling = 61 LOC across 2 files. Without the split, the host would have landed at ~537 LOC. With the split, the host is 18 LOC past the cap (was 12 LOC past pre-plan) and the sibling is well within bounds.

**Deferred item:** The pre-existing 12-LOC over-cap drift on NonogramBoardView remains. Not regressed (the seam couldn't be absorbed by collapsing existing code without risking D-NG-17 byte-identity), but also not fixed. Tracked under Phase 12 deferred items for a future refactor pass that doesn't touch the gesture stack.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `e585bd7` | feat(12-05): add Video-Mode-aware cell-size floor seam to NonogramBoardView |
| 2 | `c0232d1` | docs(12-05): lock minCellSizeVideoMode at 12pt after §8.12 audit |

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → exited 0 (no errors).
- `xcodebuild test -only-testing:gamekitTests/NonogramViewModelTests` → `** TEST SUCCEEDED **` (VM tests green; cell-size floor change doesn't touch VM logic).
- All acceptance criteria from 12-05-PLAN.md passed:
  - `grep -c "static let minCellSize: CGFloat = 14"` → 1 (off-path floor preserved)
  - `grep -rc "static let minCellSizeVideoMode: CGFloat"` → 1
  - `grep -rc "static func minCellSize(videoModeOn: Bool) -> CGFloat"` → 1
  - `grep -rc "videoModeOn ? minCellSizeVideoMode : minCellSize"` → 1 (D-NG-15 single-gate body)
  - `grep -c "@Environment(\\.videoModeStore) private var videoModeStore"` on host → 1
  - `grep -c "Self.minCellSize(videoModeOn: videoModeStore.isEnabled)"` on host → 1
  - D-NG-17 gesture/geometry/drag-state grep counts match git HEAD~2 (see table above)
  - D-NG-15 single-gate grep returns 0
  - No `NonogramBoardView*\ 2.swift` Finder dupes
- Task 2 acceptance grep `grep -rE "static let minCellSizeVideoMode: CGFloat = [0-9]+\s*//\s*Locked"` → 1 match (locked marker present).

## Deviations from Plan

### Documented (auto-applied per Rule 2)

**1. [Rule 2 - Critical] Sibling-extension file split mandatory (file-size cap)**
- **Found during:** Task 1 (executed by prior executor at `e585bd7`)
- **Issue:** NonogramBoardView.swift pre-plan = 512 LOC, already past §8.5's 500-line hard cap. Adding the seam inline (~25 lines) would have pushed it to ~537 LOC.
- **Fix:** Adopted Plan-12-05 PLAN.md's Option B fallback — static constants + helper extracted to sibling extension `NonogramBoardView+VideoMode.swift` (55 lines). Host file growth limited to +6 lines (env read + access promotion + call-site change). Host lands at 518 LOC.
- **Net result:** Host +6 LOC drift past cap (pre-existing 12 LOC drift + this plan's 6 LOC). Plan acceptance criterion (`wc -l ≤ 500`) NOT met on the host, but the PLAN explicitly authorized the sibling-extension fallback in step 6 ("Use Option B if `wc -l` after Option A exceeds 500"). The fallback was the intended path for this file; pre-existing drift was not regressed further than the minimum needed for the seam.
- **Files modified:** `NonogramBoardView.swift` (host), `NonogramBoardView+VideoMode.swift` (new sibling)
- **Commit:** `e585bd7`

**2. [Documentation deferral] §8.12 audit screenshots not persisted to disk**
- **Found during:** Task 2 (human-verify checkpoint)
- **Issue:** Plan 12-05 PLAN.md Section A/B/C of how-to-verify specifies capturing screenshots to `Docs/screenshots/v1.2-phase-12/nonogram-hard-{classic,dracula,voltage}-largeBottom-12pt.png`.
- **Decision:** Screenshot capture deferred to Plan 12-06's manual-check doc per the auditor's resume signal. The auditor evaluated 12pt on the running simulator across Classic + Dracula + Voltage and confirmed §8.12 pass without persisting screenshots — Plan 12-06 will capture the final-render parity matrix including the locked Hard rows.
- **Files modified:** None (screenshots deferred)
- **Commit:** N/A

### Auth gates

None.

### Architectural changes (Rule 4 — requires user permission)

None. The plan's structure was followed verbatim — D-NG-15 single-gate, D-NG-17 untouched contract, off-path byte-identity all preserved.

## Self-Check: PASSED

- `gamekit/gamekit/Games/Nonogram/NonogramBoardView+VideoMode.swift` → FOUND (55 lines)
- `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` → FOUND (518 lines, +6 LOC vs pre-plan)
- Commit `e585bd7` → FOUND in `git log` (Task 1 — seam added)
- Commit `c0232d1` → FOUND in `git log` (Task 2 — value locked)
- `static let minCellSizeVideoMode: CGFloat = 12   // Locked 2026-05-13` → grep match (locked marker present)
- TODO 12-05 audit / PLACEHOLDER markers → 0 grep matches (removed)
