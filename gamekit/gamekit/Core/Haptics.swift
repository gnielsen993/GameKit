//
//  Haptics.swift
//  gamekit
//
//  P5 (D-07/D-10/D-11): @MainActor enum wrapping CHHapticEngine for AHAP
//  file playback. A single shared engine is lazy-loaded on the first
//  enabled `playAHAP(...)` call and re-loaded if the system resets it
//  (Apple's CHHapticEngine documents reset/stoppedHandler callbacks fire
//  on audio-route change, app backgrounding, etc.).
//
//  Phase 5 invariants:
//    - **Gating at the source (D-10):** `hapticsEnabled` is the FIRST guard.
//      If false, this method returns BEFORE touching the lazy engine — call
//      sites pass `settingsStore.hapticsEnabled` explicitly so this file
//      stays Foundation/CoreHaptics-only with no SettingsStore coupling.
//    - **Non-fatal failure (D-11):** AHAP file missing, JSON malformed, or
//      CHHapticEngine init failing all log via `os.Logger(subsystem:
//      "com.lauterstar.gamekit", category: "haptics")` and silently no-op.
//      Matches the GameStats logger precedent (Core/GameStats.swift:47-50)
//      with `privacy: .public` on system-error descriptions.
//    - **Single shared engine (D-11):** lazy via `ensureEngine()`. The
//      engine's `resetHandler` and `stoppedHandler` clear the cached
//      reference so the next call re-initializes cleanly.
//    - **Hardware capability gate:** `CHHapticEngine.capabilitiesForHardware
//      ().supportsHaptics` silently no-ops on devices/simulators without
//      haptic hardware (CHHapticEngine docs note Simulator is a no-op).
//    - **Test seam (#if DEBUG):** `resetForTesting()` and
//      `hasInitializedEngineForTesting` are visible only via `@testable
//      import gamekit` — production callers see only `playAHAP(named:
//      hapticsEnabled:)`.
//
//  Threat model (Plan 05-03 register):
//    - T-05-08 (Info Disclosure): logger only emits the AHAP file basename
//      and system-error descriptions — no PII. `privacy: .public` matches
//      the GameStats precedent (Core/GameStats.swift:92).
//    - T-05-09 (DoS): single shared engine bounded by user game cadence
//      (1 win/loss per game); no rate-limiting needed.
//    - T-05-10 (Privilege): `CHHapticEngine.capabilitiesForHardware` is
//      the hardware gate; iOS-Settings-level haptic mute is honored at
//      the OS layer automatically.
//

import Foundation
import CoreHaptics
import os

@MainActor
enum Haptics {

    // MARK: - Private state

    private static var engine: CHHapticEngine?

    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "haptics"
    )

    // MARK: - Public API

    /// Play a bundled `.ahap` haptic pattern. Gated at the source on
    /// `hapticsEnabled` (per CONTEXT D-10). Failure is non-fatal — logs and
    /// returns silently per CONTEXT D-11.
    ///
    /// - Parameters:
    ///   - name: AHAP file basename (without extension), e.g. `"win"` /
    ///     `"loss"`.
    ///   - hapticsEnabled: pass `settingsStore.hapticsEnabled` from the
    ///     call site. When `false`, this method returns immediately
    ///     BEFORE constructing the lazy engine.
    static func playAHAP(named name: String, hapticsEnabled: Bool) {
        // 1. D-10 source-gate: cheapest possible early-out, before any
        //    framework I/O or engine construction. Tested via
        //    HapticsTests.playAHAP_disabled_doesNotInitializeEngine.
        guard hapticsEnabled else { return }

        // 2. Hardware gate. Simulator + iPad-without-Taptic-Engine = no-op.
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        // 3. File presence — non-fatal log per D-11 if missing.
        guard let url = Bundle.main.url(forResource: name, withExtension: "ahap") else {
            logger.error("AHAP not found in bundle: \(name, privacy: .public)")
            return
        }

        do {
            try ensureEngine()
            let pattern = try CHHapticPattern(contentsOf: url)
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            logger.error(
                "AHAP playback failed for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            // Drop the cached engine so the next call gets a fresh one.
            engine = nil
        }
    }

    // MARK: - Private helpers

    /// Lazy-init the shared engine on first use. Wires reset/stopped
    /// handlers so a system-triggered reset clears the cached reference.
    private static func ensureEngine() throws {
        if engine != nil { return }
        let newEngine = try CHHapticEngine()
        newEngine.resetHandler = { Self.engine = nil }
        newEngine.stoppedHandler = { _ in Self.engine = nil }
        try newEngine.start()
        engine = newEngine
    }

    // MARK: - Test seam (#if DEBUG — do NOT call from production)

    #if DEBUG
    /// Test-only: clears the cached engine reference so each test starts
    /// from a known state. Visible only via `@testable import gamekit`.
    internal static func resetForTesting() {
        engine = nil
    }

    /// Test-only: reports whether the lazy engine has been instantiated.
    /// Used by `HapticsTests.playAHAP_disabled_doesNotInitializeEngine`
    /// to prove the D-10 source-gate fires BEFORE engine construction.
    internal static var hasInitializedEngineForTesting: Bool { engine != nil }
    #endif
}
