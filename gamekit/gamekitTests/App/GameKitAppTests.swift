//
//  GameKitAppTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that GameKitApp (Wave 2,
//  plan 09-03) must satisfy:
//    - VIDEO-03: VideoModeStore is constructed at app-root and injected
//                via `.environment(\.videoModeStore, ...)` so every game
//                screen can read it via @Environment.
//
//  Pattern source: SettingsStoreFlagsTests.swift:23-39 (test-file header)
//  + 09-PATTERNS.md §8 environment-injection skeleton.
//
//  RED-STATE NOTE: SwiftUI App tests can only assert construction-time
//  invariants, not view-tree injection. This placeholder asserts the
//  EnvironmentKey default-value path is reachable; the real injection
//  assertion lands when Wave 2 ships GameKitApp wiring. Per
//  09-PATTERNS.md §8 last paragraph, the RED gate here is the
//  REFERENCE to missing symbols (EnvironmentValues.videoModeStore),
//  not an interaction assertion.
//
//  Test name matches 09-VALIDATION.md row 09-02-02 verbatim.
//

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("GameKitApp")
struct GameKitAppTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Declared per-file (NOT shared) — Swift Testing parallelism risk.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - VIDEO-03: App-root store construction (VALIDATION row 09-02-02)

    @Test("VideoModeStore is injected at app-root via EnvironmentValues.videoModeStore (VIDEO-03 / 09-02-02)")
    func test_videoModeStore_injected_at_app_root() {
        // Placeholder body — SwiftUI App scene-tree injection is not
        // directly inspectable from a unit test. The RED gate here is
        // the reference to EnvironmentValues.videoModeStore (which
        // does not exist until Wave 1 plan 09-02 ships the EnvironmentKey
        // extension) AND VideoModeStore (Wave 1 type).
        //
        // The default-value path is exercised here — Wave 2 plan 09-03
        // will replace this body with a real assertion against the
        // GameKitApp constructor seam once it lands.
        let env = EnvironmentValues()
        #expect(env.videoModeStore != nil)
        // TODO(09-03): swap for real GameKitApp.init seam assertion once
        // VideoModeStore is wired at app-root.
    }
}
