import Testing
import Foundation
@testable import gamekit

/// FreeCell earns a "show me a move" hint where Klondike does not: every card
/// is visible and essentially every deal is winnable, so a stuck board almost
/// always means the move is there and the player cannot see it.
///
/// The trap these tests guard is that *any* legal move is nearly worthless —
/// there is almost always something legal to do, and most of it is shuffling.
/// The suggestion has to be legal, and it has to be worth making.
@Suite("FreeCell hint")
@MainActor
struct FreeCellHintTests {

    private func board(deal: Int = 1) -> FreeCellBoard {
        FreeCellBoard(dealNumber: deal)
    }

    @Test("a fresh deal always has something to suggest")
    func freshDealHasAMove() {
        #expect(FreeCellHint.nextMove(board: board()) != nil)
    }

    @Test("the suggested move is actually legal")
    func suggestionIsLegal() throws {
        for deal in 1...25 {
            let b = board(deal: deal)
            guard let suggestion = FreeCellHint.nextMove(board: b) else { continue }
            switch suggestion.move {
            case .toFoundation(let card, _):
                #expect(FreeCellRules.canMoveToFoundation(card, foundations: b.foundations))
            case .columnToColumn(let card, let from, let to):
                #expect(b.columns[from].last == card)
                #expect(FreeCellRules.canPlace(card, onto: b.columns[to]))
            case .freeCellToColumn(let card, let cell, let to):
                #expect(b.freeCells[cell] == card)
                #expect(FreeCellRules.canPlace(card, onto: b.columns[to]))
            case .columnToFreeCell(let card, let from, let cell):
                #expect(b.columns[from].last == card)
                #expect(b.freeCells[cell] == nil)
            }
        }
    }

    /// The rule that stops a hint from ruining a winnable deal: never bank a
    /// card an opposite-colour card still needs as a landing spot.
    @Test("a foundation suggestion is never an unsafe bank")
    func foundationSuggestionsAreSafe() {
        for deal in 1...40 {
            let b = board(deal: deal)
            guard let suggestion = FreeCellHint.nextMove(board: b),
                  case .toFoundation(let card, _) = suggestion.move else { continue }
            // Aces and twos are always safe; anything higher needs both
            // opposite-colour foundations up to rank - 1.
            if card.rank == .ace || card.rank == .two { continue }
            let needed = card.rank.rawValue - 1
            let opposite: [Int] = card.suit.isRed ? [0, 3] : [1, 2]
            for index in opposite {
                #expect((b.foundations[index]?.rawValue ?? 0) >= needed)
            }
        }
    }

    /// Parking spends the resource the whole game rations, so it must only
    /// appear when nothing better exists.
    @Test("parking in a free cell is only ever a last resort")
    func parkingIsLastResort() {
        for deal in 1...40 {
            let b = board(deal: deal)
            guard let suggestion = FreeCellHint.nextMove(board: b),
                  case .columnToFreeCell = suggestion.move else { continue }
            // If parking was chosen, no tableau or foundation move existed.
            #expect(suggestion.reason == .parksToFreeCell)
            for (index, column) in b.columns.enumerated() {
                guard let card = column.last else { continue }
                for (dst, target) in b.columns.enumerated() where dst != index {
                    #expect(FreeCellRules.canPlace(card, onto: target) == false)
                }
            }
        }
    }

    @Test("every reason has copy, and it names the card")
    func copyCoversEveryReason() {
        let card = PlayingCard(rank: .nine, suit: .hearts, faceUp: true)
        let moves: [FreeCellHint.Suggestion] = [
            .init(move: .toFoundation(card: card, fromColumn: 0), reason: .safeToFoundation),
            .init(move: .freeCellToColumn(card: card, cell: 0, to: 1), reason: .unburies),
            .init(move: .columnToColumn(card: card, from: 0, to: 1), reason: .unburies),
            .init(move: .columnToColumn(card: card, from: 0, to: 1), reason: .buildsSequence),
            .init(move: .columnToFreeCell(card: card, from: 0, cell: 0), reason: .parksToFreeCell)
        ]
        for suggestion in moves {
            let text = FreeCellHintCopy.text(for: suggestion)
            #expect(text.isEmpty == false)
            #expect(text.contains("9 of hearts"))
            // Column indices make the player count; card names do not.
            #expect(text.contains("column 0") == false)
        }
    }

    // MARK: - View-model wiring

    private func viewModel() -> FreeCellViewModel {
        FreeCellViewModel(mode: .deal(1))
    }

    @Test("asking produces a suggestion and counts an assist")
    func requestCounts() {
        let vm = viewModel()
        #expect(vm.assistsUsed == 0)
        vm.requestHint()
        #expect(vm.hintText != nil)
        #expect(vm.assistsUsed == 1)
    }

    @Test("a request never changes the board")
    func requestDoesNotMutate() {
        let vm = viewModel()
        // FreeCellBoard is not Equatable; compare the parts that a move
        // would necessarily disturb.
        let columnsBefore = vm.board.columns.map { $0.map(\.id) }
        let cellsBefore = vm.board.freeCells.map { $0?.id }
        let foundationsBefore = vm.board.foundations
        vm.requestHint()
        #expect(vm.board.columns.map { $0.map(\.id) } == columnsBefore)
        #expect(vm.board.freeCells.map { $0?.id } == cellsBefore)
        #expect(vm.board.foundations == foundationsBefore)
    }

    @Test("a new deal resets the assist count")
    func resetClearsAssists() {
        let vm = viewModel()
        vm.requestHint()
        #expect(vm.assistsUsed == 1)
        vm.reset()
        #expect(vm.assistsUsed == 0)
        #expect(vm.hintText == nil)
    }
}
