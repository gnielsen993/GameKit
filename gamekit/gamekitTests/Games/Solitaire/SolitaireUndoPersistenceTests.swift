import Testing
import Foundation
@testable import gamekit

/// Undo used to end at the app boundary: neither save file carried the undo
/// stack, so reopening a game in progress left the button dead. FreeCell's
/// history is unbounded in memory, so a long deal could throw away dozens of
/// reversible moves simply because the player took a phone call.
///
/// The stack is now persisted, capped, and — critically — optional, so saves
/// written before the field existed still decode and simply resume with no
/// undo, exactly as they behaved when they were written.
@Suite("Solitaire undo persistence")
@MainActor
struct SolitaireUndoPersistenceTests {

    // MARK: - Klondike

    private func klondikeSave(historyDepth: Int?) -> SolitaireSaveState {
        let board = SolitaireBoard.deal(seed: 42, difficulty: .easy)
        let history = historyDepth.map { Array(repeating: board, count: $0) }
        return SolitaireSaveState(
            board: board,
            dealNumber: 42,
            difficulty: .easy,
            moveCount: historyDepth ?? 0,
            elapsedSeconds: 12,
            savedAt: Date(timeIntervalSince1970: 0),
            history: history
        )
    }

    @Test("a restored Klondike game can undo")
    func klondikeRestoreEnablesUndo() {
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.restoreState(klondikeSave(historyDepth: 3))
        #expect(vm.canUndo)
    }

    @Test("a restored Klondike game can actually pop its stack")
    func klondikeRestoredUndoPops() {
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.restoreState(klondikeSave(historyDepth: 2))
        vm.undo()
        #expect(vm.canUndo)     // one entry left
        vm.undo()
        #expect(vm.canUndo == false)
    }

    @Test("a save written before undo was persisted still restores")
    func klondikeLegacySaveRestores() {
        let vm = SolitaireViewModel(difficulty: .easy)
        vm.restoreState(klondikeSave(historyDepth: nil))
        // Old behaviour preserved: the game resumes, undo is simply empty.
        #expect(vm.gameState == .playing)
        #expect(vm.canUndo == false)
    }

    @Test("a legacy Klondike save with no history key decodes")
    func klondikeLegacyJSONDecodes() throws {
        // Encode without the field, exactly as a pre-change build wrote it.
        let board = SolitaireBoard.deal(seed: 7, difficulty: .easy)
        let boardJSON = try JSONEncoder().encode(board)
        let boardObject = try JSONSerialization.jsonObject(with: boardJSON)
        let legacy: [String: Any] = [
            "board": boardObject,
            "dealNumber": 7,
            "difficulty": SolitaireDifficulty.easy.rawValue,
            "moveCount": 4,
            "elapsedSeconds": 30.0,
            "savedAt": 0.0
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(SolitaireSaveState.self, from: data)
        #expect(decoded.history == nil)
        #expect(decoded.dealNumber == 7)
    }

    @Test("Klondike history round-trips through JSON")
    func klondikeHistoryRoundTrips() throws {
        let original = klondikeSave(historyDepth: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SolitaireSaveState.self, from: data)
        #expect(decoded.history?.count == 5)
    }

    /// The cap exists because this lives in UserDefaults. If a board ever
    /// grows enough to blow the budget, this is the test that says so.
    @Test("a full persisted Klondike stack stays a reasonable size")
    func klondikePersistedStackIsBounded() throws {
        let full = klondikeSave(historyDepth: SolitaireSaveState.persistedHistoryDepth)
        let data = try JSONEncoder().encode(full)
        // A blowup guard, not a measured figure: a 52-card board is a few KB
        // of JSON, so a 20-deep stack lands well inside this. The number is
        // here to catch an order-of-magnitude regression (an uncapped stack,
        // or a board type that grows) before it reaches UserDefaults.
        #expect(data.count < 200_000)
    }

    // MARK: - FreeCell

    private func freeCellSave(historyDepth: Int?) -> FreeCellSaveState {
        let board = FreeCellBoard(dealNumber: 1)
        let move = FreeCellMove(
            cards: [],
            source: .freeCell(cellIdx: 0),
            destination: .foundation,
            boardBefore: board
        )
        return FreeCellSaveState(
            board: board,
            dealNumber: 1,
            difficulty: nil,
            elapsedSeconds: 8,
            savedAt: Date(timeIntervalSince1970: 0),
            history: historyDepth.map { Array(repeating: move, count: $0) }
        )
    }

    @Test("a restored FreeCell game can undo")
    func freeCellRestoreEnablesUndo() {
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.restoreState(freeCellSave(historyDepth: 3))
        #expect(vm.canUndo)
    }

    @Test("a restored FreeCell game can actually pop its stack")
    func freeCellRestoredUndoPops() {
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.restoreState(freeCellSave(historyDepth: 2))
        vm.undo()
        #expect(vm.canUndo)
        vm.undo()
        #expect(vm.canUndo == false)
    }

    @Test("a FreeCell save written before undo was persisted still restores")
    func freeCellLegacySaveRestores() {
        let vm = FreeCellViewModel(mode: .deal(1))
        vm.restoreState(freeCellSave(historyDepth: nil))
        #expect(vm.gameState == .playing)
        #expect(vm.canUndo == false)
    }

    @Test("FreeCell move metadata survives the round trip")
    func freeCellMoveRoundTrips() throws {
        let board = FreeCellBoard(dealNumber: 1)
        let move = FreeCellMove(
            cards: [PlayingCard(rank: .ace, suit: .spades, faceUp: true)],
            source: .column(colIdx: 3, startIdx: 5),
            destination: .freeCell(2),
            boardBefore: board
        )
        let data = try JSONEncoder().encode(move)
        let decoded = try JSONDecoder().decode(FreeCellMove.self, from: data)
        #expect(decoded.source == .column(colIdx: 3, startIdx: 5))
        #expect(decoded.destination == .freeCell(2))
        #expect(decoded.cards.count == 1)
    }

    @Test("a full persisted FreeCell stack stays a reasonable size")
    func freeCellPersistedStackIsBounded() throws {
        let full = freeCellSave(historyDepth: FreeCellSaveState.persistedHistoryDepth)
        let data = try JSONEncoder().encode(full)
        // A blowup guard, not a measured figure: a 52-card board is a few KB
        // of JSON, so a 20-deep stack lands well inside this. The number is
        // here to catch an order-of-magnitude regression (an uncapped stack,
        // or a board type that grows) before it reaches UserDefaults.
        #expect(data.count < 200_000)
    }
}
