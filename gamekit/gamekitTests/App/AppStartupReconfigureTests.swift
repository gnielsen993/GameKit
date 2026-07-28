import Testing
@testable import gamekit

/// Covers `AppStartupController.reconfigure(cloudSyncEnabled:)` — the seam that
/// replaced the "quit and reopen to finish iCloud setup" prompt on 2026-07-27.
///
/// Scope note: these exercise the local-only (`.none`) mode and the guard
/// logic, which are deterministic in the test host. Building a container in
/// `.private` mode needs live CloudKit entitlements and an iCloud account, so
/// the true-mode swap is verified on device, not here.
@Suite("App startup reconfigure")
@MainActor
struct AppStartupReconfigureTests {

    @Test("Cold start publishes a container and stamps the first token")
    func coldStartStampsToken() async {
        let controller = AppStartupController(cloudSyncEnabled: false)

        await controller.start()

        #expect(controller.presentation == .ready)
        #expect(controller.container != nil)
        #expect(controller.containerToken == 1)
        #expect(!controller.cloudSyncEnabled)
    }

    @Test("Reconfiguring to the mode already in use rebuilds nothing")
    func sameModeIsANoOp() async {
        let controller = AppStartupController(cloudSyncEnabled: false)
        await controller.start()
        let tokenAfterStart = controller.containerToken

        await controller.reconfigure(cloudSyncEnabled: false)

        // No token bump means no container swap, so the view tree keeps its
        // identity and no @Query is needlessly torn down.
        #expect(controller.containerToken == tokenAfterStart)
        #expect(controller.presentation == .ready)
    }

    @Test("Retry preserves the sync mode currently in force")
    func retryKeepsCurrentMode() async {
        let controller = AppStartupController(cloudSyncEnabled: false)
        await controller.start()

        await controller.retry()

        #expect(!controller.cloudSyncEnabled)
        #expect(controller.presentation == .ready)
        // retry() rebuilds unconditionally, so the token must advance —
        // otherwise the recovered tree would keep the dead context.
        #expect(controller.containerToken == 2)
    }
}
