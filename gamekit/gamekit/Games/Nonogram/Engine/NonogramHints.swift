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
            let filled = (0..<board.size).map { col in
                board.cell(row: row, col: col) == .filled
            }
            let marked = (0..<board.size).map { col in
                board.cell(row: row, col: col) == .marked
            }
            return crossOffMask(filled: filled, marked: marked, hints: hints[safe: row] ?? [0])
        }
    }

    static func columnsCrossOff(board: NonogramBoard, hints: [[Int]]) -> [[Bool]] {
        (0..<board.size).map { col in
            let filled = (0..<board.size).map { row in
                board.cell(row: row, col: col) == .filled
            }
            let marked = (0..<board.size).map { row in
                board.cell(row: row, col: col) == .marked
            }
            return crossOffMask(filled: filled, marked: marked, hints: hints[safe: col] ?? [0])
        }
    }

    /// Run with start position. Internal to cross-off math.
    private struct PositionedRun { let start: Int; let length: Int }

    /// Cross-off computation for a single line. A hint number is crossed
    /// off ONLY when the corresponding player run is locked into that hint
    /// position by the surrounding cells — i.e. across every valid
    /// placement of all hints consistent with the current fills + X marks,
    /// the run maps to the same hint index.
    ///
    /// Player intuition (from feedback): if hints are `[1, 1]` in a 10-cell
    /// row and the player places a fill at column 3 with cols 0–2 still
    /// blank, neither hint may be crossed yet — the fill could be either
    /// the first OR the second 1 until walls (edges or X marks) lock its
    /// position. Marking cols 0–2 with X then crosses off the first hint.
    static func crossOffMask(filled: [Bool], marked: [Bool], hints: [Int]) -> [Bool] {
        let n = filled.count

        // Empty-line edge case: single hint of 0 means the line has no fills.
        // Crossed off when there are zero fills — and ALL non-mark cells
        // can plausibly be empty. Marks are fine; they're an explicit
        // "no fill" signal.
        if hints == [0] {
            let allEmpty = !filled.contains(true)
            return [allEmpty]
        }

        // Player runs we want to map to hint indices.
        var playerRuns: [PositionedRun] = []
        var cur = 0
        var start = -1
        for (i, bit) in filled.enumerated() {
            if bit {
                if start == -1 { start = i }
                cur += 1
            } else if cur > 0 {
                playerRuns.append(PositionedRun(start: start, length: cur))
                cur = 0
                start = -1
            }
        }
        if cur > 0 {
            playerRuns.append(PositionedRun(start: start, length: cur))
        }

        // Enumerate every valid placement of the hint chain consistent
        // with the current fills + X marks. Each entry is the array of
        // `start` positions, indexed by hint.
        var placements: [[Int]] = []
        enumeratePlacements(
            n: n, hints: hints, hintIdx: 0, startPos: 0,
            filled: filled, marked: marked, current: [],
            out: &placements, cap: 4000
        )
        guard !placements.isEmpty else {
            // No valid placement — the line state is internally inconsistent
            // (e.g. lives mode just transitioned). Cross nothing off.
            return Array(repeating: false, count: hints.count)
        }

        // For each player run, accumulate the set of hint indices it could
        // be across all valid placements. A player run is identified with
        // a placed hint ONLY when their length AND start position match
        // exactly — a length-1 fill inside a length-12 placed run hasn't
        // completed that hint yet, so it doesn't count.
        var candidates: [Set<Int>] = playerRuns.map { _ in Set<Int>() }
        for placement in placements {
            for (hintIdx, runStart) in placement.enumerated() {
                let runLen = hints[hintIdx]
                for (pIdx, pRun) in playerRuns.enumerated()
                where pRun.length == runLen && pRun.start == runStart {
                    candidates[pIdx].insert(hintIdx)
                }
            }
        }

        var mask = Array(repeating: false, count: hints.count)
        for set in candidates where set.count == 1 {
            mask[set.first!] = true
        }
        return mask
    }

    /// Recursively place hint `hintIdx` somewhere in `[startPos, n)`. A
    /// placement is valid only when:
    ///   - The pre-run gap `[startPos, start)` contains no filled cells.
    ///   - The run cells `[start, start+len)` contain no X marks.
    ///   - The cell immediately after the run (if any) is not filled (a
    ///     filled cell there would extend the run beyond `len`).
    /// Mirrors NonogramLineSolver.enumerate's pruning, with the addition
    /// that runs reject cells marked X.
    private static func enumeratePlacements(
        n: Int,
        hints: [Int],
        hintIdx: Int,
        startPos: Int,
        filled: [Bool],
        marked: [Bool],
        current: [Int],
        out: inout [[Int]],
        cap: Int
    ) {
        if out.count >= cap { return }

        if hintIdx == hints.count {
            if startPos < n {
                for i in startPos..<n where filled[i] { return }
            }
            out.append(current)
            return
        }

        let runLen = hints[hintIdx]
        let remaining = hints[(hintIdx + 1)...]
        let trailingNeed = remaining.reduce(0, +)
            + max(0, remaining.count - 1)
            + (remaining.isEmpty ? 0 : 1)
        let lastStart = n - runLen - trailingNeed
        guard lastStart >= startPos else { return }

        for s in startPos...lastStart {
            // Pre-run gap must not contain any filled cells.
            var ok = true
            for i in startPos..<s where filled[i] { ok = false; break }
            if !ok { continue }
            // Run cells must not be marked X.
            for i in s..<(s + runLen) where marked[i] { ok = false; break }
            if !ok { continue }
            // Cell after run must not be filled (would over-extend the run).
            let after = s + runLen
            if after < n && filled[after] { continue }

            var next = current
            next.append(s)
            enumeratePlacements(
                n: n, hints: hints, hintIdx: hintIdx + 1,
                startPos: after + 1, filled: filled, marked: marked,
                current: next, out: &out, cap: cap
            )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
