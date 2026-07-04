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

    // MARK: - Idle-start regression tests
    //
    // Root cause: start() did not clear directionQueue, so directions queued
    // while the game was idle (from D-pad/swipe before Start was tapped) would
    // persist into the first cell moves, filling the capacity-2 queue and making
    // early in-run input feel dropped. Fix: start() sets directionQueue = [].
    //
    // These tests reproduce the failure mode before the fix was applied.

    @Test("start: clears direction queue so idle-phase input does not affect the run")
    func startClearsDirectionQueue() {
        let vm = SnakeViewModel()
        // Simulate D-pad taps during idle phase — fills the capacity-2 queue.
        _ = vm.tryEnqueueDirection(.up)
        _ = vm.tryEnqueueDirection(.left)
        #expect(vm.enqueueCount == 2, "precondition: idle-phase taps should fill the queue")
        // start() must flush the queue so the first in-run input has capacity.
        vm.start()
        // Queue is now empty: two fresh post-start inputs must both be accepted.
        let first  = vm.tryEnqueueDirection(.up)
        let second = vm.tryEnqueueDirection(.left)
        #expect(first  == true, "start() must have cleared the queue; first post-start input must be accepted")
        #expect(second == true, "start() must have cleared the queue; second post-start input must be accepted")
    }

    @Test("start: does not affect enqueueCount (counter-trigger integrity)")
    func startDoesNotMutateEnqueueCount() {
        let vm = SnakeViewModel()
        _ = vm.tryEnqueueDirection(.up)
        #expect(vm.enqueueCount == 1)
        vm.start()
        // enqueueCount must remain 1 — start() clearing the queue must not
        // decrement the haptic counter-trigger (the view only increments).
        #expect(vm.enqueueCount == 1, "start() must not modify enqueueCount")
    }
}
