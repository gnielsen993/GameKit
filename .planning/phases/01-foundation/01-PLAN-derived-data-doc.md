---
phase: 01-foundation
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - Docs/derived-data-hygiene.md
autonomous: true
requirements:
  - FOUND-07
tags:
  - docs
  - tooling
  - derived-data
  - simulator-hygiene

must_haves:
  truths:
    - "Docs/derived-data-hygiene.md exists and explains when to wipe DerivedData"
    - "The doc points back to CLAUDE.md §8.9 for canonical simulator-uninstall procedure"
    - "The doc references the trigger conditions (DesignKit token signature changes, NSStagedMigrationManager crashes)"
  artifacts:
    - path: "Docs/derived-data-hygiene.md"
      provides: "Short reference for derived-data + stale-simulator-store hygiene"
      min_lines: 20
  key_links:
    - from: "Docs/derived-data-hygiene.md"
      to: "CLAUDE.md §8.9"
      via: "internal markdown link"
      pattern: "§8.9"
---

<objective>
Document the derived-data hygiene policy required by D-09: a brief, link-back-heavy `Docs/derived-data-hygiene.md` that captures (a) when to wipe `~/Library/Developer/Xcode/DerivedData/gamekit-*`, (b) when to `xcrun simctl uninstall` the simulator's stale GameKit install, and (c) why P1 deliberately ships docs-only rather than an automation script (per CONTEXT line 34, escalation to a script only happens if the manual ritual gets painful).

Purpose: D-09 keeps this docs-only for now. Pitfall 14 / CLAUDE.md §8.9 already document the simulator uninstall procedure for the `NSStagedMigrationManager` crash; this doc references those rules and adds the DesignKit-specific DerivedData trigger that is unique to GameKit.

Output: One ~30-line markdown file under a new `Docs/` directory.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@./CLAUDE.md
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create Docs/derived-data-hygiene.md</name>
  <files>Docs/derived-data-hygiene.md</files>
  <read_first>
    - .planning/phases/01-foundation/01-CONTEXT.md "D-09" (line 34 — docs-only policy, no automation script)
    - .planning/phases/01-foundation/01-PATTERNS.md §"`Docs/derived-data-hygiene.md` (docs)" (the target shape spec — ~30 lines)
    - ./CLAUDE.md §8.9 (canonical simulator-uninstall procedure for NSStagedMigrationManager crashes)
    - ./CLAUDE.md §8.7 (Finder dupes — distinct issue, link only for completeness)
    - .planning/research/PITFALLS.md §"Pitfall 14" (project hygiene — Finder dupes / pbxproj / sim stores)
  </read_first>
  <action>
    Create `Docs/` directory if it does not exist (Write tool creates parents).

    Write `Docs/derived-data-hygiene.md` with EXACTLY this content (use Markdown headings for structure):

    ```markdown
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
    ```
  </action>
  <verify>
    <automated>test -f Docs/derived-data-hygiene.md && [ "$(wc -l < Docs/derived-data-hygiene.md)" -ge 20 ]</automated>
  </verify>
  <acceptance_criteria>
    - File `Docs/derived-data-hygiene.md` exists: `test -f Docs/derived-data-hygiene.md` exits 0
    - File line count is at least 20 and at most 80: `[ $(wc -l < Docs/derived-data-hygiene.md) -ge 20 ] && [ $(wc -l < Docs/derived-data-hygiene.md) -le 80 ]` exits 0
    - File contains the DerivedData wipe command: `grep -c "DerivedData/gamekit-\*" Docs/derived-data-hygiene.md` returns at least `1`
    - File contains the simctl uninstall command: `grep -c "xcrun simctl uninstall" Docs/derived-data-hygiene.md` returns at least `1`
    - File references the locked bundle ID: `grep -c "com.lauterstar.gamekit" Docs/derived-data-hygiene.md` returns at least `1`
    - File links back to CLAUDE.md §8.9: `grep -c "§8.9" Docs/derived-data-hygiene.md` returns at least `1`
    - File acknowledges D-09 (docs-only policy): `grep -c "D-09" Docs/derived-data-hygiene.md` returns at least `1`
  </acceptance_criteria>
  <done>Docs/derived-data-hygiene.md exists, between 20–80 lines, contains all canonical commands and references.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none) | Plan adds a single markdown documentation file. No runtime behavior, no attack surface. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-08 | Information Disclosure | Docs/derived-data-hygiene.md | accept | Doc references the public bundle ID `com.lauterstar.gamekit` (already in PROJECT.md and project.pbxproj) and standard Apple-developer commands. No secrets disclosed. |

**N/A categories:** Spoofing, Tampering, Repudiation, DoS, Elevation of Privilege — markdown documentation only.
</threat_model>

<verification>
After Task 1:
- `cat Docs/derived-data-hygiene.md | head -1` outputs the H1 heading.
- All 7 acceptance-criteria grep counts pass.
- `git status` shows only `Docs/derived-data-hygiene.md` as a new file.
</verification>

<success_criteria>
- File created with all required content sections (DerivedData wipe, simctl uninstall, "no automation yet" rationale, See-also links).
- All acceptance criteria pass.
- Doc is reachable from `CLAUDE.md` §8.9's procedural hint when developers grep for "DerivedData" in the repo.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-04-SUMMARY.md` per the template.
</output>
