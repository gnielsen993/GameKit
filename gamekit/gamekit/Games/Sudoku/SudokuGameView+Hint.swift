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
        if viewModel.isHintCardVisible, let hint = viewModel.activeHint {
            GameAssistCard(
                theme: theme,
                title: String(localized: "Try this square"),
                message: SudokuHintCopy.explanation(for: hint.step),
                primaryAction: .init(
                    title: String(localized: "Fill it in"),
                    perform: { viewModel.applyHint() }
                ),
                onDismiss: { viewModel.dismissHint() }
            )
        } else if viewModel.isHintCardVisible, let reason = viewModel.hintUnavailable {
            GameAssistCard(
                theme: theme,
                title: reason == .boardHasAMistake
                    ? String(localized: "Check the red squares")
                    : String(localized: "No short step found"),
                message: SudokuHintCopy.unavailableMessage(reason),
                tone: reason == .boardHasAMistake ? .warning : .neutral,
                primaryAction: reason == .beyondSingles
                    ? .init(
                        title: String(localized: "Reveal one square"),
                        perform: { viewModel.applyFallbackHint() }
                    )
                    : nil,
                onDismiss: { viewModel.dismissHint() }
            )
        }
    }
}
