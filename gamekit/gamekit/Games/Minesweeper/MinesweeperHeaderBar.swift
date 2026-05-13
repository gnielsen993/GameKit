//
//  MinesweeperHeaderBar.swift
//  gamekit
//
//  Thin composer of mine-counter + elapsed-timer chips for the
//  Minesweeper game scene. Props-only (CLAUDE.md §8.2): receives theme
//  + four primitives — minesRemaining, timerAnchor, pausedElapsed.
//
//  D-03 (Plan 11-01): chip rendering moved to MinesRemainingChip +
//  TimerChip sibling subviews. Phase 3 D-05 timer-freeze invariants
//  (TimelineView + .distantPast anchor) now live inside TimerChip.
//  Single source of truth — HeaderBar (non-Video / Small PiP zones)
//  and the compact-row slot-2 stack (Large zones, Plan 11-04 / D-06)
//  both consume these same chip subviews.
//

import SwiftUI
import DesignKit

struct MinesweeperHeaderBar: View {
    let theme: Theme
    let minesRemaining: Int
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            MinesRemainingChip(theme: theme, minesRemaining: minesRemaining)
            Spacer()
            TimerChip(theme: theme, timerAnchor: timerAnchor, pausedElapsed: pausedElapsed)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
