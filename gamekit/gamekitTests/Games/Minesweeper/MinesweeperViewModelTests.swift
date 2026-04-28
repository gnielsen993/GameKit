//
//  MinesweeperViewModelTests.swift
//  gamekitTests
//
//  Swift Testing coverage for MinesweeperViewModel — proves MINES-02 / MINES-05
//  / MINES-06 / MINES-07 / MINES-11 + D-06 scenePhase pause/resume + D-10
//  mid-game alert flow + D-11 UserDefaults persistence.
//
//  Determinism strategy:
//    - clock: { fixedDate } — pinned Date.now so timer math is deterministic
//    - rng: SeededGenerator(seed: 1) — pinned mine layout (P2-validated)
//    - userDefaults: UserDefaults(suiteName: "test-…")! — isolated per test
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("MinesweeperViewModel")
struct MinesweeperViewModelTests {

    // MARK: - Helpers (file-scope so nested suites can reach them)

    static func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    static func makeVM(
        difficulty: MinesweeperDifficulty? = nil,
        seed: UInt64 = 1,
        clockReturns date: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> (vm: MinesweeperViewModel, defaults: UserDefaults) {
        let defaults = makeIsolatedDefaults()
        let vm = MinesweeperViewModel(
            difficulty: difficulty,
            userDefaults: defaults,
            clock: { date },
            rng: SeededGenerator(seed: seed)
        )
        return (vm, defaults)
    }

    /// Find a mine on a populated board. Used by tests that need to drive a loss.
    static func firstMine(on board: MinesweeperBoard) -> MinesweeperIndex {
        board.allIndices().first { board.cell(at: $0).isMine }!
    }

    /// Find a hidden non-mine cell. Used by tests that need to flag a "safe" target.
    static func firstHiddenNonMine(on board: MinesweeperBoard) -> MinesweeperIndex? {
        board.allIndices().first { idx in
            let c = board.cell(at: idx)
            return !c.isMine && c.state == .hidden
        }
    }

    // MARK: - MINES-02: reveal and flag transitions (RevealAndFlagTests)

    @MainActor
    @Suite("RevealAndFlag")
    struct RevealAndFlagTests {

        @Test
        func firstReveal_idleToPlaying_generatesFirstTapSafeBoard() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.gameState == .idle)
            #expect(vm.timerAnchor == nil)

            let firstTap = MinesweeperIndex(row: 0, col: 0)
            vm.reveal(at: firstTap)

            #expect(vm.gameState == .playing)
            #expect(vm.timerAnchor != nil, "First reveal must start the timer (D-07)")
            #expect(vm.board.cells.count(where: \.isMine) == MinesweeperDifficulty.easy.mineCount)
            // First-tap-safety preserved end-to-end (CLAUDE.md §8.11)
            #expect(vm.board.cell(at: firstTap).isMine == false)
        }

