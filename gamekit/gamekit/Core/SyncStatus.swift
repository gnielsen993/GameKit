//
//  SyncStatus.swift
//  gamekit
//
//  P6 (D-10): 4-state enum read by Settings SYNC status row + driven by
//  CloudSyncStatusObserver. Pure value type — no SwiftUI / no SwiftData
//  imports. Lives as a sibling of CloudSyncStatusObserver.swift per the
//  CONTEXT discretion call (PATTERNS §3 Discretion); promoted out of the
//  observer file to keep the observer under the CLAUDE.md §8.1 ~400-line
//  cap and to preserve Outcome.swift / GameKind.swift sibling-file precedent.
//
//  Phase 6 invariants (per D-10):
//    - 4 cases verbatim from RESEARCH §Pattern 5 lines 556-561 — adding a
//      5th case forces a compile error in `label(at:)` switch (T-06-state-drift
//      mitigation: exhaustive match).
//    - `Equatable, Sendable` only — NOT Hashable, NOT Codable. Transient
//      view-layer enum, never persisted (matches MinesweeperGameState
//      precedent from Plan 02-01).
//    - `func label(at now: Date) -> String` takes `now` explicitly so callers
//      (TimelineView in Plan 06-07, tests in CloudSyncStatusObserverTests)
//      drive determinism — never reads `Date.now` internally.
//

import Foundation

/// 4-state sync status surfaced in the SettingsView SYNC status row.
/// Driven by `CloudSyncStatusObserver` (Plan 06-05). Pure value type.
enum SyncStatus: Equatable, Sendable {
    case syncing
    case syncedAt(Date)
    case notSignedIn
    case unavailable(lastSynced: Date?)
}

extension SyncStatus {
    /// Primary label string for the SettingsView SYNC status row.
    /// Takes `now` explicitly so callers (TimelineView in Plan 06-07,
    /// tests below) drive determinism — never reads Date.now internally.
    ///
    /// Sub-line for .unavailable(lastSynced:) is rendered by SettingsView,
    /// not by this method (CONTEXT D-10 line 199-200).
    func label(at now: Date) -> String {
        switch self {
        case .syncing:
            return String(localized: "Syncing…")
        case .syncedAt(let date):
            if now.timeIntervalSince(date) < 60 {
                return String(localized: "Synced just now")
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.dateTimeStyle = .named
            return String(
                format: String(localized: "Synced %@"),
                formatter.localizedString(for: date, relativeTo: now)
            )
        case .notSignedIn:
            return String(localized: "Not signed in")
        case .unavailable:
            return String(localized: "iCloud unavailable")
        }
    }
}
