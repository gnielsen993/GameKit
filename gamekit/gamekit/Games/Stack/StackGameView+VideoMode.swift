//
//  StackGameView+VideoMode.swift
//  gamekit
//
//  Video Mode branch layouts for StackGameView (ARCADE-08 amendment
//  2026-07-02 — Stack's exemption lifted; see 15-VIDEO-MODE-ADR.md).
//  Mirrors MergeGameView+VideoMode.swift, the closest analog: score-based
//  game, no mid-game mode picker.
//
//  Owns:
//    - `videoModeLayout` — zone dispatch (Large vs Small).
//    - `largeZoneLayout` — nav bar hidden (DESIGN §7.1); compact row at the
//      edge OPPOSITE the reserved video band; score/streak migrate from the
//      floating overlay into the row (`coreStack(scoreAlignment: nil)`).
//    - `compactRowComposed` — Back | StackScoreChip | (empty picker) |
//      StackStreakChip (streak > 0 only). NO restart button — Stack has no
//      mid-run restart affordance by design (a restart mid-run forfeits the
//      run); the game-over banner carries Restart. `onSettings: nil` —
//      Stack has no in-game settings.
//    - `smallZoneLayout` — existing layout; back chevron repositioned via
//      VideoModeSlotRouter `anchors.back`, score/streak overlay packs to
//      the `anchors.headerBar` corner (opposite the PiP, DESIGN §7.2).
//
//  Reflow safety: StackEngine is pure normalized-coordinate (playfield
//  width = 1.0) and StackBoardCanvas derives all geometry from its size
//  every frame — a mid-run band reflow rescales the render and cannot
//  desync engine state. This is why the ARCADE-08 rationale (pixel-derived
//  state) never applied to Stack; it still applies to Snake.
//

import SwiftUI
import DesignKit

extension StackGameView {

    // MARK: - Zone dispatch

    @ViewBuilder
    var videoModeLayout: some View {
        switch videoModeStore.location {
        case .largeTop, .largeBottom:
            largeZoneLayout
        case .smallTopLeft, .smallTopRight, .smallBottomLeft, .smallBottomRight:
            smallZoneLayout
        }
    }

    // MARK: - Large zones (DESIGN §7.1)

    /// Nav bar hidden; compact row at the edge opposite the reserved band
    /// (`.largeTop` band → row at bottom; `.largeBottom` band → row at top).
    /// The backdrop paints the full screen behind row + board and joins the
    /// game-over grayscale drain, matching the off-path treatment. The
    /// compact row stays un-grayscaled — it is chrome, like the banner.
    @ViewBuilder
    var largeZoneLayout: some View {
        ZStack {
            backdrop
                .grayscale(vm.state == .gameOver ? 1.0 : 0.0)
                .animation(fxEnabled ? .easeOut(duration: 0.5) : nil,
                           value: vm.state == .gameOver)

            VStack(spacing: theme.spacing.m) {
                if videoModeStore.location == .largeBottom {
                    compactRowComposed
                }

                coreStack(scoreAlignment: nil, includeBackdrop: false)

                if videoModeStore.location == .largeTop {
                    compactRowComposed
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// §3.5 slot order: Back | primary info | picker | secondary info.
    /// Score is the load-bearing chip (primary); streak renders on the
    /// secondary side only while > 0, matching the off-path overlay's
    /// conditional streak line. Empty picker slot per §3.5 — mode-switching
    /// mid-run is semantically wrong for Stack (there are no modes).
    @ViewBuilder
    var compactRowComposed: some View {
        VideoCompactControlRow(
            theme: theme,
            onBack: { dismiss() },
            onSettings: nil      // no in-game settings; no picker to demote
        ) {
            StackScoreChip(theme: theme, score: vm.frame.score, compact: true)
        } picker: {
            EmptyView()
        } secondaryInfo: {
            if vm.frame.streak > 0 {
                StackStreakChip(theme: theme, streak: vm.frame.streak, compact: true)
            }
        }
    }

    // MARK: - Small zones (DESIGN §7.2)

    /// Existing layout, chrome repositioned: back chevron follows
    /// `anchors.back`; the score/streak overlay (Stack's headerBar
    /// equivalent) packs to the `anchors.headerBar` corner — always
    /// opposite the covered PiP corner.
    @ViewBuilder
    var smallZoneLayout: some View {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        coreStack(scoreAlignment: Self.overlayAlignment(for: anchors.headerBar))
            .navigationTitle(String(localized: "Stack"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { smallZoneToolbarContent }
    }

    @ToolbarContentBuilder
    var smallZoneToolbarContent: some ToolbarContent {
        let anchors = VideoModeSlotRouter.anchors(for: videoModeStore.location)
        ToolbarItem(placement: Self.toolbarPlacement(for: anchors.back)) {
            backButton
        }
    }

    // MARK: - Anchor mapping

    /// Maps a VideoModeSlotRouter SlotAnchor to a ToolbarItemPlacement.
    /// Copied verbatim from MergeGameView+VideoMode.toolbarPlacement(for:) —
    /// only `.topLeading` / `.topTrailing` are reachable on Small zones.
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

    /// Maps a SlotAnchor to the score-overlay frame alignment.
    static func overlayAlignment(for anchor: SlotAnchor) -> Alignment {
        switch anchor {
        case .topLeading:        return .topLeading
        case .topTrailing:       return .topTrailing
        case .bottomLeading:     return .bottomLeading
        case .bottomTrailing:    return .bottomTrailing
        case .inCompactRow,
             .hidden:            return .topTrailing        // defensive — unreachable on Small zones
        }
    }
}
