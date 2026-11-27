import Testing
import Foundation
@testable import gamekit

/// Phase 19.1 plan 03: a row, column or box is acknowledged only when it is
/// full AND correct (D-18), and the ripple order is a pure function of the
/// placed cell.
@Suite("SudokuCompletionWave")
@MainActor
struct SudokuCompletionWaveTests {

    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    /// Givens = the solution with the listed flat indices blanked.
    private static func givens(blanking blanks: Set<Int>) -> String {
        String(solution.enumerated().map { blanks.contains($0.offset) ? "0" : $0.element })
    }

    private static func solutionDigit(_ index: Int) -> Int {
        Int(String(solution[solution.index(solution.startIndex, offsetBy: index)]))!
    }

    /// Rows 0 and 1 blanked: no column and no box through row 0 can be full
    /// unless the test fills row 1 as well.
    private static let rowZeroAndOne = Set(0..<18)

    /// A board where row 0 is filled with the solution digits, except the
    /// listed overrides (index -> digit).
    private static func boardWithRowZeroFilled(
        blanking blanks: Set<Int> = rowZeroAndOne,
        overrides: [Int: Int] = [:]
    ) -> SudokuBoard {
        var board = SudokuBoard(givens: givens(blanking: blanks), solution: solution)!
        for col in 0..<9 {
            let digit = overrides[col] ?? solutionDigit(col)
            board = board.setting(.user(digit), atRow: 0, col: col)
        }
        return board
    }

    // MARK: correctCompletedCells

    @Test("the last correct digit of a row returns exactly that row")
    func correctRowReturnsRow() {
        let board = Self.boardWithRowZeroFilled()
        let cells = SudokuCompletionWave.correctCompletedCells(board: board, row: 0, col: 4)
        #expect(cells == Set(0...8))
    }

    @Test("a full row holding one wrong digit is not acknowledged")
    func rowWithWrongDigitReturnsEmpty() {
        let wrong = Self.solutionDigit(0) % 9 + 1
        let board = Self.boardWithRowZeroFilled(overrides: [0: wrong])
        let cells = SudokuCompletionWave.correctCompletedCells(board: board, row: 0, col: 4)
        #expect(cells.isEmpty)
    }

    @Test("a row that is not full returns nothing")
    func partialRowReturnsEmpty() {
        let board = SudokuBoard(givens: Self.givens(blanking: Self.rowZeroAndOne), solution: Self.solution)!
            .setting(.user(Self.solutionDigit(4)), atRow: 0, col: 4)
        #expect(SudokuCompletionWave.correctCompletedCells(board: board, row: 0, col: 4).isEmpty)
    }

    @Test("a placement completing its row and its box returns the 15-cell union")
    func rowAndBoxReturnUnion() {
        // Row 0 blanked and (5,0..2) blanked: box 0 can fill, columns 0..2 cannot.
        let blanks = Set(0..<9).union([45, 46, 47])
        let board = Self.boardWithRowZeroFilled(blanking: blanks)
        let cells = SudokuCompletionWave.correctCompletedCells(board: board, row: 0, col: 0)
        let expectedRow = Set(0...8)
        let expectedBox: Set<Int> = [0, 1, 2, 9, 10, 11, 18, 19, 20]
        #expect(cells == expectedRow.union(expectedBox))
        #expect(cells.count == 15)
    }

    @Test("givens count as correct for the units they sit in")
    func givensCountAsCorrect() {
        // Only (0,0) blanked: row 0, column 0 and box 0 all become correct.
        let board = SudokuBoard(givens: Self.givens(blanking: [0]), solution: Self.solution)!
            .setting(.user(Self.solutionDigit(0)), atRow: 0, col: 0)
        let cells = SudokuCompletionWave.correctCompletedCells(board: board, row: 0, col: 0)
        #expect(cells.count == 21) // 27 minus the pairwise overlaps (1 + 3 + 3) plus the triple (1)
    }

    // MARK: unitSteps

