# Sudoku Phase 14 — Vendor SudokuCore + CLI Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor the `SudokuCore` Swift Package from `cxnielsen/sudokuplus` into the GameKit repo as a local package, drop the SQLite dependency, build a JSON-output `GenerateSudokuPack` CLI tool, and ship a 40-puzzle placeholder pack so the app target still compiles. End state: `swift test` in `Packages/SudokuCore` is green; `swift run GenerateSudokuPack` produces valid JSON; the main app target builds with the new local SPM dependency.

**Architecture:** Vendored copy (not SPM remote dep) at `Packages/SudokuCore/`. Engine sources lifted verbatim from upstream commit `b02c848f62ad4ad70fc6f1079916e193cb9470ae`. SQLite-backed `SQLitePuzzleRepository` dropped — replaced with `InMemoryPuzzleRepository` for the CLI tool's `GeneratePuzzleUseCase`. Upstream `SeedGenerator` executable target removed during vendor (we ship our own `GenerateSudokuPack` with JSON output + resumable batching). Pack JSON committed as a bundle resource in `gamekit/gamekit/Resources/`.

**Tech Stack:** Swift 6, Swift Package Manager (local package), Foundation only (no external Swift deps after SQLite removal), Xcode 16 with `objectVersion = 77` synchronized root groups.

**Reference design spec:** `Docs/superpowers/specs/2026-05-15-sudoku-integration-design.md`

---

## File Structure

### New top-level directories

```
Packages/SudokuCore/                              ← NEW vendored Swift Package
  Package.swift
  Sources/SudokuCore/
    Errors.swift
    Models.swift
    Protocols.swift
    SHA256Hasher.swift
    SudokuCore.swift
    SudokuPuzzleGenerator.swift
    SudokuSolver.swift
    TechniqueRater.swift
    UseCases.swift
    InMemoryPuzzleRepository.swift                ← NEW (replaces SQLite repo)
  Tests/SudokuCoreTests/
    SudokuCoreTests.swift
  README.md                                       ← NEW (provenance + sync log)

Tools/GenerateSudokuPack/                         ← NEW Swift CLI executable
  Package.swift
  Sources/GenerateSudokuPack/
    main.swift

gamekit/gamekit/Resources/
  SudokuPuzzles.json                              ← NEW placeholder (40 puzzles)
```

### Existing files modified

```
gamekit/gamekit.xcodeproj/project.pbxproj
  ↳ Add local SPM dep on Packages/SudokuCore (via Xcode UI, then commit)
  ↳ Add SudokuPuzzles.json as bundle resource (auto-picked up by Xcode 16
    synchronized root group; no manual pbxproj edit needed for resource file)
```

### Files explicitly NOT vendored

- `SudokuCore/Sources/SudokuCore/SQLitePuzzleRepository.swift` (drops SQLite3 link)
- `SudokuCore/Sources/SeedGenerator/main.swift` (we ship our own CLI with JSON output)
- All of `SudokuPlus/` app target (we have our own app shells)

---

## Vendor SHA

`b02c848f62ad4ad70fc6f1079916e193cb9470ae` (cxnielsen/sudokuplus@main as of 2026-05-15). Record this in `Packages/SudokuCore/README.md` (Task 5).

---

## Task 1: Create local Swift Package scaffold

**Files:**
- Create: `Packages/SudokuCore/Package.swift`

- [ ] **Step 1: Create the Packages/SudokuCore directory**

```bash
mkdir -p Packages/SudokuCore/Sources/SudokuCore
mkdir -p Packages/SudokuCore/Tests/SudokuCoreTests
```

- [ ] **Step 2: Write Package.swift**

