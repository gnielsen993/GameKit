//
//  MergeEngine.swift
//  gamekit
//
//  Pure slide+merge logic for the canonical 2048 algorithm. Stateless;
//  uninhabited (`enum`). Foundation-only — no SwiftUI / SwiftData / Combine.
//
//  Algorithm:
//    1. Clear every tile's `mergedThisTurn` flag (per-turn merge gate reset).
//    2. Rotate the board so the swipe direction == .left.
//    3. Compress + pair-merge each row left-to-right. Already-merged tiles
//       cannot merge again this turn (`[2,2,4]` -> `[4,4]`, NOT `[8]`).
//    4. Rotate back.
//
//  Determinism: no RNG used in slide. Spawning new tiles is BoardSpawner's
//  job — the VM calls spawn AFTER slide when `didChange == true`.
//
//  CLAUDE.md §4: pure / testable, no SwiftUI imports.
//

import Foundation

/// Direction the player swiped.
nonisolated enum SwipeDirection: String, CaseIterable, Sendable {
    case up, down, left, right
}

/// Side-effect record of a single merge — the surviving tile's id, the
/// resulting value, and the (row, col) where it landed. View consumers use
/// this for haptics scaling and merge-flash animation.
nonisolated struct MergeEvent: Equatable, Sendable {
    let id: UUID
    let value: Int
    let row: Int
    let col: Int
}

/// Outcome of one slide.
nonisolated struct SlideResult: Equatable, Sendable {
    let board: MergeBoard
    let scoreDelta: Int
    /// True iff any tile moved or merged. Spawner runs only when this is true
    /// — the canonical 2048 rule that "a no-op swipe doesn't spawn a tile."
    let didChange: Bool
    let merges: [MergeEvent]
}

