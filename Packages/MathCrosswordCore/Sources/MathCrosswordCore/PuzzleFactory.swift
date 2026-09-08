import Foundation

public enum PuzzleFactory {
    public static let generatorVersion = 1

    public enum GenerationError: Error, Equatable, Sendable {
        case attemptBudgetExhausted(difficulty: TallyDifficulty, seed: UInt64, attempts: Int)
        case cancelled
    }

    public static func generate(
        difficulty: TallyDifficulty,
        seed: UInt64 = UInt64.random(in: 1..<UInt64.max),
        maximumAttempts: Int = 8
    ) throws -> TallyPuzzle {
        var rng = SeededGenerator(seed: seed)
        let config = GenerationConfig.forDifficulty(difficulty)
        let attemptBudget = max(1, maximumAttempts)
        for _ in 0..<attemptBudget {
            if Task.isCancelled { throw GenerationError.cancelled }
            let skeleton = LayoutTemplates.skeleton(for: difficulty, rng: &rng)
            guard let candidate = fillValues(skeleton: skeleton, config: config, rng: &rng),
                  let puzzle = chooseGivens(seed: seed, difficulty: difficulty, candidate: candidate, config: config, rng: &rng) else {
                continue
            }
            return puzzle
        }
        throw GenerationError.attemptBudgetExhausted(difficulty: difficulty, seed: seed, attempts: attemptBudget)
    }
}

private struct GenerationConfig {
    let maxOperand: Int
    let givenFraction: Double
    let minDistinctOps: Int
    let maxValue: Int
    let blanks: ClosedRange<Int>
    let entryPoints: ClosedRange<Int>
    let pairSteps: ClosedRange<Int>

    static func forDifficulty(_ difficulty: TallyDifficulty) -> GenerationConfig {
        switch difficulty {
        case .easy: return GenerationConfig(maxOperand: 12, givenFraction: 0.52, minDistinctOps: 2, maxValue: 50, blanks: 5...7, entryPoints: 2...99, pairSteps: 0...1)
        case .medium: return GenerationConfig(maxOperand: 20, givenFraction: 0.45, minDistinctOps: 3, maxValue: 120, blanks: 10...13, entryPoints: 1...3, pairSteps: 1...99)
        case .hard: return GenerationConfig(maxOperand: 30, givenFraction: 0.38, minDistinctOps: 3, maxValue: 200, blanks: 13...16, entryPoints: 1...2, pairSteps: 2...99)
        }
    }
}

private func fillValues(skeleton: LayoutTemplates.Skeleton, config: GenerationConfig, rng: inout SeededGenerator) -> ([Equation], [GridPos: Int])? {
    for _ in 0..<400 {
        if Task.isCancelled { return nil }
        var values: [GridPos: Int] = [:]
        var equations: [Equation] = []
        for spec in skeleton.equations {
            guard let solved = solve(spec: spec, known: [values[spec.a], values[spec.b], values[spec.r]], config: config, rng: &rng) else {
                equations = []
                break
            }
            values[spec.a] = solved.a
            values[spec.b] = solved.b
            values[spec.r] = solved.r
            equations.append(Equation(a: spec.a, opCell: operatorCell(for: spec), b: spec.b, eqCell: equalsCell(for: spec), r: spec.r, op: solved.op))
        }
        guard !equations.isEmpty, equations.count == skeleton.equations.count else { continue }
        let valuesAreVaried = Set(equations.map(\.op)).count >= config.minDistinctOps
        let maximumRepeats = multiset(values.values).values.max() ?? 0
        let factFamilies = equations.map { [values[$0.a]!, values[$0.b]!, values[$0.r]!].sorted() }
        guard valuesAreVaried, maximumRepeats <= 3, Set(factFamilies).count == factFamilies.count else { continue }
        return (equations, values)
    }
    return nil
}

private func solve(
    spec: (a: GridPos, b: GridPos, r: GridPos, across: Bool),
    known: [Int?],
    config: GenerationConfig,
    rng: inout SeededGenerator
) -> (a: Int, b: Int, r: Int, op: Op)? {
    for _ in 0..<40 {
        let op = Op.allCases.randomElement(using: &rng)!
        var a = known[0]
        var b = known[1]
        var result = known[2]
        switch (a, b, result) {
        case (nil, nil, nil): (a, b) = randomOperands(op: op, config: config, rng: &rng); result = a.flatMap { left in b.flatMap { op.apply(left, $0) } }
        case let (.some(left), nil, nil): b = partner(for: left, op: op, config: config, rng: &rng); result = b.flatMap { op.apply(left, $0) }
        case let (nil, .some(right), nil): a = partnerA(for: right, op: op, config: config, rng: &rng); result = a.flatMap { op.apply($0, right) }
        case let (nil, nil, .some(total)): (a, b) = operands(for: total, op: op, config: config, rng: &rng)
        case let (.some(left), .some(right), nil): result = op.apply(left, right)
        case let (.some(left), nil, .some(total)): b = solveB(a: left, result: total, op: op)
        case let (nil, .some(right), .some(total)): a = solveA(b: right, result: total, op: op)
        case let (.some(left), .some(right), .some(total)) where op.apply(left, right) == total: break
        case (.some, .some, .some): continue
        }
        guard let a, let b, let result,
              (1...config.maxValue).contains(a), (1...config.maxValue).contains(b), (1...config.maxValue).contains(result),
              op.apply(a, b) == result else { continue }
        return (a, b, result, op)
    }
    return nil
}

