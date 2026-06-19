import Foundation

struct WordGridSaveState: Codable {
    let boardRows: [String]
    let foundWords: [String]
    let mode: String
    let score: Int
    let remainingSeconds: Double
    let savedAt: Date

    static func key(mode: WordGridMode) -> String {
        "wordGrid.saveState.\(mode.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for mode in WordGridMode.allCases {
            userDefaults.removeObject(forKey: key(mode: mode))
        }
    }
}
