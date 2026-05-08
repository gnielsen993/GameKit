//
//  NonogramViewModel.swift
//  gamekit
//
//  @Observable @MainActor orchestrator for the Nonogram screen. Currently
//  in GALLERY MODE — every puzzle is rendered pre-completed so reviewers
//  can eyeball every shipped grid before locking in the seed set. Once
//  the gallery is greenlit, the play-mode follow-up phase swaps `state =
//  .gallery` for `.idle` / `.playing` and adds the cell-tap mutation
//  paths.
//
//  Foundation-only — no SwiftUI / SwiftData / Combine, mirroring the
//  Minesweeper + Merge VM discipline (CLAUDE §1 lightweight MVVM).
//

import Foundation

@Observable @MainActor
final class NonogramViewModel {

    // MARK: - State surface

    private(set) var difficulty: NonogramDifficulty
    private(set) var puzzleIndex: Int = 0
    private(set) var board: NonogramBoard
    private(set) var state: NonogramGameState = .gallery
    private(set) var interactionMode: NonogramInteractionMode = .place

    // MARK: - Derived

    /// Puzzle list for the active difficulty. Empty if the bundle file is
    /// missing or all entries failed validation.
    var puzzles: [NonogramPuzzle] {
        NonogramLibrary.puzzles(for: difficulty)
    }

    var currentPuzzle: NonogramPuzzle? {
        let list = puzzles
        guard puzzleIndex >= 0, puzzleIndex < list.count else { return nil }
        return list[puzzleIndex]
    }

    /// "3 / 12" style counter for the header.
    var positionLabel: String {
        let total = puzzles.count
        guard total > 0 else { return "0 / 0" }
        return "\(puzzleIndex + 1) / \(total)"
    }

    var rowHints: [[Int]] {
        guard let puzzle = currentPuzzle else { return [] }
        return NonogramHints.rows(for: puzzle, size: difficulty.size)
    }

    var columnHints: [[Int]] {
        guard let puzzle = currentPuzzle else { return [] }
        return NonogramHints.columns(for: puzzle, size: difficulty.size)
    }

    // MARK: - Init

    init(difficulty: NonogramDifficulty = .small) {
        self.difficulty = difficulty
        let firstPuzzle = NonogramLibrary.puzzles(for: difficulty).first
        if let puzzle = firstPuzzle {
            self.board = .solved(puzzle: puzzle, size: difficulty.size)
        } else {
            self.board = .empty(size: difficulty.size)
        }
    }

    // MARK: - Gallery navigation

    func next() {
        let total = puzzles.count
        guard total > 0 else { return }
        puzzleIndex = (puzzleIndex + 1) % total
        refreshBoardForCurrentPuzzle()
    }

    func previous() {
        let total = puzzles.count
        guard total > 0 else { return }
        puzzleIndex = (puzzleIndex - 1 + total) % total
        refreshBoardForCurrentPuzzle()
    }

    func setDifficulty(_ d: NonogramDifficulty) {
        guard d != difficulty else { return }
        difficulty = d
        puzzleIndex = 0
        refreshBoardForCurrentPuzzle()
    }

    // MARK: - Reserved for play mode

    func setInteractionMode(_ mode: NonogramInteractionMode) {
        interactionMode = mode
    }

    // MARK: - Private

    private func refreshBoardForCurrentPuzzle() {
        if let puzzle = currentPuzzle {
            board = .solved(puzzle: puzzle, size: difficulty.size)
        } else {
            board = .empty(size: difficulty.size)
        }
    }
}
