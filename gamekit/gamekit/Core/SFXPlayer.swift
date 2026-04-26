//
//  SFXPlayer.swift
//  gamekit
//
//  P5 (D-08/D-09/D-10/D-12): @MainActor final class wrapping AVAudioPlayer
//  for tap/win/loss CAF playback. Three preloaded players, AVAudioSession.
//  ambient category (does not duck user music). Gated at the source on
//  `sfxEnabled` (D-10).
//
//  Constructed at GameKitApp.init() AFTER SettingsStore (CONTEXT D-12);
//  injected via custom EnvironmentKey mirroring the Plan 04 SettingsStore
//  D-29 pattern (Core/SettingsStore.swift:124-135).
//
//  Phase 5 invariants:
//    - **Gating at the source (D-10):** `sfxEnabled` is the FIRST guard.
//      Call sites pass `settingsStore.sfxEnabled` explicitly; this class
//      stays Foundation/AVFoundation/SwiftUI-only with no SettingsStore
//      coupling.
//    - **AVAudioSession.ambient (D-09):** set ONCE in init via the shared
//      session. Verified by an adversarial grep gate in Plan 05-03
//      verification — `setCategory` should appear in exactly one Swift
//      file across `gamekit/gamekit/`.
//    - **Preload via prepareToPlay() (D-08):** all 3 players construct
//      and decode at init time so first playback has zero latency.
//    - **Non-fatal failure (D-11/D-12):** missing CAF, decode error, or
//      session-category error all log via `os.Logger(category: "audio")`
//      with `privacy: .public` on system errors. Players become nil and
//      `play(...)` is a no-op for that event. Init MUST succeed even
//      when CAFs are absent — Plan 05-02 Task 3 (CAF files) is deferred,
//      and SFXPlayer must construct cleanly so GameKitApp.init() does
//      not crash on app launch.
//    - **Test seam (#if DEBUG):** `lastInvocationAttempt` (set BEFORE
//      the gate) + `lastPlayedEvent` (set AFTER the gate) make the
//      gating contract directly observable. `preloadedTap/Win/Loss`
//      expose the optional players for file-presence assertions.
//      Visible only via `@testable import gamekit`.
//
//  Threat model (Plan 05-03 register):
//    - T-05-07 (Audio session drift): `.ambient` set once in init;
//      adversarial grep confirms no other site touches `setCategory`.
//    - T-05-08 (Info Disclosure): logger only emits CAF basenames and
//      system error descriptions — no PII. `privacy: .public` matches
//      the GameStats precedent (Core/GameStats.swift:92).
//

import Foundation
import AVFoundation
import SwiftUI
import os

/// Discrete SFX cue identifiers — one preloaded `AVAudioPlayer` per case.
/// `Sendable` so it can be passed across `Task` boundaries if a future
/// game schedules audio off-MainActor (none currently do).
enum SFXEvent: Sendable {
    case tap
    case win
    case loss
}

@MainActor
final class SFXPlayer {

    // MARK: - Preloaded players (D-08)

    private let tapPlayer: AVAudioPlayer?
    private let winPlayer: AVAudioPlayer?
    private let lossPlayer: AVAudioPlayer?

    private let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "audio"
    )

    // MARK: - Init

    init() {
        // D-09: configure the shared AVAudioSession for `.ambient` so SFX
        // never duck user music. Done BEFORE preloading players because
        // `prepareToPlay()` honors the session configuration in effect at
        // call time. Failure logged as non-fatal (Logger created locally —
        // self.logger isn't usable until all stored properties are set).
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        } catch {
            Logger(subsystem: "com.lauterstar.gamekit", category: "audio")
                .error("Failed to set AVAudioSession .ambient: \(error.localizedDescription, privacy: .public)")
        }

        // D-08: preload all three players. Missing CAF = nil player +
        // logged error (non-fatal per D-11/D-12).
        self.tapPlayer  = Self.makePlayer(name: "tap")
        self.winPlayer  = Self.makePlayer(name: "win")
        self.lossPlayer = Self.makePlayer(name: "loss")
    }

    // MARK: - Player construction (private)

    /// Build one preloaded `AVAudioPlayer` from a bundled CAF. Returns
    /// `nil` if the file is missing or decode fails — the corresponding
    /// `play(...)` branch then no-ops, matching D-11/D-12 non-fatal
    /// failure semantics. Logger is constructed locally because this is
    /// a `static` method called from `init` before `self.logger` exists.
    private static func makePlayer(name: String) -> AVAudioPlayer? {
        let logger = Logger(subsystem: "com.lauterstar.gamekit", category: "audio")
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else {
            logger.error("CAF not found in bundle: \(name, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error(
                "AVAudioPlayer init failed for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Public API

    /// Play one preloaded SFX cue. Gated at the source on `sfxEnabled`
    /// per CONTEXT D-10 — call sites pass `settingsStore.sfxEnabled`
    /// explicitly. When `false`, this method early-returns BEFORE the
    /// per-event switch.
    ///
    /// Missing CAF (player is nil) is silently a no-op — the `?.play()`
    /// optional-chain returns nil without firing.
    func play(_ event: SFXEvent, sfxEnabled: Bool) {
        // Test seam: record EVERY invocation regardless of the gate so
        // tests can distinguish "called with disabled" from "never called".
        #if DEBUG
        lastInvocationAttempt = (event, sfxEnabled)
        #endif

        // D-10 source-gate: cheapest possible early-out.
        guard sfxEnabled else { return }

        // Test seam: only set when the gate passes — proves D-10 contract.
        #if DEBUG
        lastPlayedEvent = event
        #endif

        switch event {
        case .tap:  tapPlayer?.play()
        case .win:  winPlayer?.play()
        case .loss: lossPlayer?.play()
        }
    }

    // MARK: - Test seam (#if DEBUG — do NOT call from production)

    #if DEBUG
    /// Test-only: every call to `play(_:sfxEnabled:)` records the (event,
    /// enabled) pair here BEFORE the D-10 gate, so tests can prove the
    /// method was invoked but the gate caught it.
    internal var lastInvocationAttempt: (event: SFXEvent, enabled: Bool)?

    /// Test-only: set ONLY after the D-10 gate passes. A disabled call
    /// must NOT touch this — that is the gating-at-source contract.
    internal var lastPlayedEvent: SFXEvent?

    /// Test-only: expose the preloaded players for file-presence
    /// assertions. Tests skip the assertion when CAF files are missing
    /// (Plan 05-02 Task 3 deferred — see 05-02 SUMMARY).
    internal var preloadedTap:  AVAudioPlayer? { tapPlayer }
    internal var preloadedWin:  AVAudioPlayer? { winPlayer }
    internal var preloadedLoss: AVAudioPlayer? { lossPlayer }
    #endif
}

// MARK: - EnvironmentKey injection (mirror Core/SettingsStore.swift:124-135)

private struct SFXPlayerKey: EnvironmentKey {
    @MainActor static let defaultValue = SFXPlayer()
}

extension EnvironmentValues {
    var sfxPlayer: SFXPlayer {
        get { self[SFXPlayerKey.self] }
        set { self[SFXPlayerKey.self] = newValue }
    }
}
