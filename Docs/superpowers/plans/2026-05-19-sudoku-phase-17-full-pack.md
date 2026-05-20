# Sudoku Phase 17 — Full Puzzle Pack Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow `gamekit/gamekit/Resources/SudokuPuzzles.json` from the Phase 14 placeholder (10 per difficulty) to **1500 per difficulty** (~6000 total puzzles, ~1MB JSON). Each batch run = one `--append --time-budget N` invocation of `tools/GenerateSudokuPack`, which atomically writes the grown JSON. Each batch lands as its own `chore(17-NN)` commit so the growth is auditable.

**Architecture:** No new code. Use Phase 14's `tools/GenerateSudokuPack` CLI verbatim. The CLI is already resumable (`--append` reads existing JSON + dedups by hash) and budget-bounded (`--time-budget <minutes>` exits cleanly when the cap hits). Repeat runs across sessions until every difficulty reaches 1500.

**Tech Stack:** `swift run -c release GenerateSudokuPack` against the vendored `SudokuCore` engine.

**Reference design spec:** `Docs/superpowers/specs/2026-05-15-sudoku-integration-design.md` (§4)
**Phase 14 plan (prerequisite):** `Docs/superpowers/plans/2026-05-15-sudoku-phase-14-vendor-engine.md`

---

## What's already in place from Phase 14

- `tools/GenerateSudokuPack/` Swift CLI with the JSON schema + atomic-write + dedup-by-hash + budget bounds.
- `gamekit/gamekit/Resources/SudokuPuzzles.json` populated with 10 entries per difficulty (40 total).

---

## Per-batch task template

Run this loop until all 4 difficulties reach 1500. Each iteration produces one `chore(17-NN)` commit.

### Task NN — Generate batch NN

- [ ] **Step 1: Check current pool fill**

```bash
python3 -c "
import json
with open('gamekit/gamekit/Resources/SudokuPuzzles.json') as f:
    pack = json.load(f)
for d in ['easy','medium','hard','extreme']:
    print(f'{d}: {len(pack[\"puzzles\"][d])}/1500')
"
```

Note the current count per difficulty. If all four are at 1500, Phase 17 is done — skip to Task FINAL.

- [ ] **Step 2: Run a budgeted batch**

From the repo root:

```bash
cd tools/GenerateSudokuPack
swift run -c release GenerateSudokuPack \
    --per-difficulty 1500 \
    --append \
    --time-budget 20 \
    2>&1 | tail -30
cd ../..
```

`--time-budget 20` caps the run at ~20 minutes of wall time. If you have more time available, raise the value (e.g., `--time-budget 60` for a 1-hour batch). The CLI exits cleanly when the budget elapses, writing the grown JSON.

Expected log shape — a header line every 60s showing progress per difficulty:
```
---
  easy     1500/1500 (100%)
  medium   1500/1500 (100%)
  hard      823/1500 ( 54%)
  extreme   201/1500 ( 13%)
  elapsed: 18m22s  budget: 20m
```

- [ ] **Step 3: Re-check pool fill**

Run the Python one-liner from Step 1 again. Note the new counts.

- [ ] **Step 4: Atomic write integrity check**

The CLI uses `data.write(to: tmp, options: .atomic)` + `replaceItemAt` so the destination JSON is never in a partial state on normal exit. Verify by re-running the same Python validator from the Phase 14 plan Task 8 Step 2 (full schema + 81-char string check). If validation passes, commit.

- [ ] **Step 5: Stage + commit the grown JSON**

```bash
git add gamekit/gamekit/Resources/SudokuPuzzles.json
git commit -m "$(cat <<EOF
chore(17-NN): grow Sudoku pack batch NN

After this batch:
  easy:    <count>/1500
  medium:  <count>/1500
  hard:    <count>/1500
  extreme: <count>/1500

Generator time: ~XX min (--time-budget 20).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

Replace `NN` with the batch number (01, 02, 03, …) and fill the actual counts + time.

- [ ] **Step 6: Decide next move**

- If all 4 difficulties hit 1500 → proceed to Task FINAL.
- Otherwise → repeat Task NN as a new batch. Each successive batch only fills the not-yet-saturated difficulties.

---

## Task FINAL — Phase 17 wrap-up

- [ ] **Step 1: Final validation**

```bash
python3 -c "
import json
with open('gamekit/gamekit/Resources/SudokuPuzzles.json') as f:
    pack = json.load(f)
