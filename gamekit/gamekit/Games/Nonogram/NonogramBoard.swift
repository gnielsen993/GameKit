//
//  NonogramBoard.swift
//  gamekit
//
//  Player-side board state. Held by NonogramViewModel; engines transform
//  it (toggle a cell) or read it (compute hints / detect win).
//
//  Layout: row-major flat array of NonogramCellState. Index = row * size + col.
//
//  Foundation-only — engine purity per CLAUDE §4.
//

import Foundation

struct NonogramBoard: Equatable, Hashable, Sendable, Codable {
    let size: Int
    var cells: [NonogramCellState]

    init(size: Int, cells: [NonogramCellState]) {
        precondition(cells.count == size * size, "cells.count must equal size*size")
        self.size = size
        self.cells = cells
    }

    /// Empty board of the given size — no input.
    static func empty(size: Int) -> NonogramBoard {
        NonogramBoard(
            size: size,
            cells: Array(repeating: .empty, count: size * size)
        )
    }

    /// Board pre-filled to a puzzle's solution. Used by gallery mode so
    /// reviewers can eyeball each completed picture without playing it.
    static func solved(puzzle: NonogramPuzzle, size: Int) -> NonogramBoard {
        let cells = puzzle.solution.map { $0 ? NonogramCellState.filled : .empty }
        return NonogramBoard(size: size, cells: cells)
    }

    func cell(row: Int, col: Int) -> NonogramCellState {
        cells[row * size + col]
    }

    func setting(_ state: NonogramCellState, atRow row: Int, col: Int) -> NonogramBoard {
        var next = cells
        next[row * size + col] = state
        return NonogramBoard(size: size, cells: next)
    }

    /// Iterate all (row, col) pairs in row-major order.
    func allIndices() -> [(row: Int, col: Int)] {
        var out: [(Int, Int)] = []
        out.reserveCapacity(size * size)
        for r in 0..<size {
            for c in 0..<size {
                out.append((r, c))
            }
        }
        return out
    }
}
