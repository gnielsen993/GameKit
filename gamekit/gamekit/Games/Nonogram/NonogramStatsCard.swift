//
//  NonogramStatsCard.swift
//  gamekit
//
//  Per-difficulty Nonogram stats panel for StatsView. Mirrors the
//  MinesStatsCard / MergeStatsCard discipline: pure props, no @Query, no
//  modelContext access. Trailing row is a NavigationLink into the solved-
//  puzzles gallery — only enabled when at least one win exists.
//

import SwiftUI
import DesignKit

struct NonogramStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var hasAnyRecord: Bool { !records.isEmpty }
    /// Distinct curated puzzles solved. Procedural ids (`proc-*`) are
    /// excluded so the count matches what the gallery actually renders.
    private var solvedCount: Int {
        Set(
            records
                .filter { $0.outcomeRaw == Outcome.win.rawValue }
                .compactMap { $0.puzzleIdRaw }
                .filter { !$0.hasPrefix("proc-") }
        ).count
    }

    var body: some View {
        if !hasAnyRecord {
            Text(String(localized: "No Nonogram games played yet."))
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
                        Text(String(localized: "Best")).gridColumnAlignment(.trailing)
                    }
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)

                    Rectangle()
                        .fill(theme.colors.border)
                        .frame(height: 1)
                        .gridCellColumns(4)

                    ForEach(NonogramDifficulty.allCases, id: \.self) { diff in
                        NonogramDifficultyStatsRow(
                            theme: theme,
                            difficulty: diff,
                            records: records,
                            bestTimes: bestTimes
                        )
                    }
                }

                Rectangle()
                    .fill(theme.colors.border)
                    .frame(height: 1)

                NavigationLink {
                    SolvedNonogramsView(records: records)
                } label: {
                    HStack {
                        Text(String(localized: "Solved puzzles"))
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                        Text("\(solvedCount)")
                            .font(theme.typography.monoNumber)
                            .monospacedDigit()
                            .foregroundStyle(theme.colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(solvedCount == 0)
                .opacity(solvedCount == 0 ? 0.5 : 1)
                .accessibilityLabel(Text("Solved puzzles, \(solvedCount)"))
            }
        }
    }
}

private struct NonogramDifficultyStatsRow: View {
    let theme: Theme
    let difficulty: NonogramDifficulty
    let records: [GameRecord]
    let bestTimes: [BestTime]

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var games: Int { cohort.count }
    private var wins: Int {
        cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count
    }
    private var bestText: String {
        guard let s = bestTimes.first(where: {
            $0.difficultyRaw == difficulty.rawValue
        })?.seconds else { return "—" }
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    private var displayName: String {
        switch difficulty {
        case .tiny:   return String(localized: "Tiny")
        case .small:  return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large:  return String(localized: "Large")
        }
    }

    var body: some View {
        GridRow {
            Text(displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            statNumber("\(games)")
            statNumber("\(wins)")
            statNumber(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(displayName): \(games) games, \(wins) wins, best time \(bestText)"))
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
