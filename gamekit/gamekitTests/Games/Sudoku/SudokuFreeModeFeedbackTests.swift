import Testing
import Foundation
@testable import gamekit

/// Free mode used to accept a wrong digit with no feedback of any kind. The
/// mode's own header and the comment in `commitValue` both claimed wrong
/// placements showed red; neither was true, so a player could poison the
/// board on move eight and grind for the rest of the session on something
/// that could never be solved.
///
/// Lives mode is unaffected by design: it never commits a wrong value, so it
/// can never hold one.
@Suite("Sudoku free-mode wrong-digit feedback")
@MainActor
struct SudokuFreeModeFeedbackTests {

    // Same fixture the existing SudokuViewModelTests use.
    private static let testGivens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private static let testSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private static func makeViewModel(mode: SudokuGameMode) -> SudokuViewModel {
        let suite = UserDefaults(suiteName: "SudokuFreeModeFeedbackTests.\(UUID().uuidString)")!
        suite.set(mode.rawValue, forKey: SudokuViewModel.lastGameModeKey)
        let vm = SudokuViewModel(difficulty: .easy, mode: mode, userDefaults: suite)
        // Board loading is async; this is the existing unit-test seam.
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "free-mode-feedback-fixture",
                givens: testGivens,
                solution: testSolution,
                givenCount: 30
            )
        )
        return vm
    }

    /// Finds an empty cell and a digit that is *not* the solution for it.
    private static func wrongDigit(for vm: SudokuViewModel) -> (row: Int, col: Int, value: Int)? {
        guard let board = vm.board else { return nil }
        for row in 0..<9 {
            for col in 0..<9 {
                guard case .empty = board.cell(row: row, col: col) else { continue }
                let solution = board.solutionDigit(atRow: row, col: col)
                let wrong = (1...9).first { $0 != solution }!
                return (row, col, wrong)
            }
        }
        return nil
    }

    private static func correctDigit(for vm: SudokuViewModel) -> (row: Int, col: Int, value: Int)? {
        guard let board = vm.board else { return nil }
        for row in 0..<9 {
            for col in 0..<9 {
                guard case .empty = board.cell(row: row, col: col) else { continue }
                return (row, col, board.solutionDigit(atRow: row, col: col))
            }
        }
        return nil
    }

    @Test("a fresh board flags nothing")
    func freshBoardIsClean() {
        let vm = Self.makeViewModel(mode: .free)
        #expect(vm.incorrectCellIndices.isEmpty)
    }

    @Test("a wrong digit in free mode is flagged")
    func wrongDigitIsFlagged() throws {
        let vm = Self.makeViewModel(mode: .free)
        let target = try #require(Self.wrongDigit(for: vm))

        vm.select(row: target.row, col: target.col)
        vm.place(value: target.value)

        #expect(vm.incorrectCellIndices.contains(target.row * 9 + target.col))
    }

    @Test("a correct digit is not flagged")
    func correctDigitIsNotFlagged() throws {
        let vm = Self.makeViewModel(mode: .free)
        let target = try #require(Self.correctDigit(for: vm))

        vm.select(row: target.row, col: target.col)
        vm.place(value: target.value)

        #expect(vm.incorrectCellIndices.contains(target.row * 9 + target.col) == false)
    }

    @Test("correcting a wrong digit clears the flag")
    func correctingClearsTheFlag() throws {
        let vm = Self.makeViewModel(mode: .free)
        let target = try #require(Self.wrongDigit(for: vm))
        let idx = target.row * 9 + target.col

        vm.select(row: target.row, col: target.col)
        vm.place(value: target.value)
        #expect(vm.incorrectCellIndices.contains(idx))

        let solution = try #require(vm.board).solutionDigit(atRow: target.row, col: target.col)
        vm.place(value: solution)
        #expect(vm.incorrectCellIndices.contains(idx) == false)
    }

    @Test("erasing a wrong digit clears the flag")
    func erasingClearsTheFlag() throws {
        let vm = Self.makeViewModel(mode: .free)
        let target = try #require(Self.wrongDigit(for: vm))
        let idx = target.row * 9 + target.col

        vm.select(row: target.row, col: target.col)
        vm.place(value: target.value)
        #expect(vm.incorrectCellIndices.contains(idx))

        vm.erase()
        #expect(vm.incorrectCellIndices.contains(idx) == false)
    }

    @Test("lives mode never reports an incorrect cell")
    func livesModeStaysEmpty() throws {
        let vm = Self.makeViewModel(mode: .lives)
        let target = try #require(Self.wrongDigit(for: vm))

        vm.select(row: target.row, col: target.col)
        vm.place(value: target.value)

        // The wrong value was rejected rather than committed, so there is
        // nothing to flag — and the flag is scoped to free mode regardless.
        #expect(vm.incorrectCellIndices.isEmpty)
    }

    @Test("givens are never flagged")
    func givensAreNeverFlagged() throws {
        let vm = Self.makeViewModel(mode: .free)
        let board = try #require(vm.board)
        var givenCount = 0
        for row in 0..<9 {
            for col in 0..<9 {
                if case .given = board.cell(row: row, col: col) { givenCount += 1 }
            }
        }
        #expect(givenCount > 0)
        #expect(vm.incorrectCellIndices.isEmpty)
    }
}
