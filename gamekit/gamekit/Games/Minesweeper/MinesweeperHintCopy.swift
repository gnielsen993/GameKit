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
        case .comparingTwoNumbers(let smaller, let larger):
            return String(
                format: String(localized: "Compare the highlighted %d and %d. Every square the %d touches, the %d touches too — so the %d's mines are all inside that shared group, and the squares only the %d touches are safe. The outlined one is safe to open."),
                smaller, larger, smaller, larger, smaller, larger
            )
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
