//
//  CloudAccountWiper.swift
//  gamekit
//
//  P7.1 (account-controls): wipes the user's CloudKit private-database
//  zones used by NSPersistentCloudKitContainer. Called by
//  AuthStore.deleteAccount to satisfy App Store Guideline 5.1.1(v) —
//  the in-app delete must remove cloud-side data, not only local state.
//
//  Why a zone delete (not record-by-record):
//    NSPersistentCloudKitContainer materialises a single custom zone
//    in the user's private database (default name
//    `com.apple.coredata.cloudkit.zone`). Deleting that zone wipes
//    every CD_GameRecord / CD_BestTime / CD_BestScore record in one
//    call, idempotently — no record-id enumeration required, no risk
//    of missing rows that haven't synced down yet.
//
//  Protocol seam (mirrors KeychainBackend / CredentialStateProvider):
//    AuthStoreTests inject `InMemoryCloudAccountWiper` so the unit
//    suite never touches the real CKContainer (which would require an
//    iCloud-signed device + entitlement). Production callers receive
//    `CloudKitAccountWiper` — wraps `CKContainer.privateCloudDatabase`.
//
//  Failure policy: best-effort. AuthStore.deleteAccount logs failures
//  via os.Logger and continues — local Keychain wipe + flag-flip MUST
//  proceed even if the cloud zone delete throws (offline, no iCloud
//  account, transient CloudKit error). The user can finish revocation
//  from Settings → Apple ID → Sign in with Apple → GameDrawer.
//

import Foundation
import CloudKit
import os

// MARK: - Protocol seam

/// Test-injectable CloudKit zone wiper. Production: `CloudKitAccountWiper`;
/// tests: `InMemoryCloudAccountWiper` (test target).
protocol CloudAccountWiper: Sendable {
    /// Deletes the SwiftData/CloudKit-backing zone in the user's private
    /// database. Throws on CloudKit failure; AuthStore catches + logs.
    func wipePrivateZones() async throws
}

// MARK: - Production wiper

/// Wraps `CKContainer.privateCloudDatabase`. Targets the
/// `com.apple.coredata.cloudkit.zone` custom zone that
/// `NSPersistentCloudKitContainer` materialises for SwiftData stores
/// configured with `cloudKitDatabase: .private(...)`.
final class CloudKitAccountWiper: CloudAccountWiper, @unchecked Sendable {
    // @unchecked Sendable: no instance state; CloudKit APIs are thread-safe.

    /// SwiftData/CloudKit zone name (Apple docs + RESEARCH §A1). Lock
    /// per T-06-06 — drift breaks the wipe silently.
    private static let coreDataZoneName = "com.apple.coredata.cloudkit.zone"

    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "cloudkit"
    )

    /// Container ID literal lock — must match GameKitApp + entitlements
    /// + CloudKitSchemaInitializer (T-06-06).
    private let containerIdentifier: String

    init(containerIdentifier: String = "iCloud.com.lauterstar.gamekit") {
        self.containerIdentifier = containerIdentifier
    }

    func wipePrivateZones() async throws {
        let container = CKContainer(identifier: containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: Self.coreDataZoneName,
            ownerName: CKCurrentUserDefaultName
        )
        // deleteRecordZone is async (iOS 15+). Idempotent: deleting a
        // missing zone returns success per CloudKit semantics.
        _ = try await database.deleteRecordZone(withID: zoneID)
        Self.logger.info("CloudKit private zone wiped: \(Self.coreDataZoneName, privacy: .public)")
    }
}
