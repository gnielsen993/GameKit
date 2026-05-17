//
//  GenerateSudokuPack — offline JSON puzzle pack generator
//
//  Generates a JSON file with N puzzles per difficulty, dedup-by-hash,
//  resumable across runs (--append). Output schema matches what
//  Games/Sudoku/SudokuPuzzlePool expects.
//
//  Usage:
//    swift run GenerateSudokuPack [flags]
//
//  Flags:
//    --per-difficulty <N>   Target count per difficulty (default 1500)
//    --difficulties <csv>   Subset (e.g. "hard,extreme"); default = all 4
//    --output <path>        Output JSON path (default
//                           ../../gamekit/gamekit/Resources/SudokuPuzzles.json)
//    --append               Read existing JSON and fill missing slots only
//    --time-budget <min>    Soft cap in minutes; clean exit when exceeded
//

import Foundation
import SudokuCore

// MARK: - Schema (matches Games/Sudoku/SudokuPuzzlePool decoder)

struct PuzzleEntry: Codable, Sendable {
    let id: String
    let givens: String
    let solution: String
    let givenCount: Int
}

struct PuzzlePack: Codable, Sendable {
    var schemaVersion: Int
    var generatedAt: String
    var generatorSourceSha: String
    var puzzles: [String: [PuzzleEntry]]  // keys = Difficulty.rawValue
}

// MARK: - Arg parsing (minimal — no Argument Parser dep)

struct Args: Sendable {
    var perDifficulty: Int = 1500
    var difficulties: [Difficulty] = Difficulty.allCases
    var output: String = "../../gamekit/gamekit/Resources/SudokuPuzzles.json"
    var append: Bool = false
    var timeBudgetMinutes: Double? = nil
}

func parseArgs() -> Args {
    var a = Args()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "--per-difficulty":
            i += 1
            guard i < argv.count, let v = Int(argv[i]) else { fatalError("--per-difficulty <N>") }
            a.perDifficulty = v
        case "--difficulties":
            i += 1
            guard i < argv.count else { fatalError("--difficulties <csv>") }
            a.difficulties = argv[i].split(separator: ",").compactMap { Difficulty(rawValue: String($0)) }
            if a.difficulties.isEmpty { fatalError("--difficulties: no valid values parsed from \(argv[i])") }
        case "--output":
            i += 1
            guard i < argv.count else { fatalError("--output <path>") }
            a.output = argv[i]
        case "--append":
            a.append = true
        case "--time-budget":
            i += 1
            guard i < argv.count, let v = Double(argv[i]) else { fatalError("--time-budget <minutes>") }
            a.timeBudgetMinutes = v
        case "--help", "-h":
            print("""
            GenerateSudokuPack — generate a JSON Sudoku puzzle pack.

            Flags:
              --per-difficulty <N>   Target count per difficulty (default 1500)
              --difficulties <csv>   Subset, e.g. hard,extreme (default = all)
              --output <path>        Output JSON path
              --append               Read existing JSON and top up
              --time-budget <min>    Soft cap in minutes; clean exit when exceeded
            """)
            exit(0)
        default:
            fatalError("Unknown arg: \(arg). Use --help.")
        }
        i += 1
    }
    return a
}

// MARK: - IO

func loadExistingPack(at path: String) -> PuzzlePack? {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(PuzzlePack.self, from: data)
}

func writePackAtomically(_ pack: PuzzlePack, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    let tmp = url.appendingPathExtension("tmp")
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try enc.encode(pack)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: tmp, options: .atomic)
    if FileManager.default.fileExists(atPath: url.path) {
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    } else {
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}

// MARK: - Helpers

func countGivens(_ s: String) -> Int {
    s.filter { $0 != "0" && $0 != "." }.count
}

func nowISO8601() -> String {
    ISO8601DateFormatter().string(from: Date())
}

// MARK: - Entry point

