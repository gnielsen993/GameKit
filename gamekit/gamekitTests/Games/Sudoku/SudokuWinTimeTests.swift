import Testing
import Foundation
@testable import gamekit

/// Phase 19.1 plan 05: the win time's text and its count-up easing are pure
/// functions (sketch 012: 1100ms cubic ease-out), so the card can show a
/// counting number without the animation being the only thing under test.
@Suite("SudokuWinTime")
struct SudokuWinTimeTests {

    @Test("formats minutes and seconds under an hour")
    func formatsUnderAnHour() {
        #expect(SudokuWinTime.string(0) == "0:00")
        #expect(SudokuWinTime.string(59.9) == "0:59")
        #expect(SudokuWinTime.string(61) == "1:01")
    }

    @Test("formats hours once past an hour")
    func formatsHours() {
        #expect(SudokuWinTime.string(3661) == "1:01:01")
    }

    @Test("a negative time clamps to zero")
    func negativeClamps() {
        #expect(SudokuWinTime.string(-5) == "0:00")
    }

    @Test("the count-up shows zero until its delay has passed")
    func zeroBeforeAndAtDelay() {
        #expect(SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: 0) == 0)
        #expect(SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: SudokuWinTime.countUpDelay) == 0)
        #expect(SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: -1) == 0)
    }

    @Test("the count-up lands on the target and stays there")
    func landsOnTarget() {
        let end = SudokuWinTime.countUpDelay + SudokuWinTime.countUpDuration
        #expect(SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: end) == 251)
        #expect(SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: end + 10) == 251)
    }

    @Test("halfway through, a cubic ease-out has covered 87.5 percent")
    func halfwayIsCubicEaseOut() {
        let mid = SudokuWinTime.countUpDelay + SudokuWinTime.countUpDuration / 2
        let value = SudokuWinTime.countUpSeconds(target: 400, elapsedSinceStart: mid)
        #expect(abs(value - 0.875 * 400) <= 0.01 * 400)
    }

    @Test("the count-up never goes backwards")
    func nonDecreasing() {
        let end = SudokuWinTime.countUpDelay + SudokuWinTime.countUpDuration
        var previous = -1.0
        for step in 0...50 {
            let t = end * 1.2 * Double(step) / 50
            let value = SudokuWinTime.countUpSeconds(target: 251, elapsedSinceStart: t)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test("a zero target always shows zero")
    func zeroTarget() {
        for t in [0.0, 0.3, 0.9, 1.4, 5] {
            #expect(SudokuWinTime.countUpSeconds(target: 0, elapsedSinceStart: t) == 0)
        }
    }
}
