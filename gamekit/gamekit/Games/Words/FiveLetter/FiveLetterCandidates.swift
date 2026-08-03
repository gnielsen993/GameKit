//
//  FiveLetterCandidates.swift
//  gamekit
//
//  How many answers still fit everything the player has been told.
//
//  This is the one assist that suits the game. In a five-letter word puzzle
//  almost every hint is the answer or one step from it — a revealed letter is
//  20% of a five-letter word plus a huge constraint — so there is very little
//  middle ground. A count has none of that problem: it leaks nothing that is
//  not already sitting on the board in green, yellow, and grey. It only
//  relieves the pressure of not knowing whether you are close.
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4).
//

import Foundation

nonisolated enum FiveLetterCandidates {

    /// Answers consistent with every guess so far.
    ///
    /// The filter is **replay consistency**, not a re-derivation of the
    /// constraints: a candidate survives if scoring each past guess against it
    /// reproduces exactly the marks the player was shown. That is the whole
    /// rule, it cannot drift from what the board displays, and it handles
    /// duplicate letters correctly for free — which a hand-rolled
    /// green/yellow/grey filter famously does not.
    static func remaining(after guesses: [FiveLetterGuess], answers: [String]) -> [String] {
        guard !guesses.isEmpty else { return answers }
        return answers.filter { candidate in
            for guess in guesses {
                guard guess.marks.count == 5 else { continue }
                if FiveLetterFeedback.evaluate(guess: guess.word, answer: candidate) != guess.marks {
                    return false
                }
            }
            return true
        }
    }

    static func count(after guesses: [FiveLetterGuess], answers: [String]) -> Int {
        remaining(after: guesses, answers: answers).count
    }
}
