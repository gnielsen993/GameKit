//
//  NonogramLineSolver.swift
//  gamekit
//
//  Pure line-by-line constraint solver. Used by `NonogramGenerator` to
//  reject puzzles requiring guessing — every accepted procedural puzzle
//  is line-solvable (only one consistent solution under iterative
//  per-line constraint propagation).
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4
//  engine-purity). The solver does NOT search by guessing — the whole
//  point is to detect puzzles that REQUIRE guessing and reject them.
//

import Foundation

nonisolated enum NonogramLineSolver {

    /// Per-cell state during line-solver iteration.
    enum CellState: UInt8 {
        case unknown = 0
        case filled = 1
        case empty = 2
    }

    /// Line-by-line solve. Given the row + column hint lists, returns
    /// `true` if iterative constraint propagation determines every cell
    /// without guessing. Used by NonogramGenerator as the
    /// "is this fair?" gate.
    static func isLineSolvable(
        size: Int,
        rowHints: [[Int]],
        columnHints: [[Int]]
    ) -> Bool {
        var grid = [CellState](repeating: .unknown, count: size * size)

        var changed = true
        while changed {
            changed = false

            for row in 0..<size {
                let line = (0..<size).map { grid[row * size + $0] }
                guard let next = solveLine(line: line, hints: rowHints[row]) else {
                    return false  // contradiction → not line-solvable
                }
                for c in 0..<size where line[c] != next[c] {
                    grid[row * size + c] = next[c]
                    changed = true
                }
            }

            for col in 0..<size {
                let line = (0..<size).map { grid[$0 * size + col] }
                guard let next = solveLine(line: line, hints: columnHints[col]) else {
                    return false
                }
                for r in 0..<size where line[r] != next[r] {
                    grid[r * size + col] = next[r]
                    changed = true
                }
            }
        }

        return !grid.contains(.unknown)
    }

    /// Single-line propagation. Enumerate every placement of runs that's
    /// consistent with both the hints AND the current known cells; the
    /// AND-intersection of all placements is the new known state.
    /// Returns nil if no placement satisfies the constraints (contradiction).
    static func solveLine(line: [CellState], hints: [Int]) -> [CellState]? {
        let n = line.count
        // Empty hint or [0] → all-empty line.
        if hints.isEmpty || hints == [0] {
            for cell in line where cell == .filled { return nil }
            return [CellState](repeating: .empty, count: n)
        }

        var placements: [[CellState]] = []
        enumerate(
            n: n,
            hints: hints,
            hintIdx: 0,
            startPos: 0,
            current: [CellState](repeating: .empty, count: n),
            line: line,
            out: &placements,
            cap: 10_000  // safety cap — pathological lines bail out
        )
        guard !placements.isEmpty else { return nil }

        // Intersect all placements. Cells with the same state in every
        // placement become known; the rest stay unknown.
        var result = placements[0]
        for p in placements.dropFirst() {
            for i in 0..<n where result[i] != p[i] {
                result[i] = .unknown
            }
        }
        return result
    }

    /// Recursive enumeration of valid placements, pruning against the
    /// caller's known cells. `current` is the in-progress placement;
    /// each recursion places `hints[hintIdx]` starting at some position
    /// `>= startPos`, then recurses. Already-known cells are checked at
    /// every step so impossible placements abort early.
    private static func enumerate(
        n: Int,
        hints: [Int],
        hintIdx: Int,
        startPos: Int,
        current: [CellState],
        line: [CellState],
        out: inout [[CellState]],
        cap: Int
    ) {
        if out.count >= cap { return }

        if hintIdx == hints.count {
            // Tail: every remaining cell must be empty. `startPos` can be
            // n+1 when the previous run ended on the last cell — guard
            // before forming the range, otherwise Swift traps on
            // `(n+1)..<n`.
            if startPos < n {
                for i in startPos..<n where line[i] == .filled { return }
            }
            out.append(current)
            return
        }

        let runLen = hints[hintIdx]
        let remainingRuns = hints[(hintIdx + 1)...]
        // Min space remaining after this run: sum(remaining) + (count(remaining) - 1) gaps + 1 gap before
        let trailingNeed = remainingRuns.reduce(0, +) + max(0, remainingRuns.count - 1) + (remainingRuns.isEmpty ? 0 : 1)
        let lastStart = n - runLen - trailingNeed

        guard lastStart >= startPos else { return }

        for start in startPos...lastStart {
            // Pre-run gap: line cells [startPos, start) must be empty-compatible.
            var ok = true
            for i in startPos..<start where line[i] == .filled {
                ok = false; break
            }
            if !ok { continue }

            // Run cells [start, start+runLen) must be filled-compatible.
            for i in start..<(start + runLen) where line[i] == .empty {
                ok = false; break
            }
            if !ok { continue }

            // Cell after run (if any) must be empty-compatible.
            let after = start + runLen
            if after < n && line[after] == .filled { continue }

            var next = current
            for i in startPos..<start { next[i] = .empty }
            for i in start..<after { next[i] = .filled }
            if after < n { next[after] = .empty }

            let nextStart = after + 1
            enumerate(
                n: n, hints: hints, hintIdx: hintIdx + 1,
                startPos: nextStart, current: next, line: line,
                out: &out, cap: cap
            )
        }
    }
}
