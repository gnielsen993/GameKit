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

    /// Guess-and-recurse on top of the shared single-technique engine.
    ///
    /// The naked/hidden-single implementations used to live here as private
    /// sweeps. They now come from `SudokuHintEngine`, so the rater and the
    /// player-facing hint cannot drift apart — a technique the rater counts is
    /// by construction one the hint can explain.
    private func solveWithTechniques(board: inout [Int], stats: inout SolverStats) -> Bool {
        let engine = SudokuHintEngine(gridSize: gridSize, boxSize: boxSize)
        let applied = engine.applyAllSingles(board: &board)
        stats.nakedSingles += applied.naked
        stats.hiddenSingles += applied.hidden

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
}
