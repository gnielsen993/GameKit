import Foundation

struct FreeCellSaveState: Codable {
    let board: FreeCellBoard
    let dealNumber: Int
    let difficulty: String?   // FreeCellDifficulty rawValue; nil = custom deal
    let elapsedSeconds: TimeInterval
    let savedAt: Date

    static let currentKey = "freeCell.saveState.current"

    static func clearAll(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: currentKey)
    }
}
