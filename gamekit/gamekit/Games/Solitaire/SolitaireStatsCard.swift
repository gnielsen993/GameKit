import SwiftUI
import DesignKit

struct SolitaireStatsCard: View {
    let theme:     Theme
    let records:   [GameRecord]
    let bestTimes: [BestTime]

    var body: some View {
        if records.isEmpty {
            Text(String(localized: "No Solitaire games played yet."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity)
        } else {
            Grid(
                alignment: .leading,
                horizontalSpacing: theme.spacing.m,
                verticalSpacing: theme.spacing.s
            ) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                    Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)

                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                    .gridCellColumns(3)

                ForEach(SolitaireDifficulty.allCases, id: \.self) { d in
                    SolitaireDifficultyRow(
                        theme:      theme,
                        difficulty: d,
                        records:    records,
                        bestTimes:  bestTimes
                    )
                }
            }
        }
    }
}

private struct SolitaireDifficultyRow: View {
    let theme:      Theme
    let difficulty: SolitaireDifficulty
    let records:    [GameRecord]
    let bestTimes:  [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var wins: Int { cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count }

    private var bestText: String {
        guard let s = bestTimes.first(where: { $0.difficultyRaw == difficulty.rawValue })?.seconds
        else { return "—" }
        return formatTime(s)
    }

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 2) {
                Text(difficulty.label)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(difficulty.detail)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            statNum("\(wins)")
            statNum(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(difficulty.label): \(wins) wins, best \(bestText)"))
    }

    @ViewBuilder
    private func statNum(_ s: String) -> some View {
        Text(s)
            .font(theme.typography.monoNumber)
            .monospacedDigit()
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.trailing)
    }

    private func formatTime(_ s: Double) -> String {
        let t = Int(s.rounded())
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}
