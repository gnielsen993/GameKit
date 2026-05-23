import SwiftUI
import DesignKit

// Pure props — StatsView owns the @Query; this card just renders.
// Mirrors SudokuStatsCard / NonogramStatsCard discipline.

struct FreeCellStatsCard: View {
    let theme:     Theme
    let records:   [GameRecord]
    let bestTimes: [BestTime]

    // Ordered display rows: 4 difficulty tiers + Deal # catch-all
    private static let rows: [(label: String, raw: String)] = [
        (String(localized: "Easy"),   "easy"),
        (String(localized: "Medium"), "medium"),
        (String(localized: "Hard"),   "hard"),
        (String(localized: "Expert"), "expert"),
        (String(localized: "Deal #"), "deal"),
    ]

    var body: some View {
        if records.isEmpty {
            Text(String(localized: "No FreeCell games played yet."))
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
                    Text(String(localized: "Games")).gridColumnAlignment(.trailing)
                    Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                    Text(String(localized: "Win %")).gridColumnAlignment(.trailing)
                    Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)

                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)
                    .gridCellColumns(5)

                ForEach(Self.rows, id: \.raw) { row in
                    FreeCellDifficultyRow(
                        theme:        theme,
                        label:        row.label,
                        difficultyRaw: row.raw,
                        records:      records,
                        bestTimes:    bestTimes
                    )
                }
            }
        }
    }
}

private struct FreeCellDifficultyRow: View {
    let theme:         Theme
    let label:         String
    let difficultyRaw: String
    let records:       [GameRecord]
    let bestTimes:     [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficultyRaw }
    }
    private var gamesCount: Int { cohort.count }
    private var winsCount:  Int { cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count }

    private var winPctText: String {
        guard gamesCount > 0 else { return "—" }
        return "\(Int((Double(winsCount) * 100.0 / Double(gamesCount)).rounded()))%"
    }

    private var bestText: String {
        guard let s = bestTimes.first(where: { $0.difficultyRaw == difficultyRaw })?.seconds
        else { return "—" }
        return formatTime(s)
    }

    var body: some View {
        GridRow {
            Text(label)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            statNum("\(gamesCount)")
            statNum("\(winsCount)")
            statNum(winPctText)
            statNum(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(label): \(gamesCount) games, \(winsCount) wins, \(winPctText), best \(bestText)"
        ))
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
