import Testing
import Foundation
import SudokuCore
@testable import gamekit

/// App-side wiring for the Sudoku hint: what counts as an assist, the
/// graduated stages, and the refusal to reason from a board the player has
/// already broken.
@Suite("Sudoku hint")
@MainActor
struct SudokuHintTests {

    private static let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private static let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func makeViewModel(mode: SudokuGameMode = .free) -> SudokuViewModel {
        let suite = UserDefaults(suiteName: "SudokuHintTests.\(UUID().uuidString)")!
        let vm = SudokuViewModel(difficulty: .easy, mode: mode, userDefaults: suite)
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "hint-fixture",
                givens: Self.testGivens,
                solution: Self.testSolution,
                givenCount: 30
            )
        )
        return vm
    }

    @Test("asking produces a step and charges one assist")
    func requestProducesStep() {
        let vm = makeViewModel()
        #expect(vm.assistsUsed == 0)
        vm.requestHint()
        #expect(vm.activeHint != nil)
        #expect(vm.assistsUsed == 1)
    }

    @Test("the first ask explains without giving the answer")
    func firstAskExplainsOnly() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        #expect(hint.stage == .explanation)

        let text = SudokuHintCopy.explanation(for: hint.step)
        #expect(text.isEmpty == false)
        // The explanation must not contain the digit — that is the reveal's job.
        #expect(text.contains("is \(hint.step.value).") == false)
    }

    @Test("asking again reveals, and does not charge twice")
    func secondAskRevealsWithoutRecharging() throws {
        let vm = makeViewModel()
        vm.requestHint()
        #expect(vm.assistsUsed == 1)

        vm.requestHint()
        let hint = try #require(vm.activeHint)
        #expect(hint.stage == .reveal)
        // Escalating the same hint is the same help, not a second one.
        #expect(vm.assistsUsed == 1)
    }

    @Test("the hinted digit is the correct one")
    func hintedDigitIsCorrect() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        let solution = Array(Self.testSolution)
        let expected = Int(String(solution[hint.step.index]))
        #expect(hint.step.value == expected)
    }

    @Test("filling it in places that digit and clears the banner")
    func applyPlacesTheDigit() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        vm.applyHint()

        let placed = try #require(vm.board).cell(row: hint.step.row, col: hint.step.column)
        #expect(placed == .user(hint.step.value))
        #expect(vm.activeHint == nil)
    }

    @Test("a request never changes the board on its own")
    func requestDoesNotMutate() throws {
        let vm = makeViewModel()
        let before = try #require(vm.board)
        vm.requestHint()
        #expect(vm.board?.cells == before.cells)
    }

    @Test("a wrong digit on the board blocks the hint rather than reasoning from it")
    func mistakeBlocksTheHint() throws {
        let vm = makeViewModel(mode: .free)
        // Place a digit that disagrees with the solution.
        let board = try #require(vm.board)
        var target: (row: Int, col: Int)?
        outer: for row in 0..<9 {
            for col in 0..<9 where board.cell(row: row, col: col).value == nil {
                target = (row, col)
                break outer
            }
        }
        let cell = try #require(target)
        let correct = board.solutionDigit(atRow: cell.row, col: cell.col)
        let wrong = (1...9).first { $0 != correct }!
        vm.select(row: cell.row, col: cell.col)
        vm.place(value: wrong)

        vm.requestHint()
        #expect(vm.activeHint == nil)
        #expect(vm.hintUnavailable == .boardHasAMistake)
        // Refused help is not charged.
        #expect(vm.assistsUsed == 0)
    }

    @Test("dismissing hides the explanation but keeps the board hint")
    func dismissKeepsBoardHint() {
        let vm = makeViewModel()
        vm.requestHint()
        let target = vm.hintTargetIndex
        vm.dismissHint()
        #expect(vm.isHintCardVisible == false)
        #expect(vm.hintTargetIndex == target)
        #expect(vm.assistsUsed == 1)
    }

    @Test("another placement does not consume the board hint")
    func otherPlacementKeepsHint() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        // Place something in a different empty cell. It has to be genuinely
        // empty — a given is immutable, so place() would no-op and the test
        // would pass for the wrong reason.
        let board = try #require(vm.board)
        var other: (row: Int, col: Int)?
        outer: for row in 0..<9 {
            for col in 0..<9 where board.cell(row: row, col: col).value == nil {
                if row * 9 + col != hint.step.index { other = (row, col); break outer }
            }
        }
        let target = try #require(other)
        vm.select(row: target.row, col: target.col)
        vm.place(value: board.solutionDigit(atRow: target.row, col: target.col))
        #expect(vm.activeHint == hint)
    }

    @Test("placing the hinted digit consumes the board hint")
    func targetPlacementClearsHint() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let hint = try #require(vm.activeHint)
        vm.dismissHint()
        vm.select(row: hint.step.row, col: hint.step.column)
        vm.place(value: hint.step.value)
        #expect(vm.activeHint == nil)
        #expect(vm.isHintCardVisible == false)
    }

    @Test("both unavailable reasons have copy")
    func unavailableCopyExists() {
        #expect(SudokuHintCopy.unavailableMessage(.boardHasAMistake).isEmpty == false)
        #expect(SudokuHintCopy.unavailableMessage(.beyondSingles).isEmpty == false)
    }

    @Test("every unit kind is named")
    func unitNames() {
        #expect(SudokuHintCopy.unitName(.row(0)).isEmpty == false)
        #expect(SudokuHintCopy.unitName(.column(8)).isEmpty == false)
        #expect(SudokuHintCopy.unitName(.box(row: 1, column: 1)).isEmpty == false)
    }

    @Test("assist count survives save and restore")
    func assistCountPersists() throws {
        let vm = makeViewModel()
        vm.requestHint()
        let used = vm.assistsUsed
        #expect(used == 1)

        let board = try #require(vm.board)
        let saved = SudokuSaveState(
            puzzleId: "hint-fixture",
            givens: Self.testGivens,
            solution: Self.testSolution,
            givenCount: 30,
            cells: board.cells,
            elapsedSeconds: 20,
            mistakes: 0,
            lockedCellIndices: [],
            gameMode: SudokuGameMode.free.rawValue,
            savedAt: Date(timeIntervalSince1970: 0),
            assistsUsed: used
        )
        let restored = makeViewModel()
        restored.restoreState(saved)
        #expect(restored.assistsUsed == used)
    }

    @Test("a save predating assists restores as unaided")
    func legacySaveIsUnaided() throws {
        let vm = makeViewModel()
        let board = try #require(vm.board)
        let legacy = SudokuSaveState(
            puzzleId: "hint-fixture",
            givens: Self.testGivens,
            solution: Self.testSolution,
            givenCount: 30,
            cells: board.cells,
            elapsedSeconds: 20,
            mistakes: 0,
            lockedCellIndices: [],
            gameMode: SudokuGameMode.free.rawValue,
            savedAt: Date(timeIntervalSince1970: 0)
        )
        let restored = makeViewModel()
        restored.restoreState(legacy)
        #expect(restored.assistsUsed == 0)
    }
}
