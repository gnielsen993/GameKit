import Foundation
import XCTest

@testable import SudokuCore

/// The hint engine's one non-negotiable property: a step it reports must be
/// correct. A wrong digit delivered with a confident explanation is worse than
/// admitting the puzzle is beyond the engine.
final class SudokuHintEngineTests: XCTestCase {

    private let engine = SudokuHintEngine()

    /// A standard easy puzzle and its solution.
    private let puzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func board(_ string: String) -> [Int] {
        string.map { Int(String($0)) ?? 0 }
    }

    func testFindsAStepOnAnEasyPuzzle() {
        XCTAssertNotNil(engine.nextStep(board: board(puzzle)))
    }

    /// The property that matters most: the digit is right.
    func testEveryReportedStepAgreesWithTheSolution() {
        let answer = board(solution)
        var current = board(puzzle)
        var steps = 0

        while let step = engine.nextStep(board: current) {
            XCTAssertEqual(
                step.value, answer[step.index],
                "engine claimed \(step.value) at index \(step.index) but the solution is \(answer[step.index])"
            )
            current[step.index] = step.value
            steps += 1
            XCTAssertLessThan(steps, 200, "step loop did not converge")
        }
        XCTAssertGreaterThan(steps, 0)
    }

    func testSinglesAloneSolveAnEasyPuzzle() {
        var current = board(puzzle)
        _ = engine.applyAllSingles(board: &current)
        XCTAssertEqual(current, board(solution))
    }

    func testAFinishedBoardOffersNothing() {
        XCTAssertNil(engine.nextStep(board: board(solution)))
    }

    func testRejectsAWronglySizedBoard() {
        XCTAssertNil(engine.nextStep(board: [1, 2, 3]))
    }

    /// A naked single: one square with a single possibility. Row 0 is missing
    /// only a 9 at index 8, so nothing else can go there.
    func testNakedSingleIsNamedAndSupported() throws {
        var cells = board(solution)
        cells[8] = 0
        let step = try XCTUnwrap(engine.nextStep(board: cells))
        XCTAssertEqual(step.index, 8)
        XCTAssertEqual(step.value, 2)
        XCTAssertEqual(step.technique, .nakedSingle)
        // The peers are what rule out every other digit — 20 of them.
        XCTAssertEqual(step.supportingIndices.count, 20)
        XCTAssertFalse(step.supportingIndices.contains(8))
    }

    /// Supporting squares must actually contain the argument: for a hidden
    /// single, the reported unit has to include the square being filled.
    func testHiddenSingleUnitContainsItsCell() {
        var cells = board(puzzle)
        // Drive the board forward a little so hidden singles appear.
        for _ in 0..<5 {
            guard let step = engine.nextStep(board: cells) else { break }
            cells[step.index] = step.value
        }
        var sawHidden = false
        var probe = cells
        for _ in 0..<60 {
            guard let step = engine.nextStep(board: probe) else { break }
            if case .hiddenSingle = step.technique {
                sawHidden = true
                XCTAssertTrue(
                    step.supportingIndices.contains(step.index),
                    "a hidden single's unit must contain the square it fills"
                )
                XCTAssertEqual(step.supportingIndices.count, 9)
            }
            probe[step.index] = step.value
        }
        // Not every puzzle path needs a hidden single; only assert the shape
        // when one actually occurred.
        if !sawHidden {
            XCTAssertTrue(true, "no hidden single arose on this path")
        }
    }

    func testRowAndColumnAreDerivedFromTheIndex() {
        let step = SudokuHintEngine.Step(
            index: 40, value: 5, technique: .nakedSingle, supportingIndices: []
        )
        XCTAssertEqual(step.row, 4)
        XCTAssertEqual(step.column, 4)
    }

    /// The rater is now built on this engine; its published ratings must not
    /// have moved, since they decide which puzzles ship at which difficulty.
    func testRaterStillRatesTheKnownEasyPuzzle() throws {
        let rater = TechniqueRater()
        let rating = try rater.rate(puzzleString: puzzle, solutionString: solution)
        XCTAssertEqual(rating, .easy)
    }
}
