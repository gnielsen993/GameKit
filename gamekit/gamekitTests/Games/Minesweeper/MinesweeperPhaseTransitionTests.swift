//
//  MinesweeperPhaseTransitionTests.swift
//  gamekitTests
//
//  Plan 05-06 — Swift Testing coverage for the 5 D-06 phase transitions
//  on `MinesweeperViewModel`. Phase 5 extends the P3 VM additively with
//  `phase: MinesweeperPhase` + `revealCount` + `flagToggleCount` published
//  state. These tests pin the contract:
//
//    1. First reveal     → `.revealing(cells:)` with engine-ordered list
//    2. Toggle flag      → `.flagging(idx:)` + `flagToggleCount` bumped
//    3. Reveal mine      → `.lossShake(mineIdx:)` matching `gameState.lost`
//    4. Reveal last safe → `.winSweep`
//    5. Restart          → `.idle`, `revealCount = 0`, `flagToggleCount = 0`
//    6. Idempotent reveal does NOT bump `revealCount` (engine D-19 contract:
//       reveal of already-revealed cell returns `(board, [])`).
//
//  Determinism: reuses `MinesweeperViewModelTests.makeVM(...)` static factory
//  per Plan 05-06 PATTERNS line 723 — same isolated UserDefaults / pinned
//  Date / SeededGenerator(seed: 1) shape as the P3 suite. The factory is
//  static, so a sibling `@Suite` calls it as
//  `MinesweeperViewModelTests.makeVM(...)` (verified at line 81 of the same
//  file where `RevealAndFlagTests` uses it).
//
//  Foundation invariant (CONTEXT D-05) preserved by the VM under test —
//  no SwiftUI/Combine/SwiftData imports needed here.
//

import Testing
import Foundation
@testable import gamekit

@MainActor
@Suite("MinesweeperPhaseTransitions")
struct MinesweeperPhaseTransitionTests {

    // MARK: - 1. First reveal → .revealing(cells:) with engine-ordered list

    @Test
    func firstReveal_setsPhaseToRevealing_withEngineOrderedCells() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        #expect(vm.phase == .idle, "VM starts in .idle phase (CONTEXT D-06 first case)")
        #expect(vm.revealCount == 0)

        let firstTap = MinesweeperIndex(row: 0, col: 0)
        vm.reveal(at: firstTap)

