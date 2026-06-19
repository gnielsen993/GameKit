import SwiftUI
import DesignKit

struct FiveLetterStatsCard: View {
    let theme: Theme
    let records: [GameRecord]

    var body: some View {
        if records.isEmpty {
            Text(String(localized: "No Five Letter games played yet."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                summaryRow(title: String(localized: "Daily Challenge"), records: dailyRecords)
                summaryRow(title: String(localized: "Unlimited"), records: unlimitedRecords)
                guessDistribution(records: records)
            }
        }
    }

    private var dailyRecords: [GameRecord] {
        records.filter { $0.difficultyRaw == FiveLetterMode.daily.rawValue }
    }

    private var unlimitedRecords: [GameRecord] {
        records.filter { $0.difficultyRaw == FiveLetterMode.unlimited.rawValue }
    }

    private func wins(in records: [GameRecord]) -> Int {
        records.filter { $0.outcome == .win }.count
    }

    private func summaryRow(title: String, records: [GameRecord]) -> some View {
        let winCount = wins(in: records)
        return Grid(alignment: .leading, horizontalSpacing: theme.spacing.m, verticalSpacing: theme.spacing.s) {
            GridRow {
                Text(title)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .gridCellColumns(4)
            }
            GridRow {
                stat("Games", "\(records.count)")
                stat("Wins", "\(winCount)")
                stat("Win %", "\(Int((Double(winCount) / Double(max(1, records.count))) * 100))")
                stat("Streak", "\(currentStreak(records: records))")
            }
        }
    }

    private func guessDistribution(records: [GameRecord]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(String(localized: "Guess distribution"))
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textSecondary)
            ForEach(1...6, id: \.self) { guess in
                let count = records.filter { $0.outcome == .win && $0.score == guess }.count
                HStack(spacing: theme.spacing.s) {
                    Text("\(guess)")
                        .font(theme.typography.caption.monospacedDigit())
                        .foregroundStyle(theme.colors.textSecondary)
                    Rectangle()
                        .fill(theme.colors.accentPrimary)
                        .frame(width: CGFloat(max(1, count)) * 18, height: 8)
                        .opacity(count == 0 ? 0.25 : 1)
                    Text("\(count)")
                        .font(theme.typography.caption.monospacedDigit())
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
    }

    private func currentStreak(records: [GameRecord]) -> Int {
        var streak = 0
        for record in records.sorted(by: { $0.playedAt > $1.playedAt }) {
            if record.outcome == .win {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(String(localized: "\(label)"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Text(value)
                .font(theme.typography.monoNumber.monospacedDigit())
                .foregroundStyle(theme.colors.textPrimary)
        }
    }
}
