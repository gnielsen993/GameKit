# Internal Release Logs

Per-version release notes for **CorePlay (CorePlay Arcade)** iOS app.
Scope = anything that ships in a `MARKETING_VERSION` bump.

Mirrors the convention used in the sibling repos (ParkedUp,
FitnessTracker, DesignKit) so any AI session crossing repos sees the
same shape.

## How to use

- Version source: `MARKETING_VERSION` in
  `gamekit/gamekit.xcodeproj/project.pbxproj`.
- Create one file per release: `vX.Y.Z.md` (or `vX.Y.md` if the patch
  digit is unused).
- Use [`TEMPLATE.md`](TEMPLATE.md) as the starting point.
- Keep entries factual, brief, bullet-pointed.
- For every significant change (feature, fix, behavior shift) during
  a version, append to that version's file in the same commit as the
  code change.
- A new release file is opened when `MARKETING_VERSION` is bumped.

## Sections in each file

- **Summary** — one or two sentences on the release theme
- **User-facing changes** — what a player notices
- **Internal changes** — engine / structure / refactors
- **Fixes** — bug fixes (with root cause when non-obvious)
- **Risks / notes** — schema changes, migration concerns, manual steps
- **QA checklist** — pre-ship verification steps

## What NOT to put here

- Self-explanatory commits, comment tweaks, doc-only changes
- Per-file modification lists (commit history covers that)
- Anything that didn't actually ship in this `MARKETING_VERSION`

## Related artifacts

- Live phase / milestone status: `.planning/STATE.md`
- Milestone audits: `.planning/v{X.Y}-MILESTONE-AUDIT.md`
- Recent commits: `git log --oneline -20`
- Pinned project facts (display name, brand, milestone label):
  CLAUDE.md / AGENTS.md §0.1

The milestone audit and the per-version release log are complementary:
the audit asks "did v1.0 satisfy the original intent?", the release log
asks "what shipped, in what order, and what should QA check?".

## Entries

- `v1.0.md` — first public release (in progress)
