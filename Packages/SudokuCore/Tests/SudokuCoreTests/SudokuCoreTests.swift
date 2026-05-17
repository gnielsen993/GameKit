import Foundation
import XCTest

@testable import SudokuCore

// MARK: - Existing stubs + use-case tests

private struct GeneratorStub: PuzzleGenerating {
  let output: Puzzle
  func generate(targetDifficulty: Difficulty, seed: Int?) throws -> Puzzle { output }
}

private struct SolverStub: PuzzleSolving {
  let count: Int
  func countSolutions(for puzzleString: String, max: Int) throws -> Int { count }
}

private struct RaterStub: DifficultyRating {
  let difficulty: Difficulty
  func rate(puzzleString: String, solutionString: String) throws -> Difficulty { difficulty }
}

private struct HasherStub: PuzzleHashing {
  let hash: String
  func canonicalHash(for puzzleString: String) -> String { hash }
}

private actor RepositoryStub: PuzzleRepository {
  private(set) var saved: [Puzzle] = []
  private(set) var lastExcluded: Set<PuzzleStatus> = []
  private(set) var nextResult: Puzzle?

  func save(_ puzzle: Puzzle) async throws {
    saved.append(puzzle)
  }

  func nextPuzzle(excluding statuses: Set<PuzzleStatus>, difficulty: Difficulty?) async throws
    -> Puzzle?
  {
    lastExcluded = statuses
    return nextResult
  }

  func markStatus(_ status: PuzzleStatus, for puzzleHash: String) async throws {}
  func updateProgress(
    for puzzleHash: String, elapsedSec: Int, mistakes: Int, hintsUsed: Int, score: Int,
    boardString: String, notesJSON: String?
  ) async throws {}
  func fetchInProgress() async throws -> (Puzzle, PuzzleProgress)? { nil }
  func inventoryCounts() async throws -> [Difficulty: Int] { [:] }
  func clearLibrary() async throws {}

  func savedPuzzles() -> [Puzzle] { saved }
  func excludedStatuses() -> Set<PuzzleStatus> { lastExcluded }
  func setNextResult(_ puzzle: Puzzle?) { nextResult = puzzle }
}

final class SudokuCoreTests: XCTestCase {
  private func expect(
    _ expression: @autoclosure () throws -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) rethrows {
    XCTAssertTrue(try expression(), file: file, line: line)
  }