assert pack['schemaVersion'] == 1
for d in ['easy','medium','hard','extreme']:
    entries = pack['puzzles'][d]
    assert len(entries) == 1500, f'{d}: {len(entries)} != 1500'
    for e in entries:
        assert len(e['givens']) == 81
        assert len(e['solution']) == 81
        assert e['givenCount'] == sum(1 for c in e['givens'] if c not in '0.')
print('All 6000 puzzles valid.')
"
```

- [ ] **Step 2: Verify the app builds + bundle contains the full pack**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

The JSON is bundled as a Resources file (auto-picked up by the synchronized root group since Phase 14); no pbxproj change needed.

Optional: launch in simulator → tap Sudoku → confirm a puzzle loads in each difficulty (no need to play; just load).

- [ ] **Step 3: Append Phase 17 entry to release log**

Add a `## Internal changes (17)` section AFTER `## Internal changes (16)` in `Docs/releases/v1.2.md`:

```markdown
## Internal changes (17)
- **Phase 17 — Sudoku pack ramp to 1500/difficulty.** Grew
  `Resources/SudokuPuzzles.json` from the Phase 14 placeholder
  (10/difficulty) to the full v1.2 target (1500/difficulty, 6000
  total puzzles, ~1MB bundle). Generated by repeated
  `swift run GenerateSudokuPack --append --time-budget N` runs of
  the Phase 14 CLI; each batch atomically wrote the grown JSON and
  landed as its own `chore(17-NN)` commit for auditability. Bundle
  resource auto-picked up by the synchronized root group — no
  pbxproj change. Generator source SHA unchanged
  (`cxnielsen/sudokuplus@b02c848`). The `SudokuPuzzlePool` silent-
  recycle path (Phase 15) still applies if a player ever solves
  all 1500 puzzles of one difficulty.
```

- [ ] **Step 4: Final commit**

```bash
git add Docs/releases/v1.2.md
git commit -m "$(cat <<'EOF'
docs(17): Phase 17 release log — Sudoku pack at full 1500/difficulty

The grown pack landed across N chore(17-NN) commits; this entry
documents the final state.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Sizing expectations

Phase 14's CLI generated the 40-puzzle placeholder in **<1 second** in release mode. That's heavily dominated by easy/medium puzzles which take <50ms each; hard and extreme are slower because the technique rater rejects more candidates.

Honest estimate for the full 1500/diff growth:
- Easy: a few minutes
- Medium: ~15–30 min
- Hard: ~30–60 min
- Extreme: ~60–120+ min

Total: somewhere between **2 and 4 hours** of wall time, depending on hardware + dedup rejection rate. Spread across however many `--time-budget` batches are convenient.

If a single difficulty starts showing >300s/puzzle, that's a generator-side regression — STOP and investigate; do not paper over with longer time budgets.

---

## Summary of what this plan delivers

After all batches complete:

1. `gamekit/gamekit/Resources/SudokuPuzzles.json` at 1500 entries per difficulty (6000 total, ~1MB).
2. N `chore(17-NN)` commits showing the growth curve.
3. One `docs(17)` commit closing out the phase with the release log entry.
4. App bundle ships the full pack; `SudokuPuzzlePool` cycles through it normally.

---

## Open items / Phase boundary

Phase 17 closes the v1.2 Sudoku scope. The next milestone (v1.3 or later) can extend with:
- Hints / technique-suggestion UI (was deferred from spec §10)
- Daily Puzzle (deterministic date-seeded selection from the pool)
- 4×4 Beginner board
- Solved-Sudokus gallery (mirror Nonogram's `SolvedNonogramsView`)
- Streak / longest-streak stats

None of these block Phase 17.

---

*End of Phase 17 plan.*
