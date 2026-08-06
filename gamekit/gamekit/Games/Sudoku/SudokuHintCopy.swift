//
//  SudokuHintCopy.swift
//  gamekit
//
//  Turns a SudokuHintEngine.Step into a sentence.
//
//  Presentation-layer, like NonogramTalkthroughCopy: the engine returns a
//  structured technique so the reasoning stays testable in the package and
//  the wording stays localizable here.
//
//  The engine proves exactly two techniques. Rather than dress that up, the
//  copy leans into what each one actually argues — and the unavailable case
//  says plainly that the puzzle needs something harder.
//

import Foundation
import SudokuCore

enum SudokuHintCopy {

    /// "row 4" / "column 7" / "this box" — lowercase, for use mid-sentence.
    /// 1-indexed, because players count from one.
    static func unitName(_ unit: SudokuHintEngine.Unit) -> String {
        switch unit {
        case .row(let index):
            return String(format: String(localized: "row %d"), index + 1)
        case .column(let index):
            return String(format: String(localized: "column %d"), index + 1)
        case .box:
            return String(localized: "this box")
        }
    }

    /// Actionable explanation: the player sees both what to place and why.
    static func explanation(for step: SudokuHintEngine.Step) -> String {
        switch step.technique {
        case .nakedSingle:
            // The ring and the shaded row/column are on screen, so the
            // sentence can point at them instead of describing coordinates
            // the player then has to go and find.
            return String(
                format: String(localized: "Row %d, column %d can only be %d. Every other digit is already used in its row, column, or box."),
                step.row + 1, step.column + 1, step.value
            )
        case .hiddenSingle(let unit):
            return String(
                format: String(localized: "In %@, %d can only go in the ringed square at row %d, column %d."),
                unitName(unit), step.value, step.row + 1, step.column + 1
            )
        }
    }

    /// The answer, given only on a second ask.
    static func reveal(for step: SudokuHintEngine.Step) -> String {
        String(
            format: String(localized: "Row %d, column %d is %d."),
            step.row + 1, step.column + 1, step.value
        )
    }

    static func unavailableMessage(_ reason: SudokuViewModel.HintUnavailable) -> String {
        switch reason {
        case .boardHasAMistake:
            return String(localized: "A digit already placed does not match the solution. Fix the red squares first — anything worked out from here would rest on it.")
        case .beyondSingles:
            // The honest ceiling. The engine proves single-candidate
            // arguments and nothing more; claiming otherwise would be the
            // one thing this feature must never do.
            return String(localized: "This one needs a harder technique than a single square or a single digit. No step here can be spelled out.")
        }
    }
}
