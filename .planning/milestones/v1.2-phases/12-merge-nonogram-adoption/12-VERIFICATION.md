---
phase: 12-merge-nonogram-adoption
verified: 2026-05-13T22:30:00Z
status: gaps_found
score: 3/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Merge plays across all 6 PiP locations — swipe-driven tile merging stays gesture-clean, score/picker/best chips reflow per Phase 10 primitives, end-of-game flow remains reachable without an extra tap. (ROADMAP SC1)"
    status: partial
    reason: "P11 carryforward defect: small-zone branches in MergeGameView+VideoMode.smallZoneToolbarContent consume only anchors.back + anchors.settings — anchors.picker is never wired. On Bottom L/R PiP zones the Small overlay covers the bottom-center MergeModePill (Win/Infinite picker); on Top L/R PiP zones the Small overlay covers the top-center MergeHeaderBar chips (Score + Best). Large-zone path (largeBottom verified) PASSES. 4 of 6 zones affected for Merge."
    artifacts:
      - path: "gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift"
        issue: "smallZoneToolbarContent (line 145-159) reads anchors.back and anchors.settings only; anchors.picker is never read or wired. MergeModePill stays at default bottom-center on Small zones (collides with bottom-PiP overlay). MergeHeaderBar stays at default top (collides with top-PiP overlay)."
    missing:
      - "Wire anchors.picker into the Merge Small-zone branch to reposition MergeModePill away from the overlay zone."
      - "Add a Small-zone seam (hide / re-anchor) for MergeHeaderBar on Top L/R zones."
  - truth: "Legibility regression check passes on Classic preset AND one Loud preset (Voltage or Dracula) per CLAUDE.md §8.12 for BOTH games across all 6 PiP locations. (ROADMAP SC3)"
    status: partial
    reason: "Manual audit recorded SC3 FAIL on the same 4 small-zone-per-game rows that SC1 + SC2's small-zone equivalents fail on. The legibility check on Large-zone worst-case rows PASSED on Classic + Dracula + Voltage (Nonogram Hard 15×15 largeBottom at 12pt floor; Merge winMode largeBottom)."
    artifacts:
      - path: "gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift"
        issue: "Small-zone branch doesn't reposition chips/picker — affects per-game legibility on 4 of 6 zones."
      - path: "gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift"
        issue: "Same small-zone routing omission as Merge — NonogramModePill (Place/Mark) and NonogramHeaderBar chips (Size/Lives + Timer) stay at default positions and collide with the PiP overlay on Small zones."
    missing:
      - "Once SC1's small-zone routing is wired, re-audit the 4 Small-zone rows per game on Classic + Voltage/Dracula."
deferred: []
---

# Phase 12: Merge + Nonogram Adoption Verification Report

