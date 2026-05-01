//
//  MinesweeperViewModel+Persistence.swift
//  gamekit
//
//  GameStats injection + terminal-state recording extracted from
//  MinesweeperViewModel on 2026-05-01 to keep the host file under the §8.1
//  split-smell zone.
//
//  VM stays Foundation-only (P3 invariant + ARCHITECTURE Anti-Pattern 1):
//  the SwiftData dependency lives BEHIND `GameStats?` here — we never
//  import SwiftData, never touch ModelContext directly.
//
//  Cross-file access: `recordTerminalState(outcome:)` was `private` when
//  colocated with its sole caller `reveal(at:)`. Moving it to a sibling
//  file forces `internal` access (same-module). The `try?` failure-swallow
//  contract from D-15 is preserved: persistence failure logs inside
//  GameStats via os.Logger and the gameplay UI continues to render the
//  terminal state.
//

import Foundation

extension MinesweeperViewModel {
    /// UserDefaults key per D-11 — locked at "mines.lastDifficulty".
    /// Renaming = data break for any user who already played a game.
    static var lastDifficultyKey: String { "mines.lastDifficulty" }

    /// One-shot setter called from MinesweeperGameView.body's `.task` modifier
    /// (RESEARCH Pitfall 8 — `GameStats(modelContext:)` MUST NOT live inside
    /// `body` because that constructs a new instance on every render). Second
    /// call is benign no-op — production fires this exactly once per scene
    /// lifecycle.
    func attachGameStats(_ stats: GameStats) {
        guard self.gameStats == nil else { return }
        self.gameStats = stats
    }

    /// Writes a GameRecord (and updates BestTime on win-and-faster) at terminal
    /// state. Wraps `try? gameStats?.record(...)` — failure is logged inside
    /// GameStats via os.Logger and gameplay UI continues to render the terminal
    /// state (D-15 — persistence failure must NOT block the user from seeing
    /// the win/loss overlay). MUST be called AFTER `freezeTimer()` so
    /// `frozenElapsed` holds the correct elapsed value (RESEARCH Pitfall 3).
    func recordTerminalState(outcome: GameOutcome) {
        try? gameStats?.record(
            gameKind: .minesweeper,
            difficulty: difficulty.rawValue,
            outcome: outcome == .win ? .win : .loss,
            durationSeconds: frozenElapsed
        )
    }
}
