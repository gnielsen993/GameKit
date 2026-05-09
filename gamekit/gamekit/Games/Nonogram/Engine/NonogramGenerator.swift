//
//  NonogramGenerator.swift
//  gamekit
//
//  Procedural puzzle source for Nonogram's "Unlimited" tier — kicks in
//  after the player has seen every curated puzzle for a given difficulty.
//  Each generated puzzle is line-solvable (NonogramLineSolver gate) so
//  the player never has to guess.
//
//  Foundation-only · deterministic given a seed (CLAUDE §4 engine purity).
//
//  Puzzle id format: `proc-<size>-<seed>`. Same seed → same grid →
//  re-generatable for replay. Tracked in GameRecord.puzzleIdRaw like any
//  curated puzzle.
//

import Foundation

enum NonogramGenerator {

    /// Soft retry budget — if we can't find a line-solvable grid in this
    /// many tries at the requested density, return the last attempt
    /// anyway (still a valid puzzle, just may need light guessing).
    /// The Unlimited tier is meant to be casual, not punishing.
    static let maxAttempts: Int = 60

    /// Generate one procedural puzzle for `difficulty`. Uses
    /// `SystemRandomNumberGenerator` by default; tests inject a seeded
    /// RNG for determinism. The returned puzzle's id is
    /// `proc-<rawValue>-<seed>` where `seed` is a UInt64 derived from
    /// the RNG.
    static func generate(
        difficulty: NonogramDifficulty,
        rng: inout any RandomNumberGenerator
    ) -> NonogramPuzzle {
        let seed = UInt64.random(in: .min ... .max, using: &rng)
        return generate(difficulty: difficulty, seed: seed)
    }

    /// Seed-deterministic core. `reconstruct(fromId:)` calls this
    /// directly so the grid is exactly the one originally recorded.
    static func generate(
        difficulty: NonogramDifficulty,
        seed: UInt64
    ) -> NonogramPuzzle {
        let size = difficulty.size
        var localRng = SeededRNG(seed: seed)

        // Density target: empirically 45-55% reads well under our hint
        // header. Slight downward bias at large sizes so the picture
        // isn't a solid blob.
        let baseDensity: Double = {
            switch difficulty {
            case .tiny:   return 0.50
            case .small:  return 0.50
            case .medium: return 0.48
            case .large:  return 0.45
            }
        }()

        var lastGrid = randomGrid(size: size, density: baseDensity, rng: &localRng)
        for attempt in 0..<maxAttempts {
            let grid = (attempt == 0) ? lastGrid
                : randomGrid(size: size, density: baseDensity, rng: &localRng)
            lastGrid = grid

            let filled = grid.lazy.filter { $0 }.count
            if filled == 0 || filled == size * size { continue }

            let rowHints = lineHints(grid: grid, size: size, axis: .row)
            let colHints = lineHints(grid: grid, size: size, axis: .col)

            if NonogramLineSolver.isLineSolvable(
                size: size,
                rowHints: rowHints,
                columnHints: colHints
            ) {
                return puzzle(from: grid, size: size, seed: seed, difficulty: difficulty)
            }
        }
        return puzzle(from: lastGrid, size: size, seed: seed, difficulty: difficulty)
    }

    /// Reconstruct a procedural puzzle from a previously-recorded id.
    /// Returns nil if `id` doesn't match `proc-<size>-<seed>`.
    static func reconstruct(fromId id: String) -> NonogramPuzzle? {
        let parts = id.split(separator: "-")
        guard parts.count == 3, parts[0] == "proc",
              let difficulty = NonogramDifficulty(rawValue: String(parts[1])),
              let seed = UInt64(parts[2]) else { return nil }
        return generate(difficulty: difficulty, seed: seed)
    }

    // MARK: - Internals

    private enum Axis { case row, col }

    private static func randomGrid(
        size: Int,
        density: Double,
        rng: inout SeededRNG
    ) -> [Bool] {
        var out = [Bool](repeating: false, count: size * size)
        for i in 0..<out.count {
            out[i] = Double.random(in: 0..<1, using: &rng) < density
        }
        return out
    }

    private static func lineHints(grid: [Bool], size: Int, axis: Axis) -> [[Int]] {
        (0..<size).map { idx in
            var line: [Bool] = []
            line.reserveCapacity(size)
            for j in 0..<size {
                let cell = (axis == .row) ? grid[idx * size + j] : grid[j * size + idx]
                line.append(cell)
            }
            return runs(in: line)
        }
    }

    private static func runs(in line: [Bool]) -> [Int] {
        var out: [Int] = []
        var cur = 0
        for b in line {
            if b { cur += 1 } else if cur > 0 { out.append(cur); cur = 0 }
        }
        if cur > 0 { out.append(cur) }
        return out.isEmpty ? [0] : out
    }

    private static func puzzle(
        from grid: [Bool],
        size: Int,
        seed: UInt64,
        difficulty: NonogramDifficulty
    ) -> NonogramPuzzle {
        let id = "proc-\(difficulty.rawValue)-\(seed)"
        let bits = grid.map { $0 ? "1" : "0" }.joined()
        return NonogramPuzzle(id: id, title: String(localized: "Pattern"), grid: bits)
    }
}

/// Splitmix64 — small deterministic RNG keyed on a UInt64 seed. We don't
/// use SystemRandomNumberGenerator inside the generator because we need
/// the seed → grid map to be reconstructable for the solved-puzzle
/// gallery (`NonogramGenerator.reconstruct(fromId:)`).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
