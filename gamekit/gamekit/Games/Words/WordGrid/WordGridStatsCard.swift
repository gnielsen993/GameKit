import SwiftUI
import DesignKit

struct WordGridStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestScores: [BestScore]

    var body: some View {
        if records.isEmpty {
            Text(String(localized: "No Word Grid games played yet."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity)
        } else {
            Grid(alignment: .leading, horizontalSpacing: theme.spacing.m, verticalSpacing: theme.spacing.s) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    Text(String(localized: "Games")).gridColumnAlignment(.trailing)
                    Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)

                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                    .gridCellColumns(3)

                ForEach(WordGridMode.allCases, id: \.self) { mode in
                    GridRow {
                        Text(mode.displayName)
                        Text("\(records.filter { $0.difficultyRaw == mode.rawValue }.count)")
                            .gridColumnAlignment(.trailing)
                        Text("\(bestScores.first { $0.difficultyRaw == mode.rawValue }?.score ?? 0)")
                            .gridColumnAlignment(.trailing)
                    }
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                }
            }
        }
    }
}
