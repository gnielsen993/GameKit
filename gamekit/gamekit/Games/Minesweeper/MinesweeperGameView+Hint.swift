//
//  MinesweeperGameView+Hint.swift
//  gamekit
//
//  The hint banner: the argument, with the numbers that carry it outlined on
//  the board so the player can check it rather than take it on faith.
//

import SwiftUI
import DesignKit

extension MinesweeperGameView {

    @ViewBuilder
    var hintBanner: some View {
        if let step = viewModel.activeHint {
            banner(MinesweeperHintCopy.explanation(for: step), stroke: theme.colors.accentPrimary)
        } else if viewModel.hintFoundNothing {
            // Says what it cannot do, and offers the way out rather than
            // leaving the player stuck with a refusal.
            VStack(spacing: theme.spacing.s) {
                Text(MinesweeperHintCopy.noStepFound)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: theme.spacing.m) {
                    Button(MinesweeperHintCopy.spendTheGuess) {
                        viewModel.openASafeSquare()
                    }
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.accentPrimary)
                    Button(String(localized: "Dismiss")) {
                        viewModel.dismissHint()
                    }
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .frame(maxWidth: .infinity)
            .background(bannerBackground(stroke: theme.colors.textTertiary))
            .padding(.horizontal, theme.spacing.m)
        }
    }

    private func banner(_ text: String, stroke: Color) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .frame(maxWidth: .infinity)
            .background(bannerBackground(stroke: stroke))
            .padding(.horizontal, theme.spacing.m)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.dismissHint() }
    }

    private func bannerBackground(stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
            .fill(theme.colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
