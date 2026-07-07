// Core/ScreenshotSeeder.swift
//
// DEBUG-only full-wipe screenshot seeder. Triggered by the --screenshots
// launch argument. Unlike DummyDataSeeder (one-shot per install),
// ScreenshotSeeder always wipes and reseeds — every launch with the flag
// produces an identical, predictable UI state for App Store screenshots.
//
// Usage (see scripts/screenshot_seed.sh for the one-command flow):
//   xcrun simctl launch <device> com.lauterstar.gamekit --screenshots
//
// --screenshots-arcade: same as --screenshots, PLUS Stack + Snake arcade
//   data (including 6-7 digit high scores for the Phase 18 D-04 overflow
//   audit). Stack/Snake sections show "No runs yet." under plain --screenshots.
//
// What it seeds:
//   - SwiftData: GameRecord + BestTime + BestScore rows for all 6 base games
//   - UserDefaults: in-progress save states for Minesweeper Easy, Merge
//     win-mode, FreeCell deal #1, Solitaire Easy, Sudoku easy/free
//   - Nonogram skipped — puzzle IDs are library-coupled; existing wins
//     in GameRecord records are enough to populate the solved gallery

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum ScreenshotSeeder {

    static var isActive: Bool {
        CommandLine.arguments.contains("--screenshots")
    }

    /// Activated by --screenshots-arcade. Seeds everything --screenshots seeds
    /// PLUS Stack and Snake arcade data (6-7 digit scores for D-04 overflow check).
    static var isArcadeActive: Bool {
        CommandLine.arguments.contains("--screenshots-arcade")
    }

    static func seed(container: ModelContainer, includeArcade: Bool = false) {
        let context = container.mainContext
        do {
            try context.delete(model: GameRecord.self)
            try context.delete(model: BestTime.self)
            try context.delete(model: BestScore.self)
            seedStats(context: context)
            if includeArcade { seedArcadeStats(context: context) }
            try context.save()
            seedSaveStates()
            let label = includeArcade ? "6 base games + arcade (Stack/Snake)" : "6 base games"
            print("📸 ScreenshotSeeder: wiped + reseeded \(label) + save states.")
        } catch {
            print("❌ ScreenshotSeeder failed: \(error)")
        }
    }

    // MARK: - SwiftData records

    private static func seedStats(context: ModelContext) {
        let now = Date()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

        // Minesweeper
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "easy",   seconds: 23,  achievedAt: ago(2)))
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "medium", seconds: 105, achievedAt: ago(5)))
        context.insert(BestTime(gameKind: .minesweeper, difficulty: "hard",   seconds: 332, achievedAt: ago(11)))
        for (o, s, d) in [(Outcome.win,23.0,2.0),(.win,31,6),(.win,28,9),(.win,35,12),
                          (.win,41,15),(.win,26,18),(.win,38,22),(.win,45,28),
                          (.loss,12,4),(.loss,18,21)] {
            context.insert(GameRecord(gameKind: .minesweeper, difficulty: "easy", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
        for (o, s, d) in [(Outcome.win,105.0,5.0),(.win,134,8),(.win,156,13),(.win,142,19),(.win,178,25),
                          (.loss,89,3),(.loss,67,10),(.loss,112,16),(.loss,95,22)] {
            context.insert(GameRecord(gameKind: .minesweeper, difficulty: "medium", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
        for (o, s, d) in [(Outcome.win,332.0,11.0),(.win,421,24),
                          (.loss,187,1),(.loss,245,6),(.loss,198,14),
                          (.loss,276,17),(.loss,312,20),(.loss,156,27)] {
            context.insert(GameRecord(gameKind: .minesweeper, difficulty: "hard", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }

        // Merge
        context.insert(BestScore(gameKind: .merge, difficulty: "win",      score: 18432, achievedAt: ago(3)))
        context.insert(BestScore(gameKind: .merge, difficulty: "infinite", score: 4096,  achievedAt: ago(7)))
        for (o, s, sc, d) in [(Outcome.win,612.0,18432,3.0),(.win,489,12856,7),
                               (.loss,287,4096,14),(.loss,156,2048,19)] {
            context.insert(GameRecord(gameKind: .merge, difficulty: "win", outcome: o, durationSeconds: s, playedAt: ago(d), score: sc))
        }
        for (o, s, sc, d) in [(Outcome.loss,423.0,4096,7.0),(.loss,198,1024,21)] {
            context.insert(GameRecord(gameKind: .merge, difficulty: "infinite", outcome: o, durationSeconds: s, playedAt: ago(d), score: sc))
        }

        // Nonogram
        context.insert(BestTime(gameKind: .nonogram, difficulty: "tiny",   seconds: 14,  achievedAt: ago(1)))
        context.insert(BestTime(gameKind: .nonogram, difficulty: "small",  seconds: 78,  achievedAt: ago(4)))
        context.insert(BestTime(gameKind: .nonogram, difficulty: "medium", seconds: 312, achievedAt: ago(9)))
        for (pid, s, d) in [("tiny-001",14.0,1.0),("tiny-002",22,2),("tiny-003",19,5),("tiny-004",31,8)] {
            context.insert(GameRecord(gameKind: .nonogram, difficulty: "tiny", outcome: .win, durationSeconds: s, playedAt: ago(d), puzzleId: pid))
        }
        for (pid, s, d) in [("small-001",78.0,4.0),("small-002",124,11)] {
            context.insert(GameRecord(gameKind: .nonogram, difficulty: "small", outcome: .win, durationSeconds: s, playedAt: ago(d), puzzleId: pid))
        }
        context.insert(GameRecord(gameKind: .nonogram, difficulty: "medium", outcome: .win,  durationSeconds: 312, playedAt: ago(9),  puzzleId: "medium-001"))
        context.insert(GameRecord(gameKind: .nonogram, difficulty: "medium", outcome: .loss, durationSeconds: 188, playedAt: ago(13)))

        // Sudoku
        context.insert(BestTime(gameKind: .sudoku, difficulty: "easy",   seconds: 134, achievedAt: ago(2)))
        context.insert(BestTime(gameKind: .sudoku, difficulty: "medium", seconds: 287, achievedAt: ago(6)))
        context.insert(BestTime(gameKind: .sudoku, difficulty: "hard",   seconds: 512, achievedAt: ago(14)))
        for (o, s, d) in [(Outcome.win,134.0,2.0),(.win,156,5),(.win,201,9),(.win,178,13),(.loss,67,1),(.loss,89,7)] {
            context.insert(GameRecord(gameKind: .sudoku, difficulty: "easy", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
        for (o, s, d) in [(Outcome.win,287.0,6.0),(.win,334,10),(.win,412,17),(.loss,198,3),(.loss,223,11)] {
            context.insert(GameRecord(gameKind: .sudoku, difficulty: "medium", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }

        // FreeCell
        context.insert(BestTime(gameKind: .freeCell, difficulty: "easy",   seconds: 187, achievedAt: ago(3)))
        context.insert(BestTime(gameKind: .freeCell, difficulty: "medium", seconds: 324, achievedAt: ago(8)))
        for (o, s, d) in [(Outcome.win,187.0,3.0),(.win,203,7),(.win,241,12),(.win,198,18),(.loss,134,1),(.loss,156,9)] {
            context.insert(GameRecord(gameKind: .freeCell, difficulty: "easy", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
        for (o, s, d) in [(Outcome.win,324.0,8.0),(.win,356,15),(.loss,212,4),(.loss,267,11)] {
            context.insert(GameRecord(gameKind: .freeCell, difficulty: "medium", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }

        // Klondike / Solitaire
        context.insert(BestTime(gameKind: .klondike, difficulty: "easy",   seconds: 234, achievedAt: ago(1)))
        context.insert(BestTime(gameKind: .klondike, difficulty: "medium", seconds: 387, achievedAt: ago(5)))
        for (o, s, d) in [(Outcome.win,234.0,1.0),(.win,267,4),(.win,312,8),(.win,289,14),(.loss,156,2),(.loss,198,10)] {
            context.insert(GameRecord(gameKind: .klondike, difficulty: "easy", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
        for (o, s, d) in [(Outcome.win,387.0,5.0),(.win,423,12),(.loss,234,3),(.loss,312,9),(.loss,278,16)] {
            context.insert(GameRecord(gameKind: .klondike, difficulty: "medium", outcome: o, durationSeconds: s, playedAt: ago(d)))
        }
    }

    // MARK: - Arcade stats (Stack + Snake) — Phase 18 D-04 overflow audit

    /// Seeds Stack and Snake arcade data. Called only under --screenshots-arcade.
    /// Includes a 7-digit Stack high score and 6-digit Snake high score to exercise
    /// the D-04 hero-numeral wrap/clip check in ScoreStatsCard.
    private static func seedArcadeStats(context: ModelContext) {
        let now = Date()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

        // Stack — 7-digit hero score (D-04 overflow-check target).
        // Keys must match GameStats.stackEndlessMode ("endless") and
        // GameStats.stackPerfectStreakMode ("perfectStreak") — renaming = data break.
        context.insert(BestScore(gameKind: .stack, difficulty: "endless",       score: 1_234_567, achievedAt: ago(1)))
        context.insert(BestScore(gameKind: .stack, difficulty: "perfectStreak", score: 42,        achievedAt: ago(3)))
        for (sc, d) in [(1_234_567, 1.0), (987_321, 4.0), (765_432, 8.0), (543_210, 12.0), (321_098, 19.0)] {
            context.insert(GameRecord(
                gameKind: .stack,
                difficulty: "endless",
                outcome: .loss,
                durationSeconds: 120,
                playedAt: ago(d),
                score: sc
            ))
        }

        // Snake — 6-digit hero score.
        // Key matches GameStats.snakeEndlessMode (D-12 — renaming = data break).
        context.insert(BestScore(gameKind: .snake, difficulty: GameStats.snakeEndlessMode, score: 987_654, achievedAt: ago(2)))
        for (sc, d) in [(987_654, 2.0), (743_210, 5.0), (512_345, 10.0), (298_765, 15.0)] {
            context.insert(GameRecord(
                gameKind: .snake,
                difficulty: GameStats.snakeEndlessMode,
                outcome: .loss,
                durationSeconds: 90,
                playedAt: ago(d),
                score: sc
            ))
        }
    }

    // MARK: - UserDefaults save states

    private static func seedSaveStates() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        // Minesweeper Easy — mid-game (45 s elapsed, top-left corner revealed, 2 flags)
        var rng = SeededRNG(seed: 42)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        var mineBoard = BoardGenerator.generate(difficulty: .easy, firstTap: firstTap, rng: &rng)
        (mineBoard, _) = RevealEngine.reveal(at: firstTap, on: mineBoard)
        var flagsPlaced = 0
        outer: for r in 0..<mineBoard.rows {
            for c in 0..<mineBoard.cols {
                guard flagsPlaced < 2 else { break outer }
                let idx = MinesweeperIndex(row: r, col: c)
                let cell = mineBoard.cell(at: idx)
                if cell.isMine && cell.state == .hidden {
                    mineBoard = mineBoard.replacingCell(
                        at: idx,
                        with: MinesweeperCell(isMine: true, adjacentMineCount: cell.adjacentMineCount, state: .flagged)
                    )
                    flagsPlaced += 1
                }
            }
        }
        encode(MinesweeperSaveState(board: mineBoard, difficulty: .easy, flaggedCount: flagsPlaced,
                                    elapsedSeconds: 45, savedAt: Date()),
               to: MinesweeperSaveState.key(difficulty: .easy), defaults: defaults, encoder: encoder)

        // Merge win-mode — mid-game board, score 3200
        var mergeCells: [MergeTile?] = Array(repeating: nil, count: 16)
        mergeCells[0]  = MergeTile(value: 256)
        mergeCells[2]  = MergeTile(value: 128)
        mergeCells[5]  = MergeTile(value: 512)
        mergeCells[7]  = MergeTile(value: 64)
        mergeCells[8]  = MergeTile(value: 32)
        mergeCells[11] = MergeTile(value: 16)
        mergeCells[13] = MergeTile(value: 64)
        mergeCells[14] = MergeTile(value: 128)
        encode(MergeSaveState(board: MergeBoard(cells: mergeCells), score: 3200,
                              mode: MergeMode.winMode.rawValue, hasContinuedPastWin: false, savedAt: Date()),
               to: MergeSaveState.key(mode: .winMode), defaults: defaults, encoder: encoder)

        // FreeCell deal #1 — initial state
        encode(FreeCellSaveState(board: FreeCellBoard(dealNumber: 1), dealNumber: 1,
                                 difficulty: "easy", elapsedSeconds: 0, savedAt: Date()),
               to: FreeCellSaveState.currentKey, defaults: defaults, encoder: encoder)

        // Solitaire Easy — initial deal
        encode(SolitaireSaveState(board: SolitaireBoard.deal(seed: 1, difficulty: .easy),
                                  dealNumber: 1, difficulty: .easy,
                                  moveCount: 0, elapsedSeconds: 0, savedAt: Date()),
               to: SolitaireSaveState.key(difficulty: .easy), defaults: defaults, encoder: encoder)

        // Sudoku easy/free — Wikipedia example puzzle, ~20 cells player-filled
        // givens: 0=empty, 1-9=clue. solution: complete 81-digit string.
        let givens   = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
        let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
        let cells = makeSudokuCells(givens: givens, solution: solution, playerFilledCount: 20)
        encode(SudokuSaveState(puzzleId: "easy-001", givens: givens, solution: solution,
                               givenCount: givens.filter { $0 != "0" }.count, cells: cells,
                               elapsedSeconds: 78, mistakes: 0, lockedCellIndices: [],
                               gameMode: SudokuGameMode.free.rawValue, savedAt: Date()),
               to: SudokuSaveState.key(difficulty: .easy, gameMode: .free), defaults: defaults, encoder: encoder)
    }

    private static func makeSudokuCells(givens: String, solution: String, playerFilledCount: Int) -> [SudokuCell] {
        let g = givens.map   { $0 == "0" ? 0 : Int(String($0))! }
        let s = solution.compactMap { Int(String($0)) }
        guard s.count == 81 else {
            print("❌ ScreenshotSeeder: invalid solution string (count \(s.count)); Sudoku save state skipped.")
            return []
        }
        var filled = 0
        return (0..<81).map { i in
            if g[i] != 0 { return .given(g[i]) }
            if filled < playerFilledCount { filled += 1; return .user(s[i]) }
            return .empty(notes: [])
        }
    }

    private static func encode<T: Encodable>(_ value: T, to key: String, defaults: UserDefaults, encoder: JSONEncoder) {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            print("❌ ScreenshotSeeder: failed to encode \(T.self) for key '\(key)': \(error)")
        }
    }
}
#endif
