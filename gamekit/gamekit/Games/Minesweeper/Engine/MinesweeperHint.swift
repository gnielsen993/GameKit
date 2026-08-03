//
//  MinesweeperHint.swift
//  gamekit
//
//  Finds a square that can be proved safe from the numbers already on the
//  board, and says which numbers prove it.
//
//  Two rules, both of which a player can carry away:
//
//   1. Counting a single number — "this 2 already touches 2 unopened squares,
//      so both are mines" / "this 1 already has its mine, so the rest are
//      safe".
//   2. Comparing two overlapping numbers — the classic 1-1 and 1-2 patterns.
//      If one number's unopened squares are a subset of another's, the
//      difference resolves.
//
//  **Flags are ignored entirely.** A flag is the player's belief, not a fact,
//  and reasoning from a wrong flag would produce a confidently wrong "this is
//  safe". Everything here is derived from revealed numbers and the solver's
//  own deductions, so a mis-flagged board still gets correct advice.
//
//  The rules are deliberately incomplete: some positions need whole-board
//  enumeration to resolve, and a few need a genuine guess. The engine says it
//  cannot find a step rather than pretending either way — see
//  `MinesweeperViewModel.requestHint`.
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4).
//

import Foundation

nonisolated enum MinesweeperHint {

    enum Technique: Equatable {
        /// One number, counted on its own.
        case countingOneNumber(number: Int)
        /// Two overlapping numbers compared.
        case comparingTwoNumbers(smaller: Int, larger: Int)
    }

    struct Step: Equatable {
        /// A square proved safe to open.
        let safe: MinesweeperIndex
        /// The revealed number(s) the argument rests on — highlighted so the
        /// player can check the reasoning rather than take it on trust.
        let evidence: [MinesweeperIndex]
        let technique: Technique
    }

    /// One constraint: the unopened squares around a revealed number, and how
    /// many mines must be among them.
    private struct Constraint {
        let origin: MinesweeperIndex
        let number: Int
        let cells: Set<MinesweeperIndex>
        let mines: Int
    }

    /// The first provable safe square, or nil when these two rules cannot
    /// find one. nil does not mean the position is unsolvable.
    static func nextStep(board: MinesweeperBoard) -> Step? {
        var knownMines: Set<MinesweeperIndex> = []
        var knownSafe: Set<MinesweeperIndex> = []

        // Iterate to a fixpoint: each deduction can unlock the next.
        for _ in 0..<8 {
            let constraints = buildConstraints(
                board: board, knownMines: knownMines, knownSafe: knownSafe
            )
            if let step = applySingleNumberRules(
                constraints, knownMines: &knownMines, knownSafe: &knownSafe
            ) { return step }
            if let step = applySubsetRule(
                constraints, knownMines: &knownMines, knownSafe: &knownSafe
            ) { return step }
            if constraints.isEmpty { break }
        }
        return nil
    }

    // MARK: - Constraints

    private static func buildConstraints(
        board: MinesweeperBoard,
        knownMines: Set<MinesweeperIndex>,
        knownSafe: Set<MinesweeperIndex>
    ) -> [Constraint] {
        var result: [Constraint] = []
        for index in board.allIndices() {
            let cell = board.cell(at: index)
            guard cell.state == .revealed, cell.adjacentMineCount > 0 else { continue }

            var unknown: Set<MinesweeperIndex> = []
            var minesFound = 0
            for neighbor in index.neighbors8(rows: board.rows, cols: board.cols) {
                let neighborCell = board.cell(at: neighbor)
                // Deliberately not `.flagged` — see the header. A flag says
                // nothing; only a revealed square or our own deduction does.
                guard neighborCell.state != .revealed else { continue }
                if knownMines.contains(neighbor) {
                    minesFound += 1
                } else if !knownSafe.contains(neighbor) {
                    unknown.insert(neighbor)
                }
            }
            guard !unknown.isEmpty else { continue }
            result.append(
                Constraint(
                    origin: index,
                    number: cell.adjacentMineCount,
                    cells: unknown,
                    mines: cell.adjacentMineCount - minesFound
                )
            )
        }
        return result
    }

    // MARK: - Rule 1

    private static func applySingleNumberRules(
        _ constraints: [Constraint],
        knownMines: inout Set<MinesweeperIndex>,
        knownSafe: inout Set<MinesweeperIndex>
    ) -> Step? {
        for constraint in constraints {
            // Every remaining neighbour is a mine.
            if constraint.mines == constraint.cells.count {
                knownMines.formUnion(constraint.cells)
                continue
            }
            // All mines accounted for — the rest are safe, and that is a
            // square the player can actually open.
            if constraint.mines == 0, let safe = constraint.cells.min(by: reading) {
                knownSafe.formUnion(constraint.cells)
                return Step(
                    safe: safe,
                    evidence: [constraint.origin],
                    technique: .countingOneNumber(number: constraint.number)
                )
            }
        }
        return nil
    }

    // MARK: - Rule 2

    private static func applySubsetRule(
        _ constraints: [Constraint],
        knownMines: inout Set<MinesweeperIndex>,
        knownSafe: inout Set<MinesweeperIndex>
    ) -> Step? {
        for a in constraints {
            for b in constraints where b.origin != a.origin {
                guard a.cells.isSubset(of: b.cells), a.cells.count < b.cells.count else { continue }
                let difference = b.cells.subtracting(a.cells)
                let differenceMines = b.mines - a.mines

                // The leftover squares hold no mines — all safe.
                if differenceMines == 0, let safe = difference.min(by: reading) {
                    knownSafe.formUnion(difference)
                    return Step(
                        safe: safe,
                        evidence: [a.origin, b.origin],
                        technique: .comparingTwoNumbers(smaller: a.number, larger: b.number)
                    )
                }
                // The leftover squares are all mines — record and keep going;
                // knowing a mine often unlocks a safe square next pass.
                if differenceMines == difference.count {
                    knownMines.formUnion(difference)
                }
            }
        }
        return nil
    }

    /// Stable ordering so the same board always yields the same hint.
    private static func reading(_ lhs: MinesweeperIndex, _ rhs: MinesweeperIndex) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }
}
