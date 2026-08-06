//
//  NonogramTalkthrough.swift
//  gamekit
//
//  Finds the next cell the player could deduce, and — crucially — why.
//
//  The solver this is built on already shipped: `NonogramLineSolver.solveLine`
//  returns the intersection of every arrangement consistent with the current
//  line, which is exactly "the cells you can prove". It was only ever fed a
//  blank grid, to decide whether a generated puzzle was fair. Feeding it the
//  player's board is the whole feature.
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4).
//  Returns a structured technique rather than a sentence; the presentation
//  layer owns the wording, so copy stays localizable and the engine stays
//  testable.
//

import Foundation

// Not marked `nonisolated`: NonogramBoard and the `[safe:]` subscript are
// main-actor isolated, and NonogramHints alongside this file has the same
// shape. Purity per CLAUDE §4 is about determinism and importing neither
// SwiftUI nor SwiftData, both of which hold here.
enum NonogramTalkthrough {

    /// Which line a deduction lives on.
    enum Line: Equatable, Hashable {
        case row(Int)
        case column(Int)
    }

    /// Why the forced cells are forced.
    ///
    /// Deliberately a short list. The survey's warning was that a
    /// plausible-but-wrong explanation is worse than no explanation, so every
    /// case here is one the solver can actually prove, and anything else falls
    /// through to `.forced` — which claims nothing beyond what the
    /// intersection itself guarantees.
    enum Technique: Equatable {
        /// A single clue long enough that every arrangement overlaps in the
        /// middle. The classic teachable case: an 8 in a 10-wide line fills
        /// the middle 6 no matter where it sits.
        case overlap(clue: Int, lineLength: Int)
        /// Every run in the line is already placed, so the rest must be empty.
        case lineComplete
        /// The line's clue is zero — nothing goes here at all.
        case allEmpty
        /// Provable from the intersection, without a named pattern.
        case forced
    }

    struct Deduction: Equatable {
        let line: Line
        let technique: Technique
        /// Indices within the line that must be filled.
        let newFilled: [Int]
        /// Indices within the line that must be empty.
        let newEmpty: [Int]

        var newCellCount: Int { newFilled.count + newEmpty.count }
    }

    /// The best next deduction available, or nil when the board offers none.
    ///
    /// nil means one of three very different things, and the caller is
    /// expected to distinguish them: the puzzle is finished, the player has
    /// made a mistake (see `NonogramHints.lineIsSatisfiable`), or this puzzle
    /// genuinely needs a step this line-by-line solver cannot make. The last
    /// is possible: the generator falls back to a non-line-solvable puzzle
    /// after 60 attempts, and curated puzzles are filtered on shape alone.
    static func nextDeduction(
        board: NonogramBoard,
        rowHints: [[Int]],
        columnHints: [[Int]]
    ) -> Deduction? {
        var best: Deduction?

        for row in 0..<board.size {
            let line = (0..<board.size).map { state(board.cell(row: row, col: $0)) }
            let hints = rowHints.indices.contains(row) ? rowHints[row] : [0]
            if let deduction = deduce(line: line, hints: hints, as: .row(row)) {
                best = preferred(best, deduction)
            }
        }

        for col in 0..<board.size {
            let line = (0..<board.size).map { state(board.cell(row: $0, col: col)) }
            let hints = columnHints.indices.contains(col) ? columnHints[col] : [0]
            if let deduction = deduce(line: line, hints: hints, as: .column(col)) {
                best = preferred(best, deduction)
            }
        }

        return best
    }

    // MARK: - Ranking

    /// How much a technique teaches, best first. This ranks above raw yield
    /// on purpose: the point of the feature is the explanation, not the
    /// cells. An overlap argument is worth more to a stuck player than "this
    /// row's clue is zero, mark it all" even when the zero row reveals twice
    /// as many squares.
    private static func teachingRank(_ technique: Technique) -> Int {
        switch technique {
        case .overlap:      return 0
        case .lineComplete: return 1
        case .allEmpty:     return 2
        case .forced:       return 3
        }
    }

    /// Better technique first, then the smallest useful action set, then
    /// first-encountered — a short task is easier to follow and finish.
    /// so the result is stable rather than dependent on iteration order.
    private static func preferred(_ lhs: Deduction?, _ rhs: Deduction) -> Deduction {
        guard let lhs else { return rhs }
        let lhsRank = teachingRank(lhs.technique)
        let rhsRank = teachingRank(rhs.technique)
        if lhsRank != rhsRank { return lhsRank < rhsRank ? lhs : rhs }
        if lhs.newCellCount != rhs.newCellCount {
            return lhs.newCellCount < rhs.newCellCount ? lhs : rhs
        }
        return lhs
    }

    // MARK: - Per-line deduction

    private static func deduce(
        line: [NonogramLineSolver.CellState],
        hints: [Int],
        as lineID: Line
    ) -> Deduction? {
        guard let solved = NonogramLineSolver.solveLine(line: line, hints: hints) else {
            return nil   // contradiction — the player's error, not a deduction
        }

        var newFilled: [Int] = []
        var newEmpty: [Int] = []
        for index in line.indices where line[index] == .unknown {
            switch solved[index] {
            case .filled: newFilled.append(index)
            case .empty:  newEmpty.append(index)
            case .unknown: break
            }
        }
        guard !newFilled.isEmpty || !newEmpty.isEmpty else { return nil }

        return Deduction(
            line: lineID,
            technique: classify(line: line, hints: hints, newFilled: newFilled),
            newFilled: newFilled,
            newEmpty: newEmpty
        )
    }

    private static func classify(
        line: [NonogramLineSolver.CellState],
        hints: [Int],
        newFilled: [Int]
    ) -> Technique {
        if hints.isEmpty || hints == [0] { return .allEmpty }

        let filledCount = line.filter { $0 == .filled }.count
        let clueTotal = hints.reduce(0, +)

        // Every run already on the board: what is left can only be empty.
        if filledCount == clueTotal && newFilled.isEmpty { return .lineComplete }

        // Overlap is only honestly nameable for a single clue on a line the
        // player has not touched — with several clues, or existing marks, the
        // intersection is doing more than the overlap argument explains.
        if hints.count == 1,
           filledCount == 0,
           !line.contains(.empty),
           !newFilled.isEmpty {
            return .overlap(clue: hints[0], lineLength: line.count)
        }

        return .forced
    }

    // MARK: - Adapter

    /// The board's three-state cell in solver terms. A cell the player has not
    /// touched is *unknown*, not empty — only an explicit mark asserts that
    /// nothing goes there.
    private static func state(_ cell: NonogramCellState) -> NonogramLineSolver.CellState {
        switch cell {
        case .filled: return .filled
        case .marked: return .empty
        case .empty:  return .unknown
        }
    }
}
