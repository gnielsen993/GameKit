import Foundation

/// Gameplay feedback uses only arithmetic the player can see on the board.
public struct PlacementValidation: Equatable, Sendable {
    public let conflictingCells: Set<GridPos>
    public var hasBrokenEquation: Bool { !conflictingCells.isEmpty }
}

extension Solver {
    /// An incomplete equation stays neutral, even if no completion exists.
    /// Only givens read from the saved solution; placed tiles never compare to it.
    public static func validatePlacements(
        puzzle: TallyPuzzle,
        placements: [GridPos: Int]
    ) -> PlacementValidation {
        var values = placements
        for given in puzzle.givens { values[given] = puzzle.solution[given] }
        let broken = puzzle.equations.filter { equation in
            guard let a = values[equation.a], let b = values[equation.b], let r = values[equation.r] else { return false }
            return !equation.holds(a, b, r)
        }
        return PlacementValidation(conflictingCells: Set(broken.flatMap(\.numberCells)).intersection(placements.keys))
    }
}
