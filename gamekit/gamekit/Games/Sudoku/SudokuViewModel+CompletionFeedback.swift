//
//  SudokuViewModel+CompletionFeedback.swift
//  gamekit
//
//  Group-completion feedback (row / column / box glow + digit-complete
//  pulse) extracted from SudokuViewModel to keep the host file under the
//  §8.5 line cap. Mirrors NonogramViewModel+LineFeedback.swift.
//
//  Completion means filled AND correct (D-18): see SudokuCompletionWave.
//
//  The feedback counters it writes (`completionGlowIndices`,
//  `completionGlowCount`, `numberCompleteCount`, `justCompletedDigit`)
//  live on the main VM as plain `var` so these cross-file writes compile.
//

import Foundation

extension SudokuViewModel {

    /// Fire the completion glow + digit-complete pulse for a placement.
    /// Called from the commit path after a correct value lands.
    func fireCompletionEffects(row: Int, col: Int, value: Int, board: SudokuBoard) {
        // Only a full AND correct row / column / box counts (D-18).
        let newGlow = SudokuCompletionWave.correctCompletedCells(board: board, row: row, col: col)

        if !newGlow.isEmpty {
            completionGlowIndices = newGlow
            completionGlowCount += 1
            let snapshot = newGlow
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(SudokuCompletionWave.clearDelayMilliseconds))
                if self.completionGlowIndices == snapshot {
                    self.completionGlowIndices = []
                }
            }
        }

        // Number fully placed?
        let placed = board.cells.filter { $0.value == value }.count
        if placed == 9 {
            numberCompleteCount += 1
            justCompletedDigit = value
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                if self.justCompletedDigit == value {
                    self.justCompletedDigit = nil
                }
            }
        }
    }
}
