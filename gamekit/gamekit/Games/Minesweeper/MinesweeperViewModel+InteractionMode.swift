//
//  MinesweeperViewModel+InteractionMode.swift
//  gamekit
//
//  Reveal/Flag interaction-mode toggle (Phase 6.1, MINES-12) extracted
//  from MinesweeperViewModel on 2026-05-01 to keep the host file under
//  the §8.1 split-smell zone.
//
//  Mode-routing logic (CLAUDE.md §1 lightweight MVVM, ARCHITECTURE
//  Anti-Pattern 1) lives entirely in the VM — `MinesweeperCellView` never
//  branches on mode, only forwards `handleTap` / `handleLongPress` closures.
//
//  CONTEXT D-06 / D-09 / D-11 invariants preserved:
//    - `.reveal` (default) — tap reveals, long-press flags
//    - `.flag` — tap toggles flag, long-press reveals (long-press always
//      escapes the current mode, regardless of which one)
//    - Terminal states are a structural no-op — the FAB hides post-terminal
//      per D-09, and these guards ensure any future call site can't change
//      mode after the game ends
//    - `modeToggleCount` bumps on `toggleInteractionMode()` and
//      `setInteractionMode(_:)` for the FAB-level
//      `.sensoryFeedback(.impact(.light))` haptic
//

import Foundation

extension MinesweeperViewModel {
    /// Toggle between `.reveal` and `.flag` modes. Bumps `modeToggleCount`
    /// for the FAB-level `.sensoryFeedback(.impact(.light))` haptic
    /// (CONTEXT D-09). Terminal states (.won / .lost) are a structural
    /// no-op — the FAB hides post-terminal per CONTEXT D-09 / RESEARCH
    /// open question #2, but this guard ensures any future call site
    /// also can't change mode after the game ends.
    func toggleInteractionMode() {
        if case .won = gameState { return }
        if case .lost = gameState { return }
        switch interactionMode {
        case .reveal: interactionMode = .flag
        case .flag:   interactionMode = .reveal
        }
        modeToggleCount += 1
    }

    /// Set interaction mode directly. No-op when already at target mode or
    /// when the game has ended. Used by pill-flipper UI where the user taps
    /// a specific segment rather than a single toggle button.
    func setInteractionMode(_ mode: MinesweeperInteractionMode) {
        if case .won = gameState { return }
        if case .lost = gameState { return }
        guard interactionMode != mode else { return }
        interactionMode = mode
        modeToggleCount += 1
    }

    /// View-tier entry point for tap gesture. Branches on `interactionMode`
    /// (CONTEXT D-06 / D-11). View NEVER calls `reveal(at:)` /
    /// `toggleFlag(at:)` directly after Phase 6.1 — mode-routing logic
    /// lives in the VM (CLAUDE.md §1 lightweight MVVM, ARCHITECTURE
    /// Anti-Pattern 1).
    func handleTap(at index: MinesweeperIndex) {
        switch interactionMode {
        case .reveal: reveal(at: index)
        case .flag:   toggleFlag(at: index)
        }
    }

    /// View-tier entry point for long-press gesture. Long-press is ALWAYS
    /// the OPPOSITE of the current mode's tap action — provides a
    /// quick-action escape regardless of which mode is active (CONTEXT
    /// D-06). The 0.25s threshold + `.exclusively(before:)` gesture
    /// composition are owned by `MinesweeperCellView` and are NOT touched
    /// by Phase 6.1 (ROADMAP P3 SC1 lock + Plan 03-03 invariant).
    func handleLongPress(at index: MinesweeperIndex) {
        switch interactionMode {
        case .reveal: toggleFlag(at: index)
        case .flag:   reveal(at: index)
        }
    }
}
