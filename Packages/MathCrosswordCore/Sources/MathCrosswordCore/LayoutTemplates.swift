import Foundation

enum LayoutTemplates {
    struct Skeleton {
        var equations: [(a: GridPos, b: GridPos, r: GridPos, across: Bool)] = []

        mutating func addBlock(originRow: Int, originCol: Int) {
            for index in 0..<3 {
                let row = originRow + 2 * index
                equations.append((GridPos(row: row, col: originCol), GridPos(row: row, col: originCol + 2), GridPos(row: row, col: originCol + 4), true))
                let col = originCol + 2 * index
                equations.append((GridPos(row: originRow, col: col), GridPos(row: originRow + 2, col: col), GridPos(row: originRow + 4, col: col), false))
            }
        }
    }

    static func skeleton(for difficulty: TallyDifficulty, rng: inout SeededGenerator) -> Skeleton {
        let limits: (target: Int, minimum: Int, maxColumns: Int, maxRows: Int)
        switch difficulty {
        case .easy: limits = (4, 3, 7, 9)
        case .medium: limits = (8, 7, 9, 13)
        case .hard: limits = (10, 9, 9, 15)
        }
        for _ in 0..<60 {
            if let skeleton = organic(limits: limits, rng: &rng) { return skeleton }
        }
        var fallback = Skeleton()
        fallback.addBlock(originRow: 0, originCol: 0)
        return fallback
    }

    private static func organic(
        limits: (target: Int, minimum: Int, maxColumns: Int, maxRows: Int),
        rng: inout SeededGenerator
    ) -> Skeleton? {
        var equations: [(a: GridPos, b: GridPos, r: GridPos, across: Bool)] = []
        var numberCells = Set<GridPos>()
        var occupied = Set<GridPos>()

        func cells(from origin: GridPos, across: Bool) -> [GridPos] {
            (0..<5).map { offset in
                across ? GridPos(row: origin.row, col: origin.col + offset) : GridPos(row: origin.row + offset, col: origin.col)
            }
        }
        func append(_ run: [GridPos], across: Bool) {
            equations.append((run[0], run[2], run[4], across))
            numberCells.formUnion([run[0], run[2], run[4]])
            occupied.formUnion(run)
        }

        append(cells(from: GridPos(row: 0, col: 0), across: true), across: true)
        var stalledAttempts = 0
        while equations.count < limits.target && stalledAttempts < 80 {
            stalledAttempts += 1
            guard let anchor = numberCells.sorted().randomElement(using: &rng) else { break }
            let across = Bool.random(using: &rng)
            let anchorSlot = [0, 2, 4].randomElement(using: &rng)!
            let origin = across
                ? GridPos(row: anchor.row, col: anchor.col - anchorSlot)
                : GridPos(row: anchor.row - anchorSlot, col: anchor.col)
            let run = cells(from: origin, across: across)
            let acceptable = run.enumerated().allSatisfy { index, cell in
                index.isMultiple(of: 2) ? !occupied.contains(cell) || numberCells.contains(cell) : !occupied.contains(cell)
            }
            guard acceptable, run[anchorSlot] == anchor,
                  run.filter({ !occupied.contains($0) }).count >= 2 else { continue }
            append(run, across: across)
            stalledAttempts = 0
        }
        guard equations.count >= limits.minimum else { return nil }
        let rows = occupied.map(\.row)
        let columns = occupied.map(\.col)
        guard let minRow = rows.min(), let maxRow = rows.max(), let minColumn = columns.min(), let maxColumn = columns.max(),
              maxColumn - minColumn + 1 <= limits.maxColumns,
              maxRow - minRow + 1 <= limits.maxRows else { return nil }
        var normalized = Skeleton()
        normalized.equations = equations.map { equation in
            (GridPos(row: equation.a.row - minRow, col: equation.a.col - minColumn),
             GridPos(row: equation.b.row - minRow, col: equation.b.col - minColumn),
             GridPos(row: equation.r.row - minRow, col: equation.r.col - minColumn),
             equation.across)
        }
        return normalized
    }
}
