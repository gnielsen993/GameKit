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
        switch deduction.technique {
        case .overlap(let clue, let lineLength):
            // The classic teachable case, and the reason this feature is a
            // talkthrough rather than a reveal: the argument transfers.
            return String(
                format: String(localized: "%@ has a run of %d in %d squares. Wherever that run sits, these %d always fall inside it."),
                line, clue, lineLength, deduction.newFilled.count
            )
        case .lineComplete:
            return String(
                format: String(localized: "%@ already has every square its clues call for. The rest of it must be empty."),
                line
            )
        case .allEmpty:
            return String(
                format: String(localized: "%@ has a clue of zero. Nothing goes in it at all."),
                line
            )
        case .forced:
            return String(
                format: String(localized: "In %@, these squares are the same in every arrangement that fits the clues."),
                line
            )
        }
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
