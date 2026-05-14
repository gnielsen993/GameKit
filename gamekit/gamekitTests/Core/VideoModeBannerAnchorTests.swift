//
//  VideoModeBannerAnchorTests.swift
//  gamekitTests
//
//  Phase 13 — Anchor table coverage for VideoModeBannerRouter.anchor(for:).
//  Locks the 6-row D-09 table from 08-BANNER-PLACEMENT.md verbatim:
//
//    | PiP location       | edge   | alignment |
//    | largeTop           | bottom | fullWidth |
//    | largeBottom        | top    | fullWidth |
//    | smallTopLeft       | bottom | trailing  |
//    | smallTopRight      | bottom | leading   |
//    | smallBottomLeft    | top    | trailing  |
//    | smallBottomRight   | top    | leading   |
//
//  Pattern source: VideoModeSlotRouterTests.swift (one @Test per zone × field).
//  Plus a final exhaustiveness loop mirroring VideoModeStoreTests:85-95 —
//  iterates `VideoModeLocation.allCases` to assert the router has a mapping
//  for every case (compile-time exhaustive switch is the primary guarantee;
//  this test is the runtime safety net).
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("VideoModeBannerRouter")
struct VideoModeBannerAnchorTests {

    @Test("largeTop — banner docks bottom edge, full-width (D-09)")
    func test_largeTop_bottomEdge_fullWidthAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .largeTop)
        #expect(anchor.edge == .bottom)
        #expect(anchor.alignment == .fullWidth)
    }

    @Test("largeBottom — banner docks top edge, full-width (D-09)")
    func test_largeBottom_topEdge_fullWidthAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .largeBottom)
        #expect(anchor.edge == .top)
        #expect(anchor.alignment == .fullWidth)
    }

    @Test("smallTopLeft — banner docks bottom edge, trailing-aligned (D-09)")
    func test_smallTopLeft_bottomEdge_trailingAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .smallTopLeft)
        #expect(anchor.edge == .bottom)
        #expect(anchor.alignment == .trailing)
    }

    @Test("smallTopRight — banner docks bottom edge, leading-aligned (D-09)")
    func test_smallTopRight_bottomEdge_leadingAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .smallTopRight)
        #expect(anchor.edge == .bottom)
        #expect(anchor.alignment == .leading)
    }

    @Test("smallBottomLeft — banner docks top edge, trailing-aligned (D-09)")
    func test_smallBottomLeft_topEdge_trailingAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .smallBottomLeft)
        #expect(anchor.edge == .top)
        #expect(anchor.alignment == .trailing)
    }

    @Test("smallBottomRight — banner docks top edge, leading-aligned (D-09)")
    func test_smallBottomRight_topEdge_leadingAlignment() {
        let anchor = VideoModeBannerRouter.anchor(for: .smallBottomRight)
        #expect(anchor.edge == .top)
        #expect(anchor.alignment == .leading)
    }

    @Test("All 6 locations have a router mapping (compile-time guarantee + runtime safety net)")
    func test_all_cases_have_mappings() {
        for loc in VideoModeLocation.allCases {
            _ = VideoModeBannerRouter.anchor(for: loc)
        }
        #expect(VideoModeLocation.allCases.count == 6)
    }
}
