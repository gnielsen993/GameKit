import Foundation

struct SolitaireSaveState: Codable {
    let board: SolitaireBoard
    let dealNumber: Int
    let difficulty: SolitaireDifficulty
    let moveCount: Int
    let elapsedSeconds: TimeInterval
    let savedAt: Date

    static func key(difficulty: SolitaireDifficulty) -> String {
        "solitaire.saveState.\(difficulty.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for d in SolitaireDifficulty.allCases {
            userDefaults.removeObject(forKey: key(difficulty: d))
        }
    }
}