  private func expectThrows<E: Error & Equatable>(
    _ expectedError: E,
    _ body: () throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
      XCTAssertEqual(error as? E, expectedError, file: file, line: line)
    }
  }

  func testGeneratePuzzlePersistsRatedPuzzle() async throws {
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: puzzle9Easy,
      solutionString: solution9,
      difficulty: .easy,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 1),
      rater: RaterStub(difficulty: .hard),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    let saved = try await useCase.run(targetDifficulty: .hard)
    expect(saved.difficulty == .hard)
    expect(saved.hash == "canonical-hash")

    let stored = await repo.savedPuzzles()
    expect(stored.count == 1)
    expect(stored.first?.hash == "canonical-hash")
  }

  func testPlayNextExcludesNonNewByDefault() async throws {
    let repo = RepositoryStub()
    let useCase = PlayNextPuzzleUseCase(repository: repo)
    _ = try await useCase.run(difficulty: nil)

    let excluded = await repo.excludedStatuses()
    expect(excluded.contains(.inProgress))
    expect(excluded.contains(.completed))
    expect(excluded.contains(.skipped))
    expect(!excluded.contains(.new))
  }

  func testGeneratePuzzleFailsWhenNotUnique() async {
    let puzzleString = String(repeating: "0", count: 81)
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: puzzleString,
      solutionString: solution9,
      difficulty: .easy,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 2),
      rater: RaterStub(difficulty: .hard),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    do {
      _ = try await useCase.run(targetDifficulty: .hard)
      XCTFail("Expected non-unique error")
    } catch {
      expect(error as? SudokuCoreError == .nonUniqueSolution)
    }
  }

  func testGeneratePuzzleFailsWhenRatedDifficultyDoesNotMatchTarget() async {
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: puzzle9Easy,
      solutionString: solution9,
      difficulty: .easy,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 1),
      rater: RaterStub(difficulty: .medium),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    do {
      _ = try await useCase.run(targetDifficulty: .hard)
      XCTFail("Expected difficulty mismatch error")
    } catch {
      expect(error as? SudokuCoreError == .difficultyMismatch(expected: .hard, actual: .medium))
    }

    let stored = await repo.savedPuzzles()
    expect(stored.isEmpty)
  }

  func testGeneratePuzzleCanSaveOffTargetRatedPuzzle() async throws {
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: puzzle9Easy,
      solutionString: solution9,
      difficulty: .extreme,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 1),
      rater: RaterStub(difficulty: .hard),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    let result = try await useCase.runSavingRatedCandidate(targetDifficulty: .extreme)
    expect(!result.matchesTarget)
    expect(result.puzzle.difficulty == .hard)

    let stored = await repo.savedPuzzles()
    expect(stored.count == 1)
    expect(stored.first?.difficulty == .hard)
  }

  func testGeneratePuzzleFailsWhenSolutionIsInvalid() async {
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: puzzle9Easy,
      solutionString: String(repeating: "1", count: 81),
      difficulty: .easy,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 1),
      rater: RaterStub(difficulty: .easy),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    do {
      _ = try await useCase.run(targetDifficulty: .easy)
      XCTFail("Expected invalid solution error")
    } catch {
      expect(error as? SudokuCoreError == .invalidSolutionString)
    }
  }

  func testGeneratePuzzleFailsWhenSolutionDoesNotMatchPuzzle() async {
    let candidate = Puzzle(
      hash: "temp",
      puzzleString: replacingCharacter(in: puzzle9Easy, at: 1, with: "4"),
      solutionString: solution9,
      difficulty: .easy,
      source: .generated
    )

    let repo = RepositoryStub()
    let useCase = GeneratePuzzleUseCase(
      generator: GeneratorStub(output: candidate),
      solver: SolverStub(count: 1),
      rater: RaterStub(difficulty: .easy),
      hasher: HasherStub(hash: "canonical-hash"),
      repository: repo
    )

    do {
      _ = try await useCase.run(targetDifficulty: .easy)
      XCTFail("Expected solution mismatch error")
    } catch {
      expect(error as? SudokuCoreError == .solutionDoesNotMatchPuzzle)
    }
  }

  // MARK: - Test fixtures

  // Valid 9×9 solution (every row/col/box contains 1–9).
  private let solution9 =
    "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

  // Same solution with 5 cells zeroed — each is a naked single determined by its row.
  // Positions zeroed: 0(row0,col0=5), 10(row1,col1=7), 20(row2,col2=8), 30(row3,col3=7), 40(row4,col4=5).
  private let puzzle9Easy =
    "034678912602195348190342567859061423426803791713924856961537284287419635345286179"

  // Al Escargot — 21 clues, forces extreme rating (clues < 25 -> never hard/medium/easy).
  private let puzzle9Extreme =
    "800000000003600000070090200050007000000045700000100030001000068008500010090000400"
  private let solution9Extreme =
    "812753649943682175675491283154237896369845721287169534521974368438526917796318452"

  private func makePuzzle(difficulty: Difficulty, hash: String = UUID().uuidString) -> Puzzle {
    Puzzle(
      hash: hash,
      puzzleString: puzzle9Easy,
      solutionString: solution9,
      difficulty: difficulty,
      source: .generated,
      seed: 42
    )
  }

  private func replacingCharacter(in text: String, at offset: Int, with character: Character)
    -> String
  {
    var chars = Array(text)
    chars[offset] = character
    return String(chars)
  }

  private func addingGivens(to puzzle: String, from solution: String, at offsets: [Int]) -> String {
    var chars = Array(puzzle)
    let solutionChars = Array(solution)
    for offset in offsets {
      chars[offset] = solutionChars[offset]
    }
    return String(chars)
  }

  // MARK: - SudokuSolver

  func testSolverFindsUniqueSolution() throws {
    // 4×4: row 0 = 1,2,3,_ → last cell forced to 4 by all three constraints.
    let solver = SudokuSolver(gridSize: 4, boxSize: 2)
    let count = try solver.countSolutions(for: "1230341241232341", max: 2)
    expect(count == 1)
  }

  func testSolverFindsNoSolution() throws {
    // 4×4: position 6 (row1,col2) needs 1 from row+col but 4 from box → contradiction.
    let solver = SudokuSolver(gridSize: 4, boxSize: 2)
    let count = try solver.countSolutions(for: "1231340241232341", max: 2)
    expect(count == 0)
  }

  func testSolverRejectsFilledGridWithDuplicateGiven() throws {
    // Filled 4×4 board with two 1s in row 0. A full board is solved only if every unit is valid.
    let solver = SudokuSolver(gridSize: 4, boxSize: 2)
    let count = try solver.countSolutions(for: "1134341221434321", max: 2)
    expect(count == 0)
  }

  func testSolverDetectsMultipleSolutions() throws {
    // Only one given in a 4×4; many completions possible.
    let solver = SudokuSolver(gridSize: 4, boxSize: 2)
    let count = try solver.countSolutions(for: "1000000000000000", max: 2)
    expect(count == 2)
  }

  func testSolverRespectsStepLimit() throws {
    // stepLimit 0: first recursive call immediately returns maxSolutions.
    let solver = SudokuSolver(gridSize: 4, boxSize: 2, stepLimit: 0)
    let count = try solver.countSolutions(for: "1000000000000000", max: 2)
    expect(count == 2)
  }

  func testSolverThrowsOnInvalidLength() {
    let solver = SudokuSolver(gridSize: 4, boxSize: 2)
    expectThrows(SudokuCoreError.invalidPuzzleStringLength) {
      _ = try solver.countSolutions(for: "123", max: 2)
    }
  }

  func testSolverDefaultStepLimitIs120000For9x9() {
    let solver = SudokuSolver()
    expect(solver.stepLimit == 120_000)
  }

  func testSolverCustomStepLimitOverridesDefault() {
    let solver = SudokuSolver(stepLimit: 50_000)
    expect(solver.stepLimit == 50_000)
  }

  // MARK: - TechniqueRater

  func testRaterThrowsForNon9x9() {
    let rater = TechniqueRater(gridSize: 4, boxSize: 2)
    expectThrows(SudokuCoreError.unableToRateDifficulty) {
      _ = try rater.rate(puzzleString: "1230341241232341", solutionString: "1234341241232341")
    }
  }

  func testRaterThrowsForInvalidPuzzleLength() {
    let rater = TechniqueRater()
    expectThrows(SudokuCoreError.invalidPuzzleStringLength) {
      _ = try rater.rate(
        puzzleString: String(repeating: "0", count: 10),
        solutionString: solution9)
    }
  }

  func testRaterThrowsForInvalidSolutionLength() {
    let rater = TechniqueRater()
    expectThrows(SudokuCoreError.invalidSolutionStringLength) {
      _ = try rater.rate(
        puzzleString: puzzle9Easy,
        solutionString: String(repeating: "1", count: 10))
    }
  }

  func testRaterThrowsForInvalidSolutionGrid() {
    let rater = TechniqueRater()
    expectThrows(SudokuCoreError.invalidSolutionString) {
      _ = try rater.rate(
        puzzleString: puzzle9Easy,
        solutionString: String(repeating: "1", count: 81))
    }
  }

  func testRaterThrowsWhenSolutionDoesNotMatchPuzzle() {
    let rater = TechniqueRater()
    expectThrows(SudokuCoreError.solutionDoesNotMatchPuzzle) {
      _ = try rater.rate(
        puzzleString: replacingCharacter(in: puzzle9Easy, at: 1, with: "4"),
        solutionString: solution9)
    }
  }

  func testRaterRatesNearTrivialPuzzleAsEasy() throws {
    // puzzle9Easy has 76 clues; all 5 empty cells are naked singles → 0 guesses, 0 hidden singles.
    let rater = TechniqueRater()
    let difficulty = try rater.rate(puzzleString: puzzle9Easy, solutionString: solution9)
    expect(difficulty == .easy)
  }

  func testRaterRatesAlEscargotAsExtreme() throws {
    // 20 clues < 25 → always extreme regardless of guess count.
    let rater = TechniqueRater()
    let difficulty = try rater.rate(puzzleString: puzzle9Extreme, solutionString: solution9Extreme)
    expect(difficulty == .extreme)
  }

  func testRaterRatesSparseTwentyThreeCluePuzzleAsExtreme() throws {
    // Extreme generation commonly yields 21–23 clue puzzles; those should not be rejected as Hard.
    let sparsePuzzle = addingGivens(to: puzzle9Extreme, from: solution9Extreme, at: [1, 2])
    expect(sparsePuzzle.filter { $0 != "0" }.count == 23)

    let rater = TechniqueRater()
    let difficulty = try rater.rate(puzzleString: sparsePuzzle, solutionString: solution9Extreme)
    expect(difficulty == .extreme)
  }

  // MARK: - SudokuPuzzleGenerator

  func testGeneratorProducesUniquePuzzleForEasy() throws {
    let puzzle = try SudokuPuzzleGenerator().generate(targetDifficulty: .easy, seed: 42)
    let count = try SudokuSolver().countSolutions(for: puzzle.puzzleString, max: 2)
    expect(count == 1)
  }

  func testGeneratorSolutionIsValidGrid() throws {
    let puzzle = try SudokuPuzzleGenerator().generate(targetDifficulty: .easy, seed: 42)
    let sol = puzzle.solutionString
    expect(sol.count == 81)
    for row in 0..<9 {
      let digits = Set(sol.dropFirst(row * 9).prefix(9).compactMap(\.wholeNumberValue))
      expect(digits == Set(1...9))
    }
  }

  func testGeneratorIsDeterministicWithSameSeed() throws {
    let a = try SudokuPuzzleGenerator().generate(targetDifficulty: .hard, seed: 100)
    let b = try SudokuPuzzleGenerator().generate(targetDifficulty: .hard, seed: 100)
    expect(a.puzzleString == b.puzzleString)
    expect(a.solutionString == b.solutionString)
  }

  func testGeneratorPuzzleStringIsCorrectLength() throws {
    let puzzle = try SudokuPuzzleGenerator().generate(targetDifficulty: .medium, seed: 1)
    expect(puzzle.puzzleString.count == 81)
    expect(puzzle.solutionString.count == 81)
  }

  func testGeneratorPuzzleHasFewer81Clues() throws {
    // A puzzle with all 81 cells filled is a solved grid, not a puzzle.
    let puzzle = try SudokuPuzzleGenerator().generate(targetDifficulty: .easy, seed: 7)
    let clues = puzzle.puzzleString.filter { $0 != "0" }.count
    expect(clues < 81)
    expect(clues > 0)
  }

  // MARK: - SQLitePuzzleRepository

  func testRepositorySavesAndFetchesNewPuzzle() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — nextPuzzle not supported in InMemoryPuzzleRepository")
  }

  func testRepositoryExcludesCompletedFromNextPuzzle() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — markStatus/nextPuzzle not supported in InMemoryPuzzleRepository")
  }

  func testRepositoryFetchesInProgressPuzzle() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — markStatus/updateProgress/fetchInProgress not supported in InMemoryPuzzleRepository")
  }

  func testRepositoryFetchesMostRecentInProgressPuzzle() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — markStatus/fetchInProgress not supported in InMemoryPuzzleRepository")
  }

  func testRepositoryInventoryCountsReflectSaves() async throws {
    let repo = InMemoryPuzzleRepository()
    try await repo.save(makePuzzle(difficulty: .easy, hash: "e1"))
    try await repo.save(makePuzzle(difficulty: .easy, hash: "e2"))
    try await repo.save(makePuzzle(difficulty: .medium, hash: "m1"))

    let counts = try await repo.inventoryCounts()
    expect(counts[.easy] == 2)
    expect(counts[.medium] == 1)
    expect(counts[.hard] == 0)
    expect(counts[.extreme] == 0)
  }

  func testRepositoryClearLibraryRemovesAllPuzzles() async throws {
    let repo = InMemoryPuzzleRepository()
    try await repo.save(makePuzzle(difficulty: .easy))
    try await repo.save(makePuzzle(difficulty: .hard))
    try await repo.clearLibrary()

    let counts = try await repo.inventoryCounts()
    expect(counts.values.reduce(0, +) == 0)
  }

  func testRepositoryThrowsOnDuplicateHash() async throws {
    let repo = InMemoryPuzzleRepository()
    let puzzle = makePuzzle(difficulty: .easy)
    try await repo.save(puzzle)

    do {
      try await repo.save(puzzle)
      XCTFail("Expected hashAlreadyExists to be thrown")
    } catch {
      expect(error as? SudokuCoreError == .hashAlreadyExists)
    }
  }

  func testRepositoryRejectsDuplicateBeginnerPuzzle() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — saveBeginnerPuzzle/beginnerPuzzleCount are SQLite-only extensions not on PuzzleRepository protocol")
  }

  func testRepositoryRejectsInvalidBeginnerPuzzleLength() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — saveBeginnerPuzzle is a SQLite-only extension not on PuzzleRepository protocol")
  }

  func testRepositoryFiltersNextPuzzleByDifficulty() async throws {
    throw XCTSkip("Requires SQLitePuzzleRepository — nextPuzzle not supported in InMemoryPuzzleRepository")
  }
}
