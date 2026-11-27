//
//  SudokuWinTime.swift
//  gamekit
//
//  Pure text and easing for the win card's counting time (Phase 19.1,
//  DESIGN.md 10.2). Foundation only: the count-up is a function of elapsed
//  time so it can be tested without a view or a clock.
//
//  Sketch 012: the time counts from 0 to the final value over 1100ms with a
//  cubic ease-out, starting 300ms after the card appears.
//

import Foundation

nonisolated enum SudokuWinTime {

    /// Seconds the card waits before the number starts to move.
    static let countUpDelay: Double = 0.3
    /// Seconds the number takes to reach the final time.
    static let countUpDuration: Double = 1.1

    /// `m:ss` under an hour, `h:mm:ss` from an hour up. Fractions truncate;
    /// a negative time reads as zero.
    static func string(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// The value the counting time shows `elapsedSinceStart` seconds after
    /// the card appeared: 0 through the delay, the target once the duration
    /// has run, cubic ease-out in between.
    static func countUpSeconds(target: TimeInterval, elapsedSinceStart: Double) -> TimeInterval {
        let k = (elapsedSinceStart - countUpDelay) / countUpDuration
        if k <= 0 { return 0 }
        if k >= 1 { return target }
        return target * (1 - pow(1 - k, 3))
    }
}
