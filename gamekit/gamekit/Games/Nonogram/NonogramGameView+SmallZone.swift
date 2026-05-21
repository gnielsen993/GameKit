//
//  NonogramGameView+SmallZone.swift
//  gamekit
//
//  Phase 12.1 Plan 12.1-06 (round 2) — Small-zone layout for Nonogram.
//
//  Final shape (user feedback 2026-05-14 rounds 1 + 2):
//    - **Top L/R Small zones**: v1.1 existingLayout shape (HeaderBar at top
//      → Board → ModePill at bottom) but everything compact — chips render
//      directly with `compact: true`, ModePill with `compact: true`. Tight
//      VStack spacing.
//    - **Bot L/R Small zones**: compact HeaderBar at top → Board → HStack
//      picker row at the bottom, ModePill (compact) slid to the side
//      OPPOSITE the covered PiP corner per `anchors.picker`. Picker is a
//      SIBLING row below the board (NOT an overlay).
//
//  Anchor mapping (Bot L/R only):
//    `.smallBottomLeft`  → anchors.picker = `.bottomTrailing` → pill on RIGHT
//    `.smallBottomRight` → anchors.picker = `.bottomLeading`  → pill on LEFT
//
//  D-NG-10 LOCKED: `NonogramBoardView.computeLayout` floor seam (12pt when
//  Video Mode is On) untouched. The board sub-view is the same
//  `nonogramBoard` helper consumed by `existingLayout` / `largeZoneLayout`.
//
//  D-11 LOCKED: this file does NOT modify `existingLayout`. The off-path
//  body still resolves to `existingLayout` verbatim.
//

import SwiftUI
import DesignKit

extension NonogramGameView {

    // MARK: - Top L/R Small zones — original shape, compact chrome

    /// Top L/R Small-zone layout. Same shape as v1.1 `existingLayout`
    /// (HeaderBar top → Board → ModePill bottom) but with compact chips.
    /// User feedback 2026-05-14 round 3 — Nonogram top zones: "toggle too
    /// small". ModePill renders FULL-SIZE; VStack spacing widens to `m`.
    @ViewBuilder
    var smallTopZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                smallZoneCompactHeader
                smallZonePuzzleBlock
                smallZoneFullSizePicker
            }

            confettiOverlay

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    // MARK: - Bot L/R Small zones — board top, chrome cluster bottom-opposite-PiP

    /// Bot L/R Small-zone layout (Plan 12.1-06 round 6 — mirrors Mines).
    /// Board fills the upper area. Below the board, a Spacer-centered
    /// chrome cluster (compact chips ABOVE full-size Fill/Mark picker —
    /// the picker is FREQUENTLY tapped during play, so it stays full-size
    /// for tap-target ergonomics) anchors in the bottom corner OPPOSITE
    /// the covered PiP corner.
    @ViewBuilder
    var smallBottomZoneLayout: some View {
        let chromeAtTrailing = (videoModeStore.location == .smallBottomLeft)

        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.s) {
                smallZonePuzzleBlock

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

            confettiOverlay

            if isTerminal && endCardVisible {
                endStateOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    /// Bottom chrome cluster: compact chips ABOVE compact ModePill.
    /// Size chip omitted — it was too wide for the small corner area; the
    /// puzzle grid itself makes the size visible. Only lives (if applicable)
    /// + timer shown.
    @ViewBuilder
    private var bottomChromeCluster: some View {
        VStack(spacing: theme.spacing.m) {
            HStack(spacing: theme.spacing.s) {
                if viewModel.gameMode == .lives {
                    NonogramLivesChip(
                        theme: theme,
                        remaining: viewModel.livesRemaining,
                        compact: true
                    )
                }
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

    // MARK: - Shared sub-views

    /// Puzzle-conditional block — board if a puzzle is loaded, otherwise the
    /// "No puzzles bundled yet" placeholder. Re-uses the existing `nonogramBoard`
    /// helper so the board call site stays byte-identical to `existingLayout` /
    /// `largeZoneLayout` per D-NG-10 / D-NG-17.
    @ViewBuilder
    fileprivate var smallZonePuzzleBlock: some View {
        if viewModel.currentPuzzle != nil {
            nonogramBoard
        } else {
            Spacer()
            Text(String(localized: "No puzzles bundled yet"))
                .font(.callout)
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
        }
    }

    /// Compact header — chips packed to the corner OPPOSITE the PiP.
    /// Size chip omitted here (same reason as bottomChromeCluster): the
    /// 3-chip row was too wide for the small zone and got covered. Only
    /// lives (if applicable) + timer shown.
    @ViewBuilder
    fileprivate var smallZoneCompactHeader: some View {
        let chipsTrailing = (videoModeStore.location == .smallTopLeft
                             || videoModeStore.location == .smallBottomLeft)

        HStack(spacing: theme.spacing.s) {
            if chipsTrailing {
                Spacer()
            }
            if viewModel.gameMode == .lives {
                NonogramLivesChip(
                    theme: theme,
                    remaining: viewModel.livesRemaining,
                    compact: true
                )
            }
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

    /// Compact ModePill — used by Bot L/R Small zones (slid-to-side row).
    @ViewBuilder
    fileprivate var smallZoneCompactPicker: some View {
        NonogramModePill(
            theme: theme,
            mode: viewModel.interactionMode,
            isInteractive: isInteractive,
            onSelect: { viewModel.setInteractionMode($0) },
            compact: true
        )
        .opacity(isInteractive ? 1 : 0)
        .allowsHitTesting(isInteractive)
    }

    /// Full-size ModePill — used by Top L/R Small zones per user feedback
    /// 2026-05-14 round 3 ("toggle too small").
    @ViewBuilder
    fileprivate var smallZoneFullSizePicker: some View {
        NonogramModePill(
            theme: theme,
            mode: viewModel.interactionMode,
            isInteractive: isInteractive,
            onSelect: { viewModel.setInteractionMode($0) }
        )
        .opacity(isInteractive ? 1 : 0)
        .allowsHitTesting(isInteractive)
    }

    // MARK: - Anchor → side mapping (Bot L/R only)

    /// Returns `true` when `anchors.picker` indicates the picker should
    /// render on the LEADING side of the HStack picker row (Bot L/R only).
    ///
    /// Router contract for Bot L/R zones (P10 D-02 — UNCHANGED in 12.1):
    ///   `.smallBottomLeft`  → picker = `.bottomTrailing` → trailing (FALSE)
    ///   `.smallBottomRight` → picker = `.bottomLeading`  → leading  (TRUE)
    static func pickerOnLeading(for anchor: SlotAnchor) -> Bool {
        switch anchor {
        case .bottomLeading, .topLeading:   return true
        case .bottomTrailing, .topTrailing: return false
        case .inCompactRow, .hidden:        return false      // defensive
        }
    }
}
