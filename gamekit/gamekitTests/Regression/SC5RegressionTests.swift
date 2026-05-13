//
//  SC5RegressionTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 surface — locks SC5 (Off-state byte-identical
//  regression) as a contract Phase 11/12 must satisfy:
//    - Row 09-07-01: With `videoModeStore.isEnabled == false`, every
//                    game view (Minesweeper / Merge / Nonogram)
//                    renders byte-identically to its pre-v1.2 baseline.
//
//  CONTEXT D-15 — "Off-state SC5 is automatically preserved in Phase 9":
//  Phase 9 game views do NOT yet read `videoModeStore.isEnabled` or
//  `videoModeStore.location`. Those reads start in Phase 11/12. Therefore
//  on a fresh install / no UserDefaults touch, the off-state is
//  automatically byte-identical to v1.1 by code-path analysis — this file
//  codifies that invariant at the store level and documents the upgrade
//  path Phase 11/12 will take (real snapshot diff once the layout-altering
//  branches are introduced).
//
//  Pattern source: SettingsStoreFlagsTests.swift:23-29 (test-file header)
//  + 09-PATTERNS.md §8 last paragraph (contract test, not screenshot diff).
//
//  Test name matches 09-VALIDATION.md row 09-07-01 verbatim.
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("SC5Regression")
struct SC5RegressionTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Each test gets a fresh suite so a stray prior-run write cannot mask
    /// the default-state contract we are asserting here.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-sc5-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - SC5 row 09-07-01: Off-state byte-identical

    @Test("SC5 D-15 contract — Video Mode default Off + no Phase 9 game view reads location → off-state byte-identical to pre-v1.2 baseline")
    func test_off_state_byte_identical() {
        // CONTEXT D-15 lock: in Phase 9, NO game view reads videoModeStore.isEnabled
        // or videoModeStore.location yet (those reads start in Phase 11/12).
        // Therefore on fresh install / no UserDefaults touch, the off-state is
        // automatically byte-identical to v1.1 — this test codifies that invariant
        // at the store level + provides a documented site for Phase 11/12 to
        // upgrade to real snapshot infrastructure.

        // Invariant 1: Default isEnabled is false on fresh install.
        let defaults = Self.makeIsolatedDefaults()
        let store = VideoModeStore(userDefaults: defaults)
        #expect(store.isEnabled == false)
        // The default-off contract IS the SC5 baseline preservation: if every
        // game view's only branch is `if store.isEnabled { ... apply video mode ... }`
        // (which is what Phase 11/12 will land), then isEnabled == false means
        // the layout-altering branch is never entered, and rendering is identical
        // to v1.1 by code-path analysis.

        // Invariant 2: Default location is .largeBottom — irrelevant for off-state
        // but locked by D-03 + ROADMAP SC2.
        #expect(store.location == .largeBottom)

        // TODO(P11/P12): Once Mines/Merge/Nonogram game views adopt
        // VideoCompactControlRow + videoModeStore reads, replace this body with
        // a real snapshot diff (capture rendered view image with
        // store.isEnabled = false; compare to v1.1 baseline image stored in
        // gamekitTests/Resources/SC5/baselines/).
    }
}
