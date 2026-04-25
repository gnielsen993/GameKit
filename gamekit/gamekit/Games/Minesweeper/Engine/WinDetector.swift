//
//  WinDetector.swift
//  gamekit
//
//  Pure terminal-state predicates. Two functions, one file (D-07 single-responsibility).
//  P3 ViewModel calls these after every reveal pass:
//
//      let r = reveal(at: tap, on: board)   // produced by the reveal engine
//      board = r.board
//      if WinDetector.isLost(board) { state = .lost(mineIdx) }
//      else if WinDetector.isWon(board) { state = .won }
//
//  This file is intentionally decoupled from the reveal engine — it only
//  inspects Board state, never triggers reveals (D-07 single-responsibility).
//
//  Phase 2 invariants (per D-07, D-10):
//    - Foundation-only — no SwiftUI, no SwiftData (ROADMAP P2 SC5)
//    - Pure predicates — never mutate input (D-10)
//    - Mutually exclusive: a Board satisfies AT MOST one of {isWon, isLost}
//      (D-17 mutual-exclusion fuzz proves this over seed-generated boards)
//

import Foundation

/// Pure-function namespace for terminal-state detection. Stateless; uninhabited (`enum`).
/// Foundation-only — ROADMAP P2 SC5.
nonisolated enum WinDetector {

    /// True iff any cell is in the `.mineHit` state — the player revealed a mine.
    /// Does not depend on which mine, only that any mine was hit.
    static func isLost(_ board: MinesweeperBoard) -> Bool {
        board.cells.contains { $0.state == .mineHit }
    }

    /// True iff the player has revealed every non-mine cell AND not hit any mine.
    ///
    /// Order of checks matters for short-circuit performance on terminal-loss boards:
    /// we check the cheap "no mineHit" first, then the per-cell scan for full reveal.
    static func isWon(_ board: MinesweeperBoard) -> Bool {
        // If any mine was hit, the player has already lost — cannot win.
        // (Also enforces the mutual-exclusion invariant at the type level.)
        if isLost(board) { return false }
        // Win iff every non-mine cell is revealed.
        // Flagged non-mine cells, or hidden non-mine cells, both block the win.
        for cell in board.cells {
            if !cell.isMine && cell.state != .revealed {
                return false
            }
        }
        return true
    }
}
