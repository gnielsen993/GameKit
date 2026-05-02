//
//  InMemoryCloudAccountWiper.swift
//  gamekitTests
//
//  Test-only CloudAccountWiper stub (P7.1). No CKContainer; records
//  call count + a configurable error so AuthStoreTests can prove both
//  the happy path and the cloud-wipe-failed branch in deleteAccount.
//
//  TEST TARGET ONLY. Mirrors InMemoryKeychainBackend.swift's placement
//  + @unchecked Sendable rationale.
//

import Foundation
@testable import gamekit

final class InMemoryCloudAccountWiper: CloudAccountWiper, @unchecked Sendable {
    var errorToThrow: Error?
    private(set) var callCount: Int = 0

    func wipePrivateZones() async throws {
        callCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
