//
//  GameOverDetectorTests.swift
//  gamekitTests
//
//  Swift Testing coverage for GameOverDetector. Mirrors WinDetectorTests
//  discipline at gamekitTests/Engine/WinDetectorTests.swift:17.
//

import Testing
import Foundation
@testable import gamekit

@Suite("GameOverDetector")
nonisolated struct GameOverDetectorTests {

    private static func board(_ values: [[Int]]) -> MergeBoard {
        precondition(values.count == MergeBoard.size)
        var cells: [MergeTile?] = []
        for row in values {
            precondition(row.count == MergeBoard.size)
            for v in row {
                cells.append(v == 0 ? nil : MergeTile(value: v))
            }
        }
        return MergeBoard(cells: cells)
    }

    @Test
    func emptyBoard_notGameOver() {
        #expect(GameOverDetector.isGameOver(.empty) == false)
    }

    @Test
    func boardWithEmptyCell_notGameOver() {
        let b = Self.board([
            [2, 4, 2, 4],
            [4, 2, 4, 2],
            [2, 4, 2, 4],
            [4, 2, 4, 0],     // one empty cell
        ])
        #expect(GameOverDetector.isGameOver(b) == false)
    }

    @Test
    func fullBoardNoMergeable_isGameOver() {
        let b = Self.board([
            [2, 4, 2, 4],
            [4, 2, 4, 2],
            [2, 4, 2, 4],
            [4, 2, 4, 2],
        ])
        #expect(GameOverDetector.isGameOver(b) == true)
    }

    @Test
    func fullBoardWithAdjacentPair_notGameOver() {
        // Two adjacent 2s in the bottom-right — still a legal move.
        let b = Self.board([
            [2, 4, 2, 4],
            [4, 2, 4, 2],
            [2, 4, 2, 4],
            [4, 2, 2, 4],
        ])
        #expect(GameOverDetector.isGameOver(b) == false)
    }

    @Test
    func hasReached2048_falseOnEmptyBoard() {
        #expect(GameOverDetector.hasReached2048(.empty) == false)
    }

    @Test
    func hasReached2048_trueWhen2048Present() {
        let b = Self.board([
            [2048, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(GameOverDetector.hasReached2048(b) == true)
    }

    @Test
    func hasReached2048_trueAboveTarget() {
        // Continuation past 2048: a 4096 also satisfies the predicate.
        let b = Self.board([
            [4096, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(GameOverDetector.hasReached2048(b) == true)
    }

    @Test
    func hasReached2048_falseBelowTarget() {
        let b = Self.board([
            [1024, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(GameOverDetector.hasReached2048(b) == false)
    }
}
