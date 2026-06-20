//
//  SudokuViewModel+SaveState.swift
//  gamekit
//
//  Resume / persistence I/O extracted from SudokuViewModel to keep the host
//  file under the §8.5 line cap. Mirrors NonogramViewModel+SaveState.swift.
//
//  Stored properties live on the main VM (extensions cannot declare stored
//  properties). The properties this extension writes are plain `var` (not
//  private(set)) so the cross-file writes compile — same convention the
//  Nonogram save-state extension documents.
//

import Foundation

extension SudokuViewModel {

    /// Called from SudokuGameView when the player taps Continue on the resume prompt.
    func restoreState(_ saved: SudokuSaveState) {
        guard let cleanBoard = SudokuBoard(givens: saved.givens, solution: saved.solution) else {
            // Malformed save — discard and load fresh.
            discardSaveAndLoadNew()
            return
        }
        // Overlay saved non-default cells onto the clean board.
        var restored = cleanBoard
        for (idx, savedCell) in saved.cells.enumerated() where !savedCell.isGiven {
            let row = idx / 9, col = idx % 9
            if case .empty(let notes) = savedCell, notes.isEmpty { continue }
            restored = restored.setting(savedCell, atRow: row, col: col)
        }
        currentPuzzle = SudokuPuzzleEntry(
            id: saved.puzzleId,
            givens: saved.givens,
            solution: saved.solution,
            givenCount: saved.givenCount
        )
        self.board = restored
        mistakes = saved.mistakes
        lockedCells = Set(saved.lockedCellIndices)
        pausedElapsed = saved.elapsedSeconds
        state = .playing
        timerAnchor = clock()
        pendingSaveState = nil
    }

    /// Called from SudokuGameView when the player taps New Puzzle on the resume prompt.
    func discardSaveAndLoadNew() {
        clearSavedState()
        Task { @MainActor in await loadFreshPuzzle() }
    }

    func checkAndLoadOrRestoreState() {
        let key = SudokuSaveState.key(difficulty: difficulty, gameMode: gameMode)
        if let data = userDefaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(SudokuSaveState.self, from: data) {
            pendingSaveState = saved
            // Pre-warm the pool while the alert is on screen so "New Puzzle"
            // → instant board with no loading flash when the user decides.
            Task { try? await pool.load() }
        } else {
            Task { @MainActor in await loadFreshPuzzle() }
        }
    }

    func saveCurrentState() {
        guard state == .playing, let board, let puzzle = currentPuzzle else { return }
        let snapshot = SudokuSaveState(
            puzzleId: puzzle.id,
            givens: puzzle.givens,
            solution: puzzle.solution,
            givenCount: puzzle.givenCount,
            cells: board.cells,
            elapsedSeconds: elapsedSeconds,
            mistakes: mistakes,
            lockedCellIndices: Array(lockedCells),
            gameMode: gameMode.rawValue,
            savedAt: Date.now
        )
        let key = SudokuSaveState.key(difficulty: difficulty, gameMode: gameMode)
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: key)
        }
    }

    func clearSavedState() {
        userDefaults.removeObject(forKey: SudokuSaveState.key(difficulty: difficulty, gameMode: gameMode))
        pendingSaveState = nil
    }
}
