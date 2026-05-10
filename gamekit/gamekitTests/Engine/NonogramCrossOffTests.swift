//
//  NonogramCrossOffTests.swift
//  gamekitTests
//
//  Pinpoints the cross-off rule under the player-feedback constraint:
//  a hint is only crossed off when its corresponding player run is
//  locked into that hint position by the surrounding cells (edges or
//  X marks). Under-determined runs leave hints uncrossed.
//

import Testing
@testable import gamekit

@MainActor
struct NonogramCrossOffTests {

    @Test("[1,1] in 10 cells, fill at col 3 with no X marks → no cross-off")
    func ambiguousFillDoesNotCrossOff() {
        var filled = Array(repeating: false, count: 10)
        filled[3] = true
        let marked = Array(repeating: false, count: 10)
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [1, 1])
        #expect(mask == [false, false],
                "Run at col 3 could be either hint 0 or hint 1 — neither locked.")
    }

    @Test("[1,1] in 10 cells, fill at col 3 + X marks at 0..2 → first hint crosses off")
    func leftWallLocksFirstHint() {
        var filled = Array(repeating: false, count: 10)
        filled[3] = true
        var marked = Array(repeating: false, count: 10)
        marked[0] = true; marked[1] = true; marked[2] = true
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [1, 1])
        #expect(mask == [true, false],
                "X marks at 0..2 force the col-3 fill to be the first hint.")
    }

    @Test("Filling a run at col 0 (left edge) crosses off the first hint when length matches")
    func leftEdgeLocksFirstHint() {
        var filled = Array(repeating: false, count: 10)
        filled[0] = true
        let marked = Array(repeating: false, count: 10)
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [1, 2])
        #expect(mask == [true, false], "A length-1 run anchored at col 0 IS hint 0.")
    }

    @Test("Filling at right edge crosses off last hint when length matches")
    func rightEdgeLocksLastHint() {
        var filled = Array(repeating: false, count: 10)
        filled[9] = true
        let marked = Array(repeating: false, count: 10)
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [2, 1])
        #expect(mask == [false, true], "A length-1 run anchored at col 9 IS the last hint.")
    }

    @Test("Empty-line case: hints == [0], no fills → cross off")
    func emptyLineCrossOff() {
        let filled = Array(repeating: false, count: 10)
        let marked = Array(repeating: false, count: 10)
        #expect(
            NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [0]) == [true]
        )
    }

    @Test("Empty-line case: hints == [0], any fill → no cross off")
    func emptyLineWithFillNoCrossOff() {
        var filled = Array(repeating: false, count: 10)
        filled[5] = true
        let marked = Array(repeating: false, count: 10)
        #expect(
            NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [0]) == [false]
        )
    }

    @Test("Run length 2 in 5 cells with hints [1,2]: anchored at right wall locks hint 1")
    func anchoredRunByEdge() {
        // 5 cells: . . _ # #  (run at cols 3..4, hints [1, 2])
        var filled = Array(repeating: false, count: 5)
        filled[3] = true; filled[4] = true
        let marked = Array(repeating: false, count: 5)
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [1, 2])
        #expect(mask == [false, true],
                "Length-2 run at the right edge can only be the second hint.")
    }

    @Test("Length-1 fill inside a length-12 hint range does NOT cross off the 12")
    func partialRunDoesNotCrossOff() {
        // 20 cells, hints [12]. Player has X-marked col 0, filled col 11.
        // The length-1 fill could be part of an eventual length-12 run, but
        // it's far from completing the hint. Strict matching = no cross-off.
        var filled = Array(repeating: false, count: 20)
        filled[11] = true
        var marked = Array(repeating: false, count: 20)
        marked[0] = true
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [12])
        #expect(mask == [false],
                "Single fill in a 12-length-hint column is not a completion.")
    }

    @Test("Empty column + X marks ≠ all-empty puzzle ≠ cross-off")
    func xMarkedColumnWithBigHintNoCrossOff() {
        // 20 cells, hints [5]. X-mark at col 0 only, no fills anywhere.
        // Player hasn't started filling. No cross-off should fire.
        var marked = Array(repeating: false, count: 20)
        marked[0] = true
        let filled = Array(repeating: false, count: 20)
        let mask = NonogramHints.crossOffMask(filled: filled, marked: marked, hints: [5])
        #expect(mask == [false], "No fills means no completion regardless of marks.")
    }
}
