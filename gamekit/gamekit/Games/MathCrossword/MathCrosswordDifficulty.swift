import Foundation
import MathCrosswordCore

enum MathCrosswordDifficulty: String, CaseIterable, Codable, Sendable, Hashable {
    case easy
    case medium
    case hard

    init?(routeValue: String?) {
        guard let routeValue else {
            self = .easy
            return
        }
        self.init(rawValue: routeValue.lowercased())
    }

    var displayName: String { rawValue.capitalized }

    var coreDifficulty: TallyDifficulty {
        switch self {
        case .easy: .easy
        case .medium: .medium
        case .hard: .hard
        }
    }
}
