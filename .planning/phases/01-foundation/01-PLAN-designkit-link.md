---
phase: 01-foundation
plan: 05
type: execute
wave: 2
depends_on: [1]
files_modified:
  - gamekit/gamekit.xcodeproj/project.pbxproj
autonomous: false
requirements:
  - FOUND-02
tags:
  - spm
  - designkit
  - xcode-pbxproj

must_haves:
  truths:
    - "GameKit's Xcode project resolves DesignKit from the local relative path ../DesignKit"
    - "DesignKit is a target dependency of the gamekit app target (not the test targets)"
    - "import DesignKit succeeds at compile time inside any source file under gamekit/gamekit/"
    - "No version pinning exists — local-path tracks whatever ../DesignKit has on disk (per D-08)"
  artifacts:
    - path: "gamekit/gamekit.xcodeproj/project.pbxproj"
      provides: "XCLocalSwiftPackageReference for ../DesignKit + product dependency on the app target"
      contains: "DesignKit"
  key_links:
    - from: "gamekit app target"
      to: "../DesignKit"
      via: "XCLocalSwiftPackageReference + XCSwiftPackageProductDependency"
      pattern: "relativePath = \"../DesignKit\""
---

<objective>
Add DesignKit as a local Swift Package Manager dependency at the relative path `../DesignKit`, satisfying FOUND-02. Per D-07, the addition happens through Xcode's "Add Package Dependencies → Add Local" UI (NOT by hand-patching `XCLocalSwiftPackageReference` blocks in `project.pbxproj`), because Xcode 16/26 emits the correct sync-root-group hooks alongside the package reference and hand-edits are the #1 source of malformed pbxproj diffs.

Purpose: DesignKit is the design-system source of truth for the entire ecosystem (CLAUDE.md §0). Every shell screen in Plan 07 will `import DesignKit` and consume `theme.colors.*`, `theme.spacing.*`, `theme.radii.*` — which means this dependency must be resolvable BEFORE plan 06 (App scene) compiles. Per D-08, no version pin: local-path tracks `../DesignKit` on disk, so DesignKit edits flow back to GameKit immediately (CLAUDE.md §2 — "Promote to DesignKit only when proven; consume read-only").