**Phase Goal:** The two remaining v1.1 games — Merge (square board, swipe-driven) and Nonogram (grid + hints) — adopt the Video Mode layout primitives. Both reflow across all 6 PiP locations without legibility regression, with particular care given to Nonogram's row/column hints in Large-top and Large-bottom layouts where vertical real estate is most constrained.
**Verified:** 2026-05-13T22:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|--------------------|--------|----------|
| SC1 | Merge plays across all 6 PiP locations — swipe gesture clean, score/picker/best reflow, end-of-game reachable | ✗ FAILED (partial) | Large-zone path (largeBottom) PASSED on Classic + Dracula per manual sign-off 2026-05-13. Small-zone path FAILS on 4 of 6 zones: MergeGameView+VideoMode.smallZoneToolbarContent (line 145-159) wires anchors.back + anchors.settings only; anchors.picker is never consumed. ModePill + HeaderBar overlap PiP overlay on Top/Bottom L/R Small zones. P11 carryforward gap. |
| SC2 | Nonogram plays across all 6 PiP locations — hints + grid readable in Large-top AND Large-bottom | ✓ VERIFIED | Hard 15×15 hint legibility @ 12pt floor verified on Classic + Dracula + Voltage at largeBottom (sign-off row 20, 2026-05-13). NonogramBoardView+VideoMode.swift locks `minCellSizeVideoMode: CGFloat = 12`. Floor seam routes through `NonogramBoardView.computeLayout` line 484. Final renders match Plan 12-05 locked screenshots. Hint digits 1–9 legible without pinch-zoom; fill/X marks distinguishable; super-cell rules visible. |
| SC3 | Legibility regression: Classic + Loud preset × both games × 6 zones | ✗ FAILED (partial) | Large-zone worst-case rows PASS on Classic + Dracula + Voltage per manual sign-off. Small-zone rows FAIL on 4 of 6 zones per game due to the SC1 routing gap (overlay collides with un-routed picker + HeaderBar). |
| SC4 | Video Mode Off restores both games' baseline layouts byte-identical (VIDEO-13 spot-check on each game) | ✓ VERIFIED | MergeBoardView.swift SHA `4aec14161b00ac2dbd1ea00e3bebb696bea6fc26` UNCHANGED across all 5 wave commits (D-MG-17). NonogramBoardView host file only added 6 lines for the floor seam, with off-path floor 14pt unchanged (D-NG-17). MergeHeaderBar + NonogramHeaderBar invoke extracted chips with NO `compact:` argument → defaults to `false` → v1.1 byte-identical render. VideoModeStore.isEnabled == false branch in both GameView body Group { ... } resolves to existingLayout + existingToolbarContent verbatim. Manual sign-off SC4 PASS. |
| SC5 | Compact control row consumed verbatim — Merge slots Back \| Score \| Mode picker \| Best/time \| Settings; Nonogram slots Back \| Lives/size \| Fill/Mark \| Time \| Settings; no per-game forking | ✓ VERIFIED | `gamekit/gamekit/Core/VideoCompactControlRow.swift` SHA `105ca0b60d321c1dc2ed0d68c384f73983677aa5` UNCHANGED from pre-P12 to HEAD. Both Merge + Nonogram call `VideoCompactControlRow` from their `+VideoMode.swift` extensions with `onSettings: nil` (no gear; picker covers settings role per D-MG-01 / D-NG-01). D-NG-01 single-slot Size↔Lives swap implemented at line 301-315 of NonogramGameView+VideoMode.swift via `if viewModel.gameMode == .lives`. Manual sign-off SC5 PASS. |

