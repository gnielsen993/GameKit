//
//  MergeGameView+VideoMode.swift
//  gamekit
//
//  Phase 12 Plan 12-02 — Video Mode layout helpers for MergeGameView.
//  Split from MergeGameView.swift to keep that file under CLAUDE.md §8.5
//  ≤500-line hard cap. Mirrors MinesweeperGameView+VideoMode.swift shape
//  per CONTEXT "Locked Mines pattern" lines 22-36.
//
//  Owns:
//    - `existingLayout` — v1.1 ZStack body extracted verbatim. Rendered on
//      off-path AND Small-zone path (D-02 keeps existing layout + repositioned
//      toolbar). Large-zone path uses `largeZoneLayout` instead.
//    - `existingToolbarContent` — v1.1 nav-bar items (Back · Restart ·
//      MergeToolbarMenu). Applied off-path.
//    - `smallZoneToolbarContent` — same items, repositioned via
//      VideoModeSlotRouter.anchors(for: location).
//    - `largeZoneLayout` — Large-zone view tree. HeaderBar + ModePill HIDDEN
//      (their roles migrate into the compact row). Compact row at the edge
//      opposite the reserved video band.
//    - `compactRowComposed` — VideoCompactControlRow per D-MG-01:
//        Back | MergeScoreChip(compact:true) | <Spacer> MergeModePill(compact:true) <Spacer>
//          | (MergeBestChip(compact:true) · restartWithOverflowMenu)
//      `onSettings: nil` (D-MG-01 — no gear; Mode picker covers settings).
//    - `restartWithOverflowMenu` — Restart button hosts a primary-action Menu
//      with Change-mode list folded in (always-collapsed pattern per P11-04
//      round 1 polish; not gated on .collapsedSettings).
//
//  D-MG-17 untouched contract: this file does NOT import the inside of
//  MergeBoardView and does NOT change its constructor call site. The
//  swipe-driven merge gesture composition stays byte-identical.
//

import SwiftUI
import DesignKit

extension MergeGameView {

    // MARK: - Existing v1.1 layout (off-path + Small-zone)

    /// The current v1.1 Merge layout — background + VStack(HeaderBar / Board /
    /// ModePill) + end-state overlay. Rendered on off-path AND Small-zone path.
    /// Large-zone branch uses `largeZoneLayout` instead.
    @ViewBuilder
    var existingLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                MergeHeaderBar(
                    theme: theme,
                    score: viewModel.score,
                    bestScore: viewModel.bestScore,
                    mode: viewModel.mode
                )

