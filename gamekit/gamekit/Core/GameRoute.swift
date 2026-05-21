//
//  GameRoute.swift
//  gamekit
//
//  Cross-game NavigationStack routing key. Each playable game ships a case
//  here; HomeView's `.navigationDestination(for: GameRoute.self)` switch
//  resolves the case to its game view. Keeps per-game routing centralized
//  so adding game #N does not require new @State Bool flags or new
//  navigationDestination modifiers in HomeView.
//
//  Each case carries an optional mode/difficulty (associated value) so the
//  Home drawer's mode chips can deep-link straight into a specific mode.
//  Passing `nil` falls back to the VM's last-played persistence (see each
//  VM init's `mode/difficulty ?? UserDefaults ?? sensible default` chain).
//
//  Hashable + Sendable so the case + payload can ride a `[GameRoute]` path
//  on iOS 17+ NavigationStack. All associated value types are raw-string
//  enums that are already Hashable + Sendable.
//
//  Foundation-only — no SwiftUI imports. Routing destinations are resolved
//  in HomeView (the screen that owns the NavigationStack), not here.
//

import Foundation

enum GameRoute: Hashable, Sendable {
    case minesweeper(MinesweeperDifficulty?)
    case merge(MergeMode?)
    case nonogram(NonogramDifficulty?, NonogramGameMode?)
    case sudoku(SudokuDifficulty?, SudokuGameMode?)
}
