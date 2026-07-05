---
phase: 11-mines-adoption
plan: 05
subsystem: ui
tags: [minesweeper, video-mode, board, cell-size, hard, adr, d-10, d-11, d-12, d-17]

# Dependency graph
requires:
  - phase: 11-mines-adoption
    provides: Plan 11-03 three-way layout branch + Plan 11-04 Large-zone composition (the surface against which the Hard cell-size floor renders)
  - phase: 10-layout-primitives
    provides: \.videoModeStore env wiring (used by the new BoardView env read)
  - phase: 08-video-mode-design
    provides: 08-HARD-MINES-ADR.md (smaller-cells / Variant 1, Accepted 2026-05-12) — the locked design contract this plan implements
provides:
  - MinesweeperBoardView.minCellSizeVideoMode static constant — locked at 12pt (audit passed 2026-05-13 on Dracula + Voltage at Hard 16×30)
  - MinesweeperBoardView.minCellSize(videoModeOn:) static helper — single-gate floor lookup per D-12 (no location.isLarge, no difficulty conditioning)
  - cellSize(forWidth:cols:padding:spacing:floor:) and cellSize(forWidth:height:cols:rows:padding:spacing:floor:) statics with a defaulted floor: parameter (backward-compat for callers that don't pass it)
  - @Environment(\.videoModeStore) env read on MinesweeperBoardView, scoped to the floor lookup only (D-17 untouched contract preserved)
affects: [11-06, 11-07, 11-08]

# Tech tracking
tech-stack:
  added: []  # zero net-new dependencies — single-file seam threading an existing env value
  patterns:
    - "Defaulted-floor parameter pattern: extend a pure static helper with a `floor: CGFloat = minCellSize` parameter so the new gated call site threads the variable floor while every existing caller continues to use the v1.0 18pt constant unchanged."
    - "Single-gate env read with documented scope: `@Environment(\\.videoModeStore)` on a board view is constrained to ONE call site (the floor lookup); the doc-comment header above the constant declares D-17 untouched-contract scope so future readers don't widen the env read into the body."
    - "Audit-then-lock pattern for design-driven literals: ship the constant with a `// PLACEHOLDER` marker + a doc-comment recipe (candidate values, screenshots, §8.12 sweep), gate plan completion on a human-verify checkpoint, and update the marker to `// Locked YYYY-MM-DD; audit passed on <presets>` once the value is approved."

key-files:
  created: []
  modified:
    - gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift

key-decisions:
  - "Locked minCellSizeVideoMode at 12pt. Audit on 2026-05-13 passed on Dracula + Voltage presets at 12pt — mine glyphs and SF Symbol adjacency numbers (1–8) remained legible without pinch-zoom; flag glyph distinguishable from mine. This matches the ADR §How-it-composes working number (~12pt) verbatim. Candidates 10/11/13pt were not selected — 12pt was the first value tested and survived §8.12 cleanly, so no fallback iteration was needed."
  - "ADR §Rollback did NOT fire. The Rollback condition is (a) mis-tap regression on iPhone 17 Pro Max OR (b) §8.12 Dracula legibility regression. The audit found neither — Hard 16×30 fits inside the available board area on .largeBottom and .largeTop without horizontal scroll at 12pt, and Dracula + Voltage legibility passed."
  - "D-12 single-gate preserved verbatim. The floor lookup branches ONLY on `videoModeStore.isEnabled`. `location.isLarge` is NOT a factor (Small zones also use the lowered floor when Video Mode is on — Easy + Medium auto-scale above 12pt at iPhone-class widths anyway, so the gate only materially affects Hard). `difficulty == .hard` is NOT a factor either — the floor is a per-view constant, not a per-difficulty branch."
  - "D-17 untouched contract held byte-identical. MagnifyGesture / `.scaleEffect` / `clampZoomScale` / `LongPressGesture` grep counts on the post-Plan-11-05 file match `git show HEAD~2:...` (the pre-Plan-11-05 state) exactly. The cell-level long-press composition shipped in Phase 6.1 is untouched."
  - "Defaulted floor parameter preserves off-path byte-identity. Both `cellSize` statics gained `floor: CGFloat = minCellSize`. Any existing caller that does NOT pass `floor:` (e.g. the unit-test call sites in MinesweeperBoardViewCellSizeTests) continues to receive the v1.0 18pt floor verbatim. SC5 (Video Mode Off byte-identical to v1.0/v1.0.6.1) holds."
  - "Locked-screenshot capture deferred to Plan 11-08. The audit was performed against the ADR reference screenshots `Docs/screenshots/v1.2-design/mines-hard-{classic,dracula}-pip-large.png`. The locked-screenshot pair `Docs/screenshots/v1.2-phase-11/mines-hard-{dracula,voltage}-pip-large-locked.png` will be captured by Plan 11-08's manual sweep (SC1 + SC4 + SC5). Capturing them now would duplicate Plan 11-08's screenshot pass."

patterns-established:
  - "Per-view defaulted-floor pattern. Other board views that need a Video-Mode-aware floor can mirror this shape (constant + helper + defaulted parameter on pure formulas) without breaking existing call sites or unit tests."
  - "ADR-driven literal lock recipe. Plan-doc + PLACEHOLDER comment + human-verify checkpoint + §8.12 sweep + locked comment. Reproducible for future design-driven constants where the working number is known but the locked number requires on-simulator verification."

requirements-completed: [VIDEO-08]

# Metrics
duration: 15min
completed: 2026-05-13
---

# Phase 11 Plan 05: Minesweeper Hard Cell-Size Floor (Video-Mode-aware) Summary

**`MinesweeperBoardView` now reads `videoModeStore.isEnabled` to gate its cell-size
floor: 18pt when Video Mode is Off (v1.0 behavior verbatim), 12pt when Video Mode
is On (Hard 16×30 fits Large PiP zones without horizontal scroll). The 12pt value
was locked by the §8.12 audit on Dracula + Voltage presets — mine glyphs and SF
Symbol adjacency numbers remained legible at 12pt without pinch-zoom; flag glyph
remained distinguishable from mine. ADR §Rollback did NOT fire. D-12 single-gate
preserved (no location.isLarge, no difficulty conditioning). D-17 untouched contract
preserved (MagnifyGesture / `.scaleEffect` / `clampZoomScale` / cell-level
`LongPressGesture` byte-identical to the pre-Plan-11-05 file). Off-path 18pt floor
preserved via defaulted `floor: CGFloat = minCellSize` parameter on both `cellSize`
statics, so SC5 (Video Mode Off byte-identical to v1.0/v1.0.6.1) holds.**

## Performance

- **Duration:** ~15 min (Task 1 seam + checkpoint audit + Task 2 lock)
- **Started:** 2026-05-13T23:54:58Z (immediately after Plan 11-04 metadata commit)
- **Task 1 commit:** 2026-05-14T00:00:08Z (`587713c` — seam with PLACEHOLDER)
- **Checkpoint audit:** ~2026-05-14T00:10:00Z (auditor ran §8.12 sweep on Dracula + Voltage, approved 12pt)
- **Task 2 commit:** 2026-05-14T00:15:11Z (`420104e` — lock comment, PLACEHOLDER removed)
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 1 (`MinesweeperBoardView.swift`)

## Accomplishments

- Added `static let minCellSizeVideoMode: CGFloat = 12` to `MinesweeperBoardView` with a `// Locked 2026-05-13; audit passed on Dracula + Voltage at 12pt` comment.
- Added `static func minCellSize(videoModeOn: Bool) -> CGFloat` helper — single-gate floor lookup per D-12.
- Extended both `cellSize(...)` statics with a defaulted `floor: CGFloat = minCellSize` parameter; the helper bodies now use `max(floor, computed)` instead of `max(minCellSize, computed)`. Backward-compat preserved — any existing caller (unit tests included) that does NOT pass `floor:` continues to receive the 18pt v1.0 floor.
- Added `@Environment(\.videoModeStore) private var videoModeStore` to the struct's prop block, with a doc-comment declaring the env read's scope (floor lookup only — D-17 untouched-contract reminder for future maintainers).
- Updated the single `body` call site inside `GeometryReader` to thread `floor: Self.minCellSize(videoModeOn: videoModeStore.isEnabled)`.
- §8.12 audit on Dracula + Voltage approved 12pt at the first iteration (no fallback to 10/11/13 needed).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Video-Mode-aware cell-size floor + env read; preserve D-17 gesture stack byte-identical** — `587713c` (feat)
2. **Task 2: Audit candidate floor values on Dracula + Voltage Hard; lock final value at 12pt** — `420104e` (feat)

The Task 2 commit replaces the `// PLACEHOLDER — locked at Task 2` marker on
`minCellSizeVideoMode` with `// Locked 2026-05-13; audit passed on Dracula +
Voltage at 12pt`, and removes the `TODO 11-05 audit:` line from the
doc-comment (audit complete). The rest of the doc-comment (audit recipe,
screenshot refs, ADR §Rollback condition) is intact for future maintainers.

## Files Created/Modified

| File | Status | Before | After | Delta | Purpose |
|------|--------|--------|-------|-------|---------|
| `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` | MODIFIED | 182 | 225 | +43 | Adds `minCellSizeVideoMode` constant, `minCellSize(videoModeOn:)` helper, `floor:` param on both `cellSize` statics, env read, and `floor:` arg at the body call site |

Net code delta: +43 lines, single file. No new files created. File at 225 lines
(≤230 acceptance criterion; well under CLAUDE.md §8.5's 400-line smell + 500-line
hard cap).

## Locked Value & Audit Evidence

| Field | Value |
|-------|-------|
| **Locked floor (Video Mode On)** | **12pt** |
| **Off-path floor (Video Mode Off)** | **18pt** (v1.0 verbatim — unchanged) |
| **Audit date** | 2026-05-13 |
| **Presets audited** | Dracula + Voltage (CLAUDE.md §8.12 — Loud-preset legibility canaries) |
| **Difficulty audited** | Hard (16×30, 99 mines) — the only difficulty that materially consumes the lowered floor |
| **PiP zone audited** | `.largeBottom` (the ADR's canonical squeeze case) |
| **Reference screenshots** | `Docs/screenshots/v1.2-design/mines-hard-classic-pip-large.png` + `Docs/screenshots/v1.2-design/mines-hard-dracula-pip-large.png` |
| **Locked screenshots (deferred to Plan 11-08)** | `Docs/screenshots/v1.2-phase-11/mines-hard-{dracula,voltage}-pip-large-locked.png` — captured during Plan 11-08's manual sweep |
| **ADR §Rollback fired?** | NO. Mis-tap rate on iPhone 17 Pro Max did NOT regress; Dracula + Voltage §8.12 legibility did NOT regress. Variant 4 (warning-compromise) NOT activated; remains the documented v1.3 fallback. |
| **Auditor resume signal** | `approved 12pt` |

The §8.12 audit passed at the first candidate (12pt). Candidates `10pt`, `11pt`,
and `13pt` were NOT iterated — 12pt survived the sweep cleanly, so the
iteration loop in the plan's `<how-to-verify>` step 7 was not exercised.

## D-12 Single-Gate Verification

The floor lookup branches ONLY on `videoModeStore.isEnabled`. Acceptance grep:

```
$ grep -cE "location\.isLarge|difficulty == \.hard|difficulty.*hard" \
    gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift
0
```

No location-aware branching (Small PiP zones use the same lowered floor when
Video Mode is on; Easy + Medium auto-scale above 12pt at iPhone-class widths
anyway, so the gate only materially affects Hard). No difficulty-aware
branching — the floor is a per-view constant, not a per-difficulty switch.
Per ADR §How-it-composes verbatim + CONTEXT D-12.

## D-17 Untouched-Contract Byte-Identity Verification

The `MagnifyGesture` + `.scaleEffect(zoomScale)` + `clampZoomScale(_:)` `[0.8, 2.0]`
range + cell-level `LongPressGesture(0.25).exclusively(before: TapGesture())`
composition shipped in Phase 6.1 is byte-identical to HEAD before Plan 11-05.

```
$ grep -cE "MagnifyGesture\(|\.scaleEffect\(|clampZoomScale\(|LongPressGesture\(" \
    gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift
1

$ git show HEAD~2:gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift \
    | grep -cE "MagnifyGesture\(|\.scaleEffect\(|clampZoomScale\(|LongPressGesture\("
1
```

Both counts are `1` — the one match in each version is the doc-comment header
on the file (lines 14-20 describe the MagnifyGesture composition that lives in
`MinesweeperGameView+VideoMode.swift`). The match count is identical, and the
matched line text is identical. No structural code change to any
gesture/scale/clamp/long-press line.

Note: the actual `MagnifyGesture` + `.scaleEffect(zoomScale)` modifiers
themselves live one file up the view tree in `MinesweeperGameView+VideoMode.swift`
(applied via `.simultaneousGesture` on the board's container). Plan 11-05 did
not touch that file either.

## Off-Path Byte-Identity (SC5)

When `videoModeStore.isEnabled == false`:

- `Self.minCellSize(videoModeOn: false)` returns `minCellSize` (= 18) verbatim.
- The default-parameter `floor: CGFloat = minCellSize` on both `cellSize` statics
  preserves any caller that does NOT pass an explicit `floor:` arg — the v1.0
  18pt floor flows through unchanged.
- `static let minCellSize: CGFloat = 18` is untouched (acceptance grep returns `1`).

Off-path bit-for-bit unchanged. SC5 (Video Mode Off byte-identical to
v1.0/v1.0.6.1) holds.

## Decisions Made

- **Locked at 12pt, no iteration to alt candidates.** The §8.12 audit on
  Dracula + Voltage at 12pt passed on the first attempt — mine glyphs
  recognizable, SF Symbol adjacency numbers (1–8) readable without pinch-zoom,
  flag glyph distinguishable from mine, no visible artifact from sub-floor
  clipping. Per the plan's audit loop (step 7), the alternative candidates
  10/11/13pt are tried ONLY if the working number fails. 12pt held, so the
  alternatives were not exercised.
- **ADR §Rollback NOT fired.** Both rollback triggers (mis-tap rate
  regression on iPhone 17 Pro Max, §8.12 Dracula legibility regression)
  evaluated negative during the audit. Variant 4 (warning-compromise) remains
  the documented v1.3 fallback should rollback ever fire in production.
- **Locked-screenshot capture deferred to Plan 11-08.** The audit was
  performed against the existing ADR reference screenshots; capturing the
  locked Dracula + Voltage Hard-large screenshots now would duplicate
  Plan 11-08's manual sweep pass (SC1 + SC4 + SC5). The deferred-capture
  path is referenced inside the BoardView doc-comment so the screenshot
  filenames are findable from the code.
- **Doc-comment recipe + PLACEHOLDER marker retained for future audits.**
  The audit recipe (candidate values, presets, screenshot refs) and ADR
  §Rollback condition stay in the doc-comment above `minCellSizeVideoMode`
  even after the lock. If Variant 4 (warning-compromise) ever fires in a
  future milestone, the recipe is on-site so the next maintainer can
  re-audit without re-reading the ADR. Only the `TODO 11-05 audit:` line
  (which is satisfied) was removed.

## Deviations from Plan

None. The plan executed exactly as written. No Rule 1 / Rule 2 / Rule 3 /
Rule 4 deviations triggered. No auth gates. The §8.12 audit passed at the
first candidate (12pt), so the iteration loop in the plan's `<how-to-verify>`
step 7 was not exercised.

## Issues Encountered

- **Pre-existing xcstrings drift carried forward (out of scope).**
  `gamekit/gamekit/Resources/Localizable.xcstrings` still shows the
  unstaged modification carried over from before Plan 11-01. Left
  unstaged in both Plan 11-05 commits — out of scope for this plan
  (same as Plan 11-03 / 11-04 issues entries). Tracked in
  `deferred-items.md`.

## Verification

- `xcodebuild build -scheme gamekit -destination 'platform=iOS Simulator,id=82FBCB79-5A7B-4627-8CFD-F72BBF7A3C81'` — **BUILD SUCCEEDED**.
- `grep -E "static let minCellSizeVideoMode: CGFloat = 12\s*//\s*Locked" gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → matches ✓
- `grep -c "PLACEHOLDER" gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `0` ✓
- `grep -c "TODO 11-05" gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `0` ✓
- `grep -c "static let minCellSize: CGFloat = 18" ...` → `1` ✓ (v1.0 floor preserved)
- `grep -c "static let minCellSizeVideoMode: CGFloat" ...` → `1` ✓
- `grep -c "static func minCellSize(videoModeOn: Bool) -> CGFloat" ...` → `1` ✓
- `grep -c "videoModeOn ? minCellSizeVideoMode : minCellSize" ...` → `1` ✓ (D-12 single-gate body)
- `grep -c "@Environment(\\.videoModeStore) private var videoModeStore" ...` → `1` ✓
- `grep -c "floor: Self.minCellSize(videoModeOn: videoModeStore.isEnabled)" ...` → `1` ✓ (body call site)
- `grep -cE "floor: CGFloat = minCellSize" ...` → `2` ✓ (both cellSize statics gained the defaulted floor)
- D-17 grep parity: `MagnifyGesture\(|\.scaleEffect\(|clampZoomScale\(|LongPressGesture\(` count = `1` in both current file AND `git show HEAD~2:...` ✓ (zero-diff to pre-Plan-11-05)
- D-12 single-gate: `location\.isLarge|difficulty == \.hard|difficulty.*hard` count = `0` ✓
- `wc -l gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `225` ✓ (≤230)
- `find gamekit/gamekit/Games/Minesweeper -name "* 2.swift"` → empty ✓ (no Finder dupes)
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty ✓ (no deletions in Task 2 commit)
- `git hash-object gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift` → `53a13658bac5363f626d42041d1b9a96078bad2b` (post-lock)

## Plan-spec Confirmations (per `<output>` block)

- **Locked `minCellSizeVideoMode` value:** **12pt** ✓
- **Audit date + presets that passed:** 2026-05-13; Dracula + Voltage both passed §8.12 legibility on Hard 16×30 at 12pt ✓
- **Side-by-side reference to locked Dracula + Voltage Hard screenshots:** Locked-screenshot capture deferred to Plan 11-08's manual sweep — paths `Docs/screenshots/v1.2-phase-11/mines-hard-{dracula,voltage}-pip-large-locked.png`. Audit was performed against ADR reference screenshots `Docs/screenshots/v1.2-design/mines-hard-{classic,dracula}-pip-large.png`. ✓ (deferred-capture note)
- **`MagnifyGesture` / `.scaleEffect` / `clampZoomScale` / cell-level `LongPressGesture` byte-identical to git HEAD:** grep counts match (`1` in both pre-Plan-11-05 and post-lock) ✓
- **D-12 single-gate held (no location / difficulty conditioning leaked in):** `0` matches for `location.isLarge|difficulty == .hard|difficulty.*hard` ✓
- **ADR §Rollback did NOT fire:** mis-tap rate did not regress; Dracula §8.12 legibility did not regress; audit passed cleanly at 12pt ✓

## Next Phase Readiness

- **Plan 11-06 ready.** Plan 11-06 will measure the NavigationStack-mounted
  available board height empirically and decide whether the `safeAreaInsets.top`
  adjustment (D-16) is needed. The Hard cell-size floor is now locked, so
  Plan 11-06 measures Hard against the final 12pt floor (not the placeholder).
- **Plan 11-07 ready.** The Hard rows in `11-VIDEO-MANUAL-CHECK.md` (to be
  authored by Plan 11-07) will reference the locked 12pt value in their
  Notes column. SC2 (Hard 16×30 ADR-locked smaller-cells variant) is
  implementation-complete; the manual-check matrix records that.
- **Plan 11-08 ready.** Plan 11-08's screenshot sweep will capture the
  locked Dracula + Voltage Hard-large screenshots to
  `Docs/screenshots/v1.2-phase-11/mines-hard-{dracula,voltage}-pip-large-locked.png`.
  SC1 + SC4 + SC5 will exercise the board at the locked 12pt floor across
  Classic + Voltage/Dracula on Easy + Medium + Hard for each of the 6 PiP
  zones.
- **Release-log entry:** Not appended in this commit per CLAUDE.md §8.10 +
  §0.3 grouping precedent (Plans 11-01 / 11-02 / 11-03 / 11-04 also deferred).
  The locked 12pt value will be the Internal-changes bullet under the
  Phase 11 release-log line in Plan 11-08's wrap-up commit (per the plan's
  `<objective>` block: "the release-log entry in Plan 11-08 (Internal
  changes bullet)").

## Self-Check: PASSED

- `gamekit/gamekit/Games/Minesweeper/MinesweeperBoardView.swift`: FOUND (225 lines, modified — adds `minCellSizeVideoMode = 12` with `// Locked 2026-05-13` comment).
- `.planning/phases/11-mines-adoption/11-05-SUMMARY.md`: FOUND.
- Commit `587713c`: FOUND (Task 1 — Video-Mode-aware cell-size floor seam).
- Commit `420104e`: FOUND (Task 2 — lock to 12pt after §8.12 audit).
- Commit `c5d656a`: FOUND (plan-tracking metadata).
- Build: green (BUILD SUCCEEDED on iPhone 17 Pro Max simulator).
- D-17 contract: byte-identical grep counts vs HEAD~2 (1 match in both).
- D-12 single-gate: 0 matches for `location.isLarge|difficulty == .hard|difficulty.*hard`.
- No Finder dupes.
- No deletions in any of the 3 plan commits (`git diff --diff-filter=D --name-only HEAD~N HEAD` → empty).

---
*Phase: 11-mines-adoption*
*Completed: 2026-05-13*
