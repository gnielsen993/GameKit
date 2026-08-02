import Testing
import Foundation
@testable import gamekit

/// View-model wiring for the talkthrough: when it counts as an assist, when
/// it does not, and that a request never mutates the board.
///
/// The rule that matters: a request producing nothing is not an assist. The
/// player asked and got no help, so charging them for it would be dishonest
/// in exactly the direction the milestone is trying to correct.
@Suite("Nonogram talkthrough wiring")
@MainActor
struct NonogramTalkthroughWiringTests {

    private func makeViewModel() -> NonogramViewModel {
        let suite = UserDefaults(suiteName: "NonogramTalkthroughWiring.\(UUID().uuidString)")!
        return NonogramViewModel(difficulty: .tiny, userDefaults: suite)
    }

    @Test("asking for a step produces an explanation and counts one assist")
    func requestProducesDeductionAndCounts() throws {
        let vm = makeViewModel()
        try #require(vm.currentPuzzle != nil)
        #expect(vm.assistsUsed == 0)

        vm.requestTalkthrough()

        #expect(vm.activeTalkthrough != nil)
        #expect(vm.assistsUsed == 1)
        #expect(vm.talkthroughUnavailable == nil)
    }

    @Test("a request never changes the board")
    func requestDoesNotMutateTheBoard() throws {
        let vm = makeViewModel()
        try #require(vm.currentPuzzle != nil)
        let before = vm.board
        vm.requestTalkthrough()
        #expect(vm.board == before)
    }

    @Test("every explanation is non-empty and names its line")
    func explanationsAreWritten() throws {
        let vm = makeViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        let deduction = try #require(vm.activeTalkthrough)

        let text = NonogramTalkthroughCopy.explanation(for: deduction)
        #expect(text.isEmpty == false)
        #expect(text.contains(NonogramTalkthroughCopy.lineName(deduction.line)))
    }

    @Test("all four techniques have copy")
    func everyTechniqueHasCopy() {
        let techniques: [NonogramTalkthrough.Technique] = [
            .overlap(clue: 8, lineLength: 10), .lineComplete, .allEmpty, .forced
        ]
        for technique in techniques {
            let deduction = NonogramTalkthrough.Deduction(
                line: .row(0), technique: technique, newFilled: [1, 2], newEmpty: []
            )
            #expect(NonogramTalkthroughCopy.explanation(for: deduction).isEmpty == false)
        }
    }

    @Test("both unavailable reasons have copy")
    func bothUnavailableReasonsHaveCopy() {
        #expect(NonogramTalkthroughCopy.unavailableMessage(.boardHasAMistake).isEmpty == false)
        #expect(NonogramTalkthroughCopy.unavailableMessage(.noLineDeduction).isEmpty == false)
    }

    @Test("dismissing clears the banner but keeps the count")
    func dismissKeepsTheCount() throws {
        let vm = makeViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        #expect(vm.assistsUsed == 1)

        vm.dismissTalkthrough()
        #expect(vm.activeTalkthrough == nil)
        // The help was given; dismissing the sentence does not un-give it.
        #expect(vm.assistsUsed == 1)
    }

    @Test("a solved board offers nothing and charges nothing")
    func solvedBoardChargesNothing() throws {
        let vm = makeViewModel()
        let puzzle = try #require(vm.currentPuzzle)

        // Fill in the whole solution, so no deduction remains.
        for row in 0..<vm.board.size {
            for col in 0..<vm.board.size {
                let index = row * vm.board.size + col
                let isFilled = Array(puzzle.grid)[index] == "1"
                vm.setCell(at: row, col: col, to: isFilled ? .filled : .marked)
            }
        }

        let countBefore = vm.assistsUsed
        vm.requestTalkthrough()
        #expect(vm.activeTalkthrough == nil)
        // Nothing was given, so nothing is charged.
        #expect(vm.assistsUsed == countBefore)
    }

    @Test("the explanation does not outlive the board it describes")
    func explanationClearsOnMutation() throws {
        let vm = makeViewModel()
        try #require(vm.currentPuzzle != nil)
        vm.requestTalkthrough()
        #expect(vm.activeTalkthrough != nil)

        vm.handleTap(at: 0, col: 0)
        #expect(vm.activeTalkthrough == nil)
    }

    @Test("assist count survives a save and restore")
    func assistCountPersists() throws {
        let vm = makeViewModel()
        let puzzle = try #require(vm.currentPuzzle)
        vm.handleTap(at: 0, col: 0)      // enter .playing so the save writes
        vm.requestTalkthrough()
        let used = vm.assistsUsed
        #expect(used >= 1)

        let saved = NonogramSaveState(
            puzzleId: puzzle.id,
            puzzleGrid: puzzle.grid,
            puzzleTitle: puzzle.title,
            cells: vm.board.cells,
            size: vm.board.size,
            difficulty: vm.difficulty.rawValue,
            gameMode: vm.gameMode.rawValue,
            livesRemaining: vm.livesRemaining,
            lockedCellIndices: [],
            elapsedSeconds: 10,
            savedAt: Date(timeIntervalSince1970: 0),
            assistsUsed: used
        )
        let restored = makeViewModel()
        restored.restoreState(saved)
        #expect(restored.assistsUsed == used)
    }

    @Test("a save predating assists restores as unaided")
    func legacySaveRestoresUnaided() throws {
        let vm = makeViewModel()
        let puzzle = try #require(vm.currentPuzzle)
        let legacy = NonogramSaveState(
            puzzleId: puzzle.id,
            puzzleGrid: puzzle.grid,
            puzzleTitle: puzzle.title,
            cells: vm.board.cells,
            size: vm.board.size,
            difficulty: vm.difficulty.rawValue,
            gameMode: vm.gameMode.rawValue,
            livesRemaining: vm.livesRemaining,
            lockedCellIndices: [],
            elapsedSeconds: 10,
            savedAt: Date(timeIntervalSince1970: 0)
        )
        let restored = makeViewModel()
        restored.restoreState(legacy)
        #expect(restored.assistsUsed == 0)
    }
}
