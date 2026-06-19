import Foundation

struct WordGridPosition: Hashable, Codable, Sendable {
    let row: Int
    let column: Int
}

nonisolated enum WordGridEngine {
    static let size = 4
    static let timedDuration: Double = 180
    private static let letters = Array("EEEEEEEEEEEEAAAAAAAIIIIIIIOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYK")

    static func makeBoard(seed: UInt64 = UInt64(Date().timeIntervalSince1970)) -> [[Character]] {
        var rng = SeededRandom(seed: seed)
        var bestBoard = randomBoard(using: &rng)
        var bestScore = playableWords(on: bestBoard).count - rowWordCount(on: bestBoard)

        for _ in 0..<120 {
            let board = randomBoard(using: &rng)
            let words = playableWords(on: board)
            let score = words.count - rowWordCount(on: board)
            if score > bestScore {
                bestBoard = board
                bestScore = score
            }
            if words.count >= 18, rowWordCount(on: board) <= 1 {
                return board
            }
        }
        return bestBoard
    }

    static func word(for path: [WordGridPosition], board: [[Character]]) -> String {
        String(path.compactMap { pos in
            guard board.indices.contains(pos.row), board[pos.row].indices.contains(pos.column) else { return nil }
            return board[pos.row][pos.column]
        })
    }

    static func canAppend(_ next: WordGridPosition, to path: [WordGridPosition]) -> Bool {
        guard (0..<size).contains(next.row), (0..<size).contains(next.column),
              !path.contains(next) else { return false }
        guard let last = path.last else { return true }
        let dr = abs(next.row - last.row)
        let dc = abs(next.column - last.column)
        return dr <= 1 && dc <= 1 && (dr + dc) > 0
    }

    static func playableWords(on board: [[Character]]) -> Set<String> {
        var words = Set<String>()
        for row in 0..<size {
            for column in 0..<size {
                collectWords(
                    board: board,
                    position: WordGridPosition(row: row, column: column),
                    path: [],
                    current: "",
                    words: &words
                )
            }
        }
        return words
    }

    static func score(_ word: String) -> Int {
        switch WordLexicon.normalize(word).count {
        case 0...2: return 0
        case 3...4: return 1
        case 5: return 2
        case 6: return 3
        case 7: return 5
        default: return 11
        }
    }

    private static func randomBoard(using rng: inout SeededRandom) -> [[Character]] {
        (0..<size).map { _ in
            (0..<size).map { _ in letters.randomElement(using: &rng) ?? "E" }
        }
    }

    private static func rowWordCount(on board: [[Character]]) -> Int {
        board.map { String($0) }.filter { WordLexicon.isValidGridWord($0) }.count
    }

    private static func collectWords(
        board: [[Character]],
        position: WordGridPosition,
        path: [WordGridPosition],
        current: String,
        words: inout Set<String>
    ) {
        guard canAppend(position, to: path) else { return }
        let nextWord = current + word(for: [position], board: board)
        guard WordLexicon.wordGridPrefixes.contains(nextWord) else { return }

        if WordLexicon.isValidGridWord(nextWord) {
            words.insert(nextWord)
        }
        guard nextWord.count < WordLexicon.maxWordGridWordLength else { return }

        let nextPath = path + [position]
        for row in max(0, position.row - 1)...min(size - 1, position.row + 1) {
            for column in max(0, position.column - 1)...min(size - 1, position.column + 1) {
                collectWords(
                    board: board,
                    position: WordGridPosition(row: row, column: column),
                    path: nextPath,
                    current: nextWord,
                    words: &words
                )
            }
        }
    }
}