private func chooseGivens(seed: UInt64, difficulty: TallyDifficulty, candidate: ([Equation], [GridPos: Int]), config: GenerationConfig, rng: inout SeededGenerator) -> TallyPuzzle? {
    let cells = candidate.1.keys.sorted()
    for _ in 0..<30 {
        if Task.isCancelled { return nil }
        let givens = Set(cells.filter { _ in Double.random(in: 0...1, using: &rng) < config.givenFraction })
        let blanks = cells.filter { !givens.contains($0) }
        let entryPointCount = candidate.0.count { equation in equation.numberCells.count { !givens.contains($0) } == 1 }
        guard config.blanks.contains(blanks.count), config.entryPoints.contains(entryPointCount),
              let puzzle = try? TallyPuzzle(seed: seed, difficulty: difficulty, equations: candidate.0, solution: candidate.1, givens: givens, bank: blanks.compactMap { candidate.1[$0] }.shuffled(using: &rng)),
              Solver.countSolutions(puzzle: puzzle, cap: 2) == 1,
              let chain = Solver.forcedChain(puzzle: puzzle, placements: [:]),
              config.pairSteps.contains(chain.count { $0.placements.count >= 2 }) else { continue }
        return puzzle
    }
    return nil
}

private func operatorCell(for spec: (a: GridPos, b: GridPos, r: GridPos, across: Bool)) -> GridPos {
    spec.across ? GridPos(row: spec.a.row, col: spec.a.col + 1) : GridPos(row: spec.a.row + 1, col: spec.a.col)
}

private func equalsCell(for spec: (a: GridPos, b: GridPos, r: GridPos, across: Bool)) -> GridPos {
    spec.across ? GridPos(row: spec.a.row, col: spec.a.col + 3) : GridPos(row: spec.a.row + 3, col: spec.a.col)
}

private func randomOperands(op: Op, config: GenerationConfig, rng: inout SeededGenerator) -> (Int?, Int?) {
    switch op {
    case .add: return (Int.random(in: 1...config.maxOperand, using: &rng), Int.random(in: 1...config.maxOperand, using: &rng))
    case .sub: let b = Int.random(in: 1...config.maxOperand, using: &rng); return (b + Int.random(in: 1...config.maxOperand, using: &rng), b)
    case .mul: return (Int.random(in: 2...min(12, config.maxOperand), using: &rng), Int.random(in: 2...min(12, config.maxOperand), using: &rng))
    case .div: let b = Int.random(in: 2...10, using: &rng); return (b * Int.random(in: 2...10, using: &rng), b)
    }
}

private func partner(for a: Int, op: Op, config: GenerationConfig, rng: inout SeededGenerator) -> Int? {
    switch op {
    case .add: return Int.random(in: 1...config.maxOperand, using: &rng)
    case .sub: return a > 1 ? Int.random(in: 1...(a - 1), using: &rng) : nil
    case .mul: return a <= 30 ? Int.random(in: 2...12, using: &rng) : nil
    case .div: return a >= 4 ? (2...(a / 2)).filter { a % $0 == 0 }.randomElement(using: &rng) : nil
    }
}

private func partnerA(for b: Int, op: Op, config: GenerationConfig, rng: inout SeededGenerator) -> Int? {
    switch op {
    case .add: return Int.random(in: 1...config.maxOperand, using: &rng)
    case .sub: return b + Int.random(in: 1...config.maxOperand, using: &rng)
    case .mul: return b <= 12 ? Int.random(in: 2...12, using: &rng) : nil
    case .div: return (2...10).contains(b) ? b * Int.random(in: 2...10, using: &rng) : nil
    }
}

private func operands(for result: Int, op: Op, config: GenerationConfig, rng: inout SeededGenerator) -> (Int?, Int?) {
    switch op {
    case .add: guard result > 1 else { return (nil, nil) }; let a = Int.random(in: 1...(result - 1), using: &rng); return (a, result - a)
    case .sub: let b = Int.random(in: 1...config.maxOperand, using: &rng); return (result + b, b)
    case .mul: return (2...12).compactMap { factor in result % factor == 0 && (2...12).contains(result / factor) ? (factor, result / factor) : nil }.randomElement(using: &rng) ?? (nil, nil)
    case .div: guard result >= 2 else { return (nil, nil) }; let b = Int.random(in: 2...10, using: &rng); return (result * b, b)
    }
}

private func solveB(a: Int, result: Int, op: Op) -> Int? {
    switch op {
    case .add: return result - a > 0 ? result - a : nil
    case .sub: return a - result > 0 ? a - result : nil
    case .mul: return a != 0 && result % a == 0 && result / a >= 2 ? result / a : nil
    case .div: return result >= 2 && a % result == 0 && a / result >= 2 ? a / result : nil
    }
}

private func solveA(b: Int, result: Int, op: Op) -> Int? {
    switch op {
    case .add: return result - b > 0 ? result - b : nil
    case .sub: return result + b
    case .mul: return b >= 2 && result % b == 0 && result / b >= 2 ? result / b : nil
    case .div: return b >= 2 && result >= 2 ? result * b : nil
    }
}
