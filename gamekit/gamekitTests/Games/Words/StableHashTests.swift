import Foundation
import Testing
@testable import gamekit

/// These golden values are a product contract, not an implementation detail.
/// They decide which puzzle every player receives on a given date, so if one
/// of them fails, the daily word changed for everyone — fix the code, do not
/// update the expectation.
@Suite("StableHash")
struct StableHashTests {
    @Test("FNV-1a golden values are frozen")
    func goldenValues() {
        // Reference FNV-1a/64 offset basis — the hash of the empty string.
        #expect(StableHash.fnv1a("") == 14_695_981_039_346_656_037)
        #expect(StableHash.fnv1a("a") == 12_638_187_200_555_641_996)
        #expect(StableHash.fnv1a("2026-07-31") == 12_379_822_423_690_054_150)
        #expect(StableHash.fnv1a("2026-08-01") == 4_395_687_841_058_506_242)
        #expect(StableHash.fnv1a("2000-01-01") == 12_652_529_679_025_355_847)
    }

    @Test("same input hashes identically within a run")
    func deterministic() {
        #expect(StableHash.fnv1a("2026-07-31") == StableHash.fnv1a("2026-07-31"))
        #expect(StableHash.index(for: "2026-07-31", upperBound: 1033)
                == StableHash.index(for: "2026-07-31", upperBound: 1033))
    }

    @Test("adjacent dates do not collide")
    func adjacentDatesDiffer() {
        #expect(StableHash.fnv1a("2026-07-31") != StableHash.fnv1a("2026-08-01"))
    }

    @Test("index stays in range, including the empty and single-element cases")
    func indexInRange() {
        #expect(StableHash.index(for: "anything", upperBound: 0) == 0)
        #expect(StableHash.index(for: "anything", upperBound: 1) == 0)
        for day in 1...31 {
            let id = String(format: "2026-07-%02d", day)
            let index = StableHash.index(for: id, upperBound: 1033)
            #expect(index >= 0)
            #expect(index < 1033)
        }
    }

    /// A year of dates should spread across the pool rather than clustering.
    /// Not a randomness proof — a smoke test that the modulo mapping is not
    /// degenerate (e.g. every date landing on one word).
    @Test("a year of dates spreads across the pool")
    func distribution() {
        var seen = Set<Int>()
        for month in 1...12 {
            for day in 1...28 {
                let id = String(format: "2026-%02d-%02d", month, day)
                seen.insert(StableHash.index(for: id, upperBound: 1033))
            }
        }
        // 336 draws from 1033 slots. The birthday expectation is
        // 1033 * (1 - (1 - 1/1033)^336) ~= 287 distinct, and this input set
        // yields 292. The bound is set well below that mean: it catches
        // degenerate clustering, not ordinary collisions.
        #expect(seen.count > 250)
    }
}
