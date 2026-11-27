//
//  SudokuViewModel+DebugFixture.swift
//  gamekit
//
//  DEBUG-only. Turns the loaded puzzle into a near-win game: every cell
//  filled except three that take the same digit, a realistic clock, and the
//  first of the three selected. Fixture games never write stats and never
//  touch the player's saved game (see recordWin / recordGameOver and
//  SudokuViewModel+SaveState.swift). Never compiled into Release.
//

#if DEBUG

import Foundation
import os

extension SudokuViewModel {

    /// True when the current puzzle was produced by `applyNearWinFixture()`.
    var isNearWinFixture: Bool {
        SudokuNearWinFixture.isFixture(puzzleID: currentPuzzle?.id)
    }

    /// Fill the loaded puzzle to three empty cells. A no-op (logged) when
    /// there is no puzzle or no digit has three open cells.
    func applyNearWinFixture() {
        guard let puzzle = currentPuzzle else {
            AppLog.puzzles.warning("near-win fixture skipped: no puzzle loaded")
            return
        }
        let open = SudokuNearWinFixture.emptyIndices(
            givens: puzzle.givens,
            solution: puzzle.solution
        )
        guard !open.isEmpty,
              var filled = SudokuBoard(givens: puzzle.givens, solution: puzzle.solution) else {
            AppLog.puzzles.warning("near-win fixture skipped: no digit with three open cells")
            return
        }

        let openSet = Set(open)
        for idx in 0..<81 where !filled.cells[idx].isGiven && !openSet.contains(idx) {
            let row = idx / 9, col = idx % 9
            filled = filled.setting(
                .user(filled.solutionDigit(atRow: row, col: col)),
                atRow: row, col: col
            )
        }

        let id = SudokuNearWinFixture.isFixture(puzzleID: puzzle.id)
            ? puzzle.id
            : puzzle.id + SudokuNearWinFixture.puzzleIDSuffix
        currentPuzzle = SudokuPuzzleEntry(
            id: id,
            givens: puzzle.givens,
            solution: puzzle.solution,
            givenCount: puzzle.givenCount
        )
        board = filled
        lockedCells = Set((0..<81).filter { idx in
            gameMode == .lives ? !openSet.contains(idx) : filled.cells[idx].isGiven
        })
        mistakes = 0
        assistsUsed = 0
        frozenElapsed = 0
        pausedElapsed = SudokuNearWinFixture.previewElapsedSeconds
        state = .playing
        // Set directly: the normal first-move path (startTimer) zeroes the clock.
        timerAnchor = clock()
        if let first = open.first {
            select(row: first / 9, col: first % 9)
        }
    }

    /// Apply the fixture when the launch arguments ask for it.
    func applyNearWinFixtureIfLaunched(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard arguments.contains(SudokuNearWinFixture.launchArgument) else { return }
        applyNearWinFixture()
    }
}

#endif
