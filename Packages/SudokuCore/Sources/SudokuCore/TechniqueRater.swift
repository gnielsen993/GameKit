import Foundation

struct SolverStats {
    var nakedSingles = 0
    var hiddenSingles = 0
    var guesses = 0
}

public struct TechniqueRater: DifficultyRating {
    public let gridSize: Int
    public let boxSize: Int

    public init(gridSize: Int = 9, boxSize: Int = 3) {
        self.gridSize = gridSize
        self.boxSize = boxSize
    }

    public func rate(puzzleString: String, solutionString: String) throws -> Difficulty {
        guard gridSize == 9 else { throw SudokuCoreError.unableToRateDifficulty }
        var board = sudokuParseBoard(puzzleString, gridSize: gridSize)
        guard board.count == gridSize * gridSize else {
            throw SudokuCoreError.invalidPuzzleStringLength
        }
        guard solutionString.count == gridSize * gridSize else {
            throw SudokuCoreError.invalidSolutionStringLength
        }
        guard sudokuCompleteSolutionIsValid(
            solutionString: solutionString,
            gridSize: gridSize,
            boxSize: boxSize
        ) else {
            throw SudokuCoreError.invalidSolutionString
        }
        guard sudokuSolutionMatchesGivens(
            puzzleString: puzzleString,
            solutionString: solutionString,
            gridSize: gridSize
        ) else {
            throw SudokuCoreError.solutionDoesNotMatchPuzzle
        }
        let clues = puzzleString.filter { $0 != "0" }.count

        // Very sparse puzzles are classified as Extreme even when this
        // lightweight rater can solve them with only a few guesses.
        if clues < 25 { return .extreme }

        var stats = SolverStats()
        _ = solveWithTechniques(board: &board, stats: &stats)

        // Easy: purely logic-solvable (no guessing) with ≤10 hidden singles.
        if stats.guesses == 0 && stats.hiddenSingles <= 10 { return .easy }
        // Medium: at most 2 guesses, reasonably dense clue set.
        if stats.guesses <= 2 && clues >= 28 { return .medium }
        // Hard: up to 5 guesses, still has enough clues for a fair fight.
        if stats.guesses <= 5 && clues >= 25 { return .hard }
        return .extreme
    }

    private func solveWithTechniques(board: inout [Int], stats: inout SolverStats) -> Bool {
        while true {
            var progress = false
            if applyNakedSingles(board: &board, stats: &stats) { progress = true }
            if applyHiddenSingles(board: &board, stats: &stats) { progress = true }
            if !progress { break }
        }

        guard let (index, candidates) = sudokuBestCell(board: board, gridSize: gridSize, boxSize: boxSize) else { return true }
        if candidates.isEmpty { return false }

        stats.guesses += 1
        let savedStats = stats
        for value in candidates {
            var trial = board
            trial[index] = value
            var trialStats = savedStats
            if solveWithTechniques(board: &trial, stats: &trialStats) {
                board = trial
                stats = trialStats
                return true
            }
        }
        return false
    }

    private func applyNakedSingles(board: inout [Int], stats: inout SolverStats) -> Bool {
        var progress = false
        for index in board.indices where board[index] == 0 {
            let candidates = sudokuCandidates(at: index, board: board, gridSize: gridSize, boxSize: boxSize)
            if candidates.count == 1, let value = candidates.first {
                board[index] = value
                stats.nakedSingles += 1
                progress = true
            }
        }
        return progress
    }

    private func applyHiddenSingles(board: inout [Int], stats: inout SolverStats) -> Bool {
        var progress = false
        for row in 0..<gridSize {
            if placeHiddenSingle(in: sudokuUnitRow(row, gridSize: gridSize), board: &board, stats: &stats) { progress = true }
        }
        for col in 0..<gridSize {
            if placeHiddenSingle(in: sudokuUnitCol(col, gridSize: gridSize), board: &board, stats: &stats) { progress = true }
        }
        for boxRow in 0..<(gridSize / boxSize) {
            for boxCol in 0..<(gridSize / boxSize) {
                if placeHiddenSingle(in: sudokuUnitBox(boxRow: boxRow, boxCol: boxCol, gridSize: gridSize, boxSize: boxSize), board: &board, stats: &stats) { progress = true }
            }
        }
        return progress
    }

    private func placeHiddenSingle(in unit: [Int], board: inout [Int], stats: inout SolverStats) -> Bool {
        var placed = false
        for value in 1...gridSize {
            var spots: [Int] = []
            for index in unit where board[index] == 0 {
                if sudokuIsValid(value: value, at: index, board: board, gridSize: gridSize, boxSize: boxSize) {
                    spots.append(index)
                }
            }
            if spots.count == 1, let index = spots.first {
                board[index] = value
                stats.hiddenSingles += 1
                placed = true
            }
        }
        return placed
    }
}
