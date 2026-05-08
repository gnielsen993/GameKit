//
//  NonogramInteractionMode.swift
//  gamekit
//
//  Tap-vs-mark interaction toggle. Mirrors MinesweeperInteractionMode shape
//  so the cross-game pill component reads the same way for users.
//
//  - .place : tap fills the cell (the picture-painting mode)
//  - .mark  : tap marks the cell with X (the "definitely-empty" annotation)
//
//  Long-press always escapes the current mode (place ↔ mark inversion).
//

import Foundation

enum NonogramInteractionMode: String, Sendable, Equatable, Codable {
    case place
    case mark
}
