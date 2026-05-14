//
//  TimerChip.swift
//  gamekit
//
//  Props-only elapsed-timer chip extracted from MinesweeperHeaderBar
//  (Plan 11-01 / D-03). Preserves Phase 3 D-05 timer rendering
//  invariants verbatim:
//    - TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))
//    - When timerAnchor is nil, .distantPast anchor stops the tick;
//      displayedElapsed(at:) returns pausedElapsed unchanged.
//    - NO Timer.publish, NO Combine, NO Task { while … sleep }.
//    - monospaced digits via theme.typography.monoNumber so digits do
//      NOT jitter on every second tick.
//  Consumed by MinesweeperHeaderBar + MinesweeperGameView Large-zone
//  branch (Plan 11-04 / D-06 slot 2 stack).
//

import SwiftUI
import DesignKit

struct TimerChip: View {
    let theme: Theme
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
    /// Compact variant for Video Mode slot 2's stacked-chip slot (P11 11-04
    /// user-feedback polish 2026-05-13). When `true`, the chip drops one
    /// Dynamic Type step (caption instead of monoNumber/body), reduces
    /// horizontal padding (xs instead of m), and reduces vertical padding
    /// (xs instead of s) so two chips can stack inside `theme.spacing.xl`
    /// (the row's pill-height anchor). Off-path callers (HeaderBar) leave
    /// this defaulted to `false` and get the v1.0 chip byte-identical.
    var compact: Bool = false

    var body: some View {
        TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1)) { context in
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.colors.textPrimary)
                Text(formatElapsed(displayedElapsed(at: context.date)))
                    .font(compact ? theme.typography.caption : theme.typography.monoNumber)
                    .foregroundStyle(theme.colors.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, compact ? theme.spacing.xs : theme.spacing.m)
            .padding(.vertical, compact ? theme.spacing.xs : theme.spacing.s)
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
