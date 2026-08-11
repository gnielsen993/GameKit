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
        if viewModel.isHintCardVisible, let step = viewModel.activeHint {
            GameAssistCard(
                theme: theme,
                title: String(localized: "This square is safe"),
                message: MinesweeperHintCopy.explanation(for: step),
                onDismiss: { viewModel.dismissHint() }
            )
        } else if viewModel.isHintCardVisible, viewModel.hintFoundNothing {
            // Says what it cannot do, and offers the way out rather than
            // leaving the player stuck with a refusal.
            GameAssistCard(
                theme: theme,
                title: String(localized: "No certain move found"),
                message: MinesweeperHintCopy.noStepFound,
                tone: .neutral,
                primaryAction: .init(
                    title: MinesweeperHintCopy.spendTheGuess,
                    perform: { viewModel.openASafeSquare() }
                ),
                onDismiss: { viewModel.dismissHint() }
            )
        }
    }
}
