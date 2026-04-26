//
//  SettingsStoreFlagsTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 05-01 SettingsStore extension —
//  the 3 new flags downstream P5 waves depend on:
//    - hapticsEnabled  (default true,  CONTEXT D-10)
//    - sfxEnabled      (default false, CONTEXT D-10)
//    - hasSeenIntro    (default false, CONTEXT D-23)
//
//  Per-test isolated UserDefaults via the makeIsolatedDefaults() helper
//  (mirrored from MinesweeperViewModelTests.swift:25-28) — avoids cross-
//  test bleed under Swift Testing's default concurrent execution.
//
//  The default-true semantics test (`unsetHapticsEnabledKey_returnsTrueByDefault`)
//  is the load-bearing case proving the `object(forKey:) as? Bool ?? true`
//  pattern from PATTERNS.md works for fresh installs (CLAUDE.md §1 data
//  safety: "schema changes additive when possible"). UserDefaults.bool(forKey:)
//  returns false for unset keys per Apple docs — the documented gotcha that
//  necessitates the optional-cast fallback (SettingsStore.swift:25-26).
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("SettingsStoreFlags")
struct SettingsStoreFlagsTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors MinesweeperViewModelTests:25-28.
    /// Each test gets a fresh suite name so toggles in one test never bleed
    /// into a sibling test running in parallel.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - Default-state coverage

    @Test("Defaults: cloudSync=false (P4), haptics=true (D-10), sfx=false (D-10), hasSeenIntro=false (D-23)")
    func defaults_haveCorrectInitialValues() {
        let defaults = Self.makeIsolatedDefaults()
        let store = SettingsStore(userDefaults: defaults)
        // P4 regression — cloudSyncEnabled preserved
        #expect(store.cloudSyncEnabled == false)
        // D-10 — premium feel default
        #expect(store.hapticsEnabled == true)
        // D-10 — sound is opt-in per ROADMAP SC2 verbatim
        #expect(store.sfxEnabled == false)
        // D-23 — onboarding hint default
        #expect(store.hasSeenIntro == false)
    }

    // MARK: - Round-trip persistence

    @Test("Setting hapticsEnabled = false persists to UserDefaults under gamekit.hapticsEnabled key")
    func setHapticsEnabled_persistsToUserDefaults() {
        let defaults = Self.makeIsolatedDefaults()
        let store = SettingsStore(userDefaults: defaults)
        store.hapticsEnabled = false
        // Re-read directly from defaults — proves didSet wrote through
        #expect(defaults.bool(forKey: SettingsStore.hapticsEnabledKey) == false)
        // Re-construct a fresh store from the same defaults — proves init reads back
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.hapticsEnabled == false)
    }

    @Test("Setting sfxEnabled = true persists to UserDefaults under gamekit.sfxEnabled key")
    func setSfxEnabled_persistsToUserDefaults() {
        let defaults = Self.makeIsolatedDefaults()
        let store = SettingsStore(userDefaults: defaults)
        store.sfxEnabled = true
        #expect(defaults.bool(forKey: SettingsStore.sfxEnabledKey) == true)
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.sfxEnabled == true)
    }

    @Test("Setting hasSeenIntro = true persists to UserDefaults under gamekit.hasSeenIntro key")
    func setHasSeenIntro_persistsToUserDefaults() {
        let defaults = Self.makeIsolatedDefaults()
        let store = SettingsStore(userDefaults: defaults)
        store.hasSeenIntro = true
        #expect(defaults.bool(forKey: SettingsStore.hasSeenIntroKey) == true)
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.hasSeenIntro == true)
    }

    // MARK: - Default-true semantics (D-10 caveat)

    @Test("Unset hapticsEnabled key initializes to true (object(forKey:) as? Bool ?? true pattern)")
    func unsetHapticsEnabledKey_returnsTrueByDefault() {
        let defaults = Self.makeIsolatedDefaults()
        // Pre-condition: confirm the key is genuinely absent in this fresh suite
        #expect(defaults.object(forKey: SettingsStore.hapticsEnabledKey) == nil)
        // Constructing the store on absent key must yield true (D-10 default)
        let store = SettingsStore(userDefaults: defaults)
        #expect(store.hapticsEnabled == true)
    }

    // MARK: - P4 regression guard

    @Test("cloudSyncEnabled still round-trips (P4 D-28/D-29 regression guard)")
    func cloudSyncEnabled_stillRoundTrips_p4Regression() {
        let defaults = Self.makeIsolatedDefaults()
        let store = SettingsStore(userDefaults: defaults)
        store.cloudSyncEnabled = true
        #expect(defaults.bool(forKey: SettingsStore.cloudSyncEnabledKey) == true)
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.cloudSyncEnabled == true)
    }
}
