---
phase: 01-foundation
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/install-hooks.sh
  - .githooks/pre-commit
autonomous: true
requirements:
  - FOUND-07
tags:
  - git-hooks
  - lint
  - token-discipline
  - design-system

must_haves:
  truths:
    - "Pre-commit hook is installed via scripts/install-hooks.sh"
    - "Hook rejects new commits that contain Color literals in Games/ or Screens/"
    - "Hook rejects numeric cornerRadius and padding integers in Games/ or Screens/"
    - "Hook rejects Finder-dupe '* 2.swift' files anywhere"
    - "Hook does not run on App/ or Core/ (legitimate Color imports allowed there)"
  artifacts:
    - path: "scripts/install-hooks.sh"
      provides: "One-time bootstrap that points git core.hooksPath at .githooks and chmods the hook"
      min_lines: 4
    - path: ".githooks/pre-commit"
      provides: "Token-discipline + Finder-dupe enforcement gate"
      min_lines: 30
  key_links:
    - from: ".git/hooks/pre-commit (installed)"
      to: "git commit"
      via: "core.hooksPath = .githooks"
      pattern: "git config core.hooksPath"
---

<objective>
Install the project-hygiene gate that catches the issues most expensive to debug retroactively: hardcoded `Color(...)` / numeric `cornerRadius:` / numeric `padding(...)` literals in `Games/` and `Screens/` (Pitfall 8 — invisible token-discipline drift), and Finder-dupe `* 2.swift` files (Pitfall 14 / CLAUDE.md §8.7 — cause "invalid redeclaration" build failures from Xcode 16's `PBXFileSystemSynchronizedRootGroup`).

Purpose: FOUND-07 mandates this. The hook is installed locally per-developer via `scripts/install-hooks.sh`; the hook script itself is committed under `.githooks/` so every clone gets the same enforcement. Pure shell, no `lefthook` / `husky` dependency (CONTEXT line 44 — matches the "no extra dependency" posture). Scope is `Games/**.swift` and `Screens/**.swift` only — `App/` and `Core/` legitimately import `Color` for theme bridging.

Output: Two files (`scripts/install-hooks.sh`, `.githooks/pre-commit`); a `.git/hooks/pre-commit` symlink-equivalent created via `core.hooksPath`.
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
  <name>Task 1: Create scripts/install-hooks.sh bootstrap</name>
  <files>scripts/install-hooks.sh</files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"`scripts/install-hooks.sh` + `.githooks/pre-commit`" (the verbatim shell content to use)
    - .planning/phases/01-foundation/01-CONTEXT.md "Claude's Discretion" line 44 (rationale: pure shell + bootstrap)
    - ./CLAUDE.md §8.7, §8.8, §8.10 (Finder dupes, sync-root-group, atomic commits — all enforced by the hook)
  </read_first>
  <action>
    Create the directory `scripts/` if it does not exist (verify with `ls scripts/ 2>/dev/null`; if absent, the Write tool will create the directory along with the file).

    Write `scripts/install-hooks.sh` with EXACTLY this content:

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    git config core.hooksPath .githooks
    chmod +x .githooks/pre-commit
    echo "GameKit git hooks installed."
    ```

    After writing, make it executable: `chmod +x scripts/install-hooks.sh`.
  </action>
  <verify>
    <automated>test -x scripts/install-hooks.sh && bash -n scripts/install-hooks.sh</automated>
  </verify>
  <acceptance_criteria>
    - File `scripts/install-hooks.sh` exists: `test -f scripts/install-hooks.sh` exits 0
    - File is executable: `test -x scripts/install-hooks.sh` exits 0
    - File parses as valid bash: `bash -n scripts/install-hooks.sh` exits 0
    - Contains the exact line `git config core.hooksPath .githooks`: `grep -c "git config core.hooksPath .githooks" scripts/install-hooks.sh` returns exactly `1`
    - Contains the exact line `chmod +x .githooks/pre-commit`: `grep -c "chmod +x .githooks/pre-commit" scripts/install-hooks.sh` returns exactly `1`
    - First line is `#!/usr/bin/env bash`: `head -n 1 scripts/install-hooks.sh` outputs `#!/usr/bin/env bash`
    - File is ≤ 10 lines (it should be 5): `wc -l < scripts/install-hooks.sh` returns a number ≤ `10`
  </acceptance_criteria>
  <done>scripts/install-hooks.sh exists, is executable, and contains exactly the 5-line bootstrap.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Create .githooks/pre-commit and smoke-test against fixtures</name>
  <files>.githooks/pre-commit</files>
  <read_first>
    - .planning/phases/01-foundation/01-PATTERNS.md §"`scripts/install-hooks.sh` + `.githooks/pre-commit`" (the full hook script with rationale)
    - .planning/phases/01-foundation/01-PATTERNS.md §"Token vocabulary the hook must protect" (radii: card/button/chip/sheet; spacing: xs/s/m/l/xl/xxl)
    - ../DesignKit/Sources/DesignKit/Theme/Tokens.swift (confirms `Color` types in DesignKit; hook must NOT match these because hook scope excludes App/ and Core/)
    - .planning/research/PITFALLS.md §"Pitfall 8" (token discipline) and §"Pitfall 14" (Finder dupes)
    - ./CLAUDE.md §1 (no hardcoded colors / radii / spacing in UI), §8.7 (Finder dupes block builds)
  </read_first>
  <action>
    Create the directory `.githooks/` if it does not exist (Write tool will create it).

    Write `.githooks/pre-commit` with EXACTLY this content:

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail

    # Reject Finder-dupe files (CLAUDE.md §8.7 / Pitfall 14)
    dupes=$(git diff --cached --name-only --diff-filter=A | grep -E ' 2\.swift$' || true)
    if [ -n "$dupes" ]; then
      echo "ERROR: Finder-dupe files detected (will break the build via PBXFileSystemSynchronizedRootGroup):"
      echo "$dupes"
      exit 1
    fi

    # Reject hardcoded colors / radii / padding integers under Games/ and Screens/ (CLAUDE.md §1, Pitfall 8)
    staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^gamekit/gamekit/(Games|Screens)/.*\.swift$' || true)
    if [ -n "$staged" ]; then
      bad=""
      for f in $staged; do
        # Color literals (Color(red:..) / Color(hex:..) / Color.gray etc.)
        if git diff --cached "$f" | grep -E '^\+' | grep -E 'Color\(\s*(red:|hex:|white:)|Color\.(red|blue|green|gray|orange|yellow|pink|purple|black|white)' > /dev/null; then
          bad="${bad}${f}: hardcoded Color literal\n"
        fi
        # cornerRadius: <int>
        if git diff --cached "$f" | grep -E '^\+' | grep -E 'cornerRadius:\s*[0-9]+' > /dev/null; then
          bad="${bad}${f}: numeric cornerRadius literal (use theme.radii.{card,button,chip,sheet})\n"
        fi
        # padding(<int>)
        if git diff --cached "$f" | grep -E '^\+' | grep -E '\.padding\(\s*[0-9]+(\.[0-9]+)?\s*\)' > /dev/null; then
          bad="${bad}${f}: numeric padding literal (use theme.spacing.{xs,s,m,l,xl,xxl})\n"
        fi
      done
      if [ -n "$bad" ]; then
        echo -e "ERROR: token-discipline violations under Games/ or Screens/:\n${bad}"
        exit 1
      fi
    fi

    exit 0
    ```

    After writing, make it executable: `chmod +x .githooks/pre-commit`.

    **Smoke-test the hook locally without committing.** Create three temporary fixture files in a throwaway location, simulate a staged diff via `git diff --cached`-equivalent grep checks, and confirm:

    1. **Finder-dupe rejection.** Create empty `gamekit/gamekit/Screens/HomeView 2.swift`, run `git add gamekit/gamekit/Screens/HomeView\ 2.swift`, then run `bash .githooks/pre-commit`. It MUST exit non-zero with output containing "Finder-dupe". Then `git rm --cached "gamekit/gamekit/Screens/HomeView 2.swift" && rm "gamekit/gamekit/Screens/HomeView 2.swift"` to clean up.

    2. **Color literal rejection.** Create temporary `gamekit/gamekit/Screens/__lint_fixture.swift` containing `let x = Color.red`, `git add` it, run `bash .githooks/pre-commit`. MUST exit non-zero with output containing "hardcoded Color literal". Then `git rm --cached gamekit/gamekit/Screens/__lint_fixture.swift && rm gamekit/gamekit/Screens/__lint_fixture.swift` to clean up.

    3. **cornerRadius integer rejection.** Same fixture path, content `RoundedRectangle(cornerRadius: 12)`, repeat. MUST exit non-zero with output containing "numeric cornerRadius".

    4. **Clean pass.** Same fixture path, content `import SwiftUI` (single import line, no violations), repeat. MUST exit `0`. Then clean up.

    5. **App/ scope exclusion.** Create temporary `gamekit/gamekit/App/__lint_fixture.swift` containing `let x = Color.red`, `git add` it, run `bash .githooks/pre-commit`. MUST exit `0` (App/ is out of hook scope per CONTEXT line 44). Clean up.

    Document smoke-test results in the plan summary (which fixtures, which exit codes were observed). Do NOT leave fixture files in the repo or in git's index.

    Finally, run `bash scripts/install-hooks.sh` to wire `.git/hooks/pre-commit` to `.githooks/pre-commit` via `core.hooksPath`. Verify with `git config --get core.hooksPath` returning `.githooks`.
  </action>
  <verify>
    <automated>test -x .githooks/pre-commit && bash -n .githooks/pre-commit && [ "$(git config --get core.hooksPath)" = ".githooks" ]</automated>
  </verify>
  <acceptance_criteria>
    - File `.githooks/pre-commit` exists: `test -f .githooks/pre-commit` exits 0
    - File is executable: `test -x .githooks/pre-commit` exits 0
    - File parses as valid bash: `bash -n .githooks/pre-commit` exits 0
    - First line is `#!/usr/bin/env bash`: `head -n 1 .githooks/pre-commit` outputs `#!/usr/bin/env bash`
    - File contains the Finder-dupe regex `' 2\.swift\$'`: `grep -c "' 2\\\\.swift\\\$'" .githooks/pre-commit` returns at least `1`
    - File contains the scoped-grep `^gamekit/gamekit/(Games|Screens)/.*\.swift$`: `grep -c "(Games|Screens)" .githooks/pre-commit` returns at least `1`
    - File contains all three violation patterns: `grep -c "hardcoded Color literal" .githooks/pre-commit` returns `1`, same for `numeric cornerRadius literal` and `numeric padding literal`
    - `git config --get core.hooksPath` outputs exactly `.githooks`
    - File line count is between 30 and 60: `wc -l < .githooks/pre-commit` returns a number in `[30, 60]`
    - No leftover fixture files: `find gamekit -name "__lint_fixture.swift" -o -name "* 2.swift"` returns no results
    - No leftover fixtures staged: `git diff --cached --name-only | grep -E "(__lint_fixture|HomeView 2)" || true` returns empty
    - Smoke-test results documented in plan summary (executor must report exit codes from each of the 5 fixture scenarios)
  </acceptance_criteria>
  <done>Hook installed at `.git/hooks/pre-commit` (via core.hooksPath), all 5 fixture smoke-tests behave as specified, no fixture leakage.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| developer machine ↔ git | Pre-commit hook runs locally on developer machine before code reaches the repo. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-03 | Tampering | .githooks/pre-commit | accept | Hook is committed alongside the code it gates; tampering visible in git diff. Worst case a developer disables the hook locally — caught in code review when token violations land in PRs. CI will run the same checks once the project gains CI (out of P1 scope). |
| T-01-04 | Repudiation | .githooks/pre-commit | accept | Hook bypass via `--no-verify` is a known, signposted developer escape hatch (same as every git hook ever). Per CLAUDE.md §1 / §8.10 the team commits to this convention by working agreement, not by enforcement. |
| T-01-05 | Elevation of Privilege | scripts/install-hooks.sh | accept | Script `chmod +x` and `git config` are scoped to the local working directory; no `sudo`, no system-wide changes. Standard bootstrap pattern (see GitHub's documented `core.hooksPath` workflow). |

**N/A categories:** Spoofing, Information Disclosure, DoS — purely local developer-machine tooling, no network surface, no user data.
</threat_model>

<verification>
After both tasks complete:
- `ls -l scripts/install-hooks.sh .githooks/pre-commit` shows both as executable.
- `git config --get core.hooksPath` outputs `.githooks`.
- A throwaway commit attempt with a deliberate violation (e.g. `Color.red` in `Screens/`) is rejected by the hook with a clear error message.
- A clean commit (e.g. `git commit --allow-empty -m "test"`) succeeds.
</verification>

<success_criteria>
- All acceptance criteria for both tasks met.
- Pre-commit hook is wired (`.git/hooks/pre-commit` resolves to `.githooks/pre-commit` via `core.hooksPath`).
- Hook smoke-tested against 5 fixtures with documented expected exit codes (3 reject, 2 pass).
- No fixture files left in repo or staged.
- The hook is now active for all subsequent plans in this phase — Plan 07 (shell screens) will commit through this gate.
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-02-SUMMARY.md` per the template, including the smoke-test exit codes observed for all 5 fixture scenarios.
</output>
