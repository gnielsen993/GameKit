import XCTest
@testable import MathCrosswordCore

final class MathCrosswordCoreTests: XCTestCase {
    func testGenerationIsDeterministicForCapturedSeed() throws {
        let seed = try workingSeed(for: .easy)
        let first = try PuzzleFactory.generate(difficulty: .easy, seed: seed)
        let second = try PuzzleFactory.generate(difficulty: .easy, seed: seed)

        XCTAssertEqual(first.seed, second.seed)
        XCTAssertEqual(first.equations, second.equations)
        XCTAssertEqual(first.solution, second.solution)
        XCTAssertEqual(first.givens, second.givens)
        XCTAssertEqual(first.bank, second.bank)
    }

    func testGeneratedEquationsHoldAndHaveUniqueSolution() throws {
        for difficulty in TallyDifficulty.allCases {
            let puzzle = try generatedPuzzle(for: difficulty)
            XCTAssertTrue(puzzle.equations.allSatisfy { equation in
                equation.holds(puzzle.solution[equation.a]!, puzzle.solution[equation.b]!, puzzle.solution[equation.r]!)
            })
            XCTAssertEqual(Solver.countSolutions(puzzle: puzzle, cap: 2), 1)
        }
    }

    func testGenerationReturnsWithinBoundedAttemptBudget() {
        let result = Result { try PuzzleFactory.generate(difficulty: .hard, seed: 1, maximumAttempts: 1) }
        switch result {
        case .success(let puzzle): XCTAssertEqual(puzzle.seed, 1)
        case .failure(let error as PuzzleFactory.GenerationError):
            XCTAssertEqual(error, .attemptBudgetExhausted(difficulty: .hard, seed: 1, attempts: 1))
        case .failure(let error): XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancelledGenerationDoesNotProducePuzzle() async {
        let task = Task { () -> Result<TallyPuzzle, Error> in
            Result { try PuzzleFactory.generate(difficulty: .hard, seed: 9_999_991, maximumAttempts: 8) }
        }
        task.cancel()
        let result = await task.value
        switch result {
        case .success: XCTFail("Cancelled generation must not return a puzzle")
        case .failure(let error as PuzzleFactory.GenerationError): XCTAssertEqual(error, .cancelled)
        case .failure(let error): XCTFail("Unexpected error: \(error)")
        }
    }

    func testHintOnlyUsesTrustedBoardPremises() throws {
        let puzzle = try generatedPuzzle(for: .easy)
        guard let position = puzzle.blanks.first,
              let incorrect = puzzle.bank.first(where: { $0 != puzzle.solution[position] }) else {
            throw XCTSkip("Fixture has no alternative bank value")
        }

        XCTAssertNil(Solver.nextHint(puzzle: puzzle, placements: [position: incorrect]))
        XCTAssertNotNil(Solver.nextHint(puzzle: puzzle, placements: [:]))
    }

    func testSessionConsumesDuplicateBankValuesAndUndoesSafely() throws {
        let puzzle = try duplicateBankPuzzle()
        var session = try MathCrosswordSession(puzzle: puzzle)
        let blanks = puzzle.blanks

        try session.place(1, at: blanks[0])
        try session.place(1, at: blanks[1])
        XCTAssertTrue(session.remainingBank.isEmpty)
        XCTAssertTrue(session.isComplete)
        XCTAssertThrowsError(try session.place(1, at: GridPos(row: 99, col: 99)))

        try session.undo()
        XCTAssertEqual(session.remainingBank, [1])
        XCTAssertFalse(session.isComplete)
    }

    func testEraseUndoRestoresTheErasedTile() throws {
        let puzzle = try duplicateBankPuzzle()
        var session = try MathCrosswordSession(puzzle: puzzle)
        let blank = puzzle.blanks[0]

        try session.place(1, at: blank)
        try session.erase(at: blank)
        XCTAssertNil(session.placements[blank])

        try session.undo()
        XCTAssertEqual(session.placements[blank], 1)
        XCTAssertEqual(session.remainingBank, [1])
    }

    func testReplaceUndoRestoresThePreviousTile() throws {
        let puzzle = try replaceablePuzzle()
        var session = try MathCrosswordSession(puzzle: puzzle)
        let blank = puzzle.blanks[0]

        try session.place(1, at: blank)
        try session.replace(2, at: blank)
        XCTAssertEqual(session.placements[blank], 2)

        try session.undo()
        XCTAssertEqual(session.placements[blank], 1)
        XCTAssertEqual(session.history.last?.kind, .place)
    }

    func testRejectedReplacementDoesNotPartiallyMutateSession() throws {
        let puzzle = try replaceablePuzzle()
        var session = try MathCrosswordSession(puzzle: puzzle)
        let blank = puzzle.blanks[0]
        try session.place(1, at: blank)
        let stateBeforeFailure = session

        XCTAssertThrowsError(try session.replace(99, at: blank)) { error in
            XCTAssertEqual(error as? MathCrosswordSessionError, .unavailableTile(99))
        }
        XCTAssertEqual(session.placements, stateBeforeFailure.placements)
        XCTAssertEqual(session.history, stateBeforeFailure.history)
    }

    func testSessionRestoreRejectsHistoryThatDoesNotMatchPlacements() throws {
        let puzzle = try duplicateBankPuzzle()
        let blank = puzzle.blanks[0]
        let invalid = InvalidSession(puzzle: puzzle, placements: [blank: 1], history: [])
        let data = try JSONEncoder().encode(invalid)

        XCTAssertThrowsError(try JSONDecoder().decode(MathCrosswordSession.self, from: data)) { error in
            XCTAssertEqual(error as? MathCrosswordSessionError, .invalidHistory)
        }
    }

    func testPuzzleValidationRejectsEmptyAndInvalidBank() {
        XCTAssertThrowsError(try TallyPuzzle(seed: 1, difficulty: .easy, equations: [], solution: [:], givens: [], bank: [])) { error in
            XCTAssertEqual(error as? MathCrosswordValidationError, .emptyPuzzle)
        }
        XCTAssertThrowsError(try TallyPuzzle(seed: 1, difficulty: .easy, equations: [simpleEquation], solution: simpleSolution, givens: [simpleEquation.a, simpleEquation.b], bank: [4])) { error in
            XCTAssertEqual(error as? MathCrosswordValidationError, .invalidBank)
        }
    }

    func testPuzzleValidationRejectsDuplicateCellsAndOverflowingArithmetic() {
        let duplicated = Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1), b: GridPos(row: 0, col: 0), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: .add)
        XCTAssertThrowsError(try TallyPuzzle(seed: 1, difficulty: .easy, equations: [duplicated], solution: [duplicated.a: 1, duplicated.r: 2], givens: [], bank: [1, 2])) { error in
            XCTAssertEqual(error as? MathCrosswordValidationError, .duplicateEquationCell(duplicated.a))
        }
        XCTAssertNil(Op.add.apply(Int.max, 1))
        XCTAssertNil(Op.sub.apply(Int.min, 1))
        XCTAssertNil(Op.mul.apply(Int.max, 2))
        XCTAssertNil(Op.div.apply(Int.min, -1))
    }

