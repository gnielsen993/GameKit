import Foundation

// Pure static validation — no state, no SwiftUI.
enum SolitaireRules {

    // MARK: - Tableau placement

    /// Cards (a sequence, bottom card = cards[0]) can land on `column` top.
    /// Empty column accepts only a King as the bottom card.
    static func canPlaceOnTableau(_ cards: [PlayingCard], onto column: [PlayingCard]) -> Bool {
        guard let bottom = cards.first else { return false }
        if column.isEmpty { return bottom.rank == .king }
        guard let top = column.last, top.isFaceUp else { return false }
        return bottom.suit.isRed != top.suit.isRed
            && bottom.rank.rawValue + 1 == top.rank.rawValue
    }

    // MARK: - Foundation placement

    static func canPlaceOnFoundation(_ card: PlayingCard, topRank: CardRank?) -> Bool {
        if let top = topRank {
            return card.rank.rawValue == top.rawValue + 1
        }
        return card.rank == .ace
    }

    // MARK: - Sequence validity

    /// True when all cards are face-up, alternating color, strictly descending.
    static func isValidSequence(_ cards: [PlayingCard]) -> Bool {
        guard cards.count > 1 else { return cards.first?.isFaceUp == true }
        return zip(cards, cards.dropFirst()).allSatisfy { upper, lower in
            upper.isFaceUp && lower.isFaceUp
            && upper.suit.isRed != lower.suit.isRed
            && upper.rank.rawValue == lower.rank.rawValue + 1
        }
    }

    // MARK: - Pickable sequence from a column

    /// Returns the longest valid movable sequence from the bottom of the
    /// face-up run at the end of `column`, starting at `fromIndex`.
    static func pickableSequence(from column: [PlayingCard], startingAt fromIndex: Int) -> [PlayingCard] {
        let slice = Array(column[fromIndex...])
        guard isValidSequence(slice) else { return [] }
        return slice
    }
}
