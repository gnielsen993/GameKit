//
//  VideoModeStore.swift
//  gamekit
//
//  User-preference store for Video Mode, backed by `UserDefaults.standard`.
//  Mirrors `SettingsStore.swift:34-142` shape (Phase 4 D-29 pattern) with two
//  Phase 9 properties:
//    - `isEnabled: Bool` (VIDEO-01) — default `false` per ROADMAP SC1
//    - `location: VideoModeLocation` (VIDEO-02 / VIDEO-03) — default
//      `.largeBottom` per CONTEXT D-03
//
//  Phase 9 invariants (per D-05, D-06, D-07, D-03):
//    - `@Observable` + `@MainActor` + `final class` — all three attributes
//      load-bearing per 09-RESEARCH §Topic 3 #1. Matches SettingsStore.swift:34-36
//      shape; iOS-17-canonical for SwiftUI views observing the value.
//    - Custom EnvironmentKey injection is required by the Plan 09-02 GREEN
//      gate (test bundle compile depends on `EnvironmentValues.videoModeStore`
//      symbol existing via VideoModeEnvironmentTests). Plan 09-03 still wires
//      the App-root `.environment(\.videoModeStore, ...)` and flips
//      `GameKitAppTests` GREEN. `@EnvironmentObject` is INCOMPATIBLE with
//      `@Observable` (P4 RESEARCH Pitfall 1) — the EnvironmentKey extension
//      below is the iOS-17-canonical seam.
//    - `userDefaults.bool(forKey:)` returns `false` for unset keys per Apple
//      docs — no explicit `register(defaults:)` needed for the isEnabled
//      default-false case (ROADMAP SC1).
//    - `VideoModeLocation.rawValue` is the persisted form; corrupt strings
//      fall back to `.largeBottom` per D-03 default (RESEARCH Topic 3 #4).
//    - `location` MUST be a stored property with `didSet`, NOT a computed
//      getter — `@Observable` macro only tracks stored properties (09-RESEARCH
//      Pitfall 1 / 09-PATTERNS Pitfall 1).
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class VideoModeStore {

    // MARK: - Stored flags

    /// Whether Video Mode is active (per VIDEO-01 / ROADMAP SC1).
    /// Default `false` on fresh install per ROADMAP SC1 ("default Off").
    /// Read by every Phase 10+ game view to decide whether to apply
    /// Video Mode layout primitives.
    var isEnabled: Bool {
        didSet {
            userDefaults.set(isEnabled, forKey: Self.isEnabledKey)
        }
    }

    /// Which of the 6 PiP zones the user has chosen (per VIDEO-02 / D-07).
    /// Default `.largeBottom` per CONTEXT D-03 (mirrors iOS native PiP dock
    /// + exercises the Hard-Mines squeeze case from Phase 8 ADR).
    /// Read by every Phase 10+ game view via shared store.
    var location: VideoModeLocation {
        didSet {
            userDefaults.set(location.rawValue, forKey: Self.locationKey)
        }
    }

    // MARK: - Private

    private let userDefaults: UserDefaults

    // MARK: - Constants

    /// UserDefaults key for the Video Mode toggle (D-06).
    /// Renaming = preference loss; locked.
    static let isEnabledKey = "gamekit.videoModeEnabled"

    /// UserDefaults key for the selected Video Mode location (D-06).
    /// Renaming = preference loss; locked.
    static let locationKey = "gamekit.videoModeLocation"

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // VIDEO-01 default-false: bool(forKey:) returns false for unset keys,
        // which matches ROADMAP SC1 ("default Off"). No fallback needed.
        self.isEnabled = userDefaults.bool(forKey: Self.isEnabledKey)
        // D-03 default + RESEARCH Topic 3 invariant #4 defensive read —
        // `?? ""` handles missing key, `?? .largeBottom` handles missing key
        // AND any corrupt plist value (hand-edited string, value from a future
        // app version that adds a 7th case, etc.).
        self.location = VideoModeLocation(
            rawValue: userDefaults.string(forKey: Self.locationKey) ?? ""
        ) ?? .largeBottom
    }
}

// MARK: - EnvironmentKey injection (mirrors SettingsStore.swift:146-155)

/// EnvironmentKey for `VideoModeStore` — the iOS-17-canonical seam for
/// `@Observable` types (P4 RESEARCH §Pattern 5; @EnvironmentObject requires
/// `ObservableObject` and is incompatible with `@Observable`).
///
/// Default value is a fresh `VideoModeStore(userDefaults: .standard)` so
/// views reachable without the App-root injection (previews, unit tests,
/// staged scenes) still get a working store. Plan 09-03 wires
/// `.environment(\.videoModeStore, store)` at the App root so production
/// always sees the shared singleton.
private struct VideoModeStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = VideoModeStore()
}

extension EnvironmentValues {
    var videoModeStore: VideoModeStore {
        get { self[VideoModeStoreKey.self] }
        set { self[VideoModeStoreKey.self] = newValue }
    }
}
