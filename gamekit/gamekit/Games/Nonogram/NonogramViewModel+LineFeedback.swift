//
//  NonogramViewModel+LineFeedback.swift
//  gamekit
//
//  Line-completion feedback subsystem extracted from NonogramViewModel to
//  keep the host file under the §8.5 line cap. Owns the "a row/column just
//  got fully crossed off" detection plus the transient row/column flash
//  glow that pairs with the heavier haptic.
//
//  Stored properties (`lineCompletionCount`, `completedLineKeys`,
//  `flashRow`, `flashCol`) live in the main VM file — Swift extensions
//  cannot declare stored properties. They are plain `var` so this
//  cross-file extension can write them, matching the convention documented
//  on the main file's State surface. Callers reach these methods at
//  `internal` access (same module); `updateLineCompletions` is invoked
//  from `applyMutation` in the main file.
//

import Foundation

extension NonogramViewModel {

    /// Recompute the completion state for the touched row + column only —
    /// no other lines could have changed in this single-cell mutation.
    /// Bumps `lineCompletionCount` for each line that newly transitioned
    /// to fully-crossed-off; un-completing a previously-finished line
    /// drops it from the tracked set without firing a haptic.
    func updateLineCompletions(touchedRow: Int, touchedCol: Int) {
        let rowMask = rowsCrossOff
        let colMask = columnsCrossOff

        let rowKey = "r\(touchedRow)"
        let rowComplete = touchedRow >= 0 && touchedRow < rowMask.count
            && rowMask[touchedRow].allSatisfy { $0 }
        if rowComplete && !completedLineKeys.contains(rowKey) {
            completedLineKeys.insert(rowKey)
            lineCompletionCount += 1
            triggerFlashRow(touchedRow)
        } else if !rowComplete {
            completedLineKeys.remove(rowKey)
        }

        let colKey = "c\(touchedCol)"
        let colComplete = touchedCol >= 0 && touchedCol < colMask.count
            && colMask[touchedCol].allSatisfy { $0 }
        if colComplete && !completedLineKeys.contains(colKey) {
            completedLineKeys.insert(colKey)
            lineCompletionCount += 1
            triggerFlashCol(touchedCol)
        } else if !colComplete {
            completedLineKeys.remove(colKey)
        }
    }

    /// Light up `row` for ~700ms, then clear the flag. If a newer
    /// completion lands in the meantime its own trigger overrides this
    /// one, so the most-recent row's flash always wins.
    private func triggerFlashRow(_ row: Int) {
        flashRow = row
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if self.flashRow == row { self.flashRow = nil }
        }
    }

    private func triggerFlashCol(_ col: Int) {
        flashCol = col
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            if self.flashCol == col { self.flashCol = nil }
        }
    }
}
