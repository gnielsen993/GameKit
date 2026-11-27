//
//  PieceTuning.swift
//  gamekit
//
//  DEBUG-only Subtle / Medium / Bold strengths for the piece (Phase 19.1,
//  D-03 to D-05). One switch moves edge depth, travel and spring together so
//  Gabe can compare three feels on device. Whole file is compiled out of
//  Release; the key lives in UserDefaults (via @AppStorage), deliberately
//  not in SettingsStore, where it would ship. Deleted with the Settings
//  section once the device pick is made.
//

#if DEBUG

import Foundation

nonisolated enum PieceStrength: String, CaseIterable, Identifiable, Sendable {
    case subtle, medium, bold

    static let defaultsKey = "gamekit.debug.pieceStrength"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .medium: return "Medium"
        case .bold: return "Bold"
        }
    }

    var spec: PieceSpec {
        switch self {
        case .subtle: return .subtle
        case .medium: return .current
        case .bold: return .bold
        }
    }
}

nonisolated extension PieceSpec {
    /// Quieter than Medium: a thin edge and a settled release.
    static let subtle = PieceSpec(
        compactDepth: 2,
        regularDepth: 2.5,
        largeDepth: 4,
        pressInDuration: 0.05,
        releaseResponse: 0.18,
        releaseDamping: 0.8
    )

    /// Chunkier than Medium: a deep edge and a bouncier release.
    static let bold = PieceSpec(
        compactDepth: 3.5,
        regularDepth: 6,
        largeDepth: 8,
        pressInDuration: 0.05,
        releaseResponse: 0.24,
        releaseDamping: 0.45
    )

    /// Unknown or missing raw values resolve to Medium.
    static func resolved(strengthRaw: String?) -> PieceSpec {
        guard let raw = strengthRaw, let strength = PieceStrength(rawValue: raw) else {
            return .current
        }
        return strength.spec
    }
}

#endif
