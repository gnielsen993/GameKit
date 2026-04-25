---
phase: 01-foundation
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - gamekit/gamekit.xcodeproj/project.pbxproj
  - .planning/PROJECT.md
autonomous: true
requirements:
  - FOUND-04
tags:
  - ios
  - xcode-pbxproj
  - swift6
  - bundle-id

must_haves:
  truths:
    - "Bundle identifier of the app target is com.lauterstar.gamekit"
    - "iOS 17 is the deployment floor for all targets"
    - "Swift 6 strict concurrency is on for every build configuration"
    - "Xcode auto-extracts String(localized:) keys into the string catalog"
    - "CloudKit container ID iCloud.com.lauterstar.gamekit is recorded in PROJECT.md"
  artifacts:
    - path: "gamekit/gamekit.xcodeproj/project.pbxproj"
      provides: "Locked build settings: bundle ID, deployment target, Swift version, strict concurrency"
      contains: "PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit"
    - path: ".planning/PROJECT.md"
      provides: "CloudKit container ID lock per D-10"
      contains: "iCloud.com.lauterstar.gamekit"
  key_links:
    - from: "gamekit/gamekit.xcodeproj/project.pbxproj"
      to: "Xcode build pipeline"
      via: "build settings dictionary"
      pattern: "SWIFT_STRICT_CONCURRENCY = complete"
---

<objective>
Lock GameKit's project-level invariants so every later phase compiles against a stable foundation: bundle identifier `com.lauterstar.gamekit`, iOS 17.0 deployment target, Swift 6 with `complete` strict concurrency, and a CloudKit container ID pinned in PROJECT.md (capability provisioning is deferred to P6 per D-10).

Purpose: FOUND-04 demands these invariants be true from day 1. Bundle ID drift is irreversible damage post-TestFlight (Pitfall 11). The deployment target currently reads `26.2` (a template typo that would prevent install on any non-26 device). Swift version is at `5.0`, must be `6.0` with strict concurrency `complete` (CONTEXT discretion line 49). The CloudKit container ID must be locked in PROJECT.md now even though we are not turning the capability on yet (Pitfall 3 — drift = stranded TestFlight data).