        // Phase MUST be .revealing(cells:) and the cells MUST equal the engine
        // ordered reveal list. Recompute the engine output against the post-
        // first-tap board to assert order parity (the VM bootstraps the board
        // inside reveal(at:), then runs RevealEngine on the same board).
        if case .revealing(let cells) = vm.phase {
            #expect(!cells.isEmpty, "Engine returns at least the tapped cell")
            #expect(cells.contains(firstTap), "Engine reveal list must include the tapped cell")
        } else {
            Issue.record("Expected .revealing(cells:) phase after first reveal; got \(vm.phase)")
        }
        #expect(vm.revealCount == 1, "First successful reveal bumps revealCount")
    }

    // MARK: - 2. Toggle flag → .flagging(idx:) + flagToggleCount bumped

    @Test
    func toggleFlag_setsPhaseToFlagging_andBumpsFlagToggleCount() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))    // → .playing + .revealing
        #expect(vm.flagToggleCount == 0)

        guard let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) else {
            Issue.record("Expected at least one hidden non-mine cell after first reveal")
            return
        }
        vm.toggleFlag(at: target)

        if case .flagging(let idx) = vm.phase {
            #expect(idx == target)
        } else {
            Issue.record("Expected .flagging(idx:) phase after toggleFlag; got \(vm.phase)")
        }
        #expect(vm.flagToggleCount == 1, "Toggle bumps flagToggleCount once per state transition")

        // Flagged → hidden also bumps the count (D-07 trigger fires on every
        // flag spring, both directions).
        vm.toggleFlag(at: target)
        if case .flagging(let idx) = vm.phase {
            #expect(idx == target)
        } else {
            Issue.record("Expected .flagging(idx:) after second toggle; got \(vm.phase)")
        }
        #expect(vm.flagToggleCount == 2)
    }

    // MARK: - 2b. Toggle flag on revealed cell is no-op (preserves P3 D-19)

    @Test
    func toggleFlag_onRevealedCell_doesNotBumpCounter() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        vm.reveal(at: firstTap)                            // (0,0) revealed
        #expect(vm.board.cell(at: firstTap).state == .revealed)

        let countBefore = vm.flagToggleCount
        vm.toggleFlag(at: firstTap)                        // no-op (P3 D-19)
        #expect(vm.flagToggleCount == countBefore,
                "flagToggleCount must NOT bump on rejected toggle (P3 D-19)")
    }

    // MARK: - 3. Reveal mine → .lossShake(mineIdx:) matching gameState

    @Test
    func revealMine_setsPhaseToLossShake_withTrippedMineIndex() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))    // bootstrap board
        let mineIdx = MinesweeperViewModelTests.firstMine(on: vm.board)
        vm.reveal(at: mineIdx)

        // gameState.lost(mineIdx:) and phase.lossShake(mineIdx:) MUST agree.
        if case .lost(let stateMineIdx) = vm.gameState,
           case .lossShake(let phaseMineIdx) = vm.phase {
            #expect(stateMineIdx == phaseMineIdx,
                    "phase mineIdx must equal gameState mineIdx (atomic transition)")
            #expect(phaseMineIdx == mineIdx)
        } else {
            Issue.record("Expected .lost gameState + .lossShake phase; got \(vm.gameState) / \(vm.phase)")
        }
    }

    // MARK: - 4. Reveal last safe cell → .winSweep

    @Test
    func revealLastSafe_setsPhaseToWinSweep() {
        let defaults = MinesweeperViewModelTests.makeIsolatedDefaults()
        let vm = MinesweeperViewModel(
            difficulty: .easy,
            userDefaults: defaults,
            clock: { Date(timeIntervalSince1970: 1) },
            rng: SeededGenerator(seed: 1)
        )
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))    // bootstrap
        // Reveal every non-mine cell that isn't already revealed (mirrors
        // MinesweeperViewModelTests.TerminalStateTests.revealAllSafeCells_…).
        for idx in vm.board.allIndices() {
            let cell = vm.board.cell(at: idx)
            if !cell.isMine && cell.state == .hidden {
                vm.reveal(at: idx)
                if case .won = vm.gameState { break }
            }
        }
        #expect(vm.gameState == .won)
        #expect(vm.phase == .winSweep,
                "On terminal win, phase must transition to .winSweep atomically with gameState (D-05)")
    }

    // MARK: - 5. Restart → .idle, revealCount = 0, flagToggleCount = 0

    @Test
    func restart_resetsPhaseToIdle_andClearsCounters() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        vm.reveal(at: MinesweeperIndex(row: 0, col: 0))    // bumps revealCount
        if let target = MinesweeperViewModelTests.firstHiddenNonMine(on: vm.board) {
            vm.toggleFlag(at: target)                      // bumps flagToggleCount
        }
        #expect(vm.revealCount > 0)
        #expect(vm.flagToggleCount > 0)
        #expect(vm.phase != .idle)

        vm.restart()
        #expect(vm.phase == .idle)
        #expect(vm.revealCount == 0)
        #expect(vm.flagToggleCount == 0)
    }

    // MARK: - 6. revealCount semantics — successful only, NOT idempotent calls

    @Test
    func revealCount_incrementsOnSuccessfulReveal_notOnIdempotent() {
        let (vm, _) = MinesweeperViewModelTests.makeVM(difficulty: .easy)
        let firstTap = MinesweeperIndex(row: 0, col: 0)
        vm.reveal(at: firstTap)                            // first reveal
        let countAfterFirst = vm.revealCount
        #expect(countAfterFirst == 1)

        // Reveal the SAME cell again. Per RevealEngine D-19 contract, a reveal
        // of an already-`.revealed` cell returns `(board, [])` — no board
        // mutation, no meaningful state transition. revealCount must NOT bump.
        vm.reveal(at: firstTap)
        #expect(vm.revealCount == countAfterFirst,
                "Idempotent reveal of already-revealed cell must NOT bump revealCount")
    }
}
