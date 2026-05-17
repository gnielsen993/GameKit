//
//  SudokuEndStateCard.swift
//  gamekit
//
//  Terminal-state overlay for the Sudoku scene. Two variants:
//    - .won      → "You solved it!" headline, difficulty + elapsed subtitle,
//                  "New puzzle" primary CTA, "View board" secondary.
//    - .gameOver → "Out of mistakes" headline, "You used all 3 lives."
//                  subtitle, "Try again" primary CTA, "View board" secondary.
//
//  Mirrors NonogramEndStateCard chrome: DKCard wrapper, VStack(spacing: l),
//  DKButton primary + secondary. Copy locked per plan §design-decisions #3.
//

import SwiftUI
import DesignKit

enum SudokuEndStateOutcome {
    case won
    case gameOver
}

struct SudokuEndStateCard: View {
    let theme: Theme
    let outcome: SudokuEndStateOutcome
    let difficulty: SudokuDifficulty
    let elapsed: TimeInterval
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        DKCard(theme: theme) {
            VStack(spacing: theme.spacing.l) {
                VStack(spacing: theme.spacing.xs) {
                    Text(headline)
                        .font(theme.typography.titleLarge)
                        .foregroundStyle(theme.colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
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
                        String(localized: "View board"),
                        style: .secondary,
                        theme: theme,
                        action: onDismiss
                    )
                }
            }
            .padding(theme.spacing.l)
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private var headline: String {
        switch outcome {
        case .won:      return String(localized: "You solved it!")
        case .gameOver: return String(localized: "Out of mistakes")
        }
    }

    private var subtitle: String {
        switch outcome {
        case .won:
            return "\(difficulty.displayName) · \(formatElapsed(elapsed))"
        case .gameOver:
            return String(localized: "You used all 3 lives.")
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
