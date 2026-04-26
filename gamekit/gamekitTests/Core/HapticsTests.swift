//
//  HapticsTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 05-03 Core/Haptics service.
//
//  What this proves:
//    - Plan 05-02 AHAP assets are bundled correctly (file presence)
//    - AHAP JSON is valid CoreHaptics format (CHHapticPattern parses)
//    - Gating-at-source contract per CONTEXT D-10:
//        playAHAP(... hapticsEnabled: false) early-returns BEFORE
//        instantiating the lazy CHHapticEngine. Verified via the
//        DEBUG-only `hasInitializedEngineForTesting` accessor.
//    - Non-fatal failure path per CONTEXT D-11:
//        playAHAP with a missing AHAP filename does NOT crash
//        (logs and returns). Tests cannot intercept os.Logger output,
//        so this is a "doesn't crash, doesn't throw" assertion.
//
//  Why @MainActor struct: Haptics is a @MainActor enum (per D-11),
//  so all calls require main-actor isolation. Mirrors the
//  GameStatsTests pattern (gamekitTests/Core/GameStatsTests.swift:24).
//
//  Note: full haptic playback is not unit-testable on simulator
//  (CHHapticEngine is a no-op there per Apple docs). These tests
//  focus on file presence, JSON parseability, and the gating contract
//  — NOT on actual haptic output.
//

import Testing
import Foundation
import CoreHaptics
@testable import gamekit

@MainActor
@Suite("Haptics")
struct HapticsTests {

    // MARK: - File presence (proves Plan 05-02 + Xcode 16 PBXFileSystemSynchronizedRootGroup auto-registration)

    @Test("win.ahap exists in main bundle")
    func winAhap_existsInBundle() {
        let url = Bundle.main.url(forResource: "win", withExtension: "ahap")
        #expect(url != nil, "Resources/Haptics/win.ahap must be auto-registered into the bundle by Xcode 16")
    }

    @Test("loss.ahap exists in main bundle")
    func lossAhap_existsInBundle() {
        let url = Bundle.main.url(forResource: "loss", withExtension: "ahap")
        #expect(url != nil, "Resources/Haptics/loss.ahap must be auto-registered into the bundle by Xcode 16")
    }

    // MARK: - AHAP parseability (proves the JSON is valid CoreHaptics)

    @Test("win.ahap parses as a valid CHHapticPattern")
    func winAhap_parsesAsValidCHHapticPattern() throws {
        let url = try #require(Bundle.main.url(forResource: "win", withExtension: "ahap"))
        // CHHapticPattern(contentsOf:) throws if the JSON is not a valid AHAP shape.
        _ = try CHHapticPattern(contentsOf: url)
    }

    @Test("loss.ahap parses as a valid CHHapticPattern")
    func lossAhap_parsesAsValidCHHapticPattern() throws {
        let url = try #require(Bundle.main.url(forResource: "loss", withExtension: "ahap"))
        _ = try CHHapticPattern(contentsOf: url)
    }

    // MARK: - Gating-at-source contract (CONTEXT D-10)

    @Test("playAHAP with hapticsEnabled=false early-returns BEFORE instantiating CHHapticEngine")
    func playAHAP_disabled_doesNotInitializeEngine() {
        // Reset the shared engine state so this test is independent of execution order.
        Haptics.resetForTesting()
        #expect(Haptics.hasInitializedEngineForTesting == false,
                "Pre-condition: engine must be nil after resetForTesting()")

        Haptics.playAHAP(named: "win", hapticsEnabled: false)

        #expect(Haptics.hasInitializedEngineForTesting == false,
                "D-10 gate violated: hapticsEnabled=false MUST early-return before touching CHHapticEngine")
    }

    // MARK: - Non-fatal failure path (CONTEXT D-11)

    @Test("playAHAP with a missing filename does not crash (non-fatal failure path)")
    func playAHAP_missingFile_doesNotCrash() {
        // Per CONTEXT D-11: failure must be silent + non-fatal. We can't
        // intercept os.Logger output from a unit test, so this asserts
        // the call returns cleanly without crashing the test process.
        Haptics.resetForTesting()
        Haptics.playAHAP(named: "definitely-not-a-real-ahap-file-xyz", hapticsEnabled: true)
        // If we reached this line, the failure path returned cleanly.
        #expect(Bool(true))
    }
}
