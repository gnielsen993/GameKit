//
//  SudokuUndoSnapshot.swift
//  gamekit
//
//  Captured pre-mutation state for the single-step undo. Carries the
//  cell coordinates + the cell's previous SudokuCell value + the
//  previous mistakes count (so undoing a wrong placement also returns
//  the life). One snapshot held at a time; consumed on undo().
//

import Foundation

struct SudokuUndoSnapshot: Equatable, Sendable {
    let row: Int
    let col: Int
    let previousCell: SudokuCell
    let previousMistakes: Int
}
