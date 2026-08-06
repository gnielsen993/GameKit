import Foundation

struct NonogramSaveState: Codable {
    let puzzleId: String
    let puzzleGrid: String
    let puzzleTitle: String
    let cells: [NonogramCellState]
    let size: Int
    let difficulty: String
    let gameMode: String
    let livesRemaining: Int
    let lockedCellIndices: [Int]
    let elapsedSeconds: TimeInterval
    let savedAt: Date
    /// Assists used so far. Optional with a nil default so saves written
    /// before assists existed still decode; nil reads as zero.
    var assistsUsed: Int? = nil
    /// nil/"playing" for legacy ranked saves; "gameOver" retains the choice
    /// to keep solving and "practice" restores an unranked continuation.
    var continuationState: String? = nil

    static func key(difficulty: NonogramDifficulty, gameMode: NonogramGameMode) -> String {
        "nonogram.saveState.\(difficulty.rawValue).\(gameMode.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for d in NonogramDifficulty.allCases {
            for m in NonogramGameMode.allCases {
                userDefaults.removeObject(forKey: key(difficulty: d, gameMode: m))
            }
        }
    }
}
