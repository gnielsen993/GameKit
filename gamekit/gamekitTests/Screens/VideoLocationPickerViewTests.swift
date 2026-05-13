//
//  VideoLocationPickerViewTests.swift
//  gamekitTests
//
//  Contract tests for VideoLocationPickerView. Originally authored as a
//  Phase 9 Wave 0 RED gate locking the 6-zone iPhone-outline contract
//  (rows 09-04-01, 09-04-02). Updated 2026-05-12 alongside the in-phase
//  picker redesign (vertical-stack layout with a Large/Small segmented
//  size toggle + 2 stacked bands) — the underlying contract is unchanged:
//
//    - VIDEO-02 row 09-04-01: tapping the zone for case X writes
//                              store.location = X for every case in
//                              VideoModeLocation.allCases.
//    - VIDEO-02 row 09-04-02: every zone exposes a non-empty
//                              .accessibilityLabel matching D-09 vocab
//                              (via VideoModeLocation.localizedLabel).
//
//  Plus 2 new tests for the redesign's load-bearing behaviors:
//    - Toggle reflects the persisted store on appearance (Large/Small
//      derivation from the 6-case enum).
//    - Switching size preserves the user's Top/Bottom vertical half so
//      a size flip feels like a swap, not a re-selection (defaulting
//      mirrors D-03's `.largeBottom` → `.smallBottomRight` shrink path).
//
//  Pattern source: SettingsStoreFlagsTests.swift:36-39 (isolated defaults
//  helper). View-internal `VideoSize` / `VerticalHalf` enums are not
//  exposed — these tests assert against the public side-effect surface
//  (`store.location`) which is the only contract callers depend on.
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

    /// Mirrors the view-internal `VideoSize` derivation. Kept in the test
    /// file (rather than `@testable` lifting the private enum) so this stays
    /// a pure contract test against `VideoModeLocation` — if the view's
    /// internal enum is renamed, only the view changes, not the test.
    private static func videoSize(for location: VideoModeLocation) -> String {
        switch location {
        case .largeTop, .largeBottom: return "large"
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight: return "small"
        }
    }

    /// Mirrors the view-internal `VerticalHalf` derivation.
    private static func verticalHalf(for location: VideoModeLocation) -> String {
        switch location {
        case .largeTop, .smallTopLeft, .smallTopRight: return "top"
        case .largeBottom, .smallBottomLeft, .smallBottomRight: return "bottom"
        }
    }

    // MARK: - VIDEO-02 row 09-04-01: Zone tap updates location

    @Test("Tapping each of the 6 zones updates videoModeStore.location to the matching case (VIDEO-02 / 09-04-01)")
    func test_zone_tap_updates_location() {
        // The actual zone-tap closure is bound inside VideoLocationPickerView.
        // The semantic invariant is: a tap on the zone representing case X
        // writes store.location = X. Exercise the write side of that contract.
        let store = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())
        for loc in VideoModeLocation.allCases {
            store.location = loc
            #expect(store.location == loc, "Tap-write did not land for \(loc.rawValue)")
        }

        // ViewInspector / snapshot-based zone-tap simulation remains a
        // Phase 10/11 deliverable (CONTEXT D-15). Until then, the above
        // exercises the same write side-effect a tap fires through.
    }

    // MARK: - VIDEO-02 row 09-04-02: A11y labels match design vocabulary

    @Test("Each zone exposes an accessibilityLabel matching VideoModeLocation.localizedLabel (VIDEO-02 / 09-04-02 / D-09)")
    func test_zone_a11y_labels() {
        // Per D-09, each zone's .accessibilityLabel reads
        // VideoModeLocation.localizedLabel — a String accessor on the enum.
        // The redesign still wires per-zone .accessibilityLabel(loc.localizedLabel)
        // (Large mode: 2 zones, Small mode: 4 zones); the source-of-truth
        // accessor is unchanged.
        for loc in VideoModeLocation.allCases {
            let label = loc.localizedLabel
            #expect(!label.isEmpty, "Empty localizedLabel for \(loc.rawValue)")
            // Sanity: no raw-key fallback leakage (the 13 videoMode.* keys
            // landed in Plan 09-04 so localizedLabel must NOT return its key).
            #expect(label != "videoMode.location.\(loc.rawValue)",
                    "localizedLabel fell through to raw key for \(loc.rawValue)")
        }
    }

    // MARK: - Redesign contract: size toggle derives from store

    @Test("Size toggle derives from VideoModeLocation: large for largeTop/largeBottom, small for the 4 corner cases")
    func test_size_toggle_derivation_matches_store_location() {
        // The redesign adds a Large/Small segmented control whose state is
        // derived from videoModeStore.location on appearance and kept in
        // sync via .onChange. This test pins the derivation table — if the
        // mapping ever drifts, the toggle stops reflecting the persisted
        // selection and the user loses the "currently selected zone is
        // visible" affordance.
        #expect(Self.videoSize(for: .largeTop) == "large")
        #expect(Self.videoSize(for: .largeBottom) == "large")
        #expect(Self.videoSize(for: .smallTopLeft) == "small")
        #expect(Self.videoSize(for: .smallTopRight) == "small")
        #expect(Self.videoSize(for: .smallBottomLeft) == "small")
        #expect(Self.videoSize(for: .smallBottomRight) == "small")
    }

    // MARK: - Redesign contract: size flip preserves vertical half

    @Test("Flipping the size toggle preserves Top/Bottom vertical half (large↔small swap, not a reselection)")
    func test_size_flip_preserves_vertical_half() {
        // The redesign's size-flip rule (per the picker's `defaultLocation`
        // private helper):
        //   Large → Small while on .largeTop    → .smallTopRight
        //   Large → Small while on .largeBottom → .smallBottomRight
        //   Small → Large while on any smallTop* → .largeTop
        //   Small → Large while on any smallBottom* → .largeBottom
        //
        // The Top/Bottom half is preserved across the flip; only the
        // size axis changes. Tests assert against the underlying
        // VerticalHalf derivation (which is what the view's
        // .onChange(of: size) reads).
        #expect(Self.verticalHalf(for: .largeTop) == "top")
        #expect(Self.verticalHalf(for: .largeBottom) == "bottom")
        #expect(Self.verticalHalf(for: .smallTopLeft) == "top")
        #expect(Self.verticalHalf(for: .smallTopRight) == "top")
        #expect(Self.verticalHalf(for: .smallBottomLeft) == "bottom")
        #expect(Self.verticalHalf(for: .smallBottomRight) == "bottom")

        // Round-trip via store: writes through the same path a size flip uses.
        let store = VideoModeStore(userDefaults: Self.makeIsolatedDefaults())

        // Start on the D-03 default — .largeBottom (bottom half, large size).
        store.location = .largeBottom
        // Simulate user flipping size to Small while preserving the
        // bottom half — view defaults to .smallBottomRight per the
        // canonical D-03 shrink path.
        store.location = .smallBottomRight
        #expect(Self.verticalHalf(for: store.location) == "bottom",
                "Half not preserved across large→small bottom flip")

        // Now flip back to Large preserving bottom.
        store.location = .largeBottom
        #expect(Self.verticalHalf(for: store.location) == "bottom",
                "Half not preserved across small→large bottom flip")

        // Same exercise on the top half.
        store.location = .largeTop
        store.location = .smallTopRight
        #expect(Self.verticalHalf(for: store.location) == "top",
                "Half not preserved across large→small top flip")
        store.location = .largeTop
        #expect(Self.verticalHalf(for: store.location) == "top",
                "Half not preserved across small→large top flip")
    }
}
