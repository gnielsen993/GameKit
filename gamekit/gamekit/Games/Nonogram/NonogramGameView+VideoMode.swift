//
//  NonogramGameView+VideoMode.swift
//  gamekit
//
//  Phase 12 Plan 12-04 — Video Mode layout helpers for NonogramGameView.
//  Split from NonogramGameView.swift to keep that file under CLAUDE.md §8.5
//  ≤500-line hard cap. Mirrors MinesweeperGameView+VideoMode +
//  MergeGameView+VideoMode shape per CONTEXT "Locked Mines pattern" + Plan
//  12-02 polish.
//
//  Owns:
//    - `existingLayout` — v1.1 ZStack body extracted verbatim. Rendered on
//      off-path AND Small-zone path (keeps existing layout + repositioned
//      toolbar). Large-zone path uses `largeZoneLayout` instead.
//    - `existingToolbarContent` — v1.1 nav-bar items (Back · Restart ·
//      NonogramToolbarMenu). Applied off-path.
//    - `smallZoneToolbarContent` — same items, repositioned via
//      VideoModeSlotRouter.
//    - `largeZoneLayout` — Large-zone view tree. HeaderBar + ModePill
//      HIDDEN; their roles migrate into the compact row.
//    - `compactRowComposed` — VideoCompactControlRow per D-NG-01:
//        Back | <Size OR Lives>(compact:true; single-slot swap based on gameMode)
//          | <Spacer> NonogramModePill(compact:true) <Spacer>
//          | (VideoModeTimerChip(compact:true) · restartWithOverflowMenu)
//      `onSettings: nil` (D-NG-01 — no gear; Fill/Mark picker covers
//      settings).
//    - `restartWithOverflowMenu` — Restart button hosts primary-action Menu
//      with TWO sections: Change size (NonogramDifficulty.allCases) +
//      Change mode (NonogramGameMode.allCases — Free / Lives).
//
//  D-NG-17 untouched contract: this file does NOT import the inside of
//  NonogramBoardView and does NOT change its constructor call site. The
//  slide gesture / super-cell rules / hint geometry / fill+X-mark rendering
//  stays byte-identical. Plan 12-05 handles the cell-size floor seam inside
//  BoardView itself.
//

import SwiftUI
import DesignKit

extension NonogramGameView {

    // MARK: - Existing v1.1 layout (off-path + Small-zone)

    /// The current v1.1 Nonogram layout — background + VStack(HeaderBar /
    /// Board / ModePill) + confetti + end-state overlay. Rendered on off-path
    /// AND Small-zone path. Large-zone branch uses `largeZoneLayout` instead.
    @ViewBuilder
    var existingLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                NonogramHeaderBar(
                    theme: theme,
                    sizeLabel: "\(viewModel.difficulty.size) × \(viewModel.difficulty.size)",
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed,
                    livesRemaining: viewModel.gameMode == .lives ? viewModel.livesRemaining : nil
                )

