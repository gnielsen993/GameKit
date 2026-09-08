//
//  MinesweeperHintCopy.swift
//  gamekit
//
//  Turns a proved step into a sentence.
//
//  Both rules are genuinely teachable, which is why this game gets a
//  talkthrough rather than a reveal: the argument works the next time the
//  same shape appears, and these two shapes appear constantly.
//

import Foundation

enum MinesweeperHintCopy {

    static func explanation(for step: MinesweeperHint.Step) -> String {
        switch step.technique {
        case .countingOneNumber(let number):
            return String(
                format: String(localized: "The highlighted %d already touches all %d of its mines, so every other square around it is safe. The outlined one is safe to open."),
                number, number
            )
        case .comparingTwoNumbers:
            guard step.evidence.count == 2 else { return noStepFound }
            let first = step.evidence[0], second = step.evidence[1]
            return String(localized: "Open row \(step.safe.row + 1), column \(step.safe.col + 1). Compare row \(first.row + 1), column \(first.col + 1) with row \(second.row + 1), column \(second.col + 1). After accounting for the marked hint mines, both need the same number of mines. The first number's unopened neighbors are shared by the second, so the second number's extra neighbors are safe.")
        }
    }

    /// Shown when the two rules cannot find a step.
    ///
    /// Careful wording, deliberately. These rules are not complete, so the
    /// honest claim is "I cannot find one", not "none exists" — the position
    /// may be resolvable by whole-board counting this engine does not do.
    static var noStepFound: String {
        String(localized: "No square here can be proved safe by counting one number or comparing two. It may need whole-board counting, or it may genuinely be a guess.")
    }

    static var spendTheGuess: String {
        String(localized: "Open a safe square for me")
    }
}
