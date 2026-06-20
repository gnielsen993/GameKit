import Foundation

// MARK: - Selection

enum FreeCellSelection: Equatable {
    case column(colIdx: Int, startCardIdx: Int)
    case freeCell(cellIdx: Int)
    case foundation(suit: CardSuit)
}

// MARK: - Game state

enum FreeCellGameState {
    case idle, playing, won, lost
}
