//
//  RevealEngine.swift
//  gamekit
//
//  Pure single-cell reveal + iterative BFS flood-fill (D-06, D-07).
//  Returns (newBoard, revealedIndicesInBFSOrder) per CONTEXT D-06 — P3's
//  MINES-08 reveal cascade animation staggers off this list (no need to
//  reconstruct via lossy set-diff).
//
//  ITERATIVE ONLY — explicit Array<Index> queue with head pointer.
//  No recursion (ROADMAP P2 SC3). PITFALLS "Performance Traps → Recursive
//  flood-fill on Hard ... Stack overflow risk on degenerate boards."
//
//  Phase 2 invariants (per D-06, D-07, D-10):
//    - Foundation-only — no SwiftUI, no SwiftData (ROADMAP P2 SC5)
//    - Returns NEW immutable Board (D-10)
//    - No win/loss detection here (D-07 — WinDetector owns that, Plan 05)
//    - No recursion — explicit queue traversal
//

import Foundation

/// Pure-function namespace for reveal logic. Stateless; uninhabited (`enum`).
/// Foundation-only — ROADMAP P2 SC5.
nonisolated enum RevealEngine {

    /// Reveal the cell at `index`. Returns the new board and the ordered
    /// list of newly-revealed cells (BFS discovery order from `index`).
    ///
    /// Behavior matrix:
    ///   | tapped cell state | tapped is mine | result                                              |
    ///   |-------------------|----------------|-----------------------------------------------------|
    ///   | .revealed         | (any)          | (board, [])  — idempotent no-op                    |
    ///   | .flagged          | (any)          | (board, [])  — flag protection, no-op (Pitfall 7)  |
    ///   | .mineHit          | (any)          | (board, [])  — terminal, no-op                     |
    ///   | .hidden           | true           | (newBoard with .mineHit, [index])                  |
    ///   | .hidden, adj>0    | false          | (newBoard with .revealed, [index])                 |
    ///   | .hidden, adj==0   | false          | (newBoard with cascade .revealed, [BFS order…])    |
    static func reveal(
        at index: MinesweeperIndex,
        on board: MinesweeperBoard
    ) -> (board: MinesweeperBoard, revealed: [MinesweeperIndex]) {
        precondition(board.contains(index),
            "reveal index (\(index.row),\(index.col)) must be on board (\(board.rows)x\(board.cols))")

        let tappedCell = board.cell(at: index)

        // No-op cases first (D-07: pure transform; D-06: empty `revealed` signals "no work")
        switch tappedCell.state {
        case .revealed, .mineHit:
            return (board, [])
        case .flagged:
            // PITFALLS Pitfall 7: "flag-on-revealed-cell needs to be a no-op."
            // Same rule applies in reverse: revealing a flagged cell is a no-op.
            // The user must un-flag first. (P3 ViewModel can choose to surface this
            // as a hint, or simply ignore — engine's job is just to enforce.)
            return (board, [])
        case .hidden:
            break
        }

        // Mine case: flip to .mineHit, return [index]. WinDetector.isLost (Plan 05)
        // reads .mineHit to flip game state.
        if tappedCell.isMine {
            let hitCell = MinesweeperCell(
                isMine: true,
                adjacentMineCount: tappedCell.adjacentMineCount,
                state: .mineHit
            )
            let newBoard = board.replacingCell(at: index, with: hitCell)
            return (newBoard, [index])
        }

        // Numbered cell (adjacentMineCount > 0): single-cell reveal, no cascade.
        if tappedCell.adjacentMineCount > 0 {
            let revealedCell = MinesweeperCell(
                isMine: false,
                adjacentMineCount: tappedCell.adjacentMineCount,
                state: .revealed
            )
            let newBoard = board.replacingCell(at: index, with: revealedCell)
            return (newBoard, [index])
        }

        // Empty cell (adjacentMineCount == 0): iterative BFS flood-fill.
        // Reveal the tap cell + every reachable empty cell + the immediate
        // numbered border of those empty cells. Mines are NEVER revealed by cascade.
        return floodFill(from: index, on: board)
    }

    // MARK: - Iterative BFS flood-fill (no recursion — SC3)

    /// Iterative flood-fill via Array<Index> queue with head pointer.
    /// Visited set prevents re-enqueueing. Stack depth never grows past
    /// this single function frame. ROADMAP P2 SC3.
    ///
    /// Claude's Discretion (CONTEXT.md): BFS via Array<Index> with head pointer
    /// gives O(1) amortized dequeue (avoids Array.removeFirst's O(n)) and
    /// produces a layer-by-layer reveal order that P3's MINES-08 cascade
    /// animation will stagger off without reconstruction.
    private static func floodFill(
        from start: MinesweeperIndex,
        on board: MinesweeperBoard
    ) -> (board: MinesweeperBoard, revealed: [MinesweeperIndex]) {
        // BFS queue with index pointer.
        var queue: [MinesweeperIndex] = [start]
        var queueHead = 0

        // Visited tracks cells we've enqueued (and therefore will or have
        // already emitted). Ensures O(rows*cols) total work — every cell
        // is dequeued at most once.
        var visited: Set<MinesweeperIndex> = [start]

        // Newly-revealed cells in BFS discovery order (D-06).
        var revealedOrder: [MinesweeperIndex] = []
        // The cell-update list passed in one batch to Board.replacingCells (D-10 + perf).
        var updates: [(MinesweeperIndex, MinesweeperCell)] = []

        while queueHead < queue.count {
            let current = queue[queueHead]
            queueHead += 1

            let currentCell = board.cell(at: current)
            // Skip: already revealed, flagged, or mine. (Mines should not be
            // enqueued by the expansion step below, but defensive-skip is cheap.)
            guard currentCell.state == .hidden, !currentCell.isMine else {
                continue
            }

            // Reveal this cell.
            revealedOrder.append(current)
            updates.append((current, MinesweeperCell(
                isMine: false,
                adjacentMineCount: currentCell.adjacentMineCount,
                state: .revealed
            )))

            // Expansion rule: only enqueue neighbors if THIS cell is empty (adj==0).
            // Numbered cells terminate the cascade — they get revealed (above) but
            // their neighbors are NOT auto-revealed. Standard Minesweeper semantics.
            if currentCell.adjacentMineCount == 0 {
                for neighbor in current.neighbors8(rows: board.rows, cols: board.cols) {
                    if !visited.contains(neighbor) {
                        let neighborCell = board.cell(at: neighbor)
                        // Don't enqueue mines, flagged, or already-revealed.
                        // (Hidden non-mine neighbors get enqueued; their adj count
                        // gates further expansion in the next iteration.)
                        if neighborCell.state == .hidden && !neighborCell.isMine {
                            visited.insert(neighbor)
                            queue.append(neighbor)
                        }
                    }
                }
            }
        }

        // Single batched immutable transform (D-10).
        let newBoard = board.replacingCells(updates)
        return (newBoard, revealedOrder)
    }
}
