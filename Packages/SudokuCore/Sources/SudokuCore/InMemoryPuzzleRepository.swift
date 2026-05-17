//
//  InMemoryPuzzleRepository.swift
//  SudokuCore (GameKit vendor — replaces SQLitePuzzleRepository)
//
//  GameKit does not need persistent puzzle storage; runtime serves
//  puzzles from a bundled JSON pack via SudokuPuzzlePool (app target).
//  This in-memory repo exists so the CLI tool's GeneratePuzzleUseCase
//  has something to call .save(_:) against during offline pack
//  generation. Dedup-by-hash is enforced; the other PuzzleRepository
//  methods throw `notSupported` because the CLI doesn't use them.
//

import Foundation

public actor InMemoryPuzzleRepository: PuzzleRepository {
    public enum InMemoryError: Error, Equatable {
        case notSupported
    }

    private var puzzlesByHash: [String: Puzzle] = [:]

    public init() {}

    // MARK: - Actor-specific helpers (NOT on PuzzleRepository protocol)
    // The next three methods are conveniences for the CLI tool's pack-
    // generation workflow. They are intentionally not part of
    // `PuzzleRepository` — call them on a concrete `InMemoryPuzzleRepository`
    // only. Do not promote to the protocol without updating all conformers.

    /// All saved puzzles, in insertion order is NOT guaranteed — the
    /// caller should sort if order matters.
    public func allPuzzles() -> [Puzzle] {
        Array(puzzlesByHash.values)
    }

    public func count(for difficulty: Difficulty) -> Int {
        puzzlesByHash.values.filter { $0.difficulty == difficulty }.count
    }

    public func contains(hash: String) -> Bool {
        puzzlesByHash[hash] != nil
    }

    // MARK: - PuzzleRepository conformance

    public func save(_ puzzle: Puzzle) async throws {
        if puzzlesByHash[puzzle.hash] != nil {
            throw SudokuCoreError.hashAlreadyExists
        }
        puzzlesByHash[puzzle.hash] = puzzle
    }

    public func nextPuzzle(
        excluding statuses: Set<PuzzleStatus>,
        difficulty: Difficulty?
    ) async throws -> Puzzle? {
        throw InMemoryError.notSupported
    }

    public func markStatus(_ status: PuzzleStatus, for puzzleHash: String) async throws {
        throw InMemoryError.notSupported
    }

    public func updateProgress(
        for puzzleHash: String,
        elapsedSec: Int,
        mistakes: Int,
        hintsUsed: Int,
        score: Int,
        boardString: String,
        notesJSON: String?
    ) async throws {
        throw InMemoryError.notSupported
    }

    public func fetchInProgress() async throws -> (Puzzle, PuzzleProgress)? {
        throw InMemoryError.notSupported
    }

    public func inventoryCounts() async throws -> [Difficulty: Int] {
        var counts: [Difficulty: Int] = [:]
        for d in Difficulty.allCases {
            counts[d] = puzzlesByHash.values.filter { $0.difficulty == d }.count
        }
        return counts
    }

    public func clearLibrary() async throws {
        puzzlesByHash.removeAll()
    }
}
