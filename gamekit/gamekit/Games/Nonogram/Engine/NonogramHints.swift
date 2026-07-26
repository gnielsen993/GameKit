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
    /// when the player has visibly resolved that hint. Unique clue values
    /// may resolve by exact logical matching; repeated values additionally
    /// need an edge-connected chain. Lets the renderer strike through
    /// individual hints without revealing a duplicate clue's hidden index.
    ///
    /// Algorithm: find exact logical matches across every valid placement,
    /// then filter duplicate values through the visible edge-anchor rule.
    /// Ambiguous, unmatched, and isolated duplicate runs stay uncrossed.
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

    /// Cross-off computation for a single line. A completed run first has to
    /// map to one hint index across every valid placement. A unique clue value
    /// may then cross immediately; repeated values additionally require a
    /// visible chain from the left or right edge. This avoids revealing which
    /// identical clue an isolated interior run satisfies.
    ///
    /// Player intuition (from feedback): if hints are `[1, 1]` in a 10-cell
    /// row and the player places a fill at column 3 with cols 0–2 still
    /// blank, neither hint may be crossed yet — even if board geometry proves
    /// which `1` it is. Marking cols 0–2 with X visibly connects the run to
    /// the left edge, so the first hint then crosses. Conversely, an interior
    /// `4` in `[1, 4, 3]` can cross without an edge chain because its value
    /// identifies it unambiguously to the player.
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

        // Once the entire visible line matches its clue sequence, every clue
        // is resolved regardless of whether the player marked each separator.
        if runs(in: filled) == hints {
            return Array(repeating: true, count: hints.count)
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
        // belong to across all valid placements. Use containment here, not
        // exact equality: a lone fill that could still grow into a `3` or
        // `5` must not prematurely cross off a `1`.
        var candidates: [Set<Int>] = playerRuns.map { _ in Set<Int>() }
        var exactMatches = Array(repeating: false, count: playerRuns.count)
        for placement in placements {
            for (hintIdx, runStart) in placement.enumerated() {
                let runLen = hints[hintIdx]
                let runEnd = runStart + runLen
                for (pIdx, pRun) in playerRuns.enumerated()
                where pRun.start >= runStart && pRun.start + pRun.length <= runEnd {
                    candidates[pIdx].insert(hintIdx)
                    if pRun.length == runLen && pRun.start == runStart {
                        exactMatches[pIdx] = true
                    }
                }
            }
        }

        let anchored = edgeAnchoredMask(filled: filled, marked: marked, hints: hints)
        let valueCounts = Dictionary(grouping: hints, by: { $0 }).mapValues(\.count)
        var mask = Array(repeating: false, count: hints.count)
        for (idx, set) in candidates.enumerated() where exactMatches[idx] && set.count == 1 {
            let hintIdx = set.first!
            let valueIsUnique = valueCounts[hints[hintIdx]] == 1
            mask[hintIdx] = valueIsUnique || anchored[hintIdx]
        }
        return mask
    }

    /// Returns clue indices reached by an uninterrupted, player-visible chain
    /// from either edge. X marks may lead to a run and separate consecutive
    /// runs; an untouched blank stops the scan. The current exact-length run
    /// may cross as soon as the chain reaches it, while advancing to another
    /// clue requires an explicit X separator.
    private static func edgeAnchoredMask(
        filled: [Bool],
        marked: [Bool],
        hints: [Int]
    ) -> [Bool] {
        var mask = Array(repeating: false, count: hints.count)

        func scan(fromLeft: Bool) -> [Int] {
            var reached: [Int] = []
            var cell = fromLeft ? 0 : filled.count - 1
            var hintIdx = fromLeft ? 0 : hints.count - 1
            let step = fromLeft ? 1 : -1

            func isInBounds(_ index: Int) -> Bool {
                index >= 0 && index < filled.count
            }

            while isInBounds(cell), hintIdx >= 0, hintIdx < hints.count {
                while isInBounds(cell), marked[cell] { cell += step }
                guard isInBounds(cell), filled[cell] else { break }

                var runLength = 0
                while isInBounds(cell), filled[cell] {
                    runLength += 1
                    cell += step
                }
                guard runLength == hints[hintIdx] else { break }
                reached.append(hintIdx)

                // The current edge-connected run is resolved. Without an X
                // after it, however, the visible chain cannot reach another.
                guard isInBounds(cell), marked[cell] else { break }
                hintIdx += step
            }
            return reached
        }

        for index in scan(fromLeft: true) { mask[index] = true }
        for index in scan(fromLeft: false) { mask[index] = true }
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
