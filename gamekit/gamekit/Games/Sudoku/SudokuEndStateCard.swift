//
//  SudokuEndStateCard.swift
//  gamekit
//
//  Terminal-state overlay for the Sudoku scene, restyled with the pieces
//  design language (Phase 19.1, DESIGN.md 3.6). One centered card shared by
//  all four layouts (D-15). Three variants:
//    - .won              "Solved", difficulty (plus hint disclosure), the
//                        time counting up, "Your best <difficulty> time"
//                        only when GameStats says a best was set, then
//                        Next puzzle and Back to the drawer as pieces.
//    - .gameOver         "Out of mistakes", "Keep solving" / "Retry".
//    - .practiceComplete "Finished in practice", "Retry this puzzle".
//  Actions are PieceCTAButton pieces; "View board" stays a quiet text button.
//

import SwiftUI
import DesignKit

enum SudokuEndStateOutcome {
    case won
    case gameOver
    case practiceComplete
}

struct SudokuEndStateCard: View {
    let theme: Theme
    let outcome: SudokuEndStateOutcome
    let difficulty: SudokuDifficulty
    let elapsed: TimeInterval
    var assistCount: Int = 0
    /// What GameStats said about this win. Only `.won` reads it; the badge
    /// is built from `setBestTime` and nothing else (D-09, D-13).
    var record: RecordResult? = nil
    let onPrimary: () -> Void
    var onRetry: (() -> Void)? = nil
    /// Leaves Sudoku for Home. Shown on the win only.
    var onBack: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        DKCard(theme: theme) {
            // At the largest text sizes on a small phone the content is
            // taller than the screen: it scrolls instead of running off it.
            ViewThatFits(in: .vertical) {
                cardContent
                ScrollView { cardContent }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.m)
    }

    private var cardContent: some View {
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

            timeBlock

            VStack(spacing: theme.spacing.s) {
                PieceCTAButton(
                    primaryButtonLabel,
                    theme: theme,
                    identifier: "sudoku.endCard.primary",
                    action: onPrimary
                )
                if outcome == .won, let onBack {
                    PieceCTAButton(
                        String(localized: "Back to the drawer"),
                        theme: theme,
                        prominence: .secondary,
                        identifier: "sudoku.endCard.secondary",
                        action: onBack
                    )
                }
                if outcome == .gameOver, let onRetry {
                    PieceCTAButton(
                        String(localized: "Retry this puzzle"),
                        theme: theme,
                        prominence: .secondary,
                        identifier: "sudoku.endCard.secondary",
                        action: onRetry
                    )
                }
                viewBoardButton
            }
        }
        .padding(theme.spacing.l)
    }

    // MARK: - Time

    @ViewBuilder
    private var timeBlock: some View {
        if outcome == .won {
            VStack(spacing: theme.spacing.s) {
                SudokuCountUpTime(seconds: elapsed, theme: theme)
                if record?.setBestTime == true {
                    bestBadge
                }
            }
        } else {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.colors.textPrimary)
                Text(SudokuWinTime.string(elapsed))
                    .font(theme.typography.monoNumber)
                    .foregroundStyle(theme.colors.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    private var bestBadge: some View {
        Text(String(format: String(localized: "Your best %@ time"), difficulty.displayName))
            .font(RoundedType.font(.caption, weight: .bold))
            .foregroundStyle(theme.colors.accentPrimary)
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.xs)
            .background(Capsule().fill(theme.colors.accentPrimary.opacity(0.14)))
            .accessibilityIdentifier("sudoku.endCard.bestBadge")
    }

    private var viewBoardButton: some View {
        Button(action: onDismiss) {
            Text(String(localized: "View board"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sudoku.endCard.viewBoard")
    }

    // MARK: - Copy

    private var headline: String {
        switch outcome {
        case .won: return String(localized: "Solved")
        case .gameOver: return String(localized: "Out of mistakes")
        case .practiceComplete: return String(localized: "Finished in practice")
        }
    }

    private var subtitle: String {
        switch outcome {
        case .won:
            let base = difficulty.displayName
            guard assistCount > 0 else { return base }
            let disclosure = assistCount == 1
                ? String(localized: "Solved with 1 hint")
                : String(format: String(localized: "Solved with %d hints"), assistCount)
            return "\(base) · \(disclosure)"
        case .gameOver:
            return String(localized: "You used all 3 lives.")
        case .practiceComplete:
            return String(localized: "Your ranked run ended when the hearts ran out.")
        }
    }

    private var primaryButtonLabel: String {
        switch outcome {
        case .won: return String(localized: "Next puzzle")
        case .gameOver: return String(localized: "Keep solving")
        case .practiceComplete: return String(localized: "Retry this puzzle")
        }
    }
}
