import Foundation
import Testing
@testable import gamekit

@Suite("FiveLetterViewModel")
struct FiveLetterViewModelTests {
    @MainActor
    @Test("completed daily cannot be restarted into a new daily puzzle")
    func completedDailyCannotRestart() {
        let suiteName = "FiveLetterViewModelTests.daily.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = FiveLetterViewModel(mode: .daily, userDefaults: defaults)
        let answer = viewModel.answer
        let puzzleId = viewModel.puzzleId

        for letter in answer {
            viewModel.input(letter)
        }
        viewModel.submit()

        #expect(viewModel.state == .won)
        #expect(viewModel.guesses.count == 1)

        viewModel.restart()

        #expect(viewModel.state == .won)
        #expect(viewModel.puzzleId == puzzleId)
        #expect(viewModel.guesses.map(\.word) == [answer])
    }

    @MainActor
    @Test("completed daily restores on launch")
    func completedDailyRestoresOnLaunch() {
        let suiteName = "FiveLetterViewModelTests.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstViewModel = FiveLetterViewModel(mode: .daily, userDefaults: defaults)
        let answer = firstViewModel.answer
        for letter in answer {
            firstViewModel.input(letter)
        }
        firstViewModel.submit()

        let secondViewModel = FiveLetterViewModel(mode: .daily, userDefaults: defaults)

        #expect(secondViewModel.state == .won)
        #expect(secondViewModel.guesses.map(\.word) == [answer])
    }

    @MainActor
    @Test("daily restart does not clear an active attempt")
    func dailyRestartDoesNotClearActiveAttempt() {
        let suiteName = "FiveLetterViewModelTests.noRestart.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = FiveLetterViewModel(mode: .daily, userDefaults: defaults)
        let wrongGuess = viewModel.answer == "APPLE" ? "BRAVE" : "APPLE"
        for letter in wrongGuess {
            viewModel.input(letter)
        }
        viewModel.submit()
        let guesses = viewModel.guesses

        viewModel.restart()

        #expect(viewModel.guesses == guesses)
        #expect(viewModel.state == .playing)
        #expect(viewModel.message == "Daily challenge is one shot")
    }

    @MainActor
    @Test("non-word five-letter guess is rejected")
    func nonWordGuessRejected() {
        let suiteName = "FiveLetterViewModelTests.nonWord.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = FiveLetterViewModel(mode: .unlimited, userDefaults: defaults)
        for letter in "GGGGG" {
            viewModel.input(letter)
        }
        viewModel.submit()

        #expect(viewModel.guesses.isEmpty)
        #expect(viewModel.state == .playing)
        #expect(viewModel.message == "Not in word list")
        #expect(viewModel.invalidCount == 1)
    }

    @Test("isAllowedFiveLetterGuess requires a real word")
    func isAllowedFiveLetterGuessRequiresRealWord() {
        #expect(WordLexicon.isAllowedFiveLetterGuess("GGGGG") == false)
        #expect(WordLexicon.isAllowedFiveLetterGuess("APPLE") == true)
        #expect(WordLexicon.isAllowedFiveLetterGuess("CRANE") == true)
    }

    @MainActor
    @Test("unlimited restart still starts over")
    func unlimitedRestartStillStartsOver() {
        let suiteName = "FiveLetterViewModelTests.unlimited.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = FiveLetterViewModel(mode: .unlimited, userDefaults: defaults)
        for letter in "APPLE" {
            viewModel.input(letter)
        }
        viewModel.submit()

        viewModel.restart()

        #expect(viewModel.guesses.isEmpty)
        #expect(viewModel.state == .playing)
    }
}
