# Sudoku Phase 15 — Game Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Sudoku game as a playable vertical slice — drawer entry, four difficulty mode chips, full board interaction (cell selection, value placement, pencil notes, undo, timer), two game modes (`.free` and `.lives` mirroring Nonogram), end-state banner, win/loss recording via `GameStats`. Theme-audited under Classic + at least one Loud/Moody preset per CLAUDE.md §8.12.

**Architecture:** Mirrors Nonogram's file shape 1:1 under `gamekit/gamekit/Games/Sudoku/`. Pure model layer (`SudokuBoard`, `SudokuCell`, `SudokuGameState`, `SudokuGameMode`, `SudokuDifficulty`, `SudokuInteractionMode`) is Foundation-only and unit-testable. `SudokuPuzzlePool` (actor) loads `Resources/SudokuPuzzles.json` from the bundle and serves next-unplayed entries per difficulty. `SudokuViewModel` (`@Observable @MainActor`) orchestrates board mutations, applies mode rules (free vs lives), drives the 1-second timer, and reports terminal outcomes through `GameStats.record(...)`. SwiftUI views (`SudokuBoardView`, `SudokuCellView`, `SudokuNumberPad`, `SudokuHeaderBar`, `SudokuModePill`, `SudokuLivesChip`, `SudokuEndStateCard`, `SudokuToolbarMenu`, `SudokuGameView`) read DesignKit semantic tokens exclusively — zero hardcoded colors/spacing. Drawer wiring extends `GameKind`, `GameRoute`, `GameDescriptor.all`, and `HomeView.destination(for:)` switch by exactly one case each.

**Tech Stack:** Swift 6, SwiftUI, DesignKit semantic tokens, SwiftData via existing `GameStats` (no new model), Foundation, `Observation` framework.

**Reference design spec:** `Docs/superpowers/specs/2026-05-15-sudoku-integration-design.md`
**Phase 14 plan (prerequisite, already shipped):** `Docs/superpowers/plans/2026-05-15-sudoku-phase-14-vendor-engine.md`

---

## Sudoku-specific design decisions (locked here for execution)

