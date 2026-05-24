import Foundation

struct MinesweeperSaveState: Codable {
    let board: MinesweeperBoard
    let difficulty: MinesweeperDifficulty
    let flaggedCount: Int
    let elapsedSeconds: TimeInterval
    let savedAt: Date

    static func key(difficulty: MinesweeperDifficulty) -> String {
        "mines.saveState.\(difficulty.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for d in MinesweeperDifficulty.allCases {
            userDefaults.removeObject(forKey: key(difficulty: d))
        }
    }
}
