//
//  SnakeGameViewTests.swift
//  gamekitTests
//
//  Compile-time contract tests for the SnakeGameView chrome types introduced
//  in Plan 17-05. Each test references a type that does not exist until the
//  GREEN implementation commit creates the corresponding source file. A
//  compile error here is the intended RED-phase failure.
//
//  TDD gate (Plan 17-05 Task 1):
//    RED  — this file added; build fails (types undefined)
//    GREEN — SnakeScoreChip.swift, SnakeGameView.swift,
//             SnakeGameView+Chrome.swift created; build succeeds.
//

import SwiftUI
import Testing
@testable import gamekit

@Suite("SnakeGameView chrome types")
@MainActor struct SnakeGameViewTests {

    /// Ensures SnakeScoreChip is declared as a View type.
    /// Compile error until SnakeScoreChip.swift is created.
    @Test("SnakeScoreChip type is declared")
    func snakeScoreChipDeclared() {
        func requiresView<V: View>(_: V.Type) {}
        requiresView(SnakeScoreChip.self)
    }

    /// Ensures SnakeDPad is declared as a View type.
    /// Compile error until SnakeGameView+Chrome.swift declares struct SnakeDPad.
    @Test("SnakeDPad type is declared")
    func snakeDPadDeclared() {
        func requiresView<V: View>(_: V.Type) {}
        requiresView(SnakeDPad.self)
    }

    /// Ensures SnakeGameView is declared as a View type.
    /// Compile error until SnakeGameView.swift is created.
    @Test("SnakeGameView type is declared")
    func snakeGameViewDeclared() {
        func requiresView<V: View>(_: V.Type) {}
        requiresView(SnakeGameView.self)
    }
}
