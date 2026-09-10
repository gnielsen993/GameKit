import Foundation
import Testing
import MathCrosswordCore
@testable import gamekit

@MainActor
struct MathCrosswordViewModelTests {
    @Test("Math Crossword preserves duplicate number-bank counts and undo")
    func placementAndUndoPreserveInventory() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        var session = try MathCrosswordSession(puzzle: puzzle)
        let first = puzzle.blanks[0]
        let value = puzzle.solution[first]!
        let before = session.remainingBank.filter { $0 == value }.count
        let viewModel = MathCrosswordViewModel(session: session, userDefaults: defaults)

        viewModel.select(first)
        viewModel.place(value)

        #expect(viewModel.placements[first] == value)
        #expect(viewModel.remainingBank.filter { $0 == value }.count == before - 1)

        viewModel.undo()

        #expect(viewModel.placements[first] == nil)
        #expect(viewModel.remainingBank.filter { $0 == value }.count == before)
        session = try MathCrosswordSession(puzzle: puzzle)
        #expect(session.remainingBank == viewModel.remainingBank)
    }

    @Test("Math Crossword never draws a hint from an incorrect premise")
    func hintRejectsIncorrectBoard() throws {
        let puzzle = try alternativePuzzle()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: makeDefaults())
        let equation = puzzle.equations[0]
        for (position, value) in [(equation.a, 1), (equation.b, 4), (equation.r, 3)] {
            viewModel.select(position)
            viewModel.place(value)
        }
        viewModel.requestHint()

        #expect(viewModel.activeHint == nil)
        #expect(viewModel.hasIncorrectPlacement)
        #expect(viewModel.hintUnavailableMessage == viewModel.conflictMessage)
    }

    @Test("Math Crossword saves the entire puzzle session for resume")
    func saveRoundTripRestoresPuzzleAndPlacements() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)
        let position = try #require(puzzle.blanks.first)
        let value = try #require(puzzle.solution[position])

        viewModel.select(position)
        viewModel.place(value)
        viewModel.saveCurrentState()

        let data = try #require(defaults.data(forKey: MathCrosswordSaveState.key(difficulty: .easy)))
        let saved = try JSONDecoder().decode(MathCrosswordSaveState.self, from: data)

        #expect(saved.session.puzzle.seed == puzzle.seed)
        #expect(saved.session.placements[position] == value)
    }

    @Test("Math Crossword locks a recorded win against erase and undo")
    func recordedWinCannotMutateThroughControls() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)

        for position in puzzle.blanks {
            viewModel.select(position)
            viewModel.place(try #require(puzzle.solution[position]))
        }
        let solved = viewModel.placements
        viewModel.select(try #require(puzzle.blanks.first))
        viewModel.eraseSelected()
        viewModel.undo()

        #expect(viewModel.state == .won)
        #expect(viewModel.placements == solved)
    }

    @Test("Math Crossword keeps replay ineligible after help")
    func restartAfterHintDoesNotResetRecordEligibility() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)

        viewModel.requestHint()
        viewModel.restart()
        viewModel.saveCurrentState()

        let data = try #require(defaults.data(forKey: MathCrosswordSaveState.key(difficulty: .easy)))
        let saved = try JSONDecoder().decode(MathCrosswordSaveState.self, from: data)
        #expect(saved.countsTowardRecords == false)
        #expect(saved.assistsUsed == 0)
    }

    @Test("Math Crossword clears a persistent hint when another move breaks its premise")
    func wrongMoveInvalidatesPersistentHint() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)
        viewModel.requestHint()
        let hint = try #require(viewModel.activeHint)
        let unrelated = try #require(puzzle.blanks.first(where: { hint.placements[$0] == nil }))
        let wrong = try #require(viewModel.remainingBank.first(where: { $0 != puzzle.solution[unrelated] }))

        viewModel.select(unrelated)
        viewModel.place(wrong)

        #expect(viewModel.activeHint == nil)
        #expect(viewModel.isHintCardVisible == false)
    }

    @Test("Math Crossword retains an unreadable future save until replacement is confirmed")
    func futureSaveIsNotOverwritten() throws {
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let future = MathCrosswordSaveState(
            schemaVersion: 99,
            session: try MathCrosswordSession(puzzle: puzzle),
            elapsedSeconds: 12,
            assistsUsed: 0,
            activeHint: nil,
            countsTowardRecords: true,
            savedAt: .now
        )
        let key = MathCrosswordSaveState.key(difficulty: .easy)
        let data = try JSONEncoder().encode(future)
        defaults.set(data, forKey: key)

        let restored = MathCrosswordViewModel(initialDifficulty: "easy", userDefaults: defaults)

        #expect(restored.hasUnreadableSave)
        #expect(restored.state != .playing)
        #expect(defaults.data(forKey: key) == data)
    }

    @Test("A valid alternative stays neutral, can request help and wins")
    func alternativePlacementDoesNotWarn() throws {
        let puzzle = try alternativePuzzle()
        let equation = puzzle.equations[0]
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: makeDefaults())
        viewModel.select(equation.a)
        viewModel.place(3)
        #expect(!viewModel.hasIncorrectPlacement)
        #expect(viewModel.wrongAttemptCount == 0)
        #expect(viewModel.conflictMessage == nil)
        viewModel.requestHint()
        #expect(viewModel.activeHint != nil)
        viewModel.applyHint()
        #expect(viewModel.state == .won)
        #expect(viewModel.wrongAttemptCount == 0)
    }

    @Test("Returning a tile clears its conflict and preserves inventory, save and undo")
    func returnTileUsesReversibleErase() throws {
        let puzzle = try alternativePuzzle()
        let equation = puzzle.equations[0]
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)
        viewModel.select(equation.r)
        viewModel.place(1)
        #expect(!viewModel.hasIncorrectPlacement)
        #expect(viewModel.wrongAttemptCount == 0)
        #expect(viewModel.conflictMessage == nil)
        viewModel.select(equation.a)
        viewModel.place(3)
        #expect(!viewModel.hasIncorrectPlacement)
        viewModel.select(equation.b)
        viewModel.place(4)
        #expect(viewModel.hasIncorrectPlacement)
        #expect(viewModel.wrongAttemptCount == 1)
        viewModel.returnTile(at: equation.r, expectedValue: 1)
        #expect(viewModel.placements[equation.r] == nil)
        #expect(!viewModel.hasIncorrectPlacement)
        #expect(viewModel.remainingBank == [1])
        let data = try #require(defaults.data(forKey: MathCrosswordSaveState.key(difficulty: .easy)))
        let saved = try JSONDecoder().decode(MathCrosswordSaveState.self, from: data)
        #expect(saved.session.placements[equation.r] == nil)
        viewModel.restoreState(saved)
        viewModel.undo()
        #expect(viewModel.placements[equation.r] == 1)
        #expect(viewModel.hasIncorrectPlacement)
    }

    @Test("A stale drag cannot erase a replacement tile")
    func staleReturnDoesNotChangeBoard() throws {
        let puzzle = try alternativePuzzle()
        let position = puzzle.equations[0].a
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: makeDefaults())
        viewModel.select(position)
        viewModel.place(1)
        viewModel.place(3)
        viewModel.returnTile(at: position, expectedValue: 1)
        #expect(viewModel.placements[position] == 3)
        #expect(viewModel.placementHistory.count == 2)
    }

    private func alternativePuzzle() throws -> TallyPuzzle {
        let equation = Equation(a: GridPos(row: 0, col: 0), opCell: GridPos(row: 0, col: 1),
                                b: GridPos(row: 0, col: 2), eqCell: GridPos(row: 0, col: 3), r: GridPos(row: 0, col: 4), op: .add)
        return try TallyPuzzle(seed: 1, difficulty: .easy, equations: [equation],
                              solution: [equation.a: 1, equation.b: 3, equation.r: 4], givens: [], bank: [1, 3, 4])
    }

    private func makeDefaults() -> UserDefaults {
        let name = "MathCrosswordViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