@main
struct GenerateSudokuPackMain {
    static func main() async throws {
        let args = parseArgs()

        let generator = SudokuPuzzleGenerator()
        let solver    = SudokuSolver(stepLimit: 2_000_000)
        let rater     = TechniqueRater()
        let hasher    = SHA256Hasher()
        let repo      = InMemoryPuzzleRepository()

        // Bootstrap pack — either from disk (--append) or fresh.
        var pack: PuzzlePack
        if args.append, let existing = loadExistingPack(at: args.output) {
            pack = existing
            // Pre-load existing hashes into dedup repo so we don't reprocess them.
            for (_, entries) in existing.puzzles {
                for entry in entries {
                    let puzzle = Puzzle(
                        id: UUID(uuidString: entry.id) ?? UUID(),
                        hash: hasher.canonicalHash(for: entry.givens),
                        puzzleString: entry.givens,
                        solutionString: entry.solution,
                        difficulty: .easy,  // not used for dedup; hash is the key
                        source: .preloaded
                    )
                    try? await repo.save(puzzle)
                }
            }
        } else {
            pack = PuzzlePack(
                schemaVersion: 1,
                generatedAt: nowISO8601(),
                generatorSourceSha: "b02c848f62ad4ad70fc6f1079916e193cb9470ae",
                puzzles: Difficulty.allCases.reduce(into: [:]) { $0[$1.rawValue] = [] }
            )
        }

        let useCase = GeneratePuzzleUseCase(
            generator: generator,
            solver: solver,
            rater: rater,
            hasher: hasher,
            repository: repo
        )

        let startTime = Date()
        let budgetSeconds: TimeInterval? = args.timeBudgetMinutes.map { $0 * 60 }

        func budgetExceeded() -> Bool {
            guard let b = budgetSeconds else { return false }
            return Date().timeIntervalSince(startTime) >= b
        }

        var lastLogTime = Date()

        func logProgress() {
            let elapsed = Date().timeIntervalSince(startTime)
            let mm = Int(elapsed) / 60
            let ss = Int(elapsed) % 60
            print("---")
            for d in Difficulty.allCases {
                let have = pack.puzzles[d.rawValue]?.count ?? 0
                let pct = args.perDifficulty == 0 ? 0 : (have * 100 / args.perDifficulty)
                let label = d.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                print(String(format: "  %@ %4d/%-4d (%2d%%)", label, have, args.perDifficulty, pct))
            }
            if let b = args.timeBudgetMinutes {
                print(String(format: "  elapsed: %dm%02ds  budget: %.0fm", mm, ss, b))
            } else {
                print(String(format: "  elapsed: %dm%02ds", mm, ss))
            }
        }

        // One seed counter, advancing across all difficulties — guarantees seed
        // uniqueness within a single run. Start high so we never collide with
        // the upstream SeedGenerator's seedStart=10_000 (their bundled pack).
        var seed = 100_000

        logProgress()

        generation: for difficulty in args.difficulties {
            while (pack.puzzles[difficulty.rawValue]?.count ?? 0) < args.perDifficulty {
                if budgetExceeded() {
                    print("\nTime budget exceeded — writing and exiting cleanly.")
                    break generation
                }

                seed += 1
                let result: GeneratePuzzleUseCase.Result
                do {
                    result = try await useCase.runSavingRatedCandidate(
                        targetDifficulty: difficulty,
                        seed: seed
                    )
                } catch SudokuCoreError.hashAlreadyExists {
                    continue   // duplicate of an already-saved puzzle; skip
                } catch {
                    continue   // generator/solver/rater rejection; try next seed
                }

                // Accept only puzzles whose rated difficulty matches the target.
                guard result.matchesTarget else { continue }

                let entry = PuzzleEntry(
                    id: result.puzzle.id.uuidString,
                    givens: result.puzzle.puzzleString,
                    solution: result.puzzle.solutionString,
                    givenCount: countGivens(result.puzzle.puzzleString)
                )
                pack.puzzles[difficulty.rawValue, default: []].append(entry)

                // Log every 60 seconds.
                if Date().timeIntervalSince(lastLogTime) >= 60 {
                    logProgress()
                    lastLogTime = Date()
                }
            }
        }

        // Final write.
        pack.generatedAt = nowISO8601()
        try writePackAtomically(pack, to: args.output)
        print("\nWrote \(args.output)")
        logProgress()
    }
}
