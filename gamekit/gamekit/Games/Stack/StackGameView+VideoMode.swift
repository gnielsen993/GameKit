//
//  StackGameView+VideoMode.swift
//  gamekit
//
//  Video Mode branch layouts for StackGameView (ARCADE-08 amendment
//  2026-07-02 — Stack's exemption lifted; see 15-VIDEO-MODE-ADR.md).
//
//  Necessity principle (user directive 2026-07-09, DESIGN §7.7): chrome
//  changes from its off-path form ONLY where the selected PiP zone actually
//  covers it. Zones that leave an element unobstructed render it exactly
//  as off-path — the premium score overlay is never demoted to a compact
//  chip unless the band genuinely displaces it.
//
//  Owns:
//    - `videoModeLayout` — zone dispatch.
//    - `largeTopLayout` — band covers the top, so the nav bar is genuinely
//      displaced: nav bar hidden (DESIGN §7.1), compact row at the bottom
//      edge, score/streak migrate into the row (`coreStack(scoreAlignment:
//      nil)`).
//    - `.largeBottom` → `standardChromeLayout` — the band covers only the
//      bottom; the nav bar + premium `.topTrailing` score overlay stay
//      byte-identical to off-path and the `videoModeAware` safeAreaInset
//      alone shrinks the board. Board math (393×852 reference): 852 − 59
//      status/safe − 44 nav − 273 band ≈ 476pt of canvas — StackBoardCanvas
//      is fully scale-free, so no floor is broken.
//    - `smallTopZoneLayout` — per-corner necessity: smallTopLeft covers the
//      back chevron (moves to topBarTrailing; score stays .topTrailing);
//      smallTopRight covers the score overlay (packs to .bottomTrailing per
//      the VideoModeSlotRouter headerBar anchor; back chevron stays put).
//    - `.smallBottomLeft` / `.smallBottomRight` → `standardChromeLayout` —
//      bottom PiP corners cover no Stack chrome (tap-anywhere input, tower
//      centered), so the layout is byte-identical to off-path.
//    - `compactRowComposed` — Back | StackScoreChip | (empty picker) |
//      StackStreakChip (streak > 0 only). NO restart button — Stack has no
//      mid-run restart affordance by design (a restart mid-run forfeits the
//      run); the game-over banner carries Restart. `onSettings: nil` —
//      Stack has no in-game settings.
//
//  Reflow safety: StackEngine is pure normalized-coordinate (playfield
//  width = 1.0) and StackBoardCanvas derives all geometry from its size
//  every frame — a mid-run band reflow rescales the render and cannot
//  desync engine state.
//

import SwiftUI
import DesignKit

extension StackGameView {

    // MARK: - Zone dispatch (necessity principle — DESIGN §7.7)

    @ViewBuilder
    var videoModeLayout: some View {
        switch videoModeStore.location {
        case .largeTop:
            largeTopLayout
        case .largeBottom, .smallBottomLeft, .smallBottomRight:
            // Bottom PiP covers no Stack chrome — off-path chrome preserved.
            standardChromeLayout
        case .smallTopLeft, .smallTopRight:
            smallTopZoneLayout
        }
    }

    // MARK: - Off-path chrome (shared by .largeBottom + small bottom zones)

    /// The exact off-path chrome stack (StackGameView.body's else-branch):
    /// nav bar + back chevron + premium `.topTrailing` score overlay. On
    /// `.largeBottom` the `videoModeAware` band inset shrinks the content
    /// area from below; on small bottom zones nothing changes at all.
    @ViewBuilder
    var standardChromeLayout: some View {
        coreStack(scoreAlignment: .topTrailing)
            .navigationTitle(String(localized: "Stack"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { backChevron }
    }

    // MARK: - Large top (DESIGN §7.1 — band genuinely displaces the nav bar)

    /// Nav bar hidden; compact row at the bottom edge (opposite the band).
    /// The backdrop paints the full screen behind row + board and joins the
    /// game-over grayscale drain, matching the off-path treatment. The
    /// compact row stays un-grayscaled — it is chrome, like the banner.
    @ViewBuilder
    var largeTopLayout: some View {
        ZStack {
            backdrop
                .grayscale(vm.state == .gameOver ? 1.0 : 0.0)
                .animation(fxEnabled ? .easeOut(duration: 0.5) : nil,
                           value: vm.state == .gameOver)

            VStack(spacing: theme.spacing.m) {
                coreStack(scoreAlignment: nil, includeBackdrop: false)
                compactRowComposed
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

    // MARK: - Small top zones (per-corner necessity)

    /// Only the element under the covered corner moves:
    /// - `.smallTopLeft`: PiP covers the back chevron → it re-anchors to
    ///   `.topBarTrailing`; the `.topTrailing` score overlay is unobstructed
    ///   and keeps its off-path premium form.
    /// - `.smallTopRight`: PiP covers the score overlay → it packs to
    ///   `.bottomTrailing` (VideoModeSlotRouter headerBar anchor for this
    ///   zone); the back chevron is unobstructed and stays `.topBarLeading`.
    @ViewBuilder
    var smallTopZoneLayout: some View {
        let pipCoversLeading = videoModeStore.location == .smallTopLeft
        coreStack(scoreAlignment: pipCoversLeading ? .topTrailing : .bottomTrailing)
            .navigationTitle(String(localized: "Stack"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: pipCoversLeading ? .topBarTrailing : .topBarLeading) {
                    backButton
                }
            }
    }
}
