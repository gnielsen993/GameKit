import Foundation

// MARK: - CardRank

enum CardRank: Int, CaseIterable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king

    var display: String {
        switch self {
        case .ace:   return "A"
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        default:     return "\(rawValue)"
        }
    }

    var isFace: Bool { self == .jack || self == .queen || self == .king }
}

// MARK: - CardSuit

enum CardSuit: CaseIterable {
    case spades, hearts, diamonds, clubs

    var sfSymbol: String {
        switch self {
        case .spades:   return "suit.spade.fill"
        case .hearts:   return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs:    return "suit.club.fill"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

// MARK: - PlayingCard

struct PlayingCard: Identifiable, Equatable {
    let id: UUID
    let rank: CardRank
    let suit: CardSuit
    var isFaceUp: Bool

    init(rank: CardRank, suit: CardSuit, faceUp: Bool = true) {
        self.id = UUID()
        self.rank = rank
        self.suit = suit
        self.isFaceUp = faceUp
    }

    // Standard tableau stacking rule: this card can be placed onto `other`
    // when opposite color, one rank lower, and other is face-up.
    func canStack(onto other: PlayingCard) -> Bool {
        guard other.isFaceUp else { return false }
        return suit.isRed != other.suit.isRed && rank.rawValue + 1 == other.rank.rawValue
    }

    // Only a King may be placed onto an empty column.
    var canGoOnEmpty: Bool { rank == .king }
}
