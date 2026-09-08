import Foundation
import Observation
import MathCrosswordCore
import os

@Observable
@MainActor
final class MathCrosswordViewModel {
    private(set) var difficulty: MathCrosswordDifficulty
    private(set) var session: MathCrosswordSession?
    private(set) var state: MathCrosswordState = .loading
    private(set) var pendingSaveState: MathCrosswordSaveState?
    private(set) var activeHint: MathCrosswordActiveHint?
    private(set) var isHintCardVisible = false
    private(set) var hintUnavailableMessage: String?
    private(set) var assistsUsed = 0
    private(set) var hasUnreadableSave = false
    private(set) var pausedElapsed: TimeInterval = 0
    private(set) var timerAnchor: Date?
    var selectedCell: GridPos?
    var placementCount = 0
    var wrongAttemptCount = 0
    private var countsTowardRecords = true
    private var didRecordWin = false
    private var sceneIsActive = true
    private var heldGeneratedPuzzle: TallyPuzzle?
    var selectionCount = 0
    var undoCount = 0
    var winCount = 0
    private var gameStats: GameStats?
    private let userDefaults: UserDefaults
    private var generationTask: Task<Void, Never>?

    init(initialDifficulty: String? = nil, userDefaults: UserDefaults = .standard) {
        difficulty = MathCrosswordDifficulty(routeValue: initialDifficulty) ?? .easy
        self.userDefaults = userDefaults
        if initialDifficulty == nil,
           let stored = userDefaults.string(forKey: Self.lastDifficultyKey),
           let lastDifficulty = MathCrosswordDifficulty(rawValue: stored) {
            difficulty = lastDifficulty
        }
        loadPendingOrGenerate()
    }

    /// Test seam for deterministic gameplay assertions without generator work.
    init(session: MathCrosswordSession, userDefaults: UserDefaults = .standard) {
        difficulty = MathCrosswordDifficulty(rawValue: session.puzzle.difficulty.rawValue.lowercased()) ?? .easy
        self.userDefaults = userDefaults
        self.session = session
        state = .playing
        timerAnchor = .now
    }

    var elapsedSeconds: TimeInterval {
        guard let timerAnchor else { return pausedElapsed }
        return pausedElapsed + max(0, Date.now.timeIntervalSince(timerAnchor))
    }

    var puzzle: TallyPuzzle? { session?.puzzle }
    var placements: [GridPos: Int] { session?.placements ?? [:] }
    var placementHistory: [MathCrosswordMove] { session?.history ?? [] }

    var remainingBank: [Int] {
        session?.remainingBank ?? []
    }

    var filledCount: Int { placements.count }
    var blankCount: Int { puzzle?.blanks.count ?? 0 }
    var hasIncorrectPlacement: Bool {
        guard let puzzle else { return false }
        return placements.contains { position, value in puzzle.solution[position] != value }
    }

    func attachGameStats(_ stats: GameStats) {
        gameStats = stats
        if state == .won, let puzzle { recordWinIfPossible(puzzle: puzzle) }
    }

    func select(_ position: GridPos) {
        guard state == .playing, puzzle?.blanks.contains(position) == true else { return }
        selectedCell = position
        selectionCount += 1
    }

    func place(_ value: Int) {
        guard state == .playing, let target = selectedCell,
              remainingBank.contains(value) else { return }
        guard var session else { return }
        if placements[target] == nil {
            guard (try? session.place(value, at: target)) != nil else { return }
        } else {
            guard (try? session.replace(value, at: target)) != nil else { return }
        }
        self.session = session
        placementCount += 1
        if puzzle?.solution[target] != value { wrongAttemptCount += 1 }
        validateActiveHintAfterMove()
        saveCurrentState()
        checkForWin()
    }

    func eraseSelected() {
        guard state == .playing, let selectedCell, var session else { return }
        guard (try? session.erase(at: selectedCell)) != nil else { return }
        self.session = session
        validateActiveHintAfterMove()
        saveCurrentState()
    }

    func undo() {
        guard state == .playing, var session else { return }
        guard (try? session.undo()) != nil else { return }
        self.session = session
        validateActiveHintAfterMove()
        undoCount += 1
        saveCurrentState()
    }

    func requestHint() {
        guard state == .playing, let puzzle else { return }
        hintUnavailableMessage = nil
        if activeHint != nil {
            isHintCardVisible = true
            return
        }
        guard !hasIncorrectPlacement else {
            hintUnavailableMessage = "One or more placed numbers do not fit the equations. Clear the red cells before asking for a deduction."
            isHintCardVisible = true
            return
        }
        guard let hint = session?.nextHint(),
              !hint.placements.isEmpty else {
            hintUnavailableMessage = "There is no forced step from this board yet. Try another equation or clear a number to reopen the chain."
            isHintCardVisible = true
            return
        }
        activeHint = MathCrosswordActiveHint(equationIndex: hint.equationIndex, placements: hint.placements)
        assistsUsed += 1
        countsTowardRecords = false
        isHintCardVisible = true
        pause()
        saveCurrentState()
    }

