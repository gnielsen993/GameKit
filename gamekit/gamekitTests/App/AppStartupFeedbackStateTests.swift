import Testing
@testable import gamekit

@Suite("App startup feedback")
@MainActor
struct AppStartupFeedbackStateTests {
    @Test("Fast startup completes without ever showing progress")
    func fastStartupDoesNotFlashProgress() {
        var state = AppStartupFeedbackState()

        state.startupFinished()
        state.progressThresholdReached()

        #expect(state.isComplete)
        #expect(!state.showsProgress)
    }

    @Test("Delayed startup shows progress only after the feedback threshold")
    func delayedStartupShowsProgress() {
        var state = AppStartupFeedbackState()

        #expect(!state.showsProgress)
        state.progressThresholdReached()

        #expect(state.showsProgress)
        #expect(!state.isComplete)
    }

    @Test("Progress clears when delayed startup finishes")
    func delayedStartupCompletionClearsProgress() {
        var state = AppStartupFeedbackState()
        state.progressThresholdReached()

        state.startupFinished()

        #expect(state.isComplete)
        #expect(!state.showsProgress)
    }
}
