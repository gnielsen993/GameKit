//
//  MinesweeperPhase.swift
//  gamekit
//
//  Animation orchestration enum owned by the P5 ViewModel and observed by the
//  Minesweeper view tier. Distinct from `MinesweeperGameState` (lifecycle truth)
//  per CONTEXT D-05/D-06 — `gameState` drives engine/persistence logic, `phase`
//  exists purely so views can drive `.phaseAnimator` / `.keyframeAnimator` /
//  `.transition` / `.symbolEffect` modifiers via `.onChange(of: vm.phase)`.
//
//  Phase 5 invariants (per CONTEXT D-05/D-06):
//    - Five cases — idle / revealing(cells:) / flagging(idx:) / winSweep / lossShake(mineIdx:)
//    - VM publishes; views observe. VM owns NO `Animation` types and NO
//      `withAnimation` calls — animation envelope is a view-tier concern.
//    - Equatable + Sendable — `.onChange(of:)` requires Equatable; Sendable
//      keeps the value safe to ferry across actor hops.
//    - NOT Hashable — would force `[MinesweeperIndex]` payload on `.revealing`
//      to be Hashable too, and no consumer needs hashing.
//    - NOT Codable — transient view-layer enum, never persisted (matches
//      MinesweeperGameState precedent at MinesweeperGameState.swift:14).
//    - Foundation-only — ROADMAP P2 SC5 (engine purity) extends to this file
//      because the VM that publishes `phase` must remain Foundation-only per
//      MinesweeperViewModel.swift:20. ZERO SwiftUI / Combine / SwiftData imports.
//

import Foundation

/// Animation orchestration phase published by `MinesweeperViewModel` and
/// observed by the Minesweeper view tier via `.onChange(of: vm.phase)`.
///
/// Foundation-only — keeps the VM publishing path free of SwiftUI types
/// per CONTEXT D-05 (animation is view-tier concern).
nonisolated enum MinesweeperPhase: Equatable, Sendable {
    /// Pre-first-tap. No animation in flight. VM resets to `.idle` on `restart()`.
    /// Consumed by RESEARCH §Pattern 3 (per-cell `.transition` cascade) — the
    /// cascade modifier is dormant until phase leaves `.idle`.
    case idle

    /// Reveal cascade in flight. `cells` is the engine D-06 ordered reveal list
    /// from `RevealEngine.reveal(at:on:) -> (board, revealed: [Index])` (P2
    /// contract). View consumer: RESEARCH §Pattern 3 — per-cell `.transition`
    /// stagger using each cell's index in this array (CONTEXT D-01: per-cell
    /// delay = `min(8ms × index, 250ms / count)`).
    case revealing(cells: [MinesweeperIndex])

    /// Single-cell flag toggle. View consumer: RESEARCH §Pattern 4 —
    /// `.symbolEffect(.bounce)` flag spring on the targeted cell, gated on
    /// `.onChange(of: vm.flagToggleCount)` for trigger pattern.
    case flagging(idx: MinesweeperIndex)

    /// Win recognized by `WinDetector.isWon(...)`. View consumer: RESEARCH
    /// §Pattern 1 — `.phaseAnimator` win-sweep overlay (CONTEXT D-02:
    /// `theme.colors.success` opacity 0 → 0.25 → 0 over `theme.motion.slow`)
    /// plus end-state DKCard fade-in.
    case winSweep

    /// Loss recognized by `WinDetector.isLost(...)` with the triggering mine
    /// index. View consumer: RESEARCH §Pattern 2 — `.keyframeAnimator`
    /// horizontal shake on the board (CONTEXT D-03: 3-bump 8pt magnitude
    /// over 400ms) plus mine-reveal cascade.
    case lossShake(mineIdx: MinesweeperIndex)

    /// Trigger gate for `.keyframeAnimator` (RESEARCH §Pattern 2). The view
    /// drives the shake whenever this flips true; payload-agnostic so a fresh
    /// `.lossShake(mineIdx:)` doesn't replay the keyframes against the same
    /// payload pointer.
    var isLossShake: Bool {
        if case .lossShake = self { return true }
        return false
    }
}
