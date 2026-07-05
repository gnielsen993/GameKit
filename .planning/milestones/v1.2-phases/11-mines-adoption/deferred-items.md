# Phase 11 — Deferred Items

Out-of-scope discoveries during execution; not fixed in this phase.

## Localizable.xcstrings pre-existing drift (Plan 11-01)

Date: 2026-05-13
Plan that observed: 11-01

The repo had uncommitted modifications to
`gamekit/gamekit/Resources/Localizable.xcstrings` at the start of
Plan 11-01 (3 new key stubs: `"2048 · Classic"`,
`"Drawer open. Tap a mode to play, or tap again to close."`,
`"Infinite · Endless"`). These are leftover from an earlier session
and unrelated to the chip-extraction plan. Left unstaged per
CLAUDE.md §8.10 (commit discipline — do not bundle unrelated
changes). Resolve in a separate sweep commit before next plan.
