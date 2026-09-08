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
        let puzzle = try PuzzleFactory.generate(difficulty: .easy, seed: 1)
        let defaults = makeDefaults()
        let viewModel = MathCrosswordViewModel(session: try MathCrosswordSession(puzzle: puzzle), userDefaults: defaults)
        let target = try #require(puzzle.blanks.first)
        let wrongTile = try #require(puzzle.bank.first(where: { $0 != puzzle.solution[target] }))

        viewModel.select(target)
        viewModel.place(wrongTile)
        viewModel.requestHint()

        #expect(viewModel.activeHint == nil)
        #expect(viewModel.hintUnavailableMessage?.contains("do not fit") == true)
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

    private func makeDefaults() -> UserDefaults {
        let name = "MathCrosswordViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
