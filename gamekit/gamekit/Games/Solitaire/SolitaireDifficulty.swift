import Foundation

enum SolitaireDifficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case easy   // Draw 1
    case medium // Draw 2
    case hard   // Draw 3

    var drawCount: Int {
        switch self {
        case .easy:   return 1
        case .medium: return 2
        case .hard:   return 3
        }
    }

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var detail: String {
        switch self {
        case .easy:   return "Draw 1"
        case .medium: return "Draw 2"
        case .hard:   return "Draw 3"
        }
    }
}
