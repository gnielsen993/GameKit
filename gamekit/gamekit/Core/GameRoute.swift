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
//  Hashable + Equatable so it can ride a `path: [GameRoute]` /
//  `NavigationPath` binding on iOS 17+ NavigationStack.
//
//  Foundation-only — no SwiftUI imports. Routing destinations are resolved
//  in HomeView (the screen that owns the NavigationStack), not here.
//

import Foundation

enum GameRoute: Hashable, Sendable {
    case minesweeper
    case merge
}
