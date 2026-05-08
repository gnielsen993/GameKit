//
//  NonogramGameState.swift
//  gamekit
//
//  Lifecycle state for a Nonogram session, owned by NonogramViewModel.
//  Mirrors MinesweeperGameState shape for cross-game consistency.
//
//  Phase 1 (gallery mode): only `.gallery` ships. The other cases are
//  reserved for the play-mode follow-up phase that lands once the gallery
//  prototype is greenlit.
//

import Foundation

enum NonogramGameState: Equatable, Hashable, Sendable {
    /// Gallery preview — the board is pre-filled to the current puzzle's
    /// solution; tap interactions are disabled. Used to eyeball every
    /// shipped puzzle's visual quality before locking in the seed set.
    case gallery
    /// Pre-first-tap. Reserved for play mode.
    case idle
    /// First tap fired. Reserved for play mode.
    case playing
    /// All filled cells correctly placed. Reserved for play mode.
    case won
}
