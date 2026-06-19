import Foundation
import Observation

@Observable
@MainActor
final class WordGridViewModel {
    private(set) var mode: WordGridMode
    private(set) var board: [[Character]]
    private(set) var selectedPath: [WordGridPosition] = []
    private(set) var foundWords: [String] = []
    private(set) var score = 0
    private(set) var state: WordGridState = .playing
    private(set) var message: String?
    private(set) var pendingSaveState: WordGridSaveState?
    private(set) var remainingSeconds: Double
    private var gameStats: GameStats?
    private let userDefaults: UserDefaults
    private var timer: Timer?

    var submitCount = 0
    var invalidCount = 0
    var finishCount = 0

    init(mode: WordGridMode? = nil, userDefaults: UserDefaults = .standard) {
        let selectedMode = mode ?? Self.lastMode(userDefaults: userDefaults)
        self.mode = selectedMode
        self.userDefaults = userDefaults
        self.board = WordGridEngine.makeBoard()
        self.remainingSeconds = selectedMode == .timed ? WordGridEngine.timedDuration : 0
        loadPendingSave()
        startTimerIfNeeded()
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }

    var currentWord: String {
        WordGridEngine.word(for: selectedPath, board: board)
    }

    var sortedFoundWords: [String] {
        foundWords.sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs < rhs }
            return lhs.count > rhs.count
        }
    }

    func attachGameStats(_ stats: GameStats) {
        self.gameStats = stats
    }

    func select(_ position: WordGridPosition) {
        guard state == .playing else { return }
        if selectedPath.last == position {
            return
        }
        if WordGridEngine.canAppend(position, to: selectedPath) {
            selectedPath.append(position)
            message = nil
        }
    }

    func clearSelection() {
        selectedPath.removeAll()
    }

    func submitSelection() {
        let word = WordLexicon.normalize(currentWord)
        guard state == .playing, !word.isEmpty else { return }
        defer { selectedPath.removeAll() }

        guard word.count >= 3 else {
            reject(String(localized: "Too short"))
            return
        }
        guard !foundWords.contains(word) else {
            reject(String(localized: "Already found"))
            return
        }
        guard WordLexicon.isValidGridWord(word) else {
            reject(String(localized: "Not in word list"))
            return
        }

        foundWords.append(word)
        score += WordGridEngine.score(word)
        submitCount += 1
        message = String(localized: "+\(WordGridEngine.score(word))")
        saveCurrentState()
    }

    func finish() {
        guard state == .playing else { return }
        state = .finished
        timer?.invalidate()
        timer = nil
        finishCount += 1
        try? gameStats?.record(
            gameKind: .wordGrid,
            mode: mode.rawValue,
            outcome: .win,
            score: score
        )
        clearSave()
    }

    func restart() {
        board = WordGridEngine.makeBoard()
        selectedPath = []
        foundWords = []
        score = 0
        state = .playing
        message = nil
        remainingSeconds = mode == .timed ? WordGridEngine.timedDuration : 0
        clearSave()
        startTimerIfNeeded()
    }

    func setMode(_ newMode: WordGridMode) {
        mode = newMode
        userDefaults.set(newMode.rawValue, forKey: Self.lastModeKey)
        restart()
        loadPendingSave()
    }

    func restoreState(_ saved: WordGridSaveState) {
        guard let restoredMode = WordGridMode(rawValue: saved.mode) else {
            discardSaveAndLoadNew()
            return
        }
        let rows = saved.boardRows.map { Array($0) }
        guard rows.count == WordGridEngine.size, rows.allSatisfy({ $0.count == WordGridEngine.size }) else {
            discardSaveAndLoadNew()
            return
        }
        mode = restoredMode
        board = rows
        foundWords = saved.foundWords
        score = saved.score
        remainingSeconds = saved.remainingSeconds
        selectedPath = []
        state = .playing
        pendingSaveState = nil
        startTimerIfNeeded()
    }

    func discardSaveAndLoadNew() {
        clearSave()
        pendingSaveState = nil
        restart()
    }

    func saveCurrentState() {
        guard state == .playing, (!foundWords.isEmpty || !selectedPath.isEmpty) else { return }
        let snapshot = WordGridSaveState(
            boardRows: board.map { String($0) },
            foundWords: foundWords,
            mode: mode.rawValue,
            score: score,
            remainingSeconds: remainingSeconds,
            savedAt: .now
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: WordGridSaveState.key(mode: mode))
        }
    }

    private func reject(_ text: String) {
        message = text
        invalidCount += 1
    }

    private func startTimerIfNeeded() {
        timer?.invalidate()
        guard mode == .timed, state == .playing else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .playing else { return }
                self.remainingSeconds = max(0, self.remainingSeconds - 1)
                if self.remainingSeconds <= 0 {
                    self.finish()
                }
            }
        }
    }

    private func loadPendingSave() {
        let key = WordGridSaveState.key(mode: mode)
        guard let data = userDefaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(WordGridSaveState.self, from: data),
              !saved.foundWords.isEmpty else { return }
        pendingSaveState = saved
    }

    private func clearSave() {
        userDefaults.removeObject(forKey: WordGridSaveState.key(mode: mode))
    }

    private static let lastModeKey = "wordGrid.lastMode"

    private static func lastMode(userDefaults: UserDefaults) -> WordGridMode {
        guard let raw = userDefaults.string(forKey: lastModeKey),
              let mode = WordGridMode(rawValue: raw) else { return .timed }
        return mode
    }
}
