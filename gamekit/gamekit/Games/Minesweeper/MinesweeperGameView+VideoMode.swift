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

    // MARK: - Plan 11-04 — Large-zone layout (D-01/D-05/D-06/D-08/D-18)

    /// D-01/D-05/D-06/D-08/D-18 — Large-zone branch view tree. HeaderBar +
    /// ModePill are NOT rendered (D-01); they migrate into the compact row.
    /// The compact row sits at the edge OPPOSITE the reserved video band:
    /// `.largeTop` (band reserved at top) → row at bottom; `.largeBottom`
    /// (band reserved at bottom) → row at top. The `.videoModeAware` modifier
    /// already reserves the band via `.safeAreaInset(.top/.bottom)`; this
    /// view places the compact row at the OTHER edge via VStack ordering.
    ///
    /// Animation surfaces (win-sweep wash + confetti + end-state overlay)
    /// are preserved verbatim from `existingLayout` so Phase 5 D-02 / D-03
    /// behavior carries through unchanged.
    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            // Board column — VStack hugs the compact row to one edge and
            // lets the board fill the rest. `.largeTop` (band on top) → row
            // at bottom; `.largeBottom` (band on bottom) → row at top.
            VStack(spacing: theme.spacing.m) {
                if videoModeStore.location == .largeBottom {
                    compactRowComposed
                }

                // Board ZStack with Phase 5 D-03 loss-shake surface preserved
                // verbatim. HeaderBar + ModePill are NOT rendered here per
                // D-01 — the compact row hosts those roles.
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

                if videoModeStore.location == .largeTop {
                    compactRowComposed
                }
            }

            // P5 D-02 win-sweep wash — preserved verbatim from existingLayout.
            // Sits ABOVE the board cells but BELOW the end-state card so the
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

    /// D-05/D-06/D-07/D-08/D-18 — the actual compact-row composition.
    /// Preserves Phase 9 D-12 5-slot contract (`VideoCompactControlRow.swift`
    /// is byte-identical, see plan acceptance criteria); slot 2 hosts a
    /// VStack stack (Mines remaining on top, Time below per D-06); slot 3
    /// hosts MinesweeperModePill (Reveal/Flag, D-05 slot 3); the
    /// `secondaryInfo` closure of the component hosts BOTH slot 4 (Settings
    /// menu via MinesweeperToolbarMenu, D-08) AND slot 5 (Restart button,
    /// rightmost per D-05). The component's `onSettings` closure is unused
    /// — slot 4 lives in secondaryInfo per the ad-hoc Mines slot-5 pattern
    /// described in the plan body.
    @ViewBuilder
    var compactRowComposed: some View {
        VideoCompactControlRow(
            theme: theme,
            onBack: { dismiss() },
            onSettings: { /* unused — slot 4 lives in secondaryInfo per D-05+D-08 ad-hoc */ }
        ) {
            // Slot 2 — stacked chip (D-06). VStack hosts Mines/Time;
            // D-18 .reducedTime drops the TimerChip half.
            VStack(spacing: theme.spacing.xs) {
                MinesRemainingChip(theme: theme, minesRemaining: viewModel.minesRemaining)
                if videoModeCompactness != .reducedTime {
                    TimerChip(
                        theme: theme,
                        timerAnchor: viewModel.timerAnchor,
                        pausedElapsed: viewModel.pausedElapsed
                    )
                }
            }
        } picker: {
            // Slot 3 — Reveal/Flag mode pill (D-05 slot 3; reused verbatim
            // from off-path so the VM closure is identical).
            MinesweeperModePill(
                theme: theme,
                mode: viewModel.interactionMode,
                onSelect: { viewModel.setInteractionMode($0) }
            )
        } secondaryInfo: {
            // Slots 4 + 5 composite per D-05 + D-18.
            // .normal:            Menu (slot 4) + Restart (slot 5) side-by-side.
            // .collapsedSettings: Slot 4 folds into slot 5 — Restart hosts a
            //                     primary-action Menu (tap = restart, menu =
            //                     Change-difficulty list).
            // .reducedTime:       Same as .normal at slots 4/5; the reduction
            //                     happens at slot 2 above.
            HStack(spacing: theme.spacing.s) {
                if videoModeCompactness == .collapsedSettings {
                    restartWithOverflowMenu
                } else {
                    MinesweeperToolbarMenu(
                        theme: theme,
                        currentDifficulty: viewModel.difficulty,
                        onSelect: { viewModel.requestDifficultyChange($0) }
                    )
                    compactRestartButton
                }
            }
        }
    }

    /// D-05 slot 5 — Restart button sized to match the compact row's
    /// backButton / settingsButton chrome (`theme.spacing.xl` square +
    /// `theme.radii.button` corner + `theme.colors.surface` background).
    /// Distinct from the toolbar `restartButton` shape (44×44 chevron
    /// styling) because the compact row uses a tighter visual rhythm.
    @ViewBuilder
    var compactRestartButton: some View {
        Button {
            viewModel.restart()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .accessibilityLabel(Text(String(localized: "Restart game")))
    }

    /// D-18 `.collapsedSettings` — Settings (slot 4) folds into Restart
    /// (slot 5) as a primary-action Menu. Tap = restart (common case);
    /// long-press / chevron tap surfaces Change-difficulty. The menu list
    /// shape (radio-style checkmark on current difficulty) mirrors
    /// `MinesweeperToolbarMenu` so VoiceOver navigation feels identical.
    @ViewBuilder
    var restartWithOverflowMenu: some View {
        Menu {
            Section(String(localized: "Change difficulty")) {
                ForEach(MinesweeperDifficulty.allCases, id: \.self) { difficulty in
                    Button {
                        viewModel.requestDifficultyChange(difficulty)
                    } label: {
                        if difficulty == viewModel.difficulty {
                            Label(difficultyLabel(difficulty), systemImage: "checkmark")
                        } else {
                            Text(difficultyLabel(difficulty))
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        } primaryAction: {
            viewModel.restart()
        }
        .accessibilityLabel(Text(String(localized: "Restart game")))
    }

    /// Difficulty display-name mapping (engine D-03 — view layer owns
    /// localization). Duplicated from `MinesweeperToolbarMenu.displayName`
    /// because that function is `private` to the menu component; the strings
    /// themselves ("Easy"/"Medium"/"Hard") are already in
    /// `Localizable.xcstrings` from Phase 3 onward.
    private func difficultyLabel(_ d: MinesweeperDifficulty) -> String {
        switch d {
        case .easy:   return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard:   return String(localized: "Hard")
        }
    }
}
