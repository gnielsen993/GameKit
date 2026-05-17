//
//  SudokuGameState.swift
//  gamekit
//
//  Lifecycle state for a Sudoku session. Mirrors NonogramGameState shape.
//

import Foundation

enum SudokuGameState: Equatable, Hashable, Sendable {
    case idle       // pre-first-placement; timer not yet started
    case playing    // active session; timer running
    case won        // board solved; timer frozen
    case gameOver   // .lives mode: mistakes == 3; timer frozen
}
