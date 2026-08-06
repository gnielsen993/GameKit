import Foundation

/// Chooses an information-rich probe word without ever naming an answer.
nonisolated enum FiveLetterAssist {
    struct Result: Equatable {
        let remainingCount: Int
        let suggestedGuess: String?
        let fallback: String?
    }

    static func suggestion(
        after guesses: [FiveLetterGuess],
        answers: [String],
        acceptedGuesses: Set<String>
    ) -> Result {
        let remaining = FiveLetterCandidates.remaining(after: guesses, answers: answers)
        let answerSet = Set(answers)
        let eligibleProbes = acceptedGuesses
            .filter { !answerSet.contains($0) }
            .filter { FiveLetterStrictValidator.violationMessage(for: $0, previousGuesses: guesses) == nil }

        guard remaining.count > 1, !eligibleProbes.isEmpty else {
            return Result(
                remainingCount: remaining.count,
                suggestedGuess: nil,
                fallback: constraintSummary(from: guesses)
            )
        }

        // The accepted dictionary is intentionally broad (about 16,000
        // words). Rank it cheaply first, then run the exact partition search
        // across a bounded shortlist so opening the coach never stalls play.
        let probes = shortlist(Array(eligibleProbes), against: remaining)

        // Minimise expected candidates left. Sum of squared partition sizes
        // gives the same ordering without floating-point drift.
        var bestWord: String?
        var bestCost = Int.max
        var bestUniqueCount = -1
        for probe in probes {
            var buckets: [[FiveLetterMark]: Int] = [:]
            for candidate in remaining {
                buckets[FiveLetterFeedback.evaluate(guess: probe, answer: candidate), default: 0] += 1
            }
            let cost = buckets.values.reduce(0) { $0 + $1 * $1 }
            let uniqueCount = Set(probe).count
            if cost < bestCost || (cost == bestCost && uniqueCount > bestUniqueCount) {
                bestWord = probe
                bestCost = cost
                bestUniqueCount = uniqueCount
            }
        }
        return Result(remainingCount: remaining.count, suggestedGuess: bestWord, fallback: nil)
    }

    private static func shortlist(_ probes: [String], against remaining: [String]) -> [String] {
        let budget = 64
        guard probes.count > budget else { return probes.sorted() }

        var letterFrequency: [Character: Int] = [:]
        var positionFrequency: [[Character: Int]] = Array(repeating: [:], count: 5)
        for word in remaining {
            let letters = Array(word)
            for letter in Set(letters) {
                letterFrequency[letter, default: 0] += 1
            }
            for (index, letter) in letters.enumerated() {
                positionFrequency[index][letter, default: 0] += 1
            }
        }

        return probes
            .map { probe -> (word: String, score: Int, uniqueCount: Int) in
                let letters = Array(probe)
                let unique = Set(letters)
                let coverage = unique.reduce(0) { $0 + letterFrequency[$1, default: 0] }
                let positions = letters.enumerated().reduce(0) {
                    $0 + positionFrequency[$1.offset][$1.element, default: 0]
                }
                return (probe, coverage * 2 + positions, unique.count)
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.uniqueCount != $1.uniqueCount { return $0.uniqueCount > $1.uniqueCount }
                return $0.word < $1.word
            }
            .prefix(budget)
            .map(\.word)
    }

    private static func constraintSummary(from guesses: [FiveLetterGuess]) -> String? {
        for guess in guesses.reversed() {
            let letters = Array(guess.word)
            for index in guess.marks.indices where guess.marks[index] == .correct {
                return String(localized: "Keep \(String(letters[index])) in spot \(index + 1).")
            }
            for index in guess.marks.indices where guess.marks[index] == .present {
                return String(localized: "Use \(String(letters[index])) again, but in a different spot.")
            }
        }
        return guesses.isEmpty ? String(localized: "Start with a word containing five different letters.") : nil
    }
}