1. **Pencil notes UX gesture.** Dedicated pencil-toggle button in the `SudokuHeaderBar` (mirrors Nonogram's `.place`/`.mark` `InteractionMode` pill). Long-press alternative DEFERRED to a post-v1 polish pass.
2. **Auto-clear peer notes.** Default ON. When a value commits to a cell, that value is removed from notes in the same row, column, and 3×3 box. NOT user-toggleable in v1 (spec §10 — "v1.3+ call").
3. **End-state banner copy.**
   - Win: title `"You solved it!"`, subtitle showing time + difficulty (e.g., `"Hard · 4:32"`). Primary CTA `"New puzzle"`, secondary `"View board"` (dismisses banner so the user can inspect the solved board).
   - Loss (lives only): title `"Out of mistakes"`, subtitle `"You used all 3 lives."`, primary CTA `"Try again"`, secondary `"View board"`.
4. **First-tap timer start.** Mirrors Nonogram: `.idle` → `.playing` on first interaction (cell select counts; the first VALUE placement is what flips it — mere selection without commit stays `.idle`).
5. **Highlight rules at v1.**
   - Selected cell: strong accent overlay (≈18% opacity of theme accent).
   - Same row / column / 3×3 box peers: subtle accent overlay (≈6% opacity).
   - Same-number cells (cells across the board that share the selected cell's value, including the selected cell itself): medium accent overlay (≈10% opacity).
   - Wrong placement (`.lives` mode rejection): theme danger color, 600ms shake + red flash, then committed-cell returns to normal.
6. **Undo scope.** Single-step. Stored as `lastUndoSnapshot: SudokuUndoSnapshot?` on the ViewModel. Captures `(row, col, prevValue, prevNotes, prevMistakeCount)`. Consumed on `undo()`. No redo, no multi-step history.
7. **Mistakes counter visibility.** Hidden in `.free` mode entirely (`SudokuLivesChip` does not render). In `.lives` mode: 3 dots, dim as mistakes accumulate; render top-left of `SudokuHeaderBar`.

---

## File structure

### New files (17)

```
gamekit/gamekit/Games/Sudoku/                               ← NEW folder
  SudokuDifficulty.swift                                    ← raw-string enum
  SudokuCell.swift                                          ← struct: value + notes + isGiven
  SudokuBoard.swift                                         ← 9×9 grid wrapper
  SudokuGameMode.swift                                      ← .free / .lives + livesPerPuzzle
  SudokuGameState.swift                                     ← lifecycle enum (idle/playing/won/gameOver)
  SudokuInteractionMode.swift                               ← .value / .note
  SudokuUndoSnapshot.swift                                  ← captured cell pre-state
  SudokuPuzzleEntry.swift                                   ← Codable mirror of pack JSON entry
  SudokuPuzzlePack.swift                                    ← Codable mirror of pack JSON root
  SudokuPuzzlePool.swift                                    ← actor: bundle JSON loader + next-unplayed
  SudokuViewModel.swift                                     ← @Observable @MainActor orchestrator
  SudokuCellView.swift                                      ← single cell SwiftUI view
  SudokuBoardView.swift                                     ← 9×9 grid w/ box-thick borders
  SudokuNumberPad.swift                                     ← 1-9 buttons + remaining-count badges
  SudokuLivesChip.swift                                     ← 3-dot chip for .lives mode
  SudokuModePill.swift                                      ← .value/.note toggle pill
  SudokuHeaderBar.swift                                     ← timer + mistakes chip + mode pill
  SudokuEndStateCard.swift                                  ← win/loss banner content
  SudokuToolbarMenu.swift                                   ← Restart + Change-difficulty menu
  SudokuGameView.swift                                      ← full screen assembly
  SudokuGameView+VideoMode.swift                            ← .videoModeAware integration

gamekit/gamekit/Games/Sudoku/Engine/                        ← (optional thin wrappers if needed during build)
  -- (likely empty after Phase 14's SudokuCore vendor; remove if unused)
```

### Modified files (3)

```
gamekit/gamekit/Core/GameKind.swift                ← add `case sudoku`
gamekit/gamekit/Core/GameRoute.swift               ← add `case sudoku(SudokuDifficulty?)`
gamekit/gamekit/Core/GameDescriptor.swift          ← append Sudoku entry to `static let all`
gamekit/gamekit/Screens/HomeView.swift             ← add `.sudoku(...)` switch arm in destination(for:)
```

### Test files (4 new)

```
gamekit/gamekitTests/SudokuBoardTests.swift                 ← board mutation + peer detection
gamekit/gamekitTests/SudokuPuzzlePoolTests.swift            ← JSON load + next-unplayed cycle
gamekit/gamekitTests/SudokuViewModelTests.swift             ← place/erase/undo + free/lives mode rules
gamekit/gamekitTests/SudokuStatsIntegrationTests.swift      ← GameStats.record writes correct fields
```

### Modified files (release log)

```
Docs/releases/v1.2.md                              ← append Phase 15 entry under (15) heading
```

---

## Commit boundaries

| Commit | Scope |
|---|---|
| `feat(15-01)` | Pool + data types + corresponding tests. App target builds; no UI yet. |
| `feat(15-02)` | SudokuViewModel + tests. Still no UI; viewmodel exercised by unit tests only. |
| `feat(15-03)` | All SwiftUI views (board, cell, numpad, header, mode pill, lives chip, end-state, toolbar menu, game view + VideoMode). |
| `feat(15-04)` | Drawer wiring (3 enum cases + descriptor + destination arm) + release log entry. Phase 15 user-visible end state. |

Code-review follow-up commits (`chore(15-NN)`) land between feats as needed.

---

## Task 1 — `SudokuDifficulty.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuDifficulty.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuDifficulty.swift
//  gamekit
//
//  Raw-string enum identifying Sudoku difficulty tier. The raw value is the
//  stable serialization key written to GameRecord.difficultyRaw and to the
//  pack JSON's `puzzles.<key>` lookup. Renaming = data break + pack
//  mismatch.
//
//  Mirrors NonogramDifficulty's shape: raw String, CaseIterable, Codable,
//  Sendable, Hashable. Order in `allCases` = render order in the drawer
//  mode-chip row + StatsView.
//

import Foundation

enum SudokuDifficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case easy
    case medium
    case hard
    case extreme

    /// Human-readable label for chips, headers, end-state banners.
    var displayName: String {
        switch self {
        case .easy:    return "Easy"
        case .medium:  return "Medium"
        case .hard:    return "Hard"
        case .extreme: return "Extreme"
        }
    }
}
```

- [ ] **Step 2: Add to gamekit target**

File auto-registers via Xcode 16 synchronized root group (CLAUDE.md §8.8). No pbxproj edit needed.

- [ ] **Step 3: Do not commit yet — committed at end of Task 6 as feat(15-01).**

---

## Task 2 — `SudokuCell.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuCell.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuCell.swift
//  gamekit
//
//  Single cell in the 9×9 Sudoku grid. Three populated states:
//    - .given: a clue from the puzzle (locked, cannot be erased or
//      modified by the player)
//    - .user(Int): a player-placed value 1...9
//    - .empty(notes: Set<Int>): no committed value, optional pencil
//      marks (1...9 set)
//
//  `notes` only meaningful in `.empty` — `.given` and `.user` ignore it.
//  Value cells (.given / .user) implicitly clear notes.
//

import Foundation

enum SudokuCell: Equatable, Hashable, Codable, Sendable {
    case given(Int)              // value 1...9, locked
    case user(Int)               // value 1...9, placed by player
    case empty(notes: Set<Int>)  // notes ⊆ {1...9}

    /// Currently-visible value, or nil if empty. Reads from .given or .user.
    var value: Int? {
        switch self {
        case .given(let v): return v
        case .user(let v):  return v
        case .empty:        return nil
        }
    }

    /// True for clue cells (.given). Player input + erase target this flag
    /// to no-op on locked cells.
    var isGiven: Bool {
        if case .given = self { return true }
        return false
    }

    /// True for cells the player can interact with (everything except .given).
    var isPlayerEditable: Bool { !isGiven }

    /// Currently-stored notes, or empty set if not in .empty state.
    var notes: Set<Int> {
        if case .empty(let n) = self { return n }
        return []
    }
}
```

---

## Task 3 — `SudokuBoard.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuBoard.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuBoard.swift
//  gamekit
//
//  9×9 grid of SudokuCell. Immutable value type — mutations return a new
//  Board (mirrors NonogramBoard.setting(...) pattern). Indexed by
//  (row: 0..<9, col: 0..<9).
//
//  Givens and solution strings use the SudokuCore pack convention:
//    - 81-char string
//    - characters '1'..'9' = filled value; '0' or '.' = empty
//    - row-major order (row 0 cols 0..8, then row 1 cols 0..8, …)
//

import Foundation

struct SudokuBoard: Equatable, Hashable, Sendable {
    static let size: Int = 9
    static let boxSize: Int = 3

    /// Row-major flat array, length 81.
    private(set) var cells: [SudokuCell]

    /// Solution string for win-check + .lives validation. 81 chars, '1'..'9'.
    let solution: String

    /// Initialize from puzzle pack strings.
    /// - Parameter givens: 81-char string, '0'/'.' = empty, '1'..'9' = clue.
    /// - Parameter solution: 81-char solved board.
    /// Returns nil if either string is malformed.
    init?(givens: String, solution: String) {
        guard givens.count == 81, solution.count == 81 else { return nil }
        guard solution.allSatisfy({ $0 >= "1" && $0 <= "9" }) else { return nil }

        var cells: [SudokuCell] = []
        cells.reserveCapacity(81)
        for ch in givens {
            switch ch {
            case "1"..."9":
                guard let v = Int(String(ch)) else { return nil }
                cells.append(.given(v))
            case "0", ".":
                cells.append(.empty(notes: []))
            default:
                return nil
            }
        }
        self.cells = cells
        self.solution = solution
    }

    /// Direct cell accessor.
    func cell(row: Int, col: Int) -> SudokuCell {
        cells[row * Self.size + col]
    }

    /// Returns a copy of the board with the given cell replaced.
    func setting(_ cell: SudokuCell, atRow row: Int, col: Int) -> SudokuBoard {
        var copy = self
        copy.cells[row * Self.size + col] = cell
        return copy
    }

    /// Solution digit at (row, col), 1...9. Always defined per init guard.
    func solutionDigit(atRow row: Int, col: Int) -> Int {
        let ch = solution[solution.index(solution.startIndex, offsetBy: row * Self.size + col)]
        return Int(String(ch))!  // safe: solution chars validated in init
    }

    /// True when every cell holds the correct solution digit.
    var isSolved: Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                let cell = cell(row: r, col: c)
                guard let v = cell.value, v == solutionDigit(atRow: r, col: c) else {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Peer geometry

    /// All cell indices in the same row, column, or 3×3 box as (row, col),
    /// EXCLUDING the cell itself. 20 peers per cell.
    static func peerIndices(row: Int, col: Int) -> Set<Int> {
        var peers: Set<Int> = []
        // Row
        for c in 0..<size where c != col {
            peers.insert(row * size + c)
        }
        // Column
        for r in 0..<size where r != row {
            peers.insert(r * size + col)
        }
        // 3×3 box
        let boxRow = (row / boxSize) * boxSize
        let boxCol = (col / boxSize) * boxSize
        for r in boxRow..<(boxRow + boxSize) {
            for c in boxCol..<(boxCol + boxSize) {
                if r != row || c != col {
                    peers.insert(r * size + c)
                }
            }
        }
        return peers
    }

    /// Remove `value` from every peer cell's notes. Used when a value
    /// commits — auto-clears stale notes per spec.
    func clearingPeerNotes(of value: Int, fromRow row: Int, col: Int) -> SudokuBoard {
        let peers = Self.peerIndices(row: row, col: col)
        var copy = self
        for idx in peers {
            if case .empty(var notes) = copy.cells[idx], notes.contains(value) {
                notes.remove(value)
                copy.cells[idx] = .empty(notes: notes)
            }
        }
        return copy
    }
}
```

---

## Task 4 — Small enums

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuGameMode.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuGameState.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuInteractionMode.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuUndoSnapshot.swift`

- [ ] **Step 1: Write `SudokuGameMode.swift`**

```swift
//
//  SudokuGameMode.swift
//  gamekit
//
//  Two-mode toggle for the Sudoku session:
//    - .free  → wrong placements highlight red but never lock the cell or
//               fail the session. Player can erase + retry freely.
//    - .lives → wrong placements increment mistakes (cap 3). Correct
//               placements lock the cell. 3 mistakes → .gameOver.
//
//  rawValue is the stable UserDefaults key for `sudoku.lastGameMode`.
//  Renaming = data break.
//

import Foundation

enum SudokuGameMode: String, Codable, Sendable, CaseIterable, Hashable {
    case free
    case lives

    static let livesPerPuzzle: Int = 3
}
```

- [ ] **Step 2: Write `SudokuGameState.swift`**

```swift
//
//  SudokuGameState.swift
//  gamekit
//
//  Lifecycle state for a Sudoku session. Mirrors NonogramGameState shape.
//

import Foundation

enum SudokuGameState: Equatable, Hashable, Sendable {
    case idle       // pre-first-placement; timer not yet started
    case playing    // active session; timer running
    case won        // board solved; timer frozen
    case gameOver   // .lives mode: mistakes == 3; timer frozen
}
```

- [ ] **Step 3: Write `SudokuInteractionMode.swift`**

```swift
//
//  SudokuInteractionMode.swift
//  gamekit
//
//  Pencil toggle for the number pad:
//    - .value → tapping a number-pad button commits the value to the
//               selected cell.
//    - .note  → tapping a number-pad button toggles that digit in the
//               selected cell's notes set.
//
//  Selecting the same number-pad digit twice in .note mode (with same
//  cell selected) clears it from the notes set.
//

import Foundation

enum SudokuInteractionMode: String, Codable, Sendable, CaseIterable, Hashable {
    case value
    case note
}
```

- [ ] **Step 4: Write `SudokuUndoSnapshot.swift`**

```swift
//
//  SudokuUndoSnapshot.swift
//  gamekit
//
//  Captured pre-mutation state for the single-step undo. Carries the
//  cell coordinates + the cell's previous SudokuCell value + the
//  previous mistakes count (so undoing a wrong placement also returns
//  the life). One snapshot held at a time; consumed on undo().
//

import Foundation

struct SudokuUndoSnapshot: Equatable, Sendable {
    let row: Int
    let col: Int
    let previousCell: SudokuCell
    let previousMistakes: Int
}
```

---

## Task 5 — `SudokuPuzzleEntry.swift` + `SudokuPuzzlePack.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuPuzzleEntry.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuPuzzlePack.swift`

These mirror the JSON schema written by `tools/GenerateSudokuPack/`. App-side reader.

- [ ] **Step 1: Write `SudokuPuzzleEntry.swift`**

```swift
//
//  SudokuPuzzleEntry.swift
//  gamekit
//
//  Codable mirror of one entry in Resources/SudokuPuzzles.json. Matches
//  the schema written by tools/GenerateSudokuPack (Phase 14, Task 7).
//

import Foundation

struct SudokuPuzzleEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String           // UUID string
    let givens: String       // 81 chars
    let solution: String     // 81 chars
    let givenCount: Int
}
```

- [ ] **Step 2: Write `SudokuPuzzlePack.swift`**

```swift
//
//  SudokuPuzzlePack.swift
//  gamekit
//
//  Codable mirror of the root document of Resources/SudokuPuzzles.json.
//  Schema version 1; matches tools/GenerateSudokuPack output exactly.
//

import Foundation

struct SudokuPuzzlePack: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let generatorSourceSha: String
    let puzzles: [String: [SudokuPuzzleEntry]]
}
```

---

## Task 6 — `SudokuPuzzlePool.swift` (actor)

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuPuzzlePool.swift`

This is the runtime loader. Reads `SudokuPuzzles.json` from the bundle lazily on first call, caches in memory, and serves next-unplayed entries per difficulty.

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuPuzzlePool.swift
//  gamekit
//
//  Actor that owns the bundled SudokuPuzzles.json pack. Lazy-loads on
//  first access (off main thread), caches parsed entries per difficulty,
//  and serves next-unplayed entries. "Played" is derived from
//  GameRecord rows (gameKindRaw == "sudoku" && outcomeRaw == "win" &&
//  puzzleIdRaw matches an entry id) — provided by the caller via the
//  `playedIDs(for:)` injection.
//
//  When a difficulty's pool is exhausted (every entry has a corresponding
//  played GameRecord), the pool silently recycles by emptying its in-
//  memory "played" set and returning the first entry. The persistent
//  GameRecord history is untouched, so a future "Solved Sudoku" gallery
//  still sees full history.
//
//  In-session cursor prevents consecutive `next(...)` calls within one
//  session from repeating before any GameRecord is written.
//

import Foundation

public actor SudokuPuzzlePool {

    public enum PoolError: Error, Equatable {
        case bundleResourceMissing
        case decodeFailed(String)
    }

    private let bundle: Bundle
    private let resourceName: String
    private let resourceExtension: String

    private var pack: SudokuPuzzlePack?
    private var cursor: [SudokuDifficulty: Int] = [:]   // session-local round-robin

    public init(
        bundle: Bundle = .main,
        resourceName: String = "SudokuPuzzles",
        resourceExtension: String = "json"
    ) {
        self.bundle = bundle
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
    }

    /// Force a load; returns the loaded pack. Called implicitly by other
    /// methods on first access. Exposed for tests + warm-up.
    @discardableResult
    public func load() throws -> SudokuPuzzlePack {
        if let pack { return pack }
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw PoolError.bundleResourceMissing
        }
        let data = try Data(contentsOf: url)
        do {
            let decoded = try JSONDecoder().decode(SudokuPuzzlePack.self, from: data)
            self.pack = decoded
            return decoded
        } catch {
            throw PoolError.decodeFailed(String(describing: error))
        }
    }

    /// Total puzzles available for the given difficulty.
    public func count(for difficulty: SudokuDifficulty) throws -> Int {
        let pack = try load()
        return pack.puzzles[difficulty.rawValue]?.count ?? 0
    }

    /// Return the next un-played puzzle for `difficulty`. `playedIDs` is
    /// the set of puzzle IDs already won (caller-supplied — typically
    /// queried from GameRecord). Silent recycle when exhausted.
    public func next(
        difficulty: SudokuDifficulty,
        playedIDs: Set<String>
    ) throws -> SudokuPuzzleEntry {
        let pack = try load()
        guard let entries = pack.puzzles[difficulty.rawValue], !entries.isEmpty else {
            throw PoolError.decodeFailed("No entries for difficulty: \(difficulty.rawValue)")
        }

        // Combine caller's set with session-cursor-local exclusions to
        // avoid serving the same puzzle twice in one session before any
        // GameRecord is written.
        let cursorIdx = cursor[difficulty] ?? 0

        // Walk starting from cursor; pick first entry not in playedIDs.
        for i in 0..<entries.count {
            let idx = (cursorIdx + i) % entries.count
            let candidate = entries[idx]
            if !playedIDs.contains(candidate.id) {
                cursor[difficulty] = (idx + 1) % entries.count
                return candidate
            }
        }

        // All entries played — recycle. Reset cursor and serve [0].
        cursor[difficulty] = 1 % entries.count
        return entries[0]
    }
}
```

---

## Commit boundary — feat(15-01)

At this point in execution, Tasks 1–6 have been completed. Time to commit Tasks 1–6 + their tests (Tasks 7 + 8 below) together.

---

## Task 7 — `SudokuBoardTests.swift`

**Files:**
- Create: `gamekit/gamekitTests/SudokuBoardTests.swift`

- [ ] **Step 1: Write tests using XCTest**

```swift
//
//  SudokuBoardTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

final class SudokuBoardTests: XCTestCase {

    // Standard test puzzle: a valid easy Sudoku with known solution.
    private let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    func testInit_rejectsMalformedGivens() {
        XCTAssertNil(SudokuBoard(givens: "tooshort", solution: testSolution))
        XCTAssertNil(SudokuBoard(givens: testGivens, solution: "tooshort"))
        XCTAssertNil(SudokuBoard(givens: String(repeating: "x", count: 81), solution: testSolution))
        XCTAssertNil(SudokuBoard(givens: testGivens, solution: String(repeating: "0", count: 81)))
    }

    func testInit_parsesGivensCorrectly() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertEqual(board.cell(row: 0, col: 0), .given(5))
        XCTAssertEqual(board.cell(row: 0, col: 1), .given(3))
        XCTAssertEqual(board.cell(row: 0, col: 2), .empty(notes: []))
        XCTAssertEqual(board.cell(row: 0, col: 4), .given(7))
        XCTAssertEqual(board.cell(row: 8, col: 8), .given(9))
    }

    func testSolutionDigit_matchesString() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertEqual(board.solutionDigit(atRow: 0, col: 0), 5)
        XCTAssertEqual(board.solutionDigit(atRow: 0, col: 2), 4)
        XCTAssertEqual(board.solutionDigit(atRow: 8, col: 8), 9)
    }

    func testSetting_returnsBoardWithCellChanged() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        let mutated = board.setting(.user(7), atRow: 0, col: 2)
        XCTAssertEqual(mutated.cell(row: 0, col: 2), .user(7))
        XCTAssertEqual(board.cell(row: 0, col: 2), .empty(notes: []))   // original unchanged
    }

    func testIsSolved_falseUntilAllCellsCorrect() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertFalse(board.isSolved)

        // Fill every empty cell with the solution digit; should now be solved.
        var b = board
        for r in 0..<9 {
            for c in 0..<9 {
                if case .empty = b.cell(row: r, col: c) {
                    b = b.setting(.user(b.solutionDigit(atRow: r, col: c)), atRow: r, col: c)
                }
            }
        }
        XCTAssertTrue(b.isSolved)
    }

    func testPeerIndices_excludesSelf_and_returns20Peers() {
        let peers = SudokuBoard.peerIndices(row: 4, col: 4)
        XCTAssertFalse(peers.contains(4 * 9 + 4))
        XCTAssertEqual(peers.count, 20)
        XCTAssertTrue(peers.contains(4 * 9 + 0))   // same row
        XCTAssertTrue(peers.contains(0 * 9 + 4))   // same col
        XCTAssertTrue(peers.contains(3 * 9 + 3))   // same 3×3 box
        XCTAssertFalse(peers.contains(0 * 9 + 0))  // unrelated
    }

    func testClearingPeerNotes_removesValueFromRowColBox() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        // Seed notes into 3 empty cells: same row, same col, same box.
        var b = board
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 0, col: 2)   // same row as (0,0)
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 5, col: 0)   // same col as (0,0)
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 1, col: 2)   // same box as (0,0)
        // Also one unrelated cell — should NOT lose its 7.
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 5, col: 5)   // unrelated

        let cleared = b.clearingPeerNotes(of: 7, fromRow: 0, col: 0)
        XCTAssertEqual(cleared.cell(row: 0, col: 2).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 5, col: 0).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 1, col: 2).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 5, col: 5).notes, [3, 5, 7])    // unrelated, untouched
    }

    func testGivenCells_areMarkedIsGiven() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertTrue(board.cell(row: 0, col: 0).isGiven)
        XCTAssertFalse(board.cell(row: 0, col: 2).isGiven)
        XCTAssertFalse(board.cell(row: 0, col: 2).isPlayerEditable == false)
    }
}
```

- [ ] **Step 2: Run tests**

Run from Xcode (⌘+U), or from CLI:

```bash
xcodebuild test \
  -project gamekit/gamekit.xcodeproj \
  -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:gamekitTests/SudokuBoardTests \
  2>&1 | tail -20
```

Expected: all 7 tests pass.

---

## Task 8 — `SudokuPuzzlePoolTests.swift`

**Files:**
- Create: `gamekit/gamekitTests/SudokuPuzzlePoolTests.swift`

- [ ] **Step 1: Write tests**

```swift
//
//  SudokuPuzzlePoolTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

final class SudokuPuzzlePoolTests: XCTestCase {

    /// Pool initialized against the real bundled SudokuPuzzles.json
    /// (40-puzzle placeholder pack from Phase 14).
    private func makeRealPool() -> SudokuPuzzlePool {
        SudokuPuzzlePool()
    }

    func test_loadsRealBundleResource() async throws {
        let pool = makeRealPool()
        let pack = try await pool.load()
        XCTAssertEqual(pack.schemaVersion, 1)
        XCTAssertEqual(pack.generatorSourceSha, "b02c848f62ad4ad70fc6f1079916e193cb9470ae")
        XCTAssertEqual(pack.puzzles.keys.sorted(), ["easy", "extreme", "hard", "medium"])
    }

    func test_countPerDifficulty_isAtLeastTen() async throws {
        let pool = makeRealPool()
        for d in SudokuDifficulty.allCases {
            let count = try await pool.count(for: d)
            XCTAssertGreaterThanOrEqual(count, 10, "Difficulty \(d.rawValue) has only \(count) entries")
        }
    }

    func test_next_returnsUnplayedEntry() async throws {
        let pool = makeRealPool()
        let first = try await pool.next(difficulty: .easy, playedIDs: [])
        XCTAssertEqual(first.givens.count, 81)
        XCTAssertEqual(first.solution.count, 81)
        XCTAssertGreaterThan(first.givenCount, 0)
    }

    func test_next_skipsPlayedIDs() async throws {
        let pool = makeRealPool()
        let first = try await pool.next(difficulty: .easy, playedIDs: [])
        let second = try await pool.next(difficulty: .easy, playedIDs: [first.id])
        XCTAssertNotEqual(first.id, second.id)
    }

    func test_next_recyclesWhenExhausted() async throws {
        let pool = makeRealPool()
        let pack = try await pool.load()
        guard let entries = pack.puzzles["easy"], entries.count >= 1 else {
            return XCTFail("Expected easy pool to have entries")
        }
        let everyID = Set(entries.map { $0.id })
        // With every ID marked played, pool should still return a valid entry.
        let recycled = try await pool.next(difficulty: .easy, playedIDs: everyID)
        XCTAssertEqual(entries.first?.id, recycled.id)
    }

    func test_decodeFails_onMalformedBundleResource() async {
        // Use a bundle that has no SudokuPuzzles.json under the wrong name.
        let pool = SudokuPuzzlePool(bundle: .main, resourceName: "DoesNotExist", resourceExtension: "json")
        do {
            _ = try await pool.load()
            XCTFail("Expected throw")
        } catch SudokuPuzzlePool.PoolError.bundleResourceMissing {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test \
  -project gamekit/gamekit.xcodeproj \
  -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:gamekitTests/SudokuPuzzlePoolTests \
  2>&1 | tail -20
```

Expected: all 6 tests pass.

---

## Task 9 — Commit feat(15-01)

- [ ] **Step 1: Verify build**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Stage + commit**

Stage only Phase 15 files (no unrelated working-tree changes):

```bash
git add gamekit/gamekit/Games/Sudoku/ gamekit/gamekitTests/SudokuBoardTests.swift gamekit/gamekitTests/SudokuPuzzlePoolTests.swift
git commit -m "$(cat <<'EOF'
feat(15-01): Sudoku data types + puzzle pool

Adds the pure-model layer for the Sudoku game vertical slice:
- SudokuDifficulty (raw-string enum, 4 cases matching pack JSON keys)
- SudokuCell (given/user/empty with notes Set)
- SudokuBoard (9×9 grid + peer-geometry helpers + auto-clear-peer-notes)
- SudokuGameMode (.free / .lives, livesPerPuzzle=3)
- SudokuGameState (idle/playing/won/gameOver)
- SudokuInteractionMode (.value / .note pencil toggle)
- SudokuUndoSnapshot (single-step undo capture)
- SudokuPuzzleEntry + SudokuPuzzlePack (Codable mirrors of pack JSON)
- SudokuPuzzlePool (actor; bundle JSON loader + next-unplayed cycle
  with silent recycle when exhausted + session-local cursor)

Tests: SudokuBoardTests (7 cases) + SudokuPuzzlePoolTests (6 cases),
all green. App target builds clean — no UI yet (Phase 15-03 ships
views).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Verify**

```bash
git log --oneline -3
```

Expected: top commit is the `feat(15-01)` just made.

---

## Task 10 — `SudokuViewModel.swift`

This is the orchestrator. Mirrors `NonogramViewModel`'s shape with Sudoku-specific state (selected cell, undo snapshot, value placement vs note placement).

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuViewModel.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator for the Sudoku screen. Mirrors
//  NonogramViewModel discipline (Foundation-only, all state private(set),
//  GameStats firewall — no SwiftData import here, GameRecord writes
//  routed through GameStats.record(...)).
//
//  Lifecycle:
//    - init: load pool (lazy), pick next unplayed puzzle, .idle state.
//    - first commit (place value or note) → .playing, timer starts.
//    - on every successful value commit: check isSolved → .won.
//    - .lives mode: 3 mistakes → .gameOver.
//
//  Selection model:
//    - User taps a cell → that cell becomes `selected`.
//    - User taps a number-pad button (1...9) → in .value mode, commits
//      that digit to the selected cell; in .note mode, toggles that
//      digit in the cell's notes.
//    - Erase button → clears value or notes from the selected cell
//      (no-op on .given cells; no-op on locked correct cells in .lives).
//

import Foundation
import Observation

@Observable @MainActor
final class SudokuViewModel {

    // MARK: - State surface

    private(set) var difficulty: SudokuDifficulty
    private(set) var currentPuzzle: SudokuPuzzleEntry?
    private(set) var board: SudokuBoard?
    private(set) var state: SudokuGameState = .idle
    private(set) var gameMode: SudokuGameMode = .free
    private(set) var interactionMode: SudokuInteractionMode = .value

    /// Currently-selected cell, or nil if none. Selection persists across
    /// mutations.
    private(set) var selected: (row: Int, col: Int)?

    // Timer (mirrors NonogramViewModel's pattern)
    private(set) var timerAnchor: Date?
    private(set) var pausedElapsed: TimeInterval = 0
    private(set) var frozenElapsed: TimeInterval = 0

    // Lives-mode state
    private(set) var mistakes: Int = 0
    /// Flat indices of cells locked by a correct .lives placement (or by
    /// being given). Erase + re-place no-op on these.
    private(set) var lockedCells: Set<Int> = []

    // Sensory feedback counters
    private(set) var placeCount: Int = 0
    private(set) var winCount: Int = 0
    private(set) var wrongAttemptCount: Int = 0
    /// Flat index of the most-recent wrong placement, for the red-flash +
    /// shake animation in CellView. Auto-cleared ~600ms after being set.
    private(set) var lastWrongAttemptIdx: Int?

    // Single-step undo
    private(set) var undoSnapshot: SudokuUndoSnapshot?

    // MARK: - Injection seams

    private let pool: SudokuPuzzlePool
    private let userDefaults: UserDefaults
    private let clock: () -> Date
    private(set) var gameStats: GameStats?

    // MARK: - Derived

    /// Live elapsed seconds (matches NonogramViewModel pattern).
    var elapsedSeconds: TimeInterval {
        if state == .won || state == .gameOver { return frozenElapsed }
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + clock().timeIntervalSince(anchor)
    }

    /// Currently-selected cell, or nil if none selected.
    var selectedCell: SudokuCell? {
        guard let s = selected, let board else { return nil }
        return board.cell(row: s.row, col: s.col)
    }

    /// Remaining count of each digit 1...9 (9 minus number of cells
    /// committed to that digit). Used by SudokuNumberPad badges.
    var remainingPerDigit: [Int: Int] {
        guard let board else {
            return Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 9) })
        }
        var counts: [Int: Int] = [:]
        for d in 1...9 { counts[d] = 9 }
        for cell in board.cells {
            if let v = cell.value, counts[v] != nil {
                counts[v]! -= 1
            }
        }
        return counts
    }

    // MARK: - Init

    init(
        difficulty: SudokuDifficulty? = nil,
        pool: SudokuPuzzlePool = SudokuPuzzlePool(),
        userDefaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { Date.now },
        gameStats: GameStats? = nil
    ) {
        self.pool = pool
        self.userDefaults = userDefaults
        self.clock = clock
        self.gameStats = gameStats

        let resolved = difficulty
            ?? SudokuDifficulty(rawValue: userDefaults.string(forKey: Self.lastDifficultyKey) ?? "")
            ?? .easy
        self.difficulty = resolved

        let resolvedMode = SudokuGameMode(rawValue: userDefaults.string(forKey: Self.lastGameModeKey) ?? "")
            ?? .free
        self.gameMode = resolvedMode

        // Load the first puzzle lazily.
        Task { @MainActor in
            await self.loadFreshPuzzle()
        }
    }

    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
    }

    // MARK: - Public API

    /// Select a cell. Does NOT mutate the board or start the timer.
    func select(row: Int, col: Int) {
        guard (0..<9).contains(row), (0..<9).contains(col) else { return }
        selected = (row, col)
    }

    /// Place a value 1...9 into the selected cell. Honors the current
    /// interactionMode: in .value commits the digit, in .note toggles it
    /// in the notes set.
    func place(value: Int) {
        guard (1...9).contains(value),
              let s = selected,
              let board else { return }
        let idx = s.row * 9 + s.col
        let cell = board.cell(row: s.row, col: s.col)

        // Givens are immutable.
        guard !cell.isGiven else { return }

        // .lives: locked correct cells are immutable.
        if gameMode == .lives && lockedCells.contains(idx) { return }

        switch interactionMode {
        case .value:
            commitValue(value, atRow: s.row, col: s.col)
        case .note:
            toggleNote(value, atRow: s.row, col: s.col)
        }
    }

    /// Erase the selected cell's value/notes. No-op on givens and on
    /// locked correct cells in .lives.
    func erase() {
        guard let s = selected, let board else { return }
        let idx = s.row * 9 + s.col
        let cell = board.cell(row: s.row, col: s.col)
        guard !cell.isGiven else { return }
        if gameMode == .lives && lockedCells.contains(idx) { return }
        guard case .user = cell.value.map({ _ in cell }) ?? .empty(notes: []) else {
            // Cell is empty — if notes present, clear them; else no-op.
            if case .empty(let notes) = cell, !notes.isEmpty {
                captureUndo(at: s.row, col: s.col, previousCell: cell)
                self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
            }
            return
        }
        captureUndo(at: s.row, col: s.col, previousCell: cell)
        self.board = board.setting(.empty(notes: []), atRow: s.row, col: s.col)
    }

    /// Restore the last mutation. Consumes the snapshot.
    func undo() {
        guard let snap = undoSnapshot, let board else { return }
        self.board = board.setting(snap.previousCell, atRow: snap.row, col: snap.col)
        self.mistakes = snap.previousMistakes
        undoSnapshot = nil
    }

    func setInteractionMode(_ mode: SudokuInteractionMode) {
        interactionMode = mode
    }

    func setDifficulty(_ d: SudokuDifficulty) {
        guard d != difficulty else { return }
        difficulty = d
        userDefaults.set(d.rawValue, forKey: Self.lastDifficultyKey)
        Task { @MainActor in await loadFreshPuzzle() }
    }

    func setGameMode(_ mode: SudokuGameMode) {
        guard mode != gameMode else { return }
        gameMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.lastGameModeKey)
        Task { @MainActor in await loadFreshPuzzle() }
    }

    /// Restart the current puzzle (same givens, fresh state).
    func restart() {
        guard let puzzle = currentPuzzle else { return }
        resetSessionState()
        board = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution)
    }

    /// Load a new (unplayed) puzzle for the current difficulty.
    func newPuzzle() {
        Task { @MainActor in await loadFreshPuzzle() }
    }

    func pause() {
        guard let anchor = timerAnchor else { return }
        pausedElapsed += clock().timeIntervalSince(anchor)
        timerAnchor = nil
    }

    func resume() {
        guard state == .playing, timerAnchor == nil else { return }
        timerAnchor = clock()
    }

    // MARK: - Private

    private func loadFreshPuzzle() async {
        resetSessionState()
        do {
            let playedIDs = await gameStats.flatMap { stats in
                stats.sudokuPlayedIDs(for: difficulty)
            } ?? Set<String>()
            let entry = try await pool.next(difficulty: difficulty, playedIDs: playedIDs)
            currentPuzzle = entry
            board = SudokuBoard(givens: entry.givens, solution: entry.solution)
            // Mark all .given cells as locked so erase() no-ops on them.
            var locked = Set<Int>()
            if let board {
                for i in 0..<81 {
                    if board.cells[i].isGiven { locked.insert(i) }
                }
            }
            lockedCells = locked
        } catch {
            currentPuzzle = nil
            board = nil
        }
    }

    private func resetSessionState() {
        state = .idle
        timerAnchor = nil
        pausedElapsed = 0
        frozenElapsed = 0
        mistakes = 0
        placeCount = 0
        wrongAttemptCount = 0
        lastWrongAttemptIdx = nil
        undoSnapshot = nil
        selected = nil
        lockedCells = []
        interactionMode = .value
    }

    private func commitValue(_ value: Int, atRow row: Int, col: Int) {
        guard var board else { return }
        let idx = row * 9 + col
        let prevCell = board.cell(row: row, col: col)
        let correct = board.solutionDigit(atRow: row, col: col) == value

        if gameMode == .lives {
            if !correct {
                // Wrong placement — increment mistakes, NO commit, record
                // the wrong-attempt for visual flash + haptic.
                if state == .idle { startTimer() }
                recordWrongAttempt(at: idx)
                return
            }
            // Correct — commit + lock + auto-clear peer notes.
            captureUndo(at: row, col: col, previousCell: prevCell)
            board = board.setting(.user(value), atRow: row, col: col)
            board = board.clearingPeerNotes(of: value, fromRow: row, col: col)
            self.board = board
            lockedCells.insert(idx)
            placeCount += 1
            if state == .idle { startTimer() }
            if board.isSolved { recordWin(); return }
            return
        }

        // .free mode — commit unconditionally. Wrong placements show red
        // via the CellView's solution-mismatch overlay, but no failure
        // state.
        captureUndo(at: row, col: col, previousCell: prevCell)
        board = board.setting(.user(value), atRow: row, col: col)
        board = board.clearingPeerNotes(of: value, fromRow: row, col: col)
        self.board = board
        placeCount += 1
        if state == .idle { startTimer() }
        if board.isSolved { recordWin() }
    }

    private func toggleNote(_ value: Int, atRow row: Int, col: Int) {
        guard let board else { return }
        let cell = board.cell(row: row, col: col)
        // Notes can only be added to .empty cells. Committing a value
        // clears notes implicitly.
        guard case .empty(var notes) = cell else { return }
        if notes.contains(value) {
            notes.remove(value)
        } else {
            notes.insert(value)
        }
        captureUndo(at: row, col: col, previousCell: cell)
        self.board = board.setting(.empty(notes: notes), atRow: row, col: col)
        if state == .idle { startTimer() }
    }

    private func startTimer() {
        state = .playing
        timerAnchor = clock()
        pausedElapsed = 0
    }

    private func captureUndo(at row: Int, col: Int, previousCell: SudokuCell) {
        undoSnapshot = SudokuUndoSnapshot(
            row: row,
            col: col,
            previousCell: previousCell,
            previousMistakes: mistakes
        )
    }

    private func recordWrongAttempt(at idx: Int) {
        wrongAttemptCount += 1
        lastWrongAttemptIdx = idx
        mistakes += 1
        if mistakes >= SudokuGameMode.livesPerPuzzle {
            recordGameOver()
        }
        // Auto-clear flash after 600ms (mirrors Nonogram).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if self.lastWrongAttemptIdx == idx {
                self.lastWrongAttemptIdx = nil
            }
        }
    }

    private func recordGameOver() {
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .gameOver
        try? gameStats?.record(
            gameKind: .sudoku,
            difficulty: difficulty.rawValue,
            outcome: .loss,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    private func recordWin() {
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .won
        winCount += 1
        try? gameStats?.record(
            gameKind: .sudoku,
            difficulty: difficulty.rawValue,
            outcome: .win,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id
        )
    }

    // MARK: - Constants

    static let lastDifficultyKey = "sudoku.lastDifficulty"
    static let lastGameModeKey   = "sudoku.lastGameMode"
}

// MARK: - GameStats convenience

extension GameStats {
    /// All puzzle IDs the player has WON for the given difficulty.
    /// Source of truth = GameRecord rows (no separate UserDefaults state).
    func sudokuPlayedIDs(for difficulty: SudokuDifficulty) -> Set<String> {
        let records = wonGameRecords(gameKind: .sudoku, difficulty: difficulty.rawValue)
        return Set(records.compactMap { $0.puzzleIdRaw })
    }
}
```

**Note on the `wonGameRecords` helper used above:** This method does not yet exist on `GameStats`. Inspect `Core/GameStats.swift` for the existing query surface — there is likely an analogous helper for `.nonogram` (e.g. `nonogramPlayedPuzzleIDs(for:)`). If not, add a small helper to `GameStats` in the SAME task that filters `[GameRecord]` by `gameKindRaw == "sudoku"` && `outcomeRaw == "win"` && `difficultyRaw == X`. Keep the helper alongside other game-kind-specific helpers; do not introduce a new file.

- [ ] **Step 2: Resolve the `GameStats.sudokuPlayedIDs` helper**

Read `gamekit/gamekit/Core/GameStats.swift`. Search for any existing per-game played-IDs helper. Two possibilities:

A. **A reusable query exists** (e.g., `wonGameRecords(gameKind:difficulty:)`). Use it — confirm signature matches the `extension GameStats { ... }` above.

B. **No helper exists.** Add this to `Core/GameStats.swift` near the existing record-write methods, then return:

```swift
/// All winning records for a given game-kind + difficulty. Read-side
/// helper used by per-game played-puzzle queries.
func wonGameRecords(gameKind: GameKind, difficulty: String) -> [GameRecord] {
    // Implementation depends on whether GameStats holds modelContext or
    // queries SwiftData via FetchDescriptor. Follow the existing read-
    // path pattern; if no read path exists yet, add a minimal one:
    //   let predicate = #Predicate<GameRecord> { r in
    //       r.gameKindRaw == gameKind.rawValue
    //       && r.difficultyRaw == difficulty
    //       && r.outcomeRaw == "win"
    //   }
    //   let descriptor = FetchDescriptor(predicate: predicate)
    //   return (try? modelContext.fetch(descriptor)) ?? []
}
```

Adjust the implementation to whatever pattern `Core/GameStats.swift` already uses for reads. If the existing class has no SwiftData read path at all (only writes), defer the helper to Phase 16 and **stub** the played-IDs lookup in `SudokuViewModel.loadFreshPuzzle` to return an empty set — the cosmetic effect is that the same puzzles may be served until the GameStats read path lands.

If you take the stub path, log a TODO in the viewmodel:

```swift
// TODO(Phase 16): swap to gameStats?.sudokuPlayedIDs(for: difficulty)
let playedIDs = Set<String>()
```

- [ ] **Step 3: Build to confirm ViewModel compiles**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 11 — `SudokuViewModelTests.swift`

**Files:**
- Create: `gamekit/gamekitTests/SudokuViewModelTests.swift`

- [ ] **Step 1: Write tests**

```swift
//
//  SudokuViewModelTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

@MainActor
final class SudokuViewModelTests: XCTestCase {

    // Reusable test puzzle.
    private let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func makeVM(mode: SudokuGameMode = .free) -> SudokuViewModel {
        // Inject a stub pool that always returns our test puzzle.
        // Since SudokuPuzzlePool is a concrete actor, simplest approach:
        // use the real pool but make tests rely on Bundle.main's pack.
        // For deterministic behavior we override via dependency injection
        // if available; otherwise use the live pool and assert on shape.
        let defaults = UserDefaults(suiteName: "SudokuViewModelTests.\(UUID().uuidString)")!
        defaults.set(SudokuDifficulty.easy.rawValue, forKey: SudokuViewModel.lastDifficultyKey)
        defaults.set(mode.rawValue, forKey: SudokuViewModel.lastGameModeKey)
        let vm = SudokuViewModel(
            difficulty: .easy,
            userDefaults: defaults
        )
        // Force a board to be present immediately, bypassing async load:
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "test-uuid",
                givens: testGivens,
                solution: testSolution,
                givenCount: 30
            )
        )
        return vm
    }

    func testFreeMode_commitsValueAndChecksWin() async {
        let vm = makeVM(mode: .free)
        XCTAssertEqual(vm.state, .idle)

        vm.select(row: 0, col: 2)   // empty cell, solution = 4
        vm.place(value: 4)

        XCTAssertEqual(vm.state, .playing)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))
        XCTAssertEqual(vm.placeCount, 1)
    }

    func testFreeMode_wrongValueCommitsButDoesNotIncrementMistakes() async {
        let vm = makeVM(mode: .free)
        vm.select(row: 0, col: 2)   // solution = 4
        vm.place(value: 9)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(9))
        XCTAssertEqual(vm.mistakes, 0)
    }

    func testLivesMode_wrongValueIncrementsMistakes_andDoesNotCommit() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)
        XCTAssertEqual(vm.mistakes, 1)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: []))
        XCTAssertEqual(vm.wrongAttemptCount, 1)
    }

    func testLivesMode_threeMistakesLeadToGameOver() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)
        vm.place(value: 1)
        vm.place(value: 2)
        XCTAssertEqual(vm.mistakes, 3)
        XCTAssertEqual(vm.state, .gameOver)
    }

    func testLivesMode_correctValueLocksCell() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 4)   // correct (solution = 4)
        XCTAssertTrue(vm.lockedCells.contains(0 * 9 + 2))
        // Erase should no-op on a locked correct cell.
        vm.erase()
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))
    }

    func testGivensAreImmutable() async {
        let vm = makeVM()
        vm.select(row: 0, col: 0)   // .given(5)
        vm.place(value: 7)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 0), .given(5))
    }

    func testNoteMode_togglesNotes() async {
        let vm = makeVM()
        vm.setInteractionMode(.note)
        vm.select(row: 0, col: 2)
        vm.place(value: 3)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [3]))
        vm.place(value: 5)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [3, 5]))
        vm.place(value: 3)   // toggle off
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [5]))
    }

    func testCommitClearsPeerNotes() async {
        let vm = makeVM()
        // Test puzzle solution row 0 = "534678912" → (0,2) = 4.
        // Strategy: seed digit 4 in another row-0 cell's notes, then commit
        // 4 to (0, 2). The peer note must clear automatically.
        vm.setInteractionMode(.note)
        vm.select(row: 0, col: 5)        // empty cell in same row
        vm.place(value: 4)               // toggle 4 into notes → {4}
        XCTAssertEqual(vm.board?.cell(row: 0, col: 5), .empty(notes: [4]))

        vm.setInteractionMode(.value)
        vm.select(row: 0, col: 2)        // empty cell, solution = 4
        vm.place(value: 4)               // commits user(4)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))

        // Peer note at (0, 5) must have been auto-cleared.
        XCTAssertEqual(vm.board?.cell(row: 0, col: 5), .empty(notes: []))
    }

    func testUndo_restoresPreviousCellAndMistakes() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)   // wrong, mistakes -> 1, NOT committed
        XCTAssertEqual(vm.mistakes, 1)
        // .lives wrong attempts don't capture an undo snapshot in this
        // implementation — they don't mutate the cell. Confirm:
        XCTAssertNil(vm.undoSnapshot)

        // Now commit a correct value, which should capture undo.
        vm.place(value: 4)
        XCTAssertNotNil(vm.undoSnapshot)
        vm.undo()
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: []))
    }

    func testRestart_resetsStateButKeepsPuzzle() async {
        let vm = makeVM()
        let originalID = vm.currentPuzzle?.id
        vm.select(row: 0, col: 2)
        vm.place(value: 4)
        vm.restart()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.currentPuzzle?.id, originalID)
        XCTAssertEqual(vm.placeCount, 0)
    }
}

// MARK: - Test injection seam

#if DEBUG
extension SudokuViewModel {
    /// Test-only entry point that bypasses the async pool load.
    @MainActor
    func injectTestBoardForUnitTests(puzzle: SudokuPuzzleEntry) {
        self.currentPuzzle = puzzle
        self.board = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution)
        var locked = Set<Int>()
        if let b = self.board {
            for i in 0..<81 where b.cells[i].isGiven {
                locked.insert(i)
            }
        }
        self.lockedCells = locked
    }
}
#endif
```

Note: the tests above use `injectTestBoardForUnitTests` as a `#if DEBUG` extension on the ViewModel to bypass the async pool. This is a deliberate test-injection seam — keep it gated to DEBUG builds so it never reaches production. The implementer should also rewrite the half-finished `testCommitClearsPeerNotes` per the inline NOTE.

- [ ] **Step 2: Run tests**

```bash
xcodebuild test \
  -project gamekit/gamekit.xcodeproj \
  -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:gamekitTests/SudokuViewModelTests \
  2>&1 | tail -30
```

Expected: all ~10 tests pass.

---

## Task 12 — Commit feat(15-02)

- [ ] **Step 1: Stage + commit**

```bash
git add gamekit/gamekit/Games/Sudoku/SudokuViewModel.swift \
        gamekit/gamekitTests/SudokuViewModelTests.swift \
        gamekit/gamekit/Core/GameStats.swift  # if helper added
git commit -m "$(cat <<'EOF'
feat(15-02): SudokuViewModel orchestrator + tests

@Observable @MainActor view-model owning a SudokuBoard, applying
mode rules (free commits any value; lives validates against the
solution, rejects wrong placements, increments mistakes, locks
correct placements, reaches .gameOver at 3 mistakes), driving
the 1-second timer (idle→playing on first commit), capturing
single-step undo snapshots, and auto-clearing peer notes when a
value commits.

GameStats writes routed through .record(gameKind: .sudoku, ...)
on terminal transitions — no new SwiftData model (mirrors
Nonogram).

Tests cover free vs lives mode, given immutability, locked cells,
note toggling, peer-note clearing, and undo. Test injection seam
is #if DEBUG only.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13 — `SudokuCellView.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuCellView.swift`

The single-cell SwiftUI view. Renders one of three states: a centered value digit, a 3×3 mini-grid of notes, or empty. Selection / peer / wrong overlays handled by props.

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuCellView.swift
//  gamekit
//
//  Single cell renderer. Pure-presentation — takes a SudokuCell + a
//  HighlightTier + an isWrongFlashing flag and renders accordingly.
//  No interaction logic; SudokuBoardView handles taps and feeds back
//  the selected/peer state via props.
//

import SwiftUI
import DesignKit

struct SudokuCellView: View {
    let cell: SudokuCell
    let highlight: HighlightTier
    let isWrongFlashing: Bool
    let theme: Theme

    enum HighlightTier: Equatable {
        case none                  // no overlay
        case peer                  // ~6% accent
        case sameNumber            // ~10% accent
        case selected              // ~18% accent
    }

    var body: some View {
        ZStack {
            background
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(wrongFlashOverlay)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var background: some View {
        let opacity: Double = {
            switch highlight {
            case .none:       return 0
            case .peer:       return 0.06
            case .sameNumber: return 0.10
            case .selected:   return 0.18
            }
        }()
        return Rectangle().fill(theme.colors.accent.opacity(opacity))
    }

    @ViewBuilder
    private var content: some View {
        switch cell {
        case .given(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.bold))
                .foregroundStyle(theme.colors.textPrimary)
        case .user(let v):
            Text("\(v)")
                .font(theme.typography.title.weight(.regular))
                .foregroundStyle(theme.colors.accent)
        case .empty(let notes):
            if notes.isEmpty {
                Color.clear
            } else {
                notesGrid(notes)
            }
        }
    }

    private func notesGrid(_ notes: Set<Int>) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = r * 3 + c + 1
                        Text(notes.contains(digit) ? "\(digit)" : " ")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wrongFlashOverlay: some View {
        if isWrongFlashing {
            Rectangle()
                .fill(theme.colors.danger.opacity(0.30))
                .transition(.opacity)
        }
    }

    private var accessibilityText: Text {
        switch cell {
        case .given(let v): return Text("Given \(v)")
        case .user(let v):  return Text("\(v)")
        case .empty(let notes):
            if notes.isEmpty { return Text("Empty") }
            return Text("Notes: \(notes.sorted().map(String.init).joined(separator: ", "))")
        }
    }
}
```

**Verify DesignKit token availability** before commit: `theme.typography.title` must exist. If not present, sub in `theme.typography.headline` (which definitely exists per existing Nonogram code). Same for `theme.typography.caption` (exists).

---

## Task 14 — `SudokuBoardView.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuBoardView.swift`

9×9 grid with thicker box borders. Hosts tap gestures that call `viewModel.select(row:col:)`.

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuBoardView.swift
//  gamekit
//
//  9×9 Sudoku board renderer. Uses a single LazyVGrid of SudokuCellView
//  with overlay paths to draw the thicker borders that separate the
//  nine 3×3 boxes. Reads cell state + selection/peer/same-number
//  highlights from the @Observable SudokuViewModel.
//

import SwiftUI
import DesignKit

struct SudokuBoardView: View {
    @Bindable var viewModel: SudokuViewModel
    let theme: Theme

    private static let size = SudokuBoard.size       // 9
    private static let boxSize = SudokuBoard.boxSize // 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cellSide = side / CGFloat(Self.size)

            ZStack {
                gridBackground
                cellGrid(cellSide: cellSide)
                boxBorderOverlay(side: side)
                outerBorder(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var gridBackground: some View {
        Rectangle()
            .fill(theme.colors.surface)
    }

    @ViewBuilder
    private func cellGrid(cellSide: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.size, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<Self.size, id: \.self) { c in
                        let board = viewModel.board ?? emptyBoard()
                        let cell = board.cell(row: r, col: c)
                        let highlight = highlightTier(row: r, col: c)
                        let isFlash = viewModel.lastWrongAttemptIdx == r * 9 + c
                        SudokuCellView(
                            cell: cell,
                            highlight: highlight,
                            isWrongFlashing: isFlash,
                            theme: theme
                        )
                        .frame(width: cellSide, height: cellSide)
                        .overlay(thinDivider, alignment: .bottom)
                        .overlay(thinDivider, alignment: .trailing)
                        .onTapGesture {
                            viewModel.select(row: r, col: c)
                        }
                    }
                }
            }
        }
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.40))
            .frame(width: 1, height: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func boxBorderOverlay(side: CGFloat) -> some View {
        // Two heavy verticals + two heavy horizontals at the 3× lines.
        let third = side / 3
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: third, y: 0))
                p.addLine(to: CGPoint(x: third, y: side))
                p.move(to: CGPoint(x: 2 * third, y: 0))
                p.addLine(to: CGPoint(x: 2 * third, y: side))
                p.move(to: CGPoint(x: 0, y: third))
                p.addLine(to: CGPoint(x: side, y: third))
                p.move(to: CGPoint(x: 0, y: 2 * third))
                p.addLine(to: CGPoint(x: side, y: 2 * third))
            }
            .stroke(theme.colors.border, lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func outerBorder(side: CGFloat) -> some View {
        Rectangle()
            .stroke(theme.colors.border, lineWidth: 2)
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }

    private func highlightTier(row: Int, col: Int) -> SudokuCellView.HighlightTier {
        guard let sel = viewModel.selected else { return .none }
        if sel.row == row && sel.col == col { return .selected }

        // Same-number tier: if selected cell has a value and this cell shares it.
        if let board = viewModel.board {
            let selValue = board.cell(row: sel.row, col: sel.col).value
            let thisValue = board.cell(row: row, col: col).value
            if let sv = selValue, let tv = thisValue, sv == tv {
                return .sameNumber
            }
        }

        // Peer tier: same row, column, or 3×3 box.
        let peers = SudokuBoard.peerIndices(row: sel.row, col: sel.col)
        if peers.contains(row * 9 + col) { return .peer }

        return .none
    }

    private func emptyBoard() -> SudokuBoard {
        // Defensive fallback — shouldn't actually render before VM loads.
        let zeros = String(repeating: "0", count: 81)
        let ones  = String(repeating: "1", count: 81)
        return SudokuBoard(givens: zeros, solution: ones)!
    }
}
```

Note: the inner thin-divider implementation above is sketchy — real divider lines should NOT block taps. Implement as a single-pass `Path` overlay similar to `boxBorderOverlay` but stroked at lineWidth 0.5 between every cell. The implementer may simplify this during execution.

---

## Task 15 — `SudokuNumberPad.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuNumberPad.swift`

1–9 button grid + erase button + interaction-mode pill access.

- [ ] **Step 1: Write the file**

```swift
//
//  SudokuNumberPad.swift
//  gamekit
//
//  9-digit number pad + erase button. Each digit shows a remaining-count
//  badge (9 minus the number of times that digit is already placed on
//  the board). When a digit's remaining count is 0, the button greys
//  out and disables.
//

