//
//  SnakeScoreChip.swift
//  gamekit
//
//  Props-only score chip for Snake. Renders the DESIGN.md §3.3 generic-info-chip
//  shell with a rolling numericText content transition (D-08 score roll on food
//  eat). Carries no @State, no @Environment stored properties — all state lives
//  in SnakeViewModel. Mirrors StackScoreChip; adds contentTransition for the
//  score-roll animation gated by feedbackAnimation (reads env from mount site).
//
//  Snake has no Video Mode compact row (Video Mode exempt per 15-VIDEO-MODE-ADR),
//  so no compact variant is needed here (contrast StackScoreChip).
//
//  Token discipline: all colors via theme.colors.* only (CLAUDE.md §1, SNAKE-06).
//

import SwiftUI
import DesignKit

struct SnakeScoreChip: View {
    let theme: Theme
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Score").uppercased())
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            Text("\(score)")
                .font(theme.typography.monoNumber)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText(countsDown: false))
                .feedbackAnimation(.default, value: score)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score \(score)"))
    }
}
