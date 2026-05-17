//
//  SudokuBoardTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

@MainActor
final class SudokuBoardTests: XCTestCase {

    // Standard test puzzle: a valid easy Sudoku with known solution.
    private let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    func testInit_rejectsMalformedGivens() {
        XCTAssertNil(SudokuBoard(givens: "tooshort", solution: testSolution))
        XCTAssertNil(SudokuBoard(givens: testGivens, solution: "tooshort"))
        XCTAssertNil(SudokuBoard(givens: String(repeating: "x", count: 81), solution: testSolution))
        XCTAssertNil(SudokuBoard(givens: testGivens, solution: String(repeating: "0", count: 81)))
    }

    func testInit_parsesGivensCorrectly() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertEqual(board.cell(row: 0, col: 0), .given(5))
        XCTAssertEqual(board.cell(row: 0, col: 1), .given(3))
        XCTAssertEqual(board.cell(row: 0, col: 2), .empty(notes: []))
        XCTAssertEqual(board.cell(row: 0, col: 4), .given(7))
        XCTAssertEqual(board.cell(row: 8, col: 8), .given(9))
    }

    func testSolutionDigit_matchesString() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertEqual(board.solutionDigit(atRow: 0, col: 0), 5)
        XCTAssertEqual(board.solutionDigit(atRow: 0, col: 2), 4)
        XCTAssertEqual(board.solutionDigit(atRow: 8, col: 8), 9)
    }

    func testSetting_returnsBoardWithCellChanged() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        let mutated = board.setting(.user(7), atRow: 0, col: 2)
        XCTAssertEqual(mutated.cell(row: 0, col: 2), .user(7))
        XCTAssertEqual(board.cell(row: 0, col: 2), .empty(notes: []))   // original unchanged
    }

    func testIsSolved_falseUntilAllCellsCorrect() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertFalse(board.isSolved)

        // Fill every empty cell with the solution digit; should now be solved.
        var b = board
        for r in 0..<9 {
            for c in 0..<9 {
                if case .empty = b.cell(row: r, col: c) {
                    b = b.setting(.user(b.solutionDigit(atRow: r, col: c)), atRow: r, col: c)
                }
            }
        }
        XCTAssertTrue(b.isSolved)
    }

    func testPeerIndices_excludesSelf_and_returns20Peers() {
        let peers = SudokuBoard.peerIndices(row: 4, col: 4)
        XCTAssertFalse(peers.contains(4 * 9 + 4))
        XCTAssertEqual(peers.count, 20)
        XCTAssertTrue(peers.contains(4 * 9 + 0))   // same row
        XCTAssertTrue(peers.contains(0 * 9 + 4))   // same col
        XCTAssertTrue(peers.contains(3 * 9 + 3))   // same 3×3 box
        XCTAssertFalse(peers.contains(0 * 9 + 0))  // unrelated
    }

    func testClearingPeerNotes_removesValueFromRowColBox() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        // Seed notes into 3 empty cells: same row, same col, same box.
        var b = board
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 0, col: 2)   // same row as (0,0)
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 5, col: 0)   // same col as (0,0)
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 1, col: 2)   // same box as (0,0)
        // Also one unrelated cell — should NOT lose its 7.
        b = b.setting(.empty(notes: [3, 5, 7]), atRow: 5, col: 5)   // unrelated

        let cleared = b.clearingPeerNotes(of: 7, fromRow: 0, col: 0)
        XCTAssertEqual(cleared.cell(row: 0, col: 2).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 5, col: 0).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 1, col: 2).notes, [3, 5])
        XCTAssertEqual(cleared.cell(row: 5, col: 5).notes, [3, 5, 7])    // unrelated, untouched
    }

    func testGivenCells_areMarkedIsGiven() throws {
        let board = try XCTUnwrap(SudokuBoard(givens: testGivens, solution: testSolution))
        XCTAssertTrue(board.cell(row: 0, col: 0).isGiven)
        XCTAssertFalse(board.cell(row: 0, col: 2).isGiven)
        XCTAssertFalse(board.cell(row: 0, col: 2).isPlayerEditable == false)
    }
}
