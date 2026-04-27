//
//  MinesweeperBoardView.swift
//  gamekit
//
//  Composes MinesweeperCellView instances into a LazyVGrid.
//  Easy 9×9 (cell 44pt) and Medium 16×16 (cell 40pt) render without scrolling
//  on iPhone 13/15 standard widths; Hard 16×30 (cell 36pt) wraps in a
//  horizontal ScrollView regardless of device (CONTEXT Discretion (a)).
//
//  Phase 3 invariants (per CONTEXT D-12, UI-SPEC §Layout & Sizing,
//  RESEARCH §Pattern 5 loss-state per-cell switch is OWNED BY MinesweeperCellView):
//    - Cell-size constants are intrinsic component dimensions — UI-SPEC §Spacing carve-out
//      (NOT new spacing tokens; .frame(width:height:) is exempt from the FOUND-07 hook)
//    - Props-only — receives theme + board + gameState + tap/long-press closures
//    - Routes events through closures; never reads or writes the VM directly
//    - ForEach iterates board.allIndices() (Hashable Index) — NOT enumerated() —
//      RESEARCH Pitfall 6 (stable diffing across board reset)
//

import SwiftUI
import DesignKit

struct MinesweeperBoardView: View {
    let theme: Theme
    let board: MinesweeperBoard
    let gameState: MinesweeperGameState

    // P5 (D-01/D-04/D-07) — animation orchestration props (props-only,
    // CLAUDE.md §8.2). MinesweeperGameView hoists these from the VM /
    // environment and passes through; child cells receive the same.
    let phase: MinesweeperPhase
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let revealCount: Int
    let flagToggleCount: Int

    let onTap: (MinesweeperIndex) -> Void
    let onLongPress: (MinesweeperIndex) -> Void

    // MARK: - Cell-size heuristic (UI-SPEC §Layout & Sizing)
    //
    // Intrinsic component dimensions; NOT a spacing token.
    // Easy 44pt = HIG min; Medium 40pt; Hard 36pt = documented carve-out
    // (gesture accuracy validated as part of SC1 manual-test pass).
    private var cellSize: CGFloat {
        switch board.difficulty {
        case .easy:   return 44
        case .medium: return 40
        case .hard:   return 36
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSize), spacing: theme.spacing.xs),
            count: board.cols
        )
    }

    var body: some View {
        // P5 D-01: extract the engine-ordered reveal list once per render so
        // the per-cell delay lookup is O(n) instead of O(n²).
        let revealingCells: [MinesweeperIndex] = {
            if case .revealing(let cells) = phase { return cells }
            return []
        }()
        let cascadeCount = max(revealingCells.count, 1)

        ScrollView(scrollAxis(for: board.difficulty), showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: theme.spacing.xs) {
                ForEach(board.allIndices(), id: \.self) { index in
                    let perCellDelay: Double = {
                        // D-04: Reduce Motion → no stagger; cascade collapses
                        // to simultaneous reveal.
                        guard !reduceMotion,
                              let order = revealingCells.firstIndex(of: index)
                        else { return 0 }
                        // D-01 budget: per-cell delay = min(8ms × index,
                        // theme.motion.normal / count). Hard flood-fill of
                        // 100+ cells stays inside theme.motion.normal cap.
                        return min(0.008 * Double(order), theme.motion.normal / Double(cascadeCount))
                    }()

                    MinesweeperCellView(
                        cell: board.cell(at: index),
                        index: index,
                        cellSize: cellSize,
                        theme: theme,
                        gameState: gameState,
                        hapticsEnabled: hapticsEnabled,
                        reduceMotion: reduceMotion,
                        revealCount: revealCount,
                        flagToggleCount: flagToggleCount,
                        onTap: onTap,
                        onLongPress: onLongPress
                    )
                    .transition(
                        reduceMotion
                        ? .identity
                        : .opacity.animation(.easeOut(duration: theme.motion.fast).delay(perCellDelay))
                    )
                }
            }
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.s)
        }
    }

    /// Hard scrolls horizontally; Easy/Medium do not scroll on phones ≥ 390pt.
    /// (On iPhone SE 320pt, Medium will scroll horizontally too — `.horizontal`
    /// is harmless when content fits because ScrollView no-ops; the guard here
    /// is a layout choice for the typical-device path.)
    private func scrollAxis(for difficulty: MinesweeperDifficulty) -> Axis.Set {
        difficulty == .hard ? .horizontal : []
    }
}
