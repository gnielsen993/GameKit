import SwiftUI
import DesignKit

// Timer chip + deal label. Mirrors SudokuHeaderBar's thin-composer pattern.
// Layout: [VideoModeTimerChip] ── Spacer ── [deal · difficulty label]

struct FreeCellHeaderBar: View {
    let theme:        Theme
    let timerAnchor:  Date?
    let pausedElapsed: TimeInterval
    let dealNumber:   Int
    let difficulty:   FreeCellDifficulty?  // nil = Deal # mode

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: timerAnchor,
                pausedElapsed: pausedElapsed
            )
            Spacer()
            HStack(spacing: theme.spacing.xs) {
                Text("Deal #\(dealNumber)")
                    .foregroundStyle(theme.colors.textPrimary)
                if let difficulty {
                    Text(difficulty.label)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
            .font(theme.typography.caption.weight(.semibold))
            .lineLimit(1)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }
}
