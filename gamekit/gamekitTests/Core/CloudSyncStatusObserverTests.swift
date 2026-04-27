//
//  CloudSyncStatusObserverTests.swift
//  gamekitTests
//
//  Swift Testing coverage for the Plan 06-05 Core/CloudSyncStatusObserver
//  service — the 4-state machine that drives the SettingsView SYNC row.
//
//  What this proves (PERSIST-06):
//    - SyncStatus 4-state machine state transitions per CONTEXT D-10:
//        endDate == nil           → .syncing
//        endDate != nil + success → .syncedAt(endDate); lastSyncDate updated
//        endDate != nil + failure → .unavailable(lastSynced: lastSyncDate)
//    - Initial-status injection contract — `init(initialStatus:)` defaults
//      to `.notSignedIn` (cloudSync OFF) and accepts `.syncing` (cloudSync ON,
//      observer should flip to .syncedAt within 1-2s in production).
//    - Relative-time label format on the pure-function `SyncStatus.label(at:)`
//      (Plan 06-02 — already shipped in Core/SyncStatus.swift). These tests
//      lock the labels SettingsView (Plan 06-07) will consume:
//        < 60s  → "Synced just now"
//        ≥ 60s  → "Synced X ago"   (RelativeDateTimeFormatter, .named, .full)
//        unavail→ "iCloud unavailable" (locale-stable; no formatter)
//
//  Why @MainActor struct: CloudSyncStatusObserver is a @MainActor @Observable
//  class (per RESEARCH §Pattern 5 line 554), so all calls require main-actor
//  isolation. Mirrors HapticsTests.swift:34-36.
//
//  Why applyEvent_forTesting seam: NSPersistentCloudKitContainer.Event has
//  no public initializer (PATTERNS §7 lines 419-431). Tests cannot fabricate
//  a real Event payload to post via NotificationCenter; the cleanest path is
//  a #if DEBUG internal func applyEvent_forTesting(...) seam on the observer
//  that bypasses the notification path and tests the translator function
//  directly. Mirrors SFXPlayer's #if DEBUG internal var lastInvocationAttempt
//  (SFXPlayer.swift:158) and Haptics' #if DEBUG internal static func
//  resetForTesting() (Haptics.swift:117-120).
//
//  TDD RED gate: this file compile-fails until Plan 06-05 ships
//  Core/CloudSyncStatusObserver.swift. Expected error message:
//    "cannot find 'CloudSyncStatusObserver' in scope"
//  Plan 06-05's feat(06-05) commit will turn 9/9 tests GREEN.
//

import Testing
import Foundation
import CoreData
@testable import gamekit

@MainActor
@Suite("CloudSyncStatusObserver")
struct CloudSyncStatusObserverTests {

    // MARK: - State-machine tests (5)

    @Test("Initial status defaults to .notSignedIn when no argument is passed")
    func initialStatus_notSignedIn_default() {
        let observer = CloudSyncStatusObserver()
        #expect(observer.status == .notSignedIn)
    }

    @Test("Initial status accepts an explicit .syncing seed (cloudSync = ON path)")
    func initialStatus_syncing_explicit() {
        let observer = CloudSyncStatusObserver(initialStatus: .syncing)
        #expect(observer.status == .syncing)
    }

    @Test("eventChangedNotification with endDate=nil flips status to .syncing")
    func event_endDateNil_flipsToSyncing() {
        let observer = CloudSyncStatusObserver(initialStatus: .notSignedIn)

        // Fully-qualified EventType used here to lock the seam signature
        // (per PATTERNS §S5 lines 941-945 — applyEvent_forTesting MUST accept
        // type: NSPersistentCloudKitContainer.EventType). Other call sites
        // below rely on Swift type inference (`.export`, `.import`).
        let setupType: NSPersistentCloudKitContainer.EventType = .setup

        observer.applyEvent_forTesting(
            type: setupType,
            endDate: nil,
            succeeded: false,
            error: nil
        )

        #expect(observer.status == .syncing)
    }

    @Test("eventChangedNotification with succeeded=true flips status to .syncedAt(endDate)")
    func event_succeeded_flipsToSyncedAt() {
        let observer = CloudSyncStatusObserver(initialStatus: .notSignedIn)
        let endDate = Date(timeIntervalSince1970: 1_700_000_000)

        observer.applyEvent_forTesting(
            type: .export,
            endDate: endDate,
            succeeded: true,
            error: nil
        )

        #expect(observer.status == .syncedAt(endDate))
    }

    @Test("Failed event after a prior success flips to .unavailable(lastSynced: priorSuccessDate)")
    func event_failed_flipsToUnavailable_withLastSynced() {
        let observer = CloudSyncStatusObserver(initialStatus: .notSignedIn)
        let firstSuccess = Date(timeIntervalSince1970: 1_700_000_000)
        let laterFailure = Date(timeIntervalSince1970: 1_700_000_120)

        // Step 1 — succeed once: status flips to .syncedAt, lastSyncDate = firstSuccess
        observer.applyEvent_forTesting(
            type: .export,
            endDate: firstSuccess,
            succeeded: true,
            error: nil
        )
        #expect(observer.status == .syncedAt(firstSuccess))

        // Step 2 — fail: status flips to .unavailable carrying the prior success date
        observer.applyEvent_forTesting(
            type: .import,
            endDate: laterFailure,
            succeeded: false,
            error: NSError(domain: "CKErrorDomain", code: 7, userInfo: nil)
        )
        #expect(observer.status == .unavailable(lastSynced: firstSuccess))
    }

    // MARK: - Relative-time label tests (4) — locks SyncStatus.label(at:) contract

    @Test("Synced just now — < 60s")
    func label_lessThan60s_isJustNow() {
        let now = Date()
        let recent = now.addingTimeInterval(-30)
        let label = SyncStatus.syncedAt(recent).label(at: now)
        #expect(label.contains("just now"))
    }

    @Test("Synced X minutes ago — 5 minutes back")
    func label_minutes_isXAgo() {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300)
        let label = SyncStatus.syncedAt(fiveMinutesAgo).label(at: now)
        #expect(label.contains("minute"))
        #expect(label.hasPrefix("Synced"))
    }

    @Test("Synced X hours ago — 2 hours back")
    func label_hours_isXAgo() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let label = SyncStatus.syncedAt(twoHoursAgo).label(at: now)
        #expect(label.contains("hour"))
    }

    @Test("Unavailable label is the plain locale-stable string (no formatter)")
    func label_unavailable_isPlainString() {
        let label = SyncStatus.unavailable(lastSynced: nil).label(at: .now)
        #expect(label == "iCloud unavailable")
    }
}
