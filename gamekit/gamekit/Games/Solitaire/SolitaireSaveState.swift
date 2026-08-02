import Foundation

struct SolitaireSaveState: Codable {
    let board: SolitaireBoard
    let dealNumber: Int
    let difficulty: SolitaireDifficulty
    let moveCount: Int
    let elapsedSeconds: TimeInterval
    let savedAt: Date
    /// Undo history, oldest first. Optional so saves written before this
    /// field existed still decode — they simply resume with no undo, exactly
    /// as they behaved when they were written.
    ///
    /// Capped independently of the 50-deep in-memory history: a full board is
    /// ~3 KB of JSON and this lives in UserDefaults, so the whole stack is not
    /// worth persisting. Twenty moves is far past the point where anyone is
    /// still unwinding a mistake.
    var history: [SolitaireBoard]? = nil

    static let persistedHistoryDepth = 20

    static func key(difficulty: SolitaireDifficulty) -> String {
        "solitaire.saveState.\(difficulty.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for d in SolitaireDifficulty.allCases {
            userDefaults.removeObject(forKey: key(difficulty: d))
        }
    }
}