    func testPuzzleValidationRejectsUnboundedRestoreCoordinates() {
        let farAway = Equation(a: GridPos(row: TallyPuzzle.maximumGridDimension, col: 0), opCell: GridPos(row: TallyPuzzle.maximumGridDimension, col: 1), b: GridPos(row: TallyPuzzle.maximumGridDimension, col: 2), eqCell: GridPos(row: TallyPuzzle.maximumGridDimension, col: 3), r: GridPos(row: TallyPuzzle.maximumGridDimension, col: 4), op: .add)
        XCTAssertThrowsError(try TallyPuzzle(seed: 1, difficulty: .easy, equations: [farAway], solution: [farAway.a: 1, farAway.b: 1, farAway.r: 2], givens: [], bank: [1, 1, 2])) { error in
            guard case .invalidCoordinate = error as? MathCrosswordValidationError else {
                return XCTFail("Expected invalid coordinate, got \(error)")
            }
        }
    }
}

private extension MathCrosswordCoreTests {
    func workingSeed(for difficulty: TallyDifficulty) throws -> UInt64 {
        for seed in 1...200 where (try? PuzzleFactory.generate(difficulty: difficulty, seed: UInt64(seed))) != nil {
            return UInt64(seed)
        }
        XCTFail("No generated fixture in seed range")
        return 1
    }

    func generatedPuzzle(for difficulty: TallyDifficulty) throws -> TallyPuzzle {
        try PuzzleFactory.generate(difficulty: difficulty, seed: try workingSeed(for: difficulty))
    }

    var simpleEquation: Equation {
        Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1), b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: .add)
    }

    var simpleSolution: [GridPos: Int] {
        [simpleEquation.a: 2, simpleEquation.b: 3, simpleEquation.r: 5]
    }

    func duplicateBankPuzzle() throws -> TallyPuzzle {
        let first = Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1), b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: .mul)
        let second = Equation(a: GridPos(row: 2, col: 0), opCell: GridPos(row: 2, col: 1), b: GridPos(row: 2, col: 2), eqCell: GridPos(row: 2, col: 3), r: GridPos(row: 2, col: 4), op: .mul)
        return try TallyPuzzle(
            seed: 1,
            difficulty: .easy,
            equations: [first, second],
            solution: [first.a: 1, first.b: 1, first.r: 1, second.a: 1, second.b: 1, second.r: 1],
            givens: [first.a, first.b, second.a, second.b],
            bank: [1, 1]
        )
    }

    func replaceablePuzzle() throws -> TallyPuzzle {
        let equation = Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1), b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: .add)
        return try TallyPuzzle(
            seed: 2,
            difficulty: .easy,
            equations: [equation],
            solution: [equation.a: 1, equation.b: 1, equation.r: 2],
            givens: [equation.a],
            bank: [1, 2]
        )
    }
}

private struct InvalidSession: Encodable {
    let puzzle: TallyPuzzle
    let placements: [GridPos: Int]
    let history: [MathCrosswordMove]
}