                if viewModel.currentPuzzle != nil {
                    nonogramBoard
                } else {
                    Spacer()
                    Text(String(localized: "No puzzles bundled yet"))
                        .font(.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                NonogramModePill(
                    theme: theme,
                    mode: viewModel.interactionMode,
                    isInteractive: isInteractive,
                    onSelect: { viewModel.setInteractionMode($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(isInteractive ? 1 : 0)
                .allowsHitTesting(isInteractive)
            }
            .padding(.bottom, theme.spacing.l)

            confettiOverlay

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Toolbar items (shared button bodies)

    /// Back chevron — dismiss the NavigationStack push. Body byte-identical
    /// to the v1.1 chevron at the top-leading nav-bar slot.
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

    /// Restart icon — body byte-identical to the v1.1 restart button at the
    /// top-leading nav-bar slot.
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

    /// v1.1 toolbar shape: Back + Restart at top-leading, NonogramToolbarMenu
    /// at top-trailing. Applied on the off-path.
    @ToolbarContentBuilder
    var existingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { backButton }
        ToolbarItem(placement: .topBarLeading) { restartButton }
        ToolbarItem(placement: .topBarTrailing) {
            NonogramToolbarMenu(
                theme: theme,
                currentDifficulty: viewModel.difficulty,
                currentGameMode: viewModel.gameMode,
                onSelectDifficulty: { viewModel.setDifficulty($0) },
                onSelectGameMode: { viewModel.setGameMode($0) }
            )
        }
    }

    /// D-02 Small-zone toolbar: same items, placements derived from
    /// VideoModeSlotRouter.anchors(for: videoModeStore.location).
    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { backButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { restartButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
            NonogramToolbarMenu(
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
    /// Copied verbatim from MinesweeperGameView+VideoMode.toolbarPlacement(for:).
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

    // MARK: - Shared sub-views (consumed by existingLayout + largeZoneLayout)

    /// The board with all 4 sensoryFeedback modifiers preserved verbatim.
    /// Extracted so existingLayout + largeZoneLayout consume the same
    /// construction — D-NG-17 untouched-call-site contract.
    @ViewBuilder
    var nonogramBoard: some View {
        NonogramBoardView(
            board: viewModel.board,
            rowHints: viewModel.rowHints,
            columnHints: viewModel.columnHints,
            rowsCrossOff: viewModel.rowsCrossOff,
            columnsCrossOff: viewModel.columnsCrossOff,
            theme: theme,
            isInteractive: isInteractive,
            interactionMode: viewModel.interactionMode,
            wrongFlashIdx: viewModel.lastWrongAttemptIdx,
            flashRow: viewModel.flashRow,
            flashCol: viewModel.flashCol,
            onTap: { row, col in viewModel.handleTap(at: row, col: col) },
            onLongPress: { row, col in viewModel.handleLongPress(at: row, col: col) },
            onSlide: { row, col, next in viewModel.setCell(at: row, col: col, to: next) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.m)
        .layoutPriority(1)
        .sensoryFeedback(
            .error,
            trigger: settingsStore.hapticsEnabled ? viewModel.wrongAttemptCount : 0
        )
        .sensoryFeedback(
            .impact(weight: .light, intensity: 0.7),
            trigger: settingsStore.hapticsEnabled ? viewModel.placeCount : 0
        )
        .sensoryFeedback(
            .selection,
            trigger: settingsStore.hapticsEnabled ? viewModel.markCount : 0
        )
        .sensoryFeedback(
            .impact(weight: .medium, intensity: 1.0),
            trigger: settingsStore.hapticsEnabled ? viewModel.lineCompletionCount : 0
        )
    }

    /// Confetti overlay — gated on `state == .won && animationsEnabled && !reduceMotion`.
    /// Preserved verbatim from v1.1; consumed by both existingLayout +
    /// largeZoneLayout so the win celebration plays in either path.
    @ViewBuilder
    var confettiOverlay: some View {
        if viewModel.state == .won
           && settingsStore.animationsEnabled
           && !reduceMotion {
            ConfettiView(theme: theme)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - Large-zone layout (D-NG-01)

    /// Large-zone branch view tree. HeaderBar + ModePill are NOT rendered
    /// (their roles migrated into the compact row); NonogramBoardView
    /// rendered between the reserved video band and the compact row. The
    /// compact row sits at the edge OPPOSITE the reserved video band:
    /// `.largeTop` → row at bottom; `.largeBottom` → row at top.
    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                if videoModeStore.location == .largeBottom {
                    compactRowComposed
                }

                if viewModel.currentPuzzle != nil {
                    nonogramBoard
                } else {
                    Spacer()
                    Text(String(localized: "No puzzles bundled yet"))
                        .font(.callout)
                        .foregroundStyle(theme.colors.textSecondary)
                    Spacer()
                }

                if videoModeStore.location == .largeTop {
                    compactRowComposed
                }
            }
            .padding(.bottom, theme.spacing.l)

            confettiOverlay

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Compact-row composition (D-NG-01 slot order)

    /// D-NG-01 single-slot Size↔Lives swap: in Free mode, slot 2 renders
    /// NonogramSizeChip(compact:true); in Lives mode, slot 2 renders
    /// NonogramLivesChip(compact:true). NOT a stacked composite (D-06
    /// stays superseded per CONTEXT line 54-55).
    ///
    /// `onSettings: nil` (D-NG-01) — no gear; Fill/Mark picker covers
    /// settings. Change-difficulty + Change-mode menus fold into the
    /// Restart button's overflow Menu unconditionally per the always-
    /// collapsed pattern from P11-04 round 1 polish.
    @ViewBuilder
    var compactRowComposed: some View {
        VideoCompactControlRow(
            theme: theme,
            onBack: { dismiss() },
            onSettings: nil      // D-NG-01 — Fill/Mark picker covers settings role
        ) {
            // Slot 2 — Size↔Lives single-slot swap per D-NG-01
            if viewModel.gameMode == .lives {
                NonogramLivesChip(
                    theme: theme,
                    remaining: viewModel.livesRemaining,
                    compact: true
                )
            } else {
                NonogramSizeChip(
                    theme: theme,
                    sizeLabel: "\(viewModel.difficulty.size) × \(viewModel.difficulty.size)",
                    compact: true
                )
            }
        } picker: {
            // Slot 3 — Fill/Mark mode pill (center-anchored via Spacer flanking
            // in VideoCompactControlRow)
            NonogramModePill(
                theme: theme,
                mode: viewModel.interactionMode,
                isInteractive: isInteractive,
                onSelect: { viewModel.setInteractionMode($0) },
                compact: true
            )
        } secondaryInfo: {
            // Slot 4+5 composite — VideoModeTimerChip + Restart-with-overflow-Menu.
            // TimerChip half gated on videoModeCompactness != .reducedTime
            // (mirror P11-04 D-18 reaction).
            HStack(spacing: theme.spacing.s) {
                if videoModeCompactness != .reducedTime {
                    VideoModeTimerChip(
                        theme: theme,
                        timerAnchor: viewModel.timerAnchor,
                        pausedElapsed: viewModel.pausedElapsed,
                        compact: true
                    )
                }
                restartWithOverflowMenu
            }
        }
    }

    /// Restart button with primary-action Menu folding both Change-size
    /// (NonogramDifficulty.allCases) AND Change-mode (NonogramGameMode.allCases)
    /// per D-NG-01. Tap = restart; long-press / chevron = surface both menus.
    @ViewBuilder
    var restartWithOverflowMenu: some View {
        Menu {
            Section(String(localized: "Change size")) {
                ForEach(NonogramDifficulty.allCases, id: \.self) { d in
                    Button {
                        viewModel.setDifficulty(d)
                    } label: {
                        if d == viewModel.difficulty {
                            Label(difficultyLabel(d), systemImage: "checkmark")
                        } else {
                            Text(difficultyLabel(d))
                        }
                    }
                }
            }
            Section(String(localized: "Change mode")) {
                ForEach(NonogramGameMode.allCases, id: \.self) { m in
                    Button {
                        viewModel.setGameMode(m)
                    } label: {
                        if m == viewModel.gameMode {
                            Label(gameModeLabel(m), systemImage: "checkmark")
                        } else {
                            Text(gameModeLabel(m))
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

    /// Difficulty display name. Strings already in `Resources/Localizable.xcstrings`
    /// (consumed by NonogramGameView.difficultyDisplayName + NonogramToolbarMenu);
    /// duplicated here because those helpers are `private` to their host.
    private func difficultyLabel(_ d: NonogramDifficulty) -> String {
        switch d {
        case .tiny:   return String(localized: "Tiny  -  5 × 5")
        case .small:  return String(localized: "Small  -  10 × 10")
        case .medium: return String(localized: "Medium  -  15 × 15")
        case .large:  return String(localized: "Large  -  20 × 20")
        }
    }

    /// Game-mode display name. Matches the strings NonogramToolbarMenu uses
    /// (`"Free"` + `"Lives  -  3 strikes"` already in xcstrings) — no new
    /// localization keys introduced by this plan.
    private func gameModeLabel(_ m: NonogramGameMode) -> String {
        switch m {
        case .free:   return String(localized: "Free")
        case .lives:  return String(localized: "Lives  -  3 strikes")
        }
    }
}
