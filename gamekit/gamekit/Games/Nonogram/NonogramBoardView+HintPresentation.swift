//
//  NonogramBoardView+HintPresentation.swift
//  gamekit
//
//  Compact, unambiguous clue presentation for the Nonogram board.
//

import SwiftUI
import DesignKit

extension NonogramBoardView {
    /// A centered dot gives adjacent runs an explicit visual boundary without
    /// widening the existing hint rail: `1·5` cannot be mistaken for `15`.
    static var rowHintSeparator: String { "·" }

    /// Precedence: targeted beats everything (it is momentary and tracks the
    /// finger), then unsatisfiable, then crossed-off.
    func hintColor(crossed: Bool, targeted: Bool, unsatisfiable: Bool = false) -> Color {
        if targeted { return theme.colors.accentPrimary }
        if unsatisfiable { return theme.colors.danger }
        return crossed ? theme.colors.textTertiary : theme.colors.textSecondary
    }

    /// Builds a single compact clue line while preserving per-clue styling.
    func rowHintText(
        hints: [Int],
        crossMask: [Bool],
        targeted: Bool,
        unsatisfiable: Bool = false
    ) -> AttributedString {
        var result = AttributedString()

        for (index, value) in hints.enumerated() {
            let crossed = crossMask.indices.contains(index) ? crossMask[index] : false
            var clue = AttributedString(String(value))
            clue.foregroundColor = hintColor(
                crossed: crossed,
                targeted: targeted,
                unsatisfiable: unsatisfiable
            )
            if crossed {
                clue.strikethroughStyle = Text.LineStyle(
                    pattern: .solid,
                    color: theme.colors.textTertiary
                )
            }
            result.append(clue)

            if index < hints.count - 1 {
                var separator = AttributedString(Self.rowHintSeparator)
                separator.foregroundColor = theme.colors.textTertiary
                result.append(separator)
            }
        }

        return result
    }

    static func rowHintDisplayString(_ hints: [Int]) -> String {
        hints.map(String.init).joined(separator: rowHintSeparator)
    }

    static func rowHintAccessibilityLabel(_ hints: [Int], unsatisfiable: Bool = false) -> String {
        let clues = hints.map(String.init).joined(separator: ", ")
        // Colour alone must not carry the signal.
        guard unsatisfiable else { return clues }
        return String(format: String(localized: "%@, line no longer matches its clues"), clues)
    }
}
