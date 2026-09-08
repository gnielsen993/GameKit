import SwiftUI
import DesignKit

struct MathCrosswordStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestTimes: [BestTime]

    var body: some View {
        if records.isEmpty {
            Text("No Math Crossword games played yet.")
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
                    Text("Games").gridColumnAlignment(.trailing)
                    Text("Wins").gridColumnAlignment(.trailing)
                    Text("Best").gridColumnAlignment(.trailing)
                }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)

                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                    .gridCellColumns(4)

                ForEach(MathCrosswordDifficulty.allCases, id: \.self) { difficulty in
                    MathCrosswordStatsRow(
                        theme: theme,
                        difficulty: difficulty,
                        records: records,
                        bestTimes: bestTimes
                    )
                }
            }
        }
    }
}

private struct MathCrosswordStatsRow: View {
    let theme: Theme
    let difficulty: MathCrosswordDifficulty
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }

    private var winCount: Int {
        cohort.filter { $0.outcome == .win }.count
    }

    private var best: String {
        guard let seconds = bestTimes.first(where: { $0.difficultyRaw == difficulty.rawValue })?.seconds else {
            return "—"
        }
        let total = max(0, Int(seconds.rounded()))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    var body: some View {
        GridRow {
            Text(difficulty.displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            stat("\(cohort.count)")
            stat("\(winCount)")
            stat(best)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(difficulty.displayName): \(cohort.count) games, \(winCount) wins, best \(best)"))
    }

    private func stat(_ value: String) -> some View {
        Text(value)
            .font(theme.typography.monoNumber)
            .foregroundStyle(theme.colors.textPrimary)
            .monospacedDigit()
            .gridColumnAlignment(.trailing)
    }
}
