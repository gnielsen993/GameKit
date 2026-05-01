//
//  MinesweeperViewModel+Timer.swift
//  gamekit
//
//  Timer / scenePhase pause-resume math extracted from MinesweeperViewModel
//  on 2026-05-01 to keep the host file under the §8.1 split-smell zone (was
//  472 LOC, now ~340 after this + Persistence + InteractionMode extensions).
//
//  Owns the timer arithmetic only. Stored properties (`timerAnchor`,
//  `pausedElapsed`) live in the main VM file because Swift extensions
//  cannot declare stored properties on a class. Cross-file callers reach
//  these methods at `internal` access (default) — same module.
//
//  D-05/D-06 invariants preserved:
//    - `timerAnchor` nil = paused/idle/terminal
//    - `pausedElapsed` is the accumulator that survives backgrounding
//    - System-clock-rollback safe (`max(0, ...)` clamp)
//    - `freezeTimer()` is the only path that finalizes `pausedElapsed`
//      from a live anchor; called by terminal-state branches in
//      `reveal(at:)` per the locked ordering gameState → phase →
//      freezeTimer → recordTerminalState
//

import Foundation

extension MinesweeperViewModel {
    /// Wall-clock elapsed at the moment of access. Used by the end-state
    /// card after the timer freezes (D-08). System-clock-rollback safe:
    /// negative deltas clamp to 0 (RESEARCH §Pattern 2).
    var frozenElapsed: TimeInterval {
        guard let anchor = timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, clock().timeIntervalSince(anchor))
    }

    /// scenePhase .background path (D-06). No-op outside .playing.
    func pause() {
        guard case .playing = gameState, let anchor = timerAnchor else { return }
        pausedElapsed += max(0, clock().timeIntervalSince(anchor))
        timerAnchor = nil
    }

    /// scenePhase .active path (D-06). No-op outside .playing.
    /// Idempotent — calling twice without a pause in between is a no-op.
    func resume() {
        guard case .playing = gameState, timerAnchor == nil else { return }
        timerAnchor = clock()
    }

    /// Finalize `pausedElapsed` from a live `timerAnchor`. Called only by
    /// terminal-state branches (`.lost` / `.won`) in `reveal(at:)`. Internal
    /// access (was private when colocated with reveal); module-private is
    /// the tightest scope Swift allows once the call site lives in another
    /// file (same module). Production call sites: 2 — both in the main VM
    /// file's `reveal(at:)`.
    func freezeTimer() {
        if let anchor = timerAnchor {
            pausedElapsed += max(0, clock().timeIntervalSince(anchor))
        }
        timerAnchor = nil
    }
}
