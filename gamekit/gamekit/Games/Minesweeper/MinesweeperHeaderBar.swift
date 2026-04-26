//
//  MinesweeperHeaderBar.swift
//  gamekit
//
//  Mine-counter chip + elapsed-timer chip for the Minesweeper game scene.
//  Props-only data-driven view (CLAUDE.md §8.2): receives theme + the four
//  primitives that drive its render — minesRemaining, timerAnchor, pausedElapsed.
//
//  Phase 3 invariants (per D-05, UI-SPEC §Typography monoNumber rule):
//    - Timer rendered via TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))
//    - NO Timer.publish, NO Combine, NO Task { while … sleep } — D-05 forbids
//    - monospaced digits via theme.typography.monoNumber so digits do NOT jitter
//      on every second tick (counter and timer both)
//    - When timerAnchor is nil (paused/idle/terminal), display reads pausedElapsed —
//      timer freezes correctly without TimelineView re-firing (.distantPast anchor
//      makes TimelineView stop ticking entirely)
//    - Zero Color(...) literals (FOUND-07 hook); zero raw integer paddings
//

import SwiftUI
import DesignKit

struct MinesweeperHeaderBar: View {
    let theme: Theme
    let minesRemaining: Int
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            counterChip(value: minesRemaining)
            Spacer()
            timerChip
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
    }

    // MARK: - Counter chip

    @ViewBuilder
    private func counterChip(value: Int) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "flag.fill")
                .foregroundStyle(theme.colors.danger)
            Text(formatCounter(value))
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
        .accessibilityLabel(Text("\(value) mines remaining"))
    }

    /// Counter format: 3-digit zero-pad for positive values; bare integer with leading
    /// minus for negative (over-flagging produces a negative counter — informational
    /// per VM behavior in Plan 02). Examples: 042 / -3 / 099.
    private func formatCounter(_ n: Int) -> String {
        if n >= 0 { return String(format: "%03d", n) }
        return "\(n)"
    }

    // MARK: - Timer chip

    /// When `timerAnchor` is nil (paused/idle/terminal), TimelineView is anchored at
    /// `.distantPast` so it does not fire — display math returns `pausedElapsed`,
    /// which is the correct frozen value for idle (00:00) and terminal (final time).
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
            .accessibilityValue(Text(formatElapsedSpoken(displayedElapsed(at: context.date))))
        }
    }

    // MARK: - Time math (mirrors Plan 02 VM frozenElapsed contract)

    private func displayedElapsed(at now: Date) -> TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, now.timeIntervalSince(anchor))
    }

    /// Format elapsed as `m:ss` (or `h:mm:ss` if ≥ 60 min). Clamps negatives
    /// to 0 (RESEARCH §Pattern 2 — system-clock-rollback safety).
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

    /// Spoken version for VoiceOver. "2 minutes 14 seconds" not "0 2 colon 1 4".
    private func formatElapsedSpoken(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append(String(localized: "\(h) hours")) }
        parts.append(String(localized: "\(m) minutes"))
        parts.append(String(localized: "\(s) seconds"))
        return parts.joined(separator: " ")
    }
}
