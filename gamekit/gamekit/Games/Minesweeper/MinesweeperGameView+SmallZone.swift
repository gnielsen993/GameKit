//
//  MinesweeperGameView+SmallZone.swift
//  gamekit
//
//  Phase 12.1 Plan 12.1-06 (round 2) — Small-zone layout for Minesweeper.
//
//  Final shape (user feedback 2026-05-14 rounds 1 + 2):
//    - **Top L/R Small zones**: v1.x existingLayout shape (HeaderBar at top
//      → Board → ModePill at bottom) but everything compact — chips render
//      directly with `compact: true`, ModePill with `compact: true`. Tight
//      VStack spacing. Stays small enough that the top-PiP overlay doesn't
//      squeeze the board.
//    - **Bot L/R Small zones**: HeaderBar (compact chips) at top → Board →
//      HStack picker row at the bottom, ModePill (compact) slid to the side
//      OPPOSITE the covered PiP corner per `anchors.picker`. Picker is a
//      SIBLING row below the board, NOT an `.overlay(alignment:)` on the
//      board (which placed it ON the board cells — user feedback 2026-05-14).
//
//  Anchor mapping (Bot L/R only — Top L/R centers the pill):
//    `.smallBottomLeft`  → anchors.picker = `.bottomTrailing` → pill on RIGHT
//    `.smallBottomRight` → anchors.picker = `.bottomLeading`  → pill on LEFT
//
//  D-MS-10 LOCKED: `MinesweeperBoardView` constructor call site is byte-
//  identical to `existingLayout` (MinesweeperGameView+VideoMode.swift
//  lines 59–73) and `largeZoneLayout` (lines 276–290). Pinch-zoom +
//  auto-scale + A11Y-05 untouched.
//
//  D-11 LOCKED: this file does NOT modify `existingLayout` or the off-path
//  branch. The off-path body still resolves to `existingLayout` verbatim.
//

import SwiftUI
import DesignKit

extension MinesweeperGameView {

    // MARK: - Top L/R Small zones — original shape, compact chrome (Plan 12.1-06 round 2)

