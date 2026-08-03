import Testing
import Foundation
@testable import gamekit

/// Hints for the two word games. They needed opposite answers: WordGrid's
/// problem is visual search, so it points; FiveLetter's problem is lexical
/// retrieval where almost any hint is the answer, so it counts instead.
@Suite("Word game hints")
@MainActor
struct WordHintTests {

    // MARK: - WordGrid

    private func wordGridViewModel() -> WordGridViewModel {
        let suite = UserDefaults(suiteName: "WordHint.\(UUID().uuidString)")!
        return WordGridViewModel(userDefaults: suite)
    }

    @Test("a hint names a word that is genuinely on the board")
    func hintWordIsPlayable() {
        let vm = wordGridViewModel()
        vm.requestHint()
        guard let word = vm.hintWord else { return }   // board may be barren
        #expect(WordGridEngine.playableWords(on: vm.board).contains(word))
    }

    @Test("the outlined path spells the word it names")
    func hintPathSpellsTheWord() {
        let vm = wordGridViewModel()
        vm.requestHint()
        guard let word = vm.hintWord else { return }
        let spelled = vm.hintPath.map { String(vm.board[$0.row][$0.column]) }.joined()
        #expect(spelled == word)
    }

    @Test("the path is a legal chain of adjacent, non-repeating squares")
    func hintPathIsLegal() {
        let vm = wordGridViewModel()
        vm.requestHint()
        guard !vm.hintPath.isEmpty else { return }

        #expect(Set(vm.hintPath).count == vm.hintPath.count)   // no reuse
        for (a, b) in zip(vm.hintPath, vm.hintPath.dropFirst()) {
            let dr = abs(a.row - b.row), dc = abs(a.column - b.column)
            #expect(dr <= 1 && dc <= 1 && (dr + dc) > 0)
        }
    }

    /// The rule that makes this assist self-pricing.
    @Test("a revealed word scores nothing")
    func revealedWordScoresZero() {
        let vm = wordGridViewModel()
        let scoreBefore = vm.score
        vm.requestHint()
        #expect(vm.score == scoreBefore)
        if let word = vm.hintWord {
            #expect(vm.foundWords.contains(word))   // it still counts as found
            #expect(vm.revealedWords.contains(word))
        }
    }

    @Test("the same word is never revealed twice")
    func hintsDoNotRepeat() {
        let vm = wordGridViewModel()
        var seen: Set<String> = []
        for _ in 0..<5 {
            vm.requestHint()
            guard let word = vm.hintWord else { break }
            #expect(seen.contains(word) == false)
            seen.insert(word)
        }
    }

    @Test("dismissing clears the outline")
    func dismissClearsPath() {
        let vm = wordGridViewModel()
        vm.requestHint()
        vm.dismissHint()
        #expect(vm.hintPath.isEmpty)
        #expect(vm.hintWord == nil)
    }

    // MARK: - FiveLetter candidates

    @Test("with no guesses every answer still fits")
    func noGuessesMeansFullPool() {
        let answers = ["CRANE", "SLATE", "BRAIN"]
        #expect(FiveLetterCandidates.count(after: [], answers: answers) == answers.count)
    }

    @Test("the real answer always survives its own feedback")
    func answerSurvivesItsOwnClues() {
        let answer = "CRANE"
        let guessWords = ["SLATE", "BRAIN", "PRICE"]
        let guesses = guessWords.map {
            FiveLetterGuess(word: $0, marks: FiveLetterFeedback.evaluate(guess: $0, answer: answer))
        }
        let remaining = FiveLetterCandidates.remaining(
            after: guesses, answers: WordLexicon.fiveLetterAnswers
        )
        #expect(remaining.contains(answer))
    }

    @Test("a guessed word that was wrong is filtered out")
    func wrongGuessIsEliminated() {
        let answer = "CRANE"
        let wrong = "SLATE"
        let guesses = [
            FiveLetterGuess(word: wrong, marks: FiveLetterFeedback.evaluate(guess: wrong, answer: answer))
        ]
        let remaining = FiveLetterCandidates.remaining(
            after: guesses, answers: WordLexicon.fiveLetterAnswers
        )
        #expect(remaining.contains(wrong) == false)
        #expect(remaining.contains(answer))
    }

    @Test("more clues never widen the field")
    func countIsMonotonic() {
        let answer = "CRANE"
        let words = ["SLATE", "BRAIN", "PRICE"]
        var guesses: [FiveLetterGuess] = []
        var last = WordLexicon.fiveLetterAnswers.count
        for word in words {
            guesses.append(
                FiveLetterGuess(word: word, marks: FiveLetterFeedback.evaluate(guess: word, answer: answer))
            )
            let count = FiveLetterCandidates.count(
                after: guesses, answers: WordLexicon.fiveLetterAnswers
            )
            #expect(count <= last)
            #expect(count >= 1)   // the answer itself always remains
            last = count
        }
    }

    /// Replay-consistency, not a re-derived filter — this is the case a
    /// hand-rolled green/yellow/grey filter gets wrong.
    @Test("duplicate letters are handled correctly")
    func duplicateLettersFilterCorrectly() {
        let answer = "ROBOT"
        let guess = "OTTER"
        let guesses = [
            FiveLetterGuess(word: guess, marks: FiveLetterFeedback.evaluate(guess: guess, answer: answer))
        ]
        let remaining = FiveLetterCandidates.remaining(after: guesses, answers: [answer, "STOMP", "OTTER"])
        #expect(remaining.contains(answer))
        #expect(remaining.contains("OTTER") == false)
    }

    @Test("asking twice on the same puzzle counts as one assist")
    func repeatedLooksAreOneAssist() {
        let suite = UserDefaults(suiteName: "WordHintFL.\(UUID().uuidString)")!
        let vm = FiveLetterViewModel(mode: .unlimited, userDefaults: suite)
        vm.requestCandidateCount()
        vm.requestCandidateCount()
        vm.requestCandidateCount()
        #expect(vm.assistsUsed == 1)
        #expect(vm.candidateCount != nil)
    }

    @Test("a new guess drops the stale count")
    func guessClearsTheCount() {
        let suite = UserDefaults(suiteName: "WordHintFL2.\(UUID().uuidString)")!
        let vm = FiveLetterViewModel(mode: .unlimited, userDefaults: suite)
        vm.requestCandidateCount()
        #expect(vm.candidateCount != nil)

        for character in "SLATE" { vm.input(character) }
        vm.submit()
        #expect(vm.candidateCount == nil)
    }
}
