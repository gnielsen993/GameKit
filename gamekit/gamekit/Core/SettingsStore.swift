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
//  P5 (D-10/D-23): hapticsEnabled / sfxEnabled / hasSeenIntro added; cloudSyncEnabled preserved unchanged.
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

    /// Whether `Haptics.playAHAP(...)` and the cell-level `.sensoryFeedback`
    /// modifiers fire (CONTEXT D-10 default `true` — premium feel).
    /// Gated at the source per CONTEXT D-10 — Plan 05-03 `Core/Haptics.swift`
    /// reads this flag once per playback call and silently no-ops when false.
    /// No view-layer plumbing of the toggle.
    var hapticsEnabled: Bool {
        didSet {
            userDefaults.set(hapticsEnabled, forKey: Self.hapticsEnabledKey)
        }
    }

    /// Whether `SFXPlayer.play(_:)` fires (CONTEXT D-10 default `false` per
    /// ROADMAP SC2 verbatim — sound is opt-in and never surprises a user
    /// playing in a coffee shop). Gated at the source per CONTEXT D-10 —
    /// Plan 05-03 `Core/SFXPlayer.swift` reads this flag once per playback
    /// call and silently no-ops when false. No view-layer plumbing.
    var sfxEnabled: Bool {
        didSet {
            userDefaults.set(sfxEnabled, forKey: Self.sfxEnabledKey)
        }
    }

    /// Whether the 3-step `IntroFlowView` `.fullScreenCover` has been
    /// dismissed at least once (CONTEXT D-23 default `false`). Set to
    /// `true` by Plan 05-05's `IntroFlowView` on Skip or Done. Read by
    /// `RootTabView` to gate `.fullScreenCover(isPresented: !hasSeenIntro)`.
    /// Tampering yields no privilege escalation per threat-model T-05-01 —
    /// the flag is a UX hint, not a guard.
    var hasSeenIntro: Bool {
        didSet {
            userDefaults.set(hasSeenIntro, forKey: Self.hasSeenIntroKey)
        }
    }

    // MARK: - Private

    private let userDefaults: UserDefaults

    // MARK: - Constants

    /// UserDefaults key for the cloud-sync flag (D-28).
    /// Renaming = preference loss for any user who already toggled the flag.
    static let cloudSyncEnabledKey = "gamekit.cloudSyncEnabled"

    /// UserDefaults key for the haptics-enabled flag (P5 D-10).
    /// Renaming = preference loss; locked.
    static let hapticsEnabledKey = "gamekit.hapticsEnabled"

    /// UserDefaults key for the SFX-enabled flag (P5 D-10).
    /// Renaming = preference loss; locked.
    static let sfxEnabledKey = "gamekit.sfxEnabled"

    /// UserDefaults key for the intro-seen flag (P5 D-23).
    /// Renaming would re-show the 3-step intro to existing users; locked.
    static let hasSeenIntroKey = "gamekit.hasSeenIntro"

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cloudSyncEnabled = userDefaults.bool(forKey: Self.cloudSyncEnabledKey)
        // D-10 default-true caveat: bool(forKey:) returns false for unset
        // keys (see lines 25-26), so we use the conventional optional-cast
        // fallback to honor the default-true contract on fresh installs.
        self.hapticsEnabled = (userDefaults.object(forKey: Self.hapticsEnabledKey) as? Bool) ?? true
        // D-10 default-false: bool(forKey:) returns false for unset keys,
        // which is exactly what we want — no fallback needed.
        self.sfxEnabled = userDefaults.bool(forKey: Self.sfxEnabledKey)
        // D-23 default-false: same — bool(forKey:) returns false for unset.
        self.hasSeenIntro = userDefaults.bool(forKey: Self.hasSeenIntroKey)
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
