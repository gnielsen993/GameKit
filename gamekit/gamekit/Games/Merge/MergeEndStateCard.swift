//
//  MergeEndStateCard.swift
//  gamekit
//
//  End-state overlay for Merge: win banner (winMode only) or game-over.
//  Mirrors MinesweeperEndStateCard at MinesweeperEndStateCard.swift:29 in
//  structure: DKCard wrapping a title + body + DKButton stack.
//

import SwiftUI
import DesignKit

enum MergeEndState: Equatable, Sendable {
    case won            // 2048 reached in winMode
    case gameOver       // no legal moves
}

struct MergeEndStateCard: View {
    let theme: Theme
    let state: MergeEndState
    let score: Int
    let bestScore: Int
    let onPrimary: () -> Void           // .won = "Continue", .gameOver = "Restart"
    let onSecondary: () -> Void         // .won = "Restart", .gameOver = "Change mode"

    var body: some View {
        DKCard(theme: theme) {
            VStack(spacing: theme.spacing.l) {
                Text(titleKey)
                    .font(theme.typography.titleLarge)
                    .foregroundStyle(state == .won ? theme.colors.success : theme.colors.danger)
                    .multilineTextAlignment(.center)

                VStack(spacing: theme.spacing.xs) {
                    Text("\(score)")
                        .font(theme.typography.title)
                        .foregroundStyle(theme.colors.textPrimary)
                        .monospacedDigit()
                    Text(String(localized: "Best: \(bestScore)"))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                        .monospacedDigit()
                }

                VStack(spacing: theme.spacing.s) {
                    DKButton(
                        primaryLabel,
                        style: .primary,
                        theme: theme,
                        action: onPrimary
                    )
                    DKButton(
                        secondaryLabel,
                        style: .secondary,
                        theme: theme,
                        action: onSecondary
                    )
                }
            }
        }
        .frame(maxWidth: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var titleKey: LocalizedStringKey {
        switch state {
        case .won:      return "You reached 2048!"
        case .gameOver: return "Game over"
        }
    }

    private var primaryLabel: String {
        switch state {
        case .won:      return String(localized: "Continue")
        case .gameOver: return String(localized: "Restart")
        }
    }

    private var secondaryLabel: String {
        switch state {
        case .won:      return String(localized: "Restart")
        case .gameOver: return String(localized: "Change mode")
        }
    }

    private var a11yLabel: LocalizedStringKey {
        switch state {
        case .won:      return "You reached 2048! Score: \(score). Best: \(bestScore)."
        case .gameOver: return "Game over. Score: \(score). Best: \(bestScore)."
        }
    }
}
