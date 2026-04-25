# Derived-Data and Simulator Hygiene

Two unrelated kinds of "ghost build" issues bite this project. Both have
cheap manual fixes — escalation to an automation script happens only if
the ritual becomes painful (per Phase 1 D-09).

## When to wipe DerivedData

**Symptom:** Xcode reports "ghost" build errors that disappear after a
clean build, or the same source file compiles in one Xcode session and
fails in another with no code change between.

**Most common trigger here:** a DesignKit token signature changed
(e.g. `theme.spacing.l` was added or renamed in `../DesignKit`) and
the cached module fingerprint disagrees with the on-disk source.

**Fix:**

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/gamekit-*
```

Then re-build. Quitting Xcode first is rarely necessary but does no
harm.

## When to uninstall the simulator app

**Symptom:** `xcodebuild test` aborts during host-app launch with
`_findCurrentMigrationStageFromModelChecksum:` in the crash report,
or the app refuses to launch in the simulator with no obvious
error.

**Cause:** the simulator has a stale SwiftData store from a prior
schema version. Not a code bug.

**Fix (canonical procedure — also documented in [`CLAUDE.md` §8.9](../CLAUDE.md)):**

```bash
xcrun simctl list devices | grep Booted          # find the device id
xcrun simctl uninstall <device-id> com.lauterstar.gamekit
```

Re-run the test or relaunch the app — the install will start from a
fresh store.

## Why no automation script (yet)

Per Phase 1 D-09: escalating to `scripts/clean-build.sh` is appropriate
only if the manual ritual gets painful in practice. For now this doc is
the entire mitigation. If you find yourself running either command more
than ~once a week, open an issue or propose a script.

## See also

- [`CLAUDE.md` §8.9](../CLAUDE.md) — simulator uninstall canonical procedure
- [`CLAUDE.md` §8.7](../CLAUDE.md) — Finder-dupe `* 2.swift` files (distinct issue)
- `.planning/research/PITFALLS.md` Pitfall 14 — project hygiene research
