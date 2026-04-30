//
//  GameOverDetector.swift
//  gamekit
//
//  Pure terminal-state predicates for the Merge engine. Mirrors WinDetector
//  at Games/Minesweeper/Engine/WinDetector.swift. Foundation-only.
//
//  Predicates are mutually independent — `hasReached2048` and `isGameOver`
//  can both be true on the same board (no legal moves AND maxValue == 2048).
//  The VM resolves precedence: `.won` (winMode + reached) overrides `.gameOver`.
//

import Foundation

nonisolated enum GameOverDetector {

    /// True iff there are no empty cells AND no legal moves remain. Cheap
    /// short-circuit: a board with any empty cell always has at least one
    /// legal move (slide into the empty space), so we only fall through to
    /// the expensive legal-move scan when the board is full.
    static func isGameOver(_ board: MergeBoard) -> Bool {
        if !board.emptyCoordinates().isEmpty { return false }
        return !MergeEngine.hasAnyLegalMove(board)
    }

    /// True iff any tile on the board has value ≥ 2048 (the canonical
    /// MergeMode.winTarget). Used by the VM to gate the win banner in
    /// `.winMode` exactly once — the VM tracks `hasContinuedPastWin` so
    /// the banner does not re-fire on every subsequent merge above 2048.
    static func hasReached2048(_ board: MergeBoard) -> Bool {
        board.maxValue >= MergeMode.winTarget
    }
}
