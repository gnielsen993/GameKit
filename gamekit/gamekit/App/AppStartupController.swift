import Foundation
import Observation
import os
import SwiftData
import SwiftUI

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

    /// Bumped on every successful container build. `AppEntryRootView` keys the
    /// destination subtree on it so a reconfigured container rebuilds the tree
    /// cleanly rather than leaving views bound to the retired `ModelContext`.
    private(set) var containerToken: Int = 0

    /// Mutable so `reconfigure(cloudSyncEnabled:)` can swap sync modes without
    /// a relaunch. Was a `let` until 2026-07-27 — that is what forced the
    /// "quit and reopen" prompt this replaces.
    private(set) var cloudSyncEnabled: Bool
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

    /// Rebuilds the container against a new sync mode **without a relaunch**.
    ///
    /// Both modes open the SAME on-disk store (D-08 same-store-path), so no
    /// local row is created, moved, or deleted — the only difference is
    /// whether SwiftData mirrors that store to CloudKit. Existing local rows
    /// are pushed up the first time sync is turned on.
    ///
    /// Deliberately does NOT drop to `.preparing`: the caller is standing in
    /// Settings (or finishing the intro) and a flash back to the branded entry
    /// screen would be a worse experience than the brief pause. The current
    /// tree stays on screen until the replacement container is ready, then
    /// `containerToken` swaps it atomically.
    func reconfigure(cloudSyncEnabled newValue: Bool) async {
        guard newValue != cloudSyncEnabled, !isAttemptingStartup else { return }
        isAttemptingStartup = true
        cloudSyncEnabled = newValue

        do {
            container = try await Self.makeContainer(cloudSyncEnabled: newValue)
            containerToken &+= 1
            presentation = .ready
        } catch {
            // Same contract as a failed cold start: the recovery screen offers
            // Try Again, which reopens with whatever mode is now current. No
            // user data is touched on this path.
            AppLog.storage.error(
                "Container reconfigure failed (cloudSync=\(newValue, privacy: .public)): \(error.localizedDescription, privacy: .public)"
            )
            presentation = .failed
        }

        isAttemptingStartup = false
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
            containerToken &+= 1
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

// MARK: - EnvironmentKey injection (mirrors AuthStore.swift's seam)

/// Optional because there is no sensible default controller — constructing one
/// here would open a second container against the same store. `GameKitApp`
/// injects the real instance; every call site treats `nil` as "no reconfigure
/// available" rather than falling back to a throwaway.
private struct AppStartupControllerKey: EnvironmentKey {
    static let defaultValue: AppStartupController? = nil
}

extension EnvironmentValues {
    var appStartupController: AppStartupController? {
        get { self[AppStartupControllerKey.self] }
        set { self[AppStartupControllerKey.self] = newValue }
    }
}

#if DEBUG
private enum DebugStartupError: Error {
    case requestedFailure
}
#endif
