import Foundation
import Observation
import SwiftData

enum AppStartupPresentation: Equatable {
    case preparing
    case ready
    case failed
}

struct AppStartupFeedbackState {
    private(set) var isComplete = false
    private(set) var showsProgress = false

    mutating func progressThresholdReached() {
        guard !isComplete else { return }
        showsProgress = true
    }

    mutating func startupFinished() {
        isComplete = true
        showsProgress = false
    }
}

@Observable
@MainActor
final class AppStartupController {
    private(set) var presentation: AppStartupPresentation = .preparing
    private(set) var container: ModelContainer?
    private(set) var feedback = AppStartupFeedbackState()

    private let cloudSyncEnabled: Bool
    private var isAttemptingStartup = false

    init(cloudSyncEnabled: Bool) {
        self.cloudSyncEnabled = cloudSyncEnabled
    }

    func start() async {
        guard presentation == .preparing, !isAttemptingStartup else { return }
        await attemptStartup()
    }

    func retry() async {
        guard !isAttemptingStartup else { return }
        presentation = .preparing
        container = nil
        feedback = AppStartupFeedbackState()
        await attemptStartup()
    }

    private func attemptStartup() async {
        isAttemptingStartup = true

        let progressTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.feedback.progressThresholdReached()
        }

        do {
            try await applyDebugStartupBehaviorIfRequested()
            await deployDebugCloudSchemaIfNeeded()
            let loadedContainer = try await Self.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
            container = loadedContainer
            seedDebugDataIfNeeded(container: loadedContainer)
            feedback.startupFinished()
            presentation = .ready
        } catch {
            feedback.startupFinished()
            presentation = .failed
        }

        progressTask.cancel()
        isAttemptingStartup = false
    }

    private static func makeContainer(cloudSyncEnabled: Bool) async throws -> ModelContainer {
        try await Task.detached(priority: .userInitiated) {
            let schema = Schema([GameRecord.self, BestTime.self, BestScore.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: cloudSyncEnabled
                    ? .private("iCloud.com.lauterstar.gamekit")
                    : .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }.value
    }

    private func applyDebugStartupBehaviorIfRequested() async throws {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--launch-entry-delay") {
            try await Task.sleep(for: .seconds(4))
        }
        if arguments.contains("--launch-entry-failure") {
            throw DebugStartupError.requestedFailure
        }
        #endif
    }

    private func seedDebugDataIfNeeded(container: ModelContainer) {
        #if DEBUG
        if ScreenshotSeeder.isActive || ScreenshotSeeder.isArcadeActive {
            ScreenshotSeeder.seed(
                container: container,
                includeArcade: ScreenshotSeeder.isArcadeActive
            )
        } else {
            DummyDataSeeder.seedIfNeeded(
                container: container,
                cloudSyncEnabled: cloudSyncEnabled
            )
        }
        #endif
    }

    private func deployDebugCloudSchemaIfNeeded() async {
        #if DEBUG
        let schemaDeployedKey = "gamekit.debug.didDeployCloudKitSchemaOnce.v1"
        guard !UserDefaults.standard.bool(forKey: schemaDeployedKey) else { return }
        do {
            try CloudKitSchemaInitializer.deployDevelopmentSchema()
            UserDefaults.standard.set(true, forKey: schemaDeployedKey)
            print("✅ CloudKit schema deployed to Development.")
        } catch {
            print("❌ CloudKit schema deploy failed: \(error).")
        }
        #endif
    }
}

#if DEBUG
private enum DebugStartupError: Error {
    case requestedFailure
}
#endif
