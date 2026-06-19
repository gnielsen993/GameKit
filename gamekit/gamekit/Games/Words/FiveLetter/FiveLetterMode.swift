import Foundation

enum FiveLetterMode: String, CaseIterable, Codable, Sendable {
    case daily
    case unlimited

    var displayName: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .unlimited: return String(localized: "Unlimited")
        }
    }
}
