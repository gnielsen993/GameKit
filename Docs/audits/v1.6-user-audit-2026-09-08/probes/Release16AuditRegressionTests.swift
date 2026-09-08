import Foundation
import Testing
import SudokuCore
@testable import gamekit

@Suite("Release 1.6 audit reproductions")
@MainActor
struct Release16AuditRegressionTests {
    @Test("Five Letter must not spend the last guess on a guaranteed non-answer")
    func fiveLetterLastGuess() throws {
        let guess = FiveLetterGuess(word: "BIGHT", marks: FiveLetterFeedback.evaluate(guess: "BIGHT", answer: "LIGHT"))
        let result = FiveLetterAssist.suggestion(
            after: Array(repeating: guess, count: 5),
            answers: ["LIGHT", "NIGHT"], acceptedGuesses: ["DIGHT", "LIGHT", "NIGHT"]
        )
        #expect(result.remainingCount == 2)
        withKnownIssue("Audit P1: the final-turn suggestion DIGHT cannot win and provides no distinction between LIGHT and NIGHT") {
            #expect(result.suggestedGuess == nil)
        }
    }

    @Test("FreeCell hint stays attached to the named card after it moves")
    func freeCellHintDoesNotRetargetAnotherCard() throws {
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.requestHint()
        let source = try #require(vm.activeHintSource)
        let namedCard = try #require(vm.activeHintCard)
        try #require(vm.activeHintDestination != .freeCell(1))
        try #require(vm.applyDragDrop(from: source, to: .freeCell(1)))
        try #require(vm.board.freeCells[1]?.id == namedCard.id)
        withKnownIssue("Audit P1: persistent hint points to the previous column after its named card moves") {
            #expect(vm.activeHint == nil || vm.activeHintSource == .freeCell(cellIdx: 1))
        }
    }

    @Test("Fill it in must place a value while Notes mode is selected")
    func sudokuHintInNotesMode() throws {
        let defaults = UserDefaults(suiteName: "Release16Audit.\(UUID())")!
        let vm = SudokuViewModel(difficulty: .easy, mode: .free, userDefaults: defaults)
        vm.injectTestBoardForUnitTests(puzzle: SudokuPuzzleEntry(
            id: "audit",
            givens: "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
            solution: "534678912672195348198342567859761423426853791713924856961537284287419635345286179",
            givenCount: 30
        ))
        vm.setInteractionMode(.note)
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        vm.applyHint()
        withKnownIssue("Audit P1: Fill it in creates a pencil note instead of placing the answer") {
            #expect(vm.board?.cell(row: hint.step.row, col: hint.step.column) == .user(hint.step.value))
        }
    }

    @Test("Nonogram help must not propagate an incorrect player fill")
    func nonogramWrongPremise() throws {
        let hints = [[1], [1], [5], [1], [1]]
        var board = NonogramBoard.empty(size: 5)
        for col in 0..<5 { board = board.setting(.filled, atRow: 2, col: col) }
        board = board.setting(.filled, atRow: 0, col: 0)
        let deduction = try #require(NonogramTalkthrough.nextDeduction(
            board: board, rowHints: hints, columnHints: hints
        ))
        withKnownIssue("Audit P1: wrong fill at r1c1 produces an instruction to X the correct r1c3") {
            for offset in deduction.newEmpty {
                let row: Int
                let col: Int
                switch deduction.line {
                case .row(let value): row = value; col = offset
                case .column(let value): row = offset; col = value
                }
                #expect(row != 2 && col != 2)
            }
        }
    }
}
