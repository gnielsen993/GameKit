import Foundation
import MathCrosswordCore

struct MathCrosswordSaveState: Codable {
    static let schemaVersion = 1

    let schemaVersion: Int
    /// Full verified puzzle plus placements/history, never a seed-only resume.
    let session: MathCrosswordSession
    let elapsedSeconds: TimeInterval
    let assistsUsed: Int
    let activeHint: MathCrosswordActiveHint?
    /// A restart after requesting help cannot turn the same puzzle into a record run.
    let countsTowardRecords: Bool
    let savedAt: Date

    static func key(difficulty: MathCrosswordDifficulty) -> String {
        "mathCrossword.saveState.\(difficulty.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for difficulty in MathCrosswordDifficulty.allCases {
            userDefaults.removeObject(forKey: key(difficulty: difficulty))
        }
    }
}
