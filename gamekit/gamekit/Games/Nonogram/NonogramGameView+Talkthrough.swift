//
//  NonogramGameView+Talkthrough.swift
//  gamekit
//
//  The assist banner: one sentence explaining the next deduction, or an
//  honest note when there is nothing to explain.
//
//  Presented as a top overlay rather than a chip or a sheet. A sheet would
//  cover the very grid the sentence is describing, and the compact row has no
//  free slot (DESIGN.md §7), so this floats above the board and dismisses on
//  tap or on the player's next move.
//

import SwiftUI
import DesignKit

extension NonogramGameView {

    @ViewBuilder
    var talkthroughBanner: some View {
        if let deduction = viewModel.activeTalkthrough {
            banner(text: NonogramTalkthroughCopy.explanation(for: deduction), tone: .accent)
        } else if let reason = viewModel.talkthroughUnavailable {
            banner(
                text: NonogramTalkthroughCopy.unavailableMessage(reason),
                tone: reason == .boardHasAMistake ? .warning : .neutral
            )
        }
    }

    enum TalkthroughTone { case accent, warning, neutral }

    private func banner(text: String, tone: TalkthroughTone) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous)
                    .stroke(strokeColor(tone), lineWidth: 1)
            )
            .padding(.horizontal, theme.spacing.m)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.dismissTalkthrough() }
            .accessibilityAddTraits(.isStaticText)
            .accessibilityHint(Text("Double tap to dismiss"))
    }

    private func strokeColor(_ tone: TalkthroughTone) -> Color {
        switch tone {
        case .accent:  return theme.colors.accentPrimary
        case .warning: return theme.colors.danger
        case .neutral: return theme.colors.textTertiary
        }
    }
}
