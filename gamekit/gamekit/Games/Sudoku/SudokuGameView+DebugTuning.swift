//
//  SudokuGameView+DebugTuning.swift
//  gamekit
//
//  The DEBUG near-win jump for Sudoku's settings menu (Phase 19.1, D-17).
//  Release builds get nil, so the menu shows nothing and no fixture symbol
//  is referenced.
//

import Foundation

extension SudokuGameView {

    var debugNearWinAction: (() -> Void)? {
        #if DEBUG
        return { viewModel.applyNearWinFixture() }
        #else
        return nil
        #endif
    }
}
