//
//  VideoModeLocation.swift
//  gamekit
//
//  The six locked PiP zones the user can pin the video preview to, per
//  CONTEXT D-07 vocabulary. Raw values are the stable serialization key for
//  `VideoModeStore` (D-06) — renaming any case = preference loss on existing
//  installs (D-07 lock). Listing order matches CONTEXT D-07 verbatim.
//
//  Phase 9 invariants (per D-03, D-06, D-07):
//    - No JSON-Encodable conformance — this enum is UserDefaults-only,
//      never exported to JSON (per 09-PATTERNS.md §2)
//    - No main-actor-decoupling modifier — Phase 10/11 layout views read on
//      the main actor; the enum stays implicitly main-actor-friendly
//    - 6 cases only — adding a 7th case is a future-phase decision and a
//      VIDEO-02 contract change
//    - `.largeBottom` is the D-03 default (mirrors iOS native PiP dock and
//      exercises the Hard-Mines squeeze case from Phase 8 ADR)
//
//  Foundation-only — no SwiftUI import keeps the enum reusable from any
//  context (engine layer, tests, snapshot rigs).
//

import Foundation

/// The six PiP zones Video Mode can pin the preview to (CONTEXT D-07).
/// Raw values are the stable UserDefaults serialization key — renaming = loss.
enum VideoModeLocation: String, CaseIterable, Sendable {
    case largeTop
    case largeBottom        // D-03 default
    case smallTopLeft
    case smallTopRight
    case smallBottomLeft
    case smallBottomRight

    /// Human-readable label sourced from Localizable.xcstrings — used for
    /// VoiceOver labels in the picker (D-09) and the "Video location: <label>"
    /// row title in Settings (09-05).
    ///
    /// NOTE: the `videoMode.location.*` keys do not yet exist in
    /// `Localizable.xcstrings` — Plan 09-04 ships those entries. Until then,
    /// `String(localized:)` falls back to the key name itself per Apple-
    /// documented behavior (the silent-fallback failure mode in 09-RESEARCH
    /// Pitfall 3 is the EXACT gap this design accepts between 09-02 and 09-04).
    var localizedLabel: String {
        switch self {
        case .largeTop:         return String(localized: "videoMode.location.largeTop")
        case .largeBottom:      return String(localized: "videoMode.location.largeBottom")
        case .smallTopLeft:     return String(localized: "videoMode.location.smallTopLeft")
        case .smallTopRight:    return String(localized: "videoMode.location.smallTopRight")
        case .smallBottomLeft:  return String(localized: "videoMode.location.smallBottomLeft")
        case .smallBottomRight: return String(localized: "videoMode.location.smallBottomRight")
        }
    }
}
