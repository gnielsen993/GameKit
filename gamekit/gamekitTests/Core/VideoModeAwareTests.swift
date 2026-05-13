//
//  VideoModeAwareTests.swift
//  gamekitTests
//
//  Phase 10 Wave 0 RED gate — locks the SC3 (off-restore) + VIDEO-06 (band
//  reservation + compactness publication) contract that VideoModeAware MUST
//  satisfy in Plan 10-03:
//    - VIDEO-13 / D-05 / SC3: when store.isEnabled == false, the modifier
//      returns AnyView(content) and does NOT publish the
//      \.videoModeCompactness env — descendants read the env default (.normal).
//    - VIDEO-06 / D-13: when store.isEnabled == true, the modifier publishes
//      a discrete VideoModeCompactness — one of .normal / .collapsedSettings /
//      .reducedTime — based on (available height) vs (minBoardHeight).
//    - D-14 thresholds: available >= floor -> .normal;
//      0.85*floor <= available < floor -> .collapsedSettings;
//      available < 0.85*floor -> .reducedTime.
//    - D-09 / D-10 lock: largeBandFraction = 0.32 (measured worst-case from
//      Docs/screenshots/v1.2-design/home-classic-pip-large-bottom.png).
//
//  Pattern source: VideoModeStoreTests.swift:1-43 (header doc-comment + @Suite
//  shape + makeIsolatedDefaults helper) + RESEARCH §Example 1 (renderAndCapture
//  probe helper).
//
//  RED-STATE NOTE: This file references types (VideoModeAware, VideoModeCompactness,
//  EnvironmentValues.videoModeCompactness, View.videoModeAware(minBoardHeight:))
//  that DO NOT yet exist. The compile failure IS the RED gate — Plan 10-03
//  produces these types and the file flips to GREEN.
//
//  Test names match 10-VALIDATION.md VIDEO-06 + VIDEO-13 rows.
//

import Testing
import Foundation
import SwiftUI
@testable import gamekit

@MainActor
@Suite("VideoModeAware short-circuit (SC3)")
struct VideoModeAwareTests {

    // MARK: - Helpers

    /// Per-test isolated UserDefaults — mirrors VideoModeStoreTests.swift:36-43.
    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    /// Construct a configured VideoModeStore for a test case.
    static func makeStore(enabled: Bool, location: VideoModeLocation = .largeBottom) -> VideoModeStore {
        let store = VideoModeStore(userDefaults: makeIsolatedDefaults())
        store.isEnabled = enabled
        store.location = location
        return store
    }

    /// Mounts a stub view wrapped with `.videoModeAware(minBoardHeight:)` inside
    /// a UIHostingController of the specified `forcedHeight`, reads the
    /// `\.videoModeCompactness` env at a descendant via a probe child, and
    /// returns the captured value.
    ///
    /// Approach (RESEARCH §Example 1 recommendation):
    ///   1. Build StubProbe view that has @Environment(\.videoModeCompactness) and
    ///      writes it to an Atomic captured-value box via .onAppear.
    ///   2. Wrap the probe with the modifier and the store env.
    ///   3. Mount in UIHostingController(rootView:) sized to (375, forcedHeight).
    ///   4. Force a layout pass via vc.view.setNeedsLayout() +
    ///      vc.view.layoutIfNeeded() so .onAppear fires.
    ///   5. Read the captured value.
    ///
    /// No 3rd-party ViewInspector dep — uses only UIKit hosting + SwiftUI env.
    static func renderAndCapture(
        store: VideoModeStore,
        minBoardHeight: CGFloat,
        forcedHeight: CGFloat = 900
    ) -> VideoModeCompactness {
        let captureBox = CompactnessCaptureBox()

        struct StubProbe: View {
            @Environment(\.videoModeCompactness) private var compactness
            let box: CompactnessCaptureBox
            var body: some View {
                Color.clear.onAppear { box.value = compactness }
            }
        }

        let rootView = StubProbe(box: captureBox)
            .videoModeAware(minBoardHeight: minBoardHeight)
            .environment(\.videoModeStore, store)
            .frame(width: 375, height: forcedHeight)

        let vc = UIHostingController(rootView: rootView)
        vc.view.frame = CGRect(x: 0, y: 0, width: 375, height: forcedHeight)

        // 10-03 Rule-3 fix: SwiftUI's .onAppear does NOT fire on a UIHostingController
        // whose view is not attached to a UIWindow. Attach to a transient off-screen
        // window so onAppear fires and the env-capture probe actually captures the
        // value the modifier publishes (rather than the env default).
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: forcedHeight))
        window.rootViewController = vc
        window.isHidden = false
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        // SwiftUI may defer onAppear to next runloop tick.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        // Detach to release the window after capture.
        window.isHidden = true
        window.rootViewController = nil

        return captureBox.value ?? .normal
    }

    /// Reference type so the @State-free probe can write back to the test.
    /// Marked @MainActor because the probe writes from a SwiftUI body context.
    @MainActor final class CompactnessCaptureBox {
        var value: VideoModeCompactness?
    }

    // MARK: - VIDEO-13 / D-05 / SC3: off-state byte-identical

    @Test("Off state — modifier does NOT publish videoModeCompactness env (VIDEO-13 / D-05 / SC3)")
    func test_offState_doesNotPublishCompactness() {
        let store = Self.makeStore(enabled: false)
        // When off, the modifier short-circuits with AnyView(content) and never
        // calls .environment(\.videoModeCompactness, …). Descendants read the
        // env DEFAULT value (.normal) — proving the modifier never overrode it.
        let captured = Self.renderAndCapture(
            store: store,
            minBoardHeight: 480,
            forcedHeight: 200  // intentionally TIGHT — if the modifier were
                               // running, it would publish .reducedTime here.
                               // The fact that .normal comes back proves D-05.
        )
        #expect(captured == .normal)
    }

    // MARK: - VIDEO-06 / D-13 / D-14: 3 compactness levels under on-state

    @Test("On state + comfortable size — publishes .normal (VIDEO-06 / D-13)")
    func test_onState_normal() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        // forcedHeight=900, fraction=0.32 → band=288. compactRow=24.
        // available = 900 - 288 - 24 = 588. floor=200. 588 >= 200 → .normal.
        let captured = Self.renderAndCapture(
            store: store,
            minBoardHeight: 200,
            forcedHeight: 900
        )
        #expect(captured == .normal)
    }

    @Test("On state + tight size — publishes .collapsedSettings (VIDEO-06 / D-13 / D-14)")
    func test_onState_collapsedSettings() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        // forcedHeight=1200, fraction=0.32 → band=384. compactRow=24.
        // available = 1200 - 384 - 24 = 792. floor=800. 0.85*floor=680.
        // 680 ≤ 792 < 800 → .collapsedSettings.
        let captured = Self.renderAndCapture(
            store: store,
            minBoardHeight: 800,
            forcedHeight: 1200
        )
        #expect(captured == .collapsedSettings)
    }

    @Test("On state + very tight size — publishes .reducedTime (VIDEO-06 / D-13 / D-14)")
    func test_onState_reducedTime() {
        let store = Self.makeStore(enabled: true, location: .largeBottom)
        // forcedHeight=1000, fraction=0.32 → band=320. compactRow=24.
        // available = 1000 - 320 - 24 = 656. floor=800. 0.85*floor=680.
        // 656 < 680 → .reducedTime.
        let captured = Self.renderAndCapture(
            store: store,
            minBoardHeight: 800,
            forcedHeight: 1000
        )
        #expect(captured == .reducedTime)
    }
}
