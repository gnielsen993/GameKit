# Engineering Backlog — GameKit (GameDrawer)

Engineering-health work: structure, tooling, coverage, and process debt.
Opened 2026-07-26 from a three-repo standards audit (ParkedUp, FitnessTracker,
GameKit) that reviewed agent rules, docs, release flows, ~41k lines of Swift,
the test suite, and git history adherence.

**Scope boundary.** Not the product backlog. Game roadmap and milestone scope
live in `.planning/ROADMAP.md`, `.planning/UPCOMING-GAMES.md`, and
`.planning/v2.0-VISION.md`. Local agent/toolchain problems live in
`.planning/TOOLING-ISSUES.md`. This file is repo health only.

Audit standing at open: GameKit scored highest of the three overall (8.3/10)
and originated the ecosystem's best practices — the pre-commit hook, the §0.1
dated status table, and `DESIGN.md` as a visual constitution were all ported
outward from here.

---

## P1

### 1. No CI
No `.github/workflows` exists. The pre-commit hook is the only automated gate
and is per-clone local config (`core.hooksPath`), so it cannot verify a build
on a machine you are not sitting at.

Minimum: build + test on push and PR, macOS runner, unambiguous simulator
destination — **not** `iPhone 16`, see §0.5 and item 5 below.

GameKit-specific wrinkle: vendored Swift packages under `Packages/SudokuCore`
and the `Tools/GenerateSudokuPack` CLI have their own test targets. Decide
whether they run in the same job or a separate one. Unlike FitnessTracker,
GameKit has no local-path sibling dependency, so its CI is the simplest of the
three to stand up — worth doing here first and porting the pattern outward.

Deferred 2026-07-26 pending a scope decision on signing and runner cost.

### 2. `.gitignore` is 10 lines and misses build output
Current contents cover only `.DS_Store`, `xcuserdata/`, `*.xcuserstate`,
`tools/nonogram/__pycache__/`, and `.claude/`. Missing: `DerivedData/`,
`build/`, `*.ipa`, `*.xcarchive`, `.swiftpm/`, and a general `__pycache__/` /
`*.pyc` (the current entry is a single hardcoded path, and it is lowercase
`tools/` while the real directory is `Tools/` — it only matches today because
macOS sets `core.ignorecase`).

For comparison FitnessTracker's is 77 lines and ParkedUp's is 79. Nothing is
currently mis-tracked, so this is prevention, not cleanup.

### 3. `.gitignore` excludes `.claude/` wholesale
This means project skills can never be shared or version-controlled.
FitnessTracker tracks `.claude/skills/sketch-findings-fitnesstracker/` (SKILL.md,
references, and HTML sources) and auto-loads it during UI work via CLAUDE.md
§11 — genuinely useful, and impossible here.

Fix: ignore only the local-config parts (`.claude/settings.local.json`,
`.claude/scheduled_tasks.lock`, `.claude/worktrees/`) and allow
`.claude/skills/` to be tracked. GameKit has the richest design system of the
three (`DESIGN.md`, 13 sections, the §12.5 new-game checklist) and is the
repo most likely to benefit from a committed design skill.

---

## P2

### 4. `NonogramViewModel.swift` violates the §8.5 hard cap
573 lines against a **500-line hard cap** — the only true violation of an own
stated rule in the repo. Eleven more files sit between 400 and 500 (the §8.1
soft cap), heavily concentrated in Solitaire and the Video Mode extensions:

```
573  Games/Nonogram/NonogramViewModel.swift        <- over the §8.5 hard cap
492  Games/Solitaire/FreeCellViewModel.swift
490  Games/Minesweeper/MinesweeperGameView+VideoMode.swift
488  Screens/StatsView.swift
486  Games/Merge/MergeGameView+VideoMode.swift
481  Games/Sudoku/SudokuViewModel.swift
452  Games/Solitaire/SolitaireViewModel.swift
434  Screens/HomeView.swift
433  Games/Minesweeper/MinesweeperViewModel.swift
416  Games/Nonogram/NonogramGameView+VideoMode.swift
407  Games/Solitaire/FreeCellGameView.swift
405  Games/Solitaire/SolitaireGameView.swift
```

