//
//  StatsView.swift
//  gamekit
//
//  Phase 4 (PERSIST-01 / PERSIST-02 / SHELL-03): per-difficulty Minesweeper
//  stats backed by SwiftData @Query. Replaces the P1 stub.
//
//  Layout per 04-UI-SPEC §Component Inventory + §Layout & Sizing:
//    - Single MINESWEEPER section (replaces P1's HISTORY + BEST TIMES split)
//    - DKCard wrapping a Grid: 4 column-headers row + 1pt border rule + 3
//      always-rendered difficulty rows (Easy / Medium / Hard) per D-25
//    - Per-row a11y label "Easy: 12 games, 8 wins, 67 percent, best time
//      1 minute 42 seconds" via .accessibilityElement(children: .combine)
//      (UI-SPEC §A11y labels)
//
//  Empty state (D-26 + SC2 verbatim):
//    - When `minesRecords.isEmpty`: replace the Grid with single-line
//      "No games played yet." in theme.colors.textTertiary
//
//  Token discipline (CLAUDE.md §1, §8.4 + FOUND-07 hook):
//    - Zero Color(...) literals; every padding/spacing reads
//      theme.spacing.{token}; every font reads theme.typography.{token}
//    - monoNumber + .monospacedDigit() paired pattern for stat numerals
//      (P3-locked per UI-SPEC §Typography — required so digits don't
//      jitter when stats update)
//
//  Phase 4 invariants:
//    - StatsView is data-driven, NOT data-fetching beyond the @Query
//      (CLAUDE.md §8.2 — but the @Query IS the parent's data fetch in
//      SwiftUI; the file-private MinesStatsCard / MinesDifficultyStatsRow
//      receive props, never @Query directly)
//    - No separate StatsViewModel — pure-SwiftUI computed properties
//      derive per-difficulty rows from the two @Query arrays (D-24)
//

import SwiftUI
import SwiftData
import DesignKit

struct StatsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "minesweeper" },
        sort: \.playedAt,
        order: .reverse
    )
    private var minesRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "minesweeper" })
    private var minesBestTimes: [BestTime]

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    settingsSectionHeader(theme: theme, String(localized: "MINESWEEPER"))

                    DKCard(theme: theme) {
                        MinesStatsCard(
                            theme: theme,
                            records: minesRecords,
                            bestTimes: minesBestTimes
                        )
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Stats"))
        }
    }
}

// MARK: - File-private composition (UI-SPEC §Component Inventory)

/// Per-game stats card content. Reusable enough to receive a `gameKind`
/// filter when game 2 lands; in P4 it's hardcoded to Minesweeper.
private struct MinesStatsCard: View {
    let theme: Theme
    let records: [GameRecord]
    let bestTimes: [BestTime]

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            statsGrid
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        // D-26 + SC2 verbatim.
        Text(String(localized: "No games played yet."))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textTertiary)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statsGrid: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: theme.spacing.m,
            verticalSpacing: theme.spacing.s
        ) {
            // Column headers (UI-SPEC §Copywriting).
            GridRow {
                Text("").gridColumnAlignment(.leading)
                Text(String(localized: "Games")).gridColumnAlignment(.trailing)
                Text(String(localized: "Wins")).gridColumnAlignment(.trailing)
                Text(String(localized: "Win %")).gridColumnAlignment(.trailing)
                Text(String(localized: "Best")).gridColumnAlignment(.trailing)
            }
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.textSecondary)

            // Divider rule (UI-SPEC §Layout — 1pt theme.colors.border, spans 5 cols).
            Rectangle()
                .fill(theme.colors.border)
                .frame(height: 1)
                .gridCellColumns(5)

            // 3 always-rendered difficulty rows (D-25).
            ForEach(MinesweeperDifficulty.allCases, id: \.self) { diff in
                MinesDifficultyStatsRow(
                    theme: theme,
                    difficulty: diff,
                    records: records,
                    bestTimes: bestTimes
                )
            }
        }
    }
}

/// One difficulty's row: label + 4 stat values. Pure props.
private struct MinesDifficultyStatsRow: View {
    let theme: Theme
    let difficulty: MinesweeperDifficulty
    let records: [GameRecord]
    let bestTimes: [BestTime]

    // MARK: - Derived stats (D-25, D-27 — pure SwiftUI computed)

    private var cohort: [GameRecord] {
        records.filter { $0.difficultyRaw == difficulty.rawValue }
    }
    private var games: Int { cohort.count }
    private var wins: Int {
        cohort.filter { $0.outcomeRaw == Outcome.win.rawValue }.count
    }
    private var winPctText: String {
        // D-27: integer percent; "—" when games == 0.
        guard games > 0 else { return "—" }
        return "\(Int((Double(wins) * 100.0 / Double(games)).rounded()))%"
    }
    private var bestSeconds: Double? {
        bestTimes.first(where: { $0.difficultyRaw == difficulty.rawValue })?.seconds
    }
    private var bestText: String {
        // mm:ss when < 60min; h:mm:ss when ≥ 60min (UI-SPEC §Copywriting).
        // "—" when no win recorded.
        guard let s = bestSeconds else { return "—" }
        return Self.format(seconds: s)
    }

    static func format(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    private var displayName: String {
        switch difficulty {
        case .easy:   return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard:   return String(localized: "Hard")
        }
    }

    // MARK: - Body

    var body: some View {
        GridRow {
            Text(displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
            statNumber("\(games)")
            statNumber("\(wins)")
            statNumber(winPctText)
            statNumber(bestText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    @ViewBuilder
    private func statNumber(_ s: String) -> some View {
        Text(s)
            .font(theme.typography.monoNumber)
            .monospacedDigit()                                  // P3-locked pairing
            .foregroundStyle(theme.colors.textPrimary)
            .gridColumnAlignment(.trailing)
    }

    // UI-SPEC §A11y labels — "Easy: 12 games, 8 wins, 67 percent, best time 1 minute 42 seconds"
    private var a11yLabel: String {
        let pctSpoken = games > 0
            ? "\(Int((Double(wins) * 100.0 / Double(games)).rounded())) percent"
            : "no percent yet"
        let bestSpoken: String = {
            guard let s = bestSeconds else { return "no best time yet" }
            let total = Int(s.rounded())
            let m = total / 60
            let sec = total % 60
            if m == 0 { return "\(sec) seconds" }
            if sec == 0 { return "\(m) minute\(m == 1 ? "" : "s")" }
            return "\(m) minute\(m == 1 ? "" : "s") \(sec) second\(sec == 1 ? "" : "s")"
        }()
        return String(
            localized: "\(displayName): \(games) games, \(wins) wins, \(pctSpoken), best time \(bestSpoken)"
        )
    }
}
