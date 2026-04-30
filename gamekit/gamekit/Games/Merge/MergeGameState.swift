//
//  MergeGameState.swift
//  gamekit
//
//  Lifecycle of a Merge session, owned by the ViewModel. Engines never read
//  or write this state — they transform Boards; the VM derives the next
//  state from the resulting Board via GameOverDetector predicates.
//
//  Foundation-only. Mirrors MinesweeperGameState discipline at
//  MinesweeperGameState.swift:26.
//

import Foundation

nonisolated enum MergeGameState: Equatable, Hashable, Sendable {
    /// Pre-first-spawn. Board is empty.
    case idle
    /// Tiles are spawning / sliding. Standard play.
    case playing
    /// Reached 2048 in `.winMode`. View shows the win banner; `continuePastWin()`
    /// transitions back into `.playing` with the banner suppressed.
    case won
    /// No legal moves remain. Terminal state — only `restart()` exits this.
    case gameOver
}