import SwiftUI
import DesignKit

struct SudokuNumberPad: View {
    @Bindable var viewModel: SudokuViewModel
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(1...9, id: \.self) { digit in
                digitButton(digit)
            }
            eraseButton
        }
        .padding(.horizontal, theme.spacing.m)
    }

    private func digitButton(_ digit: Int) -> some View {
        let remaining = viewModel.remainingPerDigit[digit] ?? 0
        let isExhausted = remaining == 0
        return Button {
            viewModel.place(value: digit)
        } label: {
            VStack(spacing: 2) {
                Text("\(digit)")
                    .font(theme.typography.title.weight(.semibold))
                    .foregroundStyle(isExhausted
                        ? theme.colors.textSecondary
                        : theme.colors.textPrimary)
                Text("\(remaining)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
        }
        .disabled(isExhausted)
        .accessibilityLabel("Place \(digit), \(remaining) remaining")
    }

    private var eraseButton: some View {
        Button {
            viewModel.erase()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 20))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: theme.radii.chip)
                        .fill(theme.colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radii.chip)
                        .stroke(theme.colors.border, lineWidth: 1)
                )
        }
        .accessibilityLabel("Erase")
    }
}
```

---

## Task 16 — `SudokuLivesChip.swift` + `SudokuModePill.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuLivesChip.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuModePill.swift`

Mirror `NonogramLivesChip` and `NonogramModePill` patterns 1:1. Read those files first — they're the canonical reference for chip styling, animation, and accessibility.

- [ ] **Step 1: Inspect `gamekit/gamekit/Games/Nonogram/NonogramLivesChip.swift` for the chip pattern.** Carry over: 3 dots, dim as lives decrement, theme.colors.danger for last life.

- [ ] **Step 2: Inspect `gamekit/gamekit/Games/Nonogram/NonogramModePill.swift` for the pill pattern.** Carry over: 2-segment pill switching `.value` ↔ `.note` (mirrors `.place` ↔ `.mark` in Nonogram).

- [ ] **Step 3: Write `SudokuLivesChip.swift`** — adapt the Nonogram version, replacing `NonogramGameMode.livesPerPuzzle` with `SudokuGameMode.livesPerPuzzle` and reading `viewModel.mistakes` (rather than `livesRemaining`).

- [ ] **Step 4: Write `SudokuModePill.swift`** — adapt to switch `viewModel.interactionMode` between `.value` and `.note`. Labels: "Value" and "Notes".

---

## Task 17 — `SudokuHeaderBar.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuHeaderBar.swift`

Mirrors `NonogramHeaderBar.swift`. Layout: `SudokuLivesChip` (lives mode only) | timer | `SudokuModePill`.

- [ ] **Step 1: Inspect `gamekit/gamekit/Games/Nonogram/NonogramHeaderBar.swift` for the header layout.**

- [ ] **Step 2: Write `SudokuHeaderBar.swift`** — adapt to render `SudokuLivesChip` only when `viewModel.gameMode == .lives`, otherwise hide the slot. Use existing timer-formatting helper if present (`Core/TimeFormatter.swift` or similar — confirm path).

---

## Task 18 — `SudokuEndStateCard.swift` + `SudokuToolbarMenu.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuEndStateCard.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuToolbarMenu.swift`

- [ ] **Step 1: Inspect `gamekit/gamekit/Games/Nonogram/NonogramEndStateCard.swift` + `NonogramToolbarMenu.swift`.**

- [ ] **Step 2: Write `SudokuEndStateCard.swift`** with the win/loss copy locked in §"Sudoku-specific design decisions" #3:
   - Win: title `"You solved it!"` · subtitle `"\(difficulty.displayName) · \(elapsedFormatted)"`. Primary CTA `"New puzzle"` (calls `viewModel.newPuzzle()`). Secondary `"View board"` (dismisses card).
   - Loss: title `"Out of mistakes"` · subtitle `"You used all 3 lives."`. Primary CTA `"Try again"` (calls `viewModel.restart()`). Secondary `"View board"`.

- [ ] **Step 3: Write `SudokuToolbarMenu.swift`** mirroring `NonogramToolbarMenu`: a `Menu` with Restart + Change-difficulty submenu (4 difficulties).

---

## Task 19 — `SudokuGameView.swift` + `SudokuGameView+VideoMode.swift`

**Files:**
- Create: `gamekit/gamekit/Games/Sudoku/SudokuGameView.swift`
- Create: `gamekit/gamekit/Games/Sudoku/SudokuGameView+VideoMode.swift`

- [ ] **Step 1: Inspect `gamekit/gamekit/Games/Nonogram/NonogramGameView.swift` + `NonogramGameView+VideoMode.swift`.**

- [ ] **Step 2: Write `SudokuGameView.swift`** — top-to-bottom: `SudokuHeaderBar` → `SudokuBoardView` → `SudokuNumberPad`. Toolbar uses `SudokuToolbarMenu`. End-state card overlays on `state == .won || state == .gameOver`. `@State` timer ticks via `TimelineView(.animation)` or `Timer.publish(every: 1)` — match whichever pattern Nonogram uses (likely TimelineView; confirm).

- [ ] **Step 3: Write `SudokuGameView+VideoMode.swift`** — mirror `NonogramGameView+VideoMode.swift`. Use the shared `videoModeAware(minBoardHeight: 480)` modifier per CLAUDE.md.

---

## Task 20 — Commit feat(15-03)

- [ ] **Step 1: Verify build**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run a quick simulator smoke test**

The game can't be reached via drawer yet (Phase 15-04 wires the drawer). For now, smoke-verify via Xcode Preview: open `SudokuGameView.swift`, hit the Preview button, confirm the board renders + you can tap cells + place values + see notes. Verify under Classic + Voltage + Dracula presets per CLAUDE.md §8.12. **Report any rendering or contrast issues as CONCERNS** — fix in chore(15-03) before proceeding to Task 21.

- [ ] **Step 3: Stage + commit**

```bash
git add gamekit/gamekit/Games/Sudoku/SudokuCellView.swift \
        gamekit/gamekit/Games/Sudoku/SudokuBoardView.swift \
        gamekit/gamekit/Games/Sudoku/SudokuNumberPad.swift \
        gamekit/gamekit/Games/Sudoku/SudokuLivesChip.swift \
        gamekit/gamekit/Games/Sudoku/SudokuModePill.swift \
        gamekit/gamekit/Games/Sudoku/SudokuHeaderBar.swift \
        gamekit/gamekit/Games/Sudoku/SudokuEndStateCard.swift \
        gamekit/gamekit/Games/Sudoku/SudokuToolbarMenu.swift \
        gamekit/gamekit/Games/Sudoku/SudokuGameView.swift \
        gamekit/gamekit/Games/Sudoku/SudokuGameView+VideoMode.swift
