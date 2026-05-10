//
//  NonogramPuzzle.swift
//  gamekit
//
//  A single shipped puzzle — bundle JSON shape. The `grid` is a row-major
//  string of "0"/"1" characters of length size*size; "1" = filled (part of
//  the picture), "0" = empty (background). Authoring discipline:
//    - id is stable across versions; renaming = a different puzzle.
//    - title is the picture name shown in the header.
//    - grid is validated at decode-time (length == size*size, only "0"/"1").
//
//  Foundation-only. Decoded once at app launch from
//  Resources/nonograms/<difficulty>.json (PuzzleLibrary).
//

import Foundation

struct NonogramPuzzle: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// Row-major "0"/"1" string of length difficulty.size * difficulty.size.
    let grid: String

    /// Decoded grid as a flat [Bool] (true = filled). Computed each access —
    /// puzzle objects are read-only and grid lookups happen rarely (once per
    /// gallery render, once per game start).
    var solution: [Bool] {
        grid.map { $0 == "1" }
    }

    /// Validate the grid string against the expected side length. Returns
    /// nil if invalid; consumer can drop or surface diagnostics.
    func isValid(for size: Int) -> Bool {
        guard grid.count == size * size else { return false }
        return grid.allSatisfy { $0 == "0" || $0 == "1" }
    }
}
