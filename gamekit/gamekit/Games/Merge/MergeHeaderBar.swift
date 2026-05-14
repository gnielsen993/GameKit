//
//  MergeHeaderBar.swift
//  gamekit
//
//  Score chip + best-score chip for the Merge game scene. Props-only.
//  Post-Plan 12-01 (D-12-CHIPS): thin composer that consumes MergeScoreChip
//  + MergeBestChip. Off-path callers leave `compact` defaulted to false,
//  producing the v1.1 inline chip shape verbatim (D-12-OFFRESTORE).
//  Mirrors MinesweeperHeaderBar's post-Plan 11-01 thin-composer shape.
//

import SwiftUI
import DesignKit

struct MergeHeaderBar: View {
    let theme: Theme
    let score: Int
    let bestScore: Int
    let mode: MergeMode

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            MergeScoreChip(theme: theme, score: score)
            Spacer()
            MergeBestChip(theme: theme, bestScore: bestScore)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
