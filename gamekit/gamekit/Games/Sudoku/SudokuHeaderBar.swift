//
//  SudokuHeaderBar.swift
//  gamekit
//
//  Timer chip + optional lives chip + mode pill for the Sudoku game scene.
//  Props-only composer. Mirrors NonogramHeaderBar's thin-composer pattern.
//
//  Layout (left → right):
//    [SudokuLivesChip] (only when gameMode == .lives) | <Spacer> | [VideoModeTimerChip] | [SudokuModePill]
//
//  Uses VideoModeTimerChip (Core/) for the elapsed-time display — same
//  TimelineView(.periodic) pattern as Minesweeper + Nonogram.
//

import SwiftUI
import DesignKit

struct SudokuHeaderBar: View {
    let theme: Theme
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
    /// nil = Free mode (hide the lives chip). Otherwise current mistake count.
    let mistakes: Int?

    /// True while the game is interactive (pre-terminal). Used to gate
    /// the mode pill's tap target.
    let isInteractive: Bool
    let interactionMode: SudokuInteractionMode
    let onSelectMode: (SudokuInteractionMode) -> Void

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            if let mistakes {
                SudokuLivesChip(theme: theme, mistakes: mistakes)
            }
            Spacer()
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: timerAnchor,
                pausedElapsed: pausedElapsed
            )
            SudokuModePill(
                theme: theme,
                mode: interactionMode,
                isInteractive: isInteractive,
                onSelect: onSelectMode
            )
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
