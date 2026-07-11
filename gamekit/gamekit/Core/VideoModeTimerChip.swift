//
//  VideoModeTimerChip.swift
//  gamekit
//
//  Shared elapsed-timer chip for Video Mode games (P12 D-12-CHIPS — moved
//  from Games/Minesweeper/TimerChip.swift to Core/ so Nonogram + Merge
//  can consume the same primitive without duplicating the TimelineView
//  logic). Renamed in Plan 12-01.
//
//  Preserves Phase 3 D-05 timer rendering invariants verbatim:
//    - TimelineView(.periodic(from: timerAnchor ?? .distantPast, by: 1))
//    - When timerAnchor is nil, .distantPast anchor stops the tick;
//      displayedElapsed(at:) returns pausedElapsed unchanged.
//    - NO Timer.publish, NO Combine, NO Task { while … sleep }.
//    - monospaced digits via theme.typography.monoNumber so digits do
//      NOT jitter on every second tick.
//
//  Consumers:
//    - MinesweeperHeaderBar (off-path / Small PiP zones) with compact: false
//    - MinesweeperGameView+VideoMode.compactRowComposed (Large zones) with compact: true
//    - NonogramHeaderBar (Plan 12-03 refactor) with compact: false
//    - NonogramGameView Large zones (Plan 12-04) with compact: true
//

import SwiftUI
import DesignKit

struct VideoModeTimerChip: View {
    let theme: Theme
    let timerAnchor: Date?
    let pausedElapsed: TimeInterval
    /// Compact variant for Video Mode Large-zone compact row (P12 D-12-CHIPS).
    /// When `true`, drops one Dynamic Type step (caption instead of monoNumber)
    /// and tightens padding to `theme.spacing.xs` so the chip fits inside
    /// `theme.spacing.xl` (the compact-row's pill-height anchor). Off-path
    /// callers leave defaulted to `false` and get the v1.1 chip byte-identical.
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
            .gameInfoReadout(theme: theme, compact: compact)
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
