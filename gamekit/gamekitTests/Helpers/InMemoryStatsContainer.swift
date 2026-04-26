//
//  InMemoryStatsContainer.swift
//  gamekitTests
//
//  Test-only ModelContainer factory (D-31). Always uses
//  isStoredInMemoryOnly: true so simulator state never leaks between
//  tests. Optionally pairs with a CloudKit configuration so the SC3
//  smoke test can validate schema constraints WITHOUT contacting iCloud
//  (RESEARCH Pattern 6 + Assumption A2).
//
//  Critical placement: TEST TARGET ONLY. If this file ends up in the
//  production app target, the in-memory configuration would break
//  PERSIST-02's force-quit survival guarantee.
//
//  Why @MainActor (NOT nonisolated like P2's SeededGenerator):
//  SwiftData ModelContext is not Sendable; mainContext is main-actor-
//  bound per RESEARCH Pattern 6
//  [CITED: hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency].
//  This is the critical correction vs. P2's `nonisolated struct` test
//  scaffold (04-PATTERNS.md line 286).
//
//  Why enum-namespace: zero ivar state, factory-only — matches the P2
//  idiom (BoardGenerator / RevealEngine / WinDetector / MinesweeperVMFixtures).
//

import SwiftData
@testable import gamekit

/// Test-only factory for an in-memory ModelContainer over the P4 schema.
/// `cloudKit` defaults to `.none`; smoke tests pass
/// `.private("iCloud.com.lauterstar.gamekit")` (D-09 + D-10) to exercise
/// the CloudKit-compat constraint validation path WITHOUT contacting iCloud
/// (per Assumption A2: `isStoredInMemoryOnly: true` + `cloudKitDatabase: .private(...)`
/// validates schema constraints with no real CloudKit handshake).
@MainActor
enum InMemoryStatsContainer {
    static func make(
        cloudKit: ModelConfiguration.CloudKitDatabase = .none
    ) throws -> ModelContainer {
        let schema = Schema([GameRecord.self, BestTime.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: cloudKit
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
