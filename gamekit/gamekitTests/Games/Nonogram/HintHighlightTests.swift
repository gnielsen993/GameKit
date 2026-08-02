import Testing
import Foundation
import SudokuCore
@testable import gamekit

/// The hints described squares the player could not see. The copy said
/// "these squares" while nothing on screen showed which, so the sentence had
/// no referent and the advice was unfollowable.
///
/// These pin the connection between what the sentence claims and what the
/// board highlights.
@Suite("Hint highlighting")
@MainActor
struct HintHighlightTests {

    // MARK: - Nonogram

    private func nonogramViewModel() -> NonogramViewModel {
        let suite = UserDefaults(suiteName: "HintHighlight.\(UUID().uuidString)")!
        return NonogramViewModel(difficulty: .tiny, userDefaults: suite)
    }

    @Test("no hint means no highlight")
    func nonogramNoHintNoHighlight() {
        let vm = nonogramViewModel()
        #expect(vm.talkthroughHighlight.isEmpty)
        #expect(vm.talkthroughRow == nil)
        #expect(vm.talkthroughColumn == nil)
    }

    @Test("the highlighted squares are exactly the ones the hint names")
    func nonogramHighlightMatchesDeduction() throws {
        let vm = nonogramViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        let deduction = try #require(vm.activeTalkthrough)

        #expect(vm.talkthroughHighlight.count == deduction.newCellCount)

        let size = vm.board.size
        for offset in deduction.newFilled + deduction.newEmpty {
            let index: Int
            switch deduction.line {
            case .row(let r):    index = r * size + offset
            case .column(let c): index = offset * size + c
            }
            #expect(vm.talkthroughHighlight.contains(index))
        }
    }

    @Test("exactly one of row or column is flagged, matching the hint")
    func nonogramLineFlagMatches() throws {
        let vm = nonogramViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        let deduction = try #require(vm.activeTalkthrough)

        switch deduction.line {
        case .row(let r):
            #expect(vm.talkthroughRow == r)
            #expect(vm.talkthroughColumn == nil)
        case .column(let c):
            #expect(vm.talkthroughColumn == c)
            #expect(vm.talkthroughRow == nil)
        }
    }

    @Test("dismissing clears the highlight")
    func nonogramDismissClearsHighlight() throws {
        let vm = nonogramViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        #expect(vm.talkthroughHighlight.isEmpty == false)
        vm.dismissTalkthrough()
        #expect(vm.talkthroughHighlight.isEmpty)
    }

    @Test("the sentence names a concrete span, not \"these\"")
    func nonogramCopyNamesTheSquares() throws {
        let vm = nonogramViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        let deduction = try #require(vm.activeTalkthrough)
        let text = NonogramTalkthroughCopy.explanation(for: deduction)
        // Either "square N" or "squares N to M" must appear, so the player
        // can find them without decoding "these".
        #expect(text.contains("square"))
        #expect(text.contains("these") == false)
    }

    // MARK: - Sudoku

    private static let givens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func sudokuViewModel() -> SudokuViewModel {
        let suite = UserDefaults(suiteName: "HintHighlightSudoku.\(UUID().uuidString)")!
        let vm = SudokuViewModel(difficulty: .easy, mode: .free, userDefaults: suite)
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "highlight-fixture",
                givens: Self.givens,
                solution: Self.solution,
                givenCount: 30
            )
        )
        return vm
    }

    @Test("no hint means no ring and no shading")
    func sudokuNoHintNoHighlight() {
        let vm = sudokuViewModel()
        #expect(vm.hintTargetIndex == nil)
        #expect(vm.hintSupportingIndices.isEmpty)
    }

    @Test("the ringed square is the one the hint names")
    func sudokuRingMatchesStep() throws {
        let vm = sudokuViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        #expect(vm.hintTargetIndex == hint.step.index)
    }

    @Test("the shaded squares include the one being explained")
    func sudokuSupportIncludesTarget() throws {
        let vm = sudokuViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        // For either technique the shading must pass through the square, or
        // the sentence points nowhere.
        #expect(vm.hintSupportingIndices.contains(hint.step.index))
        #expect(vm.hintSupportingIndices.count >= 9)
    }

    @Test("dismissing clears the ring and the shading")
    func sudokuDismissClears() {
        let vm = sudokuViewModel()
        vm.requestHint()
        vm.dismissHint()
        #expect(vm.hintTargetIndex == nil)
        #expect(vm.hintSupportingIndices.isEmpty)
    }

    @Test("the sentence refers to what is drawn")
    func sudokuCopyReferencesTheHighlight() throws {
        let vm = sudokuViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        let text = SudokuHintCopy.explanation(for: hint.step)
        #expect(text.contains("ringed"))
    }
}
