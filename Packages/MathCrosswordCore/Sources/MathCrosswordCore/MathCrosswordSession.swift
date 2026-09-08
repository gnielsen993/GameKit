import Foundation

public enum MathCrosswordSessionError: Error, Equatable, Sendable {
    case notABlank(GridPos)
    case occupied(GridPos)
    case unavailableTile(Int)
    case noPlacement(GridPos)
    case noUndo
    case noTrustedHint
    case invalidHistory
}

public enum MathCrosswordMoveKind: String, Codable, Sendable, Equatable {
    case place
    case erase
    case replace
}

/// A reversible player action. `value` is always the value selected or removed
/// by the action; `previousValue` is present only for a replacement.
public struct MathCrosswordMove: Codable, Sendable, Equatable {
    public let position: GridPos
    public let value: Int
    public let kind: MathCrosswordMoveKind
    public let previousValue: Int?

    public init(position: GridPos, value: Int) {
        self.init(position: position, value: value, kind: .place)
    }

    public init(position: GridPos, value: Int, kind: MathCrosswordMoveKind, previousValue: Int? = nil) {
        self.position = position
        self.value = value
        self.kind = kind
        self.previousValue = previousValue
    }
}

/// Persistable gameplay state. It deliberately owns no clocks, score, storage,
/// quotas, purchases, or UI state, so the app can choose those policies.
public struct MathCrosswordSession: Codable, Sendable {
    public let puzzle: TallyPuzzle
    public private(set) var placements: [GridPos: Int]
    public private(set) var history: [MathCrosswordMove]

    public init(puzzle: TallyPuzzle) throws {
        try puzzle.validate()
        self.puzzle = puzzle
        placements = [:]
        history = []
    }

    public var remainingBank: [Int] {
        var remaining = multiset(puzzle.bank)
        for value in placements.values { remaining[value, default: 0] -= 1 }
        var tiles: [Int] = []
        for value in puzzle.bank where remaining[value, default: 0] > 0 {
            tiles.append(value)
            remaining[value, default: 0] -= 1
        }
        return tiles
    }

    public var isComplete: Bool {
        placements.count == puzzle.blanks.count && placements.allSatisfy { puzzle.solution[$0.key] == $0.value }
    }

    public mutating func place(_ value: Int, at position: GridPos) throws {
        let puzzle = puzzle
        try mutate { placements, history in
            try Self.requireBlank(position, in: puzzle)
            guard placements[position] == nil else { throw MathCrosswordSessionError.occupied(position) }
            guard Self.hasAvailableTile(value, placements: placements, puzzle: puzzle) else { throw MathCrosswordSessionError.unavailableTile(value) }
            placements[position] = value
            history.append(MathCrosswordMove(position: position, value: value, kind: .place))
        }
    }

    /// Replaces an existing tile in one reversible action. Consumers should use
    /// this rather than erase-then-place so Undo restores the old tile.
    public mutating func replace(_ value: Int, at position: GridPos) throws {
        let puzzle = puzzle
        try mutate { placements, history in
            try Self.requireBlank(position, in: puzzle)
            guard let previous = placements[position] else { throw MathCrosswordSessionError.noPlacement(position) }
            guard value != previous else { return }
            var inventoryAfterReturningPrevious = placements
            inventoryAfterReturningPrevious[position] = nil
            guard Self.hasAvailableTile(value, placements: inventoryAfterReturningPrevious, puzzle: puzzle) else {
                throw MathCrosswordSessionError.unavailableTile(value)
            }
            placements[position] = value
            history.append(MathCrosswordMove(position: position, value: value, kind: .replace, previousValue: previous))
        }
    }

    public mutating func erase(at position: GridPos) throws {
        try mutate { placements, history in
            guard let value = placements.removeValue(forKey: position) else { throw MathCrosswordSessionError.noPlacement(position) }
            history.append(MathCrosswordMove(position: position, value: value, kind: .erase))
        }
    }

