//
//  SnakeGameView+VideoMode.swift
//  gamekit
//
//  Video Mode branch layouts for SnakeGameView (exemption lifted 2026-07-09;
//  see 15-VIDEO-MODE-ADR.md amendment). The old exemption rationale was
//  stale: SnakeConfig defines a FIXED logical 20×32 grid and SnakeBoardCanvas
//  derives cellSize from its own size every frame, so a PiP band reflow only
//  rescales the render — engine state (logical cell coordinates) cannot
//  desync. Same property that lifted Stack's exemption on 2026-07-02.
//
//  Necessity principle (user directive 2026-07-09, DESIGN §7.7): chrome
//  changes from its off-path form ONLY where the selected PiP zone actually
//  covers it.
//
//  Owns:
//    - `videoModeLayout` — zone dispatch.
//    - `largeTopLayout` — the band covers the nav bar: nav bar hidden
//      (DESIGN §7.1), compact row at the bottom edge (opposite the band)
//      carrying Back | compact score chip | (empty picker) | compact
//      wall-mode menu. Score row hidden — score lives in the row.
//    - `.largeBottom` → `standardLayout()` — the band covers only the
//      bottom; the `videoModeAware` safeAreaInset compresses the VStack so
//      the D-pad sits above the band and the aspect-fit board shrinks.
//      Nothing is covered, so nav bar + trailing score chip stay
//      byte-identical to off-path.
//    - `.smallTopLeft` — PiP covers the back chevron corner: back + wall
//      menu re-anchor to `.topBarTrailing`; score chip (trailing) is
//      unobstructed and stays put.
//    - `.smallTopRight` — PiP covers the trailing corner: wall menu joins
//      the back chevron at `.topBarLeading` and the score chip moves to the
//      leading side; the back chevron itself is unobstructed and stays put.
//    - `.smallBottomLeft` / `.smallBottomRight` → `standardLayout()` — the
//      centered D-pad (~140pt wide) clears the ~108pt-wide corner PiP on
//      both sides; no chrome is covered, layout byte-identical to off-path.
//
//  Input safety: the D-pad remains fully visible and tappable in every
//  zone, and the board swipe surface shrinks only with the board itself —
//  steering never lands under the PiP.
//

import SwiftUI
import DesignKit

extension SnakeGameView {

    // MARK: - Zone dispatch (necessity principle — DESIGN §7.7)

    @ViewBuilder
    var videoModeLayout: some View {
        switch videoModeStore.location {
        case .largeTop:
            largeTopLayout
        case .largeBottom, .smallBottomLeft, .smallBottomRight:
            // Bottom PiP covers no Snake chrome — off-path chrome preserved;
            // on .largeBottom the band inset alone compresses the content.
            standardLayout()
        case .smallTopLeft:
            standardLayout(backPlacement: .topBarTrailing,
                           menuPlacement: .topBarTrailing)
        case .smallTopRight:
            standardLayout(scoreOnLeading: true,
                           backPlacement: .topBarLeading,
                           menuPlacement: .topBarLeading)
        }
    }

    // MARK: - Large top (DESIGN §7.1 — band genuinely displaces the nav bar)

    /// Nav bar hidden; compact row at the bottom edge (opposite the band),
    /// below the D-pad. The score row is dropped — the compact score chip in
    /// the row is the score surface for this zone.
    @ViewBuilder
    var largeTopLayout: some View {
        coreContent(showScoreRow: false, includeCompactRow: true)
            .toolbar(.hidden, for: .navigationBar)
    }

    /// §3.5 slot order: Back | primary info | picker | secondary info.
    /// Score is the load-bearing chip (primary). Empty picker slot — Snake's
    /// D-pad occupies the mode-pill role and stays in the main stack. The
    /// wall-mode menu rides the secondary slot at row height (the 44pt
    /// toolbar variant would overflow the `theme.spacing.xl` pill).
    @ViewBuilder
    var compactRowComposed: some View {
        VideoCompactControlRow(
            theme: theme,
            onBack: { dismiss() },
            onSettings: nil      // wall-mode menu covers the settings role
        ) {
            SnakeScoreChip(theme: theme, score: vm.frame.score, compact: true)
        } picker: {
            EmptyView()
        } secondaryInfo: {
            compactWallModeMenu
        }
    }

    /// Row-height wall-mode menu — same action surface as `wallModeMenu`,
    /// sized to the compact row's `theme.spacing.xl` pill height.
    @ViewBuilder
    var compactWallModeMenu: some View {
        Menu {
            Button(vm.wallMode
                   ? String(localized: "Wall mode: On")
                   : String(localized: "Wall mode: Off")) {
                vm.requestWallModeToggle()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: theme.spacing.xl, height: theme.spacing.xl)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.button, style: .continuous))
        }
        .accessibilityLabel(Text("Options"))
    }
}
