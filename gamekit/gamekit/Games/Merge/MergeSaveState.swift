import Foundation

struct MergeSaveState: Codable {
    let board: MergeBoard
    let score: Int
    let mode: String   // MergeMode.rawValue
    let hasContinuedPastWin: Bool
    let savedAt: Date

    static func key(mode: MergeMode) -> String {
        "merge.saveState.\(mode.rawValue)"
    }

    static func clearAll(userDefaults: UserDefaults = .standard) {
        for m in MergeMode.allCases {
            userDefaults.removeObject(forKey: key(mode: m))
        }
    }
}
