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

    /// Plain-language position, so the sentence can point at something the
    /// player can actually find: "the 3rd to 8th squares of row 4".
    private static func span(_ indices: [Int]) -> String {
        guard let first = indices.first, let last = indices.last else { return "" }
        if indices.count == 1 {
            return String(format: String(localized: "square %d"), first + 1)
        }
        // Contiguous is the common case and reads far better than a list.
        if last - first + 1 == indices.count {
            return String(format: String(localized: "squares %d to %d"), first + 1, last + 1)
        }
        return String(
            format: String(localized: "%d squares"), indices.count
        )
    }

    static func explanation(for deduction: NonogramTalkthrough.Deduction) -> String {
        let line = lineName(deduction.line)
        switch deduction.technique {
        case .overlap(let clue, let lineLength):
            // Names the squares rather than saying "these", because there was
            // nothing on screen telling the player which ones "these" were.
            return String(
                format: String(localized: "%@ is one block of %d in %d squares. Slide that block to either end and %@ are covered both times, so they must be filled."),
                line, clue, lineLength, span(deduction.newFilled)
            )
        case .lineComplete:
            return String(
                format: String(localized: "%@ already has all the filled squares its clues ask for, so everything still blank in it must be empty."),
                line
            )
        case .allEmpty:
            return String(
                format: String(localized: "%@ has a clue of 0, so nothing goes in it. Mark the whole line empty."),
                line
            )
        case .forced:
            if !deduction.newFilled.isEmpty {
                return String(
                    format: String(localized: "In %@, %@ are filled in every arrangement that fits the clues."),
                    line, span(deduction.newFilled)
                )
            }
            return String(
                format: String(localized: "In %@, %@ are empty in every arrangement that fits the clues."),
                line, span(deduction.newEmpty)
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
