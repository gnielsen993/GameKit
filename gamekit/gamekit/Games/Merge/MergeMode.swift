//
//  MergeMode.swift
//  gamekit
//
//  Two locked Merge modes for v1:
//    - `.winMode`  — banner at 2048; player may continue past it (canonical 2048).
//    - `.infinite` — no win banner; play until no legal moves.
//
//  Raw values are the stable serialization key for `GameRecord.difficultyRaw`
//  and `BestScore.difficultyRaw` (mirrors MinesweeperDifficulty discipline at
//  MinesweeperDifficulty.swift:22). Renaming = data break.
//
//  Foundation-only — no SwiftUI / SwiftData imports.
//

import Foundation

nonisolated enum MergeMode: String, CaseIterable, Codable, Sendable {
    case winMode = "win"
    case infinite

    /// The score-board target value. v1: both modes target 2048; the
    /// difference is whether crossing it surfaces a banner.
    static let winTarget: Int = 2048
}
