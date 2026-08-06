import Foundation
import Observation
import SwiftUI

// FreeCellSelection + FreeCellGameState live in FreeCellSelection.swift.

// MARK: - ViewModel

@Observable @MainActor
final class FreeCellViewModel {

    // MARK: - Public state

    private(set) var board:      FreeCellBoard
    private(set) var dealNumber: Int
    private(set) var difficulty: FreeCellDifficulty?   // nil = Deal # mode
    private(set) var gameState:  FreeCellGameState = .idle
    private(set) var selection:  FreeCellSelection? = nil

    // Timer (clock-based, matches project pattern)
    private(set) var timerAnchor:   Date?          = nil
    private(set) var pausedElapsed: TimeInterval   = 0
    private(set) var frozenElapsed: TimeInterval   = 0

    // Haptic counter-triggers (DESIGN.md §8)
    private(set) var selectTick  = 0
    private(set) var dropTick    = 0
    private(set) var rejectTick  = 0
    private(set) var winTick     = 0

    private(set) var isAutoCompleting = false
    private(set) var hintText: String? = nil
    private(set) var activeHint: FreeCellHint.Suggestion? = nil

    // Stats write-side firewall
    var gameStats: GameStats?

    // Save state prompt
    private(set) var pendingSaveState: FreeCellSaveState?

    // MARK: - Private

    private var history: [FreeCellMove] = []
    private var rejectStreak = 0

    // MARK: - Init

    init(mode: FreeCellMode) {
        let dn = Self.resolveDealNumber(mode: mode)
        dealNumber = dn
        board = FreeCellBoard(dealNumber: dn)
        difficulty = { if case .random(let d) = mode { return d } else { return nil } }()
    }

    private static func resolveDealNumber(mode: FreeCellMode) -> Int {
        switch mode {
        case .random(let d): return FreeCellDifficultyIndex.randomDealNumber(difficulty: d)
        case .deal(let n):   return max(1, min(32_000, n))
        case .enterDeal:     return 1  // replaced immediately by deal-entry sheet
        }
    }

    // MARK: - Timer

