import Foundation

public enum SudokuCoreError: Error, Equatable {
    case invalidPuzzleStringLength
    case invalidSolutionStringLength
    case invalidSolutionString
    case solutionDoesNotMatchPuzzle
    case nonUniqueSolution
    case difficultyMismatch(expected: Difficulty, actual: Difficulty)
    case hashAlreadyExists
    case unableToRateDifficulty
}
