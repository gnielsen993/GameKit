import Foundation
import Observation

@Observable
@MainActor
final class FiveLetterViewModel {
    private(set) var mode: FiveLetterMode
    private(set) var answer: String
    private(set) var puzzleId: String
    private(set) var guesses: [FiveLetterGuess] = []
    private(set) var currentGuess = ""
    private(set) var state: FiveLetterState = .playing
    private(set) var message: String?
    private(set) var pendingSaveState: FiveLetterSaveState?
    private(set) var strictModeEnabled: Bool
    private(set) var pausedElapsed: Double = 0
    private(set) var timerAnchor: Date? = .now
    private var gameStats: GameStats?
    private let userDefaults: UserDefaults

    var submitCount = 0
    var invalidCount = 0
    var winCount = 0

    init(mode: FiveLetterMode? = nil, userDefaults: UserDefaults = .standard) {
        let selectedMode = mode ?? Self.lastMode(userDefaults: userDefaults)
        self.mode = selectedMode
        self.userDefaults = userDefaults
        self.strictModeEnabled = userDefaults.bool(forKey: Self.strictModeKey)
        let selection = Self.selectAnswer(mode: selectedMode)
        self.answer = selection.answer
        self.puzzleId = selection.puzzleId
        if !loadCompletedDailyIfNeeded() {
            loadPendingSave()
        }
    }

    var guessesRemaining: Int { 6 - guesses.count }
    var isTerminal: Bool { state == .won || state == .lost }
    var canRestart: Bool { mode == .unlimited }
    var statusText: String {
        strictModeEnabled ? String(localized: "\(mode.displayName) - Strict") : mode.displayName
    }

    func attachGameStats(_ stats: GameStats) {
        self.gameStats = stats
    }

    func input(_ letter: Character) {
        guard state == .playing, currentGuess.count < 5 else { return }
        let upper = String(letter).uppercased()
        guard upper.count == 1, let scalar = upper.unicodeScalars.first,
              CharacterSet.uppercaseLetters.contains(scalar) else { return }
        currentGuess.append(upper)
    }

    func deleteLast() {
        guard state == .playing, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
    }

    func submit() {
        guard state == .playing else { return }
        let normalized = WordLexicon.normalize(currentGuess)
        guard normalized.count == 5, WordLexicon.isAllowedFiveLetterGuess(normalized) else {
            message = String(localized: "Not in word list")
            invalidCount += 1
            return
        }
        if let violation = strictModeViolation(for: normalized) {
            message = violation
            invalidCount += 1
            return
        }

        let guess = FiveLetterGuess(
            word: normalized,
            marks: FiveLetterFeedback.evaluate(guess: normalized, answer: answer)
        )
        guesses.append(guess)
        currentGuess = ""
        submitCount += 1

        if normalized == answer {
            state = .won
            winCount += 1
            pause()
            record(outcome: .win)
            saveDailyResultIfNeeded()
            clearSave()
        } else if guesses.count == 6 {
            state = .lost
            pause()
            record(outcome: .loss)
            saveDailyResultIfNeeded()
            clearSave()
        } else {
            message = nil
            saveCurrentState()
        }
    }

    func restart() {
        guard canRestart else {
            if loadCompletedDailyIfNeeded(showMessage: true) {
                return
            }
            message = String(localized: "Daily challenge is one shot")
            invalidCount += 1
            return
        }
        let selection = Self.selectAnswer(mode: mode)
        answer = selection.answer
        puzzleId = selection.puzzleId
        guesses = []
        currentGuess = ""
        state = .playing
        message = nil
        pausedElapsed = 0
        timerAnchor = .now
        clearSave()
    }

    func setMode(_ newMode: FiveLetterMode) {
        mode = newMode
        userDefaults.set(newMode.rawValue, forKey: Self.lastModeKey)
        let selection = Self.selectAnswer(mode: mode)
        answer = selection.answer
        puzzleId = selection.puzzleId
        guesses = []
        currentGuess = ""
        state = .playing
        message = nil
        pausedElapsed = 0
        timerAnchor = .now
        pendingSaveState = nil
        if !loadCompletedDailyIfNeeded() {
            loadPendingSave()
        }
    }

    func toggleStrictMode() {
        strictModeEnabled.toggle()
        userDefaults.set(strictModeEnabled, forKey: Self.strictModeKey)
        message = strictModeEnabled ? String(localized: "Strict mode on") : String(localized: "Strict mode off")
    }