    var displayElapsed: TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, Date.now.timeIntervalSince(anchor))
    }

    func pause() {
        guard gameState == .playing, let anchor = timerAnchor else { return }
        pausedElapsed += max(0, Date.now.timeIntervalSince(anchor))
        timerAnchor = nil
    }

    func resume() {
        guard gameState == .playing, timerAnchor == nil else { return }
        timerAnchor = Date.now
    }

    private func startTimer() {
        guard gameState == .idle else { return }
        gameState   = .playing
        timerAnchor = Date.now
    }

    private func freezeTimer() {
        if let anchor = timerAnchor {
            pausedElapsed += max(0, Date.now.timeIntervalSince(anchor))
        }
        frozenElapsed = pausedElapsed
        timerAnchor   = nil
    }

    // MARK: - Derived selection info

    var selectedCards: [PlayingCard] {
        guard let sel = selection else { return [] }
        switch sel {
        case .column(let col, let idx): return Array(board.columns[col][idx...])
        case .freeCell(let cell):       return board.freeCells[cell].map { [$0] } ?? []
        case .foundation(let suit):
            let idx = board.foundationIndex(for: suit)
            guard let rank = board.foundations[idx] else { return [] }
            return [PlayingCard(rank: rank, suit: suit)]
        }
    }

    var validColumnTargets: Set<Int> {
        guard let cards = selectedCards.first else { return [] }
        let count = selectedCards.count
        return Set(board.columns.indices.filter { dstCol in
            guard !isSourceColumn(dstCol) else { return false }
            let dst = board.columns[dstCol]
            guard FreeCellRules.canPlace(cards, onto: dst) else { return false }
            let limit = FreeCellRules.maxMoveable(board: board, toEmptyColumn: dst.isEmpty)
            return count <= limit
        })
    }

    var validFreeCellTargets: Set<Int> {
        guard selectedCards.count == 1 else { return [] }
        return Set(board.freeCells.indices.filter { board.freeCells[$0] == nil })
    }

    var canMoveSelectionToFoundation: Bool {
        guard selectedCards.count == 1, let card = selectedCards.first else { return false }
        return FreeCellRules.canMoveToFoundation(card, foundations: board.foundations)
    }

    /// Undo stays available in `.lost`. It used to require `.playing`, which
    /// switched off the one tool that could rescue the player at exactly the
    /// moment they needed it. FreeCell deals are near-always winnable, so a
    /// dead board almost always means a recoverable misplay.
    var canUndo: Bool { !history.isEmpty && (gameState == .playing || gameState == .lost) }

    /// A dead board the player has not yet acknowledged. Held rather than
    /// written, because undo can now revive it and one deal must not produce
    /// both a loss and a win. Mirrors SolitaireViewModel.pendingLossElapsed.
    private var hasPendingLoss = false

    func clearSelection() { selection = nil; rejectStreak = 0 }
    func dismissHint() {
        hintText = nil
        activeHint = nil
        selection = nil
    }

    /// Assists asked for on this deal.
    private(set) var assistsUsed: Int = 0

    /// Suggest a move worth making.
    ///
    /// Reuses the toast that already existed for the frustration counter, so
    /// the deliberate ask and the automatic nudge speak in the same voice and
    /// from the same place on screen.
    func requestHint() {
        guard gameState == .playing || gameState == .idle else { return }
        guard let suggestion = FreeCellHint.nextMove(board: board, previousMove: history.last) else {
            activeHint = nil
            hintText = String(localized: "No move left to suggest on this board.")
            return
        }
        activeHint = suggestion
        hintText = FreeCellHintCopy.text(for: suggestion)
        selection = hintSelection(for: suggestion.move)
        assistsUsed += 1
        saveCurrentState()
    }

    func applyHint() {
        guard let suggestion = activeHint,
              let source = hintSelection(for: suggestion.move) else { return }
        let destination = hintDestination(for: suggestion.move)
        _ = attemptMove(from: source, to: destination)
    }

    private func hintSelection(for move: FreeCellHint.Move) -> FreeCellSelection? {
        switch move {
        case .columnToFoundation(_, let from),
             .columnToColumn(_, let from, _),
             .columnToFreeCell(_, let from, _):
            guard let index = board.columns[from].indices.last else { return nil }
            return .column(colIdx: from, startCardIdx: index)
        case .sequenceToColumn(let cards, let from, _):
            let start = board.columns[from].count - cards.count
            guard start >= 0 else { return nil }
            return .column(colIdx: from, startCardIdx: start)
        case .freeCellToFoundation(_, let cell), .freeCellToColumn(_, let cell, _):
            return .freeCell(cellIdx: cell)
        }
    }

    private func hintDestination(for move: FreeCellHint.Move) -> FreeCellDest {
        switch move {
        case .columnToFoundation, .freeCellToFoundation: return .foundation
        case .columnToColumn(_, _, let to), .freeCellToColumn(_, _, let to): return .column(to)
        case .sequenceToColumn(_, _, let to): return .column(to)
        case .columnToFreeCell(_, _, let cell): return .freeCell(cell)
        }
    }

    var activeHintDestination: FreeCellDest? {
        activeHint.map { hintDestination(for: $0.move) }
    }

    @discardableResult
    func applyDragDrop(from sel: FreeCellSelection, to dest: FreeCellDest) -> Bool {
        attemptMove(from: sel, to: dest)
    }

    // MARK: - Tap interactions

    func tapColumnCard(colIdx: Int, cardIdx: Int) {
        let col = board.columns[colIdx]
        guard cardIdx < col.count else { return }
        let tappedCards = Array(col[cardIdx...])

        if let sel = selection {
            // Attempt move from selection to this column
            if attemptMove(from: sel, to: .column(colIdx)) { return }
            // If the tapped range is a valid sequence, switch selection
            if FreeCellRules.isValidSequence(tappedCards), canPickUp(cards: tappedCards) {
                selection  = .column(colIdx: colIdx, startCardIdx: cardIdx)
                selectTick += 1
            } else {
                selection = nil
            }
        } else {
            guard FreeCellRules.isValidSequence(tappedCards), canPickUp(cards: tappedCards) else {
                rejectTick  += 1
                rejectStreak += 1
                if rejectStreak >= 5 {
                    let limit = FreeCellRules.maxMoveable(board: board, toEmptyColumn: false)
                    if tappedCards.count > limit {
                        hintText = board.emptyFreeCellCount == 0
                            ? "No free cells — move one card at a time"
                            : "Free more cells to pick up that stack"
                    } else {
                        hintText = "Cards aren't in sequence"
                    }
                    rejectStreak = 0
                }
                return
            }
            selection    = .column(colIdx: colIdx, startCardIdx: cardIdx)
            selectTick  += 1
            rejectStreak = 0
        }
    }

    func tapFreeCell(cellIdx: Int) {
        if let sel = selection {
            if attemptMove(from: sel, to: .freeCell(cellIdx)) { return }
            // Tap on an occupied free cell → switch selection
            if board.freeCells[cellIdx] != nil {
                selection  = .freeCell(cellIdx: cellIdx)
                selectTick += 1
            } else {
                selection = nil
            }
        } else {
            guard board.freeCells[cellIdx] != nil else { return }
            selection  = .freeCell(cellIdx: cellIdx)
            selectTick += 1
        }
    }

    func tapEmptyColumn(colIdx: Int) {
        guard let sel = selection else { return }
        _ = attemptMove(from: sel, to: .column(colIdx))
    }

    func tapFoundation(suit: CardSuit) {
        // Foundation card already selected — deselect same, switch to other
        if case .foundation(let s) = selection {
            if s == suit {
                selection = nil
            } else {
                let idx = board.foundationIndex(for: suit)
                selection = board.foundations[idx] != nil ? .foundation(suit: suit) : nil
            }
            return
        }

        // Non-foundation selection → try to move it to this foundation
        if let sel = selection {
            if attemptMove(from: sel, to: .foundation) { return }
            // Move failed — fall through to select this foundation
        }

        // Select the top foundation card (if any)
        let idx = board.foundationIndex(for: suit)
        selection = board.foundations[idx] != nil ? .foundation(suit: suit) : nil
    }

    /// Double-tap shortcut: auto-move bottom card of column to foundation.
    func doubleTapColumnCard(colIdx: Int) {
        guard let card = board.columns[colIdx].last,
              FreeCellRules.canMoveToFoundation(card, foundations: board.foundations) else {
            rejectTick += 1; return
        }
        let sel = FreeCellSelection.column(colIdx: colIdx, startCardIdx: board.columns[colIdx].count - 1)
        _ = attemptMove(from: sel, to: .foundation)
    }

    func doubleTapFreeCell(cellIdx: Int) {
        guard let card = board.freeCells[cellIdx],
              FreeCellRules.canMoveToFoundation(card, foundations: board.foundations) else {
            rejectTick += 1; return
        }
        _ = attemptMove(from: .freeCell(cellIdx: cellIdx), to: .foundation)
    }

    // MARK: - Undo / Reset / New game

    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        let wasLost = gameState == .lost
        board     = last.boardBefore
        selection = nil
        if wasLost {
            // Backing out of a dead board returns the deal to play, drops the
            // held loss, and restarts the clock from where it froze.
            hasPendingLoss = false
            gameState     = .playing
            frozenElapsed = 0
            timerAnchor   = Date.now
            saveCurrentState()
            return
        }
        if history.isEmpty { timerAnchor = nil; pausedElapsed = 0 }
        saveCurrentState()   // keep the persisted stack in step with undo
    }

    #if DEBUG
    /// Drives the deal into `.lost` without constructing a genuinely dead
    /// board. `withHistory` pushes one reversible move so undo has something
    /// to pop, which is the case these tests exist to cover.
    func forceLostForTests(withHistory: Bool) {
        if withHistory, history.isEmpty {
            history.append(
                FreeCellMove(
                    cards: [],
                    source: .freeCell(cellIdx: 0),
                    destination: .foundation,
                    boardBefore: board
                )
            )
        }
        freezeTimer()
        gameState = .lost
        hasPendingLoss = true
    }
    #endif

    /// Writes a held loss, if there is one. Called when the player accepts the
    /// dead board by moving on, or leaves the screen with it unresolved.
    func flushPendingLoss() {
        guard hasPendingLoss else { return }
        hasPendingLoss = false
        clearSavedState()
        recordResult(outcome: "loss")
    }

    func reset() {
        flushPendingLoss()   // moving on is accepting the dead board
        assistsUsed = 0
        hintText = nil
        activeHint = nil
        clearSavedState()
        board         = FreeCellBoard(dealNumber: dealNumber)
        history       = []
        selection     = nil
        timerAnchor   = nil
        pausedElapsed = 0
        frozenElapsed = 0
        gameState     = .idle
    }

    func startNewGame(mode: FreeCellMode) {
        dealNumber = Self.resolveDealNumber(mode: mode)
        difficulty = { if case .random(let d) = mode { return d } else { return nil } }()
        reset()
    }

    // MARK: - Auto-complete

    func beginAutoCompleteAnimation() {
        guard board.canAutoComplete, gameState == .playing, !isAutoCompleting else { return }
        isAutoCompleting = true
        Task { @MainActor in
            while gameState == .playing {
                var moved = false
                for i in board.columns.indices {
                    if let card = board.columns[i].last,
                       FreeCellRules.canMoveToFoundation(card, foundations: board.foundations) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            board.columns[i].removeLast()
                            board.advanceFoundation(for: card.suit)
                        }
                        moved = true
                        break
                    }
                }
                if !moved {
                    for i in board.freeCells.indices {
                        if let card = board.freeCells[i],
                           FreeCellRules.canMoveToFoundation(card, foundations: board.foundations) {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                board.freeCells[i] = nil
                                board.advanceFoundation(for: card.suit)
                            }
                            moved = true
                            break
                        }
                    }
                }
                if !moved { break }
                if board.isWon { checkTerminalState(); break }
                try? await Task.sleep(for: .milliseconds(80))
            }
            isAutoCompleting = false
        }
    }

    // MARK: - Private move logic

    @discardableResult
    private func attemptMove(from sel: FreeCellSelection, to dst: FreeCellDest) -> Bool {
        let cards = cards(for: sel)
        guard !cards.isEmpty else { return false }

        switch dst {
        case .column(let dstCol):
            guard !isSourceColumn(dstCol, sel: sel) else { return false }
            let dstCards = board.columns[dstCol]
            guard let top = cards.first,
                  FreeCellRules.canPlace(top, onto: dstCards) else { return false }
            let limit = FreeCellRules.maxMoveable(board: board, toEmptyColumn: dstCards.isEmpty)
            guard cards.count <= limit else { rejectTick += 1; selection = nil; return false }
            applyMove(cards: cards, source: source(for: sel), dest: dst)
            return true

        case .freeCell(let cellIdx):
            guard cards.count == 1, board.freeCells[cellIdx] == nil else { return false }
            applyMove(cards: cards, source: source(for: sel), dest: dst)
            return true

        case .foundation:
            guard cards.count == 1, let card = cards.first,
                  FreeCellRules.canMoveToFoundation(card, foundations: board.foundations) else {
                return false
            }
            applyMove(cards: cards, source: source(for: sel), dest: dst)
            return true
        }
    }

    private func applyMove(cards: [PlayingCard], source: FreeCellSource, dest: FreeCellDest) {
        let snap = board  // snapshot before mutation
        startTimer()

        switch (source, dest) {
        case (.column(let col, let idx), .column(let dst)):
            board.columns[col].removeSubrange(idx...)
            board.columns[dst].append(contentsOf: cards)
        case (.column(let col, _), .freeCell(let cell)):
            board.columns[col].removeLast()
            board.freeCells[cell] = cards[0]
        case (.column(let col, _), .foundation):
            board.columns[col].removeLast()
            board.advanceFoundation(for: cards[0].suit)
        case (.freeCell(let cell), .column(let dst)):
            board.freeCells[cell] = nil
            board.columns[dst].append(cards[0])
        case (.freeCell(let cell), .foundation):
            board.freeCells[cell] = nil
            board.advanceFoundation(for: cards[0].suit)
        case (.freeCell(let src), .freeCell(let dst)):
            board.freeCells[src] = nil
            board.freeCells[dst] = cards[0]
        case (.foundation(let suit), .column(let dst)):
            board.regressFoundation(for: suit)
            board.columns[dst].append(cards[0])
        case (.foundation(let suit), .freeCell(let cell)):
            board.regressFoundation(for: suit)
            board.freeCells[cell] = cards[0]
        default: return
        }

        history.append(FreeCellMove(cards: cards, source: source, destination: dest, boardBefore: snap))
        selection    = nil
        rejectStreak = 0
        hintText     = nil
        activeHint   = nil
        dropTick    += 1
        checkTerminalState()
        if gameState == .playing { saveCurrentState() }
    }

    private func checkTerminalState() {
        if board.isWon {
            clearSavedState()
            freezeTimer()
            gameState = .won
            winTick += 1
            recordResult(outcome: "win")
        } else if FreeCellRules.isLost(board: board) {
            freezeTimer()
            gameState = .lost
            // Held, not written — see `hasPendingLoss`. The saved state is
            // kept too: undo can revive this deal, so discarding it would
            // destroy a game the player has not finished with.
            hasPendingLoss = true
        }
    }

    private func recordResult(outcome: String) {
        let diff = difficulty?.rawValue ?? "deal"
        try? gameStats?.record(
            gameKind: .freeCell,
            difficulty: diff,
            outcome: outcome == "win" ? .win : .loss,
            durationSeconds: frozenElapsed,
            puzzleId: "deal-\(dealNumber)",
            assistCount: assistsUsed
        )
    }

    // MARK: - Helpers

    private func canPickUp(cards: [PlayingCard]) -> Bool {
        guard !cards.isEmpty else { return false }
        let limit = FreeCellRules.maxMoveable(board: board, toEmptyColumn: false)
        if cards.count > limit { return false }
        // Single card always pickable; sequences need validation
        return cards.count == 1 || FreeCellRules.isValidSequence(cards)
        // Also allow picking up if it can go to a free cell
        || (cards.count == 1 && board.emptyFreeCellCount > 0)
    }

    private func cards(for sel: FreeCellSelection) -> [PlayingCard] {
        switch sel {
        case .column(let col, let idx): return Array(board.columns[col][idx...])
        case .freeCell(let cell):       return board.freeCells[cell].map { [$0] } ?? []
        case .foundation(let suit):
            let idx = board.foundationIndex(for: suit)
            guard let rank = board.foundations[idx] else { return [] }
            return [PlayingCard(rank: rank, suit: suit)]
        }
    }

    private func source(for sel: FreeCellSelection) -> FreeCellSource {
        switch sel {
        case .column(let col, let idx): return .column(colIdx: col, startIdx: idx)
        case .freeCell(let cell):       return .freeCell(cellIdx: cell)
        case .foundation(let suit):     return .foundation(suit: suit)
        }
    }

    private func isSourceColumn(_ colIdx: Int, sel: FreeCellSelection? = nil) -> Bool {
        let s = sel ?? selection
        if case .column(let src, _) = s { return src == colIdx }
        return false
    }

    // MARK: - Save state

    func checkAndLoadOrRestoreState() {
        let key = FreeCellSaveState.currentKey
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(FreeCellSaveState.self, from: data) {
            pendingSaveState = saved
        }
    }

    func restoreState(_ saved: FreeCellSaveState) {
        board         = saved.board
        dealNumber    = saved.dealNumber
        difficulty    = saved.difficulty.flatMap { FreeCellDifficulty(rawValue: $0) }
        // Undo now survives a relaunch. Older saves carry no history and
        // decode to nil, restoring the previous behaviour for them.
        history       = saved.history ?? []
        assistsUsed   = saved.assistsUsed ?? 0
        selection     = nil
        pausedElapsed = saved.elapsedSeconds
        frozenElapsed = 0
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
        let snapshot = FreeCellSaveState(
            board: board,
            dealNumber: dealNumber,
            difficulty: difficulty?.rawValue,
            elapsedSeconds: elapsed,
            savedAt: Date.now,
            history: Array(history.suffix(FreeCellSaveState.persistedHistoryDepth)),
            assistsUsed: assistsUsed
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: FreeCellSaveState.currentKey)
        }
    }

    func clearSavedState() {
        UserDefaults.standard.removeObject(forKey: FreeCellSaveState.currentKey)
        pendingSaveState = nil
    }
}
