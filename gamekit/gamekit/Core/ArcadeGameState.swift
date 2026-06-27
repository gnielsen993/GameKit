//
//  ArcadeGameState.swift
//  gamekit
//
//  Shared lifecycle enum for endless arcade games (Stack, Snake). Both VMs
//  own a `private(set) var state: ArcadeGameState`. No persistence needed —
//  the live state resets cleanly on restart.
//
//  Foundation-only. Mirrors MergeGameState discipline at
//  MergeGameState.swift:15.
//

import Foundation

nonisolated enum ArcadeGameState: Equatable, Hashable, Sendable {
    /// Tap-to-start affordance shown; loop NOT running.
    case idle
    /// Frame loop active; input accepted.
    case running
    /// scenePhase backgrounded; loop suspended, state preserved.
    case paused
    /// Terminal; score frozen; restart available.
    case gameOver
}