    @Test("steps along a row are the distance from the placed cell")
    func rowSteps() {
        let steps = SudokuCompletionWave.unitSteps(origin: 4, cells: Set(0...8))
        #expect(steps == [0: 4, 1: 3, 2: 2, 3: 1, 4: 0, 5: 1, 6: 2, 7: 3, 8: 4])
    }

    @Test("a cell in both the row and the box takes the smaller step")
    func overlapTakesSmallerStep() {
        let row: Set<Int> = Set(0...8)
        let box: Set<Int> = [0, 1, 2, 9, 10, 11, 18, 19, 20]
        let steps = SudokuCompletionWave.unitSteps(origin: 0, cells: row.union(box))
        // Cell 2 is two columns away along the row and two away in the box.
        #expect(steps[2] == 2)
        // Cell 20 (row 2, col 2) is in the box only: Chebyshev distance 2.
        #expect(steps[20] == 2)
        // Cell 8 is eight columns away.
        #expect(steps[8] == 8)
        #expect(steps[0] == 0)
    }

    @Test("no cells gives no steps")
    func emptyCellsGiveEmptySteps() {
        #expect(SudokuCompletionWave.unitSteps(origin: 40, cells: []).isEmpty)
    }

    // MARK: winSteps

    @Test("the win ripples every cell outward from the final placement")
    func winStepsFromOrigin() {
        let steps = SudokuCompletionWave.winSteps(origin: 40)
        #expect(steps.count == 81)
        #expect(steps[40] == 0)
        #expect(steps.values.max() == 8)
    }

    @Test("with no origin the win sweeps diagonally from the top-left")
    func winStepsWithoutOrigin() {
        let steps = SudokuCompletionWave.winSteps(origin: nil)
        #expect(steps.count == 81)
        #expect(steps[0] == 0)
        #expect(steps[80] == 16)
    }

    @Test("the longest win wave finishes inside the 1500ms pre-roll")
    func winWaveFitsPreRoll() {
        let worst = Double(16) * SudokuCompletionWave.stepInterval + SudokuCompletionWave.cellDuration
        #expect(worst < 1.5)
        #expect(Double(SudokuCompletionWave.clearDelayMilliseconds) / 1000 > worst - 0.3)
    }
}

/// View-model gate: the glow only fires for a correct unit.
@Suite("SudokuCompletionWave view model")
@MainActor
struct SudokuCompletionWaveViewModelTests {

    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private static func makeViewModel() -> SudokuViewModel {
        let suite = UserDefaults(suiteName: "SudokuCompletionWaveTests.\(UUID().uuidString)")!
        suite.set(SudokuGameMode.free.rawValue, forKey: SudokuViewModel.lastGameModeKey)
        let vm = SudokuViewModel(difficulty: .easy, mode: .free, userDefaults: suite)
        // Rows 0 and 1 blanked so no column or box completes with row 0.
        let givens = String(repeating: "0", count: 18) + solution.dropFirst(18)
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(id: "completion-wave-fixture", givens: givens, solution: solution, givenCount: 63)
        )
        return vm
    }

    private static func digit(_ col: Int) -> Int {
        Int(String(solution[solution.index(solution.startIndex, offsetBy: col)]))!
    }

    /// Fills row 0 left to right; `wrongAt` substitutes a wrong digit there.
    private static func fillRowZero(_ vm: SudokuViewModel, wrongAt: Int? = nil) {
        for col in 0..<9 {
            vm.select(row: 0, col: col)
            let value = col == wrongAt ? digit(col) % 9 + 1 : digit(col)
            vm.place(value: value)
        }
    }

    @Test("completing a row that contains a wrong digit fires nothing")
    func wrongRowIsNotAcknowledged() {
        let vm = Self.makeViewModel()
        Self.fillRowZero(vm, wrongAt: 0)
        #expect(vm.completionGlowCount == 0)
        #expect(vm.completionGlowIndices.isEmpty)
    }

    @Test("completing a row correctly fires the glow once for that row")
    func correctRowIsAcknowledged() {
        let vm = Self.makeViewModel()
        Self.fillRowZero(vm)
        #expect(vm.completionGlowCount == 1)
        #expect(vm.completionGlowIndices == Set(0...8))
    }
}
