//
//  FreeCellHint.swift
//  gamekit
//
//  Suggests a move worth making.
//
//  FreeCell earns a "show me a move" hint where Klondike does not: every card
//  is visible, there is no stock to draw from, and essentially every deal is
//  winnable — so a stuck board almost always means a move is there and the
//  player cannot see it, rather than a dead deal.
//
//  The trap is that *any* legal move is close to worthless. There is almost
//  always something legal to do, and most of it is shuffling. So this ranks
//  by what a move actually achieves and never suggests one that only undoes
//  the position it came from.
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4).
//

import Foundation

enum FreeCellHint {

    enum Move: Equatable {
        case toFoundation(card: PlayingCard, fromColumn: Int?)
        case columnToColumn(card: PlayingCard, from: Int, to: Int)
        case freeCellToColumn(card: PlayingCard, cell: Int, to: Int)
        case columnToFreeCell(card: PlayingCard, from: Int, cell: Int)
    }

    struct Suggestion: Equatable {
        let move: Move
        /// Why this move is worth making, for the copy layer.
        let reason: Reason
    }

    enum Reason: Equatable {
        /// Safe to bank — no lower card of the opposite colour still needs it.
        case safeToFoundation
        /// Frees a card that was buried, or empties a column outright.
        case unburies
        /// Ordinary progress: a legal tableau move that keeps a sequence.
        case buildsSequence
        /// Parks a card to open the board up. Last resort — it spends a cell.
        case parksToFreeCell
    }

    /// The best available move, or nil when the board offers none.
    static func nextMove(board: FreeCellBoard) -> Suggestion? {
        var best: (rank: Int, suggestion: Suggestion)?

        func consider(_ suggestion: Suggestion, rank: Int) {
            if best == nil || rank < best!.rank {
                best = (rank, suggestion)
            }
        }

        // 1. Foundation moves that are provably safe.
        for (index, column) in board.columns.enumerated() {
            guard let card = column.last else { continue }
            if FreeCellRules.canMoveToFoundation(card, foundations: board.foundations),
               isSafeToBank(card, foundations: board.foundations) {
                consider(
                    Suggestion(move: .toFoundation(card: card, fromColumn: index), reason: .safeToFoundation),
                    rank: 0
                )
            }
        }
        for (cellIndex, cell) in board.freeCells.enumerated() {
            guard let card = cell else { continue }
            if FreeCellRules.canMoveToFoundation(card, foundations: board.foundations),
               isSafeToBank(card, foundations: board.foundations) {
                _ = cellIndex
                consider(
                    Suggestion(move: .toFoundation(card: card, fromColumn: nil), reason: .safeToFoundation),
                    rank: 0
                )
            }
        }

        // 2. Free cell back onto the tableau — always progress, it returns a cell.
        for (cellIndex, cell) in board.freeCells.enumerated() {
            guard let card = cell else { continue }
            for (dstIndex, dst) in board.columns.enumerated()
            where FreeCellRules.canPlace(card, onto: dst) {
                consider(
                    Suggestion(
                        move: .freeCellToColumn(card: card, cell: cellIndex, to: dstIndex),
                        reason: .unburies
                    ),
                    rank: 1
                )
            }
        }

        // 3. Column to column. Ranked by whether it actually achieves
        //    something: emptying a column outright beats uncovering a card,
        //    which beats a plain sequence build.
        for (srcIndex, src) in board.columns.enumerated() {
            guard let card = src.last else { continue }
            for (dstIndex, dst) in board.columns.enumerated() where dstIndex != srcIndex {
                guard FreeCellRules.canPlace(card, onto: dst) else { continue }
                // Moving the only card out of a column empties it.
                if src.count == 1 {
                    consider(
                        Suggestion(
                            move: .columnToColumn(card: card, from: srcIndex, to: dstIndex),
                            reason: .unburies
                        ),
                        rank: 2
                    )
                } else {
                    consider(
                        Suggestion(
                            move: .columnToColumn(card: card, from: srcIndex, to: dstIndex),
                            reason: .buildsSequence
                        ),
                        rank: 3
                    )
                }
            }
        }

        // 4. Parking in a free cell. Genuinely a last resort: it spends the
        //    resource the whole game is rationing, so it is only suggested
        //    when nothing above it exists.
        if best == nil, board.emptyFreeCellCount > 0,
           let cellIndex = board.freeCells.firstIndex(where: { $0 == nil }) {
            for (srcIndex, src) in board.columns.enumerated() {
                guard let card = src.last, src.count > 1 else { continue }
                consider(
                    Suggestion(
                        move: .columnToFreeCell(card: card, from: srcIndex, cell: cellIndex),
                        reason: .parksToFreeCell
                    ),
                    rank: 4
                )
                break
            }
        }

        return best?.suggestion
    }

    /// A card is safe to bank when no card that might still need it as a
    /// landing spot remains in play — the standard FreeCell autoplay rule.
    /// Without this the hint would happily bank a red 5 that a black 4 still
    /// needs, which is how a winnable deal becomes unwinnable.
    private static func isSafeToBank(_ card: PlayingCard, foundations: [CardRank?]) -> Bool {
        if card.rank == .ace || card.rank == .two { return true }
        let needed = card.rank.rawValue - 1
        let oppositeSuits: [CardSuit] = card.suit.isRed ? [.spades, .clubs] : [.hearts, .diamonds]
        for suit in oppositeSuits {
            let index = foundationIndex(for: suit)
            let top = foundations[index]?.rawValue ?? 0
            if top < needed { return false }
        }
        return true
    }

    private static func foundationIndex(for suit: CardSuit) -> Int {
        switch suit {
        case .spades: return 0
        case .hearts: return 1
        case .diamonds: return 2
        case .clubs: return 3
        }
    }
}
