//
//  SudokuStatsCard.swift
//  gamekit
//
//  Per-difficulty Sudoku stats panel for StatsView. Mirrors the
//  NonogramStatsCard / MinesStatsCard discipline: pure props, no @Query,
//  no modelContext access. Adds an "Avg" column on top of the Games /
//  Wins / Best trio so per-difficulty average win time is visible
//  alongside the personal-best.
//

import SwiftUI
import DesignKit

struct SudokuStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var hasAnyRecord: Bool { !records.isEmpty }

    var body: some View {
        if !hasAnyRecord {
            Text(String(localized: "No Sudoku games played yet."))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textTertiary)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: theme.spacing.m,
                    verticalSpacing: theme.spacing.s
                ) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Text(String(localized: "Games")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Avg")).gridColumnAlignment(.trailing)
                        Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                    }
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)

                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 1)
                        .gridCellColumns(5)

                    ForEach(SudokuDifficulty.allCases, id: \.self) { diff in
                        SudokuDifficultyStatsRow(
                            theme: theme,
                            difficulty: diff,
                            records: records,
                            bestTimes: bestTimes
                        )
                    }
                }
            }
        }
    }
}

private struct SudokuDifficultyStatsRow: View {
    let theme: Theme
    let difficulty: SudokuDifficulty
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var wins: [GameRecord] {
        cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }
    }
    private var gamesCount: Int { cohort.count }
    private var winsCount: Int { wins.count }
    private var avgText: String {
        guard !wins.isEmpty else { return "—" }
        let total = wins.reduce(0.0) { $0 + $1.durationSeconds }
        return formatSeconds(total / Double(wins.count))
    }
    private var bestText: String {
        guard let s = bestTimes.first(where: {
            $0.difficultyRaw == difficulty.rawValue
        })?.seconds else { return "—" }
        return formatSeconds(s)
    }

    private func formatSeconds(_ s: Double) -> String {
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    var body: some View {
        GridRow {
            Text(difficulty.displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            statNumber("\(gamesCount)")
            statNumber("\(winsCount)")
            statNumber(avgText)
            statNumber(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            "\(difficulty.displayName): \(gamesCount) games, \(winsCount) wins, average \(avgText), best \(bestText)"
        ))
    }

    @ViewBuilder
    private func statNumber(_ s: String) -> some View {
        Text(s)
            .font(theme.typography.monoNumber)
            .monospacedDigit()
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.trailing)
    }
}
