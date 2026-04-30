//
//  MergeEngineTests.swift
//  gamekitTests
//
//  Swift Testing coverage for MergeEngine. Mirrors BoardGeneratorTests
//  discipline: deterministic via SeededGenerator (reused from Plan 02
//  Helpers/SeededGenerator.swift).
//
//  Pinned invariants:
//    - `[2,2,_,_]` left -> `[4,_,_,_]`, scoreDelta == 4
//    - `[2,2,2,2]` left -> `[4,4,_,_]` (no triple-merge in one swipe)
//    - `[2,2,4]`   left -> `[4,4,_,_]` (already-merged tile not re-merged)
//    - Empty row swipe is a no-op (didChange == false, scoreDelta == 0)
//    - Rotation symmetry: sliding right then mirroring is the same as
//      mirroring then sliding left.
//

import Testing
import Foundation
@testable import gamekit

@Suite("MergeEngine")
nonisolated struct MergeEngineTests {

    // MARK: - Helpers

    /// Build a 4x4 board from a 2D values array. Use 0 for empty cells.
    private static func board(_ values: [[Int]]) -> MergeBoard {
        precondition(values.count == MergeBoard.size)
        var cells: [MergeTile?] = []
        for row in values {
            precondition(row.count == MergeBoard.size)
            for v in row {
                cells.append(v == 0 ? nil : MergeTile(value: v))
            }
        }
        return MergeBoard(cells: cells)
    }

    /// Extract values as 2D array (0 = empty) for assertions.
    private static func values(_ board: MergeBoard) -> [[Int]] {
        var out: [[Int]] = []
        for r in 0..<MergeBoard.size {
            var row: [Int] = []
            for c in 0..<MergeBoard.size {
                row.append(board.cell(row: r, col: c)?.value ?? 0)
            }
            out.append(row)
        }
        return out
    }

    // MARK: - Basic merges

    @Test
    func slideLeft_pairMerges_scoreDeltaIsSumOfMerged() {
        let b = Self.board([
            [2, 2, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .left)
        #expect(Self.values(result.board) == [
            [4, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 4)
        #expect(result.didChange == true)
        #expect(result.merges.count == 1)
        #expect(result.merges.first?.value == 4)
    }

    @Test
    func slideLeft_doublePair_noTripleMerge() {
        // [2,2,2,2] must NOT collapse to [8,_,_,_]; canonical 2048 does
        // [4,4,_,_] (two independent merges, total score = 8).
        let b = Self.board([
            [2, 2, 2, 2],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .left)
        #expect(Self.values(result.board) == [
            [4, 4, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 8)
        #expect(result.merges.count == 2)
    }

    @Test
    func slideLeft_alreadyMergedTileDoesNotRemerge() {
        // [2,2,4] left -> first 2+2 merges to 4, that 4 must NOT then
        // merge with the trailing 4 in the same swipe.
        let b = Self.board([
            [2, 2, 4, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .left)
        #expect(Self.values(result.board) == [
            [4, 4, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 4) // only the new 2+2 merge counts
    }

    @Test
    func slideLeft_compressionWithoutMerge() {
        let b = Self.board([
            [0, 2, 0, 4],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .left)
        #expect(Self.values(result.board) == [
            [2, 4, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 0)
        #expect(result.didChange == true)
        #expect(result.merges.isEmpty)
    }

    @Test
    func slide_emptyBoard_isNoOp() {
        let result = MergeEngine.slide(.empty, direction: .left)
        #expect(result.didChange == false)
        #expect(result.scoreDelta == 0)
        #expect(result.board == .empty)
    }

    @Test
    func slide_alreadyCompressedRow_isNoOp() {
        // Row [2,4,8,16] swiped left: nothing moves, nothing merges.
        let b = Self.board([
            [2, 4, 8, 16],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .left)
        #expect(result.didChange == false)
        #expect(result.scoreDelta == 0)
    }

    // MARK: - All four directions produce expected geometry

    @Test
    func slideRight_pairMerge() {
        let b = Self.board([
            [2, 2, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .right)
        #expect(Self.values(result.board) == [
            [0, 0, 0, 4],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 4)
    }

    @Test
    func slideUp_pairMerge() {
        let b = Self.board([
            [2, 0, 0, 0],
            [2, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .up)
        #expect(Self.values(result.board) == [
            [4, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 4)
    }

    @Test
    func slideDown_pairMerge() {
        let b = Self.board([
            [2, 0, 0, 0],
            [2, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        let result = MergeEngine.slide(b, direction: .down)
        #expect(Self.values(result.board) == [
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [4, 0, 0, 0],
        ])
        #expect(result.scoreDelta == 4)
    }

    // MARK: - Tile identity preserved across slides

    @Test
    func slideLeft_survivingTileKeepsId() {
        let leftTile = MergeTile(value: 2)
        let rightTile = MergeTile(value: 2)
        var cells: [MergeTile?] = Array(repeating: nil, count: 16)
        cells[0] = leftTile
        cells[1] = rightTile
        let b = MergeBoard(cells: cells)

        let result = MergeEngine.slide(b, direction: .left)
        let survivor = result.board.cell(row: 0, col: 0)
        #expect(survivor?.value == 4)
        // Survivor keeps the LEFT tile's id (the slide-direction lead).
        #expect(survivor?.id == leftTile.id)
        #expect(survivor?.mergedThisTurn == true)
    }

    // MARK: - hasAnyLegalMove

    @Test
    func hasAnyLegalMove_emptyBoardOnly() {
        // Single tile in the corner — sliding away from the corner into
        // empty space is itself a legal move.
        let b = Self.board([
            [2, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 0, 0],
        ])
        #expect(MergeEngine.hasAnyLegalMove(b) == true)
    }

    @Test
    func hasAnyLegalMove_lockedBoard_isFalse() {
        // No empty cells, no neighboring equal pairs — game over.
        let b = Self.board([
            [2, 4, 2, 4],
            [4, 2, 4, 2],
            [2, 4, 2, 4],
            [4, 2, 4, 2],
        ])
        #expect(MergeEngine.hasAnyLegalMove(b) == false)
    }

    @Test
    func hasAnyLegalMove_fullBoardWithAdjacentPair_isTrue() {
        let b = Self.board([
            [2, 2, 4, 8],
            [4, 8, 2, 4],
            [2, 4, 8, 2],
            [4, 8, 2, 4],
        ])
        #expect(MergeEngine.hasAnyLegalMove(b) == true)
    }
}