    /// Top L/R Small-zone layout. Same shape as v1.x `existingLayout`
    /// (HeaderBar top → Board → ModePill bottom) but rendered compact:
    /// chips inline with `compact: true`, ModePill with `compact: true`,
    /// tight VStack spacing. Stays small enough that the top-PiP overlay
    /// doesn't squeeze the board's playable area.
    @ViewBuilder
    var smallTopZoneLayout: some View {
        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                smallZoneCompactHeader

                MinesweeperBoardView(
                    theme: theme,
                    board: viewModel.board,
                    gameState: viewModel.gameState,
                    phase: viewModel.phase,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion || !settingsStore.animationsEnabled,
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
                    trigger: (reduceMotion || !settingsStore.animationsEnabled) ? false : viewModel.phase.isLossShake
                ) { content, value in
                    content.offset(x: value)
                } keyframes: { _ in
                    LinearKeyframe(8.0, duration: 0.1)
                    LinearKeyframe(-8.0, duration: 0.1)
                    LinearKeyframe(4.0, duration: 0.1)
                    LinearKeyframe(0.0, duration: 0.1)
                }

                MinesweeperModePill(
                    theme: theme,
                    mode: viewModel.interactionMode,
                    onSelect: { viewModel.setInteractionMode($0) },
                    compact: true
                )
                .opacity(viewModel.terminalOutcome == nil ? 1 : 0)
                .allowsHitTesting(viewModel.terminalOutcome == nil)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0
                )
            }

            smallZoneOverlays
        }
    }

    // MARK: - Bot L/R Small zones — board fills top, chrome cluster bottom-opposite-PiP

    /// Bot L/R Small-zone layout (Plan 12.1-06 round 5, user feedback
    /// 2026-05-14): Board fills the upper area. Below the board, a small
    /// chrome cluster (compact chips ABOVE compact picker) anchors in the
    /// bottom corner OPPOSITE the covered PiP corner. The PiP overlay sits
    /// in the other bottom corner — chrome and overlay coexist on the
    /// bottom band without colliding.
    ///
    ///   `.smallBottomLeft`  (PiP at BL) → chrome cluster at BR (trailing)
    ///   `.smallBottomRight` (PiP at BR) → chrome cluster at BL (leading)
    @ViewBuilder
    var smallBottomZoneLayout: some View {
        let chromeAtTrailing = (videoModeStore.location == .smallBottomLeft)

        ZStack {
            theme.colors.background
                .ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                MinesweeperBoardView(
                    theme: theme,
                    board: viewModel.board,
                    gameState: viewModel.gameState,
                    phase: viewModel.phase,
                    hapticsEnabled: settingsStore.hapticsEnabled,
                    reduceMotion: reduceMotion || !settingsStore.animationsEnabled,
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
                    trigger: (reduceMotion || !settingsStore.animationsEnabled) ? false : viewModel.phase.isLossShake
                ) { content, value in
                    content.offset(x: value)
                } keyframes: { _ in
                    LinearKeyframe(8.0, duration: 0.1)
                    LinearKeyframe(-8.0, duration: 0.1)
                    LinearKeyframe(4.0, duration: 0.1)
                    LinearKeyframe(0.0, duration: 0.1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    if chromeAtTrailing {
                        Spacer(minLength: 0)
                        bottomChromeCluster
                    } else {
                        bottomChromeCluster
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, theme.spacing.m)

                Spacer(minLength: 0)
            }

            smallZoneOverlays
        }
    }

    /// The bottom chrome cluster: compact chips ABOVE compact ModePill,
    /// packed in the bottom corner OPPOSITE the PiP overlay. Internal
    /// VStack spacing widened (`s` → `m`) per user feedback 2026-05-14
    /// round 6 — "create more space between picker and info".
    @ViewBuilder
    private var bottomChromeCluster: some View {
        VStack(spacing: theme.spacing.m) {
            HStack(spacing: theme.spacing.s) {
                MinesRemainingChip(
                    theme: theme,
                    minesRemaining: viewModel.minesRemaining,
                    compact: true
                )
                VideoModeTimerChip(
                    theme: theme,
                    timerAnchor: viewModel.timerAnchor,
                    pausedElapsed: viewModel.pausedElapsed,
                    compact: true
                )
            }
            smallZoneCompactPicker
        }
    }

    // MARK: - Compact chrome sub-views (shared between Top + Bot small zones)

    /// Compact HeaderBar — chips rendered inline with `compact: true` and
    /// PACKED on the side OPPOSITE the covered PiP corner (per user feedback
    /// 2026-05-14 round 3 — "Flag count, covered, should be next to time").
    ///
    /// PiP corner mapping:
    ///   TL / BL → chips trailing (Spacer leads)
    ///   TR / BR → chips leading  (Spacer trails)
    @ViewBuilder
    private var smallZoneCompactHeader: some View {
        let chipsTrailing = (videoModeStore.location == .smallTopLeft
                             || videoModeStore.location == .smallBottomLeft)

        HStack(spacing: theme.spacing.s) {
            if chipsTrailing {
                Spacer()
            }
            MinesRemainingChip(
                theme: theme,
                minesRemaining: viewModel.minesRemaining,
                compact: true
            )
            VideoModeTimerChip(
                theme: theme,
                timerAnchor: viewModel.timerAnchor,
                pausedElapsed: viewModel.pausedElapsed,
                compact: true
            )
            if !chipsTrailing {
                Spacer()
            }
        }
        .padding(.horizontal, theme.spacing.m)
    }

    /// Compact ModePill — same construction as the Top-zone version but
    /// hoisted as a helper so the Bot-zone HStack consumes it cleanly.
    @ViewBuilder
    private var smallZoneCompactPicker: some View {
        MinesweeperModePill(
            theme: theme,
            mode: viewModel.interactionMode,
            onSelect: { viewModel.setInteractionMode($0) },
            compact: true
        )
        .opacity(viewModel.terminalOutcome == nil ? 1 : 0)
        .allowsHitTesting(viewModel.terminalOutcome == nil)
        .sensoryFeedback(
            .impact(weight: .light),
            trigger: settingsStore.hapticsEnabled ? viewModel.modeToggleCount : 0
        )
    }

    // MARK: - Shared overlays (win sweep / confetti / end-state)

    /// Win-sweep wash + confetti + end-state overlay — byte-identical to the
    /// trailing overlay stack in `existingLayout`. Extracted so both
    /// `smallTopZoneLayout` and `smallBottomZoneLayout` share one source.
    @ViewBuilder
    private var smallZoneOverlays: some View {
        Rectangle()
            .fill(theme.colors.success)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .phaseAnimator(
                (reduceMotion || !settingsStore.animationsEnabled) ? [0.0] : [0.0, 0.25, 0.0],
                trigger: viewModel.phase == .winSweep
            ) { content, alpha in
                content.opacity(alpha)
            } animation: { _ in
                .easeInOut(duration: theme.motion.slow)
            }

        if showConfetti {
            ConfettiView(theme: theme)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }

        if let outcome = viewModel.terminalOutcome, endCardVisible {
            endStateOverlay(outcome: outcome)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    // MARK: - Anchor → side mapping (Bot L/R only)

    /// Returns `true` when `anchors.picker` indicates the picker should
    /// render on the LEADING side of the HStack picker row (Bot L/R only).
    ///
    /// Router contract for Bot L/R zones (P10 D-02 — UNCHANGED in 12.1):
    ///   `.smallBottomLeft`  → picker = `.bottomTrailing` → trailing  (FALSE)
    ///   `.smallBottomRight` → picker = `.bottomLeading`  → leading   (TRUE)
    static func pickerOnLeading(for anchor: SlotAnchor) -> Bool {
        switch anchor {
        case .bottomLeading, .topLeading:   return true
        case .bottomTrailing, .topTrailing: return false
        case .inCompactRow, .hidden:        return false      // defensive
        }
    }
}
