import Foundation

public struct SudokuPuzzleGenerator: PuzzleGenerating {
    public init() {}

    public func generate(targetDifficulty: Difficulty, seed: Int?) throws -> Puzzle {
        let s = seed ?? Int.random(in: 1...Int.max)
        let solution = Self.generateSolvedBoard(seed: s)
        let clueCount = Self.targetClueCount(for: targetDifficulty, seed: s)
        let puzzleString = Self.makePuzzleString(
            fromSolution: solution, clueCount: clueCount, seed: s, difficulty: targetDifficulty
        )
        return Puzzle(
            hash: "",
            puzzleString: puzzleString,
            solutionString: solution,
            difficulty: targetDifficulty,
            source: .generated,
            seed: s
        )
    }

    public static func maskSignature(of puzzle: String) -> String {
        String(puzzle.map { $0 == "0" ? "0" : "1" })
    }

    // MARK: - Board generation

    private static func generateSolvedBoard(seed: Int) -> String {
        let base = [
            [1,2,3,4,5,6,7,8,9],
            [4,5,6,7,8,9,1,2,3],
            [7,8,9,1,2,3,4,5,6],
            [2,3,4,5,6,7,8,9,1],
            [5,6,7,8,9,1,2,3,4],
            [8,9,1,2,3,4,5,6,7],
            [3,4,5,6,7,8,9,1,2],
            [6,7,8,9,1,2,3,4,5],
            [9,1,2,3,4,5,6,7,8]
        ]

        let bandOrder = shuffledGroups(seed: seed &+ 11)
        let stackOrder = shuffledGroups(seed: seed &+ 23)
        let rowOffsets = [
            shuffledGroups(seed: seed &+ 31),
            shuffledGroups(seed: seed &+ 43),
            shuffledGroups(seed: seed &+ 59)
        ]
        let colOffsets = [
            shuffledGroups(seed: seed &+ 71),
            shuffledGroups(seed: seed &+ 83),
            shuffledGroups(seed: seed &+ 97)
        ]
        let digits = shuffledDigits(seed: seed &+ 101)

        var out: [Character] = []
        out.reserveCapacity(81)
        for band in bandOrder {
            for rowInBand in rowOffsets[band] {
                let row = band * 3 + rowInBand
                for stack in stackOrder {
                    for colInStack in colOffsets[stack] {
                        let col = stack * 3 + colInStack
                        out.append(digits[base[row][col] - 1])
                    }
                }
            }
        }
        return String(out)
    }

    private static func shuffledDigits(seed: Int) -> [Character] {
        var digits: [Character] = ["1","2","3","4","5","6","7","8","9"]
        var state = UInt64(truncatingIfNeeded: max(seed, 1))
        func next() -> UInt64 { state = 2862933555777941757 &* state &+ 3037000493; return state }
        for i in stride(from: digits.count - 1, through: 1, by: -1) { digits.swapAt(i, Int(next() % UInt64(i + 1))) }
        return digits
    }

    private static func shuffledGroups(seed: Int) -> [Int] {
        var arr = [0, 1, 2]
        var state = UInt64(truncatingIfNeeded: max(seed, 1))
        func next() -> UInt64 { state = 2862933555777941757 &* state &+ 3037000493; return state }
        for i in stride(from: arr.count - 1, through: 1, by: -1) { arr.swapAt(i, Int(next() % UInt64(i + 1))) }
        return arr
    }

    // MARK: - Puzzle carving

    private static func targetClueCount(for difficulty: Difficulty, seed: Int) -> Int {
        let offset = abs(seed % 3)
        switch difficulty {
        case .easy:    return 41 - offset
        case .medium:  return 34 - offset
        case .hard:    return 28 - offset
        case .extreme: return 23 - offset
        }
    }

    private static func makePuzzleString(fromSolution solution: String, clueCount: Int, seed: Int, difficulty: Difficulty) -> String {
        var chars = Array(solution)
        guard chars.count == 81 else { return solution }

        var indexes = Array(0..<81)
        var state = UInt64(truncatingIfNeeded: max(seed, 1))
        func next() -> UInt64 { state = 2862933555777941757 &* state &+ 3037000493; return state }
        for i in stride(from: indexes.count - 1, through: 1, by: -1) { indexes.swapAt(i, Int(next() % UInt64(i + 1))) }

        // Greedily remove cells one at a time, keeping only removals that preserve a unique solution.
        var remaining = 81
        for index in indexes {
            guard remaining > clueCount else { break }
            let saved = chars[index]
            chars[index] = "0"
            var board = chars.map { $0.wholeNumberValue ?? 0 }
            var steps = 0
            if sudokuCountSolutions(board: &board, gridSize: 9, boxSize: 3, maxSolutions: 2, steps: &steps, stepLimit: 50_000) == 1 {
                remaining -= 1
            } else {
                chars[index] = saved
            }
        }

        applyDifficultyShaping(&chars, solution: Array(solution), difficulty: difficulty)
        return String(chars)
    }

    private static func applyDifficultyShaping(_ chars: inout [Character], solution: [Character], difficulty: Difficulty) {
        switch difficulty {
        case .easy:
            for box in 0..<9 { ensureAtLeast(4, inBox: box, chars: &chars, solution: solution) }
        case .medium:
            for box in 0..<9 { ensureAtLeast(3, inBox: box, chars: &chars, solution: solution) }
        case .hard, .extreme:
            break
        }
    }

    private static func ensureAtLeast(_ minCount: Int, inBox box: Int, chars: inout [Character], solution: [Character]) {
        let cells = boxCells(box)
        var given = cells.filter { chars[$0] != "0" }
        guard given.count < minCount else { return }
        for idx in cells where chars[idx] == "0" {
            chars[idx] = solution[idx]
            given.append(idx)
            if given.count >= minCount { break }
        }
    }

    private static func boxCells(_ box: Int) -> [Int] {
        let startRow = (box / 3) * 3
        let startCol = (box % 3) * 3
        return (0..<3).flatMap { r in (0..<3).map { c in (startRow + r) * 9 + (startCol + c) } }
    }
}
