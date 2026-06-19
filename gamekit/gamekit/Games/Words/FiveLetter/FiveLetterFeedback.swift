import Foundation

enum FiveLetterMark: String, Codable, Sendable, Equatable {
    case correct
    case present
    case absent
}

nonisolated enum FiveLetterFeedback {
    static func evaluate(guess rawGuess: String, answer rawAnswer: String) -> [FiveLetterMark] {
        let guess = Array(WordLexicon.normalize(rawGuess))
        let answer = Array(WordLexicon.normalize(rawAnswer))
        guard guess.count == 5, answer.count == 5 else { return [] }

        var marks = Array(repeating: FiveLetterMark.absent, count: 5)
        var remaining: [Character: Int] = [:]

        for index in 0..<5 {
            if guess[index] == answer[index] {
                marks[index] = .correct
            } else {
                remaining[answer[index], default: 0] += 1
            }
        }

        for index in 0..<5 where marks[index] != .correct {
            let letter = guess[index]
            if let count = remaining[letter], count > 0 {
                marks[index] = .present
                remaining[letter] = count - 1
            }
        }

        return marks
    }
}

nonisolated enum FiveLetterStrictValidator {
    static func violationMessage(for rawGuess: String, previousGuesses: [FiveLetterGuess]) -> String? {
        let guess = Array(WordLexicon.normalize(rawGuess))
        guard guess.count == 5 else { return nil }

        for previousGuess in previousGuesses {
            let previousWord = Array(WordLexicon.normalize(previousGuess.word))
            guard previousWord.count == 5, previousGuess.marks.count == 5 else { continue }

            for index in 0..<5 where previousGuess.marks[index] == .correct {
                let letter = previousWord[index]
                if guess[index] != letter {
                    return String(localized: "Keep \(String(letter)) in spot \(index + 1)")
                }
            }

            for index in 0..<5 where previousGuess.marks[index] == .present {
                let letter = previousWord[index]
                if guess[index] == letter {
                    return String(localized: "Move \(String(letter))")
                }
                if !guess.contains(letter) {
                    return String(localized: "Use \(String(letter))")
                }
            }

            let positiveLetters = Set(
                previousGuess.marks.enumerated().compactMap { index, mark in
                    mark == .correct || mark == .present ? previousWord[index] : nil
                }
            )

            for index in 0..<5 where previousGuess.marks[index] == .absent {
                let letter = previousWord[index]
                if !positiveLetters.contains(letter), guess.contains(letter) {
                    return String(localized: "Do not use \(String(letter))")
                }
            }
        }

        return nil
    }
}
