import Foundation

// MARK: - Board state (value type — copy for undo)

struct FreeCellBoard: Codable {
    /// 8 columns. col[0] = top of visual stack; col.last = most accessible card.
    var columns:    [[PlayingCard]]
    /// 4 free-cell slots; nil = empty.
    var freeCells:  [PlayingCard?]
    /// Foundation top rank per suit: [spades, hearts, diamonds, clubs]. nil = empty.
    var foundations: [CardRank?]

    static let columnCount   = 8
    static let freeCellCount = 4

    init(dealNumber: Int) {
        columns     = FreeCellDeal.deal(dealNumber: dealNumber)
        freeCells   = [nil, nil, nil, nil]
        foundations = [nil, nil, nil, nil]
    }

    // MARK: - Foundation helpers

    func foundationIndex(for suit: CardSuit) -> Int {
        switch suit {
        case .spades:   return 0
        case .hearts:   return 1
        case .diamonds: return 2
        case .clubs:    return 3
        }
    }

    mutating func advanceFoundation(for suit: CardSuit) {
        let idx = foundationIndex(for: suit)
        if let top = foundations[idx] {
            foundations[idx] = CardRank(rawValue: top.rawValue + 1)
        } else {
            foundations[idx] = .ace
        }
    }

    mutating func regressFoundation(for suit: CardSuit) {
        let idx = foundationIndex(for: suit)
        if let top = foundations[idx] {
            foundations[idx] = top == .ace ? nil : CardRank(rawValue: top.rawValue - 1)
        }
    }

    // MARK: - Derived

    var emptyFreeCellCount: Int { freeCells.filter { $0 == nil }.count }
    var emptyColumnCount:   Int { columns.filter { $0.isEmpty }.count }
    var isWon: Bool { foundations.allSatisfy { $0 == .king } }

    func firstEmptyFreeCellIndex() -> Int? {
        freeCells.indices.first { freeCells[$0] == nil }
    }
}

// MARK: - Move record (source + dest + snapshot for undo)

enum FreeCellSource: Hashable {
    case column(colIdx: Int, startIdx: Int)
    case freeCell(cellIdx: Int)
}

enum FreeCellDest: Hashable {
    case column(Int)
    case freeCell(Int)
    case foundation
}

struct FreeCellMove {
    let cards:       [PlayingCard]
    let source:      FreeCellSource
    let destination: FreeCellDest
    let boardBefore: FreeCellBoard  // full snapshot — trivial undo
}
