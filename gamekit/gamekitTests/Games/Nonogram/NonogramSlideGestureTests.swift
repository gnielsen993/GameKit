//
//  NonogramSlideGestureTests.swift
//  gamekitTests
//
//  Regression coverage for touch-vs-smear discrimination and fast-swipe
//  interpolation. These helpers are pure; no SwiftUI hierarchy is needed.
//

import CoreGraphics
import Testing
@testable import gamekit

@MainActor
struct NonogramSlideGestureTests {

    @Test("Dense cells use a 24pt precision window for adjacent-cell correction")
    func denseBoardActivationFloor() {
        #expect(NonogramBoardView.dragActivationDistance(cellSize: 14) == 24)
        #expect(NonogramBoardView.dragActivationDistance(cellSize: 16) == 24)
    }

    @Test("Roomy cells cap smear activation so deliberate swipes stay responsive")
    func roomyBoardActivationCap() {
        #expect(NonogramBoardView.dragActivationDistance(cellSize: 20) == 30)
        #expect(NonogramBoardView.dragActivationDistance(cellSize: 60) == 32)
    }

    @Test("Fast horizontal samples include every skipped cell")
    func fastHorizontalSwipeInterpolatesSkippedCells() {
        let cells = NonogramBoardView.cellsBetween(
            fromRow: 4, fromCol: 2,
            toRow: 4, toCol: 7,
            axis: .horizontal,
            startRow: 4, startCol: 2
        )

        #expect(cells.map { $0.1 } == [3, 4, 5, 6, 7])
        #expect(cells.allSatisfy { $0.0 == 4 })
    }

    @Test("Fast reverse vertical samples include every skipped cell")
    func fastVerticalSwipeInterpolatesSkippedCellsInReverse() {
        let cells = NonogramBoardView.cellsBetween(
            fromRow: 8, fromCol: 3,
            toRow: 3, toCol: 3,
            axis: .vertical,
            startRow: 8, startCol: 3
        )

        #expect(cells.map { $0.0 } == [7, 6, 5, 4, 3])
        #expect(cells.allSatisfy { $0.1 == 3 })
    }
}
