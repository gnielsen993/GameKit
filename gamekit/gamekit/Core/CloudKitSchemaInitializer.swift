//
//  CloudKitSchemaInitializer.swift
//  gamekit
//
//  P6 (Pitfall D — RESEARCH §Common Pitfalls): one-shot DEBUG helper that
//  materializes the SwiftData @Model record types (GameRecord, BestTime) in
//  the CloudKit Dashboard Development environment for container
//  iCloud.com.lauterstar.gamekit.
//
//  Why this is needed: SwiftData/CloudKit JIT schema creation works for
//  record WRITES, but record-type metadata (queryable / indexable / unique
//  attrs) requires explicit `initializeCloudKitSchema()` deployment.
//  Without it, SC3 (Plan 06-09 2-device promotion test) fails with
//  "schema not found" sync errors.
//
//  Why bridge to Core Data: SwiftData has no native API for
//  initializeCloudKitSchema() in iOS 17/18 (Pitfall D + RESEARCH §A7).
//  The bridge constructs an NSPersistentCloudKitContainer from the
//  SwiftData @Model types via NSManagedObjectModel.makeManagedObjectModel.
//
//  T-06-schema-prod-leak mitigation: ENTIRE file gated by #if DEBUG.
//  Release builds see zero symbols.
//
//  T-06-06 lock: container literal "iCloud.com.lauterstar.gamekit"
//  identical to PROJECT.md:141 + GameKitApp.swift:60 + ModelContainerSmokeTests
//  + gamekit.entitlements doc-comment.
//
//  Invocation: lldb expr after launching debug build:
//    expr try? GameKitApp._runtimeDeployCloudKitSchema()
//  Then verify in CloudKit Dashboard Development → iCloud.com.lauterstar.gamekit.
//  Run ONCE per Apple Developer account; remove invocation before TestFlight.
//

#if DEBUG
import CoreData
import Foundation
import SwiftData

@MainActor
enum CloudKitSchemaInitializer {
    static func deployDevelopmentSchema() throws {
        let storeURL = URL.applicationSupportDirectory
            .appending(path: "default.store")

        let desc = NSPersistentStoreDescription(url: storeURL)
        let opts = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.lauterstar.gamekit"
        )
        desc.cloudKitContainerOptions = opts
        desc.shouldAddStoreAsynchronously = false

        guard let mom = NSManagedObjectModel.makeManagedObjectModel(
            for: [GameRecord.self, BestTime.self]
        ) else {
            throw NSError(
                domain: "CloudKitSchemaInitializer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Failed to build NSManagedObjectModel from SwiftData types"]
            )
        }

        let container = NSPersistentCloudKitContainer(
            name: "GameKit",
            managedObjectModel: mom
        )
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, err in loadError = err }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema()

        // Release file locks before SwiftData container takes over
        // (next launch with cloudSyncEnabled = true).
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
#endif
