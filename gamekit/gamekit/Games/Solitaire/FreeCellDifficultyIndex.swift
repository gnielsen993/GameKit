import Foundation

// Heuristic difficulty classifier — runs in microseconds per deal.
// No pre-computed data file needed; scores are computed lazily.

enum FreeCellDifficultyIndex {

    // Score thresholds (tunable). Score ≥ 0; higher = harder.
    private static let mediumAt = 12
    private static let hardAt   = 24
    private static let expertAt = 38

    // MARK: - Public API

    static func difficulty(for dealNumber: Int) -> FreeCellDifficulty {
        let board = FreeCellBoard(dealNumber: dealNumber)
        let s = score(board.columns)
        switch s {
        case ..<mediumAt: return .easy
        case ..<hardAt:   return .medium
        case ..<expertAt: return .hard
        default:          return .expert
        }
    }

    /// Pick a random deal number in the right difficulty bucket.
    /// Tries up to 200 deals; falls back to any valid deal if no match found.
    static func randomDealNumber(
        difficulty: FreeCellDifficulty,
        excluding: Set<Int> = FreeCellDeal.unsolvable
    ) -> Int {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let n = Int.random(in: FreeCellDeal.range, using: &rng)
            guard !excluding.contains(n) else { continue }
            if FreeCellDifficultyIndex.difficulty(for: n) == difficulty { return n }
        }
        // Fallback: return a random valid deal (rare — only if distribution skewed)
        var n: Int
        repeat { n = Int.random(in: FreeCellDeal.range, using: &rng) } while excluding.contains(n)
        return n
    }

    // MARK: - Heuristic

    // Score based on how buried key cards are.
    // col[0] = top (least accessible); col.last = bottom (most accessible).
    // Depth of a card at index i in column of length n = n - 1 - i
    // (cards below it that must be moved first).
    private static func score(_ columns: [[PlayingCard]]) -> Int {
        var s = 0

        // Weighted burial depth for aces (3×), twos (2×), threes (1×)
        let keyRanks: [(CardRank, Int)] = [(.ace, 3), (.two, 2), (.three, 1)]
        for suit in CardSuit.allCases {
            for (rank, weight) in keyRanks {
                for col in columns {
                    if let idx = col.firstIndex(where: { $0.rank == rank && $0.suit == suit }) {
                        s += (col.count - 1 - idx) * weight
                    }
                }
            }
        }

        // Natural sequences from the bottom reduce difficulty
        for col in columns where col.count > 1 {
            var seqLen = 1
            for i in stride(from: col.count - 1, through: 1, by: -1) {
                let lower = col[i]; let upper = col[i - 1]
                if upper.suit.isRed != lower.suit.isRed
                    && lower.rank.rawValue + 1 == upper.rank.rawValue {
                    seqLen += 1
                } else { break }
            }
            s -= (seqLen - 1)
        }

        return max(0, s)
    }
}
