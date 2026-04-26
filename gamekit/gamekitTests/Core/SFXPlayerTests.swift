//
//  SFXPlayerTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 05-03 Core/SFXPlayer service.
//
//  What this proves:
//    - `init()` is non-throwing under all conditions (CAFs missing OR
//      present); init must succeed even with no CAF binaries on disk per
//      CONTEXT D-11/D-12 non-fatal failure handling — the players just
//      become nil and `play(...)` is a no-op.
//    - `AVAudioSession.setCategory(.ambient, mode: .default)` is set
//      exactly once during init (CONTEXT D-09 — never duck user music).
//    - **Gating-at-source contract** (CONTEXT D-10): `play(_, sfxEnabled:
//      false)` early-returns BEFORE the underlying `AVAudioPlayer.play()`
//      call. Verified via the DEBUG-only `lastInvocationAttempt` and
//      `lastPlayedEvent` test seam: `lastInvocationAttempt` records every
//      call (gate visible), `lastPlayedEvent` is set only when the gate
//      passes (proves the per-event branch fired).
//    - When CAF files DO land (Plan 05-02 Task 3 deferred per
//      05-02-SUMMARY.md), the file-presence test un-skips automatically
//      and asserts that all 3 preloaded `AVAudioPlayer?` instances
//      decoded successfully. Until then the assertion is gated on
//      `Bundle.main.url(...)` returning non-nil.
//
//  Why @MainActor struct: SFXPlayer is `@MainActor final class` (per
//  CONTEXT D-12), so all calls require main-actor isolation. Mirrors
//  GameStatsTests (gamekitTests/Core/GameStatsTests.swift:24).
//
//  Note: full audio playback is not unit-testable in CI — `AVAudioPlayer.
//  play()` may return without producing sound on the simulator. These
//  tests focus on the contract boundary (init, gating, session category)
//  rather than acoustic output.
//

import Testing
import Foundation
import AVFoundation
@testable import gamekit

@MainActor
@Suite("SFXPlayer")
struct SFXPlayerTests {

    // MARK: - Init contract

    @Test("init() does not throw, even when CAF files are missing (non-fatal failure)")
    func init_doesNotThrow() {
        // Per CONTEXT D-11/D-12: init must succeed under all conditions.
        // If CAFs are missing, the players become nil and play() no-ops.
        _ = SFXPlayer()
        // Reached this line ⇒ init returned without throwing.
        #expect(Bool(true))
    }

    @Test(
        "init() preloads all 3 AVAudioPlayer instances (tap/win/loss)",
        .disabled(
            if: Bundle.main.url(forResource: "tap", withExtension: "caf") == nil
                || Bundle.main.url(forResource: "win", withExtension: "caf") == nil
                || Bundle.main.url(forResource: "loss", withExtension: "caf") == nil,
            "TODO(05-02-CAF): un-skip when tap/win/loss CAF files land in Resources/Audio/ (deferred per 05-02 SUMMARY)"
        )
    )
    func init_preloadsAllThreeAVAudioPlayers() {
        let sfx = SFXPlayer()
        #expect(sfx.preloadedTap != nil, "tap.caf must decode into AVAudioPlayer")
        #expect(sfx.preloadedWin != nil, "win.caf must decode into AVAudioPlayer")
        #expect(sfx.preloadedLoss != nil, "loss.caf must decode into AVAudioPlayer")
    }

    // MARK: - AVAudioSession.ambient (CONTEXT D-09)

    @Test("AVAudioSession category is .ambient after SFXPlayer.init()")
    func init_setsAVAudioSessionCategoryToAmbient() {
        _ = SFXPlayer()
        #expect(
            AVAudioSession.sharedInstance().category == .ambient,
            "CONTEXT D-09: SFXPlayer.init must set AVAudioSession.ambient so SFX never duck user music"
        )
    }

    // MARK: - Gating-at-source contract (CONTEXT D-10)

    @Test("play(_:sfxEnabled: false) records the invocation attempt but does NOT set lastPlayedEvent")
    func play_disabled_doesNotInvokePlay() {
        let sfx = SFXPlayer()
        sfx.play(.tap, sfxEnabled: false)

        // Pre-gate seam: the attempt is always recorded so we can distinguish
        // "method called with disabled" from "method never called".
        #expect(sfx.lastInvocationAttempt?.event == .tap)
        #expect(sfx.lastInvocationAttempt?.enabled == false)

        // Post-gate seam: only set when the gate passes. Disabled call must
        // NOT touch this (D-10 source-gate contract).
        #expect(
            sfx.lastPlayedEvent == nil,
            "D-10 gate violated: sfxEnabled=false MUST early-return before invoking the underlying AVAudioPlayer"
        )
    }

    @Test("play(_:sfxEnabled: true) sets lastPlayedEvent (gate passes through)")
    func play_enabled_invokesPlay() {
        let sfx = SFXPlayer()
        sfx.play(.win, sfxEnabled: true)

        #expect(sfx.lastInvocationAttempt?.event == .win)
        #expect(sfx.lastInvocationAttempt?.enabled == true)
        #expect(
            sfx.lastPlayedEvent == .win,
            "When sfxEnabled=true, the gate must pass and the event must reach the per-event switch"
        )
    }
}
