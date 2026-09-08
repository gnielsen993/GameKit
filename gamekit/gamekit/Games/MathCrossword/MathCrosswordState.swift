import Foundation
import MathCrosswordCore

enum MathCrosswordState: Equatable {
    case loading
    case playing
    case won
    case failed(String)
}

struct MathCrosswordActiveHint: Codable, Equatable {
    let equationIndex: Int
    let placements: [GridPos: Int]
    var isRevealed = false
}
