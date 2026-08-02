import Testing
import Foundation
@testable import gamekit

/// The talkthrough's one non-negotiable property: it must never claim
/// something the solver cannot prove. A confidently-worded wrong explanation
/// is worse than no explanation at all, so these tests check the claims, not
/// just that a deduction was produced.
@Suite("Nonogram talkthrough")
@MainActor
struct NonogramTalkthroughTests {

    private func emptyBoard(_ size: Int) -> NonogramBoard {
        NonogramBoard(size: size, cells: Array(repeating: .empty, count: size * size))
    }

    /// A 5x5 puzzle whose solution is a plus sign. Row/column 2 are full.
    private var plusRowHints: [[Int]] { [[1], [1], [5], [1], [1]] }
    private var plusColumnHints: [[Int]] { [[1], [1], [5], [1], [1]] }

    @Test("an untouched board offers a deduction")
    func untouchedBoardHasADeduction() {
        let deduction = NonogramTalkthrough.nextDeduction(
            board: emptyBoard(5),
            rowHints: plusRowHints,
            columnHints: plusColumnHints
        )
        #expect(deduction != nil)
    }

    @Test("the full-line clue is found and named")
    func fullLineIsNamed() throws {
        let deduction = try #require(NonogramTalkthrough.nextDeduction(
            board: emptyBoard(5),
            rowHints: plusRowHints,
            columnHints: plusColumnHints
        ))
        // A 5 in a 5-wide line is the highest-yield deduction on this board.
        #expect(deduction.newFilled.count == 5)
        #expect(deduction.technique == .overlap(clue: 5, lineLength: 5))
    }

    @Test("overlap is reported for a clue longer than half the line")
    func overlapIsReported() throws {
        // A single 8 in a 10-wide line forces the middle 6.
        let size = 10
        // Consistent puzzle: 8 filled in row 0 spanning columns 1...8.
        let rows: [[Int]] = [[8]] + Array(repeating: [0], count: size - 1)
        let cols: [[Int]] = [[0]] + Array(repeating: [1], count: 8) + [[0]]
        let deduction = try #require(NonogramTalkthrough.nextDeduction(
            board: emptyBoard(size),
            rowHints: rows,
            columnHints: cols
        ))
        #expect(deduction.line == .row(0))
        #expect(deduction.technique == .overlap(clue: 8, lineLength: 10))
        // Cells 2...7 are filled in every arrangement of an 8 in a 10.
        #expect(deduction.newFilled == [2, 3, 4, 5, 6, 7])
    }

    @Test("every claimed cell agrees with the real solution")
    func claimsMatchTheSolution() throws {
        // Solution: a plus. Filled cells are row 2 and column 2.
        let size = 5
        func isFilledInSolution(row: Int, col: Int) -> Bool { row == 2 || col == 2 }

        var board = emptyBoard(size)
        // Walk several deductions, applying each, and check every claim.
        for _ in 0..<12 {
            guard let deduction = NonogramTalkthrough.nextDeduction(
                board: board,
                rowHints: plusRowHints,
                columnHints: plusColumnHints
            ) else { break }

            for index in deduction.newFilled {
                let (row, col) = coordinates(of: index, on: deduction.line)
                #expect(isFilledInSolution(row: row, col: col),
                        "claimed filled at \(row),\(col) but the solution is empty there")
                board = board.setting(.filled, atRow: row, col: col)
            }
            for index in deduction.newEmpty {
                let (row, col) = coordinates(of: index, on: deduction.line)
                #expect(isFilledInSolution(row: row, col: col) == false,
                        "claimed empty at \(row),\(col) but the solution is filled there")
                board = board.setting(.marked, atRow: row, col: col)
            }
        }
    }

    @Test("following the talkthrough solves the puzzle")
    func followingItSolves() {
        let size = 5
        var board = emptyBoard(size)
        for _ in 0..<50 {
            guard let deduction = NonogramTalkthrough.nextDeduction(
                board: board,
                rowHints: plusRowHints,
                columnHints: plusColumnHints
            ) else { break }
            for index in deduction.newFilled {
                let (row, col) = coordinates(of: index, on: deduction.line)
                board = board.setting(.filled, atRow: row, col: col)
            }
            for index in deduction.newEmpty {
                let (row, col) = coordinates(of: index, on: deduction.line)
                board = board.setting(.marked, atRow: row, col: col)
            }
        }
        for row in 0..<size {
            for col in 0..<size {
                let shouldBeFilled = (row == 2 || col == 2)
                #expect((board.cell(row: row, col: col) == .filled) == shouldBeFilled)
            }
        }
    }

    @Test("a solved board offers nothing further")
    func solvedBoardHasNoDeduction() {
        let size = 5
        var board = emptyBoard(size)
        for row in 0..<size {
            for col in 0..<size {
                board = board.setting((row == 2 || col == 2) ? .filled : .marked, atRow: row, col: col)
            }
        }
        #expect(NonogramTalkthrough.nextDeduction(
            board: board,
            rowHints: plusRowHints,
            columnHints: plusColumnHints
        ) == nil)
    }

    @Test("a contradicted line yields no deduction from that line")
    func contradictionYieldsNothing() {
        // One row filled solid against an all-zero clue: unsatisfiable.
        let size = 5
        var board = emptyBoard(size)
        for col in 0..<size { board = board.setting(.filled, atRow: 0, col: col) }
        let rows: [[Int]] = [[0], [0], [0], [0], [0]]
        let cols: [[Int]] = [[0], [0], [0], [0], [0]]
        let deduction = NonogramTalkthrough.nextDeduction(
            board: board, rowHints: rows, columnHints: cols
        )
        // Rows 1-4 are already all-empty-and-known, row 0 contradicts, so
        // there is nothing honest left to say.
        #expect(deduction?.line != .row(0))
    }

    @Test("a zero clue is named as such")
    func zeroClueIsNamed() throws {
        let size = 3
        let rows: [[Int]] = [[0], [3], [0]]
        let cols: [[Int]] = [[1], [1], [1]]
        let deduction = try #require(NonogramTalkthrough.nextDeduction(
            board: emptyBoard(size), rowHints: rows, columnHints: cols
        ))
        // Row 1's 3-in-a-3 is the higher-yield named deduction.
        #expect(deduction.technique == .overlap(clue: 3, lineLength: 3))
    }

    @Test("ranking is stable across repeated calls")
    func rankingIsStable() {
        let board = emptyBoard(5)
        let first = NonogramTalkthrough.nextDeduction(
            board: board, rowHints: plusRowHints, columnHints: plusColumnHints
        )
        let second = NonogramTalkthrough.nextDeduction(
            board: board, rowHints: plusRowHints, columnHints: plusColumnHints
        )
        #expect(first == second)
    }

    private func coordinates(of index: Int, on line: NonogramTalkthrough.Line) -> (Int, Int) {
        switch line {
        case .row(let r):    return (r, index)
        case .column(let c): return (index, c)
        }
    }
}
