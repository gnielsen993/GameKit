//
//  SudokuGameView+VideoMode.swift
//  gamekit
//
//  Video Mode layout helpers for SudokuGameView. Split from the main file to
//  keep both files under the CLAUDE.md §8.5 ≤500-line hard cap.
//
//  Sudoku's Video Mode contract mirrors Nonogram (Phase 13 VideoModeBanner
//  path). The game uses the shared VideoModeBanner for end-state (not the
//  legacy NonogramEndStateCard shape) and the shared VideoModeTimerChip
//  for elapsed time.
//
//  Large-zone layout: HeaderBar + Board + NumberPad, nav-bar hidden.
//  The number pad must remain visible in large-zone since Sudoku input
//  requires it — unlike Nonogram which has no numpad.
//
//  Small-zone layout: uses existingLayout (same as off-path) with
//  repositioned toolbar via smallZoneToolbarContent.
//

import SwiftUI
import DesignKit

extension SudokuGameView {

    // MARK: - Video Mode top-level branch

    @ViewBuilder
    var videoModeLayout: some View {
        if videoModeStore.location.isLarge {
            largeZoneLayout
                .toolbar(.hidden, for: .navigationBar)
        } else {
            existingLayout
                .toolbar { smallZoneToolbarContent }
        }
    }

    // MARK: - Large-zone layout

    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                SudokuHeaderBar(
                    theme: theme,
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed,
                    mistakes: viewModel.gameMode == .lives ? viewModel.mistakes : nil,
                    isInteractive: isInteractive,
                    interactionMode: viewModel.interactionMode,
                    onSelectMode: { viewModel.setInteractionMode($0) }
                )

                if viewModel.board != nil {
                    sudokuBoard
                } else {
                    Spacer()
                    Text(String(localized: "Loading puzzle…"))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                SudokuNumberPad(viewModel: viewModel, theme: theme)
                    .opacity(isInteractive ? 1 : 0.4)
                    .allowsHitTesting(isInteractive)
            }
            .padding(.bottom, theme.spacing.l)

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Small-zone toolbar (repositioned via VideoModeSlotRouter)

    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { backButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { restartButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
            SudokuToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                currentGameMode: viewModel.gameMode,
                onSelectDifficulty: { viewModel.setDifficulty($0) },
                onSelectGameMode: { viewModel.setGameMode($0) }
            )
        }
    }

    // MARK: - Anchor → ToolbarItemPlacement mapping

    /// Maps a VideoModeSlotRouter SlotAnchor to a SwiftUI ToolbarItemPlacement.
    /// Copied from NonogramGameView+VideoMode.toolbarPlacement(for:).
    static func toolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading:        return .topBarLeading
        case .topTrailing:       return .topBarTrailing
        case .bottomLeading,
             .bottomTrailing:    return .bottomBar
        case .inCompactRow,
             .hidden:            return .topBarLeading      // defensive
        }
    }
}
