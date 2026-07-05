---
phase: 18-stats-design-specs-adr
plan: "03"
subsystem: design-spec
tags: [design-doc, arcade, stack, snake, video-mode-adr, engine-purity]
dependency_graph:
  requires: [16-CONTEXT, 17-CONTEXT, 15-VIDEO-MODE-ADR]
  provides: [DESIGN.md §12.6, DESIGN.md §12.7]
  affects: [DESIGN.md]
tech_stack:
  added: []
  patterns: [§12 bullet-list game-entry format matching §12.3/§12.4 Nonogram/Sudoku entries]
key_files:
  created: []
  modified:
    - DESIGN.md
decisions:
  - "§12.6 Stack: Video Mode adopted (15-VIDEO-MODE-ADR.md amendment 2026-07-02); all haptic/Reduce Motion specs documented as-built"
  - "§12.7 Snake: Video Mode exempt (15-VIDEO-MODE-ADR.md, Accepted 2026-06-26); body-ramp token map and stats shape documented"
  - "Engine purity grep adapted to flat-file paths (not the non-existent Games/*/Engine subdir from roadmap SC5)"
metrics:
  duration: "~4 min"
  completed: "2026-07-05"
  tasks: 2
  files: 1
---

# Phase 18 Plan 03: DESIGN.md §12.6/§12.7 + Milestone-Close Gates Summary

**One-liner:** Authored DESIGN.md §12.6 Stack and §12.7 Snake as-built game-specific entries (Reduce Motion, haptic vocabulary, per-element token maps) and ran three mechanical milestone-close gates (ADR call-site, engine purity, file-size cap).

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write DESIGN.md §12.6 Stack and §12.7 Snake entries | 692dbe6 | DESIGN.md |
| 2 | Run milestone-close mechanical gates (ADR call-site, engine purity, file size) | (no edit — verification only) | — |

---

## Task 2: Mechanical Gate Results

### Gate 1 — ADR Call-Site (SC3, D-12)

`HomeView.swift` `destination(for:)` at lines 392–405 matches the amended ADR (2026-07-02):

- **Stack** (line 397–399): `StackGameView().videoModeAware(minBoardHeight: 480).disableInteractivePop()` — adopted. Comment at line 392–395 explains the amendment rationale (normalized-coordinate engine, per-frame canvas rescale).
- **Snake** (line 401–404): `SnakeGameView().disableInteractivePop()` — exempt. Comment reads: `// NOTE: NO Video Mode modifier — Snake exempt per 15-VIDEO-MODE-ADR.md` with body explaining pixel-derived grid cells + continuous steering.
- **Result:** Faithful to amended ADR. **No edit needed.**

### Gate 2 — Engine Purity (SC5, D-13)

Grep command:
```
grep -nE 'import (SwiftUI|SwiftData)' \
  Games/Stack/StackEngine.swift \
  Games/Stack/StackConfig.swift \
  Games/Snake/SnakeEngine.swift \
  Games/Snake/SnakeConfig.swift
```

**Result: ZERO hits.** All four engine/config files are Foundation-only.

**SC5 grep-path adaptation:** The roadmap SC5 description references `Games/*/Engine` subdirectory paths. These subdirectories do not exist — all engine and config files live flat in `Games/Stack/` and `Games/Snake/`. The grep was run against the actual flat-file paths (also listed in 18-PATTERNS.md Verification Checklist). This is a verification-path adaptation, not a code change. Tracked in 18-CONTEXT as a deferred item.

### Gate 3 — File Size (D-14)

```
wc -l Games/Stack/*.swift Games/Snake/*.swift
```

Full output (sorted by line count):
| Lines | File |
|-------|------|
| 386 | StackBoardCanvas.swift |
| 331 | StackGameView.swift |
| 265 | SnakeViewModel.swift |
| 244 | SnakeGameView.swift |
| 214 | StackEngine.swift |
| 211 | SnakeBoardCanvas.swift |
| 198 | StackViewModel.swift |
| 193 | SnakeEngine.swift |
| 165 | SnakeGameView+Chrome.swift |

**Max: 386 lines (StackBoardCanvas.swift) — within the 400-line cap.** PASS.

---

## DESIGN.md §12 Entries Authored

### §12.6 Stack — content summary

- Video Mode adopted (amendment 2026-07-02): `StackGameView` carries `.videoModeAware(minBoardHeight: 480)`
- No lives chip, no timer chip; score chip = `StackScoreChip` (compact in compact row slot 2)
- Per-layer accent ramp via `StackPalette` — never hardcoded; board background = `background` token
- Perfect-drop celebration (16-CONTEXT D-08): gated by `hapticsEnabled` + `feedbackAnimation`
- Game-over banner = `danger` token (DESIGN.md §2)
- Reduce Motion: pulse → instant fill; game-over → instant cut to danger banner; no screen shake
- Haptic vocabulary: land = `.impact(.light)`, perfect drop = `.light` tick, game over = `.error`, no per-frame
- Stats: `StackStatsCard` — hero High Score, rows Average Score + Runs Played + Best Streak (16-CONTEXT D-10/D-11)

### §12.7 Snake — content summary

- Video Mode exempt (15-VIDEO-MODE-ADR.md, 2026-06-26); remains exempt after 2026-07-02 Stack amendment
- No lives chip, no timer chip; score chip = `SnakeScoreChip` (no compact variant needed)
- Body ramp (17-CONTEXT D-02): head = `accentPrimary`, body fades toward `surface`, food = `success` or fallback; board background = `background` token
- Direction input (17-CONTEXT D-04): swipe + optional D-pad; one direction lock per tick
- Haptic vocabulary: valid direction = `.selection`, eat = `.impact(.light)`, high score = `.success` once per run (D-09), game over = `.error`, no per-frame
- Reduce Motion: death drain + eat cut instantly to banner/state; no screen shake
- Stats: `SnakeStatsCard` — hero High Score, rows Average Score + Runs Played, no streak row

---

## Deviations from Plan

### SC5 Grep-Path Adaptation (Road Adaptation, Not Rule 1-3)

The roadmap SC5 gate description names `Games/*/Engine` subdir paths. These directories do not exist — Stack and Snake ship with flat files in `Games/Stack/` and `Games/Snake/` respectively. The engine purity grep was adapted to the actual file paths. This is a documentation-level clarification (noted in 18-CONTEXT as a deferred item), not a code deviation.

No other deviations — plan executed exactly as written.

---

## Known Stubs

None. This plan is documentation-only (DESIGN.md §12.6/§12.7 + verification); no new UI or data components shipped.

---

## Threat Flags

None. This plan introduces no new network endpoints, auth paths, file access patterns, or schema changes.

---

## Self-Check: PASSED

- [x] DESIGN.md §12.6 Stack present: `grep -q "### 12.6 Stack" DESIGN.md` → found
- [x] DESIGN.md §12.7 Snake present: `grep -q "### 12.7 Snake" DESIGN.md` → found
- [x] Task 1 commit 692dbe6 exists in git log
- [x] Task 2: no code edit (working tree clean after verification)
- [x] All three gates PASS (ADR call-site, engine purity, file-size max=386)
