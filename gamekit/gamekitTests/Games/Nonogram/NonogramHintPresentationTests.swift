//
//  NonogramHintPresentationTests.swift
//  gamekitTests
//
//  Pins the compact row-hint grammar so adjacent clues can never collapse
//  into an ambiguous multi-digit number.
//

import Testing
@testable import gamekit

@MainActor
struct NonogramHintPresentationTests {

    @Test("Row clues use explicit centered-dot boundaries")
    func rowCluesHaveExplicitBoundaries() {
        #expect(NonogramBoardView.rowHintDisplayString([1, 5, 11]) == "1·5·11")
        #expect(NonogramBoardView.rowHintDisplayString([15, 1]) == "15·1")
        #expect(NonogramBoardView.rowHintDisplayString([1, 5, 1]) == "1·5·1")
    }

    @Test("VoiceOver receives spoken clue boundaries instead of dot glyphs")
    func rowCluesHaveClearAccessibilityLabel() {
        #expect(NonogramBoardView.rowHintAccessibilityLabel([1, 5, 11]) == "1, 5, 11")
    }
}
