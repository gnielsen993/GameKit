---
phase: 01-foundation
plan: "05"
subsystem: project-configuration
tags:
  - spm
  - designkit
  - xcode-pbxproj
dependency_graph:
  requires:
    - 01-01-project-setup (locked build settings + bundle ID)
  provides:
    - DesignKit importable in all gamekit app target source files
    - Local SPM dep at ../../DesignKit (no version pin, tracks disk)
  affects:
    - 01-06-app-scene (will import DesignKit in GameKitApp.swift)
    - 01-07-shell-screens (will import DesignKit in all Screens/ views)
    - All subsequent phases that consume DesignKit tokens
tech_stack:
  added:
    - DesignKit (local SPM, XCLocalSwiftPackageReference, ../../DesignKit)
  patterns:
    - XCLocalSwiftPackageReference (Xcode 16 objectVersion=77)
    - PBXFileSystemSynchronizedRootGroup (no hand-patching of pbxproj)
key_files:
  modified:
    - gamekit/gamekit.xcodeproj/project.pbxproj
decisions:
  - "D-07: DesignKit linked via Xcode UI (not hand-patched pbxproj) — avoids malformed sync-root-group hooks"
  - "D-08: No version pin — local-path tracks ../../DesignKit on disk; breaking DesignKit changes ripple immediately (accepted risk per ecosystem design)"
  - "Xcode emitted relativePath = ../../DesignKit (not ../DesignKit as the plan expected — path resolves correctly relative to .xcodeproj location: gamekit/gamekit.xcodeproj -> up to gamekit/ -> up to Desktop/ -> Desktop/DesignKit)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-25"
  tasks_completed: 2
  files_modified: 1
---

# Phase 01 Plan 05: DesignKit Local SPM Link Summary

**One-liner:** DesignKit linked as a local SPM dependency via Xcode UI with no version pin, resolving at `../../DesignKit` from the `.xcodeproj` location — `BUILD SUCCEEDED` confirmed.

## What Was Built

DesignKit is now a resolvable and linkable dependency of the `gamekit` app target. The Xcode project's `project.pbxproj` was modified by the Xcode 16 UI (via "Add Package Dependencies → Add Local"), emitting four well-formed blocks:

- `XCLocalSwiftPackageReference` pointing to `../../DesignKit`
- `XCSwiftPackageProductDependency` with `productName = DesignKit`
- `PBXBuildFile` entry in the gamekit Frameworks build phase
- `packageProductDependencies` entry on the gamekit app target

The test targets (`gamekitTests`, `gamekitUITests`) were explicitly excluded from the DesignKit dep during the Xcode UI step — their `packageProductDependencies = ( )` remain empty.

## Verification Results

| Check | Result |
|-------|--------|
| `xcodebuild -resolvePackageDependencies` | Exit 0, "DesignKit: /Users/gabrielnielsen/Desktop/DesignKit @ local" |
| `xcodebuild build` (no SWIFT_TREAT_WARNINGS_AS_ERRORS override) | **BUILD SUCCEEDED** |
| XCLocalSwiftPackageReference in pbxproj | 1 block |
| XCSwiftPackageProductDependency in pbxproj | 1 block |
| relativePath = ../../DesignKit | exactly 1 occurrence |
| productName = DesignKit | exactly 1 occurrence |
| packageProductDependencies in test targets | empty — DesignKit NOT linked to tests |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| T1 (human-action) | (Xcode UI — no commit) | User added DesignKit via Xcode "Add Local Package" |
| T2 (build-verify) | a64b1de | feat(01-05): link DesignKit as local SPM dependency via Xcode UI |

## Deviations from Plan

### Planner-vs-Xcode Path Difference (documented, not a bug)

**Found during:** Task 2 (pre-build verification)

**Issue:** The plan expected `relativePath = "../DesignKit"` in `project.pbxproj`. Xcode emitted `relativePath = ../../DesignKit` (no quotes around the value — also valid pbxproj syntax for unquoted paths).

**Root cause:** The plan's path was relative to the workspace/project root directory (`gamekit/`). Xcode computes `relativePath` relative to the `.xcodeproj` file location (`gamekit/gamekit.xcodeproj`). From there: one level up = `gamekit/`, two levels up = `GameKit/` (Desktop/GameKit), then `../DesignKit` = `Desktop/DesignKit`. So Xcode's `../../DesignKit` is correct.

**Fix:** Accepted Xcode's canonical path. Updated acceptance criteria check from `../DesignKit` to `../../DesignKit`. No code change needed — this was a planner typo noted in the resume context.

### SWIFT_TREAT_WARNINGS_AS_ERRORS=YES Conflicts with DesignKit Package Build Settings

**Found during:** Task 2 (first build attempt)

**Issue:** Running `xcodebuild build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on the CLI produced:
```
error: conflicting options '-warnings-as-errors' and '-suppress-warnings' (in target 'DesignKit' from project 'DesignKit')
```

DesignKit's own test-enablement path (`-enable-testing`) includes `-suppress-warnings`, and the CLI override injects `-warnings-as-errors` for the SPM package target as well, creating a hard conflict.

**Fix (Rule 1 — auto-fix):** Removed `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` from the CLI invocation. The gamekit app target's own `XCBuildConfiguration` already has warnings-as-errors enabled via the project build settings (set in Plan 01). The SPM package (DesignKit) should not have host-project CLI overrides forced onto it. Build without the override succeeds cleanly: **BUILD SUCCEEDED**.

**Note:** This is standard Xcode behavior — CLI `SWIFT_*` overrides propagate to linked SPM packages, which may have conflicting package-level settings. The correct approach is to rely on the host project's own build configuration rather than CLI flag injection for this type of build.

## Known Stubs

None — this plan modifies only `project.pbxproj` (project configuration). No UI or data stubs introduced.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. The `XCLocalSwiftPackageReference` boundary was analyzed in the plan's threat model (T-01-09, T-01-10) and both accepted.

## Self-Check: PASSED

- [x] `gamekit/gamekit.xcodeproj/project.pbxproj` exists and contains DesignKit blocks
- [x] Commit a64b1de exists: `git log --oneline | grep a64b1de` → confirmed
- [x] `xcodebuild -resolvePackageDependencies` exits 0 with DesignKit @ local
- [x] BUILD SUCCEEDED
- [x] Test targets have empty `packageProductDependencies`
- [x] SUMMARY.md written at `.planning/phases/01-foundation/01-05-designkit-link-SUMMARY.md`
