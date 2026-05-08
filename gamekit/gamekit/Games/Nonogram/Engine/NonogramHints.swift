//
//  NonogramHints.swift
//  gamekit
//
//  Pure functions for computing the row/column hint numbers (run-lengths
//  of consecutive filled cells) from a puzzle's solution grid. Engines
//  are Foundation-only and deterministic — no SwiftUI, no SwiftData
//  (CLAUDE §4 game-engine purity).
//
//  Convention: an empty row/column emits `[0]` (a single zero, the
//  classic nonogram convention) so the hint header always has at least
//  one number to render.
//

import Foundation

enum NonogramHints {
    /// Row run-lengths for every row of the puzzle's solution grid.
    /// Returns an array of length `size`; each entry is the row's hints.
    static func rows(for puzzle: NonogramPuzzle, size: Int) -> [[Int]] {
        let bits = puzzle.solution
        return (0..<size).map { row in
            let slice = Array(bits[(row * size)..<((row + 1) * size)])
            return runs(in: slice)
        }
    }

    /// Column run-lengths for every column of the puzzle's solution grid.
    /// Returns an array of length `size`; each entry is the column's hints.
    static func columns(for puzzle: NonogramPuzzle, size: Int) -> [[Int]] {
        let bits = puzzle.solution
        return (0..<size).map { col in
            var slice: [Bool] = []
            slice.reserveCapacity(size)
            for row in 0..<size {
                slice.append(bits[row * size + col])
            }
            return runs(in: slice)
        }
    }

    /// Run-length compression of a binary line. Empty (all-false) lines
    /// emit `[0]` so renderers always have at least one hint number.
    private static func runs(in line: [Bool]) -> [Int] {
        var out: [Int] = []
        var current = 0
        for bit in line {
            if bit {
                current += 1
            } else if current > 0 {
                out.append(current)
                current = 0
            }
        }
        if current > 0 {
            out.append(current)
        }
        return out.isEmpty ? [0] : out
    }
}
