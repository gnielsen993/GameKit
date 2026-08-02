import Testing
import Foundation
import SwiftData
@testable import gamekit

/// Replaying a lost board — the honest alternative to a revive. The loss is
/// already recorded and the run is over; this is "let me see how that should
/// have gone", not a second chance at the same run.
///
/// Two properties carry it: the mines must stay exactly where they were, and
/// the replay must never set a best time. The loss cascade has already shown
/// the player every mine, so a replayed win is a walk-through.
@Suite("Minesweeper replay board")
@MainActor
struct MinesweeperReplayBoardTests {

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    private func lostGame() -> MinesweeperViewModel {
        let vm = MinesweeperViewModel(difficulty: .easy, rng: SeededGenerator(seed: 99))
        // First tap generates the board, then walk until a mine is hit.
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
        for index in vm.board.allIndices() where vm.board.cell(at: index).isMine {
            vm.reveal(at: index)
            break
        }
        return vm
    }

    @Test("a lost game can be replayed")
    func lostGameOffersReplay() {
        let vm = lostGame()
        guard case .lost = vm.gameState else {
            Issue.record("fixture did not reach a lost state")
            return
        }
        vm.retryCurrentBoard()
        #expect(vm.isReplayingBoard)
    }

    @Test("the mines stay exactly where they were")
    func mineLayoutIsPreserved() {
        let vm = lostGame()
        let before = vm.board.allIndices().filter { vm.board.cell(at: $0).isMine }
        vm.retryCurrentBoard()
        let after = vm.board.allIndices().filter { vm.board.cell(at: $0).isMine }
        #expect(before == after)
        #expect(before.isEmpty == false)
    }

    @Test("adjacency counts survive the replay")
    func adjacencyIsPreserved() {
        let vm = lostGame()
        let before = vm.board.allIndices().map { vm.board.cell(at: $0).adjacentMineCount }
        vm.retryCurrentBoard()
        let after = vm.board.allIndices().map { vm.board.cell(at: $0).adjacentMineCount }
        #expect(before == after)
    }

    @Test("every cell is hidden again")
    func boardIsResetToHidden() {
        let vm = lostGame()
        vm.retryCurrentBoard()
        let anyRevealed = vm.board.allIndices().contains {
            vm.board.cell(at: $0).state != .hidden
        }
        #expect(anyRevealed == false)
        #expect(vm.flaggedCount == 0)
        #expect(vm.lossContext == nil)
    }

    /// The subtle one. `.idle` is the only state that regenerates the board on
    /// first tap, so a replay entering it would silently discard the layout
    /// it exists to preserve.
    @Test("a replay does not re-enter the state that regenerates the board")
    func replayDoesNotGoIdle() {
        let vm = lostGame()
        vm.retryCurrentBoard()
        #expect(vm.gameState == .playing)

        let minesBefore = vm.board.allIndices().filter { vm.board.cell(at: $0).isMine }
        // A first tap on a replayed board must not re-roll the layout.
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
        let minesAfter = vm.board.allIndices().filter { vm.board.cell(at: $0).isMine }
        #expect(minesBefore == minesAfter)
    }

    @Test("starting a genuinely new game clears the replay flag")
    func restartClearsReplayFlag() {
        let vm = lostGame()
        vm.retryCurrentBoard()
        #expect(vm.isReplayingBoard)
        vm.restart()
        #expect(vm.isReplayingBoard == false)
    }

    @Test("a replay cannot be started from a game still in progress")
    func replayRequiresALoss() {
        let vm = MinesweeperViewModel(difficulty: .easy, rng: SeededGenerator(seed: 7))
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
        vm.retryCurrentBoard()
        #expect(vm.isReplayingBoard == false)
    }

    @Test("a replayed win is recorded but sets no best time")
    func replayedWinSetsNoBestTime() throws {
        let (stats, ctx) = try Self.makeStats()

        // An honest win first, so there is a stored best to protect.
        try stats.record(
            gameKind: .minesweeper, difficulty: MinesweeperDifficulty.easy.rawValue,
            outcome: .win, durationSeconds: 200
        )
        // Then a much faster replayed win.
        try stats.record(
            gameKind: .minesweeper, difficulty: MinesweeperDifficulty.easy.rawValue,
            outcome: .win, durationSeconds: 3, countsTowardRecords: false
        )

        let records = try ctx.fetch(FetchDescriptor<GameRecord>())
        #expect(records.count == 2)   // both games count as played

        let best = try ctx.fetch(FetchDescriptor<BestTime>())
        #expect(best.count == 1)
        #expect(best.first?.seconds == 200)   // the honest time survives
    }

    /// A replay is not an assisted game — the player used no hint, and
    /// reporting one would be a lie in the disclosure copy.
    @Test("a replay is not reported as assisted")
    func replayIsNotAssisted() throws {
        let (stats, ctx) = try Self.makeStats()
        try stats.record(
            gameKind: .minesweeper, difficulty: MinesweeperDifficulty.easy.rawValue,
            outcome: .win, durationSeconds: 3, countsTowardRecords: false
        )
        let record = try #require(try ctx.fetch(FetchDescriptor<GameRecord>()).first)
        #expect(record.wasAssisted == false)
        #expect(record.assistCount == nil)
    }
}