    public mutating func undo() throws {
        var updated = self
        guard let move = updated.history.popLast() else { throw MathCrosswordSessionError.noUndo }
        switch move.kind {
        case .place:
            guard updated.placements.removeValue(forKey: move.position) == move.value else { throw MathCrosswordSessionError.invalidHistory }
        case .erase:
            guard updated.placements[move.position] == nil else { throw MathCrosswordSessionError.invalidHistory }
            updated.placements[move.position] = move.value
        case .replace:
            guard let previous = move.previousValue, updated.placements[move.position] == move.value else {
                throw MathCrosswordSessionError.invalidHistory
            }
            updated.placements[move.position] = previous
        }
        try updated.validateState()
        self = updated
    }

    public func nextHint() -> Solver.ChainStep? {
        Solver.nextHint(puzzle: puzzle, placements: placements)
    }

    @discardableResult
    public mutating func applyNextHint() throws -> Solver.ChainStep {
        guard let hint = nextHint() else { throw MathCrosswordSessionError.noTrustedHint }
        var updated = self
        for (position, value) in hint.placements.sorted(by: { $0.key < $1.key }) {
            try updated.place(value, at: position)
        }
        self = updated
        return hint
    }

    private enum CodingKeys: String, CodingKey { case puzzle, placements, history }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try container.decode(TallyPuzzle.self, forKey: .puzzle)
        placements = try container.decode([GridPos: Int].self, forKey: .placements)
        history = try container.decode([MathCrosswordMove].self, forKey: .history)
        try puzzle.validate()
        try validateState()
    }

    private mutating func mutate(_ body: (inout [GridPos: Int], inout [MathCrosswordMove]) throws -> Void) throws {
        var updated = self
        try body(&updated.placements, &updated.history)
        try updated.validateState()
        self = updated
    }

    private static func requireBlank(_ position: GridPos, in puzzle: TallyPuzzle) throws {
        guard puzzle.blanks.contains(position) else { throw MathCrosswordSessionError.notABlank(position) }
    }

    private static func hasAvailableTile(_ value: Int, placements: [GridPos: Int], puzzle: TallyPuzzle) -> Bool {
        multiset(placements.values)[value, default: 0] < multiset(puzzle.bank)[value, default: 0]
    }

    private func validateState() throws {
        let blanks = Set(puzzle.blanks)
        guard placements.keys.allSatisfy(blanks.contains) else { throw MathCrosswordSessionError.invalidHistory }
        let used = multiset(placements.values)
        let inventory = multiset(puzzle.bank)
        guard used.allSatisfy({ inventory[$0.key, default: 0] >= $0.value }) else { throw MathCrosswordSessionError.invalidHistory }

        var replayed: [GridPos: Int] = [:]
        for move in history {
            guard blanks.contains(move.position) else { throw MathCrosswordSessionError.invalidHistory }
            switch move.kind {
            case .place:
                guard move.previousValue == nil, replayed[move.position] == nil,
                      Self.hasAvailableTile(move.value, placements: replayed, puzzle: puzzle) else { throw MathCrosswordSessionError.invalidHistory }
                replayed[move.position] = move.value
            case .erase:
                guard move.previousValue == nil, replayed.removeValue(forKey: move.position) == move.value else {
                    throw MathCrosswordSessionError.invalidHistory
                }
            case .replace:
                guard let previous = move.previousValue, replayed[move.position] == previous else {
                    throw MathCrosswordSessionError.invalidHistory
                }
                var withoutPrevious = replayed
                withoutPrevious[move.position] = nil
                guard Self.hasAvailableTile(move.value, placements: withoutPrevious, puzzle: puzzle) else { throw MathCrosswordSessionError.invalidHistory }
                replayed[move.position] = move.value
            }
        }
        guard replayed == placements else { throw MathCrosswordSessionError.invalidHistory }
    }
}
