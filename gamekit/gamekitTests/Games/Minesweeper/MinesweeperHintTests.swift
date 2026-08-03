import Testing
import Foundation
@testable import gamekit

/// The engine claims a square is safe. If it is ever wrong the player loses
/// the game on the app's advice, which is the worst failure in the whole
/// milestone — so these tests check the claim against the real mine layout
/// across many boards, not just that a hint came back.
@Suite("Minesweeper hint")
@MainActor
struct MinesweeperHintTests {

    /// Plays a board far enough to give the solver something to work with.
    private func openedBoard(seed: UInt64, difficulty: MinesweeperDifficulty = .easy) -> MinesweeperViewModel {
        let vm = MinesweeperViewModel(difficulty: difficulty, rng: SeededGenerator(seed: seed))
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
        return vm
    }

    /// **The load-bearing test.** Every square the engine calls safe must
    /// genuinely not be a mine, on every board it can find a step for.
    @Test("a square called safe is never a mine")
    func safeClaimsAreAlwaysTrue() {
        var boardsChecked = 0
        var stepsChecked = 0

        for seed in UInt64(1)...80 {
            let vm = openedBoard(seed: seed)
            guard case .playing = vm.gameState else { continue }
            boardsChecked += 1

            // Follow the engine for a while, opening what it recommends.
            for _ in 0..<25 {
                guard case .playing = vm.gameState,
                      let step = MinesweeperHint.nextStep(board: vm.board) else { break }
                #expect(
                    vm.board.cell(at: step.safe).isMine == false,
                    "engine called r\(step.safe.row)c\(step.safe.col) safe but it is a mine (seed \(seed))"
                )
                stepsChecked += 1
                vm.reveal(at: step.safe)
            }
        }
        #expect(boardsChecked > 20)
        #expect(stepsChecked > 20)
    }

    @Test("the evidence is revealed numbered squares")
    func evidenceIsUsableNumbers() {
        for seed in UInt64(1)...30 {
            let vm = openedBoard(seed: seed)
            guard let step = MinesweeperHint.nextStep(board: vm.board) else { continue }
            #expect(step.evidence.isEmpty == false)
            for index in step.evidence {
                let cell = vm.board.cell(at: index)
                // Pointing at a hidden square would be useless — the player
                // cannot check an argument they cannot see.
                #expect(cell.state == .revealed)
                #expect(cell.adjacentMineCount > 0)
            }
        }
    }

    @Test("the suggested square is still unopened")
    func suggestedSquareIsUnopened() {
        for seed in UInt64(1)...30 {
            let vm = openedBoard(seed: seed)
            guard let step = MinesweeperHint.nextStep(board: vm.board) else { continue }
            #expect(vm.board.cell(at: step.safe).state != .revealed)
        }
    }

    /// Flags are the player's belief. A wrong one must not be able to make
    /// the engine assert something false.
    @Test("a wrong flag cannot poison the advice")
    func wrongFlagsDoNotCorruptTheSolver() {
        for seed in UInt64(1)...40 {
            let vm = openedBoard(seed: seed)
            guard case .playing = vm.gameState else { continue }

            // Flag a square that is definitely not a mine.
            if let wrong = vm.board.allIndices().first(where: {
                vm.board.cell(at: $0).state == .hidden && vm.board.cell(at: $0).isMine == false
            }) {
                vm.toggleFlag(at: wrong)
            }

            guard let step = MinesweeperHint.nextStep(board: vm.board) else { continue }
            #expect(
                vm.board.cell(at: step.safe).isMine == false,
                "a mis-flagged board produced a wrong safe claim (seed \(seed))"
            )
        }
    }

    @Test("an untouched board offers nothing")
    func idleBoardHasNoStep() {
        let vm = MinesweeperViewModel(difficulty: .easy, rng: SeededGenerator(seed: 3))
        // Pre-first-tap the board is a placeholder with no revealed numbers.
        #expect(MinesweeperHint.nextStep(board: vm.board) == nil)
    }

    @Test("the same board always yields the same hint")
    func hintIsStable() {
        let vm = openedBoard(seed: 11)
        let first = MinesweeperHint.nextStep(board: vm.board)
        let second = MinesweeperHint.nextStep(board: vm.board)
        #expect(first == second)
    }

    @Test("both techniques have copy that names the numbers")
    func copyCoversBothTechniques() {
        let steps: [MinesweeperHint.Step] = [
            .init(safe: MinesweeperIndex(row: 1, col: 1), evidence: [MinesweeperIndex(row: 0, col: 0)],
                  technique: .countingOneNumber(number: 1)),
            .init(safe: MinesweeperIndex(row: 1, col: 1),
                  evidence: [MinesweeperIndex(row: 0, col: 0), MinesweeperIndex(row: 0, col: 1)],
                  technique: .comparingTwoNumbers(smaller: 1, larger: 2))
        ]
        for step in steps {
            let text = MinesweeperHintCopy.explanation(for: step)
            #expect(text.isEmpty == false)
            #expect(text.contains("1"))
        }
    }
}

/// View-model wiring for the Minesweeper hint.
@Suite("Minesweeper hint wiring")
@MainActor
struct MinesweeperHintWiringTests {

    private func playing(seed: UInt64) -> MinesweeperViewModel {
        let vm = MinesweeperViewModel(difficulty: .easy, rng: SeededGenerator(seed: seed))
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
        return vm
    }

    @Test("asking counts an assist only when a step is found")
    func onlyChargesWhenItHelps() {
        var charged = 0
        var refused = 0
        for seed in UInt64(1)...30 {
            let vm = playing(seed: seed)
            guard case .playing = vm.gameState else { continue }
            vm.requestHint()
            if vm.activeHint != nil {
                #expect(vm.assistsUsed == 1)
                charged += 1
            } else {
                #expect(vm.hintFoundNothing)
                // Refused help is free.
                #expect(vm.assistsUsed == 0)
                refused += 1
            }
        }
        #expect(charged + refused > 20)
    }

    @Test("a request never opens anything")
    func requestDoesNotReveal() {
        let vm = playing(seed: 5)
        let revealedBefore = vm.board.allIndices().filter { vm.board.cell(at: $0).state == .revealed }.count
        vm.requestHint()
        let revealedAfter = vm.board.allIndices().filter { vm.board.cell(at: $0).state == .revealed }.count
        #expect(revealedAfter == revealedBefore)
    }

    /// Spending the guess must be genuinely safe — it reads the real board
    /// rather than trusting the incomplete solver.
    @Test("opening a safe square never hits a mine")
    func spendingTheGuessIsSafe() {
        for seed in UInt64(1)...40 {
            let vm = playing(seed: seed)
            guard case .playing = vm.gameState else { continue }
            vm.openASafeSquare()
            // Still playing, or won — never lost.
            if case .lost = vm.gameState {
                Issue.record("openASafeSquare hit a mine on seed \(seed)")
            }
            #expect(vm.assistsUsed == 1)
        }
    }

    @Test("the explanation clears when the board changes")
    func hintClearsOnReveal() {
        for seed in UInt64(1)...20 {
            let vm = playing(seed: seed)
            vm.requestHint()
            guard let step = vm.activeHint else { continue }
            vm.reveal(at: step.safe)
            #expect(vm.activeHint == nil)
            break
        }
    }

    @Test("a new game clears the assist count")
    func restartClearsAssists() {
        let vm = playing(seed: 9)
        vm.requestHint()
        vm.restart()
        #expect(vm.assistsUsed == 0)
        #expect(vm.activeHint == nil)
    }
}