Output: Updated `project.pbxproj` with all build-setting deltas; PROJECT.md gains a single line recording the CloudKit container ID.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@./CLAUDE.md
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Edit project.pbxproj build settings (bundle ID, deployment target, Swift 6, strict concurrency)</name>
  <files>gamekit/gamekit.xcodeproj/project.pbxproj</files>
  <read_first>
    - gamekit/gamekit.xcodeproj/project.pbxproj (the file you are editing — read the full project body in §"Project Build Settings" section, lines 285-540, before making any change)
    - .planning/phases/01-foundation/01-PATTERNS.md §"Project Build Settings (Quick Reference for Planner)" (verbatim line-numbers + target values)
    - ./CLAUDE.md §1 (absolute constraints — bundle ID, iOS 17, Swift 6) and §8.8 (only edit pbxproj for new top-level dirs / settings, never for new Swift files)
  </read_first>
  <action>
    Apply these EXACT edits to `gamekit/gamekit.xcodeproj/project.pbxproj`. Use the Edit tool with single-line `old_string` / `new_string` pairs to keep diffs surgical. Do NOT touch any setting not listed below.

    1. **`IPHONEOS_DEPLOYMENT_TARGET`** — change all 4 occurrences from `26.2` to `17.0` (lines 325, 383, 465, 487 — both Debug + Release for app target, and both for tests target):
       - `IPHONEOS_DEPLOYMENT_TARGET = 26.2;` → `IPHONEOS_DEPLOYMENT_TARGET = 17.0;`

    2. **`SWIFT_VERSION`** — change all 6 occurrences from `5.0` to `6.0` (lines 420, 452, 473, 495, 515, 535 — Debug + Release for app target, tests target, UI tests target):
       - `SWIFT_VERSION = 5.0;` → `SWIFT_VERSION = 6.0;`

    3. **`PRODUCT_BUNDLE_IDENTIFIER`** for the **app target** — change both occurrences (lines 413, 445):
       - `PRODUCT_BUNDLE_IDENTIFIER = lauterstar.gamekit;` → `PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit;`

    4. **`PRODUCT_BUNDLE_IDENTIFIER`** for the **tests target** — change both occurrences (lines 467, 489):
       - `PRODUCT_BUNDLE_IDENTIFIER = lauterstar.gamekitTests;` → `PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit.tests;`

    5. **`PRODUCT_BUNDLE_IDENTIFIER`** for the **UI tests target** — change both occurrences (lines 509, 529):
       - `PRODUCT_BUNDLE_IDENTIFIER = lauterstar.gamekitUITests;` → `PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit.uitests;`

    6. **Add `SWIFT_STRICT_CONCURRENCY = complete;`** to all 6 build configurations that have a `SWIFT_VERSION` line. Insert immediately AFTER each `SWIFT_VERSION = 6.0;` line, using the same indentation (one tab). Result, e.g. at the app target Debug config:
       ```
       SWIFT_STRICT_CONCURRENCY = complete;
       SWIFT_VERSION = 6.0;
       ```
       Six insertions total (app target Debug+Release, tests target Debug+Release, UI tests target Debug+Release).

    Settings NOT to touch (already correct per PATTERNS.md §"Settings already correct"):
    - `objectVersion = 77` (line 6) — Xcode 16 sync-root-group format
    - `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` (lines 326, 384)
    - `STRING_CATALOG_GENERATE_SYMBOLS = YES`
    - `SWIFT_APPROACHABLE_CONCURRENCY = YES` (lines 416, 448)
    - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (lines 417, 449)
    - `SWIFT_EMIT_LOC_STRINGS = YES` (lines 418, 450)
    - `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
    - `DEVELOPMENT_TEAM = JCWX4BK8GW`
    - `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`

    Per CLAUDE.md §8.8, do NOT add any new file references or PBXBuildFile entries — local SPM dep is its own plan (Wave 2). This task is build-settings-only.
  </action>
  <verify>
    <automated>grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit;" gamekit/gamekit.xcodeproj/project.pbxproj</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `2`
    - `grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit.tests;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `2`
    - `grep -c "PRODUCT_BUNDLE_IDENTIFIER = com.lauterstar.gamekit.uitests;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `2`
    - `grep -c "PRODUCT_BUNDLE_IDENTIFIER = lauterstar.gamekit" gamekit/gamekit.xcodeproj/project.pbxproj` returns `0` (no unprefixed leftovers)
    - `grep -c "IPHONEOS_DEPLOYMENT_TARGET = 17.0;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `4`
    - `grep -c "IPHONEOS_DEPLOYMENT_TARGET = 26.2;" gamekit/gamekit.xcodeproj/project.pbxproj` returns `0`
    - `grep -c "SWIFT_VERSION = 6.0;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `6`
    - `grep -c "SWIFT_VERSION = 5.0;" gamekit/gamekit.xcodeproj/project.pbxproj` returns `0`
    - `grep -c "SWIFT_STRICT_CONCURRENCY = complete;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `6`
    - `grep -c "objectVersion = 77;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `1` (untouched)
    - `grep -c "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `2` (untouched)
    - `grep -c "SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;" gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `2` (untouched)
  </acceptance_criteria>
  <done>All 12 grep counts above match. No accidental edits to untouched settings.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Pin CloudKit container ID in PROJECT.md (per D-10)</name>
  <files>.planning/PROJECT.md</files>
  <read_first>
    - .planning/PROJECT.md (the entire file — locate the "Key Decisions" table at end)
    - .planning/phases/01-foundation/01-CONTEXT.md §"iCloud / Persistence Prep" D-10 (the locking decision verbatim)
    - .planning/research/PITFALLS.md §"Pitfall 3" (silent CloudKit failures — container ID drift = stranded TestFlight data)
  </read_first>
  <action>
    Add a single new row to the **"Key Decisions"** table in `.planning/PROJECT.md` (currently ends at the row "Bundle ID `com.lauterstar.gamekit`"). Insert AFTER that bundle-ID row, BEFORE the `## Evolution` section, exactly:

    ```
    | CloudKit container ID `iCloud.com.lauterstar.gamekit` | Pinned at P1 per D-10 / Pitfall 3 to prevent stranded-TestFlight-data drift; capability provisioning deferred to P6 alongside Sign in with Apple | — Pending |
    ```

    Do NOT add an iCloud entitlement, do NOT modify Info.plist, do NOT touch the project.pbxproj `Capabilities` section. The container ID lives in PROJECT.md only at this phase per D-10.

    Do NOT touch any other line in PROJECT.md (no rewording, no reformatting). One single-row insertion.
  </action>
  <verify>
    <automated>grep -F "iCloud.com.lauterstar.gamekit" .planning/PROJECT.md</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "iCloud.com.lauterstar.gamekit" .planning/PROJECT.md` returns at least `1`
    - `grep -c "Pinned at P1 per D-10" .planning/PROJECT.md` returns exactly `1`
    - The grep-matched line lives between the "Bundle ID" row and the "## Evolution" heading (verifiable by `grep -n` checking line ordering)
    - No iCloud capability or entitlement file added: `find gamekit -name "*.entitlements" -newer .planning/STATE.md` returns no results
    - `grep -c "com.apple.developer.icloud" gamekit/gamekit.xcodeproj/project.pbxproj` returns `0` (capability NOT enabled per D-10)
  </acceptance_criteria>
  <done>PROJECT.md contains the new row referencing the container ID and D-10; no other files modified.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none in P1) | This plan only edits build-settings configuration and a planning markdown file. No new attack surface introduced. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01 | Tampering | gamekit.xcodeproj/project.pbxproj | accept | Build-config-only edits; pbxproj is source-controlled and reviewed via git diff. No code execution surface introduced. |
| T-01-02 | Information Disclosure | .planning/PROJECT.md | accept | CloudKit container ID is a public identifier (not a secret); appears in entitlements/Info.plist of every shipped iCloud app. Pinning it in a planning doc reveals nothing exploitable. |

**N/A categories for this plan:** Spoofing, Repudiation, DoS, Elevation of Privilege — pure scaffolding edits, no auth surface, no network surface, no user input.
</threat_model>

<verification>
After both tasks complete:
- `xcodebuild -project gamekit/gamekit.xcodeproj -showBuildSettings -scheme gamekit 2>/dev/null | grep -E "PRODUCT_BUNDLE_IDENTIFIER|IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY"` shows the new locked values for the gamekit scheme.
- (Optional sanity, may fail if Xcode CLT is missing) `xcodebuild -project gamekit/gamekit.xcodeproj -list` exits 0.
- `git diff --stat` shows ONLY `gamekit/gamekit.xcodeproj/project.pbxproj` and `.planning/PROJECT.md` modified.
</verification>

<success_criteria>
- All 12 acceptance-criteria grep counts in Task 1 match exactly.
- PROJECT.md has the new container-ID row and nothing else changed.
- No `.entitlements` file appears anywhere under `gamekit/` (capability deferred to P6).
- Bundle ID is contractually frozen as of this commit per CLAUDE.md §1; pre-commit hook (Plan 02) will catch any future drift.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-01-SUMMARY.md` per the template.
</output>
