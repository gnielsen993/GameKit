//
//  InMemoryKeychainBackend.swift
//  gamekitTests
//
//  Test-only KeychainBackend stub (D-16). In-memory dictionary; no SecItem
//  calls; no host-app entitlement needed.
//
//  Critical placement: TEST TARGET ONLY. If this file ends up in the
//  production app target, the AuthStore default-value EnvironmentKey
//  would silently swap to the in-memory backend in release builds.
//
//  Why @MainActor: AuthStore is @MainActor; KeychainBackend conformers
//  must align. Mirrors InMemoryStatsContainer.swift:35-36.
//
//  Why class-with-dictionary: matches RESEARCH Pattern 3 lines 458-463
//  test-stub idiom; in-memory state means tests are deterministic without
//  a tearDown step.
//

import Foundation
@testable import gamekit

@MainActor
final class InMemoryKeychainBackend: KeychainBackend {
    private var store: [String: String] = [:]

    func read(account: String) -> String? { store[account] }
    func write(_ value: String, account: String) throws { store[account] = value }
    func delete(account: String) throws { store[account] = nil }
}
