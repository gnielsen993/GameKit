import XCTest
@testable import MathCrosswordCore

final class PlacementValidationTests: XCTestCase {
    func testSwappedAddendsAreACompleteSolution() throws {
        let puzzle = try additionPuzzle()
        let equation = puzzle.equations[0]
        var session = try MathCrosswordSession(puzzle: puzzle)
        try session.place(3, at: equation.a)
        try session.place(1, at: equation.b)
        try session.place(4, at: equation.r)

        XCTAssertTrue(session.isComplete)
    }

    func testHintFollowsValidAlternativeInsteadOfStoredSolution() throws {
        let puzzle = try additionPuzzle()
        let equation = puzzle.equations[0]
        var session = try MathCrosswordSession(puzzle: puzzle)
        try session.place(3, at: equation.a)

        let hint = try XCTUnwrap(session.nextHint())
        XCTAssertEqual(hint.placements, [equation.b: 1, equation.r: 4])
        try session.applyNextHint()
        XCTAssertTrue(session.isComplete)
    }

    func testEmptyAndAlternativePartialBoardsStayNeutral() throws {
        let puzzle = try additionPuzzle()
        for placements: [GridPos: Int] in [[:], [puzzle.equations[0].a: 3]] {
            let validation = Solver.assessCompletion(puzzle: puzzle, placements: placements)
            XCTAssertEqual(validation.status, .solvable)
            XCTAssertTrue(validation.conflictingCells.isEmpty)
        }
    }

    func testImpossibleRemainingBankDoesNotRevealAnIncompleteEquation() throws {
        let puzzle = try additionPuzzle()
        let position = puzzle.equations[0].r
        let validation = Solver.validatePlacements(puzzle: puzzle, placements: [position: 1])
        XCTAssertTrue(validation.conflictingCells.isEmpty)
        XCTAssertFalse(validation.hasBrokenEquation)
        XCTAssertNil(Solver.nextHint(puzzle: puzzle, placements: [position: 1]))
    }

    func testIncorrectCompletedEquationHighlightsItsPlacedNumbers() throws {
        let puzzle = try additionPuzzle()
        let equation = puzzle.equations[0]
        var session = try MathCrosswordSession(puzzle: puzzle)
        try session.place(1, at: equation.a)
        try session.place(4, at: equation.b)
        try session.place(3, at: equation.r)
        let validation = Solver.assessCompletion(puzzle: puzzle, placements: session.placements)
        XCTAssertEqual(validation.status, .impossible)
        XCTAssertTrue(validation.hasBrokenEquation)
        XCTAssertEqual(validation.conflictingCells, Set(equation.numberCells))
        XCTAssertFalse(session.isComplete)
    }

    func testUnfilledCrossingDoesNotMarkAWorkingEquationWrong() throws {
        let first = try additionPuzzle().equations[0]
        let crossing = Equation(a: first.a, opCell: GridPos(row: 1, col: 0), b: GridPos(row: 2, col: 0),
                                eqCell: GridPos(row: 3, col: 0), r: GridPos(row: 4, col: 0), op: .add)
        let puzzle = try TallyPuzzle(seed: 2, difficulty: .easy, equations: [first, crossing],
                                    solution: [first.a: 1, first.b: 3, first.r: 4, crossing.b: 2, crossing.r: 3],
                                    givens: [first.r, crossing.r], bank: [1, 3, 2])
        let placements = [first.a: 3, first.b: 1]
        let validation = Solver.validatePlacements(puzzle: puzzle, placements: placements)
        XCTAssertTrue(validation.conflictingCells.isEmpty)
        XCTAssertFalse(validation.hasBrokenEquation)
        let broken = Solver.validatePlacements(puzzle: puzzle, placements: placements.merging([crossing.b: 2]) { _, new in new })
        XCTAssertTrue(broken.hasBrokenEquation)
        XCTAssertEqual(broken.conflictingCells, [first.a, crossing.b])

    }

    func testDuplicateTilesCannotBeInventedByValidation() throws {
        let equation = try additionPuzzle().equations[0]
        let puzzle = try TallyPuzzle(seed: 3, difficulty: .easy, equations: [equation],
                                    solution: [equation.a: 2, equation.b: 2, equation.r: 4], givens: [], bank: [2, 2, 4])
        XCTAssertEqual(Solver.assessCompletion(puzzle: puzzle, placements: [equation.a: 2, equation.b: 2]).status, .solvable)
        XCTAssertEqual(Solver.assessCompletion(puzzle: puzzle, placements: [equation.a: 4, equation.b: 4]).status, .impossible)
    }

    func testSearchBudgetExhaustionNeverMarksAValidAlternativeWrong() throws {
        let puzzle = try additionPuzzle()
        let validation = Solver.assessCompletion(puzzle: puzzle, placements: [puzzle.equations[0].a: 3], nodeLimit: 0)
        XCTAssertEqual(validation.status, .undetermined)
        XCTAssertTrue(validation.conflictingCells.isEmpty)
    }

    func testAlternateSolutionSurvivesSaveAndUndo() throws {
        let puzzle = try additionPuzzle()
        let equation = puzzle.equations[0]
        var session = try MathCrosswordSession(puzzle: puzzle)
        try session.place(3, at: equation.a)
        try session.place(1, at: equation.b)
        try session.place(4, at: equation.r)
        var restored = try JSONDecoder().decode(MathCrosswordSession.self, from: JSONEncoder().encode(session))
        XCTAssertTrue(restored.isComplete)
        try restored.undo()
        XCTAssertEqual(Solver.assessCompletion(puzzle: puzzle, placements: restored.placements).status, .solvable)
        XCTAssertEqual(restored.remainingBank, [4])
    }

    func testCommutativeAndOrderedOperationsUseArithmetic() throws {
        for (op, a, b, r, swappable) in [(Op.mul, 2, 3, 6, true), (.sub, 3, 1, 2, false), (.div, 6, 2, 3, false)] {
            let equation = Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1),
                                    b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: op)
            let puzzle = try TallyPuzzle(seed: 1, difficulty: .easy, equations: [equation],
                                        solution: [equation.a: a, equation.b: b, equation.r: r], givens: [], bank: [a, b, r])
            var session = try MathCrosswordSession(puzzle: puzzle)
            try session.place(b, at: equation.a)
            try session.place(a, at: equation.b)
            try session.place(r, at: equation.r)
            XCTAssertEqual(session.isComplete, swappable)
            XCTAssertEqual(Solver.assessCompletion(puzzle: puzzle, placements: session.placements).status, swappable ? .solvable : .impossible)
        }
    }

    private func additionPuzzle() throws -> TallyPuzzle {
        let equation = Equation(
            a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1),
            b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3),
            r: GridPos(row: 0, col: 4), op: .add
        )
        return try TallyPuzzle(seed: 1, difficulty: .easy, equations: [equation],
                              solution: [equation.a: 1, equation.b: 3, equation.r: 4],
                              givens: [], bank: [1, 3, 4])
    }
}
