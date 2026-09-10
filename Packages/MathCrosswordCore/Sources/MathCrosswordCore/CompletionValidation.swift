import Foundation

struct CompletionValidation: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case solvable
        case impossible
        /// Exhausting the bounded search is not proof that the player is wrong.
        case undetermined
    }

    let status: Status
    /// These cells participate in a conflict; no individual tile is blamed.
    let conflictingCells: Set<GridPos>
    let hasBrokenEquation: Bool
}

extension Solver {
    /// Checks visible equations and the remaining bank, accepting any solution.
    /// The saved solution is used only as a quick witness when it still fits.
    static func assessCompletion(
        puzzle: TallyPuzzle,
        placements: [GridPos: Int],
        nodeLimit: Int = 20_000
    ) -> CompletionValidation {
        let blanks = Set(puzzle.blanks)
        var inventory = multiset(puzzle.bank)
        for value in placements.values { inventory[value, default: 0] -= 1 }
        guard placements.keys.allSatisfy(blanks.contains), inventory.values.allSatisfy({ $0 >= 0 }) else {
            return CompletionValidation(status: .impossible, conflictingCells: Set(placements.keys), hasBrokenEquation: false)
        }
        var assignments = placements
        for given in puzzle.givens { assignments[given] = puzzle.solution[given] }
        let broken = puzzle.equations.filter { equation in
            guard let a = assignments[equation.a], let b = assignments[equation.b], let r = assignments[equation.r] else { return false }
            return !equation.holds(a, b, r)
        }
        if !broken.isEmpty {
            let cells = Set(broken.flatMap(\.numberCells)).intersection(placements.keys)
            return CompletionValidation(status: .impossible, conflictingCells: cells, hasBrokenEquation: true)
        }
        if placements.allSatisfy({ puzzle.solution[$0.key] == $0.value }) {
            return CompletionValidation(status: .solvable, conflictingCells: [], hasBrokenEquation: false)
        }
        var search = CompletionSearch(puzzle: puzzle, assignments: assignments, inventory: inventory, budget: nodeLimit)
        let status = search.visit()
        return CompletionValidation(
            status: status,
            conflictingCells: status == .impossible ? Set(placements.keys) : [],
            hasBrokenEquation: false
        )
    }
}

private struct CompletionSearch {
    let puzzle: TallyPuzzle
    var assignments: [GridPos: Int]
    var inventory: [Int: Int]
    var budget: Int

    mutating func visit() -> CompletionValidation.Status {
        guard !Task.isCancelled, budget > 0 else { return .undetermined }
        budget -= 1
        // Start with the equation closest to completion so wrong branches end
        // early. Every branch consumes the bank multiset, including duplicates.
        let pending = puzzle.equations.map { equation in
            equation.numberCells.filter { assignments[$0] == nil }
        }.filter { !$0.isEmpty }
        guard let position = pending.min(by: { $0.count < $1.count })?.first else { return .solvable }
        for value in inventory.keys.sorted() where inventory[value, default: 0] > 0 {
            guard budget > 0, !Task.isCancelled else { return .undetermined }
            budget -= 1
            assignments[position] = value
            inventory[value, default: 0] -= 1
            let consistent = puzzle.equations.allSatisfy { equation in
                guard let a = assignments[equation.a], let b = assignments[equation.b], let r = assignments[equation.r] else { return true }
                return equation.holds(a, b, r)
            }
            let result: CompletionValidation.Status = consistent ? visit() : .impossible
            assignments[position] = nil
            inventory[value, default: 0] += 1
            if result != .impossible { return result }
        }
        return .impossible
    }
}