    func pause() {
        guard let anchor = timerAnchor else { return }
        pausedElapsed += Date().timeIntervalSince(anchor)
        timerAnchor = nil
    }

    func resume() {
        guard state == .playing, timerAnchor == nil else { return }
        timerAnchor = .now
    }

    func restoreState(_ saved: FiveLetterSaveState) {
        guard let restoredMode = FiveLetterMode(rawValue: saved.mode) else {
            discardSaveAndLoadNew()
            return
        }
        mode = restoredMode
        answer = WordLexicon.normalize(saved.answer)
        puzzleId = saved.puzzleId
        guesses = saved.guesses
        currentGuess = ""
        state = .playing
        pausedElapsed = saved.elapsedSeconds
        timerAnchor = .now
        pendingSaveState = nil
    }

    func discardSaveAndLoadNew() {
        clearSave()
        pendingSaveState = nil
        restart()
    }

    func saveCurrentState() {
        guard state == .playing, !guesses.isEmpty else { return }
        let elapsed = elapsedSeconds
        let snapshot = FiveLetterSaveState(
            answer: answer,
            guesses: guesses,
            mode: mode.rawValue,
            puzzleId: puzzleId,
            elapsedSeconds: elapsed,
            savedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: FiveLetterSaveState.key(mode: mode))
        }
    }

    var elapsedSeconds: Double {
        pausedElapsed + (timerAnchor.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func loadPendingSave() {
        let key = FiveLetterSaveState.key(mode: mode)
        guard let data = userDefaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(FiveLetterSaveState.self, from: data),
              !saved.guesses.isEmpty else { return }
        pendingSaveState = saved
    }

    private func clearSave() {
        userDefaults.removeObject(forKey: FiveLetterSaveState.key(mode: mode))
    }

    private func strictModeViolation(for guess: String) -> String? {
        guard strictModeEnabled else { return nil }
        return FiveLetterStrictValidator.violationMessage(for: guess, previousGuesses: guesses)
    }

    private func saveDailyResultIfNeeded() {
        guard mode == .daily, isTerminal else { return }
        let snapshot = FiveLetterDailyResult(
            answer: answer,
            guesses: guesses,
            puzzleId: puzzleId,
            state: state,
            elapsedSeconds: elapsedSeconds,
            completedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: FiveLetterDailyResult.key)
        }
    }

    @discardableResult
    private func loadCompletedDailyIfNeeded(showMessage: Bool = false) -> Bool {
        guard mode == .daily,
              let data = userDefaults.data(forKey: FiveLetterDailyResult.key),
              let saved = try? JSONDecoder().decode(FiveLetterDailyResult.self, from: data),
              saved.puzzleId == puzzleId else { return false }

        answer = WordLexicon.normalize(saved.answer)
        guesses = saved.guesses
        currentGuess = ""
        state = saved.state
        pausedElapsed = saved.elapsedSeconds
        timerAnchor = nil
        pendingSaveState = nil
        message = showMessage ? String(localized: "Daily already played") : String(localized: "Daily complete")
        return true
    }

    private func record(outcome: Outcome) {
        let seconds = elapsedSeconds
        try? gameStats?.record(
            gameKind: .fiveLetter,
            difficulty: mode.rawValue,
            outcome: outcome,
            durationSeconds: seconds,
            puzzleId: puzzleId,
            score: guesses.count
        )
    }

    private static let lastModeKey = "fiveLetter.lastMode"
    private static let strictModeKey = "fiveLetter.strictModeEnabled"

    private static func lastMode(userDefaults: UserDefaults) -> FiveLetterMode {
        guard let raw = userDefaults.string(forKey: lastModeKey),
              let mode = FiveLetterMode(rawValue: raw) else { return .daily }
        return mode
    }

    private static func selectAnswer(mode: FiveLetterMode, now: Date = .now) -> (answer: String, puzzleId: String) {
        let answers = WordLexicon.fiveLetterAnswers
        guard !answers.isEmpty else { return ("APPLE", "fallback") }
        switch mode {
        case .daily:
            let id = dailyPuzzleId(now: now)
            let index = abs(id.hashValue) % answers.count
            return (answers[index], id)
        case .unlimited:
            let seed = UInt64(Date().timeIntervalSinceReferenceDate.rounded()) ^ UInt64.random(in: 0...UInt64.max)
            var rng = SeededRandom(seed: seed)
            return (answers.randomElement(using: &rng) ?? answers[0], UUID().uuidString)
        }
    }

    private static func dailyPuzzleId(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }
}
