//
//  NonogramEndStateCard.swift
//  gamekit
//
//  Terminal-state overlay for the Nonogram scene. Two variants:
//    - .won      → "Solved" headline, picture title, time, New puzzle.
//    - .gameOver → "Out of lives" headline, time, Try again.
//  Both share the secondary Change Size button.
//

import SwiftUI
import DesignKit

enum NonogramEndStateOutcome {
    case won
    case gameOver
}

struct NonogramEndStateCard: View {
    let theme: Theme
    let outcome: NonogramEndStateOutcome
    /// Picture title — shown only on `.won`. Empty string otherwise.
    let title: String
    let elapsed: TimeInterval
    let onPrimary: () -> Void
    let onChangeDifficulty: () -> Void

    var body: some View {
        DKCard(theme: theme) {
            VStack(spacing: theme.spacing.l) {
                VStack(spacing: theme.spacing.xs) {
                    Text(headline)
                        .font(theme.typography.titleLarge)
                        .foregroundStyle(theme.colors.textPrimary)
                    if outcome == .won, !title.isEmpty {
                        Text(title)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    if outcome == .gameOver {
                        Text(String(localized: "You used all 3 lives"))
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "clock")
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(formatElapsed(elapsed))
                        .font(theme.typography.monoNumber)
                        .foregroundStyle(theme.colors.textPrimary)
                        .monospacedDigit()
                }

                VStack(spacing: theme.spacing.s) {
                    DKButton(
                        primaryButtonLabel,
                        theme: theme,
                        action: onPrimary
                    )
                    DKButton(
                        String(localized: "Change size"),
                        style: .secondary,
                        theme: theme,
                        action: onChangeDifficulty
                    )
                }
            }
            .padding(theme.spacing.l)
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private var headline: String {
        switch outcome {
        case .won:      return String(localized: "Solved")
        case .gameOver: return String(localized: "Out of lives")
        }
    }

    private var primaryButtonLabel: String {
        switch outcome {
        case .won:      return String(localized: "New puzzle")
        case .gameOver: return String(localized: "Try again")
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
