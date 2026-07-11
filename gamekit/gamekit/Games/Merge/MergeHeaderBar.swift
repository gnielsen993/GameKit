//
//  MergeHeaderBar.swift
//  gamekit
//
//  Floating score + best-score hierarchy for the Merge game scene. Props-only.
//  Thin composer that consumes MergeScoreChip + MergeBestChip. Off-path
//  callers leave `compact` false for floating readouts; constrained Video
//  Mode layouts request compact bounded variants directly.
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
        HStack(alignment: .bottom, spacing: theme.spacing.s) {
            MergeScoreChip(theme: theme, score: score)
            Spacer()
            MergeBestChip(theme: theme, bestScore: bestScore)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