    func revealActiveHint() {
        guard var activeHint else { return }
        activeHint.isRevealed = true
        self.activeHint = activeHint
    }

    func applyHint() {
        guard let activeHint, state == .playing, var session else { return }
        let advertised = Solver.ChainStep(equationIndex: activeHint.equationIndex, placements: activeHint.placements)
        guard session.nextHint() == advertised else {
            self.activeHint = nil
            isHintCardVisible = false
            return
        }
        for (position, value) in activeHint.placements.sorted(by: { $0.key < $1.key }) {
            guard (try? session.place(value, at: position)) != nil else { return }
        }
        self.session = session
        self.activeHint = nil
        isHintCardVisible = false
        placementCount += 1
        validateActiveHintAfterMove()
        saveCurrentState()
        checkForWin()
    }

    func dismissHint() {
        isHintCardVisible = false
        hintUnavailableMessage = nil
    }

    func pause() {
        guard timerAnchor != nil else { return }
        pausedElapsed = elapsedSeconds
        timerAnchor = nil
        saveCurrentState()
    }

    func resume() {
        guard sceneIsActive, state == .playing, !isHintCardVisible, pendingSaveState == nil, timerAnchor == nil else { return }
        timerAnchor = .now
    }

    func restart() {
        guard let puzzle, let freshSession = try? MathCrosswordSession(puzzle: puzzle) else { return }
        let replayingCompletedPuzzle = state == .won
        session = freshSession
        selectedCell = nil
        activeHint = nil
        isHintCardVisible = false
        hintUnavailableMessage = nil
        assistsUsed = 0
        pausedElapsed = 0
        timerAnchor = .now
        state = .playing
        countsTowardRecords = countsTowardRecords && !replayingCompletedPuzzle
        didRecordWin = false
        saveCurrentState()
    }

    func newPuzzle() {
        clearSave()
        pendingSaveState = nil
        hasUnreadableSave = false
        session = nil
        heldGeneratedPuzzle = nil
        selectedCell = nil
        activeHint = nil
        isHintCardVisible = false
        didRecordWin = false
        pausedElapsed = 0
        timerAnchor = nil
        generatePuzzle()
    }

    func setDifficulty(_ newDifficulty: MathCrosswordDifficulty) {
        guard newDifficulty != difficulty else { return }
        saveCurrentState()
        difficulty = newDifficulty
        userDefaults.set(newDifficulty.rawValue, forKey: Self.lastDifficultyKey)
        pendingSaveState = nil
        session = nil
        heldGeneratedPuzzle = nil
        selectedCell = nil
        activeHint = nil
        isHintCardVisible = false
        pausedElapsed = 0
        timerAnchor = nil
        state = .loading
        loadPendingOrGenerate()
    }

    func restoreState(_ save: MathCrosswordSaveState) {
        guard save.schemaVersion == MathCrosswordSaveState.schemaVersion else {
            pendingSaveState = nil
            hasUnreadableSave = true
            state = .failed("This saved puzzle belongs to a newer version. It has been kept unchanged.")
            return
        }
        difficulty = MathCrosswordDifficulty(rawValue: save.session.puzzle.difficulty.rawValue.lowercased()) ?? .easy
        session = save.session
        pausedElapsed = save.elapsedSeconds
        assistsUsed = save.assistsUsed
        countsTowardRecords = save.countsTowardRecords
        activeHint = validatedHint(save.activeHint, in: save.session)
        pendingSaveState = nil
        hasUnreadableSave = false
        state = .playing
        timerAnchor = .now
    }

    func discardSaveAndGenerate() {
        clearSave()
        pendingSaveState = nil
        hasUnreadableSave = false
        generatePuzzle()
    }

    func replaceUnreadableSave() {
        guard hasUnreadableSave else { return }
        clearSave()
        hasUnreadableSave = false
        generatePuzzle()
    }

