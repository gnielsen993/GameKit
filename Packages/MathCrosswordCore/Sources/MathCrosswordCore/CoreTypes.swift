import Foundation

public enum Op: String, CaseIterable, Codable, Sendable {
    case add = "+"
    case sub = "−"
    case mul = "×"
    case div = "÷"

    public func apply(_ a: Int, _ b: Int) -> Int? {
        switch self {
        case .add:
            let result = a.addingReportingOverflow(b)
            return result.overflow ? nil : result.partialValue
        case .sub:
            let result = a.subtractingReportingOverflow(b)
            return result.overflow ? nil : result.partialValue
        case .mul:
            let result = a.multipliedReportingOverflow(by: b)
            return result.overflow ? nil : result.partialValue
        case .div:
            guard b != 0, !(a == Int.min && b == -1), a % b == 0 else { return nil }
            return a / b
        }
    }
}

public struct GridPos: Hashable, Codable, Sendable, Comparable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    public static func < (lhs: GridPos, rhs: GridPos) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }
}

public struct Equation: Codable, Sendable, Hashable {
    public let a: GridPos
    public let opCell: GridPos
    public let b: GridPos
    public let eqCell: GridPos
    public let r: GridPos
    public let op: Op

    public init(a: GridPos, opCell: GridPos, b: GridPos, eqCell: GridPos, r: GridPos, op: Op) {
        self.a = a
        self.opCell = opCell
        self.b = b
        self.eqCell = eqCell
        self.r = r
        self.op = op
    }

    public var numberCells: [GridPos] { [a, b, r] }

    public func holds(_ va: Int, _ vb: Int, _ vr: Int) -> Bool {
        op.apply(va, vb) == vr
    }
}

public enum TallyDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    public var id: String { rawValue }
}

public enum MathCrosswordValidationError: Error, Equatable, Sendable {
    case emptyPuzzle
    case invalidCoordinate(GridPos)
    case duplicateEquationCell(GridPos)
    case missingSolution(GridPos)
    case unexpectedSolution(GridPos)
    case invalidEquation(Int)
    case invalidGiven(GridPos)
    case invalidBank
    case nonPositiveValue(GridPos)
}

/// A verified number-bank crossword. `solution` is retained for deterministic
/// generation, local validation, and a user-requested reveal; application code
/// should not render it during ordinary play.
public struct TallyPuzzle: Codable, Sendable {
    /// Generated layouts stay below this bound. It also prevents malformed saved
    /// data from producing an unbounded consumer grid on restore.
    public static let maximumGridDimension = 64
    public let seed: UInt64
    public let difficulty: TallyDifficulty
    public let equations: [Equation]
    public let solution: [GridPos: Int]
    public let givens: Set<GridPos>
    public let bank: [Int]

    public init(
        seed: UInt64,
        difficulty: TallyDifficulty,
        equations: [Equation],
        solution: [GridPos: Int],
        givens: Set<GridPos>,
        bank: [Int]
    ) throws {
        self.seed = seed
        self.difficulty = difficulty
        self.equations = equations
        self.solution = solution
        self.givens = givens
        self.bank = bank
        try validate()
    }

    public var blanks: [GridPos] {
        solution.keys.filter { !givens.contains($0) }.sorted()
    }

    public var rowCount: Int {
        (allCells.map(\.row).max() ?? -1) + 1
    }

    public var colCount: Int {
        (allCells.map(\.col).max() ?? -1) + 1
    }

    public func validate() throws {
        guard !equations.isEmpty else { throw MathCrosswordValidationError.emptyPuzzle }
        let numberCells = Set(equations.flatMap(\.numberCells))
        let fixedCells = equations.flatMap { [$0.opCell, $0.eqCell] }
        let all = Array(numberCells) + fixedCells
        for cell in all where !(0..<Self.maximumGridDimension).contains(cell.row) || !(0..<Self.maximumGridDimension).contains(cell.col) {
            throw MathCrosswordValidationError.invalidCoordinate(cell)
        }
        guard Set(fixedCells).count == fixedCells.count,
              numberCells.isDisjoint(with: Set(fixedCells)) else {
            let duplicates = Dictionary(grouping: all, by: { $0 }).first { $0.value.count > 1 }
            throw MathCrosswordValidationError.duplicateEquationCell(duplicates!.key)
        }
        for equation in equations where Set(equation.numberCells).count != equation.numberCells.count {
            let duplicate = Dictionary(grouping: equation.numberCells, by: { $0 }).first { $0.value.count > 1 }!.key
            throw MathCrosswordValidationError.duplicateEquationCell(duplicate)
        }
        for cell in numberCells where solution[cell] == nil {
            throw MathCrosswordValidationError.missingSolution(cell)
        }
        for cell in solution.keys where !numberCells.contains(cell) {
            throw MathCrosswordValidationError.unexpectedSolution(cell)
        }
        for (cell, value) in solution where value <= 0 {
            throw MathCrosswordValidationError.nonPositiveValue(cell)
        }
        for (index, equation) in equations.enumerated() {
            guard let a = solution[equation.a], let b = solution[equation.b], let r = solution[equation.r],
                  equation.holds(a, b, r) else {
                throw MathCrosswordValidationError.invalidEquation(index)
            }
        }
        for given in givens where solution[given] == nil {
            throw MathCrosswordValidationError.invalidGiven(given)
        }
        guard multiset(bank) == multiset(blanks.compactMap { solution[$0] }) else {
            throw MathCrosswordValidationError.invalidBank
        }
    }

    private var allCells: [GridPos] {
        equations.flatMap { [$0.a, $0.opCell, $0.b, $0.eqCell, $0.r] }
    }
}

func multiset(_ values: some Sequence<Int>) -> [Int: Int] {
    values.reduce(into: [:]) { counts, value in counts[value, default: 0] += 1 }
}
