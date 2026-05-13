//
//  VideoModeEnvironmentTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that
//  EnvironmentValues.videoModeStore (Wave 1, plan 09-02) must satisfy:
//    - VIDEO-03: @Environment(\.videoModeStore) returns the injected store,
//                not the default. Identity (===) check proves not-the-default
//                (per 09-PATTERNS.md §8 environment-injection skeleton).
//
//  Pattern source: SettingsStoreFlagsTests.swift:23-39 (top-of-file header) +
//  09-PATTERNS.md §8 (environment-injection round-trip skeleton).
//
//  RED-STATE NOTE: This file references EnvironmentValues.videoModeStore +
//  VideoModeStore which DO NOT yet exist. The compile failure IS the RED
//  gate — Wave 1 plan 09-02 ships these symbols. xcodebuild build failing
//  on undefined-symbol here is EXPECTED.
//
//  Test name matches 09-VALIDATION.md row 09-02-01 verbatim.
//

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("VideoModeEnvironment")
struct VideoModeEnvironmentTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Declared per-file (NOT shared across test files) — Swift Testing's
    /// parallel execution makes shared helpers risky.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - VIDEO-03: EnvironmentKey round-trip (VALIDATION row 09-02-01)

    @Test("EnvironmentValues.videoModeStore returns the injected store, not the default (VIDEO-03 / 09-02-01)")
    func test_environmentKey_returns_injected() {
        let injected = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())
        var env = EnvironmentValues()
        env.videoModeStore = injected
        // Identity check works because VideoModeStore is a class —
        // proves the setter wrote the exact reference (not a fresh default).
        #expect(env.videoModeStore === injected)
    }
}