nonisolated enum MergeEngine {

    /// Slide the board in `direction`. Returns the new board, score delta,
    /// change flag, and per-merge events.
    static func slide(_ board: MergeBoard, direction: SwipeDirection) -> SlideResult {
        let cleared = board.clearingMergeFlags()

        // Project the board so the slide axis is "left", do the work, project back.
        let rotated = rotate(cleared, for: direction)
        let (slidRotated, scoreDelta, mergesRotated) = compressAndMergeLeft(rotated)
        let result = unrotate(slidRotated, for: direction)

        // Map merge events back through the rotation.
        let merges = mergesRotated.map { event in
            let (r, c) = unrotateCoord(row: event.row, col: event.col, for: direction)
            return MergeEvent(id: event.id, value: event.value, row: r, col: c)
        }

        let didChange = result != cleared
        return SlideResult(
            board: result,
            scoreDelta: scoreDelta,
            didChange: didChange,
            merges: merges
        )
    }

    /// True iff at least one of the four directions produces a change.
    /// Caller (GameOverDetector) uses this to decide whether the game is over.
    static func hasAnyLegalMove(_ board: MergeBoard) -> Bool {
        for direction in SwipeDirection.allCases {
            if slide(board, direction: direction).didChange { return true }
        }
        return false
    }

    // MARK: - Core: compress + pair-merge a left-projected board

    /// Operates on a board where the slide direction has been rotated to
    /// "left". Returns (newBoard, scoreDelta, merges).
    private static func compressAndMergeLeft(
        _ board: MergeBoard
    ) -> (MergeBoard, Int, [MergeEvent]) {
        let n = MergeBoard.size
        var newCells: [MergeTile?] = Array(repeating: nil, count: n * n)
        var scoreDelta = 0
        var merges: [MergeEvent] = []

        for r in 0..<n {
            // Collect the row's non-nil tiles in order.
            var row: [MergeTile] = []
            for c in 0..<n {
                if let tile = board.cells[r * n + c] {
                    row.append(tile)
                }
            }

            // Compress + merge passing left to right. Each survivor lands in
            // the next free slot of `compacted`.
            var compacted: [MergeTile] = []
            var i = 0
            while i < row.count {
                let current = row[i]
                if i + 1 < row.count,
                   row[i + 1].value == current.value,
                   !current.mergedThisTurn,
                   !row[i + 1].mergedThisTurn {
                    // Merge: survivor keeps `current.id`, value doubles.
                    let mergedValue = current.value * 2
                    let merged = MergeTile(
                        id: current.id,
                        value: mergedValue,
                        mergedThisTurn: true
                    )
                    compacted.append(merged)
                    scoreDelta += mergedValue
                    let landingCol = compacted.count - 1
                    merges.append(MergeEvent(
                        id: merged.id,
                        value: mergedValue,
                        row: r,
                        col: landingCol
                    ))
                    i += 2
                } else {
                    compacted.append(current)
                    i += 1
                }
            }

            // Write the compacted row back to the flat array.
            for c in 0..<compacted.count {
                newCells[r * n + c] = compacted[c]
            }
        }

        return (MergeBoard(cells: newCells), scoreDelta, merges)
    }

    // MARK: - Rotation helpers

    /// Rotate `board` so the slide direction becomes "left" (compaction
    /// destination = col 0 after rotation).
    ///
    /// For `.up`: the original TOP of each column must land at col 0 after
    /// rotation so left-compress collapses tiles toward the original top.
    /// `rotated90CCW` maps (r, c) → (n-1-c, r): row 0 (top) maps to col 0.
    ///
    /// For `.down`: the original BOTTOM of each column must land at col 0.
    /// `rotated90CW` maps (r, c) → (c, n-1-r): row n-1 (bottom) maps to col 0.
    private static func rotate(_ board: MergeBoard, for direction: SwipeDirection) -> MergeBoard {
        switch direction {
        case .left:  return board
        case .right: return mirroredHorizontal(board)
        case .up:    return rotated90CCW(board)
        case .down:  return rotated90CW(board)
        }
    }

    /// Inverse of `rotate(_:for:)`. CW and CCW are mutual inverses.
    private static func unrotate(_ board: MergeBoard, for direction: SwipeDirection) -> MergeBoard {
        switch direction {
        case .left:  return board
        case .right: return mirroredHorizontal(board)         // self-inverse
        case .up:    return rotated90CW(board)                // inverse of CCW
        case .down:  return rotated90CCW(board)               // inverse of CW
        }
    }

    /// Inverse coordinate mapping for merge events.
    private static func unrotateCoord(
        row: Int,
        col: Int,
        for direction: SwipeDirection
    ) -> (Int, Int) {
        let n = MergeBoard.size
        switch direction {
        case .left:
            return (row, col)
        case .right:
            return (row, n - 1 - col)
        case .up:
            // rotated90CCW maps (r, c) → (n-1-c, r). Inverse: (r', c') → (c', n-1-r').
            return (col, n - 1 - row)
        case .down:
            // rotated90CW maps (r, c) → (c, n-1-r). Inverse: (r', c') → (n-1-c', r').
            return (n - 1 - col, row)
        }
    }

    private static func mirroredHorizontal(_ board: MergeBoard) -> MergeBoard {
        let n = MergeBoard.size
        var newCells: [MergeTile?] = Array(repeating: nil, count: n * n)
        for r in 0..<n {
            for c in 0..<n {
                newCells[r * n + (n - 1 - c)] = board.cells[r * n + c]
            }
        }
        return MergeBoard(cells: newCells)
    }

    private static func rotated90CW(_ board: MergeBoard) -> MergeBoard {
        let n = MergeBoard.size
        var newCells: [MergeTile?] = Array(repeating: nil, count: n * n)
        for r in 0..<n {
            for c in 0..<n {
                // (r, c) -> (c, n - 1 - r)
                newCells[c * n + (n - 1 - r)] = board.cells[r * n + c]
            }
        }
        return MergeBoard(cells: newCells)
    }

    private static func rotated90CCW(_ board: MergeBoard) -> MergeBoard {
        let n = MergeBoard.size
        var newCells: [MergeTile?] = Array(repeating: nil, count: n * n)
        for r in 0..<n {
            for c in 0..<n {
                // (r, c) -> (n - 1 - c, r)
                newCells[(n - 1 - c) * n + r] = board.cells[r * n + c]
            }
        }
        return MergeBoard(cells: newCells)
    }
}
