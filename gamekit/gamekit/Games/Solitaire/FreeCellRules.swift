import Foundation

// Pure static validation — no state, no SwiftUI.

enum FreeCellRules {

    // MARK: - Column placement

    /// Card can land on `column` top if alternating color and one rank lower.
    /// Empty column always accepts.
    static func canPlace(_ card: PlayingCard, onto column: [PlayingCard]) -> Bool {
        guard let top = column.last else { return true }
        return card.suit.isRed != top.suit.isRed
            && card.rank.rawValue + 1 == top.rank.rawValue
    }

    // MARK: - Foundation

    static func canMoveToFoundation(_ card: PlayingCard, foundations: [CardRank?]) -> Bool {
        let idx = foundationIndex(for: card.suit)
        if let top = foundations[idx] {
            return card.rank.rawValue == top.rawValue + 1
        }
        return card.rank == .ace
    }

    // MARK: - Sequence validity

    /// True when cards form a valid FreeCell sequence: alternating color,
    /// strictly descending rank from index 0 (top) to last (bottom).
    static func isValidSequence(_ cards: [PlayingCard]) -> Bool {
        guard cards.count > 1 else { return true }
        return zip(cards, cards.dropFirst()).allSatisfy { upper, lower in
            upper.suit.isRed != lower.suit.isRed
                && upper.rank.rawValue == lower.rank.rawValue + 1
        }
    }

    // MARK: - Supermove

    /// Maximum cards moveable as one gesture given current free-cell and
    /// empty-column count.
    /// `toEmptyColumn`: the destination is an empty column, which does NOT
    /// count as a staging slot.
    static func maxMoveable(board: FreeCellBoard, toEmptyColumn: Bool) -> Int {
        let freeCells  = board.emptyFreeCellCount
        let emptyCols  = board.emptyColumnCount - (toEmptyColumn ? 1 : 0)
        return (freeCells + 1) * Int(pow(2.0, Double(max(0, emptyCols))))
    }

    // MARK: - Loss detection

    /// True when no legal move exists anywhere on the board.
    static func isLost(board: FreeCellBoard) -> Bool {
        // Any empty free cell or column always provides a legal move.
        if board.emptyFreeCellCount > 0 || board.emptyColumnCount > 0 { return false }

        // Check column bottoms
        for (colIdx, col) in board.columns.enumerated() {
            guard let card = col.last else { continue }
            if canMoveToFoundation(card, foundations: board.foundations) { return false }
            for (dstIdx, dst) in board.columns.enumerated() where dstIdx != colIdx {
                if canPlace(card, onto: dst) { return false }
            }
        }
        // Check free cell cards
        for cell in board.freeCells {
            guard let card = cell else { continue }
            if canMoveToFoundation(card, foundations: board.foundations) { return false }
            for col in board.columns where canPlace(card, onto: col) { return false }
        }
        return true
    }

    // MARK: - Private

    private static func foundationIndex(for suit: CardSuit) -> Int {
        switch suit {
        case .spades: return 0; case .hearts: return 1
        case .diamonds: return 2; case .clubs: return 3
        }
    }
}
