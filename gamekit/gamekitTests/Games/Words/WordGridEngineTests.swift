import Testing
@testable import gamekit

@Suite("WordGridEngine")
struct WordGridEngineTests {
    @Test("path adjacency allows diagonals and rejects reuse")
    func pathValidation() {
        let first = WordGridPosition(row: 0, column: 0)
        let diagonal = WordGridPosition(row: 1, column: 1)
        let far = WordGridPosition(row: 3, column: 3)
        #expect(WordGridEngine.canAppend(first, to: []))
        #expect(WordGridEngine.canAppend(diagonal, to: [first]))
        #expect(!WordGridEngine.canAppend(first, to: [first, diagonal]))
        #expect(!WordGridEngine.canAppend(far, to: [first]))
    }

    @Test("classic word-grid length scoring")
    func scoring() {
        #expect(WordGridEngine.score("AR") == 0)
        #expect(WordGridEngine.score("ART") == 1)
        #expect(WordGridEngine.score("CLOUD") == 2)
        #expect(WordGridEngine.score("GRACES") == 3)
        #expect(WordGridEngine.score("STARTED") == 5)
        #expect(WordGridEngine.score("STARTING") == 11)
    }

    @Test("generated boards have discoverable words without depending on row answers")
    func generatedBoardsArePlayable() {
        for seed in 1...12 {
            let board = WordGridEngine.makeBoard(seed: UInt64(seed))
            let rowWords = board.map { String($0) }
            let playableWords = WordGridEngine.playableWords(on: board)

            #expect(playableWords.count >= 12)
            #expect(rowWords.filter { WordLexicon.isValidGridWord($0) }.count <= 1)
        }
    }

    @Test("expanded local list accepts common cross words")
    func expandedLocalListAcceptsCommonCrossWords() {
        #expect(WordLexicon.isValidGridWord("MIME"))
        #expect(WordLexicon.isValidGridWord("FEED"))
    }
}
