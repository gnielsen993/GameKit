import Foundation

public enum Solver {
    /// Counts assignments of the bank multiset. A search-budget hit is returned as
    /// `cap`, so a generator never accepts an indeterminate puzzle as unique.
    public static func countSolutions(puzzle: TallyPuzzle, cap: Int, nodeLimit: Int = 200_000) -> Int {
        guard cap > 0 else { return 0 }
        var assignments = Dictionary(uniqueKeysWithValues: puzzle.givens.compactMap { cell in puzzle.solution[cell].map { (cell, $0) } })
        var inventory = multiset(puzzle.bank)
        var count = 0
        var visited = 0
        var exceededBudget = false

        func isConsistent() -> Bool {
            puzzle.equations.allSatisfy { equation in
                guard let a = assignments[equation.a], let b = assignments[equation.b], let result = assignments[equation.r] else { return true }
                return equation.holds(a, b, result)
            }
        }
        func visit(_ index: Int) {
            guard count < cap, !exceededBudget, !Task.isCancelled else { return }
            visited += 1
            if visited > nodeLimit { exceededBudget = true; return }
            guard index < puzzle.blanks.count else { count += 1; return }
            let cell = puzzle.blanks[index]
            for value in inventory.keys.sorted() where inventory[value, default: 0] > 0 {
                assignments[cell] = value
                inventory[value, default: 0] -= 1
                if isConsistent() { visit(index + 1) }
                assignments[cell] = nil
                inventory[value, default: 0] += 1
            }
        }
        visit(0)
        return exceededBudget || Task.isCancelled ? cap : count
    }

    public struct ChainStep: Codable, Sendable, Equatable {
        public let equationIndex: Int
        public let placements: [GridPos: Int]

        public init(equationIndex: Int, placements: [GridPos: Int]) {
            self.equationIndex = equationIndex
            self.placements = placements
        }
    }

    /// Returns deductions only when the current placements have a proven
    /// completion. Alternative solutions are valid premises too.
    public static func forcedChain(puzzle: TallyPuzzle, placements: [GridPos: Int]) -> [ChainStep]? {
        guard trusted(puzzle: puzzle, placements: placements) else { return nil }
        var assignments = placements
        for cell in puzzle.givens { assignments[cell] = puzzle.solution[cell] }
        var inventory = multiset(puzzle.bank)
        for value in placements.values { inventory[value, default: 0] -= 1 }

        var steps: [ChainStep] = []
        while assignments.count < puzzle.solution.count {
            var advanced = false
            for (index, equation) in puzzle.equations.enumerated() {
                let unknown = equation.numberCells.filter { assignments[$0] == nil }
                guard !unknown.isEmpty else { continue }
                let fills = uniqueFills(equation: equation, unknown: unknown, assignments: assignments, inventory: inventory)
                guard fills.count == 1, let fill = fills.first else { continue }
                for (cell, value) in fill {
                    assignments[cell] = value
                    inventory[value, default: 0] -= 1
                }
                steps.append(ChainStep(equationIndex: index, placements: fill))
                advanced = true
                break
            }
            guard advanced else { return nil }
        }
        return steps
    }

    public static func nextHint(puzzle: TallyPuzzle, placements: [GridPos: Int]) -> ChainStep? {
        forcedChain(puzzle: puzzle, placements: placements)?.first
    }
}

private extension Solver {
    static func trusted(puzzle: TallyPuzzle, placements: [GridPos: Int]) -> Bool {
        assessCompletion(puzzle: puzzle, placements: placements).status == .solvable
    }

    static func uniqueFills(
        equation: Equation,
        unknown: [GridPos],
        assignments: [GridPos: Int],
        inventory: [Int: Int]
    ) -> [[GridPos: Int]] {
        var results: [[GridPos: Int]] = []
        let values = inventory.filter { $0.value > 0 }.keys.sorted()
        var candidate: [Int] = []

        func tryCandidate() {
            let needs = multiset(candidate)
            guard needs.allSatisfy({ inventory[$0.key, default: 0] >= $0.value }) else { return }
            var trial = assignments
            for (cell, value) in zip(unknown, candidate) { trial[cell] = value }
            guard let a = trial[equation.a], let b = trial[equation.b], let result = trial[equation.r], equation.holds(a, b, result) else { return }
            results.append(Dictionary(uniqueKeysWithValues: zip(unknown, candidate)))
        }
        func enumerate(_ remaining: Int) {
            guard results.count < 2 else { return }
            guard remaining > 0 else { tryCandidate(); return }
            for value in values {
                candidate.append(value)
                enumerate(remaining - 1)
                candidate.removeLast()
                if results.count >= 2 { return }
            }
        }
        enumerate(unknown.count)
        return results
    }
}
