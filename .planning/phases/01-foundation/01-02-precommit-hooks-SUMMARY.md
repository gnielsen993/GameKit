---
phase: 01-foundation
plan: 02
subsystem: infra
tags: [git-hooks, bash, lint, token-discipline, design-system]

# Dependency graph
requires: []
provides:
  - Pre-commit hook that rejects hardcoded Color literals in Games/ and Screens/
  - Pre-commit hook that rejects numeric cornerRadius and padding literals in Games/ and Screens/
  - Pre-commit hook that rejects Finder-dupe (* 2.swift) files anywhere
  - scripts/install-hooks.sh bootstrap for per-developer hook installation
  - git core.hooksPath wired to .githooks/
affects:
  - All subsequent plans that commit Swift files under Games/ or Screens/

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure bash pre-commit hook committed to .githooks/ (no lefthook/husky dependency)
    - Bootstrap script (scripts/install-hooks.sh) wires git core.hooksPath on developer clone

key-files:
  created:
    - scripts/install-hooks.sh
    - .githooks/pre-commit
  modified: []

key-decisions:
  - "Pure shell + core.hooksPath bootstrap chosen over lefthook/husky to match no-extra-dependency posture"
  - "Hook scope limited to Games/ and Screens/ only; App/ and Core/ explicitly excluded (legitimate Color imports there)"

patterns-established:
  - "Pattern: git hooks committed under .githooks/ + developer runs scripts/install-hooks.sh once after clone"
  - "Pattern: grep-based token-discipline gate on staged file diffs (not full-file scan)"

requirements-completed: [FOUND-07]

# Metrics
duration: 4min
completed: 2026-04-25
---

# Phase 01 Plan 02: Pre-commit Hooks Summary

**Pure-bash pre-commit gate enforcing DesignKit token discipline (Color literals, cornerRadius integers, padding integers) in Games/ and Screens/, plus Finder-dupe rejection, wired via git core.hooksPath**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-25T17:31:33Z
- **Completed:** 2026-04-25T17:35:41Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `scripts/install-hooks.sh` (5-line bootstrap: sets core.hooksPath, chmods hook, prints confirmation)
- Created `.githooks/pre-commit` (36 lines) enforcing three token-discipline rules + Finder-dupe gate
- Wired `core.hooksPath = .githooks` via `bash scripts/install-hooks.sh` — hook is now active for all subsequent plan commits
- Smoke-tested all 5 fixture scenarios with documented exit codes (see below)

## Smoke-Test Results

| Fixture | Content / Scenario | Expected Exit | Observed Exit | Result |
|---------|-------------------|---------------|---------------|--------|
| 1 | `HomeView 2.swift` added to Screens/ | 1 (reject) | 1 | PASS — "Finder-dupe files detected" message |
| 2 | `Color.red` in Screens/__lint_fixture.swift | 1 (reject) | 1 | PASS — "hardcoded Color literal" message |
| 3 | `cornerRadius: 12` in Screens/__lint_fixture.swift | 1 (reject) | 1 | PASS — "numeric cornerRadius literal" message |
| 4 | `import SwiftUI` only in Screens/__lint_fixture.swift | 0 (pass) | 0 | PASS — no violations detected |
| 5 | `Color.red` in App/__lint_fixture.swift | 0 (pass) | 0 | PASS — App/ excluded from hook scope |

All fixture files were cleaned from disk and git index before committing.

## Task Commits

1. **Task 1: Create scripts/install-hooks.sh bootstrap** - `9f56859` (chore)
2. **Task 2: Create .githooks/pre-commit and smoke-test** - `fbfb002` (chore)

**Plan metadata:** *(pending final docs commit)*

## Files Created/Modified
- `scripts/install-hooks.sh` - One-time bootstrap: `git config core.hooksPath .githooks` + chmod
- `.githooks/pre-commit` - Token-discipline gate: Finder-dupe rejection + Color/cornerRadius/padding literal checks scoped to Games/ and Screens/

## Decisions Made
- Pure shell chosen over lefthook/husky — matches "no extra dependency" posture (CONTEXT line 44)
- Hook scope explicitly limited to `^gamekit/gamekit/(Games|Screens)/.*\.swift$` path regex; App/ and Core/ excluded
- Finder-dupe check uses `--diff-filter=A` (added files only), matching CLAUDE.md §8.7's use case (Xcode duplicating files)
- `echo -e` used for newline expansion in error output; acceptable for macOS/Linux zsh+bash targets

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
Developers who clone this repo must run `bash scripts/install-hooks.sh` once to wire the hook locally. This sets `core.hooksPath = .githooks` in their local `.git/config`. The hook itself is committed and enforced as of this plan's commits.

## Next Phase Readiness
- Pre-commit gate is live — all subsequent plans commit through it
- Plan 03 (shell screens) will commit Swift files under Screens/ through this gate automatically
- Hook will catch any token-discipline drift introduced in upcoming plans

## Self-Check: PASSED

- scripts/install-hooks.sh: FOUND, executable, syntax valid
- .githooks/pre-commit: FOUND, executable, syntax valid, 36 lines
- Commit 9f56859: FOUND (Task 1)
- Commit fbfb002: FOUND (Task 2)
- git config core.hooksPath: .githooks (active)
- No fixture file leakage confirmed

---
*Phase: 01-foundation*
*Completed: 2026-04-25*
