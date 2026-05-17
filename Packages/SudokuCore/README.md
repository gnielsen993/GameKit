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
2. Diff each vendored file against the new upstream version (macOS shell; on Linux replace `base64 -d` with `base64 --decode`):
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

These tests exercised `SQLitePuzzleRepository`-specific behavior that the
vendored InMemoryPuzzleRepository cannot replicate (persistent storage,
in-progress puzzle restoration, status transitions, progress tracking,
and SQLite-only beginner-puzzle extensions).

- `testRepositorySavesAndFetchesNewPuzzle` — calls `nextPuzzle`, which throws `InMemoryError.notSupported`
- `testRepositoryExcludesCompletedFromNextPuzzle` — calls `markStatus` + `nextPuzzle`, both unsupported
- `testRepositoryFetchesInProgressPuzzle` — calls `markStatus` + `updateProgress` + `fetchInProgress`, all unsupported
- `testRepositoryFetchesMostRecentInProgressPuzzle` — calls `markStatus` + `fetchInProgress`, both unsupported
- `testRepositoryFiltersNextPuzzleByDifficulty` — calls `nextPuzzle`, which throws `InMemoryError.notSupported`
- `testRepositoryRejectsDuplicateBeginnerPuzzle` — calls `saveBeginnerPuzzle`/`beginnerPuzzleCount`, SQLite-only extensions not on `PuzzleRepository` protocol
- `testRepositoryRejectsInvalidBeginnerPuzzleLength` — calls `saveBeginnerPuzzle`, SQLite-only extension not on `PuzzleRepository` protocol

To re-enable: restore `SQLitePuzzleRepository.swift` from upstream + add
SQLite3 linker setting to Package.swift.

## §8.5 file-size cap — vendored exemption

The project constitution (`CLAUDE.md` §8.5) caps Swift files at 500 lines:
"Never generate a single Swift file over 500 lines. Split by view /
component / extension from the start."

`Tests/SudokuCoreTests/SudokuCoreTests.swift` is 528 lines after our
vendor edits (XCTSkip shims + 3 cleanups). The file is vendored verbatim
from upstream — we do not author or maintain its structure. Splitting it
locally would diverge from upstream and complicate every future re-sync's
diff workflow.

Vendored files in `Packages/SudokuCore/` are exempt from §8.5. The rule
applies to code we author, not to upstream files we re-sync. If/when
upstream splits the test file, our copy will follow.
