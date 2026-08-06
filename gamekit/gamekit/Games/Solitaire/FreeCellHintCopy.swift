//
//  FreeCellHintCopy.swift
//  gamekit
//
//  Turns a suggested move into a sentence.
//
//  Names the card and where it goes, but not the column index — "onto the 9
//  of hearts" is something the player can find by looking, whereas "column 6"
//  makes them count. The exception is an empty column, which has no card to
//  name.
//

import Foundation

enum FreeCellHintCopy {

    static func name(_ card: PlayingCard) -> String {
        String(format: String(localized: "%@ of %@"), card.rank.display, suitName(card.suit))
    }

    private static func suitName(_ suit: CardSuit) -> String {
        switch suit {
        case .spades:   return String(localized: "spades")
        case .hearts:   return String(localized: "hearts")
        case .diamonds: return String(localized: "diamonds")
        case .clubs:    return String(localized: "clubs")
        }
    }

    static func text(for suggestion: FreeCellHint.Suggestion) -> String {
        switch suggestion.move {
        case .columnToFoundation(let card, _), .freeCellToFoundation(let card, _):
            return String(
                format: String(localized: "Send the %@ up to its foundation — nothing still needs it."),
                name(card)
            )
        case .freeCellToColumn(let card, _, _):
            return String(
                format: String(localized: "The %@ can come out of its free cell and back onto the tableau."),
                name(card)
            )
        case .columnToColumn(let card, _, _):
            switch suggestion.reason {
            case .unburies:
                return String(
                    format: String(localized: "Move the %@ across — it empties that column."),
                    name(card)
                )
            default:
                return String(
                    format: String(localized: "The %@ has somewhere to go on the tableau."),
                    name(card)
                )
            }
        case .sequenceToColumn(let cards, _, _):
            guard let first = cards.first else { return String(localized: "Move the highlighted sequence.") }
            return String(
                format: String(localized: "Move the %d-card sequence starting with the %@ onto the highlighted column."),
                cards.count, name(first)
            )
        case .columnToFreeCell(let card, _, _):
            // Said with the cost attached, because parking is the move that
            // most often turns a winnable deal into a lost one.
            return String(
                format: String(localized: "Nothing builds right now. Parking the %@ in a free cell opens things up, but spend the cell carefully."),
                name(card)
            )
        }
    }
}