                MergeBoardView(
                    theme: theme,
                    board: viewModel.board,
                    onSwipe: { viewModel.handleSwipe($0) }
                )
                .padding(.horizontal, theme.spacing.l)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: settingsStore.hapticsEnabled ? viewModel.mergeCount : 0
                )
                .sensoryFeedback(
                    .success,
                    trigger: settingsStore.hapticsEnabled ? viewModel.terminalCount : 0
                )

                MergeModePill(
                    theme: theme,
                    mode: viewModel.mode,
                    onSelect: { viewModel.requestModeChange($0) }
                )
                .padding(.top, theme.spacing.s)
                .opacity(isTerminal ? 0 : 1)
                .allowsHitTesting(!isTerminal)
            }

            if let endState = endStateForOverlay {
                endStateOverlay(state: endState)
            }
        }
    }

    // MARK: - Small-zone layout (Phase 12.1 / Plan 12.1-03)

    /// Phase 12.1 (Plan 12.1-03) — Small-zone branch consuming
    /// `anchors.headerBar` + `anchors.picker` per CONTEXT D-04 / D-05 / D-07 /
    /// D-08 / D-09. VStack ordering of HeaderBar / Board / ModePill flips on
    /// `headerBarAtBottom`. The three sub-view properties below are the single
    /// source-of-truth shared between both orderings — `MergeBoardView` call
    /// site stays byte-identical to `existingLayout` per D-MG-10
    /// (SHA `4aec14161b00ac2dbd1ea00e3bebb696bea6fc26` unchanged).
    ///
    /// - Top L/R (headerBar=bottom*, picker=bottom*): Board → HeaderBar →
    ///   ModePill. Top edge clear for top-PiP (D-07).
    /// - Bot L/R (headerBar=top*, picker=bottom*): HeaderBar → ModePill →
    ///   Board. Bottom edge clear for bottom-PiP (D-08 / D-09).
    ///
    /// `anchors.picker` is consumed via `headerBarAtBottom` — the boolean
    /// unifies the 4 small zones into 2 orderings; the cross-product is
    /// already encoded in the router's D-08 + D-09 anchor values.
    @ViewBuilder
    var smallZoneLayout: some View {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        let headerBarAtBottom = (anchors.headerBar == .bottomLeading
                                 || anchors.headerBar == .bottomTrailing)
        let _ = anchors.picker  // D-05: consumed indirectly via headerBarAtBottom unification

        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                if headerBarAtBottom {
                    // Top L/R: board first, HeaderBar + ModePill pushed down.
                    smallZoneBoard
                    smallZoneHeaderBar
                    smallZoneModePill
                } else {
                    // Bot L/R: HeaderBar + ModePill at top, board below.
                    smallZoneHeaderBar
                    smallZoneModePill
                    smallZoneBoard
                }
            }

            if let endState = endStateForOverlay {
                endStateOverlay(state: endState)
            }
        }
    }

    /// D-MG-10 byte-identical board: shared by `smallZoneLayout` orderings.
    @ViewBuilder
    private var smallZoneBoard: some View {
        MergeBoardView(
            theme: theme,
            board: viewModel.board,
            onSwipe: { viewModel.handleSwipe($0) }
        )
        .padding(.horizontal, theme.spacing.l)
        .sensoryFeedback(
            .impact(weight: .light),
            trigger: settingsStore.hapticsEnabled ? viewModel.mergeCount : 0
        )
        .sensoryFeedback(
            .success,
            trigger: settingsStore.hapticsEnabled ? viewModel.terminalCount : 0
        )
    }

    /// HeaderBar byte-identical to `existingLayout`.
    @ViewBuilder
    private var smallZoneHeaderBar: some View {
        MergeHeaderBar(
            theme: theme,
            score: viewModel.score,
            bestScore: viewModel.bestScore,
            mode: viewModel.mode
        )
    }

    /// ModePill + modifier chain byte-identical to `existingLayout`.
    @ViewBuilder
    private var smallZoneModePill: some View {
        MergeModePill(
            theme: theme,
            mode: viewModel.mode,
            onSelect: { viewModel.requestModeChange($0) }
        )
        .padding(.top, theme.spacing.s)
        .opacity(isTerminal ? 0 : 1)
        .allowsHitTesting(!isTerminal)
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

    /// v1.1 toolbar shape: Back + Restart at top-leading, MergeToolbarMenu
    /// at top-trailing. Applied on the off-path.
    @ToolbarContentBuilder
    var existingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { backButton }
        ToolbarItem(placement: .topBarLeading) { restartButton }
        ToolbarItem(placement: .topBarTrailing) {
            MergeToolbarMenu(
                theme: theme,
                currentMode: viewModel.mode,
                onSelect: { viewModel.requestModeChange($0) }
            )
        }
    }

    /// D-02 Small-zone toolbar: same items, placements derived from
    /// VideoModeSlotRouter.anchors(for: videoModeStore.location). Mirrors
    /// MinesweeperGameView+VideoMode.smallZoneToolbarContent verbatim.
    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { backButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) { restartButton }
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.settings)) {
            MergeToolbarMenu(
                theme: theme,
                currentMode: viewModel.mode,
                onSelect: { viewModel.requestModeChange($0) }
            )
        }
    }

    // MARK: - Anchor → ToolbarItemPlacement mapping

    /// Maps a VideoModeSlotRouter SlotAnchor to a SwiftUI ToolbarItemPlacement.
    /// Only `.topLeading` / `.topTrailing` anchors reach Small-zone toolbar
    /// call sites today (per P10 D-02). Remaining cases are mapped defensively.
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

    // MARK: - Large-zone layout (D-MG-01 / D-MG-17)

    /// Large-zone branch view tree. HeaderBar + ModePill are NOT rendered
    /// (their roles migrated into the compact row); MergeBoardView rendered
    /// between the reserved video band and the compact row. The compact row
    /// sits at the edge OPPOSITE the reserved video band: `.largeTop` →
    /// row at bottom; `.largeBottom` → row at top.
    ///
    /// D-MG-17: MergeBoardView constructor call site is byte-identical to
    /// `existingLayout` — same props, same closures, same sensoryFeedback
    /// modifiers. The swipe-driven merge gesture stays untouched.
    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.m) {
                if videoModeStore.location == .largeBottom {
                    compactRowComposed
                }

                MergeBoardView(
                    theme: theme,
                    board: viewModel.board,
                    onSwipe: { viewModel.handleSwipe($0) }
                )
                .padding(.horizontal, theme.spacing.l)
                .sensoryFeedback(
                    .impact(weight: .light),
                    trigger: settingsStore.hapticsEnabled ? viewModel.mergeCount : 0
                )
                .sensoryFeedback(
                    .success,
                    trigger: settingsStore.hapticsEnabled ? viewModel.terminalCount : 0
                )

                if videoModeStore.location == .largeTop {
                    compactRowComposed
                }
            }

            if let endState = endStateForOverlay {
                endStateOverlay(state: endState)
            }
        }
    }

    // MARK: - Compact-row composition (D-MG-01 slot order)

    /// D-MG-01 verbatim Mines pattern: symmetric chip-left/picker-center/chip-right
    /// layout with `onSettings: nil` (no gear; Mode picker covers settings)
    /// and the Mode-change menu folded into the Restart button's overflow Menu
    /// unconditionally (always-collapsed pattern per P11-04 round 1 polish —
    /// not gated on videoModeCompactness == .collapsedSettings since that
    /// threshold didn't fire reliably).
    ///
    /// Merge has no live timer (D-MG-01 explicit) — slot 4 hosts the persisted
    /// Best score, slot 5 hosts Restart-w/menu.
    @ViewBuilder
    var compactRowComposed: some View {
        VideoCompactControlRow(
            theme: theme,
            onBack: { dismiss() },
            onSettings: nil      // D-MG-01 — Mode picker covers settings role
        ) {
            // Slot 2 — Score chip (single, not stacked; mirrors Mines P11-04 round 2)
            MergeScoreChip(
                theme: theme,
                score: viewModel.score,
                compact: true
            )
        } picker: {
            // Slot 3 — Mode pill (center-anchored via Spacer flanking in VideoCompactControlRow)
            MergeModePill(
                theme: theme,
                mode: viewModel.mode,
                onSelect: { viewModel.requestModeChange($0) },
                compact: true
            )
        } secondaryInfo: {
            // Slot 4+5 composite — Best chip + Restart-with-overflow-menu.
            // Best is the right-side chip (stable persisted value); Restart
            // hosts the always-collapsed Change-mode menu.
            HStack(spacing: theme.spacing.s) {
                MergeBestChip(
                    theme: theme,
                    bestScore: viewModel.bestScore,
                    compact: true
                )
                restartWithOverflowMenu
            }
        }
    }

    /// Restart button with primary-action Menu folding Change-mode in
    /// (mirrors Mines's restartWithOverflowMenu shape from P11-04 polish).
    /// Tap = restart (common case); long-press / chevron = surface Change-mode.
    @ViewBuilder
    var restartWithOverflowMenu: some View {
        Menu {
            Section(String(localized: "Change mode")) {
                ForEach(MergeMode.allCases, id: \.self) { m in
                    Button {
                        viewModel.requestModeChange(m)
                    } label: {
                        if m == viewModel.mode {
                            Label(modeLabel(m), systemImage: "checkmark")
                        } else {
                            Text(modeLabel(m))
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

    /// Mode display name (view-layer localization mirror of MergeToolbarMenu's
    /// private displayName helper — duplicated because that helper is `private`).
    private func modeLabel(_ m: MergeMode) -> String {
        switch m {
        case .winMode:  return String(localized: "Win")
        case .infinite: return String(localized: "Infinite")
        }
    }
}
