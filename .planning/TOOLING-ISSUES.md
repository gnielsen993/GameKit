# Tooling Issues

Local agent/toolchain issues that affect development sessions but are outside
the GameDrawer app release scope.

Repo-health work (structure, CI, gitignore, file-size debt) lives in
`Docs/ENGINEERING-BACKLOG.md`, not here.

## Open

- [ ] 2026-08-01 — Simulator dies at test-runner launch (`Mach error -308`)
  - Symptom: `xcodebuild test` aborts before any test executes, with
    `Failed to install or launch the test runner. (Underlying Error: The
    operation couldn't be completed. (Mach error -308 - (ipc/mig) server
    died))`. The device shows `Shutdown` in `simctl list` immediately after.
  - Fix (worked all three times it happened in one session):
    ```bash
    xcrun simctl shutdown all; pkill -9 -f CoreSimulator; pkill -9 -f Simulator.app
    sleep 6 && xcrun simctl boot <device-id> && xcrun simctl bootstatus <device-id> -b
    ```
    Then re-run `xcodebuild test`.
  - **Not the same as §8.9.** CLAUDE.md §8.9 covers a crash *during* host-app
    launch with `NSStagedMigrationManager` in the report, fixed by
    `simctl uninstall`. This one kills the runner *before* it connects, the
    app bundle is irrelevant, and uninstalling does nothing. Both were hit in
    the same session; applying the §8.9 fix here wastes a cycle.
  - Also seen: the simulator shuts itself down after a completed test run, so
    a follow-up `simctl install` / `launch` fails with
    `Unable to lookup in current state: Shutdown` until it is booted again.
    Boot explicitly before any install/launch verification step.
  - Impact: cost roughly twenty minutes across three occurrences in the
    2026-08-01 session. Recurring rather than one-off.
  - App impact: none — environmental. No code change reproduces or fixes it.

- [ ] 2026-06-24 — Invalid Claude cowork schedule skill metadata
  - Symptom: session startup reports `Skipped loading 1 skill(s) due to invalid SKILL.md files.`
  - Path: `/Users/gabrielnielsen/.codex/plugins/cache/claude-cowork/anthropic-skills/1.0.0/skills/schedule/SKILL.md`
  - Error: invalid YAML, `did not find expected key at line 2 column 110, while parsing a block mapping`
  - Impact: the `schedule` skill is unavailable until the cached plugin skill file is fixed or refreshed.
  - App impact: none known; this is local agent tooling, not GameKit code.

