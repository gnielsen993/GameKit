//
//  MinesweeperBoardLayoutTests.swift
//  gamekitTests
//
//  Phase 6.1 (A11Y-05) — Wave 0 RED gate for Plan 06.1-03.
//
//  Tests the two pure helpers that Plan 06.1-03 Task 2 will extract from
//  MinesweeperBoardView for testability:
//
//    - static func cellSize(forWidth:cols:padding:spacing:) -> CGFloat
//        Auto-scale formula. Replaces the fixed-per-difficulty switch
//        with a width-driven computation clamped to a minCellSize floor.
//
//    - static func clampZoomScale(_:) -> CGFloat
//        Pinch-zoom clamp. Mirrors the [minZoomScale, maxZoomScale]
//        bounds applied inside the MagnifyGesture .onChanged handler.
//
//  Both helpers are pure value-in / value-out; no SwiftUI dependency.
//  These tests must FAIL TO COMPILE ("cannot find 'cellSize(...)' / 'clampZoomScale'
//  in scope") before Plan 06.1-03 Task 2 ships — TDD RED gate per project
//  precedent (Plan 04-02 / 05-01 / 05-06 RED→GREEN sequence locked).
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("MinesweeperBoardLayout")
struct MinesweeperBoardLayoutTests {

    // MARK: - cellSize formula tests
    //
    // Formula (Task 2 will implement):
    //   usable = max(0, width - 2 * padding)
    //   spacingTotal = max(0, (cols - 1)) * spacing
    //   cellSize = max(minCellSize, (usable - spacingTotal) / cols)
    //
    // minCellSize floor = 18pt (CONTEXT D-13 + Discretion #1).

    @Test
    func cellSize_easy_9col_390pt() {
        // Easy on iPhone 13/14/15 (390pt). Formula:
        //   (390 - 32) - 8*4 = 358 - 32 = 326; 326 / 9 ≈ 36.22
        // Above 18pt floor → returns the computed value.
        let result = MinesweeperBoardView.cellSize(
            forWidth: 390,
            cols: 9,
            padding: 16,
            spacing: 4
        )
        // Approximately 36.22pt. Allow a small float tolerance.
        #expect(result > 35.0 && result < 37.0,
                "Easy 9-col @ 390pt should be ~36.2pt; got \(result)")
        // Above floor → not clamped.
        #expect(result > 18.0)
    }

    @Test
    func cellSize_medium_16col_390pt() {
        // Medium on iPhone 13/14/15 (390pt). Formula:
        //   (390 - 32) - 15*4 = 358 - 60 = 298; 298 / 16 ≈ 18.625
        // Just above 18pt floor → returns the computed value.
        let result = MinesweeperBoardView.cellSize(
            forWidth: 390,
            cols: 16,
            padding: 16,
            spacing: 4
        )
        // Approximately 18.6pt. Allow tolerance.
        #expect(result > 18.0 && result < 20.0,
                "Medium 16-col @ 390pt should be ~18.6pt; got \(result)")
    }

    @Test
    func cellSize_hard_30col_390pt() {
        // Hard on iPhone 13/14/15 (390pt). Formula:
        //   (390 - 32) - 29*4 = 358 - 116 = 242; 242 / 30 ≈ 8.07
        // Below 18pt floor → clamped to 18.
        let result = MinesweeperBoardView.cellSize(
            forWidth: 390,
            cols: 30,
            padding: 16,
            spacing: 4
        )
        #expect(result == 18.0,
                "Hard 30-col @ 390pt should clamp to 18pt floor; got \(result)")
    }

    @Test
    func cellSize_hard_320pt_iphoneSE_clamped() {
        // Hard on iPhone SE (320pt). Formula:
        //   (320 - 32) - 29*4 = 288 - 116 = 172; 172 / 30 ≈ 5.73
        // Below 18pt floor → clamped to 18. Horizontal scroll fallback engages
        // (CONTEXT D-16) because 30 × 18 + 29 × 4 = 656 > 320pt.
        let result = MinesweeperBoardView.cellSize(
            forWidth: 320,
            cols: 30,
            padding: 16,
            spacing: 4
        )
        #expect(result == 18.0,
                "Hard 30-col @ 320pt iPhone SE should clamp to 18pt floor; got \(result)")
    }

    // MARK: - clampZoomScale tests
    //
    // Pinch-zoom range [0.8, 2.0] per CONTEXT D-14 / Discretion #4.

    @Test
    func zoomScale_clamped_lowerBound() {
        // Below 0.8 must clamp up to 0.8.
        let result = MinesweeperBoardView.clampZoomScale(0.5)
        #expect(result == 0.8,
                "Below 0.8 must clamp to 0.8; got \(result)")
    }

    @Test
    func zoomScale_clamped_upperBound() {
        // Above 2.0 must clamp down to 2.0.
        let result = MinesweeperBoardView.clampZoomScale(2.5)
        #expect(result == 2.0,
                "Above 2.0 must clamp to 2.0; got \(result)")
    }

    @Test
    func zoomScale_inRange_identity() {
        // Inside [0.8, 2.0] returns input unchanged.
        let result = MinesweeperBoardView.clampZoomScale(1.3)
        #expect(result == 1.3,
                "In-range value 1.3 must pass through unchanged; got \(result)")
    }
}
