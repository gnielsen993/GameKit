//
//  MinesweeperGameView+SmallZone.swift
//  gamekit
//
//  Phase 12.1 Plan 12.1-02 — Small-zone layout for MinesweeperGameView.
//
//  Split from MinesweeperGameView+VideoMode.swift (which was at 485 LOC,
//  close to the CLAUDE.md §8.5 ≤500-line hard cap) per CONTEXT
//  "Claude's Discretion (a)": adding the smallZoneLayout body inline
//  would have crossed the cap, so the sibling-file path is taken.
//
//  Owns ONE @ViewBuilder var:
//    - `smallZoneLayout` — Small-zone branch of MinesweeperGameView's
//      3-way layout switch. Consumes `anchors.headerBar` + `anchors.picker`
//      from VideoModeSlotRouter (extended in 12.1-01) to reposition
//      MinesweeperHeaderBar + MinesweeperModePill away from the PiP overlay
//      zone for the current Small location.
//
//  Routing summary (per CONTEXT D-04 / D-05 / D-07 / D-08 / D-09):
//    - Top L/R Small zones — anchors.headerBar = .bottomLeading / .bottomTrailing
//      → VStack ordering: Board → HeaderBar → ModePill (top edge clear).
//    - Bot L/R Small zones — anchors.headerBar = .topLeading / .topTrailing
//      → VStack ordering: HeaderBar → ModePill → Board (bottom edge clear).
//
//  The cross-product collapses to a single boolean `headerBarAtBottom`
//  because, in this matrix, picker placement is the inverse of headerBar
//  placement (Top L/R → both push to bottom; Bot L/R → both stay at top).
//  `anchors.picker` is implicitly consumed through this boolean — no
//  independent branching needed.
//
//  D-MS-10 LOCKED: MinesweeperBoardView constructor call site is byte-identical
//  to the call sites in `existingLayout` (lines 59–73) and `largeZoneLayout`
//  (lines 276–290) in MinesweeperGameView+VideoMode.swift — same labels in
//  the same order, same `.keyframeAnimator` loss-shake surface. The pinch-zoom
//  + auto-scale system from 06.1-03 + A11Y-05 is untouched.
//
//  D-11 LOCKED: this file does NOT modify `existingLayout` or the off-path
//  branch in any way. The off-path body of MinesweeperGameView still resolves
//  to `existingLayout` verbatim.
//

import SwiftUI
import DesignKit

extension MinesweeperGameView {

    // MARK: - Phase 12.1 Plan 12.1-02 — Small-zone layout