        @Test
        func toggleFlag_hiddenToFlagged_incrementsFlaggedCount() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))                // → .playing
            // Pick the first hidden non-mine cell — guaranteed to exist after first reveal.
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected at least one hidden non-mine cell after first reveal")
                return
            }
            #expect(vm.flaggedCount == 0)
            vm.toggleFlag(at: target)
            #expect(vm.flaggedCount == 1)
            #expect(vm.board.cell(at: target).state == .flagged)
        }

        @Test
        func toggleFlag_flaggedToHidden_decrementsFlaggedCount() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected at least one hidden non-mine cell after first reveal")
                return
            }
            vm.toggleFlag(at: target)
            vm.toggleFlag(at: target)
            #expect(vm.flaggedCount == 0)
            #expect(vm.board.cell(at: target).state == .hidden)
        }

        @Test
        func toggleFlag_onRevealed_isNoOp() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            let firstTap = MinesweeperIndex(row: 0, col: 0)
            vm.reveal(at: firstTap)                                        // (0,0) is now revealed
            #expect(vm.board.cell(at: firstTap).state == .revealed)
            let countBefore = vm.flaggedCount
            vm.toggleFlag(at: firstTap)
            #expect(vm.flaggedCount == countBefore)
            #expect(vm.board.cell(at: firstTap).state == .revealed)
        }
    }

    // MARK: - MINES-05 timer (TimerStateTests)

    @MainActor
    @Suite("TimerState")
    struct TimerStateTests {

        @Test
        func pause_inPlaying_accumulatesElapsedAndNilsAnchor() {
            let start = Date(timeIntervalSince1970: 1_000_000)
            let after10s = start.addingTimeInterval(10)
            var nowReturn = start
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            let vm = MinesweeperViewModel(
                difficulty: .easy,
                userDefaults: defaults,
                clock: { nowReturn },
                rng: SeededGenerator(seed: 1)
            )
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))                // anchor = start
            #expect(vm.timerAnchor == start)

            nowReturn = after10s
            vm.pause()
            #expect(vm.timerAnchor == nil)
            #expect(vm.pausedElapsed == 10)
        }

        @Test
        func resume_inPlaying_setsNewAnchor() {
            let start = Date(timeIntervalSince1970: 1_000_000)
            var nowReturn = start
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            let vm = MinesweeperViewModel(
                difficulty: .easy,
                userDefaults: defaults,
                clock: { nowReturn },
                rng: SeededGenerator(seed: 1)
            )
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            nowReturn = start.addingTimeInterval(10)
            vm.pause()
            #expect(vm.timerAnchor == nil)

            nowReturn = start.addingTimeInterval(15)
            vm.resume()
            #expect(vm.timerAnchor == start.addingTimeInterval(15))
            #expect(vm.pausedElapsed == 10)                                // unchanged across resume
        }

        @Test
        func pause_idleState_isNoOp() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.gameState == .idle)
            vm.pause()
            #expect(vm.timerAnchor == nil)
            #expect(vm.pausedElapsed == 0)
        }

        @Test
        func resume_idleState_isNoOp() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.resume()
            #expect(vm.timerAnchor == nil)
        }

        @Test
        func terminalLoss_freezesTimer() {
            let start = Date(timeIntervalSince1970: 1_000_000)
            var nowReturn = start
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            let vm = MinesweeperViewModel(
                difficulty: .easy,
                userDefaults: defaults,
                clock: { nowReturn },
                rng: SeededGenerator(seed: 1)
            )
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            // Find a mine and reveal it.
            let mineIdx = MinesweeperViewModelTests.firstMine(on: vm.board)
            nowReturn = start.addingTimeInterval(7)
            vm.reveal(at: mineIdx)
            if case .lost = vm.gameState {
                #expect(vm.timerAnchor == nil, "Terminal state must freeze timer (D-08)")
                #expect(vm.pausedElapsed == 7)
            } else {
                Issue.record("Expected .lost gameState after revealing a mine; got \(vm.gameState)")
            }
        }

        @Test
        func frozenElapsed_inIdleIsZero() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.frozenElapsed == 0)
        }
    }

    // MARK: - MINES-05 counter (MineCounterTests)

    @MainActor
    @Suite("MineCounter")
    struct MineCounterTests {

        @Test
        func minesRemaining_atIdle_equalsDifficultyMineCount() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.minesRemaining == MinesweeperDifficulty.easy.mineCount)
        }

        @Test
        func minesRemaining_decrementsOnFlag() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            let before = vm.minesRemaining
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected hidden non-mine cell after first reveal")
                return
            }
            vm.toggleFlag(at: target)
            #expect(vm.minesRemaining == before - 1)
        }

        @Test
        func minesRemaining_canGoNegativeWhenOverFlagging() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            // Flag every hidden cell — counter goes negative because we'll flag
            // more cells than there are mines. Behavior is "informational, not
            // gating" per CONTEXT.md (counter is total - flagged).
            let toFlag = vm.board.allIndices()
                .filter { vm.board.cell(at: $0).state == .hidden }
                .prefix(15)
            for idx in toFlag { vm.toggleFlag(at: idx) }
            #expect(
                vm.minesRemaining < 0,
                "Counter is informational; over-flagging produces a negative counter"
            )
        }
    }

    // MARK: - MINES-06 (RestartTests)

    @MainActor
    @Suite("Restart")
    struct RestartTests {

        @Test
        func restart_fromPlaying_resetsToIdleSameDifficulty() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .medium)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            if let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) {
                vm.toggleFlag(at: target)
            }
            let prevDifficulty = vm.difficulty

            vm.restart()
            #expect(vm.gameState == .idle)
            #expect(vm.flaggedCount == 0)
            #expect(vm.timerAnchor == nil)
            #expect(vm.pausedElapsed == 0)
            #expect(vm.lossContext == nil)
            #expect(vm.difficulty == prevDifficulty)
            #expect(vm.board.cells.count == prevDifficulty.cellCount)
        }

        @Test
        func restart_fromIdle_isIdempotent() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.restart()
            #expect(vm.gameState == .idle)
            #expect(vm.flaggedCount == 0)
            #expect(vm.timerAnchor == nil)
        }
    }

    // MARK: - MINES-07 (TerminalStateTests)

    @MainActor
    @Suite("TerminalState")
    struct TerminalStateTests {

        @Test
        func revealMine_transitionsToLost() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            let mineIdx = MinesweeperViewModelTests.firstMine(on: vm.board)
            vm.reveal(at: mineIdx)
            if case .lost(let recordedIdx) = vm.gameState {
                #expect(recordedIdx == mineIdx)
            } else {
                Issue.record("Expected .lost gameState; got \(vm.gameState)")
            }
            #expect(vm.terminalOutcome == .loss)
        }

        @Test
        func revealAllSafeCells_transitionsToWon() {
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            let vm = MinesweeperViewModel(
                difficulty: .easy,
                userDefaults: defaults,
                clock: { Date(timeIntervalSince1970: 1) },
                rng: SeededGenerator(seed: 1)
            )
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))                // bootstraps board
            // Reveal every non-mine cell that isn't already revealed.
            for idx in vm.board.allIndices() {
                let cell = vm.board.cell(at: idx)
                if !cell.isMine && cell.state == .hidden {
                    vm.reveal(at: idx)
                    if case .won = vm.gameState { break }
                }
            }
            #expect(vm.gameState == .won)
            #expect(vm.terminalOutcome == .win)
        }
    }

    // MARK: - MINES-11 (LossContextTests)

    @MainActor
    @Suite("LossContext")
    struct LossContextTests {

        @Test
        func lossContext_populatedOnMineReveal() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            let mineIdx = MinesweeperViewModelTests.firstMine(on: vm.board)
            vm.reveal(at: mineIdx)
            #expect(vm.lossContext != nil)
            if let ctx = vm.lossContext {
                #expect(ctx.minesHit >= 1)
                let safeRemaining = vm.board.cells
                    .filter { !$0.isMine && $0.state != .revealed }
                    .count
                #expect(ctx.safeCellsRemaining == safeRemaining)
            }
        }

        @Test
        func lossContext_nilOnNonTerminal() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            #expect(vm.lossContext == nil)
        }
    }

    // MARK: - D-11 (DifficultyPersistenceTests)

    @MainActor
    @Suite("DifficultyPersistence")
    struct DifficultyPersistenceTests {

        @Test
        func setDifficulty_writesUserDefaults() {
            let (vm, defaults) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.setDifficulty(.hard)
            #expect(defaults.string(forKey: MinesweeperViewModel.lastDifficultyKey) == "hard")
        }

        @Test
        func init_readsUserDefaults() {
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            defaults.set("medium", forKey: MinesweeperViewModel.lastDifficultyKey)
            let vm = MinesweeperViewModel(userDefaults: defaults)
            #expect(vm.difficulty == .medium)
        }

        @Test
        func init_emptyDefaults_fallsBackToEasy() {
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            let vm = MinesweeperViewModel(userDefaults: defaults)
            #expect(vm.difficulty == .easy, "First-launch default per D-11")
        }

        @Test
        func init_garbageInDefaults_fallsBackToEasy() {
            let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
            defaults.set("not-a-difficulty", forKey: MinesweeperViewModel.lastDifficultyKey)
            let vm = MinesweeperViewModel(userDefaults: defaults)
            #expect(vm.difficulty == .easy)
        }
    }

    // MARK: - D-10 (DifficultyChangeAlertTests)

    @MainActor
    @Suite("DifficultyChangeAlert")
    struct DifficultyChangeAlertTests {

        @Test
        func requestDifficultyChange_fromIdle_appliesImmediately() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.requestDifficultyChange(.hard)
            #expect(vm.difficulty == .hard)
            #expect(vm.showingAbandonAlert == false)
            #expect(vm.pendingDifficultyChange == nil)
        }

        @Test
        func requestDifficultyChange_fromPlaying_showsAlert() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))                // .playing
            vm.requestDifficultyChange(.hard)
            #expect(vm.difficulty == .easy, "Difficulty unchanged until user confirms abandon (D-10)")
            #expect(vm.showingAbandonAlert == true)
            #expect(vm.pendingDifficultyChange == .hard)
        }

        @Test
        func confirmDifficultyChange_appliesPendingAndDismissesAlert() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            vm.requestDifficultyChange(.hard)
            vm.confirmDifficultyChange()
            #expect(vm.difficulty == .hard)
            #expect(vm.gameState == .idle, "Restart fires after difficulty switch")
            #expect(vm.showingAbandonAlert == false)
            #expect(vm.pendingDifficultyChange == nil)
        }

        @Test
        func cancelDifficultyChange_keepsCurrentDifficultyAndDismissesAlert() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            vm.requestDifficultyChange(.hard)
            vm.cancelDifficultyChange()
            #expect(vm.difficulty == .easy)
            #expect(vm.gameState == .playing, "Cancel must NOT abandon the in-progress game (D-10)")
            #expect(vm.showingAbandonAlert == false)
            #expect(vm.pendingDifficultyChange == nil)
        }

        @Test
        func requestSameDifficulty_isNoOp() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.reveal(at: MinesweeperIndex(row: 0, col: 0))
            vm.requestDifficultyChange(.easy)
            #expect(vm.showingAbandonAlert == false)
            #expect(vm.pendingDifficultyChange == nil)
        }
    }

    // MARK: - MINES-12 Phase 6.1 (InteractionModeTests)
    //
    // Reveal/Flag interaction-mode toggle. The view tier (CellView gesture
    // closures threaded via BoardView from GameView) calls vm.handleTap and
    // vm.handleLongPress — NEVER vm.reveal/vm.toggleFlag directly. Mode-routing
    // logic lives in the VM (CONTEXT D-06 / D-11; CLAUDE.md §1 lightweight
    // MVVM; ARCHITECTURE Anti-Pattern 1).
    //
    // RED gate (Plan 06.1-02 Task 1): all 7 tests below must FAIL TO COMPILE
    // before Task 2 ships. Expected errors: cannot find 'interactionMode' /
    // 'handleTap' / 'handleLongPress' / 'toggleInteractionMode' /
    // 'modeToggleCount' in scope. TDD precedent locked across Plans 04-02 /
    // 05-01 / 05-06 / 06-01 / 06-02 / 06.1-03.

    @MainActor
    @Suite("InteractionMode")
    struct InteractionModeTests {

        @Test
        func tap_in_revealMode_revealsCell() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.interactionMode == .reveal, "Default mode is .reveal (CONTEXT D-07)")
            let firstTap = MinesweeperIndex(row: 0, col: 0)
            vm.handleTap(at: firstTap)
            #expect(vm.gameState == .playing, "First handleTap in .reveal mode bootstraps the board (D-07)")
            #expect(vm.board.cell(at: firstTap).state == .revealed)
            #expect(vm.flaggedCount == 0, "Tap in .reveal mode must NOT flag")
        }

        @Test
        func tap_in_flagMode_togglesFlag() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            // Bootstrap board with an initial reveal in .reveal mode (the .idle
            // -> .playing transition lives behind reveal(at:); flag in .idle is
            // a no-op per existing toggleFlag guard).
            vm.handleTap(at: MinesweeperIndex(row: 0, col: 0))
            // Switch to flag mode — handleTap should now flag.
            vm.toggleInteractionMode()
            #expect(vm.interactionMode == .flag)
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected hidden non-mine cell after first reveal")
                return
            }
            let countBefore = vm.flaggedCount
            vm.handleTap(at: target)
            #expect(vm.flaggedCount == countBefore + 1, "Tap in .flag mode toggles a flag (CONTEXT D-06)")
            #expect(vm.board.cell(at: target).state == .flagged)
        }

        @Test
        func longPress_in_revealMode_togglesFlag() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.handleTap(at: MinesweeperIndex(row: 0, col: 0))
            #expect(vm.interactionMode == .reveal)
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected hidden non-mine cell after first reveal")
                return
            }
            let countBefore = vm.flaggedCount
            vm.handleLongPress(at: target)
            #expect(
                vm.flaggedCount == countBefore + 1,
                "Long-press in .reveal mode flags (current MINES-02 long-press semantic; CONTEXT D-06)"
            )
            #expect(vm.board.cell(at: target).state == .flagged)
        }

        @Test
        func longPress_in_flagMode_revealsCell() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.handleTap(at: MinesweeperIndex(row: 0, col: 0))
            vm.toggleInteractionMode()
            #expect(vm.interactionMode == .flag)
            guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
                Issue.record("Expected hidden non-mine cell after first reveal")
                return
            }
            vm.handleLongPress(at: target)
            #expect(
                vm.board.cell(at: target).state == .revealed,
                "Long-press in .flag mode reveals (inverted; CONTEXT D-06)"
            )
        }

        @Test
        func toggleInteractionMode_cycles() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.interactionMode == .reveal)
            vm.toggleInteractionMode()
            #expect(vm.interactionMode == .flag)
            vm.toggleInteractionMode()
            #expect(vm.interactionMode == .reveal, "Two toggles return to default")
        }

        @Test
        func restart_resets_interactionMode_and_modeToggleCount() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            vm.toggleInteractionMode()
            vm.toggleInteractionMode()
            vm.toggleInteractionMode()
            #expect(vm.interactionMode == .flag, "Three toggles ends in .flag")
            #expect(vm.modeToggleCount == 3, "modeToggleCount bumps once per toggle")

            vm.restart()
            #expect(
                vm.interactionMode == .reveal,
                "restart() resets mode to .reveal — no UserDefaults persistence (CONTEXT D-08)"
            )
            #expect(
                vm.modeToggleCount == 0,
                "restart() resets modeToggleCount for symmetry with revealCount/flagToggleCount (RESEARCH open question #3)"
            )
        }

        @Test
        func modeToggleCount_bumps_per_toggle() {
            let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
            #expect(vm.modeToggleCount == 0)
            vm.toggleInteractionMode()
            #expect(vm.modeToggleCount == 1)
            vm.toggleInteractionMode()
            #expect(vm.modeToggleCount == 2)
            vm.toggleInteractionMode()
            #expect(vm.modeToggleCount == 3)
        }
    }

    // MARK: - ARCHITECTURE Anti-Pattern 1 — Foundation-only purity (structural belt-and-suspenders)

    @Test
    func vmSourceFile_importsOnlyFoundation() throws {
        // Resolve via candidate paths — Swift Testing test runtime does not
        // expose a stable working directory across local-dev vs CI. The Task 1
        // verify block also enforces this via grep, so this is a redundant
        // belt-and-suspenders check.
        let relPath = "gamekit/gamekit/Games/Minesweeper/MinesweeperViewModel.swift"
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            cwd + "/" + relPath,
            cwd + "/../" + relPath,
            cwd + "/../../" + relPath,
        ]
        guard let existing = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            // Path unknown — skip. Task 1 verify block enforces this anyway.
            return
        }
        let source = try String(contentsOfFile: existing, encoding: .utf8)
        #expect(!source.contains("\nimport SwiftUI"))
        #expect(!source.contains("\nimport Combine"))
        #expect(!source.contains("\nimport SwiftData"))
        #expect(!source.contains("\nimport UIKit"))
        #expect(!source.contains("\nimport AppKit"))
    }
}
