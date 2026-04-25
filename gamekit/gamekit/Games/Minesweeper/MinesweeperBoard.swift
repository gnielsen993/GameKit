//
//  MinesweeperBoard.swift
//  gamekit
//
//  The immutable Minesweeper board. Engines (BoardGenerator in Plan 03,
//  RevealEngine in Plan 04) produce NEW boards via the pure transforms
//  on this type — `replacingCell(at:with:)` and `replacingCells(_:)`.
//  This struct intentionally has zero `mutating func`s (D-10).
//
//  Phase 2 invariants (per D-10 + PATTERNS.md "immutable value-type Board"):
//    - All stored properties are `let` — no inout, no in-place mutation
//    - Storage is flat `[MinesweeperCell]` of length rows*cols, indexed
//      `row * cols + col` — Swift-idiomatic for fixed-size grids and
//      marginally faster than nested `[[Cell]]`
//    - Equatable + Hashable + Codable + Sendable — value-type discipline
//      and trivial Codable wins make mid-game persistence (deferred to
//      a later phase) a no-op extension
//    - No `flag(...)` / `reveal(...)` mutating methods — those are engine
//      concerns (Plan 04) that compose `replacingCell(at:with:)` to emit
//      new boards
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

/// Immutable Minesweeper board (D-10). Engines (BoardGenerator, RevealEngine)
/// produce NEW boards; this type has no mutating methods.
/// Storage: flat [Cell] of length rows*cols, indexed by `row * cols + col`.
/// Foundation-only — ROADMAP P2 SC5.
struct MinesweeperBoard: Equatable, Hashable, Codable, Sendable {
    let difficulty: MinesweeperDifficulty
    let rows: Int
    let cols: Int
    let mineCount: Int
    let cells: [MinesweeperCell]

    /// Designated initializer. Engines build boards via this — UI code never calls this directly.
    init(
        difficulty: MinesweeperDifficulty,
        rows: Int,
        cols: Int,
        mineCount: Int,
        cells: [MinesweeperCell]
    ) {
        precondition(cells.count == rows * cols,
            "MinesweeperBoard cells.count (\(cells.count)) must equal rows*cols (\(rows*cols))")
        self.difficulty = difficulty
        self.rows = rows
        self.cols = cols
        self.mineCount = mineCount
        self.cells = cells
    }

    /// Convenience initializer from Difficulty alone (used by engines/tests).
    init(difficulty: MinesweeperDifficulty, cells: [MinesweeperCell]) {
        self.init(
            difficulty: difficulty,
            rows: difficulty.rows,
            cols: difficulty.cols,
            mineCount: difficulty.mineCount,
            cells: cells
        )
    }

    // MARK: - Read accessors (NO mutating methods on Board — D-10)

    /// O(1) cell lookup by (row, col).
    func cell(at index: MinesweeperIndex) -> MinesweeperCell {
        cells[flatIndex(index)]
    }

    /// Convert (row, col) to flat index.
    func flatIndex(_ index: MinesweeperIndex) -> Int {
        index.row * cols + index.col
    }

    /// Enumerate every valid index on this board (top-to-bottom, left-to-right).
    func allIndices() -> [MinesweeperIndex] {
        var result: [MinesweeperIndex] = []
        result.reserveCapacity(rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                result.append(MinesweeperIndex(row: r, col: c))
            }
        }
        return result
    }

    /// Whether (row, col) is on the board. Engines/tests use this for safety asserts.
    func contains(_ index: MinesweeperIndex) -> Bool {
        index.row >= 0 && index.row < rows && index.col >= 0 && index.col < cols
    }

    // MARK: - Pure transforms (return new Board — D-10)

    /// Returns a new board with the cell at `index` replaced. Used by engines (Plan 03/04/05)
    /// to compose mutations as immutable transforms.
    func replacingCell(at index: MinesweeperIndex, with cell: MinesweeperCell) -> MinesweeperBoard {
        var newCells = cells
        newCells[flatIndex(index)] = cell
        return MinesweeperBoard(
            difficulty: difficulty,
            rows: rows,
            cols: cols,
            mineCount: mineCount,
            cells: newCells
        )
    }

    /// Returns a new board with multiple cells replaced in one pass (RevealEngine flood-fill consumer).
    func replacingCells(_ updates: [(MinesweeperIndex, MinesweeperCell)]) -> MinesweeperBoard {
        var newCells = cells
        for (index, cell) in updates {
            newCells[flatIndex(index)] = cell
        }
        return MinesweeperBoard(
            difficulty: difficulty,
            rows: rows,
            cols: cols,
            mineCount: mineCount,
            cells: newCells
        )
    }
}
