//
//  MinesweeperGameView+VideoMode.swift
//  gamekit
//
//  Phase 11 Plan 11-03 — Video Mode layout helpers for MinesweeperGameView.
//
//  Split from MinesweeperGameView.swift to keep that file under the CLAUDE.md
//  §8.5 ≤500-line hard cap. Owns the three pieces of Video-Mode-aware chrome:
//    - `existingLayout` — the v1.0 ZStack body extracted verbatim. Rendered
//      on the off-path (videoModeStore.isEnabled == false) AND on the
//      Small-zone path (D-02 keeps existing layout + repositioned toolbar).
//      Also rendered (with toolbar hidden) on the Large-zone STUB path that
//      Plan 11-04 will fill in with the actual VideoCompactControlRow
//      composition.
//    - `existingToolbarContent` — the v1.0 nav-bar items (Back · Restart ·
//      MinesweeperToolbarMenu). Applied on the off-path. Hidden on the
//      Large-zone path per D-09. Re-anchored on the Small-zone path via
//      `smallZoneToolbarContent`.
//    - `smallZoneToolbarContent` — same items, but with placements driven by
//      VideoModeSlotRouter.anchors(for: location). The router returns a
//      SlotAnchor enum value (`.topLeading` / `.topTrailing` /
//      `.bottomLeading` / `.bottomTrailing` / `.inCompactRow` / `.hidden`);
//      we map those to ToolbarItemPlacement. Bottom anchors fall back to
//      `.bottomBar` so the existing items survive a future Small-zone
//      override; `.inCompactRow` / `.hidden` are not reachable on Small zones
//      per VideoModeSlotRouter's switch (P10 D-02) but we map them defensively.
//
//  D-17 untouched contract: this file does NOT import the inside of
//  MinesweeperBoardView and does NOT change its constructor call site.
//  The MagnifyGesture / .scaleEffect / clampZoomScale / cell-level
//  LongPressGesture composition stays byte-identical in BoardView.
//

import SwiftUI
import DesignKit

extension MinesweeperGameView {

    // MARK: - Existing v1.0 layout (off-path + Small-zone + Large-zone stub)

    /// The current v1.0 board layout — HeaderBar + Board + ModePill VStack
    /// plus the win-sweep / confetti / end-state ZStack overlays. Rendered
    /// verbatim on all three branches; the Large-zone branch additionally
    /// hides the toolbar via `.toolbar(.hidden, for: .navigationBar)` per D-09.
    @ViewBuilder
    var existingLayout: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                MinesweeperHeaderBar(
                    theme: theme,
                    minesRemaining: viewModel.minesRemaining,
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed
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
                // P5 D-03: 4-keyframe horizontal loss shake. Magnitude 8pt
                // locked by CONTEXT D-03 (animation amplitude, not layout
                // — exempt from FOUND-07 spacing-token rule). Reduce Motion
                // → trigger `false` so keyframes never fire.
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

                // P6.1 (MINES-12) — Reveal/Flag pill flipper.
                // Two-segment pill, current mode highlighted. Replaces prior
                // single circular FAB.
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

            // P5 D-02: full-board win sweep — success-tint wash via
            // .phaseAnimator. Sits ABOVE the board cells but BELOW the
            // end-state DKCard so the user can interact with Restart
            // without the wash blocking taps (.allowsHitTesting(false)
            // also enforces this). Reduce Motion → single phase [0.0]
            // emits no fade.
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
            // Always rendered above the win-sweep wash and below the end card.
            // Driven by `showConfetti` which the win-orchestration Task flips.
            if showConfetti {
                ConfettiView(theme: theme)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // End-state overlay — gated on `endCardVisible` so the loss
            // cascade / win confetti finish their pre-roll first.
            if let outcome = viewModel.terminalOutcome, endCardVisible {
                endStateOverlay(outcome: outcome)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Toolbar items (shared button bodies)

    /// Back chevron — dismiss the NavigationStack push. Body byte-identical
    /// to the v1.0 chevron at the top-leading nav-bar slot.
    @ViewBuilder
    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back to The Drawer"))
    }

    /// Restart icon — re-deal the current difficulty. Body byte-identical to
    /// the v1.0 restart button at the top-leading nav-bar slot.
    @ViewBuilder
    var restartButton: some View {
        Button {
            viewModel.restart()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Restart game"))
    }

    // MARK: - Toolbar contents (off-path + Small-zone)

    /// v1.0 toolbar shape: Back + Restart at top-leading, MinesweeperToolbarMenu
    /// at top-trailing. Applied on the off-path.
    @ToolbarContentBuilder
    var existingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            backButton
        }
        ToolbarItem(placement: .topBarLeading) {
            restartButton
        }
        ToolbarItem(placement: .topBarTrailing) {
            MinesweeperToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                onSelect: { viewModel.requestDifficultyChange($0) }
            )
        }
    }

    /// D-02 Small-zone toolbar: same items, but placements derived from
    /// VideoModeSlotRouter.anchors(for: videoModeStore.location). Back and
    /// Restart follow `anchors.back`; the difficulty menu follows
    /// `anchors.settings`. The router constrains Small-zone anchors to
    /// `.topLeading` / `.topTrailing` (per P10 D-02) — `.bottomLeading` /
    /// `.bottomTrailing` map defensively to `.bottomBar` for future
    /// Small-zone refinements; `.inCompactRow` / `.hidden` are unreachable
    /// on Small zones but mapped defensively to `.topBarLeading`.
    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) {
            backButton
        }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) {
            restartButton
        }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
            MinesweeperToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                onSelect: { viewModel.requestDifficultyChange($0) }
            )
        }
    }

    // MARK: - Anchor → ToolbarItemPlacement mapping

    /// Maps a `VideoModeSlotRouter` SlotAnchor to a SwiftUI
    /// ToolbarItemPlacement. Only `.topLeading` / `.topTrailing` anchors
    /// reach Small-zone toolbar call sites today (per P10 D-02); the
    /// remaining cases are mapped defensively so a future router
    /// refinement does not silently route items into the wrong slot.
    static func toolbarPlacement(for anchor: SlotAnchor) -> ToolbarItemPlacement {
        switch anchor {
        case .topLeading:        return .topBarLeading
        case .topTrailing:       return .topBarTrailing
        case .bottomLeading,
             .bottomTrailing:    return .bottomBar
        case .inCompactRow,
             .hidden:            return .topBarLeading      // defensive — unreachable on Small zones
        }
    }
}
