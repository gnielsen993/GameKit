import Foundation
import Testing
@testable import gamekit

/// Regression coverage for the daily word being process-seeded.
///
/// `selectAnswer` previously used `abs(id.hashValue) % answers.count`. Swift
/// seeds its hasher per process, so the daily answer changed on every relaunch
/// and differed between devices and players. It only appeared stable because
/// the first guess writes a save that pins the answer.
///
/// Note a property these tests deliberately do not pin: the answer for a date
/// is an index into `WordLexicon.fiveLetterAnswers`, so editing the bundled
/// word list shifts every future daily. That is pre-existing behavior, not
/// something this fix introduced, but it means the word list is effectively
/// frozen once dailies matter to players.
@Suite("FiveLetter daily answer")
struct FiveLetterDailyAnswerTests {
    private func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)!
    }

    @Test("the same date always yields the same answer")
    func stableWithinDate() {
        let day = date("2026-07-31 09:00")
        let first = FiveLetterViewModel.selectAnswer(mode: .daily, now: day)
        let second = FiveLetterViewModel.selectAnswer(mode: .daily, now: day)
        #expect(first.answer == second.answer)
        #expect(first.puzzleId == second.puzzleId)
        #expect(first.puzzleId == "2026-07-31")
    }

    @Test("time of day does not change the answer")
    func stableAcrossTimeOfDay() {
        let morning = FiveLetterViewModel.selectAnswer(mode: .daily, now: date("2026-07-31 00:01"))
        let evening = FiveLetterViewModel.selectAnswer(mode: .daily, now: date("2026-07-31 23:59"))
        #expect(morning.answer == evening.answer)
        #expect(morning.puzzleId == evening.puzzleId)
    }

    @Test("the answer is derived from the date, not from process state")
    func derivedFromDate() {
        // The load-bearing assertion: recomputing from the same date string
        // must land on the same pool index a fresh process would.
        let day = date("2026-07-31 12:00")
        let selected = FiveLetterViewModel.selectAnswer(mode: .daily, now: day)
        let answers = WordLexicon.fiveLetterAnswers
        let expected = answers[StableHash.index(for: "2026-07-31", upperBound: answers.count)]
        #expect(selected.answer == expected)
    }

    @Test("consecutive days differ")
    func consecutiveDaysDiffer() {
        let days = (1...14).map { date(String(format: "2026-07-%02d 12:00", $0)) }
        let answers = days.map { FiveLetterViewModel.selectAnswer(mode: .daily, now: $0).answer }
        #expect(Set(answers).count >= 13)
    }

    @Test("every daily answer is a valid five-letter word from the pool")
    func answerIsValid() {
        for day in 1...31 {
            let selected = FiveLetterViewModel.selectAnswer(mode: .daily, now: date(String(format: "2026-07-%02d 12:00", day)))
            #expect(selected.answer.count == 5)
            #expect(WordLexicon.fiveLetterAnswers.contains(selected.answer))
        }
    }

    @Test("unlimited mode still varies between runs")
    func unlimitedVaries() {
        let ids = (0..<8).map { _ in FiveLetterViewModel.selectAnswer(mode: .unlimited).puzzleId }
        #expect(Set(ids).count == 8)
    }
}
