//
//  SudokuPuzzlePack.swift
//  gamekit
//
//  Codable mirror of the root document of Resources/SudokuPuzzles.json.
//  Schema version 1; matches tools/GenerateSudokuPack output exactly.
//

import Foundation

struct SudokuPuzzlePack: Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let generatorSourceSha: String
    let puzzles: [String: [SudokuPuzzleEntry]]
}

// Explicit nonisolated Codable conformance — prevents InferIsolatedConformances
// (enabled project-wide with default-isolation=MainActor) from marking
// Decodable as @MainActor-isolated, which would block use from non-MainActor
// actors such as SudokuPuzzlePool.
extension SudokuPuzzlePack: Codable {
    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion      = try c.decode(Int.self,                           forKey: .schemaVersion)
        generatedAt        = try c.decode(String.self,                        forKey: .generatedAt)
        generatorSourceSha = try c.decode(String.self,                        forKey: .generatorSourceSha)
        puzzles            = try c.decode([String: [SudokuPuzzleEntry]].self, forKey: .puzzles)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion,      forKey: .schemaVersion)
        try c.encode(generatedAt,        forKey: .generatedAt)
        try c.encode(generatorSourceSha, forKey: .generatorSourceSha)
        try c.encode(puzzles,            forKey: .puzzles)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, generatorSourceSha, puzzles
    }
}
