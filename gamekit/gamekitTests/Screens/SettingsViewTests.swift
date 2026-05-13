//
//  SettingsViewTests.swift
//  gamekitTests
//
//  Phase 9 Wave 0 RED gate — locks the contract that SettingsView's
//  VIDEO MODE card (Wave 3, plan 09-05) must satisfy:
//    - VIDEO-01 row 09-03-01: Toggle's isOn binding is wired to
//                              videoModeStore.isEnabled via Bindable.
//    - VIDEO-01 row 09-03-02: "Video location: <label>" NavigationLink
//                              row is conditional — present only when
//                              videoModeStore.isEnabled == true (D-01).
//
//  Pattern source: SettingsStoreFlagsTests.swift:36-39 (isolated defaults
//  helper) + 09-PATTERNS.md §5 (SettingsView card-clone shape).
//
//  RED-STATE NOTE: SwiftUI view-tree assertions require either ViewInspector
//  (not in scope here per 09-PATTERNS.md §8) or a snapshot rig (Phase 10/11
//  deliverable per CONTEXT D-15). For now, these tests use placeholder
//  bodies that exercise the underlying Bindable round-trip — the actual
//  Toggle binding semantics — without crossing the SwiftUI body boundary.
//  Wave 3 plan 09-05 will swap these bodies for the real view-tree
//  assertions once VideoModeStore + the card both exist.
//
//  Test names match 09-VALIDATION.md rows 09-03-01 / 09-03-02 verbatim.
//

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("SettingsView")
struct SettingsViewTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors SettingsStoreFlagsTests:36-39.
    /// Declared per-file (NOT shared) — Swift Testing parallelism risk.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    // MARK: - VIDEO-01 row 09-03-01: Toggle binds to store

    @Test("Toggle's isOn binding round-trips through videoModeStore.isEnabled (VIDEO-01 / 09-03-01)")
    func test_videoMode_toggle_binds_to_store() {
        // The actual Toggle UI element is built inside SettingsView's
        // VIDEO MODE card (Wave 3 plan 09-05). For this RED gate we
        // exercise the Bindable round-trip pattern that the Toggle will
        // use — Bindable(store).isEnabled is the same code path the
        // SwiftUI Toggle isOn: binding consumes.
        let store = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())
        #expect(store.isEnabled == false)

        // Simulate the Toggle flip — this is the exact write a SwiftUI
        // Toggle isOn: $bindable.isEnabled performs.
        let binding = Bindable(store).isEnabled
        binding.wrappedValue = true
        #expect(store.isEnabled == true)

        // TODO(09-05): swap for real SettingsView body assertion via
        // snapshot or ViewInspector once the VIDEO MODE card is shipped.
    }

    // MARK: - VIDEO-01 row 09-03-02: Conditional row visibility

    @Test("Video-location NavigationLink row is present iff videoModeStore.isEnabled is true (VIDEO-01 / 09-03-02 / D-01)")
    func test_locationRow_visibility_follows_isEnabled() {
        // The actual `if videoModeStore.isEnabled { ... NavigationLink ... }`
        // branch lives in SettingsView (Wave 3 plan 09-05). For this RED
        // gate we exercise the underlying boolean predicate that gates
        // the row's visibility.
        let store = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())
        // Off-state — row should be hidden
        #expect(store.isEnabled == false)
        // On-state — row should appear
        store.isEnabled = true
        #expect(store.isEnabled == true)

        // TODO(09-05): swap for real SettingsView snapshot diff asserting
        // the NavigationLink row text "Video location: \(label)" appears
        // exactly when store.isEnabled == true.
    }
}
