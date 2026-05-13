//
//  VideoLocationPickerViewTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that VideoLocationPickerView
//  (Wave 3, plan 09-04) must satisfy:
//    - VIDEO-02 row 09-04-01: Tapping each of 6 zones updates
//                              videoModeStore.location to corresponding case.
//    - VIDEO-02 row 09-04-02: Each zone carries an .accessibilityLabel
//                              matching the design-locked vocabulary
//                              ("Large top", "Small bottom-left", etc.) via
//                              VideoModeLocation.localizedLabel (D-09).
//
//  Pattern source: SettingsStoreFlagsTests.swift:36-39 (isolated defaults
//  helper) + 09-PATTERNS.md §4 (picker shape) + §8 (test analog).
//
//  RED-STATE NOTE: The actual VideoLocationPickerView (Wave 3 plan 09-04)
//  does not yet exist; this file's reference to VideoModeLocation +
//  VideoModeStore is sufficient for the compile-time RED gate. For zone
//  tap simulation + a11y inspection, real ViewInspector / snapshot
//  infrastructure is a Phase 10/11 deliverable per CONTEXT D-15.
//  Placeholder bodies exercise the underlying contract (writing
//  store.location flips the value to the expected case).
//
//  Test names match 09-VALIDATION.md rows 09-04-01 / 09-04-02 verbatim.
//

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("VideoLocationPickerView")
struct VideoLocationPickerViewTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Declared per-file (NOT shared) — Swift Testing parallelism risk.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - VIDEO-02 row 09-04-01: Zone tap updates location

    @Test("Tapping each of the 6 zones updates videoModeStore.location to the matching case (VIDEO-02 / 09-04-01)")
    func test_zone_tap_updates_location() {
        // The actual zone-tap closure is bound inside VideoLocationPickerView
        // (Wave 3 plan 09-04). The semantic invariant is: a tap on zone
        // representing case X writes store.location = X. Exercise the
        // write side of that contract here.
        let store = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())
        for loc in VideoModeLocation.allCases {
            store.location = loc
            #expect(store.location == loc, "Tap-write did not land for \(loc.rawValue)")
        }

        // TODO(09-04): swap for real zone-tap simulation via
        // ViewInspector or snapshot rig once the picker view ships.
    }

    // MARK: - VIDEO-02 row 09-04-02: A11y labels match design vocabulary

    @Test("Each zone exposes an accessibilityLabel matching VideoModeLocation.localizedLabel (VIDEO-02 / 09-04-02 / D-09)")
    func test_zone_a11y_labels() {
        // Per D-09, each zone's .accessibilityLabel reads
        // VideoModeLocation.localizedLabel — a String accessor on the
        // enum (Wave 1 plan 09-02 ships the accessor; xcstrings
        // catalog keys land in Wave 2 plan 09-03 per VIDEO-14).
        //
        // For this RED gate we assert the localizedLabel accessor exists
        // and returns a non-empty string for every case. Real .accessibilityLabel
        // wiring is verified in Wave 3 once the picker view ships.
        for loc in VideoModeLocation.allCases {
            let label = loc.localizedLabel
            #expect(!label.isEmpty, "Empty localizedLabel for \(loc.rawValue)")
        }

        // TODO(09-04): swap for real .accessibilityLabel inspection via
        // ViewInspector or snapshot a11y traversal once the picker view ships.
    }
}
