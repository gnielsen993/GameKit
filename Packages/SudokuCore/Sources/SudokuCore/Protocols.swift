import Foundation

public protocol PuzzleGenerating: Sendable {
    func generate(targetDifficulty: Difficulty, seed: Int?) throws -> Puzzle
}

public protocol PuzzleSolving: Sendable {
    func countSolutions(for puzzleString: String, max: Int) throws -> Int
}

public protocol DifficultyRating: Sendable {
    func rate(puzzleString: String, solutionString: String) throws -> Difficulty
}

public protocol PuzzleHashing: Sendable {
    func canonicalHash(for puzzleString: String) -> String
}

public protocol PuzzleRepository: Sendable {
    func save(_ puzzle: Puzzle) async throws
    func nextPuzzle(excluding statuses: Set<PuzzleStatus>, difficulty: Difficulty?) async throws -> Puzzle?
    func markStatus(_ status: PuzzleStatus, for puzzleHash: String) async throws
    func updateProgress(
        for puzzleHash: String,
        elapsedSec: Int,
        mistakes: Int,
        hintsUsed: Int,
        score: Int,
        boardString: String,
        notesJSON: String?
    ) async throws
    func fetchInProgress() async throws -> (Puzzle, PuzzleProgress)?
    func inventoryCounts() async throws -> [Difficulty: Int]
    func clearLibrary() async throws
}
