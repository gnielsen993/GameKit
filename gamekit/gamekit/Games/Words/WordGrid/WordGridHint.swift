//
//  WordGridHint.swift
//  gamekit
//
//  Finds one word still on the board and where it runs.
//
//  A visual assist for a visual problem: in WordGrid the words are all in
//  front of the player, they just cannot see them. So the hint outlines a
//  path rather than explaining anything — there is no deduction to teach.
//
//  Foundation-only · deterministic · no SwiftUI / SwiftData (CLAUDE §4).
//

import Foundation

enum WordGridHint {

    struct Hit: Equatable {
        let word: String
        /// The squares to outline, in order.
        let path: [WordGridPosition]
    }

    /// One unfound word and its path, or nil when nothing findable remains.
    ///
    /// Prefers the *shortest* remaining word. A hint should get the player
    /// moving again, not hand them the highest score on the board — and a
    /// short word is the easiest to verify by eye, so it teaches the shape of
    /// a legal path better than a seven-letter snake would.
    ///
    /// Deliberately never reports a count of what remains. Board generation
    /// draws from a curated ~350-word set while submission accepts a
    /// 148,736-word list, so an enumeration of "findable" words is a floor,
    /// not a total — any "12 words left" would be provably wrong.
    static func nextWord(
        board: [[Character]],
        foundWords: [String]
    ) -> Hit? {
        let found = Set(foundWords.map { WordLexicon.normalize($0) })
        var best: Hit?

        for row in 0..<WordGridEngine.size {
            for column in 0..<WordGridEngine.size {
                search(
                    board: board,
                    position: WordGridPosition(row: row, column: column),
                    path: [],
                    current: "",
                    found: found,
                    best: &best
                )
            }
        }
        return best
    }

    /// Mirrors `WordGridEngine.collectWords`, but keeps the path and stops at
    /// the shortest unfound hit rather than accumulating every word.
    private static func search(
        board: [[Character]],
        position: WordGridPosition,
        path: [WordGridPosition],
        current: String,
        found: Set<String>,
        best: inout Hit?
    ) {
        guard WordGridEngine.canAppendForHint(position, to: path) else { return }
        let nextWord = current + WordGridEngine.wordForHint(at: position, board: board)
        guard WordLexicon.wordGridPrefixes.contains(nextWord) else { return }

        let nextPath = path + [position]

        if WordLexicon.isValidGridWord(nextWord), !found.contains(nextWord) {
            if best == nil || nextWord.count < best!.word.count {
                best = Hit(word: nextWord, path: nextPath)
            }
        }
        guard nextWord.count < WordLexicon.maxWordGridWordLength else { return }

        for row in max(0, position.row - 1)...min(WordGridEngine.size - 1, position.row + 1) {
            for column in max(0, position.column - 1)...min(WordGridEngine.size - 1, position.column + 1) {
                search(
                    board: board,
                    position: WordGridPosition(row: row, column: column),
                    path: nextPath,
                    current: nextWord,
                    found: found,
                    best: &best
                )
            }
        }
    }
}
