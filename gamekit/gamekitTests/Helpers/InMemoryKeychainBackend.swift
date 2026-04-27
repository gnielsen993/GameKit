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
//  NOT @MainActor: KeychainBackend protocol is Sendable; @MainActor
//  conformance would cross actor isolation (Swift 6 strict-concurrency
//  error). Tests run on main actor by default and serialize through it,
//  so @unchecked Sendable is safe. Mirrors RESEARCH Pattern 3 lines 458-463.
//
//  Why class-with-dictionary: matches RESEARCH Pattern 3 test-stub idiom;
//  in-memory state means tests are deterministic without a tearDown step.
//

import Foundation
@testable import gamekit

final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    // @unchecked Sendable: tests post all calls from MainActor (Swift Testing
    // default), so the mutable dictionary is effectively serialized through
    // the test runner's actor. No cross-thread access in test scenarios.
    private var store: [String: String] = [:]

    func read(account: String) -> String? { store[account] }
    func write(_ value: String, account: String) throws { store[account] = value }
    func delete(account: String) throws { store[account] = nil }
}
