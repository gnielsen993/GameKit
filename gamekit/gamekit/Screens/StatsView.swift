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
    var focusedKind: GameKind? = nil

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

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "merge" },
        sort: \.playedAt,
        order: .reverse
    )
    private var mergeRecords: [GameRecord]

    @Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "merge" })
    private var mergeBestScores: [BestScore]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "nonogram" },
        sort: \.playedAt,
        order: .reverse
    )
    private var nonogramRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "nonogram" })
    private var nonogramBestTimes: [BestTime]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "sudoku" },
        sort: \.playedAt,
        order: .reverse
    )
    private var sudokuRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "sudoku" })
    private var sudokuBestTimes: [BestTime]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "freeCell" },
        sort: \.playedAt,
        order: .reverse
    )
    private var freeCellRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "freeCell" })
    private var freeCellBestTimes: [BestTime]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "klondike" },
        sort: \.playedAt,
        order: .reverse
    )
    private var klondikeRecords: [GameRecord]

    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "klondike" })
    private var klondikeBestTimes: [BestTime]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "fiveLetter" },
        sort: \.playedAt,
        order: .reverse
    )
    private var fiveLetterRecords: [GameRecord]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "wordGrid" },
        sort: \.playedAt,
        order: .reverse
    )
    private var wordGridRecords: [GameRecord]

    @Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "wordGrid" })
    private var wordGridBestScores: [BestScore]

    // Phase 15 (ARCADE-05/09): Stack + Snake @Query pairs.
    // Score-based shape (BestScore, not BestTime) per ARCADE-07 / 15-PATTERNS.md.
    // Placeholder sections; replaced by StackStatsCard/SnakeStatsCard in Phase 16/17.

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "stack" },
        sort: \.playedAt,
        order: .reverse
    )
    private var stackRecords: [GameRecord]

    @Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "stack" })
    private var stackBestScores: [BestScore]

    @Query(
        filter: #Predicate<GameRecord> { $0.gameKindRaw == "snake" },
        sort: \.playedAt,
        order: .reverse
    )
    private var snakeRecords: [GameRecord]

    @Query(filter: #Predicate<BestScore> { $0.gameKindRaw == "snake" })
    private var snakeBestScores: [BestScore]

    @Query(filter: #Predicate<GameRecord> { $0.gameKindRaw == "mathCrossword" }, sort: \.playedAt, order: .reverse)
    private var mathCrosswordRecords: [GameRecord]
    @Query(filter: #Predicate<BestTime> { $0.gameKindRaw == "mathCrossword" })
    private var mathCrosswordBestTimes: [BestTime]

    private var theme: Theme { themeManager.theme(using: colorScheme) }

    private func shows(_ kind: GameKind) -> Bool {
        focusedKind == nil || focusedKind == kind
    }

    private var navigationTitle: String {
        guard let kind = focusedKind,
              let title = GameDescriptor.all.first(where: { $0.kind == kind })?.titleKey
        else { return String(localized: "Stats") }
        return title
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {

                    if shows(.mathCrossword) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "MATH CROSSWORD")) }
                        DKCard(theme: theme) {
                            MathCrosswordStatsCard(theme: theme, records: mathCrosswordRecords, bestTimes: mathCrosswordBestTimes)
                        }
                    }
                    if shows(.minesweeper) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "MINESWEEPER")) }
                        DKCard(theme: theme) {
                            MinesStatsCard(theme: theme, records: minesRecords, bestTimes: minesBestTimes)
                        }
                    }

                    if shows(.merge) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "MERGE")) }
                        DKCard(theme: theme) {
                            MergeStatsCard(theme: theme, records: mergeRecords, bestScores: mergeBestScores)
                        }
                    }

                    if shows(.nonogram) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "NONOGRAM")) }
                        DKCard(theme: theme) {
                            NonogramStatsCard(theme: theme, records: nonogramRecords, bestTimes: nonogramBestTimes)
                        }
                    }

                    if shows(.sudoku) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SUDOKU")) }
                        DKCard(theme: theme) {
                            SudokuStatsCard(theme: theme, records: sudokuRecords, bestTimes: sudokuBestTimes)
                        }
                    }

                    if shows(.freeCell) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "FREECELL")) }
                        DKCard(theme: theme) {
                            FreeCellStatsCard(theme: theme, records: freeCellRecords, bestTimes: freeCellBestTimes)
                        }
                    }

                    if shows(.klondike) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SOLITAIRE")) }
                        DKCard(theme: theme) {
                            SolitaireStatsCard(theme: theme, records: klondikeRecords, bestTimes: klondikeBestTimes)
                        }
                    }

                    if shows(.fiveLetter) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "FIVE LETTER")) }
                        DKCard(theme: theme) {
                            FiveLetterStatsCard(theme: theme, records: fiveLetterRecords)
                        }
                    }

                    if shows(.wordGrid) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "WORD GRID")) }
                        DKCard(theme: theme) {
                            WordGridStatsCard(theme: theme, records: wordGridRecords, bestScores: wordGridBestScores)
                        }
                    }

                    if shows(.stack) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "STACK")) }
                        DKCard(theme: theme) {
                            StackStatsCard(theme: theme, records: stackRecords, bestScores: stackBestScores)
                        }
                    }

                    if shows(.snake) {
                        if focusedKind == nil { settingsSectionHeader(theme: theme, String(localized: "SNAKE")) }
                        DKCard(theme: theme) {
                            SnakeStatsCard(theme: theme, records: snakeRecords, bestScores: snakeBestScores)
                        }
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
        }
    }
}

// MARK: - Merge stats card (props-only, no @Query)
