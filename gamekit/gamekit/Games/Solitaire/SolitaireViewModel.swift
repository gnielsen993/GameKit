import SwiftUI
import SwiftData
import DesignKit

@MainActor
@Observable
final class SolitaireViewModel {

    // MARK: - Public state

    private(set) var board: SolitaireBoard
    private(set) var difficulty: SolitaireDifficulty
    private(set) var dealNumber: Int
    private(set) var moveCount: Int = 0
    private(set) var gameState: SolitaireGameState = .playing

    // Selection: (column index, card index within that column)
    // nil = nothing selected
    private(set) var selection: SolitaireSelection? = nil

    var timerAnchor: Date?       = nil
    var pausedElapsed: TimeInterval = 0

    // MARK: - Private state

    private var history: [SolitaireBoard] = []
    private var gameStats: GameStats?
    private(set) var pendingSaveState: SolitaireSaveState?

    var canUndo: Bool { !history.isEmpty && gameState == .playing }

    // MARK: - Init

    init(difficulty: SolitaireDifficulty = .easy) {
        self.difficulty = difficulty
        let deal = Int.random(in: 1...1_000_000)
        self.dealNumber = deal
        self.board = SolitaireBoard.deal(seed: deal, difficulty: difficulty)
        timerAnchor = .now
    }

    func wire(stats: GameStats) { self.gameStats = stats }

    // MARK: - Draw from stock

    func drawFromStock() {
        guard gameState == .playing else { return }
        saveHistory()
        if board.stock.isEmpty {
            // Recycle waste back to stock
            board.stock = board.waste.reversed().map {
                PlayingCard(rank: $0.rank, suit: $0.suit, faceUp: false)
            }
            board.waste = []
        } else {
            let count = min(difficulty.drawCount, board.stock.count)
            let drawn = board.stock.suffix(count).map {
                PlayingCard(rank: $0.rank, suit: $0.suit, faceUp: true)
            }
            board.stock.removeLast(count)
            board.waste.append(contentsOf: drawn)
        }
        selection = nil
        moveCount += 1
    }

    // MARK: - Selection / tap interaction

    func tap(column col: Int, cardIndex idx: Int) {
        guard gameState == .playing else { return }
        let column = board.tableau[col]
        guard idx < column.count else { return }
        let card = column[idx]

        // Tapping a face-down card: flip if it's the top card
        if !card.isFaceUp {
            guard idx == column.count - 1 else { return }
            saveHistory()
            board.tableau[col][idx] = PlayingCard(rank: card.rank, suit: card.suit, faceUp: true)
            moveCount += 1
            return
        }

        // If something is already selected, try to move it here
        if let sel = selection {
            if attemptMove(from: sel, toColumn: col) { return }
            // Re-select if tapping a different valid sequence
        }

        // Select from this card down to the bottom of the column
        let seq = SolitaireRules.pickableSequence(from: column, startingAt: idx)
        if !seq.isEmpty {
            selection = .column(col: col, fromIdx: idx)
        } else {
            selection = nil
        }
    }

    func tapWaste() {
        guard gameState == .playing, board.topWaste != nil else { return }
        if let sel = selection, case .waste = sel {
            selection = nil
            return
        }
        // If something selected, try moving onto waste (not valid in Klondike)
        selection = .waste
    }

    func tapFoundation(suit: CardSuit) {
        guard gameState == .playing else { return }
        if let sel = selection {
            _ = attemptMove(from: sel, toFoundation: suit)
        }
    }

    @discardableResult
    func sendToFoundation(column col: Int) -> Bool {
        guard gameState == .playing,
              let card = board.tableau[col].last,
              card.isFaceUp else { return false }
        let topRank = board.foundations[card.suit.foundationIndex]
        guard SolitaireRules.canPlaceOnFoundation(card, topRank: topRank) else { return false }
        saveHistory()
        board.tableau[col].removeLast()
        board.foundations[card.suit.foundationIndex] = card.rank
        flipNewTopCard(column: col)
        moveCount += 1
        selection = nil
        checkWin()
        return true
    }

    @discardableResult
    func sendWasteToFoundation() -> Bool {
        guard gameState == .playing, let card = board.topWaste else { return false }
        let topRank = board.foundations[card.suit.foundationIndex]
        guard SolitaireRules.canPlaceOnFoundation(card, topRank: topRank) else { return false }
        saveHistory()
        board.waste.removeLast()
        board.foundations[card.suit.foundationIndex] = card.rank
        moveCount += 1
        selection = nil
        checkWin()
        return true
    }

    func clearSelection() { selection = nil }

    func commitDrag(fromColumn srcCol: Int, fromIdx: Int, toColumn dstCol: Int) {
        guard gameState == .playing else { return }
        _ = attemptMove(from: .column(col: srcCol, fromIdx: fromIdx), toColumn: dstCol)
    }

    func commitWasteDrag(toColumn dstCol: Int) {
        guard gameState == .playing else { return }
        _ = attemptMove(from: .waste, toColumn: dstCol)
    }

    // MARK: - Auto-complete

    func autoComplete() {
        guard board.canAutoComplete, gameState == .playing else { return }
        // Sweep one card at a time to the correct foundation
        var changed = true
        while changed {
            changed = false
            for col in board.tableau.indices {
                guard let card = board.tableau[col].last else { continue }
                let topRank = board.foundations[card.suit.foundationIndex]
                if SolitaireRules.canPlaceOnFoundation(card, topRank: topRank) {
                    board.tableau[col].removeLast()
                    board.foundations[card.suit.foundationIndex] = card.rank
                    changed = true
                }
            }
        }
        if board.isWon { finishGame(outcome: .win) }
    }

    // MARK: - Undo