git commit -m "$(cat <<'EOF'
feat(15-03): Sudoku SwiftUI views — board, cell, numpad, header, end-state

Full UI layer for the Sudoku game vertical slice:
- SudokuCellView (single-cell renderer with 4-tier highlight overlay
  + wrong-flash danger overlay + notes 3×3 mini-grid + accessibility)
- SudokuBoardView (9×9 grid with thicker box borders, tap routing to
  viewModel.select)
- SudokuNumberPad (1-9 + erase, remaining-count badges, disables at 0)
- SudokuLivesChip / SudokuModePill (mirror Nonogram patterns)
- SudokuHeaderBar (timer + mistakes chip + mode pill)
- SudokuEndStateCard (win/loss banner with primary CTA + dismiss)
- SudokuToolbarMenu (restart + change-difficulty submenu)
- SudokuGameView assembly + +VideoMode extension

All views read DesignKit semantic tokens — no hardcoded colors,
spacings, or radii per CLAUDE.md §1. Preview-verified under Classic
+ Voltage + Dracula presets per §8.12.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 21 — Drawer wiring

**Files:**
- Modify: `gamekit/gamekit/Core/GameKind.swift`
- Modify: `gamekit/gamekit/Core/GameRoute.swift`
- Modify: `gamekit/gamekit/Core/GameDescriptor.swift`
- Modify: `gamekit/gamekit/Screens/HomeView.swift`

