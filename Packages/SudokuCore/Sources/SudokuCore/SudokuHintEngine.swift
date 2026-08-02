import Foundation

/// Finds the next digit a player can *prove*, and says which technique proves
/// it and which squares carry the argument.
///
/// The logic already existed inside `TechniqueRater`, but shaped for a
/// different job: it swept every naked single, then every hidden single, and
/// recorded only counters, because all it needed was a difficulty score.
/// A hint needs the opposite — the *first* step, with its reasoning intact.
/// `TechniqueRater` is now built on this type, so there is one implementation
/// of each technique rather than two that can drift apart.
///
/// Deliberately limited to naked and hidden singles. Those are the two the
/// original rater implemented, they are the two this engine can prove, and a
/// hint that names a technique it did not actually apply would be worse than
/// no hint. Puzzles needing more than singles return nil, and the caller is
/// expected to say so plainly rather than invent a step.
public struct SudokuHintEngine: Sendable {

    /// Which argument proves the digit.
    public enum Technique: Equatable, Sendable {
        /// One square, one possibility: every other digit is already ruled out
        /// by its row, column, and box.
        case nakedSingle
        /// One digit, one place: it fits nowhere else in this unit.
        case hiddenSingle(unit: Unit)
    }

    /// Which group of nine carries a hidden-single argument.
    public enum Unit: Equatable, Sendable {
        case row(Int)
        case column(Int)
        case box(row: Int, column: Int)
    }

    public struct Step: Equatable, Sendable {
        /// Flat index into the 81-cell board, row-major.
        public let index: Int
        public let value: Int
        public let technique: Technique
        /// The squares the argument rests on: the containing unit for a hidden
        /// single, the peers that eliminate the alternatives for a naked one.
        /// Callers highlight these; nobody has to trust the claim blindly.
        public let supportingIndices: [Int]

        public var row: Int { index / 9 }
        public var column: Int { index % 9 }
    }

    public let gridSize: Int
    public let boxSize: Int

    public init(gridSize: Int = 9, boxSize: Int = 3) {
        self.gridSize = gridSize
        self.boxSize = boxSize
    }

    /// The first provable step on `board`, or nil when singles cannot advance
    /// it. `board` is row-major with 0 for an empty square.
    ///
    /// nil does not mean the puzzle is unsolvable — it means it needs a
    /// technique beyond singles, or it is already finished, or the player has
    /// made it inconsistent. Distinguishing those is the caller's job.
    public func nextStep(board: [Int]) -> Step? {
        guard board.count == gridSize * gridSize else { return nil }

        // Naked singles first: "this square can only be a 4" is the easier
        // argument to follow, and it needs no unit to explain it.
        for index in board.indices where board[index] == 0 {
            let candidates = sudokuCandidates(
                at: index, board: board, gridSize: gridSize, boxSize: boxSize
            )
            if candidates.count == 1, let value = candidates.first {
                return Step(
                    index: index,
                    value: value,
                    technique: .nakedSingle,
                    supportingIndices: peers(of: index)
                )
            }
        }

        for row in 0..<gridSize {
            if let step = hiddenSingle(
                in: sudokuUnitRow(row, gridSize: gridSize), board: board, unit: .row(row)
            ) { return step }
        }
        for col in 0..<gridSize {
            if let step = hiddenSingle(
                in: sudokuUnitCol(col, gridSize: gridSize), board: board, unit: .column(col)
            ) { return step }
        }
        for boxRow in 0..<(gridSize / boxSize) {
            for boxCol in 0..<(gridSize / boxSize) {
                let unit = sudokuUnitBox(
                    boxRow: boxRow, boxCol: boxCol, gridSize: gridSize, boxSize: boxSize
                )
                if let step = hiddenSingle(
                    in: unit, board: board, unit: .box(row: boxRow, column: boxCol)
                ) { return step }
            }
        }

        return nil
    }

    /// Applies singles repeatedly until none remain. Used by `TechniqueRater`
    /// so the rater and the hint share one definition of each technique.
    /// Returns how many of each were applied.
    func applyAllSingles(board: inout [Int]) -> (naked: Int, hidden: Int) {
        var naked = 0
        var hidden = 0
        while let step = nextStep(board: board) {
            board[step.index] = step.value
            switch step.technique {
            case .nakedSingle:  naked += 1
            case .hiddenSingle: hidden += 1
            }
        }
        return (naked, hidden)
    }

    // MARK: - Private

    private func hiddenSingle(in unit: [Int], board: [Int], unit unitID: Unit) -> Step? {
        for value in 1...gridSize {
            var spots: [Int] = []
            for index in unit where board[index] == 0 {
                if sudokuIsValid(
                    value: value, at: index, board: board,
                    gridSize: gridSize, boxSize: boxSize
                ) {
                    spots.append(index)
                }
            }
            if spots.count == 1, let index = spots.first {
                return Step(
                    index: index,
                    value: value,
                    technique: .hiddenSingle(unit: unitID),
                    supportingIndices: unit
                )
            }
        }
        return nil
    }

    /// Every square sharing a row, column, or box with `index` — the ones
    /// doing the eliminating in a naked-single argument.
    private func peers(of index: Int) -> [Int] {
        let row = index / gridSize
        let col = index % gridSize
        var result = Set(sudokuUnitRow(row, gridSize: gridSize))
        result.formUnion(sudokuUnitCol(col, gridSize: gridSize))
        result.formUnion(
            sudokuUnitBox(
                boxRow: row / boxSize, boxCol: col / boxSize,
                gridSize: gridSize, boxSize: boxSize
            )
        )
        result.remove(index)
        return result.sorted()
    }
}
