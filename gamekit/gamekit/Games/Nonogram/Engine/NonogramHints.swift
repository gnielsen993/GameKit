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

    // MARK: - Per-hint reactive cross-off

    /// For each row, return a per-hint mask: `mask[row][hintIdx] = true`
    /// when the player has placed a run that uniquely satisfies that hint
    /// number (positionally). Lets the renderer strike through individual
    /// hint values as the player completes them, instead of waiting for
    /// the whole line to finish.
    ///
    /// Algorithm: for each player-filled run, find every hint index whose
    /// length matches AND whose valid-position range contains the run's
    /// start. If exactly one hint matches, that hint is crossed off.
    /// Ambiguous (multiple matches) and unmatched runs leave hints blank.
    static func rowsCrossOff(board: NonogramBoard, hints: [[Int]]) -> [[Bool]] {
        (0..<board.size).map { row in
            let line = (0..<board.size).map { col in
                board.cell(row: row, col: col) == .filled
            }
            return crossOffMask(line: line, hints: hints[safe: row] ?? [0])
        }
    }

    static func columnsCrossOff(board: NonogramBoard, hints: [[Int]]) -> [[Bool]] {
        (0..<board.size).map { col in
            let line = (0..<board.size).map { row in
                board.cell(row: row, col: col) == .filled
            }
            return crossOffMask(line: line, hints: hints[safe: col] ?? [0])
        }
    }

    /// Run with start position. Internal to cross-off math.
    private struct PositionedRun { let start: Int; let length: Int }

    /// Pure cross-off computation for a single line. Public path is via
    /// `rowsCrossOff` / `columnsCrossOff`; this is exposed `internal` for
    /// future unit tests.
    static func crossOffMask(line: [Bool], hints: [Int]) -> [Bool] {
        let lineLength = line.count

        // Empty-line edge case: single hint of 0 means "no fills." If line
        // has zero fills, that hint is satisfied; otherwise it isn't.
        if hints == [0] {
            return [!line.contains(true)]
        }

        // 1. Compute player runs with positions.
        var runs: [PositionedRun] = []
        var current = 0
        var start = -1
        for (i, bit) in line.enumerated() {
            if bit {
                if start == -1 { start = i }
                current += 1
            } else if current > 0 {
                runs.append(PositionedRun(start: start, length: current))
                current = 0
                start = -1
            }
        }
        if current > 0 {
            runs.append(PositionedRun(start: start, length: current))
        }

        // 2. Compute valid range for each hint index (leftmost + rightmost
        // start positions consistent with the chain of preceding/following
        // hints + their gaps).
        var ranges: [(left: Int, right: Int)] = []
        var leftAccum = 0
        for i in 0..<hints.count {
            let leftMost = leftAccum
            let trailingSum = ((i + 1)..<hints.count).reduce(0) { $0 + hints[$1] }
            let trailingGaps = max(0, hints.count - 1 - i)
            let rightMost = lineLength - trailingSum - trailingGaps - hints[i]
            ranges.append((leftMost, rightMost))
            leftAccum += hints[i] + 1
        }

        // 3. For each run, find the unique hint index it satisfies. A run
        // satisfies hint i iff hints[i] equals run.length AND the run
        // fits in [ranges[i].left, ranges[i].right]. Ambiguous matches
        // (multiple valid hints) leave the hint uncrossed.
        var mask = Array(repeating: false, count: hints.count)
        for run in runs {
            var possibleIdxs: [Int] = []
            for i in 0..<hints.count {
                guard hints[i] == run.length else { continue }
                if run.start >= ranges[i].left && run.start <= ranges[i].right {
                    possibleIdxs.append(i)
                }
            }
            if possibleIdxs.count == 1 {
                mask[possibleIdxs[0]] = true
            }
        }
        return mask
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
