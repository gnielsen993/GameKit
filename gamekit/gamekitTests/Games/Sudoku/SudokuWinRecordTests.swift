#if DEBUG

import Testing
import Foundation
import SwiftData
@testable import gamekit

/// The Sudoku view model remembers whether its last win set a personal best,
/// as decided by `GameStats` (never re-derived here), and a near-win fixture
/// game never reaches the player's real stats.
@Suite("Sudoku win record")
@MainActor
struct SudokuWinRecordTests {

    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    /// The solution with the last cell blanked: one placement from a win.
    private static let oneOpenGivens = String(solution.dropLast()) + "0"
    private static let lastDigit = 9
    private static let realGivens = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    private static func suite() -> UserDefaults {
        UserDefaults(suiteName: "SudokuWinRecordTests.\(UUID().uuidString)")!
    }

    /// A playing game one correct placement from a win, with `seconds` on the clock.
    private static func makeNearlyDone(
        stats: GameStats?,
        seconds: TimeInterval,
        mode: SudokuGameMode = .free,
        assists: Int = 0
    ) -> SudokuViewModel {
        let vm = SudokuViewModel(
            difficulty: .easy, mode: mode, userDefaults: suite(), gameStats: stats
        )
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "win-record-fixture",
                givens: oneOpenGivens,
                solution: solution,
                givenCount: 80
            )
        )
        vm.state = .playing
        vm.pausedElapsed = seconds
        vm.assistsUsed = assists
        vm.select(row: 8, col: 8)
        return vm
    }

    private static func records(_ ctx: ModelContext) throws -> [GameRecord] {
        try ctx.fetch(FetchDescriptor<GameRecord>())
    }

    // MARK: - Personal best

    @Test("a first unassisted win reports a best with nothing before it")
    func firstWinSetsBest() throws {
        let (stats, _) = try Self.makeStats()
        let vm = Self.makeNearlyDone(stats: stats, seconds: 251)
        vm.place(value: Self.lastDigit)
        #expect(vm.state == .won)
        #expect(vm.lastWinRecord == RecordResult(setBestTime: true, previousBest: nil))
    }

    @Test("a slower win on the same store reports no best and the standing time")
    func slowerWinReportsStandingBest() throws {
        let (stats, _) = try Self.makeStats()
        let first = Self.makeNearlyDone(stats: stats, seconds: 200)
        first.place(value: Self.lastDigit)

        let second = Self.makeNearlyDone(stats: stats, seconds: 300)
        second.place(value: Self.lastDigit)
        #expect(second.lastWinRecord == RecordResult(setBestTime: false, previousBest: 200))
    }

    @Test("a faster win reports a best and the time it beat")
    func fasterWinReportsPrevious() throws {
        let (stats, _) = try Self.makeStats()
        let first = Self.makeNearlyDone(stats: stats, seconds: 200)
        first.place(value: Self.lastDigit)

        let second = Self.makeNearlyDone(stats: stats, seconds: 150)
        second.place(value: Self.lastDigit)
        #expect(second.lastWinRecord == RecordResult(setBestTime: true, previousBest: 200))
    }

    @Test("an assisted win never reports a best")
    func assistedWinReportsNoBest() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = Self.makeNearlyDone(stats: stats, seconds: 100, assists: 1)
        vm.place(value: Self.lastDigit)
        #expect(vm.state == .won)
        #expect(vm.lastWinRecord?.setBestTime == false)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).isEmpty)
        #expect(try Self.records(ctx).count == 1)
    }

    @Test("a win with no stats attached reports nothing")
    func winWithoutStatsReportsNothing() {
        let vm = Self.makeNearlyDone(stats: nil, seconds: 100)
        vm.place(value: Self.lastDigit)
        #expect(vm.state == .won)
        #expect(vm.lastWinRecord == nil)
    }

    // MARK: - Practice

    @Test("a practice completion after Keep Solving records nothing and reports nothing")
    func practiceCompletionReportsNothing() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = Self.makeNearlyDone(stats: stats, seconds: 100, mode: .lives)
        let wrong = (1...9).first { $0 != Self.lastDigit }!
        for _ in 0..<SudokuGameMode.livesPerPuzzle { vm.place(value: wrong) }
        #expect(vm.state == .gameOver)
        #expect(try Self.records(ctx).count == 1)   // the loss

        vm.keepSolving()
        vm.place(value: Self.lastDigit)
        #expect(vm.state == .practiceComplete)
        #expect(vm.lastWinRecord == nil)
        #expect(try Self.records(ctx).count == 1)   // still only the loss
    }

    // MARK: - Reset

    @Test("restart clears the last win record")
    func restartClearsRecord() throws {
        let (stats, _) = try Self.makeStats()
        let vm = Self.makeNearlyDone(stats: stats, seconds: 251)
        vm.place(value: Self.lastDigit)
        #expect(vm.lastWinRecord != nil)
        vm.restart()
        #expect(vm.lastWinRecord == nil)
    }

    @Test("loading a new puzzle clears the last win record")
    func loadingNewPuzzleClearsRecord() async throws {
        let (stats, _) = try Self.makeStats()
        let vm = Self.makeNearlyDone(stats: stats, seconds: 251)
        vm.place(value: Self.lastDigit)
        #expect(vm.lastWinRecord != nil)
        await vm.loadFreshPuzzle()
        #expect(vm.lastWinRecord == nil)
    }

    // MARK: - Near-win fixture

    @Test("winning a near-win fixture writes no stats but previews the badge")
    func fixtureWinWritesNothing() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = SudokuViewModel(
            difficulty: .easy, mode: .free, userDefaults: Self.suite(), gameStats: stats
        )
        vm.injectTestBoardForUnitTests(
            puzzle: SudokuPuzzleEntry(
                id: "fixture-win-base",
                givens: Self.realGivens,
                solution: Self.solution,
                givenCount: 30
            )
        )
        vm.applyNearWinFixture()
        let board = try #require(vm.board)
        let open = (0..<81).filter { board.cells[$0].value == nil }
        #expect(open.count == 3)
        for idx in open {
            vm.select(row: idx / 9, col: idx % 9)
            vm.place(value: board.solutionDigit(atRow: idx / 9, col: idx % 9))
        }
        #expect(vm.state == .won)
        #expect(vm.lastWinRecord?.setBestTime == true)
        #expect(try Self.records(ctx).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<BestTime>()).isEmpty)
    }
}

#endif
