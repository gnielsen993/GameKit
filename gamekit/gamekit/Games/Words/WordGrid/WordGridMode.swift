import Foundation

enum WordGridMode: String, CaseIterable, Codable, Sendable {
    case timed
    case relaxed

    var displayName: String {
        switch self {
        case .timed: return String(localized: "Timed")
        case .relaxed: return String(localized: "Relaxed")
        }
    }
}
