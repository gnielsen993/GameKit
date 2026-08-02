import Testing
import Foundation
import SwiftData
@testable import gamekit

/// Both solitaires switched undo off the instant the deal died — `canUndo`
/// required `.playing`, so the one tool that could rescue the player stopped
/// working at exactly the moment they needed it.
///
/// They also wrote the loss the moment the dead end was detected, before the
/// player had agreed the game was over. That was merely premature while undo
/// was disabled; the moment undo can revive a dead deal it becomes a
/// double-count, because the same deal can then also be won.
@Suite("Solitaire dead ends")
@MainActor
struct SolitaireDeadEndTests {

    private static func makeStats() throws -> (GameStats, ModelContext) {
        let container = try InMemoryStatsContainer.make()
        let ctx = ModelContext(container)
        return (GameStats(modelContext: ctx), ctx)
    }

    private static func klondikeRecords(_ ctx: ModelContext) throws -> [GameRecord] {
        try ctx.fetch(FetchDescriptor<GameRecord>()).filter { $0.gameKindRaw == GameKind.klondike.rawValue }
    }

    private static func freeCellRecords(_ ctx: ModelContext) throws -> [GameRecord] {
        try ctx.fetch(FetchDescriptor<GameRecord>()).filter { $0.gameKindRaw == GameKind.freeCell.rawValue }
    }

    // MARK: - Klondike

    @Test("a fresh Klondike deal has nothing to undo")
    func klondikeFreshDealHasNoUndo() {
        let vm = SolitaireViewModel(difficulty: .easy)
        #expect(vm.canUndo == false)
    }

    @Test("Klondike undo becomes available after a move")
    func klondikeUndoAfterMove() {
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.drawFromStock()
        #expect(vm.canUndo)
    }

    @Test("Klondike undo reverses the draw")
    func klondikeUndoReversesDraw() {
        let vm = SolitaireViewModel(difficulty: .easy)
        let wasteBefore = vm.board.waste.count
        vm.drawFromStock()
        #expect(vm.board.waste.count != wasteBefore)
        vm.undo()
        #expect(vm.board.waste.count == wasteBefore)
        #expect(vm.moveCount == 0)
    }

    @Test("restarting a Klondike deal records exactly one loss when stuck")
    func klondikeRestartFlushesOneLoss() async throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.wire(stats: stats)

        vm.forceStuckForTests()
        // Nothing written yet — the player has not accepted the dead end.
        #expect(try Self.klondikeRecords(ctx).isEmpty)

        vm.restartCurrentDeal()
        try await Task.sleep(for: .milliseconds(120))   // record() runs in a Task
        let records = try Self.klondikeRecords(ctx)
        #expect(records.count == 1)
        #expect(records.first?.outcomeRaw == Outcome.loss.rawValue)
    }

    @Test("undoing out of a Klondike dead end writes no loss and resumes play")
    func klondikeUndoCancelsTheLoss() async throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.wire(stats: stats)

        vm.drawFromStock()          // something to undo
        vm.forceStuckForTests()
        #expect(vm.gameState == .stuck)
        #expect(vm.canUndo)         // the whole point: undo survives the dead end

        vm.undo()
        #expect(vm.gameState == .playing)

        try await Task.sleep(for: .milliseconds(120))
        #expect(try Self.klondikeRecords(ctx).isEmpty)
    }

    @Test("a revived Klondike deal that is then abandoned records one loss, not two")
    func klondikeReviveThenAbandonRecordsOnce() async throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.wire(stats: stats)

        vm.drawFromStock()
        vm.forceStuckForTests()
        vm.undo()                   // revived
        vm.forceStuckForTests()     // dead again
        vm.restartCurrentDeal()     // accepted

        try await Task.sleep(for: .milliseconds(120))
        #expect(try Self.klondikeRecords(ctx).count == 1)
    }

    // MARK: - FreeCell

    @Test("a fresh FreeCell deal has nothing to undo")
    func freeCellFreshDealHasNoUndo() {
        let vm = FreeCellViewModel(mode: .deal(1))
        #expect(vm.canUndo == false)
    }

    @Test("undoing out of a FreeCell dead board writes no loss and resumes play")
    func freeCellUndoCancelsTheLoss() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.gameStats = stats

        vm.forceLostForTests(withHistory: true)
        #expect(vm.gameState == .lost)
        #expect(vm.canUndo)

        vm.undo()
        #expect(vm.gameState == .playing)
        #expect(try Self.freeCellRecords(ctx).isEmpty)
    }

    @Test("resetting a lost FreeCell deal records exactly one loss")
    func freeCellResetFlushesOneLoss() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.gameStats = stats

        vm.forceLostForTests(withHistory: true)
        #expect(try Self.freeCellRecords(ctx).isEmpty)

        vm.reset()
        let records = try Self.freeCellRecords(ctx)
        #expect(records.count == 1)
        #expect(records.first?.outcomeRaw == Outcome.loss.rawValue)
    }

    @Test("a revived FreeCell deal that is then abandoned records one loss, not two")
    func freeCellReviveThenAbandonRecordsOnce() throws {
        let (stats, ctx) = try Self.makeStats()
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.gameStats = stats

        vm.forceLostForTests(withHistory: true)
        vm.undo()
        vm.forceLostForTests(withHistory: true)
        vm.reset()

        #expect(try Self.freeCellRecords(ctx).count == 1)
    }
}
