//
//  SudokuPuzzleEntry.swift
//  gamekit
//
//  Codable mirror of one entry in Resources/SudokuPuzzles.json. Matches
//  the schema written by tools/GenerateSudokuPack (Phase 14, Task 7).
//

import Foundation

struct SudokuPuzzleEntry: Equatable, Hashable, Sendable, Identifiable {
    let id: String           // UUID string
    let givens: String       // 81 chars
    let solution: String     // 81 chars
    let givenCount: Int
}

// Explicit nonisolated Codable conformance — same rationale as SudokuPuzzlePack.
extension SudokuPuzzleEntry: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        givens     = try c.decode(String.self, forKey: .givens)
        solution   = try c.decode(String.self, forKey: .solution)
        givenCount = try c.decode(Int.self,    forKey: .givenCount)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try c.encode(givens,     forKey: .givens)
        try c.encode(solution,   forKey: .solution)
        try c.encode(givenCount, forKey: .givenCount)
    }

    private enum CodingKeys: String, CodingKey {
        case id, givens, solution, givenCount
    }
}
