//
//  NonogramHeaderBar.swift
//  gamekit
//
//  Size chip + optional lives chip + elapsed-timer chip for the Nonogram
//  game scene. Props-only. Post-Plan 12-03 (D-12-CHIPS): thin composer
//  that consumes NonogramSizeChip, NonogramLivesChip, and the shared
//  VideoModeTimerChip (Core/). Off-path callers leave `compact`
//  defaulted to false → v1.1 inline chip shape verbatim (D-12-OFFRESTORE).
//  Mirrors MergeHeaderBar / MinesweeperHeaderBar thin-composer pattern.
//

import SwiftUI
import DesignKit

struct NonogramHeaderBar: View {
    let theme: Theme
    /// Size label like "10 × 10". The puzzle's actual title is intentionally
    /// NOT shown here during play — it would spoil the picture the player
    /// is solving. Title only appears on the end-state card.
    let sizeLabel: String
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
    /// nil = Free mode (hide the lives chip). Otherwise a 0…3 count of
    /// lives remaining; the chip renders 3 hearts and dims the missing ones.
    let livesRemaining: Int?

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            NonogramSizeChip(theme: theme, sizeLabel: sizeLabel)
            if let livesRemaining {
                NonogramLivesChip(theme: theme, remaining: livesRemaining)
            }
            Spacer()
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: timerAnchor,
                pausedElapsed: pausedElapsed
            )
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
