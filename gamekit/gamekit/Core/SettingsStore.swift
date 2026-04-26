//
//  SettingsStore.swift
//  gamekit
//
//  User-preference store backed by `UserDefaults.standard`. The Phase 4 surface
//  is a single `cloudSyncEnabled: Bool` flag (key `gamekit.cloudSyncEnabled`,
//  defaulting to `false` per D-28). The flag is read ONCE at container
//  construction in `GameKitApp.init()` per D-29 — flipping it later requires
//  an app relaunch. Live `ModelConfiguration` reconfiguration is a P6 concern
//  per ROADMAP and is out of scope for v1.
//
//  Phase 4 invariants:
//    - `@Observable` + `@MainActor` final class — matches the existing
//      `MinesweeperViewModel` shape (MinesweeperViewModel.swift:37) and is
//      iOS-17-canonical for SwiftUI views observing the value
//      (RESEARCH §State of the Art).
//    - Custom `EnvironmentKey` injection — `@EnvironmentObject` requires
//      `ObservableObject` and is incompatible with `@Observable`
//      (RESEARCH Pitfall 1 inheritance from P3). The `EnvironmentKey` is
//      the iOS-17-canonical seam for `@Observable` types per
//      RESEARCH §Pattern 5.
//    - Future P5 flags (`hapticsEnabled`, `sfxEnabled`, `hasSeenIntro`)
//      ship in their respective phases — additive properties on this same
//      class, no breaking change.
//    - `userDefaults.bool(forKey:)` returns `false` for unset keys per
//      Apple docs — no explicit `register(defaults:)` needed for v1.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsStore {

    // MARK: - Stored flags

    /// Whether SwiftData should construct its `ModelContainer` with
    /// `cloudKitDatabase: .private("iCloud.com.lauterstar.gamekit")` (D-08).
    /// P6 PERSIST-04 reads this. P4 default is `false`; the `.private(...)`
    /// branch in `GameKitApp.init` never executes in production yet, but the
    /// SC3 smoke test (Plan 04-01) verifies it constructs cleanly anyway.
    var cloudSyncEnabled: Bool {
        didSet {
            userDefaults.set(cloudSyncEnabled, forKey: Self.cloudSyncEnabledKey)
        }
    }

    // MARK: - Private

    private let userDefaults: UserDefaults

    // MARK: - Constants

    /// UserDefaults key for the cloud-sync flag (D-28).
    /// Renaming = preference loss for any user who already toggled the flag.
    static let cloudSyncEnabledKey = "gamekit.cloudSyncEnabled"

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cloudSyncEnabled = userDefaults.bool(forKey: Self.cloudSyncEnabledKey)
    }
}

// MARK: - EnvironmentKey injection (RESEARCH §Pattern 5)

private struct SettingsStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = SettingsStore()
}

extension EnvironmentValues {
    var settingsStore: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }
}
