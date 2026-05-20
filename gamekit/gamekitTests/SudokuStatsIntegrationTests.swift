//
//  SudokuStatsIntegrationTests.swift
//  gamekitTests
//
//  Integration tests for Phase 16 — verifies GameStats.record(gameKind:.sudoku, ...)
//  produces correct GameRecord rows, BestTime is updated only on faster wins,
//  and the new GameStats.wonPuzzleIDs(gameKind:difficulty:) read path returns
//  the right IDs.
//

import XCTest
import SwiftData
@testable import gamekit

@MainActor
final class SudokuStatsIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var stats: GameStats!

    override func setUp() async throws {
        let schema = Schema([GameRecord.self, BestTime.self, BestScore.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        stats = GameStats(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        stats = nil
        container = nil
    }

    func test_recordWin_createsGameRecordAndBestTime() throws {
        try stats.record(
            gameKind: .sudoku,
            difficulty: SudokuDifficulty.easy.rawValue,
            outcome: .win,
            durationSeconds: 120,
            puzzleId: "puzzle-1"
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.gameKindRaw, "sudoku")
        XCTAssertEqual(records.first?.difficultyRaw, "easy")
        XCTAssertEqual(records.first?.outcomeRaw, "win")
        XCTAssertEqual(records.first?.puzzleIdRaw, "puzzle-1")

        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 1)
        XCTAssertEqual(bests.first?.seconds, 120)
    }

    func test_recordLoss_doesNotUpdateBestTime() throws {
        try stats.record(
            gameKind: .sudoku,
            difficulty: SudokuDifficulty.hard.rawValue,
            outcome: .loss,
            durationSeconds: 300,
            puzzleId: "puzzle-2"
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        XCTAssertEqual(records.count, 1)
        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 0)
    }

    func test_fasterWin_updatesBestTime_slowerWin_doesNot() throws {
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 200, puzzleId: "p1")
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 150, puzzleId: "p2")
        try stats.record(gameKind: .sudoku, difficulty: "medium", outcome: .win, durationSeconds: 175, puzzleId: "p3")

        let bests = try container.mainContext.fetch(FetchDescriptor<BestTime>())
        XCTAssertEqual(bests.count, 1)
        XCTAssertEqual(bests.first?.seconds, 150)
    }

    func test_wonPuzzleIDs_returnsOnlyWonRecords_andOnlyForRequestedDifficulty() throws {
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 60, puzzleId: "e1")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 70, puzzleId: "e2")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .loss, durationSeconds: 80, puzzleId: "e3")
        try stats.record(gameKind: .sudoku, difficulty: "hard", outcome: .win, durationSeconds: 200, puzzleId: "h1")

        let easyIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "easy")
        XCTAssertEqual(easyIDs, ["e1", "e2"])

        let hardIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "hard")
        XCTAssertEqual(hardIDs, ["h1"])

        let extremeIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "extreme")
        XCTAssertEqual(extremeIDs, [])
    }

    func test_wonPuzzleIDs_isolatedByGameKind() throws {
        // A Nonogram win must NOT appear in Sudoku's played-IDs.
        try stats.record(gameKind: .nonogram, difficulty: "easy", outcome: .win, durationSeconds: 100, puzzleId: "nono-1")
        try stats.record(gameKind: .sudoku, difficulty: "easy", outcome: .win, durationSeconds: 100, puzzleId: "sud-1")

        let sudokuIDs = stats.wonPuzzleIDs(gameKind: .sudoku, difficulty: "easy")
        XCTAssertEqual(sudokuIDs, ["sud-1"])
        XCTAssertFalse(sudokuIDs.contains("nono-1"))
    }
}
