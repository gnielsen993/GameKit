//
//  MergeBoard.swift
//  gamekit
//
//  Immutable 4x4 Merge board. Cells are `MergeTile?` — nil = empty cell.
//  Storage is a flat [MergeTile?] of length size*size, indexed `row*size+col`
//  (mirrors MinesweeperBoard's flat-array discipline).
//
//  Engines (MergeEngine, BoardSpawner, GameOverDetector) produce NEW boards
//  via the pure transforms on this type. ZERO mutating methods. Foundation-only.
//
//  v1: `size` is locked at 4. Larger boards would require new difficulty
//  parameterization — out of scope per the approved plan.
//

import Foundation

nonisolated struct MergeBoard: Equatable, Hashable, Codable, Sendable {
    static let size: Int = 4

    let cells: [MergeTile?]

    init(cells: [MergeTile?]) {
        precondition(cells.count == Self.size * Self.size,
            "MergeBoard cells.count (\(cells.count)) must equal \(Self.size * Self.size)")
        self.cells = cells
    }

    /// Empty 4x4 board — used by tests and the idle-state placeholder.
    static var empty: MergeBoard {
        MergeBoard(cells: Array(repeating: nil, count: size * size))
    }

    // MARK: - Read accessors

    func cell(row: Int, col: Int) -> MergeTile? {
        cells[flatIndex(row: row, col: col)]
    }

    func flatIndex(row: Int, col: Int) -> Int {
        row * Self.size + col
    }

    /// (row, col) coordinates of every empty cell, row-major.
    func emptyCoordinates() -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        result.reserveCapacity(Self.size * Self.size)
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                if cells[r * Self.size + c] == nil {
                    result.append((r, c))
                }
            }
        }
        return result
    }

    var tileCount: Int {
        cells.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
    }

    var maxValue: Int {
        cells.compactMap { $0?.value }.max() ?? 0
    }

    // MARK: - Pure transforms

    /// New board with `tile` placed at (row, col). Caller is responsible for
    /// ensuring the cell was empty — engines and spawner enforce this.
    func placing(_ tile: MergeTile?, row: Int, col: Int) -> MergeBoard {
        var newCells = cells
        newCells[flatIndex(row: row, col: col)] = tile
        return MergeBoard(cells: newCells)
    }

    /// New board where every tile has `mergedThisTurn` cleared. Called by
    /// MergeEngine at the start of each slide so the per-turn merge gate
    /// resets even though the board values are otherwise unchanged.
    func clearingMergeFlags() -> MergeBoard {
        let cleared = cells.map { tile -> MergeTile? in
            guard let tile else { return nil }
            return tile.mergedThisTurn
                ? MergeTile(id: tile.id, value: tile.value, mergedThisTurn: false)
                : tile
        }
        return MergeBoard(cells: cleared)
    }
}
