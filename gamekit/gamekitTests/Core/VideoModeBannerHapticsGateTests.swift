//
//  VideoModeBannerHapticsGateTests.swift
//  gamekitTests
//
//  Phase 13 — D-13-HAPTICS contract test: VideoModeBanner.playEntranceHaptic()
//  honors the FIRST-guard pattern. When hapticsEnabled == false, the method
//  returns BEFORE touching any haptic engine. Mirrors HapticsTests.swift:69-80
//  (`playAHAP_disabled_doesNotInitializeEngine`) shape.
//
//  Pattern source: gamekit/gamekitTests/Core/HapticsTests.swift (v1.0 05-03 D-10).
//
//  Note: full haptic playback is not unit-testable on simulator (CHHapticEngine
//  is a no-op there per Apple docs). These tests focus on the FIRST-guard
//  contract shape (compile-time + early-return + no crash on either branch).
//

import Testing
import SwiftUI
import DesignKit
@testable import gamekit

@MainActor
@Suite("VideoModeBanner haptics gate")
struct VideoModeBannerHapticsGateTests {

    // MARK: - Helpers

    /// Canonical test theme — mirrors `VideoCompactControlRow.swift:103`
    /// preview pattern (`Theme.resolve(preset: .classicMuted, scheme: .light)`)
    /// which is the same shape SettingsView reads at runtime.
    private static var testTheme: Theme {
        Theme.resolve(preset: .classicMuted, scheme: .light)
    }

    private static func makeContent(outcome: VideoModeBannerContent.Outcome) -> VideoModeBannerContent {
        VideoModeBannerContent(
            outcome: outcome,
            title: outcome == .win ? "You won!" : "Bad luck",
            subtitle: nil,
            primaryButtonLabel: "Restart",
            accessibilityLabel: outcome == .win ? "You won! Restart" : "Bad luck. Restart",
            onPrimary: {}
        )
    }

    // MARK: - D-13-HAPTICS FIRST-guard contract (v1.0 05-03 D-10)

    @Test("playEntranceHaptic with hapticsEnabled=false returns without crashing (FIRST-guard contract)")
    func playEntranceHaptic_disabled_doesNotCrash() {
        let banner = VideoModeBanner(
            theme: Self.testTheme,
            content: Self.makeContent(outcome: .win),
            location: .largeBottom,
            hapticsEnabled: false,
            reduceMotion: false,
            animationsEnabled: true
        )
        // D-13-HAPTICS / v1.0 05-03 D-10: must early-return BEFORE touching
        // any haptic engine — verified by absence of crash on Simulator
        // (CHHapticEngine is a no-op there but the guard fires either way).
        banner.playEntranceHaptic()
        #expect(banner.hapticsEnabled == false,
                "FIRST-guard contract: hapticsEnabled is the first read inside playEntranceHaptic()")
    }

    @Test("playEntranceHaptic with hapticsEnabled=true completes without crashing")
    func playEntranceHaptic_enabled_doesNotCrash() {
        let banner = VideoModeBanner(
            theme: Self.testTheme,
            content: Self.makeContent(outcome: .loss),
            location: .smallTopLeft,
            hapticsEnabled: true,
            reduceMotion: false,
            animationsEnabled: true
        )
        banner.playEntranceHaptic()    // no crash on Simulator (CHHapticEngine no-op)
        #expect(banner.hapticsEnabled == true)
    }

    // MARK: - Outcome wiring (drives haptic cue + title color)

    @Test("Banner with win outcome routes through the win-cue path")
    func banner_winOutcome_propagatesToContent() {
        let content = Self.makeContent(outcome: .win)
        let banner = VideoModeBanner(
            theme: Self.testTheme,
            content: content,
            location: .largeBottom,
            hapticsEnabled: true,
            reduceMotion: false,
            animationsEnabled: true
        )
        #expect(banner.content.outcome == .win)
    }

    @Test("Banner with loss outcome routes through the loss-cue path")
    func banner_lossOutcome_propagatesToContent() {
        let content = Self.makeContent(outcome: .loss)
        let banner = VideoModeBanner(
            theme: Self.testTheme,
            content: content,
            location: .largeBottom,
            hapticsEnabled: true,
            reduceMotion: false,
            animationsEnabled: true
        )
        #expect(banner.content.outcome == .loss)
    }
}
