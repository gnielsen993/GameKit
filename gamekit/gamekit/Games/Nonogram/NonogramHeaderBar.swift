//
//  NonogramHeaderBar.swift
//  gamekit
//
//  Title chip + elapsed-timer chip for the Nonogram game scene.
//  Mirrors MinesweeperHeaderBar shape: TimelineView-driven timer (no
//  Combine, no Task/sleep), monospaced digits, .distantPast anchor when
//  the timer is frozen so it does not tick.
//

import SwiftUI
import DesignKit

struct NonogramHeaderBar: View {
    let theme: Theme
    /// Size label like "10 × 10". The puzzle's actual title is intentionally
    /// NOT shown here during play — it would spoil the picture the player
    /// is solving. Title only appears on the end-state card.
    let sizeLabel: String
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
    /// nil = Free mode (hide the lives chip). Otherwise a 0…3 count of
    /// lives remaining; the chip renders 3 hearts and dims the missing ones.
    let livesRemaining: Int?

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            sizeChip
            if let livesRemaining {
                livesChip(remaining: livesRemaining)
            }
            Spacer()
            timerChip
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    // MARK: - Lives chip (visible only in Lives mode)

    private func livesChip(remaining: Int) -> some View {
        HStack(spacing: theme.spacing.xs / 2) {
            ForEach(0..<NonogramGameMode.livesPerPuzzle, id: \.self) { i in
                Image(systemName: i < remaining ? "heart.fill" : "heart")
                    .foregroundStyle(i < remaining
                                     ? theme.colors.danger
                                     : theme.colors.textTertiary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(remaining) of \(NonogramGameMode.livesPerPuzzle) lives remaining"))
    }

    // MARK: - Size chip (no spoilers)

    private var sizeChip: some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "square.grid.3x3.square")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(sizeLabel)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Puzzle size \(sizeLabel)"))
    }

    // MARK: - Timer chip (matches MinesweeperHeaderBar exactly)

    @ViewBuilder
    private var timerChip: some View {
        TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1)) { context in
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.colors.textPrimary)
                Text(formatElapsed(displayedElapsed(at: context.date)))
                    .font(theme.typography.monoNumber)
                    .foregroundStyle(theme.colors.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radii.chip, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Time elapsed"))
        }
    }

    private func displayedElapsed(at now: Date) -> TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, now.timeIntervalSince(anchor))
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
