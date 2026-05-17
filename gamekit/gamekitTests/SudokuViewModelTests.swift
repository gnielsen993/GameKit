//
//  SudokuViewModelTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

@MainActor
final class SudokuViewModelTests: XCTestCase {

    // Reusable test puzzle.
    private let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func makeVM(mode: SudokuGameMode = .free) -> SudokuViewModel {
        let defaults = UserDefaults(suiteName: "SudokuViewModelTests.\(UUID().uuidString)")!
        defaults.set(SudokuDifficulty.easy.rawValue, forKey: SudokuViewModel.lastDifficultyKey)
        defaults.set(mode.rawValue, forKey: SudokuViewModel.lastGameModeKey)
        let vm = SudokuViewModel(
            difficulty: .easy,
            userDefaults: defaults
        )
        // Force a board to be present immediately, bypassing async load:
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "test-uuid",
                givens: testGivens,
                solution: testSolution,
                givenCount: 30
            )
        )
        return vm
    }

    func testFreeMode_commitsValueAndChecksWin() async {
        let vm = makeVM(mode: .free)
        XCTAssertEqual(vm.state, .idle)

        vm.select(row: 0, col: 2)   // empty cell, solution = 4
        vm.place(value: 4)

        XCTAssertEqual(vm.state, .playing)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))
        XCTAssertEqual(vm.placeCount, 1)
    }

    func testFreeMode_wrongValueCommitsButDoesNotIncrementMistakes() async {
        let vm = makeVM(mode: .free)
        vm.select(row: 0, col: 2)   // solution = 4
        vm.place(value: 9)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(9))
        XCTAssertEqual(vm.mistakes, 0)
    }

    func testLivesMode_wrongValueIncrementsMistakes_andDoesNotCommit() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)
        XCTAssertEqual(vm.mistakes, 1)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: []))
        XCTAssertEqual(vm.wrongAttemptCount, 1)
    }

    func testLivesMode_threeMistakesLeadToGameOver() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)
        vm.place(value: 1)
        vm.place(value: 2)
        XCTAssertEqual(vm.mistakes, 3)
        XCTAssertEqual(vm.state, .gameOver)
    }

    func testLivesMode_correctValueLocksCell() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 4)   // correct (solution = 4)
        XCTAssertTrue(vm.lockedCells.contains(0 * 9 + 2))
        // Erase should no-op on a locked correct cell.
        vm.erase()
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))
    }

    func testGivensAreImmutable() async {
        let vm = makeVM()
        vm.select(row: 0, col: 0)   // .given(5)
        vm.place(value: 7)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 0), .given(5))
    }

    func testNoteMode_togglesNotes() async {
        let vm = makeVM()
        vm.setInteractionMode(.note)
        vm.select(row: 0, col: 2)
        vm.place(value: 3)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [3]))
        vm.place(value: 5)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [3, 5]))
        vm.place(value: 3)   // toggle off
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: [5]))
    }

    func testCommitClearsPeerNotes() async {
        let vm = makeVM()
        // Test puzzle solution row 0 = "534678912" → (0,2) = 4.
        // Strategy: seed digit 4 in another row-0 cell's notes, then commit
        // 4 to (0, 2). The peer note must clear automatically.
        vm.setInteractionMode(.note)
        vm.select(row: 0, col: 5)        // empty cell in same row
        vm.place(value: 4)               // toggle 4 into notes → {4}
        XCTAssertEqual(vm.board?.cell(row: 0, col: 5), .empty(notes: [4]))

        vm.setInteractionMode(.value)
        vm.select(row: 0, col: 2)        // empty cell, solution = 4
        vm.place(value: 4)               // commits user(4)
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .user(4))

        // Peer note at (0, 5) must have been auto-cleared.
        XCTAssertEqual(vm.board?.cell(row: 0, col: 5), .empty(notes: []))
    }

    func testUndo_restoresPreviousCellAndMistakes() async {
        let vm = makeVM(mode: .lives)
        vm.select(row: 0, col: 2)
        vm.place(value: 9)   // wrong, mistakes -> 1, NOT committed
        XCTAssertEqual(vm.mistakes, 1)
        // .lives wrong attempts don't capture an undo snapshot in this
        // implementation — they don't mutate the cell. Confirm:
        XCTAssertNil(vm.undoSnapshot)

        // Now commit a correct value, which should capture undo.
        vm.place(value: 4)
        XCTAssertNotNil(vm.undoSnapshot)
        vm.undo()
        XCTAssertEqual(vm.board?.cell(row: 0, col: 2), .empty(notes: []))
    }

    func testRestart_resetsStateButKeepsPuzzle() async {
        let vm = makeVM()
        let originalID = vm.currentPuzzle?.id
        vm.select(row: 0, col: 2)
        vm.place(value: 4)
        vm.restart()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.currentPuzzle?.id, originalID)
        XCTAssertEqual(vm.placeCount, 0)
    }
}

// Note: injectTestBoardForUnitTests is defined in SudokuViewModel.swift
// under #if DEBUG — accessible here via @testable import.