- [ ] **Step 1: Add `.sudoku` to `GameKind`**

In `gamekit/gamekit/Core/GameKind.swift`, the enum currently lists `.minesweeper`, `.merge`, `.nonogram`. Append `.sudoku`:

```swift
enum GameKind: String, Codable, Sendable, CaseIterable {
    case minesweeper
    case merge
    case nonogram
    case sudoku
}
```

- [ ] **Step 2: Add `.sudoku` case to `GameRoute`**

In `gamekit/gamekit/Core/GameRoute.swift`:

```swift
enum GameRoute: Hashable, Sendable {
    case minesweeper(MinesweeperDifficulty?)
    case merge(MergeMode?)
    case nonogram(NonogramDifficulty?)
    case sudoku(SudokuDifficulty?)
}
```

- [ ] **Step 3: Append Sudoku descriptor to `GameDescriptor.all`**

In `gamekit/gamekit/Core/GameDescriptor.swift`, append AFTER the Nonogram entry (so the drawer order is Mines → Merge → Nonogram → Sudoku):

```swift
GameDescriptor(
    kind: .sudoku,
    titleKey: "Sudoku",
    captionKey: "Tap to play",
    symbol: "square.grid.3x3.fill",
    accent: .slot4,
    route: .sudoku(nil),
    modes: [
        GameModeChip(id: "easy",    labelKey: "Easy",    detailKey: "9×9", route: .sudoku(.easy)),
        GameModeChip(id: "medium",  labelKey: "Medium",  detailKey: "9×9", route: .sudoku(.medium)),
        GameModeChip(id: "hard",    labelKey: "Hard",    detailKey: "9×9", route: .sudoku(.hard)),
        GameModeChip(id: "extreme", labelKey: "Extreme", detailKey: "9×9", route: .sudoku(.extreme))
    ]
)
```

