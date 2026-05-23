import Foundation

enum FreeCellDeal {
    static let range = 1...32_000

    // Known unsolvable deals in the 1–32 000 range.
    // Source a complete list before shipping; at minimum exclude #11982.
    static let unsolvable: Set<Int> = [11982]

    /// Microsoft FreeCell LCG shuffle — deterministic from deal number.
    /// Uses overflow arithmetic intentionally: the algorithm wraps at 31 bits.
    static func shuffle(dealNumber: Int) -> [PlayingCard] {
        var state = dealNumber
        var deck  = standardDeck()
        var result: [PlayingCard] = []
        result.reserveCapacity(52)

        for remaining in stride(from: 52, through: 1, by: -1) {
            state = (state &* 214_013 &+ 2_531_011) & 0x7FFF_FFFF
            let index = (state >> 16) % remaining
            result.append(deck.remove(at: index))
        }
        return result
    }

    /// Distribute 52 shuffled cards into 8 columns (round-robin).
    /// col[0] is top of visual column (first dealt); col.last is most accessible.
    /// Columns 0–3 receive 7 cards; columns 4–7 receive 6 cards.
    static func deal(dealNumber: Int) -> [[PlayingCard]] {
        let cards = shuffle(dealNumber: dealNumber)
        var columns: [[PlayingCard]] = Array(repeating: [], count: 8)
        for (i, card) in cards.enumerated() {
            columns[i % 8].append(card)
        }
        return columns
    }

    private static func standardDeck() -> [PlayingCard] {
        var deck: [PlayingCard] = []
        deck.reserveCapacity(52)
        for suit in CardSuit.allCases {
            for rank in CardRank.allCases {
                deck.append(PlayingCard(rank: rank, suit: suit))
            }
        }
        return deck
    }
}
