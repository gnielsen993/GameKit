import Testing
import Foundation
@testable import gamekit

/// Nonogram free mode had no error signal at all: `applyMutation` consults the
/// solution only inside the `.lives` branch, so a wrong fill on move eight
/// stayed invisible and the board simply never won.
///
/// The contradiction was already being computed and discarded —
/// `crossOffMask`'s no-placement branch returns an all-false mask, which the
/// UI renders identically to "nothing crossed off yet". `lineIsSatisfiable`
/// exposes that fact as its own answer.
///
/// The signal is deliberately line-level. In a two-state puzzle, naming the
/// offending cell is equivalent to solving it.
@MainActor
@Suite("Nonogram contradiction detection")
struct NonogramContradictionTests {

    // MARK: - Engine

    @Test("an empty line is satisfiable")
    func emptyLineIsSatisfiable() {
        let filled = Array(repeating: false, count: 5)
        let marked = Array(repeating: false, count: 5)
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [3]))
    }

    @Test("a correct partial fill is satisfiable")
    func correctPartialIsSatisfiable() {
        // _XX__ against a clue of 3: the run can still grow to length 3.
        let filled = [false, true, true, false, false]
        let marked = Array(repeating: false, count: 5)
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [3]))
    }

    @Test("a run longer than its clue is unsatisfiable")
    func overlongRunIsUnsatisfiable() {
        // Four contiguous fills cannot satisfy a clue of 3.
        let filled = [true, true, true, true, false]
        let marked = Array(repeating: false, count: 5)
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [3]) == false)
    }

    /// The subtle rule, and the one that keeps this from crying wolf: an
    /// unfilled cell is *unknown*, not empty. Only an X mark asserts
    /// emptiness. So a gap between two fills is not yet a contradiction —
    /// the player may simply not have filled it in yet.
    @Test("a gap between fills is not a contradiction until it is marked")
    func gapIsOnlyContradictoryOnceMarked() {
        let filled = [true, false, true, false, false]

        // X_X__ can still become one run of 3 by filling the middle cell.
        let unmarked = Array(repeating: false, count: 5)
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: unmarked, hints: [3]))

        // Marking that middle cell empty makes the run of 3 impossible.
        var marked = Array(repeating: false, count: 5)
        marked[1] = true
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [3]) == false)
    }

    @Test("marks that leave no room make a line unsatisfiable")
    func marksCanMakeUnsatisfiable() {
        // Every cell marked empty, but the clue demands a run of 2.
        let filled = Array(repeating: false, count: 5)
        let marked = Array(repeating: true, count: 5)
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [2]) == false)
    }

    @Test("a fully solved line is satisfiable")
    func solvedLineIsSatisfiable() {
        let filled = [true, true, true, false, false]
        let marked = [false, false, false, true, true]
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [3]))
    }

    @Test("an all-zero clue rejects any fill")
    func zeroClueRejectsFill() {
        let marked = Array(repeating: false, count: 4)
        #expect(NonogramHints.lineIsSatisfiable(
            filled: Array(repeating: false, count: 4), marked: marked, hints: [0]))
        #expect(NonogramHints.lineIsSatisfiable(
            filled: [true, false, false, false], marked: marked, hints: [0]) == false)
    }

    @Test("satisfiability never disagrees with a completed correct line")
    func agreesWithCompletedLines() {
        // 1·2 in a 6-wide line: X_XX__
        let filled = [true, false, true, true, false, false]
        let marked = [false, true, false, false, true, true]
        #expect(NonogramHints.lineIsSatisfiable(filled: filled, marked: marked, hints: [1, 2]))
    }

    // MARK: - Board-level sweeps

    @Test("a clean board reports no unsatisfiable lines")
    func cleanBoardIsClean() {
        let size = 5
        let board = NonogramBoard(size: size, cells: Array(repeating: .empty, count: size * size))
        let hints: [[Int]] = Array(repeating: [1], count: size)
        #expect(NonogramHints.unsatisfiableRows(board: board, hints: hints).isEmpty)
        #expect(NonogramHints.unsatisfiableColumns(board: board, hints: hints).isEmpty)
    }

    @Test("an overfilled row is reported, and only that row")
    func overfilledRowIsIsolated() {
        let size = 5
        var board = NonogramBoard(size: size, cells: Array(repeating: .empty, count: size * size))
        // Row 2 gets three fills against a clue of 1.
        for col in 0..<3 {
            board = board.setting(.filled, atRow: 2, col: col)
        }
        let rowHints: [[Int]] = Array(repeating: [1], count: size)
        let bad = NonogramHints.unsatisfiableRows(board: board, hints: rowHints)
        #expect(bad == [2])
    }
}