- [ ] **Step 4: Add `.sudoku` switch arm in `HomeView.destination(for:)`**

In `gamekit/gamekit/Screens/HomeView.swift`, add the arm BELOW the Nonogram arm:

```swift
case .sudoku(let difficulty):
    SudokuGameView(initialDifficulty: difficulty)
        .videoModeAware(minBoardHeight: 480)
```

Note: `SudokuGameView` must accept an `initialDifficulty: SudokuDifficulty?` parameter on its init — confirm this signature was implemented in Task 19 Step 2. If not, add it.

- [ ] **Step 5: Build + verify drawer**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

Then launch in the simulator and confirm:
- Home shows 4 drawers (Mines / Merge / Nonogram / Sudoku).
- Tapping Sudoku drawer reveals 4 mode chips (Easy / Medium / Hard / Extreme).
- Tapping a difficulty chip pushes into `SudokuGameView`.
- Selecting cells + placing values + notes all work.
- Restart + Change-difficulty from toolbar both work.
- Win banner appears when board is solved.
- Lives mode: 3 wrong placements → game-over banner.

---

## Task 22 — Theme audit per CLAUDE.md §8.12

This is a hard quality gate per the project constitution.

- [ ] **Step 1: Verify on Classic preset (Chrome Diner)**

Launch sim, select Classic theme, play one game per difficulty in both `.free` and `.lives` modes. Verify:
- Cell digits are clearly legible (givens vs user vs notes have distinct weights/colors).
- Selection / peer / same-number highlights are distinguishable at a glance.
- Wrong-placement red is unmistakable.
- Box borders read as clear separators.

