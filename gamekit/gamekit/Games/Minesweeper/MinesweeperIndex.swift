//
//  MinesweeperIndex.swift
//  gamekit
//
//  A grid coordinate used uniformly across the Minesweeper engine surface.
//  Hashable so engine code (Plan 03 BoardGenerator) can use Set-based
//  first-tap-safe exclusion: `Set(allCells) - {tapped} - tapped.neighbors8`.
//
//  Phase 2 invariants (per D-09):
//    - `neighbors8(rows:cols:)` is bounds-clamped — corner taps return 3
//      neighbors, edges 5, interior 8 (PITFALLS.md Pitfall 1)
//    - Hashable + Codable + Sendable — value-type discipline across the
//      entire engine + ViewModel boundary
//    - Foundation-only — ROADMAP P2 SC5
//

import Foundation

/// A grid coordinate. Hashable so engine code can use Set-based exclusion
/// (Set(allCells) - {tapped} - tapped.neighbors8) per D-09 / PITFALLS.md Pitfall 1.
/// Foundation-only — ROADMAP P2 SC5.
struct MinesweeperIndex: Hashable, Codable, Sendable {
    let row: Int
    let col: Int

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    /// Bounds-clamped 8-neighbors. Corner = 3 neighbors, edge = 5, interior = 8.
    /// PITFALLS.md Pitfall 1: "bounds-clamp neighbors so corner/edge taps exclude
    /// only valid in-board neighbors (3 or 5 neighbors clamped, not 8 plus garbage)."
    func neighbors8(rows: Int, cols: Int) -> [MinesweeperIndex] {
        var result: [MinesweeperIndex] = []
        result.reserveCapacity(8)
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let r = row + dr
                let c = col + dc
                if r >= 0 && r < rows && c >= 0 && c < cols {
                    result.append(MinesweeperIndex(row: r, col: c))
                }
            }
        }
        return result
    }
}
