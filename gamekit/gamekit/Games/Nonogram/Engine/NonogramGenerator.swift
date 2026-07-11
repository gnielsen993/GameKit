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
//  Puzzle id format: `proc2-<size>-<seed>` (v1 ids were `proc-<size>-<seed>`).
//  Same seed → same grid → re-generatable for replay. Tracked in
//  GameRecord.puzzleIdRaw like any curated puzzle.
//
//  Density maps are VERSIONED because the seed → grid map must stay
//  stable for every id prefix ever written to a GameRecord. v1 shipped
//  large at 0.45 density, where a random 20×20 grid passes the
//  line-solver gate ~1% of the time (measured) — the 60-attempt budget
//  was effectively always exhausted (seconds of solver work per
//  generation) AND the returned fallback usually required guessing.
//  v2 raises large to 0.55 → ~36% pass rate, expected ~3 attempts.
//  `reconstruct(fromId:)` keeps the v1 map for `proc-` ids so previously
//  recorded puzzles re-generate byte-identical.
//

import Foundation

nonisolated enum NonogramGenerator {

    /// Soft retry budget — if we can't find a line-solvable grid in this
    /// many tries at the requested density, return the last attempt
    /// anyway (still a valid puzzle, just may need light guessing).
    /// The Unlimited tier is meant to be casual, not punishing.
    static let maxAttempts: Int = 60

    /// Id prefixes per density-map version. Renaming = data break.
    static let idPrefixV1 = "proc"
    static let idPrefixV2 = "proc2"

    /// Per-difficulty fill density, per id-prefix version. See header —
    /// never edit a shipped version's values; add a new version instead.
    private static func density(for difficulty: NonogramDifficulty, version: Int) -> Double {
        switch (difficulty, version) {
        case (.tiny, _):   return 0.50
        case (.small, _):  return 0.50
        case (.medium, _): return 0.48
        case (.large, 1):  return 0.45
        case (.large, _):  return 0.55
        }
    }

    /// Generate one procedural puzzle for `difficulty`. Uses the caller's
    /// RNG only to derive a seed; the grid itself comes from the
    /// seed-deterministic core. The returned puzzle's id is
    /// `proc2-<rawValue>-<seed>`.
    static func generate(
        difficulty: NonogramDifficulty,
        rng: inout any RandomNumberGenerator
    ) -> NonogramPuzzle {
        let seed = UInt64.random(in: .min ... .max, using: &rng)
        return generate(difficulty: difficulty, seed: seed)
    }

    /// Seed-deterministic entry point — current (v2) density map.
    static func generate(
        difficulty: NonogramDifficulty,
        seed: UInt64
    ) -> NonogramPuzzle {
        generateCore(difficulty: difficulty, seed: seed, version: 2, idPrefix: idPrefixV2)
    }

    /// Seed-deterministic core, parameterized on the density-map version
    /// so `reconstruct(fromId:)` regenerates v1 ids byte-identical.
    private static func generateCore(
        difficulty: NonogramDifficulty,
        seed: UInt64,
        version: Int,
        idPrefix: String
    ) -> NonogramPuzzle {
        let size = difficulty.size
        var localRng = SeededRNG(seed: seed)

        let baseDensity = density(for: difficulty, version: version)

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
                return puzzle(from: grid, size: size, seed: seed, difficulty: difficulty, idPrefix: idPrefix)
            }
        }
        return puzzle(from: lastGrid, size: size, seed: seed, difficulty: difficulty, idPrefix: idPrefix)
    }

    /// Reconstruct a procedural puzzle from a previously-recorded id.
    /// Returns nil unless `id` matches `proc-<size>-<seed>` (v1 density
    /// map) or `proc2-<size>-<seed>` (v2).
    static func reconstruct(fromId id: String) -> NonogramPuzzle? {
        let parts = id.split(separator: "-")
        guard parts.count == 3,
              let difficulty = NonogramDifficulty(rawValue: String(parts[1])),
              let seed = UInt64(parts[2]) else { return nil }
        switch parts[0] {
        case Substring(idPrefixV1):
            return generateCore(difficulty: difficulty, seed: seed, version: 1, idPrefix: idPrefixV1)
        case Substring(idPrefixV2):
            return generateCore(difficulty: difficulty, seed: seed, version: 2, idPrefix: idPrefixV2)
        default:
            return nil
        }
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
        difficulty: NonogramDifficulty,
        idPrefix: String
    ) -> NonogramPuzzle {
        let id = "\(idPrefix)-\(difficulty.rawValue)-\(seed)"
        let bits = grid.map { $0 ? "1" : "0" }.joined()
        return NonogramPuzzle(id: id, title: String(localized: "Pattern"), grid: bits)
    }
}

/// Splitmix64 — small deterministic RNG keyed on a UInt64 seed. We don't
/// use SystemRandomNumberGenerator inside the generator because we need
/// the seed → grid map to be reconstructable for the solved-puzzle
/// gallery (`NonogramGenerator.reconstruct(fromId:)`).
nonisolated struct SeededRNG: RandomNumberGenerator {
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