- [ ] **Step 2: Verify on Voltage preset (Loud)**

Same checks. If any contrast breaks (e.g., wrong-flash red is invisible against a vibrant background), fix the token reference in the view — do NOT carve a Sudoku-specific exception.

- [ ] **Step 3: Verify on Dracula preset (Moody)**

Same checks. If any contrast breaks, fix the token reference.

- [ ] **Step 4: Document audit pass in a code comment**

In `SudokuBoardView.swift`, add a top-of-file note:

```
//  Theme audit (Phase 15-04): verified under Classic + Voltage + Dracula
//  presets on iPhone 15 sim, YYYY-MM-DD. Wrong-flash danger + same-number
//  highlight + peer highlight all distinguishable.
```

Replace `YYYY-MM-DD` with the actual date the audit ran.

---

## Task 23 — Commit feat(15-04) + release log

- [ ] **Step 1: Append Phase 15 entry to `Docs/releases/v1.2.md`**

Add a new section `## Internal changes (15)` (or update one if already present), with this content:

```markdown
## Internal changes (15)
- **Phase 15 — Sudoku game vertical slice (user-visible).** Adds
  Sudoku as the 4th drawer game. New `Games/Sudoku/` folder ships
  ~17 source files mirroring the Nonogram pattern: pure-model layer
  (Board, Cell, Difficulty, GameMode, GameState, InteractionMode,
  UndoSnapshot, PuzzleEntry, PuzzlePack, PuzzlePool actor), the
  `@Observable @MainActor` `SudokuViewModel` orchestrator, and the
  SwiftUI layer (BoardView, CellView, NumberPad, HeaderBar, LivesChip,
  ModePill, EndStateCard, ToolbarMenu, GameView + VideoMode extension).
  Game runs end-to-end: 9×9 grid with thick box borders, peer +
  same-number + selected highlights, pencil notes mode (auto-clear on
  value commit), single-step undo, 1-second timer, both `.free` and
  `.lives` modes (3 mistakes → game over). Win/loss recorded via
  existing `GameStats.record(gameKind: .sudoku, ...)` — no new
  SwiftData model. Drawer wired: `GameKind.sudoku` + `GameRoute.sudoku` +
  `GameDescriptor` entry + `HomeView.destination(for:)` arm. Theme
  audited under Classic + Voltage + Dracula presets per CLAUDE §8.12.
```

