import Foundation

public struct GeneratePuzzleUseCase: Sendable {
    public struct Result: Sendable {
        public let puzzle: Puzzle
        public let matchesTarget: Bool

        public init(puzzle: Puzzle, matchesTarget: Bool) {
            self.puzzle = puzzle
            self.matchesTarget = matchesTarget
        }
    }

    public let generator: PuzzleGenerating
    public let solver: PuzzleSolving
    public let rater: DifficultyRating
    public let hasher: PuzzleHashing
    public let repository: PuzzleRepository

    public init(
        generator: PuzzleGenerating,
        solver: PuzzleSolving,
        rater: DifficultyRating,
        hasher: PuzzleHashing,
        repository: PuzzleRepository
    ) {
        self.generator = generator
        self.solver = solver
        self.rater = rater
        self.hasher = hasher
        self.repository = repository
    }

    public func run(targetDifficulty: Difficulty, seed: Int? = nil) async throws -> Puzzle {
        let candidate = try generator.generate(targetDifficulty: targetDifficulty, seed: seed)
        let ratedDifficulty = try validateAndRate(candidate)
        guard ratedDifficulty == targetDifficulty else {
            throw SudokuCoreError.difficultyMismatch(expected: targetDifficulty, actual: ratedDifficulty)
        }

        let puzzle = puzzleWithRatedDifficulty(candidate, ratedDifficulty: ratedDifficulty)
        try await repository.save(puzzle)
        return puzzle
    }

    public func runSavingRatedCandidate(targetDifficulty: Difficulty, seed: Int? = nil) async throws -> Result {
        let candidate = try generator.generate(targetDifficulty: targetDifficulty, seed: seed)
        let ratedDifficulty = try validateAndRate(candidate)
        let puzzle = puzzleWithRatedDifficulty(candidate, ratedDifficulty: ratedDifficulty)

        try await repository.save(puzzle)
        return Result(puzzle: puzzle, matchesTarget: ratedDifficulty == targetDifficulty)
    }

    private func validateAndRate(_ candidate: Puzzle) throws -> Difficulty {
        guard candidate.puzzleString.count == 81 else { throw SudokuCoreError.invalidPuzzleStringLength }
        guard candidate.solutionString.count == 81 else { throw SudokuCoreError.invalidSolutionStringLength }

        guard sudokuCompleteSolutionIsValid(solutionString: candidate.solutionString, gridSize: 9, boxSize: 3) else {
            throw SudokuCoreError.invalidSolutionString
        }
        guard sudokuSolutionMatchesGivens(puzzleString: candidate.puzzleString, solutionString: candidate.solutionString, gridSize: 9) else {
            throw SudokuCoreError.solutionDoesNotMatchPuzzle
        }

        let solutionCount = try solver.countSolutions(for: candidate.puzzleString, max: 2)
        guard solutionCount == 1 else { throw SudokuCoreError.nonUniqueSolution }

        return try rater.rate(puzzleString: candidate.puzzleString, solutionString: candidate.solutionString)
    }

    private func puzzleWithRatedDifficulty(_ candidate: Puzzle, ratedDifficulty: Difficulty) -> Puzzle {
        Puzzle(
            id: candidate.id,
            hash: hasher.canonicalHash(for: candidate.puzzleString),
            puzzleString: candidate.puzzleString,
            solutionString: candidate.solutionString,
            difficulty: ratedDifficulty,
            source: candidate.source,
            seed: candidate.seed,
            createdAt: candidate.createdAt
        )
    }
}

public struct PlayNextPuzzleUseCase: Sendable {
    public let repository: PuzzleRepository

    public init(repository: PuzzleRepository) {
        self.repository = repository
    }

    public func run(difficulty: Difficulty?) async throws -> Puzzle? {
        // V1 default: only serve brand-new puzzles in Play Next.
        try await repository.nextPuzzle(
            excluding: [.inProgress, .completed, .skipped],
            difficulty: difficulty
        )
    }
}
