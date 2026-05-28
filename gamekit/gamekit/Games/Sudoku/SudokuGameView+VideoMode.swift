//
//  SudokuGameView+VideoMode.swift
//  gamekit
//
//  Video Mode layout helpers for SudokuGameView. Split from the main file to
//  keep both files under the CLAUDE.md §8.5 ≤500-line hard cap.
//
//  Layout branches:
//
//  Large zones (.largeTop / .largeBottom):
//    Navbar hidden. A compact control row (back · mode-pill · erase · restart ·
//    settings-menu) replaces the navbar. Lives (if lives mode) overlays the
//    board's top-leading corner; timer overlays the top-trailing corner.
//    For .largeBottom the control row sits at the TOP; for .largeTop at the BOTTOM.
//
//  Small zones — top corner (.smallTopLeft / .smallTopRight):
//    Navbar repositioned via smallZoneToolbarContent.
//    A compact info header (timer + lives) is packed to the corner OPPOSITE
//    the PiP so nothing is covered. Board below, mode+erase+numpad at bottom.
//
//  Small zones — bottom corner (.smallBottomLeft / .smallBottomRight):
//    Navbar stays at standard positions (back/restart leading, settings
//    trailing — same as off-path, since the PiP does not cover the top bar).
//    Board fills the top area; compact info chips appear BELOW the board,
//    packed to the corner OPPOSITE the PiP. Mode pill + numpad follow.
//    xxl bottom padding lifts the numpad above the PiP footprint.
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
        } else if videoModeStore.location.isTopSmall {
            topSmallZoneLayout
                .toolbar { smallZoneToolbarContent }
        } else {
            bottomSmallZoneLayout
                .toolbar { smallZoneToolbarContent }
        }
    }

    // MARK: - Large-zone layout

    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if videoModeStore.location == .largeTop {
                // PiP at top → board + numpad first, control row at bottom
                VStack(spacing: theme.spacing.s) {
                    if viewModel.board != nil {
                        largeZoneBoardBlock
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
                    largeZoneControlRow
                }
                .padding(.bottom, theme.spacing.l)
            } else {
                // .largeBottom — PiP at bottom → control row at top
                VStack(spacing: theme.spacing.s) {
                    largeZoneControlRow
                    if viewModel.board != nil {
                        largeZoneBoardBlock
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
            }

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    /// Board + corner info overlays for large-zone Video Mode.
    /// Lives (compact) anchors to the board's top-leading corner;
    /// timer (compact) anchors to the top-trailing corner. Both chips
    /// sit inside the board's horizontal padding so they're visually
    /// inside the grid confines. Non-interactive overlays — taps pass
    /// through to the underlying board.
    @ViewBuilder
    var largeZoneBoardBlock: some View {
        VStack(spacing: theme.spacing.xs) {
            // Timer + lives sit ABOVE the board so they never cover cell notes.
            HStack(spacing: theme.spacing.s) {
                if viewModel.gameMode == .lives {
                    SudokuLivesChip(theme: theme, mistakes: viewModel.mistakes, compact: true)
                        .allowsHitTesting(false)
                }
                Spacer()
                VideoModeTimerChip(
                    theme: theme,
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed,
                    compact: true
                )
                .allowsHitTesting(false)
            }
            .padding(.horizontal, theme.spacing.m)

            sudokuBoard
        }
    }

    /// Compact control row replacing the navbar in large-zone Video Mode.
    /// Lives and timer have moved to board corner overlays (largeZoneBoardBlock)
    /// so this row stays narrow: Back · Mode pill · Erase · Restart · Settings.
    @ViewBuilder
    var largeZoneControlRow: some View {
        HStack(spacing: theme.spacing.s) {
            // Back
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
            .accessibilityLabel(Text("Back"))

            Spacer(minLength: 0).frame(maxWidth: theme.spacing.xs)

            // Mode pill (compact) — centered between back and erase
            SudokuModePill(
                theme: theme,
                mode: viewModel.interactionMode,
                isInteractive: isInteractive,
                onSelect: { viewModel.setInteractionMode($0) },
                compact: true
            )

            // Erase
            Button { viewModel.erase() } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
            .disabled(!isInteractive)
            .opacity(isInteractive ? 1 : 0.4)
            .accessibilityLabel(Text("Erase"))

            Spacer(minLength: 0).frame(maxWidth: theme.spacing.xs)

            // Restart / Next Puzzle — adapts when puzzle is won
            let isWon = viewModel.state == .won
            Button { if isWon { viewModel.newPuzzle() } else { viewModel.restart() } } label: {
                Image(systemName: isWon ? "chevron.forward" : "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button,
                                               style: .continuous))
            }
            .accessibilityLabel(isWon ? Text("Next puzzle") : Text("Restart puzzle"))

            // Difficulty + game-mode settings (compact)
            SudokuToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                currentGameMode: viewModel.gameMode,
                onSelectDifficulty: { viewModel.setDifficulty($0) },
                onSelectGameMode: { viewModel.setGameMode($0) },
                compact: true
            )
        }
        .padding(.horizontal, theme.spacing.m)
        .frame(height: theme.spacing.xl)
    }

    // MARK: - Small zone shared helpers

    /// Compact info header used by both top- and bottom-small zone layouts.
    /// Timer + lives chips are packed to the corner OPPOSITE the PiP so the
    /// overlay never covers them. `chipsTrailing` = true when the PiP is on
    /// the LEFT side (chips pushed to the right).
    @ViewBuilder
    func smallZoneInfoHeader(chipsTrailing: Bool) -> some View {
        HStack(spacing: theme.spacing.s) {
            if chipsTrailing { Spacer(minLength: 0) }
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed,
                compact: true
            )
            if viewModel.gameMode == .lives {
                SudokuLivesChip(theme: theme, mistakes: viewModel.mistakes, compact: true)
            }
            if !chipsTrailing { Spacer(minLength: 0) }
        }
        .padding(.horizontal, theme.spacing.m)
    }

    /// Mode pill centered + erase button floating trailing. Used by both
    /// top- and bottom-small zone layouts.
    @ViewBuilder
    var smallZoneModePillRow: some View {
        ZStack(alignment: .center) {
            SudokuModePill(
                theme: theme,
                mode: viewModel.interactionMode,
                isInteractive: isInteractive,
                onSelect: { viewModel.setInteractionMode($0) }
            )
            HStack {
                Spacer()
                eraseButton
            }
            .padding(.horizontal, theme.spacing.m)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top-small-zone layout

    /// PiP in a top corner. Compact info header packed to the OPPOSITE corner
    /// so the overlay never covers the timer or lives. Board below, numpad
    /// at the bottom with standard padding.
    @ViewBuilder
    var topSmallZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                // .smallTopLeft → PiP left → chips right (trailing)
                // .smallTopRight → PiP right → chips left (leading)
                smallZoneInfoHeader(chipsTrailing: videoModeStore.location == .smallTopLeft)

                if viewModel.board != nil {
                    sudokuBoard
                } else {
                    Spacer()
                    Text(String(localized: "Loading puzzle…"))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                smallZoneModePillRow

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

    // MARK: - Bottom-small-zone layout

    /// PiP in a bottom corner. Board fills the top area (no info header above
    /// it — mirrors the Minesweeper/Nonogram bot-small pattern). Compact info
    /// chips appear BELOW the board, packed to the corner OPPOSITE the PiP.
    /// Mode pill + numpad follow, with enough bottom padding to lift the numpad
    /// above the PiP footprint (~192pt) so it remains fully tappable.
    private static let smallPipFootprint: CGFloat = 200

    @ViewBuilder
    var bottomSmallZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                if viewModel.board != nil {
                    sudokuBoard
                } else {
                    Spacer()
                    Text(String(localized: "Loading puzzle…"))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                // Timer + lives packed to the corner OPPOSITE the PiP.
                // .smallBottomLeft → PiP left → chips right (trailing)
                // .smallBottomRight → PiP right → chips left (leading)
                smallZoneInfoHeader(chipsTrailing: videoModeStore.location == .smallBottomLeft)

                smallZoneModePillRow

                SudokuNumberPad(viewModel: viewModel, theme: theme)
                    .opacity(isInteractive ? 1 : 0.4)
                    .allowsHitTesting(isInteractive)
            }
            // Lifts the numpad above the bottom-corner PiP (~192pt tall).
            .padding(.bottom, Self.smallPipFootprint)

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

    static func toolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading:        return .topBarLeading
        case .topTrailing:       return .topBarTrailing
        case .bottomLeading,
             .bottomTrailing:    return .bottomBar
        case .inCompactRow,
             .hidden:            return .topBarLeading
        }
    }
}
