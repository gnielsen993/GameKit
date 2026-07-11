import Foundation

extension NonogramViewModel {

    func checkAndLoadOrRestoreState() {
        let key = NonogramSaveState.key(difficulty: difficulty, gameMode: gameMode)
        if let data = userDefaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(NonogramSaveState.self, from: data) {
            if isRestorable(saved) {
                pendingSaveState = saved
            } else {
                userDefaults.removeObject(forKey: key)
                pendingSaveState = nil
            }
        }
    }

    func restoreState(_ saved: NonogramSaveState) {
        guard isRestorable(saved),
              let d = NonogramDifficulty(rawValue: saved.difficulty),
              let m = NonogramGameMode(rawValue: saved.gameMode) else {
            discardSaveAndLoadNew()
            return
        }
        let puzzle = NonogramPuzzle(id: saved.puzzleId, title: saved.puzzleTitle, grid: saved.puzzleGrid)
        let restoredBoard = NonogramBoard(size: saved.size, cells: saved.cells)
        resetSessionState()
        difficulty = d
        gameMode = m
        currentPuzzle = puzzle
        board = restoredBoard
        livesRemaining = saved.livesRemaining
        lockedCells = Set(saved.lockedCellIndices)
        pausedElapsed = saved.elapsedSeconds
        state = .playing
        timerAnchor = clock()
        pendingSaveState = nil
        refreshCrossOff()
        // Defensive: an in-progress puzzle is by definition seen. Saves
        // written before the mark-on-first-move change were already
        // marked at pick time; this keeps the invariant either way.
        NonogramPicker.markSeen(puzzleId: puzzle.id, difficulty: d, userDefaults: userDefaults)
        prefetchNextPuzzleIfNeeded()
    }

    func discardSaveAndLoadNew() {
        clearSavedState()
        // Init's instant pick usually filled the slot already; when the
        // curated pool is exhausted this kicks off async generation.
        ensurePuzzleLoaded()
    }

    func saveCurrentState() {
        guard state == .playing, let puzzle = currentPuzzle else { return }
        let snapshot = NonogramSaveState(
            puzzleId: puzzle.id,
            puzzleGrid: puzzle.grid,
            puzzleTitle: puzzle.title,
            cells: board.cells,
            size: board.size,
            difficulty: difficulty.rawValue,
            gameMode: gameMode.rawValue,
            livesRemaining: livesRemaining,
            lockedCellIndices: Array(lockedCells),
            elapsedSeconds: elapsedSeconds,
            savedAt: Date.now
        )
        let key = NonogramSaveState.key(difficulty: difficulty, gameMode: gameMode)
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: key)
        }
    }

    func clearSavedState() {
        userDefaults.removeObject(
            forKey: NonogramSaveState.key(difficulty: difficulty, gameMode: gameMode)
        )
        pendingSaveState = nil
    }

    private func isRestorable(_ saved: NonogramSaveState) -> Bool {
        guard let d = NonogramDifficulty(rawValue: saved.difficulty),
              NonogramGameMode(rawValue: saved.gameMode) != nil,
              saved.size == d.size,
              saved.cells.count == saved.size * saved.size,
              saved.livesRemaining > 0,
              saved.lockedCellIndices.allSatisfy({ $0 >= 0 && $0 < saved.cells.count }) else {
            return false
        }

        let puzzle = NonogramPuzzle(id: saved.puzzleId, title: saved.puzzleTitle, grid: saved.puzzleGrid)
        return puzzle.isValid(for: saved.size)
    }
}
