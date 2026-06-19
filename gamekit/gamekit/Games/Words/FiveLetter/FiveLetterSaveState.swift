import Foundation

struct FiveLetterGuess: Codable, Hashable, Sendable {
    let word: String
    let marks: [FiveLetterMark]
}

struct FiveLetterSaveState: Codable {
    let answer: String
    let guesses: [FiveLetterGuess]
    let mode: String
    let puzzleId: String
    let elapsedSeconds: Double
    let savedAt: Date

    static func key(mode: FiveLetterMode) -> String {
        "fiveLetter.saveState.\(mode.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for mode in FiveLetterMode.allCases {
            userDefaults.removeObject(forKey: key(mode: mode))
        }
        userDefaults.removeObject(forKey: FiveLetterDailyResult.key)
    }
}

struct FiveLetterDailyResult: Codable {
    let answer: String
    let guesses: [FiveLetterGuess]
    let puzzleId: String
    let state: FiveLetterState
    let elapsedSeconds: Double
    let completedAt: Date

    static let key = "fiveLetter.dailyResult"
}
