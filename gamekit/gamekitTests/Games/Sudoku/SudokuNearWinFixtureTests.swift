#if DEBUG

import Testing
import Foundation
@testable import gamekit

/// The DEBUG near-win fixture: pure cell selection, then application to a
/// view model without touching the player's saved game.
@Suite("Sudoku near-win fixture")
@MainActor
struct SudokuNearWinFixtureTests {

    private static let givens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private static func makeViewModel(
        mode: SudokuGameMode = .free,
        suite: UserDefaults? = nil
    ) -> SudokuViewModel {
        let defaults = suite ?? UserDefaults(suiteName: "SudokuNearWinFixtureTests.\(UUID().uuidString)")!
        let vm = SudokuViewModel(difficulty: .easy, mode: mode, userDefaults: defaults)
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "near-win-fixture-base",
                givens: givens,
                solution: solution,
                givenCount: 30
            )
        )
        return vm
    }

    private static func emptyIndices(_ vm: SudokuViewModel) -> [Int] {
        guard let board = vm.board else { return [] }
        return (0..<81).filter { board.cells[$0].value == nil }
    }

    // MARK: - Pure selection

    @Test("picks exactly three non-given cells sharing the smallest eligible digit, row-major")
    func emptyIndicesPicksSmallestDigit() {
        let picked = SudokuNearWinFixture.emptyIndices(givens: Self.givens, solution: Self.solution)
        #expect(picked.count == 3)
        #expect(picked == picked.sorted())
        let solved = Array(Self.solution)
        let given = Array(Self.givens)
        let digits = Set(picked.map { solved[$0] })
        #expect(digits.count == 1)
        #expect(picked.allSatisfy { given[$0] == "0" })
        // No smaller digit has three open cells.
        let chosen = Int(String(digits.first!))!
        for smaller in 1..<chosen {
            let open = (0..<81).filter { given[$0] == "0" && solved[$0] == Character("\(smaller)") }
            #expect(open.count < 3)
        }
    }

    @Test("is deterministic")
    func emptyIndicesDeterministic() {
        let a = SudokuNearWinFixture.emptyIndices(givens: Self.givens, solution: Self.solution)
        let b = SudokuNearWinFixture.emptyIndices(givens: Self.givens, solution: Self.solution)
        #expect(a == b)
    }

    @Test("returns nothing when no digit has three open cells")
    func emptyIndicesEmptyWhenNoDigitQualifies() {
        // Only two open cells in the whole puzzle.
        var given = Array(Self.solution)
        given[0] = "0"
        given[40] = "0"
        let picked = SudokuNearWinFixture.emptyIndices(
            givens: String(given), solution: Self.solution
        )
        #expect(picked.isEmpty)
    }

    @Test("returns nothing for malformed input")
    func emptyIndicesMalformed() {
        #expect(SudokuNearWinFixture.emptyIndices(givens: "123", solution: Self.solution).isEmpty)
    }

    @Test("only ids with the fixture suffix are fixtures")
    func isFixtureMatchesSuffixOnly() {
        #expect(SudokuNearWinFixture.isFixture(puzzleID: "abc-debug-near-win"))
        #expect(!SudokuNearWinFixture.isFixture(puzzleID: "abc"))
        #expect(!SudokuNearWinFixture.isFixture(puzzleID: "debug-near-win-abc"))
        #expect(!SudokuNearWinFixture.isFixture(puzzleID: nil))
    }

    // MARK: - Applied to a view model

    @Test("leaves exactly three empty cells that all take one digit")
    func fixtureLeavesThreeSameDigitCells() throws {
        let vm = Self.makeViewModel()
        vm.applyNearWinFixture()

        let open = Self.emptyIndices(vm)
        #expect(open.count == 3)
        let board = try #require(vm.board)
        let digits = Set(open.map { board.solutionDigit(atRow: $0 / 9, col: $0 % 9) })
        #expect(digits.count == 1)
        let d = try #require(digits.first)
        for digit in 1...9 {
            #expect(vm.remainingPerDigit[digit] == (digit == d ? 3 : 0))
        }
    }

    @Test("marks the puzzle id, selects an empty cell, starts playing at 4:11")
    func fixtureStateIsPlayingNearTheEnd() throws {
        let vm = Self.makeViewModel()
        vm.applyNearWinFixture()

        #expect(vm.isNearWinFixture)
        #expect(vm.currentPuzzle?.id.hasSuffix(SudokuNearWinFixture.puzzleIDSuffix) == true)
        #expect(vm.state == .playing)
        #expect(vm.elapsedSeconds >= SudokuNearWinFixture.previewElapsedSeconds)
        #expect(vm.selectedCell?.value == nil)
        #expect(vm.selectedCell != nil)
        #expect(vm.mistakes == 0)
    }

    @Test("applying twice does not double the suffix")
    func fixtureIsIdempotentOnTheId() {
        let vm = Self.makeViewModel()
        vm.applyNearWinFixture()
        let once = vm.currentPuzzle?.id
        vm.applyNearWinFixture()
        #expect(vm.currentPuzzle?.id == once)
    }

    @Test("in Lives mode every cell but the three is locked")
    func fixtureLocksCellsInLives() {
        let vm = Self.makeViewModel(mode: .lives)
        vm.applyNearWinFixture()
        #expect(vm.lockedCells.count == 78)
    }

    @Test("the launch argument gates the fixture")
    func launchArgumentGatesFixture() {
        let off = Self.makeViewModel()
        off.applyNearWinFixtureIfLaunched(arguments: ["gamekit"])
        #expect(!off.isNearWinFixture)
        #expect(Self.emptyIndices(off).count > 3)

        let on = Self.makeViewModel()
        on.applyNearWinFixtureIfLaunched(arguments: ["gamekit", SudokuNearWinFixture.launchArgument])
        #expect(on.isNearWinFixture)
        #expect(Self.emptyIndices(on).count == 3)
    }

    // MARK: - Saved game safety

    @Test("a fixture game writes nothing to its saved-game slot")
    func fixtureDoesNotSave() {
        let suite = UserDefaults(suiteName: "SudokuNearWinFixtureTests.save.\(UUID().uuidString)")!
        let vm = Self.makeViewModel(suite: suite)
        vm.applyNearWinFixture()
        vm.saveCurrentState()
        let key = SudokuSaveState.key(difficulty: .easy, gameMode: .free)
        #expect(suite.data(forKey: key) == nil)
    }

    @Test("a real saved game survives clearSavedState while the fixture is active")
    func fixtureLeavesRealSaveAlone() {
        let suite = UserDefaults(suiteName: "SudokuNearWinFixtureTests.clear.\(UUID().uuidString)")!
        let key = SudokuSaveState.key(difficulty: .easy, gameMode: .free)
        suite.set(Data([1, 2, 3]), forKey: key)

        let vm = Self.makeViewModel(suite: suite)
        vm.applyNearWinFixture()
        vm.clearSavedState()
        #expect(suite.data(forKey: key) == Data([1, 2, 3]))
    }

    @Test("a normal game still clears its saved slot")
    func normalGameStillClears() {
        let suite = UserDefaults(suiteName: "SudokuNearWinFixtureTests.normal.\(UUID().uuidString)")!
        let key = SudokuSaveState.key(difficulty: .easy, gameMode: .free)
        suite.set(Data([1, 2, 3]), forKey: key)

        let vm = Self.makeViewModel(suite: suite)
        vm.clearSavedState()
        #expect(suite.data(forKey: key) == nil)
    }
}

#endif