Create `Packages/SudokuCore/Package.swift` with this exact content. Note: the upstream Package.swift links `sqlite3` and ships a `SeedGenerator` executable target — both removed here.

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SudokuCore",
            targets: ["SudokuCore"]
        ),
    ],
    targets: [
        .target(
            name: "SudokuCore"
        ),
        .testTarget(
            name: "SudokuCoreTests",
            dependencies: ["SudokuCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Differences vs upstream:
- Platforms bumped: iOS 13 → iOS 17, macOS 10.15 → macOS 14 (matches GameKit's iOS 17+ target per CLAUDE.md §1).
- `.linkedLibrary("sqlite3")` removed (no SQLite repo in our vendor).
- `SeedGenerator` executable target removed.

- [ ] **Step 3: Verify package skeleton parses**

```bash
cd Packages/SudokuCore && swift package describe
```

Expected output starts with: `Name: SudokuCore` and lists `SudokuCore` library + `SudokuCoreTests` test target. No "sqlite3" mention. Return to repo root: `cd ../..`.

- [ ] **Step 4: Do not commit yet — engine files arrive in Task 2.**

---

## Task 2: Vendor engine source files

**Files:**
- Create (9 files lifted verbatim from `cxnielsen/sudokuplus@b02c848`):
  - `Packages/SudokuCore/Sources/SudokuCore/Errors.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/Models.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/Protocols.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/SHA256Hasher.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/SudokuCore.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/SudokuPuzzleGenerator.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/SudokuSolver.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/TechniqueRater.swift`
  - `Packages/SudokuCore/Sources/SudokuCore/UseCases.swift`

- [ ] **Step 1: Fetch each file from upstream and write into our package**

Use the `gh` CLI to read the raw content at the locked SHA and write to disk. Run from repo root:

```bash
SHA=b02c848f62ad4ad70fc6f1079916e193cb9470ae
DEST=Packages/SudokuCore/Sources/SudokuCore
mkdir -p "$DEST"

for f in Errors.swift Models.swift Protocols.swift SHA256Hasher.swift SudokuCore.swift SudokuPuzzleGenerator.swift SudokuSolver.swift TechniqueRater.swift UseCases.swift; do
  gh api "repos/cxnielsen/sudokuplus/contents/SudokuCore/Sources/SudokuCore/$f?ref=$SHA" \
    --jq '.content' | base64 -d > "$DEST/$f"
  echo "Wrote $DEST/$f ($(wc -c < "$DEST/$f") bytes)"
done
```

Expected: nine "Wrote …" lines, each with a non-zero byte count.

- [ ] **Step 2: Verify file integrity (line counts as smoke test)**

```bash
wc -l Packages/SudokuCore/Sources/SudokuCore/*.swift
```

Expected approximate line counts (small drift OK if upstream tweaks whitespace):
- `Errors.swift` ~12
- `Models.swift` ~95
- `Protocols.swift` ~35
- `SHA256Hasher.swift` ~15
- `SudokuCore.swift` ~5
- `SudokuPuzzleGenerator.swift` ~180
- `SudokuSolver.swift` ~210
- `TechniqueRater.swift` ~160
- `UseCases.swift` ~125

If any file is empty or wildly off, the gh fetch failed for that file — re-run that one with explicit error checking:

```bash
gh api "repos/cxnielsen/sudokuplus/contents/SudokuCore/Sources/SudokuCore/Models.swift?ref=$SHA" --jq '.content' | base64 -d
```

- [ ] **Step 3: Attempt to build the vendored package (will fail — SudokuCoreError references not yet complete)**

```bash
cd Packages/SudokuCore && swift build 2>&1 | head -40
```

Expected: build **succeeds** if all 9 files are present. The engine is self-contained and has no SQLite import in any file except `SQLitePuzzleRepository.swift` (which we did not vendor). If the build fails, read the error carefully:

- "Cannot find type 'PuzzleRepository' in scope" inside `UseCases.swift` → `Protocols.swift` did not fetch correctly. Re-fetch.
- "Cannot find 'sqlite3_open_v2'" → a vendored file unexpectedly imports SQLite. Should not happen with the 9-file list above; report the actual file and abort if it does.

Return to repo root: `cd ../..`.

- [ ] **Step 4: Do not commit yet — the test target is still empty. Tasks 3 + 4 complete the package.**

---

## Task 3: Write InMemoryPuzzleRepository replacement

**Files:**
- Create: `Packages/SudokuCore/Sources/SudokuCore/InMemoryPuzzleRepository.swift`

This is the only NEW file (not vendored). It conforms to the upstream `PuzzleRepository` protocol so `GeneratePuzzleUseCase` (which the CLI tool uses) compiles. We do not vendor the SQLite-backed implementation.

- [ ] **Step 1: Write InMemoryPuzzleRepository.swift**

Create the file at `Packages/SudokuCore/Sources/SudokuCore/InMemoryPuzzleRepository.swift` with this exact content:

```swift
//
//  InMemoryPuzzleRepository.swift
//  SudokuCore (GameKit vendor — replaces SQLitePuzzleRepository)
//
//  GameKit does not need persistent puzzle storage; runtime serves
//  puzzles from a bundled JSON pack via SudokuPuzzlePool (app target).
//  This in-memory repo exists so the CLI tool's GeneratePuzzleUseCase
//  has something to call .save(_:) against during offline pack
//  generation. Dedup-by-hash is enforced; the other PuzzleRepository
//  methods throw `notSupported` because the CLI doesn't use them.
//

import Foundation

public actor InMemoryPuzzleRepository: PuzzleRepository {
    public enum InMemoryError: Error, Equatable {
        case notSupported
    }

    private var puzzlesByHash: [String: Puzzle] = [:]

    public init() {}

    /// All saved puzzles, in insertion order is NOT guaranteed — the
    /// caller should sort if order matters.
    public func allPuzzles() -> [Puzzle] {
        Array(puzzlesByHash.values)
    }

    public func count(for difficulty: Difficulty) -> Int {
        puzzlesByHash.values.filter { $0.difficulty == difficulty }.count
    }

    public func contains(hash: String) -> Bool {
        puzzlesByHash[hash] != nil
    }

    // MARK: - PuzzleRepository conformance

    public func save(_ puzzle: Puzzle) async throws {
        if puzzlesByHash[puzzle.hash] != nil {
            throw SudokuCoreError.hashAlreadyExists
        }
        puzzlesByHash[puzzle.hash] = puzzle
    }

    public func nextPuzzle(
        excluding statuses: Set<PuzzleStatus>,
        difficulty: Difficulty?
    ) async throws -> Puzzle? {
        throw InMemoryError.notSupported
    }

    public func markStatus(_ status: PuzzleStatus, for puzzleHash: String) async throws {
        throw InMemoryError.notSupported
    }

    public func updateProgress(
        for puzzleHash: String,
        elapsedSec: Int,
        mistakes: Int,
        hintsUsed: Int,
        score: Int,
        boardString: String,
        notesJSON: String?
    ) async throws {
        throw InMemoryError.notSupported
    }

    public func fetchInProgress() async throws -> (Puzzle, PuzzleProgress)? {
        throw InMemoryError.notSupported
    }

    public func inventoryCounts() async throws -> [Difficulty: Int] {
        var counts: [Difficulty: Int] = [:]
        for d in Difficulty.allCases {
            counts[d] = puzzlesByHash.values.filter { $0.difficulty == d }.count
        }
        return counts
    }

    public func clearLibrary() async throws {
        puzzlesByHash.removeAll()
    }
}
```

- [ ] **Step 2: Build the package — should compile clean**

```bash
cd Packages/SudokuCore && swift build 2>&1 | tail -20
```

Expected: `Build complete!` with no warnings about unused-imports or missing conformance. If `PuzzleRepository` complains about missing method, you mistyped a signature — re-read Step 1 carefully against `Protocols.swift`. Return: `cd ../..`.

- [ ] **Step 3: Do not commit yet — tests arrive in Task 4.**

---

## Task 4: Vendor SudokuCoreTests + verify green

**Files:**
- Create: `Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift`

- [ ] **Step 1: Fetch the test file**

```bash
SHA=b02c848f62ad4ad70fc6f1079916e193cb9470ae
gh api "repos/cxnielsen/sudokuplus/contents/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift?ref=$SHA" \
  --jq '.content' | base64 -d > Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift

wc -l Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift
```

Expected: ~600 lines (upstream file is 20827 bytes ≈ 600 lines).

- [ ] **Step 2: Inspect the test file's repository usage**

```bash
grep -n "SQLitePuzzleRepository\|InMemoryPuzzleRepository\|PuzzleRepository" \
  Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift | head -20
```

Two cases:
- (A) Tests reference `SQLitePuzzleRepository` directly → they will fail to compile. The repo class doesn't exist in our vendor. Fix by string-replacing the type name to `InMemoryPuzzleRepository`:

  ```bash
  sed -i '' 's/SQLitePuzzleRepository(databaseURL:[^)]*)/InMemoryPuzzleRepository()/g' \
    Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift
  sed -i '' 's/SQLitePuzzleRepository/InMemoryPuzzleRepository/g' \
    Packages/SudokuCore/Tests/SudokuCoreTests/SudokuCoreTests.swift
  ```

- (B) Tests only reference the abstract `PuzzleRepository` protocol → no edit needed.

- [ ] **Step 3: Run tests**

```bash
cd Packages/SudokuCore && swift test 2>&1 | tail -30
```

Expected: `Test Suite 'All tests' passed`. All tests green.

If any test fails, classify it:

1. **Test uses `nextPuzzle`/`markStatus`/`updateProgress`/`fetchInProgress`** — those throw `InMemoryError.notSupported` in our impl. The test is exercising SQLite-specific behavior. **Skip that test** by adding `func test...() throws { throw XCTSkip("Requires SQLitePuzzleRepository — not vendored in GameKit") }` shim. List each skipped test in `Packages/SudokuCore/README.md` (Task 5).

2. **Test fails for engine reasons (rater output drift, generator nondeterminism, etc.)** — investigate. Engine should be byte-identical to upstream; if a test relied on a seed that produced different output on Swift 6.3 vs upstream's 6.x, fix the seed value in the test or open a question for the user. **Do NOT silently delete tests.**

3. **Compilation error** — most likely an `import` that needs `@testable`. Re-read the upstream file structure and fix.

- [ ] **Step 4: Record skipped tests (if any) in a TODO list**

If any tests were skipped in Step 3, append to a temporary `Packages/SudokuCore/SKIPPED_TESTS.md` file (will be merged into README.md in Task 5):

```markdown
# Tests skipped during GameKit vendor

These tests exercised `SQLitePuzzleRepository`-specific behavior that the
vendored InMemoryPuzzleRepository cannot replicate (persistent storage,
in-progress puzzle restoration, status transitions, progress tracking).

- `testName1` — reason
- `testName2` — reason

To re-enable: restore `SQLitePuzzleRepository.swift` from upstream + add
SQLite3 linker setting to Package.swift.
```

If no tests were skipped, do not create this file.

- [ ] **Step 5: Return to repo root**

```bash
cd ../..
```

- [ ] **Step 6: Do not commit yet — README arrives in Task 5.**

---

## Task 5: Write Packages/SudokuCore/README.md

**Files:**
- Create: `Packages/SudokuCore/README.md`

- [ ] **Step 1: Write the README with provenance + license note + sync log**

Create `Packages/SudokuCore/README.md`:

```markdown
# SudokuCore (vendored)

This package is a vendored copy of the `SudokuCore` engine from
`cxnielsen/sudokuplus`, ported into GameKit with the SQLite repository
implementation removed.

## Why vendored, not SPM remote dep

- We want freedom to drop dependencies (SQLite) without negotiating
  upstream changes.
- The upstream repo is private; SPM auth would complicate CI.
- Sister-repo coupling is intentionally loose — we re-sync on demand,
  not on every upstream main commit.

## Provenance

- **Source repo:** `cxnielsen/sudokuplus` (private)
- **Initial vendor SHA:** `b02c848f62ad4ad70fc6f1079916e193cb9470ae`
- **Initial vendor date:** 2026-05-15
- **Vendored with permission of:** the upstream author (the GameKit
  maintainer is a collaborator on the upstream repo).

## What was removed during vendor

- `Sources/SudokuCore/SQLitePuzzleRepository.swift` — GameKit ships
  puzzles from a bundled JSON pack via `SudokuPuzzlePool` (app target).
  No on-device puzzle DB.
- `Sources/SeedGenerator/main.swift` — GameKit ships its own CLI
  (`Tools/GenerateSudokuPack`) that writes JSON instead of Swift source.
- `.linkedLibrary("sqlite3")` in Package.swift — no SQLite link needed.

## What was added during vendor

- `Sources/SudokuCore/InMemoryPuzzleRepository.swift` — minimal actor
  conforming to `PuzzleRepository`, used by `Tools/GenerateSudokuPack`'s
  `GeneratePuzzleUseCase` for dedup-by-hash during offline pack
  generation. Methods unrelated to save/inventory throw
  `InMemoryError.notSupported`.

## Re-sync workflow

1. Pick a new upstream SHA (`gh api repos/cxnielsen/sudokuplus/commits/main --jq '.sha'`).
2. Diff each vendored file against the new upstream version:
   ```
   gh api "repos/cxnielsen/sudokuplus/contents/SudokuCore/Sources/SudokuCore/<file>?ref=<sha>" --jq '.content' | base64 -d | diff - Packages/SudokuCore/Sources/SudokuCore/<file>
   ```
3. Manually apply non-conflicting upstream changes. Keep our `InMemoryPuzzleRepository.swift` and our modified `Package.swift`.
4. Re-run tests: `cd Packages/SudokuCore && swift test`.
5. Append a new entry to the sync log below.

## Sync log

| Date       | SHA                                       | Notes                                  |
|------------|-------------------------------------------|----------------------------------------|
| 2026-05-15 | b02c848f62ad4ad70fc6f1079916e193cb9470ae | Initial vendor. SQLite repo dropped.   |

## Skipped tests during vendor

<!-- If `SKIPPED_TESTS.md` was created in Task 4, merge its content here
     and delete the temporary file. Otherwise, write: "None — all
     vendored tests pass." -->
```

- [ ] **Step 2: Merge skipped-tests content (if any)**

If `Packages/SudokuCore/SKIPPED_TESTS.md` exists from Task 4 Step 4:

```bash
echo "" >> Packages/SudokuCore/README.md
cat Packages/SudokuCore/SKIPPED_TESTS.md >> Packages/SudokuCore/README.md
rm Packages/SudokuCore/SKIPPED_TESTS.md
```

Then manually edit `README.md` to place that content under the "Skipped tests during vendor" heading.

If `SKIPPED_TESTS.md` does not exist, manually replace the HTML comment in the README with the literal text: `None — all vendored tests pass.`

- [ ] **Step 3: Commit Task 1–5 together (vendor + tests + provenance)**

```bash
git add Packages/SudokuCore/
git commit -m "$(cat <<'EOF'
feat(14-01): vendor SudokuCore engine from cxnielsen/sudokuplus

Vendored at SHA b02c848 — engine sources lifted verbatim from upstream
SudokuCore Swift Package. Drops SQLitePuzzleRepository (we ship puzzles
from a bundled JSON pack via SudokuPuzzlePool, no on-device DB) and
the upstream SeedGenerator target (we ship our own JSON-output CLI in
Tools/GenerateSudokuPack).

New file: InMemoryPuzzleRepository conforming to PuzzleRepository for
the offline pack-generation use case (dedup-by-hash only).

All vendored tests green under `swift test`. Provenance + re-sync
workflow documented in Packages/SudokuCore/README.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

Then verify the commit was created:

```bash
git log --oneline -3
```

Expected: top commit is the `feat(14-01)` we just made.

---

## Task 6: Wire SudokuCore as local SPM dep in main app target

**Files:**
- Modify: `gamekit/gamekit.xcodeproj/project.pbxproj` (via Xcode UI)

The Xcode project uses `objectVersion = 77` synchronized root groups (CLAUDE.md §8.8). New source files auto-register, but **SPM dependencies are a target-membership change** and must go through Xcode's UI to update the `XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` blocks in `project.pbxproj`.

- [ ] **Step 1: Open the project in Xcode**

```bash
open gamekit/gamekit.xcodeproj
```

- [ ] **Step 2: Add local package via UI**

In Xcode:
1. File → Add Package Dependencies…
2. Click `Add Local…` in the bottom-left of the dialog.
3. Navigate to and select the `Packages/SudokuCore/` directory.
4. Click `Add Package`.
5. In the product-selection sheet, ensure `SudokuCore` library is checked. Add target: `gamekit` (the app target).
6. Click `Add Package`.

- [ ] **Step 3: Verify dependency wired correctly**

In Xcode's Project navigator, expand `gamekit` (project) → `gamekit` (target) → `Frameworks, Libraries, and Embedded Content`. Confirm `SudokuCore` appears in the list.

Also at the project level, expand `Packages` in the Project navigator — `SudokuCore` should be listed as a local package.

- [ ] **Step 4: Confirm the app target still builds**

From the terminal (do not close Xcode):

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` on the final line. If linker errors mention `SudokuCore`, the package didn't get added to the gamekit target's link phase — repeat Step 2 carefully.

If build fails with `Multiple commands produce ...` or a code-signing error unrelated to our change, you may need to also run a clean: `xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit clean`, then retry.

- [ ] **Step 5: Verify by importing SudokuCore in a throwaway test**

This step proves the linkage works at the Swift module level, not just at the linker level. Create a temporary file:

```bash
cat > /tmp/sudoku_import_test.swift <<'EOF'
import SudokuCore
let v = SudokuCore.version
print(v)
EOF
```

This is not added to the project — it's a sanity check using `swift -F`. Actually skip this step on iOS-only targets; the BUILD SUCCEEDED in Step 4 is sufficient evidence the module resolves.

```bash
rm -f /tmp/sudoku_import_test.swift
```

- [ ] **Step 6: Commit the pbxproj change**

The pbxproj diff will be small — `XCRemoteSwiftPackageReference` is not used for local packages, but there will be entries for `XCLocalSwiftPackageReference`, `XCSwiftPackageProductDependency`, and the `PBXFrameworksBuildPhase` for the gamekit target.

```bash
git status
```

Expected modified file: `gamekit/gamekit.xcodeproj/project.pbxproj` and possibly `gamekit/gamekit.xcodeproj/project.xcworkspace/contents.xcworkspacedata`.

```bash
git diff --stat gamekit/gamekit.xcodeproj/
```

Inspect that the diff scope is small (a few dozen lines). If you see hundreds of lines changed, Xcode reformatted something — review carefully before committing.

```bash
git add gamekit/gamekit.xcodeproj/project.pbxproj gamekit/gamekit.xcodeproj/project.xcworkspace/
git commit -m "$(cat <<'EOF'
feat(14-02): wire local SudokuCore SPM dep into gamekit app target

Adds Packages/SudokuCore as a local Swift Package dependency on the
gamekit app target via Xcode's File → Add Package Dependencies → Add
Local flow. `xcodebuild build` succeeds; SudokuCore module is now
importable from app target sources.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Build GenerateSudokuPack CLI tool

**Files:**
- Create: `Tools/GenerateSudokuPack/Package.swift`
- Create: `Tools/GenerateSudokuPack/Sources/GenerateSudokuPack/main.swift`

- [ ] **Step 1: Create the tool directory + Package.swift**

```bash
mkdir -p Tools/GenerateSudokuPack/Sources/GenerateSudokuPack
```

Write `Tools/GenerateSudokuPack/Package.swift`:

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "GenerateSudokuPack",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../../Packages/SudokuCore")
    ],
    targets: [
        .executableTarget(
            name: "GenerateSudokuPack",
            dependencies: [
                .product(name: "SudokuCore", package: "SudokuCore")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Write main.swift**

Write `Tools/GenerateSudokuPack/Sources/GenerateSudokuPack/main.swift`:

```swift
//
//  GenerateSudokuPack — offline JSON puzzle pack generator
//
//  Generates a JSON file with N puzzles per difficulty, dedup-by-hash,
//  resumable across runs (--append). Output schema matches what
//  Games/Sudoku/SudokuPuzzlePool expects.
//
//  Usage:
//    swift run GenerateSudokuPack [flags]
//
//  Flags:
//    --per-difficulty <N>   Target count per difficulty (default 1500)
//    --difficulties <csv>   Subset (e.g. "hard,extreme"); default = all 4
//    --output <path>        Output JSON path (default
//                           ../../gamekit/gamekit/Resources/SudokuPuzzles.json)
//    --append               Read existing JSON and fill missing slots only
//    --time-budget <min>    Soft cap in minutes; clean exit when exceeded
//

import Foundation
import SudokuCore

// MARK: - Schema (matches Games/Sudoku/SudokuPuzzlePool decoder)

struct PuzzleEntry: Codable {
    let id: String
    let givens: String
    let solution: String
    let givenCount: Int
}

struct PuzzlePack: Codable {
    var schemaVersion: Int
    var generatedAt: String
    var generatorSourceSha: String
    var puzzles: [String: [PuzzleEntry]]  // keys = Difficulty.rawValue
}

// MARK: - Arg parsing (minimal — no Argument Parser dep)

struct Args {
    var perDifficulty: Int = 1500
    var difficulties: [Difficulty] = Difficulty.allCases
    var output: String = "../../gamekit/gamekit/Resources/SudokuPuzzles.json"
    var append: Bool = false
    var timeBudgetMinutes: Double? = nil
}

func parseArgs() -> Args {
    var a = Args()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "--per-difficulty":
            i += 1
            guard i < argv.count, let v = Int(argv[i]) else { fatalError("--per-difficulty <N>") }
            a.perDifficulty = v
        case "--difficulties":
            i += 1
            guard i < argv.count else { fatalError("--difficulties <csv>") }
            a.difficulties = argv[i].split(separator: ",").compactMap { Difficulty(rawValue: String($0)) }
            if a.difficulties.isEmpty { fatalError("--difficulties: no valid values parsed from \(argv[i])") }
        case "--output":
            i += 1
            guard i < argv.count else { fatalError("--output <path>") }
            a.output = argv[i]
        case "--append":
            a.append = true
        case "--time-budget":
            i += 1
            guard i < argv.count, let v = Double(argv[i]) else { fatalError("--time-budget <minutes>") }
            a.timeBudgetMinutes = v
        case "--help", "-h":
            print("""
            GenerateSudokuPack — generate a JSON Sudoku puzzle pack.

            Flags:
              --per-difficulty <N>   Target count per difficulty (default 1500)
              --difficulties <csv>   Subset, e.g. hard,extreme (default = all)
              --output <path>        Output JSON path
              --append               Read existing JSON and top up
              --time-budget <min>    Soft cap in minutes; clean exit when exceeded
            """)
            exit(0)
        default:
            fatalError("Unknown arg: \(arg). Use --help.")
        }
        i += 1
    }
    return a
}

// MARK: - IO

func loadExistingPack(at path: String) -> PuzzlePack? {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else { return nil }
    let dec = JSONDecoder()
    return try? dec.decode(PuzzlePack.self, from: data)
}

func writePackAtomically(_ pack: PuzzlePack, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    let tmp = url.appendingPathExtension("tmp")
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try enc.encode(pack)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: tmp, options: .atomic)
    if FileManager.default.fileExists(atPath: url.path) {
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    } else {
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}

// MARK: - Helpers

func countGivens(_ s: String) -> Int {
    s.filter { $0 != "0" && $0 != "." }.count
}

func nowISO8601() -> String {
    ISO8601DateFormatter().string(from: Date())
}

// MARK: - Main

let args = parseArgs()

let generator = SudokuPuzzleGenerator()
let solver    = SudokuSolver(stepLimit: 2_000_000)
let rater     = TechniqueRater()
let hasher    = SHA256Hasher()
let repo      = InMemoryPuzzleRepository()

// Bootstrap pack — either from disk (--append) or fresh.
var pack: PuzzlePack
if args.append, let existing = loadExistingPack(at: args.output) {
    pack = existing
    // Pre-load existing hashes into the dedup repo so we don't reprocess them.
    for (_, entries) in existing.puzzles {
        for entry in entries {
            let puzzle = Puzzle(
                id: UUID(uuidString: entry.id) ?? UUID(),
                hash: hasher.canonicalHash(for: entry.givens),
                puzzleString: entry.givens,
                solutionString: entry.solution,
                difficulty: .easy,  // not used for dedup; hash is the key
                source: .preloaded
            )
            try? await repo.save(puzzle)
        }
    }
} else {
    pack = PuzzlePack(
        schemaVersion: 1,
        generatedAt: nowISO8601(),
        generatorSourceSha: "b02c848f62ad4ad70fc6f1079916e193cb9470ae",
        puzzles: Difficulty.allCases.reduce(into: [:]) { $0[$1.rawValue] = [] }
    )
}

let useCase = GeneratePuzzleUseCase(
    generator: generator,
    solver: solver,
    rater: rater,
    hasher: hasher,
    repository: repo
)

let startTime = Date()
let budgetSeconds: TimeInterval? = args.timeBudgetMinutes.map { $0 * 60 }

func budgetExceeded() -> Bool {
    guard let b = budgetSeconds else { return false }
    return Date().timeIntervalSince(startTime) >= b
}

var lastLogTime = Date()

func logProgress() {
    let elapsed = Date().timeIntervalSince(startTime)
    let mm = Int(elapsed) / 60
    let ss = Int(elapsed) % 60
    print("---")
    for d in Difficulty.allCases {
        let have = pack.puzzles[d.rawValue]?.count ?? 0
        let pct = args.perDifficulty == 0 ? 0 : (have * 100 / args.perDifficulty)
        print(String(format: "  %-8s %4d/%-4d (%2d%%)", d.rawValue, have, args.perDifficulty, pct))
    }
    if let b = args.timeBudgetMinutes {
        print(String(format: "  elapsed: %dm%02ds  budget: %.0fm", mm, ss, b))
    } else {
        print(String(format: "  elapsed: %dm%02ds", mm, ss))
    }
}

// One seed counter, advancing across all difficulties — guarantees seed
// uniqueness within a single run. Start high so we never collide with
// the upstream SeedGenerator's seedStart=10_000 (their bundled pack).
var seed = 100_000

logProgress()

generation: for difficulty in args.difficulties {
    while (pack.puzzles[difficulty.rawValue]?.count ?? 0) < args.perDifficulty {
        if budgetExceeded() {
            print("\n⏱  Time budget exceeded — writing and exiting cleanly.")
            break generation
        }

        seed += 1
        let result: GeneratePuzzleUseCase.Result
        do {
            result = try await useCase.runSavingRatedCandidate(targetDifficulty: difficulty, seed: seed)
        } catch SudokuCoreError.hashAlreadyExists {
            continue   // duplicate of an already-saved puzzle; skip
        } catch {
            continue   // generator/solver/rater rejection; try next seed
        }

        // Accept only puzzles whose rated difficulty matches the target.
        guard result.matchesTarget else { continue }

        let entry = PuzzleEntry(
            id: result.puzzle.id.uuidString,
            givens: result.puzzle.puzzleString,
            solution: result.puzzle.solutionString,
            givenCount: countGivens(result.puzzle.puzzleString)
        )
        pack.puzzles[difficulty.rawValue, default: []].append(entry)

        // Log every 60 seconds.
        if Date().timeIntervalSince(lastLogTime) >= 60 {
            logProgress()
            lastLogTime = Date()
        }
    }
}

// Final write.
pack.generatedAt = nowISO8601()
try writePackAtomically(pack, to: args.output)
print("\n✓ Wrote \(args.output)")
logProgress()
```

- [ ] **Step 3: Build the CLI tool**

```bash
cd Tools/GenerateSudokuPack && swift build 2>&1 | tail -20
```

Expected: `Build complete!` If errors mention `await` outside async context — Swift 6 top-level `await` requires the file to be treated as async. `main.swift` in an executable target supports top-level `await` by default in Swift 6 — if it complains, wrap the top-level code in:

```swift
@main
struct Main {
    static func main() async throws {
        // ... all the top-level code here
    }
}
```

Return to repo root: `cd ../..`.

- [ ] **Step 4: Do not commit yet — placeholder pack arrives in Task 8.**

---

## Task 8: Generate placeholder SudokuPuzzles.json (40 puzzles)

**Files:**
- Create: `gamekit/gamekit/Resources/SudokuPuzzles.json`

The full 1500-per-difficulty pack lands in Phase 17 (separate plan). Phase 14 ships a tiny placeholder so the app target compiles + the resource is wired.

- [ ] **Step 1: Run the CLI with --per-difficulty 10**

```bash
cd Tools/GenerateSudokuPack
swift run -c release GenerateSudokuPack \
  --per-difficulty 10 \
  --output ../../gamekit/gamekit/Resources/SudokuPuzzles.json
```

Expected duration: 30 seconds to a few minutes (10 easy + 10 medium + 10 hard + 10 extreme). Final log shows each difficulty at 10/10.

Return to repo root: `cd ../..`.

- [ ] **Step 2: Sanity-check the JSON**

```bash
python3 -c "
import json
with open('gamekit/gamekit/Resources/SudokuPuzzles.json') as f:
    pack = json.load(f)
print(f\"schemaVersion: {pack['schemaVersion']}\")
print(f\"generatedAt: {pack['generatedAt']}\")
print(f\"generatorSourceSha: {pack['generatorSourceSha']}\")
for d, entries in pack['puzzles'].items():
    print(f\"  {d}: {len(entries)} puzzles\")
    if entries:
        first = entries[0]
        assert len(first['givens']) == 81, f'givens not 81 chars: {len(first[\"givens\"])}'
        assert len(first['solution']) == 81, f'solution not 81 chars'
        assert first['givenCount'] == len(first['givens'].replace('0', '').replace('.', ''))
print('All entries valid.')
"
```

Expected output:
```
schemaVersion: 1
generatedAt: 2026-05-15T...
generatorSourceSha: b02c848f62ad4ad70fc6f1079916e193cb9470ae
  easy: 10 puzzles
  medium: 10 puzzles
  hard: 10 puzzles
  extreme: 10 puzzles
All entries valid.
```

If any assertion fails, the CLI has a bug — re-read Task 7 main.swift and fix.

- [ ] **Step 3: Add the JSON as a build resource of the gamekit target**

Xcode 16's synchronized root group auto-picks up the new file under `gamekit/gamekit/Resources/` and adds it to the target. Verify by opening Xcode:

1. In Project navigator, expand `gamekit` → `Resources`. `SudokuPuzzles.json` should be visible.
2. Click `SudokuPuzzles.json` → File Inspector (right panel, ⌥⌘1) → "Target Membership" → `gamekit` checkbox is ticked.

If it is NOT ticked (rare — happens if the synchronized group has an exception list), tick it manually.

- [ ] **Step 4: Verify the app still builds with the new resource**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit Tasks 7 + 8 together (CLI tool + placeholder pack)**

```bash
git add Tools/GenerateSudokuPack/ gamekit/gamekit/Resources/SudokuPuzzles.json
git commit -m "$(cat <<'EOF'
feat(14-03): GenerateSudokuPack CLI + 40-puzzle placeholder pack

Tools/GenerateSudokuPack is a small Swift Package executable that runs
SudokuCore's GeneratePuzzleUseCase in a loop, dedupes by hash, accepts
only puzzles whose rated difficulty matches the target, and writes a
JSON pack matching SudokuPuzzlePool's expected schema. Supports
--per-difficulty, --difficulties (csv), --output, --append (resumable),
and --time-budget (clean exit for batched generation sessions).

Placeholder pack — 10 puzzles per difficulty (40 total) — committed
to gamekit/gamekit/Resources/SudokuPuzzles.json so the app target has
a real bundle resource to load. The full 1500/difficulty pack is
generated in Phase 17 by repeated --append runs.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Phase verification

- [ ] **Step 1: SudokuCore tests green**

```bash
cd Packages/SudokuCore && swift test 2>&1 | tail -5 && cd ../..
```

Expected last line: `Test Suite 'All tests' passed`.

- [ ] **Step 2: GenerateSudokuPack builds and runs**

```bash
cd Tools/GenerateSudokuPack && swift build 2>&1 | tail -3 && cd ../..
```

Expected: `Build complete!`

- [ ] **Step 3: Main app target builds clean**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Resource is bundled**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  -showBuildSettings 2>&1 | grep -i CONFIGURATION_BUILD_DIR | head -1
```

Read the path, then verify the `.app` bundle contains the JSON (after a build the Resources folder should contain it, but exact path varies):

```bash
find ~/Library/Developer/Xcode/DerivedData -name "SudokuPuzzles.json" -path "*/gamekit.app/*" 2>/dev/null | head -1
```

Expected: at least one path printed (the JSON is in the built `.app`).

- [ ] **Step 5: Verification commit (optional — no code change, just a marker)**

If all four verifications pass, no further commit is needed — the previous commits cover the work. Phase 14 is done when:

- `feat(14-01)` — vendored engine present
- `feat(14-02)` — SPM dep wired
- `feat(14-03)` — CLI tool + placeholder pack present
- All three verification commands pass

- [ ] **Step 6: Append Phase 14 entry to `Docs/releases/v1.2.md`**

Per CLAUDE.md §0.3 / §8.14, every significant change appends to the release log for the current `MARKETING_VERSION`. The current version is 1.2 (per `gamekit/gamekit.xcodeproj/project.pbxproj`'s `MARKETING_VERSION = 1.2;`).

Open `Docs/releases/v1.2.md` and append under the **Internal changes** section:

```markdown
- **Phase 14 — Sudoku engine vendored.** Imported `cxnielsen/sudokuplus`
  SudokuCore engine at SHA `b02c848` as a local Swift Package under
  `Packages/SudokuCore/`. Dropped upstream SQLite repository (we ship
  puzzles from a bundled JSON pack instead). Added `Tools/GenerateSudokuPack`
  CLI for offline JSON pack generation. Placeholder pack of 40 puzzles
  shipped in `Resources/SudokuPuzzles.json` so the app target compiles;
  the full 1500-per-difficulty pack arrives in Phase 17.
```

Then commit:

```bash
git add Docs/releases/v1.2.md
git commit -m "$(cat <<'EOF'
docs(14): append Phase 14 (Sudoku engine vendor) to v1.2 release log

Per CLAUDE.md §0.3 / §8.14 — significant phase work appends to the
release log for the current MARKETING_VERSION.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Final status**

```bash
git log --oneline -5
git status
```

Expected: top 4 commits are `docs(14)`, `feat(14-03)`, `feat(14-02)`, `feat(14-01)`. `git status` clean (or only showing the pre-existing `Localizable.xcstrings` modification + `.claude/` directory, both unrelated to this phase).

**Phase 14 done. Phase 15 (game vertical slice) is a separate plan.**

---

## Summary of what this plan delivers

After all 9 tasks complete:

1. `Packages/SudokuCore/` — local Swift Package with the vendored engine (9 source files + tests + README + InMemoryPuzzleRepository). All upstream tests green.
2. `Tools/GenerateSudokuPack/` — Swift CLI that produces JSON puzzle packs with `--append` resumability + `--time-budget` for batched generation.
3. `gamekit/gamekit/Resources/SudokuPuzzles.json` — 40-puzzle placeholder so the app target's resource lookup compiles + runs.
4. `gamekit/gamekit.xcodeproj/project.pbxproj` — wired the local SudokuCore SPM dep onto the gamekit target.
5. `Docs/releases/v1.2.md` — Phase 14 entry appended.

The app does not yet show Sudoku in the drawer; that's Phase 15's job. Phase 14 is pure infrastructure: engine + tooling + bundle plumbing.

---

## Open items for downstream phases

These are intentionally NOT in Phase 14:

- **SudokuPuzzlePool** (runtime JSON loader, plays from the bundled pack) — Phase 15.
- **SudokuGameView + all UI** — Phase 15.
- **Drawer wiring (`GameKind.sudoku`, `GameRoute.sudoku`, `GameDescriptor` entry, `HomeView.destination(for:)` arm)** — Phase 15.
- **GameStats.record integration + SudokuStatsCard** — Phase 16.
- **Full 1500-per-difficulty pack** — Phase 17 (uses this plan's CLI tool with repeated `--append --time-budget 20` runs).

---

*End of Phase 14 plan.*
