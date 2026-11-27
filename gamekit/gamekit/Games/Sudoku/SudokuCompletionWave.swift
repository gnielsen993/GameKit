//
//  SudokuCompletionWave.swift
//  gamekit
//
//  Pure rules for Sudoku's completion feedback (Phase 19.1, DESIGN.md 10.2):
//  which cells count as a completed unit, and the order a ripple travels.
//  Foundation only; no SwiftUI, no model context.
//
//  A unit is acknowledged only when it is full AND correct (D-18). A full
//  unit that holds a wrong digit is never celebrated.
//

import Foundation

nonisolated enum SudokuCompletionWave {

    /// Delay between one ripple step and the next (sketch 012: 45ms).
    static let stepInterval: Double = 0.045
    /// Seconds one cell spends in its wave (rise + fall).
    static let cellDuration: Double = 0.7
    /// Fraction of `cellDuration` at which the cell peaks.
    static let peakFraction: Double = 0.35
    /// Scale at the peak.
    static let peakScale: Double = 1.08
    /// How long the glow set stays populated, so the static motion-off glow
    /// outlasts the longest unit ripple (8 steps x 45ms + 0.7s = 1.06s).
    static let clearDelayMilliseconds = 1200

    /// Flat indices of every row, column or box through (`row`, `col`) whose
    /// nine cells all hold the solution digit. Givens count as correct.
    /// Main-actor because `SudokuBoard` and `SudokuCell` are (module default).
    @MainActor
    static func correctCompletedCells(board: SudokuBoard, row: Int, col: Int) -> Set<Int> {
        func isCorrect(_ r: Int, _ c: Int) -> Bool {
            board.cell(row: r, col: c).value == board.solutionDigit(atRow: r, col: c)
        }
        var result = Set<Int>()

        if (0..<9).allSatisfy({ isCorrect(row, $0) }) {
            for c in 0..<9 { result.insert(row * 9 + c) }
        }
        if (0..<9).allSatisfy({ isCorrect($0, col) }) {
            for r in 0..<9 { result.insert(r * 9 + col) }
        }
        let br = (row / 3) * 3, bc = (col / 3) * 3
        if (0..<3).allSatisfy({ dr in (0..<3).allSatisfy({ dc in isCorrect(br + dr, bc + dc) }) }) {
            for dr in 0..<3 { for dc in 0..<3 { result.insert((br + dr) * 9 + (bc + dc)) } }
        }
        return result
    }

    /// Ripple step for each cell of a completed unit: Chebyshev distance from
    /// the placed cell, so the wave reads as caused by the move (DESIGN 10.1).
    /// Along a row or column this equals the index distance.
    static func unitSteps(origin: Int, cells: Set<Int>) -> [Int: Int] {
        let or = origin / 9, oc = origin % 9
        var steps: [Int: Int] = [:]
        steps.reserveCapacity(cells.count)
        for index in cells {
            steps[index] = max(abs(index / 9 - or), abs(index % 9 - oc))
        }
        return steps
    }

    /// Ripple step for all 81 cells on a win: Manhattan distance from the
    /// final placement, or `row + col` (a diagonal from the top-left) when
    /// there is no origin. Worst case 16 steps x 45ms + 0.7s = 1.42s, inside
    /// the 1500ms win pre-roll (DESIGN 10.3).
    static func winSteps(origin: Int?) -> [Int: Int] {
        var steps: [Int: Int] = [:]
        steps.reserveCapacity(81)
        for index in 0..<81 {
            let r = index / 9, c = index % 9
            if let origin {
                steps[index] = abs(r - origin / 9) + abs(c - origin % 9)
            } else {
                steps[index] = r + c
            }
        }
        return steps
    }
}
