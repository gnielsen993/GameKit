//
//  CloudSyncStatusObserver.swift
//  gamekit
//
//  P6 (D-11): @Observable @MainActor app-level singleton constructed in
//  GameKitApp.init() after AuthStore. Subscribes to CoreData's
//  `NSPersistentCloudKitContainer.eventChangedNotification` and translates
//  events into the 4-state `SyncStatus` enum (Plan 06-02) consumed by
//  the SettingsView SYNC status row (Plan 06-07).
//
//  P6 (D-12): subscribes to NSPersistentCloudKitContainer.eventChangedNotification;
//  status updates immediately on every event (no polling, no refresh cadence —
//  the notification IS the refresh trigger).
//
//  Pitfall A (RESEARCH): SwiftData has no native sync-status API — observe
//  the Core Data layer. The notification fires for SwiftData-backed stores
//  too because `ModelContainer(... cloudKitDatabase: .private)` materialises
//  an `NSPersistentCloudKitContainer` underneath.
//
//  Threat-model mitigations (Plan 06-05 register):
//    - T-06-state-bg-write (Tampering): notification fires on a background
//      thread; the @objc selector is `nonisolated` so it CAN reach from
//      background, then hops to MainActor inside `Task { @MainActor in ... }`
//      before mutating `status`. Class-level @MainActor isolation prevents
//      any direct cross-actor write.
//    - T-06-state-drift (Tampering): translator switches exhaustively over
//      the 4 SyncStatus cases via the (endDate, succeeded) shape; adding a
//      5th case to SyncStatus forces a compile error here OR in callers.
//    - T-06-A1 (Information Disclosure, low): defensive `guard let event =
//      ... as? Event else { return }` short-circuits if the userInfo cast
//      fails (key verified at RESEARCH §A1 — eventNotificationUserInfoKey).
//    - T-06-pitfall-3 (Loss of Availability): failure path → .unavailable
//      with carry-over `lastSyncDate`; logger.error logs at .public privacy
//      with error.localizedDescription only (no PII).
//
//  PATTERNS §S5: NSPersistentCloudKitContainer.Event has no public
//  initializer, so tests cannot fabricate Events to post via NotificationCenter.
//  The `#if DEBUG applyEvent_forTesting(...)` seam bypasses the notification
//  path and exercises the translator directly. Mirrors SFXPlayer.swift:152-170
//  (#if DEBUG internal seams) and Haptics.swift:71-98 (non-fatal logger pattern).
//

import Foundation
import CoreData         // NSPersistentCloudKitContainer.eventChangedNotification (Pitfall A)
import SwiftUI          // EnvironmentKey
import os

// MARK: - CloudSyncStatusObserver

@Observable
@MainActor
final class CloudSyncStatusObserver {

    // MARK: - Logger (S2 — non-fatal logger pattern)

    private static let logger = Logger(
        subsystem: "com.lauterstar.gamekit",
        category: "cloudkit"
    )

    // MARK: - Published state (PATTERNS §2 line 171: private(set) — observer is the only writer)

    /// Read-only outside this class. Views consume `\.cloudSyncStatusObserver`
    /// via `@Environment` and read `.status` directly; `Bindable` is forbidden
    /// by design (no two-way mutation surface — only the translator may write).
    private(set) var status: SyncStatus

    // MARK: - Private state

    /// Carries the last successful sync timestamp across status changes so
    /// `.unavailable(lastSynced:)` reflects the most recent good handshake.
    private var lastSyncDate: Date?

    // MARK: - Init

    /// `initialStatus` defaults to `.notSignedIn` (cloudSync OFF path); the
    /// SettingsStore-driven cloudSync-ON path will pass `.syncing` so the
    /// SettingsView SYNC row reads "Syncing…" until the first event lands.
    init(initialStatus: SyncStatus = .notSignedIn) {
        self.status = initialStatus
        // Selector form so the @objc method can be reached from the
        // background queue Apple's CoreData notification posts on.
        // The @objc method itself is `nonisolated` and hops to MainActor
        // inside its body (T-06-state-bg-write mitigation).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification handler

    /// Called on whatever thread NotificationCenter dispatches; hops to
    /// MainActor via `Task { @MainActor in ... }` before mutating `status`
    /// (T-06-state-bg-write mitigation per PATTERNS §2 line 192).
    ///
    /// The Event payload is extracted *off* main (read-only access to
    /// Apple-provided value-type-like properties is thread-safe) and only
    /// the translator hop carries an isolated, snapshot-based parameter
    /// list — this avoids capturing the full `event` reference into the
    /// `Task` closure.
    @objc nonisolated private func handleEvent(_ notification: Notification) {
        // RESEARCH §A1: userInfo key verified — eventNotificationUserInfoKey.
        // T-06-A1 mitigation: defensive cast — early-return on nil/mismatch.
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        // Snapshot the event off-main; only Sendable scalars cross the hop.
        let snapshot = (
            type: event.type,
            endDate: event.endDate,
            succeeded: event.succeeded,
            error: event.error
        )

        Task { @MainActor [weak self] in
            self?.applyEvent(
                type: snapshot.type,
                endDate: snapshot.endDate,
                succeeded: snapshot.succeeded,
                error: snapshot.error
            )
        }
    }

    /// Pure translator — single source of truth for the 4-state machine.
    /// Used by the production `handleEvent` path AND the `#if DEBUG` test
    /// seam because `NSPersistentCloudKitContainer.Event` has no public
    /// initializer (PATTERNS §S5).
    ///
    /// State transitions (RESEARCH §Pattern 5 lines 588-611):
    ///   - endDate == nil           → .syncing
    ///   - endDate != nil + success → .syncedAt(endDate); lastSyncDate := endDate
    ///   - endDate != nil + failure → .unavailable(lastSynced: lastSyncDate)
    private func applyEvent(
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        succeeded: Bool,
        error: Error?
    ) {
        if endDate == nil {
            status = .syncing
            return
        }
        if succeeded {
            lastSyncDate = endDate
            status = .syncedAt(endDate ?? Date())
        } else {
            if let error {
                // T-06-pitfall-3: surface failure to log at .public privacy
                // with localizedDescription only (no PII).
                Self.logger.error(
                    "CloudKit \(String(describing: type), privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            status = .unavailable(lastSynced: lastSyncDate)
        }
    }

    // MARK: - DEBUG test seam (PATTERNS §S5)

    #if DEBUG
    /// Direct entry to the translator. Plan 06-02 tests use this because
    /// `NSPersistentCloudKitContainer.Event` has no public initializer
    /// — fabricating a real Event payload to post via NotificationCenter
    /// is impossible. Visible only via `@testable import gamekit`.
    internal func applyEvent_forTesting(
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        succeeded: Bool,
        error: Error?
    ) {
        applyEvent(type: type, endDate: endDate, succeeded: succeeded, error: error)
    }
    #endif
}

// MARK: - EnvironmentKey injection (PATTERNS §S1; mirrors SettingsStore.swift:124-135)

private struct CloudSyncStatusObserverKey: EnvironmentKey {
    @MainActor static let defaultValue = CloudSyncStatusObserver()
}

extension EnvironmentValues {
    var cloudSyncStatusObserver: CloudSyncStatusObserver {
        get { self[CloudSyncStatusObserverKey.self] }
        set { self[CloudSyncStatusObserverKey.self] = newValue }
    }
}
