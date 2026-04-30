//
//  ModelContainerSmokeTests.swift
//  gamekitTests
//
//  SC3 smoke test — ModelContainer constructs successfully under both
//  `.none` and `.private("iCloud.com.lauterstar.gamekit")` configurations
//  even though sync is OFF in production (D-08). Catches CloudKit-compat
//  schema constraint violations (no SwiftData unique-attribute decorator,
//  all properties optional/defaulted, all relationships optional,
//  schemaVersion: Int = 1) the moment they land — long before P6 flips
//  on actual sync.
//
//  Phase 4 invariants (per D-09, D-10, D-30, D-31):
//    - Dual-config check: `.none` AND `.private("iCloud.com.lauterstar.gamekit")`
//      both must construct without throwing.
//    - In-memory only (D-31) — no iCloud handshake in CI per RESEARCH
//      Assumption A2.
//    - The literal "iCloud.com.lauterstar.gamekit" appears here as a
//      forcing-function lock for D-09 — any rename in PROJECT.md,
//      entitlements, or production code that doesn't also update this
//      test trips on PR.
//
//  Why @MainActor (NOT nonisolated like BoardGeneratorTests):
//  SwiftData ModelContext is not Sendable per RESEARCH Pattern 6
//  [CITED: hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency]
//  — critical correction vs. P2's `nonisolated struct` scaffold
//  (04-PATTERNS.md line 286).
//

import Testing
import Foundation
import SwiftData
@testable import gamekit

@MainActor
@Suite("ModelContainer smoke")
struct ModelContainerSmokeTests {

    // MARK: - SC3 dual-config construction

    @Test("constructs with .none cloudKitDatabase")
    func constructsWithoutCloudKit() throws {
        _ = try InMemoryStatsContainer.make(cloudKit: .none)
    }

    @Test("constructs with .private(\"iCloud.com.lauterstar.gamekit\") cloudKitDatabase")
    func constructsWithCloudKitCompat() throws {
        // D-09: container ID is iCloud.com.lauterstar.gamekit — locked. This
        // test tripping is THE forcing function if anyone later renames the
        // container.
        _ = try InMemoryStatsContainer.make(
            cloudKit: .private("iCloud.com.lauterstar.gamekit")
        )
    }

    // MARK: - Schema lock (D-10 + SC3)

    @Test("schema is exactly [GameRecord, BestTime, BestScore]")
    func schemaIsLocked() throws {
        // SC3 schema lock — prevents accidental re-ordering / additions.
        // BestScore added in the Merge phase (additive — JSON envelope
        // bumped to v2; SwiftData lightweight migration handles the model
        // addition transparently).
        let schema = Schema([GameRecord.self, BestTime.self, BestScore.self])
        #expect(schema.entities.count == 3)
        let names = schema.entities.map { $0.name }.sorted()
        #expect(names == ["BestScore", "BestTime", "GameRecord"])
    }
}
