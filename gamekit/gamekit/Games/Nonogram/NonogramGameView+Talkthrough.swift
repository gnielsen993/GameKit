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
            GameAssistCard(
                theme: theme,
                title: NonogramTalkthroughCopy.lineName(deduction.line),
                message: NonogramTalkthroughCopy.explanation(for: deduction),
                progress: viewModel.talkthroughProgress,
                onDismiss: { viewModel.dismissTalkthrough() }
            )
        } else if let reason = viewModel.talkthroughUnavailable {
            GameAssistCard(
                theme: theme,
                title: reason == .boardHasAMistake
                    ? String(localized: "Check your work")
                    : String(localized: "No clear next step"),
                message: NonogramTalkthroughCopy.unavailableMessage(reason),
                tone: reason == .boardHasAMistake ? .warning : .neutral,
                onDismiss: { viewModel.dismissTalkthrough() }
            )
        }
    }
}