    func setSceneActive(_ isActive: Bool) {
        sceneIsActive = isActive
        if isActive {
            applyHeldGeneratedPuzzleIfNeeded()
            if state == .won, let puzzle { recordWinIfPossible(puzzle: puzzle) }
            resume()
        } else {
            pause()
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }

    func saveCurrentState() {
        guard let session, state == .playing else { return }
        let state = MathCrosswordSaveState(
            schemaVersion: MathCrosswordSaveState.schemaVersion,
            session: session,
            elapsedSeconds: elapsedSeconds,
            assistsUsed: assistsUsed,
            activeHint: activeHint,
            countsTowardRecords: countsTowardRecords,
            savedAt: .now
        )
        guard let data = try? JSONEncoder().encode(state) else {
            AppLog.storage.error("Could not encode Math Crossword save state")
            return
        }
        userDefaults.set(data, forKey: MathCrosswordSaveState.key(difficulty: difficulty))
    }

    private static let lastDifficultyKey = "mathCrossword.lastDifficulty"

    private func loadPendingOrGenerate() {
        let key = MathCrosswordSaveState.key(difficulty: difficulty)
        if let data = userDefaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(MathCrosswordSaveState.self, from: data) {
            if saved.schemaVersion == MathCrosswordSaveState.schemaVersion {
                pendingSaveState = saved
            } else {
                hasUnreadableSave = true
                state = .failed("This saved puzzle belongs to a newer version. It has been kept unchanged.")
            }
            return
        }
        if userDefaults.data(forKey: key) != nil {
            hasUnreadableSave = true
            state = .failed("This saved puzzle could not be read. It has been kept unchanged.")
            return
        }
        generatePuzzle()
    }

    private func generatePuzzle() {
        generationTask?.cancel()
        state = .loading
        let difficulty = difficulty.coreDifficulty
        generationTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                Result { try PuzzleFactory.generate(difficulty: difficulty, maximumAttempts: 16) }
            }
            let result = await withTaskCancellationHandler(
                operation: { await worker.value },
                onCancel: { worker.cancel() }
            )
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let puzzle):
                if self.sceneIsActive {
                    self.acceptGeneratedPuzzle(puzzle)
                } else {
                    self.heldGeneratedPuzzle = puzzle
                }
            case .failure:
                self.timerAnchor = nil
                self.state = .failed("We could not make a verified puzzle. Please try a new one.")
            }
        }
    }

    private func checkForWin() {
        guard state == .playing, let session, session.isComplete, let puzzle else { return }
        state = .won
        pausedElapsed = elapsedSeconds
        timerAnchor = nil
        activeHint = nil
        isHintCardVisible = false
        winCount += 1
        recordWinIfPossible(puzzle: puzzle)
        clearSave()
    }

    private func validateActiveHintAfterMove() {
        guard let activeHint, let session else { return }
        let advertised = Solver.ChainStep(equationIndex: activeHint.equationIndex, placements: activeHint.placements)
        guard !hasIncorrectPlacement,
              !activeHint.placements.allSatisfy({ placements[$0.key] == $0.value }),
              session.nextHint() == advertised else {
            self.activeHint = nil
            isHintCardVisible = false
            return
        }
    }

    private func validatedHint(_ stored: MathCrosswordActiveHint?, in session: MathCrosswordSession) -> MathCrosswordActiveHint? {
        guard let stored else { return nil }
        let expected = Solver.ChainStep(equationIndex: stored.equationIndex, placements: stored.placements)
        return session.nextHint() == expected ? stored : nil
    }

    private func acceptGeneratedPuzzle(_ puzzle: TallyPuzzle) {
        guard let newSession = try? MathCrosswordSession(puzzle: puzzle) else {
            state = .failed("We could not validate this puzzle. Please try a new one.")
            return
        }
        session = newSession
        pausedElapsed = 0
        assistsUsed = 0
        activeHint = nil
        countsTowardRecords = true
        didRecordWin = false
        timerAnchor = .now
        state = .playing
        saveCurrentState()
    }

    private func applyHeldGeneratedPuzzleIfNeeded() {
        guard let heldGeneratedPuzzle else { return }
        self.heldGeneratedPuzzle = nil
        acceptGeneratedPuzzle(heldGeneratedPuzzle)
    }

    private func recordWinIfPossible(puzzle: TallyPuzzle) {
        guard !didRecordWin, let gameStats else { return }
        do {
            try gameStats.record(
                gameKind: .mathCrossword,
                difficulty: difficulty.rawValue,
                outcome: .win,
                durationSeconds: pausedElapsed,
                puzzleId: "math-crossword-\(puzzle.seed)",
                assistCount: assistsUsed,
                countsTowardRecords: countsTowardRecords
            )
            didRecordWin = true
        } catch {
            AppLog.storage.error("Could not save Math Crossword win")
        }
    }

    private func clearSave() {
        userDefaults.removeObject(forKey: MathCrosswordSaveState.key(difficulty: difficulty))
    }
}
