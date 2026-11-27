//
//  SudokuViewModel+Outcome.swift
//  gamekit
//
//  Terminal-state paths moved out of SudokuViewModel.swift: game over (lives
//  exhausted), practice completion after Keep Solving, and the win. The win
//  records through `GameStats.recordReportingBest`, so whether the run set a
//  personal best is decided by the same code that writes the best time; this
//  file only keeps the answer in `lastWinRecord` for the win sheet.
//

import Foundation

extension SudokuViewModel {

    func recordGameOver() {
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .gameOver
        #if DEBUG
        // A near-win fixture game is never recorded.
        let writesStats = !isNearWinFixture
        #else
        let writesStats = true
        #endif
        if writesStats {
            try? gameStats?.record(
                gameKind: .sudoku,
                difficulty: difficulty.rawValue,
                outcome: .loss,
                durationSeconds: frozenElapsed,
                puzzleId: currentPuzzle?.id,
                assistCount: assistsUsed
            )
        }
        saveCurrentState()
    }

    func completeBoard() {
        if state == .practiceAfterLoss {
            clearSavedState()
            state = .practiceComplete
        } else {
            recordWin()
        }
    }

    func recordWin() {
        clearSavedState()
        if let anchor = timerAnchor {
            pausedElapsed += clock().timeIntervalSince(anchor)
            timerAnchor = nil
        }
        frozenElapsed = pausedElapsed
        state = .won
        winCount += 1
        #if DEBUG
        if isNearWinFixture {
            // Preview the badge without touching the player's real stats.
            lastWinRecord = RecordResult(setBestTime: assistsUsed == 0, previousBest: nil)
            return
        }
        #endif
        lastWinRecord = try? gameStats?.recordReportingBest(
            gameKind: .sudoku,
            difficulty: difficulty.rawValue,
            outcome: .win,
            durationSeconds: frozenElapsed,
            puzzleId: currentPuzzle?.id,
            assistCount: assistsUsed
        )
    }
}
