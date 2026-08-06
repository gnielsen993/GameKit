//
//  NonogramTalkthroughCopy.swift
//  gamekit
//
//  Turns a NonogramTalkthrough.Deduction into a sentence.
//
//  Presentation-layer on purpose: the engine returns a structured technique
//  so the reasoning stays testable and the wording stays localizable. Every
//  sentence here states only what the solver actually proved — no case
//  reaches further than its technique allows.
//

import Foundation

enum NonogramTalkthroughCopy {

    /// "Row 4" / "Column 7" — 1-indexed, because the grid is not addressed
    /// by number anywhere in the UI and players count from one.
    static func lineName(_ line: NonogramTalkthrough.Line) -> String {
        switch line {
        case .row(let index):
            return String(format: String(localized: "Row %d"), index + 1)
        case .column(let index):
            return String(format: String(localized: "Column %d"), index + 1)
        }
    }

    static func explanation(for deduction: NonogramTalkthrough.Deduction) -> String {
        let line = lineName(deduction.line)
        let action = actionText(fills: deduction.newFilled.count, crosses: deduction.newEmpty.count)
        switch deduction.technique {
        case .overlap(let clue, let lineLength):
            return String(
                format: String(localized: "%@ has a block of %d in %d spaces. The highlighted squares are covered wherever that block starts. %@"),
                line, clue, lineLength, action
            )
        case .lineComplete:
            return String(
                format: String(localized: "%@ already has every filled square its clues need. %@"),
                line, action
            )
        case .allEmpty:
            return String(
                format: String(localized: "%@ has a 0 clue, so none of its squares are filled. %@"),
                line, action
            )
        case .forced:
            return String(
                format: String(localized: "Compare the clues with the squares already decided in %@. Only the highlighted choices still fit. %@"),
                line, action
            )
        }
    }

    private static func actionText(fills: Int, crosses: Int) -> String {
        if fills > 0 && crosses > 0 {
            return String(format: String(localized: "Fill %d and mark %d with X."), fills, crosses)
        }
        if fills > 0 {
            return String(format: String(localized: "Fill the %d highlighted squares."), fills)
        }
        return String(format: String(localized: "Mark the %d highlighted squares with X."), crosses)
    }

    static func unavailableMessage(_ reason: NonogramViewModel.TalkthroughUnavailable) -> String {
        switch reason {
        case .boardHasAMistake:
            // Says where to look without saying which square is wrong —
            // the same line-level honesty as the red clue numbers.
            return String(localized: "Something already placed does not match its clues. Check the rows and columns marked in red.")
        case .noLineDeduction:
            // The honest admission. Better than inventing a step.
            return String(localized: "No next square can be worked out from a single row or column here.")
        }
    }
}
