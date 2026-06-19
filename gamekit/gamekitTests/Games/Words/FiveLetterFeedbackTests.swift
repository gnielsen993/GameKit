import Testing
@testable import gamekit

@Suite("FiveLetterFeedback")
struct FiveLetterFeedbackTests {
    @Test("duplicate letters only mark present while answer supply remains")
    func duplicateLetterSupply() {
        let marks = FiveLetterFeedback.evaluate(guess: "APPLE", answer: "PLANT")
        #expect(marks == [.present, .present, .absent, .present, .absent])
    }

    @Test("correct letters win precedence before present letters")
    func correctBeforePresent() {
        let marks = FiveLetterFeedback.evaluate(guess: "LEVEL", answer: "LEMON")
        #expect(marks == [.correct, .correct, .absent, .absent, .absent])
    }

    @Test("strict mode rejects yellow letters in the same spot")
    func strictRejectsYellowSameSpot() {
        let previous = FiveLetterGuess(
            word: "GUESS",
            marks: [.absent, .absent, .present, .absent, .absent]
        )

        let message = FiveLetterStrictValidator.violationMessage(for: "PLESK", previousGuesses: [previous])

        #expect(message == "Move E")
    }

    @Test("strict mode rejects known absent letters")
    func strictRejectsAbsentLetters() {
        let previous = FiveLetterGuess(
            word: "GUESS",
            marks: [.absent, .absent, .present, .absent, .absent]
        )

        let message = FiveLetterStrictValidator.violationMessage(for: "ASIDE", previousGuesses: [previous])

        #expect(message == "Do not use S")
    }

    @Test("strict mode preserves duplicate letter supply from positive marks")
    func strictAllowsLetterWithPositiveDuplicate() {
        let previous = FiveLetterGuess(
            word: "LEVEL",
            marks: [.correct, .correct, .absent, .absent, .absent]
        )

        let message = FiveLetterStrictValidator.violationMessage(for: "LEMON", previousGuesses: [previous])

        #expect(message == nil)
    }
}
