import Foundation
import MathCrosswordCore

enum MathCrosswordHintCopy {
    static func explanation(for hint: MathCrosswordActiveHint) -> String {
        let targets = hint.placements.keys.sorted().map { position in
            "row \(position.row + 1), column \(position.col + 1)"
        }.joined(separator: " and ")
        return "Use the equation through the highlighted blanks. The remaining number bank leaves only one arithmetic combination for \(targets)."
    }

    static func reveal(for placements: [GridPos: Int]) -> String {
        let values = placements.keys.sorted().compactMap { position -> String? in
            guard let value = placements[position] else { return nil }
            return "\(value) at row \(position.row + 1), column \(position.col + 1)"
        }
        return values.joined(separator: "; ") + "."
    }
}