    /// Phase 12.1 (Plan 12.1-02) — Small-zone branch consuming
    /// `anchors.headerBar` + `anchors.picker` per CONTEXT D-04 / D-05 /
    /// D-07 / D-08 / D-09. Ordering of HeaderBar / ModePill / Board flips
    /// based on whether `anchors.headerBar` is a top or bottom anchor; on
    /// Top L/R zones HeaderBar moves to the bottom of the column (top edge
    /// clear for top-PiP); on Bot L/R zones HeaderBar stays at top and
    /// ModePill renders directly below it (bottom edge clear for bottom-PiP).
    /// `MinesweeperBoardView` call site is byte-identical to `existingLayout`
    /// per D-MS-10.
    @ViewBuilder
    var smallZoneLayout: some View {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        // headerBarAtBottom = Top L/R Small zones (PiP at top, push chrome down).
        // !headerBarAtBottom = Bot L/R Small zones (PiP at bottom, keep chrome up).
        // anchors.picker is implicitly consumed: on Top L/R it's a bottom anchor
        // (ModePill renders at the bottom, after HeaderBar); on Bot L/R it's a
        // bottom anchor too but the bottom-PiP forces ModePill UP to the top
        // (renders directly below HeaderBar per D-09).
        let headerBarAtBottom = (anchors.headerBar == .bottomLeading
                                 || anchors.headerBar == .bottomTrailing)

        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                if !headerBarAtBottom {
                    // Bot L/R zones — bottom-PiP at bottom; chrome stays at top.
                    // Render order: HeaderBar (top) → ModePill (just below) → Board fills.
                    MinesweeperHeaderBar(
                        theme: theme,
                        minesRemaining: viewModel.minesRemaining,
                        timerAnchor: viewModel.timerAnchor,
                        pausedElapsed: viewModel.pausedElapsed
                    )

                    MinesweeperModePill(
                        theme: theme,
                        mode: viewModel.interactionMode,
                        onSelect: { viewModel.setInteractionMode($0) }
                    )
                    .padding(.top, theme.spacing.s)
                    .opacity(viewModel.terminalOutcome == nil ? 1 : 0)
                    .allowsHitTesting(viewModel.terminalOutcome == nil)
                    .sensoryFeedback(
                        .impact(weight: .light),
                        trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0
                    )

                    MinesweeperBoardView(
                        theme: theme,
                        board: viewModel.board,
                        gameState: viewModel.gameState,
                        phase: viewModel.phase,
                        hapticsEnabled: settingsStore.hapticsEnabled,
                        reduceMotion: reduceMotion,
                        revealCount: viewModel.revealCount,
                        flagToggleCount: viewModel.flagToggleCount,
                        lossMinesRevealed: lossMinesRevealed,
                        lossWrongFlagsPopped: lossWrongFlagsPopped,
                        lossTripIdx: tripCellIndex,
                        onTap: { viewModel.handleTap(at: $0) },
                        onLongPress: { viewModel.handleLongPress(at: $0) }
                    )
                    // P5 D-03 loss-shake surface — preserved byte-identical
                    // to existingLayout per D-MS-10.
                    .keyframeAnimator(
                        initialValue: 0.0,
                        trigger: reduceMotion ? false : viewModel.phase.isLossShake
                    ) { content, value in
                        content.offset(x: value)
                    } keyframes: { _ in
                        LinearKeyframe(8.0, duration: 0.1)
                        LinearKeyframe(-8.0, duration: 0.1)
                        LinearKeyframe(4.0, duration: 0.1)
                        LinearKeyframe(0.0, duration: 0.1)
                    }
                } else {
                    // Top L/R zones — top-PiP at top; chrome moves to bottom.
                    // Render order: Board fills → HeaderBar (bottom-aligned, per D-07)
                    // → ModePill (below HeaderBar — picker is the inverse of
                    // HeaderBar in this cross-product per D-08).
                    MinesweeperBoardView(
                        theme: theme,
                        board: viewModel.board,
                        gameState: viewModel.gameState,
                        phase: viewModel.phase,
                        hapticsEnabled: settingsStore.hapticsEnabled,
                        reduceMotion: reduceMotion,
                        revealCount: viewModel.revealCount,
                        flagToggleCount: viewModel.flagToggleCount,
                        lossMinesRevealed: lossMinesRevealed,
                        lossWrongFlagsPopped: lossWrongFlagsPopped,
                        lossTripIdx: tripCellIndex,
                        onTap: { viewModel.handleTap(at: $0) },
                        onLongPress: { viewModel.handleLongPress(at: $0) }
                    )
                    // P5 D-03 loss-shake surface — preserved byte-identical
                    // to existingLayout per D-MS-10.
                    .keyframeAnimator(
                        initialValue: 0.0,
                        trigger: reduceMotion ? false : viewModel.phase.isLossShake
                    ) { content, value in
                        content.offset(x: value)
                    } keyframes: { _ in
                        LinearKeyframe(8.0, duration: 0.1)
                        LinearKeyframe(-8.0, duration: 0.1)
                        LinearKeyframe(4.0, duration: 0.1)
                        LinearKeyframe(0.0, duration: 0.1)
                    }

                    MinesweeperHeaderBar(
                        theme: theme,
                        minesRemaining: viewModel.minesRemaining,
                        timerAnchor: viewModel.timerAnchor,
                        pausedElapsed: viewModel.pausedElapsed
                    )

                    MinesweeperModePill(
                        theme: theme,
                        mode: viewModel.interactionMode,
                        onSelect: { viewModel.setInteractionMode($0) }
                    )
                    .padding(.top, theme.spacing.s)
                    .opacity(viewModel.terminalOutcome == nil ? 1 : 0)
                    .allowsHitTesting(viewModel.terminalOutcome == nil)
                    .sensoryFeedback(
                        .impact(weight: .light),
                        trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0
                    )
                }
            }

            // P5 D-02 win-sweep wash — preserved byte-identical to existingLayout.
            // Sits ABOVE the board cells but BELOW the end-state DKCard so the
            // wash doesn't block taps (.allowsHitTesting(false) also enforces).
            Rectangle()
                .fill(theme.colors.success)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .phaseAnimator(
                    reduceMotion ? [0.0] : [0.0, 0.25, 0.0],
                    trigger: viewModel.phase == .winSweep
                ) { content, alpha in
                    content.opacity(alpha)
                } animation: { _ in
                    .easeInOut(duration: theme.motion.slow)
                }

            // Confetti — fires on win for a beat before the end card lands.
            // Same gate as existingLayout (showConfetti @State on the host
            // struct, flipped by runWinChoreography in MinesweeperGameView).
            if showConfetti {
                ConfettiView(theme: theme)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // End-state overlay — same gate as existingLayout so the loss
            // cascade / win confetti finish their pre-roll first.
            if let outcome = viewModel.terminalOutcome, endCardVisible {
                endStateOverlay(outcome: outcome)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }
}
