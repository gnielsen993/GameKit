//
//  SnakeViewModelTests.swift
//  gamekitTests
//
//  Swift Testing coverage for SnakeViewModel direction-queue contract:
//    - 180° reversal rejection (Pitfall 5 / Pitfall 6)
//    - effectiveCurrent uses queue tail, not engine current direction
//    - queue capacity cap (maxQueueDepth = 2)
//
//  @MainActor struct — matches MergeViewModelTests pattern. Engine starts
//  with direction = .right (SnakeEngine.init sets currentDirection = .right).
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("SnakeViewModel direction queue")
struct SnakeViewModelTests {

    @Test("tryEnqueueDirection: rejects 180-degree reversal, fires no count increment")
    func rejects180DegreeReversal() {
        let vm = SnakeViewModel()
        // Engine starts facing .right; .left == .right.opposite → 180° reversal
        let result = vm.tryEnqueueDirection(.left)
        #expect(result == false, "180° reversal must be rejected (D-07)")
        #expect(vm.enqueueCount == 0, "rejected input must not increment enqueueCount (Pitfall 6)")
    }

    @Test("tryEnqueueDirection: accepts valid turn, increments enqueueCount exactly once")
    func acceptsValidTurn() {
        let vm = SnakeViewModel()
        // .up is a perpendicular turn from initial direction .right
        let result = vm.tryEnqueueDirection(.up)
        #expect(result == true, "valid perpendicular turn must be accepted")
        #expect(vm.enqueueCount == 1, "accepted turn must increment enqueueCount exactly once")
    }

    @Test("tryEnqueueDirection: effectiveCurrent uses queue tail, not engine current direction")
    func effectiveCurrentUsesQueueTail() {
        let vm = SnakeViewModel()
        // Enqueue .up (valid from initial .right)
        _ = vm.tryEnqueueDirection(.up)
        // Now effectiveCurrent = directionQueue.last = .up; .down == .up.opposite → reject
        let result = vm.tryEnqueueDirection(.down)
        #expect(result == false, "180° against the queue tail must be rejected (Pitfall 5)")
        #expect(vm.enqueueCount == 1, "only the accepted .up enqueue incremented count")
    }

    @Test("tryEnqueueDirection: caps queue at maxQueueDepth (2)")
    func capsQueueAtTwo() {
        let vm = SnakeViewModel()
        // First valid: .up from initial .right
        _ = vm.tryEnqueueDirection(.up)     // queue=[.up], count=1
        // Second valid: .left is not opposite of .up (.down is its opposite)
        _ = vm.tryEnqueueDirection(.left)   // queue=[.up, .left], count=2
        // Third: .up again — effectiveCurrent=.left, .up != .right (.left.opposite)
        // so direction is valid, but queue is full → reject (capacity, not 180°)
        let result = vm.tryEnqueueDirection(.up)
        #expect(result == false, "third enqueue must be rejected when queue is full (maxQueueDepth=2)")
        #expect(vm.enqueueCount == 2, "only 2 accepted enqueues should have incremented count")
    }
}
