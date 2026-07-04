//
//  SnakeEngine.swift
//  gamekit
//
//  Pure value-type engine for the Snake game. Foundation-only — no view-layer
//  or persistence imports. All coordinates use Int (col/row); all time uses Double
//  (seconds). The view converts SnakeCell to screen coordinates using cellSize.
//
//  Two time layers:
//    (outer) VM fixed-step accumulator at 1/60s drives step(dt:nextDirection:)
//    (inner) cellAccumulator fires a cell move once per tickInterval (100–200ms)
//  The Gaffer alpha (cellAccumulator / tickInterval) drives smooth interpolation
//  in the view between cell moves — always in [0, 1].
//
//  CLAUDE.md §4: pure / testable, no external framework dependencies.
//

import Foundation

// MARK: - Value Types

nonisolated struct SnakeCell: Hashable, Sendable {
    var col: Int
    var row: Int
}

nonisolated enum SnakeDirection: Equatable, Sendable {
    case up, down, left, right

    var opposite: SnakeDirection {
        switch self {
        case .up:    return .down
        case .down:  return .up
        case .left:  return .right
        case .right: return .left
        }
    }
}

nonisolated enum SnakeEvent: Equatable, Sendable {
    case none
    case ate(food: SnakeCell)   // food = new food position (spawned after eating)
    case died
}

nonisolated struct SnakeFrame: Equatable, Sendable {
    var body: [SnakeCell]           // index 0 = head; last index = tail
    var prevBody: [SnakeCell]       // body BEFORE this step's cell move (for Gaffer lerp)
    var food: SnakeCell
    var currentDirection: SnakeDirection
    var score: Int                  // food eaten count
    var cellMoveAlpha: Double       // cellAccumulator / tickInterval — Gaffer alpha for view
    var gameOver: Bool
    var event: SnakeEvent
    // True only on steps that crossed a cell-move boundary (including death
    // steps). The VM pops its direction queue only when this is true — on all
    // other steps nextDirection is untouched, so queued input is never lost.
    var didMoveCell: Bool = false
}

// MARK: - Engine

nonisolated struct SnakeEngine {

    // --- config ---
    let cfg: SnakeConfig

    // --- state (pure value semantics) ---
    private(set) var body: [SnakeCell]
    private(set) var prevBody: [SnakeCell]
    private(set) var food: SnakeCell
    private(set) var currentDirection: SnakeDirection = .right
    private(set) var score: Int = 0
    private(set) var gameOver: Bool = false

    private var cellAccumulator: Double = 0
    private var tickInterval: Double        // decreases with score, floors at cfg.minTickInterval
    private var rng: any RandomNumberGenerator

    init(cfg: SnakeConfig = .default, rng: some RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.cfg = cfg
        self.rng = rng
        self.tickInterval = cfg.startTickInterval

        // Starting body: startLength cells moving right at vertical center
        let mid = cfg.rows / 2
        var initial: [SnakeCell] = []
        for i in 0..<cfg.startLength {
            initial.append(SnakeCell(col: cfg.startLength - 1 - i + 2, row: mid))
        }
        self.body = initial
        self.prevBody = initial

        // Placeholder food — will be replaced by spawnFood()
        self.food = SnakeCell(col: 0, row: 0)
        spawnFood()
    }

    // MARK: - Main Step

    /// Called once per fixed-step tick (dt = 1/60s from VM accumulator).
    /// `nextDirection`: the VM pops this from its direction queue; nil = keep current direction.
    mutating func step(dt: Double, nextDirection: SnakeDirection?) -> SnakeFrame {
        guard !gameOver else { return frame(event: .none) }

        cellAccumulator += dt

        // Most steps: no cell move — just advance interpolation alpha.
        guard cellAccumulator >= tickInterval else { return frame(event: .none) }
        cellAccumulator -= tickInterval

        // Update speed: ramp as score grows, then plateau.
        tickInterval = max(cfg.minTickInterval,
                           cfg.startTickInterval - Double(score) * cfg.intervalDecrement)

        // Apply direction (reject 180° reversals — also enforced at VM queue level, double-guard here)
        if let dir = nextDirection, dir != currentDirection.opposite {
            currentDirection = dir
        }

        // Snapshot for Gaffer interpolation (prevBody = body before this cell move)
        prevBody = body

        // Compute new head position
        var newHead = body[0]
        switch currentDirection {
        case .up:    newHead.row -= 1
        case .down:  newHead.row += 1
        case .left:  newHead.col -= 1
        case .right: newHead.col += 1
        }

        // Wrap or wall check
        if cfg.wallMode {
            if newHead.col < 0 || newHead.col >= cfg.cols ||
               newHead.row < 0 || newHead.row >= cfg.rows {
                gameOver = true
                return frame(event: .died, didMoveCell: true)
            }
        } else {
            // Toroidal wrap (default — SNAKE-02)
            newHead.col = (newHead.col + cfg.cols) % cfg.cols
            newHead.row = (newHead.row + cfg.rows) % cfg.rows
        }

        // Self-collision: check against body EXCLUDING the tail (tail vacates on a non-eating move)
        let bodyWithoutTail = body.dropLast()
        if bodyWithoutTail.contains(newHead) {
            gameOver = true
            return frame(event: .died, didMoveCell: true)
        }

        // Grow or slide
        if newHead == food {
            // Grow: insert new head, tail stays (body length +1)
            body.insert(newHead, at: 0)
            score += 1
            spawnFood()
            return frame(event: .ate(food: food), didMoveCell: true)
        } else {
            // Slide: insert new head, remove tail
            body.insert(newHead, at: 0)
            body.removeLast()
            return frame(event: .none, didMoveCell: true)
        }
    }

    // MARK: - Helpers

    private mutating func spawnFood() {
        let occupied = Set(body)
        let candidates = (0..<cfg.cols).flatMap { c in
            (0..<cfg.rows).map { r in SnakeCell(col: c, row: r) }
        }.filter { !occupied.contains($0) }
        guard !candidates.isEmpty else { return }   // board full — rare win state
        let idx = Int.random(in: 0..<candidates.count, using: &rng)
        food = candidates[idx]
    }

    private func frame(event: SnakeEvent, didMoveCell: Bool = false) -> SnakeFrame {
        SnakeFrame(
            body: body,
            prevBody: prevBody,
            food: food,
            currentDirection: currentDirection,
            score: score,
            cellMoveAlpha: min(cellAccumulator / tickInterval, 1.0),
            gameOver: gameOver,
            event: event,
            didMoveCell: didMoveCell
        )
    }
}
