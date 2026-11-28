//
//  PieceSpec.swift
//  gamekit
//
//  Geometry and timing constants for the piece (DESIGN.md §3.8), kept pure
//  (Foundation only) so the invariants are unit-testable without SwiftUI.
//  A piece is a solid face over a visible lower edge; the face sinks by
//  `travel` under the finger and springs back.
//

import Foundation
import CoreGraphics

nonisolated enum PieceSize: Sendable {
    case compact, regular, large
}

nonisolated struct PieceSpec: Equatable, Sendable {
    let compactDepth: CGFloat
    let regularDepth: CGFloat
    let largeDepth: CGFloat
    /// Seconds for the face to reach the bottom on press (fast ease-out).
    let pressInDuration: Double
    /// Release spring: response seconds and damping fraction.
    let releaseResponse: Double
    let releaseDamping: Double

    func depth(for size: PieceSize) -> CGFloat {
        switch size {
        case .compact: return compactDepth
        case .regular: return regularDepth
        case .large: return largeDepth
        }
    }

    /// The pressed face leaves a 1pt edge showing (sketch 012), so travel is
    /// depth minus one, never below one.
    func travel(for size: PieceSize) -> CGFloat {
        max(1, depth(for: size) - 1)
    }

    /// Set on device by Gabe on 2026-11-27 in Phase 19.1 (D-04): he picked
    /// Medium and asked for no changes. Recorded in DESIGN.md §3.8. These are
    /// the only piece constants; every build reads them.
    static let current = PieceSpec(
        compactDepth: 2.5,
        regularDepth: 4,
        largeDepth: 6,
        pressInDuration: 0.05,
        releaseResponse: 0.2,
        releaseDamping: 0.55
    )
}

nonisolated enum PieceGeometry {
    /// Vertical offset of the face relative to its resting place.
    /// - Disabled: sits flat on its edge (`depth`), whatever else is set.
    /// - Pressed with motion: sinks by `travel`.
    /// - Motion off: never moves; the pressed cue is a fill, not travel.
    static func faceOffset(
        pressed: Bool,
        motion: Bool,
        enabled: Bool,
        depth: CGFloat,
        travel: CGFloat
    ) -> CGFloat {
        guard enabled else { return depth }
        guard pressed, motion else { return 0 }
        return travel
    }
}
