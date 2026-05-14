//
//  VideoModeBannerAnchor.swift
//  gamekit
//
//  Phase 13 — Win/Loss Banner anchor router. C-03 LOCKED at UI-SPEC time:
//  dedicated helper parallel to (NOT a field on) VideoModeSlotRouter's
//  SlotAnchorMap, because the banner anchor is conceptually an EDGE +
//  ALIGNMENT pair, not a 4-corner SlotAnchor.
//
//  Anchor table per 08-BANNER-PLACEMENT.md D-09 (LOCKED):
//    | PiP location       | edge   | alignment |
//    | largeTop           | bottom | fullWidth |
//    | largeBottom        | top    | fullWidth |
//    | smallTopLeft       | bottom | trailing  |
//    | smallTopRight      | bottom | leading   |
//    | smallBottomLeft    | top    | trailing  |
//    | smallBottomRight   | top    | leading   |
//
//  Foundation-only — no SwiftUI import keeps the helper reusable from any
//  context (engine layer, tests, snapshot rigs). Mirrors the
//  VideoModeSlotRouter shape.
//
//  Switch on VideoModeLocation is exhaustive — adding a 7th case in v1.3+
//  fires a compile error here, matching VideoModeSlotRouter's safety net.
//

import Foundation

/// Which screen edge the banner docks to for a given PiP zone.
/// Conceptually an EDGE anchor (not a 4-corner anchor like `SlotAnchor`)
/// — that's why this lives in a dedicated helper per UI-SPEC C-03.
enum VideoModeBannerEdge: Sendable, Equatable {
    case top                // Banner docks to top safe-area edge
    case bottom             // Banner docks to bottom safe-area edge
}

/// Horizontal alignment hint for banner content within the docked edge.
/// `.fullWidth` is the Large-zone default; `.leading` / `.trailing` are
/// the Small-zone choices that pack content opposite the covered PiP corner.
enum VideoModeBannerAlignment: Sendable, Equatable {
    case leading            // Banner content anchored leading (Small TR / Small BR)
    case trailing           // Banner content anchored trailing (Small TL / Small BL)
    case fullWidth          // Banner content spans full width (Large zones)
}

/// Edge + alignment pair returned by `VideoModeBannerRouter.anchor(for:)`.
/// Equatable so unit tests can assert the full row of the D-09 anchor table
/// per case.
struct VideoModeBannerAnchor: Sendable, Equatable {
    let edge: VideoModeBannerEdge
    let alignment: VideoModeBannerAlignment
}

/// Pure helper exposing banner anchor data for each PiP zone.
///
/// Data source: 08-BANNER-PLACEMENT.md D-09 (LOCKED). The "opposite-of-PiP"
/// rule — the banner docks away from the PiP overlay so the board stays
/// visible behind the banner.
///
/// Switch is exhaustive on `VideoModeLocation` — adding a 7th case in v1.3+
/// produces a compile error here. Mirrors `VideoModeSlotRouter.anchors(for:)`
/// safety net per Phase 12.1 D-01.
enum VideoModeBannerRouter {
    /// Returns the banner edge + alignment for the given PiP zone.
    static func anchor(for location: VideoModeLocation) -> VideoModeBannerAnchor {
        switch location {
        case .largeTop:
            // PiP covers top → banner docks at bottom edge, full-width.
            return VideoModeBannerAnchor(edge: .bottom, alignment: .fullWidth)
        case .largeBottom:
            // PiP covers bottom → banner docks at top edge, full-width.
            return VideoModeBannerAnchor(edge: .top, alignment: .fullWidth)
        case .smallTopLeft:
            // PiP covers TL → banner docks bottom-right (bottom edge, trailing).
            return VideoModeBannerAnchor(edge: .bottom, alignment: .trailing)
        case .smallTopRight:
            // PiP covers TR → banner docks bottom-left (bottom edge, leading).
            return VideoModeBannerAnchor(edge: .bottom, alignment: .leading)
        case .smallBottomLeft:
            // PiP covers BL → banner docks top-right (top edge, trailing).
            return VideoModeBannerAnchor(edge: .top, alignment: .trailing)
        case .smallBottomRight:
            // PiP covers BR → banner docks top-left (top edge, leading).
            return VideoModeBannerAnchor(edge: .top, alignment: .leading)
        }
    }
}
