//
//  SudokuPuzzlePoolTests.swift
//  gamekitTests
//

import XCTest
@testable import gamekit

@MainActor
final class SudokuPuzzlePoolTests: XCTestCase {

    /// Pool initialized against the real bundled SudokuPuzzles.json
    /// (40-puzzle placeholder pack from Phase 14).
    private func makeRealPool() -> SudokuPuzzlePool {
        SudokuPuzzlePool()
    }

    func test_loadsRealBundleResource() async throws {
        let pool = makeRealPool()
        let pack = try await pool.load()
        XCTAssertEqual(pack.schemaVersion, 1)
        XCTAssertEqual(pack.generatorSourceSha, "b02c848f62ad4ad70fc6f1079916e193cb9470ae")
        XCTAssertEqual(pack.puzzles.keys.sorted(), ["easy", "extreme", "hard", "medium"])
    }

    func test_countPerDifficulty_isAtLeastTen() async throws {
        let pool = makeRealPool()
        for d in SudokuDifficulty.allCases {
            let count = try await pool.count(for: d)
            XCTAssertGreaterThanOrEqual(count, 10, "Difficulty \(d.rawValue) has only \(count) entries")
        }
    }

    func test_next_returnsUnplayedEntry() async throws {
        let pool = makeRealPool()
        let first = try await pool.next(difficulty: .easy, playedIDs: [])
        XCTAssertEqual(first.givens.count, 81)
        XCTAssertEqual(first.solution.count, 81)
        XCTAssertGreaterThan(first.givenCount, 0)
    }

    func test_next_skipsPlayedIDs() async throws {
        let pool = makeRealPool()
        let first = try await pool.next(difficulty: .easy, playedIDs: [])
        let second = try await pool.next(difficulty: .easy, playedIDs: [first.id])
        XCTAssertNotEqual(first.id, second.id)
    }

    func test_next_recyclesWhenExhausted() async throws {
        let pool = makeRealPool()
        let pack = try await pool.load()
        guard let entries = pack.puzzles["easy"], entries.count >= 1 else {
            return XCTFail("Expected easy pool to have entries")
        }
        let everyID = Set(entries.map { $0.id })
        // With every ID marked played, pool should still return a valid entry.
        let recycled = try await pool.next(difficulty: .easy, playedIDs: everyID)
        XCTAssertEqual(entries.first?.id, recycled.id)
    }

    func test_decodeFails_onMalformedBundleResource() async {
        // Use a bundle that has no SudokuPuzzles.json under the wrong name.
        let pool = SudokuPuzzlePool(bundle: .main, resourceName: "DoesNotExist", resourceExtension: "json")
        do {
            _ = try await pool.load()
            XCTFail("Expected throw")
        } catch SudokuPuzzlePool.PoolError.bundleResourceMissing {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
