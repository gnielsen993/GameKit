//
//  NonogramGeneratorTests.swift
//  gamekitTests
//
//  Unit tests for the procedural Nonogram generator + line solver. Engine
//  tests run pure Swift — no SwiftUI / SwiftData (CLAUDE §4 + §5).
//

import Testing
@testable import gamekit

@MainActor
struct NonogramGeneratorTests {

    @Test("Same seed → same puzzle (reconstruct round-trip)")
    func reconstructIsDeterministic() {
        let original = NonogramGenerator.generate(difficulty: .small, seed: 0xDEADBEEF)
        let recon = NonogramGenerator.reconstruct(fromId: original.id)
        #expect(recon != nil)
        #expect(recon?.grid == original.grid)
        #expect(recon?.id == original.id)
    }

    @Test("Generated grid passes the line-solver gate (when budget allows)")
    func generatedGridIsLineSolvable() {
        // Seed chosen so the budget completes well before maxAttempts.
        let p = NonogramGenerator.generate(difficulty: .tiny, seed: 42)
        let size = NonogramDifficulty.tiny.size

        let bits = p.solution
        let rowHints = (0..<size).map { row -> [Int] in
            runs(in: (0..<size).map { col in bits[row * size + col] })
        }
        let colHints = (0..<size).map { col -> [Int] in
            runs(in: (0..<size).map { row in bits[row * size + col] })
        }
        #expect(NonogramLineSolver.isLineSolvable(
            size: size, rowHints: rowHints, columnHints: colHints
        ))
    }

    @Test("Reconstruct returns nil for non-procedural ids")
    func reconstructRejectsCuratedIds() {
        #expect(NonogramGenerator.reconstruct(fromId: "tiny-001") == nil)
        #expect(NonogramGenerator.reconstruct(fromId: "proc-bogus-bogus") == nil)
        #expect(NonogramGenerator.reconstruct(fromId: "proc-tiny") == nil)
    }

    @Test("Procedural id format: proc-<size>-<seed>")
    func generatedIdFormat() {
        let p = NonogramGenerator.generate(difficulty: .medium, seed: 12345)
        #expect(p.id == "proc-medium-12345")
    }

    @Test("Line solver: simple line resolves fully")
    func lineSolverSimple() {
        // 5-cell line with hints [3] — only one valid placement
        // would have at least one fixed-filled cell at index 2.
        let cells = [NonogramLineSolver.CellState](repeating: .unknown, count: 5)
        let result = NonogramLineSolver.solveLine(line: cells, hints: [3])
        #expect(result != nil)
        // The middle cell (index 2) is fixed-filled in every valid 3-run
        // placement (positions 0,1,2 / 1,2,3 / 2,3,4 — index 2 in all).
        #expect(result?[2] == .filled)
    }

    @Test("Line solver: contradiction returns nil")
    func lineSolverContradiction() {
        // Hints [3] but cell 0 already empty AND cell 4 already empty
        // AND cell 2 already empty — no 3-run fits.
        var cells = [NonogramLineSolver.CellState](repeating: .unknown, count: 5)
        cells[0] = .empty
        cells[2] = .empty
        cells[4] = .empty
        #expect(NonogramLineSolver.solveLine(line: cells, hints: [3]) == nil)
    }
}

// Local helper — mirrors NonogramHints.runs but with bool input.
private func runs(in line: [Bool]) -> [Int] {
    var out: [Int] = []
    var cur = 0
    for b in line {
        if b { cur += 1 } else if cur > 0 { out.append(cur); cur = 0 }
    }
    if cur > 0 { out.append(cur) }
    return out.isEmpty ? [0] : out
}