Split Nonogram by concern per §8.1 — the hint system and the slide-gesture work
(both WIP as of `2416949`) are the natural seams. The `+VideoMode` extensions
already demonstrate the right pattern; apply it to the view models.

### 5. `iPhone 16` appears in `.planning/` build commands
Several archived plan files under `.planning/milestones/v1.2-phases/` carry
`xcodebuild` invocations with dead `~/Desktop/GameKit` paths, and 61 files
reference the old layout. Left deliberately unfixed on 2026-07-26 — they are
historical records and rewriting them would falsify the record.

The risk is a session copying a command out of an old plan. §0.5 now documents
the verified command; if that turns out not to be enough, add a banner to the
`.planning/` README rather than editing the archived plans.

### 6. `.planning/STATE.md` progress block is internally inconsistent
Reports `status: completed` alongside `percent: 75` and `completed_phases: 3`
of `total_phases: 4`, plus `completed_plans: 67` against `total_plans: 22`.
CLAUDE.md §0.2 sends every "where are we" question to STATE.md first, so a
self-contradicting block misleads at exactly the moment it is trusted most.

### 7. `Tools/` CLI utilities print outside the §8.17 carve-out
`Tools/GenerateSudokuPack` and the `Tools/nonogram/*.py` scripts write to
stdout. That is correct for a CLI — but §8.17's carve-out names only
`ScreenshotSeeder`, `DummyDataSeeder`, and `AppStartupController`, and the
pre-commit hook scopes its check to `gamekit/gamekit/(Games|Screens|Core|App)/`
so `Tools/` is untouched either way. Worth a sentence in §8.17 stating that
`Tools/` is out of scope by design, so nobody "fixes" it later.

Also: `Tools/nonogram/__pycache__/` is untracked but present on disk; folded
into item 2.

---

## Done — 2026-07-26

Recorded so it is not re-litigated. Detail in `Docs/releases/v1.5.1.md`.

- Dead `~/Desktop` paths repointed to `~/Developer` in `WRAPUP.md` and CLAUDE.md
  §0.4/§8.15. **The Step 2d deploy was an `&&` chain starting with `cd` into a
  missing directory** — it short-circuited and no-oped while appearing to
  succeed. Now separate statements behind an explicit failure guard, plus a
  push-confirmation check. `Tools/nonogram/finalize.py` made repo-relative via
  `__file__` rather than re-hardcoded.
- Pre-commit hook widened from `Games/`+`Screens/` to also cover `Core/`+`App/`,
  matching §1 which states the rule with no directory carve-out. Three
  token-source files carry documented Color-only exemptions.
- Hook bug fixed: `for f in $staged` word-split on filenames containing spaces —
  and `X 2.swift` is exactly the Finder-dupe case the first check exists to
  catch. Replaced with NUL-delimited iteration. Also added the `print()` check,
  a line-level `// token-exempt: <reason>` hatch matching FitnessTracker, and
  widened the dupe pattern to any ` <n>.swift`.
- `AGENTS.md` collapsed into a git symlink to CLAUDE.md (mode 120000). The
  hand-maintained mirror had already drifted — it still declared "MVP scope:
  Minesweeper only" after v1.5 shipped with Stack and Snake. Unique surviving
  content was folded in first, including a new §0.5 Commands section: CLAUDE.md
  had documented **no build command at all**, and AGENTS.md's was wrong on all
  three of scheme name, project path, and destination.
- `Core/AppLog.swift` added and §8.17 recorded: centralized `os.Logger`
  namespace replacing inline `Logger(subsystem:category:)` construction and
  `print()`. `NonogramLibrary` and `SFXPlayer` converted; emoji severity markers
  dropped. Dev seeders keep `print()` under a documented carve-out.