Output: One file modified (`project.pbxproj`); the DesignKit package appears in Xcode's "Package Dependencies" pane and the gamekit app target gains "DesignKit" as a linked product.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-CONTEXT.md
@.planning/phases/01-foundation/01-PATTERNS.md
@./CLAUDE.md
@../DesignKit/README.md
@../DesignKit/Sources/DesignKit/Theme/ThemeManager.swift
@../DesignKit/Sources/DesignKit/Theme/Tokens.swift
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 1: User adds DesignKit local SPM dep via Xcode UI</name>
  <what-built>Plan 01 has locked the build settings. DesignKit is sitting at `../DesignKit` (sibling directory, verified — has `Sources/DesignKit/Theme/{ThemeManager.swift, Tokens.swift}`). Now Xcode needs to learn about it.</what-built>
  <how-to-verify>
    Per D-07: this MUST be done through Xcode's UI, not by hand-editing `project.pbxproj`. Hand-patches frequently produce malformed sync-root-group hooks in Xcode 16's `objectVersion = 77` format and the build will fail with cryptic errors.

    **Steps for the user:**
    1. Open `gamekit/gamekit.xcodeproj` in Xcode.
    2. Select the project node in the navigator (top-level "gamekit" with the blueprint icon).
    3. Select the "gamekit" PROJECT (not target) in the editor.
    4. Click the **"Package Dependencies"** tab.
    5. Click the **"+"** button at the bottom of the package list.
    6. In the dialog, click **"Add Local…"** (button at bottom-left).
    7. Navigate to `/Users/gabrielnielsen/Desktop/DesignKit` and click **"Add Package"**.
    8. In the next sheet ("Choose Package Products"), tick **"DesignKit"** for the **"gamekit"** target only. Do NOT tick it for `gamekitTests` or `gamekitUITests` — game logic / shell screens import DesignKit; tests do not (Pitfall 8 — keep token-discipline scope tight).
    9. Click **"Add Package"**.
    10. Save (`⌘S`) and close Xcode (`⌘Q`).

    **What this writes to pbxproj:**
    - A new `XCLocalSwiftPackageReference` block with `relativePath = "../DesignKit";`
    - A new `XCSwiftPackageProductDependency` entry with `productName = DesignKit;`
    - A new `PBXBuildFile` entry linking DesignKit into the gamekit app target's Frameworks build phase
    - The `gamekit` target's `packageProductDependencies` list gains the new product reference

    All four are emitted automatically by the Xcode UI. Do not edit them by hand.

    **Sanity-check before resuming:**
    - Run `grep -c "DesignKit" gamekit/gamekit.xcodeproj/project.pbxproj`. It should return AT LEAST 4 (one for each block above).
    - Run `grep -c 'relativePath = "../DesignKit";' gamekit/gamekit.xcodeproj/project.pbxproj`. It MUST return exactly `1`.
    - Run `grep -c 'productName = DesignKit;' gamekit/gamekit.xcodeproj/project.pbxproj`. It MUST return exactly `1`.

    If any of those return zero or wildly different numbers, re-do the Xcode UI steps — the dialog may have been dismissed before the package was actually attached.
  </how-to-verify>
  <resume-signal>Type "designkit-linked" once Xcode has saved the project and the three sanity-check grep counts match. Or "designkit-failed: <reason>" if you hit an error.</resume-signal>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Build-test the project with DesignKit linked</name>
  <files>gamekit/gamekit.xcodeproj/project.pbxproj</files>
  <read_first>
    - gamekit/gamekit.xcodeproj/project.pbxproj (verify the Xcode-emitted package blocks are well-formed — look for `XCLocalSwiftPackageReference`, `XCSwiftPackageProductDependency`, `packageReferences = ( ... )` in the project root object, `packageProductDependencies = ( ... )` on the gamekit target)
    - .planning/phases/01-foundation/01-CONTEXT.md "D-07" + "D-08" (linking via Xcode UI, no version pin)
    - ../DesignKit/Package.swift (confirm DesignKit declares a `DesignKit` library product)
  </read_first>
  <action>
    Confirm the package was added cleanly by parsing the pbxproj for the four expected emissions and running a no-op build.

    1. Verify package reference structure:
       ```bash
       grep -A 3 "XCLocalSwiftPackageReference" gamekit/gamekit.xcodeproj/project.pbxproj
       grep -A 3 "XCSwiftPackageProductDependency" gamekit/gamekit.xcodeproj/project.pbxproj
       grep -B 1 -A 3 "packageProductDependencies = (" gamekit/gamekit.xcodeproj/project.pbxproj
       ```
       Expect each to show non-empty blocks containing `DesignKit` / `../DesignKit`.

    2. Resolve packages and build the gamekit scheme. Run:
       ```bash
       xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -resolvePackageDependencies
       ```
       Expected: command exits 0; output contains `Resolved source packages` (or similar Xcode 16 phrasing) and references `DesignKit`.

    3. Compile-test: build the app target without booting a simulator (faster CI-friendly path). Run:
       ```bash
       xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | tail -50
       ```
       Expected: `BUILD SUCCEEDED`. The current `gamekitApp.swift` does NOT yet `import DesignKit` — that comes in Plan 06 — so this build is just verifying the dep resolves and links cleanly. If it fails with "No such module 'DesignKit'", the link is broken; re-do Task 1.

    4. (Optional sanity) Add a temporary import test: in a scratch file `/tmp/_designkit_smoke.swift`, write `import DesignKit; let _ = ThemeManager()`. This is for the executor's own debugging; it MUST NOT be committed. Delete it after verification.

    Do NOT commit any source-code changes in this task — only the pbxproj edits Xcode wrote in Task 1 should appear in `git diff`.
  </action>
  <verify>
    <automated>xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -resolvePackageDependencies 2>&1 | grep -c "DesignKit"</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "XCLocalSwiftPackageReference" gamekit/gamekit.xcodeproj/project.pbxproj` returns at least `1`
    - `grep -c "XCSwiftPackageProductDependency" gamekit/gamekit.xcodeproj/project.pbxproj` returns at least `1`
    - `grep -c 'relativePath = "../DesignKit"' gamekit/gamekit.xcodeproj/project.pbxproj` returns exactly `1`
    - `grep -c 'productName = DesignKit' gamekit/gamekit.xcodeproj/project.pbxproj` returns at least `1`
    - `grep -c 'packageProductDependencies = (' gamekit/gamekit.xcodeproj/project.pbxproj` returns at least `1`
    - `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -resolvePackageDependencies` exits 0 AND its output contains "DesignKit"
    - `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" -configuration Debug build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES 2>&1 | grep -c "BUILD SUCCEEDED"` returns at least `1`
    - No leftover scratch files: `find /tmp -name "_designkit_smoke.swift"` returns no results AND `git status` shows no changes outside `gamekit/gamekit.xcodeproj/project.pbxproj`
    - DesignKit is NOT linked into test targets: `grep -B 5 'productName = DesignKit' gamekit/gamekit.xcodeproj/project.pbxproj` does NOT show `gamekitTests` or `gamekitUITests` anywhere in surrounding context
  </acceptance_criteria>
  <done>Xcode project resolves and builds with DesignKit as a local SPM dep. `BUILD SUCCEEDED` confirmed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| GameKit ↔ DesignKit | Source-level dependency: GameKit code calls into DesignKit's public API. DesignKit lives in a sibling directory the user controls. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-09 | Tampering | ../DesignKit (sibling repo) | accept | DesignKit is a sibling directory the same user owns and version-controls separately. No external supply chain; D-08 explicitly accepts that breaking changes in DesignKit ripple to GameKit immediately (rationale: ecosystem-consistent token improvements flow to all sibling apps). The mitigation is human review of DesignKit changes before they're committed in the DesignKit repo. |
| T-01-10 | Elevation of Privilege | XCLocalSwiftPackageReference | accept | Local-path SPM packages are limited to source-code linkage; no executable is run during resolve (unlike `Package.swift` which CAN run scripts via a build plugin — DesignKit currently has no plugins, verified by reading `../DesignKit/Package.swift` for any `.plugin` declarations). Re-verify if DesignKit gains plugins. |

**N/A categories:** Spoofing, Repudiation, Information Disclosure, DoS — local sibling dep with no network, no auth, no user data crossing the boundary.
</threat_model>

<verification>
After both tasks complete:
- `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit -destination "generic/platform=iOS Simulator" build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` exits 0 with `BUILD SUCCEEDED`.
- `git diff --stat gamekit/gamekit.xcodeproj/project.pbxproj` shows only the Xcode-emitted package additions.
- `git status` shows no other files modified.
- (Manual) Reopening the project in Xcode shows "DesignKit (1.0.0 — local)" or similar in the Package Dependencies section.
</verification>

<success_criteria>
- All Task 2 acceptance criteria met.
- DesignKit is link-ready for plans 06 and 07 to `import DesignKit`.
- Tests targets are NOT polluted with the dep.
- No version pin (D-08): local path tracks `../DesignKit` on disk.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-05-SUMMARY.md` per the template.
</output>
