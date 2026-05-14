//
//  VideoModeSlotRouterTests.swift
//  gamekitTests
//
//  Phase 10 Wave 0 RED gate — locks the VIDEO-05 contract that
//  VideoModeSlotRouter.anchors(for:) MUST satisfy in Plan 10-02:
//    - 6 VideoModeLocation cases × 5 SlotAnchorMap fields = 30 anchor assertions
//    - Large zones (.largeTop / .largeBottom) → all 4 slots consolidate into
//      .inCompactRow (CONTEXT D-02 + D-08; data from VIDEO-MODE-LAYOUTS.md)
//    - Small zones (.smallTL / .smallTR / .smallBL / .smallBR) → slots place
//      opposite the covered corner (CONTEXT D-11)
//
//  Phase 12.1 update: `headerBar` field added (Plan 12.1-01) — repositions
//  per-game HeaderBar away from top-PiP overlay on Small zones per CONTEXT D-02.
//
//  Pattern source: VideoModeStoreTests.swift:1-29 (header doc-comment shape) +
//  VideoModeStoreTests.swift:85-95 (loop over VideoModeLocation.allCases for
//  exhaustiveness — RESEARCH §Example 2).
//
//  RED-STATE NOTE: This file references types (VideoModeSlotRouter, SlotAnchorMap,
//  SlotAnchor) that DO NOT yet exist. The compile failure IS the RED gate —
//  Plan 10-02 produces these types and the file flips to GREEN. xcodebuild build
//  failing on undefined-symbol here is EXPECTED.
//
//  Test names match 10-VALIDATION.md VIDEO-05 row + 10-RESEARCH.md §Pattern 2
//  switch-case mapping.
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("VideoModeSlotRouter")
struct VideoModeSlotRouterTests {

    @Test("Large top — all 4 slots consolidate into compact row (VIDEO-05 / D-08)")
    func test_largeTop_allInCompactRow() {
        let map = VideoModeSlotRouter.anchors(for: .largeTop)
        #expect(map.back == .inCompactRow)
        #expect(map.settings == .inCompactRow)
        #expect(map.picker == .inCompactRow)
        #expect(map.fab == .inCompactRow)
        #expect(map.headerBar == .inCompactRow)
    }

    @Test("Large bottom — all 4 slots consolidate into compact row (VIDEO-05 / D-08)")
    func test_largeBottom_allInCompactRow() {
        let map = VideoModeSlotRouter.anchors(for: .largeBottom)
        #expect(map.back == .inCompactRow)
        #expect(map.settings == .inCompactRow)
        #expect(map.picker == .inCompactRow)
        #expect(map.fab == .inCompactRow)
        #expect(map.headerBar == .inCompactRow)
    }

    @Test("Small top-left — slots move to trailing edge (VIDEO-05 / D-11)")
    func test_smallTopLeft_anchors() {
        let map = VideoModeSlotRouter.anchors(for: .smallTopLeft)
        #expect(map.back == .topTrailing)
        #expect(map.settings == .topTrailing)
        #expect(map.picker == .bottomTrailing)
        #expect(map.fab == .bottomTrailing)
        #expect(map.headerBar == .bottomLeading)
    }

    @Test("Small top-right — slots move to leading edge (VIDEO-05 / D-11)")
    func test_smallTopRight_anchors() {
        let map = VideoModeSlotRouter.anchors(for: .smallTopRight)
        #expect(map.back == .topLeading)
        #expect(map.settings == .topLeading)
        #expect(map.picker == .bottomLeading)
        #expect(map.fab == .bottomLeading)
        #expect(map.headerBar == .bottomTrailing)
    }

    @Test("Small bottom-left — slots split top + bottom-trailing (VIDEO-05 / D-11)")
    func test_smallBottomLeft_anchors() {
        let map = VideoModeSlotRouter.anchors(for: .smallBottomLeft)
        #expect(map.back == .topLeading)
        #expect(map.settings == .topTrailing)
        #expect(map.picker == .bottomTrailing)
        #expect(map.fab == .bottomTrailing)
        #expect(map.headerBar == .topLeading)
    }

    @Test("Small bottom-right — slots split top + bottom-leading (VIDEO-05 / D-11)")
    func test_smallBottomRight_anchors() {
        let map = VideoModeSlotRouter.anchors(for: .smallBottomRight)
        #expect(map.back == .topLeading)
        #expect(map.settings == .topTrailing)
        #expect(map.picker == .bottomLeading)
        #expect(map.fab == .bottomLeading)
        #expect(map.headerBar == .topTrailing)
    }

    @Test("All 6 locations switch exhaustively without crash (VIDEO-05 compile-time guarantee)")
    func test_all_cases_have_mappings() {
        for loc in VideoModeLocation.allCases {
            _ = VideoModeSlotRouter.anchors(for: loc)
        }
        #expect(VideoModeLocation.allCases.count == 6)
    }
}
