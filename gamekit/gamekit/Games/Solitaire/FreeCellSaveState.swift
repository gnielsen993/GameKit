import Foundation

struct FreeCellSaveState: Codable {
    let board: FreeCellBoard
    let dealNumber: Int
    let difficulty: String?   // FreeCellDifficulty rawValue; nil = custom deal
    let elapsedSeconds: TimeInterval
    let savedAt: Date
    /// Undo history, oldest first. Optional so pre-existing saves decode.
    /// Capped for the same reason as Klondike's — see
    /// `SolitaireSaveState.persistedHistoryDepth`.
    var history: [FreeCellMove]? = nil

    static let persistedHistoryDepth = 20

    static let currentKey = "freeCell.saveState.current"

    static func clearAll(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: currentKey)
    }
}
