import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard
    case extreme
}

public enum PuzzleSource: String, Codable, Sendable {
    case preloaded
    case generated
    case daily
}

public enum PuzzleStatus: String, Codable, Sendable {
    case new
    case inProgress = "in_progress"
    case completed
    case skipped
}

public struct Puzzle: Equatable, Codable, Sendable {
    public let id: UUID
    public let hash: String
    public let puzzleString: String
    public let solutionString: String
    public let difficulty: Difficulty
    public let source: PuzzleSource
    public let seed: Int?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        hash: String,
        puzzleString: String,
        solutionString: String,
        difficulty: Difficulty,
        source: PuzzleSource,
        seed: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hash = hash
        self.puzzleString = puzzleString
        self.solutionString = solutionString
        self.difficulty = difficulty
        self.source = source
        self.seed = seed
        self.createdAt = createdAt
    }
}

public struct PuzzleProgress: Equatable, Codable, Sendable {
    public let puzzleHash: String
    public var status: PuzzleStatus
    public var elapsedSec: Int
    public var mistakes: Int
    public var hintsUsed: Int
    public var score: Int
    public var boardString: String
    public var notesJSON: String?

    public init(
        puzzleHash: String,
        status: PuzzleStatus = .new,
        elapsedSec: Int = 0,
        mistakes: Int = 0,
        hintsUsed: Int = 0,
        score: Int = 0,
        boardString: String = "",
        notesJSON: String? = nil
    ) {
        self.puzzleHash = puzzleHash
        self.status = status
        self.elapsedSec = elapsedSec
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.score = score
        self.boardString = boardString
        self.notesJSON = notesJSON
    }
}
