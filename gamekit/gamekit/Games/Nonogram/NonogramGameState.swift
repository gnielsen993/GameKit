//
//  NonogramGameState.swift
//  gamekit
//
//  Lifecycle state for a Nonogram session, owned by NonogramViewModel.
//  Mirrors MinesweeperGameState shape for cross-game consistency.
//

import Foundation

enum NonogramGameState: Equatable, Hashable, Sendable {
    /// Pre-first-tap. Board is empty; hints are visible; timer hasn't started.
    case idle
    /// First tap fired. Timer running; the player is solving.
    case playing
    /// All filled cells correctly placed. Timer frozen; end-state card pending.
    case won
    /// Lives-mode terminal state — player exhausted their 3 lives. Timer
    /// frozen; end-state card offers Try Again.
    case gameOver
}
