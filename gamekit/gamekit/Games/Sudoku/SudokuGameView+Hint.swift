//
//  SudokuGameView+Hint.swift
//  gamekit
//
//  The hint banner: the argument first, the answer only if asked again.
//
//  Graduated on purpose. Naming the technique and the unit is usually enough
//  to unstick someone, and stopping there leaves them the satisfaction of
//  placing the digit themselves. "Show me the answer" is a second, deliberate
//  tap — never the default.
//

import SwiftUI
import DesignKit

extension SudokuGameView {

    @ViewBuilder
    var hintBanner: some View {
        if let hint = viewModel.activeHint {
            VStack(spacing: theme.spacing.s) {
                Text(hintText(for: hint))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: theme.spacing.m) {
                    if hint.stage == .explanation {
                        Button(String(localized: "Show the answer")) {
                            viewModel.requestHint()
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                    } else {
                        Button(String(localized: "Fill it in")) {
                            viewModel.applyHint()
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                    }

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
            .background(bannerBackground(stroke: theme.colors.accentPrimary))
            .padding(.horizontal, theme.spacing.m)
        } else if let reason = viewModel.hintUnavailable {
            Text(SudokuHintCopy.unavailableMessage(reason))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, theme.spacing.m)
                .padding(.vertical, theme.spacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    bannerBackground(
                        stroke: reason == .boardHasAMistake
                            ? theme.colors.danger
                            : theme.colors.textTertiary
                    )
                )
                .padding(.horizontal, theme.spacing.m)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.dismissHint() }
        }
    }

    private func hintText(for hint: SudokuViewModel.ActiveHint) -> String {
        switch hint.stage {
        case .explanation: return SudokuHintCopy.explanation(for: hint.step)
        case .reveal:      return SudokuHintCopy.reveal(for: hint.step)
        }
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
