//
//  SolvedNonogramsView.swift
//  gamekit
//
//  Gallery of nonogram puzzles the player has solved. Reads winning
//  GameRecord rows (filtered upstream) and resolves each unique
//  `puzzleIdRaw` against NonogramLibrary to render a mini-grid of the
//  solution. Grouped by difficulty in shipped order.
//
//  Pure props — the parent (StatsView via NonogramStatsCard) owns the
//  @Query. Mirrors §8.2.
//

import SwiftUI
import DesignKit

struct SolvedNonogramsView: View {
    let records: [GameRecord]

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    private var theme: Theme { themeManager.theme(using: colorScheme) }

    /// Resolved (difficulty, puzzle, fastest seconds) tuples — winning
    /// records only; deduplicated by puzzle id; missing-from-library ids
    /// are dropped silently (e.g. shipped puzzle removed in a later
    /// version — old stats record lingers but has nothing to render).
    private var solvedByDifficulty: [(NonogramDifficulty, [SolvedEntry])] {
        var byDiff: [NonogramDifficulty: [String: SolvedEntry]] = [:]
        for diff in NonogramDifficulty.allCases {
            let library = Dictionary(
                uniqueKeysWithValues: NonogramLibrary
                    .puzzles(for: diff)
                    .map { ($0.id, $0) }
            )
            let cohort = records.filter {
                $0.outcomeRaw == Outcome.win.rawValue
                    && $0.difficultyRaw == diff.rawValue
            }
            for rec in cohort {
                guard let pid = rec.puzzleIdRaw,
                      let puzzle = library[pid] else { continue }
                let prior = byDiff[diff]?[pid]
                let bestSeconds = min(prior?.bestSeconds ?? .infinity, rec.durationSeconds)
                let firstAt = min(prior?.firstSolvedAt ?? rec.playedAt, rec.playedAt)
                byDiff[diff, default: [:]][pid] = SolvedEntry(
                    puzzle: puzzle,
                    difficulty: diff,
                    bestSeconds: bestSeconds,
                    firstSolvedAt: firstAt
                )
            }
        }
        return NonogramDifficulty.allCases.compactMap { diff in
            guard let entries = byDiff[diff], !entries.isEmpty else { return nil }
            let sorted = entries.values.sorted { $0.firstSolvedAt > $1.firstSolvedAt }
            return (diff, sorted)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                if solvedByDifficulty.isEmpty {
                    Text(String(localized: "No solved puzzles yet."))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, theme.spacing.xl)
                } else {
                    ForEach(solvedByDifficulty, id: \.0) { (diff, entries) in
                        sectionHeader(for: diff)
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 100), spacing: theme.spacing.m)
                            ],
                            spacing: theme.spacing.m
                        ) {
                            ForEach(entries) { entry in
                                SolvedThumbnail(theme: theme, entry: entry)
                            }
                        }
                    }
                }
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Solved"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sectionHeader(for diff: NonogramDifficulty) -> some View {
        Text(headerLabel(for: diff))
            .font(theme.typography.caption.weight(.semibold))
            .foregroundStyle(theme.colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func headerLabel(for diff: NonogramDifficulty) -> String {
        switch diff {
        case .tiny:   return String(localized: "Tiny  ·  5 × 5")
        case .small:  return String(localized: "Small  ·  10 × 10")
        case .medium: return String(localized: "Medium  ·  15 × 15")
        case .large:  return String(localized: "Large  ·  20 × 20")
        }
    }
}

private struct SolvedEntry: Identifiable, Hashable {
    let puzzle: NonogramPuzzle
    let difficulty: NonogramDifficulty
    let bestSeconds: TimeInterval
    let firstSolvedAt: Date
    var id: String { puzzle.id }
}

private struct SolvedThumbnail: View {
    let theme: Theme
    let entry: SolvedEntry

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            MiniSolutionGrid(
                theme: theme,
                puzzle: entry.puzzle,
                size: entry.difficulty.size
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)

            Text(entry.puzzle.title)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)

            Text(formatElapsed(entry.bestSeconds))
                .font(theme.typography.caption)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textTertiary)
        }
        .padding(theme.spacing.s)
        .background(
            RoundedRectangle(cornerRadius: theme.radii.card)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.card)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Solved: \(entry.puzzle.title), best \(formatElapsed(entry.bestSeconds))"))
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

/// Pure rendering of a puzzle's solution as a tight grid of squares.
/// Filled cells use textPrimary; empty cells use surface; thin border
/// from `theme.colors.border`. No interactivity, no hints, no padding —
/// this is the "thumbnail" version.
private struct MiniSolutionGrid: View {
    let theme: Theme
    let puzzle: NonogramPuzzle
    let size: Int

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(size)
            let solution = puzzle.solution
            ZStack {
                Rectangle()
                    .fill(theme.colors.background)
                Path { path in
                    for r in 0..<size {
                        for c in 0..<size {
                            let idx = r * size + c
                            if idx < solution.count, solution[idx] {
                                path.addRect(
                                    CGRect(
                                        x: CGFloat(c) * cell,
                                        y: CGFloat(r) * cell,
                                        width: cell,
                                        height: cell
                                    )
                                )
                            }
                        }
                    }
                }
                .fill(theme.colors.textPrimary)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                Rectangle()
                    .stroke(theme.colors.border, lineWidth: 0.5)
                    .frame(width: side, height: side)
            )
        }
    }
}
