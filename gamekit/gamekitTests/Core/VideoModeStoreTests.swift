//
//  VideoModeStoreTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that VideoModeStore +
//  VideoModeLocation (Wave 1, plan 09-02) must satisfy:
//    - VIDEO-01: isEnabled defaults to false, round-trips through UserDefaults
//    - VIDEO-02: VideoModeLocation has exactly 6 cases (largeTop / largeBottom /
//                smallTopLeft / smallTopRight / smallBottomLeft / smallBottomRight)
//    - VIDEO-03: location persists; default is .largeBottom (D-03)
//    - RESEARCH Topic 3 invariant #4: corrupt raw-string falls back to .largeBottom
//
//  Pattern source: SettingsStoreFlagsTests.swift:23-114 — copy verbatim shape:
//  `import Testing`, `import Foundation`, `@testable import gamekit`,
//  `@MainActor @Suite("...")`, struct + makeIsolatedDefaults() static helper
//  (mirrored from MinesweeperViewModelTests.swift:25-28).
//
//  RED-STATE NOTE: This file references types (VideoModeStore, VideoModeLocation,
//  VideoModeStore.isEnabledKey, VideoModeStore.locationKey) that DO NOT yet
//  exist. The compile failure IS the RED gate — Wave 1 plan 09-02 produces
//  these types and the file flips to GREEN. xcodebuild build failing on
//  undefined-symbol here is EXPECTED.
//
//  Test names match 09-VALIDATION.md rows 09-01-01..09-01-05 verbatim.
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("VideoModeStore")
struct VideoModeStoreTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Each test gets a fresh suite name so writes in one test never bleed
    /// into a sibling test running in parallel under Swift Testing.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - VIDEO-01: isEnabled default (VALIDATION row 09-01-02)

    @Test("isEnabled defaults to false on fresh UserDefaults suite (VIDEO-01 / 09-01-02)")
    func test_isEnabled_defaults_to_false() {
        let defaults = Self.makeIsolatedDefaults()
        // Pre-condition: confirm the key is genuinely absent in this fresh suite
        #expect(defaults.object(forKey: VideoModeStore.isEnabledKey) == nil)
        // UserDefaults.bool(forKey:) returns false for unset keys — RESEARCH
        // Topic 3 invariant #3. No register(defaults:) needed.
        let store = VideoModeStore(userDefaults: defaults)
        #expect(store.isEnabled == false)
    }

    // MARK: - VIDEO-01: isEnabled round-trip (VALIDATION row 09-01-01)

    @Test("Setting isEnabled = true persists to UserDefaults under gamekit.videoModeEnabled key (VIDEO-01 / 09-01-01)")
    func test_isEnabled_persists() {
        let defaults = Self.makeIsolatedDefaults()
        let store = VideoModeStore(userDefaults: defaults)
        store.isEnabled = true
        // Re-read directly from defaults — proves didSet wrote through
        #expect(defaults.bool(forKey: VideoModeStore.isEnabledKey) == true)
        // Re-construct a fresh store from the same defaults — proves init reads back
        let reloaded = VideoModeStore(userDefaults: defaults)
        #expect(reloaded.isEnabled == true)
    }

    // MARK: - VIDEO-02 / VIDEO-03: location default (VALIDATION row 09-01-04 / CONTEXT D-03)

    @Test("location defaults to .largeBottom on fresh UserDefaults suite (VIDEO-02 / VIDEO-03 / 09-01-04 / D-03)")
    func test_location_default_is_largeBottom() {
        let defaults = Self.makeIsolatedDefaults()
        // Pre-condition: key absent
        #expect(defaults.object(forKey: VideoModeStore.locationKey) == nil)
        let store = VideoModeStore(userDefaults: defaults)
        #expect(store.location == .largeBottom)
    }

    // MARK: - VIDEO-02 / VIDEO-03: all 6 cases round-trip (VALIDATION row 09-01-03)

    @Test("location round-trips through UserDefaults for all 6 cases (VIDEO-02 / VIDEO-03 / 09-01-03)")
    func test_location_persists_all_cases() {
        for loc in VideoModeLocation.allCases {
            let defaults = Self.makeIsolatedDefaults()
            let store = VideoModeStore(userDefaults: defaults)
            store.location = loc
            // Reload from the same defaults — proves rawValue write + read symmetry
            let reloaded = VideoModeStore(userDefaults: defaults)
            #expect(reloaded.location == loc, "Round-trip failed for \(loc.rawValue)")
        }
    }

    // MARK: - VIDEO-02: enum is exhaustive (VALIDATION row 09-01-05 / CONTEXT D-07)

    @Test("VideoModeLocation has exactly 6 cases with locked rawValues (VIDEO-02 / 09-01-05 / D-07)")
    func test_location_enum_has_6_cases() {
        #expect(VideoModeLocation.allCases.count == 6)
        let rawValues = Set(VideoModeLocation.allCases.map(\.rawValue))
        #expect(rawValues == [
            "largeTop",
            "largeBottom",
            "smallTopLeft",
            "smallTopRight",
            "smallBottomLeft",
            "smallBottomRight"
        ])
    }

    // MARK: - Corruption defense (RESEARCH Topic 3 invariant #4)

    @Test("Corrupt rawValue in UserDefaults falls back to .largeBottom (RESEARCH Topic 3 invariant #4)")
    func test_corruptLocation_fallsBackToLargeBottom() {
        let defaults = Self.makeIsolatedDefaults()
        // Pre-seed the location key with a value that does NOT match any VideoModeLocation case
        defaults.set("garbage", forKey: VideoModeStore.locationKey)
        let store = VideoModeStore(userDefaults: defaults)
        #expect(store.location == .largeBottom)
    }
}
