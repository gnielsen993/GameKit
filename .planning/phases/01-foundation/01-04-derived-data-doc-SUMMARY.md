---
phase: 01-foundation
plan: "04"
subsystem: docs
tags:
  - docs
  - tooling
  - derived-data
  - simulator-hygiene

dependency_graph:
  requires: []
  provides:
    - "Docs/derived-data-hygiene.md — DerivedData and simulator-store hygiene reference"
  affects: []

tech_stack:
  added: []
  patterns:
    - "Docs/ directory established for per-feature reference docs"

key_files:
  created:
    - Docs/derived-data-hygiene.md
  modified: []

decisions:
  - "D-09: Docs-only mitigation for derived-data/simulator hygiene — no automation script until the manual ritual becomes painful"

metrics:
  duration: "~2 minutes"
  completed_date: "2026-04-25"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 01 Plan 04: Derived-Data Hygiene Doc Summary

**One-liner:** Reference doc capturing DerivedData wipe trigger (DesignKit token signature changes) and xcrun simctl uninstall procedure (stale SwiftData store), linking back to CLAUDE.md §8.9 per D-09 docs-only policy.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Docs/derived-data-hygiene.md | 3d3a02a | Docs/derived-data-hygiene.md |

## Acceptance Criteria Results

All 7 criteria passed:

- File exists at `Docs/derived-data-hygiene.md`: PASS
- Line count 57 (in 20-80 range): PASS
- Contains `DerivedData/gamekit-*` wipe command: PASS (1 match)
- Contains `xcrun simctl uninstall` command: PASS (1 match)
- References `com.lauterstar.gamekit` bundle ID: PASS (1 match)
- References `§8.9`: PASS (2 matches)
- References `D-09`: PASS (2 matches)

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- `Docs/derived-data-hygiene.md` exists: CONFIRMED
- Commit 3d3a02a exists in git log: CONFIRMED
- All acceptance criteria: CONFIRMED
