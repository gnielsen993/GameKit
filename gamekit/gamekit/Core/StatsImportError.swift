//
//  StatsImportError.swift
//  gamekit
//
//  User-surfaceable failure cases for `StatsExporter.importing(_:modelContext:)`.
//  Per D-21, `schemaVersionMismatch` produces a calm, actionable alert; other
//  failures produce a generic alert. The `errorDescription` strings land in
//  `Localizable.xcstrings` via `String(localized:)` — auto-extracted at build
//  time (FOUND-05 / SWIFT_EMIT_LOC_STRINGS=YES). Plan 05's SettingsView alert
//  body re-references the same strings — single source of truth via xcstrings.
//
//  Phase 4 invariants:
//    - `Equatable` synthesized so tests can `#expect(throws: .schemaVersionMismatch(found: 99, expected: 1))`
//      against an exact case (default synthesis works for enums with associated values in Swift 6).
//    - `LocalizedError` so SwiftUI `.alert(...)` flows surface `errorDescription`
//      without manual string mapping at call sites.
//    - Foundation-only — no SwiftUI and no persistence-framework imports
//      at the error layer.
//

import Foundation

/// Failure modes for stats import. `errorDescription` literals are
/// auto-extracted into `Localizable.xcstrings` via `String(localized:)`
/// per FOUND-05 (D-21).
enum StatsImportError: LocalizedError, Equatable {
    case schemaVersionMismatch(found: Int, expected: Int)
    case decodeFailed
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .schemaVersionMismatch:
            return String(localized: "This file was exported from a newer GameKit. Update the app and try again.")
        case .decodeFailed, .fileReadFailed:
            return String(localized: "The file couldn't be read. Check that it's a GameKit stats export and try again.")
        }
    }
}
