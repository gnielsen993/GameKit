import Foundation

public struct SudokuSolver: PuzzleSolving {
    public let gridSize: Int
    public let boxSize: Int
    public let stepLimit: Int

    public init(gridSize: Int = 9, boxSize: Int = 3, stepLimit: Int? = nil) {
        self.gridSize = gridSize
        self.boxSize = boxSize
        self.stepLimit = stepLimit ?? (gridSize == 9 ? 120_000 : 30_000)
    }

    public func countSolutions(for puzzleString: String, max: Int) throws -> Int {
        var board = sudokuParseBoard(puzzleString, gridSize: gridSize)
        guard board.count == gridSize * gridSize else {
            throw SudokuCoreError.invalidPuzzleStringLength
        }
        guard sudokuBoardHasNoConflicts(board: board, gridSize: gridSize, boxSize: boxSize) else {
            return 0
        }
        var steps = 0
        return sudokuCountSolutions(
            board: &board,
            gridSize: gridSize,
            boxSize: boxSize,
            maxSolutions: max,
            steps: &steps,
            stepLimit: stepLimit
        )
    }
}

// MARK: - Internal solver helpers (shared with TechniqueRater)

func sudokuParseBoard(_ puzzleString: String, gridSize: Int) -> [Int] {
    puzzleString.compactMap { ch in
        guard let value = ch.wholeNumberValue else { return nil }
        return (0...gridSize).contains(value) ? value : nil
    }
}

func sudokuCountSolutions(
    board: inout [Int],
    gridSize: Int,
    boxSize: Int,
    maxSolutions: Int,
    steps: inout Int,
    stepLimit: Int
) -> Int {
    steps += 1
    if steps > stepLimit { return maxSolutions }
    guard let (index, candidates) = sudokuBestCell(board: board, gridSize: gridSize, boxSize: boxSize) else {
        return sudokuBoardHasNoConflicts(board: board, gridSize: gridSize, boxSize: boxSize) ? 1 : 0
    }
    if candidates.isEmpty { return 0 }
    var total = 0
    for value in candidates {
        board[index] = value
        total += sudokuCountSolutions(
            board: &board, gridSize: gridSize, boxSize: boxSize,
            maxSolutions: maxSolutions, steps: &steps, stepLimit: stepLimit
        )
        if total >= maxSolutions {
            board[index] = 0
            return total
        }
    }
    board[index] = 0
    return total
}

func sudokuBoardHasNoConflicts(board: [Int], gridSize: Int, boxSize: Int) -> Bool {
    guard board.count == gridSize * gridSize else { return false }

    for row in 0..<gridSize {
        var seen = Set<Int>()
        for col in 0..<gridSize {
            let value = board[row * gridSize + col]
            if value == 0 { continue }
            guard (1...gridSize).contains(value), seen.insert(value).inserted else { return false }
        }
    }

    for col in 0..<gridSize {
        var seen = Set<Int>()
        for row in 0..<gridSize {
            let value = board[row * gridSize + col]
            if value == 0 { continue }
            guard (1...gridSize).contains(value), seen.insert(value).inserted else { return false }
        }
    }

    for boxRow in 0..<(gridSize / boxSize) {
        for boxCol in 0..<(gridSize / boxSize) {
            var seen = Set<Int>()
            for index in sudokuUnitBox(boxRow: boxRow, boxCol: boxCol, gridSize: gridSize, boxSize: boxSize) {
                let value = board[index]
                if value == 0 { continue }
                guard (1...gridSize).contains(value), seen.insert(value).inserted else { return false }
            }
        }
    }

    return true
}

func sudokuSolutionMatchesPuzzle(
    puzzleString: String,
    solutionString: String,
    gridSize: Int,
    boxSize: Int
) -> Bool {
    sudokuCompleteSolutionIsValid(solutionString: solutionString, gridSize: gridSize, boxSize: boxSize)
        && sudokuSolutionMatchesGivens(puzzleString: puzzleString, solutionString: solutionString, gridSize: gridSize)
}

func sudokuCompleteSolutionIsValid(solutionString: String, gridSize: Int, boxSize: Int) -> Bool {
    let solution = sudokuParseBoard(solutionString, gridSize: gridSize)
    let expectedCount = gridSize * gridSize

    guard solution.count == expectedCount else { return false }
    guard !solution.contains(0) else { return false }
    return sudokuBoardHasNoConflicts(board: solution, gridSize: gridSize, boxSize: boxSize)
}

func sudokuSolutionMatchesGivens(puzzleString: String, solutionString: String, gridSize: Int) -> Bool {
    let puzzle = sudokuParseBoard(puzzleString, gridSize: gridSize)
    let solution = sudokuParseBoard(solutionString, gridSize: gridSize)
    let expectedCount = gridSize * gridSize

    guard puzzle.count == expectedCount, solution.count == expectedCount else { return false }

    for index in 0..<expectedCount {
        let given = puzzle[index]
        if given != 0, given != solution[index] {
            return false
        }
    }

    return true
}

func sudokuBestCell(board: [Int], gridSize: Int, boxSize: Int) -> (Int, [Int])? {
    var bestIndex: Int?
    var bestCandidates: [Int] = []
    for index in board.indices where board[index] == 0 {
        let candidates = sudokuCandidates(at: index, board: board, gridSize: gridSize, boxSize: boxSize)
        if candidates.isEmpty { return (index, []) }
        if bestIndex == nil || candidates.count < bestCandidates.count {
            bestIndex = index
            bestCandidates = candidates
            if candidates.count == 1 { break }
        }
    }
    guard let idx = bestIndex else { return nil }
    return (idx, bestCandidates)
}

func sudokuCandidates(at index: Int, board: [Int], gridSize: Int, boxSize: Int) -> [Int] {
    (1...gridSize).filter { sudokuIsValid(value: $0, at: index, board: board, gridSize: gridSize, boxSize: boxSize) }
}

func sudokuIsValid(value: Int, at index: Int, board: [Int], gridSize: Int, boxSize: Int) -> Bool {
    let row = index / gridSize
    let col = index % gridSize
    for c in 0..<gridSize where board[row * gridSize + c] == value { return false }
    for r in 0..<gridSize where board[r * gridSize + col] == value { return false }
    let startRow = (row / boxSize) * boxSize
    let startCol = (col / boxSize) * boxSize
    for r in startRow..<(startRow + boxSize) {
        for c in startCol..<(startCol + boxSize) where board[r * gridSize + c] == value { return false }
    }
    return true
}

func sudokuUnitRow(_ row: Int, gridSize: Int) -> [Int] {
    (0..<gridSize).map { row * gridSize + $0 }
}

func sudokuUnitCol(_ col: Int, gridSize: Int) -> [Int] {
    (0..<gridSize).map { $0 * gridSize + col }
}

func sudokuUnitBox(boxRow: Int, boxCol: Int, gridSize: Int, boxSize: Int) -> [Int] {
    var out: [Int] = []
    let startRow = boxRow * boxSize
    let startCol = boxCol * boxSize
    for r in startRow..<(startRow + boxSize) {
        for c in startCol..<(startCol + boxSize) {
            out.append(r * gridSize + c)
        }
    }
    return out
}