- [ ] **Step 2: Stage + commit**

```bash
git add gamekit/gamekit/Core/GameKind.swift \
        gamekit/gamekit/Core/GameRoute.swift \
        gamekit/gamekit/Core/GameDescriptor.swift \
        gamekit/gamekit/Screens/HomeView.swift \
        gamekit/gamekit/Games/Sudoku/SudokuBoardView.swift \
        Docs/releases/v1.2.md
git commit -m "$(cat <<'EOF'
feat(15-04): wire Sudoku into The Drawer + Phase 15 release log

Adds GameKind.sudoku + GameRoute.sudoku + GameDescriptor entry +
HomeView.destination(for:) arm so Sudoku appears as the 4th drawer
game with 4 difficulty chips (Easy / Medium / Hard / Extreme).
Tapping any chip pushes into SudokuGameView via the same
.videoModeAware(minBoardHeight: 480) pattern used by sibling games.

Theme audit (Classic + Voltage + Dracula per §8.12) noted in
SudokuBoardView.swift header.

Phase 15 entry appended to Docs/releases/v1.2.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 24 — Final verification

- [ ] **Step 1: Run all Sudoku-related tests**

```bash
xcodebuild test \
  -project gamekit/gamekit.xcodeproj \
  -scheme gamekit \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:gamekitTests/SudokuBoardTests \
  -only-testing:gamekitTests/SudokuPuzzlePoolTests \
  -only-testing:gamekitTests/SudokuViewModelTests \
  2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 2: Full app build**

```bash
xcodebuild -project gamekit/gamekit.xcodeproj -scheme gamekit \
  -destination 'generic/platform=iOS' -configuration Debug \
  build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Smoke run in simulator**

Launch app → Home shows 4 drawer games → tap Sudoku → tap Easy → play to completion (win or lose) → verify end-state banner → tap "New puzzle" or "Try again" → verify fresh puzzle loads.

- [ ] **Step 4: Phase 15 complete**

Working tree should be clean (only pre-existing Localizable.xcstrings + .claude/ untracked). Commits on main:
```
feat(15-04)  drawer wiring + release log
feat(15-03)  SwiftUI views
feat(15-02)  SudokuViewModel + tests
feat(15-01)  data types + pool + tests
```
plus any `chore(15-NN)` code-review follow-ups.

---

## Summary of what this plan delivers

After all 24 tasks complete:

1. `gamekit/gamekit/Games/Sudoku/` — full game module, ~17 source files.
2. `gamekit/gamekitTests/` — 3 new test files (Board, Pool, ViewModel) covering core mechanics.
3. `GameKind.sudoku` + `GameRoute.sudoku` + `GameDescriptor` entry + `HomeView` switch arm.
4. Drawer shows 4 games. Sudoku plays end-to-end with both modes, notes, undo, timer.
5. Win/loss persists via `GameStats.record(gameKind: .sudoku, ...)`.
6. Theme audit passed under Classic + Voltage + Dracula.
7. `Docs/releases/v1.2.md` — Phase 15 entry appended.

---

## Open items for downstream phases

- **GameStats `sudokuPlayedIDs(for:)` helper** — implemented as part of Task 10. If GameStats has no SwiftData read path today, that read path lands as part of Phase 16 (stats integration) and the played-IDs lookup gets re-wired then.
- **`SudokuStatsCard` in `StatsView`** — Phase 16 (separate plan).
- **Full 1500-per-difficulty pack** — Phase 17 (uses `tools/GenerateSudokuPack` from Phase 14).
- **Hints / technique-suggestion UI** — Phase 18 candidate (post-v1.2).
- **Daily Puzzle** — Phase 18+ candidate.
- **4×4 Beginner board** — Phase 18+ candidate.

---

*End of Phase 15 plan.*
