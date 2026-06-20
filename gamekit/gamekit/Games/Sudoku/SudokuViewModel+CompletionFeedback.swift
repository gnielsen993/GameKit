//
//  SudokuViewModel+CompletionFeedback.swift
//  gamekit
//
//  Group-completion feedback (row / column / box glow + digit-complete
//  pulse) extracted from SudokuViewModel to keep the host file under the
//  §8.5 line cap. Mirrors NonogramViewModel+LineFeedback.swift.
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
        var newGlow = Set<Int>()

        // Row complete?
        if (0..<9).allSatisfy({ board.cell(row: row, col: $0).value != nil }) {
            for c in 0..<9 { newGlow.insert(row * 9 + c) }
        }
        // Column complete?
        if (0..<9).allSatisfy({ board.cell(row: $0, col: col).value != nil }) {
            for r in 0..<9 { newGlow.insert(r * 9 + col) }
        }
        // Box complete?
        let br = (row / 3) * 3, bc = (col / 3) * 3
        if (0..<3).allSatisfy({ dr in (0..<3).allSatisfy({
            dc in board.cell(row: br + dr, col: bc + dc).value != nil
        }) }) {
            for dr in 0..<3 { for dc in 0..<3 { newGlow.insert((br + dr) * 9 + (bc + dc)) } }
        }

        if !newGlow.isEmpty {
            completionGlowIndices = newGlow
            completionGlowCount += 1
            let snapshot = newGlow
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
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
