import Foundation

enum FreeCellDifficulty: String, CaseIterable, Hashable, Sendable, Codable {
    case easy, medium, hard, expert

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .expert: return "Expert"
        }
    }
}

enum FreeCellMode: Hashable, Sendable {
    case random(FreeCellDifficulty)
    case deal(Int)      // specific deal number 1–32 000
    case enterDeal      // show deal-number picker on launch
}