    func undo() {
        guard canUndo, let prev = history.popLast() else { return }
        board = prev
        moveCount = max(0, moveCount - 1)
        selection = nil
    }

    // MARK: - New game

    func restartCurrentDeal() {
        clearSavedState()
        board = SolitaireBoard.deal(seed: dealNumber, difficulty: difficulty)
        history = []
        moveCount = 0
        selection = nil
        gameState = .playing
        pausedElapsed = 0
        timerAnchor = .now
    }

    func startNewGame(difficulty: SolitaireDifficulty) {
        clearSavedState()
        self.difficulty = difficulty
        let deal = Int.random(in: 1...1_000_000)
        dealNumber = deal
        board = SolitaireBoard.deal(seed: deal, difficulty: difficulty)
        history = []
        moveCount = 0
        selection = nil
        gameState = .playing
        pausedElapsed = 0
        timerAnchor = .now
    }

    func pause() {
        guard gameState == .playing, let anchor = timerAnchor else { return }
        pausedElapsed += Date.now.timeIntervalSince(anchor)
        timerAnchor = nil
    }

    func resume() {
        guard gameState == .playing, timerAnchor == nil else { return }
        timerAnchor = Date.now
    }

    // MARK: - Private helpers

    @discardableResult
    private func attemptMove(from sel: SolitaireSelection, toColumn dst: Int) -> Bool {
        switch sel {
        case .column(let srcCol, let fromIdx):
            guard srcCol != dst else { selection = nil; return true }
            let cards = SolitaireRules.pickableSequence(from: board.tableau[srcCol], startingAt: fromIdx)
            guard !cards.isEmpty,
                  SolitaireRules.canPlaceOnTableau(cards, onto: board.tableau[dst]) else { return false }
            saveHistory()
            board.tableau[srcCol].removeLast(cards.count)
            flipNewTopCard(column: srcCol)
            board.tableau[dst].append(contentsOf: cards)
            moveCount += 1
            selection = nil
            return true
        case .waste:
            guard let card = board.topWaste,
                  SolitaireRules.canPlaceOnTableau([card], onto: board.tableau[dst]) else { return false }
            saveHistory()
            board.waste.removeLast()
            board.tableau[dst].append(card)
            moveCount += 1
            selection = nil
            return true
        }
    }

    @discardableResult
    private func attemptMove(from sel: SolitaireSelection, toFoundation suit: CardSuit) -> Bool {
        let card: PlayingCard
        switch sel {
        case .column(let col, let idx):
            guard idx == board.tableau[col].count - 1,
                  let top = board.tableau[col].last else { return false }
            card = top
            let topRank = board.foundations[suit.foundationIndex]
            guard card.suit == suit, SolitaireRules.canPlaceOnFoundation(card, topRank: topRank) else { return false }
            saveHistory()
            board.tableau[col].removeLast()
            flipNewTopCard(column: col)
        case .waste:
            guard let top = board.topWaste else { return false }
            card = top
            let topRank = board.foundations[suit.foundationIndex]
            guard card.suit == suit, SolitaireRules.canPlaceOnFoundation(card, topRank: topRank) else { return false }
            saveHistory()
            board.waste.removeLast()
        }
        board.foundations[suit.foundationIndex] = card.rank
        moveCount += 1
        selection = nil
        checkWin()
        return true
    }

    private func flipNewTopCard(column col: Int) {
        guard let last = board.tableau[col].last, !last.isFaceUp else { return }
        let idx = board.tableau[col].count - 1
        board.tableau[col][idx] = PlayingCard(rank: last.rank, suit: last.suit, faceUp: true)
    }

    private func saveHistory() {
        history.append(board)
        if history.count > 50 { history.removeFirst() }
        // Persist after every board mutation so background saves are always current.
        saveCurrentState()
    }

    private func checkWin() {
        guard board.isWon else { return }
        finishGame(outcome: .win)
    }

    private func finishGame(outcome: Outcome) {
        clearSavedState()
        gameState = .won
        let elapsed = pausedElapsed
        timerAnchor = nil
        Task {
            try? gameStats?.record(
                gameKind: .klondike,
                difficulty: difficulty.rawValue,
                outcome: outcome,
                durationSeconds: elapsed
            )
        }
    }
}

// MARK: - Supporting types

enum SolitaireGameState: Equatable { case playing, won }

enum SolitaireSelection: Equatable {
    case column(col: Int, fromIdx: Int)
    case waste
}

// MARK: - Save state

extension SolitaireViewModel {

    func checkAndLoadOrRestoreState() {
        let key = SolitaireSaveState.key(difficulty: difficulty)
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(SolitaireSaveState.self, from: data) {
            pendingSaveState = saved
        }
    }

    func restoreState(_ saved: SolitaireSaveState) {
        board         = saved.board
        dealNumber    = saved.dealNumber
        difficulty    = saved.difficulty
        moveCount     = saved.moveCount
        history       = []
        selection     = nil
        pausedElapsed = saved.elapsedSeconds
        timerAnchor   = Date.now
        gameState     = .playing
        pendingSaveState = nil
    }

    func discardSaveAndLoadNew() {
        clearSavedState()
    }

    func saveCurrentState() {
        guard gameState == .playing else { return }
        let elapsed = pausedElapsed + (timerAnchor.map { Date.now.timeIntervalSince($0) } ?? 0)
        let snapshot = SolitaireSaveState(
            board: board,
            dealNumber: dealNumber,
            difficulty: difficulty,
            moveCount: moveCount,
            elapsedSeconds: elapsed,
            savedAt: Date.now
        )
        let key = SolitaireSaveState.key(difficulty: difficulty)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearSavedState() {
        UserDefaults.standard.removeObject(forKey: SolitaireSaveState.key(difficulty: difficulty))
        pendingSaveState = nil
    }
}
