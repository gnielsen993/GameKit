//
//  PieceSpecTests.swift
//  gamekitTests
//
//  Geometry invariants for the piece primitive (Phase 19.1, DESIGN.md §3.8).
//  Pure: no SwiftUI, no environment. Depths are the Medium starting values
//  from sketch 012.
//

import Testing
import Foundation
@testable import gamekit

@Suite("PieceSpec")
nonisolated struct PieceSpecTests {

    private let spec = PieceSpec.current

    @Test("current depths are 2.5 / 4 / 6 for compact / regular / large")
    func currentDepths() {
        #expect(spec.depth(for: .compact) == 2.5)
        #expect(spec.depth(for: .regular) == 4)
        #expect(spec.depth(for: .large) == 6)
    }

    @Test("travel is depth minus one, never below one")
    func travelIsDepthMinusOne() {
        #expect(spec.travel(for: .compact) == 1.5)
        #expect(spec.travel(for: .regular) == 3)
        #expect(spec.travel(for: .large) == 5)
        let flat = PieceSpec(
            compactDepth: 1, regularDepth: 1, largeDepth: 1,
            pressInDuration: 0.05, releaseResponse: 0.2, releaseDamping: 0.55
        )
        #expect(flat.travel(for: .regular) == 1)
    }

    @Test("travel stays inside the edge so a pressed face still leaves edge showing")
    func travelLeavesEdge() {
        for size in [PieceSize.compact, .regular, .large] {
            #expect(spec.travel(for: size) >= 1)
            #expect(spec.travel(for: size) < spec.depth(for: size))
        }
    }

    @Test("sizes are strictly ordered compact < regular < large")
    func sizesOrdered() {
        #expect(spec.depth(for: .compact) < spec.depth(for: .regular))
        #expect(spec.depth(for: .regular) < spec.depth(for: .large))
        #expect(spec.travel(for: .compact) < spec.travel(for: .regular))
        #expect(spec.travel(for: .regular) < spec.travel(for: .large))
    }

    @Test("enabled and not pressed: face rests at zero")
    func restingOffset() {
        let y = PieceGeometry.faceOffset(pressed: false, motion: true, enabled: true, depth: 4, travel: 3)
        #expect(y == 0)
    }

    @Test("enabled and pressed with motion: face sinks by travel")
    func pressedOffset() {
        let y = PieceGeometry.faceOffset(pressed: true, motion: true, enabled: true, depth: 4, travel: 3)
        #expect(y == 3)
    }

    @Test("pressed with motion off: nothing travels")
    func pressedNoMotion() {
        let y = PieceGeometry.faceOffset(pressed: true, motion: false, enabled: true, depth: 4, travel: 3)
        #expect(y == 0)
    }

    @Test("disabled piece sits flat on its edge whatever else is set")
    func disabledOffset() {
        for pressed in [true, false] {
            for motion in [true, false] {
                let y = PieceGeometry.faceOffset(pressed: pressed, motion: motion, enabled: false, depth: 4, travel: 3)
                #expect(y == 4)
            }
        }
    }
}

#if DEBUG
@Suite("PieceSpec strengths (DEBUG)")
nonisolated struct PieceStrengthTests {

    @Test("subtle < medium < bold depths for every size")
    func strengthsAreOrdered() {
        for size in [PieceSize.compact, .regular, .large] {
            #expect(PieceSpec.subtle.depth(for: size) < PieceSpec.current.depth(for: size))
            #expect(PieceSpec.current.depth(for: size) < PieceSpec.bold.depth(for: size))
        }
    }

    @Test("medium is the shipping spec")
    func mediumIsCurrent() {
        #expect(PieceStrength.medium.spec == PieceSpec.current)
    }

    @Test("every strength keeps travel inside the edge")
    func travelInsideEdge() {
        for strength in PieceStrength.allCases {
            for size in [PieceSize.compact, .regular, .large] {
                let spec = strength.spec
                #expect(spec.travel(for: size) >= 1)
                #expect(spec.travel(for: size) < spec.depth(for: size))
            }
        }
    }

    @Test("resolved maps raw values and falls back to medium")
    func resolvedMapping() {
        #expect(PieceSpec.resolved(strengthRaw: nil) == .current)
        #expect(PieceSpec.resolved(strengthRaw: "bold") == .bold)
        #expect(PieceSpec.resolved(strengthRaw: "subtle") == .subtle)
        #expect(PieceSpec.resolved(strengthRaw: "nonsense") == .current)
    }

    @Test("three strengths and a stable defaults key")
    func casesAndKey() {
        #expect(PieceStrength.allCases.count == 3)
        #expect(PieceStrength.defaultsKey == "gamekit.debug.pieceStrength")
    }
}
#endif
