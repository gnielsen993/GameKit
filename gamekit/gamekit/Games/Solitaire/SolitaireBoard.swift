import Foundation

// Pure value type — no SwiftUI, no side effects.
struct SolitaireBoard: Codable {

    // MARK: - State

    var tableau:     [[PlayingCard]]     // 7 columns, index 0 = leftmost
    var foundations: [CardRank?]         // 4 slots indexed by CardSuit.foundationIndex
    var stock:       [PlayingCard]       // face-down draw pile (last = top)
    var waste:       [PlayingCard]       // face-up discard pile (last = top/playable)

    // MARK: - Computed

    var isWon: Bool {
        foundations.allSatisfy { $0 == .king }
    }

    var stockIsEmpty: Bool { stock.isEmpty }

    var topWaste: PlayingCard? { waste.last }

    func foundationTop(for suit: CardSuit) -> CardRank? {
        foundations[suit.foundationIndex]
    }

    // All tableau face-up and stock+waste empty — auto-complete eligible.
    var canAutoComplete: Bool {
        stock.isEmpty && waste.isEmpty
        && tableau.allSatisfy { col in col.allSatisfy { $0.isFaceUp } }
    }

    // MARK: - Factory

    static func deal(seed: Int, difficulty: SolitaireDifficulty) -> SolitaireBoard {
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(seed)))
        var deck = Self.fullDeck().shuffled(using: &rng)

        var tableau: [[PlayingCard]] = (0..<7).map { _ in [] }
        for col in 0..<7 {
            for row in 0...col {
                var card = deck.removeLast()
                card = PlayingCard(rank: card.rank, suit: card.suit, faceUp: row == col)
                tableau[col].append(card)
            }
        }
        let stock = deck.map { PlayingCard(rank: $0.rank, suit: $0.suit, faceUp: false) }
        return SolitaireBoard(
            tableau: tableau,
            foundations: [nil, nil, nil, nil],
            stock: stock,
            waste: []
        )
    }

    private static func fullDeck() -> [PlayingCard] {
        CardSuit.allCases.flatMap { suit in
            CardRank.allCases.map { rank in PlayingCard(rank: rank, suit: suit, faceUp: false) }
        }
    }
}

// MARK: - CardSuit foundation index

extension CardSuit {
    var foundationIndex: Int {
        switch self {
        case .spades:   return 0
        case .hearts:   return 1
        case .diamonds: return 2
        case .clubs:    return 3
        }
    }
}

