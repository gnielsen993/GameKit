//
//  SeededGenerator.swift
//  gamekitTests
//
//  Deterministic SplitMix64 PRNG for engine tests (CONTEXT D-12).
//  ~15 lines of body; pure-Swift, fast, uniform.
//
//  Critical placement (D-12): TEST TARGET ONLY. If this file ends up in
//  the production app target, engine purity (ROADMAP P2 SC5) is violated
//  — production must use SystemRandomNumberGenerator, never a seedable PRNG.
//
//  Why not GameplayKit.GKMersenneTwisterRandomSource?
//  CONTEXT D-12 explicitly rejects: "No GameplayKit dependency."
//  STACK.md "What NOT to Use" reinforces.
//

import Foundation

/// SplitMix64 (Steele-Lea-Flood, 2014). One mutating field, one method,
/// uniform UInt64 output. Conforms to `RandomNumberGenerator` so it composes
/// with stdlib helpers like `Array.shuffled(using:)`.
///
/// Same seed → same sequence forever. Failure on seed N is bisectable
/// by re-running with seed N (CONTEXT D-13).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }
}