**Score:** 3/5 truths verified (SC2, SC4, SC5 PASS; SC1 + SC3 partial — small-zone gap)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `gamekit/gamekit/Games/Merge/MergeScoreChip.swift` | Props-only score chip, `compact: Bool = false` API | ✓ VERIFIED | EXISTS · 50 LOC · `var compact: Bool = false` at line 27 · used 2× in HeaderBar (default) + compactRowComposed (compact:true) |
| `gamekit/gamekit/Games/Merge/MergeBestChip.swift` | Props-only best chip, `compact: Bool = false` API | ✓ VERIFIED | EXISTS · 43 LOC · `var compact: Bool = false` at line 20 · used 2× |
| `gamekit/gamekit/Core/VideoModeTimerChip.swift` | Shared timer chip moved from Mines | ✓ VERIFIED | EXISTS · 90 LOC · TimerChip.swift DELETED · `compact: Bool = false` at line 37 · 5 consumer sites (Mines HeaderBar, Mines compactRowComposed, Nonogram HeaderBar, Nonogram compactRowComposed, plus 1 doc comment ref) |
| `gamekit/gamekit/Games/Merge/MergeHeaderBar.swift` | Thin composer; off-path byte-identical | ✓ VERIFIED | EXISTS · 30 LOC · invokes MergeScoreChip + MergeBestChip with NO `compact:` arg → defaults to false → off-path v1.1 byte-identical |
| `gamekit/gamekit/Games/Merge/MergeGameView.swift` | Three-way branch: off / Large / Small | ✓ VERIFIED | EXISTS · 148 LOC · `@Environment(\.videoModeStore)` at line 49 · Group { if !isEnabled / else if location.isLarge / else } body branch at line 60-63 |
| `gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift` | Sibling extension (§8.5 split) | ✓ VERIFIED | EXISTS · 308 LOC · hosts existingLayout / smallZoneToolbarContent / largeZoneLayout / compactRowComposed / restartWithOverflowMenu |
| `gamekit/gamekit/Games/Merge/MergeModePill.swift` | `compact: Bool = false` API | ✓ VERIFIED | EXISTS · 69 LOC · `var compact: Bool = false` at line 26 |
| `gamekit/gamekit/Games/Merge/MergeBoardView.swift` | UNCHANGED (D-MG-17) | ✓ VERIFIED | SHA `4aec14161b00ac2dbd1ea00e3bebb696bea6fc26` byte-identical between `c4bf5bb^` and HEAD |
| `gamekit/gamekit/Games/Nonogram/NonogramSizeChip.swift` | Props-only size chip, `compact: Bool = false` API | ✓ VERIFIED | EXISTS · 75 LOC · `var compact: Bool = false` at line 31 |
| `gamekit/gamekit/Games/Nonogram/NonogramLivesChip.swift` | Props-only lives chip, `compact: Bool = false` API | ✓ VERIFIED | EXISTS · 62 LOC · `var compact: Bool = false` at line 23 |
| `gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift` | Thin composer consuming all 3 chips with compact:false | ✓ VERIFIED | EXISTS · 49 LOC · invokes NonogramSizeChip + NonogramLivesChip (conditional) + VideoModeTimerChip with NO `compact:` arg → off-path v1.1 byte-identical |
| `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift` | Three-way branch | ✓ VERIFIED | EXISTS · 186 LOC · `@Environment(\.videoModeStore)` at line 55 · three-way branch at line 70-73 |
| `gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift` | Sibling extension (§8.5 cap) | ✓ VERIFIED | EXISTS · 407 LOC · hosts the full Video Mode chrome surface; under 500-line cap |
| `gamekit/gamekit/Games/Nonogram/NonogramModePill.swift` | `compact: Bool = false` API | ✓ VERIFIED | EXISTS · ~90 LOC · `var compact: Bool = false` at line 27 |
| `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` | D-NG-15 floor seam, D-NG-17 untouched contract | ✓ VERIFIED | EXISTS · 518 LOC · `@Environment(\.videoModeStore)` at line 85 · `static let minCellSize: CGFloat = 14` (off-path UNCHANGED) at line 90 · `let floor = Self.minCellSize(videoModeOn: videoModeStore.isEnabled)` at line 484 |
| `gamekit/gamekit/Games/Nonogram/NonogramBoardView+VideoMode.swift` | Sibling extension for §8.5 split | ✓ VERIFIED | EXISTS · 52 LOC · `static let minCellSizeVideoMode: CGFloat = 12` locked 2026-05-13 (Plan 12-05 audit on Dracula + Voltage @ 15×15 Hard largeBottom) |
| `gamekit/gamekit/Screens/HomeView.swift` | Merge + Nonogram destinations wrapped in `.videoModeAware(minBoardHeight: 480)` | ✓ VERIFIED | 3 `.videoModeAware(minBoardHeight: 480)` modifier calls at lines 161/164/167 (Mines + Merge + Nonogram arms) |
| `gamekit/gamekit/Games/Minesweeper/TimerChip.swift` | DELETED (renamed) | ✓ VERIFIED | ABSENT — `find gamekit -name 'TimerChip*'` returns nothing |
| `.planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md` | 24-row matrix + SC sign-off block | ✓ VERIFIED | EXISTS · canonical doc · status: partial · gaps: [SC1-small-zone-picker-routing, SC3-small-zone-headerbar-chip-routing] |
| `Docs/releases/v1.2.md` | Phase 12 entries appended | ✓ VERIFIED | Contains Phase 12 user-facing bullet + Phase 12-01..12-06 Internal-changes bullets + Risks/notes for the 12pt floor lock |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| HomeView Merge destination | MergeGameView + .videoModeAware(minBoardHeight: 480) | NavigationLink modifier chain | ✓ WIRED | Line 163-164 of HomeView.swift |
| HomeView Nonogram destination | NonogramGameView + .videoModeAware(minBoardHeight: 480) | NavigationLink modifier chain | ✓ WIRED | Line 166-167 of HomeView.swift |
| MergeGameView.body | Three-way branch on videoModeStore.isEnabled + location.isLarge | Group { if/else if/else } | ✓ WIRED | Line 60-63 |
| NonogramGameView.body | Three-way branch on videoModeStore.isEnabled + location.isLarge | Group { if/else if/else } | ✓ WIRED | Line 70-73 |
| Merge compactRowComposed slot 2 | MergeScoreChip(compact: true) | VideoCompactControlRow primary slot | ✓ WIRED | Line 241-247 of MergeGameView+VideoMode.swift |
| Merge compactRowComposed slot 3 | MergeModePill(compact: true) | VideoCompactControlRow picker slot | ✓ WIRED | Line 248-258 |
| Merge compactRowComposed slot 4+5 | MergeBestChip(compact: true) + restartWithOverflowMenu | HStack inside secondaryInfo | ✓ WIRED | Line 259-264 |
| Merge compactRowComposed slot 6 | onSettings: nil | D-MG-01 — no gear | ✓ WIRED | Line 238 |
| Nonogram compactRowComposed slot 2 | Conditional swap NonogramSizeChip ↔ NonogramLivesChip | `if viewModel.gameMode == .lives` | ✓ WIRED | Line 301-315 of NonogramGameView+VideoMode.swift |
| Nonogram compactRowComposed slot 3 | NonogramModePill(compact: true) | picker slot | ✓ WIRED | Line 317 |
| Nonogram compactRowComposed slot 4+5 | VideoModeTimerChip(compact: true) + restartWithOverflowMenu | secondaryInfo HStack | ✓ WIRED | Line 330-337 |
| Nonogram compactRowComposed slot 6 | onSettings: nil | D-NG-01 — no gear | ✓ WIRED | Line 298 |
| NonogramBoardView.computeLayout | floor = Self.minCellSize(videoModeOn: videoModeStore.isEnabled) | env-gated floor read | ✓ WIRED | Line 484 — replaces hardcoded `Self.minCellSize * n` |
| Merge Small-zone branch | anchors.picker (ModePill repositioning) | VideoModeSlotRouter.anchors(for:) | ✗ NOT_WIRED | smallZoneToolbarContent (line 145-159) reads only anchors.back + anchors.settings; anchors.picker never consumed. ModePill stays at default bottom-center. |
| Nonogram Small-zone branch | anchors.picker (ModePill repositioning) | VideoModeSlotRouter.anchors(for:) | ✗ NOT_WIRED | smallZoneToolbarContent (line 151-165) reads only anchors.back + anchors.settings; anchors.picker never consumed. Same pattern as Merge. |
| Merge Small-zone branch | HeaderBar repositioning for Top L/R zones | (no anchor concept yet) | ✗ NOT_WIRED | HeaderBar stays at top of existingLayout; no seam for Top-PiP overlap mitigation. |
| Nonogram Small-zone branch | HeaderBar repositioning for Top L/R zones | (no anchor concept yet) | ✗ NOT_WIRED | Same omission as Merge. |
| MergeHeaderBar → MergeScoreChip + MergeBestChip | NO `compact:` arg | default = false → v1.1 byte-identical | ✓ WIRED | Line 22-26 of MergeHeaderBar.swift |
| NonogramHeaderBar → NonogramSizeChip + NonogramLivesChip + VideoModeTimerChip | NO `compact:` arg | default = false → v1.1 byte-identical | ✓ WIRED | Line 31-40 of NonogramHeaderBar.swift |
| VideoModeTimerChip | 5 consumer sites (Mines × 2, Nonogram × 2, comment ref × 1) | shared Core/ primitive | ✓ WIRED | grep -rn returns 5 matches across Minesweeper + Nonogram |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| VIDEO-09 | 12-01, 12-02, 12-06 | Merge adopts Video Mode across all 6 locations with no legibility regression | ✗ BLOCKED (partial) | Merge Large-zone path (2 of 6 zones) PASSES on Classic + Dracula. Merge Small-zone path (4 of 6 zones) FAILS on small-zone routing gap. Phase 12.1 planned for gap closure. |
| VIDEO-10 | 12-03, 12-04, 12-05, 12-06 | Nonogram adopts Video Mode across all 6 locations; hints + grid stay readable in Large-top and Large-bottom layouts | ✗ BLOCKED (partial) | Nonogram Large-zone path (2 of 6 zones) PASSES — `minCellSizeVideoMode = 12pt` locked, hint legibility verified on Classic + Dracula + Voltage @ Hard 15×15 largeBottom (SC2 acceptance row). Nonogram Small-zone path (4 of 6 zones) FAILS on same small-zone routing gap as Merge. The Large-top + Large-bottom hint-legibility requirement is specifically satisfied (matches VIDEO-10's worst-case clause); the 6-locations clause is partial. |

Note: REQUIREMENTS.md §v1.2 Traceability lists VIDEO-09 and VIDEO-10 both as "Pending" for Phase 12. Both requirements are progressed but not fully satisfied. Phase 12.1 closure required before marking complete.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `gamekit/gamekit/Games/Nonogram/NonogramBoardView.swift` | 1-518 | File 518 LOC — exceeds CLAUDE.md §8.5 500-line hard cap by 18 lines | ℹ️ Info | Pre-existing condition: pre-P12 the file was 512 LOC (already over). Plan 12-05 explicitly created `NonogramBoardView+VideoMode.swift` sibling extension to keep the +6 LOC delta minimal and avoid pushing further past the cap. Not introduced by Phase 12; surfaced as documentation. |
| `.planning/phases/12-merge-nonogram-adoption/12-04-PLAN.md` | 80-81 | Plan TEXT claims "The Small-zone branch is fully implemented per D-NG-01" but the actual implementation only routes anchors.back + anchors.settings | ⚠️ Warning | Plan-to-implementation drift on the same gap surfaced by the manual audit. The plan asserted full small-zone implementation; the audit caught the picker + HeaderBar omission. P11 had the same gap. |
| `gamekit/gamekit/Games/Merge/MergeGameView+VideoMode.swift` | 145-159 | smallZoneToolbarContent doesn't consume anchors.picker | ⚠️ Warning | Active functional gap. Documented in 12-VIDEO-MANUAL-CHECK.md "Gap Description". |
| `gamekit/gamekit/Games/Nonogram/NonogramGameView+VideoMode.swift` | 151-165 | smallZoneToolbarContent doesn't consume anchors.picker | ⚠️ Warning | Same as Merge. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All P12 commit hashes resolvable | `git rev-parse --verify <hash>^{commit}` for c4bf5bb / 629f237 / c53c0ea / 8a00bfc / eb638cb / 3930442 / ff28930 / 02fde26 / ab529da / 77e02bd / b524780 / 01ce270 / a327935 / e585bd7 / c0232d1 / 7a26ed9 / 2fceb1c / ca48330 / 414f255 | All 19 commits exist | ✓ PASS |
| MergeBoardView SHA unchanged across phase | `git rev-parse c4bf5bb^:.../MergeBoardView.swift == HEAD:.../MergeBoardView.swift` | Both `4aec14161b00ac2dbd1ea00e3bebb696bea6fc26` | ✓ PASS |
| VideoCompactControlRow SHA unchanged across phase (SC5 no forking) | `git rev-parse c4bf5bb^:.../VideoCompactControlRow.swift == HEAD:.../VideoCompactControlRow.swift` | Both `105ca0b60d321c1dc2ed0d68c384f73983677aa5` | ✓ PASS |
| TimerChip rename complete (no stale references in code) | `grep -rE "\bTimerChip\(" gamekit/gamekit --include="*.swift"` | 0 occurrences | ✓ PASS |
| VideoModeTimerChip consumed at 4 functional sites + 1 comment | `grep -rn "VideoModeTimerChip(" gamekit/gamekit --include="*.swift"` | 5 occurrences (4 code + 1 doc comment) | ✓ PASS |
| Locked floor value present in code | `grep "minCellSizeVideoMode: CGFloat" .../NonogramBoardView+VideoMode.swift` | `static let minCellSizeVideoMode: CGFloat = 12` | ✓ PASS |
| Off-path HeaderBar consumers use no `compact:` arg (byte-identity) | `grep "compact:" .../{Merge,Nonogram}HeaderBar.swift` | 0 occurrences in either file | ✓ PASS |
| Live simulator audit (Classic + Loud × both games × 6 zones) | Manual run on iPhone 17 Pro Max sim | Recorded in 12-VIDEO-MANUAL-CHECK.md — Large worst-case rows PASS; Small zones FAIL routing | ? SKIP-MANUAL (human-verified offline; results consumed below) |

### Human Verification Required

Already completed by user — recorded in `.planning/phases/12-merge-nonogram-adoption/12-VIDEO-MANUAL-CHECK.md` with sign-off block dated 2026-05-13. No additional human verification required for this verification pass; the gaps surfaced from that audit are captured above.

### Gaps Summary

Phase 12 ships substantial value: SC2 (Nonogram hint legibility — the single hardest engineering challenge of the phase, the entire reason VIDEO-10 calls out Large-top + Large-bottom by name), SC4 (off-restore byte-identity for both games), and SC5 (no per-game forking of the shared compact control row) are all VERIFIED. The Large-zone code paths for both games work end-to-end and survive the §8.12 dual-preset audit.

The open gap is a P11 carryforward: `VideoModeSlotRouter.anchors(for:)` returns six anchors (back / settings / picker / fab / ...), but the small-zone `smallZoneToolbarContent` in each adopter game (Mines, Merge, Nonogram identically) reads only `anchors.back` and `anchors.settings`. The `anchors.picker` value goes unread, leaving the ModePill at its default bottom-center position where it collides with the bottom-PiP overlay on Bottom L/R zones. The HeaderBar chips have no analogous reposition seam and remain at the top of the existingLayout, colliding with the top-PiP overlay on Top L/R zones.

**Affected zones (per game):** smallTopLeft, smallTopRight, smallBottomLeft, smallBottomRight — 4 of 6 zones for Merge AND Nonogram (and equivalently for Mines).
**Unaffected zones:** largeTop, largeBottom — 2 of 6 zones for both games (these pass through compactRowComposed, which IS fully wired).

**Why this verification still reports `gaps_found` rather than waiting for Phase 12.1:**
- The Phase 12 sign-off doc explicitly marked status: partial with gaps: [SC1-small-zone-picker-routing, SC3-small-zone-headerbar-chip-routing] on 2026-05-13.
- Phase 13 (Win/Loss Banner + A11y Gating) addresses different concerns and does NOT cover the small-zone routing surface.
- The gap is real, code-level, and verifiable in the current HEAD. Closure is scheduled via `/gsd-plan-phase 12.1 --gaps`.

---

*Verified: 2026-05-13T22:30:00Z*
*Verifier: Claude (gsd-verifier)*
